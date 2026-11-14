-- Only merchandise follows occupancy; the bare rack frames/furniture stream with the store.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Catalog = require(ReplicatedStorage.Shared.TechCatalog)
local Layout = require(ReplicatedStorage.Shared.TechStoreLayout)
local Geometry = require(ReplicatedStorage.Shared.TechStoreInterior)

local Interior = {}
local started = false
local PARTS_PER_FRAME, FRAME_BUDGET = 12, 0.0015

function Interior.start(onProduct, onExit)
	if started then return end
	started = true
	local player, records = Players.LocalPlayer, {}
	local function unload(record)
		-- Discard the suspended builder as well as its parts, prompts, GUIs and lights.
		record.builder = nil
		if record.folder then record.folder:Destroy(); record.folder = nil end
		if record.inside and onExit then onExit() end
		record.inside = false
	end
	local function added(store)
		if not records[store] then records[store] = {} end
	end
	local function removed(store)
		local record = records[store]
		if record then unload(record); records[store] = nil end
	end
	CollectionService:GetInstanceAddedSignal(Catalog.STORE_TAG):Connect(added)
	CollectionService:GetInstanceRemovedSignal(Catalog.STORE_TAG):Connect(removed)
	for _, store in CollectionService:GetTagged(Catalog.STORE_TAG) do added(store) end
	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		for store, record in records do
			local frame = store:GetAttribute("StoreFrame")
			local inside = root and humanoid and humanoid.Health > 0 and typeof(frame) == "CFrame"
				and store:IsDescendantOf(workspace) and Layout.inside(frame, root.Position)
			if not inside then
				unload(record)
			elseif not record.inside then
				record.inside = true
				record.folder = Instance.new("Folder")
				record.folder.Name = "LocalTechInterior"
				record.folder.Parent = store
				record.builder = coroutine.create(function()
					Geometry.build(record.folder, frame, onProduct, coroutine.yield)
				end)
			end
			if record.builder then
				local began = os.clock()
				for _ = 1, PARTS_PER_FRAME do
					local ok, problem = coroutine.resume(record.builder)
					if not ok then
						warn("[TechStore] Interior build failed: " .. tostring(problem))
						record.builder = nil
						break
					end
					if coroutine.status(record.builder) == "dead" then record.builder = nil; break end
					if os.clock() - began >= FRAME_BUDGET then break end
				end
			end
		end
	end)
end

return Interior
