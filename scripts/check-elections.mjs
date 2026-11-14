// Runs the real ElectionService against recording mocks: one vote per angler per term from
// the Stemlokaal, the count across a term change, the governing party's policy and the bell.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { resolve, join } from 'node:path';
import { spawnSync } from 'node:child_process';
const root = resolve(import.meta.dirname, '..');
const read = async p => (await readFile(join(root, p), 'utf8')).replace(/\r\n/g, '\n');
const mocks = (await read('scripts/check-city.mjs')).match(/const mocks = String.raw`([\s\S]*?)`;/)[1];
let program = 'local output = print\n' + mocks + String.raw`
local function token(name) return setmetatable({__module=name}, {__index=function(_, key) return token(key) end}) end
local function event()
  local listeners = {}
  return { Connect = function(_, callback) table.insert(listeners, callback) end, Fire = function(_, ...) for _, c in listeners do c(...) end end }
end
local storage = Instance.new("Folder"); storage.Shared = token("Shared")
local clock = 1767225600
workspace.GetServerTimeNow = function() return clock end
local player = Instance.new("Player"); player.Name = "Tester"
local playersService = { PlayerRemoving = event() }
player._parent = playersService
local tagged = { CityParliament = {}, ParliamentBell = {} }
local profile = {}
local loops, closers = {}, {}
task.spawn = function(f, ...) table.insert(loops, coroutine.create(f)) end
task.wait = function(n) coroutine.yield(); return n end
game.GetService = function(self, name)
  if name == "ReplicatedStorage" then return storage end
  if name == "Players" then return playersService end
  if name == "RunService" then return { IsStudio = function() return true end } end
  if name == "DataStoreService" then return {} end
  if name == "CollectionService" then return {
    GetTagged = function(_, tag) return tagged[tag] or {} end,
    GetInstanceAddedSignal = function() return event() end,
  } end
  return {}
end
game.GameId = 0
game.BindToClose = function(_, f) table.insert(closers, f) end
local loaded, loaders = {}, {}
local function require(target)
  if not loaded[target.__module] then loaded[target.__module] = loaders[target.__module]() end
  return loaded[target.__module]
end
local script = token("script")
loaders.BoatService = function() return {
  getProfile = function() return profile end,
  updateProgress = function(_, transform) local ok, problem = pcall(transform, profile); return ok, ok and "" or tostring(problem) end,
} end
`;
for (const [name, path] of Object.entries({ParliamentLayout:'src/shared/ParliamentLayout.luau', DayNight:'src/shared/DayNight.luau', Calendar:'src/shared/Calendar.luau', Parties:'src/shared/Parties.luau', ElectionService:'src/server/ElectionService.luau'}))
  program += `loaders.${name} = function()\n${await read(path)}\nend\n`;
program += String.raw`
local Layout, Parties, Calendar = require(token("ParliamentLayout")), require(token("Parties")), require(token("Calendar"))
local base = CFrame.new(7319.5, 8.9, 6752)
local building = Instance.new("Model"); building:SetAttribute(Layout.FrameAttribute, base)
table.insert(tagged.CityParliament, building)
local bellHolder = Instance.new("Part"); local prompt = Instance.new("ProximityPrompt"); prompt.Triggered = event(); prompt.Parent = bellHolder
table.insert(tagged.ParliamentBell, bellHolder)
local character = Instance.new("Model"); local rootPart = Instance.new("Part"); rootPart.Name = "HumanoidRootPart"; rootPart.Parent = character
player.Character = character
local year = Calendar.DAYS_PER_YEAR * Calendar.SECONDS_PER_DAY
local function at(elapsed) clock = 1767225600 + elapsed end
at(4 * year - 2000)
local fake = 1000
local realOs = os
os = setmetatable({ clock = function() fake += 1; return fake end }, { __index = realOs })
local Service = require(token("ElectionService"))
Service.start(); Service.start()
local folder = storage:FindFirstChild("Election")
local remote = folder:FindFirstChild("Request")
local function pump(n) for _ = 1, n or 1 do for _, loop in loops do if coroutine.status(loop) ~= "dead" then local ok, problem = coroutine.resume(loop); check(ok, tostring(problem)) end end end end
pump(2)
check(folder:GetAttribute("PollsOpen") == true and folder:GetAttribute("Term") == 1 and folder:GetAttribute("Governing") == "", "First term: polls open, nobody governs")
check(storage:GetAttribute("PolicyLuck") == 0 and Service.policy("Luck") == 0, "No policy yet")
local state = remote.OnServerInvoke(player, "State").State
check(state.PollsOpen and state.MyVote == nil, "State view")
rootPart.Position = base * Vector3.new(0, 3, 50)
local result = remote.OnServerInvoke(player, "Vote", "GG")
check(result.Ok == false and string.find(result.Message, "booth"), "Voting needs the Stemlokaal: " .. tostring(result.Message))
rootPart.Position = base * Vector3.new(62, 3, 14)
result = remote.OnServerInvoke(player, "Vote", "Nope")
check(result.Ok == false, "Unknown party rejected")
result = remote.OnServerInvoke(player, "Vote", "GG")
check(result.Ok == true and result.State.MyVote == "GG" and result.State.Votes.GG == 1, "A vote is counted: " .. tostring(result.Message))
check(profile.ElectionVote.Term == 1 and profile.ElectionVote.Party == "GG", "The vote is saved on the profile")
check(folder:GetAttribute("V_GG") == 1, "Votes are published")
result = remote.OnServerInvoke(player, "Vote", "VB")
check(result.Ok == false and string.find(result.Message, "already"), "One vote per term: " .. tostring(result.Message))
pump(30)
check(folder:GetAttribute("V_GG") == 1, "The count survives the sync")
at(4 * year + 10)
pump(40)
check(folder:GetAttribute("Term") == 2 and folder:GetAttribute("PollsOpen") == false, "New term")
check(folder:GetAttribute("Governing") == "GG", "The winner governs, provisionally during the count: " .. tostring(folder:GetAttribute("Governing")))
at(4 * year + 400)
pump(40)
check(folder:GetAttribute("Governing") == "GG" and storage:GetAttribute("PolicyLuck") == 0.04 and storage:GetAttribute("PolicyXP") == 0, "Its policy is in force")
check(folder:GetAttribute("S_GG") == 150 and folder:GetAttribute("V_GG") == 0, "Seats follow the last election; the new count starts empty")
result = remote.OnServerInvoke(player, "Vote", "VB")
check(result.Ok == false and string.find(result.Message, "closed"), "Polls closed between elections: " .. tostring(result.Message))
prompt.Triggered:Fire(player)
local rung = folder:GetAttribute("BellAt")
check(type(rung) == "number" and Parties.division(rung + 1, rung) == rung, "The bell starts a division")
clock += 5
prompt.Triggered:Fire(player)
check(folder:GetAttribute("BellAt") == rung, "No second bell during a division")
for _, close in closers do close() end
output("Election service: " .. checks .. " checks passed")
`;
const temp = await mkdtemp(join(tmpdir(), 'elections-'));
try {
  const path = join(temp, 'check.luau');
  await writeFile(path, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', path], { cwd: root, encoding: 'utf8', timeout: 60000 });
  if (result.error) throw result.error;
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.status) throw new Error('Election checks failed');
} finally {
  if (resolve(temp, '..') !== resolve(tmpdir())) throw new Error('Unexpected temporary directory');
  await rm(temp, { recursive: true, force: true });
}
