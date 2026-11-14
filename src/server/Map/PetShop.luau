-- Paws & Fins: a decorative pet shop on the north-east corner of the plaza, in the plot the
-- plain townhouse used to fill. Its door leads to a small shop floor away from the map with
-- puppy and kitten pens, parrot cages, a tropical fish tank, a cat tree and stocked shelves.
-- Nothing is for sale yet. Versioned builders upgrade saved storefronts and relink the doors.
local PlazaHouses = require(script.Parent.PlazaHouses)
local Props = require(script.Parent.Props)

local PetShop = {}
local LAYOUT_VERSION = 1
local INTERIOR_VERSION = 2
local ORIGIN = CFrame.new(6700, 300, 320)
local W, D, H = 40, 32, 14
local SPOT = CFrame.new(42, 0, -47) -- storefront centre in paving coordinates, door toward the fountain
local rgb = Color3.fromRGB
local M = Enum.Material
local CREAM = rgb(255, 245, 213)
local MINT = rgb(132, 186, 150)
local BLUE = rgb(60, 110, 140)
local WOOD = rgb(150, 104, 64)
local DARK = rgb(92, 66, 44)
local IRON = rgb(44, 42, 40)
local BRASS = rgb(200, 160, 84)
local NOSE = rgb(40, 30, 28)

local function interiors(): Instance
	local folder = workspace:FindFirstChild("Interiors")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name, folder.Parent = "Interiors", workspace
	end
	return folder
end

local function doorPrompt(door: BasePart, action: string, destination: CFrame)
	local prompt = door:FindFirstChild("PetShopDoorPrompt") :: ProximityPrompt?
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PetShopDoorPrompt"
		prompt.ObjectText = "Paws & Fins"
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt.Parent = door
	end
	local p = prompt :: ProximityPrompt
	p.ActionText = action
	p:SetAttribute("TeleportTo", destination)
end

-- Decorative pieces: no hitbox, no shadow.
local function trim(piece: BasePart): BasePart
	piece.CanCollide = false
	piece.CastShadow = false
	return piece
end

----------------------------------------------------------------------------------------------------
-- Animals, built from blocks. Each stands on `frame` (feet on its origin) looking along -Z.

local function dog(parent: Instance, frame: CFrame, coat: Color3, patch: Color3, scale: number?): Model
	local k = scale or 1
	local m = Instance.new("Model")
	m.Name = "Puppy"
	local function p(size: Vector3, at: Vector3, color: Color3, tilt: CFrame?)
		trim(Props.part(m, size * k, frame * CFrame.new(at * k) * (tilt or CFrame.new()), color, M.SmoothPlastic))
	end
	p(Vector3.new(1.1, 0.9, 1.8), Vector3.new(0, 1.15, 0), coat)
	p(Vector3.new(1.12, 0.5, 0.8), Vector3.new(0, 1.35, 0.3), patch)
	for _, x in { -0.35, 0.35 } do
		for _, z in { -0.6, 0.6 } do
			p(Vector3.new(0.3, 0.75, 0.3), Vector3.new(x, 0.38, z), coat)
		end
	end
	p(Vector3.new(0.9, 0.85, 0.85), Vector3.new(0, 1.85, -1.05), coat)
	p(Vector3.new(0.5, 0.4, 0.45), Vector3.new(0, 1.65, -1.6), patch)
	p(Vector3.new(0.2, 0.18, 0.12), Vector3.new(0, 1.78, -1.84), NOSE)
	for _, x in { -0.22, 0.22 } do
		p(Vector3.new(0.12, 0.12, 0.08), Vector3.new(x, 2.0, -1.48), NOSE)
	end
	for _, x in { -1, 1 } do
		p(Vector3.new(0.18, 0.6, 0.4), Vector3.new(x * 0.5, 1.75, -0.95), patch, CFrame.Angles(0, 0, x * 0.25))
	end
	p(Vector3.new(0.18, 0.18, 0.8), Vector3.new(0, 1.65, 1.15), coat, CFrame.Angles(0.7, 0, 0))
	m.Parent = parent
	return m
end

local function cat(parent: Instance, frame: CFrame, coat: Color3, curled: boolean?): Model
	local m = Instance.new("Model")
	m.Name = "Kitten"
	local function p(size: Vector3, at: CFrame, color: Color3)
		trim(Props.part(m, size, frame * at, color, M.SmoothPlastic))
	end
	if curled then
		-- Asleep in a loaf, tail wrapped round the front paws
		p(Vector3.new(1.3, 0.6, 1), CFrame.new(0, 0.3, 0), coat)
		p(Vector3.new(0.6, 0.55, 0.55), CFrame.new(-0.55, 0.45, -0.15), coat)
		for _, z in { -0.32, 0.02 } do
			p(Vector3.new(0.14, 0.22, 0.16), CFrame.new(-0.6, 0.8, z), coat)
		end
		p(Vector3.new(1.1, 0.16, 0.16), CFrame.new(0.05, 0.12, -0.55), coat)
	else
		p(Vector3.new(0.7, 0.65, 1.2), CFrame.new(0, 0.75, 0), coat)
		for _, x in { -0.22, 0.22 } do
			for _, z in { -0.42, 0.42 } do
				p(Vector3.new(0.18, 0.45, 0.18), CFrame.new(x, 0.22, z), coat)
			end
		end
		p(Vector3.new(0.65, 0.6, 0.6), CFrame.new(0, 1.25, -0.7), coat)
		for _, x in { -0.2, 0.2 } do
			p(Vector3.new(0.16, 0.25, 0.12), CFrame.new(x, 1.65, -0.7), coat)
			p(Vector3.new(0.1, 0.1, 0.06), CFrame.new(x * 0.8, 1.32, -1.01), rgb(110, 170, 70))
		end
		p(Vector3.new(0.1, 0.08, 0.06), CFrame.new(0, 1.18, -1.01), rgb(220, 130, 140))
		p(Vector3.new(0.14, 0.14, 1.1), CFrame.new(0, 1.3, 0.85) * CFrame.Angles(-0.9, 0, 0), coat)
	end
	m.Parent = parent
	return m
end

local function parrot(parent: Instance, frame: CFrame, body: Color3, wing: Color3): Model
	local m = Instance.new("Model")
	m.Name = "Parrot"
	trim(Props.part(m, Vector3.new(0.55, 0.85, 0.5), frame * CFrame.new(0, 0.5, 0) * CFrame.Angles(-0.2, 0, 0), body))
	trim(Props.ball(m, (frame * CFrame.new(0, 1.05, -0.08)).Position, 0.5, body))
	trim(Props.part(m, Vector3.new(0.16, 0.2, 0.22), frame * CFrame.new(0, 1.0, -0.36), rgb(236, 210, 120)))
	for _, x in { -0.13, 0.13 } do
		trim(Props.part(m, Vector3.new(0.06, 0.08, 0.08), frame * CFrame.new(x, 1.12, -0.26), NOSE))
	end
	for _, x in { -0.29, 0.29 } do
		trim(Props.part(m, Vector3.new(0.1, 0.65, 0.4), frame * CFrame.new(x, 0.5, 0.02) * CFrame.Angles(-0.2, 0, 0), wing))
	end
	trim(Props.part(m, Vector3.new(0.25, 0.08, 0.8), frame * CFrame.new(0, 0.1, 0.45) * CFrame.Angles(0.9, 0, 0), wing))
	m.Parent = parent
	return m
end

local function fish(parent: Instance, frame: CFrame, color: Color3, stripe: Color3)
	trim(Props.part(parent, Vector3.new(0.22, 0.42, 0.75), frame, color))
	trim(Props.part(parent, Vector3.new(0.24, 0.44, 0.12), frame * CFrame.new(0, 0, -0.08), stripe))
	trim(Props.part(parent, Vector3.new(0.08, 0.38, 0.3), frame * CFrame.new(0, 0, 0.48), color))
end

