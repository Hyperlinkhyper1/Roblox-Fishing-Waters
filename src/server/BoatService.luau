-- Server-owned wallet transactions, dock permissions, and one active boat per player.
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local BoatData = require(script.Parent.BoatData)
local RodSerials = require(script.Parent.RodSerials)
local AdminCommands = require(script.Parent.AdminCommands)
local Rowboat = require(script.Parent.Rowboat)
local FishingBoat = require(script.Parent.FishingBoat)
local Speedboat = require(script.Parent.Speedboat)
local RacingSpeedboat = require(script.Parent.RacingSpeedboat)
local PatrolBoat = require(script.Parent.PatrolBoat)
local Trawler = require(script.Parent.Trawler)
local Tugboat = require(script.Parent.Tugboat)
local Hovercraft = require(script.Parent.Hovercraft)
local DrydockLaunch = require(script.Parent.DrydockLaunch)
local BoatLaunchCollision = require(script.Parent.BoatLaunchCollision)
local BoatCatalog = require(ReplicatedStorage.Shared.BoatCatalog)
local AnglerCatalog = require(ReplicatedStorage.Shared.AnglerCatalog)
local BoatMotion = require(ReplicatedStorage.Shared.BoatMotion)
local RodSkins = require(ReplicatedStorage.Shared.RodSkins)
local SpearSkins = require(ReplicatedStorage.Shared.SpearSkins)
local BobberSkins = require(ReplicatedStorage.Shared.BobberSkins)
local RodUpgrades = require(ReplicatedStorage.Shared.RodUpgrades)
local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Weather = require(ReplicatedStorage.Shared.Weather)
local BoatDrive = require(ReplicatedStorage.Shared.BoatDrive)
local builders = {
	Rowboat = Rowboat,
	FishingBoat = FishingBoat,
	Speedboat = Speedboat,
	PatrolBoat = PatrolBoat,
	RacingSpeedboat = RacingSpeedboat,
	Trawler = Trawler,
	Tugboat = Tugboat,
	Hovercraft = Hovercraft,
}

local BoatService = {}
local profiles = {}
local active = {}
local requests = {}
local spawnTimes = {}
local launching = {}
local launchPurchased
local boatLock: ((Player, string) -> string?)? = nil
local outfitter: ((Player, string, Model) -> any)? = nil
local started = false
local Admin = require(ReplicatedStorage.Shared.Admin)
-- Studio tests use their own store; failed loads never overwrite saved data.
local studioSession = RunService:IsStudio() and game.GameId == 0
local store
if studioSession then
	-- Unpublished places cannot access DataStores. Keep test progress in this
	-- server only; never substitute defaults for a failed published save/load.
	local records = {}
	store = {
		GetAsync = function(_, key)
			return records[key]
		end,
		UpdateAsync = function(_, key, transform)
			local saved = transform(records[key])
			records[key] = saved
			return saved
		end,
	}
else
	local success, result = pcall(function()
		return DataStoreService:GetDataStore(
			if RunService:IsStudio() then "WalletAndBoats_Studio_v1" else "WalletAndBoats_v1"
		)
	end)
	if success then
		store = result
	else
		warn("[Wallet] Could not initialize saved data: " .. tostring(result))
	end
end
local feedback: RemoteEvent

local function notify(player: Player, message: string)
	if player.Parent == Players then
		feedback:FireClient(player, "Notice", message)
	end
end

local function publish(player: Player, state)
	player:SetAttribute("WalletSessionOnly", studioSession)
	player:SetAttribute("BoatDataStatus", state.status)
	player:SetAttribute("Cash", state.profile.Cash)
	for id in BoatCatalog do
		player:SetAttribute("Owns" .. id, state.status == "Ready" and state.profile.OwnedBoats[id] == true)
		player:SetAttribute("BoatLocked" .. id, BoatData.pathLocked(state.profile, id))
	end
	player:SetAttribute("OwnsStarterRod", state.status == "Ready" and state.profile.OwnedRods.StarterRod == true)
	player:SetAttribute("OwnsBasicSpear", state.status == "Ready" and state.profile.OwnedSpears.BasicSpear == true)
	for _, stat in RodUpgrades.Order do
		player:SetAttribute(RodUpgrades.attribute(stat), RodUpgrades.level(state.profile.RodUpgrades, stat))
	end
	for id in RodSkins.Skins do
		player:SetAttribute("RodSkinCount" .. id, state.profile.RodSkins[id] or 0)
	end
	for id in RodSkins.Crates do
		player:SetAttribute("RodCrateCount" .. id, state.profile.RodCrates[id] or 0)
	end
	local spearCounts = {}
	for _, copy in state.profile.SpearSkinCopies do
		spearCounts[copy.SkinId] = (spearCounts[copy.SkinId] or 0) + 1
	end
	for id in SpearSkins.Skins do
		player:SetAttribute("SpearSkinCount" .. id, spearCounts[id] or 0)
	end
	player:SetAttribute("SpearSkin", state.profile.EquippedSpearSkin or "")
	player:SetAttribute("SpearSkinSerial", state.profile.EquippedSpearSkinSerial or 0)
	player:SetAttribute("SpearSkinWear", BoatData.equippedSpearWear(state.profile))
	player:SetAttribute("RodSkinWear", BoatData.equippedRodWear(state.profile))
	player:SetAttribute("RodSkin", state.profile.EquippedRodSkin or "")
	player:SetAttribute("RodSkinSerial", state.profile.EquippedRodSkinSerial or 0)
	for id in BobberSkins.Skins do
		player:SetAttribute("BobberSkinCount" .. id, state.profile.BobberSkins[id] or 0)
	end
	player:SetAttribute("BobberSkin", state.profile.EquippedBobberSkin or "")
	player:SetAttribute("BaitCrates", state.profile.BaitCrates or 0)
	player:SetAttribute("EquippedBait", state.profile.EquippedBait or "")
	player:SetAttribute(
		"BaitCount",
		if state.profile.EquippedBait then (state.profile.Bait or {})[state.profile.EquippedBait] or 0 else 0
	)
	local level, levelXP, requiredXP = BoatData.levelProgress(state.profile)
	player:SetAttribute("Level", level)
	player:SetAttribute("LevelXP", levelXP)
	player:SetAttribute("LevelXPRequired", requiredXP)
	-- Match the bestiary's species list, excluding shark drops which are not pages.
	local bestiaryPercent = nil
	if state.status == "Ready" then
		local discovered, total = 0, 0
		for id, species in AnglerCatalog.Fish do
			if not species.DropOnly then
				total += 1
				local entry = state.profile.Angler.Catches[id]
				if entry and (entry.Count or 0) > 0 then
					discovered += 1
				end
			end
		end
		bestiaryPercent = if total > 0 then math.floor(discovered * 100 / total + 0.5) else 0
	end
	player:SetAttribute("BestiaryPercent", bestiaryPercent)

	-- The built-in player list sorts by its first stat. Keep Level primary and
	-- mirror committed profile values here alongside the gameplay attributes.
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
	end
	local levelStat = leaderstats:FindFirstChild("Level")
	if not levelStat then
		levelStat = Instance.new("IntValue")
		levelStat.Name = "Level"
		local primary = Instance.new("BoolValue")
		primary.Name, primary.Value = "IsPrimary", true
		primary.Parent = levelStat
	end
	levelStat.Value, levelStat.Parent = level, leaderstats
	local moneyStat = leaderstats:FindFirstChild("Money")
	if not moneyStat then
		moneyStat = Instance.new("IntValue")
		moneyStat.Name = "Money"
	end
	moneyStat.Value, moneyStat.Parent = state.profile.Cash, leaderstats
	leaderstats.Parent = player

	player:SetAttribute("AnglerRevision", (player:GetAttribute("AnglerRevision") or 0) + 1)
