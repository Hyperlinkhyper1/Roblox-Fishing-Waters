-- Whether a character is on a boat: sitting in one of its seats or standing on
-- its deck (a short ray down from the root hits the hull). The server uses it to
-- allow cargo moves and the client to show the cargo hold, so both agree.
local DECK_REACH = 8

return function(character: Model?, boat: Model?): boolean
	if not character or not boat or not boat.Parent then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return false
	end
	local seat = humanoid.SeatPart
	if seat and seat:IsDescendantOf(boat) then
		return true
	end
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Include
	parameters.FilterDescendantsInstances = { boat }
	return workspace:Raycast(root.Position, Vector3.new(0, -DECK_REACH, 0), parameters) ~= nil
end
