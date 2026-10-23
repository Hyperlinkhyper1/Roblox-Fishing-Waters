local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BoatService = require(script.Parent.BoatService)
local Data = require(script.Parent.AnglerData)
local Catalog = require(ReplicatedStorage.Shared.AnglerCatalog)
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))
local Service = {}
local started = false
local requests = {}
-- No active codes or Robux products have been configured yet.
local codes = {}

-- Call only after server gameplay has validated and awarded a catch. Never remote-exposed.
function Service.recordCatch(player: Player, fishId: string, mutation: string, kg: number, value: number)
	local caughtAt = os.time()
	return BoatService.updateProgress(player, function(profile)
		profile.Angler =
			Data.recordCatch(profile.Angler, fishId, mutation, kg, value, caughtAt, Catalog.Fish, Catalog.Mutations)
	end)
end

function Service.start()
	if started then
		return
	end
	started = true
	local remote = Instance.new("RemoteFunction")
	remote.Name, remote.Parent = "AnglerMenu", ReplicatedStorage
	remote.OnServerInvoke = function(player, action, key, value)
		if os.clock() - (requests[player] or -math.huge) < 0.25 then
			return { Ok = false, Message = "Please wait a moment and try again." }
		end
		requests[player] = os.clock()
		local profile = BoatService.getProfile(player)
		if not profile then
			return { Ok = false, Message = "Your progress is still loading or unavailable." }
		end
		local ok, message = true, ""
		if action == "Setting" and type(key) == "string" and Data.validSetting(key, value) then
			ok, message = BoatService.updateProgress(player, function(current)
				current.Angler.Settings[key] = value
			end)
		elseif
			action == "Title"
			and type(key) == "string"
			and (key == "" or (Catalog.Titles[key] and profile.Angler.Titles[key]))
		then
			ok, message = BoatService.updateProgress(player, function(current)
				assert(key == "" or current.Angler.Titles[key], "Title is not unlocked")
				current.Angler.EquippedTitle = key
			end)
		elseif action == "Code" then
			if type(key) ~= "string" or #key > 64 then
				return { Ok = false, Message = "Enter a valid code." }
			end
			local code = string.upper(key:match("^%s*(.-)%s*$"))
			local reward = codes[code]
			if not reward then
				return { Ok = false, Message = "This code is not active." }
			end
			if profile.Angler.RedeemedCodes[code] then
				return { Ok = false, Message = "You already redeemed this code." }
			end
			ok, message = BoatService.updateProgress(player, function(current)
				assert(not current.Angler.RedeemedCodes[code], "Code already redeemed")
				current.Angler.RedeemedCodes[code] = true
				current.Cash += reward
				current.Angler.Stats.CoinsEarned += reward
			end)
		elseif action ~= "Get" then
			return { Ok = false, Message = "That menu action is unavailable." }
		end
		return { Ok = ok, Message = message, Profile = BoatService.getProfile(player) }
	end
	local function bind(player)
		local function updateTitle()
			local character = player.Character
			local head = character and character:FindFirstChild("Head")
			if not head then
				return
			end
			local previous = head:FindFirstChild("AnglerTitle")
			if previous then
				previous:Destroy()
			end
			local current = BoatService.getProfile(player)
			local title = current and Catalog.Titles[current.Angler.EquippedTitle]
			if not title or not current.Angler.Titles[current.Angler.EquippedTitle] then
				return
			end
			local billboard = Instance.new("BillboardGui")
			billboard.Name, billboard.Size = "AnglerTitle", UDim2.fromOffset(220, 28)
			billboard.StudsOffset, billboard.MaxDistance = Vector3.new(0, 2.8, 0), 80
			local label = Instance.new("TextLabel")
			label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
			label.Font, label.TextSize, label.Text = Enum.Font.GothamBold, 15, title.Name
			Theme.text(label)
			label.Parent, billboard.Parent = billboard, head
		end
		player:GetAttributeChangedSignal("AnglerRevision"):Connect(updateTitle)
		local function characterAdded(character)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if not humanoid then
				return
			end
			character:WaitForChild("Head", 10)
			if player.Character ~= character then
				return
			end
			updateTitle()
			humanoid.Died:Once(function()
				-- Retry a concurrent purchase without discarding a death or resetting saved progress.
				for attempt = 1, 4 do
					if player.Parent ~= Players then
						return
					end
					local ok = BoatService.updateProgress(player, function(current)
						current.Angler.Stats.Deaths += 1
						current.Angler.Stats.CatchStreak = 0
					end)
					if ok then
						return
					end
					task.wait(attempt)
				end
			end)
		end
		player.CharacterAdded:Connect(characterAdded)
		if player.Character then
			task.spawn(characterAdded, player.Character)
		end
	end
	Players.PlayerAdded:Connect(bind)
	Players.PlayerRemoving:Connect(function(player)
		requests[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(bind, player)
	end
end
return Service
