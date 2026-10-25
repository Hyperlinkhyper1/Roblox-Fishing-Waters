// Exercise production build-camera framing, navigation and pointer rays with Roblox math mocks.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = name => readFile(join(root, name), 'utf8');
const source = await read('src/client/BuildMode.luau');
function section(start, end) {
  const first = source.indexOf(start);
  const last = source.indexOf(end, first);
  if (first < 0 || last < 0) throw new Error(`Missing build camera section: ${start}`);
  return source.slice(first, last);
}
const primitives = (await read('scripts/harbour-geometry.luau')).split('local CFrame = {}')[0];
const frames = (await read('scripts/drydock-geometry.luau')).split('local function typeof')[0]
  .replace('-- SHARED_PRIMITIVES --', primitives);
const program = `${frames}
local Enum = setmetatable({}, {__index = function(self, category)
  local values = setmetatable({}, {__index = function(_, value) return value end})
  rawset(self, category, values)
  return values
end})
local workspace = {}
local panel = {}
local navigation = {AbsolutePosition = Vector2.new(12, 12), AbsoluteSize = Vector2.new(600, 54)}
local inset = 0
local GuiService = {GetGuiInset = function() return Vector2.new(0, inset) end}
local focused = false
local mouse = Vector2.zero
local UserInputService = {
  GetFocusedTextBox = function() return if focused then {} else nil end,
  GetMouseLocation = function() return mouse end,
}
local houseFrame = CFrame.identity
local FLOOR_Y = 0.16
local ROOF_HEIGHT = 8.4
local Furniture = {GRID = 0.5}
${section('local CAMERA_PITCH', '\nlocal started')}
local pan, zoom, cameraDistance = Vector2.zero, 1, 60
local panKeys = {}
local turnKeys = {}
local yaw, turnVelocity = 0, 0
local dragging, dragPosition, touch = false, nil, nil
local touchStart, touchDragged = Vector2.zero, false
local held = nil
local aimCount = 0
local function aim() aimCount += 1 end
${section('\tlocal function pointerFloor(', '\n\tlocal function aim(')}
${section('\tlocal function panBy(', '\n\tlocal function freezeCharacter(')}
${section('\tlocal function updateCamera(', '\n\tlocal exit')}
local checks = 0
for _, size in {{1920, 1080}, {1280, 720}, {844, 390}, {390, 844}, {640, 360}} do
  for _, topInset in {0, 36, 58} do
    for _, rotation in {0, math.pi / 2, math.pi, math.pi * 1.5} do
     for _, viewYaw in {0, math.pi / 4, math.pi / 2, math.pi, math.pi * 1.5} do
      inset = topInset
      panel.AbsolutePosition = Vector2.new(12, size[2] - inset - 202)
      houseFrame = CFrame.new(120, 6, -75) * CFrame.Angles(0, rotation, 0)
      pan, zoom = Vector2.zero, 1
      yaw = viewYaw
      clearNavigation()
      -- Replacing CurrentCamera between calls must still update the new instance.
      local camera = {ViewportSize = Vector2.new(size[1], size[2]), FieldOfView = 70}
      workspace.CurrentCamera = camera
      updateCamera()
      assert(camera.CameraType == "Scriptable" and camera.FieldOfView == 50, "Camera ownership lost")
      assert(camera.FieldOfViewMode == "Vertical", "Camera fit must use vertical FOV")
      local expectedLook = houseFrame:VectorToWorldSpace(Vector3.new(-math.sin(yaw) * math.cos(CAMERA_PITCH),
        -math.sin(CAMERA_PITCH), -math.cos(yaw) * math.cos(CAMERA_PITCH)))
      assert(camera.CFrame.LookVector:Dot(expectedLook) > 0.99999, "Camera must keep the angled building view")
      local focal = size[2] / (2 * math.tan(math.rad(camera.FieldOfView / 2)))
      local function project(point)
        local p = camera.CFrame:PointToObjectSpace(point)
        return Vector2.new(size[1] / 2 + focal * p.X / -p.Z,
          inset + size[2] / 2 - focal * p.Y / -p.Z)
      end
      for _, x in {-23, 23} do
        for _, z in {-15, 15} do
          for _, y in {0, ROOF_HEIGHT} do
            local screen = project(houseFrame * Vector3.new(x, FLOOR_Y + y, z))
            assert(screen.X >= 12 and screen.X <= size[1] - 12, "House cropped horizontally")
            assert(screen.Y >= 2 * inset + 78 and screen.Y <= panel.AbsolutePosition.Y + 2 * inset - 12,
              "House hidden by toolbar")
            checks += 1
          end
        end
      end
      function camera:ScreenPointToRay(x, y)
        local direction = self.CFrame:VectorToWorldSpace(Vector3.new((x - size[1] / 2) / focal, -(y - inset - size[2] / 2) / focal, -1))
        return {Origin = self.CFrame.Position, Direction = direction.Unit}
      end
      local function checkPointer()
        for _, point in {Vector3.new(8.5, FLOOR_Y, 6), Vector3.new(-12.5, FLOOR_Y, -8), Vector3.new(0, FLOOR_Y, 0)} do
          local x, z = pointerSpot(project(houseFrame * point))
          assert(x == point.X and z == point.Z, "Placement ray misses pointed floor tile")
          checks += 1
        end
      end
      checkPointer()
      local before = camera.Focus.Position
      assert(cameraInput("pan", "Begin", {KeyCode = "W"}) == "Sink", "Movement must be consumed")
      updateCamera(0.1)
      local forward = Vector2.new(-math.sin(yaw), -math.cos(yaw))
      assert(pan:Dot(forward) > 0 and (pan.Unit - forward).Magnitude < 1e-7, "W must pan along the camera's floor direction")
      assert((camera.Focus.Position - before):Dot(houseFrame:VectorToWorldSpace(Vector3.new(forward.X, 0, forward.Y))) > 0,
        "Focus must move with the view")
      cameraInput("pan", "End", {KeyCode = "W"})
      local stopped = pan
      updateCamera(0.1)
      assert((pan - stopped).Magnitude < 1e-8, "Releasing a movement key must stop panning")
      checkPointer()
      changeZoom(2)
      updateCamera()
      assert(zoom < 1, "Zoom in must get closer")
      checkPointer()
      local from = project(houseFrame * Vector3.new(pan.X, FLOOR_Y, pan.Y))
      local pixel = math.min(2, focal / cameraDistance)
      local to = from + Vector2.new(pixel, pixel / 2)
      local anchor = pointerFloor(from)
      dragView(from, to)
      updateCamera()
      assert((pointerFloor(to) - anchor).Magnitude < 1e-7, "Dragging must keep the grabbed floor point under the pointer")
      checkPointer()
      local zoomedPan = pan
      changeZoom(-100)
      assert(zoom == 2.5 and (pan - zoomedPan).Magnitude == 0, "Zoom out must be bounded without losing pan")
      changeZoom(100)
      assert(zoom == 0.45, "Zoom in must be bounded")
      panBy(Vector2.new(1e6, -1e6))
      assert(pan.X == PAN_LIMIT.X and pan.Y == -PAN_LIMIT.Y, "Panning must stay near the build area")
      clearNavigation()
      focused = true
      assert(cameraInput("pan", "Begin", {KeyCode = "D"}) == "Pass", "Text input must stay usable")
      updateCamera(0.1)
      assert(pan.X == PAN_LIMIT.X, "Typing must not pan")
      focused = false
      checks += 10
     end
    end
  end
end
-- Frame-rate independence and normalized diagonal movement.
workspace.CurrentCamera.ViewportSize = Vector2.new(1920, 1080)
panel.AbsolutePosition = Vector2.new(12, 878)
inset = 0
pan, zoom, yaw = Vector2.zero, 1, 0
clearNavigation()
cameraInput("pan", "Begin", {KeyCode = "W"})
for _ = 1, 6 do updateCamera(1 / 60) end
local sixty = pan
pan = Vector2.zero
for _ = 1, 3 do updateCamera(1 / 30) end
assert((pan - sixty).Magnitude < 1e-7, "Pan speed must not depend on frame rate")
pan = Vector2.zero
cameraInput("pan", "Begin", {KeyCode = "D"})
for _ = 1, 6 do updateCamera(1 / 60) end
assert(math.abs(pan.Magnitude - sixty.Magnitude) < 1e-7, "Diagonal movement must not be faster")
cameraInput("pan", "Cancel", {KeyCode = "D"})
assert(panKeys.D == nil, "Cancelled input must release movement")
held = {R = 0}
updateCamera()
assert(aimCount > 0, "Camera motion must refresh the furniture preview")
held = nil
checks += 4

-- Hold-to-turn eases in and out, remains frame-rate independent, and handles opposing keys.
clearNavigation()
pan, zoom, yaw = Vector2.zero, 1, 0
cameraInput("turn", "Begin", {KeyCode = "E"})
for _ = 1, 30 do updateCamera(1 / 60) end
local sixtyYaw, sixtyVelocity = yaw, turnVelocity
assert(yaw > 0 and turnVelocity > 0 and turnVelocity < TURN_SPEED, "E must smoothly accelerate clockwise")
clearNavigation()
yaw = 0
cameraInput("turn", "Begin", {KeyCode = "E"})
for _ = 1, 15 do updateCamera(1 / 30) end
assert(math.abs(yaw - sixtyYaw) < 1e-7 and math.abs(turnVelocity - sixtyVelocity) < 1e-7,
  "Turn easing and speed must not depend on frame rate")
cameraInput("turn", "End", {KeyCode = "E"})
for _ = 1, 60 do updateCamera(1 / 60) end
assert(turnVelocity < 0.001 and next(turnKeys) == nil, "Releasing E must ease to a stop")
clearNavigation()
yaw = 0
cameraInput("turn", "Begin", {KeyCode = "Q"})
updateCamera(1 / 60)
assert(yaw > math.pi and turnVelocity < 0, "Q must turn counterclockwise through the angle wrap")
cameraInput("turn", "Begin", {KeyCode = "E"})
turnVelocity = 0
local opposedYaw = yaw
updateCamera(0.1)
assert(yaw == opposedYaw and turnVelocity == 0, "Q and E together must cancel")
cameraInput("turn", "Cancel", {KeyCode = "Q"})
assert(turnKeys.Q == nil, "Cancelled turn input must release the key")
focused = true
local typingYaw = yaw
updateCamera(0.1)
assert(yaw == typingYaw, "Typing must not rotate the view")
focused = false
clearNavigation()
assert(next(turnKeys) == nil and turnVelocity == 0, "Focus loss must stop rotation immediately")
yaw = 0
checks += 8

-- Run the actual pointer event handlers: drag pans, taps place, GUI input is ignored.
local callbacks = {}
for _, name in {"InputBegan", "InputChanged", "InputEnded"} do
  UserInputService[name] = {Connect = function(_, callback) callbacks[name] = callback end}
end
local active = true
local clicks, drops = 0, 0
local function clickWorld() clicks += 1 end
local function drop() drops += 1 end
local function choose() end
local function enter() active = true end
local function exit() active = false end
${section('\tUserInputService.InputBegan:Connect(', '\n\tupdate.OnClientEvent:Connect(')}
clearNavigation()
local function input(kind, position)
  return {UserInputType = kind, Position = position or Vector3.zero, KeyCode = "Unknown", UserInputState = "Begin"}
end
held = {R = 0}
callbacks.InputBegan({KeyCode = "Q"}, false)
assert(drops == 0 and held ~= nil, "Q must preserve the furniture being placed")
callbacks.InputBegan({KeyCode = "X"}, false)
assert(drops == 1, "X must cancel placement")
pan, zoom, yaw, turnVelocity = Vector2.new(1, 2), 2, 1, 1
callbacks.InputBegan({KeyCode = "Home"}, false)
assert(pan.Magnitude == 0 and zoom == 1 and yaw == 0 and turnVelocity == 0, "Home must restore the initial view")
checks += 3
drops = 0
held = {R = 0}
callbacks.InputBegan(input("MouseButton2"), false)
assert(dragging and drops == 0 and held ~= nil, "Right-drag must preserve held furniture")
callbacks.InputEnded(input("MouseButton2"))
assert(not dragging, "Right mouse release must end panning")
held = nil
callbacks.InputBegan(input("Touch"), true)
assert(touch == nil, "Touching the catalogue must not start camera navigation")
local tap = input("Touch", Vector3.new(100, 100, 0))
callbacks.InputBegan(tap, false)
assert(clicks == 0, "Touch must wait for release before placing")
callbacks.InputEnded(tap)
assert(clicks == 1, "A tap must place or select exactly once")
local swipe = input("Touch", Vector3.new(100, 100, 0))
callbacks.InputBegan(swipe, false)
swipe.Position = Vector3.new(140, 120, 0)
callbacks.InputChanged(swipe, false)
assert(touchDragged, "A swipe must start panning")
callbacks.InputEnded(swipe)
assert(clicks == 1 and touch == nil, "A swipe must never place furniture")
callbacks.InputBegan(input("MouseButton1"), true)
assert(clicks == 1, "Clicking UI must not place furniture")
callbacks.InputBegan(input("MouseButton1"), false)
assert(clicks == 2, "A world click must place or select")
local cancelled = input("Touch", Vector3.new(100, 100, 0))
callbacks.InputBegan(cancelled, false)
cancelled.UserInputState = "Cancel"
callbacks.InputEnded(cancelled)
assert(clicks == 2, "A cancelled touch must never place")
zoom = 1
callbacks.InputChanged(input("MouseWheel", Vector3.new(0, 0, 1)), true)
assert(zoom == 1, "Scrolling the catalogue must not zoom the camera")
callbacks.InputChanged(input("MouseWheel", Vector3.new(0, 0, 1)), false)
assert(zoom < 1, "Scrolling the world must zoom")
dragging, touch = true, tap
panKeys.W = PAN_KEYS.W
clearNavigation()
assert(not dragging and touch == nil and next(panKeys) == nil, "Focus loss must clear movement and dragging")
checks += 13
workspace.CurrentCamera = nil
updateCamera()
assert(pointerSpot(Vector2.zero) == nil, "Missing camera should be harmless")

-- Execute entry/exit against control and render bindings, including respawn-style cleanup.
local bound, renderStep = nil, nil
local controlsEnabled, moved = true, nil
local root = {Parent = true, Anchored = false, IsA = function(_, kind) return kind == "BasePart" end}
local humanoid = {Parent = true, Health = 100, AutoRotate = true, Move = function(_, direction) moved = direction end}
local attributes = {}
local module = {IsA = function(_, kind) return kind == "ModuleScript" end, GetControls = function() return {
  Enable = function() controlsEnabled = true end,
  Disable = function() controlsEnabled = false end,
} end}
local player = {
  Character = {FindFirstChildOfClass = function() return humanoid end, FindFirstChild = function() return root end},
  FindFirstChild = function() return {FindFirstChild = function() return module end} end,
  SetAttribute = function(_, name, value) attributes[name] = value end,
}
local moduleAvailable = true
local function require(value)
  assert(moduleAvailable, "PlayerModule unavailable during startup")
  return value
end
local ContextActionService = {
  BindActionAtPriority = function(_, name, callback, createTouchButton, priority, ...)
    assert(name == "FurnitureBuildMovement" and priority > 3000 and not createTouchButton)
    local keys = {...}
    assert(#keys == 11, "Build mode must capture movement, Q/E and jump keys")
    assert(table.find(keys, "Q") and table.find(keys, "E"), "Q and E must be owned only during build mode")
    bound = callback
  end,
  UnbindAction = function() bound = nil end,
}
local RunService = {
  BindToRenderStep = function(_, _, _, callback) renderStep = callback end,
  UnbindFromRenderStep = function() renderStep = nil end,
}
Enum.ContextActionPriority.High = {Value = 3000}
Enum.RenderPriority.Camera = {Value = 200}
UserInputService.IsKeyDown = function() return false end
UserInputService.MouseBehavior, UserInputService.MouseIconEnabled = "LockCenter", false
local saved, house, state, frozen = nil, nil, nil, nil
local roofHidden, gridDestroyed = false, false
local grid = nil
local function hideRoof() roofHidden = true end
local function showRoof() roofHidden = false end
local function showGrid() grid = {Destroy = function() gridDestroyed = true end} end
local function atHome() return true end
local function ownHouse() return {}, CFrame.identity end
local noticeMessage = nil
local function notice(message) noticeMessage = message end
local function render() end
local request = {InvokeServer = function() return {State = {Placed = {}}} end}
local task = {spawn = function(callback) callback() end}
local toggle = {Visible = true}
${section('\tlocal function freezeCharacter(', '\n\tlocal function controls(')}
${section('\tlocal function controls(', '\n\tlocal function updateCamera(')}
${section('\tlocal exit\n', '\n\tfor id, item in itemButtons')}
active = false
local originalFrame, originalFocus = CFrame.new(1, 2, 3), CFrame.new(4, 5, 6)
workspace.CurrentCamera = {ViewportSize = Vector2.new(1920, 1080), CameraType = "Custom",
  FieldOfView = 70, FieldOfViewMode = "Diagonal", CFrame = originalFrame, Focus = originalFocus}
humanoid.SeatPart = {}
enter()
assert(not active and not root.Anchored and noticeMessage ~= nil, "Build mode must not anchor a seated character's vehicle")
humanoid.SeatPart = nil
enter()
assert(active and not controlsEnabled and moved.Magnitude == 0, "Build entry must stop character movement")
assert(root.Anchored and not humanoid.AutoRotate, "Build entry must physically keep the character in place")
assert(root.AssemblyLinearVelocity.Magnitude == 0 and root.AssemblyAngularVelocity.Magnitude == 0,
  "Build entry must stop leftover character momentum")
assert(bound ~= nil and renderStep ~= nil and attributes.BuildModeOpen, "Build mode must own navigation and rendering")
assert(roofHidden and panel.Visible and navigation.Visible, "Build entry must reveal the editor")
assert(UserInputService.MouseBehavior == "Default" and UserInputService.MouseIconEnabled, "Build mode must free the pointer")
bound("pan", "Begin", {KeyCode = "D"})
bound("turn", "Begin", {KeyCode = "E"})
renderStep(0.05)
assert(pan.X > 0 and not controlsEnabled, "Movement keys must move the view while character controls stay disabled")
assert(yaw > 0 and turnVelocity > 0, "Build mode must own smooth Q/E turning")
exit()
assert(not active and controlsEnabled and bound == nil and renderStep == nil, "Exit must restore controls and release bindings")
assert(not root.Anchored and humanoid.AutoRotate, "Exit must restore the character's anchor and rotation settings")
assert(not roofHidden and gridDestroyed and not panel.Visible and not navigation.Visible, "Exit must clean up build visuals")
assert(workspace.CurrentCamera.CameraType == "Custom" and workspace.CurrentCamera.FieldOfView == 70
  and workspace.CurrentCamera.FieldOfViewMode == "Diagonal" and workspace.CurrentCamera.CFrame == originalFrame
  and workspace.CurrentCamera.Focus == originalFocus, "Exit must restore the previous camera")
assert(UserInputService.MouseBehavior == Enum.MouseBehavior.Default and UserInputService.MouseIconEnabled,
  "Exit must leave the pointer visible and free")
assert(next(panKeys) == nil and next(turnKeys) == nil and turnVelocity == 0 and not attributes.BuildModeOpen,
  "Exit must discard movement and turning state")
exit()
root.Anchored, humanoid.AutoRotate = true, false
enter()
exit()
assert(root.Anchored and not humanoid.AutoRotate, "Exit must preserve a character that was already anchored")
root.Anchored, humanoid.AutoRotate, moduleAvailable = false, true, false
enter()
assert(active and root.Anchored and bound ~= nil, "Character locking and camera navigation must survive unavailable PlayerModule")
moduleAvailable = true
exit()
assert(not root.Anchored and humanoid.AutoRotate, "Fallback entry must still clean up the character lock")
checks += 18
print("Build camera: " .. checks .. " framing, navigation, placement and touch checks passed (no Studio rendering).")
-- Parse the complete module as well as the exercised functions.
local function parseBuildMode()
${source}
end
`;
const folder = await mkdtemp(join(tmpdir(), 'build-camera-'));
try {
  const target = join(folder, 'camera.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], {cwd: root, encoding: 'utf8', timeout: 30000});
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Build camera checks failed (${result.status})`);
} finally {
  await rm(folder, {recursive: true, force: true});
}
