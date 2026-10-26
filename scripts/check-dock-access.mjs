// Check the production dock migration and ramp surfaces in rotated plots.
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = file => readFileSync(join(root, file), 'utf8');
const primitives = read('scripts/harbour-geometry.luau').split('local CFrame = {}')[0];
const mocks = read('scripts/drydock-geometry.luau').split('local function loadLowPoly()')[0]
  .replace('-- SHARED_PRIMITIVES --', () => primitives);
const harbour = read('src/server/Map/Harbour.luau');
const first = harbour.indexOf('local function ensureDockAccess(');
const last = harbour.indexOf('local function buildBase(', first);
if (first < 0 || last < 0) throw new Error('Dock access migration section missing');
const ensureFirst = harbour.indexOf('function Harbour.ensureDocks(');
const ensureLast = harbour.indexOf('-- Add the boat shop', ensureFirst);
if (ensureFirst < 0 || ensureLast < 0) throw new Error('Saved dock startup section missing');
const props = read('src/server/Map/Props.luau').replace('local LowPoly = require(script.Parent.LowPoly)', 'local LowPoly = {}');
const program = `${mocks}
local Props = (function()
${props}
end)()
local QUAY = Color3.fromRGB(132, 126, 118)
local M = Enum.Material
local Harbour = { BASE_TAG = "PlayerBase" }
${harbour.match(/local DOCK_DETAIL_VERSION = \d+/)[0]}
${harbour.slice(first, last)}
local CollectionService = { HasTag = function() return true end }
${harbour.slice(ensureFirst, ensureLast)}
${read('scripts/dock-access.luau')}`;
const temporary = mkdtempSync(join(tmpdir(), 'dock-access-'));
try {
  const target = join(temporary, 'check.luau');
  writeFileSync(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} finally {
  rmSync(temporary, { recursive: true, force: true });
}
