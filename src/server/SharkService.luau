-- Sharks are server-controlled so every crew member sees the same attacks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Biomes = require(Shared.Biomes)
local DayNight = require(Shared.DayNight)
local Weather = require(Shared.Weather)
local SpearSkins = require(Shared.SpearSkins)
local HullDamage = require(script.Parent.HullDamage)
local BoatService = require(script.Parent.BoatService)
local SharkModel = require(script.Parent.SharkModel)

local SharkService = {}
-- Sharks roam in packs of 1-3 around each boat at sea and only give chase when
-- a hull happens to pass within AGGRO_RANGE of a pack member.
local DAY_PACKS = 1
local NIGHT_PACKS = 2
local MIN_PACK_SIZE = 1
local MAX_PACK_SIZE = 3
local SPAWN_DELAY = 8
local SPAWN_DISTANCE = 120
local ROAM_SPEED = 12
local CHASE_SPEED = 55
local AGGRO_RANGE = 30
local LOSE_RANGE = 150
local DESPAWN_RANGE = 450
local PACK_SPACING = 7
local BITE_DAMAGE = 8
local BITE_INTERVAL = 12
local STEP = 0.1
local random = Random.new()
local SHARK_HEALTH = 15
local CONTRIBUTION_WINDOW = 30
local SPEAR_RANGE = 24
local SPEAR_COOLDOWN = 0.6
local sharksByModel = {}
local lastAttack = {}
local rewardCallback

-- Called once per eligible contributor when a shark dies. The caller owns
-- reward generation and persistence, keeping combat independent of inventory.
function SharkService.setKillRewardCallback(callback)
	rewardCallback = callback
end

local function removeShark(shark)
	sharksByModel[shark.model] = nil
	shark.model:Destroy()
end

local function damageShark(player: Player, shark, now: number, damage: number)
	if shark.dead or sharksByModel[shark.model] ~= shark then
		return
	end
	shark.contributors[player] = now
	shark.health = math.max(0, shark.health - damage)
	shark.model:SetAttribute("Health", shark.health)
	if shark.health > 0 then
		return
	end
	shark.dead = true
	removeShark(shark)
	if rewardCallback then
		for contributor, hitTime in shark.contributors do
			if contributor.Parent == Players and now - hitTime <= CONTRIBUTION_WINDOW then
				task.spawn(function()
					local ok, err = pcall(rewardCallback, contributor)
					if not ok then
						warn("[Sharks] Could not award drops: " .. tostring(err))
					end
				end)
			end
		end
	end
end

local function finiteVector(value): boolean
	return typeof(value) == "Vector3"
		and value.X == value.X
		and value.Y == value.Y
		and value.Z == value.Z
		and math.abs(value.X) < 1e7
		and math.abs(value.Y) < 1e7
		and math.abs(value.Z) < 1e7
end

local function attack(player: Player, aim)
	if not finiteVector(aim) or player:GetAttribute("OwnsBasicSpear") ~= true then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end
	local equipped = false
	for _, child in character:GetChildren() do
		if
			child:IsA("Tool")
			and child:GetAttribute("SpearId") == "BasicSpear"
			and child:GetAttribute("OwnerUserId") == player.UserId
		then
			equipped = true
			break
		end
	end
	if not equipped then
		return
	end
	local boosts = SpearSkins.boosts(player:GetAttribute("SpearSkin"), player:GetAttribute("SpearSkinWear"))
	local now = workspace:GetServerTimeNow()
	if now - (lastAttack[player] or -math.huge) < SPEAR_COOLDOWN / (1 + boosts.fireRate) then
		return
	end
	lastAttack[player] = now
	local origin = root.Position
	local delta = aim - origin
	if delta.Magnitude < 0.01 then
		return
	end
	local direction = delta.Unit
	local best, bestDistance
	for model, shark in sharksByModel do
		if not shark.dead and model.PrimaryPart then
			local center = model.PrimaryPart.Position + Vector3.new(0, -1.3, 0)
			local along = (center - origin):Dot(direction)
			local closest = origin + direction * math.clamp(along, 0, SPEAR_RANGE)
			-- The shark model is about 12 studs long; use a generous hit volume
			-- so aiming at its moving fins and tail is practical.
			if
				along > 0
				and along <= SPEAR_RANGE
				and (center - closest).Magnitude <= 5.5
				and (not bestDistance or along < bestDistance)
			then
				best, bestDistance = shark, along
			end
		end
	end
	if best then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local excluded = { character, workspace:FindFirstChild("Sharks") }
		params.FilterDescendantsInstances = excluded
		params.IgnoreWater = true
		-- A deck or railing should not block a crew member from attacking the
		-- shark alongside their boat. Other boats and world geometry still do.
		local boats = workspace:FindFirstChild("PlayerBoats")
		local floor = workspace:Raycast(origin, Vector3.new(0, -10, 0), params)
		if boats and floor and floor.Instance and floor.Instance:IsDescendantOf(boats) then
			local boat = floor.Instance
			while boat.Parent and boat.Parent ~= boats do
				boat = boat.Parent
			end
			if boat.Parent == boats then
				table.insert(excluded, boat)
				params.FilterDescendantsInstances = excluded
			end
		end
		local obstruction = workspace:Raycast(origin, direction * bestDistance, params)
		if not obstruction then
			damageShark(player, best, now, 1 + boosts.damage)
		end
	end
