-- Appended by scripts/check-boat-furniture.mjs: builds each id in IDS and prints
-- one JSON line per item (parts, lights, fires, or an error).
local function num(x)
	return string.format("%.4f", x)
end
local function vec(v)
	return "[" .. num(v.X) .. "," .. num(v.Y) .. "," .. num(v.Z) .. "]"
end
local function esc(s)
	return (string.gsub(string.gsub(tostring(s), '[\\"]', ""), "[%c]", " "))
end
for _, id in IDS do
	local fields = { '"id":"' .. id .. '"' }
	if MISSING[id] then
		table.insert(fields, '"error":"missing module src/shared/BoatFurnitureModels/' .. id .. '.luau"')
	elseif LOAD_ERRORS[id] then
		table.insert(fields, '"error":"' .. esc(LOAD_ERRORS[id]) .. '"')
	elseif type(BoatFurniture.builders[id]) ~= "function" then
		table.insert(fields, '"error":"module must return function(kit)"')
	else
		local warnings = {}
		local oldWarn = warn
		warn = function(...)
			table.insert(warnings, table.concat({ ... }, " "))
		end
		local model = BoatFurniture.build(nil, CFrame.identity, id, { anchored = true })
		warn = oldWarn
		if #warnings > 0 then
			table.insert(fields, '"error":"' .. esc(table.concat(warnings, "; ")) .. '"')
		end
		local parts, lights, fires = {}, 0, 0
		for _, piece in model:GetDescendants() do
			if piece.ClassName == "PointLight" then
				lights += 1
			elseif piece.ClassName == "Fire" then
				fires += 1
			end
			if piece:IsA("BasePart") then
				local shape = "block"
				if piece.ClassName == "WedgePart" then
					shape = "wedge"
				elseif piece.Shape and piece.Shape.Name == "Cylinder" then
					shape = "cylinder"
				elseif piece.Shape and piece.Shape.Name == "Ball" then
					shape = "sphere"
				end
				local c = piece.CFrame
				local material = piece.Material and piece.Material.Name or "SmoothPlastic"
				table.insert(
					parts,
					'{"n":"' .. esc(piece.Name) .. '","s":"' .. shape .. '","z":' .. vec(piece.Size)
						.. ',"p":' .. vec(c.Position) .. ',"r":[' .. vec(c.RightVector) .. "," .. vec(c.UpVector)
						.. "," .. vec(c.ZVector) .. '],"c":"#' .. piece.Color:ToHex() .. '","m":"' .. material
						.. '","t":' .. num(piece.Transparency or 0) .. "}"
				)
			end
		end
		table.insert(fields, '"lights":' .. lights)
		table.insert(fields, '"fires":' .. fires)
		table.insert(fields, '"parts":[' .. table.concat(parts, ",") .. "]")
	end
	print("{" .. table.concat(fields, ",") .. "}")
end
