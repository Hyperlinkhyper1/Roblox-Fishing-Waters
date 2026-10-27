-- A server reservation spans the saved purchase and the complete launch.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Rowboat = require(script.Parent.Rowboat)
local FishingBoat = require(script.Parent.FishingBoat)
local Speedboat = require(script.Parent.Speedboat)
local RacingSpeedboat = require(script.Parent.RacingSpeedboat)
local PatrolBoat = require(script.Parent.PatrolBoat)
local Trawler = require(script.Parent.Trawler)

local DrydockLaunch = {}
-- A purchase first raises the underwater cradle into the basin, then lowers the new hull.
DrydockLaunch.RAISE_SECONDS = 3
local LIFT_SECONDS = 4
local reservations = {}
local boats = {
	Trawler = {
		previewName = "TrawlerPreview",
		frameAttribute = "TrawlerPreviewFrame",
		builder = Trawler,
		-- Full stern and boarding ladder need the same headwall clearance as the cruiser.
		launchOffset = CFrame.new(0, 0, -10.5),
	},
	RacingSpeedboat = {
		previewName = "RacingSpeedboatPreview",
		frameAttribute = "RacingSpeedboatPreviewFrame",
		builder = RacingSpeedboat,
	},
	Rowboat = { previewName = "LaunchPreview", frameAttribute = "PreviewOriginFrame", builder = Rowboat },
	FishingBoat = {
		previewName = "FishingBoatPreview",
		frameAttribute = "FishingBoatPreviewFrame",
		builder = FishingBoat,
	},
	Speedboat = { previewName = "SpeedboatPreview", frameAttribute = "SpeedboatPreviewFrame", builder = Speedboat },
	PatrolBoat = {
		previewName = "PatrolBoatPreview",
		frameAttribute = "PatrolBoatPreviewFrame",
		builder = PatrolBoat,
		-- Keep the enlarged stern ahead of the basin headwall; the bow overhangs the slipway.
		launchOffset = CFrame.new(0, 0, -10.5),
	},
}

local function marker(shop: Model, name: string): BasePart?
	local item = shop:FindFirstChild(name, true)
	return if item and item:IsA("BasePart") then item else nil
end

function DrydockLaunch.reserve(shop: Model, player: Player, boatId: string?)
	local selectedId = boatId or "Rowboat"
	local spec = boats[selectedId]
	if not spec then
		return nil, "This boat is not available at the drydock."
	end
	if reservations[shop] then
		return nil, "The drydock lift is in use. Please wait a moment."
	end
	local preview = shop:FindFirstChild(spec.previewName, true)
	local start, railEnd, finish =
		marker(shop, "PreviewOrigin"), marker(shop, "SlipwayTop"), marker(shop, "LaunchWater")
	local cradle = shop:FindFirstChild("LaunchCradle", true)
	local displayFrame = shop:GetAttribute(spec.frameAttribute)
	if
		(preview and not preview:IsA("Model"))
		or not start
		or not railEnd
		or not finish
		or not cradle
		or not cradle:IsA("Model")
		or typeof(displayFrame) ~= "CFrame"
	then
		return nil, "The drydock is not ready. Please try again shortly."
	end
	local launchOffset = spec.launchOffset or CFrame.new()
	displayFrame *= launchOffset
	-- The cradle rests underwater (LiftDrop below the basin) and the hull is built
	-- when purchased; it appears once the cradle has risen under it.
	local rest = cradle:GetPivot()
	local drop = shop:GetAttribute("LiftDrop")
	local raised = if type(drop) == "number" then rest + Vector3.new(0, drop, 0) else rest
	local parent = nil
	if not preview then
		preview = spec.builder.build(displayFrame, true)
		preview.Name = spec.previewName
		preview:SetAttribute("BoatId", selectedId)
		preview:SetAttribute("DisplayOnly", true)
		for _, piece in preview:GetDescendants() do
			if piece:IsA("BasePart") then
				piece:SetAttribute("PreviewCanCollide", piece.CanCollide)
				piece.CanCollide = false
			end
		end
		parent = shop:FindFirstChild("RearDrydock") or shop
	end
	-- Launch without querying water depth, terrain, boats, or nearby objects.
	local reservation = {
		boatId = selectedId,
		spec = spec,
		shop = shop,
		player = player,
		preview = preview,
		start = start.CFrame * launchOffset,
		railEnd = railEnd.CFrame,
		finish = finish.CFrame * launchOffset,
		cradle = cradle,
		cradleStart = raised,
		cradleRest = rest,
		parent = parent,
		previewStart = preview:GetPivot(),
		displayFrame = displayFrame,
	}
	reservations[shop] = reservation
	-- Keep the default display out of the world while another hull uses the bay.
	if selectedId ~= "Rowboat" then
		local rowPreview = shop:FindFirstChild("LaunchPreview", true)
		if rowPreview and rowPreview:IsA("Model") then
			reservation.displacedPreview = rowPreview
			reservation.displacedStart = rowPreview:GetPivot()
			reservation.displacedParent = rowPreview.Parent
			rowPreview.Parent = nil
		end
	end
	preview:PivotTo(reservation.start * displayFrame:ToObjectSpace(reservation.previewStart))
	preview:SetAttribute("BoatId", selectedId)
	shop:SetAttribute("LaunchingUserId", player.UserId)
	shop:SetAttribute("LaunchingBoatId", selectedId)
	return reservation
