-- Budgets shadow-casting interior lights (tag ShadowLight: base pendants, dining lamps).
--
-- Every base house hangs 11 shadowed pendants, so a walk through the village had dozens of
-- point-light shadow maps on screen, each redrawn whenever a townsperson or customer moved
-- through its range. Out of the house it was the bulk of the frame. Only the lights closest
-- to the camera keep their shadows here; the rest still light the room, unshadowed. Light
-- properties written on the client stay local, so the server's Shadows = true is untouched.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local LightShadows = {}

local TAG = "ShadowLight"
-- Inside a room the pendants overhead are well within this; across the street they are not.
local RANGE = 40
local MAX_SHADOWED = 6
local INTERVAL = 0.4

local started = false

-- Pure choice, separate from the Roblox loop so a harness can drive it: the indexes of
-- `distances` that keep shadows (nearest first, at most `limit`, within `range`).
function LightShadows.choose(distances: { number }, range: number, limit: number): { [number]: boolean }
	local order = {}
	for index, distance in distances do
		if distance <= range then
			table.insert(order, index)
		end
	end
	table.sort(order, function(a, b)
		return distances[a] < distances[b]
	end)
	local keep = {}
	for rank = 1, math.min(limit, #order) do
		keep[order[rank]] = true
	end
	return keep
end

function LightShadows.start()
	if started then
		return
	end
	started = true
	local lights: { [Light]: boolean } = {} -- light -> shadows currently on (locally)

	local function add(instance: Instance)
		if instance:IsA("Light") and lights[instance] == nil then
			-- Off until the next pass decides; a newly streamed house never pops in 11 shadow maps.
			lights[instance] = false
			instance.Shadows = false
		end
	end
	local function remove(instance: Instance)
		lights[instance :: Light] = nil
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
	for _, instance in CollectionService:GetTagged(TAG) do
		add(instance)
	end

	task.spawn(function()
		local list: { Light } = {}
		local distances: { number } = {}
		while true do
			task.wait(INTERVAL)
			local camera = workspace.CurrentCamera
			if not camera then
				continue
			end
			local eye = camera.CFrame.Position
			-- Performance preset (GlobalShadows off): nothing would draw them anyway.
			local allowed = Lighting.GlobalShadows
			table.clear(list)
			table.clear(distances)
			for light in lights do
				local parent = light.Parent
				if parent and parent:IsA("BasePart") and light.Enabled then
					table.insert(list, light)
					table.insert(distances, if allowed then (parent.Position - eye).Magnitude else math.huge)
				elseif lights[light] then
					lights[light] = false
					light.Shadows = false
				end
			end
			local keep = LightShadows.choose(distances, RANGE, MAX_SHADOWED)
			for index, light in list do
				local on = keep[index] == true
				if lights[light] ~= on then
					lights[light] = on
					light.Shadows = on
				end
			end
		end
	end)
end

return LightShadows
