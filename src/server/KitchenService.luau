-- The Supermarket path's kitchen. Two prep benches stand in every unlocked
-- processing room; grill, smokehouse and sushi stations are bought furniture. The
-- owner carries a fish to a station, picks a recipe (client Kitchen picker) and the
-- dish cooks on a timer. The job is saved on the station the moment cooking starts,
-- so a rejoin never loses the fish; "Collect" moves the dish onto the kitchen pass.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnglerData = require(script.Parent.AnglerData)
local BoatService = require(script.Parent.BoatService)
local CargoService = require(script.Parent.CargoService)
local Kitchen = require(script.Parent.Map.Kitchen)
local Catalog = require(ReplicatedStorage.Shared.AnglerCatalog)
local FishModels = require(ReplicatedStorage.Shared.FishModels)
local Furniture = require(ReplicatedStorage.Shared.FurnitureCatalog)
local Paths = require(ReplicatedStorage.Shared.Paths)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))

local KitchenService = {}
local BASE_TAG = "PlayerBase"
local OWNER_PROMPT_TAG = "ShopOwnerPrompt"
local started = false
local update: RemoteEvent
local requests: { [Player]: number } = {}
local busy: { [Player]: boolean } = {}

local function ownerOf(base: Model): Player?
	local userId = base:GetAttribute("OwnerUserId")
	return if type(userId) == "number" and userId ~= 0 then Players:GetPlayerByUserId(userId) else nil
end

local function houseOf(base: Model): (Model?, CFrame?)
	local house = base:FindFirstChild("BaseHouse")
	local frame = house and house:GetAttribute("HouseFrame")
	if house and house:IsA("Model") and typeof(frame) == "CFrame" then
		return house, frame
	end
	return nil, nil
end

local function baseOf(player: Player): Model?
	for _, base in CollectionService:GetTagged(BASE_TAG) do
		if base:GetAttribute("OwnerUserId") == player.UserId then
			return base
		end
	end
	return nil
end

local function notify(player: Player, message: string)
	if player.Parent == Players then
		update:FireClient(player, "Notice", message)
	end
end

local function near(player: Player, position: Vector3, distance: number): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return humanoid ~= nil
		and humanoid.Health > 0
		and root ~= nil
		and root:IsA("BasePart")
		and (root.Position - position).Magnitude <= distance
end

local function prompt(parent: Instance, name: string, action: string, object: string, userId: number): ProximityPrompt
	local result = Instance.new("ProximityPrompt")
	result.Name = name
	result.ActionText = action
	result.ObjectText = object
	result.HoldDuration = 0.25
	result.MaxActivationDistance = 6
	result.RequiresLineOfSight = false
	result.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	result:SetAttribute("OwnerUserId", userId)
	CollectionService:AddTag(result, OWNER_PROMPT_TAG)
	result.Parent = parent
	return result
end

-- Cook and Collect prompts plus a status label above the worktop. `key` is the
-- built-in bench key or the station's furniture id.
function KitchenService.addPrompts(model: Model, frame: CFrame, key: string, userId: number)
	local anchor = Instance.new("Part")
	anchor.Name = "KitchenPromptAnchor"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency, anchor.Anchored = 1, true
	anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = false, false, false
	anchor.CFrame = frame * CFrame.new(0, Kitchen.TOP + 0.8, Kitchen.DEPTH / 2 + 0.3)
	anchor.Parent = model
	local name = Recipes.Stations[Recipes.stationOf(key) or ""].Name
	prompt(anchor, "CookPrompt", "Cook", name, userId):SetAttribute("StationKey", key)
	local collect = prompt(anchor, "CollectDishPrompt", "Collect dish", name, userId)
	collect:SetAttribute("StationKey", key)
	-- Owners' clients show a prompt only while it is Available (see ShopCustomers).
	collect:SetAttribute("Available", false)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "KitchenStatus"
	billboard.Size = UDim2.fromOffset(240, 32)
	billboard.StudsOffset = Vector3.new(0, 2.2, -0.6)
	billboard.MaxDistance = 45
	billboard.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Name = "Status"
	label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	label.Font, label.TextSize, label.Text = Enum.Font.GothamBold, 15, ""
	Theme.text(label)
	label.Parent = billboard
	model:SetAttribute("StationKey", key)
