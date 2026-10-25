-- Private command replies and permission checks live on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local Passes = require(ReplicatedStorage.Shared.Gamepasses)
local GamepassService = require(script.Parent.GamepassService)

local Service = {}
local started = false
local COMMAND_USER_ID = 2541746813 -- hyperlinkhyper
local help = table.concat({
	"Commands:",
	"/commands - show this list",
	"/gamepass list - list gamepasses",
	"/gamepass get <gamepass name> - enable a pass for this server session",
	"/set cash <amount> - set your cash",
	"/set weather list - list weather types",
	"/set weather <type> - change the weather",
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
