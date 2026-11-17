// Run the production island-city builder with the same geometry doubles as the city checks.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const cityCheck = await readFile(join(root, 'scripts/check-city.mjs'), 'utf8');
const mocks = cityCheck.match(/const mocks = String\.raw`([\s\S]*?)`;/)[1];
const names = ['LowPoly', 'Props', 'CityLand', 'CityBuildings', 'SmallCityBuilders', 'SmallCities'];
let code = 'local _G_print = print\n' + mocks + `
local Random = {new = function(seed)
  local state = seed
  local function nextValue() state = (state * 16807) % 2147483647; return (state - 1) / 2147483646 end
  return {
    NextNumber = function(_, a, b) local n = nextValue(); return if a == nil then n else a + (b-a)*n end,
    NextInteger = function(_, a, b) return a + math.floor(nextValue() * (b-a+1)) end,
  }
end}
local loaded, loaders = {}, {}
local function require(target) local name = target.__module; if loaded[name] == nil then loaded[name] = loaders[name]() end; return loaded[name] end
local script = { Parent = setmetatable({}, { __index = function(_, name) return { __module = name } end }) }
loaders.Lod = function() return {prepareIsland=function() end, pin=function() end} end
loaders.CityDetail = function() return {prepare=function() end} end
`;
for (const name of names) code += `loaders[${JSON.stringify(name)}] = function()\n${await readFile(join(root, 'src/server/Map', name + '.luau'), 'utf8')}\nend\n`;
code += `loaders.CompanyLayout = function()\n${await readFile(join(root, 'src/shared/CompanyIslands.luau'), 'utf8')}\nend\n`;
code += String.raw`
local Cities = require({__module="SmallCities"})
local companies = require({__module="CompanyLayout"})
local land = require({__module="CityLand"})
local root = Instance.new("Folder")
local scenery = Instance.new("Folder"); scenery.Parent = root
local function oldIsland(x, z)
  local island = Instance.new("Model"); island.Name = "Island"; island.Parent = scenery
  local ground = Instance.new("Model"); ground.Name = "Ground"; ground.Parent = island
  local piece = Instance.new("Part"); piece.Size = Vector3.new(80, 10, 80); piece.CFrame = CFrame.new(x, 0, z); piece.Parent = ground
  return island
end
local overlapping = oldIsland(Cities.Sites[1].x, Cities.Sites[1].z)
local distant = oldIsland(0, 0)
local stale = Instance.new("Model"); stale.Name = "Westhaven"; stale:SetAttribute("SmallCityVersion", 1); stale.Parent = root
local stalePart = Instance.new("Part"); stalePart.Parent = stale
local reserved = {}
Cities.reserve(reserved)
check(#Cities.Sites == 4 and #reserved == 4, "Exactly four city sites are reserved")
check(Cities.VERSION >= 2, "The distinct-city layout has a new baked-map version")
for i, site in Cities.Sites do
  check(math.abs(site.x) + Cities.CLEARANCE < 5200 and math.abs(site.z) + Cities.CLEARANCE < 5200, "City and berth fit in the existing ocean")
  check(math.sqrt(site.x^2 + site.z^2) > 2700, "City is clear of the home and company islands")
  for _, company in companies.Sites do
    local angle = math.rad(company[1])
    local x, z = math.cos(angle) * company[2], math.sin(angle) * company[2]
    check(math.sqrt((site.x-x)^2 + (site.z-z)^2) > Cities.CLEARANCE + companies.FOOTPRINT, "City is clear of every company property")
  end
  for _, anchor in {{-3750,-1000,340}, {-1200,3000,420}, {3300,1300,440}, {1000,-3800,360}, {-650,2150,400}} do
    check(math.sqrt((site.x-anchor[1])^2 + (site.z-anchor[2])^2) > Cities.CLEARANCE + anchor[3], "City is clear of a major biome or Pirate Cove")
  end
  for j = 1, i-1 do
    local other = Cities.Sites[j]
    check(math.sqrt((site.x-other.x)^2 + (site.z-other.z)^2) > 2*Cities.CLEARANCE, "City islands are separated")
  end
end

-- The profiles are genuinely different coasts, not one silhouette with a new seed.
local coastMarkers = {}
for _, profile in { "Fishing", "Industry", "Resort", "River" } do
  local coast = Cities.coast(profile)
  local markers = {}
  for _, point in coast do markers[point[3] or "wild"] = (markers[point[3] or "wild"] or 0) + 1 end
  coastMarkers[profile] = markers
  check(#coast > 14, profile .. " coast is roughened into a natural shoreline (" .. #coast .. ")")
end
check((coastMarkers.Resort.beach or 0) >= 6, "The resort has a marked sandy bay")
check((coastMarkers.River.riverwall or 0) >= 3, "Riverton has straight stone river walls")
check((coastMarkers.Fishing.beach or 0) == 0 and (coastMarkers.Industry.riverwall or 0) == 0, "Town coast characters do not leak into each other")

Cities.ensure(root)
check(overlapping.Parent == nil and distant.Parent == scenery, "Migration removes overlapping scenery and preserves distant islands")
check(stale.Parent == nil, "Migration replaces an older baked city")

local expected = {
  Fishing = { blocks = 33, warehouses = 2, cranes = 1, containers = 0 },
  Industry = { blocks = 30, warehouses = 3, cranes = 2, containers = 24 },
  Resort = { blocks = 37, warehouses = 1, cranes = 1, containers = 0 },
  River = { blocks = 40, warehouses = 2, cranes = 1, containers = 6 },
}
local landmarks = {
  Fishing = { "FishMarket", "HarbourLight1", "CityChurch1" },
  Industry = { "ClockTower1", "Gasometer1", "WaterTower1", "FactoryChimney1", "FactoryChimney2" },
  Resort = { "Bandstand1", "PierPavilion1" },
  River = { "CityMarketHall1", "CityMill1", "StoneBridge1", "StoneBridge2", "Weir" },
}
local function countParts(container, name)
  local n = 0
  for _, item in container:GetDescendants() do if item:IsA("BasePart") and item.Name == name then n += 1 end end
  return n
end
local function countModels(container, pattern)
  local n = 0
  for _, item in container:GetDescendants() do if item:IsA("Model") and item.Name:match(pattern) then n += 1 end end
  return n
end
local function hasModel(container, name)
  for _, item in container:GetDescendants() do if item:IsA("Model") and item.Name == name then return true end end
  return false
end
local function footprint(model)
  for _, name in { "Body", "Nave", "HallFloor", "MarketFloor", "MillBody", "HutBody", "ClockShaft", "GasTank", "WaterTank", "StackBase", "LightBase", "BandstandBase" } do
    local part = model:FindFirstChild(name)
    if part and part:IsA("BasePart") then return part end
  end
  return model
end
local profiles, citySignatures = {}, {}
local riverSite
for _, site in Cities.Sites do
  if site.name == "Riverton" then riverSite = site end
  local city = root:FindFirstChild(site.name)
  check(city ~= nil and city:GetAttribute("ChartCoast") ~= nil and city:GetAttribute("ChartLabel") == site.name, "Each city has a charted island")
  check(city:GetAttribute("SmallCityVersion") == Cities.VERSION and city:GetAttribute("SmallCityProfile") == site.profile, site.name .. " carries its version and town profile")
  check(profiles[site.profile] == nil, site.name .. " has a profile no other city uses")
  profiles[site.profile] = true
  local ground = city:FindFirstChild("Ground")
  check(ground ~= nil, site.name .. " keeps all built scenery under Ground")
  local coast = Cities.coast(site.profile)
  local port = ground:FindFirstChild("IndustrialPort")
  check(port and port:FindFirstChild("CargoPier") and port:FindFirstChild("Warehouses") and port:FindFirstChild("CargoCrane"), "Each city has a working-looking dock")
  local pier, apron = port:FindFirstChild("CargoPier"), port:FindFirstChild("PortApron")
  check(pier.Position.Z + pier.Size.Z / 2 >= site.z - 300 and pier.Position.Z - pier.Size.Z / 2 < site.z - 300
    and apron.Position.Z - apron.Size.Z / 2 <= site.z - 300,
    "Pier crosses the quay and meets the port apron")
  for _, corner in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
    check(land.inside(coast, apron.Position.X - site.x + corner[1] * apron.Size.X / 2, apron.Position.Z - site.z + corner[2] * apron.Size.Z / 2),
      "Port apron stays on made land")
  end

  local want = expected[site.profile]
  check(want ~= nil, site.name .. " has a recognised town profile")
  local blocks = countModels(ground, "^CityBlock%d+$")
  local warehouses = countModels(ground, "^DockWarehouse%d+$")
  local cranes = countModels(ground, "^CargoCrane$")
  local containers = countParts(ground, "ShippingContainer")
  check(blocks == want.blocks, site.name .. " has " .. blocks .. " distinct town buildings")
  check(warehouses == want.warehouses and cranes == want.cranes and containers == want.containers,
    site.name .. " has its own scale of port works (" .. warehouses .. "/" .. cranes .. "/" .. containers .. ")")
  for _, name in landmarks[site.profile] do
    check(hasModel(ground, name), site.name .. " has landmark " .. name)
  end
  citySignatures[site.profile] = blocks .. ":" .. warehouses .. ":" .. cranes .. ":" .. containers .. ":" .. #coast

  -- Every solid building core sits on its own profile's shoreline.
  for _, model in ground:GetDescendants() do
    if model:IsA("Model") and model:GetAttribute("LodColor")
      and (model.Name:match("^CityBlock%d+$") or model.Name:match("^CityChurch%d+$")
        or model.Name:match("^CityMarketHall%d+$") or model.Name:match("^Bandstand%d+$")
        or model.Name:match("^HarbourLight%d+$") or model.Name:match("^ClockTower%d+$")
        or model.Name:match("^Gasometer%d+$") or model.Name:match("^WaterTower%d+$")
        or model.Name:match("^FactoryChimney%d+$") or model.Name == "FishMarket" or model.Name == "BeachHut") then
      local part = footprint(model)
      local frame, size = part.CFrame, part.Size
      local halfY = math.abs(frame.RightVector.Y) * size.X / 2 + math.abs(frame.UpVector.Y) * size.Y / 2 + math.abs(frame.ZVector.Y) * size.Z / 2
      local boundsFrame, boundsSize = model:GetBoundingBox()
      for _, corner in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
        local x = boundsFrame.X - site.x + corner[1] * boundsSize.X / 2
        local z = boundsFrame.Z - site.z + corner[2] * boundsSize.Z / 2
        check(land.inside(coast, x, z), model.Name .. " overhangs the water at " .. string.format("%.1f", x) .. "," .. string.format("%.1f", z))
      end
      check(frame.Y - halfY >= 7, model.Name .. " does not sink into the ground")
    end
  end

  local sources = 0
  for _, model in ground:GetDescendants() do
    if model:IsA("Model") and model:GetAttribute("CityDetailSource") then sources += 1 end
  end
  check(sources >= 6, site.name .. " has deferred street furniture and market dressing")

  local _, bounds = ground:GetBoundingBox()
  check(bounds.X < 1100 and bounds.Z < 1100, "City is much smaller than the main city's mainland")

  -- Moored boats ride at the waterline: each hull must straddle y = 0, not hover.
  local boats = 0
  for _, item in ground:GetDescendants() do
    if item:IsA("BasePart") and item.Name == "BoatHull" then
      boats += 1
      check(item.Position.Y - item.Size.Y / 2 < 0 and item.Position.Y + item.Size.Y / 2 > 0,
        site.name .. " boat rides at the waterline")
    end
  end
  check(boats >= 2, site.name .. " moors working boats at its quay")
end
check(profiles.Fishing and profiles.Industry and profiles.Resort and profiles.River, "All four town characters are represented")
local seen = {}
for profile, signature in citySignatures do
  check(seen[signature] == nil, "Town layouts are distinguishable from one another")
  seen[signature] = true
end

-- Riverton's inlet is water, its two bridges are walkable, and the head weir closes it.
local river = root:FindFirstChild("Riverton")
local riverGround = river:FindFirstChild("Ground")
local bridgeDeck = 0
for _, item in riverGround:GetDescendants() do
  if item:IsA("BasePart") and item.Name == "BridgeDeck" then bridgeDeck += 1 end
end
check(bridgeDeck == 2, "Riverton has two stone bridge decks")
check(countParts(riverGround, "RiverWall") >= 3, "The river walls line the inlet")
check(countParts(riverGround, "BeachSand") == 0, "Only Westhaven gets a sandy shore")
local function solidAt(x, z, y)
  for _, item in riverGround:GetDescendants() do
    if item:IsA("BasePart") and item.CanCollide and item.Transparency < 1 then
      local frame, size = item.CFrame, item.Size
      local d = Vector3.new(x, y, z) - frame.Position
      if math.abs(d:Dot(frame.RightVector)) <= size.X / 2 and math.abs(d:Dot(frame.UpVector)) <= size.Y / 2
        and math.abs(d:Dot(frame.ZVector)) <= size.Z / 2 then return item end
    end
  end
  return nil
end
for _, z in { -240, -180, -100, -20, 20, 60 } do
  check(solidAt(riverSite.x + 65, riverSite.z + z, 3) == nil, "The river channel is open water at z " .. z)
end
check(solidAt(riverSite.x + 65, riverSite.z - 140, 8.2) ~= nil and solidAt(riverSite.x + 65, riverSite.z + 40, 8.2) ~= nil, "Both bridges carry a walkable deck")
check(solidAt(riverSite.x + 65, riverSite.z + 72, 4) ~= nil, "The weir closes the head of the river")

-- The resort's bay is sandy rather than rocky, and its beach furniture sits there.
local resort = root:FindFirstChild("Westhaven")
local resortGround = resort:FindFirstChild("Ground")
check(countParts(resortGround, "BeachSand") >= 5 and countParts(resortGround, "BeachBank") >= 5, "The resort bay has a broad sand shore")
check(countModels(resortGround, "^BeachHut$") == 5, "The resort has a row of beach huts")
check(countParts(resortGround, "ParasolCanopy") >= 16 and countParts(resortGround, "LoungerBase") >= 8, "The beach is furnished")

local before = #root:GetDescendants()
Cities.ensure(root)
check(#root:GetDescendants() == before, "Baked city migration is idempotent")
_G_print("Island cities: " .. checks .. " geography, distinctness, geometry and migration checks passed")
`;
const temp = await mkdtemp(join(tmpdir(), 'fishing-small-cities-'));
try {
  const file = join(temp, 'cities.luau');
  await writeFile(file, code);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', file], {cwd: root, encoding: 'utf8', timeout: 120000});
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Island city checks failed');
} finally {
  await rm(temp, {recursive: true, force: true});
}
