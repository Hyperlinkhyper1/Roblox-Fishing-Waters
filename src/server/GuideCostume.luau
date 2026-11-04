-- Part-built clothes for the tutorial guides. Limb colours make the shirt, trousers, boots and
-- gloves; hats, aprons, stripes and the rest are small parts welded to the limb they belong to, so
-- they follow the idle animation. Nothing loads from the Marketplace, so a guide always turns up
-- dressed for their job. Outfits are data in Shared.Tutorial (colours as { r, g, b }).
local Players = game:GetService("Players")

local Costume = {}

local M = Enum.Material
local BLACK = Color3.new(0, 0, 0)

local function rgb(color): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

local function plainBody(skin: Color3): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	description.HeadColor, description.TorsoColor = skin, skin
	description.LeftArmColor, description.RightArmColor = skin, skin
	description.LeftLegColor, description.RightLegColor = skin, skin
	-- Classic proportions, like the hired staff, so every piece below fits the same limbs.
	description.BodyTypeScale, description.ProportionScale = 0, 0
	description.HeightScale, description.WidthScale, description.DepthScale = 1, 1, 1
	description.HeadScale = 1
	return description
end

-- Which outfit colour each limb wears.
local function limbColors(outfit): { [string]: Color3 }
	local skin, shirt, trousers = rgb(outfit.Skin), rgb(outfit.Shirt), rgb(outfit.Trousers)
	local sleeve = if outfit.Sleeves == "None" then skin else shirt
	local forearm = if outfit.Sleeves == "Long" then shirt else skin
	local hand = if outfit.Gloves then rgb(outfit.Gloves) else skin
	local shin = if outfit.Boots then rgb(outfit.Boots) else trousers
	local shoe = if outfit.Boots then rgb(outfit.Boots) else rgb(outfit.Shoes)
	return {
		Head = skin,
		UpperTorso = shirt,
		LowerTorso = trousers,
		LeftUpperArm = sleeve,
		RightUpperArm = sleeve,
		LeftLowerArm = forearm,
		RightLowerArm = forearm,
		LeftHand = hand,
		RightHand = hand,
		LeftUpperLeg = trousers,
		RightUpperLeg = trousers,
		LeftLowerLeg = shin,
		RightLowerLeg = shin,
		LeftFoot = shoe,
		RightFoot = shoe,
	}
end

local function paint(model: Model, outfit)
	local bodyColors = model:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		-- It would repaint every limb in its single arm/leg colour.
		bodyColors:Destroy()
	end
	local skin = rgb(outfit.Skin)
	for name, color in limbColors(outfit) do
		local limb = model:FindFirstChild(name)
		if limb and limb:IsA("BasePart") then
			limb.Color = color
			limb.Material = if color == skin then M.SmoothPlastic else M.Fabric
		end
	end
end

-- One costume part at `offset` in `limb`'s space, welded so it follows the limb.
local function piece(
	into: Folder,
	limb: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	shape: ("Block" | "Cylinder" | "Ball" | "Round")?,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or M.Fabric
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	part.Massless = true
	if shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	elseif shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif shape == "Round" then
		-- A stretched sphere that fills the part's box: hair, buns, beards, cap crowns.
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.CFrame = limb.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = limb, part
	weld.Parent = part
	part.Parent = into
	return part
end

-- Cylinders run along X; these turn one upright or face-on.
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)
local FACE_ON = CFrame.Angles(0, math.pi / 2, 0)

local function at(x: number, y: number, z: number, turn: CFrame?): CFrame
	return CFrame.new(x, y, z) * (turn or CFrame.identity)
end

