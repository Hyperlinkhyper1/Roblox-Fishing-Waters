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

function MutationEffects.start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceRemovedSignal(FishModels.RAINBOW_TAG):Connect(function(model)
		parts[model] = nil
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
			if model:IsA("Model") then
				for _, item in painted(model) do
					item.Color = Color3.fromHSV(
						(item:GetAttribute("RainbowHue") + shift) % 1,
						item:GetAttribute("RainbowSaturation") or 0.6,
						item:GetAttribute("RainbowValue") or 1
					)
				end
			end
		end
	end)
end

return MutationEffects
