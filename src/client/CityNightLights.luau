-- Lights the port city after dark. Builders tag window glass and lamp heads NightGlow (with a
-- GlowColor) and lamp lights NightLight; each also carries a GlowAt darkness between 0 and 1,
-- so windows come on one by one through dusk and go out again at dawn. A lit part becomes
-- Neon in its GlowColor; a light is simply enabled. Parts are only written when their state
-- flips, and the check runs once a second (darkness only moves during dusk and dawn).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DayNight = require(ReplicatedStorage.Shared.DayNight)

local CityNightLights = {}

local GLOW_TAG = "NightGlow"
local LIGHT_TAG = "NightLight"
local DEFAULT_AT = 0.5

function CityNightLights.start()
	type Original = { material: Enum.Material, color: Color3 }
	local tracked: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- instance -> currently lit
	local originals: { [BasePart]: Original } = setmetatable({}, { __mode = "k" }) :: any
	local darkness = DayNight.darkness(DayNight.clockTime())

	local function threshold(instance: Instance): number
		local at = instance:GetAttribute("GlowAt")
		return if type(at) == "number" then at else DEFAULT_AT
	end

	local function apply(instance: Instance, lit: boolean)
		if tracked[instance] == lit then
			return
		end
		tracked[instance] = lit
		if instance:IsA("Light") then
			instance.Enabled = lit
		elseif instance:IsA("BasePart") then
			local original = originals[instance]
			if lit then
				local glow = instance:GetAttribute("GlowColor")
				instance.Material = Enum.Material.Neon
				if typeof(glow) == "Color3" then
					instance.Color = glow
				end
			elseif original then
				instance.Material = original.material
				instance.Color = original.color
			end
		end
	end

	local function add(instance: Instance)
		if tracked[instance] ~= nil then
			return
		end
		if instance:IsA("BasePart") then
			if not originals[instance] then
				originals[instance] = { material = instance.Material, color = instance.Color }
			end
			-- Built unlit: only a part that should glow needs writing
			tracked[instance] = false
		end
		apply(instance, darkness >= threshold(instance))
	end

	local function remove(instance: Instance)
		tracked[instance] = nil
	end

	for _, tag in { GLOW_TAG, LIGHT_TAG } do
		CollectionService:GetInstanceAddedSignal(tag):Connect(add)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
		for _, instance in CollectionService:GetTagged(tag) do
			add(instance)
		end
	end

	task.spawn(function()
		while true do
			task.wait(1)
			local now = DayNight.darkness(DayNight.clockTime())
			if now ~= darkness then
				darkness = now
				for instance in tracked do
					if instance.Parent then
						apply(instance, darkness >= threshold(instance))
					end
				end
			end
		end
	end)
end

return CityNightLights