local function hair(into: Folder, head: BasePart, outfit)
	local s = head.Size
	local color = rgb(outfit.Hair)
	local style = outfit.HairStyle
	if style ~= "Bald" then
		piece(into, head, "Hair", Vector3.new(s.X * 1.08, s.Y * 0.62, s.Z * 1.1), at(0, s.Y * 0.3, s.Z * 0.05), color, "Round")
	end
	if style == "Bun" then
		piece(into, head, "Bun", s * 0.42, at(0, s.Y * 0.4, s.Z * 0.48), color, "Round")
	elseif style == "Ponytail" then
		piece(into, head, "PonytailTie", s * 0.18, at(0, s.Y * 0.18, s.Z * 0.55), color:Lerp(BLACK, 0.3), "Round")
		piece(
			into,
			head,
			"Ponytail",
			Vector3.new(s.X * 0.3, s.Y * 0.8, s.Z * 0.3),
			at(0, -s.Y * 0.18, s.Z * 0.62, CFrame.Angles(0.3, 0, 0)),
			color,
			"Round"
		)
	end
	if outfit.Beard then
		piece(
			into,
			head,
			"Beard",
			Vector3.new(s.X * 0.86, s.Y * 0.46, s.Z * 0.6),
			at(0, -s.Y * 0.34, -s.Z * 0.2),
			rgb(outfit.Beard),
			"Round"
		)
	end
end

local KINDS = {}

-- Peaked harbour cap: white crown, dark band and peak, gold badge.
function KINDS.CaptainCap(into, parts, spec)
	local head = parts.Head
	local s = head.Size
	local band = rgb(spec.Band)
	piece(into, head, "CapCrown", Vector3.new(s.Y * 0.2, s.X * 1.22, s.X * 1.22), at(0, s.Y * 0.68, 0.04, UPRIGHT), rgb(spec.Color), "Cylinder")
	piece(into, head, "CapBand", Vector3.new(s.Y * 0.18, s.X * 1.1, s.X * 1.1), at(0, s.Y * 0.52, 0, UPRIGHT), band, "Cylinder")
	piece(
		into,
		head,
		"CapPeak",
		Vector3.new(s.X * 0.8, 0.06, s.Z * 0.42),
		at(0, s.Y * 0.44, -s.Z * 0.66, CFrame.Angles(-0.3, 0, 0)),
		band,
		"Block",
		M.SmoothPlastic
	)
	piece(into, head, "CapBadge", Vector3.new(s.X * 0.22, s.Y * 0.12, 0.06), at(0, s.Y * 0.53, -s.X * 0.56), rgb(spec.Badge), "Block", M.Metal)
end

local function brimmedHat(into, parts, spec, brim: number, crown: number)
	local head = parts.Head
	local s = head.Size
	local color = rgb(spec.Color)
	piece(into, head, "HatBrim", Vector3.new(0.08, s.X * brim, s.X * brim), at(0, s.Y * 0.52, 0, UPRIGHT), color, "Cylinder")
	piece(into, head, "HatCrown", Vector3.new(s.Y * crown, s.X * 1.08, s.X * 1.08), at(0, s.Y * (0.52 + crown / 2), 0, UPRIGHT), color, "Cylinder")
	piece(into, head, "HatBand", Vector3.new(s.Y * 0.1, s.X * 1.11, s.X * 1.11), at(0, s.Y * 0.6, 0, UPRIGHT), rgb(spec.Band), "Cylinder")
	piece(into, head, "HatTop", Vector3.new(s.X * 1.0, s.Y * 0.12, s.X * 1.0), at(0, s.Y * (0.52 + crown), 0), color, "Round")
end

-- Wide-brimmed straw sun hat.
function KINDS.StrawHat(into, parts, spec)
	brimmedHat(into, parts, spec, 2.3, 0.36)
end

-- Narrower cream panama.
function KINDS.Panama(into, parts, spec)
	brimmedHat(into, parts, spec, 1.75, 0.32)
end

function KINDS.FlatCap(into, parts, spec)
	local head = parts.Head
	local s = head.Size
	local color = rgb(spec.Color)
	piece(into, head, "CapCrown", Vector3.new(s.X * 1.16, s.Y * 0.36, s.Z * 1.22), at(0, s.Y * 0.56, -s.Z * 0.04), color, "Round")
	piece(
		into,
		head,
		"CapPeak",
		Vector3.new(s.X * 0.82, 0.08, s.Z * 0.32),
		at(0, s.Y * 0.5, -s.Z * 0.6, CFrame.Angles(-0.15, 0, 0)),
		color:Lerp(BLACK, 0.15),
		"Block"
	)
end

