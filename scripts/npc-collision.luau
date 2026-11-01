local registrations, filters = {}, {}
local workspace = {}
function workspace:IsCollisionGroupRegistered(name)
	return registrations[name] == true
end
function workspace:RegisterCollisionGroup(name)
	assert(not registrations[name], "Group registered twice")
	registrations[name] = true
end
function workspace:CollisionGroupSetCollidable(first, second, collidable)
	assert(registrations[first], "Group not registered")
	filters[first .. ":" .. second] = collidable
end

local NpcCollision = (function()
-- NPC_COLLISION_SOURCE --
end)()

local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback) table.insert(callbacks, callback) end,
		Fire = function(_, part) for _, callback in callbacks do callback(part) end end,
	}
end
local function part(group)
	return { CollisionGroup = group, IsA = function(_, name) return name == "BasePart" end }
end
local function npc(parts)
	return {
		DescendantAdded = signal(), DescendantRemoving = signal(),
		GetDescendants = function() return parts end,
	}
end
local root, body, accessory = part("Default"), part("Default"), part("Default")
local first = npc({ root, body, accessory })
NpcCollision.bind(first)
assert(registrations.BaseNPC and filters["BaseNPC:BaseNPC"] == false, "NPCs must not collide with each other")
assert(filters["BaseNPC:Default"] == true, "NPCs must still collide with the default world and players")
assert(root.CollisionGroup == "BaseNPC" and body.CollisionGroup == "BaseNPC" and accessory.CollisionGroup == "BaseNPC", "Existing rig parts not assigned")
local carried = part("Default")
first.DescendantAdded:Fire(carried)
assert(carried.CollisionGroup == "BaseNPC", "Carried parts must not obstruct another NPC")
first.DescendantRemoving:Fire(carried)
assert(carried.CollisionGroup == "Default", "A dropped object must recover its original group")
local secondRoot = part("Default")
NpcCollision.bind(npc({ secondRoot }))
assert(secondRoot.CollisionGroup == "BaseNPC", "Subsequent NPCs must share the group")
print("NPC collision: group setup, existing and late parts, and restored carried objects passed")
