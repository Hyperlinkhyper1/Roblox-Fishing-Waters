local Catalog = (function()
-- BUILDING_CATALOG --
end)()
local checks = 0
local function check(value, message)
	assert(value, message)
	checks += 1
end
local vector = {}
vector.__index = vector
function vector:Dot(other) return self.X * other.X + self.Y * other.Y + (self.Z or 0) * (other.Z or 0) end
function vector.__add(a, b) return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y, Z = (a.Z or 0) + (b.Z or 0) }, vector) end
function vector.__sub(a, b) return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y, Z = (a.Z or 0) - (b.Z or 0) }, vector) end
function vector.__mul(a, b) return setmetatable({ X = a.X * b, Y = a.Y * b, Z = (a.Z or 0) * b }, vector) end
local Vector2 = { new = function(x, y) return setmetatable({ X = x, Y = y }, vector) end }
Vector2.zero = Vector2.new(0, 0)
local Vector3 = { new = function(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, vector) end }
local identity = { UpVector = Vector3.new(0, 1, 0) }
function identity:PointToObjectSpace(point) return point end
setmetatable(identity, { __mul = function(_, point) return point end })
local CFrame = { identity = identity }
local colorEquality={__eq=function(a,b) return a.R==b.R and a.G==b.G and a.B==b.B end}
local Color3 = {
	new = function(r, g, b) return setmetatable({ R = r, G = g, B = b },colorEquality) end,
	fromRGB = function(r, g, b) return setmetatable({ R = r / 255, G = g / 255, B = b / 255 },colorEquality) end,
}
local UDim = { new = function(...) return { ... } end }
local UDim2 = { new = UDim.new, fromOffset = UDim.new, fromScale = UDim.new }
local Enum = setmetatable({}, { __index = function(self, name)
	local category = setmetatable({}, { __index = function(_, value) return value end })
	rawset(self, name, category)
	return category
end })
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback) table.insert(callbacks, callback); return { Disconnect = function() end } end,
		Fire = function(_, ...) for _, callback in callbacks do callback(...) end end,
	}
end
local instances = {}
local methods = {}
function methods:FindFirstChild(name)
	for _, item in instances do if item.Parent == self and item.Name == name then return item end end
	return nil
end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name), "Missing mock child " .. name) end
function methods:GetPropertyChangedSignal(name)
	local signals=self._properties.PropertySignals or {};self._properties.PropertySignals=signals
	signals[name]=signals[name] or signal();return signals[name]
end
function methods:GetChildren()
	local found = {}
	for _, item in instances do if item.Parent == self then table.insert(found, item) end end
	return found
end
function methods:GetDescendants()
	local found = {}
	for _, item in instances do
		local cursor = item.Parent
		while cursor do
			if cursor == self then table.insert(found, item); break end
			cursor = cursor.Parent
		end
	end
	return found
end
function methods:SetAttribute(name, value) self._attributes[name] = value end
function methods:GetAttribute(name) return self._attributes[name] end
function methods:IsA(class) return self.ClassName == class or class == "BasePart" and self.ClassName == "Part" end
function methods:Destroy()
	for _, child in self:GetDescendants() do child.Parent = nil end
	self.Parent = nil
	self.Destroyed = true
end
local Instance = {}
function Instance.new(class)
	local item = setmetatable({ _properties = { ClassName = class, Name = class }, _attributes = {} }, {
		__index = function(self, key)
			local value = self._properties[key]
			if value ~= nil then return value end
			if methods[key] then return methods[key] end
			if key == "Activated" or key == "FocusLost" or key == "OnClientEvent" then
				local event = signal(); self._properties[key] = event; return event
			end
			if key == "AbsolutePosition" then return Vector2.new(0, 800) end
			if key == "AbsoluteSize" then return Vector2.new(1020, 190) end
			if key == "Visible" then return true end
			if key == "Parent" then return nil end
			return methods.FindFirstChild(self, key)
		end,
		__newindex = function(self, key, value)
			local old=self._properties[key];self._properties[key] = value
			local events=self._properties.PropertySignals
			if old~=value and events and events[key] then events[key]:Fire() end
		end,
	})
	table.insert(instances, item)
	return item
