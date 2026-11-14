-- Player cafés in the city (Map/CafePlots). A company with the café branch
-- (Shared.Branches) gets one café plot while any of its members is in the
-- server; members share it. Customers walk in off the avenue, queue at the till
-- and order a coffee. A barista holds the coffee machine's prompt to brew a cup,
-- carries it and hands it to the customer at the front of the queue: the cup's
-- price goes into the company wallet and the barista earns XP.
--
-- Café-only companies spawn at their café (BaseService's spawn provider); a
-- company with both branches keeps spawning at its harbour dock.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AvatarLite = require(ReplicatedStorage.Shared.AvatarLite)
local BaseService = require(script.Parent.BaseService)
local BoatService = require(script.Parent.BoatService)
local Branches = require(ReplicatedStorage.Shared.Branches)
local CafeCatalog = require(ReplicatedStorage.Shared.CafeCatalog)
local CafePlots = require(script.Parent.Map.CafePlots)
local NpcCollision = require(script.Parent.NpcCollision)
local SaveData = require(script.Parent.SaveData)
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))

local CafeService = {}

-- Default R15 animations; NPCs have no Animate script of their own.
local IDLE_ANIMATION = "rbxassetid://507766666"
local WALK_ANIMATION = "rbxassetid://507777826"
local WALK_SPEED = 9
local MAX_USER_ID = 3_000_000_000
local TEMPLATE_POOL = 8
local CUP_NAME = "CafeCoffeeCup"

type Customer = {
	plot: Model,
	model: Model?,
	humanoid: Humanoid?,
	root: BasePart?,
	label: TextLabel?,
	prompt: ProximityPrompt?,
	queued: boolean,
	ordered: boolean,
	served: boolean,
	serving: boolean,
	gone: boolean,
}
type Cafe = {
	plot: Model,
	companyId: string,
	customers: { Customer },
	queue: { Customer },
	nextArrival: number,
}

local started = false
local random = Random.new()
local feedback: RemoteEvent
local npcFolder: Folder
local cafes: { [Model]: Cafe } = {}
local carrying: { [Player]: Instance } = {}
local templates: { Model } = {}
local buildingTemplate = false
local brewing: { [Player]: boolean } = {}
-- Other services (CafeTutorialService) hear about claims, releases, brews and serves.
local listeners: { (string, Player?, Model) -> () } = {}

local function emit(kind: string, player: Player?, plot: Model)
	for _, listener in listeners do
		task.spawn(listener, kind, player, plot)
	end
end

local function notify(player: Player?, message: string)
	if player and player.Parent == Players then
		feedback:FireClient(player, "Notice", message)
	end
end

-- The company a player is playing for, from their committed profile.
local function companyOf(player: Player): (string?, any)
	local profile = BoatService.getProfile(player)
	local info = profile and profile.SaveInfo
	if not info then
		return nil, profile
	end
	return SaveData.id(info.OwnerUserId, info.Slot), profile
end

local function frameOf(plot: Model): CFrame
	return plot:GetAttribute("CafeFrame") :: CFrame
end

local function setBoard(plot: Model, text: string)
	local board = plot:FindFirstChild("NameBoard", true)
	local label = board and board:FindFirstChild("Text", true)
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

local function cafeFor(companyId: string): Cafe?
	for _, cafe in cafes do
		if cafe.companyId == companyId then
			return cafe
		end
	end
	return nil
end

local function members(cafe: Cafe): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("BoatDataStatus") == "Ready" and player:GetAttribute("CompanyId") == cafe.companyId then
			table.insert(list, player)
		end
	end
	return list
end

----------------------------------------------------------------------------------------------------
-- Customers

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

local function randomDescription(): HumanoidDescription
	for _ = 1, 4 do
		local ok, description = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(random:NextInteger(1, MAX_USER_ID))
		end)
		if ok and description then
			return AvatarLite.strip(description)
		end
	end
	return Instance.new("HumanoidDescription")
end

