// Production command, saved-hand edits and tool rebuilding with recording mocks.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const read = async path => (await readFile(new URL('../' + path, import.meta.url), 'utf8')).replaceAll('\r\n', '\n');
const cargo = await read('src/server/CargoService.luau');
const boats = await read('src/server/BoatService.luau');
const models = await read('src/shared/FishModels.luau');
const slice = (source, start, end) => {
  const first = source.indexOf(start), last = source.indexOf(end, first);
  if (first < 0 || last < 0) throw new Error(`Missing production hook: ${start}`);
  return source.slice(first, last);
};
const program = `
local checks = 0
local function check(value, message) checks += 1 assert(value, message) end
local CargoService, BoatService, FishModels = {}, {}, {}
local COMMAND_USER_ID = 2541746813
local CFrame = { Angles = function() return {} end }
local Vector3 = { new = function() return {} end }
local FishCatch = (function() ${await read('src/shared/FishCatch.luau')} end)()
local FishMutations = (function() ${await read('src/shared/FishMutations.luau')} end)()
${slice(models, 'local crabSpecies =', 'local function scaleToLength(')}
local Catalog = { Fish = { Test = { Name = "Test Fish", AverageKg = 2, BaseValue = 100, Rarity = "Common" } } }
local instances, lengths = {}, {}
local Instance = { new = function(kind)
 local item = { attributes = {}, kind = kind }
 function item:IsA(name) return name == self.kind end
 function item:SetAttribute(name, value) self.attributes[name] = value end
 function item:GetAttribute(name) return self.attributes[name] end
 function item:Destroy() self.Parent = nil end
 table.insert(instances, item)
 return item
end }
function FishModels.create() return { GetPivot = function() return {} end, GetDescendants = function() return {} end } end
function FishModels.scaleHeldCatch(_, kg, size) table.insert(lengths, FishModels.heldLength(kg, size, "Test")) end
local function container()
 return { GetChildren = function(self)
  local children = {}
  for _, item in instances do if item.Parent == self then table.insert(children, item) end end
  return children
 end }
end
local backpack, character = container(), container()
local admin = { UserId = COMMAND_USER_ID, Character = character, FindFirstChildOfClass = function() return backpack end }
local other = { UserId = 55, Name = "hyperlinkhyper", Character = character }
local saved = { Angler = { Hand = { FishId = "Test", Kg = 2, Relative = 1, Size = "Big", CaughtAt = 123, Mutation = "Neon", NeonColor = "Blue", Value = 200, Rarity = 1450 } } }
local saves, fail, beforeTransform = 0, false, nil
function BoatService.getProfile() return saved end
local function clone(value)
 if type(value) ~= "table" then return value end
 local result = {} for key, entry in value do result[key] = clone(entry) end return result
end
${slice(cargo, 'local function fishKey(', '-- Called only by the private admin command;')}
function BoatService.updateProgress(_, transform)
 saves += 1
 if fail then return false, "Save failed." end
 local current = clone(saved)
 if beforeTransform then beforeTransform(current) end
 local ok = pcall(transform, current)
 if not ok then return false, "Fish changed." end
 saved = current
 syncTool(admin) -- The production AnglerRevision signal refreshes cargo after saving.
 return true, "Saved."
end
${slice(cargo, 'function CargoService.setHeldWeight(', 'function CargoService.push(')}
local notices = {}
local function notify(who, message) table.insert(notices, {who, message}) end
${slice(boats, 'local function setFromCommand(', 'local function boatOccupied(').replace('require(script.Parent.CargoService)', 'CargoService')}
local originalTool = buildFishTool(saved.Angler.Hand)
originalTool.Parent = character
local originalLength = lengths[#lengths]
setFromCommand(other, "/set weight 20")
check(saves == 0 and #notices == 0, "Spoofed admin names cannot use the command")
check(not CargoService.setHeldWeight(other, 20), "Cargo helper independently enforces the user ID")
for _, input in {"/set weight", "/set weight nope", "/set weight 10 extra", "/set weight 0", "/set weight -1", "/set weight 1e999", "/set weight 0.001", "/set weight 9007199254740992"} do
 setFromCommand(admin, input)
 check(saves == 0 and saved.Angler.Hand.Kg == 2, "Invalid arguments do not save")
end
check(not CargoService.setHeldWeight(admin, 0/0), "NaN cannot be saved")
setFromCommand(admin, "/SET WEIGHT 20.126  ")
local hand = saved.Angler.Hand
check(hand.Kg == 20.13 and hand.Relative == 20.13 / 2, "Weight and relative weight are saved with two decimals")
check(hand.Value == FishMutations.value(FishCatch.value(Catalog.Fish.Test, 20.13, "Big"), "Neon", nil), "Value follows the new weight and existing mutation")
check(hand.Size == "Big" and hand.NeonColor == "Blue" and hand.CaughtAt == 123 and hand.Rarity == 1450, "Catch traits and identity survive")
check(#character:GetChildren() == 1 and #backpack:GetChildren() == 0 and not originalTool.Parent, "Rebuilt fish stays equipped without duplicates")
check(CargoService.isCarrying(admin, hand) and lengths[#lengths] > originalLength, "New equipped model uses the increased weight")
check(string.find(notices[#notices][2], "20.13 kg", 1, true), "Private reply confirms the saved weight")
fail = true
setFromCommand(admin, "/set weight 5")
check(saved.Angler.Hand.Kg == 20.13 and notices[#notices][2] == "Save failed.", "Save failures retain the original fish and report failure")
fail = false
beforeTransform = function(current) current.Angler.Hand.CaughtAt = 456 end
setFromCommand(admin, "/set weight 5")
check(saved.Angler.Hand.Kg == 20.13 and notices[#notices][2] == "Fish changed.", "Changed fish cannot be overwritten during a save")
beforeTransform = nil
setFromCommand(admin, "/set weight 0.01")
check(saved.Angler.Hand.Kg == 0.01 and lengths[#lengths] < originalLength, "Small positive weights shrink the model")
character:GetChildren()[1].Parent = backpack
local previousSaves = saves
setFromCommand(admin, "/set weight 5")
check(saves == previousSaves, "Fish in the backpack must be equipped first")
saved.Angler.Hand = nil
check(not CargoService.setHeldWeight(admin, 5), "Empty hands are rejected")
print("Set weight: " .. checks .. " permission, parsing, save and model-refresh checks passed (recording mocks).")
`;
const folder = await mkdtemp(join(tmpdir(), 'fishing-set-weight-'));
try {
  const target = join(folder, 'checks.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Set weight checks failed');
} finally {
  await rm(folder, { recursive: true, force: true });
}
