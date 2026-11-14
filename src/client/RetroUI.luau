-- Widgets for the office PC's screen (OfficeComputer, StockApp). Everything is drawn on an
-- 800x600 canvas (a ScreenGui laid over the glass) in six colours, so meaning is carried by text,
-- arrows and inverse video rather than hue. The colours, fonts, phosphor bloom and scanlines
-- come from the monitor the company bought at Micro Harbour (Shared.TechCatalog): `applyScreen`
-- swaps them in before the screen is built. The default is the green MONOCHROME 14 tube.
local TweenService = game:GetService("TweenService")

local RetroUI = {}

local rgb = Color3.fromRGB
RetroUI.Colors = {
	Screen = rgb(4, 12, 7), -- unlit tube
	Panel = rgb(8, 24, 13),
	Dim = rgb(28, 82, 44), -- borders, grid lines (decoration only)
	Mid = rgb(78, 184, 104), -- secondary text
	Bright = rgb(110, 255, 140), -- primary text (the monitor's phosphor)
	Hot = rgb(205, 255, 214), -- emphasis
}
RetroUI.Fonts = {
	Title = Enum.Font.Arcade,
	Body = Enum.Font.Code,
}
RetroUI.WIDTH, RetroUI.HEIGHT = 800, 600
-- Bloom: text stroke transparency (1 = crisp). Scanlines/Rim: darkness, or nil for none.
RetroUI.Style = { Bloom = 0.88, Scanlines = 0.82 :: number?, Rim = 0.55 :: number? }

-- Takes on a monitor's look (a TechCatalog item's Screen). Widgets read these as they are built,
-- so call it before building the screen.
function RetroUI.applyScreen(screen: { [string]: any })
	for _, key in { "Screen", "Panel", "Dim", "Mid", "Bright", "Hot" } do
		RetroUI.Colors[key] = screen[key]
	end
	RetroUI.Fonts.Title, RetroUI.Fonts.Body = screen.Title, screen.Body
	RetroUI.Style.Bloom, RetroUI.Style.Scanlines, RetroUI.Style.Rim = screen.Bloom, screen.Scanlines, screen.Rim
end

local FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function apply(item: Instance, props: { [string]: any }?)
	if props then
		for key, value in props do
			(item :: any)[key] = value
		end
	end
	return item
end

function RetroUI.frame(parent: Instance, name: string, position: UDim2, size: UDim2, props: { [string]: any }?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = RetroUI.Colors.Screen
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Position = position
	frame.Size = size
	apply(frame, props)
	frame.Parent = parent
	return frame
end

function RetroUI.border(item: GuiObject, color: Color3?, thickness: number?): UIStroke
	local stroke = item:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color or RetroUI.Colors.Bright
	stroke.Thickness = thickness or 2
	stroke.Parent = item
	return stroke
end

export type TextOptions = {
	Size: number?,
	Color: Color3?,
	Font: Enum.Font?,
	AlignX: Enum.TextXAlignment?,
	AlignY: Enum.TextYAlignment?,
	Wrap: boolean?,
}

function RetroUI.text(
	parent: Instance,
	name: string,
	text: string,
	position: UDim2,
	size: UDim2,
	options: TextOptions?
): TextLabel
	local opts = options or {}
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Position = position
	label.Size = size
	label.Font = opts.Font or RetroUI.Fonts.Body
	label.Text = text
	label.TextSize = opts.Size or 20
	label.TextColor3 = opts.Color or RetroUI.Colors.Bright
	label.TextXAlignment = opts.AlignX or Enum.TextXAlignment.Left
	label.TextYAlignment = opts.AlignY or Enum.TextYAlignment.Center
	label.TextWrapped = opts.Wrap == true
	label.TextTruncate = if opts.Wrap then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd
	-- A faint same-colour stroke reads as phosphor bloom.
	label.TextStrokeColor3 = label.TextColor3
	label.TextStrokeTransparency = RetroUI.Style.Bloom
	label.Parent = parent
	return label
end

function RetroUI.setColor(label: TextLabel | TextButton | TextBox, color: Color3)
	label.TextColor3 = color
	label.TextStrokeColor3 = color
end

----------------------------------------------------------------------------------------------------
-- Hover. Roblox's MouseEnter/MouseLeave miss quick moves (rows stay lit after the pointer has
-- gone) and never fire for rows rebuilt under a still pointer, so OfficeComputer works out what is
-- under the drawn pointer every frame and calls `setHovered`; widgets register with `hover`.

