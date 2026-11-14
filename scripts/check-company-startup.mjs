import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
const temp = await mkdtemp(join(tmpdir(), 'company-startup-'));
try {
  const source = async path => (await readFile(path, 'utf8')).replace(/^local (\w+) = require\(.*$/gm, 'local $1 = deps.$1');
  const customer = await source('src/server/CustomerService.luau');
  const company = await source('src/server/CompanyService.luau');
  const fixture = `
local signal = {Connect = function() end}
local services = {Players={PlayerRemoving=signal}, RunService={Heartbeat=signal}, CollectionService={}, ReplicatedStorage={}}
local game = {GetService=function(_, name) return services[name] or {} end}
local Instance = {new=function() return {} end}
local workspace = {}
local Vector2 = {new=function(...) return {} end}
local Vector3 = {new=function(...) return {} end}
local CFrame = {new=function(...) return {} end}
local Random = {new=function() return {} end}
local task = {spawn=function() end}
local deps = {FishFreezer={ICE_Z={X=0, Y=0}}, Kitchen={CASE_SPOTS={}, SHELF_SPOTS={}}, BaseGrid={SHOP_FRONT=65.25}, BoatService={setBoatLock=function(callback) assert(type(callback) == "function") end}}
local CustomerService = (function()
${customer}
end)()
assert(type(CustomerService.useCompanyDock) == "function", "Company dock hook must exist")
assert(type(CustomerService.npc.houseFrame) == "function", "Restaurant needs the NPC interface")
deps.CustomerService = CustomerService
local CompanyService = (function()
${company}
end)()
CompanyService.start()
-- The porter empties a moored company boat before the player's own boat;
-- check-home-staff.mjs runs that selection against the production porter.
print("Company startup: dock and boat lock registered")
`;
  const target = join(temp, 'check.luau');
  await writeFile(target, fixture);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], {encoding:'utf8', timeout:30000});
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Company startup check failed');
} finally { await rm(temp, {recursive:true, force:true}); }
