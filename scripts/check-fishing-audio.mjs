// Executes the production cue mixer against recording engine mocks. This does
// not validate Roblox rendering or asset playback permissions.
import { readFileSync, writeFileSync, mkdtempSync, unlinkSync, rmdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = (file) => readFileSync(join(root, file), 'utf8');
const source = read('src/client/FishingAudio.luau');
const program = read('scripts/fishing-audio.luau')
  .replace('-- FISHING_AUDIO_SOURCE --', () => source);
const temporary = mkdtempSync(join(tmpdir(), 'fishing-audio-'));
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
