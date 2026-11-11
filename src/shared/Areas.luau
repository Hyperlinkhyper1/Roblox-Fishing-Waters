-- Named places the client announces with a big "now entering" banner (client AreaBanner):
-- the five biomes, the zones nested inside them (Pirate Cove), the open water between them,
-- and landmarks (the Modern City). Positions are X/Z only, so this stays a cheap per-tick lookup.

local Biomes = require(script.Parent.Biomes)

export type Area = {
	id: string,
	name: string,
	subtitle: string,
	accent: Color3,
	center: Vector2,
	radius: number, -- 0 = everywhere nothing else claims (open water)
	parent: string?, -- landmarks: the area they sit in; leaving one back into it stays quiet
}

local Areas = {}

-- Stay in an area until this far past its edge (fraction of its radius), so sailing along a
-- boundary never flickers the banner.
Areas.LEAVE_MARGIN = 1.1

local rgb = Color3.fromRGB

local BIOME_STYLE = {
	normal = { subtitle = "Home waters", accent = rgb(150, 196, 226) },
	swamp = { subtitle = "Murky marsh waters", accent = rgb(196, 182, 104) },
	tropical = { subtitle = "Warm lagoon waters", accent = rgb(110, 222, 214) },
	volcanic = { subtitle = "Ash and ember waters", accent = rgb(255, 136, 92) },
	ice = { subtitle = "Frozen northern waters", accent = rgb(196, 230, 255) },
	piratecove = { subtitle = "Hazy golden waters", accent = rgb(240, 196, 110) },
	open = { subtitle = "The deep open sea", accent = rgb(120, 160, 205) },
}

local byBiome: { [string]: Area } = {}
local terrainAndZones = table.clone(Biomes.list)
for _, zone in Biomes.zones do
	table.insert(terrainAndZones, zone)
end
for _, biome in terrainAndZones do
	local style = BIOME_STYLE[biome.id]
	byBiome[biome.id] = {
		id = biome.id,
		name = biome.name,
		subtitle = style.subtitle,
		accent = style.accent,
		center = biome.center,
		radius = biome.radius,
	}
end
byBiome.open = {
	id = "open",
	name = Biomes.OpenSea.name,
	subtitle = BIOME_STYLE.open.subtitle,
	accent = BIOME_STYLE.open.accent,
	center = Biomes.OpenSea.center,
	radius = 0,
}
Areas.Biomes = byBiome

-- Checked before biomes, so a zone or landmark wins inside the biome that holds it. Zones are
-- biomes of their own: leaving one back into its surroundings is announced like any border.
Areas.Landmarks = {
	byBiome.piratecove,
	{
		id = "city",
		name = "Modern City",
		subtitle = "The mainland",
		accent = rgb(230, 222, 200),
		-- ModernCity's CENTER; the coast and lighthouse reach ~1,700 studs out.
		center = Vector2.new(7000, 7000),
		radius = 1800,
		parent = "open",
	},
} :: { Area }

-- Fraction of an area's radius a point is from its centre (0 = centre, 1 = edge).
function Areas.depthIn(area: Area, position: Vector3): number
	if area.radius <= 0 then
		return math.huge
	end
	local dx, dz = position.X - area.center.X, position.Z - area.center.Y
	return math.sqrt(dx * dx + dz * dz) / area.radius
end

-- The area at `position`, given the one the player was last in (for hysteresis).
function Areas.at(position: Vector3, current: Area?): Area
	for _, landmark in Areas.Landmarks do
		local limit = if landmark == current then Areas.LEAVE_MARGIN else 1
		if Areas.depthIn(landmark, position) < limit then
			return landmark
		end
	end
	if
		current
		and current.radius > 0
		and not current.parent
		and Areas.depthIn(current, position) < Areas.LEAVE_MARGIN
	then
		return current
	end
	return byBiome[Biomes.at(position).id] or byBiome.open
end

-- Whether moving from `previous` into `area` deserves a banner. Stepping off a landmark back
-- into the water around it (Modern City -> Open Waters) is not news.
function Areas.announces(previous: Area?, area: Area): boolean
	if previous == area then
		return false
	end
	return not (previous and previous.parent == area.id)
end

return Areas
