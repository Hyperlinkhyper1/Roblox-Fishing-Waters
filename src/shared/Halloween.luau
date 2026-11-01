-- The town's Halloween party: on 31 October (in-game) the plaza fills with costumed locals and
-- decorations, and at the midnight into 1 November orange fireworks go up over the fountain.
-- Pure data and date rules, so the server, the client and the tests read the same table.

local Halloween = {}

-- The fireworks run this many in-game hours past midnight (one in-game hour is a real minute).
Halloween.FIREWORKS_HOURS = 1.5
-- The finale fills the last stretch of the show, in in-game hours.
Halloween.FINALE_HOURS = 0.3
Halloween.GUESTS = 28

-- "Party" all of 31 October, "Fireworks" for the start of 1 November, otherwise nil.
-- The guests and decorations stay up through the fireworks.
function Halloween.phase(date: { Month: number, Day: number, Hour: number }): string?
	if date.Month == 10 and date.Day == 31 then
		return "Party"
	elseif date.Month == 11 and date.Day == 1 and date.Hour < Halloween.FIREWORKS_HOURS then
		return "Fireworks"
	end
	return nil
end

-- A manually spawned party lasts only on the calendar day on which it was started.
function Halloween.forcedToday(date): boolean
	local day = workspace:GetAttribute("HalloweenEventDay")
	local ends = workspace:GetAttribute("HalloweenEventEnds")
	return type(day) == "number" and type(ends) == "number"
		and day == (date.Year - 1) * 365 + date.DayOfYear
		and workspace:GetServerTimeNow() < ends
end

function Halloween.partyActive(date): boolean
	return (date.Month == 10 and date.Day == 31) or Halloween.forcedToday(date)
end

-- Every guest wears one of Roblox's own avatar bundles, loaded with
-- Players:GetHumanoidDescriptionFromOutfitId from the bundle's UserOutfit.
-- Full Halloween costumes Roblox published as bundles.
Halloween.COSTUME_BUNDLES = {
	131929526, -- "Pumpkin Trick or Treater"
	131929455, -- "Ghastly Ghoul"
	132923275, -- "Dark Skeleton"
	131929527, -- "Cursed Mummy of Ramses II"
	132923255, -- "The Reaper"
	132923276, -- "Vampire Hunter"
	247408689, -- "Petrifying Pumpkin"
	247408657, -- "Dread Elder Warlock"
	2421793500, -- "Vie The Final Battle Witch"
	321286948, -- "Squad Ghouls: Drop Dead Tedd"
	131929491, -- "Korblox Skeleton"
	131929454, -- "Lord Umberhallow"
}
-- Everyday locals, who wear one of the costume accessory sets below on top.
Halloween.TOWNSFOLK_BUNDLES = {
	1992500252, -- "Kenneth"
	1545219396, -- "Oliver"
	1992514177, -- "Lindsey"
	2219390889, -- "Dennis"
	2273580660, -- "Cindy"
	1545101850, -- "Summer"
	3314419321, -- "Skyler"
	320870661, -- "City Life Man"
	320899613, -- "City Life Woman"
	3698903652, -- "Lumber Joe"
	3698841333, -- "Lumber Jessie"
	5556635361, -- "Lily the Baker"
	5556627777, -- "Belle the Seaside Girl"
	5556630827, -- "Ray the Hiker"
	5556656956, -- "Bonnie on Vacation"
	6264157260, -- "Fisherman"
	2397235071, -- "Cheerful Barista"
	4851269442, -- "Alice the Gardener"
}
-- Share of guests in a full costume bundle rather than a local in costume accessories.
Halloween.COSTUME_BUNDLE_SHARE = 0.35
-- Share of guests who are trick-or-treating children, scaled down.
Halloween.KID_SHARE = 0.25
Halloween.KID_SCALE = 0.72

