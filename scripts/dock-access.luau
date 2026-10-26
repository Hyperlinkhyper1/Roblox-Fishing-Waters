local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

for _, angle in { 0, 0.73, 2.1 } do
	for _, saved in { "fresh", "blocks", "stoneRamp" } do
		local base = Instance.new("Model")
		local dockFrame = CFrame.new(100, 0, -240) * CFrame.Angles(0, angle, 0)
		base:SetAttribute("OwnerUserId", 42)
		base:SetAttribute("DockDetailVersion", 1)
		base:SetAttribute("BoatDockFrame", dockFrame)
		local unrelated = Props.part(base, Vector3.new(2, 2, 2), dockFrame * CFrame.new(24, 6, 12), QUAY)
		local old = {}
		if saved == "blocks" then
			for _, side in { -1, 1 } do
				table.insert(
					old,
					Props.part(base, Vector3.new(7, 2.6, 3.2), dockFrame * CFrame.new(side * 17, 3.1, 6.4), QUAY)
				)
			end
		end
		local oldAccess = nil
		if saved == "stoneRamp" then
			oldAccess = Instance.new("Model")
			oldAccess.Name = "DockAccess"
			oldAccess:SetAttribute("LayoutVersion", 1)
			oldAccess.Parent = base
			Props.part(oldAccess, Vector3.new(7, 0.4, 8.8), dockFrame * CFrame.new(-17, 4.3, 4), QUAY)
		end
		if saved ~= "fresh" then
			Harbour.ensureDocks({
				GetDescendants = function()
					return { base }
				end,
			})
		else
			ensureDockAccess(base, dockFrame)
		end
		local access = base:FindFirstChild("DockAccess")
		check(access and #access:GetChildren() == 2, "Both piers need ramps on fresh and saved maps")
		for _, item in old do
			check(item.Parent == nil, "Old raised landings must not protrude through the ramps")
		end
		check(
			unrelated.Parent == base and base:GetAttribute("OwnerUserId") == 42,
			"Migration preserves plot ownership and other parts"
		)
		check(base:GetAttribute("DockDetailVersion") == 1, "Access repair does not rebuild the decorated piers")
		check(access:GetAttribute("LayoutVersion") == 2, "Saved stone ramps receive the timber layout")
		if oldAccess then
			check(oldAccess.Parent == nil, "Saved stone ramp model is replaced")
		end
		for _, gangway in access:GetChildren() do
			local ramp = gangway:FindFirstChild("DockRamp")
			check(ramp and ramp.Transparency == 1, "Each gangway has a continuous hidden walking surface")
			local planks, rails, stringers = 0, 0, 0
			for _, part in gangway:GetChildren() do
				if part.Name == "GangwayPlank" then
					planks += 1
					check(not part.CanCollide and not part.CanQuery, "Plank seams do not snag characters or navigation")
				elseif part.Name == "Handrail" then
					rails += 1
				elseif part.Name == "Stringer" then
					stringers += 1
				elseif part.Name == "RailPost" then
					local p = dockFrame:PointToObjectSpace(part.Position)
					local x = dockFrame:PointToObjectSpace(ramp.Position).X
					check(
						math.abs(p.X - x) - part.Size.X / 2 >= 3.5,
						"Posts leave the entire seven-stud walking lane open"
					)
				end
			end
			check(
				planks == 10 and rails == 4 and stringers == 2,
				"Each timber gangway has boards, supports and handrails"
			)
			local landing = gangway:FindFirstChild("QuayLanding")
			local landingLocal = dockFrame:ToObjectSpace(landing.CFrame)
			check(
				landing.CanCollide and math.abs(landingLocal.Position.Y + landing.Size.Y / 2 - 5.91) < 0.001,
				"Landing meets the quay without a high step"
			)
			check(math.abs(landingLocal.Position.Z - landing.Size.Z / 2 - 8) < 0.001, "Landing starts at the ramp head")
			check(ramp.CanCollide and ramp.Anchored, "Ramp must support walking")
			check(ramp.Size.X >= 7 and ramp.CFrame.UpVector.Y > 0.9, "Ramp has wide, gentle walking clearance")
			local localFrame = dockFrame:ToObjectSpace(ramp.CFrame)
			local top = localFrame * CFrame.new(0, ramp.Size.Y / 2, 0)
			local previous = nil
			for z = 0, 8, 0.25 do
				-- Intersect the actual emitted inclined top plane with a vertical
				-- ray. Checking only its bounding box would miss the dock riser.
				local normal = top.UpVector
				local y = top.Position.Y - normal.Z * (z - top.Position.Z) / normal.Y
				if previous then
					check(y >= previous and y - previous < 0.1, "Walking surface rises continuously")
				end
				if z == 0 then
					check(math.abs(y - 3.2) < 0.001, "Ramp foot matches pier height")
				end
				if z == 8 then
					check(math.abs(y - 5.9) < 0.001, "Ramp reaches quay height before its solid front face")
				end
				previous = y
			end
			-- The coloured edge projects 0.6 studs in front of the quay.
			local edgeY = top.Position.Y - top.UpVector.Z * (7.4 - top.Position.Z) / top.UpVector.Y
			check(edgeY >= 5.69, "Quay trim does not form another high step above the ramp")
		end
		ensureDockAccess(base, dockFrame)
		check(
			base:FindFirstChild("DockAccess") == access and #access:GetChildren() == 2,
			"Repeated startup keeps the same ramps"
		)
	end
end
print(
	"Dock access: "
		.. checks
		.. " ramp surface, rotated plot and saved-map migration checks passed (recording geometry)."
)
