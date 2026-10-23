-- Original geometry fixture reproduces the overlapping boat faces.
function Med.boat(parent: Instance, position: Vector3, facing: number, rng: Random, color: Color3): Model
	local m = newModel("Boat", parent)
	local base = CFrame.new(position) * CFrame.Angles(0, facing, 0)
	local length, width = rng:NextNumber(13, 17), rng:NextNumber(4.6, 5.6)
	local mid = length * 0.3
	local top, bottom = 1.4, -0.6

	part(m, Vector3.new(width, 0.4, mid * 2), base * CFrame.new(0, 0, 0), WOOD, M.WoodPlanks)
	for side = -1, 1, 2 do
		part(
			m,
			Vector3.new(0.4, top - bottom, mid * 2),
			base * CFrame.new(side * (width / 2 - 0.2), (top + bottom) / 2, 0),
			WHITEWASH,
			M.WoodPlanks
		)
		part(
			m,
			Vector3.new(0.5, 0.5, mid * 2 + 0.1),
			base * CFrame.new(side * (width / 2 - 0.15), top - 0.25, 0),
			color,
			M.WoodPlanks
		)
	end
	for _, e in { 1, -1 } do
		local function p(x: number, y: number, z: number): Vector3
			return base:PointToWorldSpace(Vector3.new(x, y, z * e))
		end
		local tl, tr = p(-width / 2, top, mid), p(width / 2, top, mid)
		local bl, br = p(-width / 2, bottom, mid), p(width / 2, bottom, mid)
		local tip = p(0, top + (if e == 1 then 1 else 0.4), length / 2)
		local keel = p(0, bottom, length / 2 - 2)
		local inside = p(0, 0.4, mid + 1)
		LowPoly.triangle(tl, bl, keel, inside, WHITEWASH, m, M.WoodPlanks)
		LowPoly.triangle(tl, keel, tip, inside, color, m, M.WoodPlanks)
		LowPoly.triangle(tr, br, keel, inside, WHITEWASH, m, M.WoodPlanks)
		LowPoly.triangle(tr, keel, tip, inside, color, m, M.WoodPlanks)
		LowPoly.triangle(bl, br, keel, inside, WHITEWASH, m, M.WoodPlanks)
		LowPoly.triangle(tl, tr, tip, inside, WOOD, m, M.WoodPlanks)
	end
	for _, z in { -mid * 0.5, mid * 0.5 } do
		part(m, Vector3.new(width - 0.8, 0.3, 1.2), base * CFrame.new(0, 0.7, z), WOOD, M.WoodPlanks)
	end
	if rng:NextNumber() < 0.5 then
		cylinder(m, base:PointToWorldSpace(Vector3.new(0, 4.5, mid * 0.5)), 8, 0.4, WOOD_DARK, M.Wood)
	else
		for side = -1, 1, 2 do
			beam(
				m,
				base:PointToWorldSpace(Vector3.new(side * 1, 1.2, -mid)),
				base:PointToWorldSpace(Vector3.new(side * 1.4, 1.2, mid)),
				0.3,
				WOOD,
				nil,
				M.Wood
			)
		end
	end
	return m
end
