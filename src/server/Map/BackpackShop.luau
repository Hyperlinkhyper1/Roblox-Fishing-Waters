-- A dedicated backpack stand takes the northern stall in the plaza market row.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Backpacks = require(ReplicatedStorage.Shared.BackpackCatalog)
local Cargo = require(ReplicatedStorage.Shared.Cargo)
local Models = require(ReplicatedStorage.Shared.BackpackModels)
local PlazaHouses = require(script.Parent.PlazaHouses)
local Props = require(script.Parent.Props)
local Shop = {}
local rgb = Color3.fromRGB
local VERSION = 4

function Shop.build(plaza: Model, plazaFrame: CFrame): Model
	local existing = plaza:FindFirstChild("BackpackShop")
	if existing and existing:GetAttribute("LayoutVersion") == VERSION then
		CollectionService:AddTag(existing, "BackpackShop")
		return existing :: Model
	end
	if existing then
		existing:Destroy()
	end
	-- Replace the decorative fish stall on older baked maps.
	for _, stall in plaza:GetChildren() do
		if stall:IsA("Model") and stall.Name == "Stall" then
			local position = plazaFrame:PointToObjectSpace(stall:GetPivot().Position)
			if math.abs(position.X - 44) < 9 and math.abs(position.Z + 18) < 5 then
				stall:Destroy()
			end
		end
	end
	local model = Instance.new("Model")
	model.Name = "BackpackShop"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("LayoutVersion", VERSION)
	local base = plazaFrame * CFrame.new(44, 0, -18) * CFrame.Angles(0, -math.pi / 2, 0)
	local function part(name, size, frame, color, material)
		local piece = Props.part(model, size, base * frame, color, material)
		piece.Name = name
		return piece
	end
	local wood, dark, green, cream = rgb(158, 111, 68), rgb(77, 57, 40), rgb(59, 109, 88), rgb(244, 234, 208)
	part("Counter", Vector3.new(9, 3, 3), CFrame.new(0, 1.5, 1.5), wood, Enum.Material.WoodPlanks)
	part("CounterTop", Vector3.new(9.4, 0.3, 3.4), CFrame.new(0, 3.15, 1.5), dark, Enum.Material.Wood)
	for _, x in { -4.3, 4.3 } do
		for _, z in { -2, 3 } do
			part("Post", Vector3.new(0.4, 8, 0.4), CFrame.new(x, 4, z), dark, Enum.Material.Wood)
		end
	end
	for index = 0, 4 do
		part(
			"Awning",
			Vector3.new(2, 0.25, 7),
			CFrame.new(-4 + index * 2, 8.2, 0.5) * CFrame.Angles(0.18, 0, 0),
			if index % 2 == 0 then green else cream,
			Enum.Material.Fabric
		)
	end
	local sign = part("StoreSign", Vector3.new(8.8, 1.5, 0.2), CFrame.new(0, 6.9, 3.3), green, Enum.Material.Wood)
	sign.CanCollide = false
	PlazaHouses.boardText(sign, "BACKPACKS", Enum.NormalId.Back)
	-- Four real samples fit the counter; all fifteen designs can be previewed inside the catalogue.
	for index, id in { "Starter", "Cooler", "Treasure", "Abyss" } do
		local item = Backpacks.Items[id]
		local x = (index - 2.5) * 2.1
		local sample = Models.create(id)
		sample.Name = "Sample_" .. id
		sample:ScaleTo(0.62)
		local box, size = sample:GetBoundingBox()
		sample:PivotTo(base * CFrame.new(x, 3.3 - box.Position.Y + size.Y / 2, 1.5))
		sample.Parent = model
		local label = part("PriceTag", Vector3.new(1.9, 0.85, 0.12), CFrame.new(x, 2.5, 3.04), dark, Enum.Material.Wood)
		PlazaHouses.boardText(
			label,
			string.format(
				"%d TILES\n%s",
				Cargo.capacity(item.Hold),
				if item.Price == 0 then "FREE" else "$" .. item.Price
			),
			Enum.NormalId.Back
		)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name, prompt.ActionText, prompt.ObjectText =
		"BrowseBackpacksPrompt", "Browse backpacks", "Plaza Backpack Store"
	prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.HoldDuration = 9, false, 0
	prompt.Parent = model.Counter
	model.Parent = plaza
	CollectionService:AddTag(model, "BackpackShop")
	return model
end

function Shop.ensure(root: Instance)
	for _, plaza in root:GetDescendants() do
		if plaza:IsA("Model") and plaza.Name == "Plaza" then
			local frame = PlazaHouses.pavingFrame(plaza)
			if frame then
				Shop.build(plaza, frame)
			end
		end
	end
end
return Shop