end

-- Server modules share the existing atomic store and lock; no client can submit a profile.
function BoatService.getProfile(player: Player)
	local state = profiles[player]
	return if state and state.status == "Ready" then BoatData.decode(state.profile) else nil
end

-- decode(nil) is only valid for a first-time load. An absent save result must
-- never replace a loaded player's live inventory with new-player defaults.
local function committedProfile(saved)
	assert(type(saved) == "table", "Save returned no confirmed player profile")
	return BoatData.decode(saved)
end

-- Multiple gameplay actions can arrive during a DataStore yield. Keep them in
-- arrival order so each sees the last committed profile and publishes in order.
local function acquireSave(player: Player, state): boolean
	state.nextSave = (state.nextSave or 0) + 1
	local ticket = state.nextSave
	while profiles[player] == state and player.Parent == Players do
		if not state.busy and ticket == (state.finishedSaves or 0) + 1 then
			state.busy = true
			return true
		end
		task.wait(0.05)
	end
	return false
end

local function releaseSave(state)
	state.finishedSaves = (state.finishedSaves or 0) + 1
	state.busy = false
end

function BoatService.updateProgress(player: Player, transform, rodSkinId: any, spearSkinIds: any): (boolean, string)
	local state = profiles[player]
	if not state or state.status ~= "Ready" then
		return false, "Your progress is still loading or unavailable."
	end
	if not acquireSave(player, state) then
		return false, "This session has ended."
	end
	local awardedAt = os.time()
	local success, saved = pcall(function()
		local serial
		if type(rodSkinId) == "table" then
			serial = {}
			for _, skinId in rodSkinId do
				assert(RodSkins.valid(skinId), "Unknown serial skin")
				table.insert(serial, RodSerials.reserve(store, skinId))
			end
		else
			assert(rodSkinId == nil or RodSkins.valid(rodSkinId), "Unknown serial skin")
			serial = if rodSkinId then RodSerials.reserve(store, rodSkinId) else nil
		end
		if spearSkinIds then
			assert(rodSkinId == nil and type(spearSkinIds) == "table", "Invalid spear serial request")
			serial = {}
			for _, skinId in spearSkinIds do
				assert(SpearSkins.valid(skinId), "Unknown spear serial skin")
				table.insert(serial, RodSerials.reserve(store, "Spear_" .. skinId))
			end
		end
		if profiles[player] ~= state or player.Parent ~= Players then
			error("This session has ended")
		end
		local result = store:UpdateAsync("Player_" .. player.UserId, function(raw)
			local profile = BoatData.decode(raw)
			assert(profile.RodSerialScope == RodSerials.Scope, "Rod serial migration is required")
			local previous = BoatData.decode(profile)
			transform(profile, serial)
			BoatData.trackProgress(previous, profile, awardedAt)
			return BoatData.decode(profile)
		end)
		return committedProfile(result)
	end)
	if not success then
		releaseSave(state)
		warn("[Angler] Save failed for " .. player.UserId .. ": " .. tostring(saved))
		return false, "Your change could not be saved. Please try again."
	end
	if profiles[player] ~= state or player.Parent ~= Players then
		releaseSave(state)
		return false, "This session has ended."
	end
	state.profile = saved
	publish(player, state)
	releaseSave(state)
	return true, "Saved."
end

local function loadPlayer(player: Player)
	if profiles[player] then
		return
	end
	local state = { profile = BoatData.decode(nil), status = "Loading", busy = false }
	profiles[player] = state
	publish(player, state)
	for attempt = 1, 3 do
		local success, result = pcall(function()
			local key = "Player_" .. player.UserId
			local loaded = BoatData.decode(store:GetAsync(key))
			return RodSerials.migrate(store, key, loaded)
		end)
		if profiles[player] ~= state then
			return
		end
		if success then
			state.profile, state.status = result, "Ready"
			publish(player, state)
			return
		end
		warn("[Boats] Could not load player " .. player.UserId .. ": " .. tostring(result))
		if attempt < 3 then
			task.wait(attempt)
		end
	end
	state.status = "Unavailable"
	publish(player, state)
	notify(player, "Boat data could not load. Rejoin to try again.")
end

local function nearPrompt(player: Player, prompt: ProximityPrompt): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local part = prompt.Parent
	return root ~= nil
		and root:IsA("BasePart")
		and humanoid ~= nil
		and humanoid.Health > 0
		and part ~= nil
		and part:IsA("BasePart")
		and (root.Position - part.Position).Magnitude <= prompt.MaxActivationDistance + 2
end

-- Talking and buying require being inside the hall with a clear view of the shipwright.
local function shopPrompt(player: Player): ProximityPrompt?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	for _, shop in CollectionService:GetTagged("BoatShop") do
		if not shop:IsDescendantOf(workspace) then
			continue
		end
		local frame, size = shop:GetAttribute("InteriorFrame"), shop:GetAttribute("InteriorSize")
		if typeof(frame) ~= "CFrame" or typeof(size) ~= "Vector3" then
			continue
		end
		local position = frame:PointToObjectSpace(root.Position)
		if
			math.abs(position.X) > size.X / 2
			or math.abs(position.Y) > size.Y / 2
			or math.abs(position.Z) > size.Z / 2
		then
			continue
		end
		local prompt = shop:FindFirstChild("TalkToShipwrightPrompt", true)
		if not prompt or not prompt:IsA("ProximityPrompt") or not nearPrompt(player, prompt) then
			continue
		end
		local npc = prompt:FindFirstAncestorOfClass("Model")
		if not npc or not npc:FindFirstChildOfClass("Humanoid") then
			continue
		end
		local parameters = RaycastParams.new()
		parameters.FilterType = Enum.RaycastFilterType.Exclude
		parameters.FilterDescendantsInstances = { character }
		local head = character:FindFirstChild("Head")
		local eye = if head and head:IsA("BasePart") then head.Position else root.Position
		local result = workspace:Raycast(eye, prompt.Parent.Position - eye, parameters)
		if not result or result.Instance:IsDescendantOf(npc) then
			return prompt
		end
	end
	return nil
