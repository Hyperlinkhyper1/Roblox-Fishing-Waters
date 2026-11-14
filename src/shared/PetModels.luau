-- Pets for the pet deck of the /tp models showcase (ScaleModels). Each pet is a model of anchored,
-- non-colliding parts sorted into joint groups: child Models carrying a "Joint" attribute (the
-- joint's CFrame relative to the pet's Root, axis aligned), the name of the group they hang from
-- and their order. The server builds the pet at rest and never moves it; the client
-- (ShowcasePets) reads the rest pose once with PetModels.rig and poses the groups every frame
-- with PetModels.step, so the animation costs the server nothing.
--
-- The scarlet macaw stands with its feet on its frame, gripping a perch bar of PERCH_RADIUS that
-- runs along its local X just under its feet, and looks along -Z.
local PetModels = {}

PetModels.TAG = "AnimatedPet"
-- Radius of the perch bar the macaw's toes wrap, at scale 1; the bar's centre sits this far
-- below the frame
PetModels.PERCH_RADIUS = 0.1

local rgb = Color3.fromRGB

-- Plumage
local RED = rgb(206, 26, 32)
local RED_BRIGHT = rgb(228, 42, 38)
local RED_DEEP = rgb(170, 16, 26)
local RED_SCALE = rgb(182, 20, 28)
local YELLOW = rgb(255, 204, 28)
local YELLOW_DEEP = rgb(240, 172, 20)
local GREEN = rgb(64, 156, 78)
local BLUE = rgb(34, 92, 206)
local BLUE_ALT = rgb(28, 80, 186)
local BLUE_SKY = rgb(86, 156, 228)
local BLUE_DEEP = rgb(26, 58, 170)
local NAVY = rgb(20, 34, 108)
local GOLD_UNDER = rgb(186, 146, 44)
-- Bare parts
local FACE = rgb(246, 242, 236)
local EYELID = rgb(236, 228, 222)
local IRIS = rgb(250, 226, 118)
local PUPIL = rgb(16, 14, 14)
local HORN = rgb(238, 228, 204)
local HORN_SHADE = rgb(212, 200, 176)
local BEAK_DARK = rgb(34, 32, 32)
local TONGUE = rgb(72, 60, 66)
local FOOT = rgb(96, 94, 100)
local NAIL = rgb(30, 28, 30)

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- 0..1, the same for the same seed and n on every client
local function noise(seed: number, n: number): number
	local x = math.sin(seed * 127.1 + n * 311.7) * 43758.5453
	return x - math.floor(x)
end

