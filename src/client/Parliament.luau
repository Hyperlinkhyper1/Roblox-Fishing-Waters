-- The parliament's local half: ornament and furniture (Shared.ParliamentInterior), the people
-- who work there (Shared.ParliamentCrowd) and the division bell. Nothing here exists for
-- players elsewhere on the map.
--
-- * Facade ornament and the Statenhal build while the square is in view; every other zone
--   builds only once a living character is inside, nearest zone first, a few parts a frame.
-- * Leaving, dying or streaming the building out detaches the interior at once and cancels
--   its builder; disposal is paced over later frames. Re-entering starts a fresh build.
-- * The "Parliament performance mode" setting (PlayerSettings) swaps every piece of furniture
--   and every person for a single block and drops the ornament and the chambers' Aura.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local Layout = require(ReplicatedStorage.Shared.ParliamentLayout)
local Geometry = require(ReplicatedStorage.Shared.ParliamentInterior)
local Crowd = require(ReplicatedStorage.Shared.ParliamentCrowd)
local Parties = require(ReplicatedStorage.Shared.Parties)
local DayNight = require(ReplicatedStorage.Shared.DayNight)

local Parliament = {}
local started = false
local PARTS_PER_FRAME, FRAME_BUDGET, CLEANUP_GROUPS = 40, 0.002, 6
-- The ornament appears a little before the square does and goes a little after it.
local NEAR_IN, NEAR_OUT = 380, 440
-- The interior is lit for its own mood; the eye adjusts a little on the way in.
local INSIDE_EXPOSURE = -0.25
local RIGS_PER_FRAME = 8
local PLAN_SECONDS = 0.5
local BELL_SOUND = "rbxasset://sounds/electronicpingshort.wav"
local F, A, V = CFrame.new, CFrame.Angles, Vector3.new
local SUIT_LEGS = Color3.fromRGB(38, 40, 48)
local LAMP_OFF, LAMP_ON = Color3.fromRGB(120, 96, 60), Color3.fromRGB(255, 176, 46)
local VOTE_IDLE, VOTE_YES, VOTE_NO = Color3.fromRGB(53, 114, 179), Color3.fromRGB(72, 208, 112), Color3.fromRGB(226, 70, 70)

local listeners = {}
local insideAny = false

-- Called with (phase, motion) as a division moves through "Bell", "Vote", "Result" and "Over",
-- only while the local player is in the building. client/ParliamentBallot shows the banner.
function Parliament.onDivision(callback)
	table.insert(listeners, callback)
end
function Parliament.isInside(): boolean
	return insideAny
end

local function election()
	local folder = ReplicatedStorage:FindFirstChild("Election")
	local info = { Seats = nil :: { [string]: number }?, Votes = {}, Governing = nil :: string?, PollsOpen = false, BellAt = nil :: number?, Key = "" }
	if not folder then
		return info
	end
	local governing = folder:GetAttribute("Governing")
	info.Governing = if type(governing) == "string" and Parties.ById[governing] then governing else nil
	info.PollsOpen = folder:GetAttribute("PollsOpen") == true
	local bellAt = folder:GetAttribute("BellAt")
	info.BellAt = if type(bellAt) == "number" then bellAt else nil
	local seats, total, key = {}, 0, { info.Governing or "-" }
	for _, party in Parties.List do
		local count = folder:GetAttribute("S_" .. party.Id)
		seats[party.Id] = if type(count) == "number" then count else 0
		total += seats[party.Id]
		table.insert(key, tostring(seats[party.Id]))
		local votes = folder:GetAttribute("V_" .. party.Id)
		info.Votes[party.Id] = if type(votes) == "number" then votes else 0
	end
	if total > 0 then
		info.Seats = seats
	end
	info.Key = table.concat(key, ",")
	return info
end

-- Fills the hall's seat board: one bar per party, the governing party or the next election.
local function showSeats(board, info, elapsed: number)
	if not board then
		return
	end
	local seats = info.Seats or Parties.seats(nil)
	local most = 1
	for _, party in Parties.List do
		most = math.max(most, seats[party.Id] or 0)
	end
	for _, party in Parties.List do
		local count = seats[party.Id] or 0
		local fill, label = board.Fills[party.Id], board.Counts[party.Id]
		local size = UDim2.fromScale(count / most, 1)
		if fill.Size ~= size then
			fill.Size = size
		end
		if label.Text ~= tostring(count) then
			label.Text = tostring(count)
		end
	end
	local governing = info.Governing and Parties.ById[info.Governing]
	local footer = if governing then "Governing: " .. governing.Name .. "  ·  " .. governing.Policy.Text else (Parties.statusLine(elapsed))
	if board.Footer.Text ~= footer then
		board.Footer.Text = footer
	end
end

