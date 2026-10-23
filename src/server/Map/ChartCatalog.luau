-- Lightweight chart records replicate independently of Workspace streaming.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Catalog = {}

function Catalog.start(root: Instance)
	local old = ReplicatedStorage:FindFirstChild("IslandChart")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "IslandChart"
	folder.Parent = ReplicatedStorage
	local seen = {}
	local function add(model)
		if not model:IsA("Model") or (model.Name ~= "Island" and model.Name ~= "Harbour Isle") or seen[model] then
			return
		end
		seen[model] = true
		local coast = model:GetAttribute("ChartCoast")
		if not coast and model.Name == "Harbour Isle" then
			local Biomes = require(ReplicatedStorage.Shared.Biomes)
			coast = HttpService:JSONEncode(require(script.Parent.Harbour).chartCoast(Biomes.Normal.center))
		end
		if not coast then
			-- Older Studio-baked islands have no coast metadata. Use their ground
			-- bounds as a chart symbol; never include buildings, trees or LOD shells.
			local ground = model:FindFirstChild("Ground")
			if not ground or not ground:IsA("Model") or not ground:FindFirstChildWhichIsA("BasePart", true) then
				return
			end
			local frame, size = ground:GetBoundingBox()
			local radius = model:GetAttribute("Radius")
			local rx, rz = radius or size.X / 2, radius or size.Z / 2
			local points = {}
			for i = 1, 16 do
				local angle = i / 16 * math.pi * 2
				table.insert(points, { frame.X + math.cos(angle) * rx, frame.Z + math.sin(angle) * rz })
			end
			coast = HttpService:JSONEncode(points)
		end
		local record = Instance.new("StringValue")
		record.Name = model.Name
		record.Value = coast
		record:SetAttribute("Atoll", model:GetAttribute("ChartAtoll") == true)
		record.Parent = folder
		model.Destroying:Connect(function()
			record:Destroy()
		end)
	end
	root.DescendantAdded:Connect(add)
	for _, model in root:GetDescendants() do
		add(model)
	end
end

return Catalog
