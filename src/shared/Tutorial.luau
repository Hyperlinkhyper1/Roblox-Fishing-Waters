-- The island tutorial: a chain of locals round the plaza who each explain one part of the game.
-- Pure data, so the server, the client and the tests read the same table. Spots are plaza-local
-- (x, z) offsets from the fountain, or offsets from a shop's door/counter when Anchor names one;
-- the server tries each spot in order and keeps the first that is clear of props.

local Tutorial = {}

-- $ granted once, the first time an angler finishes the tour.
Tutorial.REWARD = 250
-- How close the server requires a player to stand to the guide they finished talking to.
Tutorial.TALK_RANGE = 18

-- Each guide wears one of Roblox's own free avatar characters (bundles published by Roblox in the
-- Marketplace). OutfitId is the bundle's UserOutfit, loaded with Players:GetHumanoidDescriptionFromOutfitId.
Tutorial.Npcs = {
	Wren = {
		Name = "Captain Wren",
		Title = "Harbourmaster",
		OutfitId = 1992500252, -- Roblox "Kenneth" bundle
		Where = "by the fountain",
		Spots = { { 0, 26 }, { 9, 26 }, { -9, 26 }, { 0, -26 } },
		Face = { 0, 0 },
	},
	Pike = {
		Name = "Old Pike",
		Title = "Angler",
		OutfitId = 1545219396, -- Roblox "Oliver" bundle
		Where = "on the promenade by the bay",
		Spots = { { 17, 46 }, { 26, 45 }, { 17, 40 } },
		Face = { 17, 0 },
	},
	Juno = {
		Name = "Juno",
		Title = "Pack Trader",
		OutfitId = 1992514177, -- Roblox "Lindsey" bundle
		Where = "beside the backpack stall",
		-- Counter space: +z is the customers' side of the counter
		Anchor = "BackpackCounter",
		Spots = { { -7, 3 }, { 7, 3 }, { -7, 6 } },
		Fallback = { { 36, -26 } },
		Face = { 0, 12 },
	},
	Marlo = {
		Name = "Marlo",
		Title = "Fishmonger",
		OutfitId = 2219390889, -- Roblox "Dennis" bundle
		Where = "at the market stalls",
		Spots = { { 36, 0 }, { 36, 12 }, { 34, -12 } },
		Face = { 0, 0 },
	},
	Rosa = {
		Name = "Rosa",
		Title = "Tackle Hand",
		OutfitId = 2273580660, -- Roblox "Cindy" bundle
		Where = "outside Tide & Tackle",
		-- Door space: -z faces out of the door, +x is away from the chalkboard
		Anchor = "RodShopDoor",
		Spots = { { -4.5, -1 }, { -4.5, -3 }, { 4.5, -4 } },
		Fallback = { { -34, 30 } },
		Face = { 0, -12 },
	},
	Tess = {
		Name = "Tess",
		Title = "Dockhand",
		OutfitId = 1545101850, -- Roblox "Summer" bundle
		Where = "on the promenade in front of the Drydock",
		Spots = { { -5, 47 }, { -16, 46 }, { 5, 44 } },
		Face = { -5, 0 },
	},
	Hugo = {
		Name = "Hugo",
		Title = "Decorator",
		OutfitId = 3314419321, -- Roblox "Skyler" bundle
		Where = "outside Harbour Home",
		Anchor = "FurnitureShopDoor",
		Spots = { { -4.5, -1 }, { 4.5, -1 }, { -4.5, -3 } },
		Fallback = { { 34, 32 } },
		Face = { 0, -12 },
	},
}

Tutorial.Order = { "Wren", "Pike", "Juno", "Marlo", "Rosa", "Tess", "Hugo" }

