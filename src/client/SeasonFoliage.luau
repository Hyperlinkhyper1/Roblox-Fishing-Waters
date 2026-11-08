-- Recolours grass and tree foliage on this client to match the season. Summer is
-- the map as built; every other season is a tint over each part's own colour, so
-- the builders' shading survives. Foliage is any green Grass or LeafyGrass part,
-- plus the terrain's grass materials, picked up again as islands stream in. The tropics (the Coral
-- Shallows and Pirate Cove) have no seasons, so their foliage stays as built all year.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Seasons = require(ReplicatedStorage.Shared.Seasons)
local Biomes = require(ReplicatedStorage.Shared.Biomes)

local SeasonFoliage = {}

local BATCH = 600 -- parts recoloured per frame when the season turns
local GROUND_AREA = 400 -- a part this wide on top is lawn, not leaves
local PIECE_TAG = "LodPiece" -- streamed map pieces (server/Map/Lod)
local rgb = Color3.fromRGB

local SPRING = rgb(132, 198, 84)
local AUTUMN_GROUND = rgb(158, 140, 72)
local AUTUMN_LEAVES = { rgb(214, 124, 42), rgb(188, 72, 38), rgb(228, 178, 62), rgb(162, 98, 46) }
local SNOW = rgb(234, 240, 244)
local FROST = rgb(222, 230, 234)

local foliageMaterials = { [Enum.Material.Grass] = true, [Enum.Material.LeafyGrass] = true }

local function isGreen(color: Color3): boolean
	local h, s, v = color:ToHSV()
	return h >= 0.16 and h <= 0.48 and s >= 0.18 and v >= 0.12
end

local function tint(original: Color3, season: string, ground: boolean, seed: number): Color3
	if season == "Spring" then
		return original:Lerp(SPRING, 0.35)
	elseif season == "Autumn" then
		if ground then
			return original:Lerp(AUTUMN_GROUND, 0.55)
		end
		return original:Lerp(AUTUMN_LEAVES[seed % #AUTUMN_LEAVES + 1], 0.72)
	elseif season == "Winter" then
		return original:Lerp(if ground then SNOW else FROST, if ground then 0.8 else 0.5)
	end
	return original
end

-- Neighbouring leaves get different autumn colours, but a part keeps its own.
local function seedOf(part: BasePart): number
	local p = part.Position
	return math.abs(
		math.floor(p.X * 0.37) * 73856093 + math.floor(p.Y * 0.53) * 19349663 + math.floor(p.Z * 0.41) * 83492791
	)
end

function SeasonFoliage.tint(original: Color3, season: string, ground: boolean, seed: number): Color3
	return tint(original, season, ground, seed)
end

function SeasonFoliage.start()
	type Entry = { original: Color3, ground: boolean, seed: number }
	local tracked: { [BasePart]: Entry } = setmetatable({}, { __mode = "k" }) :: any
	local season = Seasons.current()
	local terrain = workspace.Terrain
	local terrainOriginal = {}
	for material in foliageMaterials do
		terrainOriginal[material] = terrain:GetMaterialColor(material)
	end

	local function apply(part: BasePart, entry: Entry)
		part.Color = tint(entry.original, season, entry.ground, entry.seed)
	end

	local function consider(item: Instance)
		if not item:IsA("BasePart") or tracked[item] or not foliageMaterials[item.Material] then
			return
		end
		if not isGreen(item.Color) or item:GetAttribute("SeasonExempt") then
			return
		end
		if Biomes.at(item.Position).id == "tropical" then
			return
		end
		-- Characters, held tools and boats keep their own colours.
		local model = item:FindFirstAncestorWhichIsA("Model")
		if item:FindFirstAncestorWhichIsA("Tool") or (model and model:FindFirstChildOfClass("Humanoid")) then
			return
		end
		local entry = {
			original = item.Color,
			ground = item.Size.X * item.Size.Z >= GROUND_AREA and item.Size.Y < math.min(item.Size.X, item.Size.Z),
			seed = seedOf(item),
		}
		tracked[item] = entry
		if season ~= "Summer" then
			apply(item, entry)
		end
	end

	local function applyTerrain()
		for material, original in terrainOriginal do
			terrain:SetMaterialColor(material, tint(original, season, true, 0))
		end
	end

	local generation = 0
	local function recolour()
		generation += 1
		local mine = generation
		applyTerrain()
		-- Parts streaming in mid-pass are tinted on arrival, so a snapshot is enough.
		local parts = {}
		for part in tracked do
			table.insert(parts, part)
		end
		local count = 0
		for _, part in parts do
			if mine ~= generation then
				return
			end
			local entry = tracked[part]
			if entry and part.Parent then
				apply(part, entry)
				count += 1
				if count % BATCH == 0 then
					RunService.Heartbeat:Wait()
				end
			end
		end
	end

	-- Map content streams in as LodPiece models that arrive whole (PersistentPerPlayer), so one
	-- scan per piece picks up its foliage. Watching workspace.DescendantAdded instead resumed a
	-- script thread for every part, weld and decal streaming in: tens of thousands per island,
	-- the deferredThreads storms in the MicroProfiler.
	local function scanPiece(piece: Instance)
		for _, item in piece:GetDescendants() do
			consider(item)
		end
	end
	CollectionService:GetInstanceAddedSignal(PIECE_TAG):Connect(scanPiece)
	task.spawn(function()
		local count = 0
		for _, item in workspace:GetDescendants() do
			consider(item)
			count += 1
			if count % 4000 == 0 then
				RunService.Heartbeat:Wait()
			end
		end
	end)
	applyTerrain()

	-- The clock turns the season every few in-game days; the override flips it at once.
	local function check()
		local now = Seasons.current()
		if now ~= season then
			season = now
			task.spawn(recolour)
		end
	end
	workspace:GetAttributeChangedSignal("SeasonOverride"):Connect(check)
	task.spawn(function()
		while Players.LocalPlayer do
			task.wait(5)
			check()
		end
	end)
end

return SeasonFoliage
