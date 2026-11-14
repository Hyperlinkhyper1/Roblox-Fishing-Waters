-- Shared by optional client visuals. A failed allocation means this device has
-- no room (or API access); don't ask Roblox again for every new fish species
-- until RETRY_AFTER has passed (or a caller forces a fresh attempt).
--
-- Roblox counts a live dynamic EditableMesh against the device budget as if it
-- were maxed out, and a destroyed one doesn't always hand that budget back on
-- the same frame. Builders therefore reuse one scratch dynamic mesh (clear())
-- and keep only fixed-size copies (fixed(..., keepSource)).
--
-- A long-lived cosmetic mesh (the swell water sheet) can leave no room at all
-- for fish skins. Such holders register a one-shot release callback; caches
-- that can rebuild later (skins nobody is showing) register a reclaimer that
-- may run on every shortage. An allocation with `evict` frees both and tries
-- once more.
local AssetService = game:GetService("AssetService")

local EditableMeshBudget = {}
local RETRY_AFTER = 30
local failedAt = -math.huge
local failureReason: string? = nil
local evicted: { string } = {}
local releasers: { [string]: () -> () } = {}
local reclaimers: { [string]: () -> number } = {}

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

-- Caches that can free meshes repeatedly; `reclaim` returns how many it freed.
function EditableMeshBudget.onReclaim(name: string, reclaim: () -> number): () -> ()
	reclaimers[name] = reclaim
	return function()
		if reclaimers[name] == reclaim then
			reclaimers[name] = nil
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

local function noteEvicted(name: string)
	if not table.find(evicted, name) then
		table.insert(evicted, name)
	end
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

-- Frees every releasable holder and reclaimable cache; true if anything went.
local function evict(): boolean
	local freed = false
	for name, release in releasers do
		releasers[name] = nil
		noteEvicted(name)
		freed = true
		local ok, message = pcall(release)
		if not ok then
			warn("[EditableMeshBudget] Releasing " .. name .. " failed: " .. tostring(message))
		end
	end
	for name, reclaim in reclaimers do
		local ok, count = pcall(reclaim)
		if not ok then
			warn("[EditableMeshBudget] Reclaiming " .. name .. " failed: " .. tostring(count))
		elseif type(count) == "number" and count > 0 then
			noteEvicted(name)
			freed = true
		end
	end
	return freed
end

local function allocate(label: string, options: Options?, create: () -> EditableMesh?): EditableMesh?
	local force = options and options.force
	if not force and os.clock() - failedAt < RETRY_AFTER then
		return nil
	end
	local mesh, reason = attempt(label, create)
	if not mesh and options and options.evict and evict() then
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

-- Empties a scratch dynamic mesh so the next piece can be built in it without
-- allocating (and budgeting) another one.
function EditableMeshBudget.clear(mesh: EditableMesh)
	for _, face in mesh:GetFaces() do
		mesh:RemoveFace(face)
	end
	mesh:RemoveUnused()
end

-- Geometry that never changes after construction keeps only the smaller fixed
-- copy. The dynamic source is destroyed even if copying fails, unless the
-- caller keeps it as a scratch mesh (`keepSource`) and destroys it itself.
function EditableMeshBudget.fixed(mesh: EditableMesh, options: Options?, keepSource: boolean?): EditableMesh?
	-- The dynamic mesh is already held, so this copy is always attempted.
	local copyOptions: Options = { force = true, evict = options and options.evict }
	local ok, fixed = pcall(allocate, "CreateEditableMeshAsync (fixed-size copy)", copyOptions, function()
		return AssetService:CreateEditableMeshAsync(Content.fromObject(mesh), { FixedSize = true })
	end)
	if not keepSource then
		mesh:Destroy()
	end
	if not ok then
		failedAt = os.clock()
		failureReason = "CreateEditableMeshAsync (fixed-size copy): " .. tostring(fixed)
		return nil
	end
	return fixed
end

return EditableMeshBudget
