-- The Restaurant path. Unlocking it builds a dining room onto the back of the
-- owner's house; dining tables are placed there from build mode. Diners walk in,
-- take a free seat and order one specific dish. Serving it takes that dish off the
-- kitchen pass and pays the restaurant markup, in one profile update.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnglerData = require(script.Parent.AnglerData)
local BoatService = require(script.Parent.BoatService)
local CustomerService = require(script.Parent.CustomerService)
local DiningRoom = require(script.Parent.Map.DiningRoom)
local Kitchen = require(script.Parent.Map.Kitchen)
local Furniture = require(ReplicatedStorage.Shared.FurnitureCatalog)
local Paths = require(ReplicatedStorage.Shared.Paths)
local Recipes = require(ReplicatedStorage.Shared.Recipes)

local RestaurantService = {}
local BASE_TAG = "PlayerBase"
local WAIT_SECONDS = 150
local EAT_SECONDS = 8
local SERVE_DISTANCE = 14
local ARRIVAL_SECONDS = Vector2.new(8, 18)
-- Most diners ask for something already on the pass; the rest for anything your
-- stations can make, so a full menu pays off.
local AVAILABLE_ORDER_CHANCE = 0.7
-- Diners walk in from the street along the west side of the house (house-local).
local STREET = Vector3.new(-26.5, 0.16, 12)

local npc = CustomerService.npc
local random = Random.new()
local started = false
local restaurants: { [Model]: any } = {}
local diners: { [ProximityPrompt]: any } = {}

local function profileOf(base: Model)
	local owner = npc.ownerOf(base)
	return owner, owner and BoatService.getProfile(owner)
end

local function open(profile): boolean
	return profile ~= nil and Paths.unlocked(profile, "Restaurant")
end

-- The dining room exists only while its owner runs a restaurant.
local function syncRoom(restaurant)
	local base = restaurant.base
	local house = base:FindFirstChild("BaseHouse")
	local frame = npc.houseFrame(base)
	if not house or not frame then
		return
	end
	local owner, profile = profileOf(base)
	local room = house:FindFirstChild("Dining")
	local wanted = open(profile)
	if room and (not wanted or room:GetAttribute("LayoutVersion") ~= DiningRoom.VERSION) then
		room:Destroy()
		room = nil
	end
	if wanted and not room and owner then
		DiningRoom.build(house, frame)
	end
end

local function at(restaurant, position: Vector3): Vector3
	return (restaurant.frame * CFrame.new(position)).Position
end

-- Free diner seats at the owner's placed tables, with each table's floor frame.
local function freeSeats(restaurant): { { seat: Seat, table: CFrame } }
	local house = restaurant.base:FindFirstChild("BaseHouse")
	local placed = house and house:FindFirstChild("Furniture")
	local result = {}
	for _, model in if placed then placed:GetChildren() else {} do
		if model:GetAttribute("ItemId") ~= "DiningTable" then
			continue
		end
		local tableFrame = Furniture.frame(restaurant.frame, {
			X = model:GetAttribute("X"),
			Z = model:GetAttribute("Z"),
			R = model:GetAttribute("R"),
		})
		for _, child in model:GetChildren() do
			if child:IsA("Seat") and not child.Occupant and not restaurant.seated[child] then
				table.insert(result, { seat = child, table = tableFrame })
			end
		end
	end
	return result
end

-- The best matching dish on the pass for an order, or nil.
local function dishFor(profile, recipeId: string)
	local best
	for _, dish in profile.Angler.Pantry do
		if dish.RecipeId == recipeId and (not best or dish.Value > best.Value) then
			best = dish
		end
	end
	return best
end

-- Recipes the owner can make: the prep bench's, plus each placed station's.
local function menu(profile): { string }
	local stations = { Prep = true }
	for _, entry in profile.Angler.Furniture do
		if Recipes.Stations[entry.ItemId] then
			stations[entry.ItemId] = true
		end
	end
	local result = {}
	for _, id in Recipes.Order do
		if stations[Recipes.Items[id].Station] then
			table.insert(result, id)
		end
	end
	return result
end

