-- Sitting down at the office PC in your own base house (Map/OfficeDesk). The client asks to sit;
-- the server checks the desk is in the player's base and they are standing by it, rolls the chair
-- up to the monitor and seats them in its hidden Seat. Getting up (jumping, or the PC's EXIT)
-- rolls the chair back out. Apps on the PC (StockMarketService) require `atDesk`.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficeDesk = require(script.Parent.Map.OfficeDesk)

local Service = {}
local started = false

local BASE_TAG = "PlayerBase"
-- How far from the chair the player may be when they ask to sit (the client prompt is shorter).
local REACH = 14

local seated: { [Player]: Instance } = {}

local function ownDesk(player: Player): Instance?
	for _, base in CollectionService:GetTagged(BASE_TAG) do
		if base:GetAttribute("OwnerUserId") == player.UserId then
			local desk = base:FindFirstChild("OfficeDesk", true)
			if desk and desk:IsA("Model") then
				return desk
			end
		end
	end
	return nil
end

local function seatOf(desk: Instance): Seat?
	local chair = desk:FindFirstChild("Chair")
	local seat = chair and chair:FindFirstChild("Seat")
	return if seat and seat:IsA("Seat") then seat else nil
end

local function humanoidOf(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil, nil
	end
	return humanoid, root
end

-- The desk the player is sitting at right now, if it is their own.
function Service.atDesk(player: Player): Instance?
	local desk = seated[player]
	local humanoid = humanoidOf(player)
	local seat = desk and seatOf(desk)
	if desk and humanoid and seat and seat.Occupant == humanoid and desk:IsDescendantOf(workspace) then
		return desk
	end
	return nil
end

local function release(player: Player)
	local desk = seated[player]
	seated[player] = nil
	if desk and desk.Parent then
		local seat = seatOf(desk)
		if seat and seat.Occupant then
			local weld = seat:FindFirstChild("SeatWeld")
			if weld then
				weld:Destroy()
			end
		end
		OfficeDesk.moveChair(desk, false)
	end
end

local function sit(player: Player): (boolean, string?)
	if Service.atDesk(player) then
		return true
	end
	local desk = ownDesk(player)
	if not desk then
		return false, "This isn't your computer."
	end
	local seat = seatOf(desk)
	local humanoid, root = humanoidOf(player)
	if not seat or not humanoid or not root then
		return false, "The computer isn't ready yet."
	end
	if (root.Position - seat.Position).Magnitude > REACH then
		return false, "Walk up to your desk first."
	end
	if seat.Occupant and seat.Occupant ~= humanoid then
		return false, "Someone is already sitting there."
	end
	if humanoid.SeatPart then
		humanoid.Sit = false
		task.wait()
	end
	humanoid:UnequipTools()
	OfficeDesk.moveChair(desk, true)
	seated[player] = desk
	seat:Sit(humanoid)
	-- Standing up by jumping clears the occupant; roll the chair back out once they're clear.
	local connection
	connection = seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if seat.Occupant ~= humanoid then
			connection:Disconnect()
			if seated[player] == desk then
				task.delay(0.4, function()
					if seated[player] == desk and seat.Occupant ~= humanoid then
						release(player)
					end
				end)
			end
		end
	end)
	return true
end

function Service.start()
	if started then
		return
	end
	started = true
	local folder = Instance.new("Folder")
	folder.Name = "OfficeComputer"
	local remote = Instance.new("RemoteFunction")
	remote.Name = "Request"
	remote.Parent = folder
	folder.Parent = ReplicatedStorage

	local lastRequest: { [Player]: number } = {}
	remote.OnServerInvoke = function(player, action)
		if os.clock() - (lastRequest[player] or -math.huge) < 0.5 then
			return { Ok = false, Message = "One moment..." }
		end
		lastRequest[player] = os.clock()
		if action == "Sit" then
			local ok, message = sit(player)
			return { Ok = ok, Message = message }
		elseif action == "Stand" then
			local humanoid = humanoidOf(player)
			release(player)
			if humanoid then
				humanoid.Sit = false
			end
			return { Ok = true }
		end
		return { Ok = false, Message = "Unknown request." }
	end

	Players.PlayerRemoving:Connect(function(player)
		release(player)
		lastRequest[player] = nil
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterRemoving:Connect(function()
			release(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterRemoving:Connect(function()
			release(player)
		end)
	end
end

return Service
