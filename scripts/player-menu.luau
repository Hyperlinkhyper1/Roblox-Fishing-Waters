local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local function signal()
	local handlers = {}
	local event = {}
	function event:Connect(callback)
		local connection = { Connected = true }
		function connection:Disconnect()
			self.Connected = false
		end
		table.insert(handlers, { callback, connection })
		return connection
	end
	function event:Once(callback)
		local connection
		connection = self:Connect(function(...)
			connection:Disconnect()
			callback(...)
		end)
		return connection
	end
	function event:Fire(...)
		for _, handler in table.clone(handlers) do
			if handler[2].Connected then
				handler[1](...)
			end
		end
	end
	return event
end
local Vector2 = {
	new = function(x, y)
		return { X = x, Y = y }
	end,
}
local vectorMeta = {
	__add = function(a, b)
		return { X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z }
	end,
}
local Vector3 = {
	new = function(x, y, z)
		return setmetatable({ X = x, Y = y, Z = z }, vectorMeta)
	end,
}
-- Transform calls are recorded here; geometric framing still needs Studio.
local frameMeta = {}
frameMeta.__mul = function(a)
	return a
end
frameMeta.__index = {
	Inverse = function(self)
		return self
	end,
}
local CFrame = {
	new = function()
		return setmetatable({ Position = Vector3.new(0, 0, 0) }, frameMeta)
	end,
	lookAt = function(position, target)
		return { Position = position, Target = target }
	end,
	Angles = function()
		return setmetatable({}, frameMeta)
	end,
}
local UDim = {
	new = function(scale, offset)
		return { Scale = scale, Offset = offset }
	end,
}
local UDim2 = {}
function UDim2.new(x, xo, y, yo)
	return { X = UDim.new(x or 0, xo or 0), Y = UDim.new(y or 0, yo or 0) }
end
function UDim2.fromOffset(x, y)
	return UDim2.new(0, x, 0, y)
end
function UDim2.fromScale(x, y)
	return UDim2.new(x, 0, y, 0)
end
local colorMethods = {}
function colorMethods:Lerp(other, alpha)
	return setmetatable({
		self[1] + (other[1] - self[1]) * alpha,
		self[2] + (other[2] - self[2]) * alpha,
		self[3] + (other[3] - self[3]) * alpha,
	}, { __index = colorMethods })
end
local Color3 = {
	new = function(...)
		return setmetatable({ ... }, { __index = colorMethods })
	end,
	fromRGB = function(...)
		return setmetatable({ ... }, { __index = colorMethods })
	end,
}
local ColorSequence = {
	new = function(...)
		return { ... }
	end,
}
local ColorSequenceKeypoint = {
	new = function(time, value)
		return { Time = time, Value = value }
	end,
}
local NumberSequenceKeypoint = {
	new = function(time, value)
		return { Time = time, Value = value }
	end,
}
local NumberSequence = {
	new = function(value)
		return { Keypoints = value }
	end,
}
local Enum = setmetatable({}, {
	__index = function(self, key)
		local values = setmetatable({}, {
			__index = function(_, name)
				return key .. "." .. name
			end,
		})
		rawset(self, key, values)
		return values
	end,
})
local Instance = {}
local methods = {}
local game
function Instance.new(kind)
	local self = {
		props = {
			ClassName = kind,
			FontFace = { Family = "mock-font-family" },
			ZIndex = 1,
			Name = kind,
			AbsoluteSize = Vector2.new(1020, 680),
			Volume = 0.5,
			Text = "",
			Visible = true,
			DescendantAdded = signal(),
			ChildAdded = signal(),
			ChildRemoved = signal(),
			Activated = signal(),
			MouseEnter = signal(),
			MouseLeave = signal(),
			SelectionGained = signal(),
			SelectionLost = signal(),
			CharacterAdded = signal(),
			CharacterRemoving = signal(),
			Died = signal(),
		},
		children = {},
		attributes = {},
		signals = {},
	}
	return setmetatable(self, {
		__index = function(item, key)
			return methods[key] or item.props[key] or methods.FindFirstChild(item, key)
		end,
		__newindex = function(item, key, value)
			local previous = item.props[key]
			if previous == value then
				return
			end
			item.props[key] = value
			if key == "Parent" then
				if previous then
					local index = table.find(previous.children, item)
					if index then
						table.remove(previous.children, index)
					end
					previous.ChildRemoved:Fire(item)
				end
				if value then
					table.insert(value.children, item)
					value.ChildAdded:Fire(item)
					local ancestor = value
					while ancestor do
						ancestor.DescendantAdded:Fire(item)
						ancestor = ancestor.Parent
					end
					if game then
						game.DescendantAdded:Fire(item)
					end
				end
			end
			if item.signals[key] then
				item.signals[key]:Fire()
			end
		end,
	})