local function chooseOrder(profile): string
	local available = {}
	for _, dish in profile.Angler.Pantry do
		if not table.find(available, dish.RecipeId) then
			table.insert(available, dish.RecipeId)
		end
	end
	if #available > 0 and random:NextNumber() < AVAILABLE_ORDER_CHANCE then
		return available[random:NextInteger(1, #available)]
	end
	local options = menu(profile)
	return options[random:NextInteger(1, #options)]
end

local function updatePrompt(diner, profile)
	local prompt = diner.prompt
	if not prompt then
		return
	end
	local recipe = Recipes.Items[diner.order]
	local dish = profile and dishFor(profile, diner.order)
	prompt.ActionText = "Serve " .. string.lower(recipe.Name)
	prompt.ObjectText = if dish
		then string.format("Diner · $%d", Recipes.dinerPrice(dish.Value))
		else "Cook " .. string.lower(recipe.Name) .. " first"
end

local function release(diner)
	if diner.leaving then
		return
	end
	diner.leaving = true
	if diner.prompt then
		diners[diner.prompt] = nil
		diner.prompt:Destroy()
		diner.prompt = nil
	end
end

local function finish(restaurant, diner)
	diner.active = false
	release(diner)
	if diner.seat then
		restaurant.seated[diner.seat] = nil
	end
	for _, item in { diner.plate, diner.model } do
		if item then
			item:Destroy()
		end
	end
	local index = table.find(restaurant.diners, diner)
	if index then
		table.remove(restaurant.diners, index)
	end
end

local function stand(diner)
	local humanoid = diner.humanoid
	if humanoid and humanoid.Parent then
		humanoid.Sit = false
		humanoid.Jump = true
	end
end

local function visit(restaurant, diner)
	local base = restaurant.base
	diner.model = npc.spawn(at(restaurant, STREET))
	diner.humanoid = diner.model:FindFirstChildOfClass("Humanoid")
	diner.root = diner.model:FindFirstChild("HumanoidRootPart")
	diner.humanoid.Died:Once(function()
		diner.active = false
	end)
	local recipe = Recipes.Items[diner.order]
	npc.bubble(diner, "A table for one, please")
	local function going(position: Vector3): boolean
		return npc.walk(diner, position, function()
			return not diner.leaving
		end)
	end
	local seat = diner.seat :: Seat
	local beside = (seat.CFrame * CFrame.new(1.6, -seat.Size.Y / 2 - 1.4, 0)).Position
	local entered = going(at(restaurant, DiningRoom.ARRIVAL))
		and going(at(restaurant, DiningRoom.INSIDE))
	if not diner.active or diner.leaving then
		return
	end
	-- Squeezing between tables can defeat pathfinding; step up to the chair instead.
	if not (entered and going(beside)) then
		diner.model:PivotTo(CFrame.new(beside + Vector3.new(0, 3, 0)))
	end
	if not diner.active or diner.leaving or seat.Occupant then
		return
	end
	seat:Sit(diner.humanoid)
	task.wait(0.6)
	local owner = npc.ownerOf(base)
	npc.bubble(diner, "I'd like the " .. string.lower(recipe.Name) .. ", please")
	local prompt = npc.ownerPrompt(diner.root, "ServeDinerPrompt", "Serve", recipe.Name)
	prompt:SetAttribute("OwnerUserId", base:GetAttribute("OwnerUserId"))
	prompt.MaxActivationDistance = 8
	diner.prompt = prompt
	diners[prompt] = diner
	updatePrompt(diner, owner and BoatService.getProfile(owner))
	npc.notify(owner, "A diner in your restaurant ordered " .. string.lower(recipe.Name) .. ".")
	local deadline = os.clock() + WAIT_SECONDS
	while diner.active and not diner.leaving and not diner.served and os.clock() < deadline do
		task.wait(0.5)
	end
	if not diner.active then
		return
	end
	if diner.served then
		npc.bubble(diner, "Mmm…")
		task.wait(EAT_SECONDS)
		npc.bubble(diner, "Delicious, thank you!")
		if diner.plate then
			diner.plate:Destroy()
			diner.plate = nil
		end
	else
		release(diner)
		npc.bubble(diner, "I'll come back another day…")
	end
	task.wait(1)
	stand(diner)
	restaurant.seated[seat] = nil
	task.wait(0.4)
	for _, position in { DiningRoom.INSIDE, DiningRoom.ARRIVAL, STREET } do
		if not npc.walk(diner, at(restaurant, position)) then
			return
		end
	end
end

local function serve(player: Player, diner)
	local restaurant = diner.restaurant
	local function authorized(): boolean
		return npc.ownerOf(restaurant.base) == player
			and diner.active
			and not diner.leaving
			and not diner.served
			and npc.near(player, diner.root.Position, SERVE_DISTANCE)
	end
	local profile = BoatService.getProfile(player)
	if diner.serving or not profile or not authorized() then
		return
	end
	local dish = dishFor(profile, diner.order)
	local recipe = Recipes.Items[diner.order]
	if not dish then
		npc.notify(player, "Cook " .. string.lower(recipe.Name) .. " in your kitchen first. This diner wants nothing else.")
		return
	end
	diner.serving = true
	local price = 0
	local ok, message = BoatService.updateProgress(player, function(current)
		assert(authorized(), "This diner can no longer be served.")
		local chosen = dishFor(current, diner.order)
		assert(chosen, "That dish is no longer on your kitchen pass.")
		local data, paid = AnglerData.sellDish(current.Angler, chosen, Recipes.RESTAURANT_MARKUP, "DinersServed")
		assert(data, "That dish is no longer on your kitchen pass.")
		current.Angler = data
		current.Cash += paid
		price = paid
	end)
	diner.serving = false
	if not ok then
		npc.notify(player, message)
		return
	end
	diner.served = true
	release(diner)
	local seat = diner.seat
	local offset = seat and seat:GetAttribute("PlateOffset")
	if seat and diner.table and typeof(offset) == "Vector3" then
		local plate = Kitchen.buildDish(diner.order, recipe.Look, diner.table * CFrame.new(offset))
		plate.Name = "ServedDish"
		plate.Parent = workspace:FindFirstChild("ShopCustomers") or workspace
		diner.plate = plate
	end
	npc.notify(player, string.format("Served %s for $%d.", string.lower(recipe.Name), price))
end

local function arrive(restaurant)
	local _, profile = profileOf(restaurant.base)
	if not open(profile) then
		return
	end
	local seats = freeSeats(restaurant)
	if #seats == 0 then
		return
	end
	local choice = seats[random:NextInteger(1, #seats)]
	local diner = {
		restaurant = restaurant,
		order = chooseOrder(profile),
		seat = choice.seat,
		table = choice.table,
		active = true,
	}
	restaurant.seated[choice.seat] = diner
	table.insert(restaurant.diners, diner)
	restaurant.nextArrival = os.clock() + random:NextNumber(ARRIVAL_SECONDS.X, ARRIVAL_SECONDS.Y)
	task.spawn(function()
		local ok, failure = pcall(visit, restaurant, diner)
		if not ok then
			warn("[Restaurant] " .. tostring(failure))
		end
		finish(restaurant, diner)
	end)
end

local function register(base: Instance)
	if not base:IsA("Model") or restaurants[base] then
		return
	end
	local frame = npc.houseFrame(base)
	if not frame then
		return
	end
	local restaurant = {
		base = base,
		frame = frame,
		diners = {},
		seated = {},
		nextArrival = os.clock() + random:NextNumber(4, 10),
	}
	restaurants[base] = restaurant
	base:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		-- A new owner never inherits the previous owner's diners or room.
		for _, diner in restaurant.diners do
			release(diner)
			stand(diner)
		end
		syncRoom(restaurant)
		restaurant.nextArrival = os.clock() + random:NextNumber(4, 10)
	end)
	syncRoom(restaurant)
end

function RestaurantService.start()
	if started then
		return
	end
	started = true
	for _, base in CollectionService:GetTagged(BASE_TAG) do
		register(base)
	end
	CollectionService:GetInstanceAddedSignal(BASE_TAG):Connect(register)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local diner = prompt.Name == "ServeDinerPrompt" and diners[prompt]
		if diner then
			task.spawn(serve, player, diner)
		end
	end)
	local function watch(player: Player)
		player:GetAttributeChangedSignal("AnglerRevision"):Connect(function()
			for _, restaurant in restaurants do
				if npc.ownerOf(restaurant.base) == player then
					syncRoom(restaurant)
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	task.spawn(function()
		while true do
			task.wait(1)
			for _, restaurant in restaurants do
				local owner, profile = profileOf(restaurant.base)
				if not open(profile) then
					for _, diner in restaurant.diners do
						release(diner)
					end
					continue
				end
				for _, diner in restaurant.diners do
					updatePrompt(diner, profile)
				end
				if owner and os.clock() >= restaurant.nextArrival then
					arrive(restaurant)
				end
			end
		end
	end)
end

return RestaurantService