end

-- Every station in the owner's house, keyed like the saved kitchen jobs.
local function stations(house: Model, houseFrame: CFrame): { [string]: { model: Model, frame: CFrame } }
	local result = {}
	local benches = house:FindFirstChild("Processing") and house.Processing:FindFirstChild("KitchenBenches")
	for key, bench in Recipes.BuiltIn do
		local model = benches and benches:FindFirstChild(key)
		if model then
			result[key] = { model = model, frame = Furniture.frame(houseFrame, bench) }
		end
	end
	local placed = house:FindFirstChild("Furniture")
	for _, model in if placed then placed:GetChildren() else {} do
		local key = model:GetAttribute("StationKey")
		if type(key) == "string" and model:IsA("Model") then
			result[key] = {
				model = model,
				frame = Furniture.frame(houseFrame, {
					X = model:GetAttribute("X"),
					Z = model:GetAttribute("Z"),
					R = model:GetAttribute("R"),
				}),
			}
		end
	end
	return result
end

-- The built-in prep benches appear once the owner has opened the Supermarket.
local function syncBenches(base: Model)
	local house, houseFrame = houseOf(base)
	local processing = house and house:FindFirstChild("Processing")
	if not processing or not houseFrame then
		return
	end
	local owner = ownerOf(base)
	local profile = owner and BoatService.getProfile(owner)
	local wanted = profile ~= nil and Paths.unlocked(profile, "Supermarket")
	local benches = processing:FindFirstChild("KitchenBenches")
	if benches and (not wanted or benches:GetAttribute("OwnerUserId") ~= owner.UserId) then
		benches:Destroy()
		benches = nil
	end
	if wanted and not benches and owner then
		benches = Instance.new("Model")
		benches.Name = "KitchenBenches"
		benches:SetAttribute("OwnerUserId", owner.UserId)
		for key, bench in Recipes.BuiltIn do
			local frame = Furniture.frame(houseFrame, bench)
			local model = Kitchen.buildStation(benches, frame, bench.Station)
			model.Name = key
			KitchenService.addPrompts(model, frame, key, owner.UserId)
		end
		benches.Parent = processing
	end
end

-- A small model of the raw fish lying on the worktop while it cooks.
local function rawFish(dish, frame: CFrame): Model?
	local model = FishModels.create(dish.FishId, dish)
	if not model then
		return nil
	end
	FishModels.scaleCatch(model, dish.Kg)
	local _, size = model:GetBoundingBox()
	local longest = math.max(size.X, size.Y, size.Z)
	if longest > 2.2 then
		model:ScaleTo(model:GetScale() * 2.2 / longest)
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
		end
	end
	model:PivotTo(frame * CFrame.Angles(math.pi / 2, 0, 0))
	local _, lifted = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + frame.UpVector * (lifted.Y / 2))
	return model
end

