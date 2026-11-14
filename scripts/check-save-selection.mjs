// Run the real native save screen against recording Roblox UI mocks.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = path => readFile(join(root, path), 'utf8');
const temporary = await mkdtemp(join(tmpdir(), 'fishing-save-selection-'));
try {
  const [mocks, theme, source, checks, branches] = await Promise.all([
    read('scripts/player-menu.luau'), read('src/first/UITheme.luau'),
    read('src/client/SaveSelection.luau'), read('scripts/save-selection.luau'),
    read('src/shared/Branches.luau'),
  ]);
  const fixture = mocks.slice(0, mocks.indexOf('local Theme = (function()'));
  const extensions = '\nfunction methods:FindFirstChildOfClass(class)\n'
    + '  for _, child in self:GetChildren() do if child:IsA(class) then return child end end\n'
    + '  return nil\nend\n'
    + 'services.RunService = { RenderStepped = signal(), Heartbeat = signal() }\n'
    + 'local camera = Instance.new("Camera")\ncamera.CameraType = Enum.CameraType.Custom\nworkspace.CurrentCamera = camera\n'
    + 'local streamRequests = {}\nfunction player:RequestStreamAroundAsync(position, timeout) table.insert(streamRequests, { position, timeout }) end\n';
  const program = fixture + extensions + '\nlocal Theme = (function()\n' + theme + '\nend)()\n'
    + checks.replace('-- SAVE_SELECTION_SOURCE --', () => source.replace(
      'require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))', 'Theme').replace(
      'require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Branches"))', () => `(function()
${branches}
end)()`));
  const path = join(temporary, 'check.luau');
  await writeFile(path, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', path], {
    cwd: root, encoding: 'utf8', timeout: 30000,
  });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Save selection checks failed (${result.status})`);
} finally {
  await rm(temporary, { recursive: true, force: true });
}