end

local function reset(reservation)
	local shop = reservation.shop
	if reservations[shop] ~= reservation then
		return
	end
	reservations[shop] = nil
	if not shop.Parent then
		if reservation.displacedPreview then
			reservation.displacedPreview:Destroy()
		end
		return
	end
	shop:SetAttribute("LaunchingUserId", nil)
	shop:SetAttribute("LaunchingBoatId", nil)
	shop:SetAttribute("LaunchStartedAt", nil)
	if reservation.cradle.Parent then
		reservation.cradle:PivotTo(reservation.cradleRest)
	end
	if reservation.preview:IsDescendantOf(shop) then
		reservation.preview:PivotTo(reservation.previewStart)
	end
	if reservation.displacedPreview then
		reservation.displacedPreview.Parent = reservation.displacedParent
		reservation.displacedPreview:PivotTo(reservation.displacedStart)
	end
	-- An unlaunched hull is only a temporary display.
	if reservation.preview:IsDescendantOf(shop) then
		reservation.preview:Destroy()
	end
end

-- Return asynchronously so the buyer regains the driving camera immediately.
function DrydockLaunch.release(reservation)
	if not reservation.activated then
		reset(reservation)
		return
	end
	if reservation.returning then
		return
	end
	reservation.returning = true
	task.spawn(function()
		local ok, reason = pcall(function()
			local model, shop = reservation.preview, reservation.shop
			while model.Parent and shop.Parent do
				local clear = true
				for _, piece in model:GetDescendants() do
					if piece:IsA("BasePart") then
						-- A bounding sphere around each piece conservatively covers
						-- rotated hulls, so the stern must clear the deck as well.
						local point = reservation.start:PointToObjectSpace(piece.Position)
						local radius = piece.Size.Magnitude / 2
						if math.abs(point.X) < 13 + radius and math.abs(point.Z) < 63 + radius then
							clear = false
							break
						end
					end
				end
				if clear then
					break
				end
				RunService.Heartbeat:Wait()
			end
			local cradle = reservation.cradle
			if not cradle.Parent or not shop.Parent then
				return
			end
			local from, elapsed = cradle:GetPivot(), 0
			repeat
				elapsed += RunService.Heartbeat:Wait()
				local alpha = math.min(elapsed / 5, 1)
				alpha = alpha * alpha * (3 - 2 * alpha)
				cradle:PivotTo(from:Lerp(reservation.cradleRest, alpha))
			until elapsed >= 5 or not cradle.Parent or not shop.Parent
		end)
		reset(reservation)
		if not ok then
			warn("[Boats] Lift return failed: " .. tostring(reason))
		end
	end)
end

