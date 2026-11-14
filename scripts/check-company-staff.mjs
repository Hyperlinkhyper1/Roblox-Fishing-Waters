// Executes each passive worker's production host gate. Personal bases and manual
// interactions remain independent; a shared company gets one passive staff set.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
const temporary = await mkdtemp(join(tmpdir(), 'company-staff-'));
const section = (source, start, end) => {
  const first = source.indexOf(start);
  const last = source.indexOf(end, first);
  if (first < 0 || last < 0) throw new Error(`Missing production worker section ${start}`);
  return source.slice(first, last);
};
try {
  const company = await readFile('src/server/CompanyService.luau', 'utf8');
  const chef = await readFile('src/server/ChefService.luau', 'utf8');
  const porter = await readFile('src/server/CompanyIslandPorter.luau', 'utf8');
  const program = `
local checks = 0
local function check(value, message) checks += 1; assert(value, message) end
local host = false
local owner = {UserId=101}
local profile = {Angler={Staff={Fisherman=true,RestaurantChef=true,Porter=true},Kitchen={},ChefRecipes={}}}
local readProfiles = 0
local BoatService = {
 isBusinessHost=function() return host end,
 getProfile=function() readProfiles+=1; return profile end,
}
do
 local base, crew = {}, {ownerId=101,boatId="Rowboat",dock="dock"}
 local crews = {[base]=crew}
 local npc = {ownerOf=function() return owner end}
 local despawns, builds = 0, 0
 local function despawn() despawns+=1; crews[base]=nil end
 local function assignment(current) return if current then "Rowboat" else nil end
 local function dockFrame() return "dock" end
 local function build() builds+=1; return {ownerId=101,boatId="Rowboat",dock="dock"} end
 ${section(company, 'local function syncBase(', 'function CompanyService.start()')}
 syncBase(base)
 check(despawns==1 and builds==0 and readProfiles==0,"Non-host fishermen are removed without spawning another crew")
 host=true; syncBase(base)
 check(builds==1 and crews[base]~=nil,"One business host runs the hired fisherman")
 host=false; syncBase(base)
 check(despawns==2 and crews[base]==nil,"Fisherman transfers when the original creator rejoins")
end
do
 local removed, ensured = 0, 0
 local function removeWorker(state,role) removed+=1; state.workers[role]=nil end
 local function ensureWorker() ensured+=1; return {} end
 local Paths = {unlocked=function() return true end}
 local rolePaths={RestaurantChef="Restaurant"}
 local frame = setmetatable({Position={}}, {__mul=function(a) return a end})
 local CFrame={new=function() return frame end,Angles=function() return frame end}
 local Recipes={Items={},Stations={}}
 local function display() end
 local state={workers={RestaurantChef={}}}
 local base={Parent=true}
 local function ownerOf() return owner end
 local AnglerData = {collectChefDish=function() return {},nil end}
 local Kitchen={DEPTH=3}
 local saved = false
 BoatService.updateProgress=function(_,transform)
   host=false
   local ok=pcall(transform,profile)
   saved=ok
   return ok
 end
 ${section(chef, 'local function processRole(', 'local function processBase(')}
 host=false; processRole(base,state,owner,"RestaurantChef",frame,{})
 check(removed==1 and ensured==0,"Non-host chef is removed before any saved kitchen work starts")
 host=true; processRole(base,state,owner,"RestaurantChef",frame,{})
 check(ensured==1,"The remaining company member can host its chef while the creator is offline")
 profile.Angler.Kitchen={Prep={ChefRole="RestaurantChef",Dish={RecipeId="Test"},ReadyAt=0}}
 host=true; processRole(base,state,owner,"RestaurantChef",frame,{})
 check(not saved,"Chef delivery rechecks hosting inside the wallet transaction")
end
do
 local removed=0
 local function clear(state) removed+=1; state.worker=nil end
 local Players={GetPlayerByUserId=function() return owner end}
 local island={GetAttribute=function() return 101 end}
 ${section(porter, 'local function tick(', 'function Porter.start()')}
 host=false
 local state={worker={}}
 tick(island,state)
 check(removed==1 and state.worker==nil,"A second company island does not duplicate the hired island porter")
end
print("Company staff: "..checks.." fisherman, chef and island-porter host checks passed (production functions).")
`;
  const target = join(temporary, 'check.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Company staff checks failed');
} finally {
  await rm(temporary, { recursive: true, force: true });
}
