// Execute the production helm-send block with a simulated client clock.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const source = (await readFile(join(root, 'src/client/Boating.luau'), 'utf8')).replace(/\r\n/g, '\n');
const start = source.indexOf('\t\t\tsinceInput += dt');
const endMarker = '\t\t\tpreviousSeat = seat';
const end = source.indexOf(endMarker, start);
if (start < 0 || end < 0) throw new Error('Boat input test hook changed');
const program = `
local checks = 0
local function check(value, message)
  assert(value, message)
  checks += 1
end
local player = { GetAttribute = function() return false end }
local boatModel = {}
local seat = { ThrottleFloat = 0, SteerFloat = 0 }
local previousSeat, sentThrottle, sentSteer
local sinceInput = 0
local sent = {}
local request = { FireServer = function(_, action, throttle, steer)
  check(action == "Row", "Only helm input should be sent")
  table.insert(sent, { throttle = throttle, steer = steer })
end }
local function tick(dt, throttle, steer)
  seat.ThrottleFloat, seat.SteerFloat = throttle, steer
${source.slice(start, end + endMarker.length)}
end
tick(1 / 144, 0, 0)
check(#sent == 1, "Boarding must send initial controls immediately")
tick(1 / 144, 1, -1)
check(#sent == 2 and sent[2].steer == -1, "Pressing controls must bypass the analog rate cap")
tick(1 / 144, 1, 1)
check(#sent == 3 and sent[3].steer == 1, "Countersteering must send on the next frame")
tick(1 / 144, 0, 0)
check(#sent == 4 and sent[4].throttle == 0 and sent[4].steer == 0, "Releasing controls must send immediately")
tick(1 / 144, -1, 0)
check(#sent == 5 and sent[5].throttle == -1, "Reverse throttle must send immediately")
tick(1 / 144, 1, 0)
check(#sent == 6 and sent[6].throttle == 1, "Throttle reversal must bypass the rate cap")
tick(1 / 144, 1, 0.1)
check(#sent == 7, "Moving the analog stick out of neutral must send immediately")
for index = 1, 4 do tick(1 / 144, 1, 0.1 + index * 0.01) end
check(#sent == 7, "Same-direction analog changes must stay rate limited")
tick(1 / 144, 1, 0.2)
check(#sent == 8 and sent[8].steer == 0.2, "Analog update must send the latest value after the interval")
for _ = 1, 15 do tick(1 / 144, 1, 0.2) end
check(#sent == 9, "Held input must refresh the server timeout")
print("Boat input: " .. checks .. " checks passed (recording mocks)")
`;

const temporaryRoot = resolve(tmpdir());
const temporary = await mkdtemp(join(temporaryRoot, 'fishing-boat-input-'));
try {
  const target = join(temporary, 'boat-input.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Boat input regression failed');
} finally {
  if (dirname(resolve(temporary)) !== temporaryRoot) throw new Error('Unexpected temporary directory');
  await rm(temporary, { recursive: true, force: true });
}
