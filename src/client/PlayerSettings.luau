-- Sound groups keep source volumes intact, including dynamically updated thunder.
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Settings = {}
local started = false
local master, music, effects
local underwaterFilter: EqualizerSoundEffect
local underwaterTween: Tween? = nil
local underwater = false
local performance, device, preset
-- 1 = Performance, 2 = Balanced, 3 = Quality. Published as the GraphicsTier attribute so
-- ambient systems (townsfolk) can scale their own detail.
local tier = 3
-- Performance keys the player changed by hand this session; an automatic step down
-- (Settings.lowerPreset) leaves those alone.
local manual: { [string]: boolean } = {}
local lowered = false

local PRESETS = { "Performance", "Balanced", "Quality" }
local function presetValues(level: number)
	return { Shadows = level == 3, WeatherEffects = level >= 2, ParliamentPerformance = level == 1 }
end

local function applyPerformance()
	Lighting.GlobalShadows = performance.Shadows
	Players.LocalPlayer:SetAttribute("WeatherEffectsEnabled", performance.WeatherEffects)
	-- Read by BlackHoleBackpack for every worn black hole pack in view.
	Players.LocalPlayer:SetAttribute("BackpackAnimationEnabled", performance.BackpackAnimation)
	-- The black hole pack's dynamic light is only worth its cost on the Quality preset, so
	-- phones, low quality levels and anything FrameRateGuard has stepped down lose the glow.
	Players.LocalPlayer:SetAttribute("BackpackGlowEnabled", tier >= 3)
	-- Computers get the full supercell tower and denser billows. The rain deck
	-- under the supercell remains present on every device, including Performance mode.
	Players.LocalPlayer:SetAttribute("VolumetricCloudsEnabled", device == "Computer" and performance.WeatherEffects)
	Players.LocalPlayer:SetAttribute("GraphicsTier", tier)
	-- Read by client/Parliament: one block per piece of furniture and per person, no ornament.
	Players.LocalPlayer:SetAttribute("ParliamentPerformanceMode", performance.ParliamentPerformance == true)
end

local function detectPerformance()
	-- Input capabilities are a device heuristic, not a hardware benchmark. A
	-- controller connected to a computer must not lower its preset on its own.
	tier = 3
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
	preset = PRESETS[tier]
	-- The black hole pack animation is off by default on phones and tablets
	-- regardless of their graphics level; it can still be turned on in Settings.
	performance = presetValues(tier)
	performance.BackpackAnimation = device ~= "Mobile / tablet"
	table.clear(manual)
	lowered = false
end

function Settings.description()
	Settings.start()
	if lowered then
		return device .. " · lowered to the " .. preset .. " preset to keep the frame rate up. Changes apply until you rejoin."
	end
	return device .. " · " .. preset .. " preset on join. Changes apply until you rejoin."
end

-- The value this session actually uses for a performance option, or nil for other keys.
function Settings.current(key: string): any
	Settings.start()
	return performance[key]
end

-- Steps the preset down one tier for the rest of the session (FrameRateGuard calls this
-- when the frame rate stays low). Options the player set by hand are kept. Returns
-- whether anything was lowered.
function Settings.lowerPreset(): boolean
	Settings.start()
	if tier <= 1 then
		return false
	end
	tier -= 1
	preset = PRESETS[tier]
	lowered = true
	for key, value in presetValues(tier) do
		if not manual[key] then
			performance[key] = value
		end
	end
	applyPerformance()
	return true
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
	-- Attenuate the whole mix without fighting saved volumes or sounds whose
	-- source volume changes every frame. Higher frequencies lose the most energy.
	underwaterFilter = Instance.new("EqualizerSoundEffect")
	underwaterFilter.Name = "UnderwaterMuffle"
	underwaterFilter.LowGain, underwaterFilter.MidGain, underwaterFilter.HighGain = 0, 0, 0
	underwaterFilter.Parent = master
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
	-- Only places sounds can play from: the mixer, this player's GUI, characters
	-- (footsteps, splashes) and boats (engines). Watching all of workspace ran a
	-- script call for every part streaming into the map, thousands per island piece.
	local function watch(root: Instance)
		root.DescendantAdded:Connect(bind)
		for _, instance in root:GetDescendants() do
			bind(instance)
		end
	end
	watch(SoundService)
	-- Positional fishing splashes and gull calls live on Terrain attachments.
	watch(workspace.Terrain)
	watch(Players.LocalPlayer)
	local function watchPlayer(other: Player)
		other.CharacterAdded:Connect(watch)
		if other.Character then
			watch(other.Character)
		end
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
	-- Sounds parented straight to workspace, and the boats folder.
	local function topLevel(child: Instance)
		bind(child)
		if child.Name == "PlayerBoats" then
			watch(child)
		end
	end
	workspace.ChildAdded:Connect(topLevel)
	for _, child in workspace:GetChildren() do
		topLevel(child)
	end
end

function Settings.setUnderwater(submerged: boolean)
	Settings.start()
	if underwater == submerged then
		return
	end
	underwater = submerged
	if underwaterTween then
		underwaterTween:Cancel()
	end
	underwaterTween = TweenService:Create(underwaterFilter, TweenInfo.new(0.18, Enum.EasingStyle.Sine), {
		LowGain = if submerged then -4 else 0,
		MidGain = if submerged then -14 else 0,
		HighGain = if submerged then -30 else 0,
	})
	underwaterTween:Play()
end

function Settings.apply(values, changedKey)
	Settings.start()
	-- Profile refreshes and saved settings from another device must not undo
	-- this join's preset or a manual change made during the current session.
	if performance[changedKey] ~= nil and type(values[changedKey]) == "boolean" then
		performance[changedKey] = values[changedKey]
		manual[changedKey] = true
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