-- Customers reuse a small pool of random real avatars, so a busy café does
-- not fetch a new avatar for every visit.
local function customerModel(): Model
	if #templates < TEMPLATE_POOL and not buildingTemplate then
		buildingTemplate = true
		local description = randomDescription()
		local ok, built = pcall(Players.CreateHumanoidModelFromDescriptionAsync, Players, description, Enum.HumanoidRigType.R15)
		description:Destroy()
		buildingTemplate = false
		if ok and built then
			AvatarLite.stripModel(built)
			built.Archivable = true
			table.insert(templates, built)
			return built:Clone()
		end
	end
	if #templates == 0 then
		local ok, built = pcall(Players.CreateHumanoidModelFromDescriptionAsync, Players, Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
		assert(ok and built, "No customer appearance is available.")
		built.Archivable = true
		table.insert(templates, built)
	end
	return templates[random:NextInteger(1, #templates)]:Clone()
end

local function bubble(customer: Customer, text: string)
	local label = customer.label
	if not label then
		local head = customer.model and customer.model:FindFirstChild("Head")
		if not head then
			return
		end
		local billboard = Instance.new("BillboardGui")
		billboard.Name, billboard.Size = "CafeBubble", UDim2.fromOffset(220, 34)
		billboard.StudsOffset, billboard.MaxDistance = Vector3.new(0, 2.6, 0), 60
		label = Instance.new("TextLabel")
		label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		label.TextSize = 15
		Theme.text(label)
		label.Parent, billboard.Parent = billboard, head
		customer.label = label
	end
	local shown = label :: TextLabel
	shown.Text = text
end

local function removePrompt(customer: Customer)
	if customer.prompt then
		customer.prompt:Destroy()
		customer.prompt = nil
	end
end

local function dequeue(cafe: Cafe, customer: Customer)
	local index = table.find(cafe.queue, customer)
	if index then
		table.remove(cafe.queue, index)
	end
	customer.queued = false
end

local function despawn(cafe: Cafe, customer: Customer)
	customer.gone = true
	removePrompt(customer)
	dequeue(cafe, customer)
	local index = table.find(cafe.customers, customer)
	if index then
		table.remove(cafe.customers, index)
	end
	if customer.model then
		customer.model:Destroy()
		customer.model = nil
	end
end

local function alive(cafe: Cafe, customer: Customer): boolean
	return not customer.gone and cafes[cafe.plot] == cafe and customer.model ~= nil and customer.model.Parent ~= nil
		and customer.humanoid ~= nil and customer.humanoid.Health > 0
end

-- Walks to a café-local point; a customer stuck for `timeout` seconds is moved there.
local function walkTo(cafe: Cafe, customer: Customer, point: Vector3, timeout: number?): boolean
	local target = (frameOf(cafe.plot) * CFrame.new(point)).Position
	local humanoid, root = customer.humanoid :: Humanoid, customer.root :: BasePart
	local deadline = os.clock() + (timeout or 12)
	local issued = os.clock()
	humanoid:MoveTo(target)
	while alive(cafe, customer) do
		local offset = root.Position - target
		if Vector3.new(offset.X, 0, offset.Z).Magnitude < 1.3 then
			return true
		end
		if os.clock() > deadline then
			local lift = humanoid.HipHeight + root.Size.Y / 2
			customer.model:PivotTo(CFrame.new(target + Vector3.new(0, lift, 0)) * root.CFrame.Rotation)
			return true
		end
		-- Humanoid.MoveTo gives up after eight seconds.
		if os.clock() - issued > 6 then
			issued = os.clock()
			humanoid:MoveTo(target)
		end
		task.wait(0.15)
	end
	return false
end

local function faceCounter(cafe: Cafe, customer: Customer)
	local root = customer.root
	if not root then
		return
	end
	local frame = frameOf(cafe.plot)
	local look = (frame * CFrame.new(CafeCatalog.REGISTER_X, 0, CafeCatalog.COUNTER_FRONT - 5)).Position
	look = Vector3.new(look.X, root.Position.Y, look.Z)
	if (look - root.Position).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, look)
	end
end

local serve: (Player, Customer, Cafe) -> ()

local function addServePrompt(cafe: Cafe, customer: Customer)
	if customer.prompt or not customer.root then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ServeCoffee"
	prompt.ActionText = "Serve coffee"
	prompt.ObjectText = "Customer"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt:AddTag(CafeCatalog.PROMPT_TAG)
	prompt.Parent = customer.root
	customer.prompt = prompt
	prompt.Triggered:Connect(function(player)
		serve(player, customer, cafe)
	end)
end

local function leave(cafe: Cafe, customer: Customer)
	removePrompt(customer)
	dequeue(cafe, customer)
	if not alive(cafe, customer) then
		despawn(cafe, customer)
		return
	end
	task.wait(1.2)
	walkTo(cafe, customer, CafeCatalog.DOOR_INSIDE)
	walkTo(cafe, customer, CafeCatalog.DOOR_OUTSIDE)
	walkTo(cafe, customer, if random:NextNumber() < 0.5 then CafeCatalog.STREET_LEFT else CafeCatalog.STREET_RIGHT)
	despawn(cafe, customer)
end

local function visit(cafe: Cafe, customer: Customer)
	local street = if random:NextNumber() < 0.5 then CafeCatalog.STREET_LEFT else CafeCatalog.STREET_RIGHT
	local frame = frameOf(cafe.plot)
	local ok, model = pcall(customerModel)
	if not ok or cafes[cafe.plot] ~= cafe or customer.gone then
		if not ok then
			warn("[Cafe] Customer could not be created: " .. tostring(model))
		end
		despawn(cafe, customer)
		return
	end
	model.Name = "CafeCustomer"
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = WALK_SPEED
	humanoid.BreakJointsOnDeath = false
	NpcCollision.bind(model)
	model.PrimaryPart = root
	local lift = humanoid.HipHeight + root.Size.Y / 2
	model:PivotTo(frame * CFrame.new(street + Vector3.new(0, lift, 0)) * CFrame.Angles(0, math.pi, 0))
	model.Parent = npcFolder
	-- Server-owned so a nearby player's client never takes over the walk.
	pcall(root.SetNetworkOwner, root, nil)
	animate(humanoid)
	customer.model, customer.humanoid, customer.root = model, humanoid, root

	walkTo(cafe, customer, CafeCatalog.DOOR_OUTSIDE)
	walkTo(cafe, customer, CafeCatalog.DOOR_INSIDE)
	if not alive(cafe, customer) then
		despawn(cafe, customer)
		return
	end
	table.insert(cafe.queue, customer)
	customer.queued = true
	local joined = os.clock()
	local spot = 0
	while alive(cafe, customer) and not customer.served do
		local index = table.find(cafe.queue, customer) or #cafe.queue + 1
		if index ~= spot then
			spot = index
			walkTo(cafe, customer, CafeCatalog.queueSpot(index), 10)
			faceCounter(cafe, customer)
		end
		if spot == 1 and not customer.ordered then
			customer.ordered = true
			bubble(customer, "☕ One coffee, please!")
			addServePrompt(cafe, customer)
		end
		local waited = os.clock() - joined
		if not customer.serving and waited > CafeCatalog.PATIENCE then
			bubble(customer, "Too slow… I'm off.")
			break
		elseif customer.ordered and not customer.serving and waited > CafeCatalog.PATIENCE - 20 then
			bubble(customer, "☕ Still waiting for my coffee…")
		end
		task.wait(0.25)
	end
	if alive(cafe, customer) then
		leave(cafe, customer)
	else
		despawn(cafe, customer)
	end
end

local function arrive(cafe: Cafe)
	local customer: Customer = {
		plot = cafe.plot,
		queued = false,
		ordered = false,
		served = false,
		serving = false,
		gone = false,
	}
	table.insert(cafe.customers, customer)
	task.spawn(visit, cafe, customer)
end

----------------------------------------------------------------------------------------------------
-- Coffee

local function dropCup(player: Player)
	local cup = carrying[player]
	carrying[player] = nil
	if cup then
		cup:Destroy()
	end
	if player.Parent == Players then
		player:SetAttribute("CarryingCoffee", false)
	end
end

local function giveCup(player: Player): boolean
	local character = player.Character
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	if not hand or not hand:IsA("BasePart") then
		return false
	end
	local cup = Instance.new("Model")
	cup.Name = CUP_NAME
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
		p.CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 - 0.1, -0.3) * offset
		p.Parent = cup
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = hand, p
		weld.Parent = p
		return p
	end
	piece("Cup", Vector3.new(0.45, 0.6, 0.45), CFrame.new(), Color3.fromRGB(250, 248, 242), Enum.Material.SmoothPlastic)
	piece("Sleeve", Vector3.new(0.48, 0.22, 0.48), CFrame.new(0, -0.02, 0), Color3.fromRGB(150, 104, 70), Enum.Material.Cardboard)
	piece("Lid", Vector3.new(0.5, 0.08, 0.5), CFrame.new(0, 0.33, 0), Color3.fromRGB(60, 46, 40), Enum.Material.SmoothPlastic)
	cup.Parent = character
	carrying[player] = cup
	player:SetAttribute("CarryingCoffee", true)
	return true
end

-- Members of the café's company may work in it.
local function worksAt(player: Player, cafe: Cafe?): boolean
	if not cafe then
		return false
	end
	local companyId = companyOf(player)
	return companyId ~= nil and companyId == cafe.companyId
end

local function near(player: Player, position: Vector3, distance: number): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return humanoid ~= nil and humanoid.Health > 0 and root ~= nil and root:IsA("BasePart")
		and (root.Position - position).Magnitude <= distance
end

local function brew(player: Player, plot: Model, machine: Model)
	local cafe = cafes[plot]
	if not worksAt(player, cafe) then
		notify(player, "This isn't your café.")
		return
	end
	local body = machine.PrimaryPart
	if not body or not near(player, body.Position, 12) then
		return
	end
	if carrying[player] and carrying[player].Parent then
		notify(player, "You're already holding a coffee. Serve it to the customer at the till.")
		return
	end
	if brewing[player] then
		return
	end
	brewing[player] = true
	local vent = machine:FindFirstChild("SteamVent")
	local steam = vent and vent:FindFirstChild("Steam")
	if steam and steam:IsA("ParticleEmitter") then
		steam.Enabled = true
		task.delay(1.6, function()
			steam.Enabled = false
		end)
	end
	if giveCup(player) then
		notify(player, "Coffee's ready! Hand it to the customer at the till.")
		emit("Brew", player, plot)
	end
	brewing[player] = nil
end

serve = function(player: Player, customer: Customer, cafe: Cafe)
	if not worksAt(player, cafe) then
		notify(player, "This isn't your café.")
		return
	end
	if customer.serving or customer.served or not customer.ordered or not alive(cafe, customer) then
		return
	end
	if not (carrying[player] and carrying[player].Parent) then
		notify(player, "Brew a coffee at the coffee machine first (hold the prompt).")
		return
	end
	if not near(player, (customer.root :: BasePart).Position, 14) then
		return
	end
	customer.serving = true
	removePrompt(customer)
	local price, xp = CafeCatalog.COFFEE_PRICE, CafeCatalog.COFFEE_XP
	local ok, message = BoatService.updateProgress(player, function(profile)
		profile.Cash += price
		profile.Angler.Stats.CoinsEarned += price
		profile.Angler.Stats.TotalXP += xp
		-- Keep the rest of the café progress (the tour's fields) alongside the count.
		-- A café's very first coffee starts its progress with the tour still to do (a missing
		-- tour step on an existing table means a café from before the tour: see BoatData).
		local cafeProgress = if type(profile.Cafe) == "table" then profile.Cafe else { TutorialStep = 1, TutorialDone = false }
		cafeProgress.Served = (cafeProgress.Served or 0) + 1
		profile.Cafe = cafeProgress
	end)
	customer.serving = false
	if not ok then
		notify(player, message)
		if alive(cafe, customer) and not customer.served then
			addServePrompt(cafe, customer)
		end
		return
	end
	dropCup(player)
	customer.served = true
	if alive(cafe, customer) then
		bubble(customer, "Thanks! ☕")
	end
	notify(player, string.format("Coffee served! +$%d · +%d XP", price, xp))
	emit("Serve", player, cafe.plot)
end

----------------------------------------------------------------------------------------------------
-- Plots

local function bindMachine(plot: Model)
	local machine = plot:FindFirstChild("CoffeeMachine", true)
	local body = machine and machine:IsA("Model") and machine.PrimaryPart
	if not body or body:FindFirstChild("BrewCoffee") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BrewCoffee"
	prompt.ActionText = "Brew coffee"
	prompt.ObjectText = "Coffee machine"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = CafeCatalog.BREW_SECONDS
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt:AddTag(CafeCatalog.PROMPT_TAG)
	prompt.Parent = body
	prompt.Triggered:Connect(function(player)
		brew(player, plot, machine :: Model)
	end)
end

local function release(cafe: Cafe)
	if cafes[cafe.plot] ~= cafe then
		return
	end
	cafes[cafe.plot] = nil
	for _, customer in table.clone(cafe.customers) do
		despawn(cafe, customer)
	end
	local plot = cafe.plot
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("CompanyId", "")
	plot:SetAttribute("CompanyName", nil)
	setBoard(plot, string.format("CAFÉ · %02d", plot:GetAttribute("PlotId") or 0))
	-- Nobody runs it now: back to a closed shopfront.
	CafePlots.setOpen(plot, false)
	emit("Released", nil, plot)
end

-- The café a player works at, claiming a free plot for their company.
local function claim(player: Player): Model?
	local companyId, profile = companyOf(player)
	if not companyId or not Branches.has(profile, "Cafe") then
		return nil
	end
	local existing = cafeFor(companyId)
	if existing then
		player:SetAttribute("CafePlotId", existing.plot:GetAttribute("PlotId"))
		return existing.plot
	end
	for _, plot in CafePlots.plots() do
		if not cafes[plot] and (plot:GetAttribute("CompanyId") or "") == "" then
			local cafe: Cafe = {
				plot = plot,
				companyId = companyId,
				customers = {},
				queue = {},
				nextArrival = os.clock() + 5,
			}
			cafes[plot] = cafe
			plot:SetAttribute("OwnerUserId", player.UserId)
			plot:SetAttribute("CompanyId", companyId)
			local name = profile.SaveInfo and profile.SaveInfo.Name or (player.DisplayName .. "'s")
			plot:SetAttribute("CompanyName", name)
			-- The café only exists in the city while a company runs it.
			CafePlots.setOpen(plot, true)
			-- Save names were filtered by Roblox when they were saved (SaveService).
			setBoard(plot, string.upper(name) .. " · CAFÉ")
			bindMachine(plot)
			player:SetAttribute("CafePlotId", plot:GetAttribute("PlotId"))
			emit("Claimed", player, plot)
			return plot
		end
	end
	notify(player, "Every café in the city is taken on this server. Rejoin to find a free one.")
	return nil
end

local function spawnFor(player: Player): SpawnLocation?
	local plot = claim(player)
	local point = plot and plot:FindFirstChild("SpawnPoint")
	return if point and point:IsA("SpawnLocation") then point else nil
end

-- Releases cafés no member is playing in any more.
local function tidy()
	for _, cafe in table.clone(cafes) do
		if #members(cafe) == 0 then
			release(cafe)
		end
	end
end

local function watchPlayer(player: Player)
	local function check()
		if player.Parent ~= Players or player:GetAttribute("BoatDataStatus") ~= "Ready" then
			return
		end
		if player:GetAttribute("BranchCafe") == true then
			local had = player:GetAttribute("CafePlotId")
			local plot = claim(player)
			if plot and not had and player:GetAttribute("BranchFishing") == true then
				notify(player, "Your café is open in the city's café quarter, by the metro station.")
			end
		end
	end
	-- Branch attributes are published right after the save status; let them settle.
	player:GetAttributeChangedSignal("BoatDataStatus"):Connect(function()
		task.defer(check)
	end)
	player:GetAttributeChangedSignal("BranchCafe"):Connect(function()
		task.defer(check)
	end)
	player.CharacterRemoving:Connect(function()
		dropCup(player)
	end)
	task.defer(check)
end

function CafeService.start(root: Instance?)
	if started then
		return
	end
	started = true
	CafePlots.ensure(root or workspace:WaitForChild("Map"))
	npcFolder = Instance.new("Folder")
	npcFolder.Name = "CafeCustomers"
	npcFolder.Parent = workspace

	local folder = Instance.new("Folder")
	folder.Name = "Cafe"
	feedback = Instance.new("RemoteEvent")
	feedback.Name = "Feedback"
	feedback.Parent = folder
	folder.Parent = ReplicatedStorage

	-- Café-only companies have no harbour dock: they spawn in their café.
	BaseService.setSpawnProvider(spawnFor)

	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		dropCup(player)
		brewing[player] = nil
		task.defer(tidy)
	end)

	-- One arrivals loop for every café on the server.
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for _, cafe in table.clone(cafes) do
				if #members(cafe) == 0 then
					release(cafe)
				elseif #cafe.customers < CafeCatalog.MAX_CUSTOMERS and now >= cafe.nextArrival then
					cafe.nextArrival = now + random:NextNumber(CafeCatalog.ARRIVAL_MIN, CafeCatalog.ARRIVAL_MAX)
					arrive(cafe)
				end
			end
		end
	end)
end

-- For other services: `callback(kind, player, plot)` after a café is "Claimed" (by player) or
-- "Released" (player nil), and after a member's "Brew" or "Serve" there.
function CafeService.onEvent(callback: (string, Player?, Model) -> ())
	table.insert(listeners, callback)
end

-- For other services: the café plot a company currently runs on this server.
function CafeService.plotFor(player: Player): Model?
	local companyId = companyOf(player)
	local cafe = companyId and cafeFor(companyId)
	return cafe and cafe.plot
end

return CafeService
