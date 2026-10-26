-- A client-only singularity and three rotating water spirals. The server owns
-- the event location and mutation radius; these parts never affect physics.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Weather = require(ReplicatedStorage.Shared.Weather)
local Controller = {}
local started = false
local TAU = math.pi * 2
local RING_SEGMENTS = 36
local SPIRAL_SEGMENTS = 24

local function part(name: string, parent: Instance): Part
	local result = Instance.new("Part")
	result.Name = name
	result.Anchored = true
	result.CanCollide = false
	result.CanTouch = false
	result.CanQuery = false
	result.CastShadow = false
	result.Size = Vector3.one
	result.Transparency = 1
	result.Parent = parent
	return result
end

local function path(parent: Part, count: number, loop: boolean, width: number, color: Color3)
	local points = {}
	for index = 1, count do
		local point = Instance.new("Attachment")
		point.Name = "VortexPoint" .. index
		point.Parent = parent
		table.insert(points, point)
	end
	for index = 1, if loop then count else count - 1 do
		local beam = Instance.new("Beam")
		beam.Name = "VortexStream"
		beam.Attachment0 = points[index]
		beam.Attachment1 = points[index % count + 1]
		beam.Width0, beam.Width1 = width, width
		beam.Color = ColorSequence.new(color)
		beam.Transparency = NumberSequence.new(0.25)
		beam.LightEmission = 0.8
		beam.LightInfluence = 0
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Parent = parent
	end
	return points
end

function Controller.start()
	if started then
		return
	end
	started = true
	local model: Model? = nil
	local anchor: Part? = nil
	local core: Part? = nil
	local rim, lens, spirals = {}, {}, {}
	local elapsed = 0
	local function clear()
		if model then
			model:Destroy()
		end
		model, anchor, core = nil, nil, nil
		rim, lens, spirals = {}, {}, {}
	end
	local function create()
		model = Instance.new("Model")
		model.Name = "BlackHoleWeatherEffects"
		anchor = part("VortexOrigin", model)
		core = part("EventHorizon", model)
		core.Shape = Enum.PartType.Ball
		core.Size = Vector3.one * 40
		core.Color = Color3.new(0, 0, 0)
		core.Material = Enum.Material.SmoothPlastic
		core.Transparency = 0
		rim = path(anchor, RING_SEGMENTS, true, 3.2, Color3.fromRGB(181, 75, 255))
		lens = path(anchor, RING_SEGMENTS, true, 1.3, Color3.fromRGB(93, 32, 165))
		for index = 1, 3 do
			table.insert(spirals, path(anchor, SPIRAL_SEGMENTS, false, 3.5, Color3.fromRGB(91, 34, 133)))
		end
		model.Parent = workspace
	end
	RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 / 30 then
			return
		end
		elapsed %= 1 / 30
		local center = Weather.blackHolePosition()
		local camera = workspace.CurrentCamera
		local enabled = Players.LocalPlayer:GetAttribute("WeatherEffectsEnabled") ~= false
		if not center or not camera or not enabled then
			clear()
			return
		end
		if not model then
			create()
		end
		local now = workspace:GetServerTimeNow()
		local origin = anchor :: Part
		local sphere = core :: Part
		origin.CFrame = CFrame.new(center)
		local hole = Vector3.new(0, 58, 0)
		sphere.Position = center + hole
		local facing = CFrame.lookAt(center + hole, camera.CFrame.Position)
		for index = 1, RING_SEGMENTS do
			local angle = (index - 1) / RING_SEGMENTS * TAU
			local warp = 1 + math.sin(angle * 3 + now * 1.4) * 0.035
			local edge = Vector3.new(math.cos(angle), math.sin(angle), 0) * 21.7 * warp
			rim[index].Position = hole + facing:VectorToWorldSpace(edge)
			local orbit = angle + now * 0.5
			lens[index].Position = hole + Vector3.new(math.cos(orbit) * 37, math.sin(orbit) * 8, math.sin(orbit) * 18)
		end
		for arm, points in spirals do
			for index, point in points do
				local fraction = (index - 1) / (SPIRAL_SEGMENTS - 1)
				local radius = 14 + fraction * (Weather.BlackHoleRadius - 14)
				local angle = arm * TAU / 3 + fraction * TAU * 1.2 - now * 0.42
				local height = 0.65 + math.sin(angle * 2 + now) * 0.25
				point.Position = Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
			end
		end
	end)
end

return Controller
