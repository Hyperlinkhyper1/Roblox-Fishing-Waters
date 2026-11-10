-- Cheaper copies of real players' avatars for crowds (townsfolk, shop customers).
--
-- Random accounts often wear layered clothing (3D jackets, shirts, shoes). Every layered
-- item runs a wrap deformer per rig: its cage meshes are fetched and the clothing mesh is
-- deformed and kept per instance. Dozens of townsfolk made that a large share of client
-- memory and frame time, and failed fetches spammed "Wrap-deformer fetching meshes
-- resulted in error". Crowds keep classic Shirt/Pants and rigid accessories (hair, hats)
-- and drop the layered items.
local AvatarLite = {}

-- Rigid accessories kept per crowd avatar; hair and hats come first in GetAccessories order.
AvatarLite.MAX_ACCESSORIES = 6

-- Pure filter over GetAccessories entries, kept separate so it can be tested without Roblox.
function AvatarLite.filter(accessories: { any }, limit: number?): { any }
	local kept = {}
	local cap = limit or AvatarLite.MAX_ACCESSORIES
	for _, accessory in accessories do
		if #kept >= cap then
			break
		end
		if not accessory.IsLayered then
			table.insert(kept, accessory)
		end
	end
	return kept
end

-- Strips layered clothing from `description` in place and returns it.
function AvatarLite.strip(description: HumanoidDescription): HumanoidDescription
	pcall(function()
		local accessories = description:GetAccessories(true)
		local kept = AvatarLite.filter(accessories)
		if #kept ~= #accessories then
			description:SetAccessories(kept, true)
		end
	end)
	return description
end

return AvatarLite
