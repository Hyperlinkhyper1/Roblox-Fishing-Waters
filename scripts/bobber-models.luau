local nativeNew = Instance.new
Instance.new = function(class)
	local item = nativeNew(class)
	function item:GetChildren()
		return table.clone(self.children)
	end
	if class == "Part" or class == "WedgePart" then
		item.CFrame = CFrame.identity
	end
	if class == "Model" then
		function item:ScaleTo(scale)
			self.scale = scale
		end
		function item:PivotTo(frame)
			self.frame = frame
		end
	end
	if class == "ParticleEmitter" then
		function item:Emit(count)
			self.emitted = count
		end
	end
	return item
end
Vector3.yAxis, Vector3.xAxis = vector(0, 1, 0), vector(1, 0, 0)
frameMeta.__add = function(a, b)
	return CFrame.fromMatrix(a.Position + b, a.RightVector, a.UpVector, a.ZVector)
end
local NumberSequenceKeypoint = {
	new = function(...)
		return { ... }
	end,
}
local NumberRange = {
	new = function(...)
		return { ... }
	end,
}
local Vector2 = {
	new = function(...)
		return { ... }
	end,
}
workspace.Terrain = Instance.new("Terrain")
function workspace:GetServerTimeNow()
	return 20
end
local BobberSkins = (function()
	-- SKINS_SOURCE --
end)()
local FishingBobber = (function()
	-- BOBBER_SOURCE --
end)()
local FishingRod = (function()
	-- ROD_SOURCE --
end)()
local Casting = (function()
	-- CASTING_SOURCE --
end)()
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
for id, skin in BobberSkins.Skins do
	local rod = FishingRod.build("MageStaff", id)
	rod.Parent = workspace
	local root = rod:FindFirstChild("RodBobber")
	check(
		rod:GetAttribute("BobberSkin") == id and rod:GetAttribute("RodSkin") == "MageStaff",
		"Rod and bobber styles coexist"
	)
	check(root.Transparency == 1 and root:FindFirstChild("BobberSwing"), "Custom body keeps its swing joint")
	local top, bottom, crown = 0, 0, 0
	for _, part in root:GetChildren() do
		if part:IsA("BasePart") then
			check(
				part.Massless and not part.CanCollide and not part.CanTouch and not part.CanQuery,
				"Bobber details cannot disturb physics or raycasts"
			)
			local weld = part:FindFirstChildOfClass("WeldConstraint")
			check(weld and weld.Part0 == root and weld.Part1 == part, "Every detail follows the swinging float")
			if part.Name == "BobberTop" then
				top += 1
				check((part.CFrame.Position - root.CFrame.Position).Y > 0, "Top color stays above the seam")
				check((part.Material == Enum.Material.Neon) == (skin.Rarity == "Epic"), "Only epic has a neon top")
			elseif part.Name == "BobberBottom" then
				bottom += 1
				check(
					(part.CFrame.Position - root.CFrame.Position).Y < 0 and part.Material ~= Enum.Material.Neon,
					"Bottom stays below the seam and never glows"
				)
			elseif part.Name == "CrownPoint" then
				crown += 1
			end
		end
	end
	check(
		top > 0 and bottom > 0 and (crown >= 3) == (skin.Rarity == "Legendary"),
		"Two-tone body and legendary-only miniature crown"
	)
	local line = Casting.newLine(rod)
	check(line.customBobber and line.customBobber.scale == 1.45, "Cast uses the selected float model")
	local floatRoot = line.customBobber.PrimaryPart
	check(floatRoot:FindFirstChild("BobberTop").Color[1] == skin.Top[1], "Floating model keeps the selected top color")
	check(
		(floatRoot:FindFirstChild("CrownBand") ~= nil) == (skin.Rarity == "Legendary"),
		"Floating legendary retains its crown"
	)
	Casting.setBuiltInBobber(rod, false)
	check(root:FindFirstChild("BobberTop").LocalTransparencyModifier == 1, "Hanging custom pieces hide during casts")
	local target = vector(5, 0, 7)
	Casting.updateLine(line, target, 0, "Waiting", 20)
	check(
		line.customBobber.frame and math.abs(line.customBobber.frame.Position.X - target.X) < 1e-9 and line.landed,
		"Floating model follows the landed line"
	)
	Casting.destroyLine(line)
	check(
		line.folder.Parent == nil and root:FindFirstChild("BobberTop").LocalTransparencyModifier == 0,
		"Reeling in cleans the cast and restores hanging pieces"
	)
	rod:Destroy()
end
print(`Bobber models: {checks} hanging/cast style, weld, physics and visibility checks passed (recording mocks).`)
