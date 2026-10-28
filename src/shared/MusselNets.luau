-- Shared rules for mussel nets, saved in dock-local coordinates like crab cages.
local MusselNets = {}

MusselNets.PRICE = 125
MusselNets.USES = 5
-- Each harvest is ready in three to five minutes.
MusselNets.SOAK_MIN, MusselNets.SOAK_MAX = 180, 300
MusselNets.MAX_STOCK = 25
MusselNets.MAX_PLACED = 6
MusselNets.SPACING = 4.5 -- studs between neighbouring nets
MusselNets.REACH = 16 -- studs from the angler to where the net lands
MusselNets.MIN_HARVEST = 2
MusselNets.MAX_HARVEST = 5
-- Water round the base's piers in dock-local studs (BoatDockFrame: -Z is the
-- water, the piers run along x = +-17 from z = 5 to -43). It stops short of the
-- fisherman's moorings at x = +-28 and the boat spawn past the pier ends.
MusselNets.ZONE = { MinX = -24, MaxX = 24, MinZ = -42, MaxZ = 6 }
-- What a net can catch. FishCatch.roll weighs these by rarity like any pool;
-- no fishing pool lists them, so mussels only ever come from nets.
MusselNets.Pool = { Name = "Mussel Net", Fish = { "BlueMussel", "GreenMussel", "GoldenMussel", "Kelp", "SeaLettuce" } }

-- Spots are kept to a tenth of a stud, so a net's saved spot doubles as its id.
function MusselNets.round(value: number): number
	return math.round(value * 10) / 10
end

-- Cage-local points that must all be open water: the middle, the corners with a
-- little clearance and the marker float beside it. `size` is the net's size.
-- Builds Vector3s, so only call it in Roblox.
function MusselNets.footprint(size: Vector3): { Vector3 }
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
function MusselNets.soak(rng: () -> number): number
	return MusselNets.SOAK_MIN + math.floor(rng() * (MusselNets.SOAK_MAX - MusselNets.SOAK_MIN + 1))
end

function MusselNets.find(angler, x: number, z: number): (number?, any)
	for index, net in angler.MusselNets.Placed do
		if math.abs(net.X - x) < 0.05 and math.abs(net.Z - z) < 0.05 then
			return index, net
		end
	end
	return nil, nil
end

-- `profile` is the whole wallet profile: the price comes out of its Cash.
function MusselNets.buyProblem(profile): string?
	if profile.Angler.MusselNets.Stock >= MusselNets.MAX_STOCK then
		return string.format("You can carry up to %d mussel nets. Set some out first.", MusselNets.MAX_STOCK)
	elseif profile.Cash < MusselNets.PRICE then
		return string.format("You need $%d for a mussel net.", MusselNets.PRICE)
	end
	return nil
end

-- These mutate the table they are given: the profile copy inside a save.
function MusselNets.buy(profile)
	local problem = MusselNets.buyProblem(profile)
	assert(problem == nil, problem)
	profile.Cash -= MusselNets.PRICE
	profile.Angler.Stats.CoinsSpent += MusselNets.PRICE
	profile.Angler.MusselNets.Stock += 1
end

-- Only the dock-local spot; the server also checks there is open water there.
function MusselNets.zoneProblem(x: number, z: number): string?
	local zone = MusselNets.ZONE
	if x ~= x or z ~= z or x < zone.MinX or x > zone.MaxX or z < zone.MinZ or z > zone.MaxZ then
		return "Drop mussel nets in the water by your own dock."
	end
	return nil
end

function MusselNets.placeProblem(angler, x: number, z: number): string?
	local nets = angler.MusselNets
	if nets.Stock < 1 then
		return "You have no mussel nets. Buy one at Tide & Tackle."
	elseif #nets.Placed >= MusselNets.MAX_PLACED then
		return string.format("You already have %d nets out. Pull one up first.", MusselNets.MAX_PLACED)
	end
	local problem = MusselNets.zoneProblem(x, z)
	if problem then
		return problem
	end
	x, z = MusselNets.round(x), MusselNets.round(z)
	local neighbours = table.clone(nets.Placed)
	for _, other in (angler.CrabCages and angler.CrabCages.Placed or {}) do
		table.insert(neighbours, other)
	end
	for _, net in neighbours do
		if (net.X - x) ^ 2 + (net.Z - z) ^ 2 < MusselNets.SPACING ^ 2 then
			return "That's too close to another net or cage."
		end
	end
	return nil
end

-- `soak` is rolled before saving, so every save retry sets the same timer.
function MusselNets.place(angler, x: number, z: number, now: number, soak: number)
	local problem = MusselNets.placeProblem(angler, x, z)
	assert(problem == nil, problem)
	angler.MusselNets.Stock -= 1
	table.insert(angler.MusselNets.Placed, {
		X = MusselNets.round(x),
		Z = MusselNets.round(z),
		Uses = MusselNets.USES,
		ReadyAt = now + soak,
	})
end

-- Seconds until a mussel is in, or 0 once the net is ready to pull up.
function MusselNets.remaining(net, now: number): number
	return math.max(0, net.ReadyAt - now)
end

function MusselNets.collectProblem(angler, x: number, z: number, now: number): string?
	local _, net = MusselNets.find(angler, x, z)
	if not net then
		return "That mussel net is gone."
	elseif now < net.ReadyAt then
		return "The net isn't ready yet. Give it a moment."
	end
	return nil
end

-- Returns the hauls the net has left. At 0 it has worn out and is removed.
function MusselNets.collect(angler, x: number, z: number, now: number, soak: number): number
	local problem = MusselNets.collectProblem(angler, x, z, now)
	assert(problem == nil, problem)
	local index, net = MusselNets.find(angler, x, z)
	angler.Stats.MusselNetsOpened += 1
	net.Uses -= 1
	if net.Uses <= 0 then
		table.remove(angler.MusselNets.Placed, index)
		return 0
	end
	net.ReadyAt = now + soak
	return net.Uses
end

return MusselNets
