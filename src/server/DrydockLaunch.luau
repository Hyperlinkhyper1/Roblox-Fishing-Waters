-- A server reservation spans the saved purchase and the complete launch.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Rowboat = require(script.Parent.Rowboat)
local FishingBoat = require(script.Parent.FishingBoat)
local Speedboat = require(script.Parent.Speedboat)
local RacingSpeedboat = require(script.Parent.RacingSpeedboat)
local PatrolBoat = require(script.Parent.PatrolBoat)

local DrydockLaunch = {}
local reservations = {}
local boats = {
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
	PatrolBoat = { previewName = "PatrolBoatPreview", frameAttribute = "PatrolBoatPreviewFrame", builder = PatrolBoat },
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
		return nil, "The drydock is launching another boat. Please wait."
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
	-- Only the rowboat is displayed in the single basin. Other hulls are built
	-- when purchased; the shop's viewport supplies their browsing previews.
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
		preview.Parent = shop:FindFirstChild("RearDrydock") or shop
	end
	-- Launch without querying water depth, terrain, boats, or nearby objects.
	local reservation = {
		boatId = selectedId,
		spec = spec,
		shop = shop,
		player = player,
		preview = preview,
		start = start.CFrame,
		railEnd = railEnd.CFrame,
		finish = finish.CFrame,
		cradle = cradle,
		cradleStart = cradle:GetPivot(),
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
	preview:PivotTo(start.CFrame * displayFrame:ToObjectSpace(reservation.previewStart))
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
		reservation.cradle:PivotTo(reservation.cradleStart)
	end
	if reservation.preview:IsDescendantOf(shop) then
		reservation.preview:PivotTo(reservation.previewStart)
	end
	if reservation.displacedPreview then
		reservation.displacedPreview.Parent = reservation.displacedParent
		reservation.displacedPreview:PivotTo(reservation.displacedStart)
	end
	if reservation.boatId ~= "Rowboat" then
		if reservation.preview:IsDescendantOf(shop) then
			reservation.preview:Destroy()
		end
		return
	end
	-- The very same preview becomes the buyer's boat; replenish the display only
	-- after it has left the slipway. A failed save keeps the original display.
	if not shop:FindFirstChild(reservation.spec.previewName, true) then
		local preview = reservation.spec.builder.build(reservation.displayFrame, true)
		preview.Name = reservation.spec.previewName
		preview:SetAttribute("BoatId", reservation.boatId)
		preview:SetAttribute("DisplayOnly", true)
		for _, piece in preview:GetDescendants() do
			if piece:IsA("BasePart") then
				piece:SetAttribute("PreviewCanCollide", piece.CanCollide)
				piece.CanCollide = false
			end
		end
		preview.Parent = shop:FindFirstChild("RearDrydock") or shop
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
				cradle:PivotTo(from:Lerp(reservation.cradleStart, alpha))
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
			local submerge = if to == reservation.finish then Vector3.new(0, -2 * alpha, 0) else Vector3.zero
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

return DrydockLaunch
