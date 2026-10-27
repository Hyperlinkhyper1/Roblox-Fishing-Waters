// Exercises DashboardService's heartbeat and the dashboard grants it hands to
// the real GamepassService, with recording mocks for HttpService and Players.
// The luma server side is covered by server/test/fishing_waters_test.dart in
// the luma repo; a real Roblox server and the live endpoint stay unverified.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const read = path => readFile(new URL('../' + path, import.meta.url), 'utf8');
const passes = await read('src/shared/Gamepasses.luau');
const ownership = (await read('src/server/GamepassService.luau'))
  .replace('require(game:GetService("ReplicatedStorage").Shared.Gamepasses)', 'Passes');
const dashboard = (await read('src/server/DashboardService.luau'))
  .replace('require(ReplicatedStorage.Shared.Gamepasses)', 'Passes')
  .replace('require(ReplicatedStorage.Shared.Weather)', 'Weather')
  .replace('require(ReplicatedStorage.Shared.Biomes)', 'Biomes')
  .replace('require(script.Parent.GamepassService)', 'Ownership');

const program = `
local checks = 0
local function check(value, message) checks += 1 assert(value, message) end
local function signal()
 local callbacks = {}
 return { Connect = function(_, fn) table.insert(callbacks, fn) end,
  Fire = function(_, ...) for _, fn in callbacks do fn(...) end end }
end
local players = { PlayerAdded = signal(), PlayerRemoving = signal(), current = {} }
function players:GetPlayers() return self.current end
local function player(id, name, x, z)
 local value = { UserId = id, Name = name, DisplayName = name .. "!", Parent = players, attributes = {} }
 if x then value.Character = { PrimaryPart = { Position = { X = x, Z = z } } } end
 function value:SetAttribute(key, attribute) self.attributes[key] = attribute end
 table.insert(players.current, value)
 return value
end
local market = { PromptGamePassPurchaseFinished = signal(), owned = {} }
function market:UserOwnsGamePassAsync(userId) return self.owned[userId] == true end

local requests, reply, secretOk, closeHandlers = {}, nil, true, {}
local http = {}
function http:GetSecret(name) if not secretOk then error("missing secret") end return "secret:" .. name end
function http:GenerateGUID() return "abcdef1234567890" end
function http:JSONEncode(value) return value end
function http:JSONDecode(value) return value end
function http:RequestAsync(request)
 table.insert(requests, request)
 if reply == "fail" then error("HttpService is not allowed to access ROBLOX resources") end
 return { Success = true, StatusCode = 200, Body = reply or {} }
end
local game = { JobId = "", PlaceVersion = 7, PrivateServerId = "" }
function game:GetService(name)
 return ({ Players = players, MarketplaceService = market, ReplicatedStorage = {}, HttpService = http,
  RunService = { IsStudio = function() return true end } })[name]
end
function game:BindToClose(fn) table.insert(closeHandlers, fn) end
local attributes = { WeatherEpoch = 1000, WeatherSeed = 77 }
local Biomes = { WaterLevel = 0 }
local Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }
local workspace = { GetServerTimeNow = function() return 1500 end,
 GetAttribute = function(_, key) return attributes[key] end,
 SetAttribute = function(_, key, value) attributes[key] = value end }
local loop
local task = {
 spawn = function(fn, ...) local co = coroutine.create(fn) local ok, err = coroutine.resume(co, ...) assert(ok, err) if coroutine.status(co) == "suspended" then loop = co end end,
 wait = function() coroutine.yield() return 1 end,
}
local warnings = {}
local function warn(message) table.insert(warnings, message) end
local Weather = {
 MaxWaveAmplitude = 4.5,
 RadarHalfSize = 5200, BlackHoleRadius = 250, SupercellRadius = 950,
 supercell = function() return if attributes.WeatherOverride == "Supercell" then { position = { X = 1.4, Z = 2.6 }, strength = 1, forced = true } else nil end,
 tornadoes = function() return if attributes.WeatherOverride == "Supercell" then { { position = { X = 5.2, Z = 6 }, radius = 30.4, strength = 0.5 } } else {} end,
 blackHolePosition = function() return if attributes.WeatherOverride == "BlackHole" then attributes.BlackHolePosition else nil end,
 radar = function() return { version = 1, resolution = 2, halfSize = 5200,
  cells = { { 0, 0, 6, 0.3 }, { 1, 1, 52, 4.5 }, { 0.5, 0, 25, 1.5 }, { 0, 0, 6, 0.3 } } } end,
 Presets = { Storm = { rain = 1, storm = 1 }, Clear = { rain = 0, storm = 0 }, Rain = { rain = 0.62, storm = 0 }, Supercell = { rain = 0.5, storm = 0.35 }, BlackHole = { rain = 0.28, storm = 0 } },
 Schedule = { { kind = "Clear", duration = 150 }, { kind = "Rain", duration = 180 } },
 CycleSeconds = 330,
 getState = function() return { kind = "Rain", rain = 0.6, storm = 0, cloudCover = 0.8, windSpeed = 30,
  windDirection = { X = 0, Z = 1 }, waveAmplitude = 0.5 } end,
}
local function step(n) for _ = 1, n or 1 do local ok, err = coroutine.resume(loop) assert(ok, err) end end

local Passes = (function() ${passes} end)()
local Ownership = (function() ${ownership} end)()
Ownership.start()

-- Without the secret the service stays off and says so once.
secretOk = false
local Off = (function() ${dashboard} end)()
Off.start()
check(#requests == 0 and #warnings == 1 and string.find(warnings[1], "LumaDashboardKey", 1, true), "Missing secret disables reporting with one warning")
warnings = {}
secretOk = true

local angler = player(42, "angler", 10.4, -20.6)
local Dashboard = (function() ${dashboard} end)()
Dashboard.start()
Dashboard.start()
check(#requests == 1 and loop, "Starts once and reports immediately")
local first = requests[1]
check(first.Url == "https://sync.luma-app.cc/api/v1/fishing-waters/heartbeat" and first.Method == "POST", "Posts to the luma heartbeat")
check(first.Headers["X-Fishing-Waters-Key"] == "secret:LumaDashboardKey", "Authenticates with the Roblox secret")
local body = first.Body
check(body.jobId == "studio-abcdef12" and body.studio == true and body.placeVersion == 7, "Studio servers get a stable stand-in job id")
check(#body.players == 1 and body.players[1].userId == 42 and body.players[1].displayName == "angler!", "Reports each player")
check(body.players[1].x == 10 and body.players[1].z == -21, "Rounds player positions for the radar")
check(body.weather.kind == "Rain" and body.weather.windAngle == 90 and body.weather.cycleElapsed == 170, "Reports weather, wind heading and forecast position")
check(body.weather.seed == 77 and body.weather.override == nil, "Reports the radar seed and no override")
check(body.weather.maxWaveAmplitude == 4.5 and body.weather.radar.version == 1 and #body.weather.radar.cells == 4,
 "Reports the actual regional samples and higher sea limit to the admin dashboard")
check(body.kinds[1] == "Clear" and body.kinds[3] == "Storm", "Weather kinds go calmest first")
check(body.kinds[4] == "Supercell" and body.kinds[5] == "BlackHole", "Rare supercell, then the admin-only event, appear after ordinary weather")
check(body.weather.supercell == nil and #body.weather.tornadoes == 0, "No supercell or tornadoes are reported in ordinary weather")
check(body.passes[1].key == "AutoStore" and body.passes[1].id == 3722004182, "Reports the gamepass catalogue")
check(#body.schedule == 2 and body.schedule[2].duration == 180, "Reports the forecast schedule")

-- The dashboard's override and grants come back on the reply.
reply = { intervalSeconds = 15, weatherOverride = "Storm", weatherVersion = 5, grants = { AutoStore = { 42 } } }
step(15)
check(#requests == 2, "Waits a full interval between heartbeats")
check(attributes.WeatherOverride == "Storm", "Applies the dashboard weather override")
check(Ownership.ownsAutoStore(angler) and angler.attributes.OwnsAutoStore == true, "Dashboard grant unlocks the benefit")

-- A chat /set weather survives until the dashboard changes again.
attributes.WeatherOverride = "Clear"
step(15)
check(attributes.WeatherOverride == "Clear", "An unchanged dashboard version leaves in-game weather commands alone")
reply = { weatherOverride = nil, weatherVersion = 9, grants = {} }
step(15)
check(attributes.WeatherOverride == nil, "Auto on the dashboard clears the override")
check(not Ownership.ownsAutoStore(angler) and angler.attributes.OwnsAutoStore == false, "Revoking falls back to Marketplace ownership")
reply = { weatherOverride = "Hail", weatherVersion = 10, grants = { Unknown = { 42 } } }
step(15)
check(attributes.WeatherOverride == nil and not Ownership.ownsAutoStore(angler), "Unknown weather and pass keys are ignored")

-- A location is mandatory, finite and bounded; malformed commands do not
-- consume the version, so a corrected response can still apply.
for _, point in { false, {}, { x = 0 / 0, z = 0 }, { x = 0, z = math.huge }, { x = 5201, z = 0 }, { x = "10", z = 0 } } do
 reply = { weatherOverride = "BlackHole", weatherVersion = 11, blackHole = point }
 step(15)
 check(attributes.WeatherOverride == nil and attributes.BlackHolePosition == nil, "Rejects a black hole without a safe location")
end
reply = { weatherOverride = "BlackHole", weatherVersion = 11, blackHole = { x = 120, z = -300 } }
step(15)
check(attributes.WeatherOverride == "BlackHole" and attributes.BlackHolePosition.X == 120 and attributes.BlackHolePosition.Y == Biomes.WaterLevel and attributes.BlackHolePosition.Z == -300, "Applies the admin event at the chosen water-level location")
reply.blackHole.x = 999
step(15)
check(attributes.BlackHolePosition.X == 120, "Repeated version cannot move an active black hole")
local reported = requests[#requests].Body.weather.blackHole
check(reported.x == 120 and reported.z == -300 and reported.radius == 250, "Reports event center and radius back to Luma")
reply.weatherVersion = 12
step(15)
check(attributes.BlackHolePosition.X == 999, "A newer admin command moves the black hole")
reply = { weatherVersion = 13 }
step(15)
check(attributes.WeatherOverride == nil and attributes.BlackHolePosition == nil, "Auto clears the event and its location")

-- A supercell takes an optional location; without one it circles a player.
reply = { weatherOverride = "Supercell", weatherVersion = 14, supercell = { x = 400, z = 600 } }
step(15)
check(attributes.WeatherOverride == "Supercell" and attributes.SupercellPosition.X == 400 and attributes.SupercellPosition.Z == 600 and attributes.SupercellSince == 1500, "Applies a supercell at the chosen location")
reply = { weatherOverride = "Supercell", weatherVersion = 15, supercell = { x = 0 / 0, z = 0 } }
step(15)
check(attributes.SupercellPosition.X == 10.4 and attributes.SupercellPosition.Z == -20.6, "An unusable location falls back to a player's position")
local stormy = requests[#requests].Body.weather
check(stormy.supercell.x == 1 and stormy.supercell.z == 3 and stormy.supercell.radius == 950 and stormy.supercell.forced, "Reports the supercell to Luma")
check(#stormy.tornadoes == 1 and stormy.tornadoes[1].x == 5 and stormy.tornadoes[1].radius == 30, "Reports active tornadoes to Luma")
reply = { weatherVersion = 16 }
step(15)
check(attributes.WeatherOverride == nil and attributes.SupercellPosition == nil and attributes.SupercellSince == nil, "Auto clears the supercell and its location")

-- A purchased pass stays owned when a dashboard grant is revoked.
local buyer = player(77, "buyer")
market.owned[77] = true
reply = { grants = { AutoStore = { 77 } } }
players.PlayerAdded:Fire(buyer)
local before = #requests
step()
check(#requests == before + 1, "A join reports within a second")
check(buyer.attributes.OwnsAutoStore == true, "Grant reaches a player who just joined")
reply = { grants = {} }
step(15)
check(Ownership.ownsAutoStore(buyer) and buyer.attributes.OwnsAutoStore == true, "Revoking keeps a real purchase")

-- Failures are throttled, and closing tells the dashboard right away.
reply = "fail"
step(15 * 3)
check(#warnings == 1 and string.find(warnings[1], "Heartbeat failed", 1, true), "Repeated failures warn only once")
reply = {}
for _, fn in closeHandlers do fn() end
check(requests[#requests].Body.closing == true and requests[#requests].Body.jobId == "studio-abcdef12", "Shutdown reports the server closing")
print("Dashboard: " .. checks .. " heartbeat, weather and grant checks passed (recording mocks).")
`;
const folder = await mkdtemp(join(tmpdir(), 'fishing-dashboard-'));
try {
  const target = join(folder, 'checks.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Dashboard checks failed');
} finally {
  await rm(folder, { recursive: true, force: true });
}
