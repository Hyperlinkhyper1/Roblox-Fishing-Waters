-- Move decorative city-building parts into compact per-building descriptions. Solid parts stay
-- on the server for physics; clients rebuild the optional dressing at a controlled rate.
local HttpService = game:GetService("HttpService")
local CityDetail = {}

local function building(model: Instance): boolean
	return model:IsA("Model") and (string.match(model.Name, "^CityBlock%d+$") ~= nil
		or string.match(model.Name, "^CityBuilding%d+$") ~= nil
		or string.match(model.Name, "^DockWarehouse%d+$") ~= nil)
end

local function prepareModel(model: Instance)
	if model:GetAttribute("CityDetailData") then return end
	local detail, originals = {}, {}
	local anchor: Vector3? = nil
	for _, part in model:GetChildren() do
		-- Leave interactive, collidable and complicated descendants exactly as they are.
		if not part:IsA("Part") or part.CanCollide or part.CanQuery or #part:GetChildren() > 0 then continue end
		anchor = anchor or part.Position
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = part.CFrame:GetComponents()
		local glow = part:GetAttribute("GlowColor")
		local record = {
			part.Name, part.Size.X, part.Size.Y, part.Size.Z,
			x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22,
			part.Color.R, part.Color.G, part.Color.B, part.Material.Name, part.Shape.Name,
			part.Transparency, part.Reflectance, part.CastShadow,
			part:HasTag("NightGlow"), part:HasTag("AviationBeacon"),
			if typeof(glow) == "Color3" then { glow.R, glow.G, glow.B } else false,
			part:GetAttribute("GlowAt") or false,
		}
		table.insert(detail, record)
		table.insert(originals, part)
	end
	if #detail > 0 then
		-- Publish the complete description before deleting anything, including on baked maps.
		model:SetAttribute("CityDetailAnchor", anchor)
		model:SetAttribute("CityDetailData", HttpService:JSONEncode(detail))
		for _, part in originals do part:Destroy() end
		model:AddTag("CityDetail")
	end
end

function CityDetail.prepare(city: Instance)
	local ground = city:FindFirstChild("Ground")
	if not ground then return end
	local resumed = os.clock()
	for _, model in ground:GetDescendants() do
		if os.clock() - resumed > 0.004 then
			task.wait()
			resumed = os.clock()
		end
		if building(model) then prepareModel(model) end
	end
	-- The entire stop is pinned atomically for the ride. Keep its collision, signs,
	-- lights and controls, but do not send hundreds of loose decorations with it.
	local station = city:FindFirstChild("CityMetroStop")
	if station then
		for _, room in station:GetChildren() do
			if room:IsA("Model") and room.Name:match("^Metro") then
				prepareModel(room)
				if os.clock() - resumed > 0.004 then task.wait(); resumed = os.clock() end
			end
		end
	end
end

return CityDetail
