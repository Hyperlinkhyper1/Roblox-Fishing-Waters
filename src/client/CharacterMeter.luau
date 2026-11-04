-- Position slim screen-space meters beside the local avatar at any zoom.
local GuiService = game:GetService("GuiService")
local CharacterMeter = {}

function CharacterMeter.position(meter: Frame, player: Player, side: number): boolean
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not camera or not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local center, visible = camera:WorldToViewportPoint(root.Position + Vector3.new(0, 0.5, 0))
	local viewport = camera.ViewportSize
	local firstPerson = (camera.CFrame.Position - root.Position).Magnitude < 4
	if firstPerson then
		center = Vector3.new(viewport.X / 2, viewport.Y / 2, 1)
		visible = true
	end
	if not visible then
		return false
	end
	local edge = camera:WorldToViewportPoint(root.Position + camera.CFrame.RightVector * 2.7)
	local height = math.floor(math.min(180, viewport.Y * 0.28))
	local offset = if firstPerson then 76 else math.clamp(math.abs(edge.X - center.X), 64, 200)
	local margin = if side > 0 then 90 else 28
	local screenGui = meter:FindFirstAncestorOfClass("ScreenGui")
	local inset = if screenGui and not screenGui.IgnoreGuiInset then GuiService:GetGuiInset() else Vector2.zero
	meter.AnchorPoint = Vector2.new(0.5, 0.5)
	meter.Size = UDim2.fromOffset(14, height)
	meter.Position = UDim2.fromOffset(
		math.clamp(center.X + side * offset, margin, math.max(margin, viewport.X - margin)) - inset.X,
		math.clamp(center.Y, height / 2 + inset.Y + 20, math.max(height / 2 + inset.Y + 20, viewport.Y - height / 2 - 70)) - inset.Y
	)
	return true
end

return CharacterMeter