end

local function openShop(player: Player, expectedPrompt: ProximityPrompt?, boatId: string?)
	if launching[player] then
		return
	end
	local prompt = shopPrompt(player)
	if not prompt or (expectedPrompt and prompt ~= expectedPrompt) then
		return
	end
	local shop = prompt:FindFirstAncestorOfClass("Model")
	while shop and not CollectionService:HasTag(shop, "BoatShop") do
		shop = shop:FindFirstAncestorOfClass("Model")
	end
	if shop then
		feedback:FireClient(player, "OpenShop", shop, boatId or "Rowboat")
	end
end

local function readyState(player: Player)
	local state = profiles[player]
	if not state or state.status ~= "Ready" then
		notify(player, "Boat data is unavailable or still loading. Please try again shortly.")
		return nil
	end
	return state
end

-- This handler is server-only; the sender comes from TextChatCommand's TextSource.
function BoatService.setCashFromCommand(player: Player, message: string)
	if not Admin.isAdmin(player) then
		return
	end
	local digits = message:match("^/set%s+cash%s+(%d+)%s*$")
	local amount = digits and tonumber(digits)
	if not amount or amount < 0 or amount >= 2 ^ 53 or amount % 1 ~= 0 then
		notify(player, "Usage: /set cash <amount> (a non-negative whole number below 9007199254740992).")
		return
	end
	local state = readyState(player)
	if not state then
		return
	end
	if not acquireSave(player, state) then
		return
	end
	local success, saved = pcall(function()
		local result = store:UpdateAsync("Player_" .. player.UserId, function(raw)
			local profile = BoatData.decode(raw)
			profile.Cash = amount
			return profile
		end)
		return committedProfile(result)
	end)
	if not success then
		releaseSave(state)
		warn("[Wallet] Set cash failed for " .. player.UserId .. ": " .. tostring(saved))
		notify(player, "Cash could not be saved. Please try again.")
		return
	end
	local valid, profile = pcall(BoatData.decode, saved)
	if not valid or profiles[player] ~= state or player.Parent ~= Players then
		releaseSave(state)
		return
	end
	state.profile = profile
	publish(player, state)
	releaseSave(state)
	notify(player, "Cash set to $" .. tostring(profile.Cash) .. ".")
end

local function setFromCommand(player: Player, message: string)
	if not Admin.isAdmin(player) then
		return
	end
	local normalized = string.lower(message)
	local subject = normalized:match("^/set%s+(%S+)")
	if subject == "weight" then
		local input = normalized:match("^/set%s+weight%s+(%S+)%s*$")
		local cargo = require(script.Parent.CargoService)
		local _, result = cargo.setHeldWeight(player, input and tonumber(input))
		notify(player, result)
		return
	end
	if subject == "season" then
		local Seasons = require(ReplicatedStorage.Shared.Seasons)
		local argument = (normalized:match("^/set%s+season%s+(%a+)%s*$") or ""):lower()
		if argument == "auto" then
			workspace:SetAttribute("SeasonOverride", nil)
			notify(player, "Seasons follow the clock again.")
			return
		end
		for _, season in Seasons.ORDER do
			if string.lower(season) == argument then
				workspace:SetAttribute("SeasonOverride", season)
				notify(player, "Season set to " .. season .. ".")
				return
			end
		end
		notify(player, "Usage: /set season <spring|summer|autumn|winter|auto>.")
		return
	end
	if subject == "date" then
		local Calendar = require(ReplicatedStorage.Shared.Calendar)
		local argument = normalized:match("^/set%s+date%s+(.-)%s*$") or ""
		if argument == "auto" then
			workspace:SetAttribute("CalendarOffset", nil)
			notify(player, "The date follows the shared calendar again: " .. Calendar.format(Calendar.now()) .. ".")
			return
		end
		local month, day, hour = Calendar.parse(argument)
		if not month then
			notify(player, "Usage: /set date <month-day> [hh:mm], e.g. /set date 10-31 23:50, or /set date auto.")
			return
		end
		-- Shift the calendar so it reads that moment now, then let it run on from there.
		workspace:SetAttribute("CalendarOffset", nil)
		local today = Calendar.now()
		local target = Calendar.elapsedAt(today.Year, month, day :: number, hour or today.Hour)
		workspace:SetAttribute("CalendarOffset", target - Calendar.elapsedAt(today.Year, today.Month, today.Day, today.Hour))
		local date = Calendar.now()
		local clock = date.Hour
		notify(player, string.format("Date set to %s, %02d:%02d.", Calendar.format(date), math.floor(clock), math.floor(clock % 1 * 60)))
		return
	end
	if subject ~= "weather" then
		BoatService.setCashFromCommand(player, message)
		return
	end
	local argument = normalized:match("^/set%s+weather%s+(.+)") or ""
	argument = argument:gsub("%s+", "")
	local kinds = {}
	local selected
	for kind in Weather.Presets do
		if kind ~= "BlackHole" then
			table.insert(kinds, kind)
			if string.lower(kind) == argument then
				selected = kind
			end
		end
	end
	table.sort(kinds)
	if argument == "list" then
		notify(player, "Weather types: " .. table.concat(kinds, ", ") .. ".")
	elseif selected then
		workspace:SetAttribute("BlackHolePosition", nil)
		-- A summoned supercell circles the admin who called it.
		local root = player.Character and player.Character.PrimaryPart
		local summoned = selected == "Supercell" and root
		workspace:SetAttribute(
			"SupercellPosition",
			if summoned then Vector3.new(root.Position.X, Biomes.WaterLevel, root.Position.Z) else nil
		)
		workspace:SetAttribute("SupercellSince", if selected == "Supercell" then workspace:GetServerTimeNow() else nil)
		workspace:SetAttribute("WeatherOverride", selected)
		notify(player, "Weather set to " .. selected .. ".")
	else
		notify(player, "Usage: /set weather <type>. Use /set weather list for available types.")
	end
end

local function boatOccupied(player: Player): boolean
	local boat = active[player]
	if boat then
		for _, piece in boat.model:GetDescendants() do
			if (piece:IsA("Seat") or piece:IsA("VehicleSeat")) and piece.Occupant then
				return true
			end
		end
	end
	return false
end

local function lockedNotice(spec): string
	return "The " .. spec.Name .. " unlocks with the " .. spec.RequiresPath .. " path. Unlock it in Home ▸ Paths."
end

