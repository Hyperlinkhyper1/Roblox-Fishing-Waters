-- The café tutorial: what a brand-new café company learns on its first visit. Bea, a café mentor,
-- stands on every claimed café's floor; talking to her bookends hands-on tasks (brew a coffee,
-- serve it, serve a few more, sit at the office PC) that the server ticks off as they happen.
-- Pure data and rules, so the server, the client and the tests read the same table. Progress is
-- saved on the company profile as Cafe.TutorialStep / TutorialDone / TutorialCount.

local CafeTutorial = {}

-- $ granted once per company, the first time the café tour is finished.
CafeTutorial.REWARD = 250
-- How close the server requires a player to stand to Bea when they finish talking to her.
CafeTutorial.TALK_RANGE = 18

-- Bea stands on the customer floor beside the open end of the counter, clear of the queue
-- (CafeCatalog.REGISTER_X) and of the gap to the staff door. Café-local (x, z), +z to the street.
CafeTutorial.Mentor = {
	Id = "Bea",
	Name = "Bea",
	Title = "Café Mentor",
	Spot = { 9.5, -3 },
	Face = { 16, 4 }, -- towards the café spawn point
	Outfit = {
		Skin = { 198, 140, 100 },
		Shirt = { 244, 240, 230 }, -- crisp white shirt
		Sleeves = "Long",
		Trousers = { 40, 38, 40 },
		Shoes = { 60, 40, 30 },
		Hair = { 120, 62, 34 },
		HairStyle = "Bun",
		Pieces = {
			{ Kind = "Apron", Color = { 46, 92, 72 }, Pockets = true }, -- the awning's green
			{ Kind = "Neckerchief", Color = { 214, 160, 48 } },
			{ Kind = "Pencil", Color = { 236, 196, 52 } },
		},
	},
}

-- Arrow targets the client knows how to find in the player's own café.
CafeTutorial.Targets = {
	Mentor = "Bea",
	CoffeeMachine = "Coffee machine",
	Customer = "Customer",
	OfficePc = "Office PC",
}

-- One entry per step, in order. Talk steps finish when the player closes Bea's dialogue beside her;
-- Task steps finish after Count matching events (default 1) reported by the café services.
CafeTutorial.Steps = {
	{
		Kind = "Talk",
		Target = "Mentor",
		Goal = "Talk to Bea, your café mentor, by the counter",
		Lines = {
			"Oh, hello! You must be the new owner. I'm Bea - I've helped open cafés all over this city, and I'll show you how yours works.",
			"Out front is the customer floor. Behind the counter you've got the till and the coffee machine, and through the STAFF ONLY door there's your office.",
			"Customers walk in off the avenue and queue at the till. Every coffee you serve puts $20 in your company wallet and earns you 25 XP.",
			"Let's make your first one. Walk round the open end of the counter and hold E at the coffee machine behind the till. On a phone, hold the Brew coffee button.",
		},
	},
	{
		Kind = "Task",
		Event = "Brew",
		Target = "CoffeeMachine",
		Goal = "Hold E at the coffee machine behind the till to brew a coffee",
	},
	{
		Kind = "Task",
		Event = "Serve",
		Target = "Customer",
		Goal = "Carry the coffee to the customer at the front of the queue and press E",
		Waiting = "Hold on to that coffee - a customer will walk in any second",
	},
	{
		Kind = "Talk",
		Target = "Mentor",
		Goal = "Tell Bea how your first coffee went",
		Lines = {
			"Your first customer, and a happy one! That's the whole job: brew, carry, serve.",
			"You can only carry one cup at a time, so brew one coffee per customer and always serve whoever is at the front of the queue.",
			"Customers are patient, but not forever. After two minutes without a coffee they give up and walk out, so don't wander off for long.",
			"Up to four customers fit inside at once, and new ones keep coming in. Serve three more and then I'll show you the back office.",
		},
	},
	{
		Kind = "Task",
		Event = "Serve",
		Count = 3,
		Target = "Customer",
		Goal = "Serve 3 more customers",
		Waiting = "Brew a coffee while you wait for the next customer",
	},
	{
		Kind = "Task",
		Event = "Computer",
		Target = "OfficePc",
		Goal = "Go through the STAFF ONLY door and sit at your office PC",
	},
	{
		Kind = "Talk",
		Target = "Mentor",
		Goal = "Report back to Bea on the café floor",
		Lines = {
			"So you found the office! That PC runs your whole company, and everyone in your company can use it.",
			"The BRANCHES app grows the business. For $5,000 you can open a fishing branch: your own dock and fish shop at Gullhaven harbour, where the guides by the fountain will teach you to fish.",
			"The STOCKS app lets you invest the company's cash once you own a trading license. Micro Harbour, the megastore in the industrial district across Harbour Road from the container docks, sells those - and faster parts for your PC.",
			"Want help behind the counter? Turn on multiplayer for this save on the save screen and up to four friends can join your company and serve coffee with you.",
			"Your company climbs the Companies leaderboard as it grows. Press M for the map if you ever get lost in the city.",
			"Here's a little something to get you started. If you ever want a refresher, type /tutorial in chat. Now go and make some coffee!",
		},
	},
}

