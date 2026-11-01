-- Each roll is independent; every eligible contributor gets 2 to 5 rolls.
local SharkDrops = {}
SharkDrops.Table = {
	{ FishId = "SharkMeat", Name = "Shark Meat", Weight = 60 },
	{ FishId = "SharkFin", Name = "Shark Fin", Weight = 20 },
	{ FishId = "SharkTail", Name = "Shark Tail", Weight = 12 },
	{ FishId = "SharkHead", Name = "Shark Head", Weight = 5 },
	{ FishId = "GreatWhiteTooth", Name = "Great White Tooth", Weight = 3 },
}

function SharkDrops.roll(random)
	local drops = {}
	for _ = 1, random:NextInteger(2, 5) do
		local roll = random:NextInteger(1, 100)
		for _, item in SharkDrops.Table do
			roll -= item.Weight
			if roll <= 0 then
				table.insert(drops, { FishId = item.FishId, Name = item.Name })
				break
			end
		end
	end
	return drops
end

return SharkDrops
