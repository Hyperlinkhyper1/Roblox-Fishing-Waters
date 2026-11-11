-- World layout and mood for each biome. Shared so the server can build the map
-- and the client can match the atmosphere to wherever the camera is.

export type Look = {
	waterColor: Color3,
	atmosphereColor: Color3,
	atmosphereDecay: Color3,
	density: number,
	haze: number,
	glare: number,
	tint: Color3,
	saturation: number,
	contrast: number,
	ambient: Color3,
	cloudCover: number,
	cloudColor: Color3,
	sunRays: number?, -- daytime sun-ray strength on a clear sky; nil = the usual faint rays
}

export type Biome = {
	id: string,
	name: string,
	center: Vector2, -- X/Z in world space
	radius: number,
	seabed: Enum.Material,
	seabedColor: Color3,
	shelfDepth: number?, -- biome-wide seabed height; nil keeps the deep sea floor
	parent: string?, -- zones only: the terrain biome they sit inside
	look: Look,
}

local rgb = Color3.fromRGB

local Biomes = {}

Biomes.Seed = 1847
Biomes.WaterLevel = 0
-- Shared by map setup and client biome transitions so clarity stays consistent.
Biomes.SurfaceWaterTransparency = 0.45
Biomes.WaterReflectance = 0.12
Biomes.SeaFloor = -64
Biomes.MapHalfSize = 5200
-- The original archipelago keeps its generation bounds; the ocean extends
-- farther southeast to encompass the distant city and its approaches.
Biomes.OceanMin = -Biomes.MapHalfSize
Biomes.OceanMax = 8200
Biomes.CityOceanStart = 4200
-- Dry rooms below sea level inside the ocean bounds: the two metro stations. The map
-- clears terrain water out of them, and nobody in them is underwater.
Biomes.DryPockets = {
	{ min = Vector3.new(6618, -46, 6882), max = Vector3.new(6884, 8, 7032) },
	-- Gullhaven's recessed east-row entrance and its 172-stud platform hall.
	{ min = Vector3.new(62, -34, -678), max = Vector3.new(172, 12, -500) },
}

function Biomes.inOceanBounds(position: Vector3): boolean
	for _, pocket in Biomes.DryPockets do
		local lo, hi = pocket.min, pocket.max
		if
			position.X > lo.X and position.X < hi.X
			and position.Y > lo.Y and position.Y < hi.Y
			and position.Z > lo.Z and position.Z < hi.Z
		then
			return false
		end
	end
	local original = math.abs(position.X) < Biomes.MapHalfSize and math.abs(position.Z) < Biomes.MapHalfSize
	local southeast = position.X > Biomes.CityOceanStart and position.X < Biomes.OceanMax
		and position.Z > Biomes.CityOceanStart and position.Z < Biomes.OceanMax
	return original or southeast
end
-- Blend distant islands into the horizon instead of keeping sharp silhouettes.
Biomes.DistanceFogOffset = 0.1

Biomes.Normal = {
	id = "normal",
	name = "Gullhaven Sound",
	center = Vector2.new(0, 0),
	radius = 1300,
	seabed = Enum.Material.Sand,
	seabedColor = rgb(206, 190, 148),
	look = {
		waterColor = rgb(82, 105, 132),
		atmosphereColor = rgb(199, 205, 200),
		atmosphereDecay = rgb(92, 106, 114),
		density = 0.32,
		haze = 1.8,
		glare = 0.2,
		tint = rgb(240, 245, 245),
		saturation = -0.05,
		contrast = 0.05,
		ambient = rgb(128, 132, 136),
		cloudCover = 0.55,
		cloudColor = rgb(230, 232, 235),
	},
} :: Biome

Biomes.Swamp = {
	id = "swamp",
	name = "The Sodden Mire",
	center = Vector2.new(-3750, -1000),
	radius = 1250,
	seabed = Enum.Material.Mud,
	seabedColor = rgb(64, 58, 36),
	shelfDepth = -14,
	look = {
		waterColor = rgb(92, 84, 46),
		atmosphereColor = rgb(214, 190, 128),
		atmosphereDecay = rgb(140, 110, 60),
		density = 0.42,
		haze = 2.8,
		glare = 0.1,
		tint = rgb(255, 236, 200),
		saturation = -0.1,
		contrast = 0.04,
		ambient = rgb(140, 126, 96),
		cloudCover = 0.7,
		cloudColor = rgb(220, 200, 160),
	},
} :: Biome

Biomes.Tropical = {
	id = "tropical",
	name = "Coral Shallows",
	center = Vector2.new(-1200, 3000),
	radius = 1300,
	seabed = Enum.Material.Limestone,
	seabedColor = rgb(226, 214, 170),
	shelfDepth = -22,
	look = {
		waterColor = rgb(82, 137, 151),
		atmosphereColor = rgb(210, 235, 240),
		atmosphereDecay = rgb(120, 170, 190),
		density = 0.28,
		haze = 1.2,
		glare = 0.6,
		tint = rgb(255, 252, 240),
		saturation = 0.15,
		contrast = 0.06,
		ambient = rgb(150, 156, 150),
		cloudCover = 0.45,
		cloudColor = rgb(255, 255, 255),
	},
} :: Biome

