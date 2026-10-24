-- Shop customers. Owners stock cooler fish into their base freezer; a customer
-- wearing a random Roblox avatar walks in, takes one frozen fish to the register
-- and waits until the owner serves them. The sale is a single profile update,
-- so a fish can never be sold twice or paid for without leaving the freezer.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnglerData = require(script.Parent.AnglerData)
local BoatService = require(script.Parent.BoatService)
local FishFreezer = require(script.Parent.Map.FishFreezer)
local ShopDesk = require(script.Parent.Map.ShopDesk)
local Catalog = require(ReplicatedStorage.Shared.AnglerCatalog)
local FishCatch = require(ReplicatedStorage.Shared.FishCatch)
local FishModels = require(ReplicatedStorage.Shared.FishModels)
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))

local CustomerService = {}
local BASE_TAG = "PlayerBase"
local OWNER_PROMPT_TAG = "ShopOwnerPrompt"
local WALK_SPEED = 9
local WAIT_SECONDS = 150
local ARRIVAL_SECONDS = Vector2.new(6, 16)
local SERVE_DISTANCE = 14
local CARRY_LENGTH = 1.8
local DISPLAY_LENGTH = 1.2
local DISPLAY_LIMIT = 24
-- Freezer-local Z of each display row's centre, front row first.
local DISPLAY_ROWS = { 0.75, -0.85 }
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

local function frozenCount(owner: Player?): number
	local profile = owner and BoatService.getProfile(owner)
	return if profile then #profile.Angler.Freezer else 0
end

local function describeFish(record): string
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

local function spawnCustomer(position: Vector3): Model
	local model = Players:CreateHumanoidModelFromDescription(randomAvatar(), Enum.HumanoidRigType.R15)
	model.Name = "Customer"
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = WALK_SPEED
	humanoid.BreakJointsOnDeath = false
	model:PivotTo(CFrame.new(position + Vector3.new(0, model:GetExtentsSize().Y / 2, 0)))
	model.Parent = folder
	-- Server-owned so a nearby player's client never takes over the walk.
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	pcall(root.SetNetworkOwner, root, nil)
	animate(humanoid)
	return model
end

-- Returns the fish scaled so its longest side is `length`, plus its scaled size
-- in fish axes (snout +X, back +Y). Welded fish can be carried; others stay anchored.
local function fishModel(record, length: number, welded: boolean): (Model?, Vector3)
	local model = FishModels.create(record.FishId)
	if not model then
		return nil, Vector3.zero
	end
	local size = model:GetAttribute("BoundsSize") :: Vector3
	local scale = length / math.max(size.X, size.Y, size.Z, 0.1)
	model:ScaleTo(scale)
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
	return model, size * scale
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

local function recordKey(record): string
	return string.format("%s:%s:%s:%s", record.FishId, record.Kg, record.CaughtAt, record.Value)
end

