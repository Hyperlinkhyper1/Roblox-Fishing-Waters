// Run the actual client LOD controller against streamed hierarchy events.
// Covers scheduling and visibility churn; does not simulate Roblox rendering.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const source = await readFile(join(root, 'src/client/Lod.luau'), 'utf8');
const serverSource = await readFile(join(root, 'src/server/Map/Lod.luau'), 'utf8');
const pinStart = serverSource.indexOf('local UNPIN_DISTANCE =');
const pinEnd = serverSource.indexOf('\nfunction Lod.prepareStreaming', pinStart);
if (pinStart < 0 || pinEnd < 0) throw new Error('LOD pin lifecycle hook changed');
const program = `
local checks, writes, scheduled = 0, 0, 0
local function check(value, message) checks += 1; assert(value, message) end
local function signal()
  local listeners = {}
  return {
    Connect = function(_, callback)
      local connection = {active=true}
      function connection:Disconnect() self.active = false end
      table.insert(listeners, {connection, callback})
      return connection
    end,
    Fire = function(_, ...)
      for _, listener in table.clone(listeners) do
        if listener[1].active then listener[2](...) end
      end
    end,
  }
end
local queue = {}
-- Spawned loops park on their first wait and never run again
local task = {defer=function(callback)
  scheduled += 1
  table.insert(queue, callback)
end, wait=coroutine.yield, spawn=function(callback)
  local ok, err = coroutine.resume(coroutine.create(callback))
  assert(ok, err)
end}
local clock, writeCost = 0, 0
local os = {clock=function() return clock end}
local RunService = {Heartbeat=signal()}
local pinRequests = {}
local pinRemote = {OnClientEvent=signal(), FireServer=function(_, ids) table.insert(pinRequests, ids) end}
local ReplicatedStorage = {WaitForChild=function(_, name) assert(name == "LodPin"); return pinRemote end}
local CollectionService = {added=signal(), removed=signal()}
function CollectionService:GetInstanceAddedSignal(tag) assert(tag == "LodPiece"); return self.added end
function CollectionService:GetInstanceRemovedSignal(tag) assert(tag == "LodPiece"); return self.removed end
function CollectionService:GetTagged() return {} end
local game = {GetService=function(_, name)
  if name == "RunService" then return RunService end
  if name == "ReplicatedStorage" then return ReplicatedStorage end
  if name == "CollectionService" then return CollectionService end
  return {LocalPlayer={}}
end}
local function flush(render)
  while #queue > 0 do
    local callbacks = queue; queue = {}
    for _, callback in callbacks do callback() end
  end
  if render ~= false then RunService.Heartbeat:Fire() end
end
-- Hidden shells fade out over a few frames; run them to the end.
local function settle()
  flush()
  clock += 1
  RunService.Heartbeat:Fire()
end
local methods = {}
local vector = {}
local Vector3 = {new=function(x, y, z) return setmetatable({X=x, Y=y, Z=z}, vector) end}
vector.__div = function(v, n) return Vector3.new(v.X / n, v.Y / n, v.Z / n) end
vector.__sub = function(a, b) return Vector3.new(a.X-b.X, a.Y-b.Y, a.Z-b.Z) end
local function object(class, name, parent)
  local item = setmetatable({ClassName=class, Name=name, Parent=parent, children={}, attributes={}, Position=Vector3.new(0, 0, 0),
    ChildAdded=signal(), ChildRemoved=signal(), DescendantAdded=signal(), DescendantRemoving=signal(),
    AncestryChanged=signal()}, {
    __index=function(self, key)
      if key == "LocalTransparencyModifier" then return rawget(self, "modifier") or 0 end
      return methods[key]
    end,
    __newindex=function(self, key, value)
      if key == "LocalTransparencyModifier" then
        assert(type(value) == "number" and value >= 0 and value <= 1, "Renderer modifiers must be numeric fractions")
        writes += 1; clock += writeCost; rawset(self, "modifier", value)
      else rawset(self, key, value) end
    end,
  })
  if parent then table.insert(parent.children, item) end
  return item
end
function methods:IsA(class) return self.ClassName == class end
function methods:GetAttribute(name) return self.attributes[name] end
function methods:GetAttributeChangedSignal(name)
  local signals = rawget(self, "attributeSignals") or {}
  rawset(self, "attributeSignals", signals)
  signals[name] = signals[name] or signal()
  return signals[name]
end
local function setAttribute(item, name, value)
  item.attributes[name] = value
  item:GetAttributeChangedSignal(name):Fire()
end
function methods:GetChildren() return table.clone(self.children) end
function methods:GetDescendants()
  local found = {}
  for _, child in self.children do
    table.insert(found, child)
    for _, d in child:GetDescendants() do table.insert(found, d) end
  end
  return found
end
function methods:FindFirstChild(name)
  for _, child in self.children do if child.Name == name then return child end end
end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name)) end
function methods:IsDescendantOf(ancestor)
  local parent = self.Parent
  while parent do
    if parent == ancestor then return true end
    parent = parent.Parent
  end
  return false
end
local axes = {RightVector=Vector3.new(1, 0, 0), UpVector=Vector3.new(0, 1, 0), LookVector=Vector3.new(0, 0, 1)}
local function groundAt(parent, x, z)
  local part = object("BasePart", "GroundPart", parent)
  part.Position = Vector3.new(x, 0, z); part.Size = Vector3.new(4, 1, 4); part.CFrame = axes
  return part
end
local workspace = object("Workspace", "Workspace")
local map = object("Folder", "Map", workspace)
local shells = object("Model", "Lod", map)
local shell = object("Model", "1", shells)
local wedge = object("BasePart", "Wedge", shell)
local biome = object("Folder", "Normal", map)
local island = object("Model", "Island", biome)
island.attributes.LodId = 1
local ground = object("Model", "Ground", island)
local first = object("BasePart", "GroundPart", ground)
local Lod = (function()
${source}
end)()
Lod.start()
check(#queue == 1, "Shell and island initialization must share one refresh")
settle()
check(shell.Parent == shells and wedge.LocalTransparencyModifier == 1, "Hide loaded island shell without reparenting")
check(wedge.Position.Y == -0.2, "A baked terrain shell is inset below the real terrain to avoid coplanar faces")
local beforeWrites, beforeScheduled = writes, scheduled
for i = 1, 3000 do
  local part = object("BasePart", "GroundPart", ground)
  ground.DescendantAdded:Fire(part)
end
flush()
check(scheduled == beforeScheduled and writes == beforeWrites, "Extra ground must not schedule or redraw the shell")
for _, part in ground:GetChildren() do
  ground.DescendantRemoving:Fire(part)
end
check(#queue == 1, "A ground stream-out burst must queue one refresh")
-- Replace streamed ground in the same scheduler turn.
ground.children = {}
local replacement = object("BasePart", "Replacement", ground)
ground.DescendantAdded:Fire(replacement)
flush()
check(writes == beforeWrites and shell.Parent == shells, "Transient removal/rearrival must cause no visibility or ancestry churn")
ground.DescendantRemoving:Fire(replacement)
ground.children = {}
flush()
check(wedge.LocalTransparencyModifier == 0 and shell.Parent == shells, "Real stream-out must reveal the retained shell")
local returning = object("BasePart", "Returning", ground)
ground.DescendantAdded:Fire(returning)
settle()
check(wedge.LocalTransparencyModifier == 1 and shell.Parent == shells, "Real stream-in must hide the same shell")
local late = object("BasePart", "LateWedge", shell)
shell.DescendantAdded:Fire(late)
flush()
check(late.LocalTransparencyModifier == 1, "Late shell geometry must inherit current visibility")
shell.DescendantRemoving:Fire(late)
table.remove(shell.children, assert(table.find(shell.children, late)))
late.Parent = nil
beforeWrites = writes
island.Parent = nil
island.AncestryChanged:Fire()
flush()
check(wedge.LocalTransparencyModifier == 0 and writes == beforeWrites + 1, "Whole-island removal must reveal shell and skip removed wedges")
island.Parent = biome
island.AncestryChanged:Fire()
settle()
check(wedge.LocalTransparencyModifier == 1, "Whole-island return must hide shell")
local otherShell = object("Model", "2", shells)
local otherWedge = object("BasePart", "Wedge", otherShell)
shells.ChildAdded:Fire(otherShell)
flush()
check(otherWedge.LocalTransparencyModifier == 0, "Missing island must keep its distant shell visible")
local other = object("Model", "Other", biome)
other.attributes.LodId = 2
local otherGround = object("Model", "Ground", other)
object("BasePart", "GroundPart", otherGround)
biome.ChildAdded:Fire(other)
settle()
check(otherWedge.LocalTransparencyModifier == 1, "Newly streamed island must hide only its own shell")
beforeWrites, beforeScheduled = writes, scheduled
biome.ChildAdded:Fire(other)
flush()
check(writes == beforeWrites and scheduled == beforeScheduled, "Duplicate island events must not attach or refresh again")
local newer = object("Model", "ReplacementIsland", biome)
newer.attributes.LodId = 2
biome.ChildAdded:Fire(newer)
flush()
check(otherWedge.LocalTransparencyModifier == 0, "Replacement island without ground must reveal shell")
beforeScheduled = scheduled
other.AncestryChanged:Fire()
check(scheduled == beforeScheduled, "Old island tracking must be disconnected")
check(shell.Parent == shells and otherShell.Parent == shells, "All shell parents must stay stable")
-- Other islands stream in pieces too; their shell waits until nearly all the ground is in.
local gatedShell = object("Model", "4", shells)
gatedShell.attributes.Ground = 20
local gatedWedge = object("BasePart", "Shell", gatedShell)
shells.ChildAdded:Fire(gatedShell)
local gated = object("Model", "Gated", biome)
gated.attributes.LodId = 4
local gatedGround = object("Model", "Ground", gated)
biome.ChildAdded:Fire(gated)
settle()
local gatedParts = {}
for i = 1, 18 do
  local part = object("BasePart", "GroundPart", gatedGround)
  table.insert(gatedParts, part)
  gatedGround.DescendantAdded:Fire(part)
end
settle()
check(gatedWedge.LocalTransparencyModifier == 0, "A half-streamed island must stay covered by its shell")
beforeScheduled = scheduled
local nineteenth = object("BasePart", "GroundPart", gatedGround)
table.insert(gatedParts, nineteenth)
gatedGround.DescendantAdded:Fire(nineteenth)
check(scheduled == beforeScheduled + 1, "Only the arrival that completes an island refreshes it")
settle()
check(gatedWedge.LocalTransparencyModifier == 1, "A nearly whole island must replace its shell")
beforeWrites, beforeScheduled = writes, scheduled
for i = 1, 18 do gatedGround.DescendantRemoving:Fire(table.remove(gatedParts)) end
settle()
check(gatedWedge.LocalTransparencyModifier == 1 and writes == beforeWrites and scheduled == beforeScheduled,
  "A drawn island losing ground parts must not bring its shell back")
gatedGround.DescendantRemoving:Fire(table.remove(gatedParts))
settle()
check(gatedWedge.LocalTransparencyModifier == 0, "An island whose ground is all gone must bring its shell back")
for i = 1, 3 do
  local part = object("BasePart", "GroundPart", gatedGround)
  table.insert(gatedParts, part)
  gatedGround.DescendantAdded:Fire(part)
end
settle()
check(gatedWedge.LocalTransparencyModifier == 0, "A returning island must be nearly whole again before its shell goes")
-- The home island streams in pieces, so its shell is tiled and each tile follows its own ground.
local tiled = object("Model", "3", shells)
tiled.attributes = {TileSize=100, TileOriginX=0, TileOriginZ=0}
local nearTile = object("Model", "0,0", tiled)
nearTile.attributes.Ground = 4
local nearWedge = object("BasePart", "Shell", nearTile)
local farTile = object("Model", "1,0", tiled)
farTile.attributes.Ground = 4
local farWedge = object("BasePart", "Shell", farTile)
shells.ChildAdded:Fire(tiled)
local home = object("Model", "Harbour Isle", biome)
home.attributes.LodId = 3
local homeGround = object("Model", "Ground", home)
for i = 1, 4 do groundAt(homeGround, 10 + i * 10, 50) end
biome.ChildAdded:Fire(home)
settle()
check(nearWedge.LocalTransparencyModifier == 1, "A streamed-in tile must give way to the real ground")
check(farWedge.LocalTransparencyModifier == 0, "Tiles whose ground hasn't streamed in must stay on the horizon")
local farParts = {}
for i = 1, 3 do
  local part = groundAt(homeGround, 110 + i * 10, 50)
  table.insert(farParts, part)
  homeGround.DescendantAdded:Fire(part)
end
settle()
check(farWedge.LocalTransparencyModifier == 0, "A half-streamed tile must keep covering its gaps")
local last = groundAt(homeGround, 190, 50)
table.insert(farParts, last)
homeGround.DescendantAdded:Fire(last)
settle()
check(farWedge.LocalTransparencyModifier == 1, "A fully streamed tile must hide")
homeGround.DescendantRemoving:Fire(table.remove(farParts))
settle()
check(farWedge.LocalTransparencyModifier == 1, "A drawn tile losing a part must not come back over the town")
-- Walking past a tile hides it; walking away again must not put it back over loaded ground
local staleTile = object("Model", "0,1", tiled)
staleTile.attributes.Ground = 40
local staleWedge = object("BasePart", "Shell", staleTile)
tiled.DescendantAdded:Fire(staleWedge)
for i = 1, 4 do homeGround.DescendantAdded:Fire(groundAt(homeGround, 10 + i * 10, 150)) end
settle()
check(staleWedge.LocalTransparencyModifier == 0, "A tile missing most of its ground must stay up")
setAttribute(staleTile, "Ground", 4)
settle()
check(staleWedge.LocalTransparencyModifier == 1, "A server recount of a stale tile must let it give way")
for _, part in farParts do homeGround.DescendantRemoving:Fire(part) end
settle()
check(farWedge.LocalTransparencyModifier == 1 and nearWedge.LocalTransparencyModifier == 1,
  "A tile that gave way must stay away while its island is still here")
-- A tiled shell the server swaps in later takes over from one that had already given way
shells.ChildRemoved:Fire(tiled)
local swapped = object("Model", "3", shells)
swapped.attributes = {TileSize=100, TileOriginX=0, TileOriginZ=0}
local halfTile = object("Model", "0,0", swapped)
halfTile.attributes.Ground = 6
local halfWedge = object("BasePart", "Shell", halfTile)
local emptyTile = object("Model", "1,0", swapped)
emptyTile.attributes.Ground = 4
local emptyWedge = object("BasePart", "Shell", emptyTile)
shells.ChildAdded:Fire(swapped)
settle()
check(halfWedge.LocalTransparencyModifier == 1, "A swapped-in tile over an island already drawn must not pop up")
check(emptyWedge.LocalTransparencyModifier == 0, "A swapped-in tile whose ground isn't here must still cover it")
shells.ChildRemoved:Fire(swapped)
local replacement = object("Model", "3", shells)
local replacementWedge = object("BasePart", "Wedge", replacement)
shells.ChildAdded:Fire(replacement)
settle()
check(replacementWedge.LocalTransparencyModifier == 1, "A replacement shell must take over its island")
beforeWrites = writes
homeGround.DescendantRemoving:Fire(homeGround.children[1])
flush()
check(writes == beforeWrites, "A replaced shell must stop following the island")
-- Island pieces are reported as they stream in, so the server pins them for this player
local chunk = object("Model", "GroundChunk", workspace)
chunk.attributes.PieceId = 7
local pine = object("Model", "Pine", workspace)
pine.attributes.PieceId = 8
CollectionService.added:Fire(chunk)
CollectionService.added:Fire(pine)
CollectionService.added:Fire(chunk)
check(#pinRequests == 0, "Pieces must wait for the end of the frame")
flush()
check(#pinRequests == 1 and #pinRequests[1] == 2 and pinRequests[1][1] == 7 and pinRequests[1][2] == 8,
  "Pieces arriving together must be pinned in one request, once each")
CollectionService.added:Fire(object("Model", "Untagged"))
flush()
check(#pinRequests == 1, "A piece without an id must not be reported")
CollectionService.removed:Fire(chunk)
CollectionService.added:Fire(chunk)
flush()
check(#pinRequests == 2 and #pinRequests[2] == 1 and pinRequests[2][1] == 7,
  "A piece that streamed out before its pin landed must be reported again")
for i = 1, 1200 do
  local piece = object("Model", "Piece", workspace)
  piece.attributes.PieceId = 100 + i
  CollectionService.added:Fire(piece)
end
flush()
check(#pinRequests == 5 and #pinRequests[3] == 500 and #pinRequests[4] == 500 and #pinRequests[5] == 200,
  "A big burst of pieces must be split into batches the server accepts")
pinRemote.OnClientEvent:Fire({7, 8, 999999})
flush()
check(#pinRequests == 6 and #pinRequests[6] == 2,
  "Released pieces retained on this client must confirm their existing arrival")
CollectionService.removed:Fire(chunk)
chunk.Parent = nil
pinRemote.OnClientEvent:Fire({7})
flush()
check(#pinRequests == 6, "A revisit must not ask the server to force an unloaded piece in")
chunk.Parent = workspace
CollectionService.added:Fire(chunk)
flush()
check(#pinRequests == 7 and pinRequests[7][1] == 7,
  "A missing released piece must report itself after normal streaming brings it back")
local transient = object("Model", "Transient", workspace)
transient.attributes.PieceId = 9000
CollectionService.added:Fire(transient)
CollectionService.removed:Fire(transient)
transient.Parent = nil
flush()
check(#pinRequests == 7, "A piece removed before its deferred report must never be forced back in")

-- Several islands finishing together must share one render-write budget, including
-- initial visibility, fades, reversal and geometry arriving after a shell was hidden.
local bursts = {}
for id = 20, 22 do
  local model = object("Model", tostring(id), shells)
  local parts = {}
  for i = 1, 700 do parts[i] = object("BasePart", "Shell", model) end
  shells.ChildAdded:Fire(model)
  local island = object("Model", "BurstIsland", biome)
  island.attributes.LodId = id
  local ground = object("Model", "Ground", island)
  object("BasePart", "Ground", ground)
  biome.ChildAdded:Fire(island)
  table.insert(bursts, {model=model, parts=parts, island=island})
end
flush(false)
local arrivingBeforeFrame = object("BasePart", "ArrivingBeforeFrame", bursts[1].model)
table.insert(bursts[1].parts, arrivingBeforeFrame)
bursts[1].model.DescendantAdded:Fire(arrivingBeforeFrame)
local function frame()
  local before = writes
  clock += 1 / 60
  flush()
  check(writes - before <= 128, "Simultaneous shell transitions share at most 128 part writes per frame")
  return writes - before
end
for i = 1, 30 do frame() end
for _, burst in bursts do for _, part in burst.parts do
  check(part.LocalTransparencyModifier == 1, "Large initial shell handovers eventually finish")
end end
for _, burst in bursts do burst.island.Parent = nil; burst.island.AncestryChanged:Fire() end
frame()
-- Reverse while the reveal cursor is still suspended, then remove a part before it.
for _, burst in bursts do burst.island.Parent = biome; burst.island.AncestryChanged:Fire() end
local removed = table.remove(bursts[1].parts, 1)
bursts[1].model.DescendantRemoving:Fire(removed)
table.remove(bursts[1].model.children, assert(table.find(bursts[1].model.children, removed)))
removed.Parent = nil
for i = 1, 100 do frame() end
for _, burst in bursts do for _, part in burst.parts do
  check(part.LocalTransparencyModifier == 1, "A reversed fade converges without skipping shifted parts")
end end
beforeWrites = writes
for i = 1, 800 do
  local part = object("BasePart", "LateShell", bursts[1].model)
  table.insert(bursts[1].parts, part)
  bursts[1].model.DescendantAdded:Fire(part)
end
check(writes == beforeWrites, "Late replication bursts queue visibility without synchronous render writes")
writeCost = 0.0004
local expensiveWrites = frame()
check(expensiveWrites <= 3, "Slow renderer writes yield at the shared one-millisecond budget")
writeCost = 0
for i = 1, 20 do frame() end
for _, part in bursts[1].parts do
  check(part.LocalTransparencyModifier == 1, "Late geometry finishes within the paced handover")
end
-- Forgetting a shell cancels queued work even if it has not reached the cursor yet.
for i = 1, 300 do
  local part = object("BasePart", "RemovedShell", bursts[2].model)
  bursts[2].model.DescendantAdded:Fire(part)
end
shells.ChildRemoved:Fire(bursts[2].model)
beforeWrites = writes
for i = 1, 5 do frame() end
check(writes == beforeWrites, "Removed shells never receive queued visibility writes")
print("LOD: " .. checks .. " checks passed; 3000 arrivals without refresh churn; globally paced shell handovers")

-- Run the production server pin lifecycle against a deterministic yielding scheduler.
do
  local checks = 0
  local function check(value, message) checks += 1; assert(value, message) end
  local function harness()
    local now, jobs, requests, removals, players, warnings = 0, {}, {}, {}, {}, {}
    local warn = function(message) table.insert(warnings, message) end
    local function resume(job)
      local ok, delay = coroutine.resume(job.thread)
      assert(ok, delay)
      job.wake = if coroutine.status(job.thread) == "dead" then math.huge else now + (delay or 1 / 60)
    end
    local task = {wait=coroutine.yield, spawn=function(callback)
      local job = {thread=coroutine.create(callback), wake=now}
      table.insert(jobs, job)
      resume(job)
    end}
    local os = {clock=function() return now end}
    local Players = {PlayerRemoving=signal(), GetPlayers=function() return table.clone(players) end}
    local remote
    local ReplicatedStorage = {FindFirstChild=function() return remote and remote.Parent and remote end}
    local Instance = {new=function(class)
      assert(class == "RemoteEvent")
      remote = {OnServerEvent=signal(), FireClient=function(_, target, ids)
        check(target.Parent and table.find(players, target), "Revisit requests target connected players")
        check(#ids <= 500, "Revisit confirmations respect the batch limit")
        table.insert(requests, {player=target, ids=table.clone(ids), time=now})
      end}
      return remote
    end}
    local Enum = {ModelStreamingMode={PersistentPerPlayer="PersistentPerPlayer"}}
    local game = {GetService=function(_, name)
      return if name == "Players" then Players else ReplicatedStorage
    end}
    local Lod, pieces, pieceIds = {}, {}, {}
    local PIN_BATCH = 500
    ${serverSource.slice(pinStart, pinEnd)}
    Lod.serve()
    local api = {requests=requests, removals=removals, warnings=warnings}
    function api:advance(target)
      local iterations = 0
      while true do
        local nextJob
        for _, job in jobs do
          if job.wake <= target + 1e-9 and (not nextJob or job.wake < nextJob.wake) then nextJob = job end
        end
        if not nextJob then break end
        now = math.max(now, nextJob.wake)
        resume(nextJob)
        iterations += 1
        assert(iterations < 10000, "Scheduler failed to make progress")
      end
      now = math.max(now, target)
    end
    function api:player(x)
      local player = {Parent=Players}
      self:respawn(player, x or 0)
      table.insert(players, player)
      return player
    end
    function api:respawn(player, x)
      player.root = {Position={X=x, Y=0, Z=0}, IsA=function(_, class) return class == "BasePart" end}
      local root = player.root
      player.Character = {FindFirstChild=function(_, name) return if name == "HumanoidRootPart" then root else nil end}
    end
    function api:move(player, x) player.root.Position = {X=x, Y=0, Z=0} end
    function api:disconnect(player)
      player.Parent = nil
      local index = table.find(players, player)
      if index then table.remove(players, index) end
      Players.PlayerRemoving:Fire(player)
    end
    function api:piece(id, weight, x, city)
      local item = {Parent=true, ModelStreamingMode="PersistentPerPlayer", pins=0, releases=0,
        weight=weight or 1, position={X=x or 0, Y=0, Z=0}, city=city}
      function item:GetBoundingBox() return {Position=self.position} end
      function item:GetDescendants()
        if self.fail then self.fail = false; error("mock piece inspection failure") end
        return table.create(self.weight - 1, true)
      end
      function item:FindFirstAncestor(name) return if self.city and name == "Modern City" then self.city else nil end
      function item:AddPersistentPlayer(target)
        check(target.Parent ~= nil, "Disconnected players cannot add pins")
        self.pins += 1
      end
      function item:RemovePersistentPlayer(target)
        self.releases += 1
        table.insert(removals, {player=target, piece=self, time=now, weight=self.weight})
        now += self.cost or 0
      end
      pieces[id], pieceIds[item] = item, id
      return item
    end
    function api:report(player, ids) remote.OnServerEvent:Fire(player, ids) end
    function api:clearRequests() table.clear(requests) end
    function api:budget(player)
      local groups = {}
      for _, removal in removals do
        if removal.player == player then
          local key = math.round(removal.time * 1000000)
          local group = groups[key] or {time=removal.time, count=0, weight=0}
          groups[key] = group
          group.count += 1; group.weight += removal.weight
        end
      end
      local previous
      local order = {}
      for _, group in groups do table.insert(order, group) end
      table.sort(order, function(a, b) return a.time < b.time end)
      for _, group in order do
        check(group.count <= 8, "A release batch removes at most eight models")
        check(group.weight <= 256 or group.count == 1, "A release batch fits 256 descendants plus roots, except one oversized piece")
        if previous then check(group.time - previous >= 0.1 - 1e-8, "Release batches wait at least 0.1 seconds") end
        previous = group.time
      end
    end
    return api
  end

  local h = harness()
  local player = h:player()
  local first, retained = h:piece(1), h:piece(2)
  h:report(player, {1, 2, 1})
  check(first.pins == 1 and retained.pins == 1, "Initial arrivals pin once")
  h:move(player, 1500); h:advance(4)
  check(first.releases == 1 and retained.releases == 1, "Far scenery releases its memory pins")
  h:report(player, {1, 2})
  check(first.pins == 1 and retained.pins == 1, "Late reports from the old teleport origin cannot repin distant scenery")
  h:move(player, 0); h:advance(8)
  check(first.pins == 1 and retained.pins == 1, "Returning never eagerly repins unloaded atomic models")
  check(#h.requests == 1 and #h.requests[1].ids == 2, "Revisits ask which pieces remain loaded")
  h:report(player, {2})
  check(retained.pins == 2 and first.pins == 1, "Only a piece confirmed present by its client repins")
  h:clearRequests(); h:advance(12)
  check(#h.requests == 1 and #h.requests[1].ids == 1 and h.requests[1].ids[1] == 1,
    "Missing scenery remains unpinned until it streams in")
  h:report(player, {1}); h:clearRequests(); h:advance(16)
  check(first.pins == 2 and #h.requests == 0, "Normally streamed returning pieces leave the confirmation set")
  local cityPiece = h:piece(3, 1, 0, true)
  h:report(player, {3})
  check(cityPiece.pins == 1, "A nearby city piece initially pins")
  h:move(player, 500); h:advance(20)
  check(cityPiece.releases == 0 and first.releases == 1, "Near city and island pieces retain their pins")
  h:move(player, 600); h:advance(24)
  check(cityPiece.releases == 1 and first.releases == 1, "Only city pieces use the shorter retention range")
  h:clearRequests(); h:move(player, 350); h:advance(28)
  check(#h.requests == 0, "City pieces keep a buffer before confirmation")
  h:move(player, 300); h:advance(32)
  check(#h.requests == 1 and h.requests[1].ids[1] == 3 and cityPiece.pins == 1,
    "Returning near the city asks the client before repinning")
  h:report(player, {3})
  check(cityPiece.pins == 2, "Confirmed city pieces can be retained again")

  h = harness(); player = h:player()
  local destination = h:piece(1, 1, 2000)
  h:report(player, {1}); h:advance(4)
  check(destination.pins == 0 and #h.requests == 0, "Far destination prefetches are remembered without pinning or confirming")
  h:move(player, 2000); h:advance(8)
  check(destination.pins == 0 and #h.requests == 1 and h.requests[1].ids[1] == 1,
    "Arrival rechecks prefetched scenery rather than requiring a second tag-added event")
  h:report(player, {1})
  check(destination.pins == 1, "Already loaded prefetched scenery pins after arrival confirmation")
  local beforeSpawn = h:piece(2, 1, 2000)
  player.Character = nil; h:report(player, {2})
  check(beforeSpawn.pins == 0, "A report without a live root cannot pin scenery")
  h:respawn(player, 2000); h:clearRequests(); h:advance(12)
  check(#h.requests == 1 and h.requests[1].ids[1] == 2, "A report received during respawn remains eligible for later confirmation")

  -- More than eight cheap calls must still yield even when measured script time is zero.
  h = harness(); player = h:player()
  local ids, tiny = {}, {}
  for id = 1, 25 do ids[id] = id; tiny[id] = h:piece(id) end
  h:report(player, ids); h:move(player, 2000); h:advance(4)
  check(#h.removals == 8, "The first teleport cleanup frame removes only eight tiny models")
  h:advance(4.099)
  check(#h.removals == 8, "Cleanup cannot resume before its pacing interval")
  h:advance(4.101)
  check(#h.removals == 16, "Cleanup resumes with another bounded model batch")
  h:advance(5)
  check(#h.removals == 25, "Paced cleanup eventually releases every distant model")
  h:budget(player)

  h = harness(); player = h:player(); ids = {}
  for id, weight in {120, 120, 120, 120, 300, 20, 20, 20} do ids[id] = id; h:piece(id, weight) end
  h:report(player, ids); h:move(player, 2000); h:advance(5)
  check(#h.removals == #ids, "Mixed and individually oversized pieces all finish cleanup")
  h:budget(player)

  -- Movement and lifecycle changes happen while the cleanup coroutine is suspended.
  for _, mode in {"return", "respawn", "missing", "disconnect"} do
    h = harness(); player = h:player(); ids = {}
    for id = 1, 25 do ids[id] = id; h:piece(id) end
    h:report(player, ids); h:move(player, 2000); h:advance(4)
    check(#h.removals == 8, "Lifecycle scenario reaches its first bounded wait: " .. mode)
    if mode == "return" then h:move(player, 0)
    elseif mode == "respawn" then h:respawn(player, 0)
    elseif mode == "missing" then player.Character = nil
    else h:disconnect(player) end
    h:advance(5)
    check(#h.removals == 8, "Cleanup rechecks current position, character and connection after waiting: " .. mode)
    if mode == "disconnect" then
      h:report(player, {1})
      check(#h.requests == 0, "Disconnected cleanup emits no confirmation requests")
    end
  end

  -- The script-time yield path must also reread movement before processing another id.
  h = harness(); player = h:player(); ids = {}
  for id = 1, 4 do
    ids[id] = id
    local item = h:piece(id); item.cost = 0.005
  end
  h:report(player, ids); h:move(player, 2000); h:advance(4)
  check(#h.removals == 1, "Expensive individual release yields to the server frame budget")
  h:move(player, 0); h:advance(5)
  check(#h.removals == 1, "Frame-budget waits also discard stale teleport positions")

  -- A sweep that spans the next four-second poll cannot overlap itself or block another player.
  h = harness(); player = h:player(); ids = {}
  for id = 1, 500 do ids[id] = id; h:piece(id) end
  h:report(player, ids); h:move(player, 2000)
  local other = h:player()
  h:report(other, {1, 2, 3}); h:move(other, 2000); h:advance(4)
  local otherRemoved = 0
  for _, removal in h.removals do if removal.player == other then otherRemoved += 1 end end
  check(otherRemoved == 3, "One player's long cleanup does not delay another player's sweep")
  h:advance(11)
  local primaryRemoved = 0
  for _, removal in h.removals do if removal.player == player then primaryRemoved += 1 end end
  check(primaryRemoved == 500, "A long sweep eventually releases every piece across later polls")
  h:budget(player); h:budget(other)

  -- A completed cleanup can finish just before the next poll, after costly engine calls.
  h = harness(); player = h:player(); ids = {}
  for id = 1, 40 do
    ids[id] = id
    local item = h:piece(id, 256); item.cost = 0.0005
  end
  h:report(player, ids); h:move(player, 2000); h:advance(7.95)
  check(#h.removals == 40, "The boundary fixture finishes one sweep just before the next poll")
  local lastRelease = h.removals[#h.removals].time
  check(lastRelease > 7.9 and lastRelease < 8, "The final release leaves less than 0.1 seconds before the next sweep")
  h:piece(41)
  h:move(player, 0); h:report(player, {41}); h:move(player, 2000); h:advance(8)
  check(#h.removals == 40, "A new sweep respects the preceding sweep's final release cooldown")
  h:advance(8.1)
  check(#h.removals == 41 and h.removals[41].time - lastRelease >= 0.1,
    "The next sweep resumes only after the cross-sweep cooldown")
  h:budget(player)

  h = harness(); player = h:player()
  local faulty = h:piece(1); faulty.fail = true
  h:report(player, {1}); h:move(player, 2000); h:advance(4)
  check(#h.warnings == 1 and string.find(h.warnings[1], "mock piece inspection failure", 1, true),
    "A failed cleanup reports its cause")
  check(faulty.releases == 0, "A failed inspection cannot release an uncounted model")
  h:advance(8)
  check(faulty.releases == 1 and #h.warnings == 1, "Worker failure clears its guard so later sweeps recover")
  print("LOD pin lifecycle: " .. checks .. " checks passed; paced cleanup, live movement, stale reports and independent travelers")
end
`;

const temporary = await mkdtemp(join(tmpdir(), 'fishing-lod-'));
try {
  const path = join(temporary, 'lod.luau');
  await writeFile(path, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', path], {
    cwd: root, encoding: 'utf8', timeout: 30000,
  });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('LOD regression failed');
} finally {
  if (dirname(temporary) !== resolve(tmpdir())) throw new Error('Unexpected temporary directory');
  await rm(temporary, { recursive: true, force: true });
}