-- Scarf wrapped over the hair and knotted at the back.
function KINDS.Headscarf(into, parts, spec)
	local head = parts.Head
	local s = head.Size
	local color = rgb(spec.Color)
	piece(into, head, "Scarf", Vector3.new(s.X * 1.14, s.Y * 0.7, s.Z * 1.16), at(0, s.Y * 0.3, s.Z * 0.06), color, "Round")
	piece(into, head, "ScarfKnot", s * 0.26, at(0, s.Y * 0.06, s.Z * 0.6), color:Lerp(BLACK, 0.12), "Round")
	piece(into, head, "ScarfTail", Vector3.new(s.X * 0.18, s.Y * 0.4, 0.08), at(s.X * 0.08, -s.Y * 0.16, s.Z * 0.64, CFrame.Angles(0.2, 0, 0.25)), color)
end

function KINDS.Bandana(into, parts, spec)
	local head = parts.Head
	local s = head.Size
	local color = rgb(spec.Color)
	local width = math.max(s.X, s.Z) * 1.12
	piece(into, head, "Bandana", Vector3.new(s.Y * 0.2, width, width), at(0, s.Y * 0.36, s.Z * 0.02, UPRIGHT), color, "Cylinder")
	piece(into, head, "BandanaKnot", s * 0.2, at(0, s.Y * 0.34, s.Z * 0.58), color, "Round")
	for side = -1, 1, 2 do
		piece(
			into,
			head,
			"BandanaTail",
			Vector3.new(s.X * 0.12, s.Y * 0.34, 0.06),
			at(side * s.X * 0.08, s.Y * 0.14, s.Z * 0.6, CFrame.Angles(0.15, 0, side * 0.3)),
			color
		)
	end
end

-- A carpenter's pencil tucked behind the right ear.
function KINDS.Pencil(into, parts, spec)
	local head = parts.Head
	local s = head.Size
	piece(into, head, "Pencil", Vector3.new(s.Z * 0.5, 0.09, 0.09), at(s.X * 0.52, s.Y * 0.08, s.Z * 0.04, FACE_ON), rgb(spec.Color), "Cylinder", M.Wood)
end

-- Navy/white bands round the torso and short sleeves.
function KINDS.Stripes(into, parts, spec)
	local color = rgb(spec.Color)
	local torso = parts.UpperTorso
	local t = torso.Size
	for i = 0, 4 do
		local y = t.Y * (0.34 - i * 0.17)
		piece(into, torso, "Stripe", Vector3.new(t.X * 1.03, t.Y * 0.065, t.Z * 1.08), at(0, y, 0), color)
	end
	for _, name in { "LeftUpperArm", "RightUpperArm" } do
		local arm = parts[name]
		if arm then
			local a = arm.Size
			for i = 0, 1 do
				piece(into, arm, "Stripe", Vector3.new(a.X * 1.08, a.Y * 0.1, a.Z * 1.08), at(0, a.Y * (0.15 - i * 0.3), 0), color)
			end
		end
	end
end

-- A contrasting shirt front under an open jacket, with brass buttons down the jacket edge.
function KINDS.ShirtFront(into, parts, spec)
	local torso = parts.UpperTorso
	local t = torso.Size
	local front = -t.Z / 2
	piece(into, torso, "ShirtFront", Vector3.new(t.X * 0.3, t.Y * 0.96, 0.06), at(0, 0.02, front - 0.02), rgb(spec.Color))
	if spec.Buttons then
		for i = 0, 2 do
			for side = -1, 1, 2 do
				piece(
					into,
					torso,
					"Button",
					Vector3.new(0.14, 0.14, 0.14),
					at(side * t.X * 0.24, t.Y * (0.2 - i * 0.24), front - 0.03),
					rgb(spec.Buttons),
					"Ball",
					M.Metal
				)
			end
		end
	end
end

-- A small triangle of cloth at the throat, under a knotted collar.
function KINDS.Neckerchief(into, parts, spec)
	local torso = parts.UpperTorso
	local t = torso.Size
	local color = rgb(spec.Color)
	local side = t.X * 0.22
	piece(into, torso, "Neckerchief", Vector3.new(side, side, 0.06), at(0, t.Y * 0.32, -t.Z / 2 - 0.04, CFrame.Angles(0, 0, math.pi / 4)), color)
	piece(into, torso, "NeckerchiefCollar", Vector3.new(0.2, t.Z * 0.8, t.Z * 0.8), at(0, t.Y / 2 + 0.04, 0, UPRIGHT), color, "Cylinder")
