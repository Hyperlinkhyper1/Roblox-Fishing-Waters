-- Extra water surfaces overlap Terrain's simpler water renderer at lower quality.
-- Reserve them for the high graphics tier; Terrain still supplies water and swimming.
local WaterQuality = {}
local MIN_LAYERED_QUALITY = 7
local layered = false

local ok, settings = pcall(function()
	return UserSettings():GetService("UserGameSettings")
end)

if ok and settings then
	local function refresh()
		local readable, quality = pcall(function()
			return settings.SavedQualityLevel.Value
		end)
		-- Automatic (0) does not expose the engine's current quality to game scripts.
		-- Use the single Terrain surface when the rendering tier is unknown.
		layered = readable and type(quality) == "number" and quality >= MIN_LAYERED_QUALITY
	end

	refresh()
	settings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(refresh)
end

function WaterQuality.layeredEnabled(): boolean
	return layered
end

return WaterQuality