end
local function named(class, name, parent)
	local item = Instance.new(class)
	item.Name, item.Parent = name, parent
	return item
end
local Theme = { Colors = { Inset = Color3.new(0, 0, 0) } }
for _, method in { "text", "glassButton", "glassWindow", "corner", "scroll" } do Theme[method] = function() end end
local previewCalls = {}
local PaintQueue
local expectedFrame = identity
local Renderer = { preview = function(parent, frame, entry, pieces, builtins, valid, site)
	check(frame == expectedFrame, "The public colon API must preserve the house frame")
	table.insert(previewCalls, { Entry = entry, Valid = valid, Site = site, Builtins = builtins })
	return named("Model", "Preview", parent)
end }
Renderer.thumbnail = function(view, entry) view.PreviewStyle = entry.Style end
local replicated = named("Folder", "ReplicatedStorage")
replicated.Shared = { BuildingCatalog = "catalog", BuildingRenderer = "renderer" }
local network = named("Folder", "Building", replicated)
local request = named("RemoteFunction", "Request", network)
local update = named("RemoteEvent", "Update", network)
local first = named("Folder", "ReplicatedFirst")
named("ModuleScript", "UITheme", first)
local input = { GetFocusedTextBox = function() return nil end, IsKeyDown = function() return false end }
local services = { Players = {}, ReplicatedStorage = replicated, UserInputService = input, ReplicatedFirst = first }
local game = { GetService = function(_, name) return assert(services[name], name) end }
local function require(token)
	if token == "catalog" then return Catalog elseif token == "renderer" then return Renderer elseif token == "paintQueue" then return PaintQueue else return Theme end
end
local script = { Parent = { BuildPaintQueue = "paintQueue" } }
local rayHit = nil
local workspace = named("Folder", "Workspace")
workspace.CurrentCamera = {
	ViewportSize = Vector2.new(1920, 1080),
	ScreenPointToRay = function(_, x, y) return { Origin = Vector3.new(x, 100, y), Direction = Vector3.new(0, -1, 0) } end,
}
workspace.Raycast = function(_, _, _, parameters)
	if not rayHit then return nil end
	for _, target in parameters.FilterDescendantsInstances do if target == rayHit.Instance then return rayHit end end
	return nil
end
local RaycastParams = { new = function() return {} end }
local task = {}
local clock=0
local os={clock=function() return clock end}
function task.wait(seconds) clock+=seconds or 0;return seconds end
function task.spawn(callback,...)
	local thread=if type(callback)=='thread' then callback else coroutine.create(callback)
	local ok,reason=coroutine.resume(thread,...);assert(ok,reason)
	return thread
