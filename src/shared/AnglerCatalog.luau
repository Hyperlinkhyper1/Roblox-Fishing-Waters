-- Add each new species here once; the bestiary and journal read this registry.
-- Fish entries: { Name, Image = "rbxassetid://...", AverageKg, RarityDenominator }.
-- RarityDenominator is the base encounter odds (e.g. 100 means 1 in 100).
local Catalog = {}
Catalog.Fish = {}
Catalog.Mutations = { Normal = { Name = "Normal", RarityMultiplier = 1 } }
Catalog.Equipment = {
	StarterRod = {
		Name = "Starter fishing rod",
		Kind = "Fishing rod",
		Description = "Your first companion on the water.",
	},
}
-- Titles are awarded by server gameplay, never by the menu client.
Catalog.Titles = {}
return Catalog