local function purchase(player: Player, boatId: string?)
	local id = boatId or "Rowboat"
	local spec = BoatCatalog[id]
	if not spec then
		return
	end
	local prompt = shopPrompt(player)
	if not prompt then
		return
	end
	local state = readyState(player)
	if not state or launching[player] or not acquireSave(player, state) then
		return
	end
	if launching[player] then
		releaseSave(state)
		return
	end
	if shopPrompt(player) ~= prompt then
		releaseSave(state)
		return
	end
	if state.profile.OwnedBoats[id] then
		releaseSave(state)
		notify(player, "You already own the " .. spec.Name .. ". Spawn it at your own dock.")
		return
	end
	if BoatData.pathLocked(state.profile, id) then
		releaseSave(state)
		notify(player, lockedNotice(spec))
		return
	end
	if boatOccupied(player) then
		releaseSave(state)
		notify(player, "Everyone must leave your current boat before launching a new purchase.")
		return
	end
	if state.profile.Cash < spec.Price then
		releaseSave(state)
		notify(player, "You need $" .. spec.Price .. " for the " .. spec.Name .. ".")
		return
	end
	local shop = prompt:FindFirstAncestorOfClass("Model")
	while shop and not CollectionService:HasTag(shop, "BoatShop") do
		shop = shop:FindFirstAncestorOfClass("Model")
	end
	if not shop then
		releaseSave(state)
		return
	end
	local reservation, reason = DrydockLaunch.reserve(shop, player, id)
	if not reservation then
		releaseSave(state)
		notify(player, reason)
		return
	end
	launching[player] = reservation
	local success, saved = pcall(function()
		local result = store:UpdateAsync("Player_" .. player.UserId, function(raw)
			local profile = BoatData.purchase(raw, id)
			return profile
		end)
		return committedProfile(result)
	end)
	if not success then
		releaseSave(state)
		launching[player] = nil
		DrydockLaunch.release(reservation)
		warn("[Boats] Purchase failed for " .. player.UserId .. ": " .. tostring(saved))
		notify(player, "The purchase could not be confirmed. Please try again.")
		return
	end
	-- Both the deduction and ownership are committed in one atomic store update.
	local valid, profile = pcall(BoatData.decode, saved)
	if not valid or profiles[player] ~= state or player.Parent ~= Players then
		releaseSave(state)
		launching[player] = nil
		DrydockLaunch.release(reservation)
		return
	end
	state.profile = profile
	publish(player, state)
	releaseSave(state)
	if profile.OwnedBoats[id] then
		-- The launch camera follows the lowering, after the cradle has risen.
		shop:SetAttribute("LaunchStartedAt", workspace:GetServerTimeNow() + DrydockLaunch.RAISE_SECONDS)
		feedback:FireClient(player, "LaunchStarted", shop, id)
		task.spawn(function()
			local launched, result = pcall(function()
				return DrydockLaunch.run(reservation, launchPurchased)
			end)
			DrydockLaunch.release(reservation)
			launching[player] = nil
			if player.Parent == Players then
				feedback:FireClient(player, "LaunchFinished")
				if not launched or not result then
					notify(
						player,
						"Your " .. spec.Name .. " is saved. Use your plot's boat stand if boarding was interrupted."
					)
				end
			end
			if not launched then
				warn("[Boats] Drydock launch interrupted: " .. tostring(result))
			end
		end)
	else
		launching[player] = nil
		DrydockLaunch.release(reservation)
		notify(
			player,
			if BoatData.pathLocked(profile, id)
				then lockedNotice(spec)
				else "You need $" .. spec.Price .. " for the " .. spec.Name .. "."
		)
	end
end

local function removeBoat(player: Player)
	local boat = active[player]
	if boat then
		active[player] = nil
		player:SetAttribute("ActiveBoatId", nil)
		boat.model:Destroy()
	end
end

-- Puts the player's launched boat away when it is `boatId` and nobody is aboard.
function BoatService.stowBoat(player: Player, boatId: string): boolean
	local boat = active[player]
	if not boat or boat.model:GetAttribute("BoatId") ~= boatId then
		return true
	elseif boatOccupied(player) or launching[player] then
		return false
	end
	removeBoat(player)
	return true
end

-- `check(player, boatId)` returns a reason when another system (the hired
-- fisherman) is using that boat, so the dock cannot launch a second copy.
function BoatService.setBoatLock(check: (Player, string) -> string?)
	boatLock = check
end

-- `outfit(player, boatId, model)` dresses one of the player's hulls with their
-- refit dock paint and returns the spec its motors and rudders tune it to.
-- Refits tune the spec per player; the driving client reads it from the hull.
local function publishDriveSpec(boat)
	for _, field in BoatDrive.FIELDS do
		boat.model:SetAttribute("Drive" .. field, boat.spec[field])
	end
end

function BoatService.setOutfitter(outfit: (Player, string, Model) -> any)
	outfitter = outfit
end

-- The spec a player's hull drives with, after dressing `model` for them.
function BoatService.outfit(player: Player, boatId: string, model: Model)
	return outfitter and outfitter(player, boatId, model) or BoatCatalog[boatId]
end

-- Reapplies refits to the launched boat once a motor, rudder or paint is saved.
function BoatService.refit(player: Player)
	local boat = active[player]
	if boat and boat.model.Parent then
		boat.spec = BoatService.outfit(player, boat.model:GetAttribute("BoatId"), boat.model)
		publishDriveSpec(boat)
	end
end

-- The player's launched boat, whose cargo hold they can reach.
function BoatService.activeBoat(player: Player): (string?, Model?)
	local boat = active[player]
	if boat and boat.model.Parent then
		return boat.model:GetAttribute("BoatId"), boat.model
	end
	return nil, nil
end

-- Apply damage from server systems to an active hull, without affecting cargo.
function BoatService.damageBoat(player: Player, amount: number): boolean
	local boat = active[player]
	if
		not boat
		or not boat.model.Parent
		or type(amount) ~= "number"
		or amount <= 0
		or amount ~= amount
		or amount == math.huge
	then
		return false
	end
	local health = boat.model:GetAttribute("Health")
	if type(health) ~= "number" or health <= 0 then
		return false
	end
	boat.model:SetAttribute("Health", math.max(0, health - amount))
	return true
end

local updateSuspension = BoatDrive.updateSuspension

-- The driver's client simulates its own hull while at the helm (see client/BoatDriving),
-- so steering answers without a server round trip and the boat is not an interpolated
-- replica that stalls whenever the connection is busy streaming the map. The server keeps
-- the hull whenever nobody drives it, and for parking, sinking, lifts and tornadoes.
local function setDriver(boat, driver: Player?)
	if boat.driver == driver then
		return
	end
	boat.driver = driver
	if not boat.parked then
		boat.root:SetNetworkOwner(driver)
	end
	-- The client starts its own bank spring from level, and ours restarts from level too.
	boat.bank, boat.bankVelocity = 0, 0
	if driver then
		publishDriveSpec(boat)
	else
		-- Our heading target went stale while the client steered.
		local look = boat.root.CFrame.LookVector
		if math.abs(look.X) + math.abs(look.Z) > 0.01 then
			boat.yaw = math.atan2(-look.X, -look.Z)
		end
	end
	boat.model:SetAttribute("DriverUserId", if driver then driver.UserId else nil)
end

