-- Recording transforms validates the swing lifecycle, not Roblox rendering.
local frameMeta = {}
local function frame(x, y, z)
	return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, frameMeta)
end
frameMeta.__index = {
	Inverse = function(a)
		return frame(-a.x, -a.y, -a.z)
	end,
	Lerp = function(a, b, t)
		return frame(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t)
	end,
}
frameMeta.__mul = function(a, b)
	return frame(a.x + b.x, a.y + b.y, a.z + b.z)
end
local CFrame = { identity = frame(), Angles = frame }
local function avatar(shoulderName)
	local character = {}
	local joint = { Name = shoulderName, Parent = character, C0 = { Rotation = frame() }, Transform = frame() }
	function joint:IsA(kind)
		return kind == "Motor6D"
	end
	function joint:IsDescendantOf(parent)
		return parent == character
	end
	local humanoid = { Health = 100 }
	function character:IsA(kind)
		return kind == "Model"
	end
	function character:FindFirstChildOfClass()
		return humanoid
	end
	function character:FindFirstChild(name)
		return if name == shoulderName then joint else nil
	end
	return character, joint
end
local function rod(character)
	local tool = { Parent = character, attributes = {} }
	function tool:GetAttribute(key)
		return self.attributes[key]
	end
	return tool
end
local mine, myShoulder = avatar("RightShoulder")
local theirs, theirShoulder = avatar("Right Shoulder")
local myRod, theirRod = rod(mine), rod(theirs)
local clock, serverTime = 0, 100
local os = {
	clock = function()
		return clock
	end,
}
local workspace = {}
function workspace:GetServerTimeNow()
	return serverTime
end
local callback, connections = nil, 0
local services = {
	CollectionService = {
		GetTagged = function()
			return { myRod, theirRod }
		end,
	},
	Players = { LocalPlayer = { Character = mine } },
	RunService = { PreSimulation = {
		Connect = function(_, fn)
			callback = fn
			connections += 1
		end,
	} },
}
local game = {}
function game:GetService(name)
	return services[name]
end
local Animation = (function()
	-- CAST_ANIMATION_SOURCE --
end)()
local function step(frames, sway)
	for _ = 1, frames do
		clock += 1 / 60
		serverTime += 1 / 60
		-- The Animator rewrites joints before PreSimulation each frame.
		local animated = if sway
			then CFrame.Angles(0, math.sin(clock * 12) * 0.65, math.cos(clock * 12) * 0.5)
			else CFrame.identity
		myShoulder.Transform, theirShoulder.Transform = animated, animated
		callback(1 / 60)
	end
end

Animation.start()
Animation.start()
assert(connections == 1, "start must be idempotent")
step(30)
local hold = math.pi / 2 * 0.92
assert(
	math.abs(myShoulder.Transform.x - hold) < 0.02 and math.abs(theirShoulder.Transform.x - hold) < 0.02,
	"Equipped rods must blend into a steady hold for R15 and R6"
)
for _ = 1, 120 do
	step(1, true)
	for _, joint in { myShoulder, theirShoulder } do
		assert(
			math.abs(joint.Transform.y) < 0.055 and math.abs(joint.Transform.z) < 0.045,
			"Walking animations must not swing the rod arm sideways"
		)
	end
end

Animation.windUp(myRod)
step(1)
assert(myShoulder.Transform.x > hold and myShoulder.Transform.x < hold + 0.3, "Wind-up must blend in rather than snap")
step(40)
assert(myShoulder.Transform.x > 2.6, "Charging must cock the arm back overhead")
Animation.swing(myRod)
step(9)
assert(myShoulder.Transform.x < 1.4, "Release must whip the arm forward past the hold pose")
step(60)
assert(math.abs(myShoulder.Transform.x - hold) < 0.02, "Swing must return to the steady hold")
step(10)
assert(math.abs(myShoulder.Transform.x - hold) < 0.02, "Finished swing must keep the rod steady")

myRod.attributes.CastAt = serverTime
step(5)
assert(math.abs(myShoulder.Transform.x - hold) < 0.02, "The local rod must not replay its own server cast")

Animation.windUp(myRod)
step(20)
local beforeCancel = myShoulder.Transform.x
Animation.cancel(myRod)
step(1)
assert(
	myShoulder.Transform.x > hold and beforeCancel - myShoulder.Transform.x < 0.4,
	"Cancelling must ease back into the hold without snapping"
)
step(60)
assert(math.abs(myShoulder.Transform.x - hold) < 0.02, "Cancelled cast must return to the hold")

theirRod.attributes.CastAt = serverTime
step(6)
assert(theirShoulder.Transform.x > 1.8, "Other anglers must back-swing from CastAt")
step(14)
assert(theirShoulder.Transform.x < 1.4, "Other anglers must whip forward")
step(60)
assert(math.abs(theirShoulder.Transform.x - hold) < 0.02, "Other anglers' swings must return to the hold")

theirRod.attributes.CastAt = serverTime - 30
step(5)
assert(math.abs(theirShoulder.Transform.x - hold) < 0.02, "Late joiners must not replay old casts")

Animation.windUp(myRod)
step(20)
myRod.Parent = nil
callback(1 / 60)
assert(myShoulder.Transform.x == 0, "Unequipping mid-cast must restore the shoulder")
myRod.Parent = mine
step(5)
assert(
	myShoulder.Transform.x > 0 and myShoulder.Transform.x < hold,
	"Re-equipping must blend into the hold without a stale wind-up"
)
step(60)
assert(math.abs(myShoulder.Transform.x - hold) < 0.02, "Re-equipped rod must settle into its hold")
print("Cast animation lifecycle checks passed (mock transforms; visual quality requires Studio)")
