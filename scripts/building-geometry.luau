-- Used by check-building.mjs with recording Roblox geometry doubles.
local Building = require('../src/shared/BuildingCatalog')
local Renderer = require('../src/shared/BuildingRenderer')
local function close(a,b) return math.abs(a-b)<0.0001 end
local function create(parent,name,size,frame)
	local item=Instance.new('Part')
	item.Name,item.Size,item.CFrame=name,size,frame
	item.Material={Name='Plaster'}
	item.Color=Color3.fromRGB(180,170,160)
	item.CanTouch=true
	item.Parent=parent
	return item
end
local function contains(part,position)
	local point=part.CFrame:PointToObjectSpace(position)
	return math.abs(point.X)<part.Size.X/2-0.001 and math.abs(point.Y)<part.Size.Y/2-0.001 and math.abs(point.Z)<part.Size.Z/2-0.001
end
local function solidAt(folder,position)
	for _,part in folder:GetDescendants() do
		if part:IsA('BasePart') and part.CanCollide and contains(part,position) then return true end
	end
	return false
end
local function descendantsOfKind(folder,kind)
	local result={}
	for _,part in folder:GetDescendants() do if part:IsA('BasePart') and part:GetAttribute('BuildingKind')==kind then table.insert(result,part) end end
	return result
end

local frame=CFrame.new(150,8,-70)*CFrame.Angles(0,math.pi/2,0)
local house=Instance.new('Model'); house.Name='BaseHouse'; house.Parent=workspace
local shell=Instance.new('Model'); shell.Name='Shell'; shell.Parent=house
local original=create(shell,'SideWall',Vector3.new(18,11.5,0.65),frame*CFrame.new(0,5.75,0))
original.Transparency=0.15
local originalColor,originalMaterial=original.Color,original.Material
local oldFloor=create(shell,'WashableFloor',Vector3.new(18,0.16,18),frame*CFrame.new(0,0.08,0))
local functional=Instance.new('Folder'); functional.Name='Furniture'; functional.Parent=house
local shelf=create(functional,'WallShelf',Vector3.new(4,4,1),frame*CFrame.new(0,2,0))
local baseline=Renderer.capture(house,frame)
local wallId=original:GetAttribute('BuildingId')
check(wallId~=nil and baseline[wallId].Kind=='Wall','Original base walls must be selectable')
check(oldFloor:GetAttribute('BuildingKind')=='Floor','Existing floors must be selectable')
check(shelf:GetAttribute('BuildingId')==nil,'Functional furniture must remain outside structural edits')
check(close(Building.length(baseline[wallId]),18),'Captured wall length changed under a rotated base frame')
check(close(baseline[wallId].BaseY,0) and close(baseline[wallId].Height,11.5),'Captured opening height must match original wall')
check(Renderer.capture(house,frame)[wallId]~=nil,'Recapture must retain stable structural IDs')

