local UDim2 = {
	fromScale = function(x, y)
		return { x, y }
	end,
}
local function loadTugboat()
	-- TUGBOAT_SOURCE --
end
local Tugboat = loadTugboat()
local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end
local function localPosition(frame, p)
	return frame:ToObjectSpace(p.CFrame).Position
end
local partCount = 0
for _, frame in { CFrame.new(), CFrame.new(83, 5, -61) * CFrame.Angles(0, 1.17, 0) } do
	for _, anchored in { false, true } do
		local model = Tugboat.build(frame, anchored)
		local root = model.PrimaryPart
		check(root and root.Name == "HullRoot" and not root.CanCollide, "Invisible root must not block the deck")
		check(model:GetAttribute("HullLength") == 30 and model:GetAttribute("DryFloorHeight") == 1.6, "Hull attributes set")
		local parts, seats, deck, steps = {}, {}, {}, {}
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") then
				table.insert(parts, item)
				local position = localPosition(frame, item)
				for _, n in
					{
						item.Size.X,
						item.Size.Y,
						item.Size.Z,
						position.X,
						position.Y,
						position.Z,
						item.CFrame.RightVector.X,
						item.CFrame.UpVector.Y,
						item.CFrame.ZVector.Z,
					}
				do
					check(n == n and math.abs(n) < 1000, "Geometry must be finite and bounded: " .. item.Name)
				end
				check(
					item.Size.X > 0.001 and item.Size.Y > 0.001 and item.Size.Z > 0.001,
					"Geometry cannot contain degenerate parts: " .. item.Name
				)
				check(item.Anchored == anchored, "Anchoring must match preview/live construction")
				if item ~= root then
					local weld = item:FindFirstChildOfClass("WeldConstraint")
					check(
						item.Massless and weld and weld.Part0 == root and weld.Part1 == item,
						"Every detail must stay welded to the hull"
					)
				end
				if item:IsA("VehicleSeat") or item:IsA("Seat") then
					table.insert(seats, item)
					check(
						item.Disabled == anchored and item.CanTouch == not anchored,
						"Only live seats accept passengers"
					)
				end
				if item.Name == "WorkingDeck" then
					table.insert(deck, item)
					check(
						item.CanCollide and math.abs(position.Y + item.Size.Y / 2 - 1.6) < 0.0001,
						"Working deck is flush at dry-floor height"
					)
					check(math.abs(position.X) + item.Size.X / 2 < 5.8, "Deck strips stay inside the hull")
				elseif item.Name == "StairStep" then
					table.insert(steps, item)
				end
			end
		end
		partCount = #parts
		check(#parts < 1200, "Detailed tugboat stays within its assembly budget")
		check(
			#seats == 3 and model:FindFirstChild("HelmSeat"):IsA("VehicleSeat"),
			"Tugboat has a working helm and two crew seats"
		)
		-- Continuous center deck from bow to stern.
		for z = -14.5, 14.5, 0.5 do
			local supported = false
			for _, p in deck do
				local pos = localPosition(frame, p)
				if math.abs(pos.X) < 0.01 and math.abs(z - pos.Z) <= p.Size.Z / 2 then
					supported = true
				end
			end
			check(supported, "Continuous deck supports the center route at z=" .. z)
		end
		-- Stairs climb from the aft deck to the bridge deck in small steps.
		table.sort(steps, function(a, b)
			return localPosition(frame, a).Z > localPosition(frame, b).Z
		end)
		check(#steps == 7, "Seven stair steps")
		local previous = 1.6
		for _, p in steps do
			local top = localPosition(frame, p).Y + p.Size.Y / 2
			check(top - previous > 0 and top - previous <= 0.5 and p.CanCollide, "Stair rise is walkable")
			previous = top
		end
		check(math.abs(previous - 4.45) < 0.001, "Top step meets the bridge deck")
		-- Bridge route from the stair head to the helm: wheelhouse doorway and cabin clear for an avatar.
		for _, p in parts do
			if p.CanCollide and p.Name ~= "BridgeDeck" and p.Name ~= "StairStep" and p.Name ~= "Deckhouse" then
				local pos = localPosition(frame, p)
				local inRoute = pos.Z + p.Size.Z / 2 > -3.8 and pos.Z - p.Size.Z / 2 < 3.7
				if inRoute and not p:IsA("WedgePart") then
					check(
						math.abs(pos.X) - p.Size.X / 2 >= 1.09
							or pos.Y - p.Size.Y / 2 > 10.5
							or pos.Y + p.Size.Y / 2 < 4.46,
						"Bridge route and doorway must not be blocked: " .. p.Name
					)
				end
			end
		end
		for _, name in
			{
				"Fender",
				"BowFender",
				"WheelhouseWindow",
				"WinchDrum",
				"Mast",
				"RadarScanner",
				"PropellerBlade",
				"HeadlightLens",
				"NameBoard",
				"MachineryBox",
			}
		do
			check(model:FindFirstChild(name) ~= nil, "Reference detail exists: " .. name)
		end
	end
end
print(
	string.format(
		"Tugboat geometry: %d checks passed; %d physical parts, 3 seats, continuous deck, walkable stairs and clear wheelhouse route (recording mocks).",
		checks,
		partCount
	)
)
