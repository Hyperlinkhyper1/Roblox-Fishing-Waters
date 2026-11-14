-- Physically handling the office PC (Shared.PcModel, Shared.TechCatalog). A player can pick the
-- PC up off their desk (harbour base or company café), carry it to the workbench in their base,
-- unscrew the case, swap any part the company owns, screw it shut and carry it back to a desk,
-- which then shows the new build. A complete PC bought at Micro Harbour is handed over the same
-- way (TechStoreService calls `giveFromShop`).
--
-- The PC in transit is session state, one per player: the save only changes when a PC is put
-- down on a desk (Tech.Equipped = its parts). Dying or leaving drops a carried PC: a desk PC is
-- simply back on its desk, a shop PC can be picked up again for free (its parts are owned).
--
-- Clients (client PcWorkshop) show the prompts from attributes: the player's PcCarry
-- ("Desk"/"Shop") and PcRig ("Carried"/"Bench"), and the workbench model's PcOwner (user id)
-- and PcState ("Closed", "Opening", "Open", "Closing"). The bench PC's AccessPanel carries
-- ClosedPivot/AsidePivot so every client can animate the screws and the panel.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoatService = require(script.Parent.BoatService)
local PcModel = require(ReplicatedStorage.Shared.PcModel)
local TechCatalog = require(ReplicatedStorage.Shared.TechCatalog)

local Service = {}

local BASE_TAG = "PlayerBase"
local CAFE_TAG = "CafePlot"
local REACH = 12
-- How long unscrewing (or screwing shut) takes; clients animate over the same time.
Service.SCREW_SECONDS = 2.4
-- Workbench-local spots: the PC rests on the cutting mat, its panel leans on the tool board.
local BENCH_SPOT = CFrame.new(-0.25, 3.385, 0.3)
local PANEL_SPOT = CFrame.new(1.75, 3.37, -1.12)

type Rig = {
	Parts: { [string]: string },
	Name: string,
	Source: string, -- "Desk" or "Shop"
	Holder: Instance?, -- the base or café whose desk it came from
	Where: string, -- "Carried" or "Bench"
	State: string, -- "Closed", "Opening", "Open", "Closing"
	Model: Model?,
	Bench: Model?,
	Token: number,
}

local rigs: { [Player]: Rig } = {}
local started = false
local notice: RemoteEvent? = nil
local hooks = {
	-- Called after a desk's PC leaves or comes back, and after a save changed Tech.
	changed = function(_player: Player?) end,
}

local function notify(player: Player, message: string)
	if notice and player.Parent == Players then
		notice:FireClient(player, message)
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function near(player: Player, position: Vector3): boolean
	local root = rootOf(player)
	return root ~= nil and (root.Position - position).Magnitude <= REACH
end

-- Bases and cafés whose desk this player may use (same rule as OfficeComputerService).
local function holdersOf(player: Player): { Instance }
	local list = {}
	for _, base in CollectionService:GetTagged(BASE_TAG) do
		if base:GetAttribute("OwnerUserId") == player.UserId and base:IsDescendantOf(workspace) then
			table.insert(list, base)
		end
	end
	local companyId = player:GetAttribute("CompanyId")
	if type(companyId) == "string" and companyId ~= "" then
		for _, plot in CollectionService:GetTagged(CAFE_TAG) do
			if plot:GetAttribute("CompanyId") == companyId and plot:IsDescendantOf(workspace) then
				table.insert(list, plot)
			end
		end
	end
	return list
end

local function deskOf(holder: Instance): (Model?, CFrame?)
	local desk = holder:FindFirstChild("OfficeDesk", true)
	local frame = desk and desk:GetAttribute("DeskFrame")
	if desk and desk:IsA("Model") and typeof(frame) == "CFrame" then
		return desk, frame
	end
	return nil, nil
end

-- The player's own desk they are standing at.
local function deskNear(player: Player): (Model?, Instance?)
	for _, holder in holdersOf(player) do
		local desk, frame = deskOf(holder)
		if desk and frame and near(player, (frame * CFrame.new(0, 2, 1.5)).Position) then
			return desk, holder
		end
	end
	return nil, nil
end

local function benchOf(player: Player): Model?
	for _, base in CollectionService:GetTagged(BASE_TAG) do
		if base:GetAttribute("OwnerUserId") == player.UserId and base:IsDescendantOf(workspace) then
			for _, item in base:GetDescendants() do
				if item.Name == "Workbench" and item:IsA("Model") and typeof(item:GetAttribute("BenchFrame")) == "CFrame" then
					return item
				end
			end
		end
	end
	return nil
end