function DrydockLaunch.run(reservation, activate)
	local model, cradle = reservation.preview, reservation.cradle
	local initialPivot = model:GetPivot()
	-- Bring the empty cradle up from the water, then set the new hull on it.
	local rise = reservation.cradleStart.Position - reservation.cradleRest.Position
	local elapsed = 0
	while rise.Magnitude > 0 and elapsed < DrydockLaunch.RAISE_SECONDS do
		elapsed += RunService.Heartbeat:Wait()
		if not reservation.shop.Parent then
			error("Drydock removed")
		end
		local alpha = math.min(elapsed / DrydockLaunch.RAISE_SECONDS, 1)
		cradle:PivotTo(reservation.cradleRest + rise * (alpha * alpha * (3 - 2 * alpha)))
	end
	if reservation.parent and not model.Parent then
		model.Parent = reservation.parent
	end
	-- Lowering ends with the cradle back at rest, under the floating hull.
	local sink = rise - (reservation.start.Position - reservation.finish.Position)
	local function move(from: CFrame, to: CFrame, duration: number)
		local elapsed = 0
		repeat
			elapsed += RunService.Heartbeat:Wait()
			if not model.Parent or not reservation.shop.Parent then
				error("Launch model removed")
			end
			local alpha = math.min(elapsed / duration, 1)
			alpha = alpha * alpha * (3 - 2 * alpha)
			local frame = from:Lerp(to, alpha)
			local offset = frame.Position - reservation.start.Position
			model:PivotTo(initialPivot + offset)
			-- The cradle descends further under the floating hull at the end.
			local submerge = if to ~= reservation.finish
				then Vector3.zero
				elseif rise.Magnitude > 0 then -sink * alpha
				else Vector3.new(0, -2 * alpha, 0)
			cradle:PivotTo(reservation.cradleStart + offset + submerge)
		until elapsed >= duration
	end
	move(reservation.start, reservation.finish, 7)
	local player = reservation.player
	if player.Parent ~= Players then
		return nil
	end
	-- Physics is attached only after the anchored lowering animation has ended.
	local ok, result = pcall(activate, player, reservation.finish, model)
	reservation.activated = not model:IsDescendantOf(reservation.shop)
	if not ok then
		error(result)
	end
	return result
end

local function tween(seconds: number, step: (number) -> ())
	local elapsed = 0
	repeat
		elapsed += RunService.Heartbeat:Wait()
		local alpha = math.min(elapsed / seconds, 1)
		step(alpha * alpha * (3 - 2 * alpha))
	until alpha >= 1
end

-- World height of the hull's lowest keel point.
local function keelBottom(model: Model): number?
	local lowest = nil
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") and piece.Name == "Keel" then
			local frame, size = piece.CFrame, piece.Size
			local reach = math.abs(frame.RightVector.Y) * size.X
				+ math.abs(frame.UpVector.Y) * size.Y
				+ math.abs(frame.LookVector.Y) * size.Z
			lowest = math.min(lowest or math.huge, frame.Position.Y - reach / 2)
		end
	end
	return lowest
end

local function moveLift(lift, rise: number)
	lift.rise = rise
	if lift.cradle.Parent then
		lift.cradle:PivotTo(lift.rest + Vector3.new(0, rise, 0))
	end
	pcall(lift.hoist, math.max(0, rise - lift.contact))
end

-- The refit lift: the cradle rises under a floating hull until its keel blocks
-- meet the keel, then carries the hull up into the dry basin. `hoist(height)`
-- holds the boat that far above where it floated (nil lets it go). Yields until
-- the hull is up; returns nil and a reason when the lift is busy.
function DrydockLaunch.lift(shop: Model, player: Player, model: Model, hoist: (number?) -> ())
	if reservations[shop] then
		return nil, "The drydock lift is in use. Please wait a moment."
	end
	local cradle = shop:FindFirstChild("LaunchCradle", true)
	local drop, keel = shop:GetAttribute("LiftDrop"), shop:GetAttribute("LiftKeelHeight")
	local bottom = keelBottom(model)
	if not cradle or not cradle:IsA("Model") or type(drop) ~= "number" or type(keel) ~= "number" or not bottom then
		return nil, "The drydock lift is not ready. Please try again shortly."
	end
	local lift = {
		shop = shop,
		player = player,
		cradle = cradle,
		rest = cradle:GetPivot(),
		drop = drop,
		hoist = hoist,
		rise = 0,
		-- How far the blocks climb before they touch the keel.
		contact = math.clamp(bottom - (keel - drop), 0, drop),
	}
	reservations[shop] = lift
	shop:SetAttribute("LiftingUserId", player.UserId)
	tween(LIFT_SECONDS, function(alpha)
		moveLift(lift, drop * alpha)
	end)
	return lift
end

-- Sets the hull back afloat and returns the cradle underwater. Safe to call more than once.
function DrydockLaunch.lower(lift)
	if reservations[lift.shop] ~= lift or lift.lowering then
		return
	end
	lift.lowering = true
	local from = lift.rise
	if from > 0 then
		tween(LIFT_SECONDS * from / lift.drop, function(alpha)
			moveLift(lift, from * (1 - alpha))
		end)
	end
	moveLift(lift, 0)
	pcall(lift.hoist, nil)
	reservations[lift.shop] = nil
	lift.shop:SetAttribute("LiftingUserId", nil)
end

return DrydockLaunch
