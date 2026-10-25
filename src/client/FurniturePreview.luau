-- Inventory thumbnails use the actual furniture builders' replicated templates,
-- so buying an item does not require its showroom or a placed copy to be streamed in.
local Preview = {}

function Preview.show(view: ViewportFrame, remotes: Instance, itemId: string)
	task.spawn(function()
		local templates = remotes:WaitForChild("Previews", 10)
		local template = templates and templates:WaitForChild(itemId, 10)
		if not template or not template:IsA("Model") or not view.Parent then
			return
		end
		local world = Instance.new("WorldModel")
		world.Parent = view
		local model = template:Clone()
		model.Parent = world
		local box, size = model:GetBoundingBox()
		local camera = Instance.new("Camera")
		camera.FieldOfView = 32
		camera.Parent = view
		view.CurrentCamera = camera
		view.Ambient = Color3.fromRGB(185, 185, 185)
		view.LightColor = Color3.fromRGB(255, 244, 226)
		view.LightDirection = Vector3.new(-1, -1, -2)
		local function frame()
			local aspect = math.max(0.1, view.AbsoluteSize.X / math.max(1, view.AbsoluteSize.Y))
			local radius = size.Magnitude / 2
			local halfFov = math.atan(math.tan(math.rad(camera.FieldOfView / 2)) * math.min(1, aspect))
			local distance = radius / math.sin(halfFov) * 1.08
			camera.CFrame = CFrame.lookAt(box.Position + Vector3.new(1, 0.7, 1).Unit * distance, box.Position)
		end
		view:GetPropertyChangedSignal("AbsoluteSize"):Connect(frame)
		frame()
	end)
end

return Preview
