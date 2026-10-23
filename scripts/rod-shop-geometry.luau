-- Production plaza and shop builders are inserted by check-rod-shop.mjs.
-- Recording mocks check geometry and migrations, not Roblox rendering or live physics.
local root = Instance.new("Folder")
root.Name = "Map"
local village = Instance.new("Model")
village.Name, village.Parent = "Village", root
local plazaCenter = shape.toWorld({ 870, 694 })
Harbour.buildPlaza(village, plazaCenter, Random.new(Biomes.Seed + 1))
local plaza = root:FindFirstChild("Plaza", true)
local paving
for _, piece in plaza:GetChildren() do
	if piece:IsA("BasePart") and piece.Size.X == 116 and piece.Size.Z == 116 then
		paving = piece
	end
end
assert(paving, "Plaza paving was not built")
local plazaFrame = paving.CFrame * CFrame.new(0, paving.Size.Y / 2, 0)
-- The rod shop is built by the real plaza builder, so walk its entrance
-- against every existing plaza prop as well as its own furnished interior.
local rodShop = plaza:FindFirstChild("FishingRodShop")
check(rodShop and CollectionService:HasTag(rodShop, "FishingRodShop"), "Plaza lacks its tagged tackle shop")
check(rodShop:GetAttribute("Price") == 0 and rodShop:GetAttribute("RodId") == "StarterRod", "Starter rod must be free")
local rodFrame = plazaFrame * CFrame.new(-43, 0, 34) * CFrame.Angles(0, -math.pi / 2, 0)
local interiorFrame, interiorSize = rodShop:GetAttribute("InteriorFrame"), rodShop:GetAttribute("InteriorSize")
check(
	typeof(interiorFrame) == "CFrame"
		and interiorSize ~= nil
		and interiorSize.X > 0
		and interiorSize.Y > 0
		and interiorSize.Z > 0,
	"Rod purchase needs an interior volume"
)
local buyRod = rodShop:FindFirstChild("BuyFishingRodPrompt", true)
check(
	buyRod and buyRod:IsA("ProximityPrompt") and buyRod.Parent.Name == "CounterTop",
	"Rod browse prompt must be on the indoor counter"
)
local customer = rodFrame * Vector3.new(3.5, 3.3, 2.3)
local inside = interiorFrame:PointToObjectSpace(customer)
check(
	math.abs(inside.X) < interiorSize.X / 2
		and math.abs(inside.Y) < interiorSize.Y / 2
		and math.abs(inside.Z) < interiorSize.Z / 2,
	"Counter customer is outside the server purchase volume"
)
check(
	(customer - buyRod.Parent.Position).Magnitude < buyRod.MaxActivationDistance,
	"Browse prompt is out of reach from customer side"
)
local rodSolids = {}
for _, piece in plaza:GetDescendants() do
	if piece:IsA("BasePart") and piece.CanCollide then
		table.insert(rodSolids, piece)
	end
end
local rodRoute = { Vector3.new(-15, 3.4, 37.5), Vector3.new(-30, 3.4, 37.5), Vector3.new(-45.3, 3.4, 37.5) }
for segment = 1, #rodRoute - 1 do
	local a, b = rodRoute[segment], rodRoute[segment + 1]
	local steps = math.ceil((b - a).Magnitude / 0.5)
	for step = 0, steps do
		local avatar = { Size = Vector3.new(3, 5.5, 3), CFrame = plazaFrame * CFrame.new(a:Lerp(b, step / steps)) }
		for _, obstacle in rodSolids do
			check(not overlaps(avatar, obstacle), "Tackle shop route blocked by " .. obstacle:GetFullName())
		end
	end
end
-- Reproduce the server's eye-to-prompt ray against the actual part boxes.
-- The counter may be the first hit; a perched sign or display may not.
local function segmentHit(a, b, obstacle)
	local origin = obstacle.CFrame:PointToObjectSpace(a)
	local delta = obstacle.CFrame:VectorToObjectSpace(b - a)
	local near, far = 0, 1
	for _, axis in { "X", "Y", "Z" } do
		local half = obstacle.Size[axis] / 2
		if math.abs(delta[axis]) < EPS then
			if math.abs(origin[axis]) > half then
				return nil
			end
		else
			local low = (-half - origin[axis]) / delta[axis]
			local high = (half - origin[axis]) / delta[axis]
			near = math.max(near, math.min(low, high))
			far = math.min(far, math.max(low, high))
			if near > far then
				return nil
			end
		end
	end
	return near
end
for _, x in { -2, 0, 3.5 } do
	local eye = rodFrame * Vector3.new(x, 5.2, 2)
	local target = buyRod.Parent.Position
	local counterHit = segmentHit(eye, target, buyRod.Parent)
	check(counterHit ~= nil, "Browse eye ray does not reach its counter")
	for _, obstacle in rodShop:GetDescendants() do
		if obstacle:IsA("BasePart") and obstacle ~= buyRod.Parent and obstacle.CanQuery ~= false then
			local hit = segmentHit(eye, target, obstacle)
			check(
				not hit or hit >= counterHit - EPS,
				"Browse ray from aisle x=" .. x .. " is blocked by " .. obstacle.Name
			)
		end
	end
end
for _, width in { 116, 120 } do
	local saved = Instance.new("Folder")
	local savedPlaza = Instance.new("Model")
	savedPlaza.Name, savedPlaza.Parent = "Plaza", saved
	local savedFloor = Instance.new("Part")
	savedFloor.Size, savedFloor.CFrame, savedFloor.Parent =
		Vector3.new(width, 0.6, width), CFrame.new(112, 8.5, -92) * CFrame.Angles(0, 0.72, 0), savedPlaza
	local unrelated = Instance.new("Part")
	unrelated.Name, unrelated.Parent = "UnrelatedPlazaDecoration", savedPlaza
	dependencies.RodShop.ensure(saved)
	local result = savedPlaza:FindFirstChild("FishingRodShop")
	check(result ~= nil, "Saved plaza " .. width .. " did not receive its tackle shop")
	local expected = savedFloor.CFrame * CFrame.new(0, 0.3, 0) * CFrame.new(-43, 0, 34)
	check(
		(result.PrimaryPart.Position - (expected * Vector3.new(0, -0.18, 0))).Magnitude < EPS,
		"Saved tackle shop ignored paving position or rotation"
	)
	local afterRodEnsure = #saved:GetDescendants()
	dependencies.RodShop.ensure(saved)
	check(
		savedPlaza:FindFirstChild("FishingRodShop") == result and #saved:GetDescendants() == afterRodEnsure,
		"Rod shop saved-map upgrade is not idempotent"
	)
	check(unrelated.Parent == savedPlaza, "Rod shop upgrade removed an unrelated plaza decoration")
	result:SetAttribute("LayoutVersion", 0)
	dependencies.RodShop.ensure(saved)
	check(
		result.Parent == nil and savedPlaza:FindFirstChild("FishingRodShop") ~= result,
		"Stale tackle shop layout did not upgrade"
	)
end
assert(failures == 0, tostring(failures) .. " tackle shop geometry checks failed")
print(
	string.format(
		"PASS: %d tackle shop geometry assertions; actual plaza approach and interior clearances, free starter rod contract, current and legacy saved-map upgrades, and idempotency. Recording mocks do not verify live Roblox rendering or physics.",
		checks
	)
)
