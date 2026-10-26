-- Sound groups keep source volumes intact, including dynamically updated thunder.
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Settings = {}
local started = false
local master, music, effects
local performance, device, preset

local function applyPerformance()
	Lighting.GlobalShadows = performance.Shadows
	Players.LocalPlayer:SetAttribute("WeatherEffectsEnabled", performance.WeatherEffects)
end

local function detectPerformance()
	-- Input capabilities are a device heuristic, not a hardware benchmark. A
	-- controller connected to a computer must not lower its preset on its own.
	local tier = 3
	device = "Computer"
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		device, tier = "Mobile / tablet", 1
	elseif
		UserInputService.GamepadEnabled
		and not UserInputService.KeyboardEnabled
		and not UserInputService.TouchEnabled
	then
		device, tier = "Console", 2
	end
	local ok, quality = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	-- Zero means Roblox's automatic quality, not the lowest graphics level.
	if ok and type(quality) == "number" and quality > 0 then
		tier = math.min(tier, if quality <= 3 then 1 elseif quality <= 6 then 2 else 3)
	end
	preset = if tier == 1 then "Performance" elseif tier == 2 then "Balanced" else "Quality"
	performance = { Shadows = tier == 3, WeatherEffects = tier >= 2 }
end

function Settings.description()
	Settings.start()
	return device .. " · " .. preset .. " preset on join. Changes apply until you rejoin."
end

function Settings.start()
	if started then
		return
	end
	started = true
	detectPerformance()
	-- Apply before the profile/remote is available, even if loading takes time.
	applyPerformance()
	master = Instance.new("SoundGroup")
	master.Name, master.Parent = "PlayerMaster", SoundService
	master.Volume = 1
	music = Instance.new("SoundGroup")
	music.Name, music.Parent = "PlayerMusic", master
	music.Volume = 1
	effects = Instance.new("SoundGroup")
	effects.Name, effects.Parent = "PlayerEffects", master
	effects.Volume = 1
	local function bind(instance)
		if not instance:IsA("Sound") then
			return
		end
		local function route()
			local group = instance.SoundGroup
			-- Preserve an authored group's effects/volume by parenting that group
			-- under our mixer; ungrouped sounds use their AudioCategory attribute.
			if group and group ~= music and group ~= effects and group ~= master then
				local top = group
				while top.Parent and top.Parent:IsA("SoundGroup") and top.Parent ~= master do
					top = top.Parent
				end
				if top.Parent ~= master then
					top.Parent = if instance:GetAttribute("AudioCategory") == "Music" or top.Name == "Music"
						then music
						else effects
				end
			else
				local target = if instance:GetAttribute("AudioCategory") == "Music" then music else effects
				if group ~= target then
					instance.SoundGroup = target
				end
			end
		end
		instance:GetAttributeChangedSignal("AudioCategory"):Connect(route)
		instance:GetPropertyChangedSignal("SoundGroup"):Connect(route)
		route()
	end
	-- Only places sounds can play from. Watching the whole game ran this for every
	-- part streaming into the map, and the first scan walked every instance there is.
	for _, root in { workspace, SoundService, Players.LocalPlayer } do
		root.DescendantAdded:Connect(bind)
		for _, instance in root:GetDescendants() do
			bind(instance)
		end
	end
end

function Settings.apply(values, changedKey)
	Settings.start()
	-- Profile refreshes and saved settings from another device must not undo
	-- this join's preset or a manual change made during the current session.
	if performance[changedKey] ~= nil and type(values[changedKey]) == "boolean" then
		performance[changedKey] = values[changedKey]
	end
	local effective = table.clone(values)
	for key, value in performance do
		effective[key] = value
	end
	applyPerformance()
	master.Volume = values.MasterVolume / 100
	music.Volume = values.MusicVolume / 100
	effects.Volume = values.EffectsVolume / 100
	return effective
end
return Settings