local hoverables: { [GuiObject]: (boolean) -> () } = setmetatable({}, { __mode = "k" }) :: any
-- Pointer and scanline frames sit on top of everything but must never catch the pointer.
local passThrough: { [GuiObject]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local hovered: GuiObject? = nil

function RetroUI.hover(item: GuiObject, paint: (boolean) -> ())
	hoverables[item] = paint
end

function RetroUI.ignoreHover(item: GuiObject)
	passThrough[item] = true
end

function RetroUI.setHovered(item: GuiObject?)
	if item == hovered then
		return
	end
	local old = hovered
	hovered = item
	if old and hoverables[old] then
		hoverables[old](false)
	end
	if item and hoverables[item] then
		hoverables[item](true)
	end
end

local function outside(gui: GuiObject, point: Vector2): boolean
	local low = gui.AbsolutePosition
	local high = low + gui.AbsoluteSize
	return point.X < low.X or point.Y < low.Y or point.X >= high.X or point.Y >= high.Y
end

-- The widget the pointer is over: walks PlayerGui:GetGuiObjectsAtPosition's results (top-most
-- first) and stops at the first thing that would catch a click or hides what is behind it.
-- `point` is in the same GUI space as AbsolutePosition.
function RetroUI.hoverTarget(objects: { GuiObject }, point: Vector2): GuiObject?
	for _, object in objects do
		if passThrough[object] then
			continue
		end
		local found: GuiObject? = nil
		local clipped = false
		local node: Instance? = object
		while node and node:IsA("GuiObject") do
			local gui = node :: GuiObject
			if not found and hoverables[gui] then
				found = gui
			end
			if gui ~= object and gui.ClipsDescendants and outside(gui, point) then
				clipped = true -- scrolled out of its list
				break
			end
			node = node.Parent
		end
		if not clipped then
			if found then
				return found
			end
			if object.Active or object.BackgroundTransparency < 1 then
				return nil
			end
		end
	end
	return nil
end

export type Button = {
	Instance: TextButton,
	setEnabled: (Button, boolean) -> (),
	setSelected: (Button, boolean) -> (),
	setText: (Button, string) -> (),
}

-- A bordered phosphor button: inverse video on hover/selection, a bright flash on press.
function RetroUI.button(
	parent: Instance,
	name: string,
	text: string,
	position: UDim2,
	size: UDim2,
	onClick: () -> (),
	options: TextOptions?
): Button
	local opts = options or {}
	local item = Instance.new("TextButton")
	item.Name = name
	item.AutoButtonColor = false
	item.BackgroundColor3 = RetroUI.Colors.Bright
	item.BackgroundTransparency = 1
	item.BorderSizePixel = 0
	item.Position = position
	item.Size = size
	item.Font = opts.Font or RetroUI.Fonts.Body
	item.Text = text
	item.TextSize = opts.Size or 20
	item.TextXAlignment = opts.AlignX or Enum.TextXAlignment.Center
	item.TextTruncate = Enum.TextTruncate.AtEnd
	item.Parent = parent
	local stroke = RetroUI.border(item, RetroUI.Colors.Bright, 2)

	local enabled, selected, hovered = true, false, false
	local function paint()
		local inverse = enabled and (selected or hovered)
		item.BackgroundTransparency = if inverse then 0 else 1
		item.BackgroundColor3 = if hovered and not selected then RetroUI.Colors.Hot else RetroUI.Colors.Bright
		local color = if not enabled
			then RetroUI.Colors.Dim
			elseif inverse then RetroUI.Colors.Screen
			else RetroUI.Colors.Bright
		RetroUI.setColor(item, color)
		item.TextStrokeTransparency = if inverse then 1 else RetroUI.Style.Bloom
		stroke.Color = if enabled then RetroUI.Colors.Bright else RetroUI.Colors.Dim
	end
	RetroUI.hover(item, function(value)
		hovered = value
		paint()
	end)
	-- Light up the moment the button goes down; the action itself runs on release.
	item.MouseButton1Down:Connect(function()
		if not enabled then
			return
		end
		item.BackgroundColor3 = RetroUI.Colors.Hot
		item.BackgroundTransparency = 0
		RetroUI.setColor(item, RetroUI.Colors.Screen)
		item.TextStrokeTransparency = 1
	end)
	item.MouseButton1Up:Connect(paint)
	item.Activated:Connect(function()
		if not enabled then
			return
		end
		item.BackgroundColor3 = RetroUI.Colors.Hot
		item.BackgroundTransparency = 0
		TweenService:Create(item, FAST, { BackgroundTransparency = if selected or hovered then 0 else 1 }):Play()
		onClick()
	end)
	paint()

	local button = { Instance = item }
	function button.setEnabled(_, value: boolean)
		enabled = value
		item.Active = value
		paint()
	end
	function button.setSelected(_, value: boolean)
		selected = value
		paint()
	end
	function button.setText(_, value: string)
		item.Text = value
	end
	return (button :: any) :: Button
