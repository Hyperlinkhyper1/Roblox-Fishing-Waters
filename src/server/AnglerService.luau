local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local MarketplaceService = game:GetService("MarketplaceService")
local BoatService = require(script.Parent.BoatService)
local Data = require(script.Parent.AnglerData)
local GamepassService = require(script.Parent.GamepassService)
local Aboard = require(ReplicatedStorage.Shared.Aboard)
local BoatCatalog = require(ReplicatedStorage.Shared.BoatCatalog)
local BackpackCatalog = require(ReplicatedStorage.Shared.BackpackCatalog)
local Catalog = require(ReplicatedStorage.Shared.AnglerCatalog)
local FishingRanks = require(ReplicatedStorage.Shared.FishingRanks)
local Paths = require(ReplicatedStorage.Shared.Paths)
local StaffCatalog = require(ReplicatedStorage.Shared.StaffCatalog)
local ShopUpgrades = require(ReplicatedStorage.Shared.ShopUpgrades)
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))
local Service = {}
local started = false
local requests = {}
-- No active codes have been configured yet.
local codes = {}

-- Call only after server gameplay has validated and awarded a catch. Never remote-exposed.
function Service.recordCatch(
	player: Player,
	fishId: string,
	mutation: string,
	kg: number,
	value: number,
	size: string?,
	traits: { NeonColor: string?, Corruptions: { string }? }?
)
	local caughtAt = os.time()
	local ownsAutoStore = GamepassService.ownsAutoStore(player)
	local autoStored = false
	local destination
	local ok, message = BoatService.updateProgress(player, function(profile)
		local emptyHand = profile.Angler.Hand == nil
		local backpackLayout = BackpackCatalog.Items[profile.Angler.BackpackId] or BackpackCatalog.Items.Starter
		profile.Angler, destination = Data.recordCatch(
			profile.Angler,
			fishId,
			mutation,
			kg,
			value,
			caughtAt,
			Catalog.Fish,
			Catalog.Mutations,
			size,
			traits,
			backpackLayout
		)
		autoStored = false
		if ownsAutoStore and emptyHand then
			local boatId, model = BoatService.activeBoat(player)
			local layout = boatId and BoatCatalog[boatId]
			if layout and Aboard(player.Character, model) then
				profile.Angler, autoStored = Data.autoStore(profile.Angler, boatId, layout, Catalog.Fish)
			end
		end
		if autoStored then
			destination = "Boat"
		end
	end)
	return ok, message, ok and autoStored, if ok then destination else nil
end