-- A local CFrame in unit (scale 1) pet space
local function C(x: number, y: number, z: number, ax: number?, ay: number?, az: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(ax or 0, ay or 0, az or 0)
end

-- A frame on the front (-Z) of the ellipsoid at e with the given size, at normalised (u, v)
-- across it, facing out along the surface normal and lifted off it by lift.
local function onEgg(e: CFrame, size: Vector3, u: number, v: number, lift: number): CFrame
	local a, b, c = size.X / 2, size.Y / 2, size.Z / 2
	local w = math.sqrt(math.max(0, 1 - u * u - v * v))
	local p = Vector3.new(u * a, v * b, -w * c)
	local n = Vector3.new(p.X / (a * a), p.Y / (b * b), p.Z / (c * c)).Unit
	local at = p + n * lift
	return e * CFrame.lookAt(at, at + n, Vector3.yAxis)
end

----------------------------------------------------------------------------------------------------
-- Scarlet macaw

function PetModels.scarletMacaw(parent: Instance, frame: CFrame, scale: number?): Model
	local S = scale or 1
	local model = Instance.new("Model")
	model.Name = "ScarletMacaw"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local function at(c: CFrame): CFrame
		return frame * (CFrame.new(c.Position * S) * c.Rotation)
	end
	local function base(holder: Instance, name: string, size: Vector3, c: CFrame, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size * S
		p.CFrame = at(c)
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = math.max(size.X, size.Y, size.Z) > 0.3
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = holder
		return p
	end
	-- An ellipsoid filling its size
	local function egg(holder: Instance, name: string, size: Vector3, c: CFrame, color: Color3): Part
		local p = base(holder, name, size, c, color)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		return p
	end
	local function ball(holder: Instance, name: string, d: number, c: CFrame, color: Color3): Part
		local p = base(holder, name, Vector3.new(d, d, d), c, color)
		p.Shape = Enum.PartType.Ball
		return p
	end
	local function rod(holder: Instance, name: string, length: number, d: number, c: CFrame, color: Color3): Part
		local p = base(holder, name, Vector3.new(length, d, d), c, color)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	local order = 0
	local function group(name: string, jointParent: string, joint: Vector3): Model
		order += 1
		local g = Instance.new("Model")
		g.Name = name
		g:SetAttribute("Joint", CFrame.new(joint * S))
		g:SetAttribute("JointParent", jointParent)
		g:SetAttribute("JointOrder", order)
		g.Parent = model
		return g
	end

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2) * S
	root.CFrame = frame
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.Parent = model
	model.PrimaryPart = root

	-- Legs and zygodactyl feet, two toes forward and two back, curled round the perch. They
	-- never move, so they sit outside the joint groups.
	local legs = Instance.new("Model")
	legs.Name = "Legs"
	legs.Parent = model
	local R = PetModels.PERCH_RADIUS + 0.025
	local barY = -PetModels.PERCH_RADIUS
	for _, s in { -1, 1 } do
		rod(legs, "Tarsus", 0.24, 0.08, C(s * 0.12, 0.13, 0, 0, 0, math.pi / 2), FOOT)
		for _, toe in { { -0.035, -1 }, { 0.035, -1 }, { -0.03, 1 }, { 0.03, 1 } } do
			local x, dir = s * 0.12 + toe[1], toe[2]
			for k, theta in { math.rad(22), math.rad(68) } do
				local y, z = barY + R * math.cos(theta), dir * R * math.sin(theta)
				egg(legs, "Toe", Vector3.new(0.05, 0.05, if k == 1 then 0.13 else 0.1), C(x, y, z, dir * theta, 0, 0), FOOT)
			end
			local nail = math.rad(108)
			ball(legs, "Claw", 0.035, C(x, barY + R * math.cos(nail), dir * R * math.sin(nail)), NAIL)
		end
	end

	-- Body: torso, chest, mantle, feathered thighs and the sky-blue rump
	local body = group("Body", "", Vector3.new(0, 0.3, 0.05))
	local bellyFrame, bellySize = C(0, 0.72, 0.02, -0.35, 0, 0), Vector3.new(0.72, 1, 0.7)
	egg(body, "Belly", bellySize, bellyFrame, RED)
	egg(body, "Chest", Vector3.new(0.62, 0.62, 0.55), C(0, 0.98, -0.12, -0.3, 0, 0), RED_BRIGHT)
	local mantleFrame, mantleSize = C(0, 0.86, 0.16, -0.45, 0, 0), Vector3.new(0.66, 0.86, 0.5)
	egg(body, "Mantle", mantleSize, mantleFrame, RED_DEEP)
	egg(body, "Neck", Vector3.new(0.48, 0.44, 0.46), C(0, 1.2, -0.12, -0.2, 0, 0), RED)
	for _, s in { -1, 1 } do
		egg(body, "Thigh", Vector3.new(0.24, 0.3, 0.28), C(s * 0.15, 0.32, 0.02), RED_DEEP)
	end
	egg(body, "Rump", Vector3.new(0.38, 0.4, 0.3), C(0, 0.38, 0.3, -0.6, 0, 0), BLUE_SKY)
	-- Rows of scalloped breast feathers, and a few on the mantle
	for row, v in { 0.42, 0.16, -0.1, -0.36 } do
		local us = if row % 2 == 1 then { -0.42, 0, 0.42 } else { -0.22, 0.22 }
		for _, u in us do
			egg(body, "BreastFeather", Vector3.new(0.17, 0.12, 0.05), bellyFrame * onEgg(CFrame.new(), bellySize, u, v, 0.005), RED_SCALE)
		end
	end
	local back = mantleFrame * CFrame.Angles(0, math.pi, 0)
	for _, uv in { { -0.3, 0.3 }, { 0.3, 0.3 }, { 0, 0.05 }, { -0.3, -0.2 }, { 0.3, -0.2 } } do
		egg(body, "MantleFeather", Vector3.new(0.18, 0.13, 0.05), back * onEgg(CFrame.new(), mantleSize, uv[1], uv[2], 0.005), RED_SCALE)
	end

	-- Head: skull, crown and nape in reds, bare white face, yellow eyes and the hooked beak
	local headJoint = Vector3.new(0, 1.2, -0.1)
	local head = group("Head", "Body", headJoint)
	egg(head, "Skull", Vector3.new(0.54, 0.52, 0.58), C(0, 1.44, -0.16), RED_BRIGHT)
	egg(head, "Crown", Vector3.new(0.42, 0.24, 0.42), C(0, 1.63, -0.14), RED_BRIGHT)
	egg(head, "Nape", Vector3.new(0.46, 0.42, 0.4), C(0, 1.36, 0.02, -0.25, 0, 0), RED)
	for _, s in { -1, 1 } do
		egg(head, "FacePatch", Vector3.new(0.08, 0.3, 0.34), C(s * 0.235, 1.39, -0.3, 0, s * 0.35, 0), FACE)
		-- Faint lines of tiny red feathers across the bare cheek
		for i, y in { 1.33, 1.38, 1.43 } do
			base(head, "FaceLine", Vector3.new(0.02, 0.018, 0.13 - i * 0.015), C(s * 0.277, y, -0.33, 0, s * 0.35, 0), RED_DEEP)
		end
		ball(head, "Iris", 0.11, C(s * 0.255, 1.48, -0.25), IRIS)
		ball(head, "Pupil", 0.056, C(s * 0.29, 1.48, -0.255), PUPIL)
		ball(head, "EyeShine", 0.022, C(s * 0.315, 1.495, -0.265), FACE)
		-- Shown only while blinking (ShowcasePets)
		local lid = egg(head, "Eyelid", Vector3.new(0.065, 0.15, 0.15), C(s * 0.29, 1.48, -0.25, 0, s * 0.3, 0), EYELID)
		lid.Transparency = 1
	end
	-- Upper mandible: a pale horn hook built down an arc, black along its cutting edge
	egg(head, "Cere", Vector3.new(0.27, 0.26, 0.2), C(0, 1.42, -0.42), HORN_SHADE)
	egg(head, "Beak", Vector3.new(0.25, 0.21, 0.22), C(0, 1.43, -0.51, 0.3, 0, 0), HORN)
	egg(head, "Beak", Vector3.new(0.21, 0.2, 0.18), C(0, 1.37, -0.6, 0.7, 0, 0), HORN)
	egg(head, "Beak", Vector3.new(0.16, 0.18, 0.14), C(0, 1.28, -0.635, 1.2, 0, 0), HORN)
	egg(head, "Beak", Vector3.new(0.11, 0.14, 0.1), C(0, 1.19, -0.61, 1.7, 0, 0), HORN_SHADE)
	egg(head, "BeakTip", Vector3.new(0.065, 0.1, 0.07), C(0, 1.12, -0.56, 2.1, 0, 0), BEAK_DARK)
	egg(head, "BeakEdge", Vector3.new(0.27, 0.06, 0.17), C(0, 1.33, -0.47, 0.15, 0, 0), BEAK_DARK)
	-- Lower mandible on its own hinge, for squawks
	local jaw = group("Jaw", "Head", Vector3.new(0, 1.33, -0.4))
	egg(jaw, "LowerBeak", Vector3.new(0.22, 0.15, 0.22), C(0, 1.25, -0.49, -0.2, 0, 0), BEAK_DARK)
	egg(jaw, "Tongue", Vector3.new(0.1, 0.05, 0.1), C(0, 1.3, -0.5), TONGUE)

	-- Wings: red lesser coverts, the yellow band with green tips, blue flight feathers lined with
	-- gold underneath. The primaries hang from the wrist on a joint of their own.
	local function feather(holder: Instance, f: CFrame, width: number, length: number, color: Color3, tip: Color3?)
		egg(holder, "Feather", Vector3.new(0.045, length, width), f * C(0, -length / 2, 0), color)
		if tip then
			egg(holder, "FeatherTip", Vector3.new(0.047, 0.24, width - 0.01), f * C(0, -length + 0.13, 0), tip)
		end
	end
	for _, s in { -1, 1 } do
		local side = if s < 0 then "L" else "R"
		local shoulder = Vector3.new(s * 0.33, 1.04, 0.02)
		local wing = group("Wing" .. side, "Body", shoulder)
		-- Folded along the body: the wing's -Y runs down and back
		local W = CFrame.new(shoulder) * CFrame.Angles(-0.42, 0, 0)
		egg(wing, "Scapulars", Vector3.new(0.1, 0.3, 0.3), W * C(s * 0.05, -0.05, 0.08), RED_DEEP)
		egg(wing, "LesserCoverts", Vector3.new(0.16, 0.55, 0.44), W * C(s * 0.06, -0.2, 0), RED)
		egg(wing, "MedianCoverts", Vector3.new(0.12, 0.34, 0.42), W * C(s * 0.08, -0.47, 0.02), YELLOW)
		egg(wing, "GreaterCoverts", Vector3.new(0.1, 0.24, 0.4), W * C(s * 0.095, -0.62, 0.04), YELLOW_DEEP)
		for _, z in { -0.08, 0.04, 0.16 } do
			egg(wing, "GreenTip", Vector3.new(0.07, 0.12, 0.13), W * C(s * 0.105, -0.72, z), GREEN)
		end
		egg(wing, "SecondaryLining", Vector3.new(0.03, 0.62, 0.38), W * C(s * 0.045, -0.86, 0.08), GOLD_UNDER)
		for i = 0, 3 do
			local f = W * C(s * 0.075, -0.58 - i * 0.02, -0.06 + i * 0.09, -0.03 * i, 0, 0)
			feather(wing, f, 0.13, 0.62, if i % 2 == 0 then BLUE else BLUE_ALT, NAVY)
		end
		local wristAt = (W * CFrame.new(s * 0.07, -0.6, -0.12)).Position
		local tip = group("WingTip" .. side, "Wing" .. side, wristAt)
		egg(tip, "PrimaryLining", Vector3.new(0.025, 0.72, 0.2), W * C(s * 0.04, -0.95, -0.06), GOLD_UNDER)
		for i = 0, 4 do
			local f = W * C(s * 0.065, -0.56, -0.14 + i * 0.055, 0.02 * i, 0, 0)
			feather(tip, f, 0.12, 0.98 - i * 0.08, BLUE_DEEP, NAVY)
		end
	end

	-- Tail: blue coverts over long red central feathers that turn blue at the tips, shorter and
	-- bluer towards the sides, hanging below the perch
	local tailJoint = Vector3.new(0, 0.36, 0.3)
	local tail = group("Tail", "Body", tailJoint)
	local T = CFrame.new(tailJoint) * CFrame.Angles(-0.32, 0, 0)
	egg(tail, "Undertail", Vector3.new(0.26, 0.34, 0.14), T * C(0, -0.15, -0.05), RED_DEEP)
	for _, spec in { { 0.18, 1.05, 0.35, 0.11, 0.1, 0.005 }, { 0.12, 1.45, 0.6, 0.06, 0.11, 0.02 }, { 0.045, 1.9, 0.78, 0.015, 0.12, 0.035 } } do
		local x, length, redShare, fan, width, z = table.unpack(spec)
		for _, s in { -1, 1 } do
			local f = T * C(s * x, -0.05, z, 0, 0, s * fan)
			local redLength = length * redShare
			egg(tail, "TailFeather", Vector3.new(width, redLength + 0.1, 0.045), f * C(0, -redLength / 2, 0), RED)
			local blueLength = length - redLength
			egg(tail, "TailTip", Vector3.new(width - 0.01, blueLength + 0.12, 0.045), f * C(0, -redLength - blueLength / 2 + 0.04, 0.004), BLUE)
		end
	end
	egg(tail, "TailCoverts", Vector3.new(0.32, 0.42, 0.16), T * C(0, -0.12, 0.07), BLUE_SKY)

	local count = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	model:SetAttribute("PartCount", count)
	model:SetAttribute("Scale", S)
	model:SetAttribute("Pet", "ScarletMacaw")
	model:AddTag(PetModels.TAG)
	model.Parent = parent
	return model
end

----------------------------------------------------------------------------------------------------
-- Animation (client)

type RigGroup = {
	name: string,
	parent: number,
	rel: CFrame,
	first: number,
	offsets: { CFrame },
}
type Event = { next: number, start: number, n: number }
export type Rig = {
	model: Model,
	root: BasePart,
	scale: number,
	seed: number,
	groups: { RigGroup },
	parts: { BasePart },
	cframes: { CFrame },
	worlds: { CFrame },
	lids: { BasePart },
	lidsClosed: boolean,
	look: { from: Vector3, to: Vector3, start: number, next: number, n: number },
	events: { [string]: Event },
}

-- Seconds between starts (lo, hi), how long each lasts, and when the first comes after the
-- pet appears
local BEHAVIOURS = {
	blink = { 1.8, 4.8, 0.13, 0.6 },
	flap = { 8, 14, 2, 4 },
	dance = { 11, 19, 2.6, 7.5 },
	squawk = { 6, 13, 0.7, 2.5 },
}

-- Reads a pet's rest pose. Nil until every part has arrived (Atomic streaming sends them
-- together, but the tag can replicate a moment ahead).
function PetModels.rig(model: Model, now: number): Rig?
	local root = model:FindFirstChild("Root")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local groups = {}
	local count = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	if count ~= model:GetAttribute("PartCount") then
		return nil
	end
	for _, child in model:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("Joint") then
			table.insert(groups, child)
		end
	end
	table.sort(groups, function(a, b)
		return (a:GetAttribute("JointOrder") :: number) < (b:GetAttribute("JointOrder") :: number)
	end)
	local rootFrame = root.CFrame
	local seed = rootFrame.Position.X * 0.13 + rootFrame.Position.Z * 0.071
	local rig: Rig = {
		model = model,
		root = root,
		scale = model:GetAttribute("Scale") or 1,
		seed = seed - math.floor(seed),
		groups = {},
		parts = {},
		cframes = {},
		worlds = {},
		lids = {},
		lidsClosed = false,
		look = { from = Vector3.zero, to = Vector3.zero, start = now, next = now + 0.8, n = 0 },
		events = {},
	}
	local index: { [string]: number } = {}
	local joints: { CFrame } = {}
	for i, g in groups do
		local joint = g:GetAttribute("Joint") :: CFrame
		local parent = index[g:GetAttribute("JointParent") :: string] or 0
		local world = rootFrame * joint
		local entry: RigGroup = {
			name = g.Name,
			parent = parent,
			rel = if parent > 0 then joints[parent]:Inverse() * joint else joint,
			first = #rig.parts + 1,
			offsets = {},
		}
		for _, d in g:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(rig.parts, d)
				table.insert(rig.cframes, d.CFrame)
				table.insert(entry.offsets, world:Inverse() * d.CFrame)
				if d.Name == "Eyelid" then
					table.insert(rig.lids, d)
				end
			end
		end
		index[g.Name] = i
		joints[i] = joint
		rig.groups[i] = entry
	end
	for name, spec in BEHAVIOURS do
		rig.events[name] = { next = now + spec[4], start = -math.huge, n = 0 }
	end
	return rig
