-- Six compact harbour noticeboards, arranged in pairs around the plaza.
local Boards = {}
local LAYOUT_VERSION = 3
Boards.Definitions = {
	{ Id = "Level", Title = "HIGHEST LEVEL", Unit = "LEVEL", Weekly = false },
	{ Id = "WeeklyXP", Title = "MOST XP THIS WEEK", Unit = "XP", Weekly = true },
	{ Id = "Caught", Title = "MOST FISH CAUGHT", Unit = "FISH", Weekly = false },
	{ Id = "WeeklyCaught", Title = "FISH THIS WEEK", Unit = "FISH", Weekly = true },
	{ Id = "Earned", Title = "MOST MONEY EARNED", Unit = "$", Weekly = false },
	{ Id = "WeeklyEarned", Title = "MONEY THIS WEEK", Unit = "$", Weekly = true },
}

local cream = Color3.fromRGB(244, 234, 208)
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))
local gold = Theme.Colors.Text
local function styleBoard(gui)
	local backing = gui:FindFirstChild("BoardWindow") or Instance.new("Frame")
	backing.Name = "BoardWindow"
	backing.Position = UDim2.fromOffset(3, 3)
	backing.Size = UDim2.new(1, -6, 1, -6)
	backing.ZIndex = 0
	backing.Parent = gui
	Theme.window(backing)
	local money = gui.Parent:GetAttribute("LeaderboardId")
	for _, item in gui:GetDescendants() do
		if item:IsA("TextLabel") then
			Theme.text(
				item,
				if (money == "Earned" or money == "WeeklyEarned") and string.match(item.Name, "^Score")
					then Theme.Colors.Green
					else nil
			)
		end
	end
end

local function label(parent, name, text, x, y, width, height, size, color)
	local item = Instance.new("TextLabel")
	item.Name, item.Text = name, text
	item.Position, item.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(width, height)
	item.BackgroundTransparency = 1
	item.Font, item.TextSize = Enum.Font.GothamBold, size
	Theme.text(item, color)
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextTruncate = Enum.TextTruncate.AtEnd
	item.Parent = parent
	return item
end

