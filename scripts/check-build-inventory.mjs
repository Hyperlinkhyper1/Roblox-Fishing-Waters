// Run the production roof, inventory, and thumbnail code with recording Roblox doubles.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = path => readFile(join(root, path), 'utf8');
const [build, service, preview, furniture, primitives, frameSource] = await Promise.all([
  read('src/client/BuildMode.luau'), read('src/server/FurnitureService.luau'),
  read('src/client/FurniturePreview.luau'), read('src/shared/FurnitureCatalog.luau'),
  read('scripts/harbour-geometry.luau'), read('scripts/drydock-geometry.luau'),
]);
function section(source, start, end) {
  const first = source.indexOf(start), last = source.indexOf(end, first);
  if (first < 0 || last < 0) throw new Error(`Missing build-mode section: ${start}`);
  return source.slice(first, last);
}
const frames = frameSource.split('local function typeof')[0]
  .replace('-- SHARED_PRIMITIVES --', () => primitives.split('local CFrame = {}')[0]);
const program = `${frames}
local Furniture = (function()
${furniture}
end)()
local checks = 0
local function check(condition, message)
  assert(condition, message)
  checks += 1
end
-- Streaming, repeated visibility updates, and restoration of the actual roof functions.
do
  local active, hidden, roofConnection = true, {}, nil
  local houseFrame = CFrame.new(120, 6, -75) * CFrame.Angles(0, math.pi / 2, 0)
  local ROOF_HEIGHT = 8.4
  local task = {defer = function(callback) callback() end}
  local added, disconnected = nil, false
  local parts = {}
  local house = {GetDescendants = function() return parts end,
    DescendantAdded = {Connect = function(_, callback)
      added = callback
      return {Disconnect = function() disconnected = true end}
    end}}
  local folder = {Parent = house}
  house.FindFirstChild = function(_, name) return if name == "Furniture" then folder else nil end
  local function part(name, height, parent, modifier)
    local item = {Name = name, Parent = parent or house, Position = houseFrame * Vector3.new(0, height, 0),
      Transparency = 0.15, LocalTransparencyModifier = modifier or 0}
    function item:IsA(kind) return kind == "BasePart" end
    function item:IsDescendantOf(ancestor)
      local node = self.Parent
      while node do
        if node == ancestor then return true end
        node = node.Parent
      end
      return false
    end
    table.insert(parts, item)
    return item
  end
  local roof = part("RoofSlope", 14, nil, 0.2)
  local tie = part("CeilingTie", 11.1)
  local lamp = part("LampShade", 9.25)
  local floor = part("Floor", 0.16)
  local tallFurniture = part("TallFurniture", 13, folder)
${section(build, '\tlocal function hideRoofPart(', '\n\tlocal function showGrid(')}
  hideRoof()
  check(roof.LocalTransparencyModifier == 1 and tie.LocalTransparencyModifier == 1
    and lamp.LocalTransparencyModifier == 1, "Roof, rafters and overhead lights must be invisible")
  check(floor.LocalTransparencyModifier == 0 and tallFurniture.LocalTransparencyModifier == 0,
    "The floor and furniture must stay visible")
  check(roof.Transparency == 0.15, "Build visibility must not change replicated transparency")
  local streamed = part("TileCourse", 16)
  added(streamed)
  check(streamed.LocalTransparencyModifier == 1, "Newly streamed roof pieces must disappear")
  local lateFrame = part("RainGutter", 0)
  added(lateFrame)
  check(lateFrame.LocalTransparencyModifier == 0, "Unpositioned parts must wait for their frame")
  lateFrame.Position = houseFrame * Vector3.new(0, 11.6, 0)
  roof.LocalTransparencyModifier = 0.7
  hideRoof()
  check(lateFrame.LocalTransparencyModifier == 1 and roof.LocalTransparencyModifier == 1,
    "Repeated passes must catch late frames and keep the roof invisible")
  showRoof()
  check(disconnected and roofConnection == nil, "Exit must disconnect the streaming watcher")
  check(roof.LocalTransparencyModifier == 0.2 and streamed.LocalTransparencyModifier == 0
    and lateFrame.LocalTransparencyModifier == 0, "Exit must restore original local visibility after repeated hiding")
  active = false
  local afterExit = part("RoofSlope", 14)
  added(afterExit)
  check(afterExit.LocalTransparencyModifier == 0, "Queued streaming work must not hide the roof after exit")
end
-- Stock is the unplaced inventory, separate from the Placed list.
do
  local state, held, selected, spot = nil, nil, nil, nil
  local pending = false
  local itemButtons, stockLabels = {}, {}
  local itemViews, previewStarted, previewCalls = {}, {}, {}
  local remotes = {}
  local FurniturePreview = {show = function(_, _, id) previewCalls[id] = (previewCalls[id] or 0) + 1 end}
  for _, id in Furniture.Order do itemButtons[id], stockLabels[id], itemViews[id] = {}, {}, {} end
  local inventoryTitle, emptyInventory, hint = {}, {}, {}
  local rotate, cancel, move, pickUp = {}, {}, {}, {}
  local function setButton(item, text, enabled, chosen) item.Active, item.Chosen = enabled, chosen end
${section(build, '\tlocal function render()', '\n\tlocal function clearPreview(')}
  render()
  check(emptyInventory.Visible and string.find(emptyInventory.Text, "Loading"), "Loading inventory must have a clear status")
  state = {Stock = {Freezer = 2}, Placed = {{ItemId = "Register"}}}
  render()
  check(itemButtons.Freezer.Visible and not itemButtons.Register.Visible and not itemButtons.StorageRack.Visible,
    "Only owned, unplaced item types belong in the bottom bar")
  check(string.find(stockLabels.Freezer.Text, "2") and string.find(inventoryTitle.Text, "2"), "Stock quantities must be shown")
  check(not emptyInventory.Visible and itemButtons.Freezer.Active, "Available stock must be selectable")
  check(previewCalls.Freezer == 1 and previewCalls.Register == nil and previewCalls.StorageRack == nil,
    "Only owned inventory needs a thumbnail clone")
  held = {ItemId = "Freezer", From = "Freezer"}
  render()
  check(itemButtons.Freezer.Chosen, "The held inventory item must be highlighted")
  check(previewCalls.Freezer == 1, "Inventory updates must reuse cached thumbnails")
  held = nil
  state.Stock.Freezer = 0
  table.insert(state.Placed, {ItemId = "Freezer"})
  render()
  check(not itemButtons.Freezer.Visible and emptyInventory.Visible, "Placing the final copy must remove its card")
  state.Stock.Freezer = 1
  table.remove(state.Placed)
  render()
  check(itemButtons.Freezer.Visible and not emptyInventory.Visible, "Picking up furniture must return it to the bar")
  pending = true
  render()
  check(itemButtons.Freezer.Visible and not itemButtons.Freezer.Active, "Saving must disable actions without hiding inventory")
  pending = false
  state.Placed = {}
  for _ = 1, Furniture.Items.Freezer.MaxPlaced do table.insert(state.Placed, {ItemId = "Freezer"}) end
  render()
  check(itemButtons.Freezer.Visible and not itemButtons.Freezer.Active,
    "Owned stock must stay listed even at the placement limit")
end
-- Templates use all catalogue builders, with no live collisions or workspace dependence.
local created = {}
local Instance = {new = function(kind)
  local item = {ClassName = kind}
  table.insert(created, item)
  return item
end}
do
  local built = {}
  local function builder(id)
    return {build = function(_, frame)
      check(frame == CFrame.identity, "Inventory templates must be built around the origin")
      local part = {IsA = function(_, kind) return kind == "BasePart" end}
      local sample = {GetDescendants = function() return {part} end, Part = part}
      built[id] = sample
      return sample
    end}
  end
  local FishFreezer, ShopDesk, StorageRack = builder("Freezer"), builder("Register"), builder("StorageRack")
  local Kitchen = {
    buildCase = builder("FoodCase").build,
    buildStation = function(parent, frame, id) return builder(id).build(parent, frame) end,
  }
  local DiningRoom = {buildTable = builder("DiningTable").build}
${section(service, 'local function buildPreviews(', '\nfunction FurnitureService.start()')}
  local parent = {}
  buildPreviews(parent)
  for _, id in Furniture.Order do
    local sample = built[id]
    check(sample and sample.Name == id and sample.Parent.Name == "Previews" and sample.Parent.Parent == parent,
      "Every catalogue item must have a replicated template")
    check(sample.Part.Anchored and not sample.Part.CanCollide and not sample.Part.CanTouch and not sample.Part.CanQuery,
      "Preview geometry must stay inert")
  end
end
-- Exercise the real thumbnail module, including resize fitting and missing templates.
do
  local task = {spawn = function(callback) callback() end}
  local Color3 = {fromRGB = function(r, g, b) return {r, g, b} end}
  local Preview = (function()
${preview}
  end)()
  local resized = nil
  local view = {Parent = true, AbsoluteSize = Vector2.new(64, 44),
    GetPropertyChangedSignal = function() return {Connect = function(_, callback) resized = callback end} end}
  local box, size = CFrame.new(0, 3, 0), Vector3.new(9, 6, 4)
  local model = {GetBoundingBox = function() return box, size end}
  local template = {IsA = function(_, kind) return kind == "Model" end, Clone = function() return model end}
  local templates = {WaitForChild = function() return template end}
  local remotes = {WaitForChild = function() return templates end}
  Preview.show(view, remotes, "Freezer")
  check(view.CurrentCamera and model.Parent.ClassName == "WorldModel", "Thumbnail clones must stay inside their viewport world")
  check(view.CurrentCamera.CFrame.LookVector:Dot((box.Position - view.CurrentCamera.CFrame.Position).Unit) > 0.9999,
    "Thumbnail camera must point at the furniture")
  for _, viewport in {Vector2.new(64, 44), Vector2.new(28, 100), Vector2.new(200, 30)} do
    view.AbsoluteSize = viewport
    resized()
    local camera = view.CurrentCamera
    local focal = viewport.Y / (2 * math.tan(math.rad(camera.FieldOfView / 2)))
    for _, x in {-size.X / 2, size.X / 2} do
      for _, y in {-size.Y / 2, size.Y / 2} do
        for _, z in {-size.Z / 2, size.Z / 2} do
          local point = camera.CFrame:PointToObjectSpace(box.Position + Vector3.new(x, y, z))
          check(math.abs(focal * point.X / -point.Z) < viewport.X / 2
            and math.abs(focal * point.Y / -point.Z) < viewport.Y / 2,
            "Thumbnail furniture must fit after a resize")
        end
      end
    end
  end
  local before = #created
  Preview.show({Parent = nil}, remotes, "Freezer")
  Preview.show(view, {WaitForChild = function() return nil end}, "Missing")
  check(#created == before, "Removed views and missing templates must not create orphan previews")
end
print("Build inventory: " .. checks .. " roof streaming, owned stock, templates and thumbnail checks passed (no Studio rendering).")
local function parseBuildMode()
${build}
end
`;
const folder = await mkdtemp(join(tmpdir(), 'build-inventory-'));
try {
  const target = join(folder, 'inventory.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], {cwd: root, encoding: 'utf8', timeout: 30000});
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Build inventory checks failed (${result.status})`);
} finally {
  await rm(folder, {recursive: true, force: true});
}
