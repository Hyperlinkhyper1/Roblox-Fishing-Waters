-- Owner saves use three slots. Joining a friend's company never consumes one.
-- This screen mounts before character/gear readiness so first arrival can choose a save.
-- Behind it the camera slowly circles the main island under a blur, so the
-- selector reads as a title screen instead of a grey box.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))
local Branches = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Branches"))

local Service = {}
local started = false

-- The harbour bay sits at the Gullhaven Sound biome centre (world origin).
-- High enough to clear the inland hills on every side of the orbit.
local PANORAMA_FOCUS = Vector3.new(0, 10, 0)
local PANORAMA_RADIUS = 640
local PANORAMA_HEIGHT = 300
local PANORAMA_SPEED = 0.018 -- radians per second; one lap is about six minutes
local PANORAMA_BLUR = 14
-- Roblox's own top bar is 58 px tall; used until GuiService reports its inset.
local DEFAULT_TOPBAR = 58

local SLOT_HEIGHT, SLOT_GAP = 128, 10
local COMPANY_HEIGHT, COMPANY_GAP = 132, 10
local LIST_TOP = 4 -- keeps the first card's border and focus ring inside the list

local function text(parent, name, value, position, size, fontSize, muted)
	local label = Instance.new("TextLabel")
	label.Name, label.Text = name, value
	label.BackgroundTransparency = 1
	label.Position, label.Size = position, size
	label.TextSize = fontSize or 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	Theme.text(label, if muted then Theme.Colors.Muted else nil)
	label.Parent = parent
	return label
end

local function style(item, state)
	Theme.glassButton(item, state)
end

local function button(parent, name, value, position, size, callback, state)
	local item = Instance.new("TextButton")
	item.Name, item.Text = name, value
	item.Position, item.Size = position, size
	item.TextSize, item.Selectable = 15, true
	item:SetAttribute("SaveButtonStyle", state or "Normal")
	style(item, state)
	item.Parent = parent
	item.Activated:Connect(callback)
	return item
end

local function scroll(parent, name, position, size)
	local frame = Instance.new("ScrollingFrame")
	frame.Name, frame.Position, frame.Size = name, position, size
	frame.BackgroundTransparency = 1
	frame.CanvasSize = UDim2.fromOffset(0, 0)
	frame.ScrollingDirection = Enum.ScrollingDirection.Y
	Theme.scroll(frame)
	frame.ScrollBarThickness = 6
	frame.ScrollBarImageColor3 = Theme.Colors.Border
	frame.Parent = parent
	return frame
end

local function money(value)
	local amount = tostring(math.floor(tonumber(value) or 0))
	local formatted = string.reverse(amount):gsub("(%d%d%d)", "%1,")
	return "$" .. string.reverse(formatted):gsub("^,", "")
end

-- Mirrors SaveData.cleanIcon closely enough for a live preview; the server
-- validates and normalises what is actually saved.
local function iconId(value)
	if type(value) == "number" then return if value > 0 and value % 1 == 0 then value else nil end
	if type(value) ~= "string" then return nil end
	local trimmed = string.match(value, "^%s*(.-)%s*$")
	local digits = string.match(trimmed, "^(%d+)$")
		or string.match(trimmed, "rbxassetid://(%d+)")
		or string.match(trimmed, "[?&]id=(%d+)")
		or string.match(trimmed, "/(%d+)/?[^/]*$")
		or string.match(trimmed, "/(%d+)/")
	local id = digits and #digits <= 16 and tonumber(digits)
	return if id and id > 0 then id else nil
end

-- Asset thumbnails render both decals and images from the same ID.
local function iconImage(id)
	return if id then "rbxthumb://type=Asset&id=" .. tostring(id) .. "&w=150&h=150" else ""
end