-- A seated avatar should not push the hull below its waterline. Preserve the
-- original values, including accessories added while seated, and restore them
-- as soon as the rider leaves or the boat is removed.
local function protectSeatFromRiderWeight(seat: Seat | VehicleSeat)
	local saved = {}
	local addedConnection
	local function restore()
		if addedConnection then
			addedConnection:Disconnect()
			addedConnection = nil
		end
		for part, massless in saved do
			part.Massless = massless
		end
		table.clear(saved)
	end
	local function update()
		restore()
		local humanoid = seat.Occupant
		local character = humanoid and humanoid.Parent
		if not character or not Players:GetPlayerFromCharacter(character) then
			return
		end
		local function makeMassless(part)
			if part:IsA("BasePart") and saved[part] == nil then
				saved[part] = part.Massless
				part.Massless = true
			end
		end
		for _, part in character:GetDescendants() do
			makeMassless(part)
		end
		addedConnection = character.DescendantAdded:Connect(makeMassless)
	end
	seat:GetPropertyChangedSignal("Occupant"):Connect(update)
	seat.Destroying:Connect(restore)
	update()
end

local function clearMotion(boat)
	for _, piece in boat.model:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.AssemblyLinearVelocity = Vector3.zero
			piece.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

-- Anchor or release a whole hull as one assembly change. The root goes first when
-- anchoring (the welded hull becomes static at once) and last when releasing (every piece
-- is already in the root's assembly when it starts to move). In descendant order the root
-- was released first, so each of the hull's parts then merged into a moving assembly one
-- at a time, and clients reprocessed simulation ownership for every merge (a 20 ms
-- ISR::processPotentialSimulationOwnershipChanges spike whenever a boat parked or set off).
local function setHullAnchored(model: Model, root: BasePart, anchored: boolean)
	if anchored then
		root.Anchored = true
	end
	for _, piece in model:GetDescendants() do
		if piece ~= root and piece:IsA("BasePart") then
			piece.Anchored = anchored
		end
	end
	if not anchored then
		root.Anchored = false
	end
end

local function setParked(boat, parked: boolean)
	if boat.parked == parked then
		return
	end
	-- Anchoring resets ownership, and every release starts on the server.
	setDriver(boat, nil)
	boat.parked = parked
	if parked then
		-- A standing character is a separate, client-simulated assembly. Keeping
		-- an idle hull dynamic lets its contacts fight our server-side movers.
		-- Anchor only the hull root, leaving deck collisions and seats usable.
		boat.speed, boat.turn = 0, 0
		boat.bank, boat.bankVelocity = 0, 0
		boat.velocity.PlaneVelocity = Vector2.zero
		clearMotion(boat)
		-- Anchor every piece, not just the root. A standing player is carried by the
		-- velocity of the part underfoot, so no deck piece may keep a stray drift.
		setHullAnchored(boat.model, boat.root, true)
		boat.model:SetAttribute("RowThrottle", 0)
		boat.model:SetAttribute("RowSteer", 0)
		-- Clients bob the anchored hull locally from this pose and swell clock.
		boat.model:SetAttribute("ParkedFrame", boat.root.CFrame)
		boat.model:SetAttribute("ParkedAt", workspace:GetServerTimeNow())
		boat.model:SetAttribute("WaterlineRootOffset", boat.waterlineOffset)
	else
		-- Release from the pose clients have bobbed it to, so riders see no snap.
		local rest, parkedAt = boat.model:GetAttribute("ParkedFrame"), boat.model:GetAttribute("ParkedAt")
		if rest and parkedAt then
			boat.model:PivotTo(
				Weather.parkedOffset(
					rest,
					parkedAt,
					workspace:GetServerTimeNow(),
					boat.model:GetAttribute("DryFloorHeight"),
					boat.model:GetAttribute("DryFloorHalfBeam"),
					boat.model:GetAttribute("DryFloorHalfLength"),
					boat.waterlineOffset
				) * boat.model:GetPivot()
			)
		end
		setHullAnchored(boat.model, boat.root, false)
		-- Anchoring resets network ownership. Reapply it after releasing the
		-- hull, before enabling forces, so boarding cannot change its simulator.
		boat.root:SetNetworkOwner(nil)
	end
	boat.float.Enabled = not parked
	boat.lift.Enabled = not parked
	boat.heading.Enabled = not parked
	boat.velocity.Enabled = not parked
	boat.model:SetAttribute("Parked", parked)
end

-- Tornadoes throw boats. The hull's movers let go while the vortex spirals it up
-- the funnel, then hurl it outward; they take over again once it falls back to
-- the sea. Deterministic tornado tracks keep this where clients draw the funnel.
local FLING_LIFT_SECONDS = 0.9
local FLING_MAX_SECONDS = 5
local FLING_COOLDOWN = 4

local function setMovers(boat, enabled: boolean)
	boat.float.Enabled = enabled
	boat.lift.Enabled = enabled
	boat.heading.Enabled = enabled
	boat.velocity.Enabled = enabled
end

local function catchInTornado(boat, tornadoes): boolean
	if boat.flight or os.clock() - (boat.flungAt or -math.huge) < FLING_COOLDOWN then
		return false
	end
	local position = boat.root.Position
	for _, tornado in tornadoes do
		local dx, dz = position.X - tornado.position.X, position.Z - tornado.position.Z
		local reach = tornado.radius * Weather.TornadoReach
		if tornado.strength > 0.25 and dx * dx + dz * dz <= reach * reach then
			if boat.parked then
				setParked(boat, false)
			end
			setDriver(boat, nil)
			boat.speed, boat.turn = 0, 0
			boat.bank, boat.bankVelocity = 0, 0
			boat.velocity.PlaneVelocity = Vector2.zero
			setMovers(boat, false)
			boat.flight = { id = tornado.id, center = tornado.position, radius = tornado.radius, started = os.clock() }
			boat.flight.strength = math.max(0.6, tornado.strength)
			return true
		end
	end
	return false
end

-- True while the tornado still owns the hull.
local function updateFlight(boat, tornadoes): boolean
	local flight = boat.flight
	local root = boat.root
	local age = os.clock() - flight.started
	for _, tornado in tornadoes do
		if tornado.id == flight.id then
			flight.center = tornado.position
		end
	end
	local offset = Vector3.new(root.Position.X - flight.center.X, 0, root.Position.Z - flight.center.Z)
	local distance = offset.Magnitude
	local outward = if distance > 0.1 then offset / distance else Vector3.xAxis
	-- Counter-clockwise from above, like the cyclonic cell above it.
	local around = Vector3.yAxis:Cross(outward)
	local strength = flight.strength
	if age < FLING_LIFT_SECONDS then
		root.AssemblyLinearVelocity = around * 55 * strength
			+ Vector3.new(0, 40 + 30 * strength, 0)
			- outward * (distance - flight.radius) * 2
		root.AssemblyAngularVelocity = Vector3.new(1.4, 3.8, 0.9) * strength
		return true
	elseif not flight.thrown then
		flight.thrown = true
		root.AssemblyLinearVelocity = around * 70 * strength
			+ outward * 45 * strength
			+ Vector3.new(0, 45 * strength, 0)
		return true
	end
	local falling = root.AssemblyLinearVelocity.Y <= 0
	if (falling and root.Position.Y <= Biomes.WaterLevel + 6) or age > FLING_MAX_SECONDS then
		boat.flight = nil
		boat.flungAt = os.clock()
		local look = root.CFrame.LookVector
		if Vector2.new(look.X, look.Z).Magnitude > 0.01 then
			boat.yaw = math.atan2(-look.X, -look.Z)
		end
		boat.float.Position = root.Position
		setMovers(boat, true)
		return false
	end
	return true
end

-- Holds the launched boat on the drydock lift: parked, upright, deaf to the helm and
-- `height` studs above where it floated. nil sets it back afloat at that pose.
function BoatService.hoist(player: Player, height: number?): boolean
	local boat = active[player]
	if not boat or not boat.model.Parent or (not height and not boat.hoistBase) then
		return false
	end
	if not boat.hoistBase then
		setDriver(boat, nil)
		setParked(boat, true)
		local look = boat.root.CFrame.LookVector
		boat.hoistBase = CFrame.new(boat.root.Position) * CFrame.Angles(0, math.atan2(-look.X, -look.Z), 0)
		boat.model:SetAttribute("Hoisted", true)
	end
	local target = boat.hoistBase + Vector3.new(0, height or 0, 0)
	boat.model:PivotTo(target * boat.root.CFrame:ToObjectSpace(boat.model:GetPivot()))
	-- Clients bob a parked hull from this pose, and the helm releases from it.
	boat.model:SetAttribute("ParkedFrame", boat.root.CFrame)
	boat.model:SetAttribute("ParkedAt", workspace:GetServerTimeNow())
	-- Clients animate the lift themselves from the model's pivot at height 0.
	boat.model:SetAttribute("HoistPivot", if height then boat.model:GetPivot() - Vector3.new(0, height, 0) else nil)
	if not height then
		boat.hoistBase = nil
		boat.model:SetAttribute("Hoisted", nil)
	end
	return true
end

local function launch(player: Player, frame: CFrame, existing: Model?, boatId: string?)
	local id = boatId or (existing and existing:GetAttribute("BoatId")) or "Rowboat"
	local model = existing or builders[id].build(frame, false)
	local spec = BoatService.outfit(player, id, model)
	model.Name = id .. "_" .. player.UserId
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("BoatId", id)
	-- Each launched hull starts at full health; attributes replicate to everyone aboard.
	model:SetAttribute("MaxHealth", BoatCatalog[id].MaxHealth)
	model:SetAttribute("Health", BoatCatalog[id].MaxHealth)
	model:SetAttribute("LightsEnabled", true)
	-- Server time, for the driving client: a fresh hull may start in a dry slipway.
	model:SetAttribute("LaunchGraceUntil", if existing then workspace:GetServerTimeNow() + 10 else nil)
	local lights, lightParts = {}, {}
	for _, piece in model:GetDescendants() do
		if piece:IsA("PointLight") or piece:IsA("SpotLight") or piece:IsA("SurfaceLight") then
			table.insert(lights, piece)
		elseif piece:IsA("BasePart") then
			if piece.Material == Enum.Material.Neon then
				table.insert(lightParts, piece)
			end
			-- A moving hull re-renders the shadow map every frame; trim smaller than a stud
			-- (bolts, cleats, lantern frames, handles) adds draw calls but no visible shadow.
			local size = piece.Size
			if size and size.X < 1 and size.Y < 1 and size.Z < 1 then
				piece.CastShadow = false
			end
		end
	end
	local root = model.PrimaryPart :: BasePart
	local seat = model:FindFirstChild(spec.DriverSeat, true) :: VehicleSeat
	model:SetAttribute("DisplayOnly", nil)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	if existing then
		BoatLaunchCollision.protect(model, 10)
		for _, piece in model:GetDescendants() do
			if piece:IsA("BasePart") then
				-- The root is released last (below), so the hull starts moving as one assembly.
				if piece ~= root then
					piece.Anchored = false
				end
				local collide = piece:GetAttribute("PreviewCanCollide")
				if collide ~= nil then
					piece.CanCollide = collide
				end
				piece:SetAttribute("PreviewCanCollide", nil)
				if piece:IsA("Seat") or piece:IsA("VehicleSeat") then
					piece.Disabled = false
					piece.CanTouch = true
				end
			end
		end
		seat.Disabled = false
		seat.CanTouch = true
		root.Anchored = false
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "BoatMotion"
	attachment.Parent = root

	local float = Instance.new("AlignPosition")
	float.Name = "Waterline"
	float.Mode = Enum.PositionAlignmentMode.OneAttachment
	float.Attachment0 = attachment
	float.ApplyAtCenterOfMass = true
	float.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	float.ForceRelativeTo = Enum.ActuatorRelativeTo.World
	float.Position = root.Position
	-- Rigid alignment ignores the per-axis limits and can fight horizontal
	-- propulsion and deck contacts. Only the bounded Y suspension lifts boats.
	float.RigidityEnabled = false
	float.Responsiveness = 20
	float.MaxVelocity = 6
	float.Parent = root

	local lift = Instance.new("VectorForce")
	lift.Name = "WeightSupport"
	lift.Attachment0 = attachment
	lift.RelativeTo = Enum.ActuatorRelativeTo.World
	lift.ApplyAtCenterOfMass = true
	lift.Parent = root

	local heading = Instance.new("AlignOrientation")
	heading.Name = "UprightHeading"
	heading.Mode = Enum.OrientationAlignmentMode.OneAttachment
	heading.Attachment0 = attachment
	heading.CFrame = root.CFrame.Rotation
	heading.MaxAngularVelocity = spec.TurnRate + 2
	heading.RigidityEnabled = false
	heading.Responsiveness = 20
	heading.Parent = root

	-- Drive at the current center of mass; passengers can move it away from
	-- the hull root. The horizontal velocity below makes the stern the pivot.
	local driveAttachment = Instance.new("Attachment")
	driveAttachment.Name = "BoatDrive"
	driveAttachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "Rowing"
	velocity.Attachment0 = driveAttachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	velocity.PlaneVelocity = Vector2.zero
	velocity.ForceLimitsEnabled = true
	velocity.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	velocity.Parent = root

	model.Parent = workspace:FindFirstChild("PlayerBoats")
	root:SetNetworkOwner(nil)
	for _, piece in model:GetDescendants() do
		if piece:IsA("Seat") or piece:IsA("VehicleSeat") then
			protectSeatFromRiderWeight(piece)
		end
	end
	local _, yaw = root.CFrame:ToOrientation()
	local boat = {
		spec = spec,
		model = model,
		lights = lights,
		lightParts = lightParts,
		root = root,
		seat = seat,
		heading = heading,
		float = float,
		lift = lift,
		velocity = velocity,
		driveAttachment = driveAttachment,
		-- Each hull's physical root is below its waterline. Preserve that local
		-- offset when the hull tilts, so its waterline follows the sampled surface.
		waterlineOffset = frame:PointToObjectSpace(root.Position),
		yaw = yaw,
		speed = 0,
		bank = 0,
		bankVelocity = 0,
		throttle = 0,
		steer = 0,
		lastInput = 0,
		lastWaterCheck = 0,
		clearWater = true,
		launchGraceUntil = if existing then os.clock() + 10 else 0,
	}
	updateSuspension(boat)
	setParked(boat, true)
	active[player] = boat
	player:SetAttribute("ActiveBoatId", id)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		boat.throttle, boat.steer = 0, 0
		local humanoid = seat.Occupant
		if humanoid and Players:GetPlayerFromCharacter(humanoid.Parent) ~= player then
			task.defer(function()
				if humanoid.Parent then
					humanoid.Sit = false
				end
			end)
		end
	end)
	return boat