end
function methods:IsA(kind)
	return self.ClassName == kind
		or (kind == "BasePart" and self.ClassName == "Part")
		or (
			kind == "GuiObject"
			and table.find(
					{ "Frame", "TextLabel", "TextButton", "TextBox", "ImageLabel", "ScrollingFrame" },
					self.ClassName
				)
				~= nil
		)
end
function methods:GetChildren()
	return table.clone(self.children)
end
function methods:GetDescendants()
	local result = {}
	for _, child in self.children do
		table.insert(result, child)
		for _, nested in child:GetDescendants() do
			table.insert(result, nested)
		end
	end
	return result
end
function methods:FindFirstChild(name, recursive)
	for _, child in self.children do
		if child.Name == name then
			return child
		end
		if recursive then
			local found = child:FindFirstChild(name, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function methods:WaitForChild(name)
	return assert(self:FindFirstChild(name), name)
end
function methods:GetPropertyChangedSignal(key)
	if not self.signals[key] then
		self.signals[key] = signal()
	end
	return self.signals[key]
end
function methods:GetAttributeChangedSignal(key)
	return self:GetPropertyChangedSignal("Attribute_" .. key)
end
function methods:GetAttribute(key)
	return self.attributes[key]
end
function methods:SetAttribute(key, value)
	if self.attributes[key] == value then
		return
	end
	self.attributes[key] = value
	self:GetAttributeChangedSignal(key):Fire()
end
function methods:ClearAllChildren()
	for _, child in self:GetChildren() do
		child:Destroy()
	end
end
function methods:Destroy()
	self:ClearAllChildren()
	self.Parent = nil
end
function methods:Clone()
	local copy = Instance.new(self.ClassName)
	for key, value in self.props do
		if key ~= "Parent" and type(value) ~= "table" then
			copy[key] = value
		end
	end
	for _, child in self:GetChildren() do
		child:Clone().Parent = copy
	end
	return copy
end
function methods:PivotTo(frame)
	self.PivotFrame = frame
end
function methods:GetPivot()
	return CFrame.new()
end
function methods:GetBoundingBox()
	return CFrame.new(), Vector3.new(4, 6, 2)
end
function methods:IsDescendantOf(parent)
	local current = self.Parent
	while current do
		if current == parent then
			return true
		end
		current = current.Parent
	end
	return false
end
local now, timers = 100, {}
local os = {
	clock = function()
		return now
	end,
	time = function()
		return 123456
	end,
	date = function()
		return "Oct 23, 2026"
	end,
}
local task = {}
function task.spawn(callback, ...)
	callback(...)
end
function task.wait(delay)
	now += delay or 0
	return delay
end
function task.delay(delay, callback)
	table.insert(timers, { now + delay, callback })
end
local function advance(delay)
	now += delay
	local previous = timers
	timers = {}
	for _, timer in previous do
		if timer[1] <= now then
			timer[2]()
		else
			table.insert(timers, timer)
		end
	end
end
local player = Instance.new("Player")
player.Name, player.DisplayName, player.UserId = "TestAngler", "Test Angler", 7
player:SetAttribute("BoatDataStatus", "Ready")
local playerGui = Instance.new("PlayerGui")
playerGui.Parent = player
local Players = Instance.new("Players")
player.Parent = Players
Players.LocalPlayer, Players.PlayerAdded, Players.PlayerRemoving = player, signal(), signal()
function Players:GetPlayers()
	return { player }
end
function Players:GetPlayerByUserId(userId)
	return if player.Parent == self and player.UserId == userId then player else nil
end
function Players:GetUserThumbnailAsync()
	return "mock-thumbnail"
end
local previewLoads, failPreview = 0, false
function Players:CreateHumanoidModelFromDescriptionAsync(description, rig)
	previewLoads += 1
	assert(not failPreview, "Avatar service unavailable")
	check(
		description.ClassName == "HumanoidDescription" and rig == Enum.HumanoidRigType.R15,
		"Preview uses the shared staff description and the live NPC rig"
	)
	check(
		description.Shirt == 382578523 or description.Shirt == 6500613508,
		"Preview loads a role-specific catalog uniform"
	)
	local model = Instance.new("Model")
	local head = Instance.new("Part")
	head.Name, head.Parent = "Head", model
	Instance.new("Humanoid").Parent = model
	Instance.new("LocalScript").Parent = model
	return model
end
local ReplicatedStorage = Instance.new("ReplicatedStorage")
local workspace = Instance.new("Workspace")
local Lighting = Instance.new("Lighting")
local SoundService = Instance.new("SoundService")
local GuiService = {}
local UserInputService = { InputBegan = signal(), GamepadEnabled = true, KeyboardEnabled = true, TouchEnabled = false }
local passPrompts = {}
local productPrompts, failProductPrompt = {}, false
local MarketplaceService = {
	PromptProductPurchase = function(_, who, productId)
		assert(not failProductPrompt, "Purchase prompt unavailable")
		table.insert(productPrompts, { who, productId })
	end,
	PromptGamePassPurchase = function(_, who, passId)
		table.insert(passPrompts, { who, passId })
	end,
}
Enum.GroupMembershipStatus =
	{ None = "None", Joined = "Joined", JoinRequestPending = "Pending", AlreadyMember = "Member" }
local groupPrompts, failGroupPrompt, groupPromptStatus = 0, false, Enum.GroupMembershipStatus.Joined
local GroupService = {
	PromptJoinAsync = function(_, groupId)
		assert(groupId == 772704145, "Join prompt must use the configured community")
		groupPrompts += 1
		assert(not failGroupPrompt, "Join prompt unavailable")
		return groupPromptStatus
	end,
}
function player:IsInGroupAsync(groupId)
	assert(groupId == 772704145, "Membership check must use the configured community")
	return self.groupMember == true
end
local services = {
	TextService = {
		FilterStringAsync = function(_, value)
			return { GetNonChatStringForBroadcastAsync = function() return value:gsub("badword", "#######") end }
		end,
	},
	GroupService = GroupService,
	MarketplaceService = MarketplaceService,
	Players = Players,
	ReplicatedStorage = ReplicatedStorage,
	Lighting = Lighting,
	SoundService = SoundService,
	GuiService = GuiService,
	UserInputService = UserInputService,
}
game = {
	DescendantAdded = signal(),
	GetService = function(_, name)
		return assert(services[name], name)
	end,
	GetDescendants = function()
		local all = {}
		for _, service in { Players, ReplicatedStorage, Lighting, SoundService } do
			for _, item in service:GetDescendants() do
				table.insert(all, item)
			end
		end
		return all
	end,
}
local Theme = (function()
	-- THEME_SOURCE --
end)()
local Data = (function()
	-- DATA_SOURCE --
end)()
local Catalog = (function()
	-- CATALOG_SOURCE --
end)()
local StaffCatalog = (function()
	-- STAFF_SOURCE --
end)()
local StaffPreview = (function()
	-- PREVIEW_SOURCE --
end)()
local BoatCatalog = (function()
	-- BOAT_SOURCE --
end)()
local profile = { Cash = 0, OwnedRods = {}, OwnedBoats = {}, Angler = Data.decode(nil) }
local failSave = false
local BoatService = {
	getProfile = function()
		return profile
	end,
	updateProgress = function(_, transform)
		if failSave then
			return false, "Save failed"
		end
		transform(profile)
		player:SetAttribute("AnglerRevision", (player:GetAttribute("AnglerRevision") or 0) + 1)
		return true, "Saved."
	end,
}
local Service = (function()
	-- SERVICE_SOURCE --
end)()
Service.start()
local remote = ReplicatedStorage:WaitForChild("AnglerMenu")
function remote:InvokeServer(...)
	return self.OnServerInvoke(player, ...)
end
local function invoke(...)
	now += 1
	return remote:InvokeServer(...)
end
check(invoke("Get").Ok, "Can fetch current profile")
check(not invoke("Catch", "Trout", 999).Ok and profile.Angler.Stats.TotalCaught == 0, "Forged catches rejected")
check(not invoke("Setting", "Cash", 999).Ok and profile.Cash == 0, "Settings cannot change the wallet")
check(not invoke("Setting", "MasterVolume", 101).Ok, "Out of bounds settings rejected")
check(
	invoke("Setting", "MasterVolume", 50).Ok and profile.Angler.Settings.MasterVolume == 50,
	"Validated settings save"
)
check(not remote:InvokeServer("Setting", "MasterVolume", 0).Ok, "Remote requests are rate limited")
check(not invoke("Title", "Admin").Ok and profile.Angler.EquippedTitle == "", "Locked/unknown titles rejected")
check(not invoke("Code", "FAKE").Ok and profile.Cash == 0, "No invented code rewards")
check(not invoke("Code", {}).Ok and not invoke("Code", string.rep("x", 65)).Ok, "Malformed code requests rejected")
Catalog.Titles.Angler = { Name = "Angler" }
check(not invoke("Title", "Angler").Ok, "Catalog titles still require ownership")
profile.Angler.Titles.Angler = true
local character = Instance.new("Model")
local head = Instance.new("Part")
head.Name, head.Parent = "Head", character
local humanoid = Instance.new("Humanoid")
humanoid.Parent = character
player.Character = character
player.CharacterAdded:Fire(character)
check(
	invoke("Title", "Angler").Ok and head:FindFirstChild("AnglerTitle"),
	"Unlocked title equips and appears above avatar"
)
local nameplate = head:FindFirstChild("AnglerTitle")
check(invoke("Title", "").Ok and not nameplate.Title.Visible, "Removing title hides the optional title row")
check(
	nameplate.Rank.Text == "[0] Beginner" and nameplate.PlayerName.Text == player.DisplayName,
	"Rank appears without an equipped title or loaded level"
)
check(humanoid.DisplayDistanceType == Enum.HumanoidDisplayDistanceType.None, "Custom name replaces the default name")
for _, range in
	{
		{ 0, 9, "Beginner" },
		{ 10, 14, "Student Fisher" },
		{ 15, 19, "Novice Fisher" },
		{ 20, 24, "Good Fisher" },
		{ 25, 34, "Experienced Fisher" },
		{ 35, 49, "Veteran Fisher" },
		{ 50, 74, "Master Fisher" },
		{ 75, 100, "Poseidon" },
	}
do
	for level = range[1], range[2] do
		player:SetAttribute("Level", level)
		check(
			nameplate.Rank.Text == string.format("[%d] %s", level, range[3]),
			"Rank follows the saved level, including every threshold"
		)
	end
end
check(nameplate.Rank.TextColor3[3] > nameplate.Rank.TextColor3[1], "Highest rank is purple")
player:SetAttribute("Level", 5)
check(nameplate.Rank.TextColor3[1] > nameplate.Rank.TextColor3[3], "Beginner is yellow")
check(
	head:FindFirstChild("AnglerTitle") == nameplate and #head:GetChildren() == 1,
	"Progress updates reuse the nameplate"
)
local displayName = player.DisplayName
player.DisplayName = "Renamed Angler"
check(nameplate.PlayerName.Text == "Renamed Angler", "Name row follows the player display name")
player.DisplayName = displayName
local respawn = Instance.new("Model")
local respawnHead = Instance.new("Part")
respawnHead.Name, respawnHead.Parent = "Head", respawn
Instance.new("Humanoid").Parent = respawn
player.Character = respawn
player.CharacterAdded:Fire(respawn)
check(respawnHead.AnglerTitle.Rank.Text == "[5] Beginner", "Respawning restores the current rank")
player.Character = character
profile.Angler.Titles.Angler = nil
humanoid.Died:Fire()
check(
	profile.Angler.Stats.Deaths == 1 and profile.Angler.Stats.CatchStreak == 0,
	"Death is saved and resets current streak"
)
failSave = true
check(
	not invoke("Setting", "MasterVolume", 20).Ok and profile.Angler.Settings.MasterVolume == 50,
	"Failed saves do not publish changes"
)
failSave = false
local thunder = Instance.new("Sound")
thunder.Name, thunder.Volume, thunder.Parent = "WeatherThunder", 0.43, SoundService
local Settings = (function()
	-- SETTINGS_SOURCE --
end)()
Settings.start()
Settings.apply(profile.Angler.Settings)
check(thunder.Volume == 0.43 and thunder.SoundGroup.Name == "PlayerEffects", "Mixer preserves source volumes")
check(
	thunder.SoundGroup.Volume == 1 and thunder.SoundGroup.Parent.Volume == 0.5,
	"Audio multipliers match saved settings"
)
local track = Instance.new("Sound")
track:SetAttribute("AudioCategory", "Music")
track.Parent = SoundService
check(track.SoundGroup.Name == "PlayerMusic", "Future music is routed to the music mixer")
local fishing = Instance.new("Folder")
fishing.Name, fishing.Parent = "Fishing", ReplicatedStorage
local rodRequest = Instance.new("RemoteEvent")
rodRequest.Name, rodRequest.Parent = "Request", fishing
local rodActions = {}
local skinActions = {}
function rodRequest:FireServer(action, value)
	table.insert(rodActions, action)
	if action == "EquipRodSkin" then
		table.insert(skinActions, value)
	end
end
-- Roblox supplies child lookups through instance indexing.
ReplicatedStorage.props.Fishing = fishing
fishing.props.Request = rodRequest
function methods:FindFirstChildOfClass(class)
	for _, child in self:GetChildren() do
		if child:IsA(class) then
			return child
		end
	end
	return nil
end
-- Preview geometry is covered by check-rods; these mocks exercise menu lifecycle.
services.CollectionService = {
	RemoveTag = function(_, tool, tag)
		tool:SetAttribute("RemovedPreviewTag", tag)
	end,
}
local FishingRod = {
	build = function()
		local tool = Instance.new("Tool")
		local part = Instance.new("Part")
		part.Parent = tool
		return tool
	end,
}
local EquipmentBag = (function()
	-- BAG_SOURCE --
end)()
local Menu = (function()
	-- MENU_SOURCE --
end)()
Menu.start()
advance(1)
local gui = playerGui:WaitForChild("PlayerMenu")
local sidebar = gui:WaitForChild("LeftNavigation")
local overlay = gui:WaitForChild("MenuOverlay")
local card = overlay:WaitForChild("MenuWindow")
local content = card:WaitForChild("Content")
check(
	sidebar.Bestiary.LayoutOrder == 1
		and sidebar.Journal.LayoutOrder == 2
		and sidebar.Home.LayoutOrder == 3
		and sidebar.Equipmentbag.LayoutOrder == 4,
	"Bestiary and Journal lead the sidebar"
)
local function contains(value)
	for _, item in content:GetDescendants() do
		if type(item.Text) == "string" and string.find(item.Text, value, 1, true) then
			return true
		end
	end
	return false
end
local function clickText(value)
	for _, item in content:GetDescendants() do
		if item:IsA("TextButton") and item.Text == value then
			item.Activated:Fire()
			return
		end
	end
	error("Missing button: " .. value)
end
local function open(name)
	now += 1
	sidebar:WaitForChild(name):GetPropertyChangedSignal("Text")
	sidebar:WaitForChild(name).Activated:Fire()
end
player:SetAttribute("DrydockScreenOpen", true)
check(not sidebar.Visible, "Drydock preview must hide all five navigation buttons")
open("Bestiary")
check(
	not overlay.Visible and not player:GetAttribute("PlayerMenuOpen"),
	"Hidden navigation must not open a menu over the drydock"
)
player:SetAttribute("DrydockScreenOpen", false)
check(sidebar.Visible, "Closing the drydock must restore navigation")
for _, name in { "Bestiary", "Equipmentbag", "Journal", "Settings", "Shop" } do
	open(name)
	check(overlay.Visible and player:GetAttribute("PlayerMenuOpen"), "Navigation opens " .. name)
	check(sidebar.Parent == gui and not sidebar.Visible, "Menu windows do not contain the main navigation tabs")
	local selected = sidebar:WaitForChild(name)
	check(selected.ThemeFace:GetAttribute("Finish") == "Selected", "Active navigation retains its selected state")
	local isBook = name == "Bestiary" or name == "Journal"
	check(
		selected.ThemeCaption.Text == selected.Text and selected.ThemeCaption.TextStrokeTransparency == 1,
		"Sidebar captions use clean typography"
	)
	check(
		(not not card.BookChrome.Visible) == isBook and (not card.ThemeInnerRim.Visible) == isBook,
		"Only books use the parchment window"
	)
	if isBook then
		check(
			selected.ThemeFace:FindFirstChild("BookSpine") and selected.ThemeFace:FindFirstChild("PageEdges"),
			"Book buttons show covers and page edges"
		)
	end
	card:WaitForChild("CloseMenu").Activated:Fire()
	check(not overlay.Visible and not player:GetAttribute("PlayerMenuOpen"), "Close resets modal state")
	check(
		sidebar.Parent == gui and sidebar.Visible and selected.ThemeFace:GetAttribute("Finish") == "Normal",
		"Close restores the neutral HUD navigation"
	)
end
open("Bestiary")
check(contains("A bestiary waiting"), "No fake species in the empty collection")
Catalog.Fish.Trout = { Name = "Trout", Image = "mock-fish-image", AverageKg = 2, RarityDenominator = 10 }
Catalog.Mutations.Albino = { Name = "Albino", RarityMultiplier = 100 }
profile.Angler = Data.recordCatch(profile.Angler, "Trout", "Albino", 3.25, 48, 100, Catalog.Fish, Catalog.Mutations)
open("Bestiary")
open("Bestiary")
check(contains("3.25 kg") and contains("Albino ×1"), "Bestiary renders actual weight and mutations")
local fishImage = false
for _, item in content:GetDescendants() do
	if item.ClassName == "ImageLabel" and item.Image == "mock-fish-image" then
		fishImage = true
	end
end
check(fishImage, "Fish catalog images are rendered")
for _, item in content:GetChildren() do
	if item.ClassName == "TextBox" then
		item.Text = "absent"
		check(contains("No matching fish"), "Search empty state")
		item.Text = "albino"
		check(contains("3.25 kg"), "Search includes caught mutations")
	end
end
-- BAG_CHECKS_START
open("Equipmentbag")
check(
	contains("Tidebound Rod") and contains("One-time reward") and not contains("Owned"),
	"Unclaimed group rod is an offer, not owned equipment"
)
check(content:FindFirstChild("GroupReward", true):FindFirstChild("RodPreview") ~= nil, "Group offer has a rod preview")
clickText("[Join & Claim]")
check(
	groupPrompts == 1 and rodActions[#rodActions] == "ClaimGroupReward",
	"Group offer prompts joining then asks the server to verify"
)
player.groupMember = true
clickText("[Claim / Check again]")
check(
	groupPrompts == 1 and rodActions[#rodActions] == "ClaimGroupReward",
	"Existing members can claim without a join prompt"
)
player.groupMember = false
failGroupPrompt = true
local actionsBeforeGroup = #rodActions
clickText("[Claim / Check again]")
check(#rodActions == actionsBeforeGroup and contains("Retry"), "Failed join prompt restores a usable retry button")
failGroupPrompt = false
groupPromptStatus = Enum.GroupMembershipStatus.None
local promptButton = content:FindFirstChild("GroupReward", true).ClaimGroupReward
promptButton.Activated:Fire()
check(
	#rodActions == actionsBeforeGroup and promptButton.Text == "[Join & Claim]",
	"Cancelled join prompt leaves the reward unclaimed"
)
groupPromptStatus = Enum.GroupMembershipStatus.JoinRequestPending
promptButton.Activated:Fire()
check(
	#rodActions == actionsBeforeGroup and contains("Membership pending"),
	"Pending group requests do not request a reward"
)
groupPromptStatus = Enum.GroupMembershipStatus.Joined
local beforeRetry = #rodActions
advance(66)
check(
	#rodActions > beforeRetry and rodActions[#rodActions] == "ClaimGroupReward",
	"Successful join schedules a later server check for membership propagation"
)
profile.OwnedRods.StarterRod = true
open("Equipmentbag")
open("Equipmentbag")
clickText("[Equip]")
check(rodActions[#rodActions] == "EquipRod", "Equipment uses authorized rod service")
player:SetAttribute("RodEquipped", true)
clickText("[Equipped · Stow]")
check(rodActions[#rodActions] == "UnequipRod", "Equipment supports stowing")
profile.RodSkins = { BoneRod = 2, BambooRod = 1 }
profile.RodSkinCopies =
	{ { SkinId = "BoneRod", Serial = 1 }, { SkinId = "BoneRod", Serial = 2 }, { SkinId = "BambooRod", Serial = 1 } }
for _, width in { 1020, 362 } do
	player:SetAttribute("RodSkinSerial", 0)
	player:SetAttribute("RodSkin", "")
	card.AbsoluteSize = Vector2.new(width, 600)
	open("Equipmentbag")
	open("Equipmentbag")
	local cards = content:FindFirstChild("RodCards", true)
	local first, second = cards:FindFirstChild("Skin:BoneRod:1"), cards:FindFirstChild("Skin:BoneRod:2")
	check(
		first ~= nil and second ~= nil and contains("Serial #000001") and contains("Serial #000002"),
		"Each saved duplicate has a separate numbered card on desktop and phone"
	)
	second.EquipSkin.Activated:Fire()
	check(
		skinActions[#skinActions].SkinId == "BoneRod" and skinActions[#skinActions].Serial == 2,
		"Bag selects the exact owned copy through FishingService"
	)
	player:SetAttribute("RodSkinSerial", 2)
	player:SetAttribute("RodSkin", "BoneRod")
	open("Equipmentbag")
	open("Equipmentbag")
	check(contains("[Selected · Remove skin]"), "Saved equipped serial identifies the selected duplicate")
	content:FindFirstChild("RodCards", true):FindFirstChild("Skin:BoneRod:2").EquipSkin.Activated:Fire()
	check(skinActions[#skinActions] == "", "Selected skin can return to the plain look")
	local search = content:FindFirstChild("SearchRods", true)
	search.Text = "000002"
	check(
		not content:FindFirstChild("Skin:BoneRod:1", true) and content:FindFirstChild("Skin:BoneRod:2", true),
		"Bag searches skin serials"
	)
	search.Text = ""
	player:SetAttribute("RodSkinSerial", 1)
	open("Equipmentbag")
	open("Equipmentbag")
	local cards = content:FindFirstChild("RodCards", true)
	local bone, bamboo = cards:FindFirstChild("Skin:BoneRod:1"), cards:FindFirstChild("Skin:BambooRod:1")
	check(
		bone and bamboo and bone.EquipSkin.Text == "[Selected · Remove skin]" and bamboo.EquipSkin.Text == "[Use skin]",
		"Matching serials on different skins keep separate cards and selection"
	)
	bamboo.EquipSkin.Activated:Fire()
	check(
		skinActions[#skinActions].SkinId == "BambooRod" and skinActions[#skinActions].Serial == 1,
		"Bag selects the right skin when serials overlap"
	)
end
profile.GroupRodClaimed = true
profile.RodSkins.TideboundRod = 1
table.insert(profile.RodSkinCopies, { SkinId = "TideboundRod", Serial = 1 })
for _, width in { 1020, 362 } do
	card.AbsoluteSize = Vector2.new(width, 600)
	open("Equipmentbag")
	open("Equipmentbag")
	check(
		not content:FindFirstChild("GroupReward", true) and content:FindFirstChild("Skin:TideboundRod:1", true),
		"Claimed reward replaces the offer with its serialized copy on desktop and phone"
	)
	check(
		contains("+7.5% reel per hit") and contains("+7.5% big fish chance"),
		"Group perks preserve fractional values in the bag"
	)
end
card.AbsoluteSize = Vector2.new(1020, 600)
open("Journal")
check(
	contains("Fish caught") and contains("Highest value") and contains("Relative largest"),
	"Journal stats and findings render"
)
clickText("Achievements")
check(contains("First catch") and contains("Complete"), "Achievements derive from saved catches")
check(
	card.BookChrome:FindFirstChild("BestiaryBookmarkTab") == nil
		and card.BookChrome:FindFirstChild("JournalBookmarkTab") == nil,
	"Book edge tabs are removed"
)
open("Settings")
check(content:FindFirstChild("Shadows", true) ~= nil, "Performance tab exposes shadows")
clickText("Audio")
check(contains("Master volume") and contains("Sound effects"), "Audio tab controls")
now += 1
content:FindFirstChild("MasterVolumeDown", true).Activated:Fire()
check(profile.Angler.Settings.MasterVolume == 40, "Audio control persists server-validated change")
clickText("Codes")
check(
	content:FindFirstChild("CodeInput", true) and contains("no active codes"),
	"Codes tab input and honest empty state"
)
clickText("Titles")
check(contains("No titles unlocked yet"), "Titles tab doesn't invent unlocks")
card.AbsoluteSize = Vector2.new(362, 600)
check(contains("No titles unlocked yet"), "Narrow layout rebuilds")
check(sidebar.Parent == gui and not sidebar.Visible, "Mobile menu windows also omit main navigation tabs")
check(
	content.Position.X.Offset == 20 and content.Size.X.Offset == -40,
	"Menu content uses the full window width with standard padding"
)
open("Journal")
check(content:FindFirstChild("JournalFindingsPage", true).Position.Y.Offset == 514, "Narrow journal pages stack")
check(not card.BookChrome.CenterBinding.Visible, "Narrow books hide the center binding when pages stack")
open("Shop")
check(contains("Auto Store") and contains("aboard your own ship"), "Shop explains Auto Store")
clickText("Buy Auto Store · Robux")
check(#passPrompts == 1 and passPrompts[1][2] == 3722004182, "Shop prompts configured gamepass")
player:SetAttribute("OwnsAutoStore", true)
check(contains("Owned"), "Ownership refreshes shop")
clickText("Owned")
check(#passPrompts == 1, "Owned pass does not prompt again")
UserInputService.InputBegan:Fire({ KeyCode = Enum.KeyCode.ButtonB })
check(not overlay.Visible, "Controller back closes the menu")
print("Player menu: " .. checks .. " UI, mixer and remote checks passed (recording mocks; no Studio rendering).")

local sample = Instance.new("TextButton")
sample.Text = "Before"
Theme.button(sample)
local childCount = #sample:GetDescendants()
for _ = 1, 20 do
	Theme.button(sample, "Selected")
end
check(#sample:GetDescendants() == childCount, "Repeated state updates do not duplicate theme components")
sample.Text, sample.TextSize, sample.ZIndex = "After", 23, 5
check(
	sample.ThemeCaption.Text == "After" and sample.ThemeCaption.TextSize == 23 and sample.ThemeCaption.ZIndex == 6,
	"Captions follow dynamic action text, font size and layering"
)
check(not sample:FindFirstChildOfClass("UIGradient"), "Gradients cannot tint button text")
Theme.button(sample, "Disabled")
check(
	sample.ThemeFace:GetAttribute("Finish") == "Disabled" and not sample.AutoButtonColor,
	"Disabled controls retain their muted finish"
)
check(card.CloseMenu.ThemeFace:GetAttribute("Finish") == "Danger", "Close buttons retain their red finish")
print("Shared UI theme: navigation, responsive layout, caption synchronization and repeated state updates passed.")
-- SHOP_UI_CHECKS --
