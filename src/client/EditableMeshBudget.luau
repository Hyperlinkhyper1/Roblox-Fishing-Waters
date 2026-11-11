-- Shared by optional client visuals. A failed allocation means this device has
-- no room (or API access); don't ask Roblox again for every new fish species
-- until RETRY_AFTER has passed (or a caller forces a fresh attempt).
--
-- Roblox counts a live dynamic EditableMesh against the device budget as if it
-- were maxed out, so a long-lived cosmetic mesh (the swell water sheet) can
-- leave no room at all for fish skins. Such holders register a release
-- callback; an allocation with `evict` frees them and tries once more.
local AssetService = game:GetService("AssetService")

local EditableMeshBudget = {}
local RETRY_AFTER = 30
local failedAt = -math.huge
local failureReason: string? = nil
local evicted: { string } = {}
local releasers: { [string]: () -> () } = {}

export type Options = { force: boolean?, evict: boolean? }

function EditableMeshBudget.failureReason(): string?
	return failureReason
end

-- Cosmetic holders that would give their mesh up for a higher-priority one.
function EditableMeshBudget.onRelease(name: string, release: () -> ()): () -> ()
	releasers[name] = release
	return function()
		if releasers[name] == release then
			releasers[name] = nil
		end
	end
end

-- One line for the mesh test: who still holds a releasable mesh, who was evicted.
function EditableMeshBudget.status(): string
	local held = {}
	for name in releasers do
		table.insert(held, name)
	end
	table.sort(held)
	return string.format(
		"Releasable meshes held: %s. Released for fish: %s.",
		if #held > 0 then table.concat(held, ", ") else "none",
		if #evicted > 0 then table.concat(evicted, ", ") else "none"
	)
end

local function attempt(label: string, allocate: () -> EditableMesh?): (EditableMesh?, string?)
	local ok, result = pcall(allocate)
	if ok and result then
		return result, nil
	end
	return nil,
		label .. ": " .. (if ok
			then "returned nil (device mesh budget exhausted, or Mesh & Image APIs not allowed for this experience)"
			else tostring(result))
end

local function allocate(label: string, options: Options?, create: () -> EditableMesh?): EditableMesh?
	local force = options and options.force
	if not force and os.clock() - failedAt < RETRY_AFTER then
		return nil
	end
	local mesh, reason = attempt(label, create)
	if not mesh and options and options.evict and next(releasers) then
		for name, release in releasers do
			releasers[name] = nil
			table.insert(evicted, name)
			local ok, message = pcall(release)
			if not ok then
				warn("[EditableMeshBudget] Releasing " .. name .. " failed: " .. tostring(message))
			end
		end
		-- A destroyed mesh doesn't always hand its budget back on the same frame.
		for _ = 1, 3 do
			task.wait()
		end
		mesh, reason = attempt(label, create)
	end
	if not mesh then
		failedAt = os.clock()
		failureReason = reason
		return nil
	end
	return mesh
end

function EditableMeshBudget.create(options: Options?): EditableMesh?
	return allocate("CreateEditableMesh", options, function()
		return AssetService:CreateEditableMesh()
	end)
end

-- Fish geometry never changes after construction. Keep only the smaller fixed
-- copy; the temporary dynamic mesh must be released even if copying fails.
function EditableMeshBudget.fixed(mesh: EditableMesh, options: Options?): EditableMesh?
	-- The dynamic mesh is already held, so this copy is always attempted.
	local copyOptions: Options = { force = true, evict = options and options.evict }
	local ok, fixed = pcall(allocate, "CreateEditableMeshAsync (fixed-size copy)", copyOptions, function()
		return AssetService:CreateEditableMeshAsync(Content.fromObject(mesh), { FixedSize = true })
	end)
	mesh:Destroy()
	if not ok then
		failedAt = os.clock()
		failureReason = "CreateEditableMeshAsync (fixed-size copy): " .. tostring(fixed)
		return nil
	end
	return fixed
end

return EditableMeshBudget