local site={Pieces={{Id='p1',Kind='Door',HostId=wallId,Offset=9,Style='Open',Level=0,Material='Wood',Color={100,80,60}}},Overrides={}}
Renderer.sync(house,frame,nil,site)
local geometry=house:FindFirstChild('BuildingPieces')
check(original.Transparency==1 and not original.CanCollide and not original.CanQuery,'A cut original wall must stop blocking the rendered opening')
check(not solidAt(geometry,frame*Vector3.new(0,4,0)),'Door must create an actual passable hole')
check(solidAt(geometry,frame*Vector3.new(-5,4,0)),'Door cutout must preserve the wall on both sides')
check(solidAt(geometry,frame*Vector3.new(0,10,0)),'Door cutout must preserve a lintel')
check(#descendantsOfKind(geometry,'Door')>0,'Door frame geometry is missing')
for _,part in descendantsOfKind(geometry,'Wall') do check(part:GetAttribute('BuildingId')==wallId,'Cut wall fragments must keep the host selection ID') end

site.Pieces={{Id='p2',Kind='Window',HostId=wallId,Offset=9,Style='Classic',Level=0,Material='Wood',Color={100,80,60}}}
Renderer.sync(house,frame,nil,site)
geometry=house:FindFirstChild('BuildingPieces')
check(not solidAt(geometry,frame*Vector3.new(-0.6,5,0)),'Window must create an actual wall cutout around its glass')
check(solidAt(geometry,frame*Vector3.new(0,1.5,0)),'Window must preserve the lower wall')
check(solidAt(geometry,frame*Vector3.new(0,10,0)),'Window must preserve the upper wall')
local glass=geometry:FindFirstChild('Glass',true)
check(glass and glass.Transparency>0 and glass.CanCollide==false,'Window glass must be transparent and fit the opening')

-- Undo and plot ownership changes supply an empty site snapshot and restore the pristine shell.
Renderer.sync(house,frame,nil,{Pieces={},Overrides={[wallId]={Color={10,20,30},Material='Brick',Removed=true}}})
check(original.Transparency==1 and not original.CanCollide,'Removing an original wall must remove its collision')
Renderer.sync(house,frame,nil,{Pieces={},Overrides={}})
check(original.Color==originalColor and original.Material==originalMaterial,'Clearing owner overrides must restore original appearance')
check(original.Transparency==0.15 and original.CanCollide and original.CanQuery and original.CanTouch,'Clearing overrides must restore original physical properties')
check(#house:FindFirstChild('BuildingPieces'):GetDescendants()==0,'Clearing construction must remove old owner geometry')
check(shelf.Parent==functional and shelf.CanCollide,'Structural refresh must preserve functional furniture')

-- A custom wall uses the same cutout renderer; removing its door closes the gap again.
local custom={Id='p3',Kind='Wall',X1=-9,Z1=0,X2=9,Z2=0,Level=0,Material='Brick',Color={100,120,140}}
site={Pieces={custom,{Id='p4',Kind='Door',HostId='p3',Offset=9,Level=0,Style='Panel',Material='Wood',Color={80,70,60}}},Overrides={}}
Renderer.sync(house,frame,nil,site)
geometry=house:FindFirstChild('BuildingPieces')
check(not solidAt(geometry,frame*Vector3.new(0,4,0)),'Custom wall door must remain passable')
site.Pieces={custom}
Renderer.sync(house,frame,nil,site)
geometry=house:FindFirstChild('BuildingPieces')
check(solidAt(geometry,frame*Vector3.new(0,4,0)),'Removing a hosted opening must close the custom wall')

for _,style in {'Flat','Gable','Shed'} do
	local roof={Id='p5',Kind='Roof',X1=-9,Z1=-9,X2=9,Z2=9,Level=1,Material='RoofShingles',Color={120,70,50},Style=style}
	local preview=Renderer.preview(workspace,frame,roof,{},baseline,true)
	check(#preview:GetDescendants()>0,style..' roof preview is empty')
	for _,part in preview:GetDescendants() do
		if part:IsA('BasePart') then
			check(not part.CanCollide and not part.CanQuery and not part.CanTouch,style..' preview must not change placement raycasts or physics')
			check(part.Transparency==0.5 and part.Size.X>0 and part.Size.Y>0 and part.Size.Z>0,'Preview pieces must have valid translucent geometry')
			check(frame:PointToObjectSpace(part.Position).Y>Building.LEVEL_HEIGHT+Building.WALL_HEIGHT,'Roof must use the selected floor level')
		end
	end
	preview:Destroy()
end

local company=Instance.new('Model'); company.Parent=workspace
local decoration=create(company,'SideWall',Vector3.new(4,10,0.5),frame*CFrame.new(0,5,0))
check(next(Renderer.capture(company,frame,'Company'))==nil and decoration:GetAttribute('BuildingId')==nil,'Company scenery outside the plot must not become editable')

-- The same room hierarchy keeps its edit IDs after a different plot rotation/position.
local movedFrame=CFrame.new(-420,20,140)*CFrame.Angles(0,-math.pi/3,0)
local movedHouse=Instance.new('Model'); movedHouse.Name='BaseHouse'; movedHouse.Parent=workspace
local movedShell=Instance.new('Model'); movedShell.Name='Shell'; movedShell.Parent=movedHouse
local movedWall=create(movedShell,'SideWall',Vector3.new(18,11.5,0.65),movedFrame*CFrame.new(0,5.75,0))
Renderer.capture(movedHouse,movedFrame)
check(movedWall:GetAttribute('BuildingId')==wallId,'Saved shell edits must keep matching when an owner moves to a rotated base')

local upper={Id='p6',Kind='Floor',X1=-9,Z1=-9,X2=9,Z2=9,Level=1,Material='WoodPlanks',Color={160,140,120}}
for _,direction in {'North','East','South','West'} do
	local alongX=direction=='East' or direction=='West'
	local stair={Id='p7',Kind='Stairs',X1=if alongX then -4.5 else -2.25,Z1=if alongX then -2.25 else -4.5,
		X2=if alongX then 4.5 else 2.25,Z2=if alongX then 2.25 else 4.5,Level=0,Style=direction,Material='WoodPlanks',Color={100,80,60}}
	Renderer.sync(house,frame,nil,{Pieces={upper,stair},Overrides={}})
	geometry=house:FindFirstChild('BuildingPieces')
	local steps=descendantsOfKind(geometry,'Stairs')
	check(#steps==16,direction..' staircase must have sixteen physical treads')
	local previousTop,previousAxis=0,nil
	for _,step in steps do
		local position=frame:PointToObjectSpace(step.Position)
		local top=position.Y+step.Size.Y/2
		local axis=if alongX then position.X else position.Z
		check(step.CanCollide and top>previousTop,'Stair treads must rise continuously and remain collidable')
		if previousAxis then
			check((if direction=='East' or direction=='South' then axis>previousAxis else axis<previousAxis),'Stair climb direction differs from its selected style')
		end
		previousTop,previousAxis=top,axis
	end
	check(close(previousTop,0.16+Building.LEVEL_HEIGHT+0.13),'Top tread must meet the next floor finish')
	check(not solidAt(geometry,frame*Vector3.new(0,12.23,0)),'Upper floor must have an actual hole over the staircase')
	check(solidAt(geometry,frame*Vector3.new(8,12.23,8)),'Stair cutout must preserve the surrounding upper floor')
	local remainingArea=0
	for _,floorPart in descendantsOfKind(geometry,'Floor') do remainingArea+=floorPart.Size.X*floorPart.Size.Z end
	check(close(remainingArea,18*18-4.5*9),'Stair cutout must remove only its own footprint')
	Renderer.sync(house,frame,nil,{Pieces={upper},Overrides={}})
	check(solidAt(house:FindFirstChild('BuildingPieces'),frame*Vector3.new(0,12.23,0)),'Removing the staircase must close its upper-floor opening')
end

local upperOriginal=create(shell,'UpperFloor',Vector3.new(18,0.16,18),frame*CFrame.new(0,12.08,0))
local topBuiltins=Renderer.capture(house,frame)
local topId=upperOriginal:GetAttribute('BuildingId')
check(topBuiltins[topId].Level==1 and close(topBuiltins[topId].X2-topBuiltins[topId].X1,18)
	and close(topBuiltins[topId].Z2-topBuiltins[topId].Z1,18),'Original elevated floors must capture their complete rectangle and level')
local stair={Id='p8',Kind='Stairs',X1=-2.25,Z1=-4.5,X2=2.25,Z2=4.5,Level=0,Style='North',Material='WoodPlanks',Color={100,80,60}}
Renderer.sync(house,frame,nil,{Pieces={stair},Overrides={}})
check(not upperOriginal.CanCollide and upperOriginal.Transparency==1,'Original upper floor must yield collision to the stair opening')
check(not solidAt(house:FindFirstChild('BuildingPieces'),frame*Vector3.new(0,12.08,0)),'Original upper floor cutout must leave staircase headroom')
check(solidAt(house:FindFirstChild('BuildingPieces'),frame*Vector3.new(8,12.08,8)),'Cut original floor must preserve its surrounding platform')
Renderer.sync(house,frame,nil,{Pieces={},Overrides={}})
check(upperOriginal.CanCollide and upperOriginal.Transparency==0,'Removing stairs must restore an original upper floor')
