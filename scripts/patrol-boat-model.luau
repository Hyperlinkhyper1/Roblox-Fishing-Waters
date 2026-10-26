local function loadPatrolBoat()
	-- PATROL_BOAT_SOURCE --
end
local PatrolBoat = loadPatrolBoat()
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
for _, frame in { CFrame.new(35, 72, -18), CFrame.new(-42, 19, 81) * CFrame.Angles(0, math.pi / 2, 0) } do
	for _, anchored in { false, true } do
		local model = PatrolBoat.build(frame, anchored)
		check(model.Name == "PatrolBoat" and model.Parent == nil, "PatrolBoat builder contract")
		check(
			model:GetAttribute("HullLength") == 63 and model:GetAttribute("HullBeam") == 18,
			"Hull dimensions match catalog"
		)
		check(model.PrimaryPart.Name == "HullRoot", "One physical root")
		check(
			(model.PrimaryPart.CFrame.Position - (frame * CFrame.new(0, -0.6, 0)).Position).Magnitude < 0.0001,
			"Correct waterline origin"
		)
		local parts, welds, helms, passengers = 0, 0, 0, 0
		local names = {}
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") then
				parts += 1
				local lamp = item.Name == "PortNavLight" or item.Name == "StarboardNavLight" or item.Name == "LightBarStrobe"
			if item ~= model.PrimaryPart and item.Name ~= "Windshield" and item.Name ~= "CabinSideWindow" and not lamp then
					check(
						item.Color[1] == item.Color[2] and item.Color[2] == item.Color[3]
							or math.abs(item.Color[1] - item.Color[3]) <= 10,
						"Neutral gray finish"
					)
				end
				names[item.Name] = (names[item.Name] or 0) + 1
				check(
					item.Anchored == anchored
						and item.CanTouch == (not anchored and (item:IsA("Seat") or item:IsA("VehicleSeat"))),
					"Preview and owned collision modes"
				)
				check(item.Size.X > 0 and item.Size.Y > 0 and item.Size.Z > 0, "Positive part sizes")
				for _, v in { item.CFrame.Position, item.CFrame.RightVector, item.CFrame.UpVector, item.CFrame.ZVector } do
					check(v.X == v.X and v.Y == v.Y and v.Z == v.Z, "Finite geometry: " .. item.Name)
				end
				if item ~= model.PrimaryPart then
					check(item.Massless, "Visible geometry cannot change handling mass")
				end
				if item.ClassName == "VehicleSeat" or item.ClassName == "Seat" then
					check(item.Disabled == anchored and not item.CanCollide, "Correct seating state")
					check((item.CFrame.LookVector - frame.LookVector).Magnitude < 0.0001, "Seats face the bow")
					if item.ClassName == "VehicleSeat" then
						helms += 1
						check(
							item.Name == "HelmSeat" and item.MaxSpeed == 0 and item.Torque == 0 and item.TurnSpeed == 0,
							"Shared controller owns propulsion"
						)
					else
						passengers += 1
					end
				end
			elseif item.ClassName == "WeldConstraint" then
				welds += 1
				check(item.Part0 == model.PrimaryPart and item.Part1 == item.Parent, "Each piece welds to hull root")
			end
		end
		check(parts < 520 and welds == parts - 1, "Bounded single assembly")
		check(helms == 1 and passengers == 2, "One helm and two outdoor passenger seats")
		check(not names.PassengerSeatNavigator and not names.NavCushion and not names.NavBackrest and not names.NavPedestal, "Cabin contains only the helm chair")
		check(model:GetAttribute("PassengerSeats") == passengers, "Passenger count matches model metadata")
		check(names.BilgePanel == 48 and names.BottomPanel == 48 and names.HullEndCap == 16, "Closed V hull")
		check(
			names.Foredeck == 32
				and names.Windshield == 2
				and names.BowRail == 8
				and names.RaisedBowHousing == 8
				and names.CabinRoof == 1,
			"Reference silhouette features"
		)
		-- The open central cockpit must remain traversable behind the windscreen.
		for _, z in { 5, 6.5, 8, 9.5, 11, 12.6, 14, 16, 18 } do
			for _, y in { 1.45, 2.5, 4.5 } do
				for _, item in model:GetDescendants() do
					if item.ClassName == "Part" and item.CanCollide then
						local p = frame:ToObjectSpace(item.CFrame).Position
						check(
							not (
									math.abs(p.X) < item.Size.X / 2 - 0.001
									and math.abs(y * 1.5 - p.Y) < item.Size.Y / 2 - 0.001
									and math.abs(z * 1.5 - p.Z) < item.Size.Z / 2 - 0.001
								),
							"Clear rear doorway and cabin aisle"
						)
					end
				end
			end
		end
	end
end
print(
	string.format("PatrolBoat geometry: %d checks passed (mock construction; no Studio rendering or physics)", checks)
)
