-- The teal trawler's purchased stern net. Owns the visible gear welded behind the
-- transom, the helm toggle in ReplicatedStorage.TrawlerNet, and the passive catch
-- loop that only runs while the hull is moving. BoatRefitService calls dress()
-- whenever a hull is launched or refitted, and stows the net before a lift.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AnglerData = require(script.Parent.AnglerData)
local BoatService = require(script.Parent.BoatService)
local Aboard = require(ReplicatedStorage.Shared.Aboard)
local AnglerCatalog = require(ReplicatedStorage.Shared.AnglerCatalog)
local BoatCatalog = require(ReplicatedStorage.Shared.BoatCatalog)
local BoatUpgrades = require(ReplicatedStorage.Shared.BoatUpgrades)
local TrawlerNet = require(ReplicatedStorage.Shared.TrawlerNet)
local Weather = require(ReplicatedStorage.Shared.Weather)

local TrawlerNetService = {}
local started = false
local remote: RemoteEvent
local random = Random.new()
local toggledAt = {}
local netTweens = setmetatable({}, { __mode = "k" })
local DEPLOY_SECONDS = 3
local NET_COLOR = Color3.fromRGB(69, 112, 83)
local NET_DARK = Color3.fromRGB(43, 88, 64)
local ROPE_COLOR = Color3.fromRGB(183, 161, 115)
local FLOAT_COLOR = Color3.fromRGB(220, 113, 48)
local STRANDS = 12
local SECTIONS = 5
local RADII = { 2.8, 2.25, 1.75, 1.3, 0.85 }