Biomes.Volcanic = {
	id = "volcanic",
	name = "Cinder Isles",
	center = Vector2.new(3300, 1300),
	radius = 1250,
	seabed = Enum.Material.Basalt,
	seabedColor = rgb(38, 36, 38),
	look = {
		waterColor = rgb(40, 46, 50),
		atmosphereColor = rgb(180, 110, 90),
		atmosphereDecay = rgb(90, 40, 30),
		density = 0.38,
		haze = 2.3,
		glare = 0.4,
		tint = rgb(255, 220, 205),
		saturation = -0.05,
		contrast = 0.12,
		ambient = rgb(120, 96, 90),
		cloudCover = 0.75,
		cloudColor = rgb(110, 96, 92),
	},
} :: Biome

Biomes.Ice = {
	id = "ice",
	name = "Frostmere Expanse",
	center = Vector2.new(1000, -3800),
	radius = 1300,
	seabed = Enum.Material.Glacier,
	seabedColor = rgb(150, 186, 204),
	look = {
		waterColor = rgb(70, 120, 150),
		atmosphereColor = rgb(215, 228, 240),
		atmosphereDecay = rgb(150, 175, 200),
		density = 0.36,
		haze = 2,
		glare = 0.3,
		tint = rgb(230, 240, 255),
		saturation = -0.2,
		contrast = 0.05,
		ambient = rgb(150, 160, 175),
		cloudCover = 0.65,
		cloudColor = rgb(240, 245, 250),
	},
} :: Biome

Biomes.OpenSea = {
	id = "open",
	name = "Open Waters",
	center = Vector2.new(0, 0),
	radius = 0,
	seabed = Enum.Material.Slate,
	seabedColor = rgb(56, 74, 80),
	look = {
		waterColor = rgb(66, 87, 114),
		atmosphereColor = rgb(180, 190, 195),
		atmosphereDecay = rgb(70, 85, 95),
		density = 0.35,
		haze = 2.1,
		glare = 0.2,
		tint = rgb(235, 240, 245),
		saturation = -0.1,
		contrast = 0.06,
		ambient = rgb(118, 124, 130),
		cloudCover = 0.6,
		cloudColor = rgb(215, 220, 225),
	},
} :: Biome

-- Pirate Cove: a small biome of its own inside the Coral Shallows, golden and hazy with the low
-- sun blooming through sea mist. A zone keeps its parent's seabed and terrain (map generation
-- only walks Biomes.list), but has its own name, mood and fish pool.
Biomes.PirateCove = {
	id = "piratecove",
	name = "Pirate Cove",
	-- Shared.PirateCove.CENTER; the island (RADIUS 170) plus its anchorage.
	center = Vector2.new(-650, 2150),
	radius = 260,
	parent = "tropical",
	seabed = Biomes.Tropical.seabed,
	seabedColor = Biomes.Tropical.seabedColor,
	shelfDepth = Biomes.Tropical.shelfDepth,
	look = {
		waterColor = rgb(104, 132, 152),
		atmosphereColor = rgb(236, 216, 186),
		atmosphereDecay = rgb(196, 152, 124),
		density = 0.4,
		haze = 2.7,
		glare = 1.4,
		tint = rgb(255, 238, 220),
		saturation = -0.04,
		contrast = 0.02,
		ambient = rgb(164, 150, 136),
		cloudCover = 0.5,
		cloudColor = rgb(255, 234, 212),
		sunRays = 0.12,
	},
} :: Biome

Biomes.list = { Biomes.Normal, Biomes.Swamp, Biomes.Tropical, Biomes.Volcanic, Biomes.Ice } :: { Biome }
-- Small biomes nested inside a terrain biome; Biomes.zoneAt checks them first.
Biomes.zones = { Biomes.PirateCove } :: { Biome }

-- How far a point is into a biome, as a fraction of its radius (0 = center, 1 = edge).
function Biomes.depthIn(biome: Biome, position: Vector3): number
	return (Vector2.new(position.X, position.Z) - biome.center).Magnitude / biome.radius
end

-- The terrain biome at `position` (seabed, scenery, sharks). Ignores zones.
function Biomes.at(position: Vector3): Biome
	local best, bestDepth = Biomes.OpenSea, 1
	for _, biome in Biomes.list do
		local depth = Biomes.depthIn(biome, position)
		if depth < bestDepth then
			best, bestDepth = biome, depth
		end
	end
	return best
end

-- The biome a player is in for its mood, name and fish: a zone when inside one, else Biomes.at.
function Biomes.zoneAt(position: Vector3): Biome
	for _, zone in Biomes.zones do
		if Biomes.depthIn(zone, position) < 1 then
			return zone
		end
	end
	return Biomes.at(position)
end

return Biomes