end

local function isOpenWater(position: Vector3, params: RaycastParams): boolean
	if
		not Biomes.inOceanBounds(position)
		or Weather.inLake(position)
	then
		return false
	end
	local hit =
		workspace:Raycast(Vector3.new(position.X, Biomes.WaterLevel + 25, position.Z), Vector3.new(0, -40, 0), params)
	return hit ~= nil and hit.Material == Enum.Material.Water
end

local function spawnPosition(target: Vector3, params: RaycastParams): Vector3?
	local start = random:NextNumber(0, math.pi * 2)
	for index = 0, 11 do
		local angle = start + index * math.pi / 6
		local candidate = target + Vector3.new(math.cos(angle) * SPAWN_DISTANCE, 0, math.sin(angle) * SPAWN_DISTANCE)
		if isOpenWater(candidate, params) then
			return candidate
		end
	end
	return nil
end

local function headingVector(heading: number): Vector3
	return Vector3.new(math.cos(heading), 0, math.sin(heading))
end

-- Members trail the leader in a loose arrowhead.
local function formationPosition(center: Vector3, heading: number, index: number): Vector3
	if index == 1 then
		return center
	end
	local forward = headingVector(heading)
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local side = if index == 2 then -1 else 1
	return center + right * (side * PACK_SPACING) - forward * PACK_SPACING
end

-- Flat offset from a position to the closest point on a hull, rather than a
-- large circular radius that would let sharks bite from far off a long side.
local function hullOffset(entry, position: Vector3): Vector3
	local root = entry.root
	local localPosition = root.CFrame:PointToObjectSpace(position)
	local halfBeam = (entry.boat:GetAttribute("HullBeam") or root.Size.X) / 2
	local halfLength = (entry.boat:GetAttribute("HullLength") or root.Size.Z) / 2
	local closest = root.CFrame:PointToWorldSpace(
		Vector3.new(
			math.clamp(localPosition.X, -halfBeam, halfBeam),
			0,
			math.clamp(localPosition.Z, -halfLength, halfLength)
		)
	)
	return Vector3.new(closest.X - position.X, 0, closest.Z - position.Z)
end

local function nearestMember(pack, entry): number
	local best = math.huge
	for _, shark in pack.sharks do
		best = math.min(best, hullOffset(entry, shark.position).Magnitude)
	end
	return best
end

local function removePack(packs, index: number)
	for _, shark in packs[index].sharks do
		if not shark.dead then
			removeShark(shark)
		end
	end
	table.remove(packs, index)
end

