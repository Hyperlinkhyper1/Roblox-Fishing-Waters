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
function methods:GetAttributeChangedSignal() return signal() end
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
