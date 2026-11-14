player:SetAttribute("BoatDataStatus", "Selecting")
player:SetAttribute("SaveSelectionRequired", true)
local remotes = Instance.new("Folder")
remotes.Name, remotes.Parent = "Remotes", ReplicatedStorage
local remote = Instance.new("RemoteFunction")
remote.Name, remote.Parent = "SaveRequest", remotes
local calls, failNext, repeatSubmit = {}, false, nil
local selectShowedLoading = nil
local saved = {
	Ok = true,
	Slots = {
		{ Slot = 1, OwnerUserId = 7, Name = "Original save", Exists = true, Multiplayer = false, NetWorth = 1250, Icon = 4242 },
	},
	Companies = {
		{ Slot = 2, OwnerUserId = 20, OwnerName = "OfflineFriend", Name = "Sea Crew", Multiplayer = true, MemberCount = 2, NetWorth = 12500, Members = { { UserId = 20 }, { UserId = 7 } } },
		{ Slot = 1, OwnerUserId = 30, OwnerName = "OtherFriend", Name = "Full Crew", Multiplayer = true, MemberCount = 5, NetWorth = 25000, Icon = 9001 },
	},
}
function remote:InvokeServer(action, payload)
	table.insert(calls, { Action = action, Payload = payload })
	if action == "Select" then
		local selector = playerGui:FindFirstChild("SaveSelection")
		selectShowedLoading = player:GetAttribute("SaveSelectionOpening") == true and selector ~= nil and not selector.Enabled
	end
	if failNext then failNext = false; return { Ok = false, Message = "Saved data is temporarily unavailable." } end
	if action == "List" then return saved end
	if action == "Create" then
		check(payload.Slot == 2, "Creating a save submits the selected empty owner slot")
		table.insert(saved.Slots, { Slot = payload.Slot, OwnerUserId = 7, Exists = true, Name = payload.Name, Multiplayer = payload.Multiplayer, Icon = tonumber(payload.Icon), Members = { { UserId = 7, Name = "TestAngler" }, { UserId = 21, Name = "Crewmate" } }, MemberCount = 2 })
	elseif action == "Settings" then
		if repeatSubmit then local fire = repeatSubmit; repeatSubmit = nil; fire() end
		local slot = saved.Slots[2]
		slot.Name, slot.Multiplayer = payload.Name, payload.Multiplayer
		if payload.RemoveUserId then slot.Members = { slot.Members[1] }; slot.MemberCount = 1 end
	elseif action == "Select" then
		return { Ok = true, Entering = true }
	else error("Unexpected save action " .. tostring(action)) end
	return saved
end