-- One step per conversation, in order. Lines are pages of one dialogue; Goal is the tracker text.
Tutorial.Steps = {
	{
		Npc = "Wren",
		Goal = "Talk to Captain Wren by the plaza fountain",
		Lines = {
			"Ahoy, and welcome to the harbour! I'm Captain Wren. One of the docks along the shore is yours while you're here - your own shop and jetty included.",
			"The trade is simple: catch fish, sell them from your shop, and grow that little stall into a real business.",
			"My friends around the island each know one part of the job. Follow the yellow arrow and have a chat with each of them.",
			"First up is Old Pike on the promenade by the bay. Nobody on this island knows fishing better.",
		},
	},
	{
		Npc = "Pike",
		Goal = "Learn to fish from Old Pike on the promenade",
		Lines = {
			"So you want to fish? Stand at the water's edge - your own jetty is perfect - and get your rod out.",
			"Hold click to charge your cast and let go to throw. On a phone, hold the screen. The longer you hold, the further it flies.",
			"When a fish bites, click to start reeling. Then pull - press F or the Pull button - whenever the needle sits in the green. Pull in the red and the line goes slack.",
			"Deeper, stranger waters hold rarer fish, and storms bring out odd mutations. Juno at the backpack stall can tell you where your catch goes.",
		},
	},
	{
		Npc = "Juno",
		Goal = "Ask Juno about your catch at the backpack stall",
		Lines = {
			"Hi! Every fish you land goes into your backpack, and every backpack has a set number of tiles.",
			"Press C to open your hold. Click a fish to pick it up, press R to turn it, and click a free spot to pack it in. Big fish take more room!",
			"When your pack is full, bigger backpacks from my stall hold far more. Have a look whenever you've saved some coins.",
			"Full backpack? Then it's time to sell. Marlo at the market stalls will show you how.",
		},
	},
	{
		Npc = "Marlo",
		Goal = "Learn how to sell fish from Marlo at the market",
		Lines = {
			"Coins come from your own shop, back at your dock. Walk up to your freezer and use Place fish to put your catch on ice.",
			"Customers wander in and pick fish from the freezer. Walk over and use Sell to take their money.",
			"Later you can hire a seller to serve customers for you, and a porter to carry fish from your boat. Open the menu, go to Home and look under Workers.",
			"Your gear matters too. Rosa outside Tide & Tackle knows all about rods.",
		},
	},
	{
		Npc = "Rosa",
		Goal = "Visit Rosa outside Tide & Tackle",
		Lines = {
			"Welcome to Tide & Tackle! Inside, Finn at the counter upgrades your rod so it casts further and hooks bigger fish.",
			"There are rod crates in there too. Open one for a chance at a rare rod skin.",
			"Crab cages and mussel nets go out on the water and catch by themselves. Come back later and pull them up.",
			"And if you head out to deep water, take a shark spear. For boats, though, you'll want Tess by the Drydock.",
		},
	},
	{
		Npc = "Tess",
		Goal = "Ask Tess about boats in front of the Drydock",
		Lines = {
			"Boats take you to the far islands, where the rare fish live. Your free rowboat waits at your own dock - use Choose boat there to launch it.",
			"Mara inside the Drydock sells faster, bigger boats. A boat has its own cargo hold, so you can keep fishing long after your backpack is full.",
			"Hit rocks and your hull takes damage. Sail into the Drydock and use Lift & refit to repair it, or to upgrade and repaint it.",
			"Keep an eye on the weather radar before a long trip. Once you're earning, see Hugo outside Harbour Home about making your shop look the part.",
		},
	},
	{
		Npc = "Hugo",
		Goal = "Meet Hugo outside Harbour Home",
		Lines = {
			"Harbour Home sells furniture for your shop: freezers, shelves, tables and more. Some furniture even lets you store more fish.",
			"At your own shop, press B for build mode. Pick an item, move it with WASD or the mouse, turn it with R and click to place it.",
			"A busy, good-looking shop brings in more customers. Now go and tell Captain Wren how you got on!",
		},
	},
	{
		Npc = "Wren",
		Goal = "Report back to Captain Wren at the fountain",
		Lines = {
			"Back already? Then you know the ropes: fish, pack your catch, sell it at your shop, and spend the coins on better gear.",
			"Open the menu, go to Home and look at Paths. Finish a stage's goals and your fish shop grows into a supermarket, and later a restaurant or a fishing company.",
			"Press M for the map whenever you're lost. My friends stay where they are, so come back for a chat any time.",
			"First time round? Then here's a little something to get you started. And if you ever want the tour again, just type /tutorial in chat. Fair winds!",
		},
	},
}

function Tutorial.step(index: number)
	return Tutorial.Steps[index]
end

-- What a guide says when the player talks to them: the current step's lines when it is their turn,
-- otherwise their own last lesson (so they repeat their advice once the tour has moved on).
function Tutorial.dialogue(npcId: string, stepIndex: number?, done: boolean?): ({ string }, boolean)
	local current = stepIndex and not done and Tutorial.Steps[stepIndex]
	if current and current.Npc == npcId then
		return current.Lines, true
	end
	local fallback
	for index, step in Tutorial.Steps do
		if step.Npc == npcId then
			-- A guide who appears twice keeps their welcome until the tour reaches their later step.
			if fallback == nil or done or (stepIndex ~= nil and index <= stepIndex) then
				fallback = step.Lines
			end
		end
	end
	return fallback or {}, false
end

-- The step a "finished talking" request moves to, or nil if it is not that guide's turn.
function Tutorial.advance(stepIndex: number, done: boolean, npcId: string): (number?, boolean)
	local current = not done and Tutorial.Steps[stepIndex]
	if not current or current.Npc ~= npcId then
		return nil, done
	end
	if stepIndex >= #Tutorial.Steps then
		return stepIndex, true
	end
	return stepIndex + 1, false
end

return Tutorial
