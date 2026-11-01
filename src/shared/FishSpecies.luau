-- Every species, keyed by id. Each one is its own ModuleScript in Shared.Fish
-- (src/shared/Fish/<Id>.luau), so species can be added or edited one file at a
-- time; AnglerCatalog turns the data into Catalog.Fish and the pools, and
-- FishModels registers each Build. A module returns:
--
--   Name, Rarity (an AnglerCatalog.Rarities key), RarityDenominator (1 in N
--   encounter odds), MinKg, AverageKg, MaxKg (the rare HUGE record), BaseValue
--   (cash for an average-weight fish; open sea species are worth roughly
--   double their lake tier plus 20%, species in both somewhere between),
--   Fight (nudges the reel difficulty),
--   Shapes (cargo footprint per size class, see Shared.Cargo),
--   Pools?     AnglerCatalog.Pools keys it bites in; none for net, cage and drop items
--   Seasons?   Shared.Seasons names in calendar order; nil bites all year
--   Requires?  Shared.CatchConditions keys, e.g. { "Rain", "Night" }. Weather keys (FishCatch.WEATHER)
--              are alternatives, so { "Storm", "Supercell" } bites in either; every other key must hold
--   DropOnly?  true for rewards that never bite (shark parts)
--   Build?     function(b, kit) drawing the model with FishModels' Builder
local FishSpecies = {}

for _, module in script.Parent.Fish:GetChildren() do
	if module:IsA("ModuleScript") then
		FishSpecies[module.Name] = require(module)
	end
end

return FishSpecies