end
task.defer=task.spawn
PaintQueue=(function()
-- BUILD_PAINT_QUEUE --
end)()
local serverState = { Cash = 10000, Pieces = {}, Overrides = {}, Builtins = {}, CanUndo = false, CanRedo = false }
local calls, nextId, pieceInstances = {}, 1, {}
local house = named("Model", "Home", workspace)
local wall = named("Part", "ExistingWall", house)
wall:SetAttribute("BuildingId", "b:fixture")
wall:SetAttribute("BuildingKind", "Wall")
wall.Material, wall.Color = Enum.Material.Plaster, Color3.fromRGB(235,229,211)
serverState.Builtins["b:fixture"] = {
	Id = "b:fixture", Kind = "Wall", X1 = -20, Z1 = -20.25, X2 = 20, Z2 = -20.25,
	BaseY = 0.16, Height = 11.5, Thickness = 0.45, Level = 0, Material = "Plaster", Color = { 235, 229, 211 },
}
local function deep(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[key] = deep(child) end
	return result
end
local delayPaint, waitingPaint = false, {}
local function acknowledgePaint(index, accepted)
	local record=assert(waitingPaint[index],'No paint acknowledgement is waiting')
	local ok,reason=coroutine.resume(record.Thread,accepted~=false)
	assert(ok,reason)
end
function request:InvokeServer(action, payload, site)
	table.insert(calls, { Action = action, Payload = deep(payload), Site = site })
	if action == "PaintBatch" and delayPaint then
		table.insert(waitingPaint,{Thread=coroutine.running(),Payload=deep(payload),Site=site})
		if coroutine.yield('paint save pending')==false then return {Ok=false,Message='Save rejected',State=deep(serverState)} end
	end
	if action == "Place" then
		for _, raw in payload.Entries do
			local entry = deep(raw); entry.Id = "p" .. nextId; nextId += 1
			table.insert(serverState.Pieces, entry)
			local part = named("Part", entry.Id, house)
			part:SetAttribute("BuildingId", entry.Id)
			part:SetAttribute("BuildingKind", entry.Kind)
			pieceInstances[entry.Id] = part
		end
	elseif action == "Move" then
		for index, entry in serverState.Pieces do
			if entry.Id == payload.Id then local moved = deep(payload.Entry); moved.Id = entry.Id; serverState.Pieces[index] = moved end
		end
	elseif action == "Remove" then
		serverState.Overrides[payload.Id] = { Removed = true }
	elseif action == "PaintBatch" then
		for _, patch in payload.Entries do
			local custom=false
			for _,entry in serverState.Pieces do
				if entry.Id==patch.Id then entry.Material,entry.Color=patch.Material,deep(patch.Color);custom=true end
			end
			if not custom then serverState.Overrides[patch.Id]={Material=patch.Material,Color=deep(patch.Color)} end
		end
	end
	if action ~= "Get" then serverState.CanUndo = true end
	return { Ok = true, State = deep(serverState) }
end
local StructureEditor = (function()
-- STRUCTURE_EDITOR --
end)()
local furnitureCard = named("TextButton", "FurnitureCard")
local furnitureTitle = named("TextLabel", "FurnitureTitle", furnitureCard)
local furnitureStock = named("TextLabel", "FurnitureStock", furnitureCard)
StructureEditor.styleButton(furnitureCard, "Selected")
check(furnitureTitle.TextColor3.R > 0.95 and furnitureStock.TextColor3.R > 0.95,
	"Selected furniture cards must keep their separate title and stock captions readable")
StructureEditor.styleButton(furnitureCard, "Normal")
check(furnitureTitle.TextColor3.R > 0.8 and furnitureStock.TextColor3.R > 0.8
	and furnitureCard.BackgroundColor3.R < 0.25,
	"Unselected furniture cards must retain readable light captions on the dark menu")
local gui = named("ScreenGui", "BuildMode")
local modeChanges, notices, exits = {}, {}, 0
local editor = StructureEditor.new({
	Gui = gui, OnModeChanged = function(enabled) table.insert(modeChanges, enabled) end,
	Notice = function(message) table.insert(notices, message) end, OnExit = function() exits += 1 end,
})
local function byName(name)
	for _, item in instances do if not item.Destroyed and item.Name == name then return item end end
	error("No UI element named " .. name)
end
local function visible(item)
	while item do
		if not item.Visible then return false end
		item = item.Parent
	end
	return true
end
local function pressText(text)
	for _, item in instances do
		if not item.Destroyed and visible(item) and item:IsA("TextButton") and item.Text == text then item.Activated:Fire(); return end
	end
	error("No button reading " .. text)
end
local function textButton(text)
	for _, item in instances do
		if not item.Destroyed and item:IsA("TextButton") and item.Text == text then return item end
	end
	error("No button reading " .. text)
end
editor:enter(house, identity, nil)
check(not editor:isActive(), "Entry must start on the furniture tab")
check(calls[#calls].Action == "Get", "Entering must fetch current authoritative state")
byName("BuildTab").Activated:Fire()
check(editor:isActive() and modeChanges[#modeChanges] == true, "Structure tab must enable its controller")
local function blue(item)
	return item.BackgroundColor3.B > item.BackgroundColor3.R and item.TextColor3.R > 0.95
end
check(blue(byName("BuildTab")), "The selected Build category must have a blue tab and white caption")
local toolbox = byName("StructureTools")
check(toolbox.AnchorPoint.Y == 1 and toolbox.Position[3] == 1,
	"The category toolbox must remain anchored to the bottom of the screen")
check(toolbox.BackgroundColor3.R < 0.2 and toolbox.BackgroundColor3.G < 0.2 and toolbox.BackgroundColor3.B < 0.2,
	"The build toolbox must use the restored near-black theme")
byName("DecorateTab").Activated:Fire()
check(editor:isActive() and blue(byName("DecorateTab")) and not blue(byName("BuildTab")),
	"Decorate must own its tab selection while retaining structural input")
check(blue(byName("ToolPaint")), "Decorate must activate the paint utility")
check(visible(byName("PaintAllWalls")) and byName("PaintAllWalls").Active,
	"Decorate must offer painting all walls without selecting one first")
check(byName("ToolSelect").Parent == byName("EditingTools") and visible(byName("ToolSelect"))
	and visible(byName("ToolPaint")) and visible(byName("ToolRemove")),
	"Decorate must keep its three primary editing tools together and visible")
for _, text in { "Move", "Reshape", "Apply finish" } do
	check(not visible(textButton(text)), "Unselected painting must hide unrelated object actions: " .. text)
end
check(not visible(textButton("Grid: 4.5 [G]")), "Painting must hide construction grid controls")
check(visible(textButton("Undo")) and visible(textButton("Redo"))
	and textButton("Undo").Parent == toolbox and textButton("Redo").Parent == toolbox,
	"History controls must remain in the compact header instead of the crowded action strip")
check(not byName("BuildStatus").Text:find("Click", 1, true),
	"Decorate must keep its status header concise without repeated paint instructions")
for _, item in instances do
	if item:IsA("TextLabel") and type(item.Text) == "string" and item.Text:find("SURFACE FINISHES", 1, true) then
		check(not visible(item), "The duplicated surface-finishes help row must be removed or hidden")
	end
end
byName("BuildTab").Activated:Fire()
check(blue(byName("ToolWall")), "Build must restore its latest construction category")
check(not visible(byName("PaintAllWalls")), "Paint all walls belongs with the Decorate finishes")
check(not visible(byName('SurfaceMaterials')) and not visible(byName('SurfaceColors')),
	'Construction catalogues must replace the paint palettes rather than crowd the same rows')
byName('ToolWindow').Activated:Fire()
for _,variant in Catalog.Variants.Window do
	local card=byName('VariantWindow'..variant.Id)
	local thumbnail=card:FindFirstChild('CatalogueThumbnail')
	check(visible(card) and thumbnail and thumbnail.PreviewStyle==variant.Style,
		'Each window catalogue card must show the matching rendered shape')
end
check(not visible(byName('VariantRoofFlat')),'A window catalogue must not include unrelated roof cards')
byName('VariantWindowTall').Activated:Fire()
check(blue(byName('VariantWindowTall')),'A catalogue card must select its own shape')
byName('VariantWindowClassic').Activated:Fire()
byName('ToolWall').Activated:Fire()
for _, name in { "ToolWall", "ToolRoom", "ToolDoor", "ToolWindow", "ToolFloor", "ToolRoof" } do
	check(byName(name).Parent == byName("ConstructionTools"), "Construction categories must stay together in their tab row")
end
local hasStairs=false
for _,item in instances do if item.Name=='ToolStairs' then hasStairs=true end end
check(not hasStairs,'Stairs must no longer appear as a construction tool')
for _, name in { "ToolSelect", "ToolPaint", "ToolRemove" } do
	check(byName(name).Parent == byName("ConstructionActions"), "Editing utilities must stay separate from building categories")
end
check(editor:gridSize() == Catalog.GRID, "Structural grid must expose its initial spacing to BuildMode")
local previousModeChanges = #modeChanges
editor:key({ KeyCode = Enum.KeyCode.G })
check(editor:gridSize() == Catalog.GRID / 2 and #modeChanges == previousModeChanges + 1,
	"Grid changes must publish their spacing and request a grid redraw")
editor:key({ KeyCode = Enum.KeyCode.G })
editor:key({ KeyCode = Enum.KeyCode.G })
editor:step(Vector2.new(2.25, 2.25))
local previews = #previewCalls
editor:step(Vector2.new(2.25, 2.25))
check(#previewCalls == previews, "A stationary preview must not rebuild its geometry")
editor:click(Vector2.new(2.25, 2.25))
check(calls[#calls].Action == "Get", "First wall endpoint must not charge or place")
editor:click(Vector2.new(11.25, 2.25))
check(calls[#calls].Action == "Place" and #calls[#calls].Payload.Entries == 1, "Second endpoint must submit one wall")
check(calls[#calls].Payload.Entries[1].X1 == 2.25 and calls[#calls].Payload.Entries[1].X2 == 11.25, "Wall endpoints must follow the displayed half-cell grid")
local beforeUI = #calls
editor:click(Vector2.new(50, 850))
check(#calls == beforeUI, "Clicking the toolbox must never submit world construction")
byName("ToolSelect").Activated:Fire()
rayHit = { Instance = pieceInstances.p1, Position = Vector3.new(6.75, 4, 2.25) }
editor:click(Vector2.new(6.75, 2.25))
check(visible(textButton("Move")) and visible(textButton("Reshape")) and visible(textButton("Apply finish")),
	"Selecting a custom structure must expose its relevant object actions")
pressText("Move")
editor:click(Vector2.new(6.75, 11.25))
check(calls[#calls].Action == "Move" and calls[#calls].Payload.Id == "p1", "Selecting and moving must preserve the custom ID")
check(calls[#calls].Payload.Entry.Z1 == 11.25 and calls[#calls].Payload.Entry.Z2 == 11.25, "Move must translate both endpoints to the new grid line")
pressText("Reshape")
editor:click(Vector2.new(2.25, 11.25))
editor:click(Vector2.new(15.75, 11.25))
check(calls[#calls].Action == "Move" and calls[#calls].Payload.Entry.X2 == 15.75, "Reshape must replace geometry through the authoritative Move action")
rayHit = nil
byName("ToolRoom").Activated:Fire()
editor:click(Vector2.new(-15.75, -6.75))
editor:click(Vector2.new(-6.75, 2.25))
check(calls[#calls].Action == "Place" and #calls[#calls].Payload.Entries == 5, "Room tool must submit four walls and a floor atomically")
byName("ToolRoof").Activated:Fire()
check(editor:roofVisible(), "Roof tool must show roof surfaces")
byName("VariantRoofFlat").Activated:Fire()
editor:key({ KeyCode = Enum.KeyCode.R })
editor:key({ KeyCode = Enum.KeyCode.PageUp })
check(editor:elevation() == 12, "PageUp must raise the working level and camera focus")
byName("ToolWindow").Activated:Fire()
rayHit = { Instance = wall, Position = Vector3.new(2.25, 4, -20.25) }
local beforeLowerWall = #calls
editor:click(Vector2.new(2.25, -20.25))
check(#calls == beforeLowerWall, "An upper-floor opening must never attach to a lower-floor wall")
byName("ToolRoof").Activated:Fire()
rayHit = nil
editor:click(Vector2.new(2.25, -15.75))
editor:click(Vector2.new(11.25, -6.75))
check(calls[#calls].Payload.Entries[1].Kind == "Roof" and calls[#calls].Payload.Entries[1].Level == 1
	and calls[#calls].Payload.Entries[1].Style == "Flat" and calls[#calls].Payload.Entries[1].R==1,
	"R must rotate independently of the catalogue roof style, and both must reach the server")
editor:key({ KeyCode = Enum.KeyCode.PageDown })
byName("ToolPaint").Activated:Fire()
check(not visible(textButton("Move")) and not visible(textButton("Reshape")) and not visible(textButton("Apply finish")),
	"Painting must hide object actions even when a previous selection still exists")
byName("CustomHexColor").Text = "#123ABC"
pressText("Set color")
rayHit = { Instance = wall, Position = Vector3.new(2.25, 4, -20) }
editor:click(Vector2.new(2.25, -20))
check(calls[#calls].Action == "PaintBatch" and calls[#calls].Payload.Entries[1].Id == "b:fixture", "Paint must target the stable structural ID through the batched writer")
local sentFinish=calls[#calls].Payload.Entries[1]
check(sentFinish.Color[1] == 18 and sentFinish.Color[2] == 58 and sentFinish.Color[3] == 188, "Custom hex color must submit exact RGB bytes")
byName("ToolWindow").Activated:Fire()
editor:step(Vector2.new(2.25,-20))
check(wall.LocalTransparencyModifier==1,'An opening preview must temporarily hide its uncut host so the proposed window is visible')
editor:key({KeyCode=Enum.KeyCode.X})
check((wall.LocalTransparencyModifier or 0)==0,'Cancelling an opening preview must restore the original wall visibility')
editor:click(Vector2.new(2.25, -20))
check(calls[#calls].Action == "Place" and calls[#calls].Payload.Entries[1].HostId == "b:fixture", "Window must attach to the pointed wall")
check(calls[#calls].Payload.Entries[1].Offset > 0, "Opening offset must be a stud distance along its host")
byName("ToolRemove").Activated:Fire()
editor:click(Vector2.new(2.25, -20))
check(calls[#calls].Action == "Remove", "Remove tool must submit the selected structural ID")
byName("ToolWall").Activated:Fire()
rayHit = nil
editor:step(Vector2.new(-6.75, -20.25))
check(previewCalls[#previewCalls].Valid and previewCalls[#previewCalls].Builtins["b:fixture"] == nil,
	"Removed built-in walls must stop blocking their replacement preview")
pressText("Undo")
check(calls[#calls].Action == "Undo", "Undo must be authoritative")
serverState.CanRedo = true
update.OnClientEvent:Fire("State", deep(serverState), "Home")
pressText("Redo")
check(calls[#calls].Action == "Redo", "Redo must be authoritative")
pressText("Furniture")
check(not editor:isActive() and modeChanges[#modeChanges] == false, "Furniture tab must release structural input")
byName("BuildTab").Activated:Fire()
pressText("Done [B]")
check(exits == 1, "Done must invoke BuildMode's exit callback")
editor:exit()
check(not editor:isActive() and not editor:roofVisible(), "Exit must clear structural mode and roof ownership")
local afterExit = #calls
editor:click(Vector2.new(2.25, 2.25))
check(#calls == afterExit, "Inactive structural tools must never submit changes")
editor:enter(house, identity, "Company")
byName("BuildTab").Activated:Fire()
byName("ToolWall").Activated:Fire()
rayHit = nil
editor:click(Vector2.new(0, 0))
editor:click(Vector2.new(9, 0))
check(calls[#calls].Site == "Company" and calls[#calls].Payload.Entries[1].X1 == 0, "Company construction must use its own site and origin grid")
check(previewCalls[#previewCalls].Site == "Company", "Company ghosts must receive the company's floor offset")

-- Aim oblique rays near a snap boundary on the visible grid. A ground-plane
-- projection is lower than that grid and would select its neighbouring line.
editor:exit()

-- Delayed authoritative saves must not stall input or erase newer local paint.
expectedFrame=identity
workspace.CurrentCamera.ScreenPointToRay=function(_,x,z)
	return {Origin=Vector3.new(x,100,z),Direction=Vector3.new(0,-1,0)}
end
local rapidHouse=named('Model','RapidHome',workspace)
local rapidParts={}
serverState.Pieces,serverState.Builtins,serverState.Overrides={}, {}, {}
for index=1,2 do
	local id='b:rapid'..index
	local part=named('Part','RapidWall'..index,rapidHouse)
	part:SetAttribute('BuildingId',id);part:SetAttribute('BuildingKind','Wall')
	part.Material,part.Color=Enum.Material.Plaster,Color3.fromRGB(235,229,211)
	rapidParts[index]=part
	serverState.Builtins[id]={Id=id,Kind='Wall',X1=-9,Z1=index*4.5,X2=9,Z2=index*4.5,
		BaseY=0.16,Height=11.5,Thickness=0.45,Level=0,Material='Plaster',Color={235,229,211}}
end
local fixedGlass=named('Part','FixedGlass',rapidHouse)
fixedGlass:SetAttribute('BuildingId','b:rapid1');fixedGlass:SetAttribute('BuildingKind','Wall')
fixedGlass:SetAttribute('BuildingFixedFinish',true)
fixedGlass.Material,fixedGlass.Color=Enum.Material.Glass,Color3.fromRGB(163,205,215)
editor:enter(rapidHouse,identity,nil)
byName('DecorateTab').Activated:Fire()
byName('MaterialBrick').Activated:Fire()
local function rapidClick(index,hexColor)
	byName('CustomHexColor').Text=hexColor;pressText('Set color')
	rayHit={Instance=rapidParts[index],Position=Vector3.new(0,4,index*4.5)}
	editor:click(Vector2.new(0,index*4.5))
end
delayPaint=true
local firstWait=#waitingPaint+1
rapidClick(1,'#113355')
check(#waitingPaint==firstWait and rapidParts[1].Color==Color3.fromRGB(17,51,85),
	'The first clicked wall must paint immediately before its server save returns')
check(fixedGlass.Material==Enum.Material.Glass and fixedGlass.Color==Color3.fromRGB(163,205,215),
	'Immediate local painting must preserve fixed glass finishes')
rapidClick(2,'#224466')
check(#waitingPaint==firstWait and rapidParts[2].Color==Color3.fromRGB(34,68,102),
	'A different wall must paint immediately while another paint request remains in flight')
rapidClick(1,'#335577')
check(rapidParts[1].Color==Color3.fromRGB(51,85,119),
	'A newer finish on the first wall must stay responsive during its older save')
rapidParts[1].Material=Enum.Material.Plaster
rapidParts[1].Color=Color3.fromRGB(235,229,211)
check(rapidParts[1].Material==Enum.Material.Brick and rapidParts[1].Color==Color3.fromRGB(51,85,119),
	'Late replication of an old finish must not overwrite newer optimistic paint')
acknowledgePaint(firstWait)
check(#waitingPaint==firstWait+1 and rapidParts[1].Color==Color3.fromRGB(51,85,119),
	'An old paint acknowledgement must reapply the latest finish and flush queued targets')
acknowledgePaint(firstWait+1)
check(rapidParts[1].Color==Color3.fromRGB(51,85,119) and rapidParts[2].Color==Color3.fromRGB(34,68,102),
	'After all saves finish, both walls must keep their final clicked colors')
local failureWait=#waitingPaint+1
rapidClick(2,'#FF0000')
check(rapidParts[2].Color==Color3.fromRGB(255,0,0),'A pending finish must display before a possible save rejection')
acknowledgePaint(failureWait,false)
check(rapidParts[2].Color==Color3.fromRGB(34,68,102) and #notices>0,
	'A rejected finish must roll back to the saved appearance and notify the player')
local beforeUndo=#calls
local drainWait=#waitingPaint+1
rapidClick(1,'#556677')
pressText('Undo')
check(calls[#calls].Action=='PaintBatch','Undo must wait behind an unsaved paint stroke')
acknowledgePaint(drainWait)
check(calls[#calls].Action=='Undo' and #calls==beforeUndo+2,
	'Undo must submit after its preceding paint has committed')
local exitWait=#waitingPaint+1
rapidClick(2,'#667788')
rapidClick(1,'#778899')
editor:exit()
acknowledgePaint(exitWait)
check(#waitingPaint==exitWait+1,'Exiting build mode must continue flushing already-clicked paint')
acknowledgePaint(exitWait+1)
check(not editor:isActive() and rapidParts[1].Color==Color3.fromRGB(119,136,153),
	'Queued paint may finish after exit without reopening the editor')
delayPaint=false
rayHit=nil

-- The bulk action captures the chosen finish and waits for pending paint.
editor:enter(rapidHouse,identity,"Company")
byName("DecorateTab").Activated:Fire()
byName("MaterialSlate").Activated:Fire()
delayPaint=true
local bulkWait=#waitingPaint+1
rapidClick(1,"#AABBCC")
local beforeBulk=#calls
pressText("Paint all walls")
check(#calls==beforeBulk and not byName("PaintAllWalls").Active,
	"Painting all walls must wait for a pending stroke and disable repeated submission")
pressText("Paint all walls")
acknowledgePaint(bulkWait)
local bulk=calls[#calls]
check(#calls==beforeBulk+1 and bulk.Action=="PaintAllWalls" and bulk.Site=="Company",
	"Paint all walls must submit one command to the active property after queued paint saves")
check(bulk.Payload.Material=="Slate" and bulk.Payload.Color[1]==170
	and bulk.Payload.Color[2]==187 and bulk.Payload.Color[3]==204,
	"Painting all walls must use the selected texture and custom color")
delayPaint=false
serverState.Pieces,serverState.Builtins,serverState.Overrides={}, {}, {}
update.OnClientEvent:Fire("State",deep(serverState),"Company")
check(not byName("PaintAllWalls").Active,"Properties with no walls must disable Paint all walls")
editor:exit()
rayHit=nil

local rotated = { UpVector = Vector3.new(0, 1, 0) }
function rotated:PointToObjectSpace(point)
	return Vector3.new(-point.Z - 40, point.Y - 8, point.X - 60)
end
setmetatable(rotated, { __mul = function(_, point)
	return Vector3.new(60 + point.Z, 8 + point.Y, -40 - point.X)
end })
expectedFrame = rotated
local perspectiveSite = nil
workspace.CurrentCamera.ScreenPointToRay = function(_, x, z)
	local target = rotated * Vector3.new(x, Catalog.planeHeight(perspectiveSite, 0), z)
	return { Origin = target + Vector3.new(0, 100, -60), Direction = Vector3.new(0, -1, 0.6) }
end
for _, where in { "Home", "Company" } do
	perspectiveSite = if where == "Home" then nil else "Company"
	for index, spacing in { Catalog.GRID, Catalog.GRID / 2, Catalog.GRID / 4 } do
		serverState.Pieces, serverState.Builtins, serverState.Overrides = {}, {}, {}
		editor:enter(house, rotated, perspectiveSite)
		byName("BuildTab").Activated:Fire()
		byName("ToolWall").Activated:Fire()
		while math.abs(editor:gridSize() - spacing) > 0.001 do editor:key({ KeyCode = Enum.KeyCode.G }) end
		local offset = Catalog.gridOffset(perspectiveSite)
		local first, last, z = offset + spacing * 2, offset + spacing * 5, offset - spacing * 2
		local x1, x2 = if index % 2 == 0 then last else first, if index % 2 == 0 then first else last
		local bias = spacing / 2 - 0.02
		local before = #calls
		editor:click(Vector2.new(x1 - bias, z))
		editor:click(Vector2.new(x2 - bias, z))
		local sent = calls[#calls]
		check(#calls == before + 1 and sent.Action == "Place", "Grid-line drawing must submit one wall after its second endpoint")
		local built = sent.Payload.Entries[1]
		check(math.abs(built.X1 - first) < 0.001 and math.abs(built.X2 - last) < 0.001,
			"An angled camera must snap both wall endpoints to the visible grid, including reversed strokes")
		check(math.abs(built.Z1 - z) < 0.001 and math.abs(built.Z2 - z) < 0.001,
			"Wall centerlines must lie on a displayed grid line for every grid size and property")
		editor:exit()
	end
end
print("Structure editor: " .. checks .. " UI, input, preview, network, and lifecycle assertions passed (recording doubles; no Studio rendering).")
