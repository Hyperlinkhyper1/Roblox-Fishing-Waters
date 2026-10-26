local Grid = (function()
	-- GRID_SOURCE --
end)()
local Backpacks = (function()
	-- BAGS_SOURCE --
end)()
local Data = (function()
	-- DATA_SOURCE --
end)()
local checks = 0
local function check(value, reason)
	checks += 1
	assert(value, reason)
end
local Catalog = {
	Fish = { Test = { AverageKg = 1, RarityDenominator = 1, Shapes = { Normal = { "##" } } } },
	Mutations = {
		Normal = {},
	},
}
local function catch(raw, stamp)
	return Data.recordCatch(raw, "Test", "Normal", 2, 30, stamp or 1, Catalog.Fish, Catalog.Mutations, "Normal")
end
local fresh = Data.decode(nil)
check(fresh.BackpackId == "Starter" and #fresh.Backpack == 0, "Old profiles get an empty starter pack")
check(#Backpacks.Order == 15, "Exactly fifteen backpacks")
local expected = { 4, 6, 8, 12, 16, 20, 24, 30, 36, 42, 48, 56, 64, 72, 80 }
for index, id in Backpacks.Order do
	local spec = Backpacks.Items[id]
	check(Grid.capacity(spec.Hold) == expected[index], "Catalog tile count")
	if index > 1 then
		for y, row in Backpacks.Items[Backpacks.Order[index - 1]].Hold do
			for x = 1, #row do
				check(Grid.open(spec.Hold, x, y), "Upgrade preserves all existing cells")
			end
		end
	end
end
local original = catch(nil)
local packed =
	assert(Data.moveCargo(original, nil, Backpacks.Items.Starter, "Hand", { X = 1, Y = 1, R = 0 }, Catalog.Fish, true))
check(original.Hand ~= nil and #original.Backpack == 0, "Moves copy their source profile")
check(packed.Hand == nil and #packed.Backpack == 1 and packed.Backpack[1].Fish.Kg == 2, "Fish packs with its traits")
local replay = Data.decode(packed)
check(replay.Backpack[1].X == 1 and replay.BackpackId == "Starter", "Placements survive reload")
local held = catch(packed, 2)
check(
	not Data.moveCargo(held, nil, Backpacks.Items.Starter, "Hand", { X = 1, Y = 1, R = 0 }, Catalog.Fish, true),
	"Overlaps rejected"
)
for _, spot in
	{
		{ X = 0, Y = 1, R = 0 },
		{ X = 4, Y = 1, R = 0 },
		{ X = 1, Y = 1, R = 4 },
		{ X = 0 / 0, Y = 1, R = 0 },
		{
			X = 1,
			Y = 1,
			R = 0.5,
		},
	}
do
	check(
		not Data.moveCargo(held, nil, Backpacks.Items.Starter, "Hand", spot, Catalog.Fish, true),
		"Invalid placement rejected"
	)
end
local rotated =
	assert(Data.moveCargo(packed, nil, Backpacks.Items.Starter, 1, { X = 2, Y = 1, R = 1 }, Catalog.Fish, true))
check(rotated.Backpack[1].R == 1 and packed.Backpack[1].R == 0, "Fish can rotate and move")
local released = assert(Data.moveCargo(held, nil, Backpacks.Items.Starter, 1, "Release", Catalog.Fish, true))
check(#released.Backpack == 0 and released.Hand.CaughtAt == 2, "Release preserves the other fish in hand")
check(
	not Data.moveCargo(held, nil, Backpacks.Items.Starter, 1, "Hand", Catalog.Fish, true),
	"Cannot overwrite a held fish"
)
local taken = assert(Data.moveCargo(packed, nil, Backpacks.Items.Starter, 1, "Hand", Catalog.Fish, true))
check(#taken.Backpack == 0 and taken.Hand.CaughtAt == 1, "Fish returns to the hotbar")
local BoatCatalog = { TestBoat = { Hold = { "####", "####", "####" }, StarterParts = {} } }
local onBoat =
	assert(Data.moveCargo(taken, "TestBoat", BoatCatalog.TestBoat, "Hand", { X = 1, Y = 1, R = 0 }, Catalog.Fish))
check(#onBoat.Backpack == 0 and #onBoat.Holds.TestBoat == 1, "Hand transfers backpack fish into boat cargo")
local full = Data.decode(nil)
for y = 1, 2 do
	for x = 1, 2, 2 do
		full = assert(
			Data.moveCargo(
				catch(full),
				nil,
				Backpacks.Items.Starter,
				"Hand",
				{ X = x, Y = y, R = 0 },
				Catalog.Fish,
				true
			)
		)
	end
end
local fullHand = catch(full, 8)
check(
	not Data.moveCargo(fullHand, nil, Backpacks.Items.Starter, "Hand", { X = 1, Y = 1, R = 0 }, Catalog.Fish, true)
		and fullHand.Hand ~= nil,
	"Full pack preserves a rejected catch"
)
local invalid = Data.decode(nil)
invalid.Backpack = { { PartId = "Engine", X = 1, Y = 1, R = 0 } }
check(not pcall(Data.decode, invalid), "Boat parts cannot be saved in a backpack")
-- Geometry uses the real builder and prop primitives.
local oldIndex = instanceMt.__index
instanceMt.__index = function(self, key)
	return oldIndex(self, key) or self:FindFirstChild(key)
end
function instanceMethods:GetBoundingBox()
	local low, high = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, piece in self:GetDescendants() do
		if piece:IsA("BasePart") then
			for _, x in { -0.5, 0.5 } do
				for _, y in { -0.5, 0.5 } do
					for _, z in { -0.5, 0.5 } do
						local p = piece.CFrame * Vector3.new(piece.Size.X * x, piece.Size.Y * y, piece.Size.Z * z)
						low, high = low:Min(p), high:Max(p)
					end
				end
			end
		end
	end
	return CFrame.new((low + high) / 2), high - low
end
function instanceMethods:GetPivot()
	if self.PrimaryPart then
		return self.PrimaryPart.CFrame
	end
	return self:GetBoundingBox()
end
function instanceMethods:PivotTo(target)
	local pivot = self:GetPivot()
	for _, piece in self:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.CFrame = target * pivot:ToObjectSpace(piece.CFrame)
		end
	end
end
function instanceMethods:ScaleTo(scale)
	local ratio = scale / (self._props.ModelScale or 1)
	local pivot = self:GetPivot()
	for _, piece in self:GetDescendants() do
		if piece:IsA("BasePart") then
			local frame = pivot:ToObjectSpace(piece.CFrame)
			piece.Size *= ratio
			piece.CFrame = pivot
				* CFrame.fromMatrix(frame.Position * ratio, frame.RightVector, frame.UpVector, frame.ZVector)
		end
	end
	self._props.ModelScale = scale
end
function instanceMethods:ClearAllChildren()
	for _, child in self:GetChildren() do
		child:Destroy()
	end
end
instanceMethods.WaitForChild = instanceMethods.FindFirstChild
local Models = (function()
	-- MODELS_SOURCE --
end)()
local signatures = {}
for _, id in Backpacks.Order do
	local model = Models.create(id)
	check(model:GetAttribute("BackpackId") == id and model.PrimaryPart ~= nil, "Each pack has a valid builder and root")
	local names = {}
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") then
			check(
				piece.Anchored and piece.Massless and not piece.CanCollide and not piece.CanTouch and not piece.CanQuery,
				"Display parts are inert"
			)
			table.insert(names, piece.Name)
		end
	end
	table.sort(names)
	local signature = table.concat(names, ",")
	check(not signatures[signature], "Every backpack has distinct geometry")
	signatures[signature] = true
	for _, torsoName in { "Torso", "UpperTorso" } do
		local avatar = Instance.new("Model")
		local torso = Instance.new("Part")
		torso.Name = torsoName
		torso.Size = Vector3.new(2, if torsoName == "Torso" then 2 else 1.6, 1)
		torso.CFrame = CFrame.new(20, 8, -30) * CFrame.Angles(0, 0.5, 0)
		torso.Parent = avatar
		local worn = Models.wear(avatar, id)
		check(worn.Parent == avatar and worn.PrimaryPart.BackWeld.Part1 == torso, "R6 and R15 packs weld to the torso")
		for _, piece in worn:GetDescendants() do
			if piece:IsA("BasePart") then
				check(
					not piece.Anchored and piece.Massless and not piece.CanCollide,
					"Worn packs cannot pin or weigh down the avatar"
				)
				check(torso.CFrame:PointToObjectSpace(piece.Position).Z > 0, "Worn geometry stays behind the avatar")
			end
		end
		local replacement = Models.wear(avatar, "Starter")
		check(worn.Parent == nil and replacement.Parent == avatar, "Equipping replaces the previous worn model")
	end
end
local legacy = Data.decode(packed)
legacy.BackpackVersion = nil
legacy.Backpack[1].X, legacy.Backpack[1].Y = 3, 3
local migrated = Data.decode(legacy)
check(
	migrated.BackpackId == "Cooler" and migrated.Backpack[1].X == 3,
	"Old occupied starter grids migrate without losing fish"
)
local Props = (function()
	-- PROPS_SOURCE --
end)()
local PlazaHouses = {
	boardText = function(piece, text, face)
		piece:SetAttribute("SignText", text)
	end,
	pavingFrame = function(plaza)
		return plaza:GetAttribute("PavingFrame")
	end,
}
local Shop = (function()
	-- BUILDER_SOURCE --
end)()
local plaza = Instance.new("Model")
plaza.Name = "Plaza"
plaza.Parent = workspace
local paving = CFrame.new(120, 8, -75) * CFrame.Angles(0, 0.4, 0)
plaza:SetAttribute("PavingFrame", paving)
local decorative =
	Props.stall(plaza, (paving * CFrame.new(44, 0, -18)).Position, -math.pi / 2 + 0.4, Random.new(1), Color3.new())
local keep =
	Props.stall(plaza, (paving * CFrame.new(44, 0, -6)).Position, -math.pi / 2 + 0.4, Random.new(2), Color3.new())
local shop = Shop.build(plaza, paving)
check(decorative.Parent == nil and keep.Parent == plaza, "Only replaced market stall is removed")
check(shop.Counter and CollectionService:HasTag(shop, "BackpackShop"), "Counter and shop tag exist")
check(
	(shop.Counter.Position - (paving * CFrame.new(44, 0, -18) * CFrame.Angles(0, -math.pi / 2, 0) * CFrame.new(
		0,
		1.5,
		1.5
	)).Position).Magnitude < 0.001,
	"Store follows rotated paving"
)
check(shop.StoreSign:GetAttribute("SignText") == "BACKPACKS", "Store has readable signage")
check(Shop.build(plaza, paving) == shop, "Baked map ensure is idempotent")
CollectionService:RemoveTag(shop, "BackpackShop")
Shop.ensure(workspace)
check(CollectionService:HasTag(shop, "BackpackShop"), "Saved-map migration restores the tag")
-- Exercise purchase and cargo remotes, including transaction retries.
local function signal()
	local listeners = {}
	return {
		Connect = function(_, fn)
			table.insert(listeners, fn)
		end,
		Fire = function(_, ...)
			for _, fn in listeners do
				fn(...)
			end
		end,
	}
end
local Players = {
	PlayerAdded = signal(),
	PlayerRemoving = signal(),
	GetPlayers = function()
		return {}
	end,
}
local ReplicatedStorage = Instance.new("Folder")
local root = Instance.new("Part")
root.CFrame = shop.Counter.CFrame
local character = Instance.new("Model")
local humanoid = Instance.new("Humanoid")
humanoid.Name = "Humanoid"
humanoid.Health = 100
humanoid.RigType = Enum.HumanoidRigType.R15
humanoid.Parent = character
root.Name = "HumanoidRootPart"
root.Parent = character
local torso = Instance.new("Part")
torso.Name = "UpperTorso"
torso.Size = Vector3.new(2, 1.6, 1)
torso.Parent = character
local player = { Character = character, Parent = Players, UserId = 1 }
local revisions = signal()
player.GetAttributeChangedSignal = function()
	return revisions
end
player.CharacterAdded = signal()
player.CharacterAppearanceLoaded = signal()
shop.Counter.BrowseBackpacksPrompt.Enabled = true
function CollectionService:GetTagged(tag)
	local found = {}
	for _, item in workspace:GetDescendants() do
		if self:HasTag(item, tag) then
			table.insert(found, item)
		end
	end
	return found
end
game.GetService = function(_, name)
	return ({ Players = Players, CollectionService = CollectionService, ReplicatedStorage = ReplicatedStorage })[name]
end
local now = 0
local os = {
	clock = function()
		return now
	end,
}
local profile = { Cash = 20000, Angler = packed }
local saves, failSave, aboard = 0, false, false
local Boats = {
	getProfile = function()
		return profile
	end,
	activeBoat = function()
		if aboard then
			return "TestBoat", {}
		end
	end,
}
function Boats.updateProgress(_, transform)
	saves += 1
	if failSave then
		return false, "Save failed"
	end
	local current
	for attempt = 1, 2 do
		current = { Cash = profile.Cash, Angler = Data.decode(profile.Angler) }
		local ok, reason = pcall(transform, current)
		if not ok then
			return false, tostring(reason)
		end
	end
	profile = current
	return true, "Saved"
end
local Service = (function()
	-- SERVICE_SOURCE --
end)()
Service.start()
Players.PlayerAdded:Fire(player)
check(character.FishingBackpack:GetAttribute("BackpackId") == "Starter", "Joining equips the starter model")
local initialPack = character.FishingBackpack
revisions:Fire()
check(character.FishingBackpack == initialPack, "Unchanged profile revisions reuse the worn model")
player.CharacterAppearanceLoaded:Fire(character)
check(initialPack.Parent == nil and character.FishingBackpack ~= nil, "Avatar appearance load refreshes the pack")
local remote = ReplicatedStorage:FindFirstChild("BackpackShop")
local function purchase(action, id)
	now += 0.3
	return remote.OnServerInvoke(player, action, id)
end
check(purchase("Get").State.BackpackId == "Starter", "Shop loads saved pack")
root.CFrame = CFrame.new(0, 1000, 0)
check(not purchase("Buy", "Angler").Ok and saves == 0, "Remote purchases require plaza proximity")
root.CFrame = shop.Counter.CFrame
check(not purchase("Buy", {}).Ok and saves == 0, "Malformed upgrade rejected before saving")
profile.Cash = 1
check(not purchase("Buy", "Angler").Ok and saves == 0, "Insufficient cash rejected")
profile.Cash = 20000
failSave = true
check(
	not purchase("Buy", "Angler").Ok and profile.Cash == 20000 and profile.Angler.BackpackId == "Starter",
	"Save failure preserves wallet and pack"
)
failSave = false
check(
	purchase("Buy", "Angler").Ok and profile.Cash == 17500 and profile.Angler.Stats.CoinsSpent == 2500,
	"Upgrade charged once despite save retries"
)
check(#profile.Angler.Backpack == 1 and profile.Angler.Backpack[1].Fish.CaughtAt == 1, "Upgrade preserves packed fish")
check(
	character.FishingBackpack:GetAttribute("BackpackId") == "Angler",
	"Successful purchase immediately updates the worn model"
)
check(not purchase("Buy", "Angler").Ok and not purchase("Buy", "Starter").Ok, "Duplicates and downgrades rejected")
check(purchase("Buy", "Expedition").Ok and profile.Angler.BackpackId == "Expedition", "Can buy a larger pack directly")
local CargoService = (function()
	-- CARGO_SERVICE_SOURCE --
end)()
CargoService.start()
local cargoRemote = ReplicatedStorage:FindFirstChild("Cargo"):FindFirstChild("Request")
local function move(from, to, container)
	now += 0.3
	return cargoRemote.OnServerInvoke(player, "Move", from, to, container)
end
check(move(1, { X = 6, Y = 7, R = 1 }, "Backpack").Ok, "Backpack can be rearranged on land")
check(not move(1, "Hand", "Boat").Ok, "Boat cargo still requires being aboard")
check(not move(1, "Hand", "SomeoneElse").Ok, "Unknown inventory rejected")
check(
	move(1, "Hand", "Backpack").Ok and profile.Angler.Hand ~= nil and #profile.Angler.Backpack == 0,
	"Backpack withdrawal uses real cargo remote"
)
check(move("Hand", { X = 1, Y = 1, R = 0 }, "Backpack").Ok, "Hand fish packs through real cargo remote")
local result = cargoRemote.OnServerInvoke(player, "Get")
check(result.State.BackpackId == "Expedition" and #result.State.Backpack == 1, "Cargo state includes saved backpack")

-- Run actual inventory and storefront UI code, with recording controls.
local function event()
	local listeners = {}
	return {
		Connect = function(_, fn)
			table.insert(listeners, fn)
		end,
		Fire = function(_, ...)
			for _, fn in listeners do
				fn(...)
			end
		end,
	}
end
local UDim = {
	new = function(scale, offset)
		return { Scale = scale, Offset = offset }
	end,
}
UDim2.new = function(xs, xo, ys, yo)
	return { X = UDim.new(xs or 0, xo or 0), Y = UDim.new(ys or 0, yo or 0) }
end
UDim2.fromOffset = function(x, y)
	return UDim2.new(0, x, 0, y)
end
UDim2.fromScale = function(x, y)
	return UDim2.new(x, 0, y, 0)
end
local create = Instance.new
Instance.new = function(class)
	local item = create(class)
	item.Activated = event()
	item.MouseButton2Click = event()
	item.OnClientEvent = event()
	item.Scale = 1
	item.AbsolutePosition = Vector2.zero
	return item
end
instanceMethods.WaitForChild = instanceMethods.FindFirstChild
local playerGui = Instance.new("PlayerGui")
player.WaitForChild = function()
	return playerGui
end
player.GetAttribute = function(_, name)
	return if name == "ActiveBoatId" and aboard then "TestBoat" else nil
end
Players.LocalPlayer = player
local mouse = Vector2.zero
local UserInputService = {
	InputBegan = event(),
	GetMouseLocation = function()
		return mouse
	end,
}
local RunService = { Heartbeat = event(), RenderStepped = event() }
workspace.CurrentCamera = { ViewportSize = Vector2.new(1280, 800) }
local ProximityPromptService = { PromptTriggered = event() }
local Theme = {
	Colors = { Green = Color3.new(0, 1, 0) },
	window = function() end,
	glassPanel = function() end,
	text = function() end,
	button = function() end,
}
local services = {
	Players = Players,
	ReplicatedStorage = ReplicatedStorage,
	RunService = RunService,
	UserInputService = UserInputService,
	ProximityPromptService = ProximityPromptService,
	GuiService = {
		GetGuiInset = function()
			return Vector2.zero
		end,
	},
}
game.GetService = function(_, name)
	return services[name]
end
task.spawn = function(fn)
	fn()
end
task.delay = function() end
cargoRemote.InvokeServer = function(_, ...)
	now += 0.3
	return cargoRemote.OnServerInvoke(player, ...)
end
remote.InvokeServer = function(_, ...)
	now += 0.3
	return remote.OnServerInvoke(player, ...)
end
local cargoUpdate = ReplicatedStorage.Cargo.Update
cargoUpdate.OnClientEvent = event()
Catalog.Rarities = {}
BoatCatalog.TestBoat.Name = "Test boat"
local ClientCargo = (function()
	-- CLIENT_CARGO_SOURCE --
end)()
ClientCargo.start()
local cargoGui = playerGui.Cargo
local panel = cargoGui.CargoPanel
check(cargoGui.OpenCargo.Visible and not panel.Visible, "Backpack button is available on land without opening on join")
cargoGui.OpenCargo.Activated:Fire()
check(panel.Visible, "Backpack opens on land")
local grid = panel.Hold
check(#grid:GetChildren()[3]:GetChildren() == 48, "Backpack UI draws the upgraded mask")
local function buttonWithText(parent, value)
	for _, item in parent:GetDescendants() do
		if item:IsA("TextButton") and item.Text == value then
			return item
		end
	end
	error("Missing button: " .. value)
end
local boatTab = buttonWithText(panel, "Boat · aboard only")
boatTab.Activated:Fire()
check(#grid:GetChildren()[3]:GetChildren() == 48, "Boat tab cannot expose remote boat cargo on land")
-- Click and rotate a packed fish, then submit through the real cargo remote.
local hit = grid:GetChildren()[6]
mouse = Vector2.new(20, 20)
hit.Activated:Fire()
buttonWithText(panel, "Rotate [R]").Activated:Fire()
mouse = Vector2.new(110, 132)
hit.Activated:Fire()
check(
	profile.Angler.Backpack[1].R == 1 and profile.Angler.Backpack[1].X == 3,
	"UI rotation and placement update the saved backpack"
)
aboard = true
cargoUpdate.OnClientEvent:Fire(cargoRemote.OnServerInvoke(player, "Get").State)
now += 1
RunService.Heartbeat:Fire()
buttonWithText(panel, "Boat hold").Activated:Fire()
check(#grid:GetChildren()[3]:GetChildren() == 12, "Boat tab uses its own mask")
buttonWithText(panel, "Backpack").Activated:Fire()
check(
	#grid:GetChildren()[3]:GetChildren() == 48 and #profile.Angler.Backpack == 1,
	"Switching tabs preserves the packed fish"
)
local ClientShop = (function()
	-- CLIENT_SHOP_SOURCE --
end)()
ClientShop.start()
ProximityPromptService.PromptTriggered:Fire(shop.Counter.BrowseBackpacksPrompt, player)
local storeGui = playerGui.BackpackShop
local overlay = storeGui:GetChildren()[1]
check(overlay.Visible, "Plaza prompt opens the backpack store")
check(buttonWithText(overlay, "Equipped").Parent.Name == "Expedition", "Store shows the saved upgrade as equipped")
profile = { Cash = 3000, Angler = Data.decode(packed) }
ProximityPromptService.PromptTriggered:Fire(shop.Counter.BrowseBackpacksPrompt, player)
buttonWithText(overlay, "Buy · $2500").Activated:Fire()
check(profile.Cash == 500 and profile.Angler.BackpackId == "Angler", "Store buy button completes the saved upgrade")
check(buttonWithText(overlay, "Equipped").Parent.Name == "Angler", "Purchase refreshes the equipped store row")
workspace.CurrentCamera.ViewportSize = Vector2.new(390, 700)
RunService.RenderStepped:Fire()
local storeCard = overlay:GetChildren()[1]
local previewCount = 0
for _, item in storeCard:GetDescendants() do
	if item:IsA("ViewportFrame") and item.Name == "ModelPreview" then
		previewCount += 1
		check(item.CurrentCamera ~= nil, "Store models have a framed camera")
	end
end
check(previewCount == 15, "All fifteen backpacks have 3D store previews")
check(storeCard:FindFirstChildOfClass("UIScale").Scale < 1, "Store scales for a phone viewport")
local function avatar(torsoName)
	local rig = Instance.new("Model")
	local hum = Instance.new("Humanoid")
	hum.Name = "Humanoid"
	hum.Health = 100
	hum.RigType = if torsoName == "Torso" then Enum.HumanoidRigType.R6 else Enum.HumanoidRigType.R15
	hum.Parent = rig
	local body = Instance.new("Part")
	body.Name = torsoName
	body.Size = Vector3.new(2, 2, 1)
	body.Parent = rig
	return rig
end
local respawn = avatar("Torso")
player.Character = respawn
player.CharacterAdded:Fire(respawn)
check(
	respawn.FishingBackpack:GetAttribute("BackpackId") == profile.Angler.BackpackId,
	"Respawn restores the saved pack on R6"
)
local savedProfile = profile
profile = nil
local loadingRig = avatar("UpperTorso")
player.Character = loadingRig
player.CharacterAdded:Fire(loadingRig)
check(loadingRig:FindFirstChild("FishingBackpack") == nil, "Appearance waits for profile readiness")
profile = savedProfile
revisions:Fire()
check(
	loadingRig.FishingBackpack:GetAttribute("BackpackId") == profile.Angler.BackpackId,
	"Profile readiness equips the saved pack on R15"
)
player.Character = character
profile = { Cash = 500000, Angler = Data.decode(packed) }
for index, id in Backpacks.Order do
	if index > 1 then
		local before = profile.Cash
		check(
			purchase("Buy", id).Ok and profile.Cash == before - Backpacks.Items[id].Price,
			"Every upgrade charges its configured price"
		)
		check(
			character.FishingBackpack:GetAttribute("BackpackId") == id,
			"Every purchased tier equips its matching model"
		)
		check(
			#profile.Angler.Backpack == 1 and profile.Angler.Backpack[1].Fish.CaughtAt == 1,
			"All fifteen tiers preserve saved fish"
		)
	end
end
cargoUpdate.OnClientEvent:Fire(cargoRemote.OnServerInvoke(player, "Get").State)
workspace.CurrentCamera.ViewportSize = Vector2.new(640, 320)
RunService.RenderStepped:Fire()
local inventoryScale = panel:FindFirstChildOfClass("UIScale").Scale
check(panel.Size.Y.Offset * inventoryScale <= 320 - 48, "Largest backpack grid fits a short landscape viewport")
print(string.format("Backpacks: %d data, grid, purchase, proximity, plaza, and UI checks passed.", checks))
