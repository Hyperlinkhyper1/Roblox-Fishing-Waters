return function(kit)
	local P = kit.Palette
	local M = kit.Material

	-- Two posts on square feet.
	for i, x in { -2.75, 2.75 } do
		kit.block("LightFoot" .. i, Vector3.new(0.5, 0.2, 0.5), CFrame.new(x, 0.1, 0), P.DarkWood, M.Wood)
		kit.cylinder("LightPost" .. i, 0.28, 5.5, CFrame.new(x, 2.95, 0), P.Wood, M.Wood)
		kit.ball("LightPostCap" .. i, 0.32, CFrame.new(x, 5.76, 0), P.Brass, M.Metal)
	end

	-- Sagging cable: a parabola sampled into four straight runs.
	local top, sag, half = 5.45, 0.9, 2.75
	local function cableY(x)
		local t = x / half
		return top - sag * (1 - t * t)
	end
	local xs = { -half, -half / 2, 0, half / 2, half }
	local pts = {}
	for i, x in xs do
		pts[i] = Vector3.new(x, cableY(x), 0)
	end
	for i = 1, #pts - 1 do
		kit.beam("LightCable" .. i, pts[i], pts[i + 1], 0.06, 0.06, P.Iron, M.Fabric)
	end
	-- y on the straight runs (bulbs hang from the drawn cable, not the curve).
	local function onCable(x)
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			if x >= a.X and x <= b.X then
				return a.Y + (b.Y - a.Y) * (x - a.X) / (b.X - a.X)
			end
		end
		return top
	end

	local colours = {
		Color3.fromRGB(255, 90, 80),
		P.Glow,
		Color3.fromRGB(90, 210, 200),
		Color3.fromRGB(255, 230, 110),
		Color3.fromRGB(130, 220, 110),
		P.Glow,
		Color3.fromRGB(255, 120, 190),
		Color3.fromRGB(255, 170, 70),
		Color3.fromRGB(110, 170, 255),
	}
	for i = 1, 9 do
		local x = (i - 5) * 0.55
		local y = onCable(x)
		kit.cylinder("LightSocket" .. i, 0.14, 0.16, CFrame.new(x, y - 0.1, 0), P.Iron, M.Metal)
		local bulb = kit.ball("LightBulb" .. i, 0.36, CFrame.new(x, y - 0.34, 0), colours[i], M.Neon)
		if i == 5 then
			kit.light(bulb, P.Glow, 16, 1.2)
		end
	end
end
