-- Fishing cues stay on the client: shared sounds parent to SoundService so
-- PlayerSettings routes them through the effects mixer, while splash and bite
-- cues use a temporary attachment so they follow the bobber in world space.
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local FishingAudio = {}
local CAST_SOUND = "rbxassetid://9126047581" -- Synth air whoosh
local SPLASH_SOUND = "rbxassetid://9125702798" -- Small shallow-water splash
local BITE_SOUND = "rbxassetid://9114451227" -- Heavy fishing reel zuzz
local PULL_SOUND = "rbxassetid://9114452634" -- Short fishing reel burst
local MISS_SOUND = "rbxassetid://9113616170" -- Light whip crack
local CATCH_SOUND = "rbxassetid://9040233162" -- Light, fun orchestral transition
local FAIL_SOUND = "rbxassetid://9042478443" -- Deflated fail quack

local CUES = {
	Cast = { id = CAST_SOUND, volume = 0.45, speed = 1.15 },
	Splash = { id = SPLASH_SOUND, volume = 0.55, speed = 1.1 },
	Bite = { id = BITE_SOUND, volume = 0.5, speed = 0.95 },
	Pull = { id = PULL_SOUND, volume = 0.35, speed = 1.2 },
	Miss = { id = MISS_SOUND, volume = 0.4, speed = 0.8 },
	Catch = { id = CATCH_SOUND, volume = 0.55, speed = 1 },
	Fail = { id = FAIL_SOUND, volume = 0.55, speed = 1 },
}

local started = false
local preloaded = false
local sounds = {}
local lastPlayed = {}

local function ensureStarted()
	if started then
		return
	end
	started = true
	for name, cue in CUES do
		local sound = Instance.new("Sound")
		sound.Name = "Fishing" .. name
		sound.SoundId = cue.id
		sound.Volume = cue.volume
		sound.PlaybackSpeed = cue.speed
		sound.Looped = false
		sound.Parent = SoundService
		sounds[name] = sound
	end
end

function FishingAudio.start()
	ensureStarted()
	if preloaded then
		return
	end
	preloaded = true
	local list = {}
	for _, sound in sounds do
		table.insert(list, sound)
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)
end

local function ready(name: string): Sound?
	ensureStarted()
	return sounds[name]
end

local function play(name: string, throttle: number?)
	local sound = ready(name)
	if not sound then
		return
	end
	local now = os.clock()
	if throttle and now - (lastPlayed[name] or -math.huge) < throttle then
		return
	end
	lastPlayed[name] = now
	sound.TimePosition = 0
	sound:Play()
end

local function playAt(name: string, position: Vector3?, throttle: number?)
	local source = ready(name)
	if not source then
		return
	end
	local now = os.clock()
	if throttle and now - (lastPlayed[name] or -math.huge) < throttle then
		return
	end
	lastPlayed[name] = now
	local terrain = if Workspace then Workspace.Terrain else nil
	if not position or not terrain then
		source.TimePosition = 0
		source:Play()
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "FishingSound"
	attachment.WorldPosition = position
	attachment.Parent = terrain
	local sound = source:Clone()
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 16
	sound.RollOffMaxDistance = 100
	sound.Parent = attachment
	sound:Play()
	Debris:AddItem(attachment, 4)
end

function FishingAudio.cast(strength: number?)
	local sound = ready("Cast")
	if not sound then
		return
	end
	local power = if type(strength) == "number" then math.clamp(strength, 0, 1) else 0.5
	sound.PlaybackSpeed = 1.05 + power * 0.25
	play("Cast", 0.5)
end

function FishingAudio.splash(position: Vector3?)
	playAt("Splash", position)
end

function FishingAudio.bite(position: Vector3?)
	playAt("Bite", position, 0.5)
end

function FishingAudio.pull()
	play("Pull")
end

function FishingAudio.miss()
	play("Miss")
end

function FishingAudio.catch()
	play("Catch", 1)
end

function FishingAudio.fail()
	play("Fail", 2)
end

return FishingAudio
