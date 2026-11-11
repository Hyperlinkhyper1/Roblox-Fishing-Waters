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
-- Chance rolls (NextNumber with no range) return `roll`; angles and jitter stay at 0.
local roll = 0
local Random = { new = function() return {
	NextNumber = function(_, low) return if low == nil then roll else 0 end,
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
		object.broadcasts = {}
		function object:FireAllClients(...) table.insert(self.broadcasts, { ... }) end
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
function workspace:Raycast(origin, direction, params)
	if not params.IgnoreWater then return if water then { Material = "Water" } else nil end
	return if blocked and (direction.X ~= 0 or direction.Z ~= 0) then { Instance = {}, Position = origin + direction * 0.5 } else nil
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
local Spears = (function()
-- SPEARS_SOURCE --
end)()
local dependencies = {
	SpearSkins = SpearSkins,
	Spears = Spears,
	SharkModel = { build = function(parent, pivot)
		local model = Instance.new("Model")
		model.Name = "Shark"
		model.PrimaryPart = Instance.new("Part")
		model:PivotTo(pivot)
		model.Parent = parent
		return model
	end },
	-- Shark waters (Coral Shallows) start at x = 400; nearer the bay is home water.
	Biomes = { MapHalfSize = 5200, WaterLevel = 0, at = function(position)
		return { id = if position.X >= 400 then "tropical" else "normal" }
	end, inOceanBounds = function(position)
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
local function liveSharks()
	local list = {}
	for _, object in objects do
		if object.ClassName == "Model" and object.Name == "Shark" and not object.destroyed then table.insert(list, object) end
	end
	return list
end
local function sharkPositions()
	local positions = {}
	for _, object in liveSharks() do
		-- The server moves only the root between full pivots.
		table.insert(positions, (object.PrimaryPart.CFrame or object.pivot).Position)
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

SharkService.start()
-- Rarity: failed chance rolls keep the reef empty; a successful roll brings one pack.
roll = 0.5
advance(65)
assert(sharks() == 0, "Failed spawn rolls must not bring sharks")
roll = 0.1
advance(21)
assert(sharks() == 1, "A daytime roll under 15% should spawn one shark")
roll = 0

local remote, thrown
for _, object in objects do
	if object.ClassName == "RemoteEvent" and object.Name == "SpearAttack" then remote = object end
	if object.ClassName == "RemoteEvent" and object.Name == "SpearThrown" then thrown = object end
end
assert(remote and thrown, "Spear remotes are published")
local target = liveSharks()[1]
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
local function targetPosition() return (target.PrimaryPart.CFrame or target.pivot).Position end
-- Stand `distance` studs beside the shark (the boat keeps 100 studs off so it
-- never aggroes), throw at its body and let the spear fly for `wait` seconds.
local function throw(who, distance, wait)
	local at = targetPosition()
	root.Position = at + Vector3.new(0, 0, 100)
	playerRoot.Position = at + Vector3.new(0, -Spears.THROW_HEIGHT, distance or 10)
	remote.fire(who or player, at + Vector3.new(0, -Spears.SHARK_DEPTH, 0))
	advance(wait or 1.1)
end
local function sharkHealth() return target:GetAttribute("Health") end

local oldContributor = { Parent = Players, UserId = 1, Character = player.Character, GetAttribute = player.GetAttribute }
local recentContributor = { Parent = Players, UserId = 1, Character = player.Character, GetAttribute = player.GetAttribute }
local rewards = {}
SharkService.setKillRewardCallback(function(recipient) rewards[recipient] = (rewards[recipient] or 0) + 1 end)
remote.fire(player, "invalid")
player.GetAttribute = function() return false end
throw()
player.GetAttribute = function(_, name) return name == "OwnsBasicSpear" end
player.Character.GetChildren = function() return {} end
throw()
player.Character.GetChildren = function() return { spear } end
assert(#thrown.broadcasts == 0, "Invalid aim, ownership or equipment must not throw a spear")
throw(player, 100)
assert(#thrown.broadcasts == 1, "A valid throw is shown to every client")
blocked = true
throw()
blocked = false
assert(sharkHealth() == 15, "Out-of-range and obstructed throws must not deal damage")

throw(oldContributor)
assert(sharkHealth() == 12, "A thrown spear deals three damage")
now += 31
throw(recentContributor)
throw()
throw(player, 10, 0.5)
assert(sharkHealth() == 3 and next(rewards) == nil, "A shark must survive four spear hits")
throw()
assert(sharkHealth() == 3, "Throw cooldown must be enforced")
throw()
assert(target.destroyed and rewards[player] == 1 and rewards[recentContributor] == 1 and not rewards[oldContributor],
	"The fifth hit must reward each recent contributor once, excluding old hits")
throw()
assert(rewards[player] == 1 and rewards[recentContributor] == 1, "A dead shark must not award twice")

-- Leading: a spear thrown at where the shark was misses once it has swum on.
advance(22)
assert(sharks() == 1, "A killed shark should respawn after the spawn delay")
target = liveSharks()[1]
local before = sharkHealth()
local at = targetPosition()
root.Position = at + Vector3.new(0, 0, 100)
playerRoot.Position = at + Vector3.new(0, -Spears.THROW_HEIGHT, 60)
remote.fire(player, at + Vector3.new(-14, -Spears.SHARK_DEPTH, 0))
advance(1.1)
assert(sharkHealth() == before, "Aiming behind a roaming shark must miss")
at = targetPosition()
playerRoot.Position = at + Vector3.new(0, -Spears.THROW_HEIGHT, 60)
-- 60 studs takes ~0.55 s; the roaming shark covers ~6.5 studs in that time.
remote.fire(player, at + Vector3.new(6.5, -Spears.SHARK_DEPTH, 0))
advance(1.1)
assert(sharkHealth() == before - 3, "Leading a roaming shark must hit it at range")

local chosenSkin, chosenWear = "Obsidian", 0.01
player.GetAttribute = function(_, name)
	if name == "OwnsBasicSpear" then return true end
	if name == "SpearSkin" then return chosenSkin end
	if name == "SpearSkinWear" then return chosenWear end
end
before = sharkHealth()
throw()
assert(math.abs(sharkHealth() - (before - 3 * 1.144)) < 0.0001, "Factory-new wear must increase shark damage")
chosenWear = 0.9
before = sharkHealth()
throw()
assert(math.abs(sharkHealth() - (before - 3 * 1.096)) < 0.0001, "Battle-scarred wear must reduce the damage boost")
assert(thrown.broadcasts[#thrown.broadcasts][4] == "Obsidian", "Throw broadcasts carry the spear skin")
-- Fire rate: cooldown 1 / (1 + boost). Count accepted throws, not damage.
chosenSkin, chosenWear = "GoldenHarpoon", 0.01
local function accepted(gap)
	local count = #thrown.broadcasts
	now += gap
	remote.fire(player, targetPosition() + Vector3.new(0, 30, 0))
	return #thrown.broadcasts > count
end
now += 2
assert(accepted(0), "A rested throw is accepted")
assert(not accepted(0.79), "Boosted cooldown must still reject throws that are too fast")
assert(accepted(0.02), "Factory-new fire rate must allow a faster throw")
chosenWear = 0.9
assert(not accepted(0.85), "Battle-scarred fire rate must enforce a longer cooldown")
assert(accepted(0.02), "Battle-scarred fire rate must allow throws after its cooldown")
advance(2)

-- Kill the remaining shark so the chase checks start from a fresh pack.
chosenSkin = nil
while not target.destroyed do throw() end
advance(22)
assert(sharks() == 1, "Another pack arrives after the delay")
root.Position = sharkPositions()[1] + Vector3.new(0, 0, 150)
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
root.Position = root.Position + Vector3.new(0, 0, 200)
advance(15)
assert(hits == hitsBeforeEscape and sharks() == 1 and nearestShark() > 150,
	"Outrunning a pack should end the chase without despawning it")

-- Leaving the reef: a chase ends at the biome edge and home water stays empty.
health = 100
root.Position = sharkPositions()[1] - Vector3.new(20, 0, 13)
advance(4)
local hitsAtEdge = hits
root.Position = Vector3.new(300, 0, root.Position.Z)
advance(15)
assert(hits == hitsAtEdge, "Sharks must not follow a boat out of shark waters")
advance(30)
assert(sharks() == 0, "A pack left far behind at the reef edge swims off")
advance(120)
assert(sharks() == 0, "Sharks never spawn outside the Coral Shallows and Cinder Isles")

root.Position = Vector3.new(1000, 0, 0)
night, packSize = true, 3
advance(45)
assert(sharks() == 4, "Nighttime should allow a second pack, each holding at most two sharks")
night = false
advance(0.2)
assert(sharks() == 2, "Extra packs should leave when day returns")
root.Position = Vector3.new(-100, 0, 0)
local hitsAtBay = hits
advance(5)
assert(sharks() == 0 and hits == hitsAtBay, "The bay should immediately stop attacks")
root.Position = Vector3.new(1000, 0, 0)
water = false
advance(30)
assert(sharks() == 0 and hits == hitsAtBay, "Land should not spawn sharks")
water = true
packSize = 2
health = 8
advance(21)
assert(sharks() == 2 and hits == hitsAtBay, "A pack of two should spawn and keep to itself")
root.Position = sharkPositions()[1] - Vector3.new(20, 0, 0)
advance(30)
assert(health == 0 and sharks() == 0, "Sharks should stop after the boat reaches zero health")
print("Shark service: reef-only rare spawns, thrown-spear flight, leading, 5-hit kills, contribution window, roaming packs and proximity chases passed.")