---------------------------------------------------------------------------------------------------
-- People

local function limb(model, name, size, color, shape)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Color, p.Material = name, size, color, Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

local function buildRig(person, lite: boolean)
	local model = Instance.new("Model")
	model.Name = person.Role
	local parts
	if lite then
		parts = { limb(model, "Body", V(1.8, 4.6, 1), person.Color) }
	else
		local sleeve = person.Color:Lerp(Color3.new(0, 0, 0), 0.18)
		parts = {
			limb(model, "Torso", V(1.8, 2, 0.9), person.Color),
			limb(model, "Head", V(1.25, 1.25, 1.25), person.Skin, Enum.PartType.Ball),
			limb(model, "Hair", V(1.3, 0.45, 1.3), person.Hair),
			limb(model, "LeftLeg", V(0.8, 2, 0.8), SUIT_LEGS),
			limb(model, "RightLeg", V(0.8, 2, 0.8), SUIT_LEGS),
			limb(model, "LeftArm", V(0.6, 1.9, 0.7), sleeve),
			limb(model, "RightArm", V(0.6, 1.9, 0.7), sleeve),
		}
	end
	return { model = model, parts = parts }
end

-- Appends this person's part frames for the pose they are in.
local function pose(person, rig, root: CFrame, lite: boolean, parts, frames)
	local sitting = person.Pose == "Sit"
	local function put(index, frame)
		table.insert(parts, rig.parts[index])
		table.insert(frames, frame)
	end
	if lite then
		put(1, root * F(0, if sitting then 2.9 else 2.3, 0))
		return
	end
	if sitting then
		put(1, root * F(0, 3, 0.1))
		put(2, root * F(0, 4.6, 0.1))
		put(3, root * F(0, 5.17, 0.15))
		for index, side in { -1, 1 } do
			put(3 + index, root * F(side * 0.45, 2.25, -0.85) * A(math.pi / 2, 0, 0))
			put(5 + index, root * F(side * 1.2, 3.85, 0.1) * A(1.15, 0, 0) * F(0, -0.9, 0))
		end
		return
	end
	local swing = if person.Points then math.sin(person.Phase or 0) * 0.7 else 0
	put(1, root * F(0, 3, 0))
	put(2, root * F(0, 4.62, 0))
	put(3, root * F(0, 5.19, 0.05))
	for index, side in { -1, 1 } do
		put(3 + index, root * F(side * 0.45, 2, 0) * A(side * swing, 0, 0) * F(0, -1, 0))
		put(5 + index, root * F(side * 1.2, 3.9, 0) * A(-side * swing, 0, 0) * F(0, -0.9, 0))
	end
end

---------------------------------------------------------------------------------------------------