local SaveSelection = (function()
-- SAVE_SELECTION_SOURCE --
end)()
SaveSelection.start()
SaveSelection.start()
local gui = assert(playerGui:FindFirstChild("SaveSelection"))
local backdrop = gui.Backdrop
local window = backdrop.Window
local slots = window.Body.OwnSaves.Slots
local companies = window.Body.Companies.CompanyList
check(#playerGui:GetChildren() == 1, "Selector starts once")
check(player:GetAttribute("SaveSelectionMounted") == true and gui.Enabled, "Screen mounts before character/gear readiness")
check(player.Character == nil, "Initial selection needs no character")
check(#slots:GetChildren() == 3, "Owner always receives exactly three save slots")
local blur = camera:FindFirstChild("SaveSelectionBlur")
check(blur ~= nil and blur.Size > 0 and camera.CameraType == Enum.CameraType.Scriptable, "Selector shows a blurred camera panorama behind it")
check(#streamRequests == 1 and streamRequests[1][1].X == 0 and streamRequests[1][1].Z == 0, "Panorama streams in the main island without a character")
check(backdrop.BackgroundTransparency > 0.5, "Backdrop turns translucent once the island has streamed in")
check(window.Position.Y.Offset == 29 and window.Size.Y.Offset == -32 - 58, "Window stays below the Roblox top bar")
check(slots.Slot1.Position.Y.Offset > 0, "The first card is not clipped by the top of its list")
check(slots.Slot1.Icon.Image:find("id=4242", 1, true) ~= nil and not slots.Slot1.Icon.Initial.Visible, "Saved company icon shows on its card")
check(slots.Slot2.Icon.Image == "" and slots.Slot2.Icon.Initial.Text == "+", "Empty slots show a placeholder icon")
check(companies.Company2.Icon.Image:find("id=9001", 1, true) ~= nil, "Friend company icons show in the sidebar")
check(companies.Company1.Icon.Initial.Visible and companies.Company1.Icon.Initial.Text == "S", "Companies without an icon show their initial")
check(slots.Slot1.SaveName.Text == "Original save", "Existing save keeps its name")
check(slots.Slot1.Details.Text:find("$1,250", 1, true) ~= nil, "Saved net worth has readable currency formatting")
check(slots.Slot2.Create ~= nil and slots.Slot3.Create ~= nil, "Empty owner slots show creation controls")
check(#companies:GetChildren() == 2 and #slots:GetChildren() == 3, "Joined companies appear separately without consuming owner slots")
check(companies.Company1.Owner.Text == "Created by OfflineFriend", "Offline friend's company remains visible")
check(companies.Company1.Join.Text == "Continue company", "Existing company members can continue")
check(not companies.Company2.Join.Active and not companies.Company2.Join.Selectable, "Five-member company cannot accept a sixth member")
local before = #calls
companies.Company2.Join.Activated:Fire()
check(#calls == before, "Even a forced activation cannot submit a full-company join")

slots.Slot2.Create.Activated:Fire()
local settings = assert(backdrop.SaveSettings)
local content = settings.Panel.SettingsContent
check(content.SaveName.Text == "Save 2", "Creation defaults to the chosen slot name")
content.SaveName.Text = "Tidal Company"
check(content.IconId.Text == "" and content.IconPreview.Initial.Visible, "New saves start without an icon")
content.IconId.Text = "https://create.roblox.com/store/asset/777123/Logo"
check(content.IconPreview.Image:find("id=777123", 1, true) ~= nil and not content.IconPreview.Initial.Visible, "Icon preview follows a pasted Creator Store link")
content.IconId.Text = "777"
content.Multiplayer.Activated:Fire()
check(content.Multiplayer.Text == "Multiplayer: ON", "Multiplayer is editable before creating the save")
failNext = true
settings.Panel.Save.Activated:Fire()
check(backdrop.SaveSettings == settings and settings.Panel.Error.Text == "Saved data is temporarily unavailable.", "Save failures stay in the editor with an actionable error")
check(settings.Panel.Save.Active, "Failed saves re-enable controls for retry")
settings.Panel.Save.Activated:Fire()
check(backdrop.SaveSettings == nil, "Successful creation closes the editor")
check(slots.Slot2.SaveName.Text == "Tidal Company" and slots.Slot2.Details.Text:find("2/5", 1, true), "New company occupies only its creator's selected slot")
check(calls[#calls].Action == "Create", "Create response refreshes cards without an immediate rate-limited List")
check(calls[#calls].Payload.Icon == "777" and slots.Slot2.Icon.Image:find("id=777", 1, true) ~= nil, "Created save submits and shows its icon")

slots.Slot2.Settings.Activated:Fire()
settings = assert(backdrop.SaveSettings)
content = settings.Panel.SettingsContent
content.SaveName.Text = "Renamed Crew"
local start = #calls
repeatSubmit = function() settings.Panel.Save.Activated:Fire() end
settings.Panel.Save.Activated:Fire()
local mutations = 0
for index = start + 1, #calls do if calls[index].Action == "Settings" then mutations += 1 end end
check(mutations == 1, "Duplicate save clicks cannot submit concurrent mutations")
check(slots.Slot2.SaveName.Text == "Renamed Crew", "Owner can rename the company")
check(not companies.Company2.Join.Active, "Refresh preserves the full-company disabled state")

slots.Slot2.Settings.Activated:Fire()
settings = assert(backdrop.SaveSettings)
content = settings.Panel.SettingsContent
check(content.Remove7 == nil and content.Remove21 ~= nil, "Member controls protect the original creator")
content.Remove21.Activated:Fire()
local removal
for _, call in calls do if call.Action == "Settings" and call.Payload.RemoveUserId then removal = call end end
check(removal and removal.Payload.RemoveUserId == 21, "Owner can remove a company member from save settings")

backdrop.AbsoluteSize = Vector2.new(393, 852)
check(window.Body.OwnSaves.Size.X.Scale == 1 and window.Body.Companies.Position.Y.Scale == 0.56, "Phone layout stacks the company list beneath owner saves")
check(window.Body.OwnSaves.Slots.ScrollingDirection == Enum.ScrollingDirection.Y, "All three saves remain accessible by scrolling on compact screens")
backdrop.AbsoluteSize = Vector2.new(1280, 720)
check(window.Body.Companies.Position.X.Scale == 0.59, "Desktop company list returns to the side of the screen")

local previousLists = 0
for _, call in calls do if call.Action == "List" then previousLists += 1 end end
advance(15)
local nextLists = 0
for _, call in calls do if call.Action == "List" then nextLists += 1 end end
check(nextLists == previousLists + 1, "Visible selector periodically refreshes company availability")
failNext = true
companies.Company1.Join.Activated:Fire()
check(selectShowedLoading, "Picking a save hands the screen to the loading screen before the server answers")
check(gui.Enabled and player:GetAttribute("SaveSelectionOpening") == nil and window.Status.Text == "Saved data is temporarily unavailable.", "A failed pick brings the selector back with its error")
selectShowedLoading = nil
companies.Company1.Join.Activated:Fire()
local last = calls[#calls]
check(last.Action == "Select" and last.Payload.OwnerUserId == 20 and last.Payload.Slot == 2, "Joining submits the original creator's slot identity")
check(not window.Refresh.Active, "Entry in progress prevents duplicate joins")
check(selectShowedLoading and not gui.Enabled and player:GetAttribute("SaveSelectionOpening") == true, "Loading stays up while the accepted save opens")
player:SetAttribute("SaveSelectionError", "Teleport failed. Please try again.")
check(window.Refresh.Active and window.Status.Text == "Teleport failed. Please try again.", "Failed teleport restores retry controls")
check(gui.Enabled and player:GetAttribute("SaveSelectionOpening") == nil, "Failed teleport brings the selector back over the loading screen")
player:SetAttribute("BoatDataStatus", "Ready")
player:SetAttribute("SaveSelectionRequired", false)
check(not gui.Enabled and GuiService.SelectedObject == nil, "Successful selection releases the overlay and controller focus")
check(camera:FindFirstChild("SaveSelectionBlur") == nil and camera.CameraType == Enum.CameraType.Custom, "Entering a save hands the camera back and removes the blur")
previousLists = #calls
advance(15)
check(#calls == previousLists, "Hidden selector does not make background save requests")
print("Save selection: " .. checks .. " checks passed (production native UI with recording mocks).")
