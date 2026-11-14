-- A compact harbour ferry, with a sheltered helm and four passenger seats.
-- The waterline is the origin and the bow points along local -Z.
local SmallFerry = {}
local WHITE = Color3.fromRGB(230, 231, 218)
local BLUE = Color3.fromRGB(36, 86, 112)
local DARK = Color3.fromRGB(34, 48, 55)
local WOOD = Color3.fromRGB(159, 126, 83)
local RED = Color3.fromRGB(211, 79, 48)

function SmallFerry.build(frame: CFrame, anchored: boolean?): Model
	local fixed = anchored == true
	local model = Instance.new("Model")
	model.Name = "SmallFerry"
	model:SetAttribute("HullLength", 30)
	model:SetAttribute("HullBeam", 12)
	model:SetAttribute("PassengerSeats", 4)
	model:SetAttribute("DriverSeat", "HelmSeat")
	model:SetAttribute("DryFloorHeight", 1.2)
	model:SetAttribute("DryFloorHalfBeam", 5.3)
	model:SetAttribute("DryFloorHalfLength", 14)

	local root = Instance.new("Part")
	root.Name = "HullRoot"
	root.Size = Vector3.new(8, 0.5, 22)
	root.CFrame = frame * CFrame.new(0, -0.4, 0)
	root.Transparency = 1
	root.Anchored, root.CanCollide, root.CanTouch = fixed, false, false
	root.RootPriority = 127
	root.CustomPhysicalProperties = PhysicalProperties.new(1.4, 0.45, 0.05, 100, 100)
	root.Parent = model
	model.PrimaryPart = root

	local function finish(piece: BasePart, name: string, color: Color3, collide: boolean?)
		piece.Name = name
		piece.Anchored, piece.CanCollide, piece.CanTouch = fixed, collide == true, false
		piece.TopSurface, piece.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		piece.Color, piece.Massless, piece.Parent = color, true, model
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = root, piece, piece
		return piece
	end
	local function part(name: string, size: Vector3, pos: Vector3, color: Color3, collide: boolean?): Part
		local p = Instance.new("Part")
		p.Size, p.CFrame = size, frame * CFrame.new(pos)
		finish(p, name, color, collide)
		return p
	end

	-- Solid low hull and a continuous walkable deck, with open sides for boarding.
	part("Hull", Vector3.new(11.4, 2.4, 29), Vector3.new(0, -0.15, 0), BLUE, true)
	part("Deck", Vector3.new(11.5, 0.25, 29), Vector3.new(0, 1.2, 0), WOOD, true)
	part("BowStripe", Vector3.new(11.45, 0.3, 0.18), Vector3.new(0, 0.65, -14.55), WHITE)
	part("SternStripe", Vector3.new(11.45, 0.3, 0.18), Vector3.new(0, 0.65, 14.55), WHITE)
	for _, side in { -1, 1 } do
		part("HullStripe", Vector3.new(0.15, 0.32, 29), Vector3.new(side * 5.73, 0.65, 0), WHITE)
		-- Break the rail amidships so passengers can step aboard from a dock.
		for _, z in { -10, 10 } do
			part("Rail", Vector3.new(0.18, 0.18, 8), Vector3.new(side * 5.45, 3.2, z), WHITE)
			for _, dz in { -3.8, 3.8 } do
				part("RailPost", Vector3.new(0.16, 2, 0.16), Vector3.new(side * 5.45, 2.2, z + dz), WHITE)
			end
		end
	end
	-- Raised pilothouse at the bow: open at the rear for access to the helm.
	part("CabinFront", Vector3.new(7, 4.5, 0.3), Vector3.new(0, 3.55, -10.2), WHITE, true)
	for _, side in { -1, 1 } do
		part("CabinSide", Vector3.new(0.3, 4.5, 5.5), Vector3.new(side * 3.35, 3.55, -7.5), WHITE, true)
		local window = part("CabinWindow", Vector3.new(0.34, 1.7, 3.6), Vector3.new(side * 3.35, 4.2, -7.6), BLUE)
		window.Material = Enum.Material.Glass
		window.Transparency = 0.35
	end
	part("CabinRoof", Vector3.new(7.6, 0.4, 6.4), Vector3.new(0, 5.95, -7.5), WHITE, true)
	part("Dashboard", Vector3.new(3, 1.3, 0.7), Vector3.new(0, 2, -9.3), DARK)

	local function seat(name: string, x: number, z: number, driver: boolean)
		part(name .. "Cushion", Vector3.new(1.7, 0.4, 1.6), Vector3.new(x, 1.8, z), BLUE)
		part(name .. "Back", Vector3.new(1.7, 1.5, 0.25), Vector3.new(x, 2.5, z + 0.75), BLUE)
		local chair = Instance.new(if driver then "VehicleSeat" else "Seat") :: Seat | VehicleSeat
		chair.Size, chair.CFrame, chair.Transparency = Vector3.new(1.7, 0.24, 1.5), frame * CFrame.new(x, 2.05, z), 1
		if chair:IsA("VehicleSeat") then
			chair.HeadsUpDisplay = false
			chair.MaxSpeed, chair.Torque, chair.TurnSpeed = 0, 0, 0
		end
		finish(chair, name, DARK)
		chair.CanTouch, chair.Disabled = not fixed, fixed
	end
	seat("HelmSeat", 0, -7.5, true)
	seat("FerryPassengerSeat1", -2.5, 1, false)
	seat("FerryPassengerSeat2", 2.5, 1, false)
	seat("FerryPassengerSeat3", -2.5, 5, false)
	seat("FerryPassengerSeat4", 2.5, 5, false)
	part("LifeRingPort", Vector3.new(0.25, 1.5, 1.5), Vector3.new(-5.8, 1.8, 11), RED)
	part("LifeRingStarboard", Vector3.new(0.25, 1.5, 1.5), Vector3.new(5.8, 1.8, 11), RED)
	return model
end

return SmallFerry
