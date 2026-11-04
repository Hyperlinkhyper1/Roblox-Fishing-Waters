-- Render every decoration through the production base and preview paths.
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local function dummy(parent)
	local model = Instance.new("Model")
	local part = Instance.new("Part")
	part.Parent = model
	model.Parent = parent
	return model
end
local FishFreezer = { build = dummy }
local ShopDesk = { build = dummy }
local StorageRack = { build = dummy }
local Kitchen = { buildCase = dummy, buildStorage = dummy, buildStation = dummy }
local DiningRoom = { buildTable = dummy }
local WeatherRadar = { build = dummy }
local CompanyIslandMap = { buildDesk = dummy }
local Recipes = { Stations = {} }
-- BUILD_SOURCE --
-- PREVIEWS_SOURCE --
local world = Instance.new("Folder")
local remotes = Instance.new("Folder")
buildPreviews(remotes)
local previews = remotes:FindFirstChild("Previews")
local count = 0
for _, id in Furniture.Order do
	local item = Furniture.Items[id]
	if not item.Decoration then continue end
	count += 1
	check(Decorations.has(id), "Missing decoration builder: " .. id)
	local preview = previews:FindFirstChild(id)
	check(preview and preview:IsA("Model") and #preview:GetDescendants() > 0, "Missing preview: " .. id)
	for _, part in preview:GetDescendants() do
		if part:IsA("BasePart") then
			check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery, "Preview must be inert: " .. id)
		end
	end
	local entry = { ItemId = id, X = 8, Z = 8, R = 1 }
	local placed = buildItem(world, CFrame.identity, entry, 42)
	check(placed and placed.Parent == world and placed:GetAttribute("ItemId") == id
		and placed:GetAttribute("R") == 1 and #placed:GetDescendants() > 0, "Missing placed model: " .. id)
	local area = Furniture.footprint(id, entry.X, entry.Z, entry.R)
	for _, part in placed:GetDescendants() do
		if part:IsA("BasePart") then
			for _, x in { -0.5, 0.5 } do
				for _, y in { -0.5, 0.5 } do
					for _, z in { -0.5, 0.5 } do
						local corner = part.CFrame * Vector3.new(x * part.Size.X, y * part.Size.Y, z * part.Size.Z)
						check(corner.X >= area[1] - 0.01 and corner.X <= area[3] + 0.01
							and corner.Z >= area[2] - 0.01 and corner.Z <= area[4] + 0.01,
							"Model extends beyond placement footprint: " .. id .. " / " .. part.Name)
					end
				end
			end
		end
	end
end
check(count >= 10, "Expected a variety of decorations")
print(string.format("Decorations: %d model and preview checks passed (recording mocks; no Roblox runtime).", checks))
