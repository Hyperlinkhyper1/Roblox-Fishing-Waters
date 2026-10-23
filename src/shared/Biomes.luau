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
}

export type Biome = {
	id: string,
	name: string,
	center: Vector2, -- X/Z in world space
	radius: number,
	seabed: Enum.Material,
	seabedColor: Color3,
	shelfDepth: number?, -- biome-wide seabed height; nil keeps the deep sea floor
	look: Look,
}

local rgb = Color3.fromRGB

local Biomes = {}

Biomes.Seed = 1847
Biomes.WaterLevel = 0
Biomes.SeaFloor = -64
Biomes.MapHalfSize = 5200
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
		waterColor = rgb(46, 110, 118),
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
	center = Vector2.new(-3700, -200),
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
	center = Vector2.new(-200, 3700),
	radius = 1300,
	seabed = Enum.Material.Limestone,
	seabedColor = rgb(226, 214, 170),
	shelfDepth = -22,
	look = {
		waterColor = rgb(38, 170, 170),
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
	center = Vector2.new(3700, 300),
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
	center = Vector2.new(300, -3700),
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
		waterColor = rgb(30, 80, 96),
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

Biomes.list = { Biomes.Normal, Biomes.Swamp, Biomes.Tropical, Biomes.Volcanic, Biomes.Ice } :: { Biome }

-- How far a point is into a biome, as a fraction of its radius (0 = center, 1 = edge).
function Biomes.depthIn(biome: Biome, position: Vector3): number
	return (Vector2.new(position.X, position.Z) - biome.center).Magnitude / biome.radius
end

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

return Biomes
