-- Run with: lute run scripts/ferry.luau
-- Exercise the real ferry service through its server-only dock callback with fake boats and saves.
local fs = require("@lute/fs")
local luau = require("@lute/luau")
local function read(path)
	local f = fs.open(path, "r")
	local s = fs.read(f)
	fs.close(f)
	return s
end
local rules = luau.load(luau.compile(read("src/shared/Ferry.luau")), "Ferry", {})()
local vectors = {}
vectors.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z) end
end
vectors.__sub = function(a,b) return setmetatable({X=a.X-b.X,Y=a.Y-b.Y,Z=a.Z-b.Z}, vectors) end
local Vector3 = {new = function(x,y,z) return setmetatable({X=x,Y=y,Z=z},vectors) end}
local frame = setmetatable({}, {__mul = function() return frame end})
local CFrame = {new = function() return frame end}
local Color3 = {fromRGB=function(...) return {...} end}
local Enum = {Material={SmoothPlastic=1},PartType={Ball=1}}
local function event()
	local e = {listeners={}}
	function e:Connect(f) table.insert(self.listeners,f) end
	function e:fire(...) for _,f in self.listeners do f(...) end end
	return e
end
local Instance = {}
function Instance.new(class)
	local o = {ClassName=class, Destroying=event()}
	function o:IsA(name) return self.ClassName == name end
	function o:Destroy() self.Destroying:fire(); self.Parent = nil end
	return o
end
local player = {UserId=1, attrs={}, Character={}}
function player:SetAttribute(k,v) self.attrs[k]=v end
local root = {Position=Vector3.new(0,0,0)}
function player.Character:FindFirstChild(name) return if name == "HumanoidRootPart" then root else nil end
local players = {PlayerRemoving=event()}
player.Parent = players
local notification = {FireClient=function() end}
local boating = {FindFirstChild=function(_, name) return if name == "Feedback" then notification else nil end}
local storage = {Shared={Ferry={}},FindFirstChild=function(_, name) return if name == "Boating" then boating else nil end}
local workspace = {DescendantAdded=event()}
local game = {GetService=function(_,name) return if name == "Players" then players else storage end}
local serviceMock = {boat=nil, fail=false, cash=0, writes=0}
function serviceMock.activeBoat() return if serviceMock.boat then "SmallFerry" else nil, serviceMock.boat end
function serviceMock.updateProgress(_, transform)
	serviceMock.writes += 1
	if serviceMock.onWrite then serviceMock.onWrite() end
	if serviceMock.fail then return false, "save failed" end
	local profile = {Cash=serviceMock.cash}
	transform(profile)
	serviceMock.cash = profile.Cash
	return true, "Saved"
end
local script = {Parent={BoatService={}}}
local function fakeRequire(target)
	if target == script.Parent.BoatService then return serviceMock end
	if target == storage.Shared.Ferry then return rules end
	error("unexpected require")
end
local source = read("src/server/FerryService.luau")
source = string.gsub(source, "return Service%s*$", "return {useStop=useStop, trips=trips, unlocked=unlocked, stops=stops, clearTrip=clearTrip}")
local svc = luau.load(luau.compile(source), "FerryService", {
	game=game, script=script, require=fakeRequire, workspace=workspace,
	Instance=Instance, Vector3=Vector3, CFrame=CFrame, Color3=Color3, Enum=Enum, table=table, math=math,
})()
local function boat()
	local b={PrimaryPart={Position=Vector3.new(0,0,0)}, seats={}}
	function b:FindFirstChild(name) return self.seats[name] end
	function b:IsDescendantOf() return true end
	for i=1,4 do
		b.seats["FerryPassengerSeat"..i] = {Parent=b, Disabled=false, CFrame=frame, IsA=function(_,x) return x == "Seat" end}
	end
	return b
end
local main={Position=Vector3.new(0,0,0),IsDescendantOf=function() return true end}
local city={Position=Vector3.new(1000,0,0),IsDescendantOf=function() return true end}
svc.stops.Main, svc.stops.City = main, city
local b = boat()
serviceMock.boat = b
local function at(stop) root.Position=stop.Position; b.PrimaryPart.Position=stop.Position end
at(city); svc.useStop(player,"City",city)
assert(not svc.trips[player], "city cannot start the first trip")
at(main)
b.seats.FerryPassengerSeat1.Occupant = {}
svc.useStop(player,"Main",main)
assert(not svc.trips[player], "occupied seats must prevent boarding")
b.seats.FerryPassengerSeat1.Occupant = nil
svc.useStop(player,"Main",main)
assert(svc.trips[player] and b.seats.FerryPassengerSeat1.Disabled, "boarding reserves seats")
svc.useStop(player,"Main",main)
assert(serviceMock.cash == 0, "origin cannot pay out")
at(city)
serviceMock.fail=true; svc.useStop(player,"City",city)
assert(serviceMock.cash == 0 and svc.trips[player], "save failure keeps the crossing retryable")
serviceMock.fail=false; serviceMock.onWrite=function() svc.useStop(player,"City",city) end
local writes = serviceMock.writes
svc.useStop(player,"City",city)
assert(serviceMock.writes == writes + 1, "reentrant delivery cannot pay twice")
serviceMock.onWrite=nil
assert(serviceMock.cash == rules.FARE and not svc.trips[player], "successful arrival pays once")
assert(not b.seats.FerryPassengerSeat1.Disabled, "delivery frees seats")
svc.useStop(player,"City",city)
assert(serviceMock.cash == rules.FARE and svc.trips[player], "another press boards a return crossing instead of paying twice")
local replacement = boat()
serviceMock.boat = replacement
svc.useStop(player,"Main",main)
assert(not svc.trips[player] and serviceMock.cash == rules.FARE, "a replacement boat cannot claim the old crossing")
assert(not b.seats.FerryPassengerSeat1.Disabled, "replacement frees previous passenger seats")
for _, path in {"src/shared/Ferry.luau", "src/server/FerryService.luau", "src/client/Ferry.luau"} do
	local ok, err = pcall(luau.compile, read(path))
	assert(ok, path .. " failed to compile: " .. tostring(err))
end
print("Ferry service: range, boarding, seats, save retry, payout and replacement passed")
