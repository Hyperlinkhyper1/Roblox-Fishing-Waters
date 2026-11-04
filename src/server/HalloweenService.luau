-- The Halloween party across Harbour Isle. On 31 October (in-game) the server puts up the
-- decorations, turns every street lamp on the island orange, and gathers locals around town
-- in Roblox's own avatar bundles and Halloween accessories. Everything comes down again once the
-- midnight fireworks (drawn by each client, see src/client/HalloweenParty.luau) are over.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Calendar = require(ReplicatedStorage.Shared.Calendar)
local Halloween = require(ReplicatedStorage.Shared.Halloween)
local Props = require(script.Parent.Map.Props)
local PlazaHouses = require(script.Parent.Map.PlazaHouses)

local Service = {}
local started = false

local GUEST_TAG = "HalloweenGuest"
local BOB_TAG = "HalloweenBob"
local PROMPT = "HalloweenGuestPrompt"
local IDLE_ANIMATION = "rbxassetid://507766388" -- Roblox's stock R15 idle
local DANCES = { "rbxassetid://507771019", "rbxassetid://507776043", "rbxassetid://507777268" } -- stock R15 dances
local DANCER_SHARE = 0.3

local rgb = Color3.fromRGB
local M = Enum.Material
local part, beam, cylinder = Props.part, Props.beam, Props.cylinder
local ORANGE = rgb(232, 118, 26)
local ORANGE_DARK = rgb(196, 90, 18)
local GLOW = rgb(255, 160, 40)
local PURPLE = rgb(130, 60, 200)
local BLACK = rgb(28, 24, 30)
local STEM = rgb(92, 112, 44)
local HAY = rgb(214, 182, 96)
local STONE = rgb(128, 126, 132)
local GHOST = rgb(240, 244, 255)
local SKIN = Color3.fromRGB(224, 173, 132)

-- The party's folder while it is up, and a counter that tells slow guest builds it was torn down.
local party: Folder?
local generation = 0
-- Original colours of the lamps turned orange, restored afterwards.
local tinted: { [Instance]: { any } } = {}

local function homePlaza(): (Model?, CFrame?)
	local map = workspace:FindFirstChild("Map")
	if not map then
		return nil, nil
	end
	for _, plaza in map:GetDescendants() do
		-- Other islands have piazzas too; the harbour's is the one with the Drydock.
		if plaza:IsA("Model") and plaza.Name == "Plaza" and plaza:FindFirstChild("Drydock") then
			local frame = PlazaHouses.pavingFrame(plaza)
			if frame then
				return plaza, frame
			end
		end
	end
	return nil, nil
end

local function exclusions(): { Instance }
	local list: { Instance } = {}
	if party then
		table.insert(list, party)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

-- Ground under a spot, if it is open paving with `clearance` studs of room and nothing overhead.
local function openGround(position: Vector3, clearance: number): Vector3?
	local ignore = exclusions()
	local rays = RaycastParams.new()
	rays.FilterType = Enum.RaycastFilterType.Exclude
	rays.FilterDescendantsInstances = ignore
	rays.RespectCanCollide = true
	local hit = workspace:Raycast(position + Vector3.new(0, 12, 0), Vector3.new(0, -20, 0), rays)
	if not hit or math.abs(hit.Position.Y - position.Y) > 2.5 then
		return nil
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = ignore
	overlap.RespectCanCollide = true
	local box = CFrame.new(hit.Position + Vector3.new(0, 3.4, 0))
	if #workspace:GetPartBoundsInBox(box, Vector3.new(clearance, 4.6, clearance), overlap) > 0 then
		return nil
	end
	return hit.Position
end

