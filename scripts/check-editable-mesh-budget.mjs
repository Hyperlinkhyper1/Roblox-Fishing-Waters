// Exercise the shared scratch lock, failure latch and cosmetic priority without Roblox.
import { readFileSync, writeFileSync, mkdtempSync, unlinkSync, rmdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const source = readFileSync(join(root, 'src/client/EditableMeshBudget.luau'), 'utf8');
const program = `
local pending = {}
local task = {}
function task.wait() coroutine.yield() end
local function spawn(callback)
  table.insert(pending, coroutine.create(callback))
end
local function flush()
  for _ = 1, 1000 do
    if #pending == 0 then return end
    local thread = table.remove(pending, 1)
    local ok, message = coroutine.resume(thread)
    assert(ok, tostring(message))
    if coroutine.status(thread) ~= "dead" then table.insert(pending, thread) end
  end
  error("Scratch callers did not complete")
end
local attempts, live, peak = 0, 0, 0
local deny = false
local elapsed = 0
local os = { clock = function() return elapsed end }
local asset = {}
function asset:CreateEditableMesh()
  attempts += 1
  if deny then return nil end
  live += 1
  peak = math.max(peak, live)
  local mesh = {}
  function mesh:Destroy()
    assert(not self.destroyed, "Destroy exactly once")
    self.destroyed = true
    live -= 1
  end
  return mesh
end
local Content = { fromObject = function(mesh) return mesh end }
local game = { GetService = function() return asset end }
local function loadBudget()
${source}
end

local budget = loadBudget()
local completed = 0
for _ = 1, 5 do
  spawn(function()
    local first, second = budget.withScratch({ evict = true }, function(scratch)
      assert(live == 1 and not scratch.destroyed)
      task.wait()
      assert(live == 1 and not scratch.destroyed)
      return "skin", 42
    end)
    assert(first == "skin" and second == 42, "Preserve callback return values")
    completed += 1
  end)
end
flush()
assert(completed == 5 and peak == 1 and live == 0)
print("PASS concurrent fish/shark builders share one scratch slot and preserve return values")

spawn(function()
  local ok, message = pcall(budget.withScratch, nil, function() error("geometry failed") end)
  assert(not ok and tostring(message):find("geometry failed", 1, true))
end)
flush()
spawn(function()
  assert(budget.withScratch(nil, function() return true end), "Error must release the lock")
end)
flush()
assert(live == 0)
print("PASS callback errors release scratch and unlock future builders")

budget = loadBudget()
deny = true
local before = attempts
assert(budget.create() == nil)
for _ = 1, 100 do
  elapsed += 60
  assert(budget.create() == nil)
end
assert(attempts == before + 1, "A full budget stays latched without resources being freed")
assert(budget.create({ force = true }) == nil and attempts == before + 2)
local reclaimed = 0
budget.onReclaim("idle skins", function()
  if reclaimed > 0 then return 0 end
  reclaimed += 1
  deny = false
  return 1
end)
spawn(function()
  assert(budget.withScratch({ evict = true }, function() return true end), "Reclaim during latch")
end)
flush()
assert(reclaimed == 1 and live == 0 and attempts == before + 3)
print("PASS allocation failures latch until force or actual reclamation, including reclamation during latch")

budget = loadBudget()
local cosmetic = asset:CreateEditableMesh()
local released = false
budget.onRelease("water", function() cosmetic:Destroy(); released = true end)
peak = 1
before = attempts
spawn(function()
  assert(budget.withScratch({ evict = true }, function()
    assert(released and cosmetic.destroyed and live == 1)
    assert(budget.create() == nil, "Water cannot allocate during a scratch build")
    return true
  end))
end)
flush()
assert(attempts == before + 1 and peak == 1 and live == 0)
print("PASS skin builders release water before their first allocation and suppress competing water allocations")
print("Recording mocks only; actual device memory limits still require Studio play testing.")
`;
const temporary = mkdtempSync(join(tmpdir(), 'editable-mesh-budget-'));
const target = join(temporary, 'check.luau');
try {
  writeFileSync(target, program);
  const result = spawnSync(process.env.LUTE || 'lute.exe', ['run', target], {
    cwd: root, encoding: 'utf8', timeout: 30000,
  });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} finally {
  unlinkSync(target);
  rmdirSync(temporary);
}
