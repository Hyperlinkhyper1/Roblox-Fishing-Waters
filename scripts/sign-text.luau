-- Actual builders and the production baked-map repair run on recording mocks.
local activeRoot
function workspace:FindFirstChild(name)
	return if name == "Map" then activeRoot else nil
end
Map.ensureSignText() -- An absent map is harmless.
local root = Instance.new("Folder")
root.Name = "Map"
activeRoot = root
local rng = Random.new(Biomes.Seed + 1)
local village = Instance.new("Model")
village.Name, village.Parent = "Village", root
Harbour.buildPlaza(village, shape.toWorld({ 870, 665 }), rng)
Harbour.buildBase(shape, root, 1, shape.toWorld({ 668, 1030 }), rng)
dependencies.Props.signpost(root, Vector3.zero, 0.7, { { "Harbour", 0 }, { "Village", 0.5 } })
dependencies.Mediterranean.townhouse(root, Vector3.zero, 0.7, rng, true)
local function proportional(gui)
	if gui.SizingMode == Enum.SurfaceGuiSizingMode.PixelsPerStud then
		return gui.PixelsPerStud > 0
	end
	local board = gui.Adornee or gui.Parent
	local width = if gui.Face == Enum.NormalId.Left or gui.Face == Enum.NormalId.Right then board.Size.Z else board.Size.X
	local height = if gui.Face == Enum.NormalId.Top or gui.Face == Enum.NormalId.Bottom then board.Size.Z else board.Size.Y
	return math.abs(gui.CanvasSize.X / gui.CanvasSize.Y / (width / height) - 1) < 0.001
end
local signs, fixed, dynamic = {}, 0, 0
for _, gui in root:GetDescendants() do
	if gui:IsA("SurfaceGui") then
		assert(proportional(gui), "Fresh sign stretches text: " .. gui:GetFullName())
		table.insert(signs, gui)
		if gui.SizingMode == Enum.SurfaceGuiSizingMode.FixedSize then fixed += 1 else dynamic += 1 end
	end
end
assert(fixed > 0 and dynamic > 10, "Builders did not exercise both canvas modes")
assert(root:FindFirstChild("FishingRodShop", true), "Missing tackle shop coverage")
assert(root:FindFirstChild("Drydock", true), "Missing drydock coverage")
assert(root:FindFirstChild("NameBoard", true), "Missing owner-name coverage")
assert(root:FindFirstChild("Signpost", true), "Missing directional sign coverage")
assert(root:FindFirstChild("Townhouse", true), "Missing village shop coverage")
-- Simulate old baked signs, including signs in shops whose layout is current.
local preserved, legacy = {}, {}
for _, gui in signs do
	if gui.SizingMode == Enum.SurfaceGuiSizingMode.FixedSize then
		table.insert(preserved, gui)
	else
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = Vector2.new(800, 600)
		table.insert(legacy, { gui = gui, density = gui.PixelsPerStud, text = gui:FindFirstChildWhichIsA("TextLabel").Text })
	end
end
-- Every physical face and an explicit Adornee must use the correct dimensions.
for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Top, Enum.NormalId.Bottom } do
	local board = Instance.new("Part")
	board.Size, board.Parent = Vector3.new(9, 2, 5), root
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.Parent = face, board
	local label = Instance.new("TextLabel")
	label.Text, label.Parent = "FACE TEST", gui
	table.insert(legacy, { gui = gui, density = 50, text = label.Text })
end
local adorned = Instance.new("SurfaceGui")
adorned.Parent = root
adorned.Adornee = Instance.new("Part")
adorned.Adornee.Size = Vector3.new(10, 2, 1)
local nested = Instance.new("Frame")
nested.Parent = adorned
Instance.new("TextLabel").Parent = nested
local nonText = Instance.new("SurfaceGui")
nonText.Parent = root
local before = #root:GetDescendants()
Map.ensureSignText()
for _, item in legacy do
	assert(proportional(item.gui), "Saved sign still stretches text: " .. item.gui:GetFullName())
	assert(item.gui.PixelsPerStud == item.density, "Repair changed sign resolution")
	assert(item.gui:FindFirstChildWhichIsA("TextLabel").Text == item.text, "Repair changed sign copy")
end
for _, gui in preserved do
	assert(gui.SizingMode == Enum.SurfaceGuiSizingMode.FixedSize and proportional(gui), "Correct padded canvas was changed")
end
assert(adorned.SizingMode == Enum.SurfaceGuiSizingMode.PixelsPerStud, "Nested text or Adornee was missed")
assert(nonText.SizingMode == Enum.SurfaceGuiSizingMode.FixedSize, "Non-text GUI was changed")
Map.ensureSignText()
assert(#root:GetDescendants() == before, "Repair rebuilt geometry or duplicated signs")
for _, gui in signs do assert(proportional(gui), "Second repair stretched a sign") end
print(string.format("PASS: %d production signs; fresh and baked canvases, six faces, Adornee, nested text, preserved padded signs and idempotency. Roblox rendering not exercised.", #signs))
