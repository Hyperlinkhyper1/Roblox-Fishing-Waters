-- Hired chefs work independently at the owner's existing kitchen stations. Fish,
-- station jobs and finished dishes are moved together through the saved profile.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnglerData = require(script.Parent.AnglerData)
local BoatService = require(script.Parent.BoatService)
local CompanyIslandAccess = require(script.Parent.CompanyIslandAccess)
local CustomerService = require(script.Parent.CustomerService)
local Kitchen = require(script.Parent.Map.Kitchen)
local Catalog = require(ReplicatedStorage.Shared.AnglerCatalog)
local Furniture = require(ReplicatedStorage.Shared.FurnitureCatalog)
local Paths = require(ReplicatedStorage.Shared.Paths)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local StaffCatalog = require(ReplicatedStorage.Shared.StaffCatalog)

local ChefService = {}
local roles = { "RestaurantChef", "CompanyChef" }
local rolePaths = { RestaurantChef = "Restaurant", CompanyChef = "Company" }
local npc = CustomerService.npc
local started = false
local bases = {}

local function ownerOf(base)
	local id = base:GetAttribute("OwnerUserId")
	return if type(id) == "number" and id ~= 0 then Players:GetPlayerByUserId(id) else nil
end

-- A saved station is usable only after its world model is present too.
local function stations(house, frame)
	local result = {}
	-- Prep benches are furniture too (PrepBench), saved under their bench key.
	local placed = house:FindFirstChild("Furniture")
	for _, model in if placed then placed:GetChildren() else {} do
		local key = model:GetAttribute("StationKey")
		local x, z, r = model:GetAttribute("X"), model:GetAttribute("Z"), model:GetAttribute("R")
		if
			type(key) == "string"
			and Recipes.stationOf(key)
			and type(x) == "number"
			and type(z) == "number"
			and type(r) == "number"
		then
			result[key] = Furniture.frame(frame, { ItemId = model:GetAttribute("ItemId"), X = x, Z = z, R = r })
		end
	end
	return result
end

local function removeWorker(state, role)
	local worker = state.workers[role]
	if worker then
		worker.model:Destroy()
		state.workers[role] = nil
	end
end

local function clear(state)
	for _, role in roles do
		removeWorker(state, role)
	end
end

local function ensureWorker(base, state, owner, role, position)
	local worker = state.workers[role]
	if worker and worker.model.Parent and worker.humanoid.Health > 0 then
		return worker
	end
	removeWorker(state, role)
	if state.spawning[role] then
		return nil
	end
	state.spawning[role] = true
	task.spawn(function()
		local model
		local ok, failure = pcall(function()
			model = npc.spawn(position, role)
			if bases[base] ~= state or ownerOf(base) ~= owner or not base.Parent then
				model:Destroy()
				return
			end
			local profile = BoatService.getProfile(owner)
			if not profile or not profile.Angler.Staff[role] or not Paths.unlocked(profile, rolePaths[role]) then
				model:Destroy()
				return
			end
			model.Name = role
			model:SetAttribute("OwnerUserId", owner.UserId)
			model:SetAttribute("StaffRole", role)
			StaffCatalog.finishModel(model)
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart")
			assert(humanoid and root and root:IsA("BasePart"), "Chef has no humanoid or root")
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
			root.Anchored = true
			model.Parent = if role == "CompanyChef" then (CompanyIslandAccess.get(owner) or base) else base
			state.workers[role] = { model = model, humanoid = humanoid, root = root }
		end)
		state.spawning[role] = nil
		if not ok then
			if model then
				model:Destroy()
			end
			warn("[Chef] Spawn: " .. tostring(failure))
		end
	end)
	return nil
end

local function display(worker, role, message, frame)
	if not worker then
		return
	end
	local height = worker.model:GetExtentsSize().Y / 2
	worker.model:PivotTo(frame * CFrame.new(0, height, 0))
	npc.bubble(worker, (if role == "RestaurantChef" then "Restaurant chef" else "Company chef") .. " · " .. message)
end

