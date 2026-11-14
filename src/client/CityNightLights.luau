-- Lights the port city after dark. Builders tag window glass and lamp heads NightGlow (with a
-- GlowColor) and lamp lights NightLight; each also carries a GlowAt darkness between 0 and 1,
-- so windows come on one by one through dusk and go out again at dawn. A lit part becomes
-- Neon in its GlowColor. Parts are only written when their state flips, and the check runs
-- once a second (darkness only moves during dusk and dawn).
-- Tower masts carry an AviationBeacon that blinks red after dark.
--
-- The city has several hundred street lamps and canopy downlights, and every enabled light in
-- view costs the renderer. Only the nearest MAX_LIT[tier] lights within LIGHT_DISTANCE of the
-- camera are switched on; every other lamp head still glows Neon, so distant streets still read
-- as lit. The choice is refreshed twice a second, and only when the camera has moved, the
-- darkness changed, the graphics tier changed or lights streamed in or out.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DayNight = require(ReplicatedStorage.Shared.DayNight)

local CityNightLights = {}

local GLOW_TAG = "NightGlow"
local LIGHT_TAG = "NightLight"
local DEFAULT_AT = 0.5
local BEACON_TAG = "AviationBeacon"
local BEACON_AT = 0.3
local LIGHT_DISTANCE = 320
CityNightLights.LIGHT_DISTANCE = LIGHT_DISTANCE
local MAX_LIT = { 24, 40, 64 } -- by graphics tier: Performance, Balanced, Quality
CityNightLights.MAX_LIT = MAX_LIT
local REFRESH = 0.5
local MOVE_STUDS = 16 -- camera travel that forces a fresh choice
local rgb = Color3.fromRGB

export type Candidate = { position: Vector3, at: number }

-- Which lights to switch on: the nearest `limit` whose GlowAt the darkness has passed,
-- within `distance` of `focus`. Pure, so the check scripts can drive it directly.
function CityNightLights.choose<K>(lights: { [K]: Candidate }, focus: Vector3, darkness: number, limit: number, distance: number): { [K]: boolean }
	local near: { { key: K, d: number } } = {}
	for key, light in lights do
		if darkness >= light.at then
			local d = (light.position - focus).Magnitude
			if d <= distance then
				table.insert(near, { key = key, d = d })
			end
		end
	end
	if #near > limit then
		table.sort(near, function(a, b)
			return a.d < b.d
		end)
	end
	local chosen: { [K]: boolean } = {}
	for i = 1, math.min(limit, #near) do
		chosen[near[i].key] = true
	end
	return chosen
end

function CityNightLights.start()
	type Original = { material: Enum.Material, color: Color3 }
	local player = Players.LocalPlayer
	local tracked: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- glow part -> currently lit
	local originals: { [BasePart]: Original } = setmetatable({}, { __mode = "k" }) :: any
	local lights: { [Light]: Candidate } = {}
	local lit: { [Light]: boolean } = {}
	local lightsDirty = true
	local darkness = DayNight.darkness(DayNight.clockTime())

	local function threshold(instance: Instance): number
		local at = instance:GetAttribute("GlowAt")
		return if type(at) == "number" then at else DEFAULT_AT
	end

	local function tier(): number
		local value = player and player:GetAttribute("GraphicsTier")
		return if type(value) == "number" then math.clamp(math.floor(value), 1, 3) else 3
	end

	local function applyGlow(part: BasePart, on: boolean)
		if tracked[part] == on then
			return
		end
		tracked[part] = on
		local original = originals[part]
		if on then
			local glow = part:GetAttribute("GlowColor")
			part.Material = Enum.Material.Neon
			if typeof(glow) == "Color3" then
				part.Color = glow
			end
		elseif original then
			part.Material = original.material
			part.Color = original.color
		end
	end

	local function setLight(light: Light, on: boolean)
		if lit[light] ~= on then
			lit[light] = on
			light.Enabled = on
		end
	end

	local function add(instance: Instance)
		if instance:IsA("Light") then
			local holder = instance.Parent
			if lights[instance] or not (holder and holder:IsA("BasePart")) then
				return
			end
			-- Lamps are anchored, so the position is read once
			lights[instance] = { position = holder.Position, at = threshold(instance) }
			lit[instance] = nil
			setLight(instance, false) -- built enabled; wait for the next choice
			lightsDirty = true
		elseif instance:IsA("BasePart") then
			if tracked[instance] ~= nil then
				return
			end
			if not originals[instance] then
				originals[instance] = { material = instance.Material, color = instance.Color }
			end
			-- Built unlit: only a part that should glow needs writing
			tracked[instance] = false
			applyGlow(instance, darkness >= threshold(instance))
		end
	end

	local function remove(instance: Instance)
		if lights[instance :: Light] then
			lights[instance :: Light] = nil
			lit[instance :: Light] = nil
			lightsDirty = true
		end
		tracked[instance] = nil
	end

	for _, tag in { GLOW_TAG, LIGHT_TAG } do
		CollectionService:GetInstanceAddedSignal(tag):Connect(add)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
		for _, instance in CollectionService:GetTagged(tag) do
			add(instance)
		end
	end
	if player then
		player:GetAttributeChangedSignal("GraphicsTier"):Connect(function()
			lightsDirty = true
		end)
	end

	-- Aviation beacons on the tower masts blink red through the night: two writes per beacon
	-- per 1.6 s blink, only while it is dark, and only for beacons streamed in.
	local beacons: { [BasePart]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local BEACON_ON, BEACON_OFF = rgb(255, 44, 32), rgb(96, 24, 20)
	local function setBeacon(beacon: BasePart, on: boolean)
		if beacons[beacon] ~= on then
			beacons[beacon] = on
			beacon.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
			beacon.Color = if on then BEACON_ON else BEACON_OFF
		end
	end
	CollectionService:GetInstanceAddedSignal(BEACON_TAG):Connect(function(instance)
		if instance:IsA("BasePart") then
			beacons[instance] = false
		end
	end)
	CollectionService:GetInstanceRemovedSignal(BEACON_TAG):Connect(function(instance)
		beacons[instance :: BasePart] = nil
	end)
	for _, instance in CollectionService:GetTagged(BEACON_TAG) do
		if instance:IsA("BasePart") then
			beacons[instance] = false
		end
	end
	task.spawn(function()
		local blinkOn = false
		while true do
			blinkOn = not blinkOn and darkness >= BEACON_AT
			for beacon in beacons do
				setBeacon(beacon, blinkOn)
			end
			task.wait(if blinkOn then 0.5 else 1.1)
		end
	end)

	-- Windows and lamp heads: once a second, only while the darkness is changing
	task.spawn(function()
		while true do
			task.wait(1)
			local now = DayNight.darkness(DayNight.clockTime())
			if now ~= darkness then
				darkness = now
				lightsDirty = true
				for instance in tracked do
					if instance.Parent then
						applyGlow(instance :: BasePart, darkness >= threshold(instance))
					end
				end
			end
		end
	end)

	-- Lamp lights: the nearest few around the camera
	task.spawn(function()
		local lastFocus: Vector3? = nil
		while true do
			task.wait(REFRESH)
			local camera = workspace.CurrentCamera
			local focus = camera and camera.CFrame.Position
			if focus and (lightsDirty or not lastFocus or (focus - lastFocus).Magnitude > MOVE_STUDS) then
				lightsDirty, lastFocus = false, focus
				local chosen = CityNightLights.choose(lights, focus, darkness, MAX_LIT[tier()], LIGHT_DISTANCE)
				for light in lights do
					setLight(light, chosen[light] == true)
				end
			end
		end
	end)
end

return CityNightLights
