local checks = 0
local function check(ok, reason)
	checks += 1
	assert(ok, reason)
end
for _, frame in { CFrame.new(), CFrame.new(85, 20, -47) * CFrame.Angles(0, math.pi / 2, 0) } do
	for _, anchored in { false, true } do
		local boat = RacingSpeedboat.build(frame, anchored)
		check(boat.Name == "RacingSpeedboat" and boat.Parent == nil, "Builder returns an unparented racing model")
		check(
			boat:GetAttribute("HullLength") == 36 and boat:GetAttribute("HullBeam") == 9.6,
			"Long narrow hull metadata matches the catalog"
		)
		check(
			boat.PrimaryPart.Name == "HullRoot" and not boat.PrimaryPart.CanCollide,
			"Invisible root does not block the cockpit"
		)
		local parts, welds, drivers, passengers = 0, 0, 0, 0
		local names = {}
		for _, part in boat:GetDescendants() do
			if part:IsA("BasePart") then
				parts += 1
				names[part.Name] = (names[part.Name] or 0) + 1
				check(part.Anchored == anchored, "All parts follow the requested anchor state")
				check(
					part.Size.X > 0 and part.Size.Y > 0 and part.Size.Z > 0,
					"Every facet has positive dimensions: " .. part.Name
				)
				for _, axis in
					{ part.CFrame.Position, part.CFrame.RightVector, part.CFrame.UpVector, part.CFrame.ZVector }
				do
					check(
						axis.X == axis.X and axis.Y == axis.Y and axis.Z == axis.Z,
						"No degenerate hull facets: " .. part.Name
					)
				end
				if part ~= boat.PrimaryPart then
					check(part.Massless, "Decorations must not shift hull mass")
				end
				if part:IsA("VehicleSeat") or part:IsA("Seat") then
					check(
						part.Disabled == anchored and part.CanTouch == not anchored,
						"Preview seats are disabled; launched seats are usable"
					)
					check(
						(part.CFrame.LookVector - frame.LookVector).Magnitude < 0.0001,
						"All bucket seats face the bow"
					)
					if part:IsA("VehicleSeat") then
						drivers += 1
						check(
							part.Name == "HelmSeat" and part.MaxSpeed == 0 and part.Torque == 0,
							"Shared server controller owns helm physics"
						)
					else
						passengers += 1
					end
				end
			elseif part:IsA("WeldConstraint") then
				welds += 1
				check(
					part.Part0 == boat.PrimaryPart and part.Part1 == part.Parent,
					"Every visible part is welded to the root"
				)
			end
		end
		check(drivers == 1 and passengers == 3, "Four working cockpit seats")
		check(welds == parts - 1 and parts < 600, "Detailed hull stays within a bounded, single welded assembly")
		check(
			names.BucketCushion == 4 and names.Foredeck and names.SternSunpad and names.OutboardCover,
			"Reference silhouette includes four seats, pointed foredeck, sunpad and outboard"
		)
		check(names.BottomPanel and names.BilgePanel and names.HullEndCap, "Hull has a sealed underside and end caps")
		-- Keep a standing avatar's central cockpit path clear at chest height.
		for _, z in { -1, 1, 3, 5 } do
			for _, part in boat:GetDescendants() do
				if part:IsA("Part") and part.CanCollide then
					local localFrame = frame:ToObjectSpace(part.CFrame)
					local center = localFrame.Position
					check(
						not (
								math.abs(center.X) < part.Size.X / 2
								and math.abs(center.Y - 3) < part.Size.Y / 2
								and math.abs(center.Z - z) < part.Size.Z / 2
							),
						"Cockpit walking lane stays open: " .. part.Name
					)
				end
			end
		end
	end
end
print(string.format("Racing speedboat model: %d construction and assembly checks passed (recording mocks)", checks))
