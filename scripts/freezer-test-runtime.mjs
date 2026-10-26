// Real fish builders and packing rules under the existing geometry doubles.
import { readFile } from 'node:fs/promises';
const read = async p => (await readFile(new URL('../' + p, import.meta.url), 'utf8')).replace(/\r\n/g, '\n');
export async function freezerRuntime() {
  const primitives = (await read('scripts/harbour-geometry.luau')).split('local CFrame = {}')[0];
  const mocks = (await read('scripts/drydock-geometry.luau')).split('local function loadLowPoly()')[0].replace('-- SHARED_PRIMITIVES --', () => primitives);
  const mutations = await read('src/shared/FishMutations.luau');
  const fish = (await read('src/shared/FishModels.luau')).replace('require(script.Parent.FishMutations)', 'FishMutations');
  const packing = await read('src/shared/FreezerPacking.luau');
  return 'local freezerTestPacking, freezerTestModels = (function()\n' + mocks + `
local originalTypeof = typeof
local function typeof(value)
  if type(value)=='table' then
    if getmetatable(value)==getmetatable(Vector2.zero) then return 'Vector2' end
    if getmetatable(value)==getmetatable(Vector3.zero) then return 'Vector3' end
  end
  return originalTypeof(value)
end
Vector3.one = Vector3.new(1,1,1)
local vectorMt = getmetatable(Vector3.zero)
local scalarMultiply = vectorMt.__mul
function vectorMt.__mul(a,b)
  if type(a) == 'table' and type(b) == 'table' then return Vector3.new(a.X*b.X,a.Y*b.Y,a.Z*b.Z) end
  return scalarMultiply(a,b)
end
function frameMt.__sub(a,b) return a + (-b) end
local originalFrameIndex = frameMt.__index
function frameMt.__index(self, key)
  if key == 'Rotation' then return frame(Vector3.zero, self.RightVector, self.UpVector, self.ZVector) end
  return originalFrameIndex(self, key)
end
function instanceMethods:AddTag(tag) self._tags[tag] = true end
function instanceMethods:Clone()
  local copy = Instance.new(self.ClassName)
  for key, value in self._props do if key ~= 'Parent' then copy._props[key] = value end end
  copy._attributes = table.clone(self._attributes)
  copy._tags = table.clone(self._tags)
  for _, child in self:GetChildren() do child:Clone().Parent = copy end
  return copy
end
local FishMutations = (function() ` + mutations + ` end)()
local FishModels = (function() ` + fish + ` end)()
local Packing = (function() ` + packing + ` end)()
return Packing, FishModels
end)()\n`;
}
export function injectFreezer(source) {
  return source.replace('local FreezerPacking, FreezerModels', 'local FreezerPacking, FreezerModels = freezerTestPacking, freezerTestModels');
}