-- Picks open spots on the square, `spacing` studs from each other and from anything already taken.
local function spotsOnPlaza(
	frame: CFrame,
	rng: Random,
	count: number,
	inner: number,
	outer: number,
	clearance: number,
	spacing: number,
	taken: { Vector3 }
): { Vector3 }
	local found = {}
	for _ = 1, count * 30 do
		if #found >= count then
			break
		end
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(inner, outer)
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		if math.abs(x) > 54 or math.abs(z) > 54 then
			continue
		end
		local candidate = frame * Vector3.new(x, 0, z)
		local crowded = false
		for _, other in taken do
			if (Vector3.new(other.X, candidate.Y, other.Z) - candidate).Magnitude < spacing then
				crowded = true
				break
			end
		end
		local ground = not crowded and openGround(candidate, clearance)
		if ground then
			table.insert(found, ground)
			table.insert(taken, ground)
		end
	end
	return found
end

local function quiet(model: Instance)
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.CanCollide, piece.CanTouch, piece.CanQuery = false, false, false
		end
	end
end

local function sphere(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = part(parent, size, cframe, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- A carved, lit jack-o'-lantern standing on `ground`, its face towards the frame's look vector.
local function jackOLantern(parent: Instance, ground: CFrame, size: number): Model
	local m = Instance.new("Model")
	m.Name = "JackOLantern"
	local w, h = size * 1.2, size * 0.92
	local center = ground * CFrame.new(0, h / 2, 0)
	sphere(m, Vector3.new(w, h, w * 0.86), center, ORANGE)
	sphere(m, Vector3.new(w * 0.72, h * 0.98, w), center, ORANGE_DARK)
	cylinder(m, (center * CFrame.new(0, h / 2 + size * 0.1, 0)).Position, size * 0.28, size * 0.16, STEM, M.Wood)
	local front = -w * 0.86 / 2 + size * 0.02
	for _, side in { -1, 1 } do
		part(
			m,
			Vector3.new(size * 0.2, size * 0.2, size * 0.08),
			center * CFrame.new(side * size * 0.24, size * 0.12, front) * CFrame.Angles(0, 0, math.rad(45)),
			GLOW,
			M.Neon
		)
	end
	part(
		m,
		Vector3.new(size * 0.56, size * 0.12, size * 0.08),
		center * CFrame.new(0, -size * 0.16, front),
		GLOW,
		M.Neon
	)
	part(
		m,
		Vector3.new(size * 0.1, size * 0.08, size * 0.08),
		center * CFrame.new(-size * 0.12, -size * 0.07, front),
		GLOW,
		M.Neon
	)
	part(
		m,
		Vector3.new(size * 0.1, size * 0.08, size * 0.08),
		center * CFrame.new(size * 0.12, -size * 0.07, front),
		GLOW,
		M.Neon
	)
	local core = part(m, Vector3.new(0.2, 0.2, 0.2), center, GLOW, M.Neon)
	core.Transparency = 1
	Props.light(core, GLOW, 8 + size * 3, 1.4)
	quiet(m)
	m.Parent = parent
	return m
end

local function facing(position: Vector3, target: Vector3): CFrame
	local flat = Vector3.new(target.X, position.Y, target.Z)
	if (flat - position).Magnitude < 0.1 then
		return CFrame.new(position)
	end
	return CFrame.lookAt(position, flat)
end

-- A sagging string of orange and purple bulbs with black pennants between `a` and `b`.
local function garland(parent: Instance, a: Vector3, b: Vector3)
	local m = Instance.new("Model")
	m.Name = "Garland"
	local span = (b - a).Magnitude
	local count = math.max(4, math.floor(span / 2.2))
	local sag = span * 0.08
	local last = a
	for index = 1, count do
		local t = index / count
		local point = a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
		beam(m, last, point, 0.12, BLACK)
		if index < count then
			local bulb = sphere(
				m,
				Vector3.new(0.55, 0.7, 0.55),
				CFrame.new(point - Vector3.new(0, 0.4, 0)),
				if index % 2 == 0 then GLOW else PURPLE,
				M.Neon
			)
			if index % 4 == 0 then
				Props.light(bulb, GLOW, 7, 0.6)
			end
			if index % 2 == 1 then
				local flag = part(
					m,
					Vector3.new(0.9, 1.1, 0.06),
					CFrame.lookAt(point, point + (b - a)) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(0, -0.7, 0),
					if index % 4 == 1 then BLACK else ORANGE
				)
				flag.Name = "Pennant"
			end
		end
		last = point
	end
	quiet(m)
	m.Parent = parent
end

local function pole(parent: Instance, ground: Vector3, height: number): Vector3
	local m = Instance.new("Model")
	m.Name = "GarlandPole"
	part(m, Vector3.new(1.2, 0.6, 1.2), CFrame.new(ground + Vector3.new(0, 0.3, 0)), BLACK, M.Metal)
	cylinder(m, ground + Vector3.new(0, height / 2, 0), height, 0.45, BLACK, M.Metal)
	quiet(m)
	m.Parent = parent
	jackOLantern(parent, CFrame.new(ground + Vector3.new(0, height, 0)), 1.4)
	return ground + Vector3.new(0, height - 0.3, 0)
end

local function hayBale(parent: Instance, ground: CFrame, rng: Random)
	local m = Instance.new("Model")
	m.Name = "HayBale"
	part(m, Vector3.new(4.2, 2.2, 2.6), ground * CFrame.new(0, 1.1, 0), HAY, M.Fabric)
	for _, x in { -1.2, 1.2 } do
		part(m, Vector3.new(0.15, 2.25, 2.65), ground * CFrame.new(x, 1.1, 0), rgb(150, 110, 60), M.Fabric)
	end
	quiet(m)
	m.Parent = parent
	jackOLantern(parent, ground * CFrame.new(-0.9, 2.2, 0), 1.6)
	jackOLantern(parent, ground * CFrame.new(1.1, 2.2, 0.2) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), 1.1)
	jackOLantern(parent, ground * CFrame.new(2.9, 0, -0.6), 1.3)
end

local function tombstones(parent: Instance, ground: CFrame, rng: Random)
	local m = Instance.new("Model")
	m.Name = "Tombstones"
	for index = 1, 4 do
		local at = ground
			* CFrame.new((index - 2.5) * 2.4, 0, rng:NextNumber(-0.6, 0.6))
			* CFrame.Angles(0, 0, rng:NextNumber(-0.12, 0.12))
		local height = rng:NextNumber(2.2, 3.2)
		part(m, Vector3.new(1.8, height, 0.45), at * CFrame.new(0, height / 2, 0), STONE, M.Slate)
		local cap = part(
			m,
			Vector3.new(0.45, 1.8, 1.8),
			at * CFrame.new(0, height, 0) * CFrame.Angles(0, math.pi / 2, 0),
			STONE,
			M.Slate
		)
		cap.Shape = Enum.PartType.Cylinder
		part(m, Vector3.new(0.8, 0.14, 0.05), at * CFrame.new(0, height * 0.72, -0.25), BLACK)
		part(m, Vector3.new(0.14, 0.8, 0.05), at * CFrame.new(0, height * 0.72, -0.25), BLACK)
		part(m, Vector3.new(1.9, 0.25, 2.8), at * CFrame.new(0, 0.12, -1.5), rgb(84, 62, 44), M.Ground)
	end
	quiet(m)
	m.Parent = parent
end

local function cauldron(parent: Instance, ground: CFrame)
	local m = Instance.new("Model")
	m.Name = "Cauldron"
	for index = 0, 2 do
		local angle = index * math.pi * 2 / 3
		local foot = ground * CFrame.new(math.cos(angle) * 1.3, 0, math.sin(angle) * 1.3)
		beam(m, foot.Position, (ground * CFrame.new(0, 1.2, 0)).Position, 0.25, BLACK, nil, M.Metal)
	end
	sphere(m, Vector3.new(3.2, 2.6, 3.2), ground * CFrame.new(0, 1.9, 0), BLACK, M.Metal)
	local brew = cylinder(m, (ground * CFrame.new(0, 2.9, 0)).Position, 0.2, 2.5, rgb(110, 230, 60), M.Neon)
	Props.light(brew, rgb(120, 255, 80), 12, 1.2)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Color = ColorSequence.new(rgb(150, 255, 110), rgb(90, 70, 130))
	smoke.LightEmission = 0.4
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.2) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(1.5, 2.5)
	smoke.Rate = 10
	smoke.Speed = NumberRange.new(1.5, 3)
	smoke.SpreadAngle = Vector2.new(15, 15)
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Parent = brew
	quiet(m)
	m.Parent = parent