local function rabbit(parent: Instance, frame: CFrame, coat: Color3, lop: boolean?)
	local m = Instance.new("Model")
	m.Name = "Rabbit"
	local function p(size: Vector3, at: CFrame, color: Color3)
		trim(Props.part(m, size, frame * at, color, M.SmoothPlastic))
	end
	p(Vector3.new(0.8, 0.7, 1.1), CFrame.new(0, 0.4, 0.1), coat)
	p(Vector3.new(0.6, 0.55, 0.6), CFrame.new(0, 0.7, -0.5), coat)
	p(Vector3.new(0.14, 0.1, 0.06), CFrame.new(0, 0.62, -0.81), rgb(220, 130, 140))
	for _, x in { -1, 1 } do
		p(Vector3.new(0.08, 0.08, 0.06), CFrame.new(x * 0.18, 0.78, -0.8), NOSE)
		if lop then
			p(Vector3.new(0.1, 0.6, 0.26), CFrame.new(x * 0.34, 0.65, -0.45) * CFrame.Angles(0, 0, x * 0.2), coat)
		else
			p(Vector3.new(0.12, 0.7, 0.24), CFrame.new(x * 0.14, 1.25, -0.45) * CFrame.Angles(0.15, 0, x * 0.12), coat)
		end
		p(Vector3.new(0.22, 0.14, 0.5), CFrame.new(x * 0.25, 0.07, -0.15), coat)
	end
	trim(Props.ball(m, (frame * CFrame.new(0, 0.5, 0.7)).Position, 0.35, CREAM))
	m.Parent = parent
end

local function turtle(parent: Instance, frame: CFrame)
	local m = Instance.new("Model")
	m.Name = "Turtle"
	local skin, shell = rgb(120, 150, 80), rgb(90, 110, 56)
	local function p(size: Vector3, at: CFrame, color: Color3)
		trim(Props.part(m, size, frame * at, color, M.SmoothPlastic))
	end
	p(Vector3.new(1.1, 0.35, 1.3), CFrame.new(0, 0.3, 0), shell)
	p(Vector3.new(0.8, 0.25, 0.95), CFrame.new(0, 0.55, 0), rgb(110, 132, 66))
	p(Vector3.new(0.35, 0.3, 0.45), CFrame.new(0, 0.3, -0.8), skin)
	for _, x in { -0.45, 0.45 } do
		for _, z in { -0.45, 0.45 } do
			p(Vector3.new(0.25, 0.2, 0.3), CFrame.new(x, 0.12, z), skin)
		end
	end
	m.Parent = parent
end

local function hamster(parent: Instance, center: Vector3, coat: Color3)
	trim(Props.ball(parent, center, 0.55, coat))
	trim(Props.ball(parent, center + Vector3.new(0, 0.05, -0.25), 0.35, CREAM))
	for _, x in { -0.14, 0.14 } do
		trim(Props.ball(parent, center + Vector3.new(x, 0.26, -0.1), 0.14, rgb(220, 160, 150)))
	end
end

-- A flat round disc whose face looks along the frame's X axis.
local function disc(parent: Instance, frame: CFrame, thickness: number, diameter: number, color: Color3, material: Enum.Material?): BasePart
	local p = Props.part(parent, Vector3.new(thickness, diameter, diameter), frame, color, material)
	p.Shape = Enum.PartType.Cylinder
	return trim(p)
end

----------------------------------------------------------------------------------------------------
-- The shop floor

