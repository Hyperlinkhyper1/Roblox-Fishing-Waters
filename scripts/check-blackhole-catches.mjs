// Execute real rod/crew catch paths with recording Roblox mocks. Rendering and
// network behavior still require Studio; these checks cover event award rules.
import { readFileSync, writeFileSync, mkdtempSync, unlinkSync, rmdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = file => readFileSync(join(root, file), 'utf8');
const dependencies = source => source.replace(/require\((?:script\.Parent|ReplicatedStorage\.Shared)\.([A-Za-z]+)\)/g, (_, name) => `dependencies.${name}`);
const crewSource = dependencies(read('src/server/CompanyService.luau'));
if (!/return CompanyService\s*$/.test(crewSource)) throw new Error('CompanyService return hook changed');
const crew = crewSource.replace(/return CompanyService\s*$/, 'return landFish');
const program = read('scripts/blackhole-catches.luau')
  .replace('-- FISH_MUTATIONS_SOURCE --', () => read('src/shared/FishMutations.luau'))
  .replace('-- CATCH_SERVICE_SOURCE --', () => dependencies(read('src/server/CatchService.luau')))
  .replace('-- COMPANY_CATCH_SOURCE --', () => crew);
const temporary = mkdtempSync(join(tmpdir(), 'blackhole-catches-'));
const target = join(temporary, 'check.luau');
try {
  writeFileSync(target, program);
  const result = spawnSync(process.env.LUTE || 'lute.exe', ['run', target], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} finally {
  unlinkSync(target);
  rmdirSync(temporary);
}
