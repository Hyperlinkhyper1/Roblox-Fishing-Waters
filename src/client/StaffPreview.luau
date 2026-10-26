-- Cached, local-only avatars. No preview model ever enters the live world.
local Players = game:GetService("Players")
local Staff = require(game:GetService("ReplicatedStorage").Shared.StaffCatalog)
local Preview = {}
local templates, pending = {}, {}

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
					item.Anchored = true
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
		local box
		box, bounds = model:GetBoundingBox()
		center = box.Position
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
