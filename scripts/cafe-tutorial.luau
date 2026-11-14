-- Café tutorial checks: Bea's costume and spot, the step chain, how talks and café events move
-- the tour, the saved defaults, and that every file shipping with it compiles. No Roblox runtime.
-- Run: lute run scripts/cafe-tutorial.luau
local fs = require("@lute/fs")
local luau = require("@lute/luau")
local CafeTutorial = require("../src/shared/CafeTutorial")

local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

local function source(path: string): string
	local file = fs.open(path, "r")
	local text = fs.read(file)
	fs.close(file)
	return text
end

-- CafeCatalog builds Vector3s when it loads; give it a tiny stand-in.
local Vector3Stub = {
	new = function(x, y, z)
		return { X = x or 0, Y = y or 0, Z = z or 0 }
	end,
}
local catalogEnv = setmetatable({ Vector3 = Vector3Stub }, { __index = _G })
local CafeCatalog = luau.load(luau.compile(source("src/shared/CafeCatalog.luau")), "CafeCatalog", catalogEnv)()

-- Every source that ships with the café tour at least compiles.
local sources = {}
for _, path in {
	"src/shared/CafeTutorial.luau",
	"src/server/CafeTutorialService.luau",
	"src/server/CafeService.luau",
	"src/server/OfficeComputerService.luau",
	"src/server/TutorialService.luau",
	"src/server/BoatData.luau",
	"src/server/BoatService.luau",
	"src/server/init.server.luau",
	"src/client/Tutorial.luau",
	"src/server/GuideCostume.luau",
} do
	sources[path] = source(path)
	check(pcall(luau.load, luau.compile(sources[path]), path, {}), path .. " does not compile")
end

-- Bea is dressed only in pieces GuideCostume can build.
local kinds = {}
for kind in string.gmatch(sources["src/server/GuideCostume.luau"], "function KINDS%.(%w+)") do
	kinds[kind] = true
end
local mentor = CafeTutorial.Mentor
check(type(mentor.Id) == "string" and type(mentor.Name) == "string" and type(mentor.Title) == "string", "Bea needs a name")
check(({ Long = true, Short = true, None = true })[mentor.Outfit.Sleeves], "Bea's sleeves are unknown")
check(({ Short = true, Bun = true, Ponytail = true, Bald = true })[mentor.Outfit.HairStyle], "Bea's hair is unknown")
for _, piece in mentor.Outfit.Pieces do
	check(kinds[piece.Kind], "Bea wears an unknown piece " .. tostring(piece.Kind))
end

-- Bea stands on the customer floor, clear of the counter, the queue, the door path and the spawn.
local x, z = mentor.Spot[1], mentor.Spot[2]
check(math.abs(x) < CafeCatalog.HALF_WIDTH - 2, "Bea stands inside the walls")
check(z > CafeCatalog.COUNTER_FRONT + 2 and z < CafeCatalog.FRONT - 2, "Bea stands on the customer floor")
check(math.abs(x - CafeCatalog.REGISTER_X) > 6, "Bea is out of the queue")
check(math.abs(x) > 4, "Bea is out of the door path")
check(math.sqrt((x - 16) ^ 2 + (z - 4) ^ 2) > 5, "Bea is off the café spawn point")
check(x < 13.5 - 2, "Bea leaves the gap round the counter open")

