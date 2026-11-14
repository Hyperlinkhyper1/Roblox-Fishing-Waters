-- The ballot and the division banner.
--
-- A booth in the parliament's Polling Station (prompts tagged Layout.BallotTag) opens the ballot:
-- the parties, their leaders and the policy each would bring in, with one vote per angler
-- per election. ElectionService checks and counts the vote; this only shows what it says.
-- The banner along the top follows the division bell while you are inside the building.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Layout = require(ReplicatedStorage.Shared.ParliamentLayout)
local Parties = require(ReplicatedStorage.Shared.Parties)
local Parliament = require(script.Parent.Parliament)
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))

local Ballot = {}
local started = false
local WIDTH, HEIGHT, ROW = 560, 620, 78

local function make(class, parent, properties)
	local item = Instance.new(class)
	for key, value in properties do
		item[key] = value
	end
	item.Parent = parent
	return item
end

local function label(parent, text, size, properties)
	local item = make("TextLabel", parent, {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	Theme.text(item)
	for key, value in properties do
		item[key] = value
	end
	return item
end

function Ballot.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), {
		Name = "ParliamentBallot",
		ResetOnSpawn = false,
		DisplayOrder = 29,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	-- The division banner.
	local banner = make("Frame", gui, {
		Name = "DivisionBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(520, 64),
		Visible = false,
	})
	Theme.panel(banner, true, 10)
	local bannerTitle = label(banner, "", 18, {
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -28, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local bannerDetail = label(banner, "", 14, {
		Position = UDim2.fromOffset(14, 32),
		Size = UDim2.new(1, -28, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Colors.Muted,
	})
	local bannerToken = 0
	Parliament.onDivision(function(phase, motion)
		bannerToken += 1
		local token = bannerToken
		if phase == "Over" or not motion then
			banner.Visible = false
			return
		end
		banner.Visible = true
		if phase == "Ring" or phase == "Bell" then
			bannerTitle.Text = "DIVISION BELL"
			bannerDetail.Text = motion.Title .. "  ·  members are on their way to the chamber"
		elseif phase == "Vote" then
			bannerTitle.Text = "THE HOUSE IS VOTING"
			bannerDetail.Text = motion.Title
		else
			bannerTitle.Text = if motion.Adopted then "CARRIED" else "REJECTED"
			bannerDetail.Text = string.format("%s  ·  ayes %d, noes %d", motion.Title, motion.For, motion.Against)
			task.delay(12, function()
				if bannerToken == token then
					banner.Visible = false
				end
			end)
		end
	end)

	-- The ballot.
	local overlay = make("TextButton", gui, {
		Name = "Ballot",
		Size = UDim2.fromScale(1, 1),
		Text = "",
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.35,
		Visible = false,
		AutoButtonColor = false,
		Modal = true,
	})
	local card = make("Frame", overlay, {
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
	})
	Theme.window(card)
	local scale = make("UIScale", card, {})
	label(card, "BALLOT  ·  General Election", 22, {
		Position = UDim2.fromOffset(22, 18),
		Size = UDim2.new(1, -90, 0, 28),
	})
	local status = label(card, "", 14, {
		Position = UDim2.fromOffset(22, 48),
		Size = UDim2.new(1, -44, 0, 36),
		TextColor3 = Theme.Colors.Muted,
	})
	local close = make("TextButton", card, {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(40, 34),
		Text = "X",
		TextSize = 18,
	})
	Theme.button(close, "Danger")
	local list = make("Frame", card, {
		Name = "Parties",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 90),
		Size = UDim2.new(1, -36, 0, #Parties.List * (ROW + 6)),
	})
	local message = label(card, "", 14, {
		Position = UDim2.new(0, 22, 1, -44),
		Size = UDim2.new(1, -44, 0, 32),
	})

	local remote: RemoteFunction? = nil
	local function request(action: string, value: any?)
		if not remote then
			local folder = ReplicatedStorage:WaitForChild("Election", 10)
			local found = folder and folder:WaitForChild("Request", 10)
			remote = if found and found:IsA("RemoteFunction") then found else nil
		end
		if not remote then
			return { Ok = false, Message = "The polling station is not ready yet. Try again in a moment." }
		end
		local ok, result = pcall(remote.InvokeServer, remote, action, value)
		if not ok or type(result) ~= "table" then
			return { Ok = false, Message = "The polling station didn't answer. Try again." }
		end
		return result
	end

	local buttons: { [string]: TextButton } = {}
	local shares: { [string]: TextLabel } = {}
	local busy = false
	local render: (any) -> ()

	local function vote(partyId: string)
		if busy then
			return
		end
		busy = true
		message.Text = "Casting your vote..."
		local result = request("Vote", partyId)
		busy = false
		render(result)
	end

	for index, party in Parties.List do
		local row = make("Frame", list, {
			Name = party.Id,
			Position = UDim2.fromOffset(0, (index - 1) * (ROW + 6)),
			Size = UDim2.new(1, 0, 0, ROW),
		})
		Theme.panel(row, false, 8)
		local chip = make("Frame", row, {
			BackgroundColor3 = party.Color,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(10, ROW - 16),
		})
		Theme.corner(chip, 4)
		label(row, party.Name, 17, {
			Position = UDim2.fromOffset(28, 6),
			Size = UDim2.new(1, -170, 0, 22),
		})
		label(row, party.Leader .. "  ·  \"" .. party.Slogan .. "\"", 13, {
			Position = UDim2.fromOffset(28, 29),
			Size = UDim2.new(1, -170, 0, 18),
			TextColor3 = Theme.Colors.Muted,
		})
		label(row, party.Policy.Name .. ": " .. party.Policy.Text, 13, {
			Position = UDim2.fromOffset(28, 50),
			Size = UDim2.new(1, -170, 0, 20),
			TextColor3 = Theme.Colors.Green,
		})
		shares[party.Id] = label(row, "", 12, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 6),
			Size = UDim2.fromOffset(120, 16),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Theme.Colors.Muted,
		})
		local button = make("TextButton", row, {
			Name = "Vote",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -10, 1, -8),
			Size = UDim2.fromOffset(120, 38),
			Text = "Vote",
			TextSize = 16,
		})
		Theme.button(button)
		button.Activated:Connect(function()
			if button:GetAttribute("CanVote") then
				vote(party.Id)
			end
		end)
		buttons[party.Id] = button
	end

	render = function(result)
		local state = result.State
		if type(state) ~= "table" then
			status.Text = "The polling station is closed for a moment."
			message.Text = tostring(result.Message or "")
			for _, button in buttons do
				button:SetAttribute("CanVote", false)
				button.Text = "Vote"
				Theme.button(button, "Disabled")
			end
			return
		end
		local line = Parties.statusLine(state.Elapsed)
		local office = state.Governing and Parties.ById[state.Governing]
		status.Text = line
			.. "\n"
			.. (if office then "In office: " .. office.Name .. " (" .. office.Policy.Text .. ")" else "No party is in office yet.")
		local total = Parties.total(state.Votes)
		for _, party in Parties.List do
			local button = buttons[party.Id]
			local mine = state.MyVote == party.Id
			local canVote = state.PollsOpen and state.MyVote == nil
			button:SetAttribute("CanVote", canVote)
			button.Text = if mine then "Your vote" else "Vote"
			Theme.button(button, if mine then "Selected" elseif canVote then "Normal" else "Disabled")
			local count = state.Votes[party.Id] or 0
			shares[party.Id].Text = if state.PollsOpen and total > 0
				then string.format("%d%%  ·  %d votes", math.floor(count / total * 100 + 0.5), count)
				else ""
		end
		if result.Message and result.Message ~= "" then
			message.Text = result.Message
		elseif state.MyVote then
			message.Text = "You voted for " .. Parties.ById[state.MyVote].Name .. " in this election."
		elseif state.PollsOpen then
			message.Text = "Choose one party. The party with the most votes on every server governs for four years."
		else
			message.Text = "The polls are closed. Come back when they open."
		end
	end

	local function open()
		overlay.Visible = true
		message.Text = "Opening the ballot..."
		task.spawn(function()
			render(request("State"))
		end)
	end
	close.Activated:Connect(function()
		overlay.Visible = false
	end)
	overlay.Activated:Connect(function()
		overlay.Visible = false
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then
			overlay.Visible = false
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		local holder = prompt.Parent
		if not holder or not CollectionService:HasTag(holder, Layout.BallotTag) or (who and who ~= player) then
			return
		end
		local camera = workspace.CurrentCamera
		if camera then
			local viewport = camera.ViewportSize
			scale.Scale = math.min(1, (viewport.X - 24) / WIDTH, (viewport.Y - 32) / HEIGHT)
		end
		open()
	end)
end
return Ballot
