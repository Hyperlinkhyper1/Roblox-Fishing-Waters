-- Steps the graphics preset down while the frame rate stays low.
--
-- PlayerSettings picks a preset on join from the device and Roblox's saved graphics
-- level, but most players leave graphics on Automatic, which tells it nothing: every
-- computer got the full Quality preset (shadows, detailed clouds), however weak. This
-- watches real frame times once the world has loaded and, if a window is slow, lowers
-- the preset one step (Quality -> Balanced -> Performance), leaving any option the player
-- set by hand. It never raises the preset again during the session.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local PlayerSettings = require(script.Parent.PlayerSettings)

local FrameRateGuard = {}

-- Pure decision, separate from the Roblox loop so a harness can drive it. A window is
-- slow when its average frame rate is under SLOW_FPS, or when it hitches often while
-- also missing 60 FPS. A device capped at 30 FPS with steady frames is left alone
-- unless it drops well below the cap.
FrameRateGuard.SLOW_FPS = 40
FrameRateGuard.CAPPED_FPS = 26
FrameRateGuard.HITCH_SECONDS = 0.1
FrameRateGuard.HITCH_LIMIT = 6
function FrameRateGuard.isSlow(frames: number, seconds: number, hitches: number, steady: boolean): boolean
	if seconds <= 0 or frames <= 0 then
		return false
	end
	local fps = frames / seconds
	if steady then
		return fps < FrameRateGuard.CAPPED_FPS
	end
	return fps < FrameRateGuard.SLOW_FPS or (hitches >= FrameRateGuard.HITCH_LIMIT and fps < 55)
end

local WINDOW = 10 -- seconds of frames judged together
local SETTLE = 15 -- after the loading screen lifts, streaming still settles this long
local COOLDOWN = 20 -- after a step down (it hitches once while shadows rebuild)
local LOADING_TIMEOUT = 120

local started = false

function FrameRateGuard.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	task.spawn(function()
		local deadline = os.clock() + LOADING_TIMEOUT
		while player:GetAttribute("FishingWatersLoadingSeconds") == nil and os.clock() < deadline do
			task.wait(1)
		end
		task.wait(SETTLE)

		local frames, seconds, hitches = 0, 0, 0
		local shortest, longest = math.huge, 0
		local resumeAt = 0
		local function reset()
			frames, seconds, hitches = 0, 0, 0
			shortest, longest = math.huge, 0
		end
		-- A window spent in the background (alt-tabbed, minimised) says nothing about the game.
		local focused = true
		UserInputService.WindowFocusReleased:Connect(function()
			focused = false
			reset()
		end)
		UserInputService.WindowFocused:Connect(function()
			focused = true
			reset()
		end)
		local connection: RBXScriptConnection
		connection = RunService.Heartbeat:Connect(function(dt: number)
			local now = os.clock()
			if now < resumeAt or not focused then
				return
			end
			frames += 1
			seconds += dt
			if dt > FrameRateGuard.HITCH_SECONDS then
				hitches += 1
			end
			-- Ignore the worst frames when judging steadiness; a capped game has a flat floor.
			shortest = math.min(shortest, dt)
			if dt < 0.25 then
				longest = math.max(longest, dt)
			end
			if seconds < WINDOW then
				return
			end
			-- A frame-rate cap shows up as frame times that barely vary and no hitches.
			local steady = hitches == 0 and longest - shortest < 0.006
			if FrameRateGuard.isSlow(frames, seconds, hitches, steady) then
				local fps = math.floor(frames / seconds + 0.5)
				if PlayerSettings.lowerPreset() then
					print(string.format("[FrameRateGuard] %d FPS over %ds; lowered graphics preset", fps, WINDOW))
					resumeAt = now + COOLDOWN
				else
					connection:Disconnect() -- already at the lowest preset
					return
				end
			end
			reset()
		end)
	end)
end

return FrameRateGuard
