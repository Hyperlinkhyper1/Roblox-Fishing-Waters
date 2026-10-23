-- Owns a player's breath while their head is below the ocean surface.  The
-- replicated attributes deliberately contain presentation state only; the
-- server decides when a player has run out of air and respawns them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Biomes = require(ReplicatedStorage.Shared.Biomes)

local OXYGEN_SECONDS = 20
local SAMPLE_INTERVAL = 0.1
local BLACKOUT_SECONDS = 1.15

type BreathState = {

	oxygen: number,
	drowning: boolean,
}

local OxygenService = {}
local states: { [Player]: BreathState } = {}
local elapsed = 0

local function isUnderwater(character: Model): boolean
	-- Breathing is based on the head rather than the root part, so a player can
	-- tread water at the surface without losing oxygen.
	local head = character:FindFirstChild("Head") :: BasePart?
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local part = head or root
	if not part then
		return false
	end

	local position = part.Position
	return math.abs(position.X) < Biomes.MapHalfSize
		and math.abs(position.Z) < Biomes.MapHalfSize
		and position.Y > Biomes.SeaFloor
		and position.Y < Biomes.WaterLevel
end

local function publish(player: Player, state: BreathState, underwater: boolean)
	player:SetAttribute("Underwater", underwater)
	player:SetAttribute("Oxygen", state.oxygen)
end

local function reset(player: Player, state: BreathState)
	state.oxygen = 1
	publish(player, state, false)
end

local function drown(player: Player, state: BreathState)
	if state.drowning then
		return
	end
	state.drowning = true
	publish(player, state, true)
	player:SetAttribute("OxygenBlackout", true)

	-- The client begins its fade immediately.  Loading the character after the
	-- fade means BaseService's normal CharacterAdded placement returns them to
	-- their owned base (or the harbour fallback if all bases are occupied).
	task.delay(BLACKOUT_SECONDS, function()
		if states[player] ~= state or not state.drowning or player.Parent ~= Players then
			return
		end
		player:LoadCharacter()
		task.delay(0.7, function()
			if states[player] ~= state then
				return
			end
			state.drowning = false
			reset(player, state)
			player:SetAttribute("OxygenBlackout", false)
		end)
	end)
end

local function track(player: Player)
	local state: BreathState = { oxygen = 1, drowning = false }
	states[player] = state
	player:SetAttribute("OxygenBlackout", false)
	reset(player, state)

	player.CharacterAdded:Connect(function()
		-- Natural respawns and BaseService placements always begin with a full
		-- tank. The blackout sequence clears itself after the new avatar appears.
		reset(player, state)
	end)
end

function OxygenService.start()
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		track(player)
	end

	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < SAMPLE_INTERVAL then
			return
		end
		local step = elapsed
		elapsed = 0

		for player, state in states do
			if state.drowning then
				continue
			end
			local character = player.Character
			if not character then
				reset(player, state)
				continue
			end
			local underwater = isUnderwater(character)
			if underwater then
				state.oxygen = math.max(0, state.oxygen - step / OXYGEN_SECONDS)
				publish(player, state, true)
				if state.oxygen <= 0 then
					drown(player, state)
				end
			else
				reset(player, state)
			end
		end
	end)
end

return OxygenService