-- A square company badge: the chosen icon, or the company's first letter.
local function badge(parent, name, position, size, id, fallback)
	local tile = Instance.new("ImageLabel")
	tile.Name = name
	tile.Position, tile.Size = position, UDim2.fromOffset(size, size)
	tile.BackgroundColor3 = Color3.fromRGB(20, 34, 48)
	tile.BackgroundTransparency = 0
	tile.BorderSizePixel = 0
	tile.ScaleType = Enum.ScaleType.Crop
	tile.Image = iconImage(id)
	Theme.corner(tile, 8)
	local stroke = Instance.new("UIStroke")
	stroke.Name, stroke.Color, stroke.Transparency, stroke.Thickness = "ThemeBorder", Theme.Colors.Border, 0.45, 1
	stroke.Parent = tile
	local letter = text(tile, "Initial", fallback or "", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), math.floor(size * 0.46), true)
	letter.TextXAlignment = Enum.TextXAlignment.Center
	letter.Visible = id == nil
	tile.Parent = parent
	return tile
end

local function initial(name)
	local first = type(name) == "string" and string.match(name, "[%w]") or nil
	return if first then string.upper(first) else "?"
end

function Service.start()
	if started then return end
	started = true
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "SaveSelection"
	gui.ResetOnSpawn, gui.IgnoreGuiInset = false, true
	gui.DisplayOrder = 1001
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- Opaque until the island has streamed in behind it, then a dark tint over
	-- the blurred panorama.
	local backdrop = Instance.new("Frame")
	backdrop.Name, backdrop.Size = "Backdrop", UDim2.fromScale(1, 1)
	backdrop.BorderSizePixel, backdrop.Active = 0, true
	backdrop.BackgroundColor3 = Color3.fromRGB(9, 15, 22)
	backdrop.BackgroundTransparency = 0
	backdrop.Parent = gui
	local shade = Instance.new("Frame")
	shade.Name, shade.Size = "Shade", UDim2.fromScale(1, 1)
	shade.BorderSizePixel, shade.BackgroundColor3 = 0, Color3.fromRGB(0, 0, 0)
	shade.BackgroundTransparency = 0
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.45, 0.85),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	fade.Parent = shade
	shade.Parent = backdrop

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.new(1, -32, 1, -32)
	Theme.glassWindow(window)
	window.BackgroundTransparency = 0.16
	window.Parent = backdrop
	local bounds = Instance.new("UISizeConstraint")
	bounds.MaxSize = Vector2.new(1060, 720)
	bounds.Parent = window
	local title = text(window, "Title", "Choose your save", UDim2.fromOffset(24, 18), UDim2.new(1, -180, 0, 34), 27)
	local subtitle = text(window, "Subtitle", "Your company, your crew, one shared wallet.", UDim2.fromOffset(24, 55), UDim2.new(1, -180, 0, 22), 14, true)
	local body = Instance.new("Frame")
	body.Name, body.BackgroundTransparency = "Body", 1
	body.Position, body.Size = UDim2.fromOffset(24, 100), UDim2.new(1, -48, 1, -164)
	body.Parent = window
	local own = Instance.new("Frame")
	own.Name = "OwnSaves"
	Theme.glassPanel(own, true)
	own.Parent = body
	text(own, "Heading", "YOUR SAVES · 3 SLOTS", UDim2.fromOffset(14, 10), UDim2.new(1, -28, 0, 24), 15)
	local slotsScroll = scroll(own, "Slots", UDim2.fromOffset(10, 40), UDim2.new(1, -16, 1, -48))
	local side = Instance.new("Frame")
	side.Name = "Companies"
	Theme.glassPanel(side, true)
	side.Parent = body
	text(side, "Heading", "FRIENDS' COMPANIES", UDim2.fromOffset(14, 10), UDim2.new(1, -28, 0, 24), 15)
	local sideHelp = text(side, "Help", "Join here without using a save slot.", UDim2.fromOffset(14, 35), UDim2.new(1, -28, 0, 36), 13, true)
	sideHelp.TextWrapped, sideHelp.TextTruncate = true, Enum.TextTruncate.None
	local companiesScroll = scroll(side, "CompanyList", UDim2.fromOffset(10, 76), UDim2.new(1, -16, 1, -84))
	local status = text(window, "Status", "Loading your saves…", UDim2.new(0, 24, 1, -54), UDim2.new(1, -48, 0, 40), 14, true)
	status.TextWrapped, status.TextTruncate = true, Enum.TextTruncate.None

	local busy, entering, loaded = false, false, false
	local remote, modal
	local data = { Slots = {}, Companies = {} }
	local refresh, render, openSettings
	local firstButton

	-- Panorama -------------------------------------------------------------
	local panorama = {}
	local function stopPanorama()
		if panorama.connection then panorama.connection:Disconnect() end
		if panorama.blur then panorama.blur:Destroy() end
		local camera = panorama.camera
		if camera and camera.CameraType == Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Custom
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then camera.CameraSubject = humanoid end
		end
		panorama = {}
	end
	local function startPanorama()
		local camera = workspace.CurrentCamera
		if panorama.connection or not camera then return end
		panorama.camera = camera
		local blur = Instance.new("BlurEffect")
		blur.Name, blur.Size = "SaveSelectionBlur", PANORAMA_BLUR
		blur.Parent = camera
		panorama.blur = blur
		camera.CameraType = Enum.CameraType.Scriptable
		local angle = panorama.angle or 0.9
		panorama.connection = RunService.RenderStepped:Connect(function(dt)
			angle += dt * PANORAMA_SPEED
			panorama.angle = angle
			local eye = PANORAMA_FOCUS + Vector3.new(math.cos(angle) * PANORAMA_RADIUS, PANORAMA_HEIGHT, math.sin(angle) * PANORAMA_RADIUS)
			camera.CFrame = CFrame.lookAt(eye, PANORAMA_FOCUS)
		end)
		if panorama.streamed or panorama.streaming then return end
		panorama.streaming = true
		-- Without a character nothing streams in; ask for the island explicitly.
		task.spawn(function()
			pcall(player.RequestStreamAroundAsync, player, PANORAMA_FOCUS, 8)
			panorama.streaming, panorama.streamed = false, true
			if gui.Enabled then
				backdrop.BackgroundTransparency = 0.62
				shade.BackgroundTransparency = 0
			end
		end)
	end

	-- Visibility and layout -----------------------------------------------
	local function selectionRequired()
		return player:GetAttribute("SaveSelectionRequired") ~= false
			and player:GetAttribute("BoatDataStatus") ~= "Ready"
	end

	-- A picked save hands the screen to the loading screen at once, instead of
	-- after the server confirms (which waits for the harbour on a fresh server).
	-- A failed pick clears this and brings the selector back.
	local function setOpening(value)
		player:SetAttribute("SaveSelectionOpening", if value then true else nil)
	end

	local function visibility()
		gui.Enabled = selectionRequired() and player:GetAttribute("SaveSelectionOpening") ~= true
		if not gui.Enabled then
			stopPanorama()
			if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
				GuiService.SelectedObject = nil
			end
		else
			startPanorama()
			if UserInputService.GamepadEnabled and not GuiService.SelectedObject and firstButton then
				GuiService.SelectedObject = firstButton
			end
		end
	end

	local function setBusy(value)
		busy = value
		for _, item in gui:GetDescendants() do
			if item:IsA("TextButton") then
				local enabled = not value and item:GetAttribute("SaveButtonStyle") ~= "Disabled"
				item.Active, item.Selectable = enabled, enabled
				style(item, if value then "Disabled" else item:GetAttribute("SaveButtonStyle"))
			end
		end
	end

	local function showError(message)
		status.Text = message
		local errorLabel = modal and modal:FindFirstChild("Error", true)
		if errorLabel then errorLabel.Text = message end
	end

	local function request(action, payload)
		if busy or entering then return nil end
		if not remote then
			showError("Connecting to saved data. Please try again shortly.")
			return nil
		end
		setBusy(true)
		local ok, response = pcall(remote.InvokeServer, remote, action, payload)
		setBusy(false)
		if not ok or type(response) ~= "table" or response.Ok ~= true then
			showError(if ok and type(response) == "table" and type(response.Message) == "string"
				then response.Message else "Could not reach your saves. Press Refresh to retry.")
			return nil
		end
		return response
	end

	local function closeModal()
		if modal then modal:Destroy(); modal = nil end
		if UserInputService.GamepadEnabled then GuiService.SelectedObject = firstButton end
	end

	local function selectSave(entry)
		if busy or entering then return end
		local opening = "Opening " .. tostring(entry.Name or "your save") .. "…"
		status.Text = opening
		-- Saves list while the harbour is still building; entering waits for it.
		local waiting = true
		task.delay(1.5, function()
			while waiting and gui.Enabled do
				if ReplicatedStorage:GetAttribute("FishingWatersWorldReady") ~= true then
					local stage = ReplicatedStorage:GetAttribute("FishingWatersLoadStage")
					status.Text = opening .. " " .. (if type(stage) == "string" then stage else "Preparing the harbour") .. "…"
				end
				task.wait(0.5)
			end
		end)
		if remote then setOpening(true) end
		local response = request("Select", { OwnerUserId = entry.OwnerUserId or player.UserId, Slot = entry.Slot })
		waiting = false
		if response then
			entering = response.Entering == true
			if entering then
				setBusy(true)
				status.Text = "Opening your save. Your crew can play here together."
			end
		end
		if not entering then setOpening(false) end
	end

	local function card(parent, name, y, height)
		local frame = Instance.new("Frame")
		frame.Name, frame.Position, frame.Size = name, UDim2.fromOffset(2, y), UDim2.new(1, -12, 0, height)
		Theme.panel(frame, false, 8)
		frame.BackgroundColor3 = Color3.fromRGB(38, 44, 52)
		frame.BackgroundTransparency = 0.15
		frame.Parent = parent
		return frame
	end

	render = function()
		if modal then return end
		local focused = GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui)
		slotsScroll:ClearAllChildren()
		companiesScroll:ClearAllChildren()
		firstButton = nil
		local slotsById = {}
		for _, entry in data.Slots or {} do slotsById[entry.Slot] = entry end
		for slot = 1, 3 do
			local y = LIST_TOP + (slot - 1) * (SLOT_HEIGHT + SLOT_GAP)
			local frame = card(slotsScroll, "Slot" .. slot, y, SLOT_HEIGHT)
			if not loaded then
				-- Placeholder while the first list is in flight.
				badge(frame, "Icon", UDim2.fromOffset(12, 12), 64, nil, "")
				text(frame, "SlotNumber", "SAVE " .. slot, UDim2.fromOffset(88, 12), UDim2.new(1, -100, 0, 18), 12, true)
				text(frame, "SaveName", "Loading…", UDim2.fromOffset(88, 31), UDim2.new(1, -100, 0, 25), 19, true)
				continue
			end
			local entry = slotsById[slot] or { Slot = slot, OwnerUserId = player.UserId, Exists = false }
			local exists = entry.Exists == true or (entry.Exists ~= false and entry.Name ~= nil)
			badge(frame, "Icon", UDim2.fromOffset(12, 12), 64, exists and iconId(entry.Icon) or nil, if exists then initial(entry.Name) else "+")
			local tag = if not exists then "SAVE " .. slot .. " · EMPTY"
				elseif entry.Multiplayer then "SAVE " .. slot .. " · COMPANY"
				else "SAVE " .. slot .. " · SOLO"
			text(frame, "SlotNumber", tag, UDim2.fromOffset(88, 11), UDim2.new(1, -100, 0, 18), 12, true)
			text(frame, "SaveName", if exists then entry.Name or "Untitled save" else "Start a new adventure", UDim2.fromOffset(88, 29), UDim2.new(1, -100, 0, 25), 20)
			local kind = if exists then Branches.label(entry.Branches) else nil
			local summary = if not exists then "Fishing company or café · solo or with up to four friends."
				elseif entry.Multiplayer then string.format("%s · %d/5 members · %s net worth", kind, entry.MemberCount or 1, money(entry.NetWorth))
				else string.format("%s · solo · %s net worth", kind, money(entry.NetWorth))
			text(frame, "Details", summary, UDim2.fromOffset(88, 55), UDim2.new(1, -100, 0, 20), 13, true)
			local primary = button(frame, if exists then "Play" else "Create", if exists then "Play" else "Create save", UDim2.new(0, 12, 1, -44), UDim2.new(if exists then 0.62 else 1, if exists then -18 else -24, 0, 34), function()
				if busy or entering then return end
				if exists then selectSave(entry) else openSettings(entry, true) end
			end, "Selected")
			firstButton = firstButton or primary
			if exists then
				button(frame, "Settings", "Settings", UDim2.new(0.62, 0, 1, -44), UDim2.new(0.38, -12, 0, 34), function()
					if not busy and not entering then openSettings(entry, false) end
				end)
			end
		end
		slotsScroll.CanvasSize = UDim2.fromOffset(0, LIST_TOP + 3 * (SLOT_HEIGHT + SLOT_GAP))
		local companies = data.Companies or {}
		for index, entry in companies do
			local y = LIST_TOP + (index - 1) * (COMPANY_HEIGHT + COMPANY_GAP)
			local frame = card(companiesScroll, "Company" .. index, y, COMPANY_HEIGHT)
			badge(frame, "Icon", UDim2.fromOffset(12, 12), 56, iconId(entry.Icon), initial(entry.Name))
			text(frame, "Name", entry.Name or "Friend's company", UDim2.fromOffset(80, 10), UDim2.new(1, -92, 0, 24), 18)
			local ownerName = entry.OwnerName or ("User " .. tostring(entry.OwnerUserId))
			text(frame, "Owner", "Created by " .. ownerName, UDim2.fromOffset(80, 35), UDim2.new(1, -92, 0, 18), 12, true)
			text(frame, "Details", string.format("%s · %d/5 members · %s net worth", Branches.label(entry.Branches), entry.MemberCount or 1, money(entry.NetWorth)), UDim2.fromOffset(80, 54), UDim2.new(1, -92, 0, 18), 12, true)
			local member = entry.IsMember == true
			for _, person in entry.Members or {} do
				if person.UserId == player.UserId then member = true end
			end
			local full = (entry.MemberCount or 1) >= 5 and not member
			local join = button(frame, "Join", if full then "Company full" elseif member then "Continue company" else "Join company", UDim2.new(0, 12, 1, -46), UDim2.new(1, -24, 0, 34), function()
				if not full then selectSave(entry) end
			end, if full then "Disabled" else "Selected")
			join.Active, join.Selectable = not full, not full
		end
		if #companies == 0 then
			local empty = text(companiesScroll, "Empty", if not loaded or data.FriendsLoading then "Finding your friends' companies…" else "No companies to join yet. A friend can enable Multiplayer in their save settings; their company will appear here, even while they are offline.", UDim2.fromOffset(6, 8), UDim2.new(1, -22, 0, 128), 14, true)
			empty.TextWrapped, empty.TextTruncate, empty.TextYAlignment = true, Enum.TextTruncate.None, Enum.TextYAlignment.Top
		end
		companiesScroll.CanvasSize = UDim2.fromOffset(0, LIST_TOP + math.max(144, #companies * (COMPANY_HEIGHT + COMPANY_GAP)))
		if busy or entering then setBusy(true) end
		if focused or UserInputService.GamepadEnabled then GuiService.SelectedObject = firstButton end
	end

	refresh = function()
		if not gui.Enabled or modal or busy or entering then return end
		local response = request("List")
		if not response then return end
		data, loaded = response, true
		render()
		status.Text = if response.SessionOnly then "Studio session: saves last for this server session."
			elseif response.FriendsLoading then "Your saves are ready. Finding friends' companies…"
			else "Only the creator uses a slot. Companies share progress and money, with five members maximum."
	end

	local function acceptChange(response, message)
		closeModal()
		-- Create/settings already include fresh lists. A second request would hit
		-- the server's admission limit and leave the just-edited card stale.
		if type(response.Slots) == "table" then
			data, loaded = response, true
			render()
		else
			task.delay(0.6, refresh)
		end
		status.Text = message
	end

	openSettings = function(entry, creating)
		closeModal()
		modal = Instance.new("Frame")
		modal.Name, modal.Size, modal.BackgroundTransparency = "SaveSettings", UDim2.fromScale(1, 1), 0.35
		modal.BackgroundColor3, modal.Active = Theme.Colors.Black, true
		modal.ZIndex, modal.Parent = 10, backdrop
		local panel = Instance.new("Frame")
		panel.Name, panel.AnchorPoint = "Panel", Vector2.new(0.5, 0.5)
		panel.Position, panel.Size = window.Position, UDim2.new(1, -32, 1, -48 - (window:GetAttribute("TopInset") or 0))
		panel.ZIndex = 11
		Theme.window(panel)
		panel.Parent = modal
		local limit = Instance.new("UISizeConstraint")
		limit.MaxSize, limit.Parent = Vector2.new(560, 660), panel
		local heading = text(panel, "Heading", if creating then "Create save " .. entry.Slot else "Save settings", UDim2.fromOffset(22, 16), UDim2.new(1, -44, 0, 32), 23)
		heading.ZIndex = 12
		local content = scroll(panel, "SettingsContent", UDim2.fromOffset(20, 58), UDim2.new(1, -40, 1, -184))
		content.ZIndex = 12
		text(content, "NameLabel", "Save / company name", UDim2.fromOffset(2, 0), UDim2.new(1, -18, 0, 26), 15)
		local nameInput = Instance.new("TextBox")
		nameInput.Name, nameInput.Text = "SaveName", entry.Name or ("Save " .. entry.Slot)
		nameInput.PlaceholderText = "Name your save"
		nameInput.ClearTextOnFocus, nameInput.MultiLine = false, false
		nameInput.Position, nameInput.Size = UDim2.fromOffset(2, 32), UDim2.new(1, -18, 0, 42)
		nameInput.TextSize, nameInput.TextXAlignment = 18, Enum.TextXAlignment.Center
		Theme.panel(nameInput, true)
		Theme.text(nameInput)
		nameInput.Parent = content

		-- Company icon: any Roblox decal or image ID, previewed as it is typed.
		text(content, "IconLabel", "Company icon (optional)", UDim2.fromOffset(2, 88), UDim2.new(1, -18, 0, 26), 15)
		local preview = badge(content, "IconPreview", UDim2.fromOffset(2, 120), 56, iconId(entry.Icon), initial(entry.Name))
		local iconInput = Instance.new("TextBox")
		iconInput.Name, iconInput.Text = "IconId", if entry.Icon then tostring(entry.Icon) else ""
		iconInput.PlaceholderText = "Decal or image ID"
		iconInput.ClearTextOnFocus, iconInput.MultiLine = false, false
		iconInput.Position, iconInput.Size = UDim2.fromOffset(70, 127), UDim2.new(1, -86, 0, 42)
		iconInput.TextSize, iconInput.TextXAlignment = 17, Enum.TextXAlignment.Center
		Theme.panel(iconInput, true)
		Theme.text(iconInput)
		iconInput.Parent = content
		local iconHelp = text(content, "IconHelp", "Paste a decal or image ID, or its Creator Store link. Leave empty for no icon.", UDim2.fromOffset(2, 182), UDim2.new(1, -18, 0, 36), 13, true)
		iconHelp.TextWrapped, iconHelp.TextTruncate, iconHelp.TextYAlignment = true, Enum.TextTruncate.None, Enum.TextYAlignment.Top
		local function updatePreview()
			local id = iconId(iconInput.Text)
			preview.Image = iconImage(id)
			preview.Initial.Visible = id == nil
			preview.Initial.Text = initial(nameInput.Text)
		end
		iconInput:GetPropertyChangedSignal("Text"):Connect(updatePreview)
		nameInput:GetPropertyChangedSignal("Text"):Connect(updatePreview)

		-- The company type is picked once, when the save is created. The other
		-- branch is bought later from the office PC (BRANCHES app).
		local companyType = "Fishing"
		local top = 230
		if creating then
			text(content, "CompanyTypeLabel", "Company type", UDim2.fromOffset(2, top), UDim2.new(1, -18, 0, 26), 15)
			local typeButtons = {}
			local typeHelp
			local function paintTypes()
				for kind, item in typeButtons do
					item:SetAttribute("SaveButtonStyle", if kind == companyType then "Selected" else "Normal")
					style(item, item:GetAttribute("SaveButtonStyle"))
				end
				local other = Branches.Info[if companyType == "Fishing" then "Cafe" else "Fishing"]
				typeHelp.Text = string.format("%s You can buy the %s later on your office PC.", Branches.Info[companyType].Blurb, string.lower(other.Title))
			end
			for index, kind in Branches.ORDER do
				local label = if kind == "Fishing" then "Fishing company" else "Café (city)"
				typeButtons[kind] = button(content, "Company" .. kind, label, UDim2.new((index - 1) * 0.5, 2, 0, top + 30), UDim2.new(0.5, -13, 0, 42), function()
					if busy or entering then return end
					companyType = kind
					paintTypes()
				end)
			end
			typeHelp = text(content, "CompanyTypeHelp", "", UDim2.fromOffset(2, top + 80), UDim2.new(1, -18, 0, 48), 13, true)
			typeHelp.TextWrapped, typeHelp.TextTruncate, typeHelp.TextYAlignment = true, Enum.TextTruncate.None, Enum.TextYAlignment.Top
			paintTypes()
			top += 136
		end

		local multiplayer = entry.Multiplayer == true
		local toggle
		local function toggleText()
			toggle.Text = "Multiplayer: " .. (if multiplayer then "ON" else "OFF")
			toggle:SetAttribute("SaveButtonStyle", if multiplayer then "Selected" else "Normal")
			style(toggle, toggle:GetAttribute("SaveButtonStyle"))
		end
		toggle = button(content, "Multiplayer", "", UDim2.fromOffset(2, top), UDim2.new(1, -18, 0, 42), function()
			if busy or entering then return end
			multiplayer = not multiplayer
			toggleText()
		end)
		toggleText()
		local hint = text(content, "MultiplayerHelp", "ON: Roblox friends can join while you are offline. Up to five members share this save and its wallet. The save name is the company name.", UDim2.fromOffset(2, top + 52), UDim2.new(1, -18, 0, 70), 14, true)
		hint.TextWrapped, hint.TextTruncate, hint.TextYAlignment = true, Enum.TextTruncate.None, Enum.TextYAlignment.Top
		local y = top + 132
		if not creating then
			text(content, "MembersHeading", "COMPANY MEMBERS", UDim2.fromOffset(2, y), UDim2.new(1, -18, 0, 24), 15)
			y += 32
			local members = entry.Members or { { UserId = player.UserId, Name = player.Name } }
			for _, member in members do
				local memberId = member.UserId
				local owner = memberId == player.UserId
				text(content, "Member" .. tostring(memberId), (member.Name or ("User " .. tostring(memberId))) .. (if owner then " · Creator" else ""), UDim2.fromOffset(2, y), UDim2.new(1, if owner then -18 else -110, 0, 36), 14, true)
				if not owner then
					button(content, "Remove" .. tostring(memberId), "Remove", UDim2.new(1, -104, 0, y), UDim2.fromOffset(88, 34), function()
						local response = request("Settings", { Slot = entry.Slot, Name = entry.Name, Multiplayer = entry.Multiplayer == true, RemoveUserId = memberId })
						if response then acceptChange(response, "Company member removed.") end
					end, "Danger")
				end
				y += 44
			end
		end
		content.CanvasSize = UDim2.fromOffset(0, y + 8)
		local errorLabel = text(panel, "Error", "", UDim2.new(0, 22, 1, -116), UDim2.new(1, -44, 0, 48), 13, true)
		errorLabel.TextWrapped, errorLabel.TextTruncate, errorLabel.ZIndex = true, Enum.TextTruncate.None, 12
		local function submit()
			if busy or entering then return end
			local response = request(if creating then "Create" else "Settings", {
				Slot = entry.Slot, Name = nameInput.Text, Multiplayer = multiplayer, Icon = iconInput.Text,
				Company = if creating then companyType else nil,
			})
			if response then
				acceptChange(response, if creating then "Save created. Press Play when you are ready." else "Save settings updated.")
			end
		end
		local cancel = button(panel, "Cancel", "Cancel", UDim2.new(0, 22, 1, -60), UDim2.new(0.5, -30, 0, 40), function()
			if not busy then closeModal() end
		end)
		local save = button(panel, "Save", if creating then "Create save" else "Save settings", UDim2.new(0.5, 8, 1, -60), UDim2.new(0.5, -30, 0, 40), submit, "Selected")
		cancel.ZIndex, save.ZIndex = 12, 12
		nameInput.FocusLost:Connect(function(enterPressed) if enterPressed then submit() end end)
		if UserInputService.GamepadEnabled then GuiService.SelectedObject = toggle end
	end

	local refreshButton = button(window, "Refresh", "Refresh", UDim2.new(1, -128, 0, 22), UDim2.fromOffset(104, 34), function()
		if not entering then refresh() end
	end)
	-- Keep the window clear of Roblox's top bar (menu, chat and other core
	-- buttons draw over IgnoreGuiInset screens).
	local function topInset()
		local ok, inset = pcall(function() return GuiService.TopbarInset end)
		if ok and typeof(inset) == "Rect" and inset.Max.Y > 0 then return inset.Max.Y end
		return DEFAULT_TOPBAR
	end
	local function resize()
		local size = backdrop.AbsoluteSize
		local narrow = size.X < 760
		local margin = if narrow then 8 else 16
		local top = topInset()
		window:SetAttribute("TopInset", top)
		title.TextSize = if narrow then 21 else 27
		subtitle.Text = if narrow then "Three saves. Five members per company." else "Your company, your crew, one shared wallet."
		window.Position = UDim2.new(0.5, 0, 0.5, top / 2)
		window.Size = UDim2.new(1, -margin * 2, 1, -margin * 2 - top)
		refreshButton.Size = UDim2.fromOffset(if narrow then 88 else 104, 34)
		refreshButton.Position = UDim2.new(1, if narrow then -104 else -128, 0, 22)
		body.Position, body.Size = UDim2.fromOffset(if narrow then 16 else 24, 100), UDim2.new(1, if narrow then -32 else -48, 1, -164)
		own.Position, own.Size = UDim2.fromScale(0, 0), if narrow then UDim2.new(1, 0, 0.56, -6) else UDim2.new(0.59, -8, 1, 0)
		side.Position, side.Size = if narrow then UDim2.new(0, 0, 0.56, 6) else UDim2.new(0.59, 8, 0, 0), if narrow then UDim2.new(1, 0, 0.44, -6) else UDim2.new(0.41, -8, 1, 0)
		if modal and modal:FindFirstChild("Panel") then
			modal.Panel.Position = window.Position
			modal.Panel.Size = UDim2.new(1, -32, 1, -48 - top)
		end
	end
	backdrop:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	pcall(function() GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(resize) end)
	player:GetAttributeChangedSignal("SaveSelectionRequired"):Connect(function()
		entering = false
		setBusy(false)
		if selectionRequired() then setOpening(false) end
		visibility()
		if gui.Enabled and loaded then task.spawn(refresh) end
	end)
	player:GetAttributeChangedSignal("BoatDataStatus"):Connect(visibility)
	player:GetAttributeChangedSignal("SaveSelectionOpening"):Connect(visibility)
	local function teleportState()
		if player:GetAttribute("SaveTeleporting") == true then
			entering = true
			setBusy(true)
			status.Text = "Joining your company server…"
		elseif entering and selectionRequired() then
			entering = false
			setBusy(false)
			setOpening(false)
			status.Text = "The company server could not be reached. Please try joining again."
		end
	end
	player:GetAttributeChangedSignal("SaveTeleporting"):Connect(teleportState)
	-- A failed Roblox teleport restores selection without requiring a rejoin.
	player:GetAttributeChangedSignal("SaveSelectionError"):Connect(function()
		local message = player:GetAttribute("SaveSelectionError")
		if type(message) == "string" and message ~= "" then
			entering = false
			setBusy(false)
			setOpening(false)
			status.Text = message
		end
	end)
	render()
	gui.Parent = player:WaitForChild("PlayerGui")
	resize()
	visibility()
	teleportState()
	player:SetAttribute("SaveSelectionMounted", true)
	task.spawn(function()
		remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SaveRequest")
		refresh()
	end)
	-- Retry the first list quickly; afterwards refresh company availability.
	local function poll()
		if gui.Parent == nil then return end
		if gui.Enabled then refresh() end
		task.delay(if loaded then 15 else 2, poll)
	end
	task.delay(if loaded then 15 else 2, poll)
end

return Service
