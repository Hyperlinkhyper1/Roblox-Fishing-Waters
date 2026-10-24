-- Freezer and customer prompts belong to the base owner; everyone else never sees
-- them. Shop notices use the standard Roblox notification.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local ShopCustomers = {}
local OWNER_PROMPT_TAG = "ShopOwnerPrompt"
local started = false

local function bindPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local function refresh()
		-- Local only: the server never writes Enabled on these prompts.
		prompt.Enabled = prompt:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
	end
	prompt:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh)
	refresh()
end

function ShopCustomers.start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceAddedSignal(OWNER_PROMPT_TAG):Connect(bindPrompt)
	for _, prompt in CollectionService:GetTagged(OWNER_PROMPT_TAG) do
		bindPrompt(prompt)
	end
	local update = ReplicatedStorage:WaitForChild("ShopCustomers"):WaitForChild("Update") :: RemoteEvent
	update.OnClientEvent:Connect(function(kind, message)
		if kind == "Notice" and type(message) == "string" then
			pcall(StarterGui.SetCore, StarterGui, "SendNotification", {
				Title = "Fish & Tackle",
				Text = message,
				Duration = 5,
			})
		end
	end)
end

return ShopCustomers