-- The owner's frozen fish on the ice bed, oldest first, in two rows. The fish a
-- customer has taken is left out until it is sold or put back.
local function refreshDisplay(shop)
	local owner = ownerOf(shop.base)
	local profile = owner and BoatService.getProfile(owner)
	local frozen = if profile then profile.Angler.Freezer else {}
	local customer = shop.customer
	local taken = if customer and customer.taken then recordKey(customer.record) else ""
	local keys = { tostring(owner and owner.UserId), taken }
	for index = 1, math.min(#frozen, DISPLAY_LIMIT) do
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
	local frame = FishFreezer.frame(shop.frame)
	local left, right = FishFreezer.ICE_X.X + 0.15, FishFreezer.ICE_X.Y - 0.15
	local row, x = 1, left
	shop.shown = 0
	for index = 1, math.min(#frozen, DISPLAY_LIMIT) do
		local record = frozen[index]
		local fish, size = fishModel(record, DISPLAY_LENGTH, false)
		if not fish then
			continue
		end
		-- Flatfish and rays lie flat; everything else lies on its side.
		local flat = size.Z > size.Y
		local footprint = if flat then size.Z else size.Y
		if x + footprint > right then
			row, x = row + 1, left
			if row > #DISPLAY_ROWS then
				fish:Destroy()
				break
			end
		end
		local center = x + footprint / 2
		x += footprint + 0.08
		shop.shown = index
		if recordKey(record) == taken then
			fish:Destroy()
			continue
		end
		-- Snout towards the back, with a slight deterministic splay.
		local splay = ((index % 3) - 1) * 0.12
		local turn = CFrame.Angles(0, math.pi / 2 + splay, 0)
			* (if flat then CFrame.identity else CFrame.Angles(math.pi / 2, 0, 0))
		restOn(fish, FishFreezer.iceSurface(frame, center, DISPLAY_ROWS[row]), turn)
		fish.Parent = display
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

local function carry(customer, fish: Model)
	local hand = customer.model:FindFirstChild("RightHand") :: BasePart?
	if not hand then
		return
	end
	setAnchored(fish, false)
	-- Held by the middle just in front of the hand, snout forward.
	fish:PivotTo(hand.CFrame * CFrame.new(0, -0.3, -0.5) * CFrame.Angles(0, math.pi / 2, 0))
	fish.Parent = customer.model
	local grip = Instance.new("WeldConstraint")
	grip.Name, grip.Part0, grip.Part1, grip.Parent = "FishGrip", hand, fish.PrimaryPart, hand
	customer.grip = grip
end

local function putOnCounter(customer, fish: Model, frame: CFrame)
	if customer.grip then
		customer.grip:Destroy()
		customer.grip = nil
	end
	-- Lying on its side along the counter edge, resting on the desk top.
	setAnchored(fish, true)
	restOn(fish, frame, CFrame.Angles(math.pi / 2, 0, 0))
	fish.Parent = folder
end

-- MoveTo gives up after 8 seconds; a pushed or blocked customer is placed at the
-- waypoint so a shop can never be held up by a stuck NPC.
local function walk(customer, target: Vector3): boolean
	local humanoid = customer.humanoid
	if not customer.active or humanoid.Health <= 0 then
		return false
	end
	humanoid:MoveTo(target)
	local reached = humanoid.MoveToFinished:Wait()
	if not customer.active then
		return false
	end
	local root = customer.root
	local flat = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
	if not reached and flat.Magnitude > 2 then
		customer.model:PivotTo(customer.model:GetPivot() + flat)
	end
	return true
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
	if shop.customer == customer then
		shop.customer = nil
		shop.nextArrival = os.clock() + random:NextNumber(ARRIVAL_SECONDS.X, ARRIVAL_SECONDS.Y)
		refreshDisplay(shop)
	end
end

local function visit(shop, customer)
	local base, frame = shop.base, shop.frame
	local function at(x: number, z: number): Vector3
		return (frame * CFrame.new(x, 0.16, z)).Position
	end
	local freezerFrame = FishFreezer.frame(frame)
	local deskFrame = ShopDesk.frame(frame)
	local freezerSpot = (freezerFrame * CFrame.new(0, 0, FishFreezer.DEPTH / 2 + 1.6)).Position
	local counterSpot = (deskFrame * CFrame.new(0.15 * ShopDesk.WIDTH, 0, -ShopDesk.DEPTH / 2 - 1.4)).Position
	local counterTop = deskFrame * CFrame.new(0.2 * ShopDesk.WIDTH, ShopDesk.HEIGHT, -ShopDesk.DEPTH / 4)

	-- Arrive from the street outside the front door when there is ground there.
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = { folder }
	local street = at(0, 24)
	local hit = workspace:Raycast(street + Vector3.new(0, 10, 0), Vector3.new(0, -20, 0), parameters)
	local entry = if hit then hit.Position else at(0, 18.6)

	customer.model = spawnCustomer(entry)
	customer.humanoid = customer.model:FindFirstChildOfClass("Humanoid")
	customer.root = customer.model:FindFirstChild("HumanoidRootPart")
	local name = describeFish(customer.record)
	bubble(customer, "Looking for fish…")
	customer.humanoid.Died:Once(function()
		customer.active = false
	end)

	-- Each step stops early if the owner leaves or the customer is dismissed.
	local function shopping(): boolean
		local function going(target: Vector3): boolean
			return not customer.leaving and walk(customer, target) and not customer.leaving
		end
		if not (going(at(0, 18.6)) and going(at(0, 11)) and going(freezerSpot)) then
			return false
		end
		face(customer, freezerFrame.Position)
		task.wait(1.2)
		local fish = fishModel(customer.record, CARRY_LENGTH, true)
		if not customer.active or customer.leaving or not fish then
			return false
		end
		-- Lift it off the ice: the display copy disappears as the carried one appears.
		customer.taken = true
		refreshDisplay(shop)
		carry(customer, fish)
		customer.fish = fish
		bubble(customer, "I'd like this " .. name)
		if not (going(at(0, 9)) and going(counterSpot)) then
			return false
		end
		face(customer, deskFrame.Position)
		task.wait(0.5)
		if not customer.active or customer.leaving then
			return false
		end
		putOnCounter(customer, fish, counterTop)
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
		refreshDisplay(shop)
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

local function sell(player: Player, customer)
	local shop = customer.shop
	if
		customer.leaving
		or customer.selling
		or ownerOf(shop.base) ~= player
		or not near(player, customer.root.Position, SERVE_DISTANCE)
	then
		return
	end
	customer.selling = true
	local price = 0
	local ok, message = BoatService.updateProgress(player, function(profile)
		local data, paid = AnglerData.sellFrozen(profile.Angler, customer.record)
		assert(data, "That fish is no longer in your freezer.")
		profile.Angler = data
		profile.Cash += paid
		price = paid
	end)
	customer.selling = false
	if ok then
		customer.sold = true
		refreshDisplay(shop)
		leave(customer)
		notify(player, string.format("Sold %s for $%d.", describeFish(customer.record), price))
		return
	end
	local profile = BoatService.getProfile(player)
	if profile and not AnglerData.sellFrozen(profile.Angler, customer.record) then
		-- The fish is gone (sold elsewhere or a stale session); the customer gives up.
		leave(customer)
		notify(player, "That fish is no longer in your freezer.")
	else
		notify(player, message)
	end
end

local function stock(player: Player, shop)
	if stocking[player] or ownerOf(shop.base) ~= player or not near(player, shop.freezerPrompt.Parent.Position, 14) then
		return
	end
	local profile = BoatService.getProfile(player)
	if not profile then
		notify(player, "Your tackle box is still loading. Try again in a moment.")
		return
	elseif #profile.Angler.Cooler == 0 then
		notify(player, "Your cooler is empty. Catch some fish to stock the freezer.")
		return
	elseif #profile.Angler.Freezer >= AnglerData.FREEZER_CAPACITY then
		notify(player, "Your freezer is full. Sell some fish first.")
		return
	end
	stocking[player] = true
	local moved = 0
	local ok, message = BoatService.updateProgress(player, function(current)
		current.Angler, moved = AnglerData.stockFreezer(current.Angler)
	end)
	stocking[player] = nil
	if ok then
		local left = #(BoatService.getProfile(player) or profile).Angler.Cooler
		notify(
			player,
			string.format("Put %d fish in the freezer.", moved)
				.. (if left > 0 then string.format(" The freezer is full; %d stay in your cooler.", left) else "")
		)
		update:FireClient(player, "Stocked")
		refreshDisplay(shop)
	else
		notify(player, message)
	end
end

local function arrive(shop)
	local owner = ownerOf(shop.base)
	local profile = owner and BoatService.getProfile(owner)
	if not profile or #profile.Angler.Freezer == 0 then
		return
	end
	-- Choose from the fish on show so the customer visibly takes one off the ice.
	local choices = if shop.shown and shop.shown > 0 then shop.shown else #profile.Angler.Freezer
	local record = profile.Angler.Freezer[random:NextInteger(1, math.min(choices, #profile.Angler.Freezer))]
	local customer = { shop = shop, record = record, active = true }
	shop.customer = customer
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
	local shop = { base = base, frame = frame, nextArrival = os.clock() + random:NextNumber(3, 8) }
	shop.freezerPrompt = ownerPrompt(anchor, "StockFreezerPrompt", "Stock fish", "Freezer")
	shops[base] = shop
	local function owned()
		local userId = base:GetAttribute("OwnerUserId")
		shop.freezerPrompt:SetAttribute("OwnerUserId", userId)
		if shop.customer then
			if shop.customer.prompt then
				shop.customer.prompt:SetAttribute("OwnerUserId", userId)
			end
			-- A new or departed owner never inherits the previous customer.
			leave(shop.customer)
		end
		shop.nextArrival = os.clock() + random:NextNumber(4, 10)
	end
	base:GetAttributeChangedSignal("OwnerUserId"):Connect(owned)
	shop.freezerPrompt:SetAttribute("OwnerUserId", base:GetAttribute("OwnerUserId"))
end

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
		elseif prompt.Name == "StockFreezerPrompt" then
			for _, shop in shops do
				if shop.freezerPrompt == prompt then
					task.spawn(stock, player, shop)
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
				shop.freezerPrompt.ObjectText =
					string.format("Freezer · %d/%d fish", frozenCount(owner), AnglerData.FREEZER_CAPACITY)
				refreshDisplay(shop)
				if owner and not shop.customer and os.clock() >= shop.nextArrival then
					arrive(shop)
				end
			end
		end
	end)
end

return CustomerService