local function ensureInterior(): Model
	local folder = interiors()
	local existing = folder:FindFirstChild("PetShopInterior")
	if existing and existing:IsA("Model") and existing:GetAttribute("LayoutVersion") == INTERIOR_VERSION then
		return existing
	elseif existing then
		existing:Destroy()
	end
	local hall = Instance.new("Model")
	hall.Name = "PetShopInterior"
	hall.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	hall:SetAttribute("LayoutVersion", INTERIOR_VERSION)
	hall:SetAttribute("InteriorFrame", ORIGIN * CFrame.new(0, H / 2, 0))
	hall:SetAttribute("InteriorSize", Vector3.new(W, H, D))
	hall:SetAttribute("ArrivalFrame", ORIGIN * CFrame.new(0, 3.2, -D / 2 + 5) * CFrame.Angles(0, math.pi, 0))
	local rng = Random.new(8128)
	local function part(name: string, size: Vector3, frame: CFrame, color: Color3, material: Enum.Material?): Part
		local p = Props.part(hall, size, ORIGIN * frame, color, material)
		p.Name = name
		return p
	end
	local function deco(name: string, size: Vector3, frame: CFrame, color: Color3, material: Enum.Material?): BasePart
		return trim(part(name, size, frame, color, material))
	end
	local function sign(name: string, size: Vector3, frame: CFrame, text: string, color: Color3)
		PlazaHouses.boardText(deco(name, size, frame, color, M.Wood), text, Enum.NormalId.Front)
	end
	local function at(x: number, y: number, z: number): CFrame
		return ORIGIN * CFrame.new(x, y, z)
	end

	-- Shell: chequered tiles, mint wainscot under butter-yellow plaster, a timber-beamed ceiling.
	part("Floor", Vector3.new(W + 2, 1, D + 2), CFrame.new(0, -0.5, 0), rgb(238, 226, 200), M.Marble)
	for x = -W / 2 + 2, W / 2 - 2, 4 do
		for z = -D / 2 + 2, D / 2 - 2, 4 do
			if ((x + z) / 4) % 2 == 0 then
				deco("FloorTile", Vector3.new(4, 0.04, 4), CFrame.new(x, 0.02, z), rgb(196, 222, 204), M.Marble)
			end
		end
	end
	part("Ceiling", Vector3.new(W + 2, 1, D + 2), CFrame.new(0, H + 0.5, 0), rgb(250, 240, 214), M.Plaster)
	for _, side in { -1, 1 } do
		part("SideWall", Vector3.new(1, H, D + 2), CFrame.new(side * (W / 2 + 0.5), H / 2, 0), rgb(250, 228, 160), M.Plaster)
		part("EndWall", Vector3.new(W, H, 1), CFrame.new(0, H / 2, side * (D / 2 + 0.5)), rgb(250, 228, 160), M.Plaster)
		deco("Wainscot", Vector3.new(0.2, 3.5, D), CFrame.new(side * (W / 2 - 0.1), 1.75, 0), MINT, M.WoodPlanks)
		deco("Wainscot", Vector3.new(W, 3.5, 0.2), CFrame.new(0, 1.75, side * (D / 2 - 0.1)), MINT, M.WoodPlanks)
		deco("WainscotCap", Vector3.new(0.35, 0.2, D), CFrame.new(side * (W / 2 - 0.2), 3.55, 0), CREAM, M.Wood)
		deco("WainscotCap", Vector3.new(W, 0.2, 0.35), CFrame.new(0, 3.55, side * (D / 2 - 0.2)), CREAM, M.Wood)
	end
	for _, z in { -10, 0, 10 } do
		deco("CeilingBeam", Vector3.new(W, 0.8, 0.8), CFrame.new(0, H - 0.4, z), WOOD, M.Wood)
		for _, x in { -12, 0, 12 } do
			local lamp = Props.lantern(hall, at(x, H - 2.6, z), 20, 0.8)
			for _, piece in lamp:GetDescendants() do
				if piece:IsA("BasePart") then trim(piece) end
			end
		end
	end

	-- Entrance wall: the way out, windows either side, a paw-print trail leading in.
	part("ExitDoor", Vector3.new(4, 8, 0.3), CFrame.new(0, 4, -D / 2 + 0.2), rgb(70, 120, 66), M.WoodPlanks)
	deco("DoorFrame", Vector3.new(5, 0.6, 0.4), CFrame.new(0, 8.3, -D / 2 + 0.2), CREAM, M.Wood)
	sign("ExitSign", Vector3.new(6, 1.3, 0.2), CFrame.new(0, 9.6, -D / 2 + 0.4) * CFrame.Angles(0, math.pi, 0), "EXIT · PLAZA", BLUE)
	for _, side in { -1, 1 } do
		local x = side * 11
		deco("WindowFrame", Vector3.new(7, 6, 0.3), CFrame.new(x, 7, -D / 2 + 0.25), BLUE, M.Wood)
		local pane = deco("WindowLight", Vector3.new(6, 5, 0.1), CFrame.new(x, 7, -D / 2 + 0.45), CREAM, M.Neon)
		Props.light(pane, CREAM, 14, 0.35)
		deco("WindowBar", Vector3.new(0.2, 5, 0.2), CFrame.new(x, 7, -D / 2 + 0.55), BLUE, M.Wood)
		deco("WindowBar", Vector3.new(6, 0.2, 0.2), CFrame.new(x, 7, -D / 2 + 0.55), BLUE, M.Wood)
	end
	deco("EntryMat", Vector3.new(6, 0.08, 2.5), CFrame.new(0, 0.06, -D / 2 + 2), MINT, M.Fabric)
	for i = 0, 5 do
		local x, z = (if i % 2 == 0 then -0.7 else 0.7), -D / 2 + 4.5 + i * 2
		deco("PawPad", Vector3.new(0.7, 0.06, 0.6), CFrame.new(x, 0.07, z), DARK, M.SmoothPlastic)
		for _, toe in { -0.32, -0.11, 0.11, 0.32 } do
			deco("PawToe", Vector3.new(0.22, 0.06, 0.22), CFrame.new(x + toe, 0.07, z + 0.55 - math.abs(toe) * 0.5), DARK, M.SmoothPlastic)
		end
	end

	-- Back wall: the shop's name over the counter and the shelves.
	sign("WelcomeSign", Vector3.new(20, 2.6, 0.2), CFrame.new(0, 11, D / 2 - 0.3), "PAWS & FINS", BLUE)
	sign("WelcomeLine", Vector3.new(18, 1.2, 0.2), CFrame.new(0, 9.1, D / 2 - 0.3), "Friends for every angler · Adoptions coming soon", DARK)

	-- Counter on the left, with a till, a treat jar and a cat asleep by the bell.
	local counterZ = D / 2 - 5
	part("Counter", Vector3.new(10, 3.4, 2.6), CFrame.new(-9, 1.7, counterZ), WOOD, M.WoodPlanks)
	part("CounterTop", Vector3.new(10.6, 0.3, 3), CFrame.new(-9, 3.55, counterZ), DARK, M.Wood)
	deco("CounterPanel", Vector3.new(9, 2.4, 0.1), CFrame.new(-9, 1.7, counterZ - 1.33), MINT, M.Wood)
	deco("TillBase", Vector3.new(1.8, 0.7, 1.4), CFrame.new(-11.5, 4.05, counterZ), rgb(60, 60, 64), M.Metal)
	deco("TillScreen", Vector3.new(1.4, 0.8, 0.12), CFrame.new(-11.5, 4.7, counterZ + 0.3) * CFrame.Angles(-0.3, 0, 0), rgb(120, 200, 160), M.Neon)
	deco("TreatJar", Vector3.new(0.9, 1.2, 0.9), CFrame.new(-8.2, 4.3, counterZ - 0.3), rgb(220, 236, 240), M.Glass).Transparency = 0.4
	for i = 0, 4 do
		deco("Treat", Vector3.new(0.45, 0.2, 0.25), CFrame.new(-8.2 + (i % 2) * 0.2 - 0.1, 3.85 + i * 0.16, counterZ - 0.3) * CFrame.Angles(0, i, 0), rgb(196, 140, 80), M.SmoothPlastic)
	end
	deco("Bell", Vector3.new(0.5, 0.35, 0.5), CFrame.new(-6.6, 3.88, counterZ - 0.6), BRASS, M.Metal)
	cat(hall, at(-5.6, 3.7, counterZ + 0.2) * CFrame.Angles(0, math.pi / 2, 0), rgb(232, 150, 70), true)
	sign("CounterSign", Vector3.new(4.5, 1, 0.12), CFrame.new(-9, 2.4, counterZ - 1.42), "PLEASE PET GENTLY", BLUE)

	-- Shelves on the right of the back wall: food sacks, tins and toys.
	local shelfX, shelfZ = 9, D / 2 - 1.1
	for _, x in { shelfX - 6.2, shelfX + 6.2 } do
		part("ShelfUpright", Vector3.new(0.4, 7.4, 1.8), CFrame.new(x, 3.7, shelfZ), WOOD, M.Wood)
	end
	local sacks = { rgb(196, 70, 54), rgb(60, 110, 160), rgb(230, 180, 70), rgb(84, 140, 84), rgb(150, 96, 170) }
	for level, y in { 0.6, 2.8, 5 } do
		part("Shelf", Vector3.new(12, 0.25, 1.8), CFrame.new(shelfX, y, shelfZ), WOOD, M.Wood)
		local x = shelfX - 5.4
		while x < shelfX + 5.2 do
			if level == 1 then
				local color = Props.pick(rng, sacks)
				deco("FoodSack", Vector3.new(1.3, 1.8, 0.9), CFrame.new(x + 0.65, y + 1.03, shelfZ) * CFrame.Angles(0, rng:NextNumber(-0.15, 0.15), 0), color, M.Fabric)
				deco("SackLabel", Vector3.new(0.9, 0.6, 0.05), CFrame.new(x + 0.65, y + 1.1, shelfZ - 0.48), CREAM, M.SmoothPlastic)
				x += 1.5
			elseif level == 2 then
				for row = 0, 1 do
					Props.cylinder(hall, (at(x + 0.35, y + 0.47 + row * 0.7, shelfZ - 0.2)).Position, 0.7, 0.65, Props.pick(rng, sacks), M.Metal).CanCollide = false
				end
				x += 0.8
			else
				if rng:NextNumber() < 0.5 then
					trim(Props.ball(hall, (at(x + 0.45, y + 0.58, shelfZ)).Position, 0.9, Props.pick(rng, sacks)))
				else
					deco("ChewBone", Vector3.new(1, 0.3, 0.35), CFrame.new(x + 0.5, y + 0.28, shelfZ) * CFrame.Angles(0, 0.4, 0), CREAM, M.SmoothPlastic)
				end
				x += 1.1
			end
		end
	end
	sign("ShelfSign", Vector3.new(8, 1.2, 0.15), CFrame.new(shelfX, 7.2, D / 2 - 0.4), "FOOD · TREATS · TOYS", MINT)

	-- Right wall: a long tropical tank on a cabinet, bubbling and lit from within.
	local tankX, tankL = W / 2 - 2, 20
	part("TankCabinet", Vector3.new(3, 3, tankL + 0.4), CFrame.new(tankX, 1.5, 0), BLUE, M.WoodPlanks)
	part("TankGlass", Vector3.new(3, 5, tankL), CFrame.new(tankX, 5.5, 0), rgb(200, 230, 240), M.Glass).Transparency = 0.75
	local water = deco("TankWater", Vector3.new(2.7, 4.3, tankL - 0.3), CFrame.new(tankX, 5.3, 0), rgb(70, 160, 210), M.SmoothPlastic)
	water.Transparency = 0.6
	local glow = deco("TankLid", Vector3.new(3.2, 0.4, tankL + 0.2), CFrame.new(tankX, 8.2, 0), rgb(40, 50, 60), M.Metal)
	Props.light(glow, rgb(140, 210, 255), 12, 0.6)
	deco("TankSand", Vector3.new(2.7, 0.5, tankL - 0.3), CFrame.new(tankX, 3.25, 0), rgb(230, 210, 160), M.Sand)
	for z = -tankL / 2 + 1.5, tankL / 2 - 1, 2.6 do
		local base = Vector3.new(tankX + rng:NextNumber(-0.6, 0.6), 3.5, z)
		for _ = 1, 3 do
			local top = base + Vector3.new(rng:NextNumber(-0.3, 0.3), rng:NextNumber(1.6, 3.4), rng:NextNumber(-0.5, 0.5))
			trim(Props.beam(hall, (ORIGIN * CFrame.new(base)).Position, (ORIGIN * CFrame.new(top)).Position, 0.2, rgb(70, 150, 80), 0.08, M.SmoothPlastic))
		end
		trim(Props.ball(hall, (at(tankX + rng:NextNumber(-0.7, 0.7), 3.6, z + 1.2)).Position, rng:NextNumber(0.5, 0.9), rgb(140, 130, 120), M.Slate))
	end
	local fins = {
		{ rgb(255, 130, 40), CREAM },
		{ rgb(60, 120, 230), rgb(250, 220, 60) },
		{ rgb(250, 220, 60), rgb(40, 40, 40) },
		{ rgb(230, 70, 90), rgb(250, 200, 210) },
	}
	for _ = 1, 14 do
		local colors = Props.pick(rng, fins)
		local z = rng:NextNumber(-tankL / 2 + 1, tankL / 2 - 1)
		local facing = if rng:NextNumber() < 0.5 then 0 else math.pi
		fish(hall, at(tankX + rng:NextNumber(-0.7, 0.7), rng:NextNumber(4.1, 6.9), z) * CFrame.Angles(0, facing, 0), colors[1], colors[2])
	end
	for i = 0, 7 do
		trim(Props.ball(hall, (at(tankX - 0.6, 3.9 + i * 0.5, tankL / 2 - 1.2 + math.sin(i) * 0.15)).Position, 0.18, CREAM, M.Glass)).Transparency = 0.3
	end
	sign("TankSign", Vector3.new(10, 1.6, 0.15), CFrame.new(W / 2 - 0.6, 10.5, 0) * CFrame.Angles(0, math.pi / 2, 0), "TROPICAL FISH", BLUE)

	-- Left wall: two parrot cages on stands, and a cat tree by the window.
	local plumage = { { rgb(220, 50, 40), rgb(40, 100, 200) }, { rgb(70, 170, 70), rgb(240, 200, 50) } }
	for i, z in { -2, 5 } do
		local x = -W / 2 + 3.2
		part("CageStand", Vector3.new(0.35, 4, 0.35), CFrame.new(x, 2, z), IRON, M.Metal)
		part("CageFoot", Vector3.new(2.2, 0.2, 2.2), CFrame.new(x, 0.1, z), IRON, M.Metal)
		Props.cylinder(hall, (at(x, 4.1, z)).Position, 0.25, 3, BRASS, M.Metal)
		for k = 0, 11 do
			local a = k / 12 * math.pi * 2
			local dx, dz = math.cos(a) * 1.4, math.sin(a) * 1.4
			deco("CageBar", Vector3.new(0.08, 3.4, 0.08), CFrame.new(x + dx, 5.9, z + dz), BRASS, M.Metal)
		end
		trim(Props.cylinder(hall, (at(x, 7.65, z)).Position, 0.2, 3, BRASS, M.Metal))
		deco("CageCap", Vector3.new(1.2, 0.6, 1.2), CFrame.new(x, 8, z), BRASS, M.Metal)
		deco("CageRing", Vector3.new(0.12, 0.6, 0.12), CFrame.new(x, 8.55, z), BRASS, M.Metal)
		deco("Perch", Vector3.new(0.15, 0.15, 2.6), CFrame.new(x, 5.3, z), WOOD, M.Wood)
		parrot(hall, at(x, 5.38, z) * CFrame.Angles(0, -math.pi / 2, 0), plumage[i][1], plumage[i][2])
	end
	sign("BirdSign", Vector3.new(8, 1.4, 0.15), CFrame.new(-(W / 2 - 0.6), 10.5, 1.5) * CFrame.Angles(0, -math.pi / 2, 0), "FEATHERED FRIENDS", MINT)
	do
		local x, z = -W / 2 + 3.2, -D / 2 + 7
		local sisal, fluff = rgb(214, 190, 150), rgb(170, 120, 150)
		part("CatTreeBase", Vector3.new(4, 0.6, 4), CFrame.new(x, 0.3, z), fluff, M.Fabric)
		part("CatTreePost", Vector3.new(0.8, 6, 0.8), CFrame.new(x - 0.8, 3.6, z - 0.8), sisal, M.Fabric)
		part("CatTreePost", Vector3.new(0.8, 3.4, 0.8), CFrame.new(x + 0.9, 2.3, z + 0.9), sisal, M.Fabric)
		part("CatTreeShelf", Vector3.new(2.4, 0.4, 2.4), CFrame.new(x + 0.6, 4.2, z + 0.6), fluff, M.Fabric)
		part("CatTreeTop", Vector3.new(2.6, 0.5, 2.6), CFrame.new(x - 0.6, 6.85, z - 0.6), fluff, M.Fabric)
		cat(hall, at(x - 0.6, 7.1, z - 0.6) * CFrame.Angles(0, -math.pi / 2, 0), rgb(70, 70, 76))
		deco("DanglingMouse", Vector3.new(0.3, 0.3, 0.5), CFrame.new(x + 1.4, 3.3, z + 0.6), rgb(160, 160, 170), M.Fabric)
		deco("ToyString", Vector3.new(0.04, 0.55, 0.04), CFrame.new(x + 1.4, 3.72, z + 0.6), CREAM, M.Fabric)
	end

	-- Middle of the floor: a puppy pen and a kitten pen, with the walk to the counter between them.
	local function pen(name: string, cx: number, cz: number, size: number, label: string)
		local half = size / 2
		for _, s in { -1, 1 } do
			part(name .. "Rail", Vector3.new(size, 0.25, 0.25), CFrame.new(cx, 2.4, cz + s * half), CREAM, M.Wood)
			part(name .. "Rail", Vector3.new(0.25, 0.25, size), CFrame.new(cx + s * half, 2.4, cz), CREAM, M.Wood)
			part(name .. "Kick", Vector3.new(size, 0.8, 0.2), CFrame.new(cx, 0.4, cz + s * half), MINT, M.Wood)
			part(name .. "Kick", Vector3.new(0.2, 0.8, size), CFrame.new(cx + s * half, 0.4, cz), MINT, M.Wood)
		end
		for i = -half, half, 1 do
			for _, s in { -1, 1 } do
				deco("Picket", Vector3.new(0.16, 1.6, 0.16), CFrame.new(cx + i, 1.6, cz + s * half), CREAM, M.Wood)
				deco("Picket", Vector3.new(0.16, 1.6, 0.16), CFrame.new(cx + s * half, 1.6, cz + i), CREAM, M.Wood)
			end
		end
		deco(name .. "Straw", Vector3.new(size - 0.4, 0.1, size - 0.4), CFrame.new(cx, 0.08, cz), rgb(226, 204, 140), M.Fabric)
		sign(name .. "Sign", Vector3.new(3.6, 1, 0.12), CFrame.new(cx, 3.1, cz - half - 0.15), label, BLUE)
	end
	pen("PuppyPen", -7, 1, 8, "PUPPIES")
	pen("KittenPen", 7, 1, 8, "KITTENS")
	-- Puppies round a bed and a bowl
	deco("DogBed", Vector3.new(3, 0.5, 2.4), CFrame.new(-8.6, 0.35, 3), rgb(180, 70, 60), M.Fabric)
	deco("DogBedCushion", Vector3.new(2.4, 0.3, 1.8), CFrame.new(-8.6, 0.55, 3), CREAM, M.Fabric)
	dog(hall, at(-8.6, 0.3, 3) * CFrame.Angles(0, math.pi / 2, 0), rgb(214, 170, 110), CREAM, 0.7)
	dog(hall, at(-5.5, 0.1, -0.6) * CFrame.Angles(0, 0.5, 0), rgb(240, 236, 228), rgb(60, 50, 44), 0.75)
	dog(hall, at(-8, 0.1, -1.5) * CFrame.Angles(0, -0.9, 0), rgb(110, 76, 50), rgb(200, 160, 110), 0.65)
	trim(Props.cylinder(hall, (at(-4.6, 0.25, 3.6)).Position, 0.4, 1.2, rgb(60, 110, 160), M.Metal))
	trim(Props.ball(hall, (at(-6.4, 0.45, 1.4)).Position, 0.7, rgb(230, 80, 60)))
	-- Kittens with a yarn ball and a scratching box
	cat(hall, at(5.5, 0.1, -0.8) * CFrame.Angles(0, -0.6, 0), rgb(236, 236, 236))
	cat(hall, at(8.8, 0.1, 0.5) * CFrame.Angles(0, 2.2, 0), rgb(232, 150, 70))
	cat(hall, at(6.5, 0.1, 3.4) * CFrame.Angles(0, math.pi / 2, 0), rgb(110, 110, 118), true)
	trim(Props.ball(hall, (at(7.2, 0.4, -1.6)).Position, 0.6, rgb(220, 60, 120), M.Fabric))
	deco("YarnTail", Vector3.new(0.06, 0.06, 1.4), CFrame.new(7.6, 0.13, -2.2) * CFrame.Angles(0, 0.6, 0), rgb(220, 60, 120), M.Fabric)
	deco("ScratchBox", Vector3.new(2, 0.8, 1.4), CFrame.new(9.2, 0.5, 3.6), rgb(190, 150, 100), M.Cardboard)

	-- Potted palms soften the corners by the door.
	for _, x in { -W / 2 + 2, W / 2 - 2 } do
		local pot = at(x, 0, -D / 2 + 1.8)
		trim(Props.cylinder(hall, (pot * CFrame.new(0, 0.9, 0)).Position, 1.8, 1.8, rgb(164, 96, 62), M.SmoothPlastic))
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2
			trim(Props.beam(hall, (pot * CFrame.new(0, 1.8, 0)).Position, (pot * CFrame.new(math.cos(a) * 1.6, 3.6 + (k % 2) * 0.6, math.sin(a) * 1.6)).Position, 0.6, rgb(64, 118, 66), 0.1, M.LeafyGrass))
		end
	end

	------------------------------------------------------------------------------------------------
	-- Finer details

	local STRAW = rgb(226, 204, 140)
	local WIRE = rgb(186, 186, 192)
	local TIMBER = rgb(176, 128, 80)
	local BRIGHT = { rgb(230, 90, 70), rgb(250, 200, 70), rgb(90, 170, 120), rgb(80, 140, 210), rgb(200, 110, 180) }

	-- Bunting of little pennants strung across the room between the side walls.
	for _, z in { -6, 6 } do
		local a, b = Vector3.new(-W / 2 + 0.3, 12, z), Vector3.new(W / 2 - 0.3, 12, z)
		local count = 24
		local last = a
		for i = 1, count do
			local t = i / count
			local point = a + (b - a) * t - Vector3.new(0, math.sin(t * math.pi) * 1.2, 0)
			trim(Props.beam(hall, (ORIGIN * CFrame.new(last)).Position, (ORIGIN * CFrame.new(point)).Position, 0.06, CREAM, 0.06, M.Fabric))
			if i < count then
				deco("Pennant", Vector3.new(0.75, 0.75, 0.04), CFrame.new(point - Vector3.new(0, 0.53, 0)) * CFrame.Angles(0, 0, math.pi / 4), BRIGHT[i % #BRIGHT + 1], M.Fabric)
			end
			last = point
		end
	end

	-- Framed portraits of the shop's own pets either side of the door.
	for i, look in {
		{ x = -5, coat = rgb(214, 170, 110), back = rgb(150, 200, 220), name = "BISCUIT", floppy = true },
		{ x = 5, coat = rgb(70, 70, 76), back = rgb(240, 200, 170), name = "SHADOW", floppy = false },
	} do
		local x, z = look.x, -D / 2 + 0.2
		deco("PortraitFrame", Vector3.new(2.6, 3.2, 0.15), CFrame.new(x, 6.5, z + 0.05), BRASS, M.Wood)
		deco("PortraitCanvas", Vector3.new(2.1, 2.7, 0.06), CFrame.new(x, 6.5, z + 0.15), look.back, M.SmoothPlastic)
		deco("PortraitBody", Vector3.new(1.6, 0.8, 0.05), CFrame.new(x, 5.55, z + 0.2), look.coat, M.SmoothPlastic)
		deco("PortraitHead", Vector3.new(1.1, 1, 0.05), CFrame.new(x, 6.4, z + 0.21), look.coat, M.SmoothPlastic)
		for _, s in { -1, 1 } do
			local ear = if look.floppy
				then CFrame.new(x + s * 0.6, 6.4, z + 0.22) * CFrame.Angles(0, 0, s * 0.2)
				else CFrame.new(x + s * 0.38, 7.0, z + 0.22) * CFrame.Angles(0, 0, s * -0.5)
			deco("PortraitEar", if look.floppy then Vector3.new(0.3, 0.8, 0.05) else Vector3.new(0.32, 0.4, 0.05), ear, look.coat, M.SmoothPlastic)
			deco("PortraitEye", Vector3.new(0.14, 0.14, 0.04), CFrame.new(x + s * 0.22, 6.55, z + 0.25), NOSE, M.SmoothPlastic)
		end
		deco("PortraitNose", Vector3.new(0.2, 0.14, 0.04), CFrame.new(x, 6.22, z + 0.25), if i == 1 then NOSE else rgb(220, 130, 140), M.SmoothPlastic)
		PlazaHouses.boardText(deco("PortraitPlate", Vector3.new(1.6, 0.4, 0.08), CFrame.new(x, 4.6, z + 0.05), BRASS, M.Metal), look.name, Enum.NormalId.Back, DARK)
	end

	-- Under the left window: a rabbit hutch with a run, a sleeping box and a hay rack.
	do
		local cx, cz = -10, -D / 2 + 1.5
		for _, x in { -3.3, 3.3 } do
			for _, z in { -1.1, 1.1 } do
				part("HutchLeg", Vector3.new(0.35, 1.2, 0.35), CFrame.new(cx + x, 0.6, cz + z), DARK, M.Wood)
			end
		end
		part("HutchFloor", Vector3.new(7, 0.3, 2.6), CFrame.new(cx, 1.35, cz), TIMBER, M.WoodPlanks)
		part("HutchBack", Vector3.new(7, 2.6, 0.2), CFrame.new(cx, 2.6, cz - 1.2), TIMBER, M.WoodPlanks)
		for _, x in { -3.4, 1.2, 3.4 } do
			part("HutchSide", Vector3.new(0.2, 2.6, 2.6), CFrame.new(cx + x, 2.6, cz), TIMBER, M.WoodPlanks)
		end
		part("HutchRoof", Vector3.new(7.6, 0.25, 3.2), CFrame.new(cx, 4.05, cz + 0.1) * CFrame.Angles(-0.12, 0, 0), rgb(120, 80, 60), M.WoodPlanks)
		deco("HutchBoxFront", Vector3.new(2.0, 2.6, 0.15), CFrame.new(cx + 2.3, 2.6, cz + 1.2), TIMBER, M.WoodPlanks)
		disc(hall, at(cx + 2.3, 2.3, cz + 1.3) * CFrame.Angles(0, math.pi / 2, 0), 0.06, 1.2, rgb(50, 36, 26), M.Wood)
		for x = cx - 3.2, cx + 1.0, 0.4 do
			deco("HutchWire", Vector3.new(0.05, 2.5, 0.05), CFrame.new(x, 2.65, cz + 1.25), WIRE, M.Metal)
		end
		for _, y in { 1.6, 2.6, 3.6 } do
			deco("HutchWire", Vector3.new(4.4, 0.05, 0.05), CFrame.new(cx - 1.1, y, cz + 1.25), WIRE, M.Metal)
		end
		deco("HutchStraw", Vector3.new(4.4, 0.08, 2.2), CFrame.new(cx - 1.1, 1.54, cz), STRAW, M.Fabric)
		deco("HayRack", Vector3.new(1.4, 0.8, 0.5), CFrame.new(cx - 1.1, 3.2, cz - 0.9), STRAW, M.Grass)
		rabbit(hall, at(cx - 2.4, 1.55, cz) * CFrame.Angles(0, math.pi + 0.4, 0), rgb(244, 240, 232), true)
		rabbit(hall, at(cx - 0.2, 1.55, cz - 0.1) * CFrame.Angles(0, math.pi - 0.5, 0), rgb(150, 110, 76))
		deco("Carrot", Vector3.new(0.18, 0.18, 0.6), CFrame.new(cx - 1.3, 1.67, cz + 0.8) * CFrame.Angles(0, 0.8, 0), rgb(240, 130, 40), M.SmoothPlastic)
		deco("CarrotTop", Vector3.new(0.25, 0.1, 0.25), CFrame.new(cx - 1.08, 1.67, cz + 1.02), rgb(80, 150, 70), M.SmoothPlastic)
		trim(Props.cylinder(hall, (at(cx - 3.0, 3.0, cz + 1.38)).Position, 1.0, 0.3, rgb(210, 236, 245), M.Glass)).Transparency = 0.4
		local label = deco("HutchSign", Vector3.new(3, 0.7, 0.1), CFrame.new(cx - 1.1, 4.6, cz + 1.0), BLUE, M.Wood)
		PlazaHouses.boardText(label, "BUNNIES", Enum.NormalId.Back)
	end

	-- Under the right window: a turtle terrarium with a pond, a basking rock and a heat lamp.
	do
		local cx, cz = 10, -D / 2 + 1.6
		part("TerrariumStand", Vector3.new(7, 2.4, 2.6), CFrame.new(cx, 1.2, cz), DARK, M.WoodPlanks)
		for _, x in { -1.7, 1.7 } do
			deco("StandDoor", Vector3.new(3.1, 1.9, 0.08), CFrame.new(cx + x, 1.2, cz + 1.32), TIMBER, M.Wood)
			trim(Props.ball(hall, (at(cx + x + (if x < 0 then 1.2 else -1.2), 1.4, cz + 1.4)).Position, 0.2, BRASS, M.Metal))
		end
		part("TerrariumGlass", Vector3.new(6.6, 2.2, 2.4), CFrame.new(cx, 3.5, cz), rgb(210, 236, 240), M.Glass).Transparency = 0.8
		deco("TerrariumSoil", Vector3.new(6.4, 0.4, 2.2), CFrame.new(cx, 2.6, cz), rgb(120, 90, 60), M.Ground)
		local pond = deco("TerrariumPond", Vector3.new(2.2, 0.1, 1.5), CFrame.new(cx + 1.8, 2.82, cz + 0.2), rgb(80, 150, 190), M.Glass)
		pond.Transparency = 0.3
		deco("BaskingRock", Vector3.new(1.8, 0.5, 1.2), CFrame.new(cx - 1.4, 3.0, cz - 0.2) * CFrame.Angles(0, 0.3, 0.08), rgb(150, 140, 128), M.Slate)
		for _ = 1, 4 do
			trim(Props.ball(hall, (at(cx + rng:NextNumber(-3, 3), 2.85, cz + rng:NextNumber(-0.9, 0.9))).Position, rng:NextNumber(0.25, 0.45), rgb(130, 124, 116), M.Slate))
		end
		for _, x in { -2.8, 0.2, 2.9 } do
			for _ = 1, 3 do
				local root = at(cx + x, 2.8, cz - 0.7)
				trim(Props.beam(hall, root.Position, (root * CFrame.new(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0.8, 1.6), rng:NextNumber(-0.2, 0.3))).Position, 0.18, rgb(80, 150, 70), 0.06, M.SmoothPlastic))
			end
		end
		turtle(hall, at(cx - 1.4, 3.13, cz - 0.2) * CFrame.Angles(0, math.pi + 0.4, 0))
		turtle(hall, at(cx + 1.7, 2.65, cz + 0.2) * CFrame.Angles(0, -2.2, 0))
		deco("TerrariumLid", Vector3.new(6.8, 0.12, 2.6), CFrame.new(cx, 4.65, cz), rgb(60, 60, 64), M.DiamondPlate)
		deco("HeatLampHood", Vector3.new(1.6, 0.5, 1.4), CFrame.new(cx - 1.4, 4.95, cz - 0.2), IRON, M.Metal)
		local bulb = deco("HeatLampBulb", Vector3.new(0.9, 0.1, 0.9), CFrame.new(cx - 1.4, 4.7, cz - 0.2), rgb(255, 170, 80), M.Neon)
		Props.light(bulb, rgb(255, 170, 90), 8, 0.6)
		local label = deco("TerrariumSign", Vector3.new(3.2, 0.6, 0.1), CFrame.new(cx, 2.15, cz + 1.36), BLUE, M.Wood)
		PlazaHouses.boardText(label, "TURTLES", Enum.NormalId.Back)
	end

	-- Two round display tables by the entrance: a hamster cage and a row of goldfish bowls.
	local function roundTable(x: number, z: number)
		Props.cylinder(hall, (at(x, 0.1, z)).Position, 0.2, 1.8, DARK, M.Wood)
		Props.cylinder(hall, (at(x, 1.35, z)).Position, 2.3, 0.5, DARK, M.Wood)
		Props.cylinder(hall, (at(x, 2.65, z)).Position, 0.3, 3.2, WOOD, M.Wood)
		trim(Props.cylinder(hall, (at(x, 2.81, z)).Position, 0.02, 2.6, MINT, M.Fabric))
	end
	do
		local x, z = -7.5, -8.5
		roundTable(x, z)
		deco("HamsterTray", Vector3.new(2.2, 0.35, 1.5), CFrame.new(x, 2.98, z), rgb(80, 140, 210), M.SmoothPlastic)
		deco("HamsterBedding", Vector3.new(2.0, 0.06, 1.3), CFrame.new(x, 3.17, z), rgb(240, 230, 200), M.Fabric)
		for dx = -1.05, 1.06, 0.3 do
			for _, s in { -1, 1 } do
				deco("CageWire", Vector3.new(0.04, 1.3, 0.04), CFrame.new(x + dx, 3.8, z + s * 0.72), WIRE, M.Metal)
			end
		end
		for dz = -0.7, 0.71, 0.35 do
			for _, s in { -1, 1 } do
				deco("CageWire", Vector3.new(0.04, 1.3, 0.04), CFrame.new(x + s * 1.07, 3.8, z + dz), WIRE, M.Metal)
			end
		end
		deco("CageTop", Vector3.new(2.2, 0.06, 1.5), CFrame.new(x, 4.47, z), WIRE, M.Metal)
		deco("WheelStand", Vector3.new(0.1, 0.7, 0.1), CFrame.new(x + 0.62, 3.5, z), rgb(80, 140, 210), M.SmoothPlastic)
		disc(hall, at(x + 0.55, 3.75, z), 0.35, 1.0, rgb(250, 200, 70), M.SmoothPlastic)
		disc(hall, at(x + 0.5, 3.75, z), 0.36, 0.8, rgb(240, 230, 200), M.SmoothPlastic)
		deco("HamsterHouse", Vector3.new(0.7, 0.5, 0.6), CFrame.new(x - 0.6, 3.45, z - 0.2), rgb(230, 90, 70), M.SmoothPlastic)
		deco("HamsterRoof", Vector3.new(0.8, 0.12, 0.7), CFrame.new(x - 0.6, 3.75, z - 0.2), rgb(250, 200, 70), M.SmoothPlastic)
		hamster(hall, (at(x + 0.5, 3.55, z)).Position, rgb(222, 170, 110))
		hamster(hall, (at(x - 0.3, 3.45, z + 0.35)).Position, rgb(240, 236, 226))
		trim(Props.cylinder(hall, (at(x - 1.0, 3.9, z + 0.78)).Position, 0.8, 0.25, rgb(210, 236, 245), M.Glass)).Transparency = 0.4
		local label = deco("HamsterSign", Vector3.new(1.8, 0.45, 0.08), CFrame.new(x, 3.25, z - 0.8), CREAM, M.Wood)
		PlazaHouses.boardText(label, "HAMSTERS", Enum.NormalId.Front, BLUE)
	end
	do
		local x, z = 7.5, -8.5
		roundTable(x, z)
		local golds = { rgb(255, 140, 40), rgb(255, 200, 80), rgb(240, 90, 50) }
		for i, dx in { -0.95, 0, 0.95 } do
			local center = at(x + dx, 3.45, z + (if i == 2 then 0.35 else -0.2))
			trim(Props.ball(hall, center.Position, 1.25, rgb(220, 240, 250), M.Glass)).Transparency = 0.7
			trim(Props.ball(hall, (center * CFrame.new(0, -0.1, 0)).Position, 1.05, rgb(90, 170, 220), M.SmoothPlastic)).Transparency = 0.55
			trim(Props.cylinder(hall, (center * CFrame.new(0, -0.5, 0)).Position, 0.12, 0.7, Props.pick(rng, BRIGHT), M.Pebble))
			local swim = CFrame.new(x + dx, 3.4, z + (if i == 2 then 0.35 else -0.2)) * CFrame.Angles(0, i * 1.7, 0)
			deco("Goldfish", Vector3.new(0.14, 0.28, 0.42), swim, golds[i], M.SmoothPlastic)
			deco("GoldfishTail", Vector3.new(0.05, 0.26, 0.2), swim * CFrame.new(0, 0, 0.28), golds[i], M.SmoothPlastic)
		end
		local label = deco("GoldfishSign", Vector3.new(1.8, 0.45, 0.08), CFrame.new(x, 3.25, z - 1.2), CREAM, M.Wood)
		PlazaHouses.boardText(label, "GOLDFISH", Enum.NormalId.Front, BLUE)
	end

	-- Pen toys: a rope tug for the puppies, a cardboard tunnel for the kittens.
	trim(Props.beam(hall, (at(-9.9, 0.2, -1.6)).Position, (at(-8.4, 0.2, -2.2)).Position, 0.18, rgb(220, 200, 160), 0.18, M.Fabric))
	for _, p in { Vector3.new(-9.9, 0.2, -1.6), Vector3.new(-8.4, 0.2, -2.2) } do
		trim(Props.ball(hall, (ORIGIN * CFrame.new(p)).Position, 0.38, rgb(200, 70, 60), M.Fabric))
	end
	disc(hall, at(9.0, 0.5, -2.0), 1.6, 0.9, rgb(190, 150, 100), M.Cardboard)
	disc(hall, at(9.0, 0.5, -2.0), 1.62, 0.7, rgb(60, 44, 30), M.Cardboard)

	-- Price tags along the shelf edges.
	local prices = { "$4", "$9", "$12", "$3", "$6", "$2", "$5", "$8", "$1" }
	for level, y in { 0.6, 2.8, 5 } do
		for k, dx in { -4.5, 0, 4.5 } do
			local tag = deco("PriceTag", Vector3.new(0.9, 0.35, 0.04), CFrame.new(shelfX + dx, y - 0.05, shelfZ - 0.93), CREAM, M.SmoothPlastic)
			PlazaHouses.boardText(tag, prices[(level - 1) * 3 + k], Enum.NormalId.Front, DARK)
		end
	end

	-- Tank cabinet doors, and a tub of flakes waiting on the lid.
	for i = 0, 4 do
		local z = -8 + i * 4
		deco("CabinetDoor", Vector3.new(0.08, 2.2, 3.6), CFrame.new(tankX - 1.54, 1.5, z), rgb(80, 130, 160), M.Wood)
		trim(Props.ball(hall, (at(tankX - 1.62, 1.6, z + 1.4)).Position, 0.2, BRASS, M.Metal))
	end
	trim(Props.cylinder(hall, (at(tankX - 0.6, 8.75, 7.5)).Position, 0.7, 0.6, rgb(250, 200, 70), M.SmoothPlastic))
	trim(Props.cylinder(hall, (at(tankX - 0.6, 9.15, 7.5)).Position, 0.12, 0.65, rgb(230, 90, 70), M.SmoothPlastic))

	-- Counter: a goldfish bowl by the till; a stool and an adoption board behind it.
	do
		local center = at(-13.4, 4.32, counterZ)
		trim(Props.ball(hall, center.Position, 1.2, rgb(220, 240, 250), M.Glass)).Transparency = 0.7
		trim(Props.ball(hall, (center * CFrame.new(0, -0.1, 0)).Position, 1.0, rgb(90, 170, 220), M.SmoothPlastic)).Transparency = 0.55
		deco("BowlFish", Vector3.new(0.14, 0.28, 0.42), CFrame.new(-13.4, 4.3, counterZ) * CFrame.Angles(0, 1.2, 0), rgb(255, 140, 40), M.SmoothPlastic)
		Props.cylinder(hall, (at(-9, 2.3, counterZ + 2.8)).Position, 0.25, 1.5, rgb(196, 70, 54), M.Fabric)
		Props.cylinder(hall, (at(-9, 1.1, counterZ + 2.8)).Position, 2.2, 0.3, IRON, M.Metal)
		Props.cylinder(hall, (at(-9, 0.05, counterZ + 2.8)).Position, 0.1, 1.2, IRON, M.Metal)

		local bz = D / 2 - 0.2
		deco("AdoptFrame", Vector3.new(7.4, 3.4, 0.1), CFrame.new(-9, 5.6, bz + 0.05), WOOD, M.Wood)
		deco("AdoptBoard", Vector3.new(7, 3, 0.12), CFrame.new(-9, 5.6, bz - 0.02), rgb(196, 156, 110), M.Cardboard)
		local coats = { rgb(214, 170, 110), rgb(70, 70, 76), rgb(240, 236, 228), rgb(232, 150, 70), rgb(150, 110, 76), rgb(120, 150, 80) }
		local n = 0
		for _, y in { 6.35, 4.85 } do
			for _, dx in { -2.2, 0, 2.2 } do
				n += 1
				local px, tilt = -9 + dx, CFrame.Angles(0, 0, rng:NextNumber(-0.12, 0.12))
				deco("Polaroid", Vector3.new(1.4, 1.25, 0.04), CFrame.new(px, y, bz - 0.1) * tilt, rgb(250, 248, 240), M.SmoothPlastic)
				deco("PolaroidPhoto", Vector3.new(1.15, 0.8, 0.03), CFrame.new(px, y, bz - 0.13) * tilt * CFrame.new(0, 0.12, 0), rgb(170, 210, 230), M.SmoothPlastic)
				deco("PolaroidPet", Vector3.new(0.55, 0.45, 0.02), CFrame.new(px, y, bz - 0.15) * tilt * CFrame.new(0, 0.05, 0), coats[n], M.SmoothPlastic)
				trim(Props.ball(hall, (at(px, y + 0.55, bz - 0.15)).Position, 0.16, rgb(220, 50, 50), M.SmoothPlastic))
			end
		end
		sign("AdoptSign", Vector3.new(5, 0.8, 0.12), CFrame.new(-9, 7.75, bz - 0.1), "ADOPT A FRIEND", rgb(196, 70, 54))
	end

	-- Left wall behind the cages: a pegboard of collars and leads above a basket of plush toys.
	do
		local x = -W / 2 + 0.15
		deco("Pegboard", Vector3.new(0.15, 4, 6), CFrame.new(x, 6.2, 12), rgb(196, 160, 112), M.Wood)
		sign("PegboardSign", Vector3.new(5, 0.8, 0.1), CFrame.new(x + 0.15, 8.7, 12) * CFrame.Angles(0, -math.pi / 2, 0), "COLLARS & LEADS", MINT)
		for i, z in { 9.8, 11.3, 12.8, 14.3 } do
			local color = BRIGHT[i]
			deco("Peg", Vector3.new(0.5, 0.08, 0.08), CFrame.new(x + 0.3, 7.5, z), IRON, M.Metal)
			disc(hall, at(x + 0.35, 7.0, z), 0.12, 0.9, color, M.Fabric)
			disc(hall, at(x + 0.35, 7.0, z), 0.14, 0.62, rgb(196, 160, 112), M.Wood)
			trim(Props.ball(hall, (at(x + 0.4, 6.5, z)).Position, 0.2, BRASS, M.Metal))
			deco("Peg", Vector3.new(0.5, 0.08, 0.08), CFrame.new(x + 0.3, 5.9, z), IRON, M.Metal)
			deco("Lead", Vector3.new(0.06, 1.5, 0.14), CFrame.new(x + 0.45, 5.15, z), BRIGHT[(i + 1) % #BRIGHT + 1], M.Fabric)
			disc(hall, at(x + 0.45, 4.3, z), 0.06, 0.5, BRIGHT[(i + 1) % #BRIGHT + 1], M.Fabric)
		end
		local basket = at(-17.6, 0, 13.6)
		Props.cylinder(hall, (basket * CFrame.new(0, 0.7, 0)).Position, 1.4, 2.4, rgb(186, 146, 96), M.Fabric)
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			local spot = basket * CFrame.new(math.cos(a) * 0.6, 1.5 + (k % 2) * 0.2, math.sin(a) * 0.6)
			if k % 3 == 0 then
				trim(Props.part(hall, Vector3.new(1.1, 0.3, 0.35), spot * CFrame.Angles(0, a, 0.5), CREAM, M.Fabric)).Name = "PlushBone"
			else
				trim(Props.ball(hall, spot.Position, 0.7, BRIGHT[k % #BRIGHT + 1], M.Fabric))
			end
		end
	end

	-- Back right corner: aquarium supplies on the wall and an old dog dozing on its cushion.
	do
		local x = W / 2 - 0.8
		for _, y in { 4.6, 6.6 } do
			part("SupplyShelf", Vector3.new(1.4, 0.2, 4.4), CFrame.new(x, y, 13), WOOD, M.Wood)
			for i = 0, 3 do
				local tub = at(x, y + 0.45, 11.3 + i * 1.1)
				trim(Props.cylinder(hall, tub.Position, 0.7, 0.75, BRIGHT[(i + math.floor(y)) % #BRIGHT + 1], M.SmoothPlastic))
				trim(Props.cylinder(hall, (tub * CFrame.new(0, 0.4, 0)).Position, 0.1, 0.8, CREAM, M.SmoothPlastic))
			end
		end
		for _, dz in { -0.4, 0.4 } do
			local foot = at(x - 0.1, 6.75, 15 + dz)
			trim(Props.beam(hall, foot.Position, (foot * CFrame.new(-0.4, 2.2, 0)).Position, 0.08, DARK, nil, M.Wood))
			disc(hall, foot * CFrame.new(-0.45, 2.55, 0) * CFrame.Angles(0, 0, 0.2), 0.5, 0.8, rgb(80, 140, 210), M.Fabric).Transparency = 0.3
		end
		sign("SupplySign", Vector3.new(4.2, 0.8, 0.1), CFrame.new(W / 2 - 0.15, 8.4, 13) * CFrame.Angles(0, math.pi / 2, 0), "AQUARIUM SUPPLIES", BLUE)
		trim(Props.cylinder(hall, (at(16.6, 0.25, 13.4)).Position, 0.5, 3.2, rgb(90, 130, 170), M.Fabric))
		trim(Props.cylinder(hall, (at(16.6, 0.52, 13.4)).Position, 0.06, 2.6, rgb(120, 160, 200), M.Fabric))
		local k = 0.95
		dog(hall, at(16.6, 0.5 - 0.6 * k, 13.4) * CFrame.Angles(0, 2.4, 0), rgb(200, 140, 70), CREAM, k)
		deco("ChewBone", Vector3.new(1, 0.3, 0.35), CFrame.new(15.0, 0.18, 11.6) * CFrame.Angles(0, 0.7, 0), CREAM, M.SmoothPlastic)
	end

	hall.Parent = folder
	return hall
end

----------------------------------------------------------------------------------------------------
-- Storefront on the square

function PetShop.build(plaza: Model, plazaFrame: CFrame): Model
	local hall = ensureInterior()
	local existing = plaza:FindFirstChild("PetShop")
	local shop: Model
	if existing and existing:IsA("Model") and existing:GetAttribute("LayoutVersion") == LAYOUT_VERSION then
		shop = existing
	else
		if existing then existing:Destroy() end
		local base = plazaFrame * SPOT
		-- The plain townhouse that used to stand on this corner makes way.
		for _, house in plaza:GetChildren() do
			if house:IsA("Model") and house.Name == "Townhouse" then
				local box = house:GetBoundingBox()
				local p = base:PointToObjectSpace(box.Position)
				if math.abs(p.X) < 8 and math.abs(p.Z) < 8 then house:Destroy() end
			end
		end
		local doorFace, leaf
		shop, doorFace, leaf = PlazaHouses.house(plaza, base, {
			width = 18, depth = 16, stories = 2,
			lower = MINT, upper = rgb(244, 234, 210), trim = rgb(250, 242, 224),
			shutter = BLUE, roof = rgb(186, 100, 62), door = rgb(70, 120, 66), balcony = true,
			shop = "PAWS & FINS", blade = "PETS", signColor = CREAM, doorSide = 1,
		}, Random.new(6160))
		shop.Name = "PetShop"
		shop:SetAttribute("LayoutVersion", LAYOUT_VERSION)
		leaf.Name = "StreetDoor"
		shop:SetAttribute("ExitFrame", doorFace * CFrame.new(0, 3.2, 4.5) * CFrame.Angles(0, math.pi, 0))
		-- A chalkboard on the step, a water bowl by the door and a cat napping on the window sill.
		local board = Props.part(shop, Vector3.new(2.8, 3.6, 0.2), doorFace * CFrame.new(-5, 1.8, 4), rgb(36, 44, 40), M.Slate)
		board.CanCollide = false
		PlazaHouses.boardText(board, "PUPPIES\nKITTENS\nPARROTS\nFISH", Enum.NormalId.Back)
		trim(Props.cylinder(shop, (doorFace * CFrame.new(2.4, 0.2, 1.2)).Position, 0.4, 1.2, rgb(60, 110, 160), M.Metal))
		local front = base * CFrame.new(0, 0, 8)
		cat(shop, front * CFrame.new(-5.5, 2.05, 0.6), rgb(232, 150, 70), true)
	end
	local leaf = shop:FindFirstChild("StreetDoor", true)
	local exit = hall:FindFirstChild("ExitDoor")
	local arrival, exitFrame = hall:GetAttribute("ArrivalFrame"), shop:GetAttribute("ExitFrame")
	if leaf and leaf:IsA("BasePart") and typeof(arrival) == "CFrame" then doorPrompt(leaf, "Enter", arrival) end
	if exit and exit:IsA("BasePart") and typeof(exitFrame) == "CFrame" then doorPrompt(exit, "Leave", exitFrame) end
	return shop
end

-- Startup repairs scan the whole map (city and islands included) before anyone spawns. Yield a
-- frame every 50 ms so the startup thread stays inside Roblox's ~10 s script timeout.
local breatheAt = os.clock()
local function breathe()
	if task and os.clock() - breatheAt > 0.05 then
		task.wait()
		breatheAt = os.clock()
	end
end

function PetShop.ensure(root: Instance)
	for _, plaza in root:GetDescendants() do
		breathe()
		if plaza:IsA("Model") and plaza.Name == "Plaza" then
			local frame = PlazaHouses.pavingFrame(plaza)
			if frame then PetShop.build(plaza, frame) end
		end
	end
end

return PetShop
