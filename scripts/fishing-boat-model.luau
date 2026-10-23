-- Run node scripts/check-fishing-boat-model.cjs; the shared recording Roblox
-- mock and production source are inserted by that runner.
local hullTriangles = {}
local function loadFishingBoat()
	-- FISHING_BOAT_SOURCE --
end
local FishingBoat = loadFishingBoat()
local checks = 0
local function check(condition, message)
	checks += 1
	assert(condition, message)
end
local function close(a, b)
	return (a - b).Magnitude < 0.0001
end
local function contains(item, localFrame, x, y, z)
	local position = localFrame.Position
	return math.abs(x - position.X) < item.Size.X / 2 - 0.00001
		and math.abs(y - position.Y) < item.Size.Y / 2 - 0.00001
		and math.abs(z - position.Z) < item.Size.Z / 2 - 0.00001
end

for _, frame in
	{
		CFrame.new(35, 72, -18),
		CFrame.new(-42, 19, 81) * CFrame.Angles(0, math.pi / 2, 0),
	}
do
	for _, anchored in { false, true } do
		hullTriangles = {}
		local boat = FishingBoat.build(frame, anchored)
		check(boat.Parent == nil and boat.Name == "FishingBoat", "unparented FishingBoat model contract")
		check(boat:GetAttribute("HullLength") == 22 and boat:GetAttribute("HullBeam") == 9.6, "larger hull dimensions")
		check(
			boat:GetAttribute("PassengerSeats") == 2 and boat:GetAttribute("DriverSeat") == "HelmSeat",
			"three-seat model metadata"
		)
		check(boat.PrimaryPart.Name == "HullRoot", "primary hull root")
		check(
			close(boat.PrimaryPart.CFrame.Position, (frame * CFrame.new(0, -0.4, 0)).Position),
			"waterline root convention"
		)
		local parts, welds, helms, passengers, hullPanels, decks = 0, 0, 0, 0, 0, 0
		local equipment = {}
		local geometry = {}
		for _, item in boat:GetDescendants() do
			if item:IsA("BasePart") then
				parts += 1
				geometry[item] = frame:ToObjectSpace(item.CFrame)
				check(item.Anchored == anchored, "anchor mismatch on " .. item.Name)
				check(item.Size.X > 0 and item.Size.Y > 0 and item.Size.Z > 0, "positive geometry on " .. item.Name)
				for _, value in
					{ item.CFrame.Position, item.CFrame.RightVector, item.CFrame.UpVector, item.CFrame.ZVector }
				do
					check(
						value.X == value.X and value.Y == value.Y and value.Z == value.Z,
						"finite geometry on " .. item.Name
					)
				end
				if item ~= boat.PrimaryPart then
					check(item.Massless, "all visible geometry must be massless")
				end
				if item.ClassName == "VehicleSeat" then
					helms += 1
					check(
						item.Name == "HelmSeat" and item.Disabled == anchored and item.CanTouch == not anchored,
						"helm seating mode"
					)
					check(
						close(item.CFrame.Position, (frame * CFrame.new(0, 2.04, 5.9)).Position),
						"stern helm location"
					)
					check(close(item.CFrame.LookVector, frame.LookVector), "helm faces the bow")
					check(
						item.MaxSpeed == 0 and item.Torque == 0 and item.TurnSpeed == 0 and not item.CanCollide,
						"controller owns driving physics"
					)
				elseif item.ClassName == "Seat" then
					passengers += 1
					check(
						item.Disabled == anchored and item.CanTouch == not anchored and not item.CanCollide,
						"passenger seating mode"
					)
					check(close(item.CFrame.LookVector, frame.LookVector), "fishing seats face the open bow")
				elseif item.Name == "HullPanel" then
					hullPanels += 1
					check(item.ClassName == "WedgePart" and item.Size.X == 0.18 and item.CanCollide, "thin hull facets")
				elseif item.Name == "WorkingDeck" then
					decks += 1
					check(
						item.CanCollide and math.abs(geometry[item].Position.Y + item.Size.Y / 2 - 1.1) < 0.0001,
						"continuous level working deck"
					)
				end
				equipment[item.Name] = (equipment[item.Name] or 0) + 1
			elseif item.ClassName == "WeldConstraint" then
				welds += 1
				check(item.Part0 == boat.PrimaryPart and item.Part1 == item.Parent, "connected root weld")
			end
		end
		check(helms == 1 and passengers == 2, "exactly one driver and two passengers")
		check(hullPanels == 80 and decks == 15, "faceted hull and fitted plank deck")
		check(parts < 400 and welds == parts - 1, "bounded single welded assembly")
		check(
			equipment.BilgePanel == 40
				and equipment.BottomPanel == 40
				and equipment.HullEndCap == 16
				and equipment.BowCap == 6,
			"sealed shaped underside and both end caps"
		)
		check(equipment.Keel == 5, "keel must follow the rising bow and stern")
		-- Intersect the generated triangle faces, rather than their bounding boxes.
		local function undersideY(x, z)
			for _, facet in hullTriangles do
				if facet.name == "BilgePanel" or facet.name == "BottomPanel" then
					local a, b, c = facet.a, facet.b, facet.c
					local det = (b.Z - c.Z) * (a.X - c.X) + (c.X - b.X) * (a.Z - c.Z)
					if math.abs(det) > 0.00001 then
						local u = ((b.Z - c.Z) * (x - c.X) + (c.X - b.X) * (z - c.Z)) / det
						local v = ((c.Z - a.Z) * (x - c.X) + (a.X - c.X) * (z - c.Z)) / det
						if u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001 then
							return u * a.Y + v * b.Y + (1 - u - v) * c.Y
						end
					end
				end
			end
			return nil
		end
		for _, z in { -7, -3, 0, 3, 7, 10 } do
			for _, x in { -1.5, -0.75, -0.15, 0, 0.15, 0.75, 1.5 } do
				local y = undersideY(x, z)
				check(y ~= nil and y < -0.72, "underside has a hole below the working deck")
				check(math.abs(y - undersideY(-x, z)) < 0.0001, "underwater hull must be symmetric")
			end
		end
		check(
			undersideY(0, 0) < -1.4 and undersideY(3.7, 0) > undersideY(0, 0) + 0.5,
			"bottom must narrow down into a real V hull"
		)
		check(undersideY(0, -10.5) > -0.3 and undersideY(0, 10.5) > -1.1, "keel must sweep upward into bow and stern")
		check(
			equipment.RubberFender == 6 and equipment.FishCrate == 2 and equipment.CoiledRope == 20,
			"working boat deck equipment"
		)
		check(
			equipment.CabinSideWindow == 4 and equipment.CabinFrontWindow == 2 and equipment.CabinRearWindow == 2,
			"glazed cream wheelhouse"
		)
		check(
			equipment.FishingRod == 2
				and equipment.FishingBuoy == 3
				and equipment.LifeRing == 12
				and equipment.Mast == 1,
			"fishing and safety silhouette"
		)

		-- Sample the entrance and helm approach at avatar body/head heights. All
		-- matching collision boxes are axis aligned in the boat's local frame.
		for _, x in { -1.1, 0, 1.1 } do
			for _, z in { -5, 0, 2.8, 3.0, 3.2, 4.4, 5.9, 6.65 } do
				for _, y in { 1.15, 2.0, 3.5, 5.5, 6.45 } do
					for item, localFrame in geometry do
						if item.CanCollide and item.ClassName == "Part" then
							check(
								not contains(item, localFrame, x, y, z),
								"blocked center aisle or full-height doorway: " .. item.Name
							)
						end
					end
				end
			end
		end
		for _, x in { 0, -3.1, 3.1 } do
			for _, z in { 3.2, 5.5, 7.8 } do
				local supported = false
				for item, localFrame in geometry do
					if item.Name == "WorkingDeck" and contains(item, localFrame, x, 1.0, z) then
						supported = true
					end
				end
				check(supported, "helm approach and side walkways need deck support")
			end
		end
		for item in geometry do
			if
				item.Name == "FishingRod"
				or item.Name == "CoiledRope"
				or item.Name == "FishCrate"
				or item.Name == "MastRigging"
				or item.Name == "HelmConsole"
			then
				check(not item.CanCollide and not item.CanTouch, "equipment cannot snag players: " .. item.Name)
			end
		end
		print(
			`FishingBoat: anchored={anchored}, parts={parts}, welds={welds}, three seats, glazed cabin, clear doorway and deck walkways`
		)
	end
end
print(`Fishing boat model: {checks} recording-mock checks passed; rendering, boarding and sailing require Studio`)
