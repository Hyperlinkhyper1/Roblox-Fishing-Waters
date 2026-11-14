-- Animates the pets on the /tp models pet deck (PetModels, tagged PetModels.TAG) on this client
-- only: the scarlet macaw glances about in quick snaps, tilts its head, blinks, bobs along in
-- little dances, squawks and flaps its wings on the perch. The server builds each pet at rest
-- and never moves it, so this is all local and cosmetic.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PetModels = require(ReplicatedStorage.Shared.PetModels)

-- Names this module's per-frame work in the MicroProfiler (otherwise it is all "Script_Client").
local function profiled<A...>(label: string, callback: (A...) -> ()): (A...) -> ()
	if not debug.profilebegin then
		return callback -- test runners without the MicroProfiler API
	end
	return function(...: A...)
		debug.profilebegin(label)
		callback(...)
		debug.profileend()
	end
end

local ShowcasePets = {}
local started = false

-- Pets farther than this from the camera hold their last pose
local MAX_DISTANCE = 180

local rigs: { [Model]: PetModels.Rig } = {}

local function track(model: Instance)
	if rigs[model :: Model] or not model:IsA("Model") or not model.Parent then
		return
	end
	local rig = PetModels.rig(model, os.clock())
	if rig then
		rigs[model] = rig
	end
end

function ShowcasePets.start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceAddedSignal(PetModels.TAG):Connect(function(model)
		task.defer(track, model)
	end)
	CollectionService:GetInstanceRemovedSignal(PetModels.TAG):Connect(function(model)
		rigs[model :: Model] = nil
	end)
	for _, model in CollectionService:GetTagged(PetModels.TAG) do
		track(model)
	end
	-- Pets whose parts were still arriving when their tag did are picked up here
	local nextScan = 0
	RunService.RenderStepped:Connect(profiled("ShowcasePets", function()
		local now = os.clock()
		if now >= nextScan then
			nextScan = now + 2
			for _, model in CollectionService:GetTagged(PetModels.TAG) do
				track(model)
			end
		end
		if next(rigs) == nil then
			return
		end
		local camera = workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else nil
		for model, rig in rigs do
			if not model.Parent or not rig.root.Parent then
				rigs[model] = nil
			elseif not eye or (rig.root.Position - eye).Magnitude <= MAX_DISTANCE then
				local parts, frames = PetModels.step(rig, now)
				workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
			end
		end
	end))
end

return ShowcasePets
