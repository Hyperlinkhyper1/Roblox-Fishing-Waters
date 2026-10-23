// Execute the production base/prompt tracking block against streaming events.
// These recording mocks verify ownership behavior and prevent quadratic scans.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const source = await readFile(join(root, 'src/client/Boating.luau'), 'utf8');
const start = source.indexOf('\tlocal tracked = {}');
const end = source.indexOf('\n\tlocal sinceInput, sinceShopCheck', start);
if (start < 0 || end < 0) throw new Error('Boating prompt tracking hook changed');
const program = `
local checks = 0
local function check(condition, message)
  assert(condition, message)
  checks += 1
end
local function signal()
  local event = { listeners = {} }
  function event:Connect(callback)
    local connection = { callback = callback, connected = true }
    function connection:Disconnect() self.connected = false end
    table.insert(self.listeners, connection)
    return connection
  end
  function event:Fire(...)
    for _, connection in table.clone(self.listeners) do
      if connection.connected then connection.callback(...) end
    end
  end
  return event
end
local function item(class, name)
  return { Name = name, Enabled = true, IsA = function(_, expected) return class == expected end }
end
local function makeBase(owner, descendants)
  local base = { owner = owner, descendants = descendants or {}, scans = 0,
    changed = signal(), DescendantAdded = signal(), DescendantRemoving = signal() }
  function base:GetAttribute(name)
    assert(name == "OwnerUserId")
    return self.owner
  end
  function base:GetAttributeChangedSignal(name)
    assert(name == "OwnerUserId")
    return self.changed
  end
  function base:GetDescendants()
    self.scans += 1
    return table.clone(self.descendants)
  end
  function base:SetOwner(owner)
    self.owner = owner
    self.changed:Fire()
  end
  function base:Add(descendant)
    table.insert(self.descendants, descendant)
    self.DescendantAdded:Fire(descendant)
  end
  function base:Remove(descendant)
    self.DescendantRemoving:Fire(descendant)
    table.remove(self.descendants, assert(table.find(self.descendants, descendant)))
  end
  return base
end
local player = { UserId = 123 }
local prompt = item("ProximityPrompt", "SpawnRowboatPrompt")
local unrelated = item("ProximityPrompt", "TalkToShipwrightPrompt")
local base = makeBase(0, { item("Part", "Floor"), prompt, unrelated })
local added, removed = signal(), signal()
local CollectionService = {
  GetTagged = function(_, name) assert(name == "PlayerBase"); return { base } end,
  GetInstanceAddedSignal = function(_, name) assert(name == "PlayerBase"); return added end,
  GetInstanceRemovedSignal = function(_, name) assert(name == "PlayerBase"); return removed end,
}
` + source.slice(start, end) + `
check(not prompt.Enabled, "An unclaimed dock must hide its spawn prompt")
check(unrelated.Enabled, "Other proximity prompts must remain untouched")
check(base.scans == 1, "An initial base must be scanned once")
base:SetOwner(player.UserId)
check(prompt.Enabled, "Claiming the dock must enable its spawn prompt")
for index = 1, 3000 do base:Add(item("Part", "StreamedPart" .. index)) end
check(base.scans == 1, "Streaming scenery must not trigger full-base rescans")
local streamed = item("ProximityPrompt", "SpawnRowboatPrompt")
base:Add(streamed)
check(streamed.Enabled, "A streamed prompt must immediately reflect its owner")
base:SetOwner(456)
check(not prompt.Enabled and not streamed.Enabled, "Ownership transfer must update every loaded spawn prompt")
check(base.scans == 1, "Ownership changes must not rescan scenery")
base:Remove(streamed)
streamed.Enabled = false
base:SetOwner(player.UserId)
check(prompt.Enabled and not streamed.Enabled, "A streamed-out prompt must no longer be updated")
base:Add(streamed)
check(streamed.Enabled, "A returning streamed prompt must be tracked again")
added:Fire(base)
check(base.scans == 1, "Duplicate tag events must not attach duplicate tracking")
removed:Fire(base)
base:SetOwner(456)
check(prompt.Enabled and streamed.Enabled, "Removing a base tag must disconnect ownership tracking")
local detached = item("ProximityPrompt", "SpawnRowboatPrompt")
base:Add(detached)
check(detached.Enabled, "A removed base must stop tracking streamed instances")
added:Fire(base)
check(not prompt.Enabled and not streamed.Enabled and not detached.Enabled, "Retagged bases must refresh all loaded prompts")
check(base.scans == 2, "Retagging must perform only one new initialization scan")
local otherPrompt = item("ProximityPrompt", "SpawnRowboatPrompt")
local other = makeBase(player.UserId, { otherPrompt })
added:Fire(other)
check(otherPrompt.Enabled and other.scans == 1, "Newly tagged bases must initialize independently")
base:SetOwner(0)
check(otherPrompt.Enabled, "Changing one base must not change another dock")
print("Boating streaming: " .. checks .. " checks passed; 3000 arrivals, one initial scan")
`;

const temporaryRoot = resolve(tmpdir());
const temporary = await mkdtemp(join(temporaryRoot, 'fishing-boating-streaming-'));
try {
  const path = join(temporary, 'boating-streaming.luau');
  await writeFile(path, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', path], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Boating streaming regression failed');
} finally {
  if (dirname(resolve(temporary)) !== temporaryRoot) throw new Error('Unexpected temporary directory');
  await rm(temporary, { recursive: true, force: true });
}