end

-- Open sleeveless vest with patch pockets.
function KINDS.Vest(into, parts, spec)
	local torso = parts.UpperTorso
	local t = torso.Size
	local color = rgb(spec.Color)
	local pocket = color:Lerp(BLACK, 0.22)
	local height = t.Y * 0.98
	for side = -1, 1, 2 do
		local x = side * t.X * 0.31
		piece(into, torso, "VestFront", Vector3.new(t.X * 0.36, height, 0.07), at(x, 0, -t.Z / 2 - 0.035), color)
		piece(into, torso, "VestSide", Vector3.new(0.07, height, t.Z * 1.04), at(side * (t.X / 2 + 0.035), 0, 0), color)
		for row = 0, 1 do
			piece(
				into,
				torso,
				"VestPocket",
				Vector3.new(t.X * 0.24, t.Y * 0.18, 0.05),
				at(x, -t.Y * (0.08 + row * 0.24), -t.Z / 2 - 0.08),
				pocket
			)
		end
	end
	piece(into, torso, "VestBack", Vector3.new(t.X * 1.04, height, 0.07), at(0, 0, t.Z / 2 + 0.035), color)
end

-- Bib apron tied at the waist, its skirt hanging over the thighs.
function KINDS.Apron(into, parts, spec)
	local torso, waist = parts.UpperTorso, parts.LowerTorso
	local t, w = torso.Size, waist.Size
	local thigh = parts.LeftUpperLeg and parts.LeftUpperLeg.Size.Y or 1.2
	local color = rgb(spec.Color)
	piece(into, torso, "ApronBib", Vector3.new(t.X * 0.56, t.Y * 0.78, 0.06), at(0, -t.Y * 0.11, -t.Z / 2 - 0.035), color)
	for side = -1, 1, 2 do
		piece(into, torso, "ApronStrap", Vector3.new(0.12, t.Y * 0.3, 0.06), at(side * t.X * 0.2, t.Y * 0.38, -t.Z / 2 - 0.035), color)
	end
	local skirt = w.Y + thigh * 0.85
	piece(into, waist, "ApronSkirt", Vector3.new(w.X * 0.96, skirt, 0.06), at(0, w.Y / 2 - skirt / 2, -w.Z / 2 - 0.05), color)
	piece(into, waist, "ApronTie", Vector3.new(w.X * 1.04, 0.1, w.Z * 1.08), at(0, w.Y * 0.3, 0), color:Lerp(BLACK, 0.2))
	if spec.Pockets then
		for side = -1, 1, 2 do
			piece(
				into,
				waist,
				"ApronPocket",
				Vector3.new(w.X * 0.34, thigh * 0.3, 0.05),
				at(side * w.X * 0.22, w.Y / 2 - skirt * 0.45, -w.Z / 2 - 0.09),
				color:Lerp(BLACK, 0.18)
			)
		end
	end
end

-- Work dungarees: a bib and braces over the top.
function KINDS.Dungarees(into, parts, spec)
	local torso = parts.UpperTorso
	local t = torso.Size
	local color = rgb(spec.Color)
	piece(into, torso, "DungareeBib", Vector3.new(t.X * 0.54, t.Y * 0.56, 0.07), at(0, -t.Y * 0.22, -t.Z / 2 - 0.035), color)
	piece(into, torso, "DungareePocket", Vector3.new(t.X * 0.24, t.Y * 0.18, 0.05), at(0, -t.Y * 0.18, -t.Z / 2 - 0.08), color:Lerp(BLACK, 0.18))
	for side = -1, 1, 2 do
		for face = -1, 1, 2 do
			piece(
				into,
				torso,
				"DungareeBrace",
				Vector3.new(0.16, t.Y * 0.56, 0.06),
				at(side * t.X * 0.22, t.Y * 0.2, face * (t.Z / 2 + 0.035)),
				color
			)
		end
		piece(into, torso, "DungareeButton", Vector3.new(0.13, 0.13, 0.13), at(side * t.X * 0.22, t.Y * 0.04, -t.Z / 2 - 0.08), Color3.fromRGB(190, 172, 120), "Ball", M.Metal)
	end
end

