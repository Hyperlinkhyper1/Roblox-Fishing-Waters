// Production boat builders and triangle geometry run in a recording Roblox mock.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const {spawnSync} = require('node:child_process');
const root = process.env.BOAT_PROJECT || path.resolve(__dirname, '..');
const sourceDir = process.env.BOAT_SOURCE || path.join(root, 'src/server/Map');
const source = name => fs.readFileSync(path.join(sourceDir, name+'.luau'), 'utf8');
let mock = fs.readFileSync(path.join(root,'scripts/rowboat-model.luau'),'utf8').split('local function loadRowboat()')[0];
mock = mock.replace('function item:GetDescendants()', `function item:GetChildren() return table.clone(self.children) end
        function item:Destroy()
          if self.Parent then
            local index = table.find(self.Parent.children, self)
            if index then table.remove(self.Parent.children, index) end
          end
          self.destroyed = true
        end
        function item:GetDescendants()`);
let extra = fs.readFileSync(path.join(__dirname,'painted-boat-model.luau'),'utf8');
const moduleText = (name, body) => `local function load${name}()\n${body}\nend\nlocal ${name}=load${name}()\n`;
const low = moduleText('LowPoly', source('LowPoly'));
const props = moduleText('Props', fs.readFileSync(path.join(root,'src/server/Map/Props.luau'),'utf8').replace('local LowPoly = require(script.Parent.LowPoly)', ''));
const med = moduleText('Med', source('Mediterranean').replace(/local (LowPoly|Props) = require\(script.Parent.\1\)/g,''));
const original = process.env.BOAT_LEGACY || path.join(__dirname,'fixtures/painted-boat-v1.luau');
// Retain just the old boat builder as a saved-map fixture, not a second module.
const oldText = fs.readFileSync(original,'utf8');
const oldEnd = oldText.lastIndexOf('return Med');
const oldBuilder = oldText.slice(oldText.indexOf('function Med.boat('), oldEnd < 0 ? undefined : oldEnd).replace('function Med.boat(', 'function Med.legacyBoat(');
const legacy = `local function installLegacy()\nlocal WOOD=Color3.fromRGB(122,92,64)\nlocal WOOD_DARK=Color3.fromRGB(78,60,46)\nlocal WHITEWASH=Color3.fromRGB(242,240,232)\nlocal M=Enum.Material\nlocal part,cylinder,beam=Props.part,Props.cylinder,Props.beam\nlocal function newModel(name,parent) local m=Instance.new('Model');m.Name=name;m.Parent=parent;return m end\n${oldBuilder}\nend\ninstallLegacy()\n`;
extra = extra.replace('-- MODULES --',low+props+med+legacy);
const temporary=fs.mkdtempSync(path.join(os.tmpdir(),'painted-boats-'));
try {
  const target=path.join(temporary,'test.luau');
  fs.writeFileSync(target,mock+extra);
  const result=spawnSync(process.env.LUTE || 'lute.exe',['run',target],{stdio:'inherit'});
  if(result.error)throw result.error;
  process.exitCode=result.status ?? 1;
} finally {fs.rmSync(temporary,{recursive:true,force:true});}
