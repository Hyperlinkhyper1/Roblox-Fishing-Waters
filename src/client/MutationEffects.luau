-- Cycles the colours of Rainbow fish, wherever they are: in hands, freezers,
-- customers' arms and menu viewports. FishModels paints each part's base hue,
-- so a fish this never reaches still shows a still rainbow.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FishModels = require(ReplicatedStorage.Shared.FishModels)

local MutationEffects = {}
local CYCLE_SECONDS = 4
local STEP_SECONDS = 1 / 20
local parts: { [Model]: { BasePart } } = setmetatable({}, { __mode = "k" }) :: any
local voids: { [Model]: any } = setmetatable({}, { __mode = "k" }) :: any
local started = false

local function painted(model: Model): { BasePart }
	local list = parts[model]
	if not list then
		list = {}
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") and item:GetAttribute("RainbowHue") ~= nil then
				table.insert(list, item)
			end
		end
		parts[model] = list
	end
	return list
end

local function animateVoid(model: Model, time: number)
	local aura = voids[model]
	if not aura then
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") and item:GetAttribute("VoidAuraCore") then
				local points = {}
				for _, child in item:GetChildren() do
					if child:IsA("Attachment") and child:GetAttribute("VoidLensAngle") ~= nil then
						table.insert(points, child)
					end
				end
				aura = { core = item, points = points }
				voids[model] = aura
				break
			end
		end
	end
	if not aura or not aura.core.Parent then
		return
	end
	local core = aura.core
	local camera = workspace.CurrentCamera
	-- Keep menu previews animated; distant stored fish can hold a still lens.
	if model:IsDescendantOf(workspace) and camera and (core.Position - camera.CFrame.Position).Magnitude > 160 then
		return
	end
	local original = core:GetAttribute("VoidAuraOriginalSize")
	local scale = core.Size.X / original.X
	local center = core:GetAttribute("VoidAuraCenter") * scale
	local radius = core:GetAttribute("VoidAuraRadius") * scale
	for _, point in aura.points do
		local angle = point:GetAttribute("VoidLensAngle")
		local warp = 1 + math.sin(angle * 3 + time * 2.4) * 0.12
		local turn = angle + time * 0.55
		point.Position = center
			+ Vector3.new(
				math.cos(turn) * radius.X * warp,
				math.sin(turn) * radius.Y * warp,
				math.sin(angle * 2 - time * 1.5) * radius.Z * 0.55
			)
	end
end

function MutationEffects.start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceRemovedSignal(FishModels.RAINBOW_TAG):Connect(function(model)
		parts[model] = nil
	end)
	CollectionService:GetInstanceRemovedSignal(FishModels.VOID_TAG):Connect(function(model)
		voids[model] = nil
	end)
	local elapsed = 0
	RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed < STEP_SECONDS then
			return
		end
		elapsed = 0
		local shift = os.clock() / CYCLE_SECONDS
		for _, model in CollectionService:GetTagged(FishModels.RAINBOW_TAG) do
			if model:IsA("Model") and not model:HasTag(FishModels.VOID_TAG) then
				for _, item in painted(model) do
					item.Color = Color3.fromHSV(
						(item:GetAttribute("RainbowHue") + shift) % 1,
						item:GetAttribute("RainbowSaturation") or 0.6,
						item:GetAttribute("RainbowValue") or 1
					)
				end
			end
		end
		for _, model in CollectionService:GetTagged(FishModels.VOID_TAG) do
			if model:IsA("Model") then
				animateVoid(model, os.clock())
			end
		end
	end)
end

return MutationEffects
