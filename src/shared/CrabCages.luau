-- Crab cage rules shared by the server (which saves every change), the client
-- (which previews where a cage may go) and scripts/crab-cages.luau. Cages are
-- bought at Tide & Tackle and wait in Angler.CrabCages.Stock until the angler
-- drops one into the water by their own dock. A placed cage catches one crab per
-- soak and wears out after USES hauls. Pure Luau: no Roblox globals.
local CrabCages = {}

CrabCages.PRICE = 35
CrabCages.USES = 3
-- A crab crawls in somewhere between one and three minutes after each drop.
CrabCages.SOAK_MIN, CrabCages.SOAK_MAX = 60, 180
CrabCages.MAX_STOCK = 25
CrabCages.MAX_PLACED = 6
CrabCages.SPACING = 4.5 -- studs between neighbouring cages
CrabCages.REACH = 16 -- studs from the angler to where the cage lands
-- Added to the normal 0.75% mutation chance: crabs have a 1% base chance.
CrabCages.MUTATION_BONUS = 0.0025
-- Water round the base's piers in dock-local studs (BoatDockFrame: -Z is the
-- water, the piers run along x = +-17 from z = 5 to -43). It stops short of the
-- fisherman's moorings at x = +-28 and the boat spawn past the pier ends.
CrabCages.ZONE = { MinX = -24, MaxX = 24, MinZ = -42, MaxZ = 6 }
-- What a cage can catch. FishCatch.roll weighs these by rarity like any pool;
-- no fishing pool lists them, so crabs only ever come from cages.
CrabCages.Pool = { Name = "Crab Cage", Fish = { "ShoreCrab", "BlueCrab", "KingCrab" } }

-- Spots are kept to a tenth of a stud, so a cage's saved spot doubles as its id.
function CrabCages.round(value: number): number
	return math.round(value * 10) / 10
end

-- Cage-local points that must all be open water: the middle, the corners with a
-- little clearance and the marker float beside it. `size` is the cage's size.
-- Builds Vector3s, so only call it in Roblox.
function CrabCages.footprint(size: Vector3): { Vector3 }
	local half = size / 2 + Vector3.new(0.4, 0, 0.4)
	return {
		Vector3.zero,
		Vector3.new(half.X, 0, half.Z),
		Vector3.new(-half.X, 0, half.Z),
		Vector3.new(half.X, 0, -half.Z),
		Vector3.new(-half.X, 0, -half.Z),
		Vector3.new(size.X / 2 + 0.7, 0, size.Z / 2 - 0.35),
	}
end

-- `rng` returns a uniform [0, 1). Whole seconds, both ends included.
function CrabCages.soak(rng: () -> number): number
	return CrabCages.SOAK_MIN + math.floor(rng() * (CrabCages.SOAK_MAX - CrabCages.SOAK_MIN + 1))
end

function CrabCages.find(angler, x: number, z: number): (number?, any)
	for index, cage in angler.CrabCages.Placed do
		if math.abs(cage.X - x) < 0.05 and math.abs(cage.Z - z) < 0.05 then
			return index, cage
		end
	end
	return nil, nil
end

-- `profile` is the whole wallet profile: the price comes out of its Cash.
function CrabCages.buyProblem(profile): string?
	if profile.Angler.CrabCages.Stock >= CrabCages.MAX_STOCK then
		return string.format("You can carry up to %d crab cages. Set some out first.", CrabCages.MAX_STOCK)
	elseif profile.Cash < CrabCages.PRICE then
		return string.format("You need $%d for a crab cage.", CrabCages.PRICE)
	end
	return nil
end

-- These mutate the table they are given: the profile copy inside a save.
function CrabCages.buy(profile)
	local problem = CrabCages.buyProblem(profile)
	assert(problem == nil, problem)
	profile.Cash -= CrabCages.PRICE
	profile.Angler.Stats.CoinsSpent += CrabCages.PRICE
	profile.Angler.CrabCages.Stock += 1
end

-- Only the dock-local spot; the server also checks there is open water there.
function CrabCages.zoneProblem(x: number, z: number): string?
	local zone = CrabCages.ZONE
	if x ~= x or z ~= z or x < zone.MinX or x > zone.MaxX or z < zone.MinZ or z > zone.MaxZ then
		return "Drop crab cages in the water by your own dock."
	end
	return nil
end

function CrabCages.placeProblem(angler, x: number, z: number): string?
	local cages = angler.CrabCages
	if cages.Stock < 1 then
		return "You have no crab cages. Buy one at Tide & Tackle."
	elseif #cages.Placed >= CrabCages.MAX_PLACED then
		return string.format("You already have %d cages out. Pull one up first.", CrabCages.MAX_PLACED)
	end
	local problem = CrabCages.zoneProblem(x, z)
	if problem then
		return problem
	end
	x, z = CrabCages.round(x), CrabCages.round(z)
	for _, cage in cages.Placed do
		if (cage.X - x) ^ 2 + (cage.Z - z) ^ 2 < CrabCages.SPACING ^ 2 then
			return "That's too close to another cage."
		end
	end
	return nil
end

-- `soak` is rolled before saving, so every save retry sets the same timer.
function CrabCages.place(angler, x: number, z: number, now: number, soak: number)
	local problem = CrabCages.placeProblem(angler, x, z)
	assert(problem == nil, problem)
	angler.CrabCages.Stock -= 1
	table.insert(angler.CrabCages.Placed, {
		X = CrabCages.round(x),
		Z = CrabCages.round(z),
		Uses = CrabCages.USES,
		ReadyAt = now + soak,
	})
end

-- Seconds until a crab is in, or 0 once the cage is ready to pull up.
function CrabCages.remaining(cage, now: number): number
	return math.max(0, cage.ReadyAt - now)
end

function CrabCages.collectProblem(angler, x: number, z: number, now: number): string?
	local _, cage = CrabCages.find(angler, x, z)
	if not cage then
		return "That crab cage is gone."
	elseif now < cage.ReadyAt then
		return "Nothing has crawled in yet. Give it a moment."
	end
	return nil
end

-- Returns the hauls the cage has left. At 0 it has worn out and is removed.
function CrabCages.collect(angler, x: number, z: number, now: number, soak: number): number
	local problem = CrabCages.collectProblem(angler, x, z, now)
	assert(problem == nil, problem)
	local index, cage = CrabCages.find(angler, x, z)
	angler.Stats.CrabCagesOpened += 1
	cage.Uses -= 1
	if cage.Uses <= 0 then
		table.remove(angler.CrabCages.Placed, index)
		return 0
	end
	cage.ReadyAt = now + soak
	return cage.Uses
end

return CrabCages
