-- Elections for the whole game (Shared.Parties holds the rules and the calendar).
--
-- Every server adds its ballots to one DataStore record per term, so the count, the winner
-- and the policy in force are the same everywhere. A player's own vote is saved on their
-- profile as `ElectionVote = { Term, Party }`: one vote per angler per term, cast from a
-- booth in the parliament's Polling Station while the polls are open.
--
-- Published for clients on ReplicatedStorage.Election (attributes Term, PollsOpen, OpensAt,
-- ClosesAt, Governing, V_<party> votes so far, S_<party> seats in the sitting house, BellAt)
-- and for gameplay as Policy<Kind> numbers on ReplicatedStorage itself, so services read the
-- policy in force without requiring this module.
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BoatService = require(script.Parent.BoatService)
local DayNight = require(ReplicatedStorage.Shared.DayNight)
local Layout = require(ReplicatedStorage.Shared.ParliamentLayout)
local Parties = require(ReplicatedStorage.Shared.Parties)

local Service = {}
local started = false
local sessionOnly = RunService:IsStudio() and game.GameId == 0
local STORE = if RunService:IsStudio() then "FishingWatersElections_Studio_v1" else "FishingWatersElections_v1"
local PUBLISH_SECONDS, SYNC_SECONDS = 5, 60
-- Other servers get this long after the polls close to hand in their last ballots.
local COUNT_GRACE = 150

local store
local memory = {} -- stands in for the DataStore in an unpublished Studio place
local records: { [number]: { Votes: { [string]: number }, Winner: string? } } = {}
local pending: { [number]: { [string]: number } } = {}
local folder: Folder
local busy: { [Player]: boolean } = {}
local lastRequest: { [Player]: number } = {}
local lastBell = -math.huge
local closing = false

local function now(): number
	return DayNight.elapsed()
end

local function notify(player: Player, message: string)
	local boating = ReplicatedStorage:FindFirstChild("Boating")
	local feedback = boating and boating:FindFirstChild("Feedback")
	if feedback and feedback:IsA("RemoteEvent") and player.Parent == Players then
		feedback:FireClient(player, "Notice", message)
	end
end

local function clean(value: any)
	local record = { Votes = {}, Winner = nil :: string? }
	if type(value) == "table" then
		if type(value.Votes) == "table" then
			for _, party in Parties.List do
				local count = value.Votes[party.Id]
				if type(count) == "number" and count > 0 then
					record.Votes[party.Id] = math.floor(count)
				end
			end
		end
		if type(value.Winner) == "string" then
			record.Winner = value.Winner
		end
	end
	return record
end

-- Hands this server's unwritten ballots for `term` to the shared record and reads it back.
-- `finalize` also locks in the winner, once, for whichever server gets there first.
local function sync(term: number, finalize: boolean?): boolean
	local delta = pending[term]
	local sent = if delta then table.clone(delta) else nil
	local key = "Term" .. tostring(term)
	local function merge(old)
		local record = clean(old)
		for id, count in sent or {} do
			record.Votes[id] = (record.Votes[id] or 0) + count
		end
		if finalize and not record.Winner then
			record.Winner = Parties.winner(record.Votes) or "None"
		end
		return record
	end
	local ok, result = pcall(function()
		if sessionOnly then
			memory[key] = merge(memory[key])
			return memory[key]
		end
		store = store or DataStoreService:GetDataStore(STORE)
		if not sent and not finalize then
			return clean(store:GetAsync(key))
		end
		return store:UpdateAsync(key, merge)
	end)
	if not ok then
		warn("[Election] Count will retry: " .. tostring(result))
		return false
	end
	records[term] = clean(result)
	-- Ballots cast while the write was under way stay pending.
	if sent and pending[term] then
		for id, count in sent do
			local left = (pending[term][id] or 0) - count
			pending[term][id] = if left > 0 then left else nil
		end
		if next(pending[term]) == nil then
			pending[term] = nil
		end
	end
	return true
end

-- Votes for `term` as far as this server knows: the shared count plus its own unwritten ballots.
local function votes(term: number): { [string]: number }
	local total = {}
	for _, party in Parties.List do
		local record, waiting = records[term], pending[term]
		total[party.Id] = ((record and record.Votes[party.Id]) or 0) + ((waiting and waiting[party.Id]) or 0)
	end
	return total
end

-- The party in office during `term`: the winner of the election held in the term before.
local function governing(term: number): string?
	local previous = records[term - 1]
	if not previous then
		return nil
	end
	local winner = previous.Winner or Parties.winner(votes(term - 1))
	return if winner and Parties.ById[winner] then winner else nil
end

local function publish()
	local state = Parties.state(now())
	local office = governing(state.Term)
	folder:SetAttribute("Term", state.Term)
	folder:SetAttribute("PollsOpen", state.PollsOpen)
	folder:SetAttribute("OpensAt", state.OpensAt)
	folder:SetAttribute("ClosesAt", state.ClosesAt)
	folder:SetAttribute("Governing", office or "")
	local cast = votes(state.Term)
	local last = votes(state.Term - 1)
	local seats = if Parties.total(last) > 0 then Parties.seats(last) else nil
	for _, party in Parties.List do
		folder:SetAttribute("V_" .. party.Id, if state.PollsOpen then cast[party.Id] else 0)
		folder:SetAttribute("S_" .. party.Id, if seats then seats[party.Id] else 0)
	end
	for kind, amount in Parties.policies(office) do
		ReplicatedStorage:SetAttribute("Policy" .. kind, amount)
	end
	return state
end

