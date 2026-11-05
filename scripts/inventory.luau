local checks = 0
local function check(value, reason) checks += 1 assert(value, reason) end
local Grid = (function() -- GRID_SOURCE --
end)()
local Inventory = (function() -- INVENTORY_SOURCE --
end)()
local Backpacks = (function() -- BACKPACKS_SOURCE --
end)()
local Data = (function() -- DATA_SOURCE --
end)()
local Catalog = {
	Fish = { Cod = { Name = "Cod", Rarity = "Common", AverageKg = 1, RarityDenominator = 10, Shapes = { Normal = { "##" }, Huge = { "###", "###" } } },
		Shark = { Name = "Shark", Rarity = "Rare", AverageKg = 10, RarityDenominator = 100, Shapes = { Normal = { "##", "##" } } },
		Tire = { Name = "Tire", Rarity = "Common", AverageKg = 7, RarityDenominator = 4, Shapes = { Normal = { "##" } } },
		WoodenBranch = { Name = "Wooden Branch", Rarity = "Junk", AverageKg = 1, RarityDenominator = 2, Shapes = { Normal = { "#" } } },
		Boot = { Name = "Old Boot", Rarity = "Junk", AverageKg = 1, RarityDenominator = 2, Shapes = { Normal = { "#" } } } },
	Rarities = { Common = { Order = 1 }, Rare = { Order = 3 }, Junk = { Order = 0 } }, Mutations = { Normal = {} },
}
local function fish(id, stamp, value)
	return Data.recordCatch(nil, id or "Cod", "Normal", 1, value or 20, stamp or 1, Catalog.Fish, Catalog.Mutations, "Normal").Hand
end
local function item(id, stamp, value, locked)
	return { Fish = fish(id, stamp, value), X = 1, Y = 1, R = 0, Locked = locked }
end
local mask = { "#.#", ".#.", "#.#" }
local scattered = { { PartId = "Lantern", X = 1, Y = 1, R = 0 }, { PartId = "Lantern", X = 3, Y = 3, R = 0 } }
check(Grid.bestSpot(mask, scattered, item(), Catalog.Fish) ~= nil, "Two-space fish fits without contiguous cells")
check(Grid.used({ item(), item() }, Catalog.Fish) == 4, "Overlapping legacy coordinates still count both fish")
check(not Grid.bestSpot({ "###" }, { item() }, item(), Catalog.Fish), "Capacity overflow rejected")
check(Grid.space({ Fish = { FishId = "Cod", Size = "Huge" } }, Catalog.Fish) == 6, "Large fish keeps original space cost")
local infinite = setmetatable({ "#" }, { __index = { Infinite = true } })
check(Grid.bestSpot(infinite, { item(), item() }, item("Shark"), Catalog.Fish), "Unlimited pack remains compatible")
local data = Data.decode(nil)
data.BackpackVersion = 2
data.Backpack = { item("Cod", 1, 30, true), item("Boot", 2, 5), item("Shark", 3, 100) }
local boat = { Name = "Test boat", Hold = { "########" }, StarterParts = { { PartId = "Lantern", X = 1, Y = 1, R = 0 } } }
local pack = { Hold = { "########" } }
local function move(raw, source, index, destination, expected)
	local entry = if source == "Hand" then raw.Hand elseif source == "Backpack" then raw.Backpack[index] else raw.Holds.TestBoat[index]
	return Data.moveInventory(raw, source, index, destination, expected or Inventory.expected(entry), "TestBoat", boat, pack, Catalog.Fish, Inventory.matches)