end

local function scarecrow(parent: Instance, ground: CFrame)
	local m = Instance.new("Model")
	m.Name = "Scarecrow"
	local wood = rgb(110, 80, 50)
	part(m, Vector3.new(0.4, 7, 0.4), ground * CFrame.new(0, 3.5, 0), wood, M.Wood)
	part(m, Vector3.new(5, 0.35, 0.35), ground * CFrame.new(0, 5, 0), wood, M.Wood)
	part(m, Vector3.new(2.2, 2.6, 1), ground * CFrame.new(0, 4.4, 0), rgb(150, 60, 40), M.Fabric)
	part(m, Vector3.new(4.6, 0.7, 0.7), ground * CFrame.new(0, 5, 0), rgb(150, 60, 40), M.Fabric)
	m.Parent = parent
	jackOLantern(parent, ground * CFrame.new(0, 6, 0), 1.7)
	-- A battered witch's hat: wide brim, tapering crown.
	cylinder(m, (ground * CFrame.new(0, 7.75, 0)).Position, 0.15, 3.2, BLACK, M.Fabric)
	cylinder(m, (ground * CFrame.new(0, 8.4, 0)).Position, 1.2, 1.5, BLACK, M.Fabric)
	cylinder(m, (ground * CFrame.new(0.15, 9.3, 0)).Position, 0.9, 0.9, BLACK, M.Fabric)
	cylinder(m, (ground * CFrame.new(0.35, 9.95, 0)).Position, 0.6, 0.4, BLACK, M.Fabric)
	quiet(m)
