Menu.start()
advance(1)
local gui = playerGui.PlayerMenu
local card = gui.MenuOverlay.MenuWindow
local content = card.Content
local function find(name)
	return assert(content:FindFirstChild(name, true), "Missing equipment control: " .. name)
end
local function click(name)
	find(name).Activated:Fire()
end
local function contains(value)
	for _, item in content:GetDescendants() do
		if (item:IsA("TextLabel") or item:IsA("TextButton")) and string.find(item.Text, value, 1, true) then
			return true
		end
	end
	return false
end
-- Isolate the empty collection check from the separate group reward card.
profile.GroupRodClaimed = true
gui.LeftNavigation.Equipmentbag.Activated:Fire()
check(contains("Your equipment bag is empty"), "Only owned rods appear")
check(find("UnlockedCount").Text == "<i>0% Unlocked</i>", "Unlock count uses real catalog ownership")
check(
	contains("No baits yet") and not content:FindFirstChild("EquipRod", true),
	"Empty categories do not invent equippable items"
)
profile.OwnedRods.StarterRod = true
profile.OwnedBoats.Rowboat = true
gui.LeftNavigation.Equipmentbag.Activated:Fire()
gui.LeftNavigation.Equipmentbag.Activated:Fire()
check(find("StarterRod").Parent == find("RodCards"), "Owned rod uses a tall collection card")
local unlocked = tonumber(string.match(find("UnlockedCount").Text, "(%d+)%%"))
check(unlocked and unlocked > 0 and unlocked < 100, "Owned rod unlock percentage includes collectible skins")
local view = find("RodPreview")
check(
	view.CurrentCamera and view.PreviewWorld.DisplayRod:FindFirstChildOfClass("Tool"),
	"Actual rod builder supplies the viewport"
)
local previewTool = view.PreviewWorld.DisplayRod:FindFirstChildOfClass("Tool")
check(
	previewTool:GetAttribute("RemovedPreviewTag") == "FishingRod" and not previewTool.Enabled,
	"Preview tool stays out of live rod listeners"
)
check(previewTool:FindFirstChildOfClass("Part").Anchored, "Preview geometry is anchored")
local before = #rodActions
player:SetAttribute("BoatDataStatus", "Unavailable")
click("EquipRod")
check(#rodActions == before, "Unavailable progress cannot send an equip request")
player:SetAttribute("BoatDataStatus", "Ready")
click("EquipRod")
check(rodActions[#rodActions] == "EquipRod", "Equip still uses the server rod service")
player:SetAttribute("RodEquipped", true)
check(find("EquipRod").Text == "[Equipped · Stow]", "Equipped state follows replicated gameplay state")
click("EquipRod")
check(rodActions[#rodActions] == "UnequipRod", "Equipped rod supports stowing")
find("SearchRods").Text = "absent"
check(contains("No matching rods") and not content:FindFirstChild("StarterRod", true), "Rod search filters owned cards")
player:SetAttribute("RodEquipped", false)
check(find("SearchRods").Text == "absent" and contains("No matching rods"), "Gameplay refresh preserves the rod search")
find("SearchRods").Text = "starter"
check(find("StarterRod") ~= nil, "Rod search matches catalog names")
click("FavoriteRod")
check(find("FavoriteRod").Text == "★", "Favorite control updates its state")
local normalWidth = find("StarterRod").Size.X.Scale
click("CardDensity")
check(find("StarterRod").Size.X.Scale < normalWidth, "Density control changes card widths")
click("BoatsCategory")
check(find("Boat:Rowboat") ~= nil and contains("Wooden rowboat"), "Previously owned boats remain accessible")
find("SearchItems").Text = "absent"
check(
	contains("No matching items") and not content:FindFirstChild("Boat:Rowboat", true),
	"Secondary search filters independently"
)
check(find("SearchRods").Text == "starter", "Secondary search preserves rod search")
find("SearchItems").Text = ""
click("SortItems")
check(find("SortItems").Text == "▾  Name: Z–A", "Sort control changes order mode")
for _, category in { "Bobbers", "Baits", "Lanterns", "Accessories" } do
	click(category .. "Category")
	check(
		contains(if category == "Bobbers" then "No bobber skins yet" else "No " .. string.lower(category) .. " yet"),
		"Empty category has an honest collection state"
	)
end
card.AbsoluteSize = Vector2.new(362, 680)
check(
	find("FishingRods").Size.X.Scale == 1 and find("ItemCollection").Position.Y.Scale > 0,
	"Phone stacks item pane below the full-width rod collection"
)
check(find("StarterRod").Size.X.Scale == 0.86, "Phone rod cards stay readable and scroll horizontally")
check(find("CardDensity").Position.Y.Offset >= 47, "Phone card controls leave room for the menu close button")
profile.RodSkins = { UmbrellaRod = 2 }
profile.RodSkinCopies = {
	{ SkinId = "UmbrellaRod", Serial = 11, Wear = 0.01 },
	{ SkinId = "UmbrellaRod", Serial = 12, Wear = 0.8 },
}
find("SearchRods").Text = "umbrella"
check(contains("Factory New") and contains("Battle-Scarred"), "Each rod copy displays its wear state")
local pristineCard = find("Skin:UmbrellaRod:11")
local wornCard = find("Skin:UmbrellaRod:12")
check(pristineCard ~= wornCard, "Different wear copies remain separately selectable")
check(contains("+6%") and contains("+4%"), "Wear-adjusted bonuses appear in the collection")
check(
	find("EquipmentCategories").IsA and find("EquipmentCategories"):IsA("ScrollingFrame"),
	"Category buttons can scroll on short screens"
)
card.CloseMenu.Activated:Fire()
check(not gui.MenuOverlay.Visible and gui.LeftNavigation.Visible, "Bag closes and restores navigation")
gui.LeftNavigation.Settings.Activated:Fire()
check(card:FindFirstChildOfClass("UISizeConstraint").MaxSize.X == 1020, "Other menus retain their existing size")
print(
	"Equipment bag: "
		.. checks
		.. " ownership, preview lifecycle, equip/stow, search, categories and responsive checks passed (recording mocks)."
)