function KINDS.Belt(into, parts, spec)
	local waist = parts.LowerTorso
	local w = waist.Size
	piece(into, waist, "Belt", Vector3.new(w.X * 1.04, w.Y * 0.4, w.Z * 1.08), at(0, w.Y * 0.2, 0), rgb(spec.Color), "Block", M.Leather)
	piece(into, waist, "Buckle", Vector3.new(0.24, w.Y * 0.42, 0.06), at(0, w.Y * 0.2, -w.Z * 0.56), Color3.fromRGB(196, 170, 104), "Block", M.Metal)
end

-- Strap from the left shoulder to the right hip, front and back.
local function sash(into, torso: BasePart, name: string, color: Color3, width: number)
	local t = torso.Size
	local length = math.sqrt(t.X * t.X + t.Y * t.Y)
	local angle = math.atan2(t.Y, t.X)
	for _, face in { -1, 1 } do
		piece(
			into,
			torso,
			name,
			Vector3.new(length, width, 0.07),
			at(0, 0, face * (t.Z / 2 + 0.04), CFrame.Angles(0, 0, -angle)),
			color,
			"Block",
			M.Leather
		)
	end
end

-- Leather market satchel slung across the body.
function KINDS.Satchel(into, parts, spec)
	local color = rgb(spec.Color)
	sash(into, parts.UpperTorso, "SatchelStrap", color:Lerp(BLACK, 0.15), 0.2)
	local waist = parts.LowerTorso
	local w = waist.Size
	piece(into, waist, "Satchel", Vector3.new(0.36, 0.8, 0.95), at(w.X / 2 + 0.22, -0.3, 0), color, "Block", M.Leather)
	piece(into, waist, "SatchelFlap", Vector3.new(0.4, 0.36, 0.99), at(w.X / 2 + 0.24, -0.04, 0), color:Lerp(BLACK, 0.2), "Block", M.Leather)
end

-- A coil of mooring line over the shoulder, hanging on the back.
function KINDS.Rope(into, parts, spec)
	local torso = parts.UpperTorso
	local t = torso.Size
	local color = rgb(spec.Color)
	sash(into, torso, "RopeSling", color, 0.18)
	piece(into, torso, "RopeCoil", Vector3.new(0.28, 1.35, 1.35), at(t.X * 0.12, -t.Y * 0.05, t.Z / 2 + 0.2, FACE_ON), color, "Cylinder")
	piece(into, torso, "RopeCoilHole", Vector3.new(0.3, 0.7, 0.7), at(t.X * 0.12, -t.Y * 0.05, t.Z / 2 + 0.21, FACE_ON), color:Lerp(BLACK, 0.45), "Cylinder")
end

-- Three-cornered hat: a low crown with the brim turned up on three sides, edged in `Trim`.
function KINDS.Tricorne(into, parts, spec)
	local head = parts.Head
	local s = head.Size
	local color = rgb(spec.Color)
	local trim = if spec.Trim then rgb(spec.Trim) else color:Lerp(BLACK, 0.3)
	piece(into, head, "HatCrown", Vector3.new(s.Y * 0.34, s.X * 1.08, s.X * 1.08), at(0, s.Y * 0.68, 0, UPRIGHT), color, "Cylinder")
	piece(into, head, "HatTop", Vector3.new(s.X * 1.0, s.Y * 0.14, s.X * 1.0), at(0, s.Y * 0.85, 0), color, "Round")
	local reach = s.X * 0.62
	for corner = 0, 2 do
		-- One turned-up wall per side of the triangle, its point at the front.
		local angle = corner * math.pi * 2 / 3 + math.pi / 3
		local turn = CFrame.Angles(0, angle, 0)
		local offset = turn * CFrame.new(0, 0, reach) * CFrame.Angles(-0.35, 0, 0)
		local wall = Vector3.new(s.X * 1.25, s.Y * 0.34, 0.08)
		piece(into, head, "HatBrim", wall, CFrame.new(0, s.Y * 0.62, 0) * offset, color)
		piece(into, head, "HatTrim", Vector3.new(wall.X, 0.08, 0.1), CFrame.new(0, s.Y * 0.62, 0) * offset * CFrame.new(0, wall.Y / 2, 0), trim)
	end
end

