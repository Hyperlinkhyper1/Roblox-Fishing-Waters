// Run the actual client LOD controller against streamed hierarchy events.
// Covers scheduling and visibility churn; does not simulate Roblox rendering.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const source = await readFile(join(root, 'src/client/Lod.luau'), 'utf8');
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
local task = {defer=function(callback)
  scheduled += 1
  table.insert(queue, callback)
end, spawn=function() end}
local clock = 0
local os = {clock=function() return clock end}
local RunService = {Heartbeat=signal()}
local game = {GetService=function(_, name)
  if name == "RunService" then return RunService end
  return {LocalPlayer={}}
end}
local function flush()
  while #queue > 0 do
    local callbacks = queue; queue = {}
    for _, callback in callbacks do callback() end
  end
end
-- Hidden shells fade out over a few frames; run them to the end.
local function settle()
  flush()
  clock += 1
  RunService.Heartbeat:Fire()
end
local methods = {}
local function object(class, name, parent)
  local item = setmetatable({ClassName=class, Name=name, Parent=parent, children={}, attributes={},
    ChildAdded=signal(), ChildRemoved=signal(), DescendantAdded=signal(), DescendantRemoving=signal(),
    AncestryChanged=signal()}, {
    __index=function(self, key)
      if key == "LocalTransparencyModifier" then return rawget(self, "modifier") or 0 end
      return methods[key]
    end,
    __newindex=function(self, key, value)
      if key == "LocalTransparencyModifier" then writes += 1; rawset(self, "modifier", value)
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
local vector = {}
local Vector3 = {new=function(x, y, z) return setmetatable({X=x, Y=y, Z=z}, vector) end}
vector.__div = function(v, n) return Vector3.new(v.X / n, v.Y / n, v.Z / n) end
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
print("LOD: " .. checks .. " checks passed; 3000 arrivals without refresh/render churn")
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
