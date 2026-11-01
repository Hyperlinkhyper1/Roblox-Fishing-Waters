-- Private command replies and permission checks live on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local Passes = require(ReplicatedStorage.Shared.Gamepasses)
local GamepassService = require(script.Parent.GamepassService)
local Calendar = require(ReplicatedStorage.Shared.Calendar)
local DayNight = require(ReplicatedStorage.Shared.DayNight)

local Service = {}
local started = false
local COMMAND_USER_ID = 2541746813 -- hyperlinkhyper
local help = table.concat({
	"Commands:",
	"/commands - show this list",
	"/gamepass list - list gamepasses",
	"/gamepass get <gamepass name> - enable a pass for this server session",
	"/event list - list events",
	"/event spawn <event> - start an event for the rest of the in-game day",
	"/set cash <amount> - set your cash",
	"/set weather list - list weather types",
	"/set weather <type> - change the weather",
	"/set season <spring|summer|autumn|winter|auto> - pin the season or let it follow the clock",
	"/set date <month-day> [hh:mm] - jump the in-game calendar there (e.g. 10-31 23:50), or auto",
	"/tp city - teleport to the city",
	"/tp models - teleport to the full-size scale models",
	"/fly - toggle flight (WASD, Space up, Ctrl down)",
	"/fly speed <studs per second> - set flight speed (default 50)",
}, "\n")

local function normalize(name: string): string
	return (string.lower(name):gsub("%s+", ""))
end

function Service.start(reply)
	if started then
		return
	end
	started = true
	local function register(name, alias, handler)
		local command = Instance.new("TextChatCommand")
		command.Name = name
		command.PrimaryAlias = alias
		command.AutocompleteVisible = false
		command.Triggered:Connect(function(source, message)
			local player = source and Players:GetPlayerByUserId(source.UserId)
			if player and player.UserId == COMMAND_USER_ID and type(message) == "string" then
				handler(player, string.lower(message))
			end
		end)
		command.Parent = TextChatService
	end

	register("CommandsCommand", "/commands", function(player)
		reply(player, help)
	end)
	register("EventCommand", "/event", function(player, message)
		if message:match("^/event%s+list%s*$") then
			reply(player, "Events: Halloween.")
			return
		end
		local requested = message:match("^/event%s+spawn%s+(%S+)%s*$")
		if requested == "halloween" then
			local now = workspace:GetServerTimeNow()
			local date = Calendar.now(now)
			workspace:SetAttribute("HalloweenEventDay", (date.Year - 1) * Calendar.DAYS_PER_YEAR + date.DayOfYear)
			workspace:SetAttribute("HalloweenEventEnds", now + (24 - date.Hour) * DayNight.SECONDS_PER_HOUR)
			reply(player, "Halloween is active in this server for the rest of the in-game day.")
		elseif requested then
			reply(player, "Unknown event. Use /event list for available events.")
		else
			reply(player, "Usage: /event list or /event spawn <event>.")
		end
	end)
	register("FlyCommand", "/fly", function(player, message)
		if message:match("^/fly%s*$") then
			local enabled = not player:GetAttribute("AdminFlyEnabled")
			player:SetAttribute("AdminFlyEnabled", enabled)
			reply(player, if enabled then "Flight enabled. Use WASD, Space and Ctrl to move." else "Flight disabled.")
			return
		end
		local input = message:match("^/fly%s+speed%s+(%S+)%s*$")
		local speed = input and tonumber(input)
		if not speed or speed <= 0 or speed ~= speed or speed == math.huge then
			reply(player, "Usage: /fly or /fly speed <positive studs per second>.")
			return
		end
		player:SetAttribute("AdminFlySpeed", speed)
		reply(player, "Flight speed set to " .. tostring(speed) .. " studs per second.")
	end)
	-- Each destination returns the part it lands on and the frame to land at
	local destinations = {
		city = function()
			local map = workspace:FindFirstChild("Map")
			local city = map and map:FindFirstChild("Modern City")
			-- Cities from version 4 on have only the arrival point at their top level
			local arrival = city and city:FindFirstChild("CityArrival")
			local pavement = city and city:FindFirstChild("CityPavement")
			if arrival and arrival:IsA("BasePart") then
				return arrival, arrival.CFrame * CFrame.new(0, 5, 0)
			elseif pavement and pavement:IsA("BasePart") then
				-- The oldest baked cities have no arrival point and keep the avenue-intersection fallback
				return pavement, pavement.CFrame * CFrame.new(-150, 5, -150)
			end
			return nil
		end,
		-- The showcase lies outside the ocean where no boat can sail, so this is the only way there.
		-- The pier goes up on the spot if needed, so the admin can watch the ship being built.
		models = function(player)
			local scaleModels = require(script.Parent.ScaleModels)
			local arrival = scaleModels.ensurePier()
			-- Pins the ship to this player, so a client short of memory does not drop it
			scaleModels.visit(player)
			return arrival, arrival.CFrame * CFrame.new(0, 3, 0)
		end,
	}
	local names = { city = "the city", models = "the scale models" }
	register("TeleportCommand", "/tp", function(player, message)
		local place = message:match("^/tp%s+(%a+)%s*$")
		local find = place and destinations[place]
		if not find then
			reply(player, "Usage: /tp city or /tp models.")
			return
		end
		local anchor, destination = find(player)
		if not anchor then
			local name = names[place]
			reply(player, string.upper(name:sub(1, 1)) .. name:sub(2) .. " " .. (if place == "city" then "is" else "are") .. " not ready yet. Try again shortly.")
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or humanoid.Health <= 0 or not root then
			reply(player, "Your character is not ready to teleport.")
			return
		end
		pcall(player.RequestStreamAroundAsync, player, destination.Position, 4)
		if player.Character ~= character or not character.Parent or humanoid.Health <= 0 or not anchor.Parent then
			return
		end
		humanoid.Sit = false
		character:PivotTo(destination)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		reply(player, "Teleported to " .. names[place] .. ".")
	end)
	register("GamepassCommand", "/gamepass", function(player, message)
		if message:match("^/gamepass%s+list%s*$") then
			local names = {}
			for _, pass in Passes do
				table.insert(names, pass.Name)
			end
			table.sort(names)
			reply(player, "Gamepasses: " .. table.concat(names, ", ") .. ".")
			return
		end
		local requested = message:match("^/gamepass%s+get%s+(.+)$")
		if requested then
			for key, pass in Passes do
				if normalize(requested) == normalize(pass.Name) or normalize(requested) == normalize(key) then
					local _, result = GamepassService.grantForSession(player, key)
					reply(player, result)
					return
				end
			end
			reply(player, "Unknown gamepass. Use /gamepass list for available names.")
		else
			reply(player, "Usage: /gamepass list or /gamepass get <gamepass name>.")
		end
	end)
end

return Service
