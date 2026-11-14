-- The café tutorial (Shared.CafeTutorial) on the server: Bea, the café mentor, stands in every
-- claimed café, and each company's saved progress through the tour. Talking happens on the
-- client; the server checks the player stood beside Bea in their own café before saving a talk
-- step, and ticks off task steps when CafeService reports a brew or a serve and
-- OfficeComputerService reports someone sitting at their desk. The tour belongs to the company
-- save, so any member's coffee counts. /tutorial restarts it for café companies.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local BoatService = require(script.Parent.BoatService)
local CafeCatalog = require(ReplicatedStorage.Shared.CafeCatalog)
local CafeService = require(script.Parent.CafeService)
local CafeTutorial = require(ReplicatedStorage.Shared.CafeTutorial)
local GuideCostume = require(script.Parent.GuideCostume)
local OfficeComputerService = require(script.Parent.OfficeComputerService)

local Service = {}
local started = false

local PROMPT = "CafeMentorPrompt"
local GUIDE_TAG = "TutorialGuide" -- the tutorial client turns tagged guides towards the player
local MENTOR_ATTRIBUTE = "MentorPosition"

local remote: RemoteEvent
local mentors: { [Model]: Model } = {}
local busy: { [Player]: boolean } = {}

local function notify(player: Player, kind: string, value: any)
	if player.Parent == Players then
		remote:FireClient(player, kind, value)
	end
end

----------------------------------------------------------------------------------------------------
-- Bea

local function mentorFrame(plot: Model): CFrame?
	local frame = plot:GetAttribute("CafeFrame")
	if typeof(frame) ~= "CFrame" then
		return nil
	end
	local spec = CafeTutorial.Mentor
	local feet = (frame * CFrame.new(spec.Spot[1], 0, spec.Spot[2])).Position
	local look = (frame * CFrame.new(spec.Face[1], 0, spec.Face[2])).Position
	return CFrame.lookAt(feet, Vector3.new(look.X, feet.Y, look.Z))
end

local function removeMentor(plot: Model)
	local model = mentors[plot]
	mentors[plot] = nil
	plot:SetAttribute(MENTOR_ATTRIBUTE, nil)
	if model then
		model:Destroy()
	end
end

local function placeMentor(plot: Model)
	if mentors[plot] and mentors[plot].Parent then
		return
	end
	local frame = mentorFrame(plot)
	if not frame then
		return
	end
	local spec = CafeTutorial.Mentor
	-- Set before the model loads so the client's arrow works straight away.
	plot:SetAttribute(MENTOR_ATTRIBUTE, frame.Position)
	local model = GuideCostume.spawn(spec.Id, spec.Outfit, spec.Name .. " · " .. spec.Title, frame, plot)
	if not model then
		return
	end
	-- The café may have been released while the outfit loaded.
	if (plot:GetAttribute("CompanyId") or "") == "" or mentors[plot] then
		model:Destroy()
		return
	end
	mentors[plot] = model
	model:AddTag(GUIDE_TAG)
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = PROMPT
		prompt.ActionText = "Talk"
		prompt.ObjectText = spec.Name .. " · " .. spec.Title
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.UIOffset = Vector2.new(0, -30)
		prompt:SetAttribute("NpcId", spec.Id)
		-- The café client shows café prompts only to members of the café's company.
		prompt:AddTag(CafeCatalog.PROMPT_TAG)
		prompt.Parent = head
	end
end

----------------------------------------------------------------------------------------------------
-- Progress

-- The café progress table on a profile, created for a company that has never served a coffee.
local function cafeProgress(profile): any
	if type(profile.Cafe) ~= "table" then
		profile.Cafe = { Served = 0, TutorialStep = 1, TutorialDone = false, TutorialCount = 0 }
	end
	return profile.Cafe
end

local function apply(cafe, step: number, done: boolean, count: number)
	cafe.TutorialStep, cafe.TutorialDone, cafe.TutorialCount = step, done, count
end

-- Saves a tour change; returns whether it saved and the reward paid if it finished the tour.
local function save(player: Player, move: (number, boolean, number) -> (number?, boolean, number)): (boolean, boolean, number)
	local moved, finished, reward = false, false, 0
	local ok = BoatService.updateProgress(player, function(profile)
		-- UpdateAsync may retry the transform; recompute from the stored profile every time.
		moved, finished, reward = false, false, 0
		local cafe = cafeProgress(profile)
		local current, done, count = CafeTutorial.state(cafe)
		local step, nowDone, nowCount = move(current, done, count)
		if not step then
			return
		end
		moved = true
		apply(cafe, step, nowDone, nowCount)
		if nowDone and not done then
			finished = true
			if not cafe.TutorialRewarded then
				cafe.TutorialRewarded = true
				reward = CafeTutorial.REWARD
				profile.Cash += reward
			end
		end
	end)
	return ok and moved, finished, reward
