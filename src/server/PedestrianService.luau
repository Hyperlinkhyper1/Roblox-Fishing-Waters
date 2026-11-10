-- Owns the shared pedestrian appearances and starts the island-wide crowd.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pedestrians = require(ReplicatedStorage.Shared.Pedestrians)
local AvatarLite = require(ReplicatedStorage.Shared.AvatarLite)
local Streets = require(script.Parent.StreetPedestrians)
local PedestrianService = {}
local MAX_USER_ID = 3_000_000_000
local AVATAR_ATTEMPTS = 10
local rng = Random.new()
local started = false

-- A real account that actually dressed up: clothes and something on its head.
-- Skips the blank starter avatars most dormant accounts still wear.
local function dressed(description: HumanoidDescription): boolean
	local clothed = description.Shirt ~= 0 or description.Pants ~= 0 or description.GraphicTShirt ~= 0
	return clothed and (description.HairAccessory ~= "" or description.HatAccessory ~= "")
end

-- Fills ReplicatedStorage.PedestrianAvatars with one HumanoidDescription per slot, taken
-- from random real players. Only descriptions replicate; each client builds the rigs.
local function loadAvatars(avatars: Folder)
	local spare: HumanoidDescription? = nil
	for slot = 1, Pedestrians.AVATAR_COUNT do
		local found: HumanoidDescription? = nil
		for _ = 1, AVATAR_ATTEMPTS do
			local ok, description =
				pcall(Players.GetHumanoidDescriptionFromUserId, Players, rng:NextInteger(1, MAX_USER_ID))
			if ok and description then
				if dressed(description) then
					found = description
					break
				end
				spare = spare or description
				if spare ~= description then
					description:Destroy()
				end
			end
			task.wait(0.1)
		end
		-- No dressed account this time: reuse an earlier slot, else any real avatar, else a plain rig
		local earlier = avatars:FindFirstChild(tostring(rng:NextInteger(1, math.max(1, slot - 1))))
		local description = found
			or (if earlier then (earlier :: HumanoidDescription):Clone() else nil)
			or (if spare then spare:Clone() else nil)
			or Instance.new("HumanoidDescription")
		-- Clients build every townsperson (and shop visitor) from these: no layered clothing.
		AvatarLite.strip(description)
		description.Name = tostring(slot)
		description.Parent = avatars
	end
	if spare then
		spare:Destroy()
	end
end

function PedestrianService.start()
	if started then return end
	started = true
	local folder = ReplicatedStorage:FindFirstChild(Pedestrians.FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name, folder.Parent = Pedestrians.FOLDER, ReplicatedStorage
	end
	local avatars = ReplicatedStorage:FindFirstChild(Pedestrians.AVATAR_FOLDER)
	if not avatars then
		avatars = Instance.new("Folder")
		avatars.Name, avatars.Parent = Pedestrians.AVATAR_FOLDER, ReplicatedStorage
	end
	task.spawn(function()
		local ok, problem = pcall(loadAvatars, avatars)
		if not ok then warn("[Pedestrians] Avatars: " .. tostring(problem)) end
	end)
	Streets.start(folder)
end

return PedestrianService
