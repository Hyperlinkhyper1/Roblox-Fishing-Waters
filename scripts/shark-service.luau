-- Behavioral checks for SharkService's real update loop, with simulated time.
local Vector3 = {}
local vector = {}
-- Roblox vectors store float32 coordinates, so stopping exactly at bite range
-- can round a shark just outside it, especially on diagonal approaches.
local coordinate = buffer.create(4)
local function float32(value)
	buffer.writef32(coordinate, 0, value)
	return buffer.readf32(coordinate, 0)
end
function Vector3.new(x, y, z)
	return setmetatable({ X = float32(x or 0), Y = float32(y or 0), Z = float32(z or 0) }, vector)
end
function vector.__add(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
function vector.__sub(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
function vector.__mul(a, b)
	return Vector3.new(a.X * b, a.Y * b, a.Z * b)
end
function vector:Dot(b) return self.X * b.X + self.Y * b.Y + self.Z * b.Z end
function vector.__index(a, key)
	local length = math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z)
	if key == "Magnitude" then return length end
	if key == "Unit" then return Vector3.new(a.X / length, a.Y / length, a.Z / length) end
	return rawget(vector, key)
end
local function typeof(value) return if getmetatable(value) == vector then "Vector3" else type(value) end
local CFrame = {}
local frame = {}
frame.__mul = function() return setmetatable({}, frame) end
function CFrame.new() return setmetatable({}, frame) end
function CFrame.Angles() return setmetatable({}, frame) end
function CFrame.lookAt(at) return setmetatable({ Position = at }, frame) end
local Color3 = { fromRGB = function() return {} end }
local Enum = setmetatable({}, { __index = function()
	return setmetatable({}, { __index = function(_, name) return name end })
end })
local packSize = 1
local Random = { new = function() return {
	NextNumber = function() return 0 end,
	NextInteger = function(_, low, high) return math.clamp(packSize, low, high) end,
} end }
local RaycastParams = { new = function() return {} end }
local objects = {}
local Instance = {}
function Instance.new(class)
	local object = { ClassName = class, destroyed = false }
	object.attributes = {}
	function object:SetAttribute(name, value) self.attributes[name] = value end
	function object:GetAttribute(name) return self.attributes[name] end
	if class == "RemoteEvent" then
		object.OnServerEvent = { Connect = function(_, fn) object.fire = fn end }
	end
	function object:Destroy() self.destroyed = true end
	function object:PivotTo(pivot)
		self.pivot = pivot
		if self.PrimaryPart then self.PrimaryPart.CFrame = pivot end
	end
	function object:FindFirstChild() return nil end
	table.insert(objects, object)
	return object
end
local now, night, water, blocked = 0, false, true, false
local workspace = {}
function workspace:GetServerTimeNow() return now end
function workspace:FindFirstChild() return {} end
function workspace:Raycast(_, direction, params)
	if not params.IgnoreWater then return if water then { Material = "Water" } else nil end
	return if blocked and direction.X ~= 0 then { Instance = {} } else nil
end
local player = {}
local Players = { GetPlayers = function() return { player } end, PlayerRemoving = { Connect = function() end } }
player.Parent = Players
local services = { Players = Players, ReplicatedStorage = {} }
local game = { GetService = function(_, name) return services[name] end }
local root = { Position = Vector3.new(1000, 0, 0), Size = Vector3.new(8, 1, 10) }
root.CFrame = {
	PointToObjectSpace = function(_, position) return position - root.Position end,
	PointToWorldSpace = function(_, position) return position + root.Position end,
}
local health = 100
local boat = { PrimaryPart = root, GetAttribute = function(_, name) if name == "Health" then return health end end }
local hits, bites = 0, 0
local hitTimes = {}
local SpearSkins = (function()
-- SPEAR_SKINS_SOURCE --
end)()
local dependencies = {
	SpearSkins = SpearSkins,
	SharkModel = { build = function(parent, pivot)
		local model = Instance.new("Model")
		model.Name = "Shark"
		model.PrimaryPart = Instance.new("Part")
		model:PivotTo(pivot)
		model.Parent = parent
		return model
	end },
	Biomes = { MapHalfSize = 5200, WaterLevel = 0, inOceanBounds = function(position)
		return (math.abs(position.X) < 5200 and math.abs(position.Z) < 5200)
			or (position.X > 4200 and position.X < 8200 and position.Z > 4200 and position.Z < 8200)
	end },
	DayNight = { clockTime = function(t) return t end, isNight = function() return night end },
	Weather = {
		inLake = function(position) return position.X < 0 end,
		getState = function() return {} end,
		heightAt = function() return 0 end,
	},
	BoatService = {
		activeBoat = function() return "boat", boat end,
		damageBoat = function(_, damage)
			assert(damage == 8, "Each shark bite should deal eight hull damage")
			table.insert(hitTimes, now)
			hits += 1
			health = math.max(0, health - damage)
			return true
		end,
	},
	HullDamage = {
		bite = function(model, from, direction)
			assert(model == boat and typeof(from) == "Vector3" and direction.Magnitude > 0, "A bite marks the attacked hull")
			bites += 1
		end,
	},
}
local thread
local task = {
	spawn = function(fn, ...) if thread then fn(...) else thread = coroutine.create(fn) end end,
	wait = function() coroutine.yield() end,
}
local SharkService = (function()
-- SHARK_SERVICE_SOURCE --
end)()
local function advance(seconds)
	for _ = 1, math.floor(seconds * 10 + 0.5) do
		now += 0.1
		local ok, err = coroutine.resume(thread)
		assert(ok, tostring(err))
	end
end
local function sharks()
	local count = 0
	for _, object in objects do
		if object.ClassName == "Model" and object.Name == "Shark" and not object.destroyed then count += 1 end
	end
	return count
end
SharkService.start()
advance(10)
assert(sharks() == 1, "Daytime should spawn one shark")
local target, remote
for _, object in objects do
	if object.ClassName == "Model" and object.Name == "Shark" then target = object end
	if object.ClassName == "RemoteEvent" and object.Name == "SpearAttack" then remote = object end
end
local spear = { IsA = function(_, name) return name == "Tool" end, GetAttribute = function(_, name)
	if name == "SpearId" then return "BasicSpear" end
	if name == "OwnerUserId" then return 1 end
end }
local playerRoot = { Position = Vector3.new(1000, 0, 0), IsA = function(_, name) return name == "BasePart" end }
player.UserId = 1
player.GetAttribute = function(_, name) return name == "OwnsBasicSpear" end
player.Character = {
	FindFirstChildOfClass = function() return { Health = 100 } end,
	FindFirstChild = function() return playerRoot end,
	GetChildren = function() return { spear } end,
}
target.PrimaryPart.Position = Vector3.new(1008, 1.3, 0)
local oldContributor = { Parent = Players, UserId = 1, Character = player.Character, GetAttribute = player.GetAttribute }
local recentContributor = { Parent = Players, UserId = 1, Character = player.Character, GetAttribute = player.GetAttribute }
local rewards = {}
SharkService.setKillRewardCallback(function(recipient) rewards[recipient] = (rewards[recipient] or 0) + 1 end)
remote.fire(player, "invalid")
player.GetAttribute = function() return false end
remote.fire(player, Vector3.new(1008, 0, 0))
player.GetAttribute = function(_, name) return name == "OwnsBasicSpear" end
player.Character.GetChildren = function() return {} end
remote.fire(player, Vector3.new(1008, 0, 0))
player.Character.GetChildren = function() return { spear } end
target.PrimaryPart.Position = Vector3.new(1040, 1.3, 0)
remote.fire(player, Vector3.new(1040, 0, 0))
now += 0.7
target.PrimaryPart.Position = Vector3.new(1008, 1.3, 0)
blocked = true
remote.fire(player, Vector3.new(1008, 0, 0))
blocked = false
assert(target:GetAttribute("Health") == 15, "Invalid aim, ownership, equipment, range or obstruction must not deal damage")
now += 0.7
remote.fire(oldContributor, Vector3.new(1008, 0, 0))
now += 31
remote.fire(recentContributor, Vector3.new(1008, 0, 0))
for _ = 1, 12 do
	now += 0.7
	remote.fire(player, Vector3.new(1008, 0, 0))
end
assert(target:GetAttribute("Health") == 1 and next(rewards) == nil, "A shark must survive 14 spear hits")
remote.fire(player, Vector3.new(1008, 0, 0))
assert(target:GetAttribute("Health") == 1, "Attack cooldown must be enforced")
now += 0.7
remote.fire(player, Vector3.new(1008, 0, 0))
assert(target.destroyed and rewards[player] == 1 and rewards[recentContributor] == 1 and not rewards[oldContributor],
	"The fifteenth hit must reward each recent contributor once, excluding old hits")
now += 0.7
remote.fire(player, Vector3.new(1008, 0, 0))
assert(rewards[player] == 1 and rewards[recentContributor] == 1, "A dead shark must not award twice")
advance(10)
assert(sharks() == 1, "A killed shark should eventually respawn")
local secondTarget
for _, object in objects do
	if object.ClassName == "Model" and object.Name == "Shark" and not object.destroyed then secondTarget = object end
end
secondTarget.PrimaryPart.Position = Vector3.new(1008, 1.3, 0)
local chosenSkin, chosenWear = "Obsidian", 0.01
player.GetAttribute = function(_, name)
	if name == "OwnsBasicSpear" then return true end
	if name == "SpearSkin" then return chosenSkin end
	if name == "SpearSkinWear" then return chosenWear end
end
now += 0.7
remote.fire(player, Vector3.new(1008, 0, 0))
assert(math.abs(secondTarget:GetAttribute("Health") - (15 - 1.144)) < 0.00001, "Factory-new wear must increase shark damage")
chosenWear = 0.9
now += 0.7
remote.fire(player, Vector3.new(1008, 0, 0))
assert(math.abs(secondTarget:GetAttribute("Health") - (15 - 1.144 - 1.096)) < 0.00001, "Battle-scarred wear must reduce the damage boost")
chosenSkin, chosenWear = "GoldenHarpoon", 0.01
now += 0.7
remote.fire(player, Vector3.new(1008, 0, 0))
local fastHealth = secondTarget:GetAttribute("Health")
now += 0.47
remote.fire(player, Vector3.new(1008, 0, 0))
assert(secondTarget:GetAttribute("Health") == fastHealth, "Boosted cooldown must still reject attacks that are too fast")
now += 0.02
remote.fire(player, Vector3.new(1008, 0, 0))
assert(secondTarget:GetAttribute("Health") == fastHealth - 1, "Factory-new fire rate must allow a faster attack")
chosenWear = 0.9
now += 0.50
remote.fire(player, Vector3.new(1008, 0, 0))
assert(secondTarget:GetAttribute("Health") == fastHealth - 1, "Battle-scarred fire rate must enforce a longer cooldown")
now += 0.03
remote.fire(player, Vector3.new(1008, 0, 0))
assert(secondTarget:GetAttribute("Health") == fastHealth - 2, "Battle-scarred fire rate must allow attacks after its cooldown")
local function sharkPositions()
	local positions = {}
	for _, object in objects do
		if object.ClassName == "Model" and object.Name == "Shark" and not object.destroyed then
			-- The server moves only the root between full pivots.
			table.insert(positions, (object.PrimaryPart.CFrame or object.pivot).Position)
		end
	end
	return positions
end
local function nearestShark()
	local best = math.huge
	for _, position in sharkPositions() do
		best = math.min(best, (position - root.Position).Magnitude)
	end
	return best
end
advance(15)
assert(hits == 0 and nearestShark() > 100, "A roaming pack must not seek a boat that keeps its distance")
root.Position = sharkPositions()[1] - Vector3.new(20, 0, 13)
advance(15)
assert(hits > 0 and health < 100, "Driving close to a pack should start a chase that ends in bites")
assert(health == 100 - hits * 8, "Bites must reduce the boat's health")
local hitsAtContact = hits
advance(12)
assert(hits > hitsAtContact, "A shark resting alongside the hull must keep biting")
for index = 2, #hitTimes do
	assert(hitTimes[index] - hitTimes[index - 1] >= 12, "Repeated bites must respect the cooldown")
end
assert(bites == hits, "Every damaging bite should scar the hull")
root.Position = root.Position + Vector3.new(0, 0, 80)
advance(3)
assert(nearestShark() < 12, "A chasing pack should follow the boat")
local hitsBeforeEscape = hits
root.Position = root.Position + Vector3.new(0, 0, 300)
advance(15)
assert(hits == hitsBeforeEscape and sharks() == 1 and nearestShark() > 150,
	"Outrunning a pack should end the chase without despawning it")
night, packSize = true, 3
advance(20)
assert(sharks() == 4, "Nighttime should add a second pack, holding up to three sharks")
night = false
advance(0.2)
assert(sharks() == 1, "Extra packs should leave when day returns")
root.Position = Vector3.new(-100, 0, 0)
local hitsAtBay = hits
advance(5)
assert(sharks() == 0 and hits == hitsAtBay, "The bay should immediately stop attacks")
root.Position = Vector3.new(1000, 0, 0)
water = false
advance(10)
assert(sharks() == 0 and hits == hitsAtBay, "Land should not spawn sharks")
water = true
packSize = 2
health = 8
advance(10)
assert(sharks() == 2 and hits == hitsAtBay, "A pack of two should spawn and keep to itself")
root.Position = sharkPositions()[1] - Vector3.new(20, 0, 0)
advance(30)
assert(health == 0 and sharks() == 0, "Sharks should stop after the boat reaches zero health")
print("Shark service: spear validation, 15-hit kills, contribution window, roaming packs and proximity chases passed.")
