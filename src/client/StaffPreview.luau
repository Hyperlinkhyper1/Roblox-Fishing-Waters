-- Cached, local-only avatars. No preview model ever enters the live world.
local Players = game:GetService("Players")
local Staff = require(game:GetService("ReplicatedStorage").Shared.StaffCatalog)
local Preview = {}
local templates, pending = {}, {}

-- Accessories can contain oversized or displaced handles. Frame the rig itself
-- so a single Marketplace item cannot shrink the entire portrait to a dot.
local function bodyBounds(model: Model): (Vector3, Vector3)
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local half = part.Size / 2
			for x = -1, 1, 2 do
				for y = -1, 1, 2 do
					for z = -1, 1, 2 do
						local point = part.CFrame:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
						low = Vector3.new(math.min(low.X, point.X), math.min(low.Y, point.Y), math.min(low.Z, point.Z))
						high = Vector3.new(math.max(high.X, point.X), math.max(high.Y, point.Y), math.max(high.Z, point.Z))
					end
				end
			end
		end
	end
	if low.X == math.huge then
		local box, size = model:GetBoundingBox()
		return box.Position, size
	end
	-- Leave room above the head for hats without trusting accessory bounds.
	high += Vector3.new(0, 0.8, 0)
	return (low + high) / 2, high - low
end

local function load(role, callback)
	if templates[role] then
		callback(templates[role])
		return
	end
	if pending[role] then
		table.insert(pending[role], callback)
		return
	end
	pending[role] = { callback }
	task.spawn(function()
		local description
		local ok, model = pcall(function()
			description = Staff.description(role)
			return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
		end)
		if description then
			description:Destroy()
		end
		if ok then
			Staff.finishModel(model)
			for _, item in model:GetDescendants() do
				if item:IsA("BasePart") then
					-- Keep the rig stationary while allowing accessory welds to place
					-- their handles correctly relative to the head and body.
					item.Anchored = item.Name == "HumanoidRootPart"
					item.CanCollide, item.CanTouch, item.CanQuery = false, false, false
				elseif item:IsA("Script") or item:IsA("LocalScript") then
					item:Destroy()
				end
			end
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
			templates[role] = model
		end
		local callbacks = pending[role]
		pending[role] = nil
		for _, waiting in callbacks do
			waiting(if ok then model else nil)
		end
	end)
end

-- Status text lives beside the viewport: nested GUI objects do not render in it.
function Preview.show(view: ViewportFrame, role: string, status: TextLabel, portrait: boolean?)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 32
	camera.Parent = view
	view.CurrentCamera = camera
	view.Ambient = Color3.fromRGB(185, 185, 185)
	view.LightColor = Color3.fromRGB(255, 244, 226)
	view.LightDirection = Vector3.new(-1, -1, -2)
	local angle, bounds, center = if portrait then 0 else math.rad(20), nil, nil
	local function frame()
		if not bounds or not view.Parent then
			return
		end
		local aspect = math.max(0.1, view.AbsoluteSize.X / math.max(1, view.AbsoluteSize.Y))
		-- Fit every angle, including the shoulders when the preview is narrow.
		local width = if portrait then bounds.X else math.sqrt(bounds.X * bounds.X + bounds.Z * bounds.Z)
		local distance = math.max(bounds.Y, width / aspect) / (2 * math.tan(math.rad(camera.FieldOfView / 2)))
		distance = if portrait then distance * 1.04 else distance * 1.12 + width / 2
		camera.CFrame = CFrame.lookAt(
			center + Vector3.new(math.sin(angle) * distance, bounds.Y * 0.035, -math.cos(angle) * distance),
			center
		)
	end
	view:GetPropertyChangedSignal("AbsoluteSize"):Connect(frame)
	load(role, function(template)
		-- The player may have changed tabs or closed Home while the avatar loaded.
		if not view.Parent then
			return
		end
		if not template then
			status.Text = "Preview unavailable. Reopen Workers to retry."
			return
		end
		local world = Instance.new("WorldModel")
		world.Parent = view
		local model = template:Clone()
		model.Name, model.Parent = role .. "Preview", world
		model:PivotTo(CFrame.new())
		center, bounds = bodyBounds(model)
		if portrait then
			-- Frame the head and torso, including headwear, instead of shrinking the
			-- entire rig into a card. The lower body is deliberately cropped.
			local height = bounds.Y * 0.58
			center += Vector3.new(0, (bounds.Y - height) / 2, 0)
			bounds = Vector3.new(bounds.X, height, bounds.Z)
		end
		status.Visible = false
		frame()
	end)
	return function(direction)
		angle += math.rad(45) * direction
		frame()
	end
end

return Preview