end

launchPurchased = function(player: Player, frame: CFrame, model: Model)
	removeBoat(player)
	local boat = launch(player, frame, model)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then
		return false
	end
	-- Request streaming while the launch camera remains active. Failure to stream
	-- is bounded and does not undo an already committed purchase.
	pcall(function()
		player:RequestStreamAroundAsync(boat.root.Position, 3)
	end)
	for _ = 1, 8 do
		if player.Character ~= character or humanoid.Health <= 0 or not boat.model.Parent then
			return false
		end
		character:PivotTo(boat.seat.CFrame + Vector3.new(0, 3, 0))
		root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
		boat.seat:Sit(humanoid)
		task.wait(0.15)
		if boat.seat.Occupant == humanoid then
			notify(player, "Your " .. boat.spec.Name .. " is afloat! Use movement controls to sail to your plot.")
			return true
		end
	end
	notify(player, "Your " .. boat.spec.Name .. " is afloat beside the slipway. Sit in the driver's seat to sail.")
	return true
end

local function dockBase(player: Player, prompt: ProximityPrompt): Model?
	if not prompt:IsDescendantOf(workspace) or not nearPrompt(player, prompt) then
		return nil
	end
	local base = prompt:FindFirstAncestorOfClass("Model")
	while base and not CollectionService:HasTag(base, "PlayerBase") and not CollectionService:HasTag(base, "CompanyIsland") do
		base = base:FindFirstAncestorOfClass("Model")
	end
	if
		not base
		or base:GetAttribute("OwnerUserId") ~= player.UserId
		or (not CollectionService:HasTag(base, "CompanyIsland") and base:GetAttribute("BaseId") ~= player:GetAttribute("BaseId"))
	then
		notify(player, "You can only spawn boats at your own dock.")
		return nil
	end
	return base
