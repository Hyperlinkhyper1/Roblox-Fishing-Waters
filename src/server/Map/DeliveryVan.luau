-- The little HARBOUR DIRECT delivery van (WebShopService). Built from plain parts, all
-- anchored and non-colliding so it never shoves anyone off the road. Van-local -Z is the
-- front and y = 0 is the road. `drive` slides the whole model between two frames, `fade`
-- brings it in and out of view at the ends of its route, `doors` swings the rear doors, and
-- `parcel` throws a box from the open back onto a storage rack.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local DeliveryVan = {}

local rgb = Color3.fromRGB
local M = Enum.Material
local WHITE = rgb(240, 242, 238)
local ACCENT = rgb(32, 116, 168)
local TRIM = rgb(46, 50, 56)
local TYRE = rgb(28, 28, 30)
local GLASS = rgb(70, 98, 120)
local CARDBOARD = rgb(186, 140, 88)

DeliveryVan.LENGTH = 13
-- Where parcels leave the van: just inside the open back, at waist height.
local TAILGATE = CFrame.new(0, 3.2, 6.2)
-- Rear door hinges sit on the back corners; doors open outward to the sides.
local DOOR_HINGES = { { side = -1, x = -3.0 }, { side = 1, x = 3.0 } }

local function part(parent: Instance, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.CFrame = offset
	piece.Color = color
	piece.Material = material or M.SmoothPlastic
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanTouch = false
	piece.CanQuery = false
	piece.CastShadow = true
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece:SetAttribute("Offset", offset) -- van-local, for `drive`
	piece:SetAttribute("Look", piece.Transparency)
	piece.Parent = parent
	return piece
end

local function sideSign(parent: BasePart, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Livery"
	gui.Face = face
	gui.CanvasSize = Vector2.new(430, 300)
	gui.LightInfluence = 1
	gui.Parent = parent
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.05, 0.12)
	title.Size = UDim2.fromScale(0.9, 0.3)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = ACCENT
	title.Text = "HARBOUR DIRECT"
	title.Parent = gui
	local strap = Instance.new("TextLabel")
	strap.BackgroundTransparency = 1
	strap.Position = UDim2.fromScale(0.08, 0.66)
	strap.Size = UDim2.fromScale(0.84, 0.16)
	strap.Font = Enum.Font.GothamBold
	strap.TextScaled = true
	strap.TextColor3 = TRIM
	strap.Text = "fishing gear · delivered in 5 minutes"
	strap.Parent = gui
end

-- Builds the van at `frame` (its ground point, facing the frame's LookVector).
function DeliveryVan.build(parent: Instance, frame: CFrame): Model
	local van = Instance.new("Model")
	van.Name = "DeliveryVan"
	van.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local root = part(van, "Root", Vector3.new(1, 1, 1), CFrame.new(0, 1.6, 0), WHITE)
	root.Transparency = 1
	root:SetAttribute("Look", 1)
	van.PrimaryPart = root

	part(van, "Chassis", Vector3.new(5.6, 0.7, 12.6), CFrame.new(0, 1.55, 0), TRIM, M.Metal)
	local box = part(van, "CargoBox", Vector3.new(6, 5.8, 8.4), CFrame.new(0, 4.8, 2.1), WHITE)
	sideSign(box, Enum.NormalId.Left)
	sideSign(box, Enum.NormalId.Right)
	part(van, "Stripe", Vector3.new(6.06, 0.7, 8.42), CFrame.new(0, 3.1, 2.1), ACCENT)
	part(van, "RoofRail", Vector3.new(5.4, 0.25, 8), CFrame.new(0, 7.82, 2.1), TRIM, M.Metal)
	-- Cab: a lower box in front of the cargo body with a raked windscreen.
	part(van, "Cab", Vector3.new(5.8, 3.6, 3.9), CFrame.new(0, 3.7, -4.05), WHITE)
	part(van, "CabRoof", Vector3.new(5.8, 0.9, 2.6), CFrame.new(0, 5.95, -3.4), WHITE)
	part(van, "CabStripe", Vector3.new(5.86, 0.7, 3.92), CFrame.new(0, 3.1, -4.05), ACCENT)
	local screen = part(van, "Windscreen", Vector3.new(5.3, 2.3, 0.15), CFrame.new(0, 5.5, -5.05) * CFrame.Angles(math.rad(-28), 0, 0), GLASS, M.Glass)
	screen.Transparency = 0.25
	screen:SetAttribute("Look", 0.25)
	for _, x in { -2.93, 2.93 } do
		local window = part(van, "SideWindow", Vector3.new(0.12, 1.6, 2.2), CFrame.new(x, 5.3, -3.8), GLASS, M.Glass)
		window.Transparency = 0.25
		window:SetAttribute("Look", 0.25)
		part(van, "Mirror", Vector3.new(0.5, 0.7, 0.3), CFrame.new(x + math.sign(x) * 0.35, 5.0, -5.0), TRIM)
	end
	part(van, "Bumper", Vector3.new(6, 0.8, 0.5), CFrame.new(0, 1.9, -6.25), TRIM)
	part(van, "Grille", Vector3.new(3.4, 1, 0.12), CFrame.new(0, 2.9, -6.02), TRIM, M.DiamondPlate)
	part(van, "RearBumper", Vector3.new(6, 0.7, 0.45), CFrame.new(0, 1.85, 6.4), TRIM)
	for _, x in { -2.2, 2.2 } do
		local head = part(van, "Headlight", Vector3.new(1.1, 0.6, 0.12), CFrame.new(x, 3.0, -6.03), rgb(255, 246, 214), M.Neon)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Range = 22
		light.Angle = 60
		light.Brightness = 1.4
		light.Color = rgb(255, 238, 200)
		light.Parent = head
		part(van, "Taillight", Vector3.new(0.5, 1.3, 0.12), CFrame.new(x * 1.25, 3.3, 6.32), rgb(214, 36, 30), M.Neon)
	end
	for _, x in { -2.8, 2.8 } do
		for _, z in { -3.9, 3.9 } do
			part(van, "Tyre", Vector3.new(0.9, 2.4, 2.4), CFrame.new(x, 1.2, z), TYRE, M.Rubber).Shape = Enum.PartType.Cylinder
			part(van, "Hubcap", Vector3.new(0.95, 1.2, 1.2), CFrame.new(x, 1.2, z), rgb(186, 190, 194), M.Metal).Shape = Enum.PartType.Cylinder
		end
	end
	-- Rear doors carry their hinge as attributes so `place` can swing them (and their stripes).
	for index, hinge in DOOR_HINGES do
		local door = part(van, "RearDoor" .. index, Vector3.new(2.95, 5.5, 0.16), CFrame.new(hinge.x - hinge.side * 1.5, 4.75, 6.38), WHITE)
		door:SetAttribute("HingeX", hinge.x)
		door:SetAttribute("Side", hinge.side)
		local stripe = part(van, "RearDoorStripe" .. index, Vector3.new(2.95, 0.7, 0.18), CFrame.new(hinge.x - hinge.side * 1.5, 3.1, 6.38), ACCENT)
		stripe:SetAttribute("DoorOf", "RearDoor" .. index)
	end
	-- A few boxes stacked inside, seen through the open doors.
	for index, offset in { Vector3.new(-1.4, 2.6, 4.5), Vector3.new(1.3, 2.6, 4.2), Vector3.new(-1.2, 3.8, 3.6) } do
		part(van, "Load" .. index, Vector3.new(1.6, 1.2, 1.6), CFrame.new(offset), CARDBOARD, M.Cardboard)
	end
	van.Parent = parent
	DeliveryVan.place(van, frame, 0)
	return van
end

-- Puts every part where it belongs for a van standing at `frame`, doors opened by `open`
-- (0 shut, 1 wide).
function DeliveryVan.place(van: Model, frame: CFrame, open: number)
	local swing = math.rad(105) * math.clamp(open, 0, 1)
	for _, piece in van:GetChildren() do
		if not piece:IsA("BasePart") then
			continue
		end
		local offset = piece:GetAttribute("Offset")
		if typeof(offset) ~= "CFrame" then
			continue
		end
		local doorName = piece:GetAttribute("DoorOf")
		local door = if type(doorName) == "string" then van:FindFirstChild(doorName) else piece
		local hingeX = door and door:GetAttribute("HingeX")
		local side = door and door:GetAttribute("Side")
		if type(hingeX) == "number" and type(side) == "number" and swing > 0 then
			local hinge = CFrame.new(hingeX, 0, 6.38)
			offset = hinge * CFrame.Angles(0, side * swing, 0) * hinge:Inverse() * offset
		end
		piece.CFrame = frame * offset
	end
end

-- Moves the van from `from` to `to` over `duration` seconds. Yields until it gets there.
function DeliveryVan.drive(van: Model, from: CFrame, to: CFrame, duration: number, style: Enum.EasingDirection)
	local elapsed = 0
	while elapsed < duration and van.Parent do
		elapsed += RunService.Heartbeat:Wait()
		local alpha = TweenService:GetValue(math.min(elapsed / duration, 1), Enum.EasingStyle.Sine, style)
		DeliveryVan.place(van, from:Lerp(to, alpha), 0)
	end
end

-- Fades the van in (`shown` true) or out over `duration` seconds without yielding.
function DeliveryVan.fade(van: Model, shown: boolean, duration: number)
	for _, piece in van:GetDescendants() do
		if piece:IsA("BasePart") then
			local look = piece:GetAttribute("Look") or 0
			if shown then
				piece.Transparency = 1
			end
			TweenService:Create(piece, TweenInfo.new(duration), { Transparency = if shown then look else 1 }):Play()
		elseif piece:IsA("SurfaceGui") then
			piece.Enabled = shown
		elseif piece:IsA("SpotLight") then
			piece.Enabled = shown
		end
	end
end

-- Swings the rear doors open or shut over `duration` seconds at a parked `frame`. Yields.
function DeliveryVan.doors(van: Model, frame: CFrame, opening: boolean, duration: number)
	local elapsed = 0
	while elapsed < duration and van.Parent do
		elapsed += RunService.Heartbeat:Wait()
		local alpha = TweenService:GetValue(math.min(elapsed / duration, 1), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		DeliveryVan.place(van, frame, if opening then alpha else 1 - alpha)
	end
end

-- Throws one parcel from the van's open back (parked at `frame`) in an arc to `target`,
-- where it shrinks away. Doesn't yield; `landed` runs when it arrives.
function DeliveryVan.parcel(parent: Instance, frame: CFrame, target: Vector3, landed: (() -> ())?)
	local box = Instance.new("Part")
	box.Name = "DeliveryParcel"
	box.Size = Vector3.new(1.3, 1, 1.3)
	box.Color = CARDBOARD
	box.Material = M.Cardboard
	box.Anchored, box.CanCollide, box.CanTouch, box.CanQuery = true, false, false, false
	local tape = Instance.new("Part")
	tape.Name = "Tape"
	tape.Size = Vector3.new(0.3, 1.02, 1.32)
	tape.Color = ACCENT
	tape.Anchored, tape.CanCollide, tape.CanTouch, tape.CanQuery = true, false, false, false
	tape.Parent = box
	local start = (frame * TAILGATE).Position
	box.CFrame = CFrame.new(start)
	tape.CFrame = box.CFrame
	box.Parent = parent
	task.spawn(function()
		local distance = (target - start).Magnitude
		local duration = math.clamp(distance / 28, 0.8, 2.2)
		local peak = math.max(start.Y, target.Y) + math.clamp(distance * 0.35, 4, 18)
		local elapsed = 0
		while elapsed < duration and box.Parent do
			elapsed += RunService.Heartbeat:Wait()
			local t = math.min(elapsed / duration, 1)
			local flat = start:Lerp(target, t)
			-- Quadratic arc through `peak` at the middle of the throw.
			local y = (1 - t) ^ 2 * start.Y + 2 * (1 - t) * t * (2 * peak - (start.Y + target.Y) / 2) + t ^ 2 * target.Y
			box.CFrame = CFrame.new(flat.X, y, flat.Z) * CFrame.Angles(t * 5, t * 3, 0)
			tape.CFrame = box.CFrame
		end
		if box.Parent then
			local shrink = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(box, shrink, { Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1 }):Play()
			TweenService:Create(tape, shrink, { Size = Vector3.new(0.05, 0.1, 0.1), Transparency = 1 }):Play()
			task.wait(0.27)
			box:Destroy()
		end
		if landed then
			landed()
		end
	end)
end

return DeliveryVan