local function benchFrame(bench: Model): CFrame
	return bench:GetAttribute("BenchFrame") :: CFrame
end

local function setAttributes(player: Player)
	local rig = rigs[player]
	if player.Parent ~= Players then
		return
	end
	player:SetAttribute("PcCarry", if rig and rig.Where == "Carried" then rig.Source else nil)
	player:SetAttribute("PcRig", if rig then rig.Where else nil)
end

local function setBench(bench: Model?, owner: number?, state: string?)
	if bench and bench.Parent then
		bench:SetAttribute("PcOwner", owner)
		bench:SetAttribute("PcState", state)
	end
end

local function clearModel(rig: Rig)
	if rig.Model then
		rig.Model:Destroy()
		rig.Model = nil
	end
end

-- Screwdriver in the right hand while the case is being opened or closed.
local function screwdriver(player: Player, holding: boolean)
	local character = player.Character
	local old = character and character:FindFirstChild("WorkshopScrewdriver")
	if old then
		old:Destroy()
	end
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	if not holding or not hand or not hand:IsA("BasePart") then
		return
	end
	local model = Instance.new("Model")
	model.Name = "WorkshopScrewdriver"
	local grip = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 - 0.05, -0.1)
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = material
		part.CanCollide, part.CanQuery, part.CanTouch, part.Massless = false, false, false, true
		part.CFrame = grip * offset
		part.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = hand, part
		weld.Parent = part
	end
	piece("Grip", Vector3.new(0.2, 0.45, 0.2), CFrame.new(), Color3.fromRGB(196, 48, 36), Enum.Material.SmoothPlastic)
	piece("Ferrule", Vector3.new(0.12, 0.1, 0.12), CFrame.new(0, -0.27, 0), Color3.fromRGB(150, 150, 156), Enum.Material.Metal)
	piece("Shaft", Vector3.new(0.05, 0.5, 0.05), CFrame.new(0, -0.55, 0), Color3.fromRGB(180, 182, 188), Enum.Material.Metal)
	model.Parent = character
end

-- Welds the PC model in front of the player's chest.
local function attachCarry(player: Player, rig: Rig): boolean
	clearModel(rig)
	local root = rootOf(player)
	if not root then
		return false
	end
	local info = PcModel.caseInfo(rig.Parts.Case)
	local offset = if info.Form == "Desktop"
		then CFrame.new(0, -0.35, -0.6 - info.D / 2)
		else CFrame.new(0, -1.15, -0.65 - info.W / 2) * CFrame.Angles(0, math.pi / 2, 0)
	local model = PcModel.build(player.Character :: Model, root.CFrame * offset, rig.Parts, { Name = "CarriedPC" })
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Massless = true
			part.CanCollide = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = root, part
			weld.Parent = part
			part.Anchored = false
		end
	end
	local humanoid = (player.Character :: Model):FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:UnequipTools()
	end
	rig.Model = model
	return true
end

-- (Re)builds the PC on the workbench, its panel on or leaning aside.
local function buildBench(rig: Rig)
	clearModel(rig)
	local bench = rig.Bench
	if not bench then
		return
	end
	local frame = benchFrame(bench)
	local open = rig.State == "Open" or rig.State == "Closing"
	local model = PcModel.build(bench, PcModel.restFrame(rig.Parts.Case, frame * BENCH_SPOT), rig.Parts, {
		Name = "BenchPC",
		Open = open,
		PanelAside = PcModel.asideFrame(rig.Parts.Case, frame * PANEL_SPOT),
		Interior = true,
	})
	rig.Model = model
end

local function drop(player: Player, reason: string?)
	local rig = rigs[player]
	if not rig then
		return
	end
	rigs[player] = nil
	clearModel(rig)
	screwdriver(player, false)
	if rig.Where == "Bench" then
		setBench(rig.Bench, nil, nil)
	end
	setAttributes(player)
	if reason then
		notify(player, if rig.Source == "Shop"
			then rig.Name .. " went back to " .. TechCatalog.STORE_NAME .. ". Pick it up there again for free."
			else "Your PC is back on your desk.")
	end
	hooks.changed(player)
end

----------------------------------------------------------------------------------------------------
-- Actions

