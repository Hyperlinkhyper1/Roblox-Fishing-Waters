// Execute the actual shell, furnishings, crowd, election rules and occupancy controller
// against recording mocks. Checks geometry, walkable routes, seat counts, the two detail
// modes, the division bell and bounded entry/exit work.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { resolve, join } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = resolve(import.meta.dirname, '..');
const read = async path => (await readFile(join(root, path), 'utf8')).replace(/\r\n/g, '\n');
const mocks = (await read('scripts/check-city.mjs')).match(/const mocks = String.raw`([\s\S]*?)`;/)[1];
const sources = {
  ParliamentLayout: 'src/shared/ParliamentLayout.luau',
  DayNight: 'src/shared/DayNight.luau',
  Calendar: 'src/shared/Calendar.luau',
  Parties: 'src/shared/Parties.luau',
  ParliamentInterior: 'src/shared/ParliamentInterior.luau',
  ParliamentCrowd: 'src/shared/ParliamentCrowd.luau',
  CityLandmark: 'src/server/Map/CityLandmark.luau',
  Renderer: 'src/client/Parliament.luau',
};
let program = 'local output = print\n' + mocks + String.raw`
local function event()
  local listeners = {}
  return { Connect = function(_, callback) table.insert(listeners, callback); return {Disconnect=function() end} end,
    Fire = function(_, ...) for _, callback in listeners do callback(...) end end }
end
local heartbeat, added, removed = event(), event(), event()
local tagged = {}
local function token(name)
  return setmetatable({__module=name}, {__index=function(_, key) return token(key) end})
end
local storage, sounds, player = Instance.new('Folder'), Instance.new('Folder'), Instance.new('Player')
storage.Shared = token('Shared')
local clock = 1767225600 + 5 * 1440 + 13 * 60
workspace.GetServerTimeNow = function() return clock end
local moved = 0
function methods:BulkMoveTo(parts, frames)
  for index, p in parts do p.CFrame = frames[index]; moved += 1 end
end
local rings = 0
function methods:Play() rings += 1 end
local oldService = game.GetService
game.GetService = function(self, name)
  if name == 'ReplicatedStorage' then return storage end
  if name == 'SoundService' then return sounds end
  if name == 'Players' then return {LocalPlayer=player} end
  if name == 'RunService' then return {Heartbeat=heartbeat} end
  if name == 'CollectionService' then return {
    GetTagged=function() return tagged end,
    GetInstanceAddedSignal=function() return added end,
    GetInstanceRemovedSignal=function() return removed end,
  } end
  return oldService(self, name)
end
local loaded, loaders = {}, {}
local function require(target)
  if not loaded[target.__module] then loaded[target.__module] = loaders[target.__module]() end
  return loaded[target.__module]
end
local script = token('script')
`;
for (const [name, path] of Object.entries(sources)) program += `loaders.${name} = function()\n${await read(path)}\nend\n`;
program += String.raw`
local Layout, Geometry = require(token('ParliamentLayout')), require(token('ParliamentInterior'))
local Parties, Crowd, Calendar = require(token('Parties')), require(token('ParliamentCrowd')), require(token('Calendar'))
local map = Instance.new('Folder'); map.Parent = workspace
local base = CFrame.new(7319.5, 8.9, 6752)
local building = require(token('CityLandmark')).build(map, base)
table.insert(tagged, building)

-- 1. The shell every player receives.
check(building:HasTag(Layout.Tag), 'The parliament is discoverable after streaming')
check(building:GetAttribute(Layout.FrameAttribute) == base, 'The occupancy frame matches the shell')
local roles, rooms, ids, special, permanentParts = {}, {}, {}, 0, 0
local bells, ballots = 0, 0
for _, p in building:GetDescendants() do
  if p:IsA('Seat') then
    local role, room = p:GetAttribute('SeatRole'), p:GetAttribute('ParliamentRoom')
    roles[role] = (roles[role] or 0) + 1
    rooms[room] = (rooms[room] or 0) + 1
    check(not ids[p.Name], 'Seat IDs are unique'); ids[p.Name] = p
    check(p.Anchored and p.CanTouch and p.Transparency == 1, 'Real seats work without rendering outside')
    if p:GetAttribute('SpecialSeat') then
      special += 1
      check(room == 'Council' and role == 'Chairperson', 'The special seat belongs to the cabinet chair')
    end
  elseif p:IsA('BasePart') then
    permanentParts += 1
    check(p.Name ~= 'SeatCushion' and p.Name ~= 'OakMemberDesk' and p.Name ~= 'MicrophoneStem', 'Furnishings never replicate from the server')
    if p:HasTag(Layout.BellTag) then bells += 1; check(p:FindFirstChildOfClass('ProximityPrompt'), 'The division bell can be rung') end
    if p:HasTag(Layout.BallotTag) then ballots += 1; check(p:FindFirstChildOfClass('ProximityPrompt'), 'Every booth opens the ballot') end
  end
end
check(roles.Member == 150 and roles.Speaker == 1, 'The Tweede Kamer has 150 members and its Speaker')
check(roles.Minister == 13, 'Vak K seats the cabinet beside the Speaker')
check(roles.Senator == 75 and roles.President == 1, 'The Eerste Kamer has 75 senators and its President')
check(rooms.Council == 9 and special == 1, 'Exactly nine cabinet seats with exactly one special seat')
check(rooms.Tribune == 30, 'The public gallery has thirty seats')
check(bells == 1 and ballots == 4, 'One division bell and four voting booths')
for _, model in building:GetChildren() do
  local n = 0
  for _, p in model:GetDescendants() do if p:IsA('BasePart') then n += 1 end end
  check(model:HasTag('LodPiece') and n <= 200, 'Parliament streaming pieces remain small: '..model.Name..' '..n)
end
check(permanentParts < 1100, 'The shell stays light: '..permanentParts)
local vak = Layout.VakK
for _, entry in Layout.Seats do
  if entry.Role == 'Minister' then
    check(entry.Angle >= vak.From and entry.Angle <= vak.To and entry.Angle > 90, 'Vak K sits beside the Speaker, facing the house')
  end
end

-- 2. Every link of the walking graph fits an avatar and has a floor under it.
local solids = {}
for _, p in building:GetDescendants() do if p:IsA('BasePart') and p.CanCollide then table.insert(solids, p) end end
local function blocked(position)
  for _, h in {1.6, 3, 4.6} do
    local world = base * (position + Vector3.new(0, h, 0))
    for _, p in solids do
      local q = p.CFrame:PointToObjectSpace(world)
      if math.abs(q.X) < p.Size.X/2 + 0.9 and math.abs(q.Y) < p.Size.Y/2 + 0.9 and math.abs(q.Z) < p.Size.Z/2 + 0.9 then return p end
    end
  end
  return nil
end
local function supported(position)
  local world = base * (position - Vector3.new(0, 0.5, 0))
  for _, p in solids do
    local q = p.CFrame:PointToObjectSpace(world)
    if math.abs(q.X) < p.Size.X/2 + 0.3 and math.abs(q.Y) < p.Size.Y/2 + 0.75 and math.abs(q.Z) < p.Size.Z/2 + 0.3 then return true end
  end
  return false
end
local links, nodes = 0, 0
for a, list in Layout.Links do
  nodes += 1
  check(Layout.route('Out', a), 'Every node can be reached from the square: '..a)
  for _, b in list do
    if a < b then
      links += 1
      local pa, pb = Layout.Nodes[a], Layout.Nodes[b]
      local steps = math.max(2, math.ceil((pb - pa).Magnitude / 0.75))
      for step = 0, steps do
        local p = pa:Lerp(pb, step / steps)
        local blocker = blocked(p)
        check(not blocker, 'A walk is blocked between '..a..' and '..b..': '..(blocker and blocker.Name or ''))
        check(p.Z > Layout.Front or supported(p), 'A walk has no floor between '..a..' and '..b)
      end
    end
  end
end
-- From the square through the entrance, up both stairs and into both chambers.
for _, goal in {'Well', 'EKAisleN', 'EKGallery', 'Trib0', 'CE2_-55', 'CW2_14', 'In:E0A', 'R2_0'} do
  check(Layout.route('Out', goal), 'A visitor can walk to '..goal)
end
local wingRooms, kinds, partyRooms = 0, {}, {}
for _, room in Layout.Rooms do
  kinds[room.Kind] = (kinds[room.Kind] or 0) + 1
  if room.Doors then
    wingRooms += 1
    check(Layout.Nodes['In:'..room.Id], 'Every room has a door on the graph: '..room.Id)
  end
  if room.Party then partyRooms[room.Party] = true end
  for _, spot in room.Spots do
    check(Layout.Nodes[spot.Node], 'Every place is reached from a real node: '..room.Id)
    if room.Doors then
      local q = room.Frame:PointToObjectSpace(spot.Position)
      check(math.abs(q.X) <= room.HalfU and math.abs(q.Z) <= room.HalfW, 'Places stay inside their room: '..room.Id)
    end
  end
end
check(wingRooms >= 20, 'The wings hold at least twenty rooms besides the chambers')
check(kinds.Committee == 4 and kinds.Fractie == #Parties.List, 'Committee rooms and one room per party')
for _, kind in {'Restaurant', 'Kitchen', 'Cafe', 'Voting', 'Library', 'Press', 'Council', 'Speaker', 'Lounge', 'Office', 'Security', 'Mail', 'Exhibition'} do
  check(kinds[kind] == 1, 'The building has its '..kind)
end
for index in Parties.List do check(partyRooms[index], 'Every party has its own room') end
for _, entry in Layout.Seats do
  check(Layout.Nodes[entry.Node] and entry.Kind == 'Sit', 'Every seat can be walked to: '..entry.Id)
end
-- Both radial aisles, across every tier, without jumping over a desk.
for _, angle in Layout.Aisles do
  for radius = 11, 40.5, 0.5 do
    local position = Layout.polar(angle, radius)
    local floor = 0
    for _, p in building:GetDescendants() do
      if p.Name ~= 'CarpetedTier' then continue end
      local q = p.CFrame:PointToObjectSpace(base * position)
      if math.abs(q.X) <= p.Size.X/2 and math.abs(q.Z) <= p.Size.Z/2 then
        floor = math.max(floor, p.Position.Y - base.Position.Y + p.Size.Y/2)
      end
    end
    local blocker = blocked(position + Vector3.new(0, floor, 0))
    check(not blocker or blocker.Name == 'CarpetedTier', 'Radial aisles fit an avatar at '..angle..' degrees, radius '..radius..': '..(blocker and blocker.Name or ''))
  end
end
for _, tier in Layout.Tiers do
  for _, x in {-1,1} do for _, z in {-1,1} do
    local corner = tier.Frame * Vector3.new(x*tier.Size.X/2,0,z*tier.Size.Z/2)
    check((corner - Layout.Focus).Magnitude < Layout.DrumRadius, 'Tier corners remain within the drum')
  end end
end
local rotated = base * CFrame.Angles(0, 0.73, 0)
for _, p in { Vector3.new(0,3,58), Vector3.new(0,3,-20), Vector3.new(60,27,-50), Vector3.new(-60,15,-40), Vector3.new(30,3,45) } do
  check(Layout.inside(rotated, rotated * p), 'Entry detection uses building coordinates')
end
for _, p in { Vector3.new(0,3,63), Vector3.new(73,3,0), Vector3.new(60,3,48), Vector3.new(0,50,0), Vector3.new(0,-5,0), Vector3.new(0,3,-66) } do
  check(not Layout.inside(rotated, rotated*p), 'Street, forecourt, dome and underground never load furniture')
end

-- 3. Furnishings: detailed, and the Performance setting's single blocks.
local function census(folder)
  local parts, auras, beams, dust, crest, stations = 0, 0, 0, 0, 0, 0
  for _, p in folder:GetDescendants() do
    if p:IsA('BasePart') then
      parts += 1
      check(not p.CanCollide and not p.CanTouch and not p.CanQuery and not p.CastShadow, 'Local furniture is visual only')
      if p.Name == 'ChairpersonGoldCrest' then crest += 1 end
    elseif p:IsA('Model') then
      if p:GetAttribute('Aura') then auras += 1 end
      if p:GetAttribute('SeatId') then stations += 1 end
    elseif p:IsA('Beam') then beams += 1
    elseif p:IsA('ParticleEmitter') then dust += 1 end
  end
  return parts, auras, beams, dust, crest, stations
end
local detail = Instance.new('Folder')
local detailed = Geometry.build(detail, base)
local detailParts, auras, beams, dust, goldChair, stations = census(detail)
local furnished = 0
for _, model in detail:GetDescendants() do
  local id = model:IsA('Model') and model:GetAttribute('SeatId')
  if id then
    local cushion = model:FindFirstChild('SeatCushion')
    check(ids[id] and cushion and (cushion.Position - ids[id].Position).Magnitude < 0.001, 'Visible cushions match real server seats: '..id)
    furnished += 1
  end
end
check(furnished == 150 + 13 + 1 + 75 + 1 + 9, 'Every member, minister, senator and cabinet seat gets furniture')
check(goldChair == 1, 'Only the cabinet chair gets a gold crest')
check(auras == 2 and beams == 16 and dust == 2, 'Both chambers hold an Aura: light shafts and drifting dust')
local auraNames = {}
for _, model in detail:GetDescendants() do
  if model:IsA('Model') and model:GetAttribute('Aura') then
    auraNames[model:GetAttribute('Aura')] = true
    check(model.Name == 'Aura', 'The Aura is named as such')
  end
end
check(auraNames['Tweede Kamer'] and auraNames['Eerste Kamer'], 'The Aura belongs to the Tweede and the Eerste Kamer')
check(detailParts > 7000 and detailParts < 10500, 'The building is richly detailed within a bounded part count: '..detailParts)
check(detailed.dynamic.Labels.ElectionBoard and detailed.dynamic.Labels.VoteBoardWest and detailed.dynamic.Labels.BallotBoard, 'Boards the client keeps current exist')
check(#detailed.dynamic.BellLamps >= 10, 'Bell lamps hang in every corridor')
local simple = Instance.new('Folder')
local performance = Geometry.build(simple, base, nil, { Performance = true })
local simpleParts, simpleAuras, simpleBeams, simpleDust, _, simpleStations = census(simple)
check(simpleAuras == 0 and simpleBeams == 0 and simpleDust == 0, 'Performance mode has no Aura')
check(simpleStations == stations, 'Performance mode keeps every seat station')
check(simpleParts < 1200 and simpleParts * 7 < detailParts, 'Performance mode removes most detail: '..simpleParts)
for _, model in simple:GetDescendants() do
  if model:IsA('Model') and model:GetAttribute('SeatId') then
    local n = 0
    for _, p in model:GetDescendants() do if p:IsA('BasePart') then n += 1 end end
    check(n <= 2, 'Performance mode draws a seat as a block (and its desk as another)')
  end
end
local zoneNames = {}
for _, zone in Geometry.zones() do
  check(not zoneNames[zone.Name], 'Zone names are unique'); zoneNames[zone.Name] = true
end

-- 4. Parties and the election calendar.
local policyKinds, names = {}, {}
for _, party in Parties.List do
  check(not names[party.Name] and not policyKinds[party.Policy.Kind], 'Every party has its own name and its own policy')
  names[party.Name], policyKinds[party.Policy.Kind] = true, true
  local values = Parties.policies(party.Id)
  local active = 0
  for kind, amount in values do if amount > 0 then active += 1; check(kind == party.Policy.Kind, 'A party enacts only its own policy') end end
  check(active == 1, 'Governing gives exactly one policy')
end
for _, amount in Parties.policies(nil) do check(amount == 0, 'Nobody in office means no policy') end
check(#Parties.List == 6, 'Six parties stand for election')
local function seatTotal(seats) local n = 0 for _, count in seats do n += count end return n end
local landslide = Parties.seats({ VB = 900, VK = 300, GG = 299, RW = 1 })
check(seatTotal(landslide) == 150 and landslide.VB == 90 and landslide.VK == 30 and landslide.RW == 0, 'Seats follow the D\'Hondt method')
check(seatTotal(Parties.seats(nil)) == 150 and Parties.seats({}).GA == 25, 'An empty count splits the house evenly')
check(Parties.winner({ VK = 5, GG = 9, GA = 9 }) == 'GG' and Parties.winner({}) == nil, 'Most votes wins; a tie goes to the party listed first')
local year = Calendar.DAYS_PER_YEAR * Calendar.SECONDS_PER_DAY
check(Parties.state(0).Term == 1 and Parties.state(4 * year - 1).Term == 1 and Parties.state(4 * year).Term == 2, 'A term lasts four in-game years')
check(Parties.termStart(2) == 4 * year, 'Terms start on 1 January')
local opens = Calendar.elapsedAt(4, 9, 1, 0)
check(not Parties.state(opens - 1).PollsOpen and Parties.state(opens).PollsOpen and Parties.state(4 * year - 1).PollsOpen and not Parties.state(4 * year).PollsOpen,
  'Polls open on 1 September of the fourth year and close when it ends')
check(Parties.state(4 * year).ElectionYear == 8, 'The next election is four years later')
local bell = Parties.BELL
local noon = 3 * Calendar.SECONDS_PER_DAY + 11 * 60
check(Parties.division(noon - 1) == nil and Parties.division(noon) == noon and Parties.division(noon + bell.End) == nil, 'The bell rings by the clock')
check(Parties.division(noon + 300, noon + 290) == noon + 290, 'A hand-rung bell starts a division of its own')
local motion = Parties.motion(41)
check(motion.For + motion.Against == 150 and motion.Adopted == (motion.For > 75) and #motion.Title > 0, 'A division has a subject and a result')

-- 5. The crowd: who is where, and that the bell brings every member to their bench.
local seats = Parties.seats({ VB = 40, VK = 22, PvdS = 18, GG = 35, GA = 20, RW = 15 })
local roster = Crowd.roster(seats, 'GG')
local lightRoster = Crowd.roster(seats, 'GG', true)
local members, perParty, ministers = 0, {}, 0
for _, person in roster do
  if person.Role == 'Member' then
    members += 1
    perParty[person.Party] = (perParty[person.Party] or 0) + 1
    check(person.Color == Parties.List[person.Party].Color, 'Members wear their party colour')
  elseif person.Role == 'Minister' then ministers += 1 end
end
check(members == 150 and ministers == 13, 'All 150 members and the cabinet are on the roster')
for index, party in Parties.List do check(perParty[index] == seats[party.Id], 'The house is divided as the voters decided') end
check(#lightRoster * 2 < #roster, 'Performance mode keeps well under half the crowd: '..#lightRoster..' of '..#roster)
local wedge = {}
for _, person in roster do
  if person.Role == 'Member' then
    local range = wedge[person.Party] or { math.huge, -math.huge }
    range[1], range[2] = math.min(range[1], person.Seat.Angle), math.max(range[2], person.Seat.Angle)
    wedge[person.Party] = range
  end
end
for index = 2, #Parties.List do check(wedge[index][1] >= wedge[index - 1][2], 'Parties sit in wedges across the half circle') end
local function distinct(plan, label)
  local used = {}
  for person, spot in plan do
    if spot ~= Crowd.Outside then
      check(not used[spot], label..': nobody shares a place')
      used[spot] = true
    end
  end
end
local busy = {}
for hour = 0, 22, 2 do
  local plan = Crowd.assign(roster, 500 + hour / 2, hour, false, hour == 14)
  distinct(plan, 'Hour '..hour)
  local present = 0
  for _, spot in plan do if spot ~= Crowd.Outside then present += 1 end end
  busy[hour] = present
end
check(busy[2] < 6 and busy[14] > 200 and busy[22] < busy[14], 'The building empties at night: '..busy[2]..' / '..busy[14]..' / '..busy[22])
local block, hour = Crowd.blockAt(5 * 1440 + 13 * 60)
check(hour == 12, 'Blocks follow the in-game clock')
local lunch = Crowd.assign(roster, block, hour, false, true)
local eating, voters = 0, 0
for _, spot in lunch do
  if spot.Room == 'E0C' then eating += 1 end
  if spot.Role == 'Voter' then voters += 1 end
end
check(eating >= 30, 'Members eat in the restaurant at lunch: '..eating)
check(voters >= 1, 'Visitors use the booths while the polls are open')
local crowd = Crowd.new(roster, lunch)
local calling = Crowd.assign(roster, block, hour, true, true)
distinct(calling, 'Division')
for person, spot in calling do
  if person.Role == 'Member' or person.Role == 'Minister' or person.Role == 'Speaker' then
    check(spot == person.Seat, 'The bell calls every member to their own bench, the cabinet to vak K')
  end
end
Crowd.retarget(crowd, calling)
local walkingAtStart = 0
for _, person in roster do if person.Points then walkingAtStart += 1 end end
check(walkingAtStart > 80, 'The bell sets the building in motion: '..walkingAtStart)
local seconds, walking = 0, walkingAtStart
while walking > 0 and seconds < 120 do
  walking = Crowd.step(crowd, 0.1, true)
  seconds += 0.1
  for _, person in roster do
    if person.Points then
      local p = person.Position
      check(math.abs(p.X) < Layout.HalfWidth and p.Z > Layout.North and p.Z < 80 and p.Y > -0.1 and p.Y < 26, 'Walkers stay in the building')
    end
  end
end
check(seconds <= bell.Vote, string.format('Everyone is seated before the vote (%.1fs of %ds)', seconds, bell.Vote))
for _, person in roster do
  if person.Role == 'Member' then
    check(person.Pose == 'Sit' and (person.Position - person.Seat.Position).Magnitude < 0.001, 'Members end up on their own bench')
  end
end
-- Changing course mid-walk never strands anyone.
Crowd.retarget(crowd, lunch)
for _ = 1, 40 do Crowd.step(crowd, 0.1) end
Crowd.retarget(crowd, calling)
seconds = 0
while Crowd.step(crowd, 0.1, true) > 0 and seconds < 120 do seconds += 0.1 end
check(seconds < 60, 'A second bell mid-walk still seats everyone')

-- 6. The local controller: entry, exit, the two modes and the bell.
local electionFolder = Instance.new('Folder'); electionFolder.Name = 'Election'; electionFolder.Parent = storage
electionFolder:SetAttribute('Governing', 'GG')
electionFolder:SetAttribute('PollsOpen', true)
for _, party in Parties.List do electionFolder:SetAttribute('S_'..party.Id, seats[party.Id]) end
local newPartCount, maxNew = 0, 0
local oldNew = Instance.new
Instance.new = function(class)
  local p = oldNew(class)
  if p:IsA('BasePart') then newPartCount += 1 end
  return p
end
local function tick(dt)
  newPartCount = 0
  clock += dt or 1/60
  heartbeat:Fire(dt or 1/60)
  maxNew = math.max(maxNew, newPartCount)
  check(newPartCount <= 40 + 8 * 7, 'At most 40 furniture parts and 8 people per frame')
end
local function count(folder)
  local n = 0
  if folder then for _, p in folder:GetDescendants() do if p:IsA('BasePart') then n += 1 end end end
  return n
end
local character = Instance.new('Model')
local rootPart = Instance.new('Part'); rootPart.Name = 'HumanoidRootPart'; rootPart.Parent = character
local humanoid = Instance.new('Humanoid'); humanoid.Health = 100; humanoid.Parent = character
player.Character = character
rootPart.Position = base * Vector3.new(0,3,600)
local renderer = require(token('Renderer')); renderer.start(); renderer.start()
local phases = {}
renderer.onDivision(function(phase, motion) table.insert(phases, phase) end)
for _ = 1, 5 do tick() end
check(not building:FindFirstChild('LocalParliamentExterior') and not building:FindFirstChild('LocalParliamentInterior'), 'Nothing is built far from the square')
rootPart.Position = base * Vector3.new(0,3,120)
local guard, idle = 0, 0
repeat
  tick(); guard += 1
  idle = if newPartCount == 0 then idle + 1 else 0
until guard > 2000 or idle >= 6
local outside = building:FindFirstChild('LocalParliamentExterior')
check(outside and outside:FindFirstChild('Exterior') and outside:FindFirstChild('Statenhal'), 'The facade ornament and the hall show from the square')
check(not building:FindFirstChild('LocalParliamentInterior') and not building:FindFirstChild('LocalParliamentPeople'), 'No rooms or people are built outside, even at the entrance')
local outsideParts = count(outside)
tick(); check(newPartCount == 0, 'Finished ornament does not rebuild')
check(string.find(detailed.dynamic.Labels.ElectionBoard.Text, 'ZETELVERDELING') ~= nil, 'The seat board has a default text')
rootPart.Position = base * Vector3.new(0,3,58)
tick()
local first = building:FindFirstChild('LocalParliamentInterior')
check(first and newPartCount > 0, 'Rooms start building after crossing the threshold')
check(renderer.isInside(), 'The controller knows the player is inside')
rootPart.Position = base * Vector3.new(0,3,73)
tick()
check(first.Parent == nil and not building:FindFirstChild('LocalParliamentInterior'), 'Leaving immediately hides and cancels a partly built interior')
check(not building:FindFirstChild('LocalParliamentPeople'), 'The people leave with the interior')
check(building:FindFirstChild('LocalParliamentExterior') == outside, 'The ornament stays while the square is in view')
rootPart.Position = base * Vector3.new(0,3,10)
local function settle(limit)
  guard, idle = 0, 0
  repeat
    tick(); guard += 1
    idle = if newPartCount == 0 then idle + 1 else 0
  until guard > limit or idle >= 6
end
settle(6000)
local second = building:FindFirstChild('LocalParliamentInterior')
local people = building:FindFirstChild('LocalParliamentPeople')
check(second ~= first and count(second) + outsideParts == detailParts, 'Re-entry completes every room exactly once: '..(count(second) + outsideParts)..' of '..detailParts)
check(second:FindFirstChild('TweedeKamer') and second:FindFirstChild('EersteKamer') and second:FindFirstChild('RoomE0C'), 'Chambers and rooms are separate zones')
tick(); check(newPartCount == 0, 'Completed furniture does not rebuild while indoors')
local rigs = 0
for _, model in people:GetChildren() do rigs += 1; check(count(model) == 7, 'A detailed person is seven parts') end
check(rigs > 150, 'The building is busy at lunch: '..rigs)
check(moved > 0, 'People are placed in one bulk move')

-- The bell: lamps flash, members walk, the boards show the result.
local DayNight = require(token('DayNight'))
electionFolder:SetAttribute('BellAt', DayNight.elapsed() + 1)
local lit, walkers = false, 0
for _ = 1, 30 do tick(0.1) end
for _, model in second:GetDescendants() do
  if model.Name == 'BellLamp' and model.Material == Enum.Material.Neon then lit = true end
end
moved = 0
tick(0.1)
check(moved > 100, 'Members walk to the chamber when the bell rings: '..moved)
check(rings > 0, 'The bell is heard inside')
local sawLamp = lit
for _ = 1, 40 do
  tick(0.1)
  for _, model in second:GetDescendants() do
    if model.Name == 'BellLamp' and model.Material == Enum.Material.Neon then sawLamp = true end
  end
end
check(sawLamp, 'Corridor lamps flash while the bell rings')
for _ = 1, 560 do tick(0.1) end
local board
for _, item in second:GetDescendants() do
  if item:IsA('TextLabel') and string.find(item.Text or '', 'VOOR %d+') then board = item.Text end
end
check(board and (string.find(board, 'AANGENOMEN') or string.find(board, 'VERWORPEN')), 'The chamber boards show the result')
local green = 0
for _, item in second:GetDescendants() do
  if item.Name == 'VoteLight' and item.Material == Enum.Material.Neon then green += 1 end
end
check(green >= 150, 'Every seated member\'s desk shows a vote: '..green)
check(phases[1] == 'Ring' and table.find(phases, 'Vote') and table.find(phases, 'Result'), 'Listeners follow the division')
for _ = 1, 400 do tick(0.1) end
check(phases[#phases] == 'Over', 'The division ends')

-- Performance mode rebuilds everything as blocks.
player:SetAttribute('ParliamentPerformanceMode', true)
tick()
check(second.Parent == nil and outside.Parent == nil and people.Parent == nil, 'Switching mode clears the detailed look at once')
settle(3000)
local liteInside, liteOutside, litePeople = building:FindFirstChild('LocalParliamentInterior'), building:FindFirstChild('LocalParliamentExterior'), building:FindFirstChild('LocalParliamentPeople')
check(count(liteInside) + count(liteOutside) == simpleParts, 'Performance mode builds only the blocks: '..(count(liteInside) + count(liteOutside)))
for _, model in litePeople:GetChildren() do check(count(model) == 1, 'A person is one block in performance mode') end
player:SetAttribute('ParliamentPerformanceMode', nil)
tick()
check(liteInside.Parent == nil, 'Switching back clears the blocks')

humanoid.Health = 0; tick()
check(not building:FindFirstChild('LocalParliamentInterior') and not building:FindFirstChild('LocalParliamentPeople'), 'Death unloads the interior')
humanoid.Health = 100; tick()
local third = building:FindFirstChild('LocalParliamentInterior') or building:FindFirstChild('LocalParliamentExterior')
check(third, 'Building restarts for a living character')
removed:Fire(building)
check(third.Parent == nil, 'Streaming removal hides and cancels the current build')
tick(); check(not building:FindFirstChild('LocalParliamentInterior') and not building:FindFirstChild('LocalParliamentExterior'), 'A removed building is not rebuilt')
added:Fire(building); tick()
check(building:FindFirstChild('LocalParliamentInterior') or building:FindFirstChild('LocalParliamentExterior'), 'Streaming return can rebuild normally')
player.Character = nil; tick()
check(not building:FindFirstChild('LocalParliamentInterior') and not building:FindFirstChild('LocalParliamentExterior'), 'Respawn without a character unloads everything')
for _ = 1, 4000 do tick() end
check(first._destroyed and second._destroyed and outside._destroyed and people._destroyed and liteInside._destroyed, 'Retired interiors are eventually destroyed')
for _, line in printed do check(not string.find(line, 'WARN'), 'No warnings: '..line) end
output(string.format('Parliament: %d checks passed; %d permanent parts, %d seats, %d rooms, %d graph links; %d detailed / %d performance local parts; %d people (%d in performance mode); max %d created/frame',
  checks, permanentParts, #Layout.Seats, wingRooms, links, detailParts, simpleParts, #roster, #lightRoster, maxNew))
`;

