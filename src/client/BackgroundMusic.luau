-- Background music: a warm harbor playlist while on land and a calmer, more open
-- orchestral playlist out at sea. Every track is from Roblox's licensed music
-- library (free for every experience). PlayerSettings routes these sounds into
-- the Music mixer through their AudioCategory, so the Music slider applies.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Aboard = require(ReplicatedStorage.Shared.Aboard)

local BackgroundMusic = {}
local started = false
-- Both playlists are acoustic; the sea one sits a touch lower so the waves
-- stay in front of it.
local VOLUMES = { Island = 0.22, Ocean = 0.2 }
-- Swimming off a dock or stepping onto a moored deck must not flip the music.
local SWITCH_DELAY = 4
-- Out at sea the waves carry the quiet between tracks, so leave more of it.
local GAPS = { Island = NumberRange.new(3, 6), Ocean = NumberRange.new(10, 25) }
local FADE_RATE = 0.8

local PLAYLISTS = {
	-- APM "Easy Acoustic Chill" vols 1-2: laid-back modern acoustic guitar for
	-- a sunny fishing village, without sad or high-energy titles.
	Island = {
		"rbxassetid://1842613995", -- Easy Life (Jacob King)
		"rbxassetid://1842600804", -- Lazy Days (Jacob King)
		"rbxassetid://1842600316", -- Sunday Vibe (Terry Caster)
		"rbxassetid://1842601084", -- Twilight Beach (James Asher)
		"rbxassetid://1842613783", -- Castaway - Underscore (Terry Caster)
	},
	-- Slow, soft piano and acoustic guitar that sits under the waves instead of
	-- over them. docs/FISCH_FEEL.md says why each was picked and lists spares.
	Ocean = {
		"rbxassetid://1838786430", -- The Grace and the Gamble ("soft and lush piano and acoustic guitar")
		"rbxassetid://1846315728", -- Andante For Guitar And Piano In C Major
		"rbxassetid://9045573146", -- No Clouds Outside, underscore ("relaxed, peaceful acoustic")
		"rbxassetid://1839919231", -- Lonely Promises ("calm and laid-back, peaceful guitar bed")
		"rbxassetid://1839967674", -- In Five b ("tender piano melody, underscore")
		"rbxassetid://1837380492", -- Happy Birds Fly ("peaceful & fragile, piano")
	},
}

local function shuffled(list: { string }, avoidFirst: string?): { string }
	local result = table.clone(list)
	for i = #result, 2, -1 do
		local j = math.random(i)
		result[i], result[j] = result[j], result[i]
	end
	-- Never repeat the track that just finished when the order reshuffles.
	if #result > 1 and result[1] == avoidFirst then
		result[1], result[#result] = result[#result], result[1]
	end
	return result
end

local function atSea(character: Model?): boolean?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	if humanoid:GetState() == Enum.HumanoidStateType.Swimming then
		return true
	end
	local boats = workspace:FindFirstChild("PlayerBoats")
	if boats then
		for _, boat in boats:GetChildren() do
			if boat:IsA("Model") and Aboard(character, boat) then
				return true
			end
		end
	end
	return false
end

function BackgroundMusic.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local folder = Instance.new("Folder")
	folder.Name = "BackgroundMusic"
	folder.Parent = SoundService

	local zones = {}
	for name, list in PLAYLISTS do
		local sound = Instance.new("Sound")
		sound.Name = name .. "Music"
		sound.Volume = 0
		sound:SetAttribute("AudioCategory", "Music")
		sound.Parent = folder
		local zone = {
			name = name,
			sound = sound,
			list = list,
			order = shuffled(list),
			index = 0,
			waitUntil = 0,
			finished = true,
		}
		zones[name] = zone
		sound.Ended:Connect(function()
			local gap = GAPS[name]
			zone.finished, zone.waitUntil = true, os.clock() + gap.Min + math.random() * (gap.Max - gap.Min)
		end)
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ zones.Island.order[1], zones.Ocean.order[1] })
		end)
	end)

	local function nextTrack(zone)
		zone.index += 1
		if zone.index > #zone.order then
			zone.order = shuffled(zone.list, zone.order[#zone.order])
			zone.index = 1
		end
		zone.sound.SoundId = zone.order[zone.index]
		zone.sound.TimePosition = 0
		zone.sound:Play()
		zone.finished = false
	end

	local current = zones.Island
	local pending: string? = nil
	local pendingSince = 0
	local sampleElapsed = math.huge
	RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock()
		-- The deck raycast is cheap but needs no per-frame resolution.
		sampleElapsed += dt
		if sampleElapsed >= 0.5 then
			sampleElapsed = 0
			local sea = atSea(player.Character)
			local wanted = if sea == nil then current.name elseif sea then "Ocean" else "Island"
			if wanted == current.name then
				pending = nil
			elseif wanted ~= pending then
				pending, pendingSince = wanted, now
			elseif now - pendingSince >= SWITCH_DELAY then
				current, pending = zones[wanted], nil
			end
		end
		local blend = 1 - math.exp(-math.clamp(dt, 0, 0.1) * FADE_RATE * 3)
		for _, zone in zones do
			local sound = zone.sound
			if zone == current then
				-- Resume where this zone's track was paused; start a new one after
				-- the previous track's short gap, or on the very first frame.
				if not sound.IsPlaying then
					if not zone.finished then
						sound:Resume()
					elseif now >= zone.waitUntil then
						nextTrack(zone)
					end
				end
				sound.Volume += (VOLUMES[zone.name] - sound.Volume) * blend
			else
				sound.Volume += (0 - sound.Volume) * blend
				if sound.Volume < 0.005 and sound.IsPlaying then
					sound.Volume = 0
					sound:Pause()
				end
			end
		end
	end)
end

return BackgroundMusic