local function pickUpDesk(player: Player): (boolean, string)
	if rigs[player] then
		return false, "Your hands are full."
	end
	local desk, holder = deskNear(player)
	if not desk or not holder then
		return false, "Walk up to your own desk first."
	end
	if Service.isAway(holder) or desk:GetAttribute("PcAway") == true then
		return false, "There's no PC on this desk."
	end
	local profile = BoatService.getProfile(player)
	if not profile then
		return false, "Your company is still loading."
	end
	local tech = TechCatalog.decode(profile.Tech)
	local rig: Rig = {
		Parts = TechCatalog.sanitize(tech.Equipped, tech),
		Name = "Your PC",
		Source = "Desk",
		Holder = holder,
		Where = "Carried",
		State = "Closed",
		Token = 0,
	}
	rigs[player] = rig
	if not attachCarry(player, rig) then
		rigs[player] = nil
		return false, "You can't carry that right now."
	end
	setAttributes(player)
	hooks.changed(player)
	return true, "Carry it to the workbench in your base to open it up."
end

local function placeDesk(player: Player): (boolean, string)
	local rig = rigs[player]
	if not rig or rig.Where ~= "Carried" then
		return false, "You aren't carrying a PC."
	end
	local desk, holder = deskNear(player)
	if not desk or not holder then
		return false, "Walk up to your own desk first."
	end
	local parts = rig.Parts
	local ok, message = BoatService.updateProgress(player, function(current)
		local tech = TechCatalog.decode(current.Tech)
		TechCatalog.fit(tech, parts)
		current.Tech = TechCatalog.encode(tech)
	end)
	if not ok then
		return false, message or "Couldn't set the PC down. Try again."
	end
	rigs[player] = nil
	clearModel(rig)
	setAttributes(player)
	hooks.changed(player)
	return true, if rig.Source == "Shop" then rig.Name .. " is set up on your desk!" else "PC set up on your desk."
end

local function placeBench(player: Player): (boolean, string)
	local rig = rigs[player]
	if not rig or rig.Where ~= "Carried" then
		return false, "You aren't carrying a PC."
	end
	local bench = benchOf(player)
	if not bench then
		return false, "Your base has no workbench. Place it from build mode."
	end
	if not near(player, (benchFrame(bench) * CFrame.new(0, 2, 2)).Position) then
		return false, "Walk up to your workbench first."
	end
	rig.Where, rig.State, rig.Bench = "Bench", "Closed", bench
	buildBench(rig)
	setBench(bench, player.UserId, "Closed")
	setAttributes(player)
	return true, "Hold E to unscrew the case."
end

local function rigOnBench(player: Player, state: string?): (Rig?, string?)
	local rig = rigs[player]
	if not rig or rig.Where ~= "Bench" or not rig.Bench then
		return nil, "Put a PC on your workbench first."
	end
	if not near(player, (benchFrame(rig.Bench) * CFrame.new(0, 2, 2)).Position) then
		return nil, "Walk up to your workbench first."
	end
	if rig.State == "Opening" or rig.State == "Closing" then
		return nil, "One moment..."
	end
	if state and rig.State ~= state then
		return nil, if state == "Open" then "Unscrew the case first." else "Screw the case shut first."
	end
	return rig, nil
end

local function screwCase(player: Player, opening: boolean): (boolean, string)
	local rig, problem = rigOnBench(player, if opening then "Closed" else "Open")
	if not rig then
		return false, problem :: string
	end
	rig.Token += 1
	local token = rig.Token
	rig.State = if opening then "Opening" else "Closing"
	setBench(rig.Bench, player.UserId, rig.State)
	screwdriver(player, true)
	task.delay(Service.SCREW_SECONDS, function()
		if rigs[player] ~= rig or rig.Token ~= token then
			return
		end
		screwdriver(player, false)
		rig.State = if opening then "Open" else "Closed"
		buildBench(rig)
		setBench(rig.Bench, player.UserId, rig.State)
	end)
	return true, if opening then "Unscrewing the case..." else "Screwing the case shut..."
end

local function pickUpBench(player: Player): (boolean, string)
	local rig, problem = rigOnBench(player, "Closed")
	if not rig then
		return false, problem :: string
	end
	local bench = rig.Bench
	rig.Where, rig.Bench = "Carried", nil
	if not attachCarry(player, rig) then
		rig.Where, rig.Bench = "Bench", bench
		buildBench(rig)
		return false, "You can't carry that right now."
	end
	setBench(bench, nil, nil)
	setAttributes(player)
	return true, "Carry it back to your desk."
end

local function swap(player: Player, slot: any, id: any): (boolean, string)
	local rig, problem = rigOnBench(player, "Open")
	if not rig then
		return false, problem :: string
	end
	local item = type(id) == "string" and TechCatalog.Items[id]
	if type(slot) ~= "string" or not item or item.Slot ~= slot then
		return false, "Choose a part for that slot."
	end
	local profile = BoatService.getProfile(player)
	if not profile or not TechCatalog.owns(TechCatalog.decode(profile.Tech), id) then
		return false, "Buy " .. item.Name .. " at " .. TechCatalog.STORE_NAME .. " first."
	end
	if rig.Parts[slot] == id then
		return true, item.Name .. " is already fitted."
	end
	rig.Parts[slot] = id
	buildBench(rig)
	return true, item.Name .. " fitted."
