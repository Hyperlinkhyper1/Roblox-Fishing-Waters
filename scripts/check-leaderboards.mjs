// Runs production builders and leaderboard indexing against recording mocks.
// Does not claim Studio rendering or live cross-server DataStore verification.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = path => readFile(join(root, path), 'utf8');
const temporary = await mkdtemp(join(tmpdir(), 'fishing-leaderboards-'));
function run(path) {
  const result = spawnSync(process.env.LUTE || 'lute', ['run', path], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Leaderboard checks failed (${result.status})`);
}
try {
  run(join(root, 'scripts/leaderboard-data.luau'));
  const primitives = (await read('scripts/harbour-geometry.luau')).split('local CFrame = {}')[0];
  let geometry = (await read('scripts/drydock-geometry.luau')).split('local function loadLowPoly()')[0]
    .replace('-- SHARED_PRIMITIVES --', () => primitives);
  geometry += `
UDim2.fromOffset = function(...) return {...} end
local oldIndex = instanceMt.__index
instanceMt.__index = function(self, key) return oldIndex(self, key) or self:FindFirstChild(key) end
local UDim = {new=function(...) return {...} end}
function instanceMethods:FindFirstChildOfClass(class)
  for _, child in self:GetChildren() do if child:IsA(class) then return child end end
  return nil
end
local Theme = (function()
${await read('src/first/UITheme.luau')}
end)()
local Boards = (function()
${(await read('src/server/Map/Leaderboards.luau')).replace('require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))', 'Theme')}
end)()
local checks = 0
local function check(value, message) checks += 1; assert(value, message) end
local root = Instance.new("Folder")
local plaza = Instance.new("Model"); plaza.Name = "Plaza"; plaza.Parent = root
local paving = Instance.new("Part"); paving.Size = Vector3.new(116, 0.6, 116)
paving.CFrame = CFrame.new(300, 5.5, -400) * CFrame.Angles(0, 0.4, 0); paving.Parent = plaza
local legacy = Instance.new("Model"); legacy.Name="Leaderboards"; legacy.Parent=plaza
legacy:SetAttribute("LayoutVersion", 2)
local oldTallPanel = Instance.new("Part"); oldTallPanel.Size=Vector3.new(12.4, 23, 0.5); oldTallPanel.Parent=legacy
Boards.ensure(root)
local built = plaza:FindFirstChild("Leaderboards")
check(built ~= nil, "Baked plaza receives leaderboards")
check(built ~= legacy and legacy.Parent == nil, "Baked maps replace the layout that overlaps the furniture shop")
check(built:GetAttribute("LayoutVersion") == 3, "Relocated layout migration is versioned")
check(built.ModelStreamingMode == Enum.ModelStreamingMode.Atomic, "Panels stream with their labels")
Boards.ensure(root)
check(plaza:FindFirstChild("Leaderboards") == built and #plaza:GetChildren() == 2, "Repeated startup never duplicates boards")
local panels, positions = 0, {}
for _, part in built:GetChildren() do
  check(part.Anchored, "Board frames and panels remain anchored")
  local localPosition = paving.CFrame:PointToObjectSpace(part.Position)
  check(localPosition.Y - paving.Size.Y / 2 + part.Size.Y / 2 < 9.5, "Whole noticeboard stays below ten studs, including frame")
  if part:GetAttribute("LeaderboardId") then
    panels += 1
    local p = paving.CFrame:PointToObjectSpace(part.Position)
    local facing = paving.CFrame:VectorToObjectSpace(part.CFrame.LookVector)
    check(facing:Dot(Vector3.new(-p.X,0,-p.Z).Unit) > 0.6, "All three pairs face into the square on rotated saved maps")
    check(p.X >= 9.9 and p.X <= 34.1 and p.Z >= -28.1 and p.Z <= 40.1, "Panels stay inside the plaza")
    if part:GetAttribute("LeaderboardId") == "Earned" or part:GetAttribute("LeaderboardId") == "WeeklyEarned" then
      check(math.abs(p.Z - 40) < 0.001, "Money boards move to the open south side")
      check(p.X - 4.8 >= 5 and p.X + 4.8 <= 27, "Whole money board frames clear the central path and furniture shop approach")
      check(p.Z + 0.5 < 51, "Money boards clear the southern palms and benches")
    end
    check(math.abs(p.Y - paving.Size.Y / 2 - 5.2) < 0.001, "Every leaderboard stands at the same height; none are stacked")
    check(part.Size.X <= 8.7 and part.Size.Y <= 7.3, "Each display is thirty percent smaller")
    check(math.abs(part.Size.X / part.Size.Y - part.Leaderboard.CanvasSize.X / part.Leaderboard.CanvasSize.Y) < 0.001, "Smaller panels preserve canvas proportions")
    for _, other in positions do
      check((p - other).Magnitude >= 11.99, "Independent boards have walking gaps instead of forming a wall")
    end
    table.insert(positions, p)
    check(part.Leaderboard.Face == Enum.NormalId.Front, "Correct display face")
    check(part.Leaderboard.BoardWindow.ThemeInnerRim ~= nil, "Leaderboard uses the shared window frame")
    check(part.Leaderboard.Title.TextStrokeTransparency == 0, "Leaderboard text uses the shared outline")
    check(#part.Leaderboard.Rows:GetChildren() == 20, "Each panel contains ten names and ten scores")
  end
end
check(panels == 6, "Exactly six requested leaderboards")
check(#built:GetChildren() == 24, "Each of the six boards has its own short posts and cap")
Boards.render(root, "WeeklyEarned", {{Name="TestAngler", Score=1200}}, "Test status")
check(built.WeeklyEarned.Leaderboard.Rows.Name1.Text == "01   TestAngler", "Rank and name rendered")
check(built.WeeklyEarned.Leaderboard.Rows.Score1.Text == "$1200", "Money displays as earnings")
check(built.WeeklyEarned.Leaderboard.Status.Text == "Test status", "Storage status visible")
Boards.render(root, "WeeklyEarned", {}, "New week")
check(built.WeeklyEarned.Leaderboard.Rows.Score1.Text == "—", "Rollover clears old rows")
local fresh = Instance.new("Model"); fresh.Name="Plaza"; fresh.Parent=root
Boards.build(fresh, CFrame.new())
check(fresh:FindFirstChild("Leaderboards") ~= nil, "Fresh plaza can receive identical boards")
print("Leaderboard geometry/display: " .. checks .. " checks passed (recording mocks).")
`;
  const geometryPath = join(temporary, 'geometry.luau');
  await writeFile(geometryPath, geometry); run(geometryPath);

  let source = await read('src/server/LeaderboardService.luau');
  source = source.replace(/require\(script.Parent.BoatService\)/g, 'BoatService')
    .replace(/require\(script.Parent.BoatData\)/g, 'BoatData')
    .replace(/require\(script.Parent.AnglerData\)/g, 'Data')
    .replace(/require\(script.Parent.Map.Leaderboards\)/g, 'Boards')
    .replace(/return Service\s*$/, 'return {start=Service.start, capture=capture, writeOne=writeOne, readBoard=readBoard, pending=pending}');
  const dataSource = await read('src/server/AnglerData.luau');
  const definitions = (await read('src/server/Map/Leaderboards.luau')).split('local cream =')[0];
  for (const mode of ['live', 'studio', 'unpublished']) {
    const program = (await read('scripts/leaderboard-service.luau')).replace('-- MODE --', `local mode = "${mode}"`)
      .replace('-- DATA_SOURCE --', () => dataSource)
      .replace('-- DEFINITIONS_SOURCE --', () => definitions)
      .replace('-- SERVICE_SOURCE --', () => source);
    const path = join(temporary, mode + '.luau');
    await writeFile(path, program); run(path);
  }
} finally {
  if (dirname(temporary) !== resolve(tmpdir())) throw new Error('Unexpected temporary path');
  await rm(temporary, {recursive: true, force: true});
}
