-- Uses replicated copies of the real builders, independent of world streaming.
local UserInputService = game:GetService("UserInputService")

local BoatPreview = {}

function BoatPreview.new(view: ViewportFrame, remotes: Instance, status: TextLabel)
	local world = Instance.new("WorldModel")
	world.Parent = view
	local camera = Instance.new("Camera")
	camera.FieldOfView = 34
	camera.Parent = view
	view.CurrentCamera = camera
	view.Ambient = Color3.fromRGB(185, 197, 211)
	view.LightColor = Color3.fromRGB(255, 241, 218)
	view.LightDirection = Vector3.new(-1, -1, -2)
	view.Active = true

	local selectedId: string? = nil
	local model: Model? = nil
	local target, radius = Vector3.zero, 1
	local yaw = math.rad(38)
	local drag: InputObject? = nil
	local lastX = 0
	local idle = 0
	local function frame()
		if not model then
			return
		end
		local aspect = math.max(0.1, view.AbsoluteSize.X / math.max(1, view.AbsoluteSize.Y))
		local halfFov = math.atan(math.tan(math.rad(camera.FieldOfView / 2)) * math.min(1, aspect))
		local distance = radius / math.sin(halfFov) * 1.06
		local direction = Vector3.new(math.sin(yaw), 0.6, -math.cos(yaw)).Unit
		camera.CFrame = CFrame.lookAt(target + direction * distance, target)
	end
	local function render()
		if not selectedId or model then
			return
		end
		local templates = remotes:FindFirstChild("Previews")
		local template = templates and templates:FindFirstChild(selectedId)
		if not template or not template:IsA("Model") then
			return
		end
		model = template:Clone()
		model.Parent = world
		local box, size = model:GetBoundingBox()
		target, radius = box.Position, size.Magnitude / 2
		status.Visible = false
		frame()
	end
	local function watchTemplates(folder: Instance)
		if folder.Name == "Previews" then
			folder.ChildAdded:Connect(render)
			render()
		end
	end
	remotes.ChildAdded:Connect(watchTemplates)
	local templates = remotes:FindFirstChild("Previews")
	if templates then
		watchTemplates(templates)
	end
	view:GetPropertyChangedSignal("AbsoluteSize"):Connect(frame)
	view.InputBegan:Connect(function(input)
		if
			selectedId
			and (
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			drag, lastX, idle = input, input.Position.X, 0
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if drag and (input == drag or input.UserInputType == Enum.UserInputType.MouseMovement) then
			yaw -= (input.Position.X - lastX) * 0.012
			lastX, idle = input.Position.X, 0
			frame()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input == drag then
			drag, idle = nil, 0
		end
	end)

	local controller = {}
	function controller.show(boatId: string?)
		if selectedId == boatId then
			return
		end
		selectedId, model, drag = boatId, nil, nil
		world:ClearAllChildren()
		yaw, idle = math.rad(38), 0
		status.Visible = boatId ~= nil
		status.Text = "Loading boat model…"
		render()
	end
	function controller.step(dt: number)
		if not model or drag then
			return
		end
		idle += dt
		if idle > 3 then
			yaw += math.min(dt, 0.1) * 0.14
			frame()
		end
	end
	return controller
end

return BoatPreview