end

local function hasCafe(player: Player): boolean
	return player:GetAttribute("BoatDataStatus") == "Ready" and player:GetAttribute("BranchCafe") == true
end

-- Cheap check on the published attributes before touching the save.
local function tourWants(player: Player, event: string): boolean
	if not hasCafe(player) or player:GetAttribute("CafeTutorialDone") ~= false then
		return false
	end
	local index = player:GetAttribute("CafeTutorialStep")
	local count = player:GetAttribute("CafeTutorialCount")
	if type(index) ~= "number" then
		return false
	end
	return CafeTutorial.event(index, false, if type(count) == "number" then count else 0, event) ~= nil
end

local function onEvent(player: Player, event: string)
	if not tourWants(player, event) then
		return
	end
	local _, finished, reward = save(player, function(step, done, count)
		return CafeTutorial.event(step, done, count, event)
	end)
	if finished then
		notify(player, "Finished", reward)
	end
end

local function nearMentor(player: Player): boolean
	local plot = CafeService.plotFor(player)
	local position = plot and plot:GetAttribute(MENTOR_ATTRIBUTE)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return typeof(position) == "Vector3"
		and humanoid ~= nil
		and humanoid.Health > 0
		and root ~= nil
		and root:IsA("BasePart")
		and (root.Position - position).Magnitude <= CafeTutorial.TALK_RANGE
end

local function finishTalk(player: Player)
	if busy[player] or not hasCafe(player) or not nearMentor(player) then
		return
	end
	busy[player] = true
	local ok, finished, reward = save(player, CafeTutorial.talk)
	busy[player] = nil
	if ok and finished then
		notify(player, "Finished", reward)
	end
end

local function skip(player: Player)
	if busy[player] or not hasCafe(player) then
		return
	end
	busy[player] = true
	BoatService.updateProgress(player, function(profile)
		cafeProgress(profile).TutorialDone = true
	end)
	busy[player] = nil
end

local function restart(player: Player)
	if busy[player] or not hasCafe(player) then
		return
	end
	busy[player] = true
	local ok = BoatService.updateProgress(player, function(profile)
		apply(cafeProgress(profile), 1, false, 0)
	end)
	busy[player] = nil
	notify(
		player,
		"Notice",
		if ok
			then "Café tutorial restarted! Follow the arrow to Bea in your café."
			else "The café tutorial could not restart right now. Try again in a moment."
	)
end

----------------------------------------------------------------------------------------------------

function Service.start()
	if started then
		return
	end
	started = true
	local folder = Instance.new("Folder")
	folder.Name = "CafeTutorial"
	remote = Instance.new("RemoteEvent")
	remote.Name = "Request"
	remote.Parent = folder
	folder.Parent = ReplicatedStorage

	remote.OnServerEvent:Connect(function(player, action)
		if action == "Finish" then
			finishTalk(player)
		elseif action == "Skip" then
			skip(player)
		end
	end)

	CafeService.onEvent(function(kind, player, plot)
		if kind == "Claimed" then
			placeMentor(plot)
		elseif kind == "Released" then
			removeMentor(plot)
		elseif player and (kind == "Brew" or kind == "Serve") then
			onEvent(player, kind)
		end
	end)
	OfficeComputerService.onSit(function(player)
		onEvent(player, "Computer")
	end)
	-- Cafés claimed before this service started.
	for _, plot in CollectionService:GetTagged(CafeCatalog.PLOT_TAG) do
		if plot:IsA("Model") and (plot:GetAttribute("CompanyId") or "") ~= "" then
			task.spawn(placeMentor, plot)
		end
	end

	-- /tutorial is TutorialService's command; café companies replay this tour with it too.
	task.spawn(function()
		local command = TextChatService:WaitForChild("TutorialCommand", 30)
		if command and command:IsA("TextChatCommand") then
			command.Triggered:Connect(function(source)
				local player = source and Players:GetPlayerByUserId(source.UserId)
				if player then
					restart(player)
				end
			end)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return Service
