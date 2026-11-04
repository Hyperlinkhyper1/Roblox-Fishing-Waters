-- Inventory thumbnails use the actual furniture builders' replicated templates,
-- so buying an item does not require its showroom or a placed copy to be streamed in.
local Preview = {}

-- Non-yielding clone for a world-space placement ghost. All templates are built
-- at the origin by the server, so their original pivot also retains that frame.
function Preview.clone(remotes: Instance, itemId: string): Model?
	local templates = remotes:FindFirstChild("Previews")
	local template = templates and templates:FindFirstChild(itemId)
	if not template or not template:IsA("Model") then return nil end
	return template:Clone()
end

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
			local direction = Vector3.new(1, 0.65, 1).Unit
			local orientation = CFrame.lookAt(Vector3.zero, -direction)
			local tangent = math.tan(math.rad(camera.FieldOfView / 2))
			local distance = 0.5
			for _, x in { -size.X / 2, size.X / 2 } do
				for _, y in { -size.Y / 2, size.Y / 2 } do
					for _, z in { -size.Z / 2, size.Z / 2 } do
						local corner = orientation:VectorToObjectSpace(box * Vector3.new(x, y, z) - box.Position)
						distance = math.max(distance, corner.Z + math.abs(corner.X) / (tangent * aspect), corner.Z + math.abs(corner.Y) / tangent)
					end
				end
			end
			camera.CFrame = CFrame.lookAt(box.Position + direction * distance * 1.12, box.Position)
		end
		view:GetPropertyChangedSignal("AbsoluteSize"):Connect(frame)
		frame()
	end)
end

return Preview