local function spawnPack(folder: Folder, owner: Player, root: BasePart, params: RaycastParams, now: number, weather)
	local center = spawnPosition(root.Position, params)
	if not center then
		return nil
	end
	-- Head roughly away from the boat so an encounter depends on where the
	-- player steers, not on the pack homing in.
	local outward = Vector3.new(center.X - root.Position.X, 0, center.Z - root.Position.Z)
	local heading = math.atan2(outward.Z, outward.X) + random:NextNumber(-1.2, 1.2)
	local pack = { owner = owner, sharks = {}, center = center, heading = heading }
	local facing = headingVector(heading)
	for index = 1, random:NextInteger(MIN_PACK_SIZE, MAX_PACK_SIZE) do
		local position = formationPosition(center, heading, index)
		if not isOpenWater(position, params) then
			position = center
		end
		local surface =
			Vector3.new(position.X, Biomes.WaterLevel + Weather.heightAt(position, now, weather), position.Z)
		local model = SharkModel.build(folder, CFrame.lookAt(surface, surface + facing))
		model:SetAttribute("Health", SHARK_HEALTH)
		model:SetAttribute("MaxHealth", SHARK_HEALTH)
		local shark = {
			model = model,
			position = position,
			direction = facing,
			lastBite = now,
			stuck = 0,
			health = SHARK_HEALTH,
			contributors = {},
		}
		sharksByModel[model] = shark
		table.insert(pack.sharks, shark)
	end
	return pack
end

local function moveShark(shark, goal: Vector3, speed: number, params: RaycastParams, keepDistance: number)
	local offset = Vector3.new(goal.X - shark.position.X, 0, goal.Z - shark.position.Z)
	local distance = offset.Magnitude
	if distance > 0.01 then
		shark.direction = offset.Unit
	end
	if distance <= keepDistance then
		return
	end
	local nextPosition = shark.position + shark.direction * math.min(speed * STEP, distance - keepDistance)
	if isOpenWater(nextPosition, params) then
		shark.position, shark.stuck = nextPosition, 0
	else
		shark.stuck += STEP
	end
end