end

-- The folded wing's length, shoulder to tip (its -Y tilted back by the 0.42 rad of the build)
local WING_LENGTH = Vector3.new(0, -math.cos(0.42), math.sin(0.42))

-- 0..1: how far into the behaviour's current run, ramped in and out
local function envelope(rig: Rig, name: string, t: number, rampIn: number, rampOut: number): (number, number)
	local event = rig.events[name]
	local spec = BEHAVIOURS[name]
	if t >= event.next then
		event.n += 1
		event.start = t
		event.next = t + spec[1] + (spec[2] - spec[1]) * noise(rig.seed, event.n * 7 + #name)
	end
	local e = t - event.start
	if e > spec[3] then
		-- Idle: an age of 0 keeps sin(age) finite before the first run (start is -inf)
		return 0, 0
	end
	return math.min(smooth(e / rampIn), smooth((spec[3] - e) / rampOut)), e
end

-- Poses the pet for time t. Returns its moving parts and their new CFrames, for
-- workspace:BulkMoveTo.
function PetModels.step(rig: Rig, t: number): ({ BasePart }, { CFrame })
	local S = rig.scale
	local TAU = math.pi * 2
	-- Blinks, sometimes twice in quick succession
	local blinks = rig.events.blink
	if t >= blinks.next then
		blinks.n += 1
		blinks.start = t
		local gap = BEHAVIOURS.blink
		blinks.next = if noise(rig.seed, blinks.n * 3) > 0.78 then t + 0.28 else t + gap[1] + (gap[2] - gap[1]) * noise(rig.seed, blinks.n * 5)
	end
	local closed = t - blinks.start < BEHAVIOURS.blink[3]
	if closed ~= rig.lidsClosed then
		rig.lidsClosed = closed
		for _, lid in rig.lids do
			lid.Transparency = if closed then 0 else 1
		end
	end

	local flap, flapAge = envelope(rig, "flap", t, 0.3, 0.4)
	local dance, danceAge = envelope(rig, "dance", t, 0.35, 0.35)
	local squawk, squawkAge = envelope(rig, "squawk", t, 0.08, 0.25)
	-- Wing beats while flapping, head bobs while dancing
	local beat = math.sin(flapAge * TAU * 4.2)
	local bob = dance * math.max(0, math.sin(danceAge * TAU * 2.1))
	local sway = dance * math.sin(danceAge * TAU * 1.05)
	local breathe = math.sin(t * TAU * 0.45)

	-- Parrots glance in quick snaps, then hold: a new look every second or few, with a curious
	-- head tilt now and then
	local look = rig.look
	if t >= look.next then
		look.n += 1
		local n = look.n * 11
		local current = look.from:Lerp(look.to, smooth((t - look.start) / 0.22))
		local tilt = if noise(rig.seed, n + 3) > 0.62 then (noise(rig.seed, n + 4) - 0.5) * 0.95 else 0
		look.from = current
		look.to = Vector3.new((noise(rig.seed, n + 1) - 0.5) * 0.5, (noise(rig.seed, n + 2) - 0.5) * 1.8, tilt)
		look.start = t
		look.next = t + 1 + 2.6 * noise(rig.seed, n + 5)
	end
	local gaze = look.from:Lerp(look.to, smooth((t - look.start) / 0.22))

	local poses: { [string]: CFrame } = {
		Body = CFrame.new(0, (0.012 * breathe + 0.04 * bob + 0.03 * flap * (beat * 0.5 + 0.5)) * S, 0)
			* CFrame.Angles(-0.13 * flap - 0.06 * bob, 0, 0.06 * sway),
		Head = CFrame.new(0, -0.03 * bob * S, -0.07 * bob * S)
			* CFrame.Angles(0, gaze.Y * (1 - dance), 0)
			* CFrame.Angles(gaze.X - 0.3 * bob + 0.22 * squawk + 0.12 * flap, 0, gaze.Z * (1 - flap) - 0.08 * sway),
		Jaw = CFrame.Angles(-0.4 * squawk * (0.75 + 0.25 * math.sin(squawkAge * TAU * 9)) - 0.06 * flap, 0, 0),
		Tail = CFrame.Angles(-0.32 * flap * (0.6 + 0.4 * beat) - 0.1 * bob + 0.015 * breathe, 0, 0.05 * math.sin(t * TAU * 0.3) - 0.12 * sway),
	}
	-- Spread wings roll out and up, beating, and twist about their length so the broad, gold-lined
	-- underside turns forward the way a parrot stretches on its perch
	local roll = flap * (1.35 + 0.65 * beat) + 0.07 * bob
	local twist = flap * (0.95 + 0.2 * beat)
	local whip = flap * (0.3 + 0.25 * math.sin(flapAge * TAU * 4.2 - 0.7))
	for _, s in { -1, 1 } do
		local side = if s < 0 then "L" else "R"
		poses["Wing" .. side] = CFrame.new(0, 0.03 * flap * S, 0)
			* CFrame.Angles(0, s * 0.45 * flap, 0)
			* CFrame.Angles(0, 0, s * roll)
			* CFrame.fromAxisAngle(WING_LENGTH, s * twist)
		poses["WingTip" .. side] = CFrame.Angles(0, 0, s * whip)
	end

	local rootFrame = rig.root.CFrame
	local worlds = rig.worlds
	for i, g in rig.groups do
		local parentWorld = if g.parent > 0 then worlds[g.parent] else rootFrame
		local world = parentWorld * g.rel * (poses[g.name] or CFrame.identity)
		worlds[i] = world
		for k, offset in g.offsets do
			rig.cframes[g.first + k - 1] = world * offset
		end
	end
	return rig.parts, rig.cframes
end

return PetModels
