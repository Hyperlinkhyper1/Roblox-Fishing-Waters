-- Rules and the replicated hotbar tool for the basic shark-hunting spear.
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
	tool:SetAttribute("SpearId", Spears.ID)
	if skin then
		tool:SetAttribute("SpearSkin", skinId)
		tool:SetAttribute("SpearSkinWear", wear)
	end
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.25, 4.5, 0.25)
	handle.Color = color(skin and skin.ShaftColor, Color3.fromRGB(119, 82, 46))
	handle.Material = Enum.Material.Wood
	handle.CanCollide, handle.CanTouch, handle.CanQuery, handle.Massless = false, false, false, true
	handle.Parent = tool
	local function piece(name, size, offset, tint, material, wedge)
		local part = Instance.new("Part")
		part.Name, part.Size, part.Color, part.Material = name, size, tint, material
		part.CanCollide, part.CanTouch, part.CanQuery, part.Massless = false, false, false, true
		part.CFrame = handle.CFrame * offset
		if wedge then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Wedge
			mesh.Parent = part
		end
		part.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = handle, part, handle
	end
	local tipColor = color(skin and skin.TipColor, Color3.fromRGB(155, 174, 174))
	piece("Spearhead", Vector3.new(0.42, 1.2, 0.16), CFrame.new(0, 2.75, 0), tipColor, Enum.Material.Metal, true)
	if skin then
		piece(
			"Grip",
			Vector3.new(0.32, 1.0, 0.32),
			CFrame.new(0, -0.65, 0),
			color(skin.GripColor, handle.Color),
			Enum.Material.Fabric,
			false
		)
		if skin.Shape == "Trident" then
			piece(
				"Crossbar",
				Vector3.new(1.3, 0.14, 0.18),
				CFrame.new(0, 2.35, 0),
				tipColor,
				Enum.Material.Metal,
				false
			)
			for _, x in { -0.6, 0.6 } do
				piece("Prong", Vector3.new(0.16, 1.2, 0.16), CFrame.new(x, 2.8, 0), tipColor, Enum.Material.Metal, true)
			end
		elseif skin.Shape == "Harpoon" then
			for _, x in { -0.27, 0.27 } do
				piece(
					"Barb",
					Vector3.new(0.3, 0.42, 0.16),
					CFrame.new(x, 2.35, 0) * CFrame.Angles(0, 0, math.rad(if x < 0 then -30 else 30)),
					tipColor,
					Enum.Material.Metal,
					true
				)
			end
		end
	end
	game:GetService("CollectionService"):AddTag(tool, "Spear")
	return tool
end

return Spears