function SharkService.start()
	local folder = Instance.new("Folder")
	folder.Name = "Sharks"
	folder.Parent = workspace
	local spearAttack = Instance.new("RemoteEvent")
	spearAttack.Name = "SpearAttack"
	spearAttack.Parent = ReplicatedStorage
	spearAttack.OnServerEvent:Connect(attack)
	Players.PlayerRemoving:Connect(function(player)
		lastAttack[player] = nil
		for _, shark in sharksByModel do
			shark.contributors[player] = nil
		end
	end)
	local spawnTimers = {}
	local packs = {}
	task.spawn(function()
		while true do
			local now = workspace:GetServerTimeNow()
			local night = DayNight.isNight(DayNight.clockTime(now))
			local weather = Weather.getState(now)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			local excluded = { folder, workspace:FindFirstChild("PlayerBoats") }
			for _, player in Players:GetPlayers() do
				if player.Character then
					table.insert(excluded, player.Character)
				end
			end
			params.FilterDescendantsInstances = excluded
			params.IgnoreWater = false
			params.RespectCanCollide = true
			local boats = {}
			for _, player in Players:GetPlayers() do
				local _, boat = BoatService.activeBoat(player)
				local root = boat and boat.PrimaryPart
				local health = boat and boat:GetAttribute("Health")
				local eligible = root
					and type(health) == "number"
					and health > 0
					and math.abs(root.Position.Y - Biomes.WaterLevel) < 20
					and isOpenWater(root.Position, params)
				if eligible then
					table.insert(boats, { player = player, boat = boat, root = root })
				end
			end

			for index = #packs, 1, -1 do
				local pack = packs[index]
				for sharkIndex = #pack.sharks, 1, -1 do
					local shark = pack.sharks[sharkIndex]
					if shark.dead or shark.stuck > 3 then
						if not shark.dead then
							removeShark(shark)
						end
						table.remove(pack.sharks, sharkIndex)
					end
				end
				if #pack.sharks == 0 then
					table.remove(packs, index)
				end
			end

			local seen = {}
			for _, entry in boats do
				local player = entry.player
				seen[player] = true
				local timer = spawnTimers[player]
				if not timer or timer.boat ~= entry.boat then
					timer = { boat = entry.boat, nextSpawn = now + SPAWN_DELAY }
					spawnTimers[player] = timer
				end
				local count = if night then NIGHT_PACKS else DAY_PACKS
				local owned = {}
				for index, pack in packs do
					if pack.owner == player then
						table.insert(owned, index)
					end
				end
				-- Extra packs swim off when day returns, but never mid-chase.
				for position = #owned, 1, -1 do
					if #owned <= count then
						break
					end
					local index = owned[position]
					if not packs[index].target then
						removePack(packs, index)
						table.remove(owned, position)
					end
				end
				if #owned < count and now >= timer.nextSpawn then
					local pack = spawnPack(folder, player, entry.root, params, now, weather)
					if pack then
						table.insert(packs, pack)
					end
					timer.nextSpawn = now + SPAWN_DELAY
				end
			end
			for player in spawnTimers do
				if not seen[player] then
					spawnTimers[player] = nil
				end
			end

			for index = #packs, 1, -1 do
				local pack = packs[index]
				if pack.owner and not seen[pack.owner] then
					pack.owner = nil
				end
				local target
				if pack.target then
					for _, entry in boats do
						if entry.boat == pack.target.boat and entry.player == pack.target.player then
							target = entry
							break
						end
					end
					if target and nearestMember(pack, target) > LOSE_RANGE then
						target = nil
					end
				end
				if not target then
					for _, entry in boats do
						if nearestMember(pack, entry) <= AGGRO_RANGE then
							target = entry
							break
						end
					end
				end
				if pack.target and not target then
					-- Give up and turn away rather than drifting after the boat.
					pack.heading += math.pi + random:NextNumber(-0.6, 0.6)
				end
				pack.target = target
				if not target then
					local nearby = false
					for _, entry in boats do
						if (entry.root.Position - pack.center).Magnitude <= DESPAWN_RANGE then
							nearby = true
							break
						end
					end
					if not nearby then
						removePack(packs, index)
						continue
					end
				end

				if target then
					local sum = Vector3.new(0, 0, 0)
					for _, shark in pack.sharks do
						local reach = 4
						local offset = hullOffset(target, shark.position)
						moveShark(shark, shark.position + offset, CHASE_SPEED, params, reach)
						if offset.Magnitude <= reach and now - shark.lastBite >= BITE_INTERVAL then
							if BoatService.damageBoat(target.player, BITE_DAMAGE) then
								-- Scar the hull where the shark struck. Its own thread keeps a
								-- cosmetic failure from stopping every shark in this loop.
								local surface = Vector3.new(
									shark.position.X,
									Biomes.WaterLevel + Weather.heightAt(shark.position, now, weather),
									shark.position.Z
								)
								task.spawn(HullDamage.bite, target.boat, surface, shark.direction)
							end
							shark.lastBite = now
						end
						sum += shark.position
					end
					pack.center = sum * (1 / #pack.sharks)
					local lead = pack.sharks[1].direction
					pack.heading = math.atan2(lead.Z, lead.X)
				else
					pack.heading += random:NextNumber(-0.06, 0.06)
					local nextCenter = pack.center + headingVector(pack.heading) * (ROAM_SPEED * STEP)
					if isOpenWater(nextCenter, params) then
						pack.center = nextCenter
					else
						pack.heading += math.pi * random:NextNumber(0.5, 1)
					end
					for sharkIndex, shark in pack.sharks do
						-- Stragglers catch up to their slot, then cruise with the pack.
						local goal = formationPosition(pack.center, pack.heading, sharkIndex)
						moveShark(shark, goal, ROAM_SPEED * 2, params, 0)
					end
				end

				for _, shark in pack.sharks do
					local wave = Weather.heightAt(shark.position, now, weather)
					local surface = Vector3.new(shark.position.X, Biomes.WaterLevel + wave, shark.position.Z)
					local biteAge = now - shark.lastBite
					local lunge = if target and biteAge < 0.6 then math.sin(biteAge / 0.6 * math.pi) * 1.5 else 0
					local direction = shark.direction
					shark.model:PivotTo(CFrame.lookAt(surface + direction * lunge, surface + direction * (lunge + 1)))
				end
			end
			task.wait(STEP)
		end
	end)
end

return SharkService