end

function RetroUI.input(parent: Instance, name: string, position: UDim2, size: UDim2, text: string): TextBox
	local box = Instance.new("TextBox")
	box.Name = name
	box.BackgroundColor3 = RetroUI.Colors.Panel
	box.BackgroundTransparency = 0
	box.BorderSizePixel = 0
	box.Position = position
	box.Size = size
	box.ClearTextOnFocus = false
	box.Font = RetroUI.Fonts.Body
	box.Text = text
	box.TextSize = 22
	box.PlaceholderColor3 = RetroUI.Colors.Dim
	RetroUI.setColor(box, RetroUI.Colors.Hot)
	box.TextStrokeTransparency = RetroUI.Style.Bloom
	box.Parent = parent
	RetroUI.border(box, RetroUI.Colors.Mid, 2)
	return box
end

function RetroUI.rule(parent: Instance, name: string, position: UDim2, width: UDim, color: Color3?): Frame
	return RetroUI.frame(parent, name, position, UDim2.new(width, UDim.new(0, 2)), {
		BackgroundTransparency = 0,
		BackgroundColor3 = color or RetroUI.Colors.Dim,
	})
end

-- Faint horizontal scanlines and a darker rim, laid over the whole canvas (as dark as the
-- monitor's Style says; flat panels have neither).
function RetroUI.scanlines(parent: Instance): Frame
	local overlay = RetroUI.frame(parent, "Scanlines", UDim2.new(), UDim2.fromScale(1, 1), { ZIndex = 50 })
	overlay.Active = false
	local lines, rim = RetroUI.Style.Scanlines, RetroUI.Style.Rim
	if lines then
		for y = 0, RetroUI.HEIGHT - 1, 4 do
			RetroUI.frame(overlay, "Line", UDim2.fromOffset(0, y), UDim2.new(1, 0, 0, 1), {
				BackgroundTransparency = lines,
				BackgroundColor3 = Color3.new(0, 0, 0),
				ZIndex = 50,
			})
		end
	end
	if rim then
		local vignette = RetroUI.frame(overlay, "Rim", UDim2.new(), UDim2.fromScale(1, 1), {
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.new(0, 0, 0),
			ZIndex = 51,
		})
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, rim),
			NumberSequenceKeypoint.new(0.12, 1),
			NumberSequenceKeypoint.new(0.88, 1),
			NumberSequenceKeypoint.new(1, rim),
		})
		gradient.Parent = vignette
	end
	passThrough[overlay] = true
	for _, item in overlay:GetDescendants() do
		if item:IsA("GuiObject") then
			passThrough[item] = true
		end
	end
	return overlay
end

-- Pixel-art mouse pointer: rows of a classic arrow, X outline and O phosphor fill.
local ARROW = {
	"X...........",
	"XX..........",
	"XOX.........",
	"XOOX........",
	"XOOOX.......",
	"XOOOOX......",
	"XOOOOOX.....",
	"XOOOOOOX....",
	"XOOOOOOOX...",
	"XOOOOOOOOX..",
	"XOOOOOXXXXX.",
	"XOOXOOX.....",
	"XOX.XOOX....",
	"XX..XOOX....",
	"X....XOOX...",
	".....XOOX...",
	"......XX....",
}

