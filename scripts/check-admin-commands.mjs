// Exercises the production command handlers and entitlement service with recording mocks.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const read = path => readFile(new URL('../' + path, import.meta.url), 'utf8');
const passes = await read('src/shared/Gamepasses.luau');
const ownership = (await read('src/server/GamepassService.luau'))
  .replace('require(game:GetService("ReplicatedStorage").Shared.Gamepasses)', 'Passes');
const commands = (await read('src/server/AdminCommands.luau'))
  .replace('require(ReplicatedStorage.Shared.Gamepasses)', 'Passes')
  .replace('require(script.Parent.GamepassService)', 'Ownership')
  .replace('require(script.Parent.ScaleModels)', 'ScaleModels');
const program = `
local checks = 0
local function check(value, message) checks += 1 assert(value, message) end
local function signal()
 local callbacks = {}
 return {
  Connect = function(_, fn) table.insert(callbacks, fn) end,
  Fire = function(_, ...) for _, fn in callbacks do fn(...) end end,
 }
end
local players = { PlayerAdded = signal(), PlayerRemoving = signal(), current = {} }
function players:GetPlayers() return self.current end
function players:GetPlayerByUserId(id)
 for _, player in self.current do if player.UserId == id then return player end end
end
local function player(id, name)
 local value = { UserId = id, Name = name, DisplayName = name, Parent = players, attributes = {} }
 function value:SetAttribute(key, attribute) self.attributes[key] = attribute end
 function value:GetAttribute(key) return self.attributes[key] end
 table.insert(players.current, value)
 return value
end
local admin = player(2541746813, "hyperlinkhyper")
local other = player(55, "hyperlinkhyper") -- Name/display-name spoof must not bypass the user ID.
local market = { PromptGamePassPurchaseFinished = signal(), queries = 0 }
local duringQuery
function market:UserOwnsGamePassAsync(_, id)
 self.queries += 1
 check((id == 3722004182 or id == 2057358447), "Ownership queries use the configured pass ID")
 if duringQuery then local callback = duringQuery duringQuery = nil callback() end
 return false
end
local chat = { commands = {} }
local position = { name = "intersection" }
local frame = setmetatable({ Position = position }, { __mul = function() return { Position = position } end })
local CFrame = { new = function() return {} end }
local Vector3 = { zero = {} }
local pavement = { CFrame = frame, Parent = true, IsA = function(_, kind) return kind == "BasePart" end }
local city = { FindFirstChild = function(_, name) if name == "CityPavement" then return pavement end end }
local map = { FindFirstChild = function(_, name) if name == "Modern City" then return city end end }
local modelsPosition = { name = "models pier" }
local modelsFrame = setmetatable({ Position = modelsPosition }, { __mul = function() return { Position = modelsPosition } end })
local modelsArrival = { CFrame = modelsFrame, Parent = true, IsA = function(_, kind) return kind == "BasePart" end }
local pier = { FindFirstChild = function(_, name) if name == "ModelsArrival" then return modelsArrival end end }
local scaleModels = { FindFirstChild = function(_, name) if name == "ModelsPier" then return pier end end }
local modelsReady = false
local modelsVisitors = {}
local ScaleModels = { ensurePier = function() modelsReady = true return modelsArrival end, visit = function(player) table.insert(modelsVisitors, player) end }
local workspace = { FindFirstChild = function(_, name)
 if name == "Map" then return map end
 if name == "ScaleModels" and modelsReady then return scaleModels end
end }
local game = { GetService = function(_, name)
 return ({Players = players, MarketplaceService = market, ReplicatedStorage = {}, TextChatService = chat})[name]
end }
local task = { spawn = function(fn, ...) fn(...) end }
local Instance = { new = function(kind)
 check(kind == "TextChatCommand", "Register engine chat commands")
 local command = { Triggered = signal() }
 table.insert(chat.commands, command)
 return command
end }
local Passes = (function() ${passes} end)()
local Ownership = (function() ${ownership} end)()
Ownership.start()
local notices = {}
local Commands = (function() ${commands} end)()
Commands.start(function(who, message) table.insert(notices, {who, message}) end)
Commands.start(function() error("Duplicate registration") end)
check(#chat.commands == 4, "Repeated startup registers each command only once")
local help, gamepass, teleport, fly
for _, command in chat.commands do
 check(command.Parent == chat and command.AutocompleteVisible == false, "Commands are registered and hidden from public autocomplete")
 if command.PrimaryAlias == "/commands" then help = command end
 if command.PrimaryAlias == "/gamepass" then gamepass = command end
 if command.PrimaryAlias == "/tp" then teleport = command end
 if command.PrimaryAlias == "/fly" then fly = command end
end
check(help and gamepass and teleport and fly, "All requested aliases exist")
local function send(command, who, message) command.Triggered:Fire({UserId = who.UserId}, message) end
send(fly, other, "/fly")
send(fly, other, "/fly speed 100")
check(other:GetAttribute("AdminFlyEnabled") == nil and other:GetAttribute("AdminFlySpeed") == nil, "Spoofed names cannot control flight")
send(fly, admin, "/FLY")
check(admin:GetAttribute("AdminFlyEnabled") == true and admin:GetAttribute("AdminFlySpeed") == nil, "Flight toggles on with default speed")
send(fly, admin, "/fly speed 125.5")
check(admin:GetAttribute("AdminFlySpeed") == 125.5, "Flight speed accepts positive numbers")
for _, message in {"/fly speed 0", "/fly speed -1", "/fly speed 1e999", "/fly speed nope", "/fly speed 5 extra"} do
 send(fly, admin, message)
 check(admin:GetAttribute("AdminFlySpeed") == 125.5, "Invalid speeds leave the setting unchanged")
end
send(fly, admin, "/fly")
check(admin:GetAttribute("AdminFlyEnabled") == false, "Flight toggles off")
local humanoid = { Health = 100, Sit = true }
local root = {}
local character = { Parent = true, moves = 0 }
function character:FindFirstChildOfClass(name) if name == "Humanoid" then return humanoid end end
function character:FindFirstChild(name) if name == "HumanoidRootPart" then return root end end
local expected = position
function character:PivotTo(destination) self.moves += 1 check(destination.Position == expected, "Teleports to the requested destination") end
admin.Character = character
function admin:RequestStreamAroundAsync(destination) check(destination == expected, "Requests streaming at the destination") end
send(teleport, other, "/tp city")
check(character.moves == 0, "Spoofed names cannot teleport")
send(teleport, admin, "/tp elsewhere")
check(character.moves == 0, "Unknown destinations do not teleport")
send(teleport, admin, "/TP CITY  ")
check(character.moves == 1 and not humanoid.Sit and root.AssemblyLinearVelocity == Vector3.zero, "City command moves and unseats the admin")
check(notices[#notices][2] == "Teleported to the city.", "City teleport confirms the destination")
send(teleport, other, "/tp models")
check(character.moves == 1, "Spoofed names cannot reach the scale models")
check(not modelsReady, "Only the admin can put up the pier")
check(#modelsVisitors == 0, "Only the admin gets the ship pinned")
expected = modelsPosition
humanoid.Sit = true
send(teleport, admin, "/TP Models ")
check(modelsReady, "Models put up the pier when the build has not reached it")
check(#modelsVisitors == 1 and modelsVisitors[1] == admin, "Models command pins the ship to the admin")
check(character.moves == 2 and not humanoid.Sit, "Models command moves the admin to the showcase pier")
check(notices[#notices][2] == "Teleported to the scale models.", "Models teleport confirms the destination")
send(teleport, admin, "/tp models now")
check(character.moves == 2 and notices[#notices][2] == "Usage: /tp city or /tp models.", "Extra words show the usage")
notices = {}
for _, message in {"/gamepass list", "/gamepass get Auto Store"} do send(gamepass, other, message) end
send(help, other, "/commands")
gamepass.Triggered:Fire(nil, "/gamepass get Auto Store")
gamepass.Triggered:Fire({UserId = -999}, "/gamepass get Auto Store")
send(gamepass, admin, {})
check(#notices == 0 and not Ownership.ownsAutoStore(other), "Unauthorized, unknown, missing and malformed senders receive nothing and gain no pass")
check(not Ownership.grantForSession(other, "AutoStore"), "Grant helper independently rejects other players")
send(help, admin, "/commands")
for _, usage in {"/commands", "/gamepass list", "/gamepass get", "/set cash", "/set weather list", "/set weather <type>", "/tp city", "/tp models", "/fly", "/fly speed"} do
 check(string.find(notices[#notices][2], usage, 1, true), "Help includes " .. usage)
end
send(gamepass, admin, "/GAMEPASS LIST  ")
check(notices[#notices][2] == "Gamepasses: 2x XP, Auto Store.", "List shows the configured pass name")
for _, message in {"/gamepass", "/gamepass get", "/gamepass get   ", "/gamepass list extra", "/gamepass get Missing", "/gamepass get Auto Store otherPlayer"} do
 send(gamepass, admin, message)
 check(not Ownership.ownsAutoStore(admin), "Malformed or unknown requests grant nothing")
end
check(not Ownership.grantForSession(admin, "Missing"), "Unknown pass keys cannot grant benefits")
send(gamepass, admin, "/GAMEPASS GET aUtO   StOrE  ")
local queries = market.queries
check(Ownership.ownsAutoStore(admin) and admin.attributes.OwnsAutoStore, "Grant overrides a cached negative result and publishes the actual benefit")
check(notices[#notices][2] == "Auto Store enabled for this server session.", "Grant explains its lifetime")
check(market.queries == queries and not Ownership.ownsAutoStore(other), "Grant needs no Marketplace call and changes only the admin")
market.PromptGamePassPurchaseFinished:Fire(admin, Passes.AutoStore.Id, false)
check(Ownership.ownsAutoStore(admin), "Cancelled purchases do not revoke a command grant")
send(gamepass, admin, "/gamepass get AutoStore")
check(Ownership.ownsAutoStore(admin), "Catalog key alias and repeated grants work")
for _, notice in notices do check(notice[1] == admin, "All command replies stay private to the authorized player") end
players.PlayerRemoving:Fire(admin)
check(not Ownership.ownsAutoStore(admin), "Leaving clears the session grant")
duringQuery = function() check(Ownership.grantForSession(admin, "AutoStore"), "Grant succeeds while an ownership lookup is yielding") end
players.PlayerRemoving:Fire(admin)
check(Ownership.ownsAutoStore(admin) and admin.attributes.OwnsAutoStore, "An in-flight negative lookup cannot overwrite the command grant")
admin.Parent = nil
check(not Ownership.grantForSession(admin, "AutoStore"), "Departed players cannot receive grants")
print("Admin commands: " .. checks .. " authorization, parsing, privacy and entitlement checks passed (recording mocks).")
`;
const folder = await mkdtemp(join(tmpdir(), 'fishing-admin-commands-'));
try {
  const target = join(folder, 'checks.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Admin command checks failed');
} finally {
  await rm(folder, { recursive: true, force: true });
}