end

----------------------------------------------------------------------------------------------------
-- API for TechStoreService

-- Whether the desk in `holder` (a base or café) has its PC away right now.
function Service.isAway(holder: Instance): boolean
	for _, rig in rigs do
		if rig.Source == "Desk" and rig.Holder == holder then
			return true
		end
	end
	return false
end

function Service.canReceive(player: Player): (boolean, string?)
	local rig = rigs[player]
	if not rig then
		return rootOf(player) ~= nil, "You can't carry that right now."
	end
	return false, if rig.Where == "Bench" then "Finish with the PC on your workbench first." else "Your hands are full. Put your PC down first."
end

-- Hands a complete PC from the store to the player.
function Service.giveFromShop(player: Player, parts: { [string]: string }, name: string): boolean
	if rigs[player] then
		return false
	end
	local rig: Rig = {
		Parts = TechCatalog.sanitize(parts),
		Name = name,
		Source = "Shop",
		Where = "Carried",
		State = "Closed",
		Token = 0,
	}
	rigs[player] = rig
	if not attachCarry(player, rig) then
		rigs[player] = nil
		return false
	end
	setAttributes(player)
	return true
end

local function state(player: Player)
	local profile = BoatService.getProfile(player)
	local tech = TechCatalog.decode(profile and profile.Tech)
	local rig = rigs[player]
	return {
		Owned = tech.Owned,
		Cash = profile and profile.Cash or 0,
		Parts = rig and table.clone(rig.Parts),
		Where = rig and rig.Where,
		State = rig and rig.State,
		Name = rig and rig.Name,
	}
end

function Service.start(options: { changed: ((Player?) -> ())? }?)
	if started then
		return
	end
	started = true
	if options and options.changed then
		hooks.changed = options.changed
	end
	local folder = Instance.new("Folder")
	folder.Name = "PcWorkshop"
	local remote = Instance.new("RemoteFunction")
	remote.Name = "Request"
	remote.Parent = folder
	local event = Instance.new("RemoteEvent")
	event.Name = "Notice"
	event.Parent = folder
	notice = event
	folder.Parent = ReplicatedStorage

	local last: { [Player]: number } = {}
	local actions = {
		PickUpDesk = pickUpDesk,
		PlaceDesk = placeDesk,
		PlaceBench = placeBench,
		Open = function(player)
			return screwCase(player, true)
		end,
		Close = function(player)
			return screwCase(player, false)
		end,
		PickUpBench = pickUpBench,
	}
	remote.OnServerInvoke = function(player, action, slot, id)
		if action == "Get" then
			return { Ok = true, State = state(player) }
		end
		if os.clock() - (last[player] or -math.huge) < 0.25 then
			return { Ok = false, Message = "One moment...", State = state(player) }
		end
		last[player] = os.clock()
		local ok, message
		if action == "Swap" then
			ok, message = swap(player, slot, id)
		elseif type(action) == "string" and actions[action] then
			ok, message = actions[action](player)
		else
			ok, message = false, "That action is unavailable."
		end
		return { Ok = ok, Message = message, State = state(player) }
	end

	local function bind(player: Player)
		player.CharacterRemoving:Connect(function()
			local rig = rigs[player]
			if rig and rig.Where == "Carried" then
				drop(player, "died")
			else
				screwdriver(player, false)
			end
		end)
	end
	Players.PlayerAdded:Connect(bind)
	for _, player in Players:GetPlayers() do
		bind(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		drop(player, nil)
		last[player] = nil
	end)

	-- Workbenches are rebuilt when furniture moves: follow the bench, or hand the PC back.
	task.spawn(function()
		while true do
			task.wait(1)
			for player, rig in rigs do
				if rig.Where == "Bench" and not (rig.Bench and rig.Bench:IsDescendantOf(workspace)) then
					local bench = benchOf(player)
					if bench then
						rig.Bench = bench
						if rig.State == "Opening" then
							rig.State = "Open"
						elseif rig.State == "Closing" then
							rig.State = "Closed"
						end
						rig.Token += 1
						buildBench(rig)
						setBench(bench, player.UserId, rig.State)
					else
						drop(player, "bench")
					end
				elseif rig.Where == "Carried" and not (rig.Model and rig.Model.Parent) then
					if not attachCarry(player, rig) then
						drop(player, "lost")
					end
				end
			end
		end
	end)
end

return Service
