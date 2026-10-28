-- Helm camera views. Trailing restores Roblox's follow camera; the other modes
-- frame the boat or put the eye at the helm without changing driving input.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BoatCamera = {}

local MODES = table.freeze({
	table.freeze({ Name = "Trailing", Label = "Trailing" }),
	table.freeze({ Name = "Front", Label = "Front" }),
	table.freeze({ Name = "Cockpit", Label = "Cockpit" }),
	table.freeze({ Name = "Side", Label = "Side" }),
})

local player = Players.LocalPlayer
local modeIndex = 1
local activeBoat: Model? = nil
local activeSeat: BasePart? = nil
local bound = false
local saved: {
	CameraType: Enum.CameraType,
	CameraSubject: Instance?,
	CameraMode: Enum.CameraMode,
}? = nil

local function currentMode()
	return MODES[modeIndex]
end

local function restoreCustomCamera()
	if bound then
		bound = false
		RunService:UnbindFromRenderStep("BoatCamera")
	end
	local camera = workspace.CurrentCamera
	if camera and saved then
		-- Never strand the player on a scripted camera: the menu that owned it
		-- may already have closed while this view was active.
		if saved.CameraType == Enum.CameraType.Scriptable then
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			camera.CameraType = Enum.CameraType.Custom
			if humanoid then
				camera.CameraSubject = humanoid
			end
		else
			camera.CameraType = saved.CameraType
			if saved.CameraSubject then
				camera.CameraSubject = saved.CameraSubject
			end
		end
	end
end

-- Keep external shots level with the horizon while the hull rolls and pitches.
local function levelBasis(frame: CFrame): (Vector3, Vector3)
	local forward = Vector3.new(frame.LookVector.X, 0, frame.LookVector.Z)
	if forward.Magnitude < 1e-3 then
		return Vector3.new(0, 0, -1), Vector3.new(1, 0, 0)
	end
	forward = forward.Unit
	return forward, forward:Cross(Vector3.yAxis)
end

local function updateCamera()
	if player:GetAttribute("FreecamEnabled") then
		return
	end
	local camera = workspace.CurrentCamera
	local boat, seat = activeBoat, activeSeat
	if not camera or not boat or not boat.Parent or not seat or not seat.Parent then
		BoatCamera.stop()
		return
	end
	local root = boat.PrimaryPart
	if not root then
		BoatCamera.stop()
		return
	end

	local mode = currentMode().Name
	if mode == "Trailing" then
		return
	end

	local frame, focus
	if mode == "Cockpit" then
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		local seatFrame = seat.CFrame
		local eye = if head and head:IsA("BasePart")
			then head.Position
			else seatFrame.Position + seatFrame.UpVector * 2.4
		-- Sit just forward of the avatar's head so a hat or head mesh cannot
		-- fill the screen, then look along the helm toward the bow.
		eye += seatFrame.UpVector * 0.35 + seatFrame.LookVector * 1.2
		focus = eye + seatFrame.LookVector * 30 - seatFrame.UpVector * 3.5
		frame = CFrame.lookAt(eye, focus, seatFrame.UpVector)
	else
		local length = boat:GetAttribute("HullLength")
		length = if typeof(length) == "number" then length else 20
		local beam = boat:GetAttribute("HullBeam")
		beam = if typeof(beam) == "number" then beam else 8
		local origin = root.Position
		local forward, right = levelBasis(root.CFrame)
		local eye
		if mode == "Front" then
			local distance = 10 + length * 0.35
			local height = 4 + length * 0.12
			eye = origin - forward * (length * 0.5 + distance) + Vector3.yAxis * height
			focus = origin + Vector3.yAxis * (height * 0.35) + forward * (length * 0.05)
		else
			local distance = 8 + beam * 0.65
			local height = 3.5 + length * 0.09
			eye = origin + right * (beam * 0.5 + distance) + Vector3.yAxis * height - forward * (length * 0.04)
			focus = origin + Vector3.yAxis * (height * 0.35)
		end
		frame = CFrame.lookAt(eye, focus)
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = frame
	camera.Focus = CFrame.new(focus)
end

local function applyMode()
	if player:GetAttribute("FreecamEnabled") then
		return
	end
	local camera = workspace.CurrentCamera
	if not activeBoat or not activeSeat or not camera then
		return
	end
	if currentMode().Name == "Trailing" then
		restoreCustomCamera()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		player.CameraMode = Enum.CameraMode.Classic
		camera.CameraType = Enum.CameraType.Custom
		if humanoid then
			camera.CameraSubject = humanoid
		end
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	if not bound then
		bound = true
		RunService:BindToRenderStep("BoatCamera", Enum.RenderPriority.Camera.Value + 1, updateCamera)
	end
end

function BoatCamera.isActive(): boolean
	return activeBoat ~= nil
end

function BoatCamera.refresh()
	if activeBoat then
		applyMode()
	end
end

function BoatCamera.label(): string
	return currentMode().Label
end

function BoatCamera.cycle(): string
	modeIndex = modeIndex % #MODES + 1
	if activeBoat then
		applyMode()
	end
	return BoatCamera.label()
end

function BoatCamera.setActive(boat: Model?, seat: BasePart?)
	if boat and seat then
		if boat ~= activeBoat or seat ~= activeSeat then
			if not activeBoat then
				local camera = workspace.CurrentCamera
				if camera and not saved then
					saved = {
						CameraType = camera.CameraType,
						CameraSubject = camera.CameraSubject,
						CameraMode = player.CameraMode,
					}
				end
			end
			activeBoat, activeSeat = boat, seat
			applyMode()
		end
	else
		BoatCamera.stop()
	end
end

function BoatCamera.stop()
	activeBoat, activeSeat = nil, nil
	if player:GetAttribute("FreecamEnabled") then
		if bound then
			bound = false
			RunService:UnbindFromRenderStep("BoatCamera")
		end
		if saved then
			player.CameraMode = saved.CameraMode
			saved = nil
		end
		return
	end
	restoreCustomCamera()
	if saved then
		player.CameraMode = saved.CameraMode
		saved = nil
	end
end

return BoatCamera
