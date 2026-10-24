-- Parked hulls are anchored on the server so movers never fight people on deck.
-- Each client rolls them on the shared swell clock instead; the server releases
-- a hull at that same pose (Weather.parkedOffset), so driving off never snaps.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Weather = require(ReplicatedStorage.Shared.Weather)

local ParkedBoats = {}
local started = false

function ParkedBoats.start()
	if started then
		return
	end
	started = true
	-- Before physics, so a local character standing on deck collides with this pose.
	RunService.PreSimulation:Connect(function()
		local folder = workspace:FindFirstChild("PlayerBoats")
		if not folder then
			return
		end
		local now = workspace:GetServerTimeNow()
		for _, model in folder:GetChildren() do
			local root = model:IsA("Model") and model.PrimaryPart
			local rest, parkedAt = model:GetAttribute("ParkedFrame"), model:GetAttribute("ParkedAt")
			if
				root
				and root.Anchored
				and model:GetAttribute("Parked")
				and typeof(rest) == "CFrame"
				and type(parkedAt) == "number"
			then
				-- The hull is rigid, so its pivot keeps one offset from the root.
				local pivot = rest * root.CFrame:ToObjectSpace(model:GetPivot())
				model:PivotTo(Weather.parkedOffset(rest, parkedAt, now) * pivot)
			end
		end
	end)
end

return ParkedBoats
