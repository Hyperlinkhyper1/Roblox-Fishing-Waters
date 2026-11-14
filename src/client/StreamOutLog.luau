-- Temporary diagnostic: names what the client streams out when a frame hitches.
--
-- The MicroProfiler shows the hitches as Replicator GC Job / Part/Model Removals, which is the
-- engine evicting streamed parts (StreamOutBehavior LowMemory drops everything past
-- StreamingMinRadius once memory runs short). It doesn't say which parts, so this counts parts
-- leaving the workspace per second, grouped by where they sat, and prints a report whenever a
-- burst goes past REPORT_AT. Parts under a pinned LodPiece are flagged, since those should never
-- leave. Server Destroy calls land here too; those are usually close to the player, which is
-- what the "beyond min radius" count is for.
--
-- Remove this module (and its entry in init.client.luau) once the culprit is known.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local StreamOutLog = {}

local WINDOW = 1 -- seconds per report window
local REPORT_AT = 100 -- parts removed in one window before it's worth printing
local TOP = 10 -- groups listed per report
local DEPTH = 3 -- path levels below workspace a group is named by
local MIN_RADIUS = 64 -- StreamingMinRadius in default.project.json; streaming never evicts closer
local PIECE_TAG = "LodPiece"

-- Parent -> group name, so a burst of thousands of parts costs one walk per container
local groups: { [Instance]: string } = setmetatable({}, { __mode = "k" }) :: any

local function groupOf(parent: Instance): string
	local cached = groups[parent]
	if cached then
		return cached
	end
	local chain = {}
	local pinned = false
	local node: Instance? = parent
	while node and node ~= workspace do
		if not pinned and node:HasTag(PIECE_TAG) then
			pinned = true
		end
		table.insert(chain, node.Name)
		node = node.Parent
	end
	local names = {}
	for i = #chain, math.max(1, #chain - DEPTH + 1), -1 do
		table.insert(names, chain[i])
	end
	local name = if #names > 0 then table.concat(names, "/") else "(workspace)"
	if pinned then
		name = "[PINNED] " .. name
	end
	groups[parent] = name
	return name
end

function StreamOutLog.start()
	local player = Players.LocalPlayer
	local removed: { [string]: number } = {}
	local total, far, arrived = 0, 0, 0
	local worst = 0
	local windowStart = os.clock()

	local function focus(): Vector3?
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			return root.Position
		end
		local camera = workspace.CurrentCamera
		return camera and camera.CFrame.Position
	end
	local centre = focus()

	workspace.DescendantRemoving:Connect(function(d)
		if not d:IsA("BasePart") then
			return
		end
		local parent = d.Parent
		if not parent or (player.Character and d:IsDescendantOf(player.Character)) then
			return
		end
		total += 1
		if centre and (d.Position - centre).Magnitude > MIN_RADIUS then
			far += 1
		end
		local name = groupOf(parent)
		removed[name] = (removed[name] or 0) + 1
	end)

	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			arrived += 1
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		if dt > worst then
			worst = dt
		end
		local now = os.clock()
		if now - windowStart < WINDOW then
			return
		end
		if total >= REPORT_AT then
			local sorted = {}
			for name, count in removed do
				table.insert(sorted, { name = name, count = count })
			end
			table.sort(sorted, function(a, b)
				return a.count > b.count
			end)
			local lines = {
				string.format(
					"[StreamOut] %d parts left in %.1fs (%d beyond %d studs), %d arrived, worst frame %d ms, memory %d MB",
					total,
					now - windowStart,
					far,
					MIN_RADIUS,
					arrived,
					math.round(worst * 1000),
					math.round(Stats:GetTotalMemoryUsageMb())
				),
			}
			for i = 1, math.min(TOP, #sorted) do
				table.insert(lines, string.format("  %6d  %s", sorted[i].count, sorted[i].name))
			end
			if #sorted > TOP then
				table.insert(lines, string.format("  ...and %d more groups", #sorted - TOP))
			end
			warn(table.concat(lines, "\n"))
		end
		table.clear(removed)
		total, far, arrived, worst = 0, 0, 0, 0
		windowStart = now
		centre = focus()
	end)
end

return StreamOutLog