local function view(player: Player)
	local state = Parties.state(now())
	local profile = BoatService.getProfile(player)
	local saved = profile and profile.ElectionVote
	local last = votes(state.Term - 1)
	return {
		Term = state.Term,
		PollsOpen = state.PollsOpen,
		OpensAt = state.OpensAt,
		ClosesAt = state.ClosesAt,
		Elapsed = now(),
		Governing = governing(state.Term),
		Votes = votes(state.Term),
		Seats = if Parties.total(last) > 0 then Parties.seats(last) else nil,
		MyVote = if type(saved) == "table" and saved.Term == state.Term then saved.Party else nil,
	}
end

-- A ballot only counts from inside the Polling Station.
local function atBooth(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local room = Layout.RoomById.E0A
	for _, building in CollectionService:GetTagged(Layout.Tag) do
		local frame = building:GetAttribute(Layout.FrameAttribute)
		if typeof(frame) == "CFrame" then
			local p = frame:PointToObjectSpace(root.Position)
			if
				math.abs(p.X - room.Centre.X) < room.HalfU + 3
				and p.Z > room.Z0 - 3
				and p.Z < room.Z1 + 3
				and p.Y > room.Y - 2
				and p.Y < room.Y + Layout.Storey
			then
				return true
			end
		end
	end
	return false
end

local function cast(player: Player, partyId: any): (boolean, string)
	local party = type(partyId) == "string" and Parties.ById[partyId]
	if not party then
		return false, "That party is not on the ballot."
	end
	local state = Parties.state(now())
	if not state.PollsOpen then
		return false, "The polls are closed. " .. (Parties.statusLine(now()))
	end
	if not atBooth(player) then
		return false, "Vote from a booth in the Polling Station, on the ground floor of the parliament's east wing."
	end
	local profile = BoatService.getProfile(player)
	if not profile then
		return false, "Your progress is still loading or unavailable."
	end
	local saved = profile.ElectionVote
	if type(saved) == "table" and saved.Term == state.Term then
		return false, "You have already voted in this election."
	end
	local term = state.Term
	local ok, message = BoatService.updateProgress(player, function(current)
		local earlier = current.ElectionVote
		assert(not (type(earlier) == "table" and earlier.Term == term), "You have already voted in this election.")
		current.ElectionVote = { Term = term, Party = party.Id }
	end)
	if not ok then
		return false, message
	end
	pending[term] = pending[term] or {}
	pending[term][party.Id] = (pending[term][party.Id] or 0) + 1
	publish()
	return true, "Your vote for " .. party.Name .. " has been counted."
end

-- Rings the division bell from the Speaker's desk. Clients see BellAt and send the members in.
local function ring(player: Player)
	local elapsed = now()
	local last = folder:GetAttribute("BellAt")
	if Parties.division(elapsed, if type(last) == "number" then last else nil) then
		notify(player, "A division is already under way.")
		return
	end
	if os.clock() - lastBell < Parties.BELL_COOLDOWN then
		notify(player, "The bell has only just rung. Give the members a few minutes.")
		return
	end
	lastBell = os.clock()
	folder:SetAttribute("BellAt", elapsed)
	notify(player, "You rang the division bell. The members are on their way to vote.")
end

-- The policy number in force for `kind` (0 when nobody governs it).
function Service.policy(kind: string): number
	local value = ReplicatedStorage:GetAttribute("Policy" .. kind)
	return if type(value) == "number" then value else 0
end

function Service.start()
	if started then
		return
	end
	started = true
	folder = Instance.new("Folder")
	folder.Name = "Election"
	local remote = Instance.new("RemoteFunction")
	remote.Name = "Request"
	remote.Parent = folder
	for kind, amount in Parties.policies(nil) do
		ReplicatedStorage:SetAttribute("Policy" .. kind, amount)
	end
	publish()
	folder.Parent = ReplicatedStorage

	remote.OnServerInvoke = function(player, action, partyId)
		if action == "State" then
			return { Ok = true, State = view(player) }
		end
		if action ~= "Vote" then
			return { Ok = false, Message = "Unknown request." }
		end
		if busy[player] or os.clock() - (lastRequest[player] or -math.huge) < 0.5 then
			return { Ok = false, Message = "One moment...", State = view(player) }
		end
		lastRequest[player] = os.clock()
		busy[player] = true
		local ok, success, message = pcall(cast, player, partyId)
		busy[player] = nil
		if not ok then
			warn("[Election] " .. tostring(success))
			return { Ok = false, Message = "The ballot box is stuck. Try again in a moment.", State = view(player) }
		end
		return { Ok = success, Message = message, State = view(player) }
	end
	Players.PlayerRemoving:Connect(function(player)
		busy[player], lastRequest[player] = nil, nil
	end)

	local function bindBell(holder: Instance)
		local prompt = holder:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(ring)
		end
	end
	CollectionService:GetInstanceAddedSignal(Layout.BellTag):Connect(bindBell)
	for _, holder in CollectionService:GetTagged(Layout.BellTag) do
		bindBell(holder)
	end

	task.spawn(function()
		local sinceSync = SYNC_SECONDS
		while not closing do
			local state = publish()
			if sinceSync >= SYNC_SECONDS then
				sinceSync = 0
				sync(state.Term)
				-- The election before this term decides who governs now.
				local previous = state.Term - 1
				if previous >= 1 and not (records[previous] and records[previous].Winner and not pending[previous]) then
					sync(previous, now() - Parties.termStart(state.Term) >= COUNT_GRACE)
				end
				for term in pending do
					if term ~= state.Term and term ~= previous then
						sync(term)
					end
				end
				publish()
			end
			sinceSync += task.wait(PUBLISH_SECONDS)
		end
	end)
	game:BindToClose(function()
		closing = true
		local deadline = os.clock() + 20
		for term in table.clone(pending) do
			if os.clock() < deadline then
				sync(term)
			end
		end
	end)
end

return Service
