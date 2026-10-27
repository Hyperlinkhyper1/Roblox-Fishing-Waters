local UDim2 = {
	fromScale = function(x, y)
		return { x, y }
	end,
}
local function loadTrawler()
	-- TRAWLER_SOURCE --
end
local Trawler = loadTrawler()
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
		local model = Trawler.build(frame, anchored)
		local root = model.PrimaryPart
		check(root and root.Name == "HullRoot" and not root.CanCollide, "Invisible root must not block the deck")
		check(
			model:GetAttribute("HullLength") == 44 and model:GetAttribute("HullBeam") == 14.8,
			"Hull matches catalog bounds"
		)
		local parts, seats, deck = {}, {}, {}
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
						item.CanCollide and math.abs(position.Y + item.Size.Y / 2 - 1.45) < 0.0001,
						"Working deck is flush at dry-floor height"
					)
				end
			end
		end
		partCount = #parts
		check(#parts < 1600, "Detailed trawler stays within its assembly budget")
		check(
			#seats == 3 and model:FindFirstChild("HelmSeat"):IsA("VehicleSeat"),
			"Trawler has a working helm and two fishing seats"
		)
		-- Continuous center deck from the aft doorway to the transom and through the cabin.
		for z = -11, 21, 0.5 do
			local supported = false
			for _, p in deck do
				local pos = localPosition(frame, p)
				if math.abs(pos.X) < 0.01 and math.abs(z - pos.Z) <= p.Size.Z / 2 then
					supported = true
				end
			end
			check(supported, "Continuous deck supports the center route at z=" .. z)
		end
		-- Rear doorway: 2.5 studs wide, clear from deck to above an avatar's head.
		for _, p in parts do
			if p.CanCollide and p.Name ~= "WorkingDeck" then
				local pos = localPosition(frame, p)
				local nearDoor = math.abs(pos.Z + 3.25) <= p.Size.Z / 2 + 0.15
				if nearDoor then
					check(
						math.abs(pos.X) - p.Size.X / 2 >= 1.25
							or pos.Y - p.Size.Y / 2 > 7.4
							or pos.Y + p.Size.Y / 2 < 1.5,
						"Walk-in doorway must not be blocked: " .. p.Name
					)
				end
			end
		end
		for _, name in
			{
				"NetDrum",
				"GantryCrossbar",
				"TireFender",
				"Windscreen",
				"RegistrationPlate",
				"PropellerBlade",
				"Rudder",
				"HeadlightLens",
			}
		do
			check(model:FindFirstChild(name) ~= nil, "Reference detail exists: " .. name)
		end
	end
end
print(
	string.format(
		"Trawler geometry: %d checks passed; %d physical parts, 3 seats, continuous deck and clear cabin doorway (recording mocks).",
		checks,
		partCount
	)
)
