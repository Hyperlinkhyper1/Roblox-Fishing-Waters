-- The replicated Tool is one connected, massless assembly. Clients articulate
-- its Motor6Ds so an equipped rod cannot push its owner or leave loose parts.
-- Crate skins (RodSkins) restyle the same jointed blank and only weld extra
-- pieces onto it, so every skin bends, casts and swings its bobber alike.
local CollectionService = game:GetService("CollectionService")

local FishingRod = {}
local LENGTHS = { 0.72, 0.69, 0.66, 0.62, 0.58, 0.54, 0.49, 0.44 }
local CORK = Color3.fromRGB(167, 128, 79)
local CARBON = Color3.fromRGB(41, 62, 59)
local BRASS = Color3.fromRGB(191, 152, 80)
local STEEL = Color3.fromRGB(103, 119, 119)
local DARK = Color3.fromRGB(36, 42, 43)

type Style = {
	Name: string,
	ToolTip: string,
	Grip: Color3,
	GripMaterial: Enum.Material,
	Blank: Color3,
	BlankMaterial: Enum.Material,
	Binding: Color3,
	Guide: Color3,
	Reel: Color3,
	Spool: Color3,
	Bobber: Color3,
	Band: Color3,
	Diameter: ((index: number) -> number)?,
	Decorate: ((kit: any) -> ())?,
}

local DEFAULT: Style = {
	Name = "Starter fishing rod",
	ToolTip = "A flexible starter rod from the plaza tackle shop.",
	Grip = CORK,
	GripMaterial = Enum.Material.Wood,
	Blank = CARBON,
	BlankMaterial = Enum.Material.Metal,
	Binding = BRASS,
	Guide = STEEL,
	Reel = DARK,
	Spool = BRASS,
	Bobber = Color3.fromRGB(199, 73, 59),
	Band = Color3.fromRGB(244, 235, 203),
}

-- Short pieces laid along a circular arc in the plane of `u` and `v`.
local function arc(kit, parent: BasePart, name: string, center: Vector3, u: Vector3, v: Vector3, options)
	local radius, from, to = options.radius, math.rad(options.from), math.rad(options.to)
	local steps, thickness = options.steps, options.thickness
	local normal = u:Cross(v).Unit
	for step = 0, steps - 1 do
		local a0 = from + (to - from) * step / steps
		local a1 = from + (to - from) * (step + 1) / steps
		local p0 = center + u * radius * math.cos(a0) + v * radius * math.sin(a0)
		local p1 = center + u * radius * math.cos(a1) + v * radius * math.sin(a1)
		local tangent = (p1 - p0).Unit
		local width = thickness * (if options.taper then 1 - 0.6 * step / steps else 1)
		kit.attach(
			parent,
			name,
			Vector3.new(width, width, (p1 - p0).Magnitude + width * 0.5),
			CFrame.fromMatrix((p0 + p1) / 2, normal, tangent:Cross(normal), tangent),
			options.color,
			options.material
		)
	end
