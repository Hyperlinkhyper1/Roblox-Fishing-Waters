-- Island tutorial checks: the guide roster and step chain, who says what, how a finished
-- conversation advances the tour, and the saved shape in AnglerData. No Roblox runtime.
-- Run: lute run scripts/tutorial.luau
local fs = require("@lute/fs")
local luau = require("@lute/luau")
local Data = require("../src/server/AnglerData")
local Tutorial = require("../src/shared/Tutorial")

local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

-- Every source that ships with the tutorial at least compiles.
for _, path in { "src/server/TutorialService.luau", "src/client/Tutorial.luau", "src/shared/Tutorial.luau" } do
	local file = fs.open(path, "r")
	local source = fs.read(file)
	fs.close(file)
	check(pcall(luau.load, luau.compile(source), path, {}), path .. " does not compile")
end

-- Roster: every guide in the order is defined once, wears a Roblox outfit and has somewhere to stand.
local seen = {}
for _, id in Tutorial.Order do
	local npc = Tutorial.Npcs[id]
	check(npc ~= nil, "Unknown guide in order: " .. id)
	check(not seen[id], "Guide listed twice: " .. id)
	seen[id] = true
	check(type(npc.Name) == "string" and type(npc.Title) == "string", id .. " needs a name and title")
	check(type(npc.OutfitId) == "number" and npc.OutfitId > 0 and npc.OutfitId % 1 == 0, id .. " needs an outfit")
	check(#npc.Spots > 0, id .. " needs a spot")
	check(npc.Anchor == nil or (npc.Fallback and #npc.Fallback > 0), id .. " needs plaza fallbacks for its anchor")
	check(type(npc.Face) == "table" and #npc.Face == 2, id .. " needs a facing point")
end
for id in Tutorial.Npcs do
	check(seen[id], "Guide missing from order: " .. id)
end
local outfits = {}
for id, npc in Tutorial.Npcs do
	check(not outfits[npc.OutfitId], id .. " shares an outfit with " .. tostring(outfits[npc.OutfitId]))
	outfits[npc.OutfitId] = id
end

-- Steps: each names a guide, has a goal and pages, and every guide teaches at least once.
local teaches = {}
for index, step in Tutorial.Steps do
	check(Tutorial.Npcs[step.Npc] ~= nil, "Step " .. index .. " names an unknown guide")
	check(type(step.Goal) == "string" and #step.Goal > 0, "Step " .. index .. " needs a goal")
	check(#step.Lines > 0, "Step " .. index .. " has nothing to say")
	if index > 1 then
		check(step.Npc ~= Tutorial.Steps[index - 1].Npc, "Step " .. index .. " repeats the previous guide")
	end
	teaches[step.Npc] = true
end
for id in Tutorial.Npcs do
	check(teaches[id], id .. " never takes part in the tour")
end
check(
	Tutorial.Steps[1].Npc == "Wren" and Tutorial.Steps[#Tutorial.Steps].Npc == "Wren",
	"Wren opens and closes the tour"
)
local last = Tutorial.Steps[#Tutorial.Steps].Lines
check(string.find(last[#last], "/tutorial", 1, true) ~= nil, "The last page tells players how to replay")

-- Dialogue: the current guide gives the step's lines; others repeat their own lesson.
local lines, current = Tutorial.dialogue("Wren", 1, false)
check(current and lines == Tutorial.Steps[1].Lines, "Wren welcomes a new player")
lines, current = Tutorial.dialogue("Pike", 1, false)
check(not current and lines == Tutorial.Steps[2].Lines, "Pike explains fishing out of turn without advancing")
lines, current = Tutorial.dialogue("Wren", 4, false)
check(not current and lines == Tutorial.Steps[1].Lines, "Wren keeps the welcome mid-tour")
lines, current = Tutorial.dialogue("Wren", #Tutorial.Steps, false)
check(current and lines == Tutorial.Steps[#Tutorial.Steps].Lines, "Wren wraps up at the last step")
lines, current = Tutorial.dialogue("Wren", 1, true)
check(not current and lines == Tutorial.Steps[#Tutorial.Steps].Lines, "Wren gives the wrap-up after the tour")
lines, current = Tutorial.dialogue("Pike", nil, nil)
check(not current and #lines > 0, "Guides still talk before progress loads")

-- Advancing: only the current guide moves the tour on, and the last one finishes it.
local nextStep, done = Tutorial.advance(1, false, "Wren")
check(nextStep == 2 and done == false, "Wren hands over to step 2")
nextStep, done = Tutorial.advance(2, false, "Wren")
check(nextStep == nil and done == false, "Talking to the wrong guide changes nothing")
nextStep, done = Tutorial.advance(#Tutorial.Steps, false, "Wren")
check(nextStep == #Tutorial.Steps and done == true, "The last conversation finishes the tour")
nextStep, done = Tutorial.advance(1, true, "Wren")
check(nextStep == nil and done == true, "A finished tour stays finished")
nextStep = Tutorial.advance(#Tutorial.Steps + 3, false, "Wren")
check(nextStep == nil, "A step beyond the tour never advances")
local step, finished = 1, false
for _, guide in Tutorial.Steps do
	step, finished = Tutorial.advance(step, finished, guide.Npc)
end
check(finished and step == #Tutorial.Steps, "Talking to every guide in order completes the tour")

-- Saved shape: new anglers start the tour, veterans start with it finished, bad saves never load.
local fresh = Data.decode(nil)
check(
	fresh.TutorialStep == 1 and fresh.TutorialDone == false and fresh.TutorialRewarded == false,
	"New anglers start the tour"
)
local veteran = Data.decode({ Stats = { TotalCaught = 12 } })
check(veteran.TutorialStep == 1 and veteran.TutorialDone == true, "Anglers who already fished skip the tour")
local resumed =
	Data.decode({ TutorialStep = 4, TutorialDone = false, TutorialRewarded = true, Stats = { TotalCaught = 9 } })
check(
	resumed.TutorialStep == 4 and resumed.TutorialDone == false and resumed.TutorialRewarded,
	"Progress survives a reload"
)
check(Data.decode(Data.decode(resumed)).TutorialStep == 4, "Decoding is stable")
check(not pcall(Data.decode, { TutorialStep = 0 }), "Step 0 is rejected")
check(not pcall(Data.decode, { TutorialStep = 2.5 }), "Fractional steps are rejected")
check(not pcall(Data.decode, { TutorialStep = "3" }), "Text steps are rejected")

print(string.format("Tutorial checks passed (%d)", checks))
