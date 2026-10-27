-- Appended to the recording menu harness by --paths-only. Runs actual service/UI.
local Paths = (function()
	-- PATH_RULES --
end)()
local granted = Enum.ProductPurchaseDecision.PurchaseGranted
local pending = Enum.ProductPurchaseDecision.NotProcessedYet
local function reset(cash)
	profile = { Cash = cash or 0, OwnedRods = {}, OwnedBoats = {}, Angler = Data.decode(nil) }
end
local function receipt(id, productId, userId)
	return MarketplaceService.ProcessReceipt({
		ProductId = productId or Paths.SKIP_PRODUCT_ID,
		PlayerId = userId or player.UserId,
		PurchaseId = id,
	})
end
reset()
check(Paths.SKIP_PRODUCT_ID == 3722698836, "Configured quest skip product")
check(profile.Angler.Paths.SkipCredits == 0, "Old profiles migrate without free skips")
for _, invalid in { -1, 0.5, false, "1" } do
	local malformed = Data.decode(nil)
	malformed.Paths.SkipCredits = invalid
	check(not pcall(Data.decode, malformed), "Malformed saved skip credits are rejected")
end
local malformedReceipts = Data.decode(nil)
malformedReceipts.Paths.SkipReceipts = false
check(not pcall(Data.decode, malformedReceipts), "Malformed saved receipt history is rejected")
check(not invoke("PreparePathSkip", {}).Ok, "Malformed path skip rejected")
check(not invoke("PreparePathSkip", "Supermarket").Ok, "Cannot skip a locked or different stage")
check(not invoke("SkipPath", "Fishshop").Ok, "Client cannot grant itself a skip")
check(receipt("unknown", 123) == pending, "Unknown product is not acknowledged")
check(receipt("offline", nil, 999) == pending, "Missing player is not acknowledged")
failSave = true
check(not invoke("PreparePathSkip", "Fishshop").Ok, "Failed preparation cannot open purchase prompt")
check(profile.Angler.Paths.SkipTarget == nil, "Failed preparation preserves saved state")
check(receipt("save-fails") == pending, "Failed receipt save remains pending")
check(not profile.Angler.Paths.SkipReceipts["save-fails"], "Failed save does not record purchase")
failSave = false
local prepared = invoke("PreparePathSkip", "Fishshop")
check(prepared.Ok and prepared.PromptProductId == 3722698836, "Server prepares configured purchase")
check(profile.Angler.Paths.SkipTarget == "Fishshop", "Purchase target persists before prompting")
check(not profile.Angler.Paths.Completed.Fishshop, "Preparing or cancelling cannot grant quests")
check(
	string.find(prepared.Message, "still need in-game money", 1, true),
	"Server warning keeps the money requirement clear"
)
check(receipt("first") == granted, "Saved receipt is granted")
profile.Angler = Data.decode(profile.Angler)
check(profile.Angler.Paths.SkipReceipts.first and profile.Angler.Paths.Completed.Fishshop, "Receipt and quest completion survive a save round trip")
check(
	profile.Angler.Paths.Completed.Fishshop and profile.Angler.Paths.SkipCredits == 0,
	"Receipt completes only targeted quests"
)
check(
	profile.Angler.Paths.Active == "Fishshop" and not profile.Angler.Paths.Unlocked.Supermarket,
	"Receipt does not advance a path for free"
)
check(
	profile.Cash == 0 and profile.Angler.Stats.FishSold == 0 and not profile.Angler.Staff.Seller,
	"Skip grants no money, stats or workers"
)
check(not invoke("ChoosePath", "Supermarket").Ok, "Skipped quests still require next stage's money")
check(
	receipt("first") == granted and profile.Angler.Paths.SkipCredits == 0,
	"Receipt retries do not grant a second skip"
)
check(not invoke("PreparePathSkip", "Fishshop").Ok, "Completed quests cannot prompt another purchase")
profile.Cash = 5000
check(invoke("ChoosePath", "Supermarket").Ok and profile.Cash == 0, "Next stage charges its full price")
check(
	profile.Angler.Paths.Active == "Supermarket" and profile.Angler.FurnitureStock.FoodCase == 1,
	"Normal path grants apply after payment"
)
check(
	receipt("first") == granted and not profile.Angler.Paths.Completed.Supermarket,
	"Old receipt never skips the next stage"
)