-- A patch over the left eye on a thin strap round the head.
function KINDS.EyePatch(into, parts, spec)
	local head = parts.Head
	local s = head.Size
	local color = rgb(spec.Color)
	piece(into, head, "EyePatch", Vector3.new(s.X * 0.26, s.Y * 0.24, 0.08), at(-s.X * 0.2, s.Y * 0.08, -s.Z * 0.5), color, "Block", M.Leather)
	piece(into, head, "EyePatchStrap", Vector3.new(0.06, s.X * 1.04, s.X * 1.04), at(0, s.Y * 0.16, 0, UPRIGHT * CFrame.Angles(0.25, 0, 0)), color, "Cylinder", M.Leather)
end

-- A gold hoop in the right ear.
function KINDS.Earring(into, parts, spec)
	local head = parts.Head
	local s = head.Size
	piece(into, head, "Earring", Vector3.new(0.05, 0.3, 0.3), at(s.X * 0.52, -s.Y * 0.1, 0), rgb(spec.Color), "Cylinder", M.Metal)
end

-- Builds a dressed R15 guide, or nil when the engine cannot make a character at all.
function Costume.build(outfit): (Model?, string?)
	local description = plainBody(rgb(outfit.Skin))
	local ok, model = pcall(Players.CreateHumanoidModelFromDescriptionAsync, Players, description, Enum.HumanoidRigType.R15)
	description:Destroy()
	if not ok then
		return nil, tostring(model)
	end
	paint(model, outfit)
	local parts = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			parts[child.Name] = child
		end
	end
	if not (parts.Head and parts.UpperTorso and parts.LowerTorso) then
		return model, nil
	end
	local into = Instance.new("Folder")
	into.Name = "Costume"
	into.Parent = model
	hair(into, parts.Head, outfit)
	for _, spec in outfit.Pieces or {} do
		local kind = KINDS[spec.Kind]
		if kind then
			kind(into, parts, spec)
		else
			warn("[GuideCostume] Unknown costume piece: " .. tostring(spec.Kind))
		end
	end
	return model, nil
end

local IDLE_ANIMATION = "rbxassetid://507766388" -- Roblox's stock R15 idle

-- A standing, idling NPC in `outfit` with its feet at `frame`, parented to `parent`. It never moves
-- or collides; only its head can be hit, so prompts on it work. Clients turn it towards whoever walks
-- up and back to its HomeFrame. Nil (with a warning) when the engine cannot make a character.
function Costume.spawn(id: string, outfit, displayName: string, frame: CFrame, parent: Instance): Model?
	local model, problem = Costume.build(outfit)
	if not model then
		warn("[GuideCostume] " .. displayName .. " could not be built: " .. tostring(problem))
		return nil
	end
	model.Name = id
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("NpcId", id)
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		-- Classic outfits bring a face decal and dynamic heads bring FaceControls; anything else
		-- gets the engine's built-in smile, like the other locals.
		if not head:FindFirstChildOfClass("Decal") and not head:FindFirstChildOfClass("FaceControls") then
			local face = Instance.new("Decal")
			face.Name, face.Face, face.Texture = "face", Enum.NormalId.Front, "rbxasset://textures/face.png"
			face.Parent = head
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = displayName
		humanoid.NameDisplayDistance = 40
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.WalkSpeed, humanoid.JumpPower = 0, 0
		humanoid.BreakJointsOnDeath = false
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = part.Name == "HumanoidRootPart"
			part.CanCollide, part.CanTouch = false, false
			part.CanQuery = part.Name == "Head"
		end
	end
	-- The pivot is the root part; it rides HipHeight above the feet. Measuring the whole model
	-- instead counts hats and hair and leaves the NPC hovering.
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	local lift = if humanoid and root and root:IsA("BasePart")
		then humanoid.HipHeight + root.Size.Y / 2
		else model:GetExtentsSize().Y / 2
	model:PivotTo(frame + Vector3.new(0, lift, 0))
	model:SetAttribute("HomeFrame", model:GetPivot())
	model.Parent = parent
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local idle = Instance.new("Animation")
		idle.AnimationId = IDLE_ANIMATION
		local loaded, track = pcall(animator.LoadAnimation, animator, idle)
		if loaded then
			track.Looped = true
			track:Play()
		end
	end
	return model
end

Costume.Kinds = KINDS

return Costume