-- Costume accessory sets, all Roblox-published catalog accessories. Each slot names a
-- HumanoidDescription accessory property and the asset ids to pick one from; it replaces
-- whatever the outfit wore in that slot. HideHair drops the outfit's hair under a full mask.
Halloween.COSTUMES = {
	Witch = {
		HatAccessory = {
			1117736987, -- Raven Witch Hat
			313545485, -- Shimmering Witch Hat
			2463692069, -- Knit Witch Hat
		},
		ShouldersAccessory = { 4078591838 }, -- Spooky Shoulder Black Cat
	},
	Pumpkin = {
		HideHair = true,
		HatAccessory = {
			58797026, -- Pumpkin Head
			1158416, -- Eerie Pumpkin Head
			14847637885, -- Spooky Pumpkin Head
			315548892, -- Googly Eyed Pumpkin
		},
		NeckAccessory = { 37820239 }, -- Pumpkin Necklace
	},
	Vampire = {
		HatAccessory = { 1117747196 }, -- Vampire's Top Hat
		NeckAccessory = { 63717491 }, -- Vampire Collar
		BackAccessory = { 1076568835 }, -- Vampire Cloak
	},
	Skeleton = {
		HideHair = true,
		HatAccessory = { 517261392 }, -- Friendly Skeleton Head
		BackAccessory = { 133554007 }, -- Demon Skeleton Wings
	},
	Ghost = {
		ShouldersAccessory = { 130448026520738 }, -- Disgruntled Sheet Ghost
		BackAccessory = {
			2445072894, -- Haunting Ghost Cape
			2413964589, -- Ghost Back Lantern
		},
	},
	Bat = {
		HatAccessory = { 1074738976 }, -- Bat Boppers
		FaceAccessory = { 63990657 }, -- Halloween Bat Shades
		BackAccessory = {
			302281482, -- Deluxe Bat Wings
			19399858, -- Dark Bat Wings
		},
	},
	Mummy = {
		HideHair = true,
		HatAccessory = { 315548534 }, -- Friendly Mummy
	},
	TrickOrTreater = {
		HatAccessory = {
			1117735914, -- Pumpkin Boppers
			94116435, -- Halloween Boo Bow Beanie
			184745025, -- Halloween Baseball Cap 2014
			2413854984, -- Halloween Ninja Headband
		},
		FaceAccessory = { 64560491 }, -- Pumpkin Shutter Shades
		NeckAccessory = { 129533465 }, -- Spooky Tie
	},
}
Halloween.COSTUME_ORDER = { "Witch", "Pumpkin", "Vampire", "Skeleton", "Ghost", "Bat", "Mummy", "TrickOrTreater" }

Halloween.NAMES = {
	"Mabel",
	"Otto",
	"Wilhelmina",
	"Bram",
	"Edgar",
	"Morticia",
	"Silas",
	"Hazel",
	"Ignatius",
	"Clementine",
	"Barnaby",
	"Ophelia",
	"Percival",
	"Winifred",
	"Ezra",
	"Lenore",
	"Thaddeus",
	"Agatha",
	"Rufus",
	"Prudence",
	"Cornelius",
	"Delphine",
	"Jasper",
	"Beatrix",
	"Mortimer",
	"Ivy",
	"Gus",
	"Nell",
	"Ambrose",
	"Elsie",
}

-- What the guests say, over their heads now and then and when someone talks to them.
Halloween.LINES = {
	"Happy Halloween!",
	"Trick or treat!",
	"Have you seen my other shoe? I think a ghost took it.",
	"I carved six pumpkins this year. Six!",
	"Fireworks at midnight, right here by the fountain!",
	"Is that a costume, or do you always look like that?",
	"The fish are biting extra hard tonight. Spooky.",
	"I heard something howling out past the lighthouse...",
	"Boo! Ha, got you.",
	"Best party the harbour has thrown in years.",
	"Someone swapped the candy for pickled herring again.",
	"Don't go near the old wreck after dark tonight.",
	"My cat dressed up as a fish. Or she ate one. Hard to say.",
	"These fangs are making it really hard to eat candy.",
	"I've had nine candy apples and I regret nothing.",
	"Say, do you think the sea monsters dress up too?",
	"Mind the cobwebs, they're real. Probably.",
	"I came as a pumpkin. Again. It's tradition.",
	"Old Pike says he caught a ghost fish once. I believe him.",
	"The baker made pumpkin pies shaped like squid!",
	"Spooky season is the best season.",
	"Ooooooooo! ...Sorry, still practising my ghost noise.",
	"Who keeps lighting all these lanterns? Not me.",
	"Stay till midnight, the fireworks are orange this year!",
	"I'm not scared. You're scared.",
	"Psst. The fountain water turns into soup at midnight. Probably.",
	"Happy Halloween from the whole harbour!",
	"I tried to scare a seagull. It scared me back.",
	"Mmm, smell those roasted pumpkin seeds.",
	"Don't eat the green candy. Trust me.",
}
-- Said during the fireworks instead.
Halloween.FIREWORK_LINES = {
	"Ooooh!",
	"Aaaah!",
	"Wow, look at that one!",
	"Happy November, everyone!",
	"Orange! It's all orange!",
	"Best fireworks ever!",
	"Did you see that? It looked like a pumpkin!",
	"Woohoo!",
}

-- Firework burst colours: orange shades, as RGB triples so the data stays Roblox-free.
Halloween.FIREWORK_COLORS = {
	{ 255, 140, 20 },
	{ 255, 110, 0 },
	{ 255, 170, 50 },
	{ 255, 95, 15 },
	{ 255, 190, 80 },
}

return Halloween
