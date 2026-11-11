-- Exercise the real client animation with full rotation-matrix CFrames: the
-- travelling body wave, speed-driven tail beat, banking, the jaw and streaming.
local Vector3 = {}
local vector = {}
function Vector3.new(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vector) end
function vector.__add(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
function vector.__sub(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
function vector.__mul(a, b) return Vector3.new(a.X * b, a.Y * b, a.Z * b) end
local methods = {}
function methods.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function methods.Cross(a, b) return Vector3.new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
function vector.__index(a, key)
	if key == "Magnitude" then return math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z) end
	if key == "Unit" then local m = a.Magnitude; return Vector3.new(a.X / m, a.Y / m, a.Z / m) end
	return methods[key]
end

-- CFrame: position plus right/up/back column vectors (Roblox's X, Y, Z axes).
local CFrame = {}
local frame = {}
local function make(p, x, y, z) return setmetatable({ Position = p, x = x, y = y, z = z }, frame) end
local function rotate(c, v) return c.x * v.X + c.y * v.Y + c.z * v.Z end
function CFrame.new(x, y, z)
	return make(Vector3.new(x, y, z), Vector3.new(1, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1))
end
CFrame.identity = CFrame.new()
local function axis(kind, t)
	local c, s = math.cos(t), math.sin(t)
	local o = Vector3.new()
	if kind == "x" then return make(o, Vector3.new(1, 0, 0), Vector3.new(0, c, s), Vector3.new(0, -s, c)) end
	if kind == "y" then return make(o, Vector3.new(c, 0, -s), Vector3.new(0, 1, 0), Vector3.new(s, 0, c)) end
	return make(o, Vector3.new(c, s, 0), Vector3.new(-s, c, 0), Vector3.new(0, 0, 1))
end
function CFrame.Angles(rx, ry, rz) return axis("x", rx) * axis("y", ry) * axis("z", rz) end
function frame.__mul(a, b)
	return make(a.Position + rotate(a, b.Position), rotate(a, b.x), rotate(a, b.y), rotate(a, b.z))
end
function frame.__index(c, key)
	if key == "LookVector" then return Vector3.new(-c.z.X, -c.z.Y, -c.z.Z) end
	if key == "UpVector" then return c.y end
	if key == "RightVector" then return c.x end
	return frame[key]
end
function frame.Inverse(c)
	-- Transpose the rotation; move by the rotated negative position.
	local x = Vector3.new(c.x.X, c.y.X, c.z.X)
	local y = Vector3.new(c.x.Y, c.y.Y, c.z.Y)
	local z = Vector3.new(c.x.Z, c.y.Z, c.z.Z)
	local r = make(Vector3.new(), x, y, z)
	return make(rotate(r, Vector3.new(-c.Position.X, -c.Position.Y, -c.Position.Z)), x, y, z)
end
function frame.Lerp(a, b, alpha)
	local function mix(u, v) return u + (v - u) * alpha end
	-- Blend axes and re-orthonormalise (small steps between frames only).
	local z = mix(a.z, b.z).Unit
	local x = mix(a.x, b.x)
	local y = z:Cross(x).Unit
	x = y:Cross(z).Unit
	return make(mix(a.Position, b.Position), x, y, z)
end
local function typeof(value) return if getmetatable(value) == frame then "CFrame" else type(value) end
local function yawOf(c) local l = c.LookVector; return math.atan2(-l.X, -l.Z) end
local function pitchOf(c) return math.asin(math.clamp(c.LookVector.Y, -1, 1)) end

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
local game = { GetService = function(_, name)
	if name == "ReplicatedStorage" then return {} end
	return { RenderStepped = render }
end }
local SHARK_SHAPE = (function()
-- SHARK_SHAPE_SOURCE --
end)()
local SharkSwim = (function()
-- SHARK_SWIM_SOURCE --
end)()

local attributes = {}
local model = { parts = {} }
function model:IsA(class) return class == "Model" end
function model:GetDescendants() return self.parts end
function model:GetAttribute(name) return attributes[name] end
local function piece(offset, segment, jaw)
	return {
		CFrame = CFrame.new(),
		IsA = function(_, class) return class == "BasePart" end,
		IsDescendantOf = function() return true end,
		GetAttribute = function(_, name)
			if name == "SwimOffset" then return offset end
			if name == "SwimSegment" then return segment end
			if name == "SwimJaw" then return jaw end
		end,
	}
end
local root = piece(nil)
root.CFrame = CFrame.new()
local head = piece(CFrame.new(0, -1, -4), 0)
local trunk = piece(CFrame.new(0, -1, 1), 1)
local rear = piece(CFrame.new(0, -1, 3), 2)
local stalk = piece(CFrame.new(0, -1, 5), 3)
local tail = piece(CFrame.new(0, -1, 7.5), 4)
local jaw = piece(CFrame.new(0, -2.8, -4.5), 0, true)
model.PrimaryPart = root
model.parts = { root, head, trunk, rear, stalk, tail, jaw }
folder.children = { model }
SharkSwim.start()

local function step(seconds, move)
	local frames = math.floor(seconds * 60 + 0.5)
	for _ = 1, frames do
		now += 1 / 60
		if move then root.CFrame = move(root.CFrame) end
		render:fire(1 / 60)
	end
end
render:fire(1 / 60)
assert(bulkMoves == 1, "Every visible piece moves in a single bulk call per frame")
assert(root.CFrame.Position.X == 0, "Animation must not change the authoritative root")
root.CFrame = CFrame.new(10, 0, 0)
now += 1 / 60
render:fire(1 / 60)
assert(head.CFrame.Position.X > 0 and head.CFrame.Position.X < 10, "Visual position should interpolate between updates")
assert(root.CFrame.Position.X == 10, "Interpolation must leave the root unchanged")
step(1)

-- The wave grows towards the tail: measure each piece's yaw swing against the root.
local function swings(seconds, move)
	local low, high = {}, {}
	local samples = {}
	for _ = 1, math.floor(seconds * 60) do
		now += 1 / 60
		if move then root.CFrame = move(root.CFrame) end
		render:fire(1 / 60)
		local base = yawOf(root.CFrame)
		for name, part in { head = head, trunk = trunk, rear = rear, stalk = stalk, tail = tail } do
			local yaw = yawOf(part.CFrame) - base
			low[name] = math.min(low[name] or math.huge, yaw)
			high[name] = math.max(high[name] or -math.huge, yaw)
		end
		table.insert(samples, yawOf(tail.CFrame) - base)
	end
	local range = {}
	for name in low do range[name] = high[name] - low[name] end
	-- Tail beats: sign changes of the tail's swing about its mean.
	local mean = 0
	for _, value in samples do mean += value / #samples end
	local crossings = 0
	for index = 2, #samples do
		if (samples[index] - mean) * (samples[index - 1] - mean) < 0 then crossings += 1 end
	end
	return range, crossings
end
local cruise, cruiseBeats = swings(4)
assert(cruise.tail > cruise.stalk and cruise.stalk > cruise.rear and cruise.rear > cruise.trunk and cruise.trunk > cruise.head,
	"Each joint bends more than the one ahead, so the tail sweeps widest")
assert(cruise.tail > 0.6, "The tail sweeps visibly (" .. cruise.tail .. " rad)")

-- A chase (55 studs/s straight ahead) beats the tail faster and harder.
local forward = function(c) return c * CFrame.new(0, 0, -55 / 60) end
step(2, forward)
local chase, chaseBeats = swings(4, forward)
assert(chaseBeats > cruiseBeats * 1.6, "Chasing quickens the tail beat (" .. cruiseBeats .. " -> " .. chaseBeats .. ")")
assert(chase.tail > cruise.tail * 1.2, "Chasing deepens the tail sweep")

-- Turning left banks the body into the turn.
local turnLeft = function(c) return c * CFrame.new(0, 0, -12 / 60) * CFrame.Angles(0, 0.8 / 60, 0) end
step(2, turnLeft)
local relative = root.CFrame:Inverse() * head.CFrame
assert(relative.x.Y > 0.08, "A left turn rolls the right side up into the turn")
step(3)

-- The jaw: barely parted while cruising, agape while hunting, wide then shut on a bite.
local function jawAngle() return pitchOf(jaw.CFrame) - pitchOf(head.CFrame) end
step(2)
local cruising = jawAngle()
attributes.Hunting = true
step(2)
local hunting = jawAngle()
assert(cruising < 0 and cruising > -0.12, "A cruising shark keeps its mouth nearly shut (" .. cruising .. ")")
assert(hunting < -0.15, "A hunting shark hangs its jaw open (" .. hunting .. ")")
attributes.BiteAt = now
step(0.14)
local wide = jawAngle()
step(0.12)
local shut = jawAngle()
assert(wide < -0.45, "A bite opens the jaw wide (" .. wide .. ")")
assert(shut > -0.06, "The jaw slams shut after the bite (" .. shut .. ")")
step(1.5)
assert(jawAngle() < -0.15, "The jaw opens again while the hunt goes on")

local streamedPart = piece(CFrame.new(0, -2, 1), 0)
table.insert(model.parts, streamedPart)
step(0.6)
assert(math.abs(streamedPart.CFrame.Position.Y - (root.CFrame.Position.Y - 2)) < 0.3, "Late streamed parts should be discovered")
folder.ChildRemoved:fire(model)
local previous = head.CFrame
root.CFrame = CFrame.new(20, 0, 0)
local movesBefore = bulkMoves
render:fire(1 / 60)
assert(head.CFrame == previous and bulkMoves == movesBefore, "Removed sharks must stop receiving animation updates")
print(string.format(
	"Shark swimming: travelling wave (tail %.2f rad cruising, %.2f chasing), beat %d -> %d, banking, jaw and streaming checks passed.",
	cruise.tail, chase.tail, cruiseBeats, chaseBeats))
