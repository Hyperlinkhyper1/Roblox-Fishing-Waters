-- Build mode: at home, press B (or the Build button) to look straight down into
-- your house with the roof hidden. Pick bought furniture from the bottom bar, turn it
-- with R and click a floor spot to place it; click placed furniture to move it or
-- pick it back up. Allowed rooms glow green while you hold an item. The preview
-- uses the shared placement rules, and the server re-checks every placement.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Furniture = require(ReplicatedStorage.Shared.FurnitureCatalog)
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))

local BuildMode = {}
local rgb = Color3.fromRGB
local FITS = rgb(84, 192, 92)
local BLOCKED = rgb(226, 72, 60)
local ROOM = rgb(96, 200, 120)
local HOME_DISTANCE = 80
-- Everything above the doorway lintels: roof, gables, ceiling ties and pendant lamps.
local ROOF_HEIGHT = 8.4
local FLOOR_Y = 0.16
local HEIGHTS = { Freezer = 4, Register = 3, StorageRack = 6.6 }
local started = false

local function make(class: string, parent: Instance?, props: { [string]: any }): any
	local item = Instance.new(class)
	for key, value in props do
		item[key] = value
	end
	item.Parent = parent
	return item
end

local function notice(message: string)
	pcall(StarterGui.SetCore, StarterGui, "SendNotification", {
		Title = "Build mode",
		Text = message,
		Duration = 4,
	})
end