-- Steps: talk steps have lines; task steps name an event and a target the client can find.
local EVENTS = { Brew = true, Serve = true, Computer = true }
for index, step in CafeTutorial.Steps do
	check(type(step.Goal) == "string" and #step.Goal > 0, "Step " .. index .. " needs a goal")
	check(CafeTutorial.Targets[step.Target] ~= nil, "Step " .. index .. " points at an unknown target")
	if step.Kind == "Talk" then
		check(type(step.Lines) == "table" and #step.Lines > 0, "Step " .. index .. " has nothing to say")
		check(step.Target == "Mentor", "Talk step " .. index .. " points at Bea")
	else
		check(step.Kind == "Task", "Step " .. index .. " is a talk or a task")
		check(EVENTS[step.Event], "Step " .. index .. " waits for an unknown event")
		check(step.Count == nil or (step.Count >= 1 and step.Count % 1 == 0), "Step " .. index .. " has a bad count")
	end
end
local steps = CafeTutorial.Steps
check(steps[1].Kind == "Talk" and steps[#steps].Kind == "Talk", "Bea opens and closes the tour")
local last = steps[#steps].Lines
check(string.find(last[#last], "/tutorial", 1, true) ~= nil, "The last page tells players how to replay")
-- What Bea says matches the café's real numbers.
local welcome = table.concat(steps[1].Lines, " ")
check(string.find(welcome, "$" .. CafeCatalog.COFFEE_PRICE, 1, true) ~= nil, "Bea quotes the coffee price")
check(string.find(welcome, CafeCatalog.COFFEE_XP .. " XP", 1, true) ~= nil, "Bea quotes the coffee XP")
check(string.find(table.concat(steps[4].Lines, " "), "two minutes", 1, true) ~= nil and CafeCatalog.PATIENCE == 120, "Bea quotes customer patience")

-- Dialogue: the current talk step speaks; between tasks Bea repeats her last advice plus the job.
local lines, current = CafeTutorial.dialogue(1, false)
check(current and lines == steps[1].Lines, "Bea welcomes a new café")
lines, current = CafeTutorial.dialogue(2, false)
check(not current and lines[1] == steps[1].Lines[1] and string.find(lines[#lines], steps[2].Goal, 1, true), "Mid-task Bea reminds you of the job")
lines, current = CafeTutorial.dialogue(5, false)
check(not current and lines[1] == steps[4].Lines[1], "Bea repeats her latest lesson")
lines, current = CafeTutorial.dialogue(#steps, true)
check(not current and lines == last, "Bea gives the wrap-up after the tour")
lines, current = CafeTutorial.dialogue(nil, nil)
check(not current and #lines > 0, "Bea talks before progress loads")

-- Talking: only talk steps advance, and the last one finishes the tour.
local step, done, count = CafeTutorial.talk(1, false)
check(step == 2 and not done and count == 0, "The welcome leads to brewing")
check(CafeTutorial.talk(2, false) == nil, "Talking does not skip a task")
step, done = CafeTutorial.talk(#steps, false)
check(step == #steps and done, "The last talk finishes the tour")
check(CafeTutorial.talk(1, true) == nil, "A finished tour stays finished")

-- Events: matching events advance; others change nothing; counted tasks count up.
step, done, count = CafeTutorial.event(2, false, 0, "Brew")
check(step == 3 and not done and count == 0, "Brewing moves on to serving")
check(CafeTutorial.event(2, false, 0, "Computer") == nil, "The wrong event changes nothing")
check(CafeTutorial.event(1, false, 0, "Serve") == nil, "Serving before meeting Bea changes nothing")
step, done, count = CafeTutorial.event(2, false, 0, "Serve")
check(step == 4 and not done, "A coffee brewed before the tour asked still counts for both steps")
step, done, count = CafeTutorial.event(5, false, 0, "Serve")
check(step == 5 and count == 1, "Counted tasks count")
step, done, count = CafeTutorial.event(5, false, 2, "Serve")
check(step == 6 and count == 0, "The last counted serve moves on")
check(CafeTutorial.event(5, true, 0, "Serve") == nil, "Events never reopen a finished tour")

-- A full play-through: the tour's own events, in order, finish it.
step, done, count = 1, false, 0
for _ = 1, 40 do
	if done then
		break
	end
	local current = steps[step]
	local nextIndex, nextDone, nextCount
	if current.Kind == "Talk" then
		nextIndex, nextDone, nextCount = CafeTutorial.talk(step, done)
	else
		nextIndex, nextDone, nextCount = CafeTutorial.event(step, done, count, current.Event)
	end
	assert(nextIndex, "The tour stalled at step " .. step)
	step, done, count = nextIndex, nextDone, nextCount
end
check(done and step == #steps, "Doing every step in order completes the tour")

-- Goals show progress on counted tasks.
check(CafeTutorial.goal(5, 2) == steps[5].Goal .. " (2/3)", "Counted goals show progress")
check(CafeTutorial.goal(2, 0) == steps[2].Goal, "Single tasks show the plain goal")

-- Saved state: new cafés start the tour; cafés from before the tour skip it; resumes keep place.
step, done, count = CafeTutorial.state(nil)
check(step == 1 and not done and count == 0, "A café that never served starts the tour")
step, done = CafeTutorial.state({ Served = 40 })
check(done, "Cafés that served before the tour start with it finished")
step, done, count = CafeTutorial.state({ Served = 3, TutorialStep = 5, TutorialDone = false, TutorialCount = 2 })
check(step == 5 and not done and count == 2, "Progress survives a reload")
step, done = CafeTutorial.state({ Served = 3, TutorialStep = #steps + 4, TutorialDone = false })
check(done and step == #steps, "A step past the tour counts as finished")

-- The save decode and attribute mirror use the same defaults, and serving keeps the tour fields.
check(string.find(sources["src/server/BoatData.luau"], "TutorialStep = step", 1, true) ~= nil, "BoatData saves the tour step")
check(string.find(sources["src/server/BoatService.luau"], "CafeTutorialStep", 1, true) ~= nil, "BoatService publishes the tour")
check(string.find(sources["src/server/CafeService.luau"], "profile.Cafe = { Served", 1, true) == nil, "Serving no longer wipes the café progress")
check(string.find(sources["src/server/init.server.luau"], "CafeTutorialService", 1, true) ~= nil, "The server starts the café tour")

print(string.format("Café tutorial checks passed (%d)", checks))
