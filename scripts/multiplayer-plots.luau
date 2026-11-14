
do
local function runPlotChecks()
	local checks = 0
	local function check(value, message) checks += 1; assert(value, message) end
	local Layout = (function()
		-- LAYOUT_SOURCE --
	end)()
	local Service = (function()
		-- SERVICE_SOURCE --
	end)()
	local originalGetService = game.GetService
	game.GetService = function(self, name)
		if name == "HttpService" then return { JSONEncode = function() return "[]" end } end
		return originalGetService(self, name)
	end
	dependencies.MetroStations = { ensureHarbour = function() end }
	-- Marketplace outfit loading has no bearing on static plot footprints.
	dependencies.Shipwright.scheduleAppearance = function() end
	local root = Instance.new("Folder")
	root.Name, root.Parent = "Map", workspace
	-- Use the real base, ring-road, back-lane and connecting-street builders.
	-- Distant forest/terrain triangulation is outside this local footprint audit;
	-- real terrain heights are sampled below and scenery clearance has fixtures.
	local island = Instance.new("Model"); island.Name, island.Parent = "Harbour Isle", root
	local bases = Instance.new("Folder"); bases.Name, bases.Parent = "Bases", island
	local village = Instance.new("Model"); village.Name, village.Parent = "Village", island
	local rng = Random.new(Biomes.Seed + 1)
	for id, anchor in Harbour.testAnchors do Harbour.buildBase(shape, bases, id, shape.toWorld(anchor), rng) end
	Harbour.testBuildStreets(shape, village, {}, shape.toWorld({870,665}), shape.toWorld({360,1640}))
	Harbour.rerouteShopRoads(island)
	check(#bases:GetChildren() == 15, "Fresh solo harbour retains fifteen normal bases")
	local originals = {}
	for _, base in bases:GetChildren() do
		originals[base:GetAttribute("BaseId")] = {
			base = base, frame = base:FindFirstChild("BaseHouse"):GetAttribute("HouseFrame"),
			dock = base:GetAttribute("BoatDockFrame"), spawn = base:FindFirstChild("SpawnPoint").CFrame,
		}
	end
	local forest = Instance.new("Model"); forest.Name, forest.Parent = "Forest", island
	local tree = Instance.new("Model"); tree.Name, tree.Parent = "ExpansionTree", forest
	local trunk = Instance.new("Part"); trunk.Size, trunk.CFrame, trunk.Parent = Vector3.new(2,12,2), originals[1].frame*CFrame.new(40,5,0), tree
	local distant = Instance.new("Part"); distant.Size, distant.CFrame, distant.Parent = Vector3.new(3,12,3), CFrame.new(4000,5,4000), forest
	local prepared, problem = Service.prepare(root)
	check(prepared, tostring(problem))
	check(tree.Parent == nil and distant.Parent == forest, "Only decorative scenery that overlaps larger land is removed")
	check(#bases:GetChildren() == 5, "Multiplayer harbour allocates exactly five enlarged properties")
	local selected = {}
	for _, base in bases:GetChildren() do
		local original = originals[base:GetAttribute("BaseId")]
		local house = base:FindFirstChild("BaseHouse")
		local extensions = base:FindFirstChild("MultiplayerPlotExtensions")
		check(base == original.base and house:GetAttribute("HouseFrame") == original.frame,
			"Preparing expanded land preserves original house and saved-layout frame")
		check(base:GetAttribute("BoatDockFrame") == original.dock and base:FindFirstChild("SpawnPoint").CFrame == original.spawn,
			"Expanded properties preserve dock launches and spawn positions")
		check(base:GetAttribute("MultiplayerPlot") and house:GetAttribute("MultiplayerPlot"),
			"Property and its house expose enlarged geometry to server and client")
		check(#extensions:GetChildren() == 4, "Each larger property has separately supported yard side wings")
		table.insert(selected, original.frame)
		for index, bound in Layout.Bounds.Home do
			check(bound[3] - bound[1] == (if index == 1 then 99 else 49.5), "Multiplayer home doubles its width while the shop keeps its safe footprint")
			for x = bound[1], bound[3], 4.5 do
				for z = bound[2], bound[4], 4.5 do
					local point = original.frame * Vector3.new(x,0,z)
					check(Harbour.heightAt(shape,Vector2.new(point.X,point.Z)) <= original.frame.Position.Y + 0.01,
						"Actual harbour terrain never rises through an expanded property")
				end
			end
		end
		for _, part in extensions:GetChildren() do
			local point = original.frame:PointToObjectSpace(part.Position)
			check(part.Anchored and part.CanCollide and part.CanQuery, "Expanded land provides solid queryable ground")
			check(point.Z + part.Size.Z / 2 <= 17.001 or point.Z - part.Size.Z / 2 >= 63.749,
				"Expansion never fills the road gap between house and shop")
			if part.Name == "MultiplayerYardFloor" or part.Name == "MultiplayerShopFloor" then
				check(math.abs(point.X) - part.Size.X / 2 >= 24.749, "Side wings never overlay the original central floors")
				local expected = if part.Name == "MultiplayerYardFloor" then 0 else 0.16
				check(math.abs(point.Y + part.Size.Y / 2 - expected) < 0.00001, "New side floors match the original yard/shop height")
			end
		end
	end
	for index, a in selected do
		for other = index + 1, #selected do
			check(Layout.separated(a, selected[other]), "Expanded houses, shop roofs, docks and approach envelopes have a walking gap")
		end
	end
	local parts = #island:GetDescendants()
	check(Service.prepare(root) and #island:GetDescendants() == parts, "Preparation is idempotent without duplicate floors")
	local missing = bases:GetChildren()[1]:FindFirstChild("MultiplayerPlotExtensions")
	missing:Destroy()
	check(Service.prepare(root) and #island:GetDescendants() == parts,
		"A stale baked version flag cannot bypass rebuilding missing enlarged ground")
	local function fixture(occupied)
		local map = Instance.new("Folder")
		local land = Instance.new("Model"); land.Name, land.Parent = "Harbour Isle", map
		local properties = Instance.new("Folder"); properties.Name, properties.Parent = "Bases", land
		for id, original in originals do
			local base = Instance.new("Model"); base.Name, base.Parent = "Base" .. id, properties
			base:SetAttribute("BaseId", id); base:SetAttribute("OwnerUserId", if occupied and id == 1 then 99 else 0)
			base:SetAttribute("BoatDockFrame", original.dock)
			CollectionService:AddTag(base, "PlayerBase")
			local house = Instance.new("Model"); house.Name, house.Parent = "BaseHouse", base
			house:SetAttribute("HouseFrame", original.frame)
		end
		return map, land, properties
	end
	local occupied, _, occupiedBases = fixture(true)
	check(not Service.prepare(occupied) and #occupiedBases:GetChildren() == 15, "An occupied harbour is never resized or cleared under live players")
	local blocked, blockedIsland, blockedBases = fixture(false)
	local road = Instance.new("Model"); road.Name, road.Parent = "Road", blockedIsland
	for _, original in originals do
		local obstacle = Instance.new("Part"); obstacle.Name, obstacle.Parent = "ProtectedRoad", road
		obstacle.Size, obstacle.CFrame = Vector3.new(10, 0.2, 10), original.frame * CFrame.new(40, -0.6, 0)
	end
	check(not Service.prepare(blocked) and #blockedBases:GetChildren() == 15, "Roads below floor height still prevent unsafe property expansion")
	check(#road:GetChildren() == 15, "Failed safety preflight preserves all public infrastructure and original bases")
	local external, _, externalBases = fixture(false)
	local publicShop = Instance.new("Model"); publicShop.Name, publicShop.Parent = "PublicShop", external
	CollectionService:AddTag(publicShop, "FurnitureShop")
	for _, original in originals do
		local fixturePart = Instance.new("Part"); fixturePart.Parent = publicShop
		fixturePart.Size, fixturePart.CFrame = Vector3.new(6,9,6), original.frame * CFrame.new(40,4,0)
	end
	check(not Service.prepare(external) and #externalBases:GetChildren() == 15,
		"Independent protected map geometry outside the harbour model prevents overlap")
	check(#publicShop:GetChildren() == 15, "Public shops are never removed to make an expanded plot fit")
	print("Multiplayer plots: " .. checks .. " production harbour, support, clearance and migration checks passed.")
end
runPlotChecks()
end
