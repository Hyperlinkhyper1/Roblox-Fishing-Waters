-- Production SaveService is injected by check-saves.mjs. The small BoatData
-- boundary retains money/metadata so these tests exercise real service control
-- flow, storage keys, authorisation, discovery and reserved-server routing.
local SaveData = (function()
-- SAVE_DATA_SOURCE --
end)()

local function clone(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[key] = clone(child) end
	return result
end

local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback)
			table.insert(callbacks, callback)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, callback in callbacks do callback(...) end
		end,
	}
end

local Enum = { InfoType = { Asset = "Asset" } }

local function newService(game, Instance, task, os, warn, dependencies)
-- SAVE_SERVICE_SOURCE --
end

local function world(config)
	config = config or {}
	local env = { records = clone(config.records or {}), now = 100, warnings = {}, writes = {}, reads = {},
		activations = {}, applies = {}, prepares = {}, teleports = {}, filterCalls = {}, scheduled = {},
		failWrites = {}, failReads = {}, retries = {}, players = {}, guid = 0, productCalls = {} }
	local Instance = {}
	local methods = {}
	local instanceMt = {
		__index = methods,
		__newindex = function(self, key, value)
			if key == "Parent" then
				local old = rawget(self, "Parent")
				if old then
					local index = table.find(old.children, self)
					if index then table.remove(old.children, index) end
				end
				rawset(self, key, value)
				if value then table.insert(value.children, self) end
			else rawset(self, key, value) end
		end,
	}
	function Instance.new(class)
		return setmetatable({ ClassName = class, Name = class, children = {}, attributes = {} }, instanceMt)
	end
	function methods:FindFirstChild(name)
		for _, child in self.children do if child.Name == name then return child end end
		return nil
	end
	function methods:SetAttribute(name, value) self.attributes[name] = value end
	function methods:GetAttribute(name) return self.attributes[name] end
	function methods:SetTeleportData(value) self.TeleportData = clone(value) end

	local Players = { PlayerAdded = signal(), PlayerRemoving = signal() }
	function Players:GetPlayers() return env.players end
	function Players:GetFriendsAsync(userId)
		if config.friendError then error("Friends API unavailable") end
		local pages, index = {}, 1
		local list = (config.friends or {})[userId] or {}
		-- Use small pages so page advance behavior also runs.
		for first = 1, #list, 2 do
			local page = {}
			for i = first, math.min(first + 1, #list) do table.insert(page, { Id = list[i] }) end
			table.insert(pages, page)
		end
		if #pages == 0 then pages[1] = {} end
		local result = { IsFinished = #pages == 1 }
		function result:GetCurrentPage() return pages[index] end
		function result:AdvanceToNextPageAsync()
			index += 1
			self.IsFinished = index == #pages
		end
		return result
	end
	function env:addPlayer(userId, joinData)
		local player = Instance.new("Player")
		player.UserId, player.Name, player.DisplayName = userId, "Player" .. userId, "Angler " .. userId
		player.Parent = Players
		function player:IsFriendsWithAsync(owner)
			return table.find((config.friends or {})[self.UserId] or {}, owner) ~= nil
		end
		function player:GetJoinData() return joinData or {} end
		table.insert(self.players, player)
		if self.started then Players.PlayerAdded:Fire(player) end
		return player
	end
	Players.children = {}
	local ReplicatedStorage = Instance.new("Folder")
	local TeleportService = { TeleportInitFailed = signal() }
	function TeleportService:TeleportAsync(place, players, options)
		if config.teleportError then error("Teleport unavailable") end
		table.insert(env.teleports, { PlaceId = place, Players = players, Options = options })
	end
	local TextService = {}
	function TextService:FilterStringAsync(name, userId)
		table.insert(env.filterCalls, { Name = name, UserId = userId })
		if config.filterError then error("Text filter unavailable") end
		return { GetNonChatStringForBroadcastAsync = function()
			return if config.filter then config.filter(name) else name
		end }
	end
	local services = {
		Players = Players, ReplicatedStorage = ReplicatedStorage,
		RunService = { IsStudio = function() return config.studio ~= false end },
		TextService = TextService, TeleportService = TeleportService,
		MarketplaceService = { GetProductInfo = function(_, id, infoType)
			assert(infoType == "Asset", "Icons are looked up as assets")
			table.insert(env.productCalls, id)
			if config.productError then error("Catalog unavailable") end
			return { AssetTypeId = (config.assetTypes or {})[id] or 13 }
		end },
		HttpService = { GenerateGUID = function()
			env.guid += 1
			return "company-guid-" .. env.guid
		end },
	}
	local game = { PlaceId = 12345, PrivateServerId = config.serverId or "", PrivateServerOwnerId = 0 }
	function game:GetService(name) assert(services[name], "Unknown mock service " .. name); return services[name] end
	local task = {
		spawn = function(callback, ...) table.insert(env.scheduled, { callback, { ... } }) end,
		wait = function(seconds) env.now += seconds or 0.03; return seconds or 0.03 end,
	}
	function env:drain()
		local count = 0
		while #self.scheduled > 0 do
			count += 1
			assert(count < 1000, "Mock task queue did not settle")
			local call = table.remove(self.scheduled, 1)
			call[1](table.unpack(call[2]))
		end
	end
	local os = { clock = function() return env.now end, time = function() return 100000 + math.floor(env.now) end }
	local warn = function(message) table.insert(env.warnings, tostring(message)) end
	local store = {}
	function store:GetAsync(key)
		table.insert(env.reads, key)
		if (env.failReads[key] or 0) > 0 then env.failReads[key] -= 1; error("DataStore read failed") end
		return clone(env.records[key])
	end
	function store:UpdateAsync(key, transform)
		table.insert(env.writes, key)
		if (env.failWrites[key] or 0) > 0 then env.failWrites[key] -= 1; error("DataStore write failed") end
		local result = transform(clone(env.records[key]))
		if env.retries[key] then
			local retry = env.retries[key]
			env.retries[key] = nil
			retry(env.records)
			result = transform(clone(env.records[key]))
		end
		if result ~= nil then env.records[key] = clone(result) end
		return clone(result)
	end
	local BoatData = { decode = function(raw)
		return clone(raw or { Version = 1, Cash = 0, OwnedBoats = { Rowboat = true }, RodSerialScope = "GlobalV1" })
	end }
	local dependencies = {
		SaveData = SaveData, BoatData = BoatData,
		RodSerials = { migrate = function(_, _, profile) return profile end },
		CompanyWorth = { calculate = function(profile) return profile.Cash end },
	}
	local service = newService(game, Instance, task, os, warn, dependencies)
	function env:open()
		service.open(store, config.sessionOnly == true)
		self.started = true
		self:drain()
		self.remote = ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("SaveRequest")
	end
	function env:start()
		service.start(store, config.sessionOnly == true, {
			beforeActivate = config.beforeActivate,
			prepare = function(player)
				table.insert(env.prepares, player)
				player:SetAttribute("BoatDataStatus", "Selecting")
				player:SetAttribute("SaveSelectionRequired", true)
			end,
			apply = function(key, profile) table.insert(env.applies, { Key = key, Profile = clone(profile) }) end,
			activate = function(player, key, profile, owner, slot)
				table.insert(env.activations, { Player = player, Key = key, Profile = clone(profile), Owner = owner, Slot = slot })
				player:SetAttribute("BoatDataStatus", "Ready")
				player:SetAttribute("SaveSelectionRequired", false)
			end,
		})
		self.started = true
		self:drain()
		self.remote = ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("SaveRequest")
	end
	function env:request(player, action, payload)
		self.now += 1
		local result = self.remote.OnServerInvoke(player, action, payload)
		self:drain()
		return result
	end
	function env:discover(player)
		self:request(player, "List")
		return self:request(player, "List")
	end
	function env:failure(player) TeleportService.TeleportInitFailed:Fire(player, "Failure") end
	return env
end

local checks = 0
local function check(value, message) checks += 1; assert(value, message) end
local function profile(owner, slot, multiplayer, cash, name)
	return { Version = 1, Cash = cash or 0, OwnedBoats = { Rowboat = true }, RodSerialScope = "GlobalV1",
		SaveInfo = SaveData.createInfo(owner, slot, name or "Gullhaven Company", multiplayer, 1, "persistent-server-" .. owner .. "-" .. slot) }
end
local function directory(slots, joined) return { Version = 1, Slots = slots or {}, Joined = joined or {} } end
local function pointer(owner, slot, name, multiplayer)
	return { Exists = true, OwnerUserId = owner, Slot = slot, Name = name or "Gullhaven Company", Multiplayer = multiplayer ~= false, MemberCount = 1, NetWorth = 100 }
end

-- Startup exposes a selector without activating a default profile or writing
-- defaults over existing progress; old Player_<id> records become slot one.
local legacy = { Version = 1, Cash = 4321, OwnedBoats = { Rowboat = true, FishingBoat = true } }
local migration = world({ records = { Player_10 = legacy }, sessionOnly = true })
local owner = migration:addPlayer(10)
migration:start()
check(#migration.prepares == 1 and #migration.activations == 0, "Joining prepares selection without starting gameplay")
check(#migration.writes == 0, "Opening game cannot create a default save")
local list = migration:request(owner, "List")
check(list.Ok and #list.Slots == 3, "Selector always contains exactly three owner slots")
check(list.Slots[1].Exists and list.Slots[1].NetWorth == 4321, "Legacy progress is shown in first slot")
check(not list.Slots[2].Exists and not list.Slots[3].Exists, "Other owner slots remain empty")
check(migration.records.Player_10.Cash == 4321 and migration.records.Player_10.SaveInfo.Name == "Existing plot", "Listing registers existing plot without replacing the legacy wallet")
check(migration.records.SaveDirectory_v1_10.Slots["1"].Exists, "Legacy first slot receives discovery pointer")
check(migration:request(owner, "Select", { OwnerUserId = 10, Slot = 1 }).Ok, "Legacy profile can be selected")
check(#migration.activations == 1 and migration.activations[1].Key == "Player_10", "Selection uses legacy key directly")
check(migration.activations[1].Profile.Cash == 4321, "Selection preserves original money")
check(not migration:request(owner, "Select", { OwnerUserId = 10, Slot = 2 }).Ok, "Live players cannot change saves under active gameplay")

local creating = world({ sessionOnly = true })
local creator = creating:addPlayer(20)
creating:start()
for slot = 1, 3 do
	local response = creating:request(creator, "Create", { Slot = slot, Name = "Company " .. slot, Multiplayer = slot == 2 })
	check(response.Ok, "Owner can create each of their three slots")
end
check(#creating.activations == 0, "Creating saves does not bypass explicit selection")
local fourth = creating:request(creator, "Create", { Slot = 4, Name = "Fourth", Multiplayer = true })
check(not fourth.Ok and creating.records.Player_20_Slot_4 == nil, "Fourth save cannot be persisted")
check(not creating:request(creator, "Create", { Slot = 1, Name = "Overwrite", Multiplayer = true }).Ok, "Create cannot overwrite occupied slot")
check(creating.records.Player_20.SaveInfo.Name == "Company 1", "Occupied profile remains intact")
check(creating:request(creator, "Settings", { Slot = 2, Name = "Renamed", Multiplayer = false }).Ok, "Owner can change company settings before entering")
check(creating.records.Player_20_Slot_2.SaveInfo.Name == "Renamed" and not creating.records.Player_20_Slot_2.SaveInfo.Multiplayer, "Owner setting change is persisted")
check(creating.records.Player_20_Slot_2.SaveInfo.PlotExpanded, "A company keeps its expanded saved plot after multiplayer is disabled")

-- An offline creator's directory is enough for a friend to find a company.
-- Membership is only a Joined pointer in that friend's account.
local shared = profile(30, 2, true, 850)
local offline = world({ records = {
	Player_30_Slot_2 = shared,
	SaveDirectory_v1_30 = directory({ ["2"] = pointer(30, 2) }),
}, friends = { [31] = { 30 }, [32] = { 30 } }, sessionOnly = true })
local friend = offline:addPlayer(31)
local friendTwo = offline:addPlayer(32)
local stranger = offline:addPlayer(33)
offline:start()
local friendsList = offline:discover(friend)
check(#friendsList.Companies == 1 and friendsList.Companies[1].OwnerUserId == 30, "Offline friend's company appears in sidebar")
for _, slot in friendsList.Slots do check(not slot.Exists, "Discovered company uses none of friend's owner slots") end
check(not offline:request(stranger, "Select", { OwnerUserId = 30, Slot = 2 }).Ok, "Guessing company pointer does not grant membership")
check(offline:request(friend, "Select", { OwnerUserId = 30, Slot = 2 }).Ok, "Friend can enter with original creator offline")
check(offline:request(friendTwo, "Select", { OwnerUserId = 30, Slot = 2 }).Ok, "Second friend can enter at same time")
check(#offline.activations == 2 and offline.activations[1].Key == offline.activations[2].Key, "Concurrent members receive same creator-owned wallet key")
check(offline.activations[1].Profile.Cash == 850 and offline.activations[2].Profile.Cash == 850, "Both members load one shared pile of money")
check(offline.records.SaveDirectory_v1_31.Joined["30_2"] ~= nil and next(offline.records.SaveDirectory_v1_31.Slots) == nil, "Guest account receives sidebar pointer without consuming a save slot")
check(offline.records.Player_31 == nil and offline.records.Player_32 == nil, "Joining never creates guest-owned company profile copies")
local unauthorised = offline:request(stranger, "Settings", { OwnerUserId = 30, Slot = 2, Name = "Stolen", Multiplayer = false })
check(not unauthorised.Ok and offline.records.Player_30_Slot_2.SaveInfo.Name == shared.SaveInfo.Name, "Only original owner can edit company")

-- The membership cap is checked inside the retried UpdateAsync transform,
-- including a competitor taking the last place while a join is in flight.
local full = profile(40, 1, true, 100)
for _, member in { 41, 42, 43 } do SaveData.join(full.SaveInfo, member, true) end
local race = world({ records = { Player_40 = full }, friends = { [44] = { 40 } }, sessionOnly = true })
local joining = race:addPlayer(44)
race:start()
race.retries.Player_40 = function(records) SaveData.join(records.Player_40.SaveInfo, 45, true) end
check(not race:request(joining, "Select", { OwnerUserId = 40, Slot = 1 }).Ok, "Retry rejects a join when another user filled company")
check(SaveData.memberCount(race.records.Player_40.SaveInfo) == 5 and not race.records.Player_40.SaveInfo.Members["44"], "Racing join cannot exceed five persisted members")
check(#race.activations == 0, "Rejected join never reaches gameplay")

local private = profile(50, 3, false, 100)
private.SaveInfo.Members["51"] = true
local disabled = world({ records = { Player_50_Slot_3 = private }, friends = { [51] = { 50 } }, sessionOnly = true })
local formerGuest = disabled:addPlayer(51)
disabled:start()
check(not disabled:request(formerGuest, "Select", { OwnerUserId = 50, Slot = 3 }).Ok and #disabled.activations == 0, "Turning multiplayer off blocks existing guests")

-- A failed auxiliary directory write cannot erase a committed profile; listing
-- subsequently repairs discovery from the creator's three canonical records.
local repair = world({ sessionOnly = true })
local repairingOwner = repair:addPlayer(60)
repair:start()
repair.failWrites.SaveDirectory_v1_60 = 1
repair:request(repairingOwner, "Create", { Slot = 2, Name = "Recoverable", Multiplayer = true })
check(repair.records.Player_60_Slot_2.SaveInfo.Name == "Recoverable", "Directory outage preserves committed company save")
local repaired = repair:request(repairingOwner, "List")
check(repaired.Ok and repaired.Slots[2].Exists and repair.records.SaveDirectory_v1_60.Slots["2"].Multiplayer, "Next list repairs missing directory pointer")

local filtered = world({ filter = function(name) return if name == "Bad Name" then "### Name" else name end })
local namedOwner = filtered:addPlayer(70)
filtered:start()
check(filtered:request(namedOwner, "Create", { Slot = 1, Name = "  Bad   Name  ", Multiplayer = true }).Ok, "Published saves accept filtered company names")
check(filtered.filterCalls[1].Name == "Bad Name" and filtered.filterCalls[1].UserId == 70, "Creator's normalized name is sent to Roblox text filter")
check(filtered.records.Player_70.SaveInfo.Name == "### Name", "Persisted and discoverable company name is filtered")
local filterFailure = world({ filterError = true })
local failedOwner = filterFailure:addPlayer(71)
filterFailure:start()
check(not filterFailure:request(failedOwner, "Create", { Slot = 1, Name = "Safe", Multiplayer = false }).Ok
	and filterFailure.records.Player_71 == nil, "Filter failure does not publish unfiltered company name")

-- A persisted reserved ID routes independent friends to the same company even
-- when its original creator is absent. Teleport payload is only a save pointer.
local liveProfile = profile(80, 1, true, 500)
local live = world({ studio = false, records = { Player_80 = liveProfile }, friends = { [81] = { 80 }, [82] = { 80 } } })
local firstTraveler = live:addPlayer(81)
local secondTraveler = live:addPlayer(82)
live:start()
check(live:request(firstTraveler, "Select", { OwnerUserId = 80, Slot = 1 }).Ok, "Live company selection starts teleport")
check(live:request(secondTraveler, "Select", { OwnerUserId = 80, Slot = 1 }).Ok, "Another live member can join concurrently")
check(#live.activations == 0 and #live.teleports == 2, "Public lobby never starts company gameplay before routing")
check(live.teleports[1].Options.ReservedServerId == liveProfile.SaveInfo.ServerId
	and live.teleports[2].Options.ReservedServerId == liveProfile.SaveInfo.ServerId, "All members reuse saved ReservedServerId")
check(live.teleports[1].Options.ReservedServerAccessCode == nil, "Company routing uses current reserved-ID API")
local teleportPointer = live.teleports[1].Options.TeleportData.FishingWatersSave
check(teleportPointer.OwnerUserId == 80 and teleportPointer.Slot == 1 and teleportPointer.Cash == nil, "Teleport payload contains no authoritative wallet")
check(firstTraveler:GetAttribute("SaveTeleporting") == true, "Pending routing state is visible to selector")
live:failure(firstTraveler)
check(firstTraveler:GetAttribute("SaveTeleporting") == false, "Asynchronous teleport failure lets player retry")
check(live:request(firstTraveler, "Select", teleportPointer).Ok and #live.teleports == 3, "Failed teleport retries using same persisted company")
local destination = world({ studio = false, serverId = liveProfile.SaveInfo.ServerId, records = live.records })
local arrived = destination:addPlayer(81, { TeleportData = { FishingWatersSave = teleportPointer } })
destination:start()
check(#destination.activations == 1 and destination.activations[1].Player == arrived and #destination.teleports == 0, "Reserved-server arrival revalidates membership then activates saved progress")
local forged = world({ studio = false, serverId = liveProfile.SaveInfo.ServerId, records = live.records })
forged:addPlayer(999, { TeleportData = { FishingWatersSave = teleportPointer } })
forged:start()
check(#forged.activations == 0 and not forged.records.Player_80.SaveInfo.Members["999"], "Forged teleport pointer cannot grant company membership")

local teleportFailure = world({ studio = false, teleportError = true, records = { Player_80 = liveProfile }, friends = { [81] = { 80 } } })
local stuckTraveler = teleportFailure:addPlayer(81)
teleportFailure:start()
check(not teleportFailure:request(stuckTraveler, "Select", teleportPointer).Ok and not stuckTraveler:GetAttribute("SaveTeleporting"), "Synchronous teleport failure resets pending state")
check(#teleportFailure.activations == 0 and teleportFailure.records.Player_80.SaveInfo.Members["81"], "Teleport outage preserves membership without starting gameplay")

local soloTravel = world({ studio = false, teleportError = true, serverId = "old-company-server",
	records = { Player_90 = profile(90, 1, false, 200) } })
local soloOwner = soloTravel:addPlayer(90)
soloTravel:start()
check(not soloTravel:request(soloOwner, "Select", { OwnerUserId = 90, Slot = 1 }).Ok
	and not soloOwner:GetAttribute("SaveTeleporting"), "Failed return to solo server also clears pending teleport state")
check(soloTravel:request(soloOwner, "List").Ok, "Solo-routing failure leaves selector usable")

local largeSolo = profile(92, 1, true, 900)
largeSolo.SaveInfo.Multiplayer = false
local expandedRouting = world({ studio = false, records = { Player_92 = largeSolo } })
local expandedOwner = expandedRouting:addPlayer(92)
expandedRouting:start()
check(expandedRouting:request(expandedOwner, "Select", { OwnerUserId = 92, Slot = 1 }).Ok
	and #expandedRouting.teleports == 1, "Expanded saves keep their company server after friends are disabled")
check(expandedRouting.teleports[1].Options.ReservedServerId == largeSolo.SaveInfo.ServerId,
	"Disabling multiplayer cannot move saved expanded buildings onto a smaller public plot")

local plotBlocked = true
local safePlot = world({ sessionOnly = true, records = { Player_93 = profile(93, 1, true, 350) },
	beforeActivate = function() assert(not plotBlocked, "The larger plots are obstructed.") end })
local waitingOwner = safePlot:addPlayer(93)
safePlot:start()
check(not safePlot:request(waitingOwner, "Select", { OwnerUserId = 93, Slot = 1 }).Ok
	and #safePlot.activations == 0 and waitingOwner:GetAttribute("BoatDataStatus") == "Selecting",
	"Obstructed larger plots leave selection available before spawning")
check(safePlot.records.Player_93.Cash == 350, "A plot preparation failure cannot reset saved progress")
plotBlocked = false
check(safePlot:request(waitingOwner, "Select", { OwnerUserId = 93, Slot = 1 }).Ok
	and #safePlot.activations == 1, "Plot preparation can be retried without restarting or losing the save")

-- Saves open at server boot, before the harbour (and the wallet service) is
-- ready. Listing and creating work at once; selecting waits for start().
local early = world({ sessionOnly = true, records = { Player_94 = profile(94, 1, false, 640, "Early Bird") } })
local earlyOwner = early:addPlayer(94)
early:open()
check(early.remote ~= nil and #early.prepares == 0, "Save remote exists before the wallet service starts")
local earlyList = early:request(earlyOwner, "List")
check(earlyList.Ok and earlyList.Slots[1].Name == "Early Bird" and earlyList.Slots[1].NetWorth == 640, "Saves list before the harbour is built")
check(table.find(early.reads, "Player_94") and table.find(early.reads, "Player_94_Slot_2") and table.find(early.reads, "Player_94_Slot_3"), "All three slots are read for one list")
check(early:request(earlyOwner, "Create", { Slot = 2, Name = "Second Wind", Multiplayer = false }).Ok
	and early.records.Player_94_Slot_2 ~= nil and #early.applies == 0, "Saves can be created before the wallet service starts")
early:start()
check(#early.prepares == 1 and early.prepares[1] == earlyOwner, "Starting the wallet service prepares players who joined early")
local readsBeforeSelect = #early.reads
check(early:request(earlyOwner, "Select", { OwnerUserId = 94, Slot = 1 }).Ok and #early.activations == 1, "Early players enter once the wallet service is running")
check(#early.reads == readsBeforeSelect, "A creator opens their own save with one transaction and no extra read")
local lateJoiner = early:addPlayer(95)
check(#early.prepares == 2 and early.prepares[2] == lateJoiner, "Players joining after start are prepared once")

-- Company icons are decal/image asset IDs stored on the creator's save.
check(SaveData.cleanIcon("12345") == 12345 and SaveData.cleanIcon(" rbxassetid://777 ") == 777, "Icon accepts bare and rbxassetid IDs")
check(SaveData.cleanIcon("https://create.roblox.com/store/asset/987654/Company-Logo") == 987654, "Icon accepts Creator Store links")
check(SaveData.cleanIcon("https://www.roblox.com/library/555123/Logo") == 555123, "Icon accepts library links")
check(SaveData.cleanIcon("") == false and SaveData.cleanIcon(nil) == false, "An empty icon clears it")
check(not pcall(SaveData.cleanIcon, "my logo") and not pcall(SaveData.cleanIcon, -4), "Icons must be positive asset IDs")
local icons = world({ sessionOnly = true })
local iconOwner = icons:addPlayer(96)
icons:start()
local iconCreated = icons:request(iconOwner, "Create", { Slot = 1, Name = "Logo Co", Multiplayer = true, Icon = "rbxassetid://4242" })
check(iconCreated.Ok and icons.records.Player_96.SaveInfo.Icon == 4242 and iconCreated.Slots[1].Icon == 4242, "Creating a save stores its company icon")
check(icons.records.SaveDirectory_v1_96.Slots["1"].Icon == 4242, "Friends discover the company icon")
SaveData.join(icons.records.Player_96.SaveInfo, 97, true, "Crew")
check(icons:request(iconOwner, "Settings", { Slot = 1, Name = "Logo Co", Multiplayer = true, RemoveUserId = 97 }).Ok
	and icons.records.Player_96.SaveInfo.Icon == 4242, "Settings without an icon keep the current one")
check(icons:request(iconOwner, "Settings", { Slot = 1, Name = "Logo Co", Multiplayer = true, Icon = "" }).Ok
	and icons.records.Player_96.SaveInfo.Icon == nil, "An empty icon removes it")
check(not icons:request(iconOwner, "Settings", { Slot = 1, Name = "Logo Co", Multiplayer = true, Icon = "logo" }).Ok, "Text that is not an ID is rejected")
local published = world({ assetTypes = { [31337] = 9 } })
local publishedOwner = published:addPlayer(98)
published:start()
local wrongType = published:request(publishedOwner, "Create", { Slot = 1, Name = "Wrong", Multiplayer = false, Icon = "31337" })
check(not wrongType.Ok and wrongType.Message == "That ID is not a decal or image." and published.records.Player_98 == nil, "Published saves reject assets that are not decals or images")
check(published:request(publishedOwner, "Create", { Slot = 1, Name = "Right", Multiplayer = false, Icon = "1818" }).Ok
	and published.records.Player_98.SaveInfo.Icon == 1818, "Published saves accept decal IDs")
local offlineCatalog = world({ productError = true })
local catalogOwner = offlineCatalog:addPlayer(99)
offlineCatalog:start()
check(offlineCatalog:request(catalogOwner, "Create", { Slot = 1, Name = "Kept", Multiplayer = false, Icon = "2020" }).Ok
	and offlineCatalog.records.Player_99.SaveInfo.Icon == 2020, "A catalog outage does not block saving an icon")

print("Save selection/company service: " .. checks .. " checks passed (recording mocks).")