-- The pivot follows the hull. Its attachments form the knots in the mesh, so
-- individual net strands stretch as the bag opens without moving the hull.
local function buildNet(folder: Folder, root: BasePart)
	local pivot = Instance.new("Part")
	pivot.Name = "NetPivot"
	pivot.Size = Vector3.new(0.2, 0.2, 0.2)
	pivot.CFrame = root.CFrame
	pivot.Transparency = 1
	pivot.Anchored, pivot.Massless = false, true
	pivot.CanCollide, pivot.CanTouch, pivot.CanQuery = false, false, false
	pivot.Parent = folder
	local motor = Instance.new("Motor6D")
	motor.Name = "NetMotor"
	motor.Part0, motor.Part1 = root, pivot
	motor.C0 = CFrame.identity
	motor.Parent = pivot

	local nodes = {}
	for section = 1, SECTIONS do
		nodes[section] = {}
		for index = 1, STRANDS do
			local knot = Instance.new("Attachment")
			knot.Name = "NetKnot"
			knot.Parent = pivot
			nodes[section][index] = knot
		end
	end
	local codTie = Instance.new("Attachment")
	codTie.Name = "NetCodTie"
	codTie.Parent = pivot
	local function line(name: string, a: Attachment, b: Attachment, width: number, color: Color3)
		local strand = Instance.new("Beam")
		strand.Name = name
		strand.Attachment0, strand.Attachment1 = a, b
		strand.Width0, strand.Width1 = width, width
		strand.Color = ColorSequence.new(color)
		strand.FaceCamera = true
		strand.Segments = 1
		strand.Parent = folder
	end
	for section = 1, SECTIONS do
		for index = 1, STRANDS do
			local nextIndex = index % STRANDS + 1
			line(
				"NetRing",
				nodes[section][index],
				nodes[section][nextIndex],
				if section == 1 then 0.14 else 0.065,
				NET_COLOR
			)
			if section < SECTIONS then
				local color = if section % 2 == 0 then NET_DARK else NET_COLOR
				line("NetStrand", nodes[section][index], nodes[section + 1][index], 0.055, color)
				line("NetLacing", nodes[section][index], nodes[section + 1][nextIndex], 0.045, color)
				line("NetLacing", nodes[section][nextIndex], nodes[section + 1][index], 0.045, color)
			end
		end
	end
	-- Gather the last ring into a tied cod end, rather than leaving a tube open.
	for index = 1, STRANDS do
		line("NetCodEnd", nodes[SECTIONS][index], codTie, 0.07, NET_DARK)
	end

	-- Two hoist lines run from the actual A-frame sheaves to opposite sides of
	-- the mouth. They stay attached to the same moving knots throughout travel.
	for _, side in { -1, 1 } do
		local top = Instance.new("Attachment")
		top.Name = "NetGantryAttachment"
		top.Position = Vector3.new(side * 3.35, 12.7, 16.3)
		top.Parent = root
		local cleanup = Instance.new("ObjectValue")
		cleanup.Name, cleanup.Value, cleanup.Parent = "GantryAttachment", top, folder
		line("NetHoistRope", top, nodes[1][if side == 1 then 1 else 7], 0.08, ROPE_COLOR)
	end

	-- The floats and sinkers are tied to knots, and move with the mouth. Motors
	-- make them follow the hull without collision or visible rigid crossbars.
	local ornaments = {}
	for _, spec in
		{
			{ 2, true },
			{ 3, true },
			{ 4, true },
			{ 5, true },
			{ 6, true },
			{ 8, false },
			{ 10, false },
			{ 12, false },
		}
	do
		local float = spec[2]
		local piece = Instance.new("Part")
		piece.Name = if float then "NetFloat" else "NetWeight"
		piece.Shape = Enum.PartType.Ball
		piece.Size = if float then Vector3.new(0.48, 0.48, 0.48) else Vector3.new(0.3, 0.3, 0.3)
		piece.Color = if float then FLOAT_COLOR else Color3.fromRGB(75, 76, 70)
		piece.Material = if float then Enum.Material.SmoothPlastic else Enum.Material.Metal
		piece.CFrame = root.CFrame
		piece.Anchored, piece.Massless = false, true
		piece.CanCollide, piece.CanTouch, piece.CanQuery = false, false, false
		piece.Parent = folder
		local joint = Instance.new("Motor6D")
		joint.Part0, joint.Part1 = pivot, piece
		joint.Parent = piece
		table.insert(ornaments, { index = spec[1], motor = joint })
	end

	local progress = Instance.new("NumberValue")
	progress.Name = "NetDeployment"
	progress.Parent = folder
	local function update()
		local t = math.clamp(progress.Value, 0, 1)
		-- Lower the flat, draped net first. The bag opens only in the final
		-- fifth of the travel, once the mouth reaches the waterline.
		local lowering = math.clamp(t / 0.8, 0, 1)
		local opening = math.clamp((t - 0.8) / 0.2, 0, 1)
		opening = opening * opening * (3 - 2 * opening)
		for section = 1, SECTIONS do
			local along = (section - 1) / (SECTIONS - 1)
			local stowed = Vector3.new(0, 9.8 - along * 6.0, 17.3 + along * 2.7)
			local deployed = Vector3.new(0, -2.6 + along * 1.95, 23.6 + along * 10.4)
			local center = stowed:Lerp(deployed, lowering)
			if section == SECTIONS then
				codTie.Position = center + Vector3.new(0, -0.15 * (1 - opening), 0.5)
			end
			for index = 1, STRANDS do
				local angle = (index - 1) * math.pi * 2 / STRANDS
				local radius = RADII[section]
				nodes[section][index].Position = center
					+ Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius * (0.025 + 0.975 * opening), 0)
			end
		end
		for _, ornament in ornaments do
			ornament.motor.C0 = CFrame.new(nodes[1][ornament.index].Position)
		end
	end
	progress.Changed:Connect(update)
	update()
end

function TrawlerNetService.setDeployed(model: Model, deployed: boolean, immediate: boolean?): boolean
	local folder = model:FindFirstChild("FishermansNet")
	local progress = folder and folder:FindFirstChild("NetDeployment")
	if not progress or not progress:IsA("NumberValue") then
		model:SetAttribute("NetDeployed", false)
		return false
	end
	local previous = netTweens[model]
	if previous then
		previous:Cancel()
		netTweens[model] = nil
	end
	model:SetAttribute("NetDeployed", deployed)
	local target = if deployed then 1 else 0
	if immediate then
		progress.Value = target
	else
		-- Preserve the current shape on a reversal and retain a constant speed.
		local duration = DEPLOY_SECONDS * math.abs(target - progress.Value)
		if duration <= 0 then
			progress.Value = target
		else
			local tween =
				TweenService:Create(progress, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Value = target })
			netTweens[model] = tween
			tween:Play()
		end
	end
	return true
end

function TrawlerNetService.stow(model: Model)
	-- The lift and outfit paths need the net safely aboard immediately.
	TrawlerNetService.setDeployed(model, false, true)
end

