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
		local description = Staff.description(role)
		local ok, model = pcall(function()
			return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
		end)
		description:Destroy()
		if ok then
			Staff.applyAppearance(model, role)
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
function Preview.show(view: ViewportFrame, role: string, status: TextLabel)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 32
	camera.Parent = view
	view.CurrentCamera = camera
	view.Ambient = Color3.fromRGB(185, 185, 185)
	view.LightColor = Color3.fromRGB(255, 244, 226)
	view.LightDirection = Vector3.new(-1, -1, -2)
	local angle, bounds, center = math.rad(20), nil, nil
	local function frame()
		if not bounds or not view.Parent then
			return
		end
		local aspect = math.max(0.1, view.AbsoluteSize.X / math.max(1, view.AbsoluteSize.Y))
		-- Fit every angle, including the shoulders when the preview is narrow.
		local width = math.sqrt(bounds.X * bounds.X + bounds.Z * bounds.Z)
		local distance = math.max(bounds.Y, width / aspect) / (2 * math.tan(math.rad(camera.FieldOfView / 2)))
		distance = distance * 1.12 + width / 2
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
			status.Text = "Preview unavailable. Reopen Staff to retry."
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
		status.Visible = false
		frame()
	end)
	return function(direction)
		angle += math.rad(45) * direction
		frame()
	end
end

return Preview