function BuildMode.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Furniture")
	local request = remotes:WaitForChild("Request") :: RemoteFunction
	local update = remotes:WaitForChild("Update") :: RemoteEvent

	local state = nil
	local active = false
	local house: Model? = nil
	local houseFrame = CFrame.identity
	local hidden: { [BasePart]: number } = {}
	local held = nil -- { ItemId, From (item id or placed index), R }
	local selected: number? = nil
	local spot = nil -- { X, Z, Reason }
	local pending = false
	local saved = nil
	local preview: Model? = nil
	local highlight: Highlight? = nil

	-- HUD
	local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), {
		Name = "BuildMode",
		ResetOnSpawn = false,
		DisplayOrder = 24,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local toggle = make("TextButton", gui, {
		Name = "OpenBuildMode",
		Text = "Build [B]",
		TextSize = 16,
		Position = UDim2.new(1, -126, 1, -146),
		Size = UDim2.fromOffset(112, 38),
		Visible = false,
	})
	Theme.button(toggle)
	local panel = make("Frame", gui, {
		Name = "BuildPanel",
		Active = true,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -24, 0, 190),
		Visible = false,
	})
	Theme.window(panel)
	local function label(parent: Instance, text: string, props: { [string]: any }): TextLabel
		local item = make("TextLabel", parent, {
			BackgroundTransparency = 1,
			Text = text,
			TextSize = 14,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		Theme.text(item, props.TextColor3)
		for key, value in props do
			item[key] = value
		end
		return item
	end
	local function button(parent: Instance, text: string, props: { [string]: any }): TextButton
		local item = make("TextButton", parent, { Text = text, TextSize = 14 })
		for key, value in props do
			item[key] = value
		end
		Theme.button(item)
		return item
	end
	label(panel, "Build mode", { Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 26), TextSize = 20 })
	local hint = label(panel, "", {
		Position = UDim2.fromOffset(16, 38),
		Size = UDim2.new(1, -32, 0, 32),
		TextSize = 12,
		Font = Enum.Font.Gotham,
		TextColor3 = Theme.Colors.Muted,
	})
	local function horizontalStrip(name: string, y: number, height: number): ScrollingFrame
		local strip = make("ScrollingFrame", panel, {
			Name = name,
			Position = UDim2.fromOffset(16, y),
			Size = UDim2.new(1, -32, 0, height),
			BackgroundTransparency = 1,
			CanvasSize = UDim2.fromOffset(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			ScrollingDirection = Enum.ScrollingDirection.X,
			Active = true,
		})
		Theme.scroll(strip)
		strip.ScrollBarThickness = 4
		make("UIListLayout", strip, {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		})
		return strip
	end
	local catalogue = horizontalStrip("Placeables", 76, 60)
	local actions = horizontalStrip("BuildActions", 144, 36)
	local itemButtons = {}
	for index, id in Furniture.Order do
		itemButtons[id] = button(catalogue, "", {
			Name = "Hold" .. id,
			LayoutOrder = index,
			Size = UDim2.fromOffset(196, 52),
			TextWrapped = true,
		})
	end
	local rotate = button(actions, "Rotate [R]", {
		Name = "Rotate",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(110, 30),
	})
	local cancel = button(actions, "Cancel [Q]", {
		Name = "Cancel",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(110, 30),
	})
	local move = button(actions, "Move", {
		Name = "MoveSelected",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(90, 30),
	})
	local pickUp = button(actions, "Pick up", {
		Name = "PickUpSelected",
		LayoutOrder = 4,
		Size = UDim2.fromOffset(90, 30),
	})
	local done = button(actions, "Done [B]", {
		Name = "ExitBuildMode",
		LayoutOrder = 5,
		Size = UDim2.fromOffset(100, 30),
	})

	local function ownHouse(): (Model?, CFrame?)
		for _, base in CollectionService:GetTagged("PlayerBase") do
			if base:GetAttribute("OwnerUserId") == player.UserId then
				local model = base:FindFirstChild("BaseHouse")
				local frame = model and model:GetAttribute("HouseFrame")
				if model and model:IsA("Model") and typeof(frame) == "CFrame" then
					return model, frame
				end
			end
		end
		return nil, nil
	end
	local function atHome(): boolean
		local _, frame = ownHouse()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		return frame ~= nil and root ~= nil and (root.Position - frame.Position).Magnitude <= HOME_DISTANCE
	end

	local function setButton(item: TextButton, text: string, enabled: boolean, chosen: boolean?)
		item.Text = text
		item.Active = enabled
		Theme.button(item, if chosen then "Selected" elseif enabled then "Normal" else "Disabled")
	end
	local function render()
		for _, id in Furniture.Order do
			local item = Furniture.Items[id]
			local stock = if state then state.Stock[id] or 0 else 0
			local full = state ~= nil and Furniture.count(state.Placed, id) >= item.MaxPlaced
			setButton(
				itemButtons[id],
				string.format("%s\n%d available", item.Name, stock),
				stock > 0 and not full and not pending,
				held ~= nil and held.From == id
			)
		end
		setButton(rotate, "Rotate [R]", held ~= nil)
		setButton(cancel, "Cancel [Q]", held ~= nil or selected ~= nil)
		setButton(move, "Move", selected ~= nil and held == nil and not pending)
		setButton(pickUp, "Pick up", selected ~= nil and held == nil and not pending)
		if held then
			local item = Furniture.Items[held.ItemId]
			hint.Text = if spot and spot.Reason
				then spot.Reason
				else string.format("Click the %s to place your %s.", Furniture.RoomNames[item.Room], string.lower(item.Name))
		elseif selected and state and state.Placed[selected] then
			hint.Text = Furniture.Items[state.Placed[selected].ItemId].Name .. " selected. Move it or pick it up."
		else
			hint.Text = "Choose furniture to place, or click placed furniture. Buy more at Harbour Home on the plaza."
		end
	end

	local function clearPreview()
		if preview then
			preview:Destroy()
			preview = nil
		end
	end
	local function setHighlight(model: Instance?)
		if highlight then
			highlight:Destroy()
			highlight = nil
		end
		if model then
			highlight = make("Highlight", model, {
				FillColor = rgb(240, 200, 90),
				FillTransparency = 0.6,
				OutlineColor = rgb(255, 230, 150),
			})
		end
	end
	local function placedModel(index: number): Model?
		local entry = state and state.Placed[index]
		local folder = house and house:FindFirstChild("Furniture")
		if not entry or not folder then
			return nil
		end
		for _, model in folder:GetChildren() do
			if
				model:GetAttribute("ItemId") == entry.ItemId
				and model:GetAttribute("X") == entry.X
				and model:GetAttribute("Z") == entry.Z
				and model:GetAttribute("R") == entry.R
			then
				return model
			end
		end
		return nil
	end
	local function choose(index: number?)
		selected = index
		setHighlight(if index then placedModel(index) else nil)
		render()
	end

	-- Local-only parts: the held item's ghost and the rooms it may go in.
	local function plate(parent: Instance, area: { number }, y: number, color: Color3, transparency: number): Part
		return make("Part", parent, {
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Material = Enum.Material.SmoothPlastic,
			Color = color,
			Transparency = transparency,
			Size = Vector3.new(area[3] - area[1], 0.08, area[4] - area[2]),
			CFrame = houseFrame * CFrame.new((area[1] + area[3]) / 2, y, (area[2] + area[4]) / 2),
		})
	end
	local function buildPreview()
		clearPreview()
		if not held then
			return
		end
		local model = make("Model", nil, { Name = "FurniturePreview" })
		local item = Furniture.Items[held.ItemId]
		plate(model, Furniture.Rooms[item.Room], FLOOR_Y + 0.05, ROOM, 0.75).Name = "AllowedRoom"
		for _, area in Furniture.Blocked do
			local room = Furniture.Rooms[item.Room]
			-- Only show the keep-clear zones inside the room being furnished.
			if area[1] < room[3] and area[3] > room[1] and area[2] < room[4] and area[4] > room[2] then
				plate(model, area, FLOOR_Y + 0.07, BLOCKED, 0.8).Name = "KeepClear"
			end
		end
		local height = HEIGHTS[held.ItemId] or 3
		make("Part", model, {
			Name = "Body",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.35,
			Size = Vector3.new(item.Width, height, item.Depth),
		})
		make("Part", model, {
			Name = "Access",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.7,
			Size = Vector3.new(item.Width, 0.1, item.Depth + item.Front + item.Back),
		})
		-- An arrow on the access side shows which way the item faces.
		make("Part", model, {
			Name = "FacingArrow",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Material = Enum.Material.Neon,
			Color = rgb(250, 240, 200),
			Size = Vector3.new(0.5, 0.12, math.max(item.Front, 1) * 0.8),
		})
		model.Parent = workspace
		preview = model
	end
	local function updatePreview()
		if not preview or not held or not spot then
			return
		end
		local item = Furniture.Items[held.ItemId]
		local frame = Furniture.frame(houseFrame, { X = spot.X, Z = spot.Z, R = held.R })
		local color = if spot.Reason then BLOCKED else FITS
		local height = HEIGHTS[held.ItemId] or 3
		local body = preview:FindFirstChild("Body") :: BasePart
		local access = preview:FindFirstChild("Access") :: BasePart
		local arrow = preview:FindFirstChild("FacingArrow") :: BasePart
		body.Color, access.Color = color, color
		body.CFrame = frame * CFrame.new(0, height / 2, 0)
		access.CFrame = frame * CFrame.new(0, 0.12, (item.Front - item.Back) / 2)
		arrow.CFrame = frame * CFrame.new(0, height + 0.2, item.Depth / 2)
	end

	-- The floor spot under the pointer, snapped to the placement grid.
	local function pointerSpot(position: Vector2)
		local camera = workspace.CurrentCamera
		if not camera then
			return nil
		end
		local ray = camera:ScreenPointToRay(position.X, position.Y)
		local floor = houseFrame * CFrame.new(0, FLOOR_Y, 0)
		local normal = houseFrame.UpVector
		local denominator = ray.Direction:Dot(normal)
		if math.abs(denominator) < 1e-4 then
			return nil
		end
		local t = (floor.Position - ray.Origin):Dot(normal) / denominator
		if t < 0 then
			return nil
		end
		local point = houseFrame:PointToObjectSpace(ray.Origin + ray.Direction * t)
		return math.round(point.X / Furniture.GRID) * Furniture.GRID, math.round(point.Z / Furniture.GRID) * Furniture.GRID
	end
	local function aim(position: Vector2)
		if not held or not state then
			return
		end
		local x, z = pointerSpot(position)
		if not x then
			return
		end
		local skip = if type(held.From) == "number" then held.From else nil
		spot = { X = x, Z = z, Reason = Furniture.check(state.Placed, held.ItemId, x, z, held.R, skip) }
		updatePreview()
		render()
	end

	local function hold(itemId: string, from: any, r: number)
		held = { ItemId = itemId, From = from, R = r }
		spot = nil
		buildPreview()
		aim(UserInputService:GetMouseLocation())
		render()
	end
	local function drop()
		held, spot = nil, nil
		clearPreview()
		render()
	end

	local function send(action: string, ...): boolean
		pending = true
		render()
		local ok, result = pcall(request.InvokeServer, request, action, ...)
		pending = false
		if ok and type(result) == "table" then
			state = result.State or state
			if not result.Ok and result.Message ~= "" then
				notice(result.Message)
			end
			render()
			return result.Ok == true
		end
		notice("Your furniture couldn't be saved. Try again.")
		render()
		return false
	end

	local function placeHeld()
		if not held or not spot or pending then
			return
		end
		if spot.Reason then
			notice(spot.Reason)
			return
		end
		local action = if type(held.From) == "number" then "Move" else "Place"
		if send(action, held.From, spot.X, spot.Z, held.R) then
			drop()
			choose(nil)
		end
	end

	local function clickFurniture(position: Vector2)
		local camera = workspace.CurrentCamera
		local folder = house and house:FindFirstChild("Furniture")
		if not camera or not folder or not state then
			return
		end
		local ray = camera:ScreenPointToRay(position.X, position.Y)
		local parameters = RaycastParams.new()
		parameters.FilterType = Enum.RaycastFilterType.Include
		parameters.FilterDescendantsInstances = { folder }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 200, parameters)
		local model = hit and hit.Instance
		while model and model.Parent ~= folder do
			model = model.Parent
		end
		if not model then
			choose(nil)
			return
		end
		for index, entry in state.Placed do
			if
				model:GetAttribute("ItemId") == entry.ItemId
				and model:GetAttribute("X") == entry.X
				and model:GetAttribute("Z") == entry.Z
				and model:GetAttribute("R") == entry.R
			then
				choose(index)
				return
			end
		end
	end

	local function hideRoof()
		hidden = {}
		if not house then
			return
		end
		local folder = house:FindFirstChild("Furniture")
		for _, part in house:GetDescendants() do
			if part:IsA("BasePart") and not (folder and part:IsDescendantOf(folder)) then
				if houseFrame:PointToObjectSpace(part.Position).Y > ROOF_HEIGHT and part.Transparency < 1 then
					hidden[part] = part.Transparency
					part.Transparency = 1
				end
			end
		end
	end
	local function showRoof()
		for part, transparency in hidden do
			if part.Parent then
				part.Transparency = transparency
			end
		end
		hidden = {}
	end

	local function controls(enabled: boolean)
		pcall(function()
			local module = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript)
			local playerControls = module:GetControls()
			if enabled then
				playerControls:Enable()
			else
				playerControls:Disable()
			end
		end)
	end

	local function updateCamera()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 50
		camera.FieldOfViewMode = Enum.FieldOfViewMode.Vertical
		local viewport = camera.ViewportSize
		if viewport.X <= 0 or viewport.Y <= 0 then
			return
		end
		local inset = game:GetService("GuiService"):GetGuiInset()
		local top = inset.Y + 12
		local bottom = panel.AbsolutePosition.Y + inset.Y - 12
		local available = math.max(1, bottom - top)
		local aspect = viewport.X / viewport.Y
		local half = math.tan(math.rad(camera.FieldOfView / 2))
		-- Fit the 46 x 30 house with a margin inside the area ABOVE the bar.
		local height = math.max(18 * viewport.Y / (half * available), 26 / (half * aspect))
		local center = (houseFrame * CFrame.new(0, FLOOR_Y, 0)).Position
		local shift = ((top + bottom) / 2 - viewport.Y / 2) * (2 * height * half / viewport.Y)
		local target = center + houseFrame.LookVector * shift
		camera.CFrame = CFrame.lookAt(target + houseFrame.UpVector * height, target, houseFrame.LookVector)
		camera.Focus = CFrame.new(center)
	end

	local exit
	local function enter()
		if active or not atHome() then
			if not active then
				notice("Go home to your base to use build mode.")
			end
			return
		end
		local model, frame = ownHouse()
		local camera = workspace.CurrentCamera
		if not camera or not model or not frame then
			return
		end
		active, house, houseFrame = true, model, frame
		saved = {
			Type = camera.CameraType,
			FieldOfView = camera.FieldOfView,
			FieldOfViewMode = camera.FieldOfViewMode,
			Frame = camera.CFrame,
			Focus = camera.Focus,
		}
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 50
		controls(false)
		hideRoof()
		panel.Visible, toggle.Visible = true, false
		player:SetAttribute("BuildModeOpen", true)
		updateCamera()
		RunService:BindToRenderStep("FurnitureBuildCamera", Enum.RenderPriority.Camera.Value + 1, updateCamera)
		render()
		task.spawn(function()
			local ok, result = pcall(request.InvokeServer, request, "Get")
			if ok and type(result) == "table" and result.State then
				state = result.State
				render()
			end
		end)
	end
	function exit()
		if not active then
			return
		end
		active = false
		drop()
		choose(nil)
		RunService:UnbindFromRenderStep("FurnitureBuildCamera")
		showRoof()
		local camera = workspace.CurrentCamera
		if saved and camera then
			camera.CameraType = saved.Type
			camera.FieldOfViewMode = saved.FieldOfViewMode
			camera.FieldOfView = saved.FieldOfView
			camera.CFrame = saved.Frame
			camera.Focus = saved.Focus
		end
		controls(true)
		panel.Visible = false
		player:SetAttribute("BuildModeOpen", false)
	end

	for id, item in itemButtons do
		item.Activated:Connect(function()
			if active and item.Active then
				choose(nil)
				hold(id, id, if held then held.R else 0)
			end
		end)
	end
	rotate.Activated:Connect(function()
		if held then
			held.R = (held.R + 1) % 4
			aim(UserInputService:GetMouseLocation())
		end
	end)
	cancel.Activated:Connect(function()
		drop()
		choose(nil)
	end)
	move.Activated:Connect(function()
		local entry = selected and state and state.Placed[selected]
		if entry and not pending then
			hold(entry.ItemId, selected, entry.R)
		end
	end)
	pickUp.Activated:Connect(function()
		if selected and not pending and send("PickUp", selected) then
			choose(nil)
		end
	end)
	done.Activated:Connect(exit)
	toggle.Activated:Connect(enter)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.B then
			if active then
				exit()
			else
				enter()
			end
		elseif not active then
			return
		elseif input.KeyCode == Enum.KeyCode.R and held then
			held.R = (held.R + 1) % 4
			aim(UserInputService:GetMouseLocation())
		elseif input.KeyCode == Enum.KeyCode.Q or input.UserInputType == Enum.UserInputType.MouseButton2 then
			drop()
			choose(nil)
		elseif
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			local position = Vector2.new(input.Position.X, input.Position.Y)
			if held then
				aim(position)
				placeHeld()
			else
				clickFurniture(position)
			end
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if active and held and input.UserInputType == Enum.UserInputType.MouseMovement then
			aim(UserInputService:GetMouseLocation())
		end
	end)
	update.OnClientEvent:Connect(function(kind, payload)
		if kind == "State" and type(payload) == "table" then
			state = payload
			if selected then
				choose(if state.Placed[selected] then selected else nil)
			end
			render()
		end
	end)
	-- Respawning or leaving home ends build mode; the toggle shows only at home.
	player.CharacterAdded:Connect(exit)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local home = atHome()
			toggle.Visible = home and not active
			if active then
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if not home or not humanoid or humanoid.Health <= 0 then
					exit()
				else
					-- Furniture rebuilt by the server since the last check keeps its highlight.
					if selected and highlight and not highlight.Parent then
						setHighlight(placedModel(selected))
					end
				end
			end
		end
	end)
end

return BuildMode