// Optional geometry dump for a software-rendered architectural preview.
const preview = process.argv.indexOf('--geometry');
if (preview >= 0) program += String.raw`
for _, container in {building, detail} do
  for _, p in container:GetDescendants() do
    if p:IsA('BasePart') then
      local f = base:ToObjectSpace(p.CFrame)
      local shape = if p.Shape == Enum.PartType.Cylinder then 'cylinder' elseif p.Shape == Enum.PartType.Ball then 'sphere' else 'block'
      output('@'..p.Name..'|'..shape..'|'..tostring(p.Material)..'|'..tostring(p.Transparency)..'|'..string.format('%f,%f,%f',p.Color.R,p.Color.G,p.Color.B)..'|'..string.format('%f,%f,%f',p.Size.X,p.Size.Y,p.Size.Z)..'|'..string.format('%f,%f,%f',f.Position.X,f.Position.Y,f.Position.Z)..'|'..string.format('%f,%f,%f',f.RightVector.X,f.RightVector.Y,f.RightVector.Z)..'|'..string.format('%f,%f,%f',f.UpVector.X,f.UpVector.Y,f.UpVector.Z)..'|'..string.format('%f,%f,%f',f.ZVector.X,f.ZVector.Y,f.ZVector.Z))
    end
  end
end
`;
const temp = await mkdtemp(join(tmpdir(), 'parliament-'));
try {
  const path = join(temp, 'check.luau');
  await writeFile(path, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', path], {cwd:root, encoding:'utf8', timeout:300000, maxBuffer:1<<28});
  if (result.error) throw result.error;
  const lines = (result.stdout || '').split(/\r?\n/);
  for (const line of lines) if (line && !line.startsWith('@')) console.log(line);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.status) throw new Error('Parliament checks failed');
  if (preview >= 0) {
    const vector = text => text.split(',').map(Number);
    const parts = lines.filter(line=>line.startsWith('@')).map(line=>{
      const [name,shape,material,transparency,color,size,position,right,up,back] = line.slice(1).split('|');
      return {name,shape,material,transparency:Number(transparency),color:vector(color).map(n=>n*255),size:vector(size),position:vector(position),axes:[right,up,back].map(vector)};
    });
    await writeFile(resolve(process.argv[preview+1]), JSON.stringify(parts));
  }
} finally {
  if (resolve(temp, '..') !== resolve(tmpdir())) throw new Error('Unexpected temporary directory');
  await rm(temp, {recursive:true,force:true});
}
