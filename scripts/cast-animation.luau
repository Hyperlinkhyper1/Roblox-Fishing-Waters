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
local function avatar(shoulderName, jointClass)
	jointClass = jointClass or "Motor6D"
	local character = { inWorld = true }
	local joints = {}
	local names = if shoulderName == "RightShoulder"
		then { shoulderName, "LeftShoulder", "RightElbow", "LeftElbow", "RightWrist", "LeftWrist", "Waist" }
		else { shoulderName, "Left Shoulder", "RootJoint" }
	for _, name in names do
		local joint = { Name = name, Parent = character, Transform = frame() }
		if jointClass == "Motor6D" then
			joint.C0 = { Rotation = frame() }
		else
			joint.Attachment0 = { CFrame = { Rotation = frame() } }
		end
		function joint:IsA(kind)
			return kind == jointClass
		end
		function joint:IsDescendantOf(parent)
			return self.Parent == parent
		end
		joints[name] = joint
	end
	local humanoid = { Health = 100 }
	function character:IsA(kind)
		return kind == "Model"
	end
	function character:FindFirstChildOfClass()
		return humanoid
	end
	function character:FindFirstChild(name)
		return joints[name]
	end
	function character:IsDescendantOf()
		return self.inWorld
	end
	return character, joints[shoulderName], joints, humanoid
end
local function rod(character)
	local tool = { Parent = character, attributes = {} }
	function tool:GetAttribute(key)
		return self.attributes[key]
	end
	return tool
