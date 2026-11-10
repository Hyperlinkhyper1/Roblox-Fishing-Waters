-- Every NPC (any Humanoid model that is not a player's character) is put in a
-- collision group that never collides with other NPCs or with players, and its
-- parts stop raising Touched events. NPCs still collide with the Default world
-- group so walking Humanoids keep their floor and do not clip through walls.
local Players = game:GetService("Players")

local NpcCollision = {}
local GROUP = "BaseNPC"
local PLAYER_GROUP = "Players"
local configured = false
local started = false
local bound = setmetatable({}, { __mode = "k" })

local function configure()
	if configured then
		return
	end
	for _, name in { GROUP, PLAYER_GROUP } do
		if not workspace:IsCollisionGroupRegistered(name) then
			workspace:RegisterCollisionGroup(name)
		end
	end
	workspace:CollisionGroupSetCollidable(GROUP, GROUP, false)
	workspace:CollisionGroupSetCollidable(GROUP, PLAYER_GROUP, false)
	workspace:CollisionGroupSetCollidable(GROUP, "Default", true)
	configured = true
end

function NpcCollision.bind(model: Model)
	configure()
	if bound[model] then
		return
	end
	bound[model] = true

	local originals = {}
	local function assign(part: Instance)
		if part:IsA("BasePart") and originals[part] == nil then
			originals[part] = { group = part.CollisionGroup, touch = part.CanTouch }
			part.CollisionGroup = GROUP
			part.CanTouch = false
		end
	end
	-- Accessories or carried objects may be parented after the avatar is made.
	-- Restore their original settings if they leave the avatar, for example when a
	-- customer puts a carried fish back on a counter.
	model.DescendantAdded:Connect(assign)
	model.DescendantRemoving:Connect(function(part)
		local original = originals[part]
		if original ~= nil then
			part.CollisionGroup = original.group
			part.CanTouch = original.touch
			originals[part] = nil
		end
	end)
	for _, part in model:GetDescendants() do
		assign(part)
	end
end

local function bindCharacter(character: Model)
	local function assign(part: Instance)
		if part:IsA("BasePart") then
			part.CollisionGroup = PLAYER_GROUP
		end
	end
	character.DescendantAdded:Connect(assign)
	for _, part in character:GetDescendants() do
		assign(part)
	end
end

local function considerHumanoid(item: Instance)
	if not item:IsA("Humanoid") then
		return
	end
	-- Deferred so a spawning character's Player.Character is already set.
	task.defer(function()
		local model = item.Parent
		if model and model:IsA("Model") and item:IsDescendantOf(workspace) and not Players:GetPlayerFromCharacter(model) then
			NpcCollision.bind(model)
		end
	end)
end

-- Run before any service registers collision groups that loop over the
-- registered ones (BoatLaunchCollision), so they see the new groups.
function NpcCollision.start()
	if started then
		return
	end
	started = true
	configure()
	local function watchPlayer(player: Player)
		player.CharacterAdded:Connect(bindCharacter)
		if player.Character then
			bindCharacter(player.Character)
		end
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	workspace.DescendantAdded:Connect(considerHumanoid)
	for _, item in workspace:GetDescendants() do
		considerHumanoid(item)
	end
end

return NpcCollision