local function formatSeconds(seconds: number): string
	return if seconds >= 60 then string.format("%d:%02d", seconds // 60, seconds % 60) else seconds .. "s"
end

-- Prompts, the status label and the food on the worktop follow the saved job.
local function refreshStation(station, job, now: number)
	local model = station.model
	local anchor = model:FindFirstChild("KitchenPromptAnchor")
	if not anchor then
		return
	end
	local cook = anchor:FindFirstChild("CookPrompt") :: ProximityPrompt?
	local collect = anchor:FindFirstChild("CollectDishPrompt") :: ProximityPrompt?
	local billboard = anchor:FindFirstChild("KitchenStatus")
	local label = billboard and billboard:FindFirstChild("Status") :: TextLabel?
	local recipe = job and Recipes.Items[job.Dish.RecipeId]
	local ready = job ~= nil and now >= job.ReadyAt
	if cook then
		cook:SetAttribute("Available", job == nil)
	end
	if collect then
		collect:SetAttribute("Available", ready)
		collect.ObjectText = if recipe then recipe.Name else "Dish"
	end
	if label then
		label.Text = if not job
			then ""
			elseif ready then (if recipe then recipe.Name else "Dish") .. " is ready!"
			else string.format("Cooking %s · %s", if recipe then string.lower(recipe.Name) else "dish", formatSeconds(job.ReadyAt - now))
	end
	local signature = if job then string.format("%s|%d|%s", job.Dish.RecipeId, job.Dish.MadeAt, tostring(ready)) else ""
	if model:GetAttribute("FoodSignature") == signature then
		return
	end
	model:SetAttribute("FoodSignature", signature)
	local previous = model:FindFirstChild("StationFood")
	if previous then
		previous:Destroy()
	end
	if not job then
		return
	end
	local spot = station.frame * Kitchen.WORK_SPOT
	local food = if ready and recipe
		then Kitchen.buildDish(job.Dish.RecipeId, recipe.Look, spot)
		else rawFish(job.Dish, spot)
	if not food then
		return
	end
	food.Name = "StationFood"
	if not ready then
		local steam = Instance.new("ParticleEmitter")
		steam.Name = "Steam"
		steam.Color = ColorSequence.new(Color3.fromRGB(235, 235, 230))
		steam.Transparency = NumberSequence.new(0.55, 1)
		steam.Size = NumberSequence.new(0.3, 1.2)
		steam.Lifetime = NumberRange.new(1, 1.8)
		steam.Rate = 6
		steam.Speed = NumberRange.new(1, 2)
		local emitter = food:FindFirstChildWhichIsA("BasePart", true)
		if emitter then
			steam.Parent = emitter
		end
	end
	food.Parent = model
end

local function refreshBase(base: Model)
	local house, houseFrame = houseOf(base)
	if not house or not houseFrame then
		return
	end
	local owner = ownerOf(base)
	local profile = owner and BoatService.getProfile(owner)
	local now = os.time()
	for key, station in stations(house, houseFrame) do
		refreshStation(station, if profile then profile.Angler.Kitchen[key] else nil, now)
	end
end

local function stationNear(player: Player, key: any): boolean
	local base = baseOf(player)
	local house, houseFrame = if base then houseOf(base) else nil
	if type(key) ~= "string" or not house or not houseFrame then
		return false
	end
	local station = stations(house, houseFrame)[key]
	local anchor = station and station.model:FindFirstChild("KitchenPromptAnchor")
	return anchor ~= nil and near(player, anchor.Position, 8)
end

local function transact(player: Player, transform): (boolean, string)
	if busy[player] then
		return false, "Please wait a moment and try again."
	end
	busy[player] = true
	local ok, message = BoatService.updateProgress(player, transform)
	busy[player] = nil
	local base = baseOf(player)
	if ok and base then
		refreshBase(base)
	end
	return ok, message
end

-- Recipes this station can make, and whether the carried fish qualifies for each.
local function options(player: Player, key: string)
	local profile = BoatService.getProfile(player)
	local station = Recipes.stationOf(key)
	if not profile or not station then
		return nil
	end
	local hand = profile.Angler.Hand
	local fish = hand and Catalog.Fish[hand.FishId]
	local list = {}
	for _, id in Recipes.Order do
		local recipe = Recipes.Items[id]
		if recipe.Station == station then
			table.insert(list, {
				Id = id,
				Name = recipe.Name,
				MinRarity = recipe.MinRarity,
				Seconds = recipe.Seconds,
				Value = if hand then Recipes.value(id, hand.Value) else nil,
				Problem = if not hand then "Carry a fish here first." else Recipes.problem(id, station, fish and fish.Rarity),
			})
		end
	end
	return {
		Station = Recipes.Stations[station].Name,
		Fish = if hand then (if fish then fish.Name else hand.FishId) else nil,
		Rarity = fish and fish.Rarity,
		FishValue = hand and math.floor(hand.Value),
		Recipes = list,
		Pantry = #profile.Angler.Pantry,
		PantryCapacity = AnglerData.pantryCapacity(profile.Angler),
	}
end

local function cook(player: Player, key: any, recipeId: any): (boolean, string)
	if not stationNear(player, key) then
		return false, "Walk up to the station to cook."
	end
	local profile = BoatService.getProfile(player)
	if not profile then
		return false, "Your progress is still loading. Try again in a moment."
	elseif not CargoService.isCarrying(player, profile.Angler.Hand) then
		return false, "Equip a fish from your hotbar and carry it to the station."
	end
	local now = os.time()
	local _, reason = AnglerData.startCooking(profile.Angler, key, recipeId, Catalog.Fish, now)
	if reason then
		return false, reason
	end
	local ok, message = transact(player, function(current)
		assert(CargoService.isCarrying(player, current.Angler.Hand), "Carry the fish to the station.")
		local data, failure = AnglerData.startCooking(current.Angler, key, recipeId, Catalog.Fish, now)
		assert(data, failure)
		current.Angler = data
	end)
	if ok then
		local recipe = Recipes.Items[recipeId]
		message = string.format("Cooking %s. It's ready in %s.", string.lower(recipe.Name), formatSeconds(recipe.Seconds))
	end
	return ok, message
end

local function collect(player: Player, key: any)
	if not stationNear(player, key) then
		return
	end
	local profile = BoatService.getProfile(player)
	if not profile then
		return
	end
	local _, reason = AnglerData.collectDish(profile.Angler, key, os.time())
	if reason then
		notify(player, reason)
		return
	end
	local job = profile.Angler.Kitchen[key]
	local ok, message = transact(player, function(current)
		local data, failure = AnglerData.collectDish(current.Angler, key, os.time())
		assert(data, failure)
		current.Angler = data
	end)
	notify(
		player,
		if ok
			then string.format(
				"%s is on the kitchen pass ($%d). Customers can buy it now.",
				Recipes.Items[job.Dish.RecipeId].Name,
				job.Dish.Value
			)
			else message
	)
end

function KitchenService.start()
	if started then
		return
	end
	started = true
	local remotes = Instance.new("Folder")
	remotes.Name = "Kitchen"
	local request = Instance.new("RemoteFunction")
	request.Name, request.Parent = "Request", remotes
	update = Instance.new("RemoteEvent")
	update.Name, update.Parent = "Update", remotes
	remotes.Parent = ReplicatedStorage
	request.OnServerInvoke = function(player, action, key, recipeId)
		if os.clock() - (requests[player] or -math.huge) < 0.25 then
			return { Ok = false, Message = "Please wait a moment and try again." }
		end
		requests[player] = os.clock()
		if type(key) ~= "string" or not Recipes.stationOf(key) then
			return { Ok = false, Message = "That isn't a kitchen station." }
		elseif action == "Options" then
			return { Ok = true, Message = "", Options = options(player, key) }
		elseif action == "Cook" then
			local ok, message = cook(player, key, recipeId)
			return { Ok = ok, Message = message, Options = options(player, key) }
		end
		return { Ok = false, Message = "That kitchen action is unavailable." }
	end
	ProximityPromptService.PromptTriggered:Connect(function(triggered, player)
		if triggered.Name == "CollectDishPrompt" then
			task.spawn(collect, player, triggered:GetAttribute("StationKey"))
		end
	end)
	local function watchPlayer(player: Player)
		player:GetAttributeChangedSignal("AnglerRevision"):Connect(function()
			local base = baseOf(player)
			if base then
				syncBenches(base)
				refreshBase(base)
			end
		end)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		requests[player], busy[player] = nil, nil
	end)
	local function watchBase(base: Instance)
		if base:IsA("Model") then
			base:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
				syncBenches(base)
			end)
			syncBenches(base)
		end
	end
	CollectionService:GetInstanceAddedSignal(BASE_TAG):Connect(watchBase)
	for _, base in CollectionService:GetTagged(BASE_TAG) do
		watchBase(base)
	end
	-- Countdowns tick once a second.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, base in CollectionService:GetTagged(BASE_TAG) do
				if base:IsA("Model") and ownerOf(base) then
					local ok, failure = pcall(refreshBase, base)
					if not ok then
						warn("[Kitchen] " .. tostring(failure))
					end
				end
			end
		end
	end)
end

return KitchenService