function Service.start()
	if started then
		return
	end
	started = true
	GamepassService.start()
	MarketplaceService.ProcessReceipt = function(receipt)
		if receipt.ProductId ~= Paths.SKIP_PRODUCT_ID then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		-- Receipts can arrive before profile loading or during another wallet save.
		-- Roblox does not automatically retry on a timer, so retry transient failures here.
		for attempt = 1, 10 do
			if player.Parent ~= Players then
				break
			end
			local ok = BoatService.updateProgress(player, function(current)
				if current.Angler.Paths.SkipReceipts[receipt.PurchaseId] then
					return
				end
				current.Angler = Data.grantPathSkip(current.Angler, receipt.PurchaseId)
				local target = current.Angler.Paths.SkipTarget
				if target and not Paths.skipProblem(current, target) then
					current.Angler = Data.usePathSkip(current.Angler, target)
				else
					-- A delayed/external purchase stays available instead of skipping a different stage.
					current.Angler.Paths.SkipTarget = nil
				end
			end)
			if ok then
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
			task.wait(math.min(attempt, 5))
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local remote = Instance.new("RemoteFunction")
	remote.Name, remote.Parent = "AnglerMenu", ReplicatedStorage
	remote.OnServerInvoke = function(player, action, key, value)
		if os.clock() - (requests[player] or -math.huge) < 0.25 then
			return { Ok = false, Message = "Please wait a moment and try again." }
		end
		requests[player] = os.clock()
		local profile = BoatService.getProfile(player)
		if not profile then
			return { Ok = false, Message = "Your progress is still loading or unavailable." }
		end
		local ok, message = true, ""
		local promptProductId
		if action == "Setting" and type(key) == "string" and Data.validSetting(key, value) then
			ok, message = BoatService.updateProgress(player, function(current)
				current.Angler.Settings[key] = value
			end)
		elseif
			action == "Title"
			and type(key) == "string"
			and (key == "" or (Catalog.Titles[key] and profile.Angler.Titles[key]))
		then
			ok, message = BoatService.updateProgress(player, function(current)
				assert(key == "" or current.Angler.Titles[key], "Title is not unlocked")
				current.Angler.EquippedTitle = key
			end)
		elseif action == "ShopSign" then
			if type(key) ~= "string" or #key > 96 then
				return { Ok = false, Message = "Enter a shop name of up to 32 characters." }
			end
			local name = key:match("^%s*(.-)%s*$")
			local length = utf8.len(name)
			if not length or length > 32 or name:find("[%c]") then
				return { Ok = false, Message = "Enter a shop name of up to 32 characters on one line." }
			end
			local filtered = ""
			if name ~= "" then
				local success, result = pcall(function()
					return TextService:FilterStringAsync(name, player.UserId):GetNonChatStringForBroadcastAsync()
				end)
				if not success or type(result) ~= "string" or #result > 96 then
					return { Ok = false, Message = "Could not filter that name. Please try again." }
				end
				filtered = result
			end
			ok, message = BoatService.updateProgress(player, function(current)
				current.Angler.ShopSign = filtered
			end)
			if ok then
				message = if filtered == "" then "Shop sign reset." else "Shop sign updated."
			end
		elseif action == "HireStaff" then
			local role = if type(key) == "string" then StaffCatalog.Roles[key] else nil
			if not role then
				return { Ok = false, Message = "Choose a staff role from the Staff tab." }
			elseif role.Requires and not Paths.unlocked(profile, role.Requires) then
				return {
					Ok = false,
					Message = "Hiring a " .. role.Name .. " unlocks with " .. Paths.Stages[role.Requires].Name .. ".",
				}
			elseif profile.Angler.Staff[key] then
				return { Ok = false, Message = "You already hired a " .. role.Name .. "." }
			elseif profile.Cash < role.Price then
				return { Ok = false, Message = "You need $" .. role.Price .. " to hire a " .. role.Name .. "." }
			end
			ok, message = BoatService.updateProgress(player, function(current)
				assert(not current.Angler.Staff[key], "Staff already hired")
				assert(current.Cash >= role.Price, "Not enough cash to hire staff")
				current.Cash -= role.Price
				current.Angler.Stats.CoinsSpent += role.Price
				current.Angler.Staff[key] = true
			end)
			if ok then
				message = role.Name .. " hired! They will work at your home base."
				if key == "Fisherman" then
					message ..= " Assign him a boat below."
				end
			end
		elseif action == "BuyShopUpgrade" then
			if key ~= "SocialMediaAdvertisement" then
				return { Ok = false, Message = "Choose a valid shop upgrade." }
			end
			local upgrade = ShopUpgrades.SocialMediaAdvertisement
			if ShopUpgrades.hasAdvertisement(profile.Angler) then
				return { Ok = false, Message = "You already own this upgrade." }
			elseif profile.Cash < upgrade.Price then
				return { Ok = false, Message = "You need $" .. upgrade.Price .. " for this upgrade." }
			end
			ok, message = BoatService.updateProgress(player, function(current)
				assert(not ShopUpgrades.hasAdvertisement(current.Angler), "Upgrade already owned")
				assert(current.Cash >= upgrade.Price, "Not enough cash for this upgrade")
				current.Cash -= upgrade.Price
				current.Angler.Stats.CoinsSpent += upgrade.Price
				current.Angler.Upgrades.SocialMediaAdvertisement = 1
			end)
			if ok then
				message = "Social Media Advertisement unlocked! Customers will arrive more often."
			end
		elseif action == "UpgradePorter" then
			local upgrade = if type(key) == "string" then StaffCatalog.PorterUpgrades[key] else nil
			if not upgrade then
				return { Ok = false, Message = "Choose a porter upgrade from the Workers tab." }
			elseif not profile.Angler.Staff.Porter then
				return { Ok = false, Message = "Hire a porter first." }
			end
			local level = StaffCatalog.porterLevel(profile.Angler, key)
			local price = upgrade.Prices[level + 1]
			if not price then
				return { Ok = false, Message = "Porter " .. upgrade.Name .. " is already at maximum level." }
			elseif value ~= level then
				return { Ok = false, Message = "This upgrade changed. Select the next level again." }
			elseif profile.Cash < price then
				return { Ok = false, Message = "You need $" .. price .. " for this upgrade." }
			end
			ok, message = BoatService.updateProgress(player, function(current)
				assert(current.Angler.Staff.Porter, "Hire a porter first")
				assert(StaffCatalog.porterLevel(current.Angler, key) == level, "Upgrade level changed")
				assert(current.Cash >= price, "Not enough cash for this upgrade")
				current.Cash -= price
				current.Angler.Stats.CoinsSpent += price
				current.Angler.Upgrades[key] = level + 1
			end)
			if ok then
				message =
					string.format("Porter %s upgraded to %d %s!", upgrade.Name, upgrade.Values[level + 2], upgrade.Unit)
			end
		elseif action == "PreparePathSkip" then
			local problem = Paths.skipProblem(profile, key)
			if problem then
				return { Ok = false, Message = problem }
			end
			local usedCredit = false
			ok, message = BoatService.updateProgress(player, function(current)
				local failure = Paths.skipProblem(current, key)
				assert(not failure, failure)
				usedCredit = current.Angler.Paths.SkipCredits > 0
				if usedCredit then
					current.Angler = Data.usePathSkip(current.Angler, key)
				else
					-- Persist the intended stage before opening the Roblox purchase prompt.
					current.Angler.Paths.SkipTarget = key
				end
			end)
			if ok then
				promptProductId = if usedCredit then nil else Paths.SKIP_PRODUCT_ID
				message = (if usedCredit then "Quests skipped! " else "") .. Paths.skipWarning(profile)
			end
		elseif action == "ChoosePath" then
			local problem = Paths.chooseProblem(profile, key)
			if problem then
				return { Ok = false, Message = problem }
			end
			local stage = Paths.Stages[key]
			ok, message = BoatService.updateProgress(player, function(current)
				local failure = Paths.chooseProblem(current, key)
				assert(not failure, failure)
				current.Cash -= stage.Price
				current.Angler.Stats.CoinsSpent += stage.Price
				current.Angler = Data.choosePath(current.Angler, key, stage)
			end)
			if ok then
				message = stage.Name .. " is open! Check the Paths tab for your new goals."
			end
		elseif action == "AssignBoat" then
			local spec = if type(key) == "string" then BoatCatalog[key] else nil
			if not profile.Angler.Staff.Fisherman then
				return { Ok = false, Message = "Hire a fisherman first." }
			elseif not spec or not profile.OwnedBoats[key] then
				return { Ok = false, Message = "Choose one of your own boats." }
			elseif profile.Angler.FishermanBoat == key then
				return { Ok = false, Message = "Your fisherman already sails the " .. spec.Name .. "." }
			end
			local activeId = BoatService.activeBoat(player)
			if activeId == key and not BoatService.stowBoat(player, key) then
				return { Ok = false, Message = "Everyone must leave your " .. spec.Name .. " before he can take it." }
			end
			ok, message = BoatService.updateProgress(player, function(current)
				assert(current.OwnedBoats[key] and current.Angler.Staff.Fisherman, "Boat is not available")
				current.Angler.FishermanBoat = key
			end)
			if ok then
				message = "Your fisherman takes the " .. spec.Name .. " out from your dock."
			end
		elseif action == "Code" then
			if type(key) ~= "string" or #key > 64 then
				return { Ok = false, Message = "Enter a valid code." }
			end
			local code = string.upper(key:match("^%s*(.-)%s*$"))
			local reward = codes[code]
			if not reward then
				return { Ok = false, Message = "This code is not active." }
			end
			if profile.Angler.RedeemedCodes[code] then
				return { Ok = false, Message = "You already redeemed this code." }
			end
			ok, message = BoatService.updateProgress(player, function(current)
				assert(not current.Angler.RedeemedCodes[code], "Code already redeemed")
				current.Angler.RedeemedCodes[code] = true
				current.Cash += reward
				current.Angler.Stats.CoinsEarned += reward
			end)
		elseif action ~= "Get" then
			return { Ok = false, Message = "That menu action is unavailable." }
		end
		local current = BoatService.getProfile(player)
		return {
			Ok = ok,
			Message = message,
			PromptProductId = promptProductId,
			Profile = current,
			FreezerUsage = if current then Data.freezerUsage(current.Angler) else 0,
			PantryCapacity = if current then Data.pantryCapacity(current.Angler) else 0,
		}
	end
	local function bind(player)
		local function updateTitle()
			local character = player.Character
			local head = character and character:FindFirstChild("Head")
			if not head then
				return
			end
			local current = BoatService.getProfile(player)
			local title = current and Catalog.Titles[current.Angler.EquippedTitle]
			local level = math.max(0, math.floor(player:GetAttribute("Level") or 0))
			local rank = FishingRanks.forLevel(level)
			local billboard = head:FindFirstChild("AnglerTitle")
			if not billboard then
				billboard = Instance.new("BillboardGui")
				billboard.Name, billboard.Size = "AnglerTitle", UDim2.fromOffset(360, 84)
				billboard.StudsOffset, billboard.MaxDistance = Vector3.new(0, 2.5, 0), 80
				billboard.Adornee = head
				for _, row in { { "Title", 0, 24 }, { "Rank", 24, 30 }, { "PlayerName", 54, 30 } } do
					local label = Instance.new("TextLabel")
					label.Name = row[1]
					label.Position, label.Size = UDim2.fromOffset(0, row[2]), UDim2.new(1, 0, 0, row[3])
					label.BackgroundTransparency = 1
					label.Font = if row[1] == "Rank" then Enum.Font.SourceSansBold else Enum.Font.SourceSans
					label.TextSize, label.TextColor3 = 24, Color3.new(1, 1, 1)
					label.TextStrokeColor3, label.TextStrokeTransparency = Color3.new(0, 0, 0), 0
					label.Parent = billboard
				end
				local titleLabel = billboard.Title
				titleLabel.Font, titleLabel.TextSize = Enum.Font.GothamBold, 15
				Theme.text(titleLabel)
				billboard.Parent = head
			end
			billboard.Rank.Text = string.format("[%d] %s", level, rank.Name)
			billboard.Rank.TextColor3 = rank.Color
			billboard.PlayerName.Text = player.DisplayName
			local hasTitle = title ~= nil and current.Angler.Titles[current.Angler.EquippedTitle] == true
			billboard.Title.Visible = hasTitle
			billboard.Title.Text = if hasTitle then title.Name else ""
		end
		player:GetAttributeChangedSignal("AnglerRevision"):Connect(updateTitle)
		player:GetAttributeChangedSignal("Level"):Connect(updateTitle)
		player:GetPropertyChangedSignal("DisplayName"):Connect(updateTitle)
		local function characterAdded(character)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if not humanoid then
				return
			end
			character:WaitForChild("Head", 10)
			if player.Character ~= character then
				return
			end
			-- The custom name row replaces Roblox's default overhead display.
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			updateTitle()
			humanoid.Died:Once(function()
				-- Retry a concurrent purchase without discarding a death or resetting saved progress.
				for attempt = 1, 4 do
					if player.Parent ~= Players then
						return
					end
					local ok = BoatService.updateProgress(player, function(current)
						current.Angler.Stats.Deaths += 1
						current.Angler.Stats.CatchStreak = 0
					end)
					if ok then
						return
					end
					task.wait(attempt)
				end
			end)
		end
		player.CharacterAdded:Connect(characterAdded)
		if player.Character then
			task.spawn(characterAdded, player.Character)
		end
	end
	Players.PlayerAdded:Connect(bind)
	Players.PlayerRemoving:Connect(function(player)
		requests[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(bind, player)
	end
end
return Service
