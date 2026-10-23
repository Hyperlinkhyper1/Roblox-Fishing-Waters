-- Shared by startup and gameplay UI. Kept in ReplicatedFirst so loading never
-- waits for the world or ReplicatedStorage before drawing its first frame.
local Theme = {}

Theme.Colors = {
	Window = Color3.fromRGB(51, 51, 51),
	Panel = Color3.fromRGB(62, 62, 62),
	Inset = Color3.fromRGB(29, 29, 29),
	Border = Color3.fromRGB(151, 151, 151),
	Text = Color3.fromRGB(245, 245, 245),
	Muted = Color3.fromRGB(215, 215, 215),
	Blue = Color3.fromRGB(56, 133, 193),
	Green = Color3.fromRGB(111, 202, 125),
	Black = Color3.fromRGB(0, 0, 0),
}

local finishes = {
	Normal = { Color3.fromRGB(147, 147, 147), Color3.fromRGB(87, 87, 87) },
	Selected = { Color3.fromRGB(82, 163, 229), Color3.fromRGB(39, 88, 128) },
	Danger = { Color3.fromRGB(238, 107, 111), Color3.fromRGB(131, 58, 61) },
	Disabled = { Color3.fromRGB(85, 85, 85), Color3.fromRGB(58, 58, 58) },
}

local function component(parent: Instance, class: string, name: string): any
	local item = parent:FindFirstChild(name)
	if not item then
		item = Instance.new(class)
		item.Name = name
		item.Parent = parent
	end
	return item
end

function Theme.corner(item: GuiObject, radius: number)
	local corner = item:FindFirstChildOfClass("UICorner") or component(item, "UICorner", "ThemeCorner")
	corner.CornerRadius = UDim.new(0, radius)
end

function Theme.text(item: any, color: Color3?)
	item.Font = Enum.Font.GothamBold
	item.TextColor3 = color or Theme.Colors.Text
	item.TextStrokeColor3 = Theme.Colors.Black
	item.TextStrokeTransparency = 0
end

function Theme.panel(item: GuiObject, inset: boolean?, radius: number?)
	item.BackgroundColor3 = if inset then Theme.Colors.Inset else Theme.Colors.Panel
	item.BackgroundTransparency = 0
	item.BorderSizePixel = 0
	Theme.corner(item, radius or 2)
	local border = component(item, "UIStroke", "ThemeBorder")
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Color = Theme.Colors.Border
	border.Thickness = 1
	border.Transparency = 0.35
end

-- Reapplying a state updates the existing finish, so tab changes and replicated
-- inventory updates cannot leave a stale gold fill or create duplicate strokes.
function Theme.button(item: TextButton, state: string?)
	local finish = finishes[state or "Normal"] or finishes.Normal
	Theme.panel(item, false, 10)
	item.BackgroundColor3 = finish[2]
	-- A gradient on the TextButton itself would also tint its text and outline.
	-- Keep the face and caption separate, while retaining native button input/Text.
	local face = component(item, "Frame", "ThemeFace")
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.BorderSizePixel = 0
	face.Active = false
	Theme.corner(face, 10)
	local gradient = component(face, "UIGradient", "ThemeFinish")
	gradient.Rotation = 90
	if face:GetAttribute("Finish") ~= (state or "Normal") then
		gradient.Color = ColorSequence.new(finish[1], finish[2])
		face:SetAttribute("Finish", state or "Normal")
	end
	local caption = item:FindFirstChild("ThemeCaption")
	if not caption then
		caption = component(item, "TextLabel", "ThemeCaption")
		caption.BackgroundTransparency = 1
		caption.Size = UDim2.new(1, -8, 1, -4)
		caption.Position = UDim2.fromOffset(4, 2)
		caption.Active = false
		local function sync()
			for _, property in
				{
					"Text",
					"TextSize",
					"TextWrapped",
					"TextScaled",
					"TextXAlignment",
					"TextYAlignment",
					"RichText",
					"TextTruncate",
				}
			do
				caption[property] = item[property]
			end
			face.ZIndex = item.ZIndex
			caption.ZIndex = item.ZIndex + 1
		end
		for _, property in
			{
				"Text",
				"TextSize",
				"TextWrapped",
				"TextScaled",
				"TextXAlignment",
				"TextYAlignment",
				"RichText",
				"TextTruncate",
				"ZIndex",
			}
		do
			item:GetPropertyChangedSignal(property):Connect(sync)
		end
		sync()
	end
	Theme.text(caption, if state == "Disabled" then Theme.Colors.Muted else Theme.Colors.Text)
	item.TextTransparency = 1
	item.TextStrokeTransparency = 1
	local border = component(item, "UIStroke", "ThemeBorder")
	border.Transparency = 0
	item.AutoButtonColor = state ~= "Disabled"
end

function Theme.window(item: GuiObject)
	Theme.panel(item, false, 12)
	item.BackgroundColor3 = Theme.Colors.Window
	local border = component(item, "UIStroke", "ThemeBorder")
	border.Thickness = 2
	border.Transparency = 0
	local rim = component(item, "Frame", "ThemeInnerRim")
	rim.Position = UDim2.fromOffset(6, 6)
	rim.Size = UDim2.new(1, -12, 1, -12)
	rim.BackgroundTransparency = 1
	rim.BorderSizePixel = 0
	Theme.corner(rim, 8)
	local line = component(rim, "UIStroke", "ThemeBorder")
	line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	line.Color = Theme.Colors.Border
	line.Thickness = 1
	line.Transparency = 0.25
	for index, point in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		local bolt = component(item, "Frame", "ThemeBolt" .. index)
		bolt.AnchorPoint = point
		bolt.Position = UDim2.new(point.X, if point.X == 0 then 6 else -6, point.Y, if point.Y == 0 then 6 else -6)
		bolt.Size = UDim2.fromOffset(6, 6)
		bolt.BackgroundColor3 = Theme.Colors.Border
		bolt.BorderSizePixel = 0
		Theme.corner(bolt, 3)
	end
end

function Theme.scroll(item: ScrollingFrame)
	item.ScrollBarThickness = 10
	item.ScrollBarImageColor3 = Theme.Colors.Inset
	item.ScrollBarImageTransparency = 0
	item.BorderSizePixel = 0
end

return Theme
