-- Small read-only interface; property ownership is assigned by CompanyIslandService.
local CollectionService = game:GetService("CollectionService")
local Access = {}

function Access.get(player: Player): Model?
	for _, island in CollectionService:GetTagged("CompanyIsland") do
		if island:IsA("Model") and island:IsDescendantOf(workspace) and island:GetAttribute("OwnerUserId") == player.UserId then
			return island
		end
	end
	return nil
end

function Access.ownsPrompt(player: Player, prompt: ProximityPrompt): boolean
	local island = Access.get(player)
	return island ~= nil and prompt:IsDescendantOf(island)
end

-- Prep benches the owner placed on the plot, keyed like their saved kitchen jobs.
function Access.stations(player: Player)
	local result = {}
	local island = Access.get(player)
	local plot = island and island:FindFirstChild("PlotFurniture")
	for _, model in if plot then plot:GetChildren() else {} do
		local key, frame = model:GetAttribute("StationKey"), model:GetAttribute("StationFrame")
		if model:IsA("Model") and type(key) == "string" and typeof(frame) == "CFrame" then
			result[key] = { model = model, frame = frame }
		end
	end
	return result
end

return Access
