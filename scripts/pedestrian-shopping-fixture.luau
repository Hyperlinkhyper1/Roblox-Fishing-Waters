if options.purchase then
	local owner={UserId=1}
	local profile={Cash=0,Angler={Freezer={},Pantry={},Staff={},Upgrades={}}}
	for i=1,30 do table.insert(profile.Angler.Freezer,{Value=20,FishId="Trout",Kg=1,Id=i}) end
	local function ownerOf(base) return if base:GetAttribute("OwnerUserId")==1 then owner else nil end
	local BoatService={
		getProfile=function() return profile end,
		updateProgress=function(_,transform)
			local ok,message=pcall(transform,profile)
			return ok,message
		end,
	}
	local AnglerData={sellFrozen=function(data,record)
		local at=table.find(data.Freezer,record)
		if not at then return nil,0 end
		local result=table.clone(data)
		result.Freezer=table.clone(data.Freezer)
		table.remove(result.Freezer,at)
		return result,record.Value
	end}
	local ShopUpgrades={hasAdvertisement=function() return false end,hasBaskets=function() return false end}
	local ShopDesk={WIDTH=9,HEIGHT=3,DEPTH=3,frame=function(frame) return frame*CFrame.new(10,0,76) end}
	local BaseGrid={SHOP_FRONT=65.25}
	local NpcNavigation={clearance=function() return 2 end}
	local Kitchen,FishFreezer={CASE_DEPTH=3},{DEPTH=3}
	local ARRIVAL_SECONDS,WAIT_SECONDS,SERVE_DISTANCE=25,150,14
	local customers={}
	local random={NextInteger=function(_,a) return a end}
	local function fixtureFrames(shop) return {ShopDesk.frame(shop.frame)} end
	local function recordKey(record) return tostring(record.Id) end
	local function dishKey(record) return tostring(record.Id) end
	local function describeFish() return "Trout" end
	local function notify() end
	local function near() return true end
	local function face() end
	local function bubble(customer) currentCustomer=customer end
	local function carry() end
	local function refreshShelves(shop)
		shop.displayFish={}
		for _,record in profile.Angler.Freezer do
			table.insert(shop.displayFish,{record=record,freezer=shop.frame*CFrame.new(-10,0,75)})
		end
	end
	local function spawnCustomer(position,_,guest)
		local root={Position=position+Vector3.new(0,3,0),Size=Vector3.new(2,2,1),Parent=true}
		local humanoid={HipHeight=2,Health=100,Died={Once=function() end}}
		local model={Parent=true}
		function model:FindFirstChild() return root end
		function model:FindFirstChildOfClass() return humanoid end
		function model:SetAttribute() end
		function model:Destroy() self.Parent=nil;root.Parent=nil end
		return model
	end
	local function walk(customer,point,allowed)
		if allowed and not allowed() then return false end
		local localPoint=customer.shop.frame:PointToObjectSpace(point)
		if localPoint.Z>65.25 then entered+=1 end
		customer.root.Position=point+Vector3.new(0,3,0)
		return true
	end
	local function takeFromFreezer(_,_,item)
		item.taken=true
		local fish={Destroy=function() end}
		item.fish=fish
		return fish
	end
	local function takeFood() return nil end
	local function putOnCounter() end
	local function ownerPrompt() return {SetAttribute=function() end,Destroy=function() end} end
	-- REAL_RETURN --
	-- REAL_DOORS --
	-- REAL_FINISH --
	-- REAL_VISIT --
	-- REAL_SELL --
	-- REAL_ARRIVE --
	engineSell=function(customer)
		sell(owner,customer)
		if customer.sold then paid+=1 end
	end
	local shop
	actualVisit=function(base,frame,guest)
		if not shop then shop={base=base,frame=frame,customers={},staff={},nextArrival=0} end
		refreshShelves(shop)
		return arrive(shop,guest)
	end
end