function Parliament.start()
	if started then
		return
	end
	started = true
	local player, records, retired = Players.LocalPlayer, {}, {}
	local bell = Instance.new("Sound")
	bell.Name, bell.SoundId, bell.Volume, bell.PlaybackSpeed = "ParliamentDivisionBell", BELL_SOUND, 0.55, 0.82
	bell:SetAttribute("AudioCategory", "Effects")
	bell.Parent = SoundService
	local lastRing, lastPhase, lastDivision = -math.huge, nil, nil
	local frameCount = 0

	local function retire(folder: Instance?)
		if not folder then
			return
		end
		-- Detaching hides everything immediately; disposal is spread over frames.
		folder.Parent = nil
		local groups = {}
		for _, item in folder:GetDescendants() do
			if item:IsA("Model") then
				table.insert(groups, item)
			end
		end
		table.insert(retired, { folder = folder, children = groups, cursor = 1 })
	end

	local function stopCrowd(record)
		if record.people then
			retire(record.people)
		end
		record.people, record.crowd, record.rigs, record.planKey, record.rosterKey = nil, nil, nil, nil, nil
	end

	local function finishZone(record)
		record.builder = nil
		record.buildingSide = nil
	end
	-- Hides one side's zones and cancels its builder, if that is the one running.
	local function unloadSide(record, side)
		if record.buildingSide == side then
			finishZone(record)
		end
		retire(side.root)
		side.root, side.ctx, side.zones = nil, nil, {}
	end
	local function unloadInterior(record)
		unloadSide(record, record.inner)
		stopCrowd(record)
		record.inside, record.voted, record.lampLit = false, nil, nil
	end
	local function unload(record)
		unloadInterior(record)
		unloadSide(record, record.outer)
		record.near = false
	end

	local function added(building)
		if not records[building] then
			records[building] = {
				zoneList = Geometry.zones(),
				inner = { name = "LocalParliamentInterior", zones = {} },
				outer = { name = "LocalParliamentExterior", zones = {} },
			}
		end
	end
	local function removed(building)
		if records[building] then
			unload(records[building])
			records[building] = nil
		end
	end
	CollectionService:GetInstanceAddedSignal(Layout.Tag):Connect(added)
	CollectionService:GetInstanceRemovedSignal(Layout.Tag):Connect(removed)
	for _, building in CollectionService:GetTagged(Layout.Tag) do
		added(building)
	end

	-- Starts the nearest zone that is wanted and not yet built.
	local function nextZone(building, record, frame: CFrame, lite: boolean, position: Vector3)
		local best, bestDistance
		for _, zone in record.zoneList do
			local side = if zone.Outside then record.outer else record.inner
			if not side.zones[zone.Name] and (zone.Outside or record.inside) then
				local distance = (frame * zone.Centre - position).Magnitude
				if not best or distance < bestDistance then
					best, bestDistance = zone, distance
				end
			end
		end
		if not best then
			return
		end
		local side = if best.Outside then record.outer else record.inner
		if not side.root then
			side.root = Instance.new("Folder")
			side.root.Name, side.root.Parent = side.name, building
			side.ctx = Geometry.context(frame, coroutine.yield, lite)
		end
		side.zones[best.Name] = true
		record.buildingSide = side
		record.builder = coroutine.create(function()
			Geometry.buildZone(side.ctx, side.root, best)
		end)
	end

	local function updateCrowd(building, record, frame: CFrame, lite: boolean, info, elapsed: number, dt: number, calling: boolean)
		record.planClock = (record.planClock or PLAN_SECONDS) + dt
		local rosterKey = info.Key .. (if lite then "L" else "D")
		if record.rosterKey ~= rosterKey then
			stopCrowd(record)
			record.rosterKey = rosterKey
			record.roster = Crowd.roster(info.Seats, info.Governing, lite)
			record.people = Instance.new("Folder")
			record.people.Name, record.people.Parent = "LocalParliamentPeople", building
			record.rigs, record.planClock = {}, PLAN_SECONDS
		end
		if record.planClock >= PLAN_SECONDS then
			record.planClock = 0
			local block, hour = Crowd.blockAt(elapsed)
			local key = tostring(block) .. (if calling then "B" else "-") .. (if info.PollsOpen then "P" else "-")
			if key ~= record.planKey then
				record.planKey = key
				local plan = Crowd.assign(record.roster, block, hour, calling, info.PollsOpen)
				if record.crowd then
					Crowd.retarget(record.crowd, plan)
				else
					record.crowd = Crowd.new(record.roster, plan)
				end
			end
		end
		local crowd = record.crowd
		if not crowd then
			return
		end
		Crowd.step(crowd, dt, calling)
		-- Blocks update on alternate frames; nobody reads their stride.
		local moveWalkers = not lite or frameCount % 2 == 0
		local parts, frames, built = {}, {}, 0
		for _, person in crowd.People do
			local rig = record.rigs[person]
			if person.Pose == "Away" then
				if rig and rig.model.Parent then
					rig.model.Parent = nil
				end
				person.Changed = false
				continue
			end
			if not rig then
				if built >= RIGS_PER_FRAME then
					continue
				end
				built += 1
				rig = buildRig(person, lite)
				record.rigs[person] = rig
				person.Changed = true
			end
			if (person.Points and moveWalkers) or person.Changed then
				pose(person, rig, frame * F(person.Position) * A(0, person.Yaw, 0), lite, parts, frames)
				person.Changed = false
				if not rig.model.Parent then
					rig.model.Parent = record.people
				end
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end

	local function setText(label, text: string)
		if label and label.Text ~= text then
			label.Text = text
		end
	end

	-- Bell lamps, the benches' voting lights and the chamber's boards.
	local function showDivision(record, phase: string?, since: number, number: number?, motion)
		local dynamic = record.inner.ctx and record.inner.ctx.dynamic
		if not dynamic then
			return
		end
		local lit = phase == "Bell" and math.floor(since * 4) % 2 == 0
		if record.lampLit ~= lit then
			record.lampLit = lit
			for _, lamp in dynamic.BellLamps do
				lamp.Color, lamp.Material = if lit then LAMP_ON else LAMP_OFF, if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
			end
		end
		local board = ""
		if phase == "Bell" then
			board = "DIVISION\n" .. motion.Title
		elseif phase == "Vote" then
			board = "VOTING\n" .. motion.Title
		elseif phase == "Result" then
			board = string.format("%s\nAYES %d  ·  NOES %d\n%s", motion.Title, motion.For, motion.Against, if motion.Adopted then "CARRIED" else "REJECTED")
		end
		setText(dynamic.Labels.VoteBoardWest, board)
		setText(dynamic.Labels.VoteBoardEast, board)
		local voting = phase == "Vote" or phase == "Result"
		local wanted = if voting then number else nil
		if record.voted ~= wanted and record.crowd then
			record.voted = wanted
			for _, person in record.crowd.People do
				local light = person.Seat and dynamic.VoteLights[person.Seat.Id]
				if light then
					local seated = voting and person.Pose == "Sit" and person.Target == person.Seat
					if seated then
						local yes = Parties.hash(person.Index, number :: number) < motion.Share
						light.Color, light.Material = if yes then VOTE_YES else VOTE_NO, Enum.Material.Neon
					else
						light.Color, light.Material = VOTE_IDLE, Enum.Material.SmoothPlastic
					end
				end
			end
		end
	end

	local boardClock = 1
	local info, infoClock = nil, 0
	RunService.Heartbeat:Connect(function(dt)
		dt = math.min(dt or 1 / 60, 0.25)
		frameCount += 1
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local lite = player:GetAttribute("ParliamentPerformanceMode") == true
		local elapsed = DayNight.elapsed()
		infoClock += dt
		if not info or infoClock >= PLAN_SECONDS then
			info, infoClock = election(), 0
		end
		local start, number = Parties.division(elapsed, info.BellAt)
		local since = if start then elapsed - start else 0
		local phase = if not start then nil elseif since < Parties.BELL.Ring then "Bell" elseif since < Parties.BELL.Vote then "Bell" elseif since < Parties.BELL.Result then "Vote" else "Result"
		local motion = if number then Parties.motion(number) else nil
		boardClock += dt
		local refreshBoards = boardClock >= 1
		if refreshBoards then
			boardClock = 0
		end
		local anyInside = false
		for building, record in records do
			local frame = building:GetAttribute(Layout.FrameAttribute)
			local alive = root and humanoid and humanoid.Health > 0 and typeof(frame) == "CFrame" and building:IsDescendantOf(workspace)
			local inside = alive and Layout.inside(frame, root.Position)
			local near = alive and (inside or Layout.near(frame, root.Position, if record.near then NEAR_OUT else NEAR_IN))
			if record.lite ~= lite or record.frame ~= frame then
				-- A different look (or a moved building) starts from nothing.
				unload(record)
				record.lite, record.frame = lite, frame
			end
			if not near then
				if record.near then
					unload(record)
				end
				continue
			end
			if record.inside and not inside then
				unloadInterior(record)
			end
			record.inside, record.near = inside, true
			anyInside = anyInside or inside
			if not record.builder then
				nextZone(building, record, frame, lite, root.Position)
			end
			if record.builder then
				local began = os.clock()
				for _ = 1, PARTS_PER_FRAME do
					local ok, problem = coroutine.resume(record.builder)
					if not ok then
						warn("[Parliament] Detail build failed: " .. tostring(problem))
						-- The zone stays marked as built, so it is not retried every frame.
						finishZone(record)
						break
					end
					if coroutine.status(record.builder) == "dead" then
						finishZone(record)
						break
					end
					if os.clock() - began >= FRAME_BUDGET then
						break
					end
				end
			end
			if inside then
				updateCrowd(building, record, frame, lite, info, elapsed, dt, start ~= nil)
				showDivision(record, phase, since, number, motion)
			end
			if refreshBoards then
				local outer, inner = record.outer.ctx, record.inner.ctx
				if outer then
					showSeats(outer.dynamic.SeatBoard, info, elapsed)
				end
			end
		end
		insideAny = anyInside
		-- Ease the exposure towards the interior's level, and back outside.
		local wanted = if anyInside then INSIDE_EXPOSURE else 0
		local exposure = Lighting.ExposureCompensation
		if math.abs(exposure - wanted) > 0.001 and (anyInside or exposure < -0.001) then
			Lighting.ExposureCompensation = exposure + math.clamp(wanted - exposure, -dt * 0.5, dt * 0.5)
		end
		-- The bell is heard, and the banner shown, only inside the building.
		local ringing = anyInside and start ~= nil and since < Parties.BELL.Ring
		if ringing and os.clock() - lastRing >= 0.42 then
			lastRing = os.clock()
			bell:Play()
		end
		local shown = if anyInside then phase else nil
		if since < Parties.BELL.Ring and shown == "Bell" then
			shown = "Ring"
		end
		if shown ~= lastPhase or (shown and number ~= lastDivision) then
			lastPhase, lastDivision = shown, number
			for _, callback in listeners do
				task.spawn(callback, shown or "Over", motion)
			end
		end

		local began, count = os.clock(), 0
		while retired[1] and count < CLEANUP_GROUPS do
			local old = retired[1]
			local child = old.children[old.cursor]
			if child then
				child:Destroy()
				old.cursor += 1
				count += 1
			else
				old.folder:Destroy()
				table.remove(retired, 1)
			end
			if os.clock() - began >= FRAME_BUDGET then
				break
			end
		end
	end)
end
return Parliament