end

-- A sheet ghost floating at `position`; clients bob it up and down.
local function ghost(parent: Instance, position: Vector3, rng: Random)
	local m = Instance.new("Model")
	m.Name = "Ghost"
	local body = sphere(m, Vector3.new(2.6, 3.6, 2.6), CFrame.new(position), GHOST, M.SmoothPlastic)
	body.Transparency = 0.25
	local skirt = cylinder(m, position - Vector3.new(0, 1.5, 0), 1.6, 2.7, GHOST, M.SmoothPlastic)
	skirt.Transparency = 0.25
	local look = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	for _, side in { -1, 1 } do
		part(m, Vector3.new(0.35, 0.55, 0.1), look * CFrame.new(side * 0.45, 0.5, -1.25), BLACK)
	end
	part(m, Vector3.new(0.45, 0.45, 0.1), look * CFrame.new(0, -0.15, -1.28), BLACK)
	Props.light(body, rgb(200, 220, 255), 10, 0.8)
	quiet(m)
	m.PrimaryPart = body
	m:SetAttribute("BobPhase", rng:NextNumber(0, math.pi * 2))
	m.Parent = parent
	m:AddTag(BOB_TAG)
end

-- Every street lamp glows orange; occasional pumpkins mark the streets.
local function decorateTown(island: Instance, folder: Instance, rng: Random)
	for _, lamp in island:GetDescendants() do
		if not (lamp:IsA("Model") and lamp.Name == "LampPost") then
			continue
		end
		for _, piece in lamp:GetChildren() do
			if piece:IsA("BasePart") and piece.Material == M.Neon then
				local light = piece:FindFirstChildOfClass("PointLight")
				tinted[piece] = { piece.Color, light, light and light.Color }
				piece.Color = GLOW
				if light then
					light.Color = GLOW
				end
			end
		end
		local base = lamp:FindFirstChildWhichIsA("BasePart")
		if base and rng:NextNumber() < 0.35 then
			local foot = base.Position - Vector3.new(0, base.Size.Y / 2, 0)
			local angle = rng:NextNumber(0, math.pi * 2)
			local at = foot + Vector3.new(math.cos(angle) * 1.4, 0, math.sin(angle) * 1.4)
			jackOLantern(folder, CFrame.new(at) * CFrame.Angles(0, -angle - math.pi / 2, 0), rng:NextNumber(1, 1.4))
		end
	end
