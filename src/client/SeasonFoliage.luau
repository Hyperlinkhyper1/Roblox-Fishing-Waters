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

local BATCH = 120 -- shared limit for each foliage pass, including streamed arrivals
local FRAME_BUDGET = 0.001
local GROUND_AREA = 400 -- a part this wide on top is lawn, not leaves
local PIECE_TAG = "LodPiece" -- streamed map pieces (server/Map/Lod)
local PART_TAG = "SeasonFoliagePart" -- individually streamed city ground and trees
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
		local color = tint(entry.original, season, entry.ground, entry.seed)
		if part.Color ~= color then part.Color = color end
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
		local started = os.clock()
		for _, part in parts do
			if mine ~= generation then
				return
			end
			local entry = tracked[part]
			if entry and part.Parent then
				apply(part, entry)
				count += 1
				if count % BATCH == 0 or os.clock() - started >= FRAME_BUDGET then
					RunService.Heartbeat:Wait()
					started = os.clock()
				end
			end
		end
	end

	-- Queue the roots of whole streaming pieces, not one thread per descendant. A burst of
	-- pieces shares one frame budget; scanning each tag callback synchronously used to tint
	-- every arriving island in the same frame. Walk child lists incrementally so startup also
	-- avoids allocating a snapshot of every instance in workspace.
	local scans, queued, head = {}, {}, 1
	local pendingParts: { [BasePart]: boolean } = {}
	CollectionService:GetInstanceAddedSignal(PART_TAG):Connect(function(part)
		if part:IsA("BasePart") then pendingParts[part] = true end
	end)
	CollectionService:GetInstanceRemovedSignal(PART_TAG):Connect(function(part)
		pendingParts[part :: BasePart] = nil
	end)
	local function scanPiece(piece: Instance)
		if queued[piece] then return end
		local scan = { root = piece, stack = { { items = { piece }, next = 1 } } }
		queued[piece] = scan
		table.insert(scans, scan)
	end
	CollectionService:GetInstanceAddedSignal(PIECE_TAG):Connect(scanPiece)
	CollectionService:GetInstanceRemovedSignal(PIECE_TAG):Connect(function(piece)
		queued[piece] = nil
	end)
	-- Include existing non-piece scenery (including persistent shells). Nested LodPieces
	-- receive their own jobs and are never traversed twice by the startup scan.
	scanPiece(workspace)
	RunService.Heartbeat:Connect(function()
		local started, count = os.clock(), 0
		-- Leave room for the regular walker when a city streams many leaves at once.
		for part in pendingParts do
			if count >= BATCH / 2 or os.clock() - started >= FRAME_BUDGET then break end
			pendingParts[part] = nil
			if part:IsDescendantOf(workspace) then
				local entry = tracked[part]
				if entry then apply(part, entry) else consider(part) end
			end
			count += 1
		end
		while head <= #scans and count < BATCH and os.clock() - started < FRAME_BUDGET do
			local scan = scans[head]
			local root, stack = scan.root, scan.stack
			if queued[root] ~= scan or (root ~= workspace and not root:IsDescendantOf(workspace)) or #stack == 0 then
				if queued[root] == scan then queued[root] = nil end
				scans[head] = false
				head += 1
				count += 1
				continue
			end
			local frame = stack[#stack]
			local item = frame.items[frame.next]
			frame.next += 1
			count += 1
			if not item then
				table.remove(stack)
			elseif item == workspace or item:IsDescendantOf(workspace) then
				if item ~= root and item:HasTag(PIECE_TAG) then
					scanPiece(item)
				else
					consider(item)
					local children = item:GetChildren()
					if #children > 0 then table.insert(stack, { items = children, next = 1 }) end
				end
			end
		end
		if head > #scans then
			table.clear(scans)
			head = 1
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