end

local function openDock(player: Player, prompt: ProximityPrompt)
	local base = dockBase(player, prompt)
	if base then
		feedback:FireClient(player, "OpenDock", base)
	end
end

local function spawnBoat(player: Player, prompt: ProximityPrompt, boatId: string?)
	local id = boatId or "Rowboat"
	local spec = BoatCatalog[id]
	if not spec then
		return
	end
	if launching[player] then
		notify(player, "Your boat is being lowered at the drydock. Please wait.")
		return
	end
	local base = dockBase(player, prompt)
	if not base then
		return
	end
	local state = readyState(player)
	if not state then
		return
	end
	if not state.profile.OwnedBoats[id] then
		notify(player, "Buy the " .. spec.Name .. " at the plaza drydock first.")
		return
	end
	local locked = boatLock and boatLock(player, id)
	if locked then
		notify(player, locked)
		return
	end
	if os.clock() - (spawnTimes[player] or -math.huge) < 4 then
		return
	end
	local previous = active[player]
	if boatOccupied(player) then
		notify(player, "Everyone must leave your boat before spawning another one.")
		return
	end
	local marker = base:FindFirstChild("BoatSpawn")
	if not marker or not marker:IsA("BasePart") then
		return
	end
	-- Keep the stern clear of the dock when a larger hull uses an older marker.
	local extraLength = math.max(0, (spec.Length - BoatCatalog.Rowboat.Length) / 2)
	local spawnFrame = marker.CFrame + marker.CFrame.LookVector * extraLength
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = if previous then { previous.model, marker } else { marker }
	local bounds = Vector3.new(math.max(11, spec.Beam + 2), 16, spec.Length + 1)
	for _, part in workspace:GetPartBoundsInBox(spawnFrame + Vector3.new(0, 6, 0), bounds, overlap) do
		if part.CanCollide then
			notify(player, "The launch space is blocked. Clear the water in front of your dock.")
			return
		end
	end
	spawnTimes[player] = os.clock()
	removeBoat(player)
	launch(player, spawnFrame, nil, id)
	notify(player, spec.Name .. " launched. Jump aboard and sit in the driver's seat to sail.")
end

