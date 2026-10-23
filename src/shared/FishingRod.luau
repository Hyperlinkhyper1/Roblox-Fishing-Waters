-- The replicated Tool is one connected, massless assembly. Clients articulate
-- its Motor6Ds so an equipped rod cannot push its owner or leave loose parts.
local CollectionService = game:GetService("CollectionService")

local FishingRod = {}
local LENGTHS = { 0.72, 0.69, 0.66, 0.62, 0.58, 0.54, 0.49, 0.44 }
local CORK = Color3.fromRGB(167, 128, 79)
local CARBON = Color3.fromRGB(41, 62, 59)
local BRASS = Color3.fromRGB(191, 152, 80)
local STEEL = Color3.fromRGB(103, 119, 119)
local DARK = Color3.fromRGB(36, 42, 43)

function FishingRod.build(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Starter fishing rod"
	tool.ToolTip = "A flexible starter rod from the plaza tackle shop."
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = CFrame.new(0, -0.18, 0) * CFrame.Angles(math.rad(-35), 0, 0)
	tool:SetAttribute("RodId", "StarterRod")
	tool:SetAttribute("RodSegmentCount", #LENGTHS)
	tool:SetAttribute("RodLineLength", 1.25)

	local function part(name: string, size: Vector3, frame: CFrame, color: Color3, material: Enum.Material?): Part
		local item = Instance.new("Part")
		item.Name, item.Size, item.CFrame = name, size, frame
		item.Color, item.Material = color, material or Enum.Material.Metal
		item.Anchored, item.Massless = false, true
		item.CanCollide, item.CanTouch, item.CanQuery = false, false, false
		item.TopSurface, item.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		item.Parent = tool
		return item
	end
	local function weld(parent: BasePart, item: BasePart)
		local joint = Instance.new("WeldConstraint")
		joint.Part0, joint.Part1 = parent, item
		joint.Parent = item
	end
	local function cylinder(
		name: string,
		length: number,
		diameter: number,
		frame: CFrame,
		color: Color3,
		parent: BasePart?
	): Part
		local item =
			part(name, Vector3.new(length, diameter, diameter), frame * CFrame.Angles(0, 0, math.pi / 2), color)
		item.Shape = Enum.PartType.Cylinder
		if parent then
			weld(parent, item)
		end
		return item
	end
	local function attachment(parent: BasePart, name: string, worldFrame: CFrame): Attachment
		local item = Instance.new("Attachment")
		item.Name, item.CFrame = name, parent.CFrame:ToObjectSpace(worldFrame)
		item.Parent = parent
		return item
	end
	local function line(from: Attachment, to: Attachment, name: string)
		local beam = Instance.new("Beam")
		beam.Name = name
		beam.Attachment0, beam.Attachment1 = from, to
		beam.Width0, beam.Width1 = 0.012, 0.012
		beam.Color = ColorSequence.new(Color3.fromRGB(220, 224, 204))
		beam.Transparency = NumberSequence.new(0.2)
		beam.FaceCamera, beam.Segments = true, 1
		beam.Parent = tool
	end

	-- A neutral upright reference makes every hinge's local Y the shaft axis.
	local handle = part("Handle", Vector3.new(0.24, 1.13, 0.24), CFrame.identity, CORK)
	handle.Transparency = 1
	handle.RootPriority = 127
	local grip = cylinder("CorkGrip", 1.13, 0.25, CFrame.identity, CORK, handle)
	grip.Material = Enum.Material.Wood
	for _, y in { -0.51, 0.51 } do
		cylinder("GripFerrule", 0.075, 0.28, CFrame.new(0, y, 0), BRASS, handle)
	end
	local reelSeat = part("ReelSeat", Vector3.new(0.12, 0.54, 0.10), CFrame.new(0, 0.05, -0.18), DARK)
	weld(handle, reelSeat)
	local reelFoot = part("ReelFoot", Vector3.new(0.10, 0.15, 0.25), CFrame.new(0, -0.02, -0.33), STEEL)
	weld(handle, reelFoot)
	local reelBody = part("ReelBody", Vector3.new(0.31, 0.30, 0.25), CFrame.new(0, -0.07, -0.49), DARK)
	weld(handle, reelBody)
	local spool = cylinder("ReelSpool", 0.24, 0.30, CFrame.new(0, 0.15, -0.51), BRASS, handle)
	local spoolLine =
		cylinder("SpoolLine", 0.14, 0.315, CFrame.new(0, 0.15, -0.51), Color3.fromRGB(194, 204, 183), handle)
	local crank = part("ReelCrank", Vector3.new(0.27, 0.055, 0.055), CFrame.new(0.25, -0.08, -0.49), STEEL)
	weld(handle, crank)
	cylinder("CrankGrip", 0.16, 0.095, CFrame.new(0.37, -0.14, -0.49), DARK, handle)

	local previous: BasePart = handle
	local height = 0.54
	local previousLine = attachment(spoolLine, "SpoolLineExit", CFrame.new(0, 0.28, -0.51))
	local tip: Attachment? = nil
	for index, length in LENGTHS do
		local diameter = 0.11 - (index - 1) * 0.0105
		local segment = cylinder("RodSegment" .. index, length, diameter, CFrame.new(0, height + length / 2, 0), CARBON)
		local pivot = CFrame.new(0, height, 0)
		local joint = Instance.new("Motor6D")
		joint.Name = "RodBend" .. index
		joint.Part0, joint.Part1 = previous, segment
		joint.C0, joint.C1 = previous.CFrame:ToObjectSpace(pivot), segment.CFrame:ToObjectSpace(pivot)
		joint:SetAttribute("RodSegment", index)
		joint:SetAttribute("FlexWeight", index / #LENGTHS)
		joint.Parent = segment
		cylinder("BlankBinding", 0.055, diameter + 0.025, CFrame.new(0, height + 0.07, 0), BRASS, segment)
		height += length
		if index % 2 == 0 then
			local center = Vector3.new(0, height - 0.06, -0.12)
			for _, side in { -1, 1 } do
				local crossbar = part(
					"LineGuide",
					Vector3.new(0.15, 0.022, 0.022),
					CFrame.new(center + Vector3.new(0, 0, side * 0.065)),
					STEEL
				)
				weld(segment, crossbar)
				local upright = part(
					"LineGuide",
					Vector3.new(0.022, 0.022, 0.15),
					CFrame.new(center + Vector3.new(side * 0.065, 0, 0)),
					STEEL
				)
				weld(segment, upright)
			end
			local guide = attachment(segment, "GuideLine", CFrame.new(center))
			line(previousLine, guide, "ShaftLine")
			previousLine = guide
		end
		if index == #LENGTHS then
			tip = attachment(segment, "RodTip", CFrame.new(0, height, -0.12))
			line(previousLine, tip, "TipLine")
		end
		previous = segment
	end

	local tipFrame = CFrame.new(0, height, -0.12)
	local bobberFrame = tipFrame * CFrame.new(0, -1.25, 0)
	local bobber = part(
		"RodBobber",
		Vector3.new(0.23, 0.31, 0.23),
		bobberFrame,
		Color3.fromRGB(199, 73, 59),
		Enum.Material.SmoothPlastic
	)
	bobber.Shape = Enum.PartType.Ball
	local band = cylinder(
		"BobberBand",
		0.10,
		0.235,
		bobberFrame * CFrame.new(0, -0.025, 0),
		Color3.fromRGB(244, 235, 203),
		bobber
	)
	band.Material = Enum.Material.SmoothPlastic
	cylinder("BobberStem", 0.19, 0.035, bobberFrame * CFrame.new(0, 0.22, 0), DARK, bobber)
	local bobberJoint = Instance.new("Motor6D")
	bobberJoint.Name = "BobberSwing"
	bobberJoint.Part0, bobberJoint.Part1 = previous, bobber
	bobberJoint.C0 = previous.CFrame:ToObjectSpace(tipFrame)
	bobberJoint.C1 = CFrame.new(0, 1.25, 0)
	bobberJoint.Parent = bobber
	local bobberEye = attachment(bobber, "BobberEye", bobberFrame * CFrame.new(0, 0.3, 0))
	line(tip :: Attachment, bobberEye, "HangingLine")
	CollectionService:AddTag(tool, "FishingRod")
	return tool
end

return FishingRod
