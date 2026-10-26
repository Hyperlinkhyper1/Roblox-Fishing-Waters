-- Shop customers. Owners carry fish individually to their base freezers; a customer
-- wearing a random Roblox avatar walks in, takes one frozen fish to a register
-- and waits until the owner serves them. Each register (the built-in counter plus
-- any bought ones) serves one customer at a time. The sale is a single profile
-- update, so a fish can never be sold twice or paid for without leaving the freezer.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnglerData = require(script.Parent.AnglerData)
local BoatService = require(script.Parent.BoatService)
local CargoService = require(script.Parent.CargoService)
local NpcNavigation = require(script.Parent.NpcNavigation)
local FishFreezer = require(script.Parent.Map.FishFreezer)
local ShopDesk = require(script.Parent.Map.ShopDesk)
local StorageRack = require(script.Parent.Map.StorageRack)
local Kitchen = require(script.Parent.Map.Kitchen)
local Catalog = require(ReplicatedStorage.Shared.AnglerCatalog)
local Paths = require(ReplicatedStorage.Shared.Paths)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Furniture = require(ReplicatedStorage.Shared.FurnitureCatalog)
local FishCatch = require(ReplicatedStorage.Shared.FishCatch)
local FishModels = require(ReplicatedStorage.Shared.FishModels)
local StaffCatalog = require(ReplicatedStorage.Shared.StaffCatalog)
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))

local CustomerService = {}
local BASE_TAG = "PlayerBase"
local OWNER_PROMPT_TAG = "ShopOwnerPrompt"
local WALK_SPEED = 9
local STAFF_WALK_SPEED = 16
local WAIT_SECONDS = 150
local ARRIVAL_SECONDS = 25
local SERVE_DISTANCE = 14
local MAX_USER_ID = 3_000_000_000
-- Default R15 animations; NPCs have no Animate script of their own.
local IDLE_ANIMATION = "rbxassetid://507766666"
local WALK_ANIMATION = "rbxassetid://507777826"

local random = Random.new()
local started = false
local update: RemoteEvent
local folder: Folder
local shops: { [Model]: any } = {}
local customers: { [ProximityPrompt]: any } = {}
local stocking: { [Player]: boolean } = {}
local PORTER_DOCK_DISTANCE = 32

local function notify(player: Player?, message: string)
	if player and player.Parent == Players then
		update:FireClient(player, "Notice", message)
	end
end

local function ownerOf(base: Model): Player?
	local userId = base:GetAttribute("OwnerUserId")
	return if type(userId) == "number" and userId ~= 0 then Players:GetPlayerByUserId(userId) else nil
end

local function houseFrame(base: Model): CFrame?
	local house = base:FindFirstChild("BaseHouse")
	local frame = house and house:GetAttribute("HouseFrame")
	return if typeof(frame) == "CFrame" then frame else nil
end

local function near(player: Player, position: Vector3, distance: number): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return humanoid ~= nil
		and humanoid.Health > 0
		and root ~= nil
		and root:IsA("BasePart")
		and (root.Position - position).Magnitude <= distance
end

local function ownerPrompt(parent: Instance, name: string, action: string, object: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	CollectionService:AddTag(prompt, OWNER_PROMPT_TAG)
	prompt.Parent = parent
	return prompt
end

-- Fish still on the ice; a customer's fish stays in the save until it is sold.
local function frozenCount(shop, owner: Player?): number
	local profile = owner and BoatService.getProfile(owner)
	local count = if profile then #profile.Angler.Freezer else 0
	for _, customer in shop.customers do
		if customer.taken and not customer.food then
			count -= 1
		end
	end
	return math.max(0, count)
end

local function describeFish(record): string
	local recipe = record.RecipeId and Recipes.Items[record.RecipeId]
	if recipe then
		return recipe.Name
	end
	local fish = Catalog.Fish[record.FishId]
	return string.format("%s · %s", if fish then fish.Name else record.FishId, FishCatch.formatKg(record.Kg))
end

-- Customers get a random real avatar; deleted accounts just mean another roll.
local function randomAvatar(): HumanoidDescription
	for _ = 1, 6 do
		local ok, description = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(random:NextInteger(1, MAX_USER_ID))
		end)
		if ok and description then
			return description
		end
	end
	return Instance.new("HumanoidDescription")
end

