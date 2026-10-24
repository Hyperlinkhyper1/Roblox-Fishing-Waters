-- Run the production freezer sizing against every species' weight range.
local fs = require("@lute/fs")
local luau = require("@lute/luau")
local function read(path)
	local file = fs.open(path, "r")
	local source = fs.read(file)
	fs.close(file)
	return source
end
local source = read("src/server/CustomerService.luau")
luau.compile(source)
local cargo = read("src/server/CargoService.luau")
luau.compile(cargo)
local models = read("src/shared/FishModels.luau")
luau.compile(models)
local start = assert(string.find(models, "function FishModels.catchLength", 1, true))
local finish = assert(string.find(models, "function FishModels.silhouette", start, true)) - 1
local sizing = luau.load(luau.compile("local FishModels = {}\n" .. string.sub(models, start, finish)
	.. "\nreturn FishModels"), "catch-size")()
local length = sizing.catchLength
local heldLength = sizing.heldLength
local catalog = luau.load(luau.compile(read("src/shared/AnglerCatalog.luau")), "catalog", {
	Color3 = { fromRGB = function(...) return { ... } end },
})()
local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end
for id, fish in catalog.Fish do
	local previous = 0
	local previousHeld = 0
	-- Include the full record range: even the largest catches must remain
	-- distinct instead of all hitting the same hard size limit.
	for step = 0, 100 do
		local kg = fish.MinKg + (fish.MaxKg - fish.MinKg) * step / 100
		local size = length(kg)
		check(size > previous, id .. ": heavier catches must look larger")
		check(size > 0 and size < 3.2, id .. ": fits the full-depth freezer row")
		local heldSize = heldLength(kg)
		check(heldSize > previousHeld, id .. ": heavier catches must look larger in hand")
		previousHeld = heldSize
		previous = size
	end
	check(length(fish.MinKg) < length(fish.AverageKg), id .. ": small catch is smaller than average")
	check(length(fish.AverageKg) < length(fish.MaxKg), id .. ": record catch is larger than average")
end
check(length(catalog.Fish.YellowfinTuna.AverageKg) > length(catalog.Fish.Clownfish.AverageKg) * 1.7,
	"Average tuna must look substantially larger than average clownfish")
check(length(catalog.Fish.Clownfish.AverageKg) > length(catalog.Fish.Anchovy.AverageKg),
	"Small species retain different sizes too")
check(string.find(source, "FishModels.scaleCatch(model, record.Kg)", 1, true) ~= nil,
	"Freezer and customers use shared catch sizing")
check(string.find(cargo, "FishModels.scaleHeldCatch(model, record.Kg)", 1, true) ~= nil,
	"Player's hand uses the catch's actual weight without the freezer size limit")
check(math.abs(heldLength(8) / heldLength(1) - 2) < 1e-9,
	"Eight times the weight doubles held fish dimensions")
check(heldLength(1100) > heldLength(35) * 3,
	"Record catches remain visibly larger than heavy catches in hand")
-- Exercise the scaling with elongated, tall and wide model bounds: every
-- orientation must retain its proportions and fit the ice at the same scale.
for _, dimensions in { {4, 1, 0.5}, {2, 4, 0.5}, {2, 0.5, 4} } do
	local bounds = setmetatable({X = dimensions[1], Y = dimensions[2], Z = dimensions[3]}, {
		__mul = function(a, b) return {X = a.X * b, Y = a.Y * b, Z = a.Z * b} end,
	})
	local function mock()
		return {
			GetAttribute = function() return bounds end,
			ScaleTo = function(self, scale) self.scale = scale end,
		}
	end
	for _, kg in {0.01, 0.09, 1.2, 35, 1100} do
		local held, frozen = mock(), mock()
		local a, b = sizing.scaleHeldCatch(held, kg), sizing.scaleCatch(frozen, kg)
		check(math.abs(math.max(a.X, a.Y, a.Z) - heldLength(kg)) < 1e-9,
			"Held model's longest axis matches its weight-based length")
		check(math.abs(a.X / a.Y - bounds.X / bounds.Y) < 1e-9
			and math.abs(a.Z / a.Y - bounds.Z / bounds.Y) < 1e-9,
			"Held scaling preserves fish proportions")
		check(math.abs(math.max(b.X, b.Y, b.Z) - length(kg)) < 1e-9,
			"Freezer's longest axis matches compact catch length")
		check(b.X < 3.34, "Catch fits ice depth with clearance")
	end
end
print("Freezer fish sizing: " .. checks .. " checks passed (no Roblox runtime).")
