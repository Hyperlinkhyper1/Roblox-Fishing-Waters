-- Production loading source runs against these mocks with only its pure geometry
-- dependency bound locally, without changing any UI or readiness logic.
-- A virtual scheduler makes slow streaming and readiness transitions reproducible.
local checks = 0
local function check(condition, message)
	checks += 1
	assert(condition, message)
end

local function scenario(mode)
	local now, queue, signals, instances, tweens = 0, {}, {}, {}, {}
	local sequence = 0
	local viewport = if mode == "mobile" then { X = 393, Y = 852 } else { X = 1280, Y = 720 }
	local function schedule(thread, delay, ...)
		sequence += 1
		table.insert(queue, { thread = thread, at = now + (delay or 0), order = sequence, args = table.pack(...) })
	end
	local function resume(thread, ...)
		if coroutine.status(thread) == "dead" then
			return
		end
		local ok, delay = coroutine.resume(thread, ...)
		assert(ok, tostring(delay))
		if coroutine.status(thread) ~= "dead" and type(delay) == "number" then
			schedule(thread, delay, delay)
		end
	end
	local task = {}
	function task.wait(duration)
		return coroutine.yield(duration or 1 / 60)
	end
	function task.spawn(callback, ...)
		local thread = if type(callback) == "thread" then callback else coroutine.create(callback)
		resume(thread, ...)
		return thread
	end
	function task.defer(callback, ...)
		local thread = coroutine.create(callback)
		schedule(thread, 0, ...)
		return thread
	end
	function task.delay(duration, callback, ...)
		local thread = coroutine.create(callback)
		schedule(thread, duration, ...)
		return thread
	end
	function task.cancel(thread)
		for index = #queue, 1, -1 do
			if queue[index].thread == thread then
				table.remove(queue, index)
			end
		end
		if coroutine.status(thread) ~= "dead" then
			coroutine.close(thread)
		end
	end
	local function advance(duration)
		local target, iterations = now + duration, 0
		while true do
			table.sort(queue, function(a, b)
				return a.at < b.at or (a.at == b.at and a.order < b.order)
			end)
			local item = queue[1]
			if not item or item.at > target then
				break
			end
			table.remove(queue, 1)
			now = item.at
			resume(item.thread, table.unpack(item.args, 1, item.args.n))
			iterations += 1
			assert(iterations < 100000, "Loading scheduler must yield")
		end
		now = target
	end
	local function signal()
		local handlers = {}
		local result = {}
		function result:Connect(callback)
			local connection = { Connected = true }
			function connection:Disconnect()
				self.Connected = false
			end
			table.insert(handlers, { callback = callback, connection = connection })
			return connection
		end
		function result:Once(callback)
			local connection
			connection = self:Connect(function(...)
				connection:Disconnect()
				callback(...)
			end)
			return connection
		end
		function result:Wait()
			local thread = coroutine.running()
			self:Once(function(...)
				schedule(thread, 0, ...)
			end)
			return coroutine.yield("signal")
		end
		function result:Fire(...)
			for _, handler in table.clone(handlers) do
				if handler.connection.Connected then
					task.spawn(handler.callback, ...)
				end
			end
		end
		function result:DisconnectAll()
			for _, handler in handlers do
				handler.connection:Disconnect()
			end
		end
		function result:Count()
			local count = 0
			for _, handler in handlers do
				if handler.connection.Connected then
					count += 1
				end
			end
			return count
		end
		table.insert(signals, result)
		return result
	end
	local Vector2 = {
		new = function(x, y)
			return { X = x, Y = y, _type = "Vector2" }
		end,
	}
	local vectorMeta = {}
	local Vector3 = {}
	function Vector3.new(x, y, z)
		return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, _type = "Vector3" }, vectorMeta)
	end
	function vectorMeta.__add(a, b)
		return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
	end
	function vectorMeta.__sub(a, b)
		return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
	end
	function vectorMeta.__mul(a, b)
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	function vectorMeta.__index(a, key)
		if key == "Magnitude" then
			return math.sqrt(a.X ^ 2 + a.Y ^ 2 + a.Z ^ 2)
		end
		if key == "Unit" then
			return a * (1 / a.Magnitude)
		end
		return nil
	end
	Vector3.zero = Vector3.new()
	local Color3 = {}
	function Color3.new(r, g, b)
		return { R = r, G = g, B = b, _type = "Color3" }
	end
	function Color3.fromRGB(r, g, b)
		return Color3.new(r / 255, g / 255, b / 255)
	end
	local UDim = {
		new = function(scale, offset)
			return { Scale = scale, Offset = offset, _type = "UDim" }
		end,
	}
	local UDim2 = {}
	function UDim2.new(xs, xo, ys, yo)
		return { X = UDim.new(xs, xo), Y = UDim.new(ys, yo), _type = "UDim2" }
	end
	function UDim2.fromScale(x, y)
		return UDim2.new(x, 0, y, 0)
	end
	function UDim2.fromOffset(x, y)
		return UDim2.new(0, x, 0, y)
	end
	local Path2DControlPoint = {
		new = function(position, left, right)
			return {
				Position = position,
				LeftTangent = left,
				RightTangent = right,
				_type = "Path2DControlPoint",
			}
		end,
	}
	local ColorSequenceKeypoint = {
		new = function(time, color)
			return { Time = time, Value = color }
		end,
	}
	local NumberSequenceKeypoint = {
		new = function(time, value)
			return { Time = time, Value = value }
		end,
	}
	local ColorSequence = {
		new = function(...)
			return { ... }
		end,
	}
	local NumberSequence = {
		new = function(...)
			return { ... }
		end,
	}
	local Enum = setmetatable({}, {
		__index = function(self, key)
			local values = setmetatable({}, {
				__index = function(_, value)
					return value
				end,
			})
			rawset(self, key, values)
			return values
		end,
	})
	local TweenInfo = {
		new = function(duration, _, _, repeats, reverses)
			return { Time = duration, RepeatCount = repeats or 0, Reverses = reverses }
		end,
	}
	local RaycastParams = {
		new = function()
			return {}
		end,
	}
	local Instance, methods = {}, {}
	function Instance.new(kind)
		local object = {
			_props = {
				Name = kind,
				ClassName = kind,
				ZIndex = 1,
				AbsoluteSize = Vector2.new(viewport.X, viewport.Y),
				AbsolutePosition = Vector2.new(0, 0),
				Visible = true,
				BackgroundTransparency = 0,
				TextTransparency = 0,
				TextStrokeTransparency = 1,
				Transparency = 0,
				Position = Vector3.zero,
				CanCollide = true,
			},
			children = {},
			attributes = {},
			properties = {},
			events = {},
			destroyed = false,
		}
		setmetatable(object, {
			__index = function(self, key)
				if methods[key] then
					return methods[key]
				end
				if self._props[key] ~= nil then
					return self._props[key]
				end
				if
					key == "Activated"
					or key == "Destroying"
					or key == "AncestryChanged"
					or key == "Changed"
					or key == "ChildAdded"
				then
					if not self.events[key] then
						self.events[key] = signal()
					end
					return self.events[key]
				end
				return self:FindFirstChild(key)
			end,
			__newindex = function(self, key, value)
				if key == "Parent" then
					local old = self._props.Parent
					if old then
						local index = table.find(old.children, self)
						if index then
							table.remove(old.children, index)
						end
					end
					if value then
						table.insert(value.children, self)
					end
				end
				self._props[key] = value
				if self.properties[key] then
					self.properties[key]:Fire()
				end
			end,
		})
		table.insert(instances, object)
		return object
	end
	function methods:IsA(kind)
		return self.ClassName == kind
			or (kind == "GuiObject" and table.find(
				{ "Frame", "TextLabel", "TextButton", "ImageLabel", "CanvasGroup" },
				self.ClassName
			) ~= nil)
			or (kind == "BasePart" and self.ClassName == "Part")
	end
	function methods:FindFirstChild(name, recursive)
		for _, child in self.children do
			if child.Name == name then
				return child
			end
			if recursive then
				local found = child:FindFirstChild(name, true)
				if found then
					return found
				end
			end
		end
		return nil
	end
	function methods:FindFirstChildOfClass(kind)
		for _, child in self.children do
			if child:IsA(kind) then
				return child
			end
		end
		return nil
	end
	function methods:WaitForChild(name)
		return assert(self:FindFirstChild(name), "Missing mocked child: " .. name)
	end
	function methods:GetChildren()
		return table.clone(self.children)
	end
	function methods:SetControlPoints(points)
		assert(self.ClassName == "Path2D", "Control points must belong to a native Path2D")
		self.ControlPoints = table.clone(points)
	end
	function methods:GetDescendants()
		local result = {}
		for _, child in self.children do
			table.insert(result, child)
			for _, descendant in child:GetDescendants() do
				table.insert(result, descendant)
			end
		end
		return result
	end
	function methods:GetAttribute(name)
		return self.attributes[name]
	end
	function methods:SetAttribute(name, value)
		self.attributes[name] = value
		if self.events["attribute:" .. name] then
			self.events["attribute:" .. name]:Fire()
		end
	end
	function methods:GetAttributeChangedSignal(name)
		local key = "attribute:" .. name
		if not self.events[key] then
			self.events[key] = signal()
		end
		return self.events[key]
	end
	function methods:GetPropertyChangedSignal(name)
		if not self.properties[name] then
			self.properties[name] = signal()
		end
		return self.properties[name]
	end
	function methods:Destroy()
		if self.destroyed then
			return
		end
		self.destroyed = true
		self.destroyedAt = now
		if self.events.Destroying then
			self.events.Destroying:Fire()
		end
		for _, child in self:GetChildren() do
			child:Destroy()
		end
		for _, event in self.events do
			event:DisconnectAll()
		end
		for _, event in self.properties do
			event:DisconnectAll()
		end
		self.Parent = nil
	end
	local player = Instance.new("Player")
	local playerGui = Instance.new("PlayerGui")
	playerGui.Parent = player
	local character = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Position = Vector3.new(100, 8, 20)
	root.Parent = character
	local humanoid = Instance.new("Humanoid")
	humanoid.Health = if mode == "dead-character" then 0 else 100
	humanoid.Parent = character
	player.Character = if mode == "character" then nil else character
	player:SetAttribute(
		"FishingWatersClientReady",
		mode ~= "client" and mode ~= "client-error" and mode ~= "slow-client"
	)
	player:SetAttribute("FishingWatersSpawnReady", mode ~= "placement")
	local ReplicatedStorage = Instance.new("ReplicatedStorage")
	ReplicatedStorage:SetAttribute("FishingWatersWorldReady", mode ~= "world")
	if mode == "fatal-error" then
		ReplicatedStorage:SetAttribute("FishingWatersStartupError", true)
	end
	local worldLoaded, ground = mode ~= "game", mode ~= "ground"
	local workspace = Instance.new("Workspace")
	workspace.StreamingEnabled = true
	workspace.CurrentCamera = { ViewportSize = Vector2.new(viewport.X, viewport.Y) }
	local groundPart = Instance.new("Part")
	local raycasts, streamRequests, defaultRemoved = 0, 0, false
	function workspace:Raycast(origin, direction, parameters)
		raycasts += 1
		check(direction.Y < 0, "Spawn safety must raycast down toward the dock")
		check(origin.Y > root.Position.Y, "Spawn probe should begin above the character's feet")
		check(
			parameters.IgnoreWater and parameters.RespectCanCollide,
			"Spawn safety must require solid ground, excluding water and non-colliding decoration"
		)
		check(
			table.find(parameters.FilterDescendantsInstances, character) ~= nil,
			"Spawn probe must exclude the local character"
		)
		return if ground
			then {
				Instance = groundPart,
				Position = Vector3.new(100, 5, 20),
				Normal = Vector3.new(0, 1, 0),
				Distance = 3,
				Material = "Wood",
			}
			else nil
	end
	function player:RequestStreamAroundAsync(_, timeout)
		streamRequests += 1
		task.wait(timeout or 8)
	end
	local TweenService = {}
	function TweenService:Create(target, info, goals)
		local tween =
			{ Completed = signal(), target = target, info = info, goals = goals, playing = false, cancelled = false }
		function tween:Play()
			self.playing = true
			if self.info.RepeatCount < 0 then
				return
			end
			self.thread = task.delay(self.info.Time, function()
				if self.cancelled then
					return
				end
				for key, value in self.goals do
					self.target[key] = value
				end
				self.playing = false
				self.Completed:Fire("Completed")
			end)
		end
		function tween:Cancel()
			self.cancelled, self.playing = true, false
			if self.thread then
				task.cancel(self.thread)
			end
		end
		table.insert(tweens, tween)
		return tween
	end
	local ReplicatedFirst = {
		RemoveDefaultLoadingScreen = function()
			check(
				playerGui:FindFirstChild("FishingWatersLoading") ~= nil,
				"Custom screen must mount before removing Roblox loading screen"
			)
			defaultRemoved = true
		end,
	}
	local RunService = { Heartbeat = signal(), RenderStepped = signal() }
	local game = { Loaded = signal() }
	function game:GetService(name)
		return assert(
			({
				Players = { LocalPlayer = player },
				ReplicatedFirst = ReplicatedFirst,
				ReplicatedStorage = ReplicatedStorage,
				TweenService = TweenService,
				RunService = RunService,
				Workspace = workspace,
			})[name],
			"Unexpected service: " .. name
		)
	end
	function game:IsLoaded()
		return worldLoaded
	end
	local os = {
		clock = function()
			return now
		end,
	}
	local warn = function() end
	local Theme = (function()
		-- UI_THEME --
	end)()
	local FishSkeletonGeometry = (function()
		-- FISH_SKELETON_GEOMETRY --
	end)()
	local loading = coroutine.create(function()
		-- LOADING_SOURCE --
	end)
	resume(loading)
	check(defaultRemoved, "Replacement should be visible immediately")
	local gui = assert(playerGui:FindFirstChild("FishingWatersLoading"), "Loading overlay must exist during its fade")
	local screen = assert(gui:FindFirstChild("Screen"), "Loading screen must have a native root Frame")
	check(screen.ClassName == "Frame", "Full-screen background must render on a native Frame")
	local background = screen.BackgroundColor3
	check(
		background.R == background.G and background.G == background.B and background.R == 51 / 255,
		"Loading screen must use the shared charcoal background"
	)
	local mark = assert(gui:FindFirstChild("FishSkeletonMark", true), "Loading mark must use the curved fish skeleton")
	check(mark.ClassName == "Frame", "Fish skeleton must have a native Frame parent")
	check(gui:FindFirstChild("FloatMark", true) == nil, "Fish skeleton must replace the bobber")
	local fishPaths = {}
	local function validCoordinates(value)
		if type(value) ~= "table" then
			return false
		end
		local function finite(number)
			return type(number) == "number" and number == number and math.abs(number) < math.huge
		end
		if value._type == "UDim2" then
			return finite(value.X.Scale) and finite(value.X.Offset) and finite(value.Y.Scale) and finite(value.Y.Offset)
		end
		return false
	end
	for _, path in mark:GetChildren() do
		if path.ClassName == "Path2D" then
			table.insert(fishPaths, path)
			check(path.Parent == mark, "Fish paths must mount directly in the native mark Frame")
			check(type(path.Thickness) == "number" and path.Thickness > 0, "Fish paths need a visible stroke")
			local points = path.ControlPoints
			check(type(points) == "table" and #points >= 2, "Fish paths need at least two control points")
			for _, point in points do
				check(point._type == "Path2DControlPoint", "Fish paths must use native control points")
				check(
					validCoordinates(point.Position)
						and validCoordinates(point.LeftTangent)
						and validCoordinates(point.RightTangent),
					"Fish path positions and tangent offsets must be finite coordinates"
				)
			end
		end
	end
	check(#fishPaths > 0, "Fish skeleton must render with native Path2D strokes")
	if mode == "ready" or mode == "mobile" then
		local function json(value)
			if type(value) == "string" then
				return '"'
					.. string.gsub(
						string.gsub(string.gsub(string.gsub(value, "\\", "\\\\"), '"', '\\"'), "\n", "\\n"),
						"\r",
						"\\r"
					)
					.. '"'
			elseif type(value) == "number" or type(value) == "boolean" then
				return tostring(value)
			elseif type(value) == "table" then
				local values = {}
				for key, item in value do
					if key ~= "Parent" and type(item) ~= "function" then
						table.insert(values, json(tostring(key)) .. ":" .. json(item))
					end
				end
				return "{" .. table.concat(values, ",") .. "}"
			end
			return "null"
		end
		local function snapshot(instance)
			local children = {}
			for index, child in instance.children do
				children[index] = snapshot(child)
			end
			return { properties = instance._props, children = children }
		end
		print(
			(if mode == "mobile" then "LOADING_MOBILE_TREE " else "LOADING_TREE ")
				.. json({ viewport = viewport, root = snapshot(gui) })
		)
	end
	for _, item in gui:GetDescendants() do
		check(item.ClassName ~= "CanvasGroup", "Opaque native Frames must avoid full-screen CanvasGroup texture fading")
		if item.ClassName == "UIGradient" then
			check(
				item.Parent.Name == "ThemeFace" and item.Parent.Parent.Name == "Continue",
				"Only the fallback button needs a beveled finish"
			)
		end
	end
	if
		mode == "world"
		or mode == "character"
		or mode == "dead-character"
		or mode == "placement"
		or mode == "client"
		or mode == "ground"
		or mode == "game"
	then
		advance(13.2)
		check(not gui.destroyed, mode .. " readiness must hold the loading overlay")
		if mode ~= "client" then
			check(
				not assert(gui:FindFirstChild("Continue", true)).Visible,
				"Continue must never bypass " .. mode .. " spawn safety"
			)
		end
		if mode == "world" then
			ReplicatedStorage:SetAttribute("FishingWatersWorldReady", true)
		elseif mode == "character" then
			player.Character = character
		elseif mode == "dead-character" then
			humanoid.Health = 100
		elseif mode == "placement" then
			player:SetAttribute("FishingWatersSpawnReady", true)
		elseif mode == "client" then
			player:SetAttribute("FishingWatersClientReady", true)
		elseif mode == "ground" then
			ground = true
		elseif mode == "game" then
			worldLoaded = true
			game.Loaded:Fire()
		end
		advance(1)
		check(gui.destroyed, mode .. " readiness should release the overlay immediately when satisfied")
	elseif mode == "fatal-error" then
		advance(13.2)
		check(not gui.destroyed, "Fatal world startup error must keep the overlay")
		check(
			not assert(gui:FindFirstChild("Continue", true)).Visible,
			"Continue must not bypass a fatal startup error"
		)
		ReplicatedStorage:SetAttribute("FishingWatersStartupError", nil)
		advance(1)
		check(gui.destroyed, "Recovered startup error should allow the normal readiness path")
	elseif mode == "client-error" or mode == "slow-client" then
		advance(2)
		check(not gui.destroyed, "Incomplete required client startup must keep the overlay")
		if mode == "client-error" then
			player:SetAttribute("FishingWatersClientError", true)
			advance(0.2)
		else
			advance(10.2)
		end
		local button = gui:FindFirstChild("Continue", true)
		check(button ~= nil and button.Visible, "A late or failed client startup must leave an actionable escape")
		button.Activated:Fire()
		advance(1)
		check(gui.destroyed, "Continue should dismiss a startup failure")
	else
		advance(1)
		check(
			gui.destroyed,
			"Already-ready startup must finish in under one second without a forced minimum or stream wait"
		)
		check(gui.destroyedAt <= 0.35, "An already-ready player should see only the short exit fade")
		check(
			player:GetAttribute("FishingWatersLoadingSeconds") == 0,
			"Ready startup must report no artificial loading delay"
		)
	end
	check(coroutine.status(loading) == "dead", "Loading script must finish after dismissal")
	check(raycasts > 0, "Loaded character must have streamed ground before automatic dismissal")
	for _, tween in tweens do
		check(not tween.playing, "Dismissal must stop every running animation")
		if tween.info.RepeatCount < 0 then
			check(tween.cancelled, "Repeating animation must be cancelled explicitly")
		end
	end
	for _, path in fishPaths do
		check(path.Thickness == 0, "Fish paths must fade with the loading screen before cleanup")
		check(path.destroyed, "Dismissal must destroy every fish path")
	end
	for _, event in signals do
		check(event:Count() == 0, "Dismissal must release loading-screen signal connections")
	end
	print(
		"Loading screen "
			.. mode
			.. ": ready gates and cleanup passed (dismissed at "
			.. string.format("%.2f", gui.destroyedAt)
			.. "s virtual time, "
			.. streamRequests
			.. " stream requests)"
	)
end

for _, mode in
	{
		"ready",
		"mobile",
		"game",
		"world",
		"character",
		"dead-character",
		"placement",
		"client",
		"ground",
		"client-error",
		"slow-client",
		"fatal-error",
	}
do
	scenario(mode)
end
print("Loading screen: " .. checks .. " checks passed")
