-- Shared by optional client visuals. A failed allocation means this device has
-- no room (or API access); don't ask Roblox again for every new fish species.
local AssetService = game:GetService("AssetService")

local EditableMeshBudget = {}
local unavailable = false
local failureReason: string? = nil

function EditableMeshBudget.failureReason(): string?
	return failureReason
end

function EditableMeshBudget.create(): EditableMesh?
	if unavailable then
		return nil
	end
	local ok, mesh = pcall(function()
		return AssetService:CreateEditableMesh()
	end)
	if not ok or not mesh then
		unavailable = true
		failureReason = "CreateEditableMesh: " .. (if ok then "returned nil (mesh budget or API access unavailable)" else tostring(mesh))
		return nil
	end
	return mesh
end

-- Fish geometry never changes after construction. Keep only the smaller fixed
-- copy; the temporary dynamic mesh must be released even if copying fails.
function EditableMeshBudget.fixed(mesh: EditableMesh): EditableMesh?
	if unavailable then
		mesh:Destroy()
		return nil
	end
	local ok, fixed = pcall(function()
		return AssetService:CreateEditableMeshAsync(Content.fromObject(mesh), { FixedSize = true })
	end)
	mesh:Destroy()
	if not ok or not fixed then
		unavailable = true
		failureReason = "CreateEditableMeshAsync (fixed-size copy): " .. (if ok then "returned nil (mesh budget or API access unavailable)" else tostring(fixed))
		return nil
	end
	return fixed
end

return EditableMeshBudget
