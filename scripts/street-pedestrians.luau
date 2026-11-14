-- Full production road discovery and pedestrian simulation on a miniature
-- harbour: long ring roads, back lanes, crossings, plaza obstacles and shops.
local Pedestrians = (function()
-- PEDESTRIANS --
end)()
local Grid = (function()
-- GRID --
end)()
local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end
local vector = {}
local Vector3 = {}
function Vector3.new(x, y, z)
	return setmetatable({X=x, Y=y, Z=z, Magnitude=math.sqrt(x*x+y*y+z*z)}, vector)
end
function vector.__add(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
function vector.__sub(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
local CFrame = {}
function CFrame.new(x,y,z,yaw)
	if type(x) == "table" then x,y,z = x.X,x.Y,x.Z end
	local frame = {Position=Vector3.new(x or 0,y or 0,z or 0), yaw=yaw or 0}
	local c,s = math.cos(frame.yaw),math.sin(frame.yaw)
	function frame:PointToWorldSpace(p) return self.Position+Vector3.new(c*p.X+s*p.Z,p.Y,-s*p.X+c*p.Z) end
	function frame:PointToObjectSpace(p)
		local d=p-self.Position
		return Vector3.new(c*d.X-s*d.Z,d.Y,s*d.X+c*d.Z)
	end
	return setmetatable(frame,{
		__add=function(a,b) return CFrame.new(a.Position.X+b.X,a.Position.Y+b.Y,a.Position.Z+b.Z,a.yaw) end,
		__mul=function(a,b)
			local p=a:PointToWorldSpace(b.Position)
			return CFrame.new(p.X,p.Y,p.Z,a.yaw+b.yaw)
		end,
	})
end

local function simulate(options)
	local now, ownerId, visits, peak, scans, maxSpan = 0, 1, 0, 0, 0, 0
	local clock = options.clock or 12
	local configs, guests, bases, loops = {}, {}, {}, {}
	local attrs, warnings = {}, 0
	local actualVisit, engineSell, currentCustomer, inVisit
	local paid, entered, firstVisitAt = 0, 0, nil
	local visitTimes = {}
	local layoutFrames
	local function object(name, children, part)
		local obj = part or {}
		obj.Name, obj.children, obj.Parent = name, children or {}, true
		function obj:IsA(kind) return if self.Size then kind=="Part" or kind=="BasePart" else kind=="Model" end
		function obj:GetChildren() return self.children end
		function obj:GetDescendants()
			local all={}
			local function add(item) for _,child in item.children do table.insert(all,child); add(child) end end
			add(self)
			return all
		end
		function obj:FindFirstChild(key) for _,child in self.children do if child.Name==key then return child end end; return nil end
		function obj:GetAttribute(key) return self.attributes and self.attributes[key] end
		function obj:SetAttribute(key,value)
			self.attributes=self.attributes or {}
			self.attributes[key]=value
			if key=="Trip" then
				local trip=Pedestrians.decode(value)
				self.trip=trip
				self.origin=self.origin or Vector3.new(trip.points[1],trip.points[2],trip.points[3])
				for i=1,#trip.points,3 do
					maxSpan=math.max(maxSpan,(Vector3.new(trip.points[i],trip.points[i+1],trip.points[i+2])-self.origin).Magnitude)
				end
			end
		end
		function obj:Destroy() self.Parent=nil; self.destroyed=true end
		return obj
	end
	local function road(a,b,width)
		local d=b-a
		return object("Paving",{},{
			Size=Vector3.new(width,0.6,d.Magnitude), Position=Vector3.new((a.X+b.X)/2,-0.3,(a.Z+b.Z)/2),
			CFrame=CFrame.new((a.X+b.X)/2,-0.3,(a.Z+b.Z)/2,math.atan2(d.X,d.Z)), Material="Cobblestone", Shape="Block",
		})
	end
	local function ring(x,z,width)
		local points={Vector3.new(-x,0,-z),Vector3.new(x,0,-z),Vector3.new(x,0,z),Vector3.new(-x,0,z)}
		local parts={}
		for i,p in points do table.insert(parts,road(p,points[i%4+1],width)) end
		return parts
	end
	local crossing=object("CrossStreets",{
		road(Vector3.new(0,0,140),Vector3.new(0,0,180),10),
		road(Vector3.new(0,0,-140),Vector3.new(0,0,-180),10),
		road(Vector3.new(260,0,0),Vector3.new(300,0,0),10),
		road(Vector3.new(-260,0,0),Vector3.new(-300,0,0),10),
	})
	local plaza=object("Plaza",{ object("Paving",{},{
		Size=Vector3.new(116,0.6,116),Position=Vector3.new(0,-0.3,-180),
		CFrame=CFrame.new(0,-0.3,-180),Material="Limestone",Shape="Block",
	}) })
	local village=object("Village",{object("Road",ring(300,180,16)),object("Lane",ring(260,140,10)),crossing,plaza})
	local map=object("Map",{object("Harbour Isle",{village})})
	local shared=object("Pedestrians")
	local Instance={new=function(kind)
		check(kind=="Configuration","Street travel never allocates physical rigs")
		local config=object("Walker")
		config.Parent=nil
		table.insert(configs,config)
		return config
	end}
	local avatars={FindFirstChild=function() return if options.noAvatars then nil else {} end}
	local ReplicatedStorage={
		GetAttribute=function() return true end,
		FindFirstChild=function(_,name) return if name==Pedestrians.AVATAR_FOLDER then avatars else nil end,
	}
	local Players={GetPlayers=function() return {} end,GetPlayerByUserId=function(_,id) return if id>0 then {} else nil end}
	local workspace={
		GetServerTimeNow=function() return now end,
		FindFirstChild=function(_,name) return if name=="Map" then map else nil end,
		Raycast=function(_,origin)
			scans+=1
			local water=not options.actualLayout and (math.abs(origin.X)>340 or math.abs(origin.Z)>245)
			return {Position=Vector3.new(origin.X,if options.actualLayout then 5.6 else 0,origin.Z),Normal=Vector3.new(0,1,0),Material=if water then "Water" else "Paving"}
		end,
		GetPartBoundsInBox=function(_,frame)
			-- A fountain breaks the direct road line through the plaza.
			local p=frame.Position
			return if p.X*p.X+(p.Z+180)^2<12^2 then {true} else {}
		end,
	}
	local game={GetService=function(_,name) return if name=="Players" then Players else ReplicatedStorage end}
	local Random={new=function()
		local seed=7331
		local rng={}
		function rng:NextNumber(a,b) seed=seed*48271%2147483647; return (a or 0)+seed/2147483647*((b or 1)-(a or 0)) end
		function rng:NextInteger(a,b) return math.floor(self:NextNumber(a,b+1)) end
		return rng
	end}
	local os={clock=function() return now end}
	local Enum={RaycastFilterType={Exclude="Exclude"},Material={Water="Water",Pebble="Pebble"},PartType={Cylinder="Cylinder"}}
	local RaycastParams,OverlapParams={new=function() return {} end},{new=function() return {} end}
	local task={
		spawn=function(fn)
			if options.purchase and #loops > 0 then
				inVisit = true
				fn()
				inVisit = false
			else table.insert(loops,fn) end
		end,
		wait=function(seconds)
			now+=seconds or 0
			if inVisit then
				if currentCustomer and currentCustomer.prompt and not currentCustomer.sold then engineSell(currentCustomer) end
				return
			end
			if options.nightAt and now>=options.nightAt then clock=2 end
			if options.changeOwnerAt and now>=options.changeOwnerAt then ownerId=2 end
			if options.leaveAt and now>=options.leaveAt then ownerId=0 end
			for _,guest in guests do
				if not guest.done and (now>=guest.finishAt or not guest.valid()) then
					if guest.ownerId~=ownerId then check(not guest.valid(),"Ownership changes invalidate active visits") end
					guest.done=true
					guest.finish(if options.stranded then Vector3.new(9999,0,9999) else guest.position,true)
					guest.finish(guest.position,true)
				end
			end
			local active=0
			for _,guest in guests do if not guest.done then active+=1 end end
			peak=math.max(peak,active)
			check(active<=Pedestrians.MAX_VISITORS,"Shared visitor limit is enforced")
			if now>=(options.duration or 240) then error("SIMULATION_COMPLETE") end
		end,
	}
	local function warn() warnings+=1 end
	-- SHOP_INTEGRATION --
	local dependencies={
		Pedestrians=Pedestrians,Grid=Grid,
		DayNight={clockTime=function() return clock end},
		Weather={getState=function() return {rain=options.rain or 0} end},
	}
	-- HARBOUR_LAYOUT --
	dependencies.Network=(function()
		-- NETWORK --
	end)()
	local discover = dependencies.Network.build
	function dependencies.Network.build(root, businesses)
		local result = discover(root, businesses)
		if options.actualLayout then
			local component
			for _, shop in businesses do
				local p = shop.frame:PointToWorldSpace(shop.position)
				local cell = Grid.nearest(result.grid, p.X, p.Z, 6)
				check(cell ~= nil, "Every production shop has a public approach")
				local id = result.componentOf[cell]
				check(component == nil or component == id, "All fifteen shop approaches share the island road network")
				component = id
			end
		end
		return result
	end
	local Streets=(function()
		-- STREETS --
	end)()
	for index=1,options.shops or 1 do
		local base=object("Base"..index)
		function base:GetAttribute() return ownerId end
		table.insert(bases,base)
		local frame=if layoutFrames then layoutFrames[index] elseif index==2 then CFrame.new(-352,0,0,math.pi/2) else CFrame.new(if index==3 then 220 else -220,0,128)
		Streets.register(base,frame,"Shop",Vector3.new(0,0,62.4),function(guest)
			visits+=1
			table.insert(visitTimes, now)
			firstVisitAt=firstVisitAt or now
			check((options.scheduled or now>=2) and guest.valid(),"Only a live pedestrian can shop")
			local config
			for _,at in configs do if at.Name==guest.id then config=at end end
			check(config and config.Parent==shared and not config.destroyed,"Buyer was already walking on the public network")
			check(config:GetAttribute("Look")==guest.look,"Appearance survives shopping")
			local sample=Pedestrians.sample(config.trip,now)
			check((Vector3.new(sample.x,sample.y,sample.z)-guest.position).Magnitude<0.2,"Handoff occurs at the walked-to endpoint")
			local localPosition=frame:PointToObjectSpace(guest.position)
			check(math.abs(localPosition.X)<0.1 and math.abs(localPosition.Z-62.4)<0.1,"Customer reaches the doorway centre")
			if options.fail then error("Deliberate visit failure") end
			if options.reject then return false end
			if actualVisit then return actualVisit(base, frame, guest) end
			check(guest.begin({SetAttribute=function() end}) and config:GetAttribute("InShop"),"Physical visitor replaces the street rig")
			guest.finishAt,guest.ownerId=now+(options.stay or 10),ownerId
			table.insert(guests,guest)
			return true
		end,function() return options.interest or 0 end, if options.scheduled then 20 else nil)
	end
	Streets.start(shared)
	check(#loops==1,"The whole island shares one scheduler")
	local ok,problem=pcall(loops[1])
	check(not ok and string.find(tostring(problem),"SIMULATION_COMPLETE",1,true)~=nil,"Scheduler stays alive: "..tostring(problem))
	local outside=0
	for _,config in configs do if config.Parent==shared and not config:GetAttribute("InShop") then outside+=1 end end
	check(shared:GetAttribute("Ready") and shared:GetAttribute("WalkableCells")>1000,"The real road geometry builds an island-wide network")
	for _,base in bases do check(base.attributes.PedestrianShopReachable,"An actual forecourt connects each shop to the roads") end
	return {outside=outside,visits=visits,visitTimes=visitTimes,peak=peak,warnings=warnings,maxSpan=maxSpan,scans=scans,paid=paid,entered=entered,firstVisitAt=firstVisitAt,components=shared:GetAttribute("RouteComponents")}
end

local day=simulate({interest=0})
check(day.outside==68 and day.visits==0,"Daytime crowd circulates without forced purchases")
check(day.maxSpan>400,"Individuals travel hundreds of studs around the island, beyond the old storefront patch")
check(day.components==1,"Main roads, back lanes, crossings and plaza remain connected around obstacles")
local night=simulate({clock=2,interest=0})
check(night.outside==11,"The shared island crowd is smaller late at night")
check(day.scans==night.scans,"Population changes do not add per-pedestrian physics queries")
local dusk=simulate({nightAt=60})
check(dusk.outside==11,"Existing daytime walkers retire gradually at night")
local shopping=simulate({interest=1,changeOwnerAt=65})
check(shopping.visits>2 and shopping.peak>0 and shopping.maxSpan>400,"The same island travellers visit shops and continue their journeys")
local ordinary=simulate({interest=0.35,duration=100})
check(ordinary.visits>0 and ordinary.firstVisitAt<60,"Normal purchase probability provides early traffic without needing a guaranteed shop roll")
local scheduled=simulate({interest=1,scheduled=true,duration=100})
check(scheduled.visits>=5,"A ready shop receives scheduled customers")
for i=2,#scheduled.visitTimes do
	check(scheduled.visitTimes[i]-scheduled.visitTimes[i-1]<=20.25,"Scheduled customers arrive every 20 seconds")
end
local missing=simulate({interest=1,noAvatars=true})
check(missing.visits==0 and missing.outside==68,"Pending appearances never create random replacement shoppers")
local rejected=simulate({interest=1,reject=true})
check(rejected.visits>0 and rejected.outside==68,"Full or unstocked shops let people continue")
local failed=simulate({interest=1,fail=true})
check(failed.warnings>0 and failed.outside==68,"Failed visits release their slots")
local stranded=simulate({interest=1,stranded=true})
check(stranded.visits>0,"Stranded visitors release capacity without teleporting back")
local purchases=simulate({interest=1,purchase=true,duration=160})
check(purchases.paid>0 and purchases.entered>0 and purchases.maxSpan>200,"An island passer-by enters, picks stock, pays through the production sale, exits and resumes walking")
local realLayout=simulate({interest=1,actualLayout=true,shops=15,duration=160})
check(realLayout.visits>0 and realLayout.maxSpan>400,"Production Harbour roads and all fifteen real shop approaches support island travel and visits")
Pedestrians.MAX_VISITORS=2
local budget=simulate({interest=1,shops=3,stay=35,duration=320})
check(budget.peak==2 and budget.visits>2,"Distant and rotated shops share the physical NPC budget")


do
	local builds = 0
	local avatarTemplates, buildingAvatar = {}, {}
	local description = { IsA = function() return true end }
	local ReplicatedStorage = { FindFirstChild = function()
		return { FindFirstChild = function() return description end }
	end }
	local Players = { CreateHumanoidModelFromDescriptionAsync = function(_, chosen)
		check(chosen == description, "Physical customers use the published pedestrian appearance")
		builds += 1
		return { Clone = function() return {} end }
	end }
	local Enum = { HumanoidRigType = { R15 = "R15" } }
	-- AVATAR_CACHE --
	local guest = { look = 1, valid = function() return true end }
	local first = pedestrianModel(guest)
	local second = pedestrianModel(guest)
	check(first ~= second and builds == 1, "Repeat visitors clone a cached rig instead of rebuilding avatars")
	guest.look += Pedestrians.AVATAR_COUNT
	pedestrianModel(guest)
	check(builds == 1, "Avatar cache is bounded by the published appearance slots")
	guest.valid = function() return false end
	check(not pcall(pedestrianModel, guest) and builds == 1, "Cancelled visits cannot build replacement avatars")
end

do
	local people, container = {}, {}
	local HIDDEN, nearCount = Pedestrians.HIDDEN, 0
	local function setMode(rig, mode) rig.mode = mode end
	-- CLIENT_SHOW --
	-- CLIENT_HIDE --
	-- CLIENT_TRACK --
	local callbacks, disconnected, attributes = {}, 0, {
		Look = 19, AreaCenter = Vector3.new(1500, 0, 1000),
		Trip = Pedestrians.encode({ start = 0, speed = 4, points = { 0, 0, 0, 10, 0, 0 } }),
	}
	local config = {
		IsA = function() return true end,
		GetAttribute = function(_, key) return attributes[key] end,
		GetAttributeChangedSignal = function(_, key)
			return { Connect = function(_, callback)
				callbacks[key] = callback
				return { Disconnect = function() disconnected += 1 end }
			end }
		end,
	}
	track(config)
	local person = people[config]
	check((person.center - Vector3.new(5, 0, 0)).Magnitude < 0.01, "Culling follows the current journey leg")
	local destroyed = false
	person.avatar = { model = { Parent = container, Destroy = function() destroyed = true end }, shown = true }
	person.tier, nearCount = 1, 1
	attributes.InShop = true
	callbacks.InShop()
	check(not person.avatar.shown and person.avatar.model.Parent == nil and nearCount == 0, "Entering hides the local rig and releases the animation slot")
	attributes.InShop = false
	callbacks.InShop()
	check(person.nextUpdate == 0 and people[config] == person, "Returning reuses the same pedestrian and updates it immediately")
	attributes.Trip = Pedestrians.encode({start=20,speed=4,points={1500,0,0,1510,0,0}})
	callbacks.Trip()
	check((person.center - Vector3.new(1505,0,0)).Magnitude < 0.01, "Walkers stay drawable after travelling far from their original block")
	untrack(config)
	check(disconnected == 2 and destroyed and people[config] == nil, "Removing a pedestrian destroys its rig and both subscriptions")
end
print(`Street pedestrians: {checks} population, purchase, handoff, rotation, cleanup and budget checks passed (simulated world).`)