end
local mine, myShoulder, myJoints, myHumanoid = avatar("RightShoulder")
local theirs, theirShoulder, theirJoints = avatar("Right Shoulder")
local upgraded, upgradedShoulder, upgradedJoints = avatar("RightShoulder", "AnimationConstraint")
local myRod, theirRod, upgradedRod = rod(mine), rod(theirs), rod(upgraded)
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
local callback, beforeAnimation, connections = nil, nil, 0
local services = {
	CollectionService = {
		GetTagged = function()
			return { myRod, theirRod, upgradedRod }
		end,
	},
	Players = { LocalPlayer = { Character = mine } },
	RunService = { PreAnimation = {
		Connect = function(_, fn)
			beforeAnimation = fn
			connections += 1
		end,
	}, PreSimulation = {
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
		beforeAnimation()
		-- The Animator rewrites joints before PreSimulation each frame.
		local animated = if sway
			then CFrame.Angles(0, math.sin(clock * 12) * 0.65, math.cos(clock * 12) * 0.5)
			else CFrame.identity
		for _, joints in { myJoints, theirJoints, upgradedJoints } do
			for _, joint in joints do
				joint.Transform = if string.find(joint.Name, "Shoulder") then animated else CFrame.identity
			end
		end
		callback(1 / 60)
	end
end

Animation.start()
Animation.start()
assert(connections == 2, "start must connect each animation phase only once")
step(30)
local hold = math.pi / 2 * 0.92
assert(
	math.abs(myShoulder.Transform.x - hold) < 0.02 and math.abs(theirShoulder.Transform.x - hold) < 0.02,
	"Equipped rods must blend into a steady hold for R15 and R6"
)
assert(
	math.abs(upgradedShoulder.Transform.x - hold) < 0.02,
	"Rigs with AnimationConstraint joints (avatar joint upgrade) must hold the rod too"
)
assert(math.abs(myJoints.Waist.Transform.x) < 0.001, "Holding the rod must not bend the waist")
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
assert(myShoulder.Transform.x > math.pi, "Charging must cock the arm back behind the head")
assert(myJoints.Waist.Transform.x > 0.1, "Charging must lean the chest back")
assert(myJoints.Waist.Transform.y < -0.2, "Charging must turn the rod shoulder away")
assert(myJoints.LeftShoulder.Transform.x > 1.4, "The free hand must come up with the rod")
Animation.swing(myRod)
step(9)
assert(myShoulder.Transform.x < 1.4, "Release must whip the arm forward past the hold pose")
step(4)
assert(myJoints.Waist.Transform.x < -0.1, "The whip must drive the chest forward")
assert(myJoints.Waist.Transform.y > 0.1, "The whip must rotate the rod shoulder through")
step(60)
assert(math.abs(myShoulder.Transform.x - hold) < 0.02, "Swing must return to the steady hold")
assert(math.abs(myJoints.Waist.Transform.x) < 0.005, "The waist must straighten after the cast")
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
	myShoulder.Transform.x > hold and beforeCancel - myShoulder.Transform.x < (beforeCancel - hold) * 0.3,
	"Cancelling must ease back into the hold without snapping"
)
step(60)
assert(math.abs(myShoulder.Transform.x - hold) < 0.02, "Cancelled cast must return to the hold")

theirRod.attributes.CastAt = serverTime
upgradedRod.attributes.CastAt = serverTime
step(6)
assert(theirShoulder.Transform.x > 1.8, "Other anglers must back-swing from CastAt")
assert(upgradedShoulder.Transform.x > 1.8, "AnimationConstraint rigs must back-swing too")
local rootLean = theirJoints.RootJoint.Transform.x
assert(rootLean > 0.02 and rootLean < 0.15, "R6 casts must lean the torso back gently from the root")
step(14)
assert(theirShoulder.Transform.x < 1.4, "Other anglers must whip forward")
step(60)
assert(math.abs(theirShoulder.Transform.x - hold) < 0.02, "Other anglers' swings must return to the hold")
assert(math.abs(theirJoints.RootJoint.Transform.x) < 0.005, "R6 roots must straighten after the cast")
upgradedRod.attributes.CastAt = nil

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

Animation.windUp(myRod)
Animation.swing(myRod)
step(6)
assert(myShoulder.Transform.x > 2.6, "A quick tap must still show an overhead backswing")
assert(myJoints.RightElbow.Transform.x > 0.2, "Casting must bend the R15 elbow")
step(10)
assert(myShoulder.Transform.x < 1.4, "A quick tap must whip forward after its backswing")
step(60)

myRod.attributes.CastAt = serverTime - 5
theirRod.attributes.CastAt = serverTime - 5
theirRod.attributes.CastPhase = "Hooked"
Animation.setReeling(myRod, true)
step(30)
assert(myJoints.LeftShoulder.Transform.x > 0.8, "The local angler must reach toward the reel")
assert(theirJoints["Left Shoulder"].Transform.x > 0.8, "Other R6 anglers must reel from replicated Hooked state")
assert(myJoints.LeftElbow.Transform.x > 0.6, "R15 reeling must bend the left elbow")
local leftX, leftZ = myJoints.LeftShoulder.Transform.x, myJoints.LeftShoulder.Transform.z
step(12)
assert(
	math.abs(myJoints.LeftShoulder.Transform.x - leftX) > 0.04
		or math.abs(myJoints.LeftShoulder.Transform.z - leftZ) > 0.04,
	"The reeling hand must keep circling during the minigame"
)
Animation.pull(myRod, true)
step(11)
assert(myShoulder.Transform.x > 2, "A successful pull must lift the rod")
step(30)
Animation.pull(myRod, false)
step(11)
assert(myShoulder.Transform.x < 1.7, "A missed pull must let the rod dip")

Animation.setReeling(myRod, false)
theirRod.attributes.CastPhase = nil
step(60)
assert(math.abs(myShoulder.Transform.x - hold) < 0.02, "Finishing the minigame must restore the rod hold")
assert(math.abs(myJoints.LeftShoulder.Transform.x) < 0.001, "Finishing must release the left arm")
assert(math.abs(theirJoints["Left Shoulder"].Transform.x) < 0.001, "Remote reeling must stop when Hooked clears")

Animation.setReeling(myRod, true)
step(20)
-- Without an Animator writing these joints, our poses must not feed back into themselves.
for _ = 1, 180 do
	clock += 1 / 60
	serverTime += 1 / 60
	beforeAnimation()
	callback(1 / 60)
	assert(myJoints.LeftShoulder.Transform.x < 1.3, "Reeling offsets must not accumulate on unkeyed joints")
end
myRod.Parent = nil
callback(1 / 60)
for _, joint in myJoints do
	assert(joint.Transform.x == 0 and joint.Transform.y == 0 and joint.Transform.z == 0,
		"Unequipping during the minigame must restore every animated joint")
end
myRod.Parent = mine
step(60)
assert(math.abs(myJoints.LeftShoulder.Transform.x) < 0.001, "Re-equipping must not resume stale reeling")

Animation.setReeling(myRod, true)
step(20)
myHumanoid.Health = 0
callback(1 / 60)
assert(myShoulder.Transform.x == 0 and myJoints.LeftShoulder.Transform.x == 0, "Death must restore both arms")
myHumanoid.Health = 100
step(60)
assert(math.abs(myJoints.LeftShoulder.Transform.x) < 0.001, "Respawning must not keep a reeling intent")

print("Cast/reel animation lifecycle checks passed (mock transforms; visual quality requires Studio)")

-- All input devices reach Reel:pull; only accepted inputs should trigger a tug.
do
	local Reel = {}
	local ZONE = "green"
	local function rgb()
		return "red"
	end
	local FishingAudio = { pull = function() end, miss = function() end }
	-- REEL_PULL_SOURCE --
	local results = {}
	local state = {
		t = 0.5, zone = 0.4, lockUntil = 0, progress = 0.5,
		tuning = { zoneSize = 0.2, gain = 0.1, missPenalty = 0.1 },
		onPull = function(hit)
			table.insert(results, hit)
		end,
	}
	local controller = setmetatable({ state = state, rounds = 0 }, { __index = Reel })
	function controller:newRound()
		self.rounds += 1
	end
	controller:pull()
	assert(#results == 1 and results[1] == true and controller.rounds == 1,
		"A green-zone input must notify the animation and still advance the minigame")
	controller:pull()
	assert(#results == 1, "Inputs during the cooldown must not trigger another animation")
	clock += 0.5
	state.t = 0.1
	controller:pull()
	assert(#results == 2 and results[2] == false, "A red-zone input must notify the animation of the miss")
	assert(math.abs(state.progress - 0.5) < 0.001, "Animation feedback must preserve scoring")
	clock += 0.5
	state.result = "Aborted"
	controller:pull()
	assert(#results == 2, "An aborted minigame must not animate more pulls")
	controller.state = nil
	controller:pull()
	assert(#results == 2, "Inputs outside the minigame must not animate a pull")
end
print("Reel input/animation callback checks passed")
