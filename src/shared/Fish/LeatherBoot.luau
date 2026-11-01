return {
	Name = "Leather Boot",
	Rarity = "Junk",
	RarityDenominator = 50,
	MinKg = 0.4,
	AverageKg = 0.8,
	MaxKg = 1.2,
	BaseValue = 1,
	Fight = 0,
	Shapes = {
		Normal = { "#.", "##" },
	},
	Build = function(b, kit)
		local rgb = kit.rgb
		local leather, trim = rgb(119, 76, 49), rgb(88, 54, 35)
		local rubber, welt, thread = rgb(37, 32, 29), rgb(78, 54, 38), rgb(167, 131, 91)
		local lace, brass = rgb(57, 43, 33), rgb(155, 120, 66)
		local function cylinder(name, center, height, length, width, color)
			local part = b:part(
				name,
				"Part",
				Vector3.new(height, length, width),
				CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2),
				color
			)
			part.Shape = Enum.PartType.Cylinder
			return part
		end
		-- Straight sides meet round end caps tangentially, keeping the sole flat
		-- underneath without the old square toe and sharp heel corners.
		local function roundedSole(name, center, length, width, height, radius, color)
			local straight = length - radius * 2
			b:part(name, "Part", Vector3.new(straight, height, width), CFrame.new(center), color)
			for _, side in { -1, 1 } do
				cylinder(name, center + Vector3.new(side * straight / 2, 0, 0), height, radius * 2, width, color)
			end
		end
		roundedSole("Sole", Vector3.new(0.025, -0.282, 0), 0.86, 0.366, 0.063, 0.17, rubber)
		roundedSole("Welt", Vector3.new(0.025, -0.241, 0), 0.872, 0.378, 0.023, 0.176, welt)
		roundedSole("Heel", Vector3.new(-0.245, -0.326, 0), 0.285, 0.326, 0.04, 0.1, rubber)
		roundedSole("LowerLeather", Vector3.new(0.025, -0.216, 0), 0.817, 0.332, 0.045, 0.16, leather)

		-- One long vamp gives the toe a continuous curve. The ankle overlaps the
		-- round shaft below the laces, so it reads as shaped leather rather than balls.
		b:ellipsoid("Foot", CFrame.new(0.025, -0.143, 0), Vector3.new(0.828, 0.286, 0.352), leather)
		b:ellipsoid("Ankle", CFrame.new(-0.205, -0.069, 0), Vector3.new(0.342, 0.36, 0.322), leather)
		cylinder("Shaft", Vector3.new(-0.215, 0.108, 0), 0.356, 0.31, 0.31, leather)
		b:ellipsoid(
			"Quarter",
			CFrame.new(-0.1, 0.065, 0) * CFrame.Angles(0, 0, 0.32),
			Vector3.new(0.34, 0.43, 0.32),
			leather
		)
		b:ellipsoid("HeelCounter", CFrame.new(-0.322, -0.135, 0), Vector3.new(0.148, 0.206, 0.306), trim)
		b:ellipsoid("Tongue", CFrame.new(0.035, 0.103, 0) * CFrame.Angles(0, 0, 0.4), Vector3.new(0.13, 0.386, 0.18), trim)
		for _, side in { -1, 1 } do
			b:ellipsoid(
				"LaceFacing",
				CFrame.new(0.061, 0.102, side * 0.065) * CFrame.Angles(0, 0, 0.42),
				Vector3.new(0.083, 0.35, 0.043),
				leather
			)
		end

		-- A recessed dark oval beneath a rolled leather rim suggests a lined opening.
		cylinder("Opening", Vector3.new(-0.215, 0.287, 0), 0.006, 0.281, 0.281, rgb(29, 22, 19))
		local segments = 32
		for index = 0, segments - 1 do
			local a, c = index * math.pi * 2 / segments, (index + 1) * math.pi * 2 / segments
			local start = Vector3.new(-0.215 + math.cos(a) * 0.149, 0.304, math.sin(a) * 0.149)
			local finish = Vector3.new(-0.215 + math.cos(c) * 0.149, 0.304, math.sin(c) * 0.149)
			b:ellipsoid(
				"RolledCuff",
				CFrame.lookAt((start + finish) / 2, finish) * CFrame.Angles(0, math.pi / 2, 0),
				Vector3.new((finish - start).Magnitude + 0.055, 0.036, 0.036),
				trim
			)
		end

		-- Brass eyelets and lifted crisscross laces follow the sloping tongue.
		local normal = Vector3.new(1, 0.42, 0).Unit
		local rows = {}
		for index = 0, 4 do
			local y = -0.015 + index * 0.058
			local x = 0.142 - index * 0.026
			rows[index + 1] = Vector3.new(x, y, 0)
			for _, side in { -1, 1 } do
				local position = Vector3.new(x, y, side * 0.065)
				local frame = CFrame.lookAt(position, position + normal)
				b:ellipsoid("Eyelet", frame, Vector3.new(0.027, 0.027, 0.009), brass)
				b:ellipsoid("EyeletInset", frame + normal * 0.004, Vector3.new(0.013, 0.013, 0.005), lace)
			end
		end
		for index = 1, #rows - 1 do
			for _, side in { -1, 1 } do
				local a = rows[index] + Vector3.new(0, 0, side * 0.065) + normal * 0.009
				local c = rows[index + 1] - Vector3.new(0, 0, side * 0.065) + normal * 0.009
				local middle = (a + c) / 2 + normal * (if side == 1 then 0.012 else 0.021)
				b:limb(a, middle, 0.01, lace, "Lace")
				b:limb(middle, c, 0.01, lace, "Lace")
			end
		end
		local knot = rows[#rows] + normal * 0.019
		b:ellipsoid("LaceKnot", CFrame.new(knot), Vector3.new(0.027, 0.021, 0.029), lace)
		for _, side in { -1, 1 } do
			local tip = knot + Vector3.new(0.022, -0.063, side * 0.049)
			b:limb(knot, tip, 0.009, lace, "LaceEnd")
		end

		-- Small separate stitches follow the curved welt, including the round toe.
		local straight, radius = 0.52, 0.17
		local perimeter = straight * 2 + math.pi * radius * 2
		local function stitchPoint(distance)
			if distance < straight then
				return Vector3.new(-0.235 + distance, -0.226, 0.174)
			elseif distance < straight + math.pi * radius then
				local angle = math.pi / 2 - (distance - straight) / radius
				return Vector3.new(0.285 + math.cos(angle) * 0.166, -0.226, math.sin(angle) * 0.174)
			elseif distance < straight * 2 + math.pi * radius then
				return Vector3.new(0.285 - (distance - straight - math.pi * radius), -0.226, -0.174)
			end
			local angle = -math.pi / 2 - (distance - straight * 2 - math.pi * radius) / radius
			return Vector3.new(-0.235 + math.cos(angle) * 0.166, -0.226, math.sin(angle) * 0.174)
		end
		for index = 0, 27 do
			local distance = index * perimeter / 28
			b:limb(stitchPoint(distance), stitchPoint(distance + 0.014), 0.005, thread, "WeltStitch")
		end
		-- The pull tab and restrained toe wear keep the found-boot character.
		b:limb(Vector3.new(-0.36, 0.235, -0.026), Vector3.new(-0.386, 0.345, -0.026), 0.022, trim, "PullTab")
		b:limb(Vector3.new(-0.386, 0.345, -0.026), Vector3.new(-0.386, 0.345, 0.026), 0.022, trim, "PullTab")
		b:limb(Vector3.new(-0.386, 0.345, 0.026), Vector3.new(-0.36, 0.235, 0.026), 0.022, trim, "PullTab")
		for index = 0, 2 do
			local x, z = 0.315 + index * 0.018, 0.065 - index * 0.018
			local y = -0.143 + 0.143 * math.sqrt(1 - ((x - 0.025) / 0.414) ^ 2 - (z / 0.176) ^ 2)
			b:ellipsoid(
				"ToeScuff",
				CFrame.new(x, y + 0.001, z) * CFrame.Angles(0, 0, -0.4),
				Vector3.new(0.026, 0.003, 0.008),
				rgb(149, 107, 72)
			)
		end
		b.model:SetAttribute("ViewDirection", Vector3.new(0.85, 0.55, 1))
	end,
}