end

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local STYLES: { [string]: { [string]: any } } = {
	TideboundRod = {
		Name = "Tidebound Rod",
		ToolTip = "Community exclusive · +7.5% reel speed & line strength",
		Grip = rgb(19, 65, 69),
		GripMaterial = Enum.Material.Fabric,
		Blank = rgb(18, 112, 119),
		BlankMaterial = Enum.Material.Metal,
		Binding = rgb(225, 183, 91),
		Guide = rgb(250, 218, 143),
		Reel = rgb(13, 46, 57),
		Spool = rgb(225, 183, 91),
		Bobber = rgb(92, 211, 200),
		Band = rgb(250, 228, 172),
		Decorate = function(kit)
			local gold, pearl, aqua = rgb(225, 183, 91), rgb(238, 241, 220), rgb(92, 211, 200)
			-- Raised gold stitching around a dark woven handle.
			for index = 0, 6 do
				kit.cylinder(
					"TideboundGripStitch",
					0.022,
					0.263,
					CFrame.new(0, -0.42 + index * 0.14, 0) * CFrame.Angles(0, 0, 0.17),
					gold,
					kit.handle
				)
			end
			kit.cylinder("TideboundPommel", 0.13, 0.32, CFrame.new(0, -0.64, 0), gold, kit.handle)
			kit.ball("TideboundPommelPearl", 0.19, CFrame.new(0, -0.75, 0), pearl, kit.handle)
			-- Inlaid wave strokes ride each articulated segment independently.
			for index, segment in kit.segments do
				local y = kit.starts[index] + LENGTHS[index] / 2
				local radius = kit.diameters[index] / 2 + 0.012
				for side = 0, 1 do
					kit.attach(
						segment,
						"TideboundWaveInlay",
						Vector3.new(0.022, LENGTHS[index] * 0.66, 0.018),
						CFrame.new(0, y, if side == 0 then radius else -radius)
							* CFrame.Angles(0, 0, if side == 0 then 0.09 else -0.09),
						gold,
						Enum.Material.Metal
					)
				end
				if index <= 4 then
					kit.ball("TideboundPearlInlay", 0.075, CFrame.new(0, y + 0.16, -radius - 0.018), pearl, segment)
				end
			end
			-- A compass medallion on the reel, with eight gilded points and a sea-glass center.
			arc(
				kit,
				kit.handle,
				"TideboundCompassRim",
				Vector3.new(0, -0.08, -0.64),
				Vector3.new(1, 0, 0),
				Vector3.new(0, 1, 0),
				{
					radius = 0.22,
					from = 0,
					to = 360,
					steps = 12,
					thickness = 0.025,
					color = gold,
					material = Enum.Material.Metal,
				}
			)
			for point = 0, 7 do
				local angle = point * math.pi / 4
				kit.attach(
					kit.handle,
					"TideboundCompassPoint",
					Vector3.new(0.035, if point % 2 == 0 then 0.17 else 0.11, 0.035),
					CFrame.new(math.sin(angle) * 0.11, -0.08 + math.cos(angle) * 0.11, -0.65)
						* CFrame.Angles(0, 0, -angle),
					gold,
					Enum.Material.Metal
				)
			end
			kit.ball("TideboundSeaGlass", 0.105, CFrame.new(0, -0.08, -0.68), aqua, kit.handle).Material =
				Enum.Material.Neon
			local tip = kit.segments[#LENGTHS]
			kit.cylinder("TideboundTipCrown", 0.09, 0.13, CFrame.new(0, kit.top - 0.04, 0), gold, tip)
			kit.ball("TideboundTipPearl", 0.11, CFrame.new(0, kit.top + 0.03, 0), pearl, tip)
		end,
	},
	PencilRod = {
		Name = "Pencil Rod",
		ToolTip = "Sketch out your next big catch.",
		Grip = rgb(246, 193, 49),
		Blank = rgb(246, 193, 49),
		BlankMaterial = Enum.Material.Wood,
		Binding = rgb(224, 158, 30),
		Bobber = rgb(235, 128, 151),
		Diameter = function(): number
			return 0.19
		end,
		Decorate = function(kit)
			for index, segment in kit.segments do
				kit.attach(
					segment,
					"PencilEdge",
					Vector3.new(0.055, LENGTHS[index], 0.025),
					CFrame.new(0, kit.starts[index] + LENGTHS[index] / 2, -0.09),
					rgb(255, 222, 97),
					Enum.Material.Wood
				)
			end
			kit.cylinder("PencilFerrule", 0.26, 0.29, CFrame.new(0, -0.48, 0), rgb(190, 196, 204), kit.handle)
			kit.cylinder("PencilEraser", 0.3, 0.27, CFrame.new(0, -0.75, 0), rgb(235, 128, 151), kit.handle).Material =
				Enum.Material.SmoothPlastic
			local tip = kit.segments[#LENGTHS]
			for step = 1, 4 do
				kit.cylinder(
					"PencilWoodTip",
					0.075,
					0.2 - step * 0.035,
					CFrame.new(0, kit.top + (step - 0.5) * 0.075, 0),
					rgb(216, 177, 127),
					tip
				).Material =
					Enum.Material.Wood
			end
			kit.cylinder("PencilGraphite", 0.1, 0.035, CFrame.new(0, kit.top + 0.34, 0), rgb(42, 43, 47), tip)
		end,
	},
	BaseballRod = {
		Name = "Baseball Rod",
		ToolTip = "Knock a catch out of the water.",
		Grip = rgb(72, 49, 36),
		GripMaterial = Enum.Material.Fabric,
		Blank = rgb(205, 163, 108),
		BlankMaterial = Enum.Material.Wood,
		Binding = rgb(172, 124, 76),
		Bobber = rgb(242, 235, 218),
		Band = rgb(197, 52, 48),
		Diameter = function(index: number): number
			return 0.13 + math.min(index, 6) * 0.055
		end,
		Decorate = function(kit)
			kit.cylinder("BatKnob", 0.12, 0.4, CFrame.new(0, -0.62, 0), rgb(205, 163, 108), kit.handle).Material =
				Enum.Material.Wood
			for step = 0, 5 do
				kit.cylinder(
					"BatGripWrap",
					0.04,
					0.27,
					CFrame.new(0, -0.4 + step * 0.16, 0),
					rgb(116, 83, 59),
					kit.handle
				).Material =
					Enum.Material.Fabric
			end
			kit.ball("BatBarrelEnd", 0.46, CFrame.new(0, kit.top - 0.04, 0), rgb(205, 163, 108), kit.segments[#LENGTHS]).Material =
				Enum.Material.Wood
		end,
	},
	MusketRod = {
		Name = "Musket Rod",
		ToolTip = "An antique musket repurposed for fishing.",
		Grip = rgb(100, 56, 33),
		GripMaterial = Enum.Material.Wood,
		Blank = rgb(67, 73, 78),
		Binding = rgb(170, 133, 66),
		Reel = rgb(100, 56, 33),
		Bobber = rgb(170, 133, 66),
		Diameter = function(index: number): number
			return 0.21 - index * 0.009
		end,
		Decorate = function(kit)
			local wood, brass = rgb(100, 56, 33), rgb(170, 133, 66)
			kit.attach(
				kit.handle,
				"MusketStock",
				Vector3.new(0.3, 0.95, 0.44),
				CFrame.new(0, -0.48, 0.12) * CFrame.Angles(math.rad(-12), 0, 0),
				wood,
				Enum.Material.Wood
			)
			kit.attach(
				kit.handle,
				"MusketButtPlate",
				Vector3.new(0.32, 0.08, 0.46),
				CFrame.new(0, -0.95, 0.21),
				brass,
				Enum.Material.Metal
			)
			for index = 1, 4 do
				kit.attach(
					kit.segments[index],
					"MusketForestock",
					Vector3.new(0.2, LENGTHS[index], 0.16),
					CFrame.new(0, kit.starts[index] + LENGTHS[index] / 2, 0.13),
					wood,
					Enum.Material.Wood
				)
			end
			kit.attach(
				kit.segments[1],
				"MusketHammer",
				Vector3.new(0.12, 0.24, 0.12),
				CFrame.new(0.18, 0.78, 0) * CFrame.Angles(0, 0, math.rad(-28)),
				brass,
				Enum.Material.Metal
			)
			arc(
				kit,
				kit.handle,
				"MusketTriggerGuard",
				Vector3.new(0, -0.3, -0.23),
				Vector3.new(0, 1, 0),
				Vector3.new(0, 0, -1),
				{
					radius = 0.2,
					from = 0,
					to = 180,
					steps = 6,
					thickness = 0.04,
					color = brass,
					material = Enum.Material.Metal,
				}
			)
			kit.cylinder("MusketMuzzle", 0.12, 0.23, CFrame.new(0, kit.top - 0.02, 0), brass, kit.segments[#LENGTHS])
			kit.cylinder(
				"MusketBore",
				0.012,
				0.12,
				CFrame.new(0, kit.top + 0.046, 0),
				rgb(24, 25, 27),
				kit.segments[#LENGTHS]
			)
		end,
	},
	HoneycombRod = {
		Name = "Honeycomb Rod",
		ToolTip = "Golden honeycomb makes every catch sweeter.",
		Grip = rgb(124, 76, 26),
		Blank = rgb(239, 164, 35),
		BlankMaterial = Enum.Material.SmoothPlastic,
		Binding = rgb(255, 207, 71),
		Bobber = rgb(255, 189, 43),
		Band = rgb(70, 43, 24),
		Decorate = function(kit)
			for index = 1, 7, 2 do
				local segment, y = kit.segments[index], kit.starts[index] + LENGTHS[index] / 2
				arc(
					kit,
					segment,
					"HoneycombCell",
					Vector3.new(0, y, -0.05),
					Vector3.new(1, 0, 0),
					Vector3.new(0, 1, 0),
					{
						radius = 0.24,
						from = 30,
						to = 390,
						steps = 6,
						thickness = 0.055,
						color = rgb(255, 201, 55),
						material = Enum.Material.SmoothPlastic,
					}
				)
				kit.ball("HoneyDrop", 0.12, CFrame.new(0.12, y - 0.2, -0.05), rgb(235, 145, 20), segment)
			end
			for _, y in { -0.3, 0, 0.3 } do
				kit.cylinder("HoneyDipperRing", 0.07, 0.4, CFrame.new(0, y, 0), rgb(239, 164, 35), kit.handle)
			end
		end,
	},
	StarRod = {
		Name = "Star Rod",
		ToolTip = "Wish upon a golden star before every cast.",
		Grip = rgb(93, 55, 137),
		GripMaterial = Enum.Material.Fabric,
		Blank = rgb(120, 83, 170),
		Binding = rgb(255, 215, 88),
		Guide = rgb(255, 215, 88),
		Bobber = rgb(255, 222, 112),
		Decorate = function(kit)
			local gold = rgb(255, 215, 88)
			local center = Vector3.new(0, kit.top + 0.17, 0)
			local tip = kit.segments[#LENGTHS]
			for edge = 0, 9 do
				local function vertex(index)
					local angle = math.pi / 2 + index * math.pi / 5
					local radius = if index % 2 == 0 then 0.42 else 0.18
					return center + Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)
				end
				local p0, p1 = vertex(edge), vertex(edge + 1)
				local tangent = (p1 - p0).Unit
				kit.attach(
					tip,
					"StarOutline",
					Vector3.new(0.065, 0.065, (p1 - p0).Magnitude + 0.03),
					CFrame.fromMatrix((p0 + p1) / 2, Vector3.new(0, 0, 1), tangent:Cross(Vector3.new(0, 0, 1)), tangent),
					gold,
					Enum.Material.Neon
				)
			end
			kit.ball("StarCore", 0.25, CFrame.new(center), gold, tip).Material = Enum.Material.Neon
			kit.glow(tip, gold, 5, 0.65)
			for index = 2, 6, 2 do
				kit.ball("StarSparkle", 0.085, CFrame.new(0.1, kit.starts[index] + 0.2, 0), gold, kit.segments[index]).Material =
					Enum.Material.Neon
			end
		end,
	},
	SelfieStickRod = {
		Name = "Selfie Stick Rod",
		ToolTip = "Catch a fish, then catch your best angle.",
		Grip = rgb(38, 39, 46),
		GripMaterial = Enum.Material.Fabric,
		Blank = rgb(180, 191, 205),
		Binding = rgb(67, 70, 82),
		Reel = rgb(38, 39, 46),
		Bobber = rgb(92, 197, 231),
		Decorate = function(kit)
			local tip, y = kit.segments[#LENGTHS], kit.top + 0.2
			kit.attach(
				tip,
				"PhoneMount",
				Vector3.new(0.14, 0.3, 0.16),
				CFrame.new(0, kit.top - 0.12, 0),
				rgb(38, 39, 46)
			)
			kit.attach(tip, "SelfiePhone", Vector3.new(0.74, 1.08, 0.13), CFrame.new(0, y, 0), rgb(26, 28, 35))
			kit.attach(
				tip,
				"PhoneScreen",
				Vector3.new(0.62, 0.87, 0.015),
				CFrame.new(0, y, -0.074),
				rgb(80, 181, 220),
				Enum.Material.Neon
			)
			kit.attach(
				tip,
				"PhoneShutter",
				Vector3.new(0.13, 0.13, 0.02),
				CFrame.new(0, y - 0.29, -0.087),
				rgb(240, 244, 250)
			)
			kit.ball("PhoneCamera", 0.055, CFrame.new(0, y + 0.47, -0.075), rgb(81, 87, 105), tip)
			for _, x in { -0.39, 0.39 } do
				kit.attach(tip, "PhoneClamp", Vector3.new(0.08, 0.25, 0.2), CFrame.new(x, y, 0), rgb(67, 70, 82))
			end
			kit.ball("SelfieButton", 0.1, CFrame.new(0, 0.3, -0.14), rgb(92, 197, 231), kit.handle)
		end,
	},
	LightsaberRod = {
		Name = "Lightsaber Rod",
		ToolTip = "A brilliant energy blade with a fishing line.",
		Grip = rgb(162, 174, 188),
		GripMaterial = Enum.Material.Metal,
		Blank = rgb(79, 220, 255),
		BlankMaterial = Enum.Material.Neon,
		Binding = rgb(160, 245, 255),
		Guide = rgb(218, 251, 255),
		Reel = rgb(42, 48, 59),
		Spool = rgb(162, 174, 188),
		Bobber = rgb(79, 220, 255),
		Band = rgb(218, 251, 255),
		Diameter = function(index: number): number
			return 0.22 - index * 0.009
		end,
		Decorate = function(kit)
			for _, y in { -0.4, -0.2, 0, 0.2 } do
				kit.cylinder("SaberHiltRing", 0.08, 0.32, CFrame.new(0, y, 0), rgb(42, 48, 59), kit.handle)
			end
			kit.cylinder("SaberEmitter", 0.18, 0.4, CFrame.new(0, 0.52, 0), rgb(162, 174, 188), kit.handle)
			kit.cylinder("SaberPommel", 0.12, 0.35, CFrame.new(0, -0.62, 0), rgb(162, 174, 188), kit.handle)
			kit.ball("SaberSwitch", 0.09, CFrame.new(0.17, 0.3, 0), rgb(238, 68, 61), kit.handle).Material =
				Enum.Material.Neon
			kit.ball("SaberBladeTip", 0.15, CFrame.new(0, kit.top, 0), rgb(79, 220, 255), kit.segments[#LENGTHS]).Material =
				Enum.Material.Neon
			kit.glow(kit.segments[2], rgb(79, 220, 255), 7, 1.2)
			kit.glow(kit.segments[7], rgb(79, 220, 255), 7, 1.2)
		end,
	},
	UmbrellaRod = {
		Name = "Umbrella Rod",
		ToolTip = "A sturdy brolly with a line through the tip.",
		Grip = rgb(78, 43, 31),
		GripMaterial = Enum.Material.Wood,
		Blank = rgb(40, 40, 46),
		Binding = rgb(196, 200, 206),
		Guide = rgb(196, 200, 206),
		Reel = rgb(42, 35, 36),
		Spool = rgb(196, 200, 206),
		Bobber = rgb(206, 52, 58),
		Band = rgb(240, 232, 214),
		Decorate = function(kit)
			local red, cream = rgb(186, 43, 53), rgb(240, 232, 214)
			local silver, leather, wood = rgb(196, 200, 206), rgb(58, 35, 32), rgb(78, 43, 31)
			-- Longitudinal gores give the closed brolly a gathered hem and a
			-- pointed crown. Each section follows its own bending rod joint.
			local radii = { 0.22, 0.25, 0.19, 0.12, 0.045 }
			for index = 1, 4 do
				local segment, length = kit.segments[index], LENGTHS[index]
				local bottom, top = radii[index], radii[index + 1]
				local core = kit.cylinder(
					"UmbrellaCanopy",
					length,
					math.min(bottom, top) * 1.7,
					CFrame.new(0, kit.starts[index] + length / 2, 0),
					red,
					segment
				)
				core.Material = Enum.Material.Fabric
				for fold = 0, 5 do
					local angle = fold * math.pi / 3
					local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
					local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
					local p0 = Vector3.new(0, kit.starts[index], 0) + radial * bottom
					local p1 = Vector3.new(0, kit.starts[index] + length, 0) + radial * top
					local along = (p1 - p0).Unit
					local frame = CFrame.fromMatrix((p0 + p1) / 2, tangent, along, tangent:Cross(along))
					kit.attach(
						segment,
						"UmbrellaPleat",
						Vector3.new((bottom + top) * 0.55, (p1 - p0).Magnitude, 0.065),
						frame,
						if fold % 2 == 0 then red else cream,
						Enum.Material.Fabric
					)
					kit.attach(
						segment,
						"UmbrellaRib",
						Vector3.new(0.018, (p1 - p0).Magnitude, 0.018),
						frame * CFrame.new(0, 0, -0.039),
						silver,
						Enum.Material.Metal
					)
					if index == 1 then
						kit.ball("UmbrellaRibEnd", 0.055, CFrame.new(p0 + radial * 0.039), silver, segment)
					end
				end
			end
			local strapY = kit.starts[2] + 0.28
			kit.cylinder("UmbrellaStrap", 0.105, 0.55, CFrame.new(0, strapY, 0), leather, kit.segments[2]).Material =
				Enum.Material.Fabric
			kit.attach(
				kit.segments[2],
				"UmbrellaStrapTab",
				Vector3.new(0.15, 0.16, 0.035),
				CFrame.new(0, strapY - 0.025, 0.275),
				leather
			)
			kit.ball("UmbrellaStrapStud", 0.055, CFrame.new(0, strapY, 0.305), silver, kit.segments[2])
			kit.cylinder("UmbrellaRunner", 0.14, 0.19, CFrame.new(0, 0.64, 0), silver, kit.segments[1])
			kit.cylinder("UmbrellaCrown", 0.12, 0.14, CFrame.new(0, kit.starts[5], 0), silver, kit.segments[5])
			-- The curve starts exactly at the bottom of the grip.
			kit.cylinder("UmbrellaCrookNeck", 0.16, 0.16, CFrame.new(0, -0.62, 0), wood, kit.handle).Material =
				Enum.Material.Wood
			arc(
				kit,
				kit.handle,
				"UmbrellaCrook",
				Vector3.new(0, -0.62, 0.2),
				Vector3.new(0, 0, -1),
				Vector3.new(0, -1, 0),
				{
					radius = 0.2,
					from = 0,
					to = 210,
					steps = 16,
					thickness = 0.15,
					color = wood,
					material = Enum.Material.Wood,
				}
			)
			kit.ball("UmbrellaCrookCap", 0.155, CFrame.new(0, -0.52, 0.3732), wood, kit.handle).Material =
				Enum.Material.Wood
			kit.cylinder(
				"UmbrellaFerrule",
				0.2,
				0.065,
				CFrame.new(0, kit.top - 0.055, 0),
				silver,
				kit.segments[#LENGTHS]
			)
			kit.ball("UmbrellaTip", 0.07, CFrame.new(0, kit.top + 0.045, 0), silver, kit.segments[#LENGTHS])
		end,
	},
	BambooRod = {
		Name = "Bamboo Rod",
		ToolTip = "Hand-cut cane, light and springy.",
		Grip = rgb(176, 150, 104),
		GripMaterial = Enum.Material.Fabric,
		Blank = rgb(196, 176, 98),
		BlankMaterial = Enum.Material.Wood,
		Binding = rgb(122, 128, 58),
		Reel = rgb(110, 78, 48),
		Spool = rgb(150, 112, 66),
		Bobber = rgb(226, 186, 84),
		Decorate = function(kit)
			-- A second node in each cane joint, and a leaf left on near the grip.
			for index, segment in kit.segments do
				local diameter = kit.diameters[index]
				kit.cylinder(
					"BambooNode",
					0.045,
					diameter + 0.03,
					CFrame.new(0, kit.starts[index] + LENGTHS[index] * 0.6, 0),
					rgb(150, 150, 70),
					segment
				)
			end
			kit.attach(
				kit.segments[1],
				"BambooLeaf",
				Vector3.new(0.02, 0.42, 0.12),
				CFrame.new(0.1, kit.starts[1] + 0.3, 0) * CFrame.Angles(0, 0, math.rad(-35)),
				rgb(92, 150, 64),
				Enum.Material.Grass
			)
		end,
	},
	BoneRod = {
		Name = "Bone Rod",
		ToolTip = "Carved from something big that didn't get away.",
		Grip = rgb(66, 44, 34),
		GripMaterial = Enum.Material.Fabric,
		Blank = rgb(232, 224, 198),
		BlankMaterial = Enum.Material.SmoothPlastic,
		Binding = rgb(200, 188, 158),
		Guide = rgb(200, 188, 158),
		Reel = rgb(66, 44, 34),
		Spool = rgb(214, 204, 176),
		Bobber = rgb(236, 230, 210),
		Band = rgb(90, 64, 52),
		Decorate = function(kit)
			-- Knuckles at every joint and a little skull for a butt cap.
			local bone = rgb(232, 224, 198)
			for index, segment in kit.segments do
				kit.ball(
					"BoneKnuckle",
					kit.diameters[index] * 1.7,
					CFrame.new(0, kit.starts[index] + 0.03, 0),
					bone,
					segment
				)
			end
			local skull = kit.ball("BoneSkull", 0.36, CFrame.new(0, -0.74, 0), bone, kit.handle)
			kit.attach(kit.handle, "BoneJaw", Vector3.new(0.22, 0.12, 0.2), CFrame.new(0, -0.9, -0.04), bone)
			for _, x in { -0.075, 0.075 } do
				kit.ball("BoneEye", 0.1, CFrame.new(x, -0.72, -0.15), rgb(30, 22, 20), skull)
			end
		end,
	},
	LanternRod = {
		Name = "Lantern Rod",
		ToolTip = "A little lantern lights the way to the bite.",
		Grip = rgb(92, 60, 38),
		Blank = rgb(78, 52, 34),
		BlankMaterial = Enum.Material.Wood,
		Binding = rgb(54, 54, 58),
		Guide = rgb(54, 54, 58),
		Reel = rgb(54, 54, 58),
		Spool = rgb(180, 132, 64),
		Bobber = rgb(240, 170, 60),
		Decorate = function(kit)
			-- A hooded lantern hangs off an iron arm just above the grip.
			local iron = rgb(46, 46, 50)
			local segment = kit.segments[2]
			local y = kit.starts[2] + 0.18
			kit.attach(
				segment,
				"LanternArm",
				Vector3.new(0.34, 0.04, 0.04),
				CFrame.new(0.17, y, 0),
				iron,
				Enum.Material.Metal
			)
			kit.attach(
				segment,
				"LanternHook",
				Vector3.new(0.03, 0.12, 0.03),
				CFrame.new(0.32, y - 0.07, 0),
				iron,
				Enum.Material.Metal
			)
			local center = Vector3.new(0.32, y - 0.3, 0)
			kit.attach(
				segment,
				"LanternCap",
				Vector3.new(0.24, 0.05, 0.24),
				CFrame.new(center + Vector3.new(0, 0.17, 0)),
				iron,
				Enum.Material.Metal
			)
			kit.attach(
				segment,
				"LanternBase",
				Vector3.new(0.24, 0.05, 0.24),
				CFrame.new(center - Vector3.new(0, 0.17, 0)),
				iron,
				Enum.Material.Metal
			)
			for _, corner in
				{ Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) }
			do
				kit.attach(
					segment,
					"LanternPost",
					Vector3.new(0.03, 0.3, 0.03),
					CFrame.new(center + corner * 0.1),
					iron,
					Enum.Material.Metal
				)
			end
			local flame = kit.attach(
				segment,
				"LanternGlass",
				Vector3.new(0.15, 0.24, 0.15),
				CFrame.new(center),
				rgb(255, 196, 96),
				Enum.Material.Neon
			)
			flame.Transparency = 0.15
			kit.glow(flame, rgb(255, 190, 110), 9, 1.2)
		end,
	},
	BaguetteRod = {
		Name = "Baguette Rod",
		ToolTip = "Freshly baked, surprisingly stiff. Do not eat.",
		Grip = rgb(238, 232, 214),
		GripMaterial = Enum.Material.Fabric,
		Blank = rgb(204, 142, 70),
		BlankMaterial = Enum.Material.Sand,
		Binding = rgb(158, 96, 44),
		Bobber = rgb(46, 84, 170),
		Diameter = function(index: number): number
			return 0.23 - (index - 1) * 0.019
		end,
		Decorate = function(kit)
			-- Paper bag stripes on the grip and slashed crust along the loaf.
			for _, y in { -0.25, 0.25 } do
				kit.cylinder("BaguetteBagStripe", 0.06, 0.26, CFrame.new(0, y, 0), rgb(46, 84, 170), kit.handle)
			end
			for index, segment in kit.segments do
				local diameter = kit.diameters[index]
				local side = if index % 2 == 0 then 1 else -1
				kit.attach(
					segment,
					"BaguetteScore",
					Vector3.new(diameter * 0.75, 0.05, 0.03),
					CFrame.new(0, kit.starts[index] + LENGTHS[index] / 2, side * diameter / 2)
						* CFrame.Angles(0, 0, math.rad(35)),
					rgb(238, 206, 150),
					Enum.Material.Sand
				)
			end
			kit.ball(
				"BaguetteEnd",
				kit.diameters[#LENGTHS],
				CFrame.new(0, kit.top, 0),
				rgb(204, 142, 70),
				kit.segments[#LENGTHS]
			).Material =
				Enum.Material.Sand
		end,
	},
	NightRod = {
		Name = "Night Rod",
		ToolTip = "Astral fish answer its call after dark.",
		Grip = rgb(36, 30, 72),
		GripMaterial = Enum.Material.Fabric,
		Blank = rgb(24, 28, 62),
		BlankMaterial = Enum.Material.SmoothPlastic,
		Binding = rgb(200, 208, 232),
		Guide = rgb(200, 208, 232),
		Reel = rgb(30, 30, 56),
		Spool = rgb(200, 208, 232),
		Bobber = rgb(84, 60, 168),
		Band = rgb(150, 220, 255),
		Decorate = function(kit)
			-- Stars along the blank and a glowing crescent moon at the butt.
			local star = rgb(190, 225, 255)
			for index, segment in kit.segments do
				local side = if index % 2 == 0 then 1 else -1
				local piece = kit.ball(
					"NightStar",
					0.06,
					CFrame.new(side * kit.diameters[index] / 2, kit.starts[index] + LENGTHS[index] * 0.55, 0),
					star,
					segment
				)
				piece.Material = Enum.Material.Neon
			end
			arc(kit, kit.handle, "NightMoon", Vector3.new(0, -0.82, 0), Vector3.new(0, 1, 0), Vector3.new(1, 0, 0), {
				radius = 0.2,
				from = 135,
				to = 405,
				steps = 9,
				thickness = 0.09,
				color = rgb(242, 236, 176),
				material = Enum.Material.Neon,
			})
			kit.attach(
				kit.handle,
				"NightMoonMount",
				Vector3.new(0.05, 0.12, 0.05),
				CFrame.new(0, -0.6, 0),
				rgb(200, 208, 232),
				Enum.Material.Metal
			)
			local bobber = kit.tool:FindFirstChild("RodBobber")
			if bobber then
				kit.glow(bobber, rgb(150, 130, 255), 6, 0.8)
			end
			kit.glow(kit.handle, rgb(242, 236, 176), 7, 0.6)
		end,
	},
	MageStaff = {
		Name = "Mage Staff",
		ToolTip = "An old sorcerer's staff, still humming with magic.",
		Grip = rgb(28, 26, 32),
		GripMaterial = Enum.Material.Fabric,
		Blank = rgb(26, 24, 30),
		BlankMaterial = Enum.Material.SmoothPlastic,
		Binding = rgb(212, 168, 72),
		Guide = rgb(212, 168, 72),
		Reel = rgb(28, 26, 32),
		Spool = rgb(212, 168, 72),
		Bobber = rgb(214, 40, 44),
		Band = rgb(212, 168, 72),
		Diameter = function(index: number): number
			return 0.13 - (index - 1) * 0.008
		end,
		Decorate = function(kit)
			local gold, black = rgb(212, 168, 72), rgb(26, 24, 30)
			-- Gold rings on the grip, a gold spike for a butt and a gold diamond collar.
			for _, y in { -0.3, 0, 0.3 } do
				kit.cylinder("StaffRing", 0.05, 0.28, CFrame.new(0, y, 0), gold, kit.handle)
			end
			for step, diameter in { 0.2, 0.15, 0.1, 0.05 } do
				kit.cylinder("StaffSpike", 0.1, diameter, CFrame.new(0, -0.6 - step * 0.09, 0), gold, kit.handle)
			end
			local collar = kit.segments[4]
			kit.attach(
				collar,
				"StaffCollar",
				Vector3.new(0.18, 0.18, 0.18),
				CFrame.new(0, kit.starts[4] + 0.1, 0) * CFrame.Angles(0, math.rad(45), math.rad(45)),
				gold,
				Enum.Material.Metal
			)
			-- The head: a white disc holding a glowing red orb inside a dark crescent.
			local tip = kit.segments[#LENGTHS]
			local center = Vector3.new(0, kit.top + 0.12, 0.2)
			local disc = kit.attach(
				tip,
				"StaffDisc",
				Vector3.new(0.05, 0.3, 0.3),
				CFrame.new(center) * CFrame.Angles(0, math.pi / 2, 0),
				rgb(245, 240, 232),
				Enum.Material.SmoothPlastic
			)
			disc.Shape = Enum.PartType.Cylinder
			local orb = kit.ball("StaffOrb", 0.16, CFrame.new(center), rgb(232, 36, 40), tip)
			orb.Material = Enum.Material.Neon
			kit.glow(orb, rgb(255, 60, 60), 8, 1.4)
			arc(kit, tip, "StaffCrescent", center, Vector3.new(1, 0, 0), Vector3.new(0, 1, 0), {
				radius = 0.27,
				from = -20,
				to = 230,
				steps = 10,
				thickness = 0.1,
				taper = true,
				color = black,
				material = Enum.Material.SmoothPlastic,
			})
			kit.attach(tip, "StaffNeck", Vector3.new(0.05, 0.16, 0.2), CFrame.new(0, kit.top - 0.02, 0.1), black)
			kit.ball("StaffJewel", 0.07, CFrame.new(center + Vector3.new(0.26, -0.1, 0)), gold, tip)
		end,
	},
}
for _, style in STYLES do
	setmetatable(style, { __index = DEFAULT })
end

-- `skinId` is a RodSkins id; nil or unknown builds the plain starter rod.
function FishingRod.build(skinId: string?, bobberSkinId: string?): Tool
	local style: Style = (skinId and STYLES[skinId] or DEFAULT) :: any
	local tool = Instance.new("Tool")
	tool.Name = style.Name
	tool.ToolTip = style.ToolTip
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	-- RightGrip applies the inverse of Tool.Grip. Positive pitch leans the
	-- shaft's local +Y toward the angler's forward (-Z), above the water.
	tool.Grip = CFrame.new(0, -0.18, 0) * CFrame.Angles(math.rad(55), 0, 0)
	tool:SetAttribute("RodId", "StarterRod")
	if skinId and STYLES[skinId] then
		tool:SetAttribute("RodSkin", skinId)
	end
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
	local handle = part("Handle", Vector3.new(0.24, 1.13, 0.24), CFrame.identity, style.Grip)
	handle.Transparency = 1
	handle.RootPriority = 127
	local grip = cylinder("CorkGrip", 1.13, 0.25, CFrame.identity, style.Grip, handle)
	grip.Material = style.GripMaterial
	for _, y in { -0.51, 0.51 } do
		cylinder("GripFerrule", 0.075, 0.28, CFrame.new(0, y, 0), style.Binding, handle)
	end
	local reelSeat = part("ReelSeat", Vector3.new(0.12, 0.54, 0.10), CFrame.new(0, 0.05, -0.18), style.Reel)
	weld(handle, reelSeat)
	local reelFoot = part("ReelFoot", Vector3.new(0.10, 0.15, 0.25), CFrame.new(0, -0.02, -0.33), style.Guide)
	weld(handle, reelFoot)
	local reelBody = part("ReelBody", Vector3.new(0.31, 0.30, 0.25), CFrame.new(0, -0.07, -0.49), style.Reel)
	weld(handle, reelBody)
	local spool = cylinder("ReelSpool", 0.24, 0.30, CFrame.new(0, 0.15, -0.51), style.Spool, handle)
	local spoolLine =
		cylinder("SpoolLine", 0.14, 0.315, CFrame.new(0, 0.15, -0.51), Color3.fromRGB(194, 204, 183), handle)
	local crank = part("ReelCrank", Vector3.new(0.27, 0.055, 0.055), CFrame.new(0.25, -0.08, -0.49), style.Guide)
	weld(handle, crank)
	cylinder("CrankGrip", 0.16, 0.095, CFrame.new(0.37, -0.14, -0.49), style.Reel, handle)

	local previous: BasePart = handle
	local height = 0.54
	local previousLine = attachment(spoolLine, "SpoolLineExit", CFrame.new(0, 0.28, -0.51))
	local tip: Attachment? = nil
	local segments, starts, diameters = {}, {}, {}
	for index, length in LENGTHS do
		local diameter = if style.Diameter then style.Diameter(index) else 0.11 - (index - 1) * 0.0105
		local segment =
			cylinder("RodSegment" .. index, length, diameter, CFrame.new(0, height + length / 2, 0), style.Blank)
		segment.Material = style.BlankMaterial
		segments[index], starts[index], diameters[index] = segment, height, diameter
		local pivot = CFrame.new(0, height, 0)
		local joint = Instance.new("Motor6D")
		joint.Name = "RodBend" .. index
		joint.Part0, joint.Part1 = previous, segment
		joint.C0, joint.C1 = previous.CFrame:ToObjectSpace(pivot), segment.CFrame:ToObjectSpace(pivot)
		joint:SetAttribute("RodSegment", index)
		joint:SetAttribute("FlexWeight", index / #LENGTHS)
		joint.Parent = segment
		cylinder("BlankBinding", 0.055, diameter + 0.025, CFrame.new(0, height + 0.07, 0), style.Binding, segment)
		height += length
		if index % 2 == 0 then
			local center = Vector3.new(0, height - 0.06, -0.12)
			for _, side in { -1, 1 } do
				local crossbar = part(
					"LineGuide",
					Vector3.new(0.15, 0.022, 0.022),
					CFrame.new(center + Vector3.new(0, 0, side * 0.065)),
					style.Guide
				)
				weld(segment, crossbar)
				local upright = part(
					"LineGuide",
					Vector3.new(0.022, 0.022, 0.15),
					CFrame.new(center + Vector3.new(side * 0.065, 0, 0)),
					style.Guide
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
	local bobber =
		part("RodBobber", Vector3.new(0.23, 0.31, 0.23), bobberFrame, style.Bobber, Enum.Material.SmoothPlastic)
	bobber.Shape = Enum.PartType.Ball
	local band = cylinder("BobberBand", 0.10, 0.235, bobberFrame * CFrame.new(0, -0.025, 0), style.Band, bobber)
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

	if style.Decorate then
		-- Skin pieces are welded to the part they ride on, so they follow its bend.
		local function attach(
			parent: BasePart,
			name: string,
			size: Vector3,
			frame: CFrame,
			color: Color3,
			material: Enum.Material?
		): Part
			local item = part(name, size, frame, color, material or Enum.Material.SmoothPlastic)
			weld(parent, item)
			return item
		end
		style.Decorate({
			tool = tool,
			handle = handle,
			segments = segments,
			starts = starts,
			diameters = diameters,
			top = height,
			attach = attach,
			cylinder = cylinder,
			ball = function(name: string, diameter: number, frame: CFrame, color: Color3, parent: BasePart): Part
				local item = attach(parent, name, Vector3.new(diameter, diameter, diameter), frame, color)
				item.Shape = Enum.PartType.Ball
				return item
			end,
			glow = function(parent: BasePart, color: Color3, range: number, brightness: number)
				local light = Instance.new("PointLight")
				light.Color, light.Range, light.Brightness = color, range, brightness
				light.Shadows = false
				light.Parent = parent
			end,
		})
	end
	if bobberSkinId then
		-- Load only for a selected bobber; plain rods retain their original float.
		local FishingBobber = require(script.Parent.FishingBobber)
		band:Destroy()
		local stem = tool:FindFirstChild("BobberStem")
		if stem then
			stem:Destroy()
		end
		for _, child in bobber:GetChildren() do
			if child:IsA("Light") then
				child:Destroy()
			end
		end
		FishingBobber.decorate(bobber, bobberSkinId)
		tool:SetAttribute("BobberSkin", bobberSkinId)
	end
	CollectionService:AddTag(tool, "FishingRod")
	return tool
end

return FishingRod
