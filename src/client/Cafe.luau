-- The café on the client: only members of a café's company see its coffee
-- machine and serve prompts (CafeService checks again on the server), and café
-- notices arrive as notifications.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local CafeCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CafeCatalog"))

local Cafe = {}
local started = false
local player = Players.LocalPlayer

local function plotOf(item: Instance): Instance?
	local node = item.Parent
	while node and node ~= workspace do
		if CollectionService:HasTag(node, CafeCatalog.PLOT_TAG) then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function mine(plot: Instance?): boolean
	local companyId = player:GetAttribute("CompanyId")
	return plot ~= nil and type(companyId) == "string" and companyId ~= "" and plot:GetAttribute("CompanyId") == companyId
end

-- Customers walk in the CafeCustomers folder, outside the plot model: match a
-- serve prompt to the café it stands in by distance to each plot's frame.
local function nearestPlot(position: Vector3): Instance?
	local best, bestDistance = nil, 60
	for _, plot in CollectionService:GetTagged(CafeCatalog.PLOT_TAG) do
		local frame = plot:GetAttribute("CafeFrame")
		if typeof(frame) == "CFrame" then
			local distance = (frame.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = plot, distance
			end
		end
	end
	return best
end

local function refresh(prompt: ProximityPrompt)
	if not prompt:IsDescendantOf(workspace) then
		return
	end
	local plot = plotOf(prompt)
	if not plot then
		local holder = prompt.Parent
		plot = if holder and holder:IsA("BasePart") then nearestPlot(holder.Position) else nil
	end
	prompt.Enabled = mine(plot)
end

local function refreshAll()
	for _, prompt in CollectionService:GetTagged(CafeCatalog.PROMPT_TAG) do
		if prompt:IsA("ProximityPrompt") then
			refresh(prompt)
		end
	end
end

function Cafe.start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceAddedSignal(CafeCatalog.PROMPT_TAG):Connect(function(prompt)
		if prompt:IsA("ProximityPrompt") then
			-- Wait a frame so the prompt has its final parent.
			task.defer(refresh, prompt)
		end
	end)
	CollectionService:GetInstanceAddedSignal(CafeCatalog.PLOT_TAG):Connect(function(plot)
		plot:GetAttributeChangedSignal("CompanyId"):Connect(refreshAll)
		task.defer(refreshAll)
	end)
	for _, plot in CollectionService:GetTagged(CafeCatalog.PLOT_TAG) do
		plot:GetAttributeChangedSignal("CompanyId"):Connect(refreshAll)
	end
	player:GetAttributeChangedSignal("CompanyId"):Connect(refreshAll)
	refreshAll()

	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("Cafe")
		local feedback = folder:WaitForChild("Feedback") :: RemoteEvent
		feedback.OnClientEvent:Connect(function(kind, message)
			if kind == "Notice" and type(message) == "string" then
				pcall(StarterGui.SetCore, StarterGui, "SendNotification", {
					Title = "Café",
					Text = message,
					Duration = 5,
				})
			end
		end)
	end)
end

return Cafe
