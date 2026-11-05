-- Shared settings fixture for the actual water renderers and quality policy.
local waterQualityCallbacks = {}
local waterSettingsAvailable, waterQualityReadable = true, true
local savedWaterQuality = 10
local waterSettings = setmetatable({
	GetPropertyChangedSignal = function(_, property)
		assert(property == "SavedQualityLevel", "Only graphics quality should affect water layers")
		return {
			Connect = function(_, callback)
				table.insert(waterQualityCallbacks, callback)
			end,
		}
	end,
}, {
	__index = function(_, property)
		assert(property == "SavedQualityLevel", "Water must not read restricted rendering settings")
		assert(waterQualityReadable, "Quality is not readable")
		return { Value = savedWaterQuality }
	end,
})
local function UserSettings()
	assert(waterSettingsAvailable, "Settings unavailable")
	return {
		GetService = function(_, name)
			assert(name == "UserGameSettings", "Use client graphics preferences")
			return waterSettings
		end,
	}
end
local function setWaterQuality(quality)
	savedWaterQuality = quality
	for _, callback in waterQualityCallbacks do
		callback()
	end
end
local function loadWaterQuality()
	-- WATER_QUALITY --
end
dependencies.WaterQuality = loadWaterQuality()
for quality = 0, 10 do
	setWaterQuality(quality)
	assert(dependencies.WaterQuality.layeredEnabled() == (quality >= 7), "Live graphics changes must select safe water layers")
end
waterQualityReadable = false
setWaterQuality(10)
assert(not dependencies.WaterQuality.layeredEnabled(), "Unreadable quality must use Terrain water")
waterQualityReadable = true
setWaterQuality(10)
assert(dependencies.WaterQuality.layeredEnabled(), "Quality reads must recover")
waterSettingsAvailable = false
assert(not loadWaterQuality().layeredEnabled(), "Unavailable settings must use Terrain water")
waterSettingsAvailable = true
print("PASS water quality policy, automatic/unavailable fallback and live graphics changes")
