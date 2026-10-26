Menu.start()
advance(1)
profile.BobberSkins = { CrownedGoldBobber = 2, NeonPurpleBobber = 1 }
local gui = playerGui.PlayerMenu
local card = gui.MenuOverlay.MenuWindow
local content = card.Content
local requests = {}
function rodRequest:FireServer(action, value)
	table.insert(requests, { action, value })
end
local function find(name)
	return assert(content:FindFirstChild(name, true), name)
end
local function reopen()
	if gui.MenuOverlay.Visible then
		card.CloseMenu.Activated:Fire()
	end
	now += 1
	gui.LeftNavigation.Equipmentbag.Activated:Fire()
	find("BobbersCategory").Activated:Fire()
end
for _, width in { 1480, 362 } do
	card.AbsoluteSize = Vector2.new(width, 680)
	reopen()
	local gold = find("Bobber:CrownedGoldBobber")
	check(
		gold.BobberPreview.CurrentCamera ~= nil and gold.EquipBobberSkin.Text == "[Use bobber]",
		"Owned bobber has a preview and equip action"
	)
	check(
		content:FindFirstChild("Bobber:NeonPurpleBobber", true) ~= nil
			and not content:FindFirstChild("Bobber:CherryBobber", true),
		"Bag lists only owned bobber skins"
	)
	player:SetAttribute("BoatDataStatus", "Unavailable")
	local before = #requests
	gold.EquipBobberSkin.Activated:Fire()
	check(#requests == before, "Unavailable data cannot equip bobbers")
	player:SetAttribute("BoatDataStatus", "Ready")
	gold.EquipBobberSkin.Activated:Fire()
	check(
		requests[#requests][1] == "EquipBobberSkin" and requests[#requests][2] == "CrownedGoldBobber",
		"Bag equip uses the server bobber action"
	)
	player:SetAttribute("BobberSkin", "CrownedGoldBobber")
	reopen()
	find("Bobber:CrownedGoldBobber").EquipBobberSkin.Activated:Fire()
	check(requests[#requests][2] == "", "Selected bobber supports removing its skin")
	find("SearchItems").Text = "neon"
	check(
		content:FindFirstChild("Bobber:NeonPurpleBobber", true) ~= nil
			and not content:FindFirstChild("Bobber:CrownedGoldBobber", true),
		"Bobber search filters owned skins"
	)
	find("SearchItems").Text = "absent"
	check(not content:FindFirstChild("Bobber:NeonPurpleBobber", true), "Missing search results show no fake items")
	find("SearchItems").Text = ""
	find("ResetBobberSkin").Activated:Fire()
	check(
		requests[#requests][1] == "EquipBobberSkin" and requests[#requests][2] == "",
		"Starter option clears the selected bobber"
	)
	player:SetAttribute("BobberSkin", "")
end
print(
	`Bobber bag: {checks} desktop/mobile ownership, preview, equip, reset and search checks passed (recording mocks).`
)