-- External and late purchases remain consumable instead of skipping the wrong stage.
check(
	receipt("external") == granted and profile.Angler.Paths.SkipCredits == 1,
	"External purchase retains a saved credit"
)
check(not profile.Angler.Paths.Completed.Supermarket, "External purchase waits for player to choose its stage")
local used = invoke("PreparePathSkip", "Supermarket")
check(
	used.Ok and used.PromptProductId == nil and profile.Angler.Paths.Completed.Supermarket,
	"Saved credit skips quests without another Robux prompt"
)
check(profile.Angler.Paths.SkipCredits == 0 and profile.Cash == 0, "Using a credit preserves the wallet")
check(
	not invoke("ChoosePath", "Restaurant").Ok and not invoke("ChoosePath", "Company").Ok,
	"Both branches still require money"
)
profile.Cash = 20000
check(invoke("ChoosePath", "Company").Ok and profile.Cash == 0, "Company branch charges server price")
check(invoke("PreparePathSkip", "Company").Ok, "A new stage can prepare its own purchase")
profile.Angler.Paths.Completed.Company = true
profile.Cash = 15000
check(invoke("ChoosePath", "Restaurant").Ok, "Player can move on before a delayed receipt")
check(
	receipt("late") == granted and profile.Angler.Paths.SkipCredits == 1,
	"Late receipt preserves the purchased credit"
)
check(not profile.Angler.Paths.Completed.Restaurant, "Late receipt cannot skip a different stage")
check(not invoke("PreparePathSkip", "Restaurant").Ok, "Final stage offers no next-level skip")

-- Simulate a discarded UpdateAsync callback followed by a retry.
reset()
check(invoke("PreparePathSkip", "Fishshop").Ok, "Prepare retry scenario")
local originalUpdate = BoatService.updateProgress
BoatService.updateProgress = function(_, transform)
	local initial = Data.decode(profile.Angler)
	transform(profile)
	profile.Angler = initial
	return originalUpdate(player, transform)
end
check(receipt("retried-update") == granted, "Retried wallet callback grants purchase")
check(
	profile.Angler.Paths.SkipCredits == 0 and profile.Angler.Paths.Completed.Fishshop,
	"Retried callback applies a single quest skip"
)
BoatService.updateProgress = originalUpdate
reset()
local saves = 0
BoatService.updateProgress = function(_, transform)
	saves += 1
	if saves < 3 then
		return false, "Busy or loading"
	end
	return originalUpdate(player, transform)
end
check(receipt("busy") == granted and saves == 3, "Receipt retries transient load/save contention")
BoatService.updateProgress = originalUpdate

Menu.start()
advance(1)
local gui = playerGui.PlayerMenu
local sidebar, card = gui.LeftNavigation, gui.MenuOverlay.MenuWindow
local content = card.Content
local function click(name)
	now += 1
	assert(content:FindFirstChild(name, true), "Missing path control: " .. name).Activated:Fire()
end
local function refresh()
	player:SetAttribute("AnglerRevision", (player:GetAttribute("AnglerRevision") or 0) + 1)
	advance(1)
end
for _, width in { 1020, 362 } do
	reset()
	card.AbsoluteSize = Vector2.new(width, 600)
	now += 1
	sidebar.Home.Activated:Fire()
	click("PathsTab")
	local stage = assert(content:FindFirstChild("FishshopStage", true))
	check(
		stage.PathSkipWarning.TextWrapped and stage.PathSkipWarning.AutomaticSize == Enum.AutomaticSize.Y,
		"Warning wraps at desktop and phone widths"
	)
	check(
		string.find(stage.PathSkipWarning.Text, "still need in-game money", 1, true)
			and string.find(stage.PathSkipWarning.Text, "$5,000", 1, true),
		"Path GUI warns of full next-stage cost"
	)
	local prompts = #productPrompts
	click("SkipPathQuests")
	check(stage.PathSkipConfirmation.Visible and not stage.SkipPathQuests.Visible, "Skip opens explicit confirmation")
	check(#productPrompts == prompts, "First click cannot charge Robux")
	click("CancelPathSkip")
	check(not stage.PathSkipConfirmation.Visible and stage.SkipPathQuests.Visible, "Cancel restores skip button")
	click("SkipPathQuests")
	click("ConfirmPathSkip")
	check(
		#productPrompts == prompts + 1 and productPrompts[#productPrompts][2] == 3722698836,
		"Confirmed purchase uses provided product ID"
	)
	check(not profile.Angler.Paths.Completed.Fishshop, "Purchase prompt alone grants nothing")
	check(receipt("ui-" .. width) == granted, "GUI purchase receipt applies")
	refresh()
	check(content:FindFirstChild("SkipPathQuests", true) == nil, "Completed stage hides skip button")
	check(
		not content:FindFirstChild("ChooseSupermarket", true).Active,
		"Next-stage button remains blocked without cash"
	)
	profile.Cash = 5000
	refresh()
	check(content:FindFirstChild("ChooseSupermarket", true).Active, "Enough cash enables next-stage purchase")
	click("ChooseSupermarket")
	check(
		profile.Cash == 0 and profile.Angler.Paths.Active == "Supermarket",
		"GUI opens next stage only after cash payment"
	)
	card.CloseMenu.Activated:Fire()
end
print(
	"Path quest skip: "
		.. checks
		.. " receipt, money requirement, save and desktop/mobile checks passed (recording mocks)."
)
