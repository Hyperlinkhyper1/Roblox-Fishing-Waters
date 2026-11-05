-- Upgrade masks grow without removing any cell from the previous tier.
local Catalog = {
	Order = {
		"Starter",
		"Satchel",
		"Tackle",
		"Creel",
		"Cooler",
		"Beacon",
		"Angler",
		"Reef",
		"Explorer",
		"Treasure",
		"Expedition",
		"Diving",
		"Storm",
		"Lunar",
		"Abyss",
	},
	Items = {
		Starter = {
			Name = "Burlap pouch",
			Price = 0,
			Description = "A tied canvas pouch for your first catches.",
			Hold = { "##", "##" },
		},
		Satchel = {
			Name = "Leather satchel",
			Price = 100,
			Description = "A stitched shoulder satchel with a brass clasp.",
			Hold = { "##", "##", "##" },
		},
		Tackle = {
			Name = "Tackle box",
			Price = 250,
			Description = "A red steel tackle case with twin latches.",
			Hold = { "##", "##", "##", "##" },
		},
		Creel = {
			Name = "Wicker creel",
			Price = 450,
			Description = "A woven fishing basket with a wooden lid.",
			Hold = { "###", "###", "###", "###" },
		},
		Cooler = {
			Name = "Ice cooler",
			Price = 900,
			Description = "An insulated blue cooler for a longer trip.",
			Hold = { "####", "####", "####", "####" },
		},
		Beacon = {
			Name = "Beacon lantern",
			Price = 1600,
			Description = "A brass harbour lantern with a warm glass core.",
			Hold = { "####", "####", "####", "####", "####" },
		},
		Angler = {
			Name = "Angler backpack",
			Price = 2500,
			Description = "A green field pack with rod tubes and side pockets.",
			Hold = { "####", "####", "####", "####", "####", "####" },
		},
		Reef = {
			Name = "Reef aquarium",
			Price = 4000,
			Description = "A round reef tank with coral and a tiny fish.",
			Hold = { "#####", "#####", "#####", "#####", "#####", "#####" },
		},
		Explorer = {
			Name = "Explorer rolltop",
			Price = 6500,
			Description = "A waxed rolltop with a compass and orange straps.",
			Hold = { "######", "######", "######", "######", "######", "######" },
		},
		Treasure = {
			Name = "Treasure chest",
			Price = 10000,
			Description = "A sea-worn chest filled with gold and gems.",
			Hold = { "######", "######", "######", "######", "######", "######", "######" },
		},
		Expedition = {
			Name = "Expedition pack",
			Price = 16000,
			Description = "A trail pack with a bedroll and hanging mug.",
			Hold = { "######", "######", "######", "######", "######", "######", "######", "######" },
		},
		Diving = {
			Name = "Diving rig",
			Price = 25000,
			Description = "Twin air cylinders in a deep-sea harness.",
			Hold = { "#######", "#######", "#######", "#######", "#######", "#######", "#######", "#######" },
		},
		Storm = {
			Name = "Storm battery",
			Price = 40000,
			Description = "A storm-powered coil with electric blue fins.",
			Hold = { "########", "########", "########", "########", "########", "########", "########", "########" },
		},
		Lunar = {
			Name = "Lunar observatory",
			Price = 65000,
			Description = "A moonstone pod carrying a small brass telescope.",
			Hold = {
				"########",
				"########",
				"########",
				"########",
				"########",
				"########",
				"########",
				"########",
				"########",
			},
		},
		-- Black Hole Backpack gamepass (999 Robux). Not sold for cash and not in
		-- Order: owning the pass replaces whatever pack is saved (layoutFor).
		-- The rows retain the legacy shape; the Infinite flag on the mask
		-- makes Cargo.capacity unlimited.
		BlackHole = {
			Name = "Black hole backpack",
			Price = 0,
			Gamepass = "BlackHoleBackpack",
			Description = "A captive singularity in a containment harness. Infinite fish storage.",
			Hold = table.freeze(setmetatable({
				"##########",
				"##########",
				"##########",
				"##########",
				"##########",
				"##########",
				"##########",
				"##########",
				"##########",
				"##########",
			}, { __index = { Infinite = true } })),
		},
		Abyss = {
			Name = "Abyss reactor",
			Price = 100000,
			Description = "A dark pressure vessel glowing with abyssal energy.",
			Hold = {
				"########",
				"########",
				"########",
				"########",
				"########",
				"########",
				"########",
				"########",
				"########",
				"########",
			},
		},
	},
}

function Catalog.rank(id): number
	return table.find(Catalog.Order, id) or 0
end

-- The id a player actually carries: the gamepass pack overrides the saved one.
-- The server sets OwnsBlackHoleBackpack, so clients read the same answer.
function Catalog.carriedId(player: Player?, savedId: string?): string
	if player and player:GetAttribute("OwnsBlackHoleBackpack") == true then
		return "BlackHole"
	end
	return if savedId and Catalog.Items[savedId] and not Catalog.Items[savedId].Gamepass then savedId else "Starter"
end

function Catalog.layoutFor(player: Player?, savedId: string?)
	return Catalog.Items[Catalog.carriedId(player, savedId)]
end

return Catalog