local function processRole(base, state, owner, role, houseFrame, available)
	local profile = BoatService.getProfile(owner)
	if not profile or not profile.Angler.Staff[role] or not Paths.unlocked(profile, rolePaths[role]) then
		removeWorker(state, role)
		return
	end
	local idle = houseFrame * CFrame.new(-18.5, 0, if role == "RestaurantChef" then -5 else -10)
	local worker = ensureWorker(base, state, owner, role, idle.Position)
	local now = os.time()
	local activeKey, activeJob
	for key, job in profile.Angler.Kitchen do
		if job.ChefRole == role then
			activeKey, activeJob = key, job
			break
		end
	end
	if activeJob then
		local stationFrame = available[activeKey]
		local stand = if stationFrame
			then stationFrame * CFrame.new(0, 0, Kitchen.DEPTH / 2 + 1.7) * CFrame.Angles(0, math.pi, 0)
			else idle
		local ready = now >= activeJob.ReadyAt
		local cookingRecipe = Recipes.Items[activeJob.Dish.RecipeId]
		display(
			worker,
			role,
			if ready
				then "Waiting for space on the pass"
				else "Cooking " .. (if cookingRecipe then cookingRecipe.Name else "dish"),
			stand
		)
		local _, reason = AnglerData.collectChefDish(profile.Angler, role, activeKey, now)
		if not reason then
			BoatService.updateProgress(owner, function(current)
				assert(ownerOf(base) == owner and base.Parent, "Kitchen owner changed")
				local data, failure = AnglerData.collectChefDish(current.Angler, role, activeKey, os.time())
				assert(data, failure)
				current.Angler = data
			end)
		end
		return
	end
	local recipeId = profile.Angler.ChefRecipes[role]
	local recipe = recipeId and Recipes.Items[recipeId]
	if not recipe then
		display(worker, role, "Choose a recipe in Workers", idle)
		return
	end
	local keys = {}
	for key in available do
		if Recipes.stationOf(key) == recipe.Station then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	local status = if #keys == 0
		then "Needs a " .. Recipes.Stations[recipe.Station].Name
		else "Waiting for fish or a free station"
	for _, key in keys do
		local _, reason = AnglerData.startChefCooking(profile.Angler, role, key, Catalog.Fish, now)
		if not reason then
			local ok = BoatService.updateProgress(owner, function(current)
				assert(ownerOf(base) == owner and base.Parent, "Kitchen owner changed")
				local data, failure = AnglerData.startChefCooking(current.Angler, role, key, Catalog.Fish, os.time())
				assert(data, failure)
				current.Angler = data
			end)
			if ok then
				status = "Cooking " .. recipe.Name
				local stand = available[key] * CFrame.new(0, 0, Kitchen.DEPTH / 2 + 1.7) * CFrame.Angles(0, math.pi, 0)
				display(worker, role, status, stand)
				return
			end
			break
		end
	end
	display(worker, role, status, idle)
end

local function processBase(base, state)
	local owner = ownerOf(base)
	local house = base:FindFirstChild("BaseHouse")
	local frame = house and house:GetAttribute("HouseFrame")
	if not owner or not house or typeof(frame) ~= "CFrame" then
		clear(state)
		return
	end
	if state.owner ~= owner then
		clear(state)
		state.owner = owner
	end
	local available = stations(house, frame)
	for _, role in roles do
		if ownerOf(base) ~= owner then
			break
		end
		local property = if role == "CompanyChef" then CompanyIslandAccess.get(owner) else nil
		local worker = state.workers[role]
		if worker then worker.model.Parent = property or base end
		if property then
			local companyStations = {}
			for key, station in CompanyIslandAccess.stations(owner) do
				companyStations[key] = station.frame
			end
			-- The company chef waits on the island plot between the benches the owner placed.
			processRole(base, state, owner, role, property:GetAttribute("PlotFrame"), companyStations)
		else
			processRole(base, state, owner, role, frame, available)
		end
	end
end

function ChefService.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		while true do
			for _, base in CollectionService:GetTagged("PlayerBase") do
				if base:IsA("Model") then
					local state = bases[base]
					if not state then
						state = { workers = {}, spawning = {}, busy = false }
						bases[base] = state
					end
					if not state.busy then
						state.busy = true
						task.spawn(function()
							local ok, failure = pcall(processBase, base, state)
							state.busy = false
							if not ok then
								warn("[Chef] " .. tostring(failure))
							end
						end)
					end
				end
			end
			for base, state in bases do
				if not base.Parent or not CollectionService:HasTag(base, "PlayerBase") then
					clear(state)
					bases[base] = nil
				end
			end
			task.wait(2)
		end
	end)
end

return ChefService
