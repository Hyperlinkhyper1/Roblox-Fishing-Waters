local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local BoatCatalog = require(ReplicatedStorage.Shared.BoatCatalog)

local DrydockCamera = {}
local saved, connection = nil, nil

function DrydockCamera.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if not saved then
		return
	end
	local camera = workspace.CurrentCamera
	if camera then
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		camera.CameraSubject = humanoid or saved.subject
		camera.CameraType = saved.kind
		camera.FieldOfView = saved.fov
		camera.CFrame = saved.frame
	end
	saved = nil
end

function DrydockCamera.show(shop: Model, launching: boolean, boatId: string?)
	local previewAttribute = if not launching and boatId == "FishingBoat"
		then "FishingBoatPreviewFrame"
		else "PreviewOriginFrame"
	local start = shop:GetAttribute(previewAttribute)
	local railEnd = shop:GetAttribute("SlipwayTopFrame")
	local finish = shop:GetAttribute("LaunchWaterFrame")
	local boatSpec = if boatId then BoatCatalog[boatId] else nil
	local framingScale = if boatSpec then math.max(1, math.sqrt(boatSpec.Length / BoatCatalog.Rowboat.Length)) else 1
	local camera = workspace.CurrentCamera
	if not camera or typeof(start) ~= "CFrame" or typeof(railEnd) ~= "CFrame" or typeof(finish) ~= "CFrame" then
		return
	end
	if not saved then
		saved = {
			subject = camera.CameraSubject,
			kind = camera.CameraType,
			frame = camera.CFrame,
			fov = camera.FieldOfView,
		}
	end
	if connection then
		connection:Disconnect()
	end
	local launchStartedAt = shop:GetAttribute("LaunchStartedAt") or workspace:GetServerTimeNow()
	task.spawn(function()
		-- The shipyard can stream out while the player talks inside the hall.
		pcall(function()
			Players.LocalPlayer:RequestStreamAroundAsync(if launching then finish.Position else start.Position, 3)
		end)
	end)
	connection = RunService.RenderStepped:Connect(function()
		camera = workspace.CurrentCamera
		if not camera then
			return
		end
		if not shop.Parent then
			DrydockCamera.stop()
			return
		end
		local frame = start
		if launching then
			local time = math.max(0, workspace:GetServerTimeNow() - launchStartedAt)
			local alpha = math.clamp(time / 7, 0, 1)
			alpha = alpha * alpha * (3 - 2 * alpha)
			frame = start:Lerp(finish, alpha)
		end
		local target = frame.Position + Vector3.new(0, framingScale, 0)
		local eye = target + start:VectorToWorldSpace(Vector3.new(-24, 15, -26) * framingScale)
		local view = CFrame.lookAt(eye, target)
		-- Leave the left of the scene clear for the stat card on every aspect ratio.
		local portrait = camera.ViewportSize.X < camera.ViewportSize.Y * 1.2
		local shift = if launching
			then Vector3.zero
			else (if portrait then view.UpVector else view.RightVector) * (8 * framingScale)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 50
		camera.CFrame = CFrame.lookAt(eye, target - shift)
		camera.Focus = CFrame.new(target)
	end)
end

return DrydockCamera
