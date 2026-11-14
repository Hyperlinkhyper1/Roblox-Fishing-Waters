local checks = 0
local function check(value, message) checks += 1; assert(value, message) end
local clock = 100
local os = { clock = function() return clock end }
local function signal()
	local handlers = {}
	return {
		Connect = function(_, fn)
			local connection = { Connected = true }
			function connection:Disconnect() self.Connected = false end
			table.insert(handlers, { fn, connection }); return connection
		end,
		Fire = function(_, ...) for _, pair in handlers do if pair[2].Connected then pair[1](...) end end end,
	}
end
local profiles, records = {}, {}
local Players = { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end }
local BoatService = { getProfile = function(player) return profiles[player] end }
local Worth = { calculate = function(profile) return profile.Cash end }
local renders, ensured = {}, 0
local Boards = {
	ensure = function() ensured += 1 end,
	render = function(_, id, rows, status) table.insert(renders, { Id = id, Rows = rows, Status = status }) end,
}
local indexRecords, indexWrites, failWrite = {}, 0, false
local ordered = {}
function ordered:SetAsync(key, score)
	if failWrite then error("offline") end
	indexWrites += 1; indexRecords[key] = score
end
function ordered:GetSortedAsync(descending, count, minimum)
	check(descending == false and count >= 10 and minimum == 1, "Company ranking reads descending positive scores")
	local rows = {}
	for key, value in indexRecords do if value >= minimum then table.insert(rows, { key = key, value = value }) end end
	table.sort(rows, function(a, b) return a.value > b.value end)
	return { GetCurrentPage = function() return rows end }
end
local storeRequests = 0
local services = {
	Players = Players, RunService = { IsStudio = function() return false end },
	DataStoreService = { GetOrderedDataStore = function(_, name, scope)
		storeRequests += 1
		check(name == "AnglerBoards_v1_Companies" and scope == "Current", "Companies have a separate current-value index")
		return ordered
	end },
}
local closeHandler
local game = {
	GetService = function(_, name) return assert(services[name], name) end,
	BindToClose = function(_, fn) closeHandler = fn end,
}
local threads = {}
local task = {
	spawn = function(fn) table.insert(threads, coroutine.create(fn)) end,
	wait = function() coroutine.yield() end,
}
local warnings = {}
local warn = function(message) table.insert(warnings, message) end
local Service = (function()
-- SOURCE --
end)()
local wallet = { GetAsync = function(_, key) return records[key] end }
local function company(owner, slot, cash, name, multiplayer)
	return { Cash = cash, SaveInfo = { OwnerUserId = owner, Slot = slot, Name = name, Multiplayer = multiplayer ~= false } }
end
local first = company(101, 1, 100, "North Sea")
records.Player_101 = first
records.Player_202_Slot_2 = company(202, 2, 150, "Second Company")
Service.configure(wallet, false)
Service.record(company(101, 1, 9999, "Old cached name"))
Service.record(first)
Service.writeOne()
check(indexRecords["101_1"] == 100 and indexWrites == 1, "Members coalesce to one company and index the authoritative save")
first.Cash = 20
Service.record(first); Service.writeOne()
check(indexRecords["101_1"] == 20, "A company score may decrease after spending")
Service.record(records.Player_202_Slot_2); Service.writeOne()
first.SaveInfo.Name, first.Cash = "Renamed Company", 300
first.SaveInfo.Icon = 4242
records.Player_202_Slot_2.SaveInfo.Icon = "not an id"
local rows = Service.readBoard()
check(rows[1].Icon == 4242 and rows[2].Icon == nil, "Board rows carry valid company icons only")
check(#rows == 2 and rows[1].CompanyId == "101_1" and rows[1].Score == 300 and rows[1].Name == "Renamed Company",
	"Board re-reads the latest name and wealth, even while the original creator is offline")
Service.writeOne()
check(indexRecords["101_1"] == 300, "Reading a stale index queues its repair")
records.Player_202_Slot_2.SaveInfo.Multiplayer = false
rows = Service.readBoard()
check(#rows == 2, "Singleplayer saves keep their named company ranking")
records.Player_202_Slot_2 = nil
rows = Service.readBoard()
check(#rows == 1 and rows[1].CompanyId == "101_1", "Missing saves never occupy company rows")
Service.writeOne()
check(indexRecords["202_2"] == 0, "Missing saves are removed from the old index")
first.Cash = 90
Service.record(first); failWrite = true; Service.writeOne()
check(Service.pending["101_1"] ~= nil and #warnings == 1, "Failed index writes remain retryable")
failWrite = false; Service.writeOne()
check(indexRecords["101_1"] == 300, "Failed writes honor their retry delay")
clock += 31; Service.writeOne()
check(indexRecords["101_1"] == 90 and not Service.pending["101_1"], "A later retry writes the saved current value")
Service.record({ SaveInfo = { OwnerUserId = 101, Slot = 4 } })
check(next(Service.pending) == nil, "Invalid fourth slots cannot enter the index")
Service.configure(wallet, true)
Service.record(first); Service.writeOne()
check(#Service.readBoard() == 1 and storeRequests == 1, "Session-only Studio indexing uses memory without new persistent requests")
Service.start({}); Service.start({})
check(ensured == 1 and #threads == 1 and closeHandler ~= nil, "Startup installs one periodic worker and shutdown flush")
check(coroutine.resume(threads[1]), "Company worker runs")
check(#renders == 1 and renders[1].Id == "Companies", "Company service renders its own board")
print("Company leaderboard: " .. checks .. " concurrency, persistence and current-value checks passed (recording mocks).")
