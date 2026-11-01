-- Moving NPCs share a collision group so they can pass one another without
-- changing their collisions with the world or with players.
local NpcCollision = {}
local GROUP = "BaseNPC"
local configured = false

function NpcCollision.bind(model: Model)
	if not configured then
		if not workspace:IsCollisionGroupRegistered(GROUP) then
			workspace:RegisterCollisionGroup(GROUP)
		end
		workspace:CollisionGroupSetCollidable(GROUP, GROUP, false)
		workspace:CollisionGroupSetCollidable(GROUP, "Default", true)
		configured = true
	end

	local originals = {}
	local function assign(part: Instance)
		if part:IsA("BasePart") and originals[part] == nil then
			originals[part] = part.CollisionGroup
			part.CollisionGroup = GROUP
		end
	end
	-- Accessories or carried objects may be parented after the avatar is made.
	-- Restore their original group if they leave the avatar, for example when a
	-- customer puts a carried fish back on a counter.
	model.DescendantAdded:Connect(assign)
	model.DescendantRemoving:Connect(function(part)
		local original = originals[part]
		if original ~= nil then
			part.CollisionGroup = original
			originals[part] = nil
		end
	end)
	for _, part in model:GetDescendants() do
		assign(part)
	end
end

return NpcCollision
