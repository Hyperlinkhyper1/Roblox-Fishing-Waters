-- Temporary launch filtering leaves island ground solid while docks, players,
-- props and other boats can be passed through. CanCollide is never changed.
local BoatLaunchCollision = {}
local GHOST = "DrydockLaunch"
local ISLAND = "IslandGround"
local started = false

local function classify(item: Instance)
	if not item:IsA("BasePart") then
		return
	end
	local map = workspace:FindFirstChild("Map")
	if not map or not item:IsDescendantOf(map) then
		return
	end
	local ancestor = item.Parent
	while ancestor and ancestor ~= workspace do
		if ancestor.Name == "Ground" then
			item.CollisionGroup = ISLAND
			return
		end
		ancestor = ancestor.Parent
	end
end

local function configure()
	for _, name in { GHOST, ISLAND } do
		if not workspace:IsCollisionGroupRegistered(name) then
			workspace:RegisterCollisionGroup(name)
		end
	end
	for _, group in workspace:GetRegisteredCollisionGroups() do
		workspace:CollisionGroupSetCollidable(GHOST, group.name, group.name == ISLAND)
	end
end

function BoatLaunchCollision.start()
	if started then
		return
	end
	started = true
	configure()
	workspace.Terrain.CollisionGroup = ISLAND
	-- Covers saved ground and distant islands generated after the harbour opens.
	workspace.DescendantAdded:Connect(classify)
	local map = workspace:FindFirstChild("Map")
	if map then
		for _, item in map:GetDescendants() do
			classify(item)
		end
	end
end

function BoatLaunchCollision.protect(model: Model, seconds: number)
	BoatLaunchCollision.start()
	configure()
	local original = {}
	local function protectPart(item: Instance)
		if item:IsA("BasePart") and original[item] == nil then
			original[item] = item.CollisionGroup
			item.CollisionGroup = GHOST
		end
	end
	for _, item in model:GetDescendants() do
		protectPart(item)
	end
	local added = model.DescendantAdded:Connect(protectPart)
	local destroying
	local restored = false
	local function restore()
		if restored then
			return
		end
		restored = true
		added:Disconnect()
		if destroying then
			destroying:Disconnect()
		end
		for part, group in original do
			if part.Parent then
				part.CollisionGroup = group
			end
		end
		model:SetAttribute("LaunchGraceEndsAt", nil)
	end
	destroying = model.Destroying:Connect(restore)
	model:SetAttribute("LaunchGraceEndsAt", workspace:GetServerTimeNow() + seconds)
	task.delay(seconds, restore)
end

return BoatLaunchCollision
