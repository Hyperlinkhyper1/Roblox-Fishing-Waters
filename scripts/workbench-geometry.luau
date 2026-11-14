local checks = 0
local function check(condition, message)
	checks += 1
	assert(condition, message)
end
local function dummy(parent)
	local model = Instance.new("Model")
	model.Parent = parent
	return model
end
local FishFreezer, ShopDesk, OfficeDesk, StorageRack = { build = dummy }, { build = dummy }, { build = dummy }, { build = dummy }
local Kitchen = { buildCase = dummy, buildShelf = dummy, buildStorage = dummy, buildStation = dummy }
local DiningRoom, WeatherRadar, CompanyIslandMap = { buildTable = dummy }, { build = dummy }, { buildDesk = dummy }
local Decorations = { has = function() return false end }
local Recipes = { Stations = {} }
-- BUILD_SOURCE --
-- PREVIEWS_SOURCE --

local item = Furniture.Items.Workbench
check(item and item.Fixture and item.Cells[1] == 2 and item.Cells[2] == 1,
	"Workbench must be a two-cell house fixture")
check(table.find(Furniture.FixtureOrder, "Workbench") ~= nil, "Workbench must be available after pickup")
check(not table.find(Furniture.Order, "Workbench"), "The starting workbench must not be sold")
check(item.Front == 0 and item.Back == 0 and Furniture.allowedOn("Workbench", "Home"),
	"Decorative workbench must not reserve an interaction aisle")
local world, remotes = Instance.new("Folder"), Instance.new("Folder")
buildPreviews(remotes)
local preview = remotes:FindFirstChild("Previews"):FindFirstChild("Workbench")
check(preview and preview:IsA("Model"), "Workbench needs its actual placement preview")
local previewParts = 0
for _, part in preview:GetDescendants() do
	if part:IsA("BasePart") then
		previewParts += 1
		check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery,
			"Workbench preview must be inert")
	end
end

local partCount = 0
for _, houseFrame in { CFrame.identity, CFrame.new(170, 12, -45) * CFrame.Angles(0, 0.73, 0) } do
	for r = 0, 3 do
		local entry = { ItemId = "Workbench", X = 13.5, Z = -13.5, R = r }
		local model = buildItem(world, houseFrame, entry, 42)
		check(model and model.Parent == world and model:GetAttribute("ItemId") == "Workbench"
			and model:GetAttribute("R") == r, "Placed workbench must use furniture dispatch")
		local area = Furniture.footprint("Workbench", entry.X, entry.Z, r)
		local count, solid = 0, 0
		for _, part in model:GetDescendants() do
			check(not part:IsA("ProximityPrompt") and not part:IsA("ClickDetector") and not part:IsA("Seat")
				and not part:IsA("Tool"), "Workbench is currently decorative only")
			if not part:IsA("BasePart") then continue end
			count += 1
			check(part.Anchored and not part.CanTouch, "Workbench parts must be anchored and untouchable")
			if part.CanCollide then solid += 1 else check(not part.CanQuery, "Small details must not block pointer rays") end
			for _, x in { -0.5, 0.5 } do
				for _, y in { -0.5, 0.5 } do
					for _, z in { -0.5, 0.5 } do
						local p = houseFrame:PointToObjectSpace(part.CFrame * Vector3.new(x * part.Size.X, y * part.Size.Y, z * part.Size.Z))
						check(p.X >= area[1] - 0.001 and p.X <= area[3] + 0.001
							and p.Z >= area[2] - 0.001 and p.Z <= area[4] + 0.001,
							"Workbench exceeds its 2x1 footprint: " .. part.Name)
						check(p.Y >= 0.159 and p.Y <= Workbench.HEIGHT + 0.161, "Workbench must stand on the floor within its declared height")
					end
				end
			end
		end
		check(count >= 40 and count <= 250, "Workbench needs detail within a reasonable part budget")
		check(solid > 0 and solid < count, "Main furniture must be solid with inert fine details")
		check(count == previewParts, "Preview must include the full model")
		partCount = count
	end
end

local sample = Workbench.build(world, CFrame.identity)
for _, part in sample:GetDescendants() do
	if not part:IsA("BasePart") then continue end
	local f, s, c = part.CFrame, part.Size, part.Color
	print(string.format("@WORKBENCH %s %s %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f",
		part.Name, part.Shape or part.ClassName, f.Position.X, f.Position.Y, f.Position.Z,
		f.RightVector.X, f.RightVector.Y, f.RightVector.Z, f.UpVector.X, f.UpVector.Y, f.UpVector.Z,
		f.ZVector.X, f.ZVector.Y, f.ZVector.Z, s.X, s.Y, s.Z, c.R, c.G, c.B))
end
print(string.format("Workbench: %d geometry and dispatch checks passed; %d parts, all four rotations and transformed bases (recording doubles; no Roblox runtime).", checks, partCount))
