-- Short foam crests move from the shallows onto the sand, widen, then dissolve.
-- Only invisible shoreline samples replicate; all moving effects stay on the client.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local ShoreWaves = {}
local TAG = "ShoreWaveSource"
local PERIOD = 9.2
local DISTANCE = 550
local started = false

local function smoothstep(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function sampleWave(time: number, along: number, layer: number): (number, number, number)
	-- A gentle phase shift down the beach makes each crest break progressively.
	local phase = (time / PERIOD + layer / 2 - along / 350 - math.sin(along / 55) * 0.08) % 1
	local travel = 1 - (1 - phase) ^ 1.6
	local offset = -10 + 12.8 * travel
	local opacity = 0.46 * smoothstep(phase / 0.16) * (1 - smoothstep((phase - 0.55) / 0.40))
	local width = 0.28 + 0.8 * smoothstep((phase - 0.28) / 0.6)
	return offset, opacity, width
end

local function attachmentFrame(position: Vector3, tangent: Vector3): CFrame
	-- Attachment Y lies across the crest, keeping the foam flat on the water.
	return CFrame.fromMatrix(position, tangent, Vector3.yAxis:Cross(tangent).Unit)
end

function ShoreWaves.start()
	if started then
		return
	end
	started = true
	local sources = {}

	local function remove(source: Instance)
		local state = sources[source]
		if state then
			for _, wave in state.waves do
				wave.beam:Destroy()
				wave.a:Destroy()
				wave.b:Destroy()
			end
			sources[source] = nil
		end
	end

	local function add(source: Instance)
		if sources[source] or not source:IsA("BasePart") then
			return
		end
		local shore = { source:GetAttribute("Shore1"), source:GetAttribute("Shore2") }
		local inland = { source:GetAttribute("Inland1"), source:GetAttribute("Inland2") }
		local water = { source:GetAttribute("WaterHeight1"), source:GetAttribute("WaterHeight2") }
		local runup = { source:GetAttribute("RunupHeight1"), source:GetAttribute("RunupHeight2") }
		for i = 1, 2 do
			if
				typeof(shore[i]) ~= "Vector3"
				or typeof(inland[i]) ~= "Vector3"
				or typeof(water[i]) ~= "number"
				or typeof(runup[i]) ~= "number"
			then
				return
			end
		end
		local delta = shore[2] - shore[1]
		if delta.Magnitude < 0.1 then
			return
		end
		local tangent = delta.Unit
		local along = source:GetAttribute("Along") or 0
		local state = {
			shore = shore,
			inland = inland,
			water = water,
			runup = runup,
			along = along,
			fade = source:GetAttribute("EdgeFade") or 1,
			waves = {},
		}
		for layer = 0, 1 do
			local a, b = Instance.new("Attachment"), Instance.new("Attachment")
			a.Name, b.Name = "SurfStart", "SurfEnd"
			a.Parent, b.Parent = source, source
			local beam = Instance.new("Beam")
			beam.Name = "LappingWave"
			beam.Attachment0, beam.Attachment1 = a, b
			beam.FaceCamera = false
			beam.Segments = 12
			beam.CurveSize0, beam.CurveSize1 = delta.Magnitude / 3, delta.Magnitude / 3
			beam.Color = ColorSequence.new(Color3.fromRGB(218, 240, 241))
			-- Built-in soft texture avoids the hard edges and triangle seams of the old strips.
			beam.Texture = "rbxasset://textures/particles/smoke_main.dds"
			beam.TextureMode = Enum.TextureMode.Wrap
			beam.TextureLength = 3.4 + math.sin(along / 17) * 0.6
			beam.TextureSpeed = 0.04
			beam.LightEmission = 0
			beam.LightInfluence = 1
			-- Separate the foam from the nearly coplanar sand/water depth surface.
			beam.ZOffset = 0.15
			beam.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.18, 0.15),
				NumberSequenceKeypoint.new(0.45, 0),
				NumberSequenceKeypoint.new(0.72, 0.25),
				NumberSequenceKeypoint.new(1, 1),
			})
			beam.Enabled = false
			beam.Parent = source
			table.insert(state.waves, {
				a = a,
				b = b,
				beam = beam,
				layer = layer,
				tangentA = (tangent + inland[1] * 0.18).Unit,
				tangentB = (tangent - inland[2] * 0.18).Unit,
			})
		end
		sources[source] = state
	end

	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
	for _, source in CollectionService:GetTagged(TAG) do
		add(source)
	end

	-- Shore foam is close to the camera: stepping it at 30 Hz visibly judders
	-- on higher-refresh displays. Server time still keeps every frame in phase.
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local time = workspace:GetServerTimeNow()
		for source, state in sources do
			local visible = camera ~= nil
				and source:IsDescendantOf(workspace)
				and (source.Position - camera.CFrame.Position).Magnitude < DISTANCE
			for _, wave in state.waves do
				local beam = wave.beam
				beam.Enabled = visible
				if not visible then
					continue
				end
				local offset, opacity, width = sampleWave(time, state.along, wave.layer)
				for i, attachment in { wave.a, wave.b } do
					-- Keep the shoreward wash steady instead of wobbling its endpoints.
					local ripple = math.sin(state.along / 35 + time * 0.25 + i * 0.2 + wave.layer) * 0.06
					local distance = offset + ripple
					local height = 0.16
						+ (state.water[i] - 0.16) * smoothstep((distance + 2) / 2)
						+ (state.runup[i] - state.water[i]) * smoothstep(distance / 2.8)
					local position = state.shore[i] + state.inland[i] * distance + Vector3.yAxis * height
					attachment.CFrame = attachmentFrame(position, if i == 1 then wave.tangentA else wave.tangentB)
				end
				beam.Width0 = width * (0.85 + math.sin(state.along / 13) * 0.15)
				beam.Width1 = width
				beam.LocalTransparencyModifier = 1 - opacity * state.fade
			end
		end
	end)
end

return ShoreWaves
