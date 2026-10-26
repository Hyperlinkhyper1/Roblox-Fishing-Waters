-- Production CatchService and the company fisherman's catch function are
-- inserted by check-blackhole-catches.mjs; event rules are the real shared code.
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback)
			table.insert(callbacks, callback)
		end,
		Fire = function(_, ...)
			for _, callback in callbacks do
				callback(...)
			end
		end,
	}
end
local vector = {}
vector.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
	end
end
local Vector3 = {}
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vector)
end
vector.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
vector.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
local function typeof(value)
	return if getmetatable(value) == vector then "Vector3" else type(value)
end
local Vector2 = { new = Vector3.new }
local CFrame = {
	new = function()
		return {}
	end,
}
local clockNow = 100
local os = {
	clock = function()
		return clockNow
	end,
	time = function()
		return clockNow
	end,
}
local Random = {
	new = function()
		return {
			NextNumber = function()
				return 0.99
			end,
		}
	end,
}
local Enum = { Material = { Water = "Water" }, RaycastFilterType = { Exclude = "Exclude" } }
local RaycastParams = {
	new = function()
		return {}
	end,
}
local delayed, messages, instances = {}, {}, {}
local task = {
	delay = function(_, callback)
		table.insert(delayed, callback)
	end,
	spawn = function(callback, ...)
		callback(...)
	end,
	wait = function() end,
}
local Instance = {}
function Instance.new(class)
	local item = { ClassName = class, OnServerEvent = signal() }
	function item:FireClient(_, kind, payload)
		table.insert(messages, { kind = kind, payload = payload })
	end
	table.insert(instances, item)
	return item
end
local Players = { PlayerRemoving = signal() }
local services =
	{ Players = Players, ReplicatedStorage = {}, RunService = { Heartbeat = signal() }, CollectionService = {} }
local game = {
	GetService = function(_, key)
		return services[key]
	end,
}
local workspace = { Terrain = {} }
function workspace:GetServerTimeNow()
	return clockNow
end
function workspace:Raycast(origin)
	return { Instance = self.Terrain, Material = Enum.Material.Water, Position = Vector3.new(origin.X, 0, origin.Z) }
end
local FishMutations = (function()
	-- FISH_MUTATIONS_SOURCE --
end)()
local profile = { Angler = {}, OwnedBoats = { Rowboat = true } }
local eventActive, lastContextPosition = false, nil
local saved, crewRoll
local dependencies = {
	FishMutations = FishMutations,
	Catalog = {},
	Weather = {
		inLake = function()
			return true
		end,
		mutationContext = function(position)
			lastContextPosition = position
			return if eventActive then { corrupted = true, voidTouched = position.X >= 10 } else nil
		end,
	},
	AnglerCatalog = {
		DefaultPool = "Lake",
		Pools = { Lake = { Name = "Lake" } },
		Fish = { Trout = { Rarity = "Common", Name = "Trout" } },
		Rarities = {},
		Mutations = {},
	},
	FishCatch = {
		roll = function()
			return { FishId = "Trout", Kg = 2, Value = 10, Size = "Normal", Difficulty = 1 }
		end,
		minimumFightSeconds = function()
			return 1
		end,
	},
	DayNight = {
		clockTime = function()
			return 12
		end,
		isNight = function()
			return false
		end,
	},
	RodSkins = {
		apply = function(boosts)
			return boosts
		end,
	},
	RodUpgrades = {
		boosts = function()
			return { reel = 0 }
		end,
	},
	BoatService = {
		getProfile = function()
			return profile
		end,
		updateProgress = function(_, callback)
			callback(profile)
			return true
		end,
	},
	AnglerService = {
		recordCatch = function(_, id, mutation, kg, value, size, traits)
			saved = { FishId = id, Mutation = mutation, Kg = kg, Value = value, Size = size, Traits = traits }
			profile.Angler.Hand = saved
			return true
		end,
	},
	AnglerData = {
		fishermanCatch = function(angler, _, _, roll)
			crewRoll = roll
			return angler
		end,
	},
	CustomerService = { npc = {} },
	Rowboat = {},
	FishingBoat = {},
	BoatCatalog = { Rowboat = {} },
	Biomes = {},
	Paths = {
		unlocked = function()
			return true
		end,
	},
}
local toolAttributes = { RodId = "StarterRod" }
local tool = {
	IsA = function(_, class)
		return class == "Tool"
	end,
	GetAttribute = function(_, key)
		return toolAttributes[key]
	end,
	SetAttribute = function(_, key, value)
		toolAttributes[key] = value
	end,
}
local root = {
	Position = Vector3.new(5, 3, 0),
	IsA = function(_, class)
		return class == "BasePart"
	end,
}
local character = {
	FindFirstChildOfClass = function()
		return { Health = 100 }
	end,
	FindFirstChild = function()
		return root
	end,
	GetChildren = function()
		return { tool }
	end,
}
local player = {
	Parent = Players,
	Character = character,
	GetAttribute = function()
		return "Ready"
	end,
}
local CatchService = (function()
	-- CATCH_SERVICE_SOURCE --
end)()
CatchService.start()
local request
for _, item in instances do
	if item.Name == "Request" then
		request = item.OnServerEvent
	end
end
check(request ~= nil, "Real catch service registers its request handler")
local function rodCatch(atCast, atBite, targetX, playerX, expected, value)
	profile.Angler.Hand, saved = nil, nil
	clockNow += 20
	root.Position = Vector3.new(playerX, 3, 0)
	eventActive = atCast
	request:Fire(player, "Cast", Vector3.new(targetX, 4, 0))
	check(#delayed == 1, "Validated cast schedules a bite")
	eventActive = atBite
	table.remove(delayed, 1)()
	check(
		lastContextPosition.X == targetX and lastContextPosition.Y == 0,
		"Event uses the validated water target at the bite"
	)
	clockNow += 3
	request:Fire(player, "Reel", true)
	check(
		saved and saved.Mutation == expected and saved.Value == value,
		"Real rod award receives event traits and value"
	)
	local caught = messages[#messages]
	check(
		caught.kind == "Caught" and caught.payload.Mutation == expected and caught.payload.Value == value,
		"Caught payload agrees with saved traits and price"
	)
end
rodCatch(true, true, 14, 5, "Corrupted+VoidTouched", 45)
rodCatch(true, true, 4, 13, "Corrupted", 25)
rodCatch(false, true, 14, 5, "Corrupted+VoidTouched", 45)
rodCatch(true, false, 14, 5, "Normal", 10)
local landFish = (function()
	-- COMPANY_CATCH_SOURCE --
end)()
profile.Angler.Staff, profile.Angler.FishermanBoat = { Fisherman = true }, "Rowboat"
for _, case in { { true, 14, "Corrupted+VoidTouched", 45 }, { true, 4, "Corrupted", 25 }, { false, 14, "Normal", 10 } } do
	eventActive, crewRoll = case[1], nil
	local crew = { frame = { Position = Vector3.new(case[2], 0, 0) }, boatId = "Rowboat", spec = {}, catches = 0 }
	landFish(crew, player)
	check(lastContextPosition == crew.frame.Position, "Company fisherman uses the boat's fishing position")
	check(
		crewRoll and crewRoll.Traits.Mutation == case[3] and crewRoll.Value == case[4],
		"Company catches receive matching event traits and pricing"
	)
	check(crew.catches == 1, "Company catch completes normally")
end
print(string.format("Black hole catches: %d checks passed (rod and company catch paths; no Roblox runtime).", checks))