-- Adds the purchased net to a player's trawler, or removes it when a profile no
-- longer owns one. Called for every launch and refit, so it must be idempotent.
function TrawlerNetService.dress(player: Player, boatId: string, model: Model)
	local profile = BoatService.getProfile(player)
	local owned = boatId == BoatUpgrades.Net.BoatId and profile ~= nil and BoatUpgrades.ownsNet(profile.Angler)
	local existing = model:FindFirstChild("FishermansNet")
	if not owned then
		if existing then
			for _, child in existing:GetChildren() do
				if child:IsA("ObjectValue") and child.Name == "GantryAttachment" and child.Value then
					child.Value:Destroy()
				end
			end
			existing:Destroy()
		end
		model:SetAttribute("NetOwned", false)
		model:SetAttribute("NetDeployed", false)
		return
	end
	model:SetAttribute("NetOwned", true)
	if existing then
		TrawlerNetService.stow(model)
		return
	end
	local root = model.PrimaryPart
	if not root then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "FishermansNet"
	folder.Parent = model
	buildNet(folder, root)
	TrawlerNetService.stow(model)
end

local function catchFish(player: Player, boatId: string, model: Model)
	local profile = BoatService.getProfile(player)
	local layout = BoatCatalog[boatId]
	local root = model.PrimaryPart
	if not profile or not layout or not root then
		return
	end
	local pool = AnglerCatalog.Pools[if Weather.inLake(root.Position) then AnglerCatalog.DefaultPool else "OpenSea"]
	local roll = TrawlerNet.roll(pool, AnglerCatalog.Fish, AnglerCatalog.Rarities, function()
		return random:NextNumber()
	end)
	if not roll then
		return
	end
	local caught = false
	local ok = BoatService.updateProgress(player, function(current)
		local data = AnglerData.netCatch(
			current.Angler,
			boatId,
			layout,
			roll,
			os.time(),
			AnglerCatalog.Fish,
			AnglerCatalog.Mutations
		)
		if data then
			current.Angler = data
			caught = true
		end
	end)
	if ok and caught then
		local fish = AnglerCatalog.Fish[roll.FishId]
		remote:FireClient(player, "Catch", fish.Name, roll.Kg, roll.Value)
	end
end

function TrawlerNetService.start()
	if started then
		return
	end
	started = true
	remote = Instance.new("RemoteEvent")
	remote.Name = "TrawlerNet"
	remote.Parent = ReplicatedStorage
	remote.OnServerEvent:Connect(function(player, action)
		if action ~= "Toggle" then
			return
		end
		local now = os.clock()
		if now - (toggledAt[player] or -math.huge) < 0.3 then
			return
		end
		toggledAt[player] = now
		local boatId, model = BoatService.activeBoat(player)
		local profile = BoatService.getProfile(player)
		if boatId ~= BoatUpgrades.Net.BoatId or not model or not profile then
			return
		elseif not BoatUpgrades.ownsNet(profile.Angler) then
			return
		elseif model:GetAttribute("Hoisted") == true then
			remote:FireClient(player, "Notice", "The net is stowed while your boat is on the lift.")
			return
		elseif not Aboard(player.Character, model) then
			remote:FireClient(player, "Notice", "Climb aboard your trawler to use the net.")
			return
		end
		local deployed = not (model:GetAttribute("NetDeployed") == true)
		TrawlerNetService.setDeployed(model, deployed)
		remote:FireClient(player, "Notice", if deployed then "Fisherman's net deployed." else "Fisherman's net stowed.")
	end)
	Players.PlayerRemoving:Connect(function(player)
		toggledAt[player] = nil
	end)

	-- One low-frequency timer per player; a hull only fishes while it is moving.
	task.spawn(function()
		local nextCatch = {}
		while true do
			task.wait(1)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				local boatId, model = BoatService.activeBoat(player)
				local root = model and model.PrimaryPart
				local velocity = if root then root.AssemblyLinearVelocity else Vector3.zero
				local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
				local fishing = boatId == BoatUpgrades.Net.BoatId
					and root ~= nil
					and model:GetAttribute("NetDeployed") == true
					and model:GetAttribute("Hoisted") ~= true
					and Aboard(player.Character, model)
					and horizontalSpeed >= TrawlerNet.MinSpeed
				if not fishing then
					nextCatch[player] = nil
				else
					local due = nextCatch[player]
					if not due then
						nextCatch[player] = now
							+ TrawlerNet.nextInterval(function()
								return random:NextNumber()
							end)
					elseif now >= due then
						nextCatch[player] = now
							+ TrawlerNet.nextInterval(function()
								return random:NextNumber()
							end)
						catchFish(player, boatId, model)
					end
				end
			end
		end
	end)
end

return TrawlerNetService
