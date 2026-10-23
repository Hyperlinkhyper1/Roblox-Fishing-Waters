-- Sound groups keep source volumes intact, including dynamically updated thunder.
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local Settings = {}
local started = false
local master, music, effects

function Settings.start()
	if started then
		return
	end
	started = true
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
	game.DescendantAdded:Connect(bind)
	for _, instance in game:GetDescendants() do
		bind(instance)
	end
end

function Settings.apply(values)
	Settings.start()
	Lighting.GlobalShadows = values.Shadows
	Players.LocalPlayer:SetAttribute("WeatherEffectsEnabled", values.WeatherEffects)
	master.Volume = values.MasterVolume / 100
	music.Volume = values.MusicVolume / 100
	effects.Volume = values.EffectsVolume / 100
end
return Settings