function Boards.build(plaza: Model, pavingFrame: CFrame)
	local existing = plaza:FindFirstChild("Leaderboards")
	if existing and existing:GetAttribute("LayoutVersion") == LAYOUT_VERSION then
		for _, gui in existing:GetDescendants() do
			if gui:IsA("SurfaceGui") and gui.Name == "Leaderboard" then
				styleBoard(gui)
			end
		end
		return existing
	end
	-- Replace older layouts on baked maps as well as new maps.
	if existing then
		existing:Destroy()
	end
	local model = Instance.new("Model")
	model.Name, model.Parent = "Leaderboards", plaza
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("LayoutVersion", LAYOUT_VERSION)
	-- Three separated pairs face into the square. All six panels stand at the
	-- same readable height, with paths between pairs and no stacked displays.
	local placements = {
		{ 22, -28, math.pi },
		{ 34, -28, math.pi },
		{ 29, -6, math.pi / 2 },
		{ 29, 6, math.pi / 2 },
		-- Keep the money pair clear of Harbour Home's southwest corner and
		-- entrance, with room for the central path and southern promenade.
		{ 10, 40, 0 },
		{ 22, 40, 0 },
	}
	for index, definition in Boards.Definitions do
		local placement = placements[index]
		local frame = pavingFrame * CFrame.new(placement[1], 0, placement[2]) * CFrame.Angles(0, placement[3], 0)
		local function part(name, size, offset, color, material)
			local p = Instance.new("Part")
			p.Name, p.Size, p.CFrame = name, size, frame * CFrame.new(offset)
			p.Anchored, p.CanTouch = true, false
			p.Color, p.Material = color, material
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			p.Parent = model
			return p
		end
		for _, x in { -4.5, 4.5 } do
			part(
				"CedarPost",
				Vector3.new(0.35, 9.1, 0.5),
				Vector3.new(x, 4.55, 0),
				Color3.fromRGB(109, 77, 51),
				Enum.Material.Wood
			)
		end
		part("LimestoneCap", Vector3.new(9.6, 0.45, 1), Vector3.new(0, 9.1, 0), cream, Enum.Material.Limestone)
		local panel = part(
			definition.Id,
			Vector3.new(8.68, 7.28, 0.35),
			Vector3.new(0, 5.2, 0),
			Theme.Colors.Window,
			Enum.Material.Wood
		)
		panel:SetAttribute("LeaderboardId", definition.Id)
		local gui = Instance.new("SurfaceGui")
		gui.Name, gui.Face = "Leaderboard", Enum.NormalId.Front
		gui.SizingMode, gui.CanvasSize = Enum.SurfaceGuiSizingMode.FixedSize, Vector2.new(620, 520)
		gui.LightInfluence, gui.MaxDistance = 0, 110
		gui.Parent = panel
		styleBoard(gui)
		label(gui, "Title", definition.Title, 22, 12, 576, 36, 26, gold)
		label(
			gui,
			"Period",
			if definition.Weekly then "WEEKLY  /  MONDAY 00:00 UTC" else "ALL TIME  /  GLOBAL TOP 10",
			22,
			50,
			576,
			25,
			17
		)
		label(gui, "Columns", "#    ANGLER", 22, 88, 410, 26, 18, gold)
		local unit = label(gui, "Unit", definition.Unit, 432, 88, 166, 26, 18, gold)
		unit.TextXAlignment = Enum.TextXAlignment.Right
		local rows = Instance.new("Frame")
		rows.Name, rows.BackgroundTransparency = "Rows", 1
		rows.Position, rows.Size = UDim2.fromOffset(22, 121), UDim2.fromOffset(576, 340)
		rows.Parent = gui
		for rank = 1, 10 do
			label(
				rows,
				"Name" .. rank,
				string.format("%02d   —", rank),
				0,
				(rank - 1) * 34,
				402,
				32,
				22,
				Theme.Colors.Text
			)
			local score = label(rows, "Score" .. rank, "—", 408, (rank - 1) * 34, 168, 32, 22)
			Theme.text(score, if definition.Unit == "$" then Theme.Colors.Green else Theme.Colors.Text)
			score.TextXAlignment = Enum.TextXAlignment.Right
		end
		label(gui, "Status", "Loading rankings…", 22, 475, 576, 28, 18)
	end
	return model
end

function Boards.ensure(root: Instance)
	for _, plaza in root:GetDescendants() do
		if plaza:IsA("Model") and plaza.Name == "Plaza" then
			for _, slab in plaza:GetChildren() do
				if
					slab:IsA("BasePart")
					and slab.Size.X >= 115.9
					and slab.Size.X <= 120.1
					and math.abs(slab.Size.X - slab.Size.Z) < 0.01
					and slab.Size.Y <= 1
				then
					Boards.build(plaza, slab.CFrame * CFrame.new(0, slab.Size.Y / 2, 0))
					break
				end
			end
		end
	end
end

function Boards.render(root: Instance, id, entries, status)
	for _, panel in root:GetDescendants() do
		if panel:IsA("BasePart") and panel:GetAttribute("LeaderboardId") == id then
			local gui = panel:FindFirstChild("Leaderboard")
			if not gui then
				continue
			end
			for rank = 1, 10 do
				local entry = entries[rank]
				gui.Rows["Name" .. rank].Text = string.format("%02d   %s", rank, if entry then entry.Name else "—")
				gui.Rows["Score" .. rank].Text = if entry
					then (if id == "Earned" or id == "WeeklyEarned" then "$" else "") .. tostring(entry.Score)
					else "—"
			end
			gui.Status.Text = status
		end
	end
end

return Boards