function RetroUI.cursor(parent: Instance, pixel: number): Frame
	local holder = RetroUI.frame(parent, "Cursor", UDim2.new(), UDim2.fromOffset(12 * pixel, #ARROW * pixel), {
		ZIndex = 100,
	})
	holder.Active = false
	for row, line in ARROW do
		-- One frame per run of the same pixel kind keeps the arrow to a few dozen frames.
		local col = 1
		while col <= #line do
			local kind = line:sub(col, col)
			local stop = col
			while stop < #line and line:sub(stop + 1, stop + 1) == kind do
				stop += 1
			end
			if kind ~= "." then
				RetroUI.frame(
					holder,
					"Px",
					UDim2.fromOffset((col - 1) * pixel, (row - 1) * pixel),
					UDim2.fromOffset((stop - col + 1) * pixel, pixel),
					{
						BackgroundTransparency = 0,
						BackgroundColor3 = if kind == "X" then RetroUI.Colors.Screen else RetroUI.Colors.Hot,
						ZIndex = 100,
					}
				)
			end
			col = stop + 1
		end
	end
	passThrough[holder] = true
	for _, item in holder:GetChildren() do
		passThrough[item :: GuiObject] = true
	end
	return holder
end

export type Chart = {
	Instance: Frame,
	set: (Chart, { number }) -> (number?, number?),
}

-- Line chart with a faint area fill and four grid lines. `set` redraws and returns the low/high.
function RetroUI.chart(parent: Instance, name: string, position: UDim2, size: Vector2): Chart
	local holder = RetroUI.frame(parent, name, position, UDim2.fromOffset(size.X, size.Y), {
		ClipsDescendants = true,
	})
	RetroUI.border(holder, RetroUI.Colors.Dim, 2)
	for index = 1, 3 do
		RetroUI.frame(holder, "Grid", UDim2.fromOffset(0, math.floor(size.Y * index / 4)), UDim2.new(1, 0, 0, 1), {
			BackgroundTransparency = 0.4,
			BackgroundColor3 = RetroUI.Colors.Dim,
		})
	end
	local bars: { Frame } = {}
	local segments: { Frame } = {}
	local empty = RetroUI.text(holder, "Empty", "LOADING...", UDim2.new(), UDim2.fromScale(1, 1), {
		AlignX = Enum.TextXAlignment.Center,
		Color = RetroUI.Colors.Mid,
		Size = 18,
	})

	local chart = { Instance = holder }
	function chart.set(_, points: { number }): (number?, number?)
		local count = #points
		empty.Visible = count < 2
		if count < 2 then
			for _, item in segments do
				item.Visible = false
			end
			for _, item in bars do
				item.Visible = false
			end
			return nil, nil
		end
		local low, high = math.huge, -math.huge
		for _, value in points do
			low, high = math.min(low, value), math.max(high, value)
		end
		local span = math.max(high - low, high * 0.002, 0.01)
		local pad = 10
		local function at(index: number): Vector2
			local x = (index - 1) / (count - 1) * (size.X - 4) + 2
			local y = pad + (1 - (points[index] - low) / span) * (size.Y - pad * 2)
			return Vector2.new(x, y)
		end
		local step = (size.X - 4) / (count - 1)
		for index = 1, count do
			local point = at(index)
			local bar = bars[index]
			if not bar then
				bar = RetroUI.frame(holder, "Fill", UDim2.new(), UDim2.new(), {
					BackgroundTransparency = 0.86,
					BackgroundColor3 = RetroUI.Colors.Bright,
				})
				bars[index] = bar
			end
			bar.Visible = true
			bar.Position = UDim2.fromOffset(point.X - step / 2, point.Y)
			bar.Size = UDim2.fromOffset(math.ceil(step) + 1, size.Y - point.Y)
			if index < count then
				local nextPoint = at(index + 1)
				local delta = nextPoint - point
				local segment = segments[index]
				if not segment then
					segment = RetroUI.frame(holder, "Line", UDim2.new(), UDim2.new(), {
						BackgroundTransparency = 0,
						BackgroundColor3 = RetroUI.Colors.Bright,
						AnchorPoint = Vector2.new(0.5, 0.5),
						ZIndex = 2,
					})
					segments[index] = segment
				end
				segment.Visible = true
				local middle = (point + nextPoint) / 2
				segment.Position = UDim2.fromOffset(middle.X, middle.Y)
				segment.Size = UDim2.fromOffset(delta.Magnitude + 1, 2)
				segment.Rotation = math.deg(math.atan2(delta.Y, delta.X))
			end
		end
		for index = count + 1, #bars do
			bars[index].Visible = false
		end
		for index = count, #segments do
			segments[index].Visible = false
		end
		return low, high
	end
	return (chart :: any) :: Chart
end

return RetroUI
