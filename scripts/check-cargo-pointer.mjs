// Exercise the production pointer conversion and placement anchor without Studio.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const source = await readFile(join(root, 'src/client/CargoHold.luau'), 'utf8');
const start = source.indexOf('\tlocal function gridPoint(');
const end = source.indexOf('\n\tlocal function takenFor()', start);
if (start < 0 || end < 0) throw new Error('Cargo pointer functions not found');
const folder = await mkdtemp(join(tmpdir(), 'cargo-pointer-'));
try {
  const program = `
local vector = {}
vector.__index = vector
local function point(x, y) return setmetatable({X = x, Y = y}, vector) end
function vector.__sub(a, b) return point(a.X - b.X, a.Y - b.Y) end
function vector.__div(a, b) return point(a.X / b, a.Y / b) end
local mouse, inset, touchPoint
local Enum = {UserInputType = {Touch = "Touch", MouseButton1 = "MouseButton1"}}
local Vector2 = {new = point}
local lastInputType = Enum.UserInputType.MouseButton1
local UserInputService = {GetMouseLocation = function() return mouse end, GetLastInputType = function() return lastInputType end}
local GuiService = {GetGuiInset = function() return inset, point(0, 0) end}
local grid, scale = {}, {}
local STEP = 44
local holding = {item = {}, r = 0}
local width, height = 1, 1
local Cargo = {cells = function() return {}, width, height end}
local function shapeOf(item) return item end
${source.slice(start, end)}
local checks = 0
for _, topInset in {0, 36, 58} do
  inset = point(0, topInset)
  for _, zoom in {0.45, 0.7, 1} do
    scale.Scale = zoom
    -- Visible grid origin is in screen pixels; AbsolutePosition excludes inset.
    local screenOrigin = point(800, 200)
    grid.AbsolutePosition = point(800, 200 - topInset)
    width, height = 1, 1
    for row = 1, 12 do
      for column = 1, 7 do
        for _, offset in {1, 20, 39} do
          mouse = point(screenOrigin.X + ((column - 1) * STEP + offset) * zoom,
            screenOrigin.Y + ((row - 1) * STEP + offset) * zoom)
          local localPoint = gridPoint()
          assert(math.floor(localPoint.X / STEP) + 1 == column, "Wrong pickup column")
          assert(math.floor(localPoint.Y / STEP) + 1 == row, "Wrong pickup row")
          local x, y = anchor()
          assert(x == column and y == row, "Preview/drop misses pointed cell")
          -- GUI input coordinates already have the inset removed. Touch must
          -- use the actual tap, even if the mouse is elsewhere or unavailable.
          local touch = {UserInputType = Enum.UserInputType.Touch,
            Position = point(mouse.X - inset.X, mouse.Y - inset.Y)}
          mouse = point(-500, -500)
          local tap = gridPoint(touch)
          assert(math.floor(tap.X / STEP) + 1 == column, "Wrong touch pickup column")
          assert(math.floor(tap.Y / STEP) + 1 == row, "Wrong touch pickup row")
          local tx, ty = anchor(touch)
          assert(tx == column and ty == row, "Touch drop misses tapped cell")
          lastInputType, touchPoint = Enum.UserInputType.Touch, touch.Position
          local px, py = anchor()
          assert(px == tx and py == ty, "Touch preview misses tapped cell")
          lastInputType = Enum.UserInputType.MouseButton1
          checks += 1
        end
      end
    end
    for _, size in {{2, 3}, {3, 2}} do
      width, height = size[1], size[2]
      mouse = point(screenOrigin.X + (2 + width / 2) * STEP * zoom,
        screenOrigin.Y + (4 + height / 2) * STEP * zoom)
      local x, y = anchor()
      assert(x == 3 and y == 5, "Multi-cell item center shifted")
      checks += 1
    end
  end
end
print("Cargo pointer: " .. checks .. " placement/pickup checks passed across insets, scales and item sizes (no Studio rendering).")
`;
  const target = join(folder, 'pointer.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Cargo pointer checks failed (${result.status})`);
} finally {
  await rm(folder, { recursive: true, force: true });
}