local function buildPreviews(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Previews"
	for id, builder in builders do
		local model = builder.build(CFrame.identity, true)
		model.Name = id
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") then
				item.Anchored = true
				item.CanCollide, item.CanTouch, item.CanQuery = false, false, false
			elseif
				item:IsA("Constraint")
				or item:IsA("JointInstance")
				or item:IsA("ClickDetector")
				or item:IsA("ProximityPrompt")
				or item:IsA("BaseScript")
				or item:IsA("Sound")
			then
				item:Destroy()
			end
		end
		model.Parent = folder
	end
	-- Publish completed templates once; the dock does not need the shipyard streamed in.
	folder.Parent = parent
end

function BoatService.start()
	if started then
		return
	end
	started = true
	BoatLaunchCollision.start()
	local boats = Instance.new("Folder")
	boats.Name = "PlayerBoats"
	boats.Parent = workspace
	local remotes = Instance.new("Folder")
	remotes.Name = "Boating"
	remotes.Parent = ReplicatedStorage
	local request = Instance.new("RemoteEvent")
	request.Name = "Request"
	request.Parent = remotes
	feedback = Instance.new("RemoteEvent")
	feedback.Name = "Feedback"
	feedback.Parent = remotes
	buildPreviews(remotes)

	local setCommand = Instance.new("TextChatCommand")
	setCommand.Name = "SetCommand"
	setCommand.PrimaryAlias = "/set"
	setCommand.AutocompleteVisible = false
	setCommand.Triggered:Connect(function(source, message)
		local player = source and Players:GetPlayerByUserId(source.UserId)
		if player then
			setFromCommand(player, message)
		end
	end)
	setCommand.Parent = TextChatService
	AdminCommands.start(function(player, message)
		if player.Parent == Players then
			feedback:FireClient(player, "CommandNotice", message)
		end
	end)

	request.OnServerEvent:Connect(function(player, action, throttle, steer)
		if action == "Row" then
			local boat = active[player]
			if not boat or not boat.seat.Occupant or boat.seat.Occupant.Parent ~= player.Character then
				return
			end
			if
				type(throttle) ~= "number"
				or type(steer) ~= "number"
				or throttle ~= throttle
				or steer ~= steer
				or math.abs(throttle) > 1
				or math.abs(steer) > 1
			then
				return
			end
			-- Always keep the newest input. Network jitter bunches packets, and
			-- dropping the later one left a released key held until the next send.
			boat.throttle, boat.steer, boat.lastInput = throttle, steer, os.clock()
		elseif action == "ToggleLights" then
			local boat = active[player]
			if not boat or not boat.seat.Occupant or boat.seat.Occupant.Parent ~= player.Character then
				return
			end
			local now = os.clock()
			if now - (boat.lastLightsToggle or -math.huge) < 0.2 then
				return
			end
			boat.lastLightsToggle = now
			local enabled = boat.model:GetAttribute("LightsEnabled") == false
			for _, light in boat.lights do
				light.Enabled = enabled
			end
			for _, part in boat.lightParts do
				part.Material = if enabled then Enum.Material.Neon else Enum.Material.SmoothPlastic
			end
			boat.model:SetAttribute("LightsEnabled", enabled)
		elseif action == "BrowseRowboat" then
			openShop(player)
		elseif action == "BrowseBoat" then
			if type(throttle) == "string" and BoatCatalog[throttle] then
				openShop(player, nil, throttle)
			end
		elseif action == "PurchaseRowboat" or action == "PurchaseBoat" then
			local id = if action == "PurchaseRowboat" then "Rowboat" else throttle
			if type(id) ~= "string" or not BoatCatalog[id] then
				return
			end
			if os.clock() - (requests[player] or -math.huge) < 1 then
				return
			end
			requests[player] = os.clock()
			purchase(player, id)
		elseif action == "SpawnBoat" then
			if type(throttle) ~= "string" or not BoatCatalog[throttle] then
				return
			end
			for _, tag in { "PlayerBase", "CompanyIsland" } do
				for _, base in CollectionService:GetTagged(tag) do
					if base:GetAttribute("OwnerUserId") == player.UserId then
						local prompt = base:FindFirstChild("SpawnRowboatPrompt", true)
						if prompt and prompt:IsA("ProximityPrompt") and nearPrompt(player, prompt) then
							spawnBoat(player, prompt, throttle)
							return
						end
					end
				end
			end
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name == "TalkToShipwrightPrompt" then
			openShop(player, prompt)
		elseif prompt.Name == "SpawnRowboatPrompt" then
			openDock(player, prompt)
		end
	end)
	-- Update mover targets before the solver, so each physics step uses one
	-- coherent set of steering, banking and buoyancy commands.
	RunService.PreSimulation:Connect(function(dt)
		local serverTime = workspace:GetServerTimeNow()
		local tornadoes = Weather.tornadoes(serverTime)
		local weather = nil
		for player, boat in active do
			if not boat.model.Parent then
				active[player] = nil
				player:SetAttribute("ActiveBoatId", nil)
				continue
			end
			if boat.model:GetAttribute("Health") == 0 then
				if not boat.sinkingAt then
					-- Release an anchored hull and lower it under its own suspension so
					-- passengers see it sink instead of the boat vanishing at zero health.
					setParked(boat, false)
					setDriver(boat, nil)
					boat.sinkingAt = serverTime
					boat.sinkingPosition = boat.root.Position
					boat.model:SetAttribute("Sinking", true)
					boat.model:SetAttribute("RowThrottle", 0)
					boat.model:SetAttribute("RowSteer", 0)
					boat.velocity.Enabled = false
					boat.float.Enabled, boat.lift.Enabled, boat.heading.Enabled = true, true, true
					updateSuspension(boat)
					for _, piece in boat.model:GetDescendants() do
						if piece:IsA("Seat") or piece:IsA("VehicleSeat") then
							if piece.Occupant then
								piece.Occupant.Sit = false
							end
							piece.Disabled = true
						end
					end
				end
				local elapsed = serverTime - boat.sinkingAt
				if elapsed >= 12 then
					removeBoat(player)
				else
					boat.float.Position = boat.sinkingPosition - Vector3.new(0, elapsed * 3, 0)
				end
				continue
			end
			if boat.hoistBase then
				-- Up on the drydock lift; DrydockLaunch moves it.
				setDriver(boat, nil)
				continue
			end
			if catchInTornado(boat, tornadoes) or (boat.flight and updateFlight(boat, tornadoes)) then
				continue
			end
			local rowing = boat.seat.Occupant
				and boat.seat.Occupant.Parent == player.Character
				and os.clock() - boat.lastInput < 0.5
			local throttle, steer = if rowing then boat.throttle else 0, if rowing then boat.steer else 0
			local wantsMotion = throttle ~= 0 or math.abs(steer) >= 0.08
			if boat.parked then
				if not wantsMotion then
					-- Anchored assemblies have infinite mass. Do not sample their
					-- mass or run wave/drive corrections while people use the deck.
					local root = boat.root
					if root.AssemblyLinearVelocity ~= Vector3.zero or root.AssemblyAngularVelocity ~= Vector3.zero then
						clearMotion(boat)
					end
					continue
				end
				setParked(boat, false)
			end
			-- Integrate the speed command across frames; water drag and solver lag
			-- must not restart the acceleration ramp at every physics step.
			local speed, turn = BoatMotion.step(boat.speed, boat.turn or 0, throttle, steer, boat.spec, dt)
			if
				not wantsMotion
				and speed == 0
				and turn == 0
				and math.abs(boat.bank) < 0.001
				and math.abs(boat.bankVelocity) < 0.005
				-- A thrown hull settles back onto the swell before it may anchor.
				and os.clock() - (boat.flungAt or -math.huge) > FLING_COOLDOWN
			then
				-- Preserve normal coasting and steering decay before holding still.
				setParked(boat, true)
				continue
			end
			-- At the helm, the driver's client steers the movers from its own input; we only
			-- track the commanded speed so the hull still parks once it has coasted to rest.
			setDriver(boat, if rowing then player else nil)
			if boat.driver then
				boat.speed, boat.turn = speed, turn
			else
				weather = BoatDrive.apply(boat, speed, turn, throttle, steer, dt, serverTime, weather)
			end
			-- Replicated intent drives the cosmetic stroke on every viewing client.
			if boat.model:GetAttribute("RowThrottle") ~= throttle then
				boat.model:SetAttribute("RowThrottle", throttle)
			end
			if boat.model:GetAttribute("RowSteer") ~= steer then
				boat.model:SetAttribute("RowSteer", steer)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		removeBoat(player)
		profiles[player], requests[player], spawnTimes[player] = nil, nil, nil
	end)
	Players.PlayerAdded:Connect(loadPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end
end

return BoatService
