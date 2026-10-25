local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

for _, angle in { 0, 0.73, 2.1 } do
	for _, saved in { false, true } do
		local base = Instance.new("Model")
		local dockFrame = CFrame.new(100, 0, -240) * CFrame.Angles(0, angle, 0)
		base:SetAttribute("OwnerUserId", 42)
		base:SetAttribute("DockDetailVersion", 1)
		base:SetAttribute("BoatDockFrame", dockFrame)
		local unrelated = Props.part(base, Vector3.new(2, 2, 2), dockFrame * CFrame.new(24, 6, 12), QUAY)
		local old = {}
		if saved then
			for _, side in { -1, 1 } do
				table.insert(
					old,
					Props.part(base, Vector3.new(7, 2.6, 3.2), dockFrame * CFrame.new(side * 17, 3.1, 6.4), QUAY)
				)
			end
		end
		if saved then
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
		for _, ramp in access:GetChildren() do
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
