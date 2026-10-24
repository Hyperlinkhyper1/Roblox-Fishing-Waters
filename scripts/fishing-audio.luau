-- Exercise the actual client cue mixer; asset playback still requires Studio.
local clock = 0
local os = { clock = function() return clock end }
local task = { spawn = function(callback, ...) callback(...) end }
local Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }
local Enum = { RollOffMode = { InverseTapered = "InverseTapered" } }

local soundService = { Name = "SoundService" }
local terrain = { Name = "Terrain" }
local debris = {}
local preloaded = nil
local game = {}
function game:GetService(name)
	if name == "SoundService" then
		return soundService
	elseif name == "Workspace" then
		return { Terrain = terrain }
	elseif name == "Debris" then
		return {
			AddItem = function(_, item, seconds)
				table.insert(debris, { item = item, seconds = seconds })
			end,
		}
	elseif name == "ContentProvider" then
		return {
			PreloadAsync = function(_, list)
				preloaded = list
			end,
		}
	end
	error("Unexpected service: " .. name)
end

local sounds, attachments = {}, {}
local Instance = {}
function Instance.new(class)
	if class == "Sound" then
		local sound = {
			ClassName = "Sound",
			Name = "",
			SoundId = "",
			Volume = 1,
			PlaybackSpeed = 1,
			Looped = false,
			TimePosition = 0,
			IsPlaying = false,
			PlayCount = 0,
			Parent = nil,
		}
		function sound:Play()
			self.IsPlaying = true
			self.PlayCount += 1
		end
		function sound:Stop()
			self.IsPlaying = false
		end
		function sound:Clone()
			local copy = Instance.new("Sound")
			for key, value in self do
				if type(value) ~= "function" then
					copy[key] = value
				end
			end
			copy.PlayCount, copy.IsPlaying = 0, false
			return copy
		end
		table.insert(sounds, sound)
		return sound
	elseif class == "Attachment" then
		local attachment = { ClassName = "Attachment", Name = "", WorldPosition = nil, Parent = nil }
		table.insert(attachments, attachment)
		return attachment
	end
	error("Unexpected instance: " .. class)
end

local Audio = (function()
	-- FISHING_AUDIO_SOURCE --
end)()

local function shared(name)
	for _, sound in sounds do
		if sound.Name == name and sound.Parent == soundService then
			return sound
		end
	end
	return nil
end

local function sharedSounds()
	local list = {}
	for _, sound in sounds do
		if sound.Parent == soundService then
			table.insert(list, sound)
		end
	end
	return list
end

Audio.start()
Audio.start()
local cues = sharedSounds()
assert(#cues == 7, "One shared cue per fishing moment")
assert(#preloaded == 7, "Every cue must preload once")
for index, sound in preloaded do
	assert(sound == cues[index], "Preload the shared cue instances")
end

local ids = {}
for _, name in { "Cast", "Splash", "Bite", "Pull", "Miss", "Catch", "Fail" } do
	local sound = shared("Fishing" .. name)
	assert(sound, "Missing cue: " .. name)
	assert(string.match(sound.SoundId, "^rbxassetid://%d+$"), name .. " needs a valid asset id")
	assert(sound.Volume > 0 and sound.Volume <= 1, name .. " needs a sensible volume")
	assert(sound.PlaybackSpeed > 0, name .. " needs a sensible pitch")
	assert(not sound.Looped, name .. " must not loop")
	assert(not ids[sound.SoundId], "Cues must use distinct audio: " .. sound.SoundId)
	ids[sound.SoundId] = true
end

clock = 10
local cast = shared("FishingCast")
cast.TimePosition = 2
Audio.cast(0.5)
assert(cast.PlayCount == 1 and cast.IsPlaying and cast.TimePosition == 0, "A cast must whoosh once from the start")
assert(math.abs(cast.PlaybackSpeed - 1.175) < 0.001, "Cast strength must pitch the whoosh")
Audio.cast(1)
assert(cast.PlayCount == 1, "A second cast within the throttle window must stay silent")
clock = 10.6
Audio.cast(1)
assert(cast.PlayCount == 2 and cast.PlaybackSpeed > 1.2, "A full-power cast must play higher")

local splash = shared("FishingSplash")
local position = Vector3.new(4, 1, -2)
local attachmentCount, debrisCount = #attachments, #debris
Audio.splash(position)
assert(#attachments == attachmentCount + 1, "A splash needs a positional emitter")
local attachment = attachments[#attachments]
local splashClone = sounds[#sounds]
assert(attachment.WorldPosition == position, "The splash must land at the bobber")
assert(attachment.Parent == terrain, "The emitter must live under Terrain")
assert(splash.PlayCount == 0, "Positional splashes must not use the shared copy")
assert(splashClone.Parent == attachment and splashClone.PlayCount == 1 and splashClone.IsPlaying, "The splash clone must play once")
assert(splashClone.SoundId == splash.SoundId, "The splash clone must use the splash cue")
assert(splashClone.RollOffMode == Enum.RollOffMode.InverseTapered, "Splashes must attenuate with distance")
assert(splashClone.RollOffMinDistance == 16 and splashClone.RollOffMaxDistance == 100, "Splash rolloff must match the world mix")
assert(#debris == debrisCount + 1, "The splash emitter must be cleaned up")
assert(debris[#debris].item == attachment and debris[#debris].seconds == 4, "Splash cleanup must wait for the tail")
Audio.splash()
assert(splash.PlayCount == 1, "Without a position the splash falls back to the shared cue")

local bite = shared("FishingBite")
local bitesBefore = #attachments
Audio.bite(position)
assert(#attachments == bitesBefore + 1, "A bite needs a positional emitter")
local biteClone = sounds[#sounds]
assert(biteClone.Parent == attachments[#attachments], "The bite must follow the bobber")
assert(biteClone.SoundId == bite.SoundId and biteClone.PlayCount == 1, "The bite clone must play once")
Audio.bite(position)
assert(#attachments == bitesBefore + 1, "A duplicate bite within the throttle window must be ignored")
clock = 11.2
Audio.bite()
assert(bite.PlayCount == 1, "A bite without a position falls back to the shared cue")

local pull, miss = shared("FishingPull"), shared("FishingMiss")
Audio.pull()
Audio.pull()
assert(pull.PlayCount == 2, "Every successful pull needs reel feedback")
Audio.miss()
Audio.miss()
assert(miss.PlayCount == 2, "Every missed pull needs failure feedback")
assert(pull.SoundId ~= miss.SoundId, "Pull and miss cues must sound different")

clock = 20
local catch, fail = shared("FishingCatch"), shared("FishingFail")
Audio.catch()
assert(catch.PlayCount == 1 and catch.IsPlaying, "Landing a fish needs a catch sting")
Audio.fail()
assert(fail.PlayCount == 1 and fail.IsPlaying, "Losing a fish needs a failure sting")
Audio.fail()
assert(fail.PlayCount == 1, "Duplicate failure cues within the throttle window must be ignored")
clock = 22.1
Audio.fail()
assert(fail.PlayCount == 2, "A later failure must play again")
Audio.catch()
assert(catch.PlayCount == 2, "A later catch must play again")
assert(catch.SoundId ~= fail.SoundId, "Catch and failure cues must sound different")

local cueCount = #sharedSounds()
Audio.start()
assert(#sharedSounds() == cueCount, "Starting twice must not duplicate sounds")

print("Fishing audio lifecycle checks passed (mock sounds; live playback requires Studio)")