function CafeTutorial.step(index: number)
	return CafeTutorial.Steps[index]
end

-- The saved state a profile's Cafe table stands for: (step, done, count). A company that has
-- never opened the tour starts at step 1; cafés that served coffee before the tour existed count
-- as finished (the decode in BoatData applies the same default when it first sees the table).
function CafeTutorial.state(cafe: any): (number, boolean, number)
	if type(cafe) ~= "table" then
		return 1, false, 0
	end
	local step = if type(cafe.TutorialStep) == "number" then cafe.TutorialStep else 1
	local done
	if cafe.TutorialStep == nil then
		done = (cafe.Served or 0) > 0
	else
		done = cafe.TutorialDone == true
	end
	-- A save from a longer future tour counts as finished rather than stranding the company.
	if step > #CafeTutorial.Steps then
		done = true
	end
	return math.clamp(step, 1, #CafeTutorial.Steps), done, if type(cafe.TutorialCount) == "number" then cafe.TutorialCount else 0
end

-- The goal text for the tracker, with the progress counter for multi-event tasks.
function CafeTutorial.goal(stepIndex: number, count: number?): string
	local step = CafeTutorial.Steps[stepIndex]
	if not step then
		return ""
	end
	local needed = step.Count or 1
	if step.Kind == "Task" and needed > 1 then
		return string.format("%s (%d/%d)", step.Goal, math.clamp(count or 0, 0, needed), needed)
	end
	return step.Goal
end

-- What Bea says when the player talks to her: the current step's lines when it is a talk step,
-- otherwise the last lines she has already said (so she repeats her advice between tasks).
function CafeTutorial.dialogue(stepIndex: number?, done: boolean?): ({ string }, boolean)
	local current = stepIndex and not done and CafeTutorial.Steps[stepIndex]
	if current and current.Kind == "Talk" then
		return current.Lines, true
	end
	local fallback = CafeTutorial.Steps[1].Lines
	for index, step in CafeTutorial.Steps do
		if step.Kind == "Talk" and (done or (stepIndex ~= nil and index < stepIndex)) then
			fallback = step.Lines
		end
	end
	if current and current.Kind == "Task" then
		-- Mid-task, Bea's reminder ends with the job at hand.
		local lines = table.clone(fallback)
		table.insert(lines, "Right now: " .. CafeTutorial.goal(stepIndex :: number, nil) .. ".")
		return lines, false
	end
	return fallback, false
end

local function nextStep(stepIndex: number): (number, boolean, number)
	if stepIndex >= #CafeTutorial.Steps then
		return stepIndex, true, 0
	end
	return stepIndex + 1, false, 0
end

-- Where a "finished talking to Bea" request moves the tour, or nil if it is not a talk step.
function CafeTutorial.talk(stepIndex: number, done: boolean): (number?, boolean, number)
	local current = not done and CafeTutorial.Steps[stepIndex]
	if not current or current.Kind ~= "Talk" then
		return nil, done, 0
	end
	return nextStep(stepIndex)
end

-- Where a café event ("Brew", "Serve", "Computer") moves the tour, or nil if it does not count.
-- A coffee served while the tour still waits for a brew covers both steps: the player brewed it
-- before the tour asked (brewing is refused while you already hold a cup).
function CafeTutorial.event(stepIndex: number, done: boolean, count: number, event: string): (number?, boolean, number)
	local current = not done and CafeTutorial.Steps[stepIndex]
	if not current or current.Kind ~= "Task" then
		return nil, done, count
	end
	if current.Event ~= event then
		local following = CafeTutorial.Steps[stepIndex + 1]
		if current.Event == "Brew" and event == "Serve" and following and following.Event == "Serve" then
			return CafeTutorial.event(stepIndex + 1, false, 0, event)
		end
		return nil, done, count
	end
	local reached = count + 1
	if reached < (current.Count or 1) then
		return stepIndex, false, reached
	end
	return nextStep(stepIndex)
end

return CafeTutorial
