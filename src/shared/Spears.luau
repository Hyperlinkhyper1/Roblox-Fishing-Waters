-- Rules and the replicated hotbar tool for the shark-hunting spear.
local Spears = {}
Spears.PRICE = 250
Spears.ID = "BasicSpear"

function Spears.buyProblem(profile): string?
	if profile.OwnedSpears[Spears.ID] then
		return "You already own a spear. Find it in your hotbar."
	elseif profile.Cash < Spears.PRICE then
		return string.format("You need $%d for a spear.", Spears.PRICE)
	end
	return nil
end

function Spears.buy(profile)
	local problem = Spears.buyProblem(profile)
	assert(problem == nil, problem)
	profile.Cash -= Spears.PRICE
	profile.Angler.Stats.CoinsSpent += Spears.PRICE
	profile.OwnedSpears[Spears.ID] = true
end

-- Optional skins restyle the same spear; the server owns the equipped skin and stats.
function Spears.build(skinId: string?, wear: number?): Tool
	local SpearSkins = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").SpearSkins)
	local skin = skinId and SpearSkins.Skins[skinId]
	local function color(rgb, fallback)
		return if rgb then Color3.fromRGB(rgb[1], rgb[2], rgb[3]) else fallback
	end
	local tool = Instance.new("Tool")
	tool.Name = "Spear"
	tool.ToolTip = "Attack sharks in the sea."
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("SpearId", Spears.ID)
	if skin then
		tool:SetAttribute("SpearSkin", skinId)
		tool:SetAttribute("SpearSkinWear", wear)
	end
	local shaftColor = color(skin and skin.ShaftColor, Color3.fromRGB(119, 82, 46))
	local tipColor = color(skin and skin.TipColor, Color3.fromRGB(155, 174, 174))
	local gripColor = color(skin and skin.GripColor, Color3.fromRGB(77, 58, 41))
	local accent = color(skin and skin.AccentColor, Color3.fromRGB(181, 147, 92))
	local shaftMaterial = if skin and skin.ShaftMaterial then Enum.Material[skin.ShaftMaterial] else Enum.Material.Wood
	local wearValue = if SpearSkins.validWear(wear) then wear else SpearSkins.DefaultWear
	-- A restrained patina keeps the palette legible at every wear level.
	local patina = Color3.fromRGB(103, 100, 91)
	shaftColor = shaftColor:Lerp(patina, wearValue * 0.16)
	tipColor = tipColor:Lerp(patina, wearValue * 0.22)
	local edgeColor = tipColor:Lerp(Color3.fromRGB(245, 248, 239), 0.3)
	local metal = Enum.Material.Metal
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.25, 4.5, 0.25)
	-- Preserve the original grip frame and length; visible geometry is welded
	-- around this root so combat thrusts and inventory previews share one model.
	handle.Transparency = 1
	handle.CFrame = CFrame.new()
	handle.CanCollide, handle.CanTouch, handle.CanQuery, handle.Massless = false, false, false, true
	handle.Parent = tool
	local function piece(name, size, offset, tint, material, className)
		local part = Instance.new(className or "Part")
		part.Name, part.Size, part.Color, part.Material = name, size, tint, material
		part.CanCollide, part.CanTouch, part.CanQuery, part.Massless = false, false, false, true
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		part.CastShadow = false
		if material == metal then
			part.Reflectance = 0.06 * (1 - wearValue)
		end
		part.CFrame = handle.CFrame * offset
		part.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = handle, part, handle
		return part
	end
	local function cylinder(name, length, diameter, frame, tint, material)
		local part = piece(name, Vector3.new(length, diameter, diameter),
			frame * CFrame.Angles(0, 0, math.pi / 2), tint, material or metal)
		part.Shape = Enum.PartType.Cylinder
		return part
	end
	local function band(name, y, diameter, tint, length)
		return cylinder(name, length or 0.07, diameter, CFrame.new(0, y, 0), tint)
	end
	local function link(name, a, b, diameter, tint)
		local up = (b - a).Unit
		local right = up:Cross(Vector3.new(0, 0, 1)).Unit
		cylinder(name, (b - a).Magnitude, diameter,
			CFrame.fromMatrix((a + b) / 2, right, up, right:Cross(up)), tint)
	end
	-- Opposed wedges meet at the centerline: a true point from both sides,
	-- with a shorter reverse taper at the socket and a raised central facet.
	local function blade(name, frame, width, upper, lower, depth, tint)
		for _, half in { { upper, 1 }, { lower, -1 } } do
			local height, direction = half[1], half[2]
			for _, side in { -1, 1 } do
				piece(name, Vector3.new(depth, height, width / 2),
					frame * CFrame.Angles(0, 0, if direction == 1 then 0 else math.pi)
						* CFrame.new(side * width / 4, height / 2, 0)
						* CFrame.Angles(0, -side * math.pi / 2, 0),
					tint, metal, "WedgePart")
			end
		end
	end
	local function facetedBlade(name, frame, width, upper, lower, depth)
		blade(name, frame, width, upper, lower, depth, edgeColor)
		blade(name .. "Ridge", frame, width * 0.36, upper * 0.93, lower * 0.92, depth + 0.035, tipColor)
	end

	cylinder("Shaft", 4.45, 0.21, CFrame.new(0, 0, 0), shaftColor, shaftMaterial)
	cylinder("Grip", 1.1, 0.27, CFrame.new(0, -0.55, 0), gripColor, Enum.Material.Fabric)
	for i = 0, 6 do
		cylinder("GripWrap", 0.035, 0.287,
			CFrame.new(0, -1.01 + i * 0.15, 0) * CFrame.Angles(0, 0, math.rad(11)),
			gripColor:Lerp(accent, 0.3), Enum.Material.Fabric)
	end
	band("GripHeel", -1.14, 0.3, accent)
	band("GripCrown", 0.04, 0.3, accent)
	band("ButtCap", -2.2, 0.26, tipColor, 0.16)
	band("ButtRim", -2.11, 0.275, accent, 0.045)
	cylinder("HeadSocket", 0.4, 0.285, CFrame.new(0, 2.15, 0), tipColor)
	band("SocketRim", 1.96, 0.31, accent)
	band("SocketCrown", 2.31, 0.31, accent)

	local shape = skin and skin.Shape or "Standard"
	if shape == "Trident" then
		facetedBlade("Spearhead", CFrame.new(0, 2.6, 0), 0.35, 0.83, 0.28, 0.15)
		for _, side in { -1, 1 } do
			link("TridentShoulder", Vector3.new(0, 2.18, 0), Vector3.new(side * 0.47, 2.3, 0), 0.17, tipColor)
			link("TridentArm", Vector3.new(side * 0.47, 2.3, 0), Vector3.new(side * 0.63, 2.6, 0), 0.15, tipColor)
			facetedBlade("Prong", CFrame.new(side * 0.63, 2.73, 0), 0.26, 0.53, 0.22, 0.13)
		end
	elseif shape == "Harpoon" then
		facetedBlade("Spearhead", CFrame.new(0, 2.66, 0), 0.42, 0.77, 0.32, 0.18)
		for _, side in { -1, 1 } do
			-- Swept, backward-facing barbs grow out of the main blade.
			blade("HarpoonBarb", CFrame.new(side * 0.23, 2.62, 0)
				* CFrame.Angles(0, 0, math.rad(-side * 155)), 0.23, 0.53, 0.14, 0.16, tipColor)
		end
	else
		facetedBlade("Spearhead", CFrame.new(0, 2.62, 0), 0.53, 0.8, 0.3, 0.14)
	end

	if skinId == "Driftwood" or not skin then
		for i = 0, 3 do
			cylinder("SocketLashing", 0.045, 0.32, CFrame.new(0, 1.96 + i * 0.085, 0), accent, Enum.Material.Fabric)
		end
	elseif skinId == "DeepBlue" then
		for _, y in { 0.36, 0.51, 1.55 } do band("NauticalStripe", y, 0.23, accent) end
	elseif skinId == "Coral" then
		for _, side in { -1, 1 } do
			link("CoralBranch", Vector3.new(0, 1.62, 0), Vector3.new(side * 0.23, 1.82, 0), 0.085, accent)
			link("CoralTwig", Vector3.new(side * 0.23, 1.82, 0), Vector3.new(side * 0.27, 2.02, 0), 0.065, accent)
		end
	elseif skinId == "Seafoam" then
		for i = 0, 4 do
			band("FoamRing", 0.65 + i * 0.18, 0.24 + (i % 2) * 0.025, accent, 0.035)
		end
	elseif skinId == "Obsidian" then
		-- Dark facets with violet seams on both faces of the blade.
		for _, face in { -1, 1 } do
			piece("ObsidianSeam", Vector3.new(0.026, 0.43, 0.025),
				CFrame.new(0, 2.78, face * 0.107) * CFrame.Angles(0, 0, -0.16), accent, Enum.Material.Neon)
		end
		band("ObsidianCollar", 1.76, 0.27, accent, 0.12)
	elseif skinId == "Storm" then
		for _, face in { -1, 1 } do
			for i = 0, 2 do
				piece("LightningInlay", Vector3.new(0.04, 0.24, 0.025),
					CFrame.new(if i == 1 then 0.035 else 0, 1.05 + i * 0.19, face * 0.113)
						* CFrame.Angles(0, 0, if i == 1 then -0.55 else 0.4), accent, Enum.Material.Neon)
			end
		end
	elseif shape == "Trident" then
		for _, face in { -1, 1 } do
			local gem = piece("ReefPearl", Vector3.new(0.2, 0.25, 0.12), CFrame.new(0, 2.2, face * 0.12), accent, Enum.Material.SmoothPlastic)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = gem
		end
		for _, y in { 0.38, 1.45, 1.62 } do band("ReefFiligree", y, 0.25, accent, 0.045) end
	elseif shape == "Harpoon" then
		for _, y in { 0.34, 0.47, 1.56, 1.69 } do band("GildedBand", y, 0.26, accent, 0.055) end
		for _, face in { -1, 1 } do
			blade("HarpoonCrest", CFrame.new(0, 2.14, face * 0.16), 0.15, 0.13, 0.13, 0.04, accent)
		end
	end
	game:GetService("CollectionService"):AddTag(tool, "Spear")
	return tool
end

return Spears