end

local function restoreTown()
	for piece, original in tinted do
		if piece.Parent then
			(piece :: BasePart).Color = original[1]
			local light = original[2]
			if light and light.Parent then
				light.Color = original[3]
			end
		end
	end
	table.clear(tinted)
end

local function decoratePlaza(folder: Instance, frame: CFrame, rng: Random, taken: { Vector3 })
	local center = frame.Position
	-- Jack-o'-lanterns round the fountain's rim, facing out.
	for index = 0, 15 do
		local angle = index / 16 * math.pi * 2
		local spot = frame * Vector3.new(math.cos(angle) * 21.5, 0, math.sin(angle) * 21.5)
		local ground = openGround(spot, 1.6)
		if ground then
			jackOLantern(folder, facing(ground, ground + (ground - center)), rng:NextNumber(1.3, 1.9))
		end
	end
	-- A giant pumpkin floating over the fountain, strung to a ring of poles with garlands.
	local apex = center + Vector3.new(0, 26, 0)
	local giant = jackOLantern(folder, CFrame.new(apex - Vector3.new(0, 3, 0)), 6)
	giant.Name = "GiantJackOLantern"
	giant:SetAttribute("BobPhase", 0)
	giant.PrimaryPart = giant:FindFirstChildWhichIsA("BasePart")
	giant:AddTag(BOB_TAG)
	local tops = {}
	for index = 0, 7 do
		local angle = (index + 0.5) / 8 * math.pi * 2
		for _, radius in { 34, 30, 38, 26 } do
			local ground = openGround(frame * Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius), 1.6)
			if ground then
				table.insert(tops, pole(folder, ground, 14))
				table.insert(taken, ground)
				break
			end
		end
	end
	for index, top in tops do
		garland(folder, top, apex - Vector3.new(0, 1.5, 0))
		local nextTop = tops[index % #tops + 1]
		if #tops > 2 and (nextTop - top).Magnitude < 40 then
			garland(folder, top, nextTop)
		end
	end
	-- Hay bales, tombstones, a cauldron and a scarecrow on open paving, and ghosts overhead.
	local props = { hayBale, tombstones, cauldron, scarecrow }
	local spots = spotsOnPlaza(frame, rng, #props, 24, 52, 5, 9, taken)
	for index, ground in spots do
		props[index](folder, facing(ground, center), rng)
	end
	for _ = 1, 2 do
		local angle, radius = rng:NextNumber(0, math.pi * 2), rng:NextNumber(14, 44)
		ghost(
			folder,
			frame * Vector3.new(math.cos(angle) * radius, rng:NextNumber(9, 16), math.sin(angle) * radius),
			rng
		)
	end
end

local function plainDescription(): HumanoidDescription
	local plain = Instance.new("HumanoidDescription")
	plain.HeadColor, plain.LeftArmColor, plain.RightArmColor = SKIN, SKIN, SKIN
	plain.TorsoColor = Color3.fromRGB(230, 120, 30)
	plain.LeftLegColor, plain.RightLegColor = Color3.fromRGB(40, 36, 44), Color3.fromRGB(40, 36, 44)
	return plain
end

local function buildModel(description: HumanoidDescription): Model?
	local ok, model =
		pcall(Players.CreateHumanoidModelFromDescriptionAsync, Players, description, Enum.HumanoidRigType.R15)
	return if ok then model else nil
end

-- A guest's body: a Roblox costume bundle, or a townsfolk bundle dressed in a costume set.
-- Falls back to the bare outfit, then a plain body, if the Marketplace refuses anything.
local function guestModel(rng: Random, kid: boolean): (Model?, string)
	local bundle = rng:NextNumber() < Halloween.COSTUME_BUNDLE_SHARE
	local list = if bundle then Halloween.COSTUME_BUNDLES else Halloween.TOWNSFOLK_BUNDLES
	local outfitId = list[rng:NextInteger(1, #list)]
	local costume = if bundle then "Costume" else Halloween.COSTUME_ORDER[rng:NextInteger(1, #Halloween.COSTUME_ORDER)]
	local loaded, outfit = pcall(Players.GetHumanoidDescriptionFromOutfitId, Players, outfitId)
	local attempts: { HumanoidDescription } = {}
	if loaded then
		if not bundle then
			local dressed = outfit:Clone()
			local set = Halloween.COSTUMES[costume]
			for slot, ids in set do
				if type(ids) == "table" then
					(dressed :: any)[slot] = tostring(ids[rng:NextInteger(1, #ids)])
				end
			end
			if set.HideHair then
				dressed.HairAccessory = ""
			end
			table.insert(attempts, dressed)
		end
		table.insert(attempts, outfit)
	else
		warn("[Halloween] Outfit " .. outfitId .. " could not load: " .. tostring(outfit))
	end
	table.insert(attempts, plainDescription())
	local model
	for _, description in attempts do
		if kid then
			description.HeightScale *= Halloween.KID_SCALE
			description.WidthScale *= 0.85
			description.DepthScale *= 0.85
			description.HeadScale *= 0.92
		end
		model = model or buildModel(description)
	end
	for _, description in attempts do
		description:Destroy()
	end
	return model, if kid then "Trick-or-Treater" else costume
end

local function costumeTitle(costume: string): string
	return (costume:gsub("(%l)(%u)", "%1 %2"))
end

local function buildGuest(
	guests: Folder,
	frame: CFrame,
	rng: Random,
	name: string,
	dancer: boolean,
	kid: boolean,
	token: number
)
	local model, costume = guestModel(rng, kid)
	if not model then
		return
	end
	if token ~= generation or not guests.Parent then
		model:Destroy()
		return
	end
	model.Name = name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		if not head:FindFirstChildOfClass("Decal") and not head:FindFirstChildOfClass("FaceControls") then
			local face = Instance.new("Decal")
			face.Name, face.Face, face.Texture = "face", Enum.NormalId.Front, "rbxasset://textures/face.png"
			face.Parent = head
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = name
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.WalkSpeed, humanoid.JumpPower = 0, 0
		humanoid.BreakJointsOnDeath = false
	end
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.Anchored = piece.Name == "HumanoidRootPart"
			piece.CanCollide, piece.CanTouch = false, false
			piece.CanQuery = piece.Name == "Head"
		end
	end
	-- The pivot is the root part; it rides HipHeight above the feet. Measuring the whole
	-- model instead counts wings, hats and costumes and leaves the guest hovering.
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	local lift = if humanoid and root and root:IsA("BasePart")
		then humanoid.HipHeight + root.Size.Y / 2
		else model:GetExtentsSize().Y / 2
	model:PivotTo(frame + Vector3.new(0, lift, 0))
	model:SetAttribute("HomeFrame", model:GetPivot())
	model:SetAttribute("Dancer", dancer)
	model.Parent = guests
	model:AddTag(GUEST_TAG)
	if head and head:IsA("BasePart") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = PROMPT
		prompt.ActionText = "Talk"
		prompt.ObjectText = name .. " · " .. costumeTitle(costume)
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.Parent = head
	end
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local animation = Instance.new("Animation")
		animation.AnimationId = if dancer then DANCES[rng:NextInteger(1, #DANCES)] else IDLE_ANIMATION
		local loaded, track = pcall(animator.LoadAnimation, animator, animation)
		if loaded then
			track.Looped = true
			track:Play()
			track.TimePosition = rng:NextNumber(0, math.max(track.Length, 0.1))
		end
	end
end

-- Guests stand in little chatting circles round the square, with a few dancing on their own.
local function inviteGuests(guests: Folder, frame: CFrame, rng: Random, taken: { Vector3 }, token: number, count: number)
	local names = table.clone(Halloween.NAMES)
	local function nextName(): string
		if #names == 0 then
			names = table.clone(Halloween.NAMES)
		end
		return table.remove(names, rng:NextInteger(1, #names)) :: string
	end
	local placed = 0
	local centers = spotsOnPlaza(frame, rng, math.ceil(count / 2.5), 24, 50, 6, 8, taken)
	for _, center in centers do
		if placed >= count then
			break
		end
		local dancer = rng:NextNumber() < DANCER_SHARE
		local size = if dancer then 1 else rng:NextInteger(2, 4)
		local turn = rng:NextNumber(0, math.pi * 2)
		for index = 1, math.min(size, count - placed) do
			local angle = turn + index / size * math.pi * 2
			local spot = if size == 1
				then center
				else center + Vector3.new(math.cos(angle) * 2.4, 0, math.sin(angle) * 2.4)
			local look = if size == 1 then frame.Position else center
			local kid = rng:NextNumber() < Halloween.KID_SHARE
			local guestRng = Random.new(rng:NextInteger(1, 2 ^ 30))
			local name = nextName()
			task.spawn(buildGuest, guests, facing(spot, look), guestRng, name, dancer, kid, token)
			placed += 1
		end
	end
end

-- Put a small string on each house facade, above doorways and player paths.
local function decorateHouses(island: Instance, folder: Instance)
	for _, house in island:GetDescendants() do
		if not house:IsA("Model") then continue end
		local name = house.Name
		if name ~= "House" and name ~= "CubeHouse" and name ~= "Townhouse" and name ~= "Villa"
			and name ~= "BaseHouse" and name ~= "PlazaHouse" and not string.match(name, "^PlazaHouse%d+$") then
			continue
		end
		local face: CFrame? = nil
		if name == "BaseHouse" then
			local shell = house:FindFirstChild("Shell")
			local header = shell and shell:FindFirstChild("DoorHeader")
			if header and header:IsA("BasePart") then
				face = header.CFrame * CFrame.new(0, 0.7, header.Size.Z / 2 + 0.25)
			end
		else
			-- The large ground-floor block has local +Z facing the street.
			local wall: BasePart? = nil
			local area = 0
			for _, piece in house:GetChildren() do
				if piece:IsA("BasePart") and piece.Size.Y >= 6 and piece.Size.X >= 6 and piece.Size.Z >= 6 then
					local candidate = piece.Size.X * piece.Size.Z
					if candidate > area then wall, area = piece, candidate end
				end
			end
			if wall then
				face = wall.CFrame * CFrame.new(0, math.min(wall.Size.Y / 2 - 0.5, 4), wall.Size.Z / 2 + 0.35)
			end
		end
		if face then
			local decoration = Instance.new("Folder")
			decoration.Name = "HouseHalloweenDecoration"
			decoration.Parent = folder
			garland(decoration, face * Vector3.new(-2.5, 0, 0), face * Vector3.new(2.5, 0, 0))
		end
	end
end

-- Spread the remaining guests and a few small displays along the island's lit streets.
local function inviteTown(guests: Folder, decorations: Instance, island: Instance, plaza: CFrame, rng: Random, taken: { Vector3 }, token: number, count: number)
	local lamps = {}
	for _, item in island:GetDescendants() do
		if item:IsA("Model") and item.Name == "LampPost" then
			local base = item:FindFirstChildWhichIsA("BasePart")
			if base then table.insert(lamps, base.Position - Vector3.new(0, base.Size.Y / 2, 0)) end
		end
	end
	for i = #lamps, 2, -1 do
		local j = rng:NextInteger(1, i)
		lamps[i], lamps[j] = lamps[j], lamps[i]
	end
	local placed = 0
	for _, foot in lamps do
		if placed >= count then break end
		if Vector2.new(foot.X - plaza.Position.X, foot.Z - plaza.Position.Z).Magnitude < 75 then continue end
		for _ = 1, 8 do
			local angle = rng:NextNumber(0, math.pi * 2)
			local candidate = foot + Vector3.new(math.cos(angle) * 6, 0, math.sin(angle) * 6)
			local crowded = false
			for _, other in taken do
				if Vector2.new(other.X - candidate.X, other.Z - candidate.Z).Magnitude < 14 then
					crowded = true
					break
				end
			end
			local ground = not crowded and openGround(candidate, 4)
			if ground then
				table.insert(taken, ground)
				placed += 1
				local name = Halloween.NAMES[rng:NextInteger(1, #Halloween.NAMES)]
				local guestRng = Random.new(rng:NextInteger(1, 2 ^ 30))
				task.spawn(buildGuest, guests, facing(ground, foot), guestRng, name, false, rng:NextNumber() < Halloween.KID_SHARE, token)
				if placed % 3 == 0 then
					ghost(decorations, ground + Vector3.new(0, rng:NextNumber(10, 14), 0), rng)
				end
				break
			end
		end
	end
end

local function openParty()
	local plaza, frame = homePlaza()
	if not plaza or not frame then
		return
	end
	generation += 1
	local token = generation
	local folder = Instance.new("Folder")
	folder.Name = "HalloweenParty"
	party = folder
	local decorations = Instance.new("Folder")
	decorations.Name = "Decorations"
	decorations.Parent = folder
	local guests = Instance.new("Folder")
	guests.Name = "Guests"
	guests.Parent = folder
	folder.Parent = workspace
	workspace:SetAttribute("HalloweenPlaza", frame)
	-- The same layout all day, a new one every year.
	local rng = Random.new(Calendar.now().Year * 31 + 10)
	local taken: { Vector3 } = {}
	decoratePlaza(decorations, frame, rng, taken)
	local island = plaza:FindFirstAncestor("Harbour Isle") or plaza
	decorateTown(island, decorations, rng)
	decorateHouses(island, decorations)
	local plazaGuests = math.floor(Halloween.GUESTS / 2)
	inviteGuests(guests, frame, rng, taken, token, plazaGuests)
	inviteTown(guests, decorations, island, frame, rng, taken, token, Halloween.GUESTS - plazaGuests)
	print("[Halloween] The party is open across Harbour Isle")
end

local function closeParty()
	generation += 1
	restoreTown()
	if party then
		party:Destroy()
		party = nil
	end
	print("[Halloween] The party is over")
end

function Service.isOpen(): boolean
	return party ~= nil
end

function Service.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		while true do
			local date = Calendar.now()
			local open = Halloween.phase(date) ~= nil or Halloween.forcedToday(date)
			if workspace:GetAttribute("HalloweenEventEnds") and not Halloween.forcedToday(date) then
				workspace:SetAttribute("HalloweenEventDay", nil)
				workspace:SetAttribute("HalloweenEventEnds", nil)
			end
			if open and not party then
				local ok, problem = pcall(openParty)
				if not ok then
					warn("[Halloween] " .. tostring(problem))
				end
			elseif not open and party then
				closeParty()
			end
			task.wait(1)
		end
	end)
end

return Service