local function animate(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local function load(id: string, priority: Enum.AnimationPriority): AnimationTrack
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local track = animator:LoadAnimation(animation)
		track.Priority, track.Looped = priority, true
		return track
	end
	local idle = load(IDLE_ANIMATION, Enum.AnimationPriority.Idle)
	local walk = load(WALK_ANIMATION, Enum.AnimationPriority.Movement)
	idle:Play()
	humanoid.Running:Connect(function(speed)
		if speed > 0.5 and not walk.IsPlaying then
			walk:Play(0.15)
		elseif speed <= 0.5 and walk.IsPlaying then
			walk:Stop(0.2)
		end
	end)
end

local function bubble(customer, text: string)
	local label = customer.label
	if not label then
		local head = customer.model:FindFirstChild("Head")
		if not head then
			return
		end
		local billboard = Instance.new("BillboardGui")
		billboard.Name, billboard.Size = "CustomerBubble", UDim2.fromOffset(240, 34)
		billboard.StudsOffset, billboard.MaxDistance = Vector3.new(0, 2.6, 0), 60
		label = Instance.new("TextLabel")
		label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		label.Font, label.TextSize = Enum.Font.GothamBold, 15
		Theme.text(label)
		label.Parent, billboard.Parent = billboard, head
		customer.label = label
	end
	label.Text = text
end

local function spawnCustomer(position: Vector3, staffRole: string?): Model
	local description = if staffRole then StaffCatalog.description(staffRole) else randomAvatar()
	local ok, model =
		pcall(Players.CreateHumanoidModelFromDescriptionAsync, Players, description, Enum.HumanoidRigType.R15)
	description:Destroy()
	if not ok then
		error(model)
	end
	if staffRole then
		StaffCatalog.finishModel(model)
	end
	model.Name = "Customer"
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = if staffRole then STAFF_WALK_SPEED else WALK_SPEED
	humanoid.BreakJointsOnDeath = false
	model:PivotTo(CFrame.new(position + Vector3.new(0, model:GetExtentsSize().Y / 2, 0)))
	model.Parent = folder
	-- Server-owned so a nearby player's client never takes over the walk.
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	pcall(root.SetNetworkOwner, root, nil)
	animate(humanoid)
	return model
end

-- Returns the fish at its catch's world size, plus its scaled size
-- in fish axes (snout +X, back +Y). Welded fish can be carried; others stay anchored.
local function fishModel(record, welded: boolean): (Model?, Vector3)
	local model = FishModels.create(record.FishId, record)
	if not model then
		return nil, Vector3.zero
	end
	local size = FishModels.scaleCatch(model, record.Kg)
	local anchor: BasePart? = nil
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Massless = true
			if not anchor then
				anchor = part
			elseif welded then
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1, weld.Parent = anchor, part, part
			end
		end
	end
	if not anchor then
		model:Destroy()
		return nil, Vector3.zero
	end
	-- Pivot at the middle of the fish, keeping its axes.
	local center = model:GetBoundingBox()
	anchor.PivotOffset = anchor.CFrame:ToObjectSpace(CFrame.new(center.Position))
	model.PrimaryPart = anchor
	return model, size
end

-- How far the model reaches below `origin` along `axis` (negative when below).
local function lowestAlong(model: Model, origin: Vector3, axis: Vector3): number
	local lowest = math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local frame, half = part.CFrame, part.Size / 2
			local reach = math.abs(frame.RightVector:Dot(axis)) * half.X
				+ math.abs(frame.UpVector:Dot(axis)) * half.Y
				+ math.abs(frame.LookVector:Dot(axis)) * half.Z
			lowest = math.min(lowest, (frame.Position - origin):Dot(axis) - reach)
		end
	end
	return lowest
end

-- Places the fish lying on the surface whose UpVector is the normal.
local function restOn(fish: Model, surface: CFrame, turn: CFrame)
	fish:PivotTo(surface * turn)
	local normal = surface.UpVector
	fish:PivotTo(fish:GetPivot() + normal * (0.01 - lowestAlong(fish, surface.Position, normal)))
end

-- The shop's built-in fixture first, then every placed one of `itemId`, as world frames.
local function fixtureFrames(shop, profile, itemId: string, builtIn: CFrame?): { CFrame }
	local frames = if builtIn then { builtIn } else {}
	for _, entry in if profile then profile.Angler.Furniture else {} do
		if entry.ItemId == itemId then
			table.insert(frames, Furniture.frame(shop.frame, entry))
		end
	end
	return frames
end

local function freezerFrames(shop, profile): { CFrame }
	return fixtureFrames(shop, profile, "Freezer", FishFreezer.frame(shop.frame))
end

local function recordKey(record): string
	return string.format(
		"%s:%s:%s:%s:%s:%s",
		record.FishId,
		record.Mutation,
		record.Size or "",
		record.Kg,
		record.CaughtAt,
		record.Value
	) .. ":" .. table.concat(record.Corruptions or {}, ",")
end

-- The owner's frozen fish use the authoritative size-based cooler layout. The
-- fish customers have taken are left out until they are sold or put back.
local function refreshDisplay(shop)
	local owner = ownerOf(shop.base)
	local profile = owner and BoatService.getProfile(owner)
	local frozen = if profile then profile.Angler.Freezer else {}
	local frames = freezerFrames(shop, profile)
	local takenKeys, taken = {}, {}
	for _, customer in shop.customers do
		if customer.taken and not customer.food then
			local key = recordKey(customer.record)
			table.insert(takenKeys, key)
			taken[key] = (taken[key] or 0) + 1
		end
	end
	table.sort(takenKeys)
	local keys = { tostring(owner and owner.UserId), table.concat(takenKeys, ","), tostring(#frames) }
	for _, frame in frames do
		table.insert(keys, tostring(frame))
	end
	for index = 1, #frozen do
		table.insert(keys, recordKey(frozen[index]))
	end
	local signature = table.concat(keys, "|")
	if signature == shop.displaySignature then
		return
	end
	shop.displaySignature = signature
	if shop.display then
		shop.display:Destroy()
	end
	local display = Instance.new("Model")
	display.Name = "FrozenFishDisplay"
	shop.display = display
	shop.displayFish = {}
	local placements = if profile then AnglerData.freezerLayout(profile.Angler) else {}
	shop.shown = 0
	for index, record in frozen do
		local placement = placements[index]
		local key = recordKey(record)
		-- Taken fish keep their reserved space until the sale completes.
		if (taken[key] or 0) > 0 then
			taken[key] -= 1
			continue
		end
		if not placement then
			continue
		end
		local frame = frames[placement.Freezer]
		local fish = fishModel(record, true)
		if not fish then
			continue
		end
		local turn = CFrame.Angles(0, if placement.Rotated then 0 else math.pi / 2, 0)
			* (if placement.Flat then CFrame.identity else CFrame.Angles(math.pi / 2, 0, 0))
		restOn(fish, FishFreezer.iceSurface(frame, placement.X, placement.Z), turn)
		fish.Parent = display
		shop.shown += 1
		table.insert(shop.displayFish, { record = record, model = fish, freezer = frame })
	end
	display.Parent = shop.freezerPrompt.Parent.Parent
end

local function setAnchored(model: Model, anchored: boolean)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = anchored
		end
	end
end

local function carry(customer, fish: Model, stackIndex: number?)
	local hand = customer.model:FindFirstChild("RightHand") :: BasePart?
	if not hand then
		return
	end
	setAnchored(fish, false)
	-- Held by the middle just in front of the hand, snout forward.
	fish:PivotTo(hand.CFrame * CFrame.new(0, -0.3 + (stackIndex or 0) * 0.45, -0.5) * CFrame.Angles(0, math.pi / 2, 0))
	fish.Parent = customer.model
	local grip = Instance.new("WeldConstraint")
	grip.Name, grip.Part0, grip.Part1, grip.Parent = "FishGrip", hand, fish.PrimaryPart, hand
	customer.grip = grip
end

local function takeFromFreezer(shop, customer): Model?
	if not customer.model:FindFirstChild("RightHand") then
		return nil
	end
	for _, item in shop.displayFish or {} do
		if recordKey(item.record) == recordKey(customer.record) and item.model.Parent == shop.display then
			-- Move the actual displayed fish before rebuilding its former container.
			local fish = item.model
			carry(customer, fish)
			customer.fish, customer.taken = fish, true
			refreshDisplay(shop)
			return fish
		end
	end
	return nil
end

local function putOnCounter(customer, fish: Model, frame: CFrame, turn: CFrame?)
	if customer.grip then
		customer.grip:Destroy()
		customer.grip = nil
	end
	-- Lying on its side along the counter edge, resting on the desk top. Dishes stay flat.
	setAnchored(fish, true)
	restOn(fish, frame, turn or CFrame.Angles(math.pi / 2, 0, 0))
	fish.Parent = folder
end

-- Cooked dishes (Supermarket path) sit in the placed food display cases, oldest
-- first, six to a case. Like frozen fish, a dish stays saved until it is paid for.
local function dishKey(dish): string
	return string.format(
		"%s:%s:%s:%s:%s",
		dish.RecipeId,
		dish.FishId,
		tostring(dish.Kg),
		tostring(dish.MadeAt),
		tostring(dish.Value)
	)
end

-- A carriable dish: every part welded to one anchor whose pivot is the plate's base.
local function dishModel(dish, frame: CFrame): Model?
	local recipe = Recipes.Items[dish.RecipeId]
	if not recipe then
		return nil
	end
	local model = Kitchen.buildDish(dish.RecipeId, recipe.Look, frame)
	local anchor: BasePart? = nil
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Massless = true
			if not anchor then
				anchor = part
			else
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1, weld.Parent = anchor, part, part
			end
		end
	end
	if not anchor then
		model:Destroy()
		return nil
	end
	anchor.PivotOffset = anchor.CFrame:ToObjectSpace(frame)
	model.PrimaryPart = anchor
	return model
end

local function refreshFoodDisplay(shop)
	local owner = ownerOf(shop.base)
	local profile = owner and BoatService.getProfile(owner)
	local dishes = if profile then profile.Angler.Pantry else {}
	local frames = fixtureFrames(shop, profile, "FoodCase")
	local taken = {}
	local keys = { tostring(owner and owner.UserId) }
	for _, customer in shop.customers do
		if customer.taken and customer.food then
			local key = dishKey(customer.record)
			taken[key] = (taken[key] or 0) + 1
			table.insert(keys, "taken " .. key)
		end
	end
	for _, frame in frames do
		table.insert(keys, tostring(frame.Position))
	end
	local shown = math.min(#dishes, #frames * #Kitchen.CASE_SPOTS)
	for index = 1, shown do
		table.insert(keys, dishKey(dishes[index]))
	end
	local signature = table.concat(keys, "|")
	if signature == shop.foodSignature then
		return
	end
	shop.foodSignature = signature
	if shop.foodDisplay then
		shop.foodDisplay:Destroy()
	end
	local display = Instance.new("Model")
	display.Name = "FoodDisplay"
	shop.foodDisplay, shop.displayFood = display, {}
	for index = 1, shown do
		local dish = dishes[index]
		local key = dishKey(dish)
		if (taken[key] or 0) > 0 then
			taken[key] -= 1
			continue
		end
		local case = frames[(index - 1) // #Kitchen.CASE_SPOTS + 1]
		local model = dishModel(dish, case * Kitchen.CASE_SPOTS[(index - 1) % #Kitchen.CASE_SPOTS + 1])
		if model then
			model.Parent = display
			table.insert(shop.displayFood, { record = dish, model = model, freezer = case, food = true })
		end
	end
	display.Parent = shop.freezerPrompt.Parent.Parent
end

local function takeFood(shop, customer): Model?
	if not customer.model:FindFirstChild("RightHand") then
		return nil
	end
	for _, item in shop.displayFood or {} do
		if dishKey(item.record) == dishKey(customer.record) and item.model.Parent == shop.foodDisplay then
			local dish = item.model
			carry(customer, dish)
			customer.fish, customer.taken = dish, true
			refreshFoodDisplay(shop)
			return dish
		end
	end
	return nil
end

local function refreshShelves(shop)
	refreshDisplay(shop)
	refreshFoodDisplay(shop)
end

local function walk(
	customer,
	target: Vector3,
	allowed: (() -> boolean)?,
	stayOnGround: boolean?,
	straight: boolean?
): boolean
	return NpcNavigation.walk(customer, target, allowed, stayOnGround, straight)
end

local function face(customer, position: Vector3)
	local root = customer.root
	local look = Vector3.new(position.X, root.Position.Y, position.Z)
	if (look - root.Position).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, look)
	end
end

local function leave(customer)
	if customer.leaving then
		return
	end
	customer.leaving = true
	if customer.prompt then
		customers[customer.prompt] = nil
		customer.prompt:Destroy()
		customer.prompt = nil
	end
end

local function finish(shop, customer)
	customer.active = false
	if customer.prompt then
		customers[customer.prompt] = nil
	end
	if customer.counterFish then
		customer.counterFish:Destroy()
	end
	if customer.model then
		customer.model:Destroy()
	end
	local index = table.find(shop.customers, customer)
	if index then
		table.remove(shop.customers, index)
		refreshShelves(shop)
	end
end

local function visit(shop, customer)
	local base, frame = shop.base, shop.frame
	local function at(x: number, z: number): Vector3
		return (frame * CFrame.new(x, 0.16, z)).Position
	end
	local freezerFrame = customer.freezer
	local deskFrame = customer.register
	local counterTop = deskFrame * CFrame.new(0.2 * ShopDesk.WIDTH, ShopDesk.HEIGHT, -ShopDesk.DEPTH / 4)

	-- Arrive from the street outside the front door when there is ground there.
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = { folder }
	parameters.RespectCanCollide = true
	parameters.IgnoreWater = true
	local street = at(0, 24)
	local hit = workspace:Raycast(street + Vector3.new(0, 10, 0), Vector3.new(0, -20, 0), parameters)
	local entry = if hit then hit.Position else at(0, 18.6)

	customer.model = spawnCustomer(entry)
	customer.humanoid = customer.model:FindFirstChildOfClass("Humanoid")
	customer.root = customer.model:FindFirstChild("HumanoidRootPart")
	local clearance = NpcNavigation.clearance(customer) + 0.4
	local shelfDepth = if customer.food then Kitchen.CASE_DEPTH else FishFreezer.DEPTH
	local freezerSpot = (freezerFrame * CFrame.new(0, 0, shelfDepth / 2 + clearance)).Position
	local counterSpot = (deskFrame * CFrame.new(0.15 * ShopDesk.WIDTH, 0, -ShopDesk.DEPTH / 2 - clearance)).Position
	local name = describeFish(customer.record)
	bubble(customer, if customer.food then "Looking for a meal…" else "Looking for fish…")
	customer.humanoid.Died:Once(function()
		customer.active = false
	end)

	-- Each step stops early if the owner leaves or the customer is dismissed.
	local function shopping(): boolean
		local function going(target: Vector3): boolean
			return walk(customer, target, function()
				return not customer.leaving
			end)
		end
		if not (going(at(0, 18.6)) and going(at(0, 11)) and going(freezerSpot)) then
			return false
		end
		face(customer, freezerFrame.Position)
		task.wait(1.2)
		if not customer.active or customer.leaving then
			return false
		end
		local fish = if customer.food then takeFood(shop, customer) else takeFromFreezer(shop, customer)
		if not fish then
			return false
		end
		bubble(customer, (if customer.food then "I'll take the " else "I'd like this ") .. name)
		if not (going(at(0, 9)) and going(counterSpot)) then
			return false
		end
		face(customer, deskFrame.Position)
		task.wait(0.5)
		if not customer.active or customer.leaving then
			return false
		end
		putOnCounter(customer, fish, counterTop, if customer.food then CFrame.identity else nil)
		customer.counterFish, customer.fish = fish, nil
		local price = math.max(1, math.floor(customer.record.Value))
		bubble(customer, string.format("%s — $%d", name, price))
		local prompt = ownerPrompt(customer.root, "SellToCustomerPrompt", "Sell for $" .. price, name)
		prompt:SetAttribute("OwnerUserId", base:GetAttribute("OwnerUserId"))
		customer.prompt = prompt
		customers[prompt] = customer
		notify(ownerOf(base), "A customer is waiting at your register for a " .. name .. ".")
		local deadline = os.clock() + WAIT_SECONDS
		while customer.active and not customer.leaving and os.clock() < deadline do
			task.wait(0.25)
		end
		return true
	end

	shopping()
	if not customer.active then
		return
	end
	leave(customer)
	if customer.sold and customer.counterFish then
		-- Paid for; take the fish home.
		carry(customer, customer.counterFish)
		customer.counterFish = nil
		bubble(customer, "Thank you!")
	else
		-- Unsold fish stays in the owner's freezer; only the display copy goes.
		for _, key in { "fish", "counterFish" } do
			if customer[key] then
				customer[key]:Destroy()
				customer[key] = nil
			end
		end
		customer.taken = false
		refreshShelves(shop)
		bubble(customer, "Never mind…")
	end
	task.wait(0.8)
	local exit = { at(0, 11), at(0, 18.6), entry }
	for _, target in exit do
		if not walk(customer, target) then
			return
		end
	end
end

local function sell(player: Player, customer, worker)
	local shop = customer.shop
	local function authorized(profile): boolean
		if ownerOf(shop.base) ~= player or not customer.active or customer.leaving then
			return false
		end
		if worker then
			local desk = ShopDesk.frame(shop.frame)
			return shop.staff.Seller == worker
				and worker.active
				and worker.humanoid.Health > 0
				and profile.Angler.Staff.Seller == true
				and worker.model.Parent ~= nil
				and (worker.root.Position - desk.Position).Magnitude <= SERVE_DISTANCE
		end
		return near(player, customer.root.Position, SERVE_DISTANCE)
	end
	local profile = BoatService.getProfile(player)
	if customer.leaving or customer.selling or not profile or not authorized(profile) then
		return
	end
	customer.selling = true
	local price = 0
	-- Dishes come off the kitchen pass; fish out of the freezer.
	local function pay(angler)
		if customer.food then
			return AnglerData.sellDish(angler, customer.record, 1, "FoodSold")
		end
		return AnglerData.sellFrozen(angler, customer.record)
	end
	local gone = if customer.food
		then "That dish is no longer on your kitchen pass."
		else "That fish is no longer in your freezer."
	local ok, message = BoatService.updateProgress(player, function(profile)
		assert(authorized(profile), "This customer can no longer be served.")
		local data, paid = pay(profile.Angler)
		assert(data, gone)
		profile.Angler = data
		profile.Cash += paid
		price = paid
	end)
	customer.selling = false
	if ok then
		customer.sold = true
		customer.taken = false
		refreshDisplay(shop)
		if customer.food then
			refreshFoodDisplay(shop)
		end
		leave(customer)
		notify(player, string.format("Sold %s for $%d.", describeFish(customer.record), price))
		return
	end
	local profile = BoatService.getProfile(player)
	if profile and not pay(profile.Angler) then
		-- The fish is gone (sold elsewhere or a stale session); the customer gives up.
		leave(customer)
		notify(player, gone)
	else
		notify(player, message)
	end
end

local function removeStaff(shop)
	for _, worker in shop.staff do
		worker.active = false
		worker.model:Destroy()
	end
	shop.staff = {}
end

-- The Company path's fisherman moors his boat beside the dock; CompanyService
-- sets this to report it (boat id and model) once it is tied up.
local companyDock: ((any, Player) -> (string?, Model?))? = nil

-- Only the owner's launched, stationary boat at this base can be unloaded.
local function dockedBoat(shop, owner: Player): (string?, Model?)
	local id, model = BoatService.activeBoat(owner)
	local marker = shop.base:FindFirstChild("BoatSpawn")
	local root = model and model.PrimaryPart
	if
		ownerOf(shop.base) ~= owner
		or not marker
		or not marker:IsA("BasePart")
		or not root
		or model:GetAttribute("OwnerUserId") ~= owner.UserId
	then
		return nil, nil
	end
	local delta = root.Position - marker.Position
	if
		Vector3.new(delta.X, 0, delta.Z).Magnitude > PORTER_DOCK_DISTANCE
		or math.abs(delta.Y) > 12
		or root.AssemblyLinearVelocity.Magnitude > 2
	then
		return nil, nil
	end
	return id, model
end

local function rackFrames(shop, profile): { CFrame }
	return fixtureFrames(shop, profile, "StorageRack")
end

-- Through the shop-to-storage doorway to the front of a rack.

local function storageRoute(shop, rack: CFrame, worker): { Vector3 }
	local function at(x: number, z: number): Vector3
		return (shop.frame * CFrame.new(x, 0.16, z)).Position
	end
	return {
		at(12, 4),
		at(12, -2),
		(rack * CFrame.new(0, 0, StorageRack.DEPTH / 2 + NpcNavigation.clearance(worker) + 0.4)).Position,
	}
end

-- A rig below the deck cannot use the dock's walking-only route back up.
local function belowDock(shop, worker): boolean
	local dock = shop.base:GetAttribute("BoatDockFrame")
	if typeof(dock) ~= "CFrame" then
		return false
	end
	local position = dock:PointToObjectSpace(worker.root.Position)
	local feet = position.Y - worker.humanoid.HipHeight - worker.root.Size.Y / 2
	return math.abs(position.X) <= 25 and position.Z >= -48 and position.Z <= 8 and feet < 2.2
end

-- Each fish has a visual copy; saved inventory changes only after delivery.
local function carryLoad(worker, load): boolean
	worker.load = {}
	for index, entry in load do
		local fish = fishModel(entry.Record, true)
		if not fish then
			return false
		end
		local carried = { fish = fish }
		table.insert(worker.load, carried)
		carry(worker, fish, index - 1)
		carried.grip = worker.grip
		worker.grip = nil
	end
	return true
end

-- Boat to the freezer, or to a storage rack once the freezers are full.
local function unloadTrip(shop, worker, owner: Player, boatId: string, boat: Model, load, rack: CFrame?)
	local dock = shop.base:GetAttribute("BoatDockFrame")
	if typeof(dock) ~= "CFrame" then
		return
	end
	local function valid(): boolean
		local currentId, currentBoat = dockedBoat(shop, owner)
		if currentBoat ~= boat and companyDock then
			currentId, currentBoat = companyDock(shop, owner)
		end
		return worker.active
			and shop.staff.Porter == worker
			and worker.humanoid.Health > 0
			and currentId == boatId
			and currentBoat == boat
	end
	local function go(position: Vector3, straight: boolean?): boolean
		if not valid() then
			return false
		end
		local reached = walk(worker, position, valid, true, straight)
		if not reached and valid() and belowDock(shop, worker) then
			worker.stranded = true
		end
		return reached and valid()
	end
	local side = if dock:PointToObjectSpace(worker.root.Position).X < 0 then -1 else 1
	local pier = (dock * CFrame.new(side * 17, 3.3, -38)).Position
	local pickup = (dock * CFrame.new(0, 3.3, -38)).Position
	-- Collect from the pier's center, never the boat-side edge. Company hulls
	-- have no collision, so stepping toward them leaves no ground underfoot.
	local moorPier = boat:GetAttribute("PorterPier")
	if typeof(moorPier) == "Vector3" then
		pier, pickup = moorPier, moorPier
		side = if dock:PointToObjectSpace(pier).X < 0 then -1 else 1
	end
	local landing = (dock * CFrame.new(side * 17, 5.9, 11)).Position
	local foot = (dock * CFrame.new(side * 17, 3.3, -2)).Position
	bubble(worker, "Porter · Collecting fish")
	local current = dock:PointToObjectSpace(worker.root.Position)
	local feet = current.Y - worker.humanoid.HipHeight - worker.root.Size.Y / 2
	local onPier = math.abs(math.abs(current.X) - 17) <= 3 and current.Z >= -43 and current.Z <= 11 and feet >= 2.2
	local onLink = math.abs(current.X) <= 17 and math.abs(current.Z + 38) <= 1 and feet >= 2.2
	if onLink then
		-- Retry from the crosswalk instead of walking back to the quay first.
		if not go((dock * CFrame.new(current.X, 3.3, -38)).Position, true) then
			return
		end
		if typeof(moorPier) == "Vector3" then
			if not go((dock * CFrame.new(side * 17, 3.3, -38)).Position, true) then
				return
			end
			if not go(pier, true) then
				return
			end
		end
	elseif onPier then
		local currentSide = if current.X < 0 then -1 else 1
		local y = math.max(3.3, 3.2 + 2.7 * math.clamp(current.Z / 8, 0, 1))
		if not go((dock * CFrame.new(currentSide * 17, y, current.Z)).Position, true) then
			return
		end
		if currentSide ~= side then
			-- Change piers over the crosswalk, never across the boat berth.
			if
				not (
					go((dock * CFrame.new(currentSide * 17, 3.3, -38)).Position, true)
					and go((dock * CFrame.new(side * 17, 3.3, -38)).Position, true)
				)
			then
				return
			end
		end
		if not go(pier, true) then
			return
		end
	else
		if not (go(landing) and go(foot, true) and go(pier, true)) then
			return
		end
	end
	if not go(pickup, true) then
		return
	end
	if not carryLoad(worker, load) then
		return
	end
	bubble(worker, string.format("Porter · Bringing %d fish to %s", #load, if rack then "storage" else "freezer"))
	local route = if rack
		then storageRoute(shop, rack, worker)
		else {
			(FishFreezer.frame(shop.frame) * CFrame.new(
				0,
				0,
				FishFreezer.DEPTH / 2 + NpcNavigation.clearance(worker) + 0.4
			)).Position,
		}
	-- Once off the pier, let pathfinding choose the doorway to the destination.
	if not (go(pier, true) and go(foot, true) and go(landing, true)) then
		return
	end
	for _, position in route do
		if not go(position) then
			return
		end
	end
	-- Revalidate inside every UpdateAsync attempt. The player may have moved the
	-- fish while the porter walked; the saved fish never leaves its hold early.
	BoatService.updateProgress(owner, function(current)
		assert(valid() and current.Angler.Staff.Porter, "The porter is no longer unloading this boat.")
		local data = current.Angler
		-- Preserve pickup order so freezer packing matches the planned load.
		-- Earlier removals shift each later cargo slot down by one.
		for index, entry in load do
			data = AnglerData.unloadFish(data, boatId, entry.Index - index + 1, entry.Record, rack ~= nil)
			assert(data, "The fish moved or the shelf is full.")
		end
		current.Angler = data
	end)
	refreshDisplay(shop)
end

-- A storage rack to the freezer, whenever a freezer has room again.
local function restockTrip(shop, worker, owner: Player, load, rack: CFrame)
	local function valid(): boolean
		return worker.active
			and shop.staff.Porter == worker
			and worker.humanoid.Health > 0
			and ownerOf(shop.base) == owner
	end
	local function go(position: Vector3): boolean
		return valid() and walk(worker, position, valid) and valid()
	end
	bubble(worker, "Porter · Restocking the freezer")
	local route = storageRoute(shop, rack, worker)
	for _, position in route do
		if not go(position) then
			return
		end
	end
	if not carryLoad(worker, load) then
		return
	end
	local freezerSpot = (FishFreezer.frame(shop.frame) * CFrame.new(
		0,
		0,
		FishFreezer.DEPTH / 2 + NpcNavigation.clearance(worker) + 0.4
	)).Position
	if not (go(route[2]) and go(route[1]) and go(freezerSpot)) then
		return
	end
	BoatService.updateProgress(owner, function(current)
		assert(valid() and current.Angler.Staff.Porter, "The porter is no longer restocking.")
		local data = current.Angler
		for _, entry in load do
			data = AnglerData.restockFish(data, entry.Record)
			assert(data, "The fish moved or the freezer is full.")
		end
		current.Angler = data
	end)
	refreshDisplay(shop)
end

local function porterTrip(shop, worker, owner: Player)
	local profile = BoatService.getProfile(owner)
	if not profile or not profile.Angler.Staff.Porter then
		return
	end
	local data = profile.Angler
	local speed, capacity = StaffCatalog.porterStats(data)
	worker.humanoid.WalkSpeed = speed
	local storageRoom = math.max(0, AnglerData.storageCapacity(data) - #data.Storage)
	local racks = rackFrames(shop, profile)
	local boatId, boat = dockedBoat(shop, owner)
	local ownBoatId, ownBoat = boatId, boat
	local load = {}
	local toStorage = false
	local room = math.min(storageRoom, AnglerData.RACK_CAPACITY - #data.Storage % AnglerData.RACK_CAPACITY)
	local function collectFish()
		load = {}
		local preview = table.clone(data)
		preview.Freezer = table.clone(data.Freezer)
		for slot, item in if boatId then data.Holds[boatId] or {} else {} do
			if item.Fish and #load < capacity then
				local fits = if toStorage then #load < room else AnglerData.canFreeze(preview, item.Fish)
				if fits then
					table.insert(load, { Index = slot, Record = item.Fish })
					table.insert(preview.Freezer, item.Fish)
				end
			end
		end
	end
	local function collectFromBoats()
		collectFish()
		if #load == 0 and companyDock then
			boatId, boat = companyDock(shop, owner)
			collectFish()
		end
	end
	collectFromBoats()
	if #load == 0 and room > 0 then
		toStorage = true
		boatId, boat = ownBoatId, ownBoat
		collectFromBoats()
	end
	if #load > 0 then
		local rack = if toStorage then racks[math.floor(#data.Storage / AnglerData.RACK_CAPACITY) + 1] else nil
		if not toStorage or rack then
			unloadTrip(shop, worker, owner, boatId :: string, boat :: Model, load, rack)
		end
	elseif #data.Storage > 0 and racks[1] then
		local preview = table.clone(data)
		preview.Freezer = table.clone(data.Freezer)
		for index = 1, math.min(#data.Storage, AnglerData.RACK_CAPACITY) do
			local record = data.Storage[index]
			if #load < capacity and AnglerData.canFreeze(preview, record) then
				table.insert(load, { Record = record })
				table.insert(preview.Freezer, record)
			end
		end
		if #load > 0 then
			restockTrip(shop, worker, owner, load, racks[1])
		end
	end
end

local function runPorter(shop, worker, owner: Player)
	if worker.busy then
		return
	end
	worker.busy = true
	worker.stranded = false
	task.spawn(function()
		local ok, failure = pcall(porterTrip, shop, worker, owner)
		for _, carried in worker.load or {} do
			if carried.grip then
				carried.grip:Destroy()
			end
			carried.fish:Destroy()
		end
		worker.load = nil
		if worker.grip then
			worker.grip:Destroy()
			worker.grip = nil
		end
		if worker.fish then
			worker.fish:Destroy()
			worker.fish = nil
		end
		worker.busy = false
		-- A pushed/fallen porter cannot climb back through the pier from below.
		-- Retire the stranded rig; ensureStaff replaces it at its normal spawn.
		-- Fish stay in the hold until the complete delivery transaction succeeds.
		if worker.stranded and worker.active and shop.staff.Porter == worker and ownerOf(shop.base) == owner then
			worker.active = false
			worker.model:Destroy()
			shop.staff.Porter = nil
		end
		if worker.active and worker.model.Parent then
			bubble(worker, "Porter · Waiting for docked cargo / shelf space")
		end
		if not ok then
			warn("[Staff] Porter: " .. tostring(failure))
		end
	end)
end

local function ensureStaff(shop, owner: Player, role: string)
	local worker = shop.staff[role]
	if worker and worker.model.Parent and worker.humanoid.Health > 0 then
		return worker
	end
	if worker then
		worker.active = false
		worker.model:Destroy()
		shop.staff[role] = nil
	end
	if shop.spawning[role] then
		return nil
	end
	shop.spawning[role] = true
	task.spawn(function()
		local model
		local ok, failure = pcall(function()
			local desk = ShopDesk.frame(shop.frame)
			local position = if role == "Seller"
				then (desk * CFrame.new(0, 0, ShopDesk.DEPTH / 2 + 1.4)).Position
				else (shop.frame * CFrame.new(-10, 0.16, 10)).Position
			model = spawnCustomer(position, role)
			if ownerOf(shop.base) ~= owner then
				model:Destroy()
				return
			end
			model.Name = role
			model:SetAttribute("OwnerUserId", owner.UserId)
			model:SetAttribute("StaffRole", role)
			local member = {
				model = model,
				active = true,
				humanoid = model:FindFirstChildOfClass("Humanoid"),
				root = model:FindFirstChild("HumanoidRootPart"),
			}
			shop.staff[role] = member
			bubble(member, role .. " · Ready to work")
			if role == "Seller" then
				face(member, desk.Position)
			end
		end)
		shop.spawning[role] = nil
		if not ok then
			if model then
				model:Destroy()
			end
			warn("[Staff] Spawn: " .. tostring(failure))
		end
	end)
	return nil
end

local function stock(player: Player, shop, prompt: ProximityPrompt)
	local position = (prompt.Parent :: BasePart).Position
	-- Leeway for walking while the prompt's hold completes.
	local reach = prompt.MaxActivationDistance + 2
	if stocking[player] or ownerOf(shop.base) ~= player or not near(player, position, reach) then
		return
	end
	local profile = BoatService.getProfile(player)
	if not profile then
		notify(player, "Your tackle box is still loading. Try again in a moment.")
		return
	elseif not CargoService.isCarrying(player, profile.Angler.Hand) then
		notify(
			player,
			"Equip a fish from your hotbar and carry it to the freezer. Pick up boat cargo one fish at a time."
		)
		return
	elseif not AnglerData.canFreeze(profile.Angler, profile.Angler.Hand) then
		notify(
			player,
			if frozenCount(shop, player) < #profile.Angler.Freezer
				then "A customer is still holding a fish from your freezer. Sell it to free the spot."
				else "That fish does not fit in the remaining cooler space. Sell some fish or use a storage rack."
		)
		return
	end
	stocking[player] = true
	local moved = 0
	local ok, message = BoatService.updateProgress(player, function(current)
		assert(
			ownerOf(shop.base) == player
				and near(player, position, reach)
				and CargoService.isCarrying(player, current.Angler.Hand),
			"Carry a fish to your freezer first."
		)
		current.Angler, moved = AnglerData.stockFreezer(current.Angler)
	end)
	stocking[player] = nil
	if ok then
		notify(
			player,
			if moved == 1
				then "Placed one fish in the freezer."
				else "That fish does not fit in the remaining cooler space. Sell some fish first."
		)
		update:FireClient(player, "Stocked")
		refreshDisplay(shop)
	else
		notify(player, message)
	end
end

-- Supermarket path: take a fish back out of the freezer to cook it. Fish a
-- customer has already chosen stay put.
local function takeFrozenFish(player: Player, shop, prompt: ProximityPrompt)
	local position = (prompt.Parent :: BasePart).Position
	local reach = prompt.MaxActivationDistance + 2
	if stocking[player] or ownerOf(shop.base) ~= player or not near(player, position, reach) then
		return
	end
	local profile = BoatService.getProfile(player)
	if not profile then
		notify(player, "Your tackle box is still loading. Try again in a moment.")
		return
	elseif not Paths.unlocked(profile, "Supermarket") then
		notify(player, "Taking fish out to cook unlocks with the Supermarket path.")
		return
	elseif profile.Angler.Hand then
		notify(player, "Your hands are already full.")
		return
	end
	local claimed = {}
	for _, customer in shop.customers do
		if not customer.food then
			local key = recordKey(customer.record)
			claimed[key] = (claimed[key] or 0) + 1
		end
	end
	local choice
	for index = #profile.Angler.Freezer, 1, -1 do
		local record = profile.Angler.Freezer[index]
		local key = recordKey(record)
		if (claimed[key] or 0) > 0 then
			claimed[key] -= 1
		else
			choice = record
			break
		end
	end
	if not choice then
		notify(
			player,
			if #profile.Angler.Freezer == 0
				then "Your freezers are empty."
				else "Every fish in your freezer is promised to a customer."
		)
		return
	end
	stocking[player] = true
	local ok, message = BoatService.updateProgress(player, function(current)
		assert(ownerOf(shop.base) == player and near(player, position, reach), "Stand at your freezer.")
		local data, failure = AnglerData.takeFrozen(current.Angler, choice)
		assert(data, failure)
		current.Angler = data
	end)
	stocking[player] = nil
	if ok then
		notify(player, "Took a " .. describeFish(choice) .. " from the freezer. Carry it to a kitchen station.")
		refreshDisplay(shop)
	else
		notify(player, message)
	end
end

local function arrive(shop)
	local owner = ownerOf(shop.base)
	local profile = owner and BoatService.getProfile(owner)
	if not profile or (#profile.Angler.Freezer == 0 and #profile.Angler.Pantry == 0) then
		return
	end
	-- One customer per register, each at a counter nobody else is using.
	local registers = fixtureFrames(shop, profile, "Register", ShopDesk.frame(shop.frame))
	local busyRegisters, claimed = {}, {}
	for _, other in shop.customers do
		busyRegisters[other.registerKey] = true
		local key = if other.food then "food " .. dishKey(other.record) else recordKey(other.record)
		claimed[key] = (claimed[key] or 0) + 1
	end
	local register
	for _, frame in registers do
		if not busyRegisters[tostring(frame.Position)] then
			register = frame
			break
		end
	end
	if not register then
		return
	end
	-- Only choose fish that actually fit on the ice, have a displayed model and
	-- aren't already wanted by another customer.
	local choices, seen = {}, {}
	for _, list in { shop.displayFish or {}, shop.displayFood or {} } do
		for _, item in list do
			local key = if item.food then "food " .. dishKey(item.record) else recordKey(item.record)
			seen[key] = (seen[key] or 0) + 1
			if seen[key] > (claimed[key] or 0) then
				table.insert(choices, item)
			end
		end
	end
	if #choices == 0 then
		return
	end
	local choice = choices[random:NextInteger(1, #choices)]
	local customer = {
		shop = shop,
		record = choice.record,
		freezer = choice.freezer,
		food = choice.food,
		register = register,
		registerKey = tostring(register.Position),
		active = true,
	}
	table.insert(shop.customers, customer)
	-- Keep the same arrival interval even when several registers are available.
	shop.nextArrival = os.clock() + ARRIVAL_SECONDS
	task.spawn(function()
		local ok, failure = pcall(visit, shop, customer)
		if not ok then
			warn("[Customers] " .. tostring(failure))
		end
		finish(shop, customer)
	end)
end

local function registerShop(base: Model)
	if shops[base] then
		return
	end
	local frame = houseFrame(base)
	local house = base:FindFirstChild("BaseHouse")
	local shopModel = house and house:FindFirstChild("Shop")
	if not frame or not shopModel then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Name = "FreezerPromptAnchor"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency, anchor.Anchored = 1, true
	anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = false, false, false
	anchor.CFrame = FishFreezer.frame(frame) * CFrame.new(0, FishFreezer.HEIGHT * 0.7, FishFreezer.DEPTH / 2)
	anchor.Parent = shopModel
	local shop = {
		base = base,
		frame = frame,
		staff = {},
		spawning = {},
		customers = {},
		nextArrival = os.clock() + ARRIVAL_SECONDS,
	}
	shop.freezerPrompt = ownerPrompt(anchor, "StockFreezerPrompt", "Place fish", "Freezer")
	shop.freezerPrompt.MaxActivationDistance = 5
	local take = ownerPrompt(anchor, "TakeFrozenFishPrompt", "Take fish", "Freezer")
	take.MaxActivationDistance = 5
	take.KeyboardKeyCode, take.GamepadKeyCode = Enum.KeyCode.F, Enum.KeyCode.ButtonY
	take:SetAttribute("Available", false)
	shops[base] = shop
	local function owned()
		removeStaff(shop)
		local userId = base:GetAttribute("OwnerUserId")
		shop.freezerPrompt:SetAttribute("OwnerUserId", userId)
		take:SetAttribute("OwnerUserId", userId)
		for _, customer in shop.customers do
			if customer.prompt then
				customer.prompt:SetAttribute("OwnerUserId", userId)
			end
			-- A new or departed owner never inherits the previous customers.
			leave(customer)
		end
		shop.nextArrival = os.clock() + ARRIVAL_SECONDS
	end
	base:GetAttributeChangedSignal("OwnerUserId"):Connect(owned)
	shop.freezerPrompt:SetAttribute("OwnerUserId", base:GetAttribute("OwnerUserId"))
	take:SetAttribute("OwnerUserId", base:GetAttribute("OwnerUserId"))
end

-- Lets the Company path's fisherman boat be unloaded by the porter.
function CustomerService.useCompanyDock(report: (any, Player) -> (string?, Model?))
	companyDock = report
end

-- Shared NPC helpers for the restaurant's diners and the hired fisherman.
CustomerService.npc = {
	spawn = function(position: Vector3, staffRole: string?): Model
		return spawnCustomer(position, staffRole)
	end,
	walk = walk,
	face = face,
	bubble = bubble,
	carry = carry,
	notify = notify,
	ownerOf = ownerOf,
	houseFrame = houseFrame,
	near = near,
	ownerPrompt = ownerPrompt,
	dishModel = dishModel,
	setAnchored = setAnchored,
}

function CustomerService.start()
	if started then
		return
	end
	started = true
	local remotes = Instance.new("Folder")
	remotes.Name = "ShopCustomers"
	update = Instance.new("RemoteEvent")
	update.Name, update.Parent = "Update", remotes
	remotes.Parent = ReplicatedStorage
	folder = Instance.new("Folder")
	folder.Name = "ShopCustomers"
	folder.Parent = workspace

	for _, base in CollectionService:GetTagged(BASE_TAG) do
		registerShop(base)
	end
	CollectionService:GetInstanceAddedSignal(BASE_TAG):Connect(registerShop)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name == "SellToCustomerPrompt" then
			local customer = customers[prompt]
			if customer then
				sell(player, customer)
			end
		elseif prompt.Name == "StockFreezerPrompt" and prompt.Parent and prompt.Parent:IsA("BasePart") then
			-- The built-in freezer and every placed one share the same stock.
			for base, shop in shops do
				if prompt:IsDescendantOf(base) then
					task.spawn(stock, player, shop, prompt)
				end
			end
		elseif prompt.Name == "TakeFrozenFishPrompt" and prompt.Parent and prompt.Parent:IsA("BasePart") then
			for base, shop in shops do
				if prompt:IsDescendantOf(base) then
					task.spawn(takeFrozenFish, player, shop, prompt)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		stocking[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, shop in shops do
				local owner = ownerOf(shop.base)
				local profile = owner and BoatService.getProfile(owner)
				if profile then
					for _, role in { "Seller", "Porter" } do
						if profile.Angler.Staff[role] then
							local worker = ensureStaff(shop, owner, role)
							if worker and role == "Porter" then
								local speed = StaffCatalog.porterStats(profile.Angler)
								worker.humanoid.WalkSpeed = speed
								runPorter(shop, worker, owner)
							elseif worker then
								for _, customer in shop.customers do
									-- Share the manual sale's lock and atomic wallet update.
									if customer.prompt and not customer.leaving and not customer.autoServing then
										customer.autoServing = true
										task.spawn(function()
											sell(owner, customer, worker)
											customer.autoServing = false
										end)
									end
								end
							end
						end
					end
				end
				local label = string.format(
					"Freezer · %d fish · %d%% space used",
					frozenCount(shop, owner),
					if profile then AnglerData.freezerUsage(profile.Angler) else 0
				)
				shop.freezerPrompt.ObjectText = label
				local cooking = profile ~= nil and Paths.unlocked(profile, "Supermarket")
				local builtInTake = shop.freezerPrompt.Parent:FindFirstChild("TakeFrozenFishPrompt")
				if builtInTake then
					builtInTake:SetAttribute("Available", cooking)
				end
				local house = shop.base:FindFirstChild("BaseHouse")
				local placed = house and house:FindFirstChild("Furniture")
				for _, item in if placed then placed:GetChildren() else {} do
					local prompt = item.Name == "Freezer" and item:FindFirstChild("StockFreezerPrompt", true)
					if prompt then
						prompt.ObjectText = label
					end
					local take = item.Name == "Freezer" and item:FindFirstChild("TakeFrozenFishPrompt", true)
					if take then
						take:SetAttribute("Available", cooking)
					end
				end
				refreshShelves(shop)
				if owner and os.clock() >= shop.nextArrival then
					arrive(shop)
				end
			end
		end
	end)
end

return CustomerService
