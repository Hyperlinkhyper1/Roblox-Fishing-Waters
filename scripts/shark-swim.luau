-- Exercise the real client animation with lightweight position/angle frames.
local Vector3 = {}
local vector = {}
function Vector3.new(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, vector) end
function vector.__sub(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
function vector.__index(a, key)
	if key == "Magnitude" then return math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z) end
end
local CFrame = {}
local frame = {}
frame.__index = frame
function CFrame.new(x, y, z)
	return setmetatable({ Position = Vector3.new(x or 0, y or 0, z or 0), yaw = 0 }, frame)
end
CFrame.identity = CFrame.new()
function CFrame.Angles(_, yaw) local result = CFrame.new(); result.yaw = yaw; return result end
function frame.__mul(a, b)
	local result = CFrame.new(a.Position.X + b.Position.X, a.Position.Y + b.Position.Y, a.Position.Z + b.Position.Z)
	result.yaw = a.yaw + b.yaw
	return result
end
function frame:Inverse() return CFrame.new(-self.Position.X, -self.Position.Y, -self.Position.Z) end
function frame:Lerp(other, alpha)
	local result = CFrame.new(self.Position.X + (other.Position.X - self.Position.X) * alpha,
		self.Position.Y + (other.Position.Y - self.Position.Y) * alpha,
		self.Position.Z + (other.Position.Z - self.Position.Z) * alpha)
	result.yaw = self.yaw + (other.yaw - self.yaw) * alpha
	return result
end
local function typeof(value) return if getmetatable(value) == frame then "CFrame" else type(value) end
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback) table.insert(callbacks, callback) end,
		fire = function(_, ...) for _, callback in callbacks do callback(...) end end,
	}
end
local render = signal()
local folder = { ChildAdded = signal(), ChildRemoved = signal(), children = {} }
function folder:GetChildren() return self.children end
local now = 0
local bulkMoves = 0
local Enum = { BulkMoveMode = { FireCFrameChanged = "FireCFrameChanged" } }
local workspace = { WaitForChild = function() return folder end, GetServerTimeNow = function() return now end }
function workspace:BulkMoveTo(parts, frames, mode)
	assert(#parts == #frames and mode == Enum.BulkMoveMode.FireCFrameChanged, "Pieces move in one bulk call")
	bulkMoves += 1
	for index, part in parts do part.CFrame = frames[index] end
end
local game = { GetService = function() return { RenderStepped = render } end }
local SharkSwim = (function()
-- SHARK_SWIM_SOURCE --
end)()
local model = { parts = {} }
function model:IsA(class) return class == "Model" end
function model:GetDescendants() return self.parts end
local function piece(offset, tail, flex)
	return {
		CFrame = CFrame.new(),
		IsA = function(_, class) return class == "BasePart" end,
		IsDescendantOf = function() return true end,
		GetAttribute = function(_, name)
			if name == "SwimOffset" then return offset end
			if name == "SwimTail" then return tail end
			if name == "SwimFlex" then return flex end
		end,
	}
end
local root = piece(nil, false)
local body = piece(CFrame.new(0, -1, 0), false)
local tail = piece(CFrame.new(0, -1, 5), true)
local hips = piece(CFrame.new(0, -1, 2.5), false, true)
model.PrimaryPart = root
model.parts = { root, body, hips, tail }
folder.children = { model }
SharkSwim.start()
render:fire(1 / 60)
local initialTailYaw, initialHipYaw = tail.CFrame.yaw, hips.CFrame.yaw
assert(bulkMoves == 1, "Every visible piece moves in a single bulk call per frame")
assert(root.CFrame.Position.X == 0, "Animation must not change the authoritative root")
root.CFrame = CFrame.new(10, 0, 0)
now += 1 / 60
render:fire(1 / 60)
assert(body.CFrame.Position.X > 0 and body.CFrame.Position.X < 10, "Visual position should interpolate between updates")
assert(root.CFrame.Position.X == 10, "Interpolation must leave the root unchanged")
assert(tail.CFrame.yaw ~= initialTailYaw, "Tail should animate over time")
assert(hips.CFrame.yaw ~= initialHipYaw, "The rear body should flex over time")
assert(hips.CFrame.yaw ~= body.CFrame.yaw and tail.CFrame.yaw ~= hips.CFrame.yaw, "Each joint bends on its own")
local streamedPart = piece(CFrame.new(0, -2, 1), false)
table.insert(model.parts, streamedPart)
now += 0.6
render:fire(1 / 60)
assert(streamedPart.CFrame.Position.Y == -2, "Late streamed parts should be discovered")
folder.ChildRemoved:fire(model)
local previous = body.CFrame
root.CFrame = CFrame.new(20, 0, 0)
local movesBefore = bulkMoves
render:fire(1 / 60)
assert(body.CFrame == previous and bulkMoves == movesBefore, "Removed sharks must stop receiving animation updates")
print("Shark swimming: interpolation, root authority, body wave, bulk moves and streaming checks passed.")
