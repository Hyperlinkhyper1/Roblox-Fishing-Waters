-- Recording transforms validate animation lifecycle, not Roblox rendering.
local frameMeta = {}
local function frame(x, y, z)
	return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, frameMeta)
end
frameMeta.__index = {
	Inverse = function(a) return frame(-a.x, -a.y, -a.z) end,
	Lerp = function(a, b, t) return frame(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t) end,
}
frameMeta.__mul = function(a, b) return frame(a.x + b.x, a.y + b.y, a.z + b.z) end
local CFrame = { identity = frame(), Angles = frame }
local rotation = { Rotation = frame() }
local function joint(name, side)
	local item = { Name = name, Parent = true, C0 = rotation, Transform = frame(), side = side }
	function item:IsA(kind) return kind == "Motor6D" end
	function item:GetAttribute(key) return if key == "RowSide" then self.side else nil end
	return item
end
local left, right = joint("LeftShoulder"), joint("RightShoulder")
local avatar = {}
function avatar:GetDescendants() return { left, right } end
local humanoid = { Health = 100, Parent = avatar }
local seat = { Occupant = humanoid }
local port, starboard = joint("PortOar", -1), joint("StarboardOar", 1)
local folder, model = {}, { attributes = { BoatId = "Rowboat", RowThrottle = 1, RowSteer = 0 } }
model.Parent = folder
function model:GetAttribute(key) return self.attributes[key] end
function model:FindFirstChild() return seat end
function model:GetDescendants() return { port, starboard } end
function seat:IsDescendantOf(parent) return parent == model end
function folder:GetChildren() return { model } end
local time = 0.25
local workspace = {}
function workspace:FindFirstChild() return folder end
function workspace:GetServerTimeNow() return time end
local callback, connections = nil, 0
local game = {}
function game:GetService()
	return { PreSimulation = { Connect = function(_, fn) callback = fn; connections += 1 end } }
end
local Animation = (function()
	-- ROWING_ANIMATION_SOURCE --
end)()
Animation.start()
Animation.start()
assert(connections == 1, "start must be idempotent")
for _ = 1, 60 do callback(1 / 60) end
assert(math.abs(port.Transform.y) > 0.1, "Forward input must stroke the oars")
assert(math.abs(port.Transform.y + starboard.Transform.y) < 1e-8, "Oars must mirror around hull")
assert(math.abs(left.Transform.x) > 0.1 and math.abs(right.Transform.x) > 0.1, "R15 shoulders must row")
model.attributes.RowThrottle = -1
for _ = 1, 90 do callback(1 / 60) end
assert(port.Transform.y > 0 and starboard.Transform.y < 0, "Reverse input must reverse stroke direction")
model.attributes.RowThrottle, model.attributes.RowSteer = 0, 1
for _ = 1, 90 do callback(1 / 60) end
assert(port.Transform.y > 0 and starboard.Transform.y > 0, "Turning must counter-row")
local before = port.Transform.y
model.attributes.RowSteer = 0
callback(1 / 60)
assert(math.abs(port.Transform.y) > math.abs(before) * 0.8, "Stopping must blend rather than snap")
for _ = 1, 180 do callback(1 / 60) end
assert(math.abs(port.Transform.y) < 0.001 and left.Transform.x == 0, "Release must restore rest pose")
left.Name, right.Name = "Left Shoulder", "Right Shoulder"
seat.Occupant = nil
callback(1 / 60)
seat.Occupant, model.attributes.RowThrottle = humanoid, 1
for _ = 1, 90 do callback(1 / 60) end
assert(math.abs(left.Transform.x) > 0.1, "R6 shoulders must row")
seat.Occupant = nil
callback(1 / 60)
assert(left.Transform.x == 0 and right.Transform.x == 0, "Dismount must restore avatar")
seat.Occupant = humanoid
callback(1 / 60)
model.Parent = nil
callback(1 / 60)
assert(left.Transform.x == 0 and port.Transform.y == 0, "Stream-out must clear avatar and oar pose")
model.Parent = folder
for _ = 1, 60 do callback(1 / 60) end
assert(math.abs(port.Transform.y) > 0.1, "Stream-in must rebind animation")
print("Rowing animation lifecycle checks passed (mock transforms; visual quality requires Studio)")
