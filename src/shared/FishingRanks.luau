-- Each rank starts at its minimum level and lasts until the next threshold.
local FishingRanks = {}

FishingRanks.Order = {
	{ Level = 0, Name = "Beginner", Color = Color3.fromRGB(255, 225, 75) },
	{ Level = 10, Name = "Student Fisher", Color = Color3.fromRGB(255, 190, 65) },
	{ Level = 15, Name = "Novice Fisher", Color = Color3.fromRGB(255, 145, 70) },
	{ Level = 20, Name = "Good Fisher", Color = Color3.fromRGB(255, 100, 85) },
	{ Level = 25, Name = "Experienced Fisher", Color = Color3.fromRGB(245, 80, 135) },
	{ Level = 35, Name = "Veteran Fisher", Color = Color3.fromRGB(220, 75, 195) },
	{ Level = 50, Name = "Master Fisher", Color = Color3.fromRGB(180, 80, 235) },
	{ Level = 75, Name = "Poseidon", Color = Color3.fromRGB(140, 65, 255) },
}

function FishingRanks.forLevel(level: number)
	local rank = FishingRanks.Order[1]
	for _, candidate in FishingRanks.Order do
		if level < candidate.Level then
			break
		end
		rank = candidate
	end
	return rank
end

return FishingRanks
