local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local BoatCatalog = require(ReplicatedStorage.Shared.BoatCatalog)
local Freecam = require(script.Parent.Freecam)

local DrydockCamera = {}
local saved, connection = nil, nil
local display = nil

local function clearDisplay()
	if display then
		display:Destroy()
		display = nil
	end
end

function DrydockCamera.stop()
	clearDisplay()
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
	clearDisplay()
	local previewAttribute = if not launching
			and boatId
			and boatId ~= "Rowboat"
		then boatId .. "PreviewFrame"
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
		Freecam.stop()
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
		-- The purchase hull is created only after the lift rises. Browsing uses a
		-- client-local copy so each player can inspect a different boat.
		if not launching and boatId then
			if shop:GetAttribute("LaunchingUserId") then
				clearDisplay()
			elseif not display then
				local boating = ReplicatedStorage:FindFirstChild("Boating")
				local templates = boating and boating:FindFirstChild("Previews")
				local template = templates and templates:FindFirstChild(boatId)
				if template and template:IsA("Model") then
					display = template:Clone()
					local offset = if boatId == "PatrolBoat" or boatId == "Trawler"
						then CFrame.new(0, 0, -10.5)
						else CFrame.identity
					-- Templates are built at identity; retain their root's offset.
					display:PivotTo(start * offset * template:GetPivot())
					display.Parent = workspace
				end
			end
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