end
local stale = Inventory.expected(data.Backpack[1])
stale.CaughtAt = 999
check(not move(data, "Backpack", 1, "Boat", stale), "Stale identity cannot move another fish")
local transferred = assert(move(data, "Backpack", 1, "Boat"))
check(#transferred.Backpack == 2 and #transferred.Holds.TestBoat == 2, "Direct transfer keeps starter fitting and moves one fish")
check(transferred.Holds.TestBoat[2].Locked and data.Backpack[1].Locked, "Transfer preserves favorite and original snapshot")
check(not move(transferred, "Boat", 2, "Release"), "Favorite cannot be released")
local inHand = assert(move(transferred, "Boat", 2, "Hand"))
check(inHand.Hand.Locked and #inHand.Holds.TestBoat == 1, "Taking in hand preserves favorite")
check(not move(inHand, "Hand", "Hand", "Release"), "Held favorite cannot be released")
local sold, soldCount = Data.sellToCove(inHand, 1, 10, true)
check(soldCount == 0 and sold.Hand, "Held favorite cannot be sold")
local delivered, record = Data.deliverFish(inHand, function() return true end)
check(record and record.CaughtAt ~= inHand.Hand.CaughtAt and delivered.Hand.Locked, "Delivery skips held favorites")
local stocked, count = Data.stockFreezer({ Hand = inHand.Hand })
check(count == 0 and stocked.Hand.Locked, "Held favorites stay out of automatic stocking")
local unlocked = assert(Data.lockInventory(inHand, "Hand", "Hand", false, Inventory.expected(inHand.Hand), "TestBoat", boat, Inventory.matches))
check(not unlocked.Hand.Locked and inHand.Hand.Locked, "Unfavorite is persisted without mutating old data")
local released = assert(move(unlocked, "Hand", "Hand", "Release"))
check(not released.Hand, "Unlocked fish can be released")
local noRoom = Data.decode(nil)
noRoom.Hand = fish("Shark")
noRoom.Backpack = { item("Shark"), item("Shark") }
check(not move(noRoom, "Hand", "Hand", "Backpack"), "Transfers cannot exceed backpack capacity")
check(not Data.hasCatchSpace(noRoom, pack, Catalog.Fish), "Casting sees the same capacity limit")
local refill = assert(move(transferred, "Boat", 2, "Backpack"))
check(refill.Backpack[#refill.Backpack].Locked, "Favorite survives boat-to-backpack transfer")
local reload = Data.decode(refill)
check(reload.Backpack[#reload.Backpack].Locked, "Favorite survives save decoding")
check(not Data.unloadFish(transferred, "TestBoat", 2, transferred.Holds.TestBoat[2].Fish), "Porter cannot unload a favorite")
check(not Data.unloadFishToKitchenStorage(transferred, "TestBoat", 2, transferred.Holds.TestBoat[2].Fish, Catalog.Fish), "Kitchen porter cannot consume a favorite")
do
	local data = { Holds = { TestBoat = { item("Cod", 1, 20, true), item("Cod", 2, 30) } } }
	-- WORKER_CARGO_SOURCE --
	local candidates = cargo("TestBoat")
	check(#candidates == 1 and candidates[1].Index == 2, "Porters skip favorites and can still collect later fish")
end
check(Data.decode(nil).Settings.AutoStore and Data.validSetting("AutoStore", false), "Auto Store defaults on and accepts boolean settings")
check(not Data.validSetting("AutoStore", "false"), "Auto Store rejects non-boolean settings")
local state = { Backpack = data.Backpack, Items = transferred.Holds.TestBoat, Hand = fish("Cod", 6, 40) }
local entries = Inventory.entries(state, Catalog, Grid)
local both = { Fish = true, Items = true, Favorites = false }
local visible, value = Inventory.visible(entries, "All", both, "", nil, true)
check(#visible == 6 and value == 205, "All tab and worth include every catch and boat fitting once")
visible, value = Inventory.visible(entries, "Backpack", both, "", nil, true)
check(#visible == 4 and value == 175, "Backpack tab includes only carried catches")
visible = Inventory.visible(entries, "Boat", both, "", nil, true)
check(#visible == 2 and visible[1].Item.PartId == "Lantern", "Boat tab retains fitted items")
visible = Inventory.visible(entries, "All", { Fish = true, Items = false, Favorites = false }, "", "Worth", true)
check(#visible == 4 and visible[1].Worth == 30 and visible[4].Worth == 100, "Fish-only worth ascending")
visible = Inventory.visible(entries, "All", both, "", "Worth", false)
check(visible[1].Name == "Shark", "Worth descending")
visible = Inventory.visible(entries, "All", both, "", "Rarity", false)
check(visible[1].Name == "Shark", "Rarity descending")
visible = Inventory.visible(entries, "All", both, "", "Rarity", true)
check(visible[1].Item.PartId == "Lantern", "Rarity ascending includes equipment first")
visible = Inventory.visible(entries, "All", both, "", "Name", true)
check(visible[1].Name == "Cod" and visible[#visible].Name == "Shark", "Alphabetical order")
visible, value = Inventory.visible(entries, "All", { Fish = true, Items = true, Favorites = true }, "", nil, true)
check(#visible == 2 and value == 60, "Favorites shows locked fish across both inventories")
visible = Inventory.visible(entries, "All", both, "  sHaRk ", nil, true)
check(#visible == 1 and visible[1].Index == 3 and visible[1].Source == "Backpack", "Search preserves original transfer index")
visible = Inventory.visible(entries, "All", both, "[", nil, true)
check(#visible == 0, "Search treats punctuation literally")
local foundItems = Inventory.entries({ Hand = fish("Boot", 20, 5),
	Backpack = { item("Tire", 21, 12), item("Cod", 22, 30) }, Items = { item("WoodenBranch", 23, 2) } }, Catalog, Grid)
visible, value = Inventory.visible(foundItems, "All", { Fish = false, Items = true }, "", nil, true)
check(#visible == 3 and value == 19 and visible[1].Name == "Old Boot" and visible[2].Name == "Tire"
	and visible[3].Name == "Wooden Branch", "Items includes boots, Common tires and branches across hand, backpack and boat")
visible = Inventory.visible(foundItems, "All", { Fish = true, Items = false }, "", nil, true)
check(#visible == 1 and visible[1].Name == "Cod", "Fish view excludes found items regardless of catch rarity")

-- Minimal recording UI and service doubles; execute the production modules.
local function signal()
	local listeners = {}
	return { Connect = function(_, fn) table.insert(listeners, fn) return { Disconnect = function() end } end,
		Fire = function(_, ...) for _, fn in listeners do fn(...) end end }
end
local methods, mt = {}, {}
local Instance = {}
function Instance.new(class)
	return setmetatable({ class = class, props = { Name = class, Visible = true, TextureId = "", Text = "", CanvasPosition = { X = 0, Y = 0 } },
		children = {}, attributes = {}, events = {}, properties = {} }, mt)
end
function mt.__index(self, key)
	if methods[key] then return methods[key] end
	if self.props[key] ~= nil then return self.props[key] end
	if key == "Activated" or key == "InputBegan" or key == "MouseButton2Click" or key == "OnClientEvent" or key == "CharacterAdded" then
		self.events[key] = self.events[key] or signal() return self.events[key]
	end
	for _, child in self.children do if child.Name == key then return child end end
	return nil
end
function mt.__newindex(self, key, value)
	if key == "Parent" then
		if self.props.Parent then local i = table.find(self.props.Parent.children, self) if i then table.remove(self.props.Parent.children, i) end end
		if value then table.insert(value.children, self) end
	end
	self.props[key] = value
	if self.properties[key] then self.properties[key]:Fire() end
end
function methods:GetChildren() return table.clone(self.children) end
function methods:GetDescendants()
	local result = {}
	for _, child in self.children do table.insert(result, child) for _, nested in child:GetDescendants() do table.insert(result, nested) end end
	return result
end
function methods:IsA(class) return self.class == class end
function methods:FindFirstChild(name, recursive)
	for _, child in if recursive then self:GetDescendants() else self.children do if child.Name == name then return child end end
	return nil
end
function methods:FindFirstChildOfClass(class)
	for _, child in self.children do if child:IsA(class) then return child end end
	return nil
end
methods.WaitForChild = methods.FindFirstChild
function methods:Destroy() self.Parent = nil self.props.Destroyed = true end
function methods:GetAttribute(name) return self.attributes[name] end
function methods:SetAttribute(name, value) self.attributes[name] = value if self.events[name] then self.events[name]:Fire() end end
function methods:GetAttributeChangedSignal(name) self.events[name] = self.events[name] or signal() return self.events[name] end
function methods:GetPropertyChangedSignal(name) self.properties[name] = self.properties[name] or signal() return self.properties[name] end
local focused
function methods:CaptureFocus() focused = self end
function methods:ReleaseFocus() focused = nil end
local Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255, Lerp = function(self) return self end } end }
Color3.new = function() return Color3.fromRGB(0, 0, 0) end
local Vector2 = { new = function(x, y) return { X = x, Y = y } end, zero = { X = 0, Y = 0 } }
local UDim = { new = function(scale, offset) return { Scale = scale, Offset = offset } end }
local UDim2 = { new = function(xs, xo, ys, yo) return { X = UDim.new(xs, xo), Y = UDim.new(ys, yo) } end }
UDim2.fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end
UDim2.fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end
local Enum = setmetatable({}, { __index = function(self, key)
	local kind = setmetatable({}, { __index = function(t, value) rawset(t, value, value) return value end })
	rawset(self, key, kind) return kind
end })
Enum.ContextActionPriority.High = { Value = 3000 }
local Font = { new = function() return {} end }
local ColorSequence = { new = function() return {} end }
Catalog.Rarities.Common.Color, Catalog.Rarities.Rare.Color, Catalog.Rarities.Junk.Color = Color3.new(), Color3.new(), Color3.new()
local now, previews = 1, 0
local os = { clock = function() return now end }
local task = { spawn = function(fn) fn() end, defer = function(fn) fn() end, wait = function(delay) now += delay or 1 end }
local Players = { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end }
local player = Instance.new("Player")
player.UserId = 12
local playerGui = Instance.new("PlayerGui") playerGui.Parent = player
local robloxBackpack = Instance.new("Backpack") robloxBackpack.Parent = player
local rod = Instance.new("Tool") rod.Name = "Starter Rod" rod.Parent = robloxBackpack
local bobber = Instance.new("Tool") bobber.Name = "Bobber" bobber.Parent = robloxBackpack
local character = Instance.new("Model") player.Character = character
local spear = Instance.new("Tool") spear.Name = "Spear" spear.Parent = character
local humanoid = Instance.new("Humanoid") humanoid.Parent = character
humanoid.EquipTool = function(_, tool) tool.Parent = character end
humanoid.UnequipTools = function() rod.Parent = robloxBackpack end
Players.LocalPlayer = player
local ReplicatedStorage = Instance.new("ReplicatedStorage")
local aboard, owns, saveFails = false, false, false
local BoatCatalog = { TestBoat = boat }
local profile = { Angler = Data.decode(nil) }
profile.Angler.BackpackVersion = 2
profile.Angler.Backpack = { item("Cod", 10, 30) }
profile.Angler.Holds.TestBoat = { { PartId = "Lantern", X = 1, Y = 1, R = 0 }, item("Shark", 11, 100) }
local saves, equipped = 0, 0
local model = Instance.new("Model")
local Boats = { getProfile = function() return profile end, activeBoat = function() return "TestBoat", model end,
	updateProgress = function(_, fn)
		if saveFails then return false, "Save failed" end
		fn(profile) saves += 1 return true, ""
	end, refit = function() end }
local RunService = { Heartbeat = signal(), RenderStepped = signal() }
local UserInputService = { InputBegan = signal(), GetFocusedTextBox = function() return focused end }
local binding
local ContextActionService = { BindActionAtPriority = function(_, name, fn, touch, priority, key)
	check(name == "ToggleInventory" and key == "Backquote" and priority > 3000, "Grave key takes priority over default backpack") binding = fn
end }
local prompts = 0
local MarketplaceService = { PromptGamePassPurchase = function(_, who, id)
	check(who == player and id == 3722004182, "Purchase opens the existing Auto Store gamepass") prompts += 1
end }
local coreBackpack = true
local StarterGui = { GetCoreGuiEnabled = function(_, kind) return if kind == "Backpack" then coreBackpack else true end,
	SetCoreGuiEnabled = function(_, kind, enabled) if kind == "Backpack" then coreBackpack = enabled end end }
local workspace = { CurrentCamera = { ViewportSize = Vector2.new(1366, 768) }, FindFirstChild = function() return nil end }
local services = { Players = Players, ReplicatedStorage = ReplicatedStorage, RunService = RunService,
	UserInputService = UserInputService, ContextActionService = ContextActionService, MarketplaceService = MarketplaceService, StarterGui = StarterGui }
local game = { GetService = function(_, name) return services[name] end }
local Server = (function() -- SERVER_SOURCE --
end)()
Server.start()
local remote = ReplicatedStorage.Cargo.Request
remote.InvokeServer = function(_, action, ...)
	now += 0.3
	return remote.OnServerInvoke(player, action, ...)
end
local function invoke(action, ...) now += 0.3 return remote.OnServerInvoke(player, action, ...) end
local before = saves
check(not invoke("AutoStore", false).Ok and saves == before, "Server denies Auto Store toggles without ownership")
owns = true
check(invoke("AutoStore", false).Ok and profile.Angler.Settings.AutoStore == false, "Owner can turn Auto Store off")
check(Data.decode(profile.Angler).Settings.AutoStore == false, "Auto Store off survives decoding")
check(invoke("AutoStore", true).Ok and profile.Angler.Settings.AutoStore, "Owner can turn Auto Store on")
check(not invoke("AutoStore", "true").Ok, "Remote rejects invalid toggle types")
local payload = { Source = "Backpack", Index = 1, Destination = "Boat", BoatId = "TestBoat", Expected = Inventory.expected(profile.Angler.Backpack[1]) }
before = saves
check(not invoke("InventoryMove", payload).Ok and saves == before, "Remote rejects boat transfers from land without a save")
aboard = true
payload.BoatId = "OtherBoat"
check(not invoke("InventoryMove", payload).Ok, "Remote rejects a stale boat id")
payload.BoatId = "TestBoat"
saveFails = true
check(not invoke("InventoryMove", payload).Ok and #profile.Angler.Backpack == 1, "Save failure preserves source fish")
saveFails = false
check(invoke("InventoryMove", payload).Ok and #profile.Angler.Backpack == 0, "Remote performs one direct atomic transfer")
check(not invoke("InventoryMove", payload).Ok, "Replaying a stale transfer cannot duplicate fish")
aboard = false
profile.Angler.Backpack = { item("Cod", 10, 30) }
local Client = (function() -- CLIENT_SOURCE --
end)()
Client.start()
local gui = playerGui.Cargo
local shade, panel = gui.InventoryShade, gui.InventoryShade.InventoryPanel
check(not shade.Visible and previews == 0, "Joining does not open inventory or build hidden previews")
check(binding(nil, "Begin") == "Sink" and shade.Visible, "Grave key opens inventory and consumes the key")
check(coreBackpack == false, "Opening inventory hides the vanilla Roblox backpack")
check(panel.InventoryItems and not panel:FindFirstChild("Hold"), "Card inventory replaces the old hold grid")
check(panel.BackpackTab and panel.BoatTab and panel.AllTab, "Three source tabs exist")
check(panel.TotalWorth.Text == "Total worth: $30", "Backpack worth is shown bottom right")
check(panel.Capacity.Text == "Backpack 2 / 4 space", "Capacity counts space independently from cards")
check(#panel.InventoryItems:GetChildren() == 1 and not panel:FindFirstChild("EquipTool"),
	"Inventory hides carried and equipped gear and has no tool equip action")
panel.ViewFish.Activated:Fire()
check(panel.EmptyInventory.Visible, "Items view stays empty when only gear is carried")
panel.ViewFish.Activated:Fire()
local first = panel.InventoryItems:GetChildren()[1]
first.Activated:Fire()
check(panel.ActionFavorite.Visible and panel.ActionHand.Visible, "Card selection exposes touch-friendly fish actions")
panel.ActionFavorite.Activated:Fire()
check(profile.Angler.Backpack[1].Locked and panel.InventoryItems:FindFirstChild("LockIcon", true), "Favorite action locks the saved fish")
panel.ViewFavorites.Activated:Fire()
check(panel.TotalWorth.Text == "Total worth: $30", "Favorites toggle recalculates displayed worth")
panel.ViewFish.Activated:Fire()
check(panel.EmptyInventory.Visible and panel.TotalWorth.Text == "Total worth: $0", "View toggles combine and empty filters clear worth")
panel.ViewFish.Activated:Fire()
panel.ViewFavorites.Activated:Fire()
panel.AllTab.Activated:Fire()
check(panel.TotalWorth.Text == "Total worth: $160", "All tab combines inventories without hand/tool duplication")
panel.Search.Activated:Fire()
panel.SearchInput.Text = "Shark"
check(panel.TotalWorth.Text == "Total worth: $100", "Search button filters the inventory")
check(binding(nil, "Begin") == "Pass" and shade.Visible, "Typing in search does not trigger inventory hotkey")
panel.Search.Activated:Fire()
check(panel.SearchInput.Text == "" and not panel.SearchInput.Visible, "Closing search restores the full list")
panel.SortWorth.Activated:Fire()
check(panel.SortWorth.Text == "↓ Worth", "Worth sort starts descending")
panel.SortWorth.Activated:Fire()
check(panel.SortWorth.Text == "↑ Worth", "Pressing the same sort reverses direction")
panel.SortOff.Activated:Fire()
check(panel.SortOff.Text == "Sorting: Off", "Sorting can be switched off")
panel.AutoStore.Activated:Fire()
check(prompts == 1, "Non-owner Auto Store button opens purchase screen")
player:SetAttribute("OwnsAutoStore", true)
panel.AutoStore.Activated:Fire()
check(not profile.Angler.Settings.AutoStore and panel.AutoStore.Text == "OFF", "Owner button saves and displays off state")
local initialPreviews = previews
RunService.Heartbeat:Fire()
check(previews == initialPreviews, "Unchanged state does not rebuild fish viewports")
ReplicatedStorage.Cargo.Update.OnClientEvent:Fire(invoke("Get").State)
check(previews == initialPreviews, "Unrelated profile refresh does not rebuild fish viewports")
aboard = true
player:SetAttribute("RefitPending", "TestBoat|Rudder|Rudder")
ReplicatedStorage.Cargo.Update.OnClientEvent:Fire(invoke("Get").State)
check(panel.FitPart.Visible and panel.CancelRefit.Visible, "Reserved refit opens confirmation in Inventory")
panel.FitPart.Activated:Fire()
check(player:GetAttribute("RefitPending") ~= nil and panel.FitPart.Visible, "Capacity refusal preserves refit reservation")
local boatFish = profile.Angler.Holds.TestBoat[3]
check(invoke("InventoryMove", { Source = "Boat", Index = 3, Destination = "Backpack", BoatId = "TestBoat",
	Expected = Inventory.expected(boatFish) }).Ok, "Boat space can be freed during a pending refit")
ReplicatedStorage.Cargo.Update.OnClientEvent:Fire(invoke("Get").State)
panel.FitPart.Activated:Fire()
check(player:GetAttribute("RefitPending") == nil and profile.Angler.Holds.TestBoat[3].PartId == "Rudder", "Fitting consumes space without choosing slots")
player:SetAttribute("RefitPending", "TestBoat|Rudder|Rudder")
ReplicatedStorage.Cargo.Update.OnClientEvent:Fire(invoke("Get").State)
panel.CancelRefit.Activated:Fire()
check(player:GetAttribute("RefitPending") == nil, "Cancel refit clears its reservation")
check(not shade.Visible, "Refit confirmation returns the screen to the drydock menu")
binding(nil, "Begin")
for _, size in { Vector2.new(1920, 1080), Vector2.new(1366, 768), Vector2.new(844, 390), Vector2.new(390, 844) } do
	workspace.CurrentCamera.ViewportSize = size RunService.RenderStepped:Fire()
	check(panel.UIScale.Scale * panel.Size.X.Offset <= size.X - 24 + 0.01, "Inventory fits viewport width")
	check(panel.UIScale.Scale * panel.Size.Y.Offset <= size.Y - 90 + 0.01, "Inventory fits viewport height")
end
check(binding(nil, "Begin") == "Sink" and not shade.Visible, "Grave key closes inventory")
check(coreBackpack == true, "Closing inventory restores the vanilla hotbar")
check(#panel.InventoryItems:GetChildren() == 0, "Closing releases card previews")
player:SetAttribute("RefitPending", "TestBoat|Rudder|Rudder")
ReplicatedStorage.Cargo.Update.OnClientEvent:Fire(invoke("Get").State)
binding(nil, "Begin")
check(not shade.Visible and player:GetAttribute("RefitPending") == nil, "Closing Inventory cancels an unfinished fitting")
print("Inventory: " .. checks .. " capacity, transactions, ownership, filters, keyboard and UI checks passed (recording doubles; no Studio rendering).")
