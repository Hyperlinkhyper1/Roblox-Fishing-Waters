-- Animates worn Black Hole Backpacks (BackpackModels "BlackHole") on this
-- client only: the accretion disk spins in two bands, five small fish spiral
-- into the horizon and fade, stardust falls inward and the glow breathes.
-- Everything here is local and cosmetic. The server builds the pack frozen and
-- never moves its joints, so turning the Backpack animation setting off (the
-- default on phones, see PlayerSettings) simply puts every joint back.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BlackHoleBackpack = {}
local started = false

local TAG = "BlackHoleBackpack"
-- Packs farther than this from the camera keep their last pose.
local MAX_DISTANCE = 140
-- Disk spin in radians per second; the inner band orbits faster, as it would.
local INNER_SPIN, OUTER_SPIN = 2.6, 1.1
-- Each fish takes this long to fall from the disk edge into the horizon.
local INFALL_SECONDS = 2.8
local INFALL_TURNS = 1.6
-- Starting orbit radius of an infalling fish in unscaled model studs (matches
-- BackpackModels: frame * F(0.74, 0, 0.05)) and the horizon radius they vanish at.
local INFALL_RADIUS, HORIZON_RADIUS = 0.74, 0.2
local FISH_COUNT = 5

type Rig = {
	model: Model,
	scale: number,
	phase: number,
	motors: { [string]: Motor6D },
	base: { [Motor6D]: CFrame },
	fish: { { BasePart } },
	dust: ParticleEmitter?,
	glow: PointLight?,
	glowBase: number,
	posed: boolean,
}

local rigs: { [Model]: Rig } = {}

local function enabled(): boolean
	return Players.LocalPlayer:GetAttribute("BackpackAnimationEnabled") ~= false
end

-- Worn packs only: store and preview copies are anchored and have no joints.
local function track(model: Instance)
	if not model:IsA("Model") or rigs[model] then
		return
	end
	local handle = model.PrimaryPart
	if not handle or not handle:FindFirstChild("DiskInner") then
		return
	end
	local rig: Rig = {
		model = model,
		scale = model:GetAttribute("RigScale") or 1,
		phase = math.random() * 10,
		motors = {},
		base = {},
		fish = {},
		dust = nil,
		glow = nil,
		glowBase = 0.9,
		posed = false,
	}
	for _, joint in handle:GetChildren() do
		if joint:IsA("Motor6D") then
			rig.motors[joint.Name] = joint
			-- The server never changes these, so the first value seen is the rest pose.
			rig.base[joint] = joint.C0
		end
	end
	for i = 1, FISH_COUNT do
		local group = model:FindFirstChild("Infall" .. i)
		local parts = {}
		if group then
			for _, piece in group:GetChildren() do
				if piece:IsA("BasePart") and piece.Name ~= "RigPivot" then
					table.insert(parts, piece)
				end
			end
		end
		rig.fish[i] = parts
	end
	local shell = model:FindFirstChild("InfallShell")
	rig.dust = shell and shell:FindFirstChildOfClass("ParticleEmitter")
	local lens = model:FindFirstChild("LensingShell")
	rig.glow = lens and lens:FindFirstChildOfClass("PointLight")
	rig.glowBase = if rig.glow then rig.glow.Brightness else 0.9
	rigs[model] = rig
end

local function rest(rig: Rig)
	for motor, c0 in rig.base do
		motor.C0 = c0
	end
	for _, parts in rig.fish do
		for _, piece in parts do
			piece.LocalTransparencyModifier = 0
		end
	end
	if rig.dust then
		rig.dust.Enabled = false
	end
	if rig.glow then
		rig.glow.Brightness = rig.glowBase
	end
	rig.posed = false
end

local function pose(rig: Rig, now: number)
	local t = now + rig.phase
	local inner, outer = rig.motors.DiskInner, rig.motors.DiskOuter
	if inner then
		inner.C0 = rig.base[inner] * CFrame.Angles(0, 0, -t * INNER_SPIN)
	end
	if outer then
		outer.C0 = rig.base[outer] * CFrame.Angles(0, 0, -t * OUTER_SPIN)
	end
	-- Each fish: rotate around the disk normal while the orbit shrinks, then
	-- fade out just before the horizon and reappear at the rim.
	for i = 1, FISH_COUNT do
		local motor = rig.motors["Infall" .. i]
		if motor then
			local progress = (t / INFALL_SECONDS + i / FISH_COUNT) % 1
			local radius = HORIZON_RADIUS + (INFALL_RADIUS - HORIZON_RADIUS) * (1 - progress) ^ 1.6
			local angle = -progress * INFALL_TURNS * 2 * math.pi
			motor.C0 = rig.base[motor]
				* CFrame.Angles(0, 0, angle)
				* CFrame.new(-(INFALL_RADIUS - radius) * rig.scale, 0, 0)
			local fade = if progress < 0.08
				then 1 - progress / 0.08
				elseif progress > 0.8 then (progress - 0.8) / 0.2
				else 0
			for _, piece in rig.fish[i] do
				piece.LocalTransparencyModifier = fade
			end
		end
	end
	if rig.dust and not rig.dust.Enabled then
		rig.dust.Enabled = true
	end
	if rig.glow then
		rig.glow.Brightness = rig.glowBase * (1 + 0.35 * math.sin(t * 2.2))
	end
	rig.posed = true
end

function BlackHoleBackpack.start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model)
		-- Joints are created right after the tag replicates; give them a frame.
		task.defer(track, model)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model)
		rigs[model] = nil
	end)
	for _, model in CollectionService:GetTagged(TAG) do
		track(model)
	end
	-- Packs that streamed in before their joints did are retried here.
	local nextScan = 0
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if now >= nextScan then
			nextScan = now + 2
			for _, model in CollectionService:GetTagged(TAG) do
				if not rigs[model] then
					track(model)
				end
			end
		end
		local animate = enabled()
		local camera = workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else nil
		for model, rig in rigs do
			if not model.Parent then
				rigs[model] = nil
			elseif not animate then
				if rig.posed then
					rest(rig)
				end
			else
				local handle = model.PrimaryPart
				local near = handle ~= nil and eye ~= nil and (handle.Position - eye).Magnitude <= MAX_DISTANCE
				if near then
					pose(rig, now)
				elseif rig.dust and rig.dust.Enabled then
					rig.dust.Enabled = false
				end
			end
		end
	end)
end

return BlackHoleBackpack
