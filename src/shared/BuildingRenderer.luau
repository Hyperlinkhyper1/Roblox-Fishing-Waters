-- Shared geometry for authoritative construction and the client's placement ghost.
-- Original shells stay in place so upgrades and functional room references survive.
local Catalog = require(script.Parent.BuildingCatalog)
local Renderer = {}
local captures = setmetatable({}, {__mode="k"})
local UP = Vector3.new(0,1,0)
local function color(value)
	return Color3.fromRGB(value[1],value[2],value[3])
end
local function bytes(value)
	return {math.round(value.R*255),math.round(value.G*255),math.round(value.B*255)}
end
local function kindOf(part)
	local n=part.Name
	if n:find("Floor") and not n:find("Lamp") then return "Floor" end
	if n:find("Roof") or n:find("Ridge") or n:find("Gable") or n:find("Eaves") or n:find("Gutter") or n:find("CeilingTie") or n:find("TileCourse") or n:lower():find("bargeboard") then return "Roof" end
	if n:find("Window") or n=="StoneSill" or n=="OpenShutter" then return "Window" end
	if n:find("DoorJamb") or n:find("DoorHeader") or n=="Door" or n=="DoorPanel" then return "Door" end
	if n:find("Wall") or n:find("Partition") or n:find("PassageLintel") or n:find("DoorLintel") then return "Wall" end
	return nil
end
local function excluded(part,model)
	local node=part.Parent
	while node and node~=model do
		if node.Name=="Furniture" or node.Name=="PlotFurniture" or node.Name=="BuildingPieces"
			or node.Name=="CeilingLights" or node.Name=="Staff" then return true end
		node=node.Parent
	end
	return false
end
local function stableId(part,model,_localFrame)
	local names={}
	local node=part
	while node and node~=model do
		local ordinal=0
		if node.Parent then
			for _,sibling in node.Parent:GetChildren() do
				if sibling.Name==node.Name then ordinal+=1 end
				if sibling==node then break end
			end
		end
		table.insert(names,1,(node.Name:gsub("[^%w_%-]","_")).."_"..tostring(ordinal))
		node=node.Parent
	end
	return "b:"..table.concat(names,"/")
end
function Renderer.capture(model,frame,site)
	local records=captures[model]
	if not records then records={} captures[model]=records end
	local known={}
	for _,record in records do known[record.Part]=true end
	for _,part in model:GetDescendants() do
		if not part:IsA("BasePart") or known[part] or excluded(part,model) then continue end
		-- An island's decorative buildings are outside its building plot.
		if site=="Company" then continue end
		local kind=kindOf(part)
		if not kind then continue end
		local localFrame=frame:ToObjectSpace(part.CFrame)
		local id=stableId(part,model,localFrame)
		local p=localFrame.Position
		local axis=if part.Size.X>=part.Size.Z then localFrame.RightVector else -localFrame.LookVector
		local length=math.max(part.Size.X,part.Size.Z)
		local start=p-axis*length/2
		local finish=p+axis*length/2
		local descriptor={Id=id,Kind=kind,X1=start.X,Z1=start.Z,X2=finish.X,Z2=finish.Z,
			BaseY=p.Y-part.Size.Y/2,Height=part.Size.Y,Thickness=math.min(part.Size.X,part.Size.Z),
			Level=0,Material=part.Material.Name,Color=bytes(part.Color)}
		if kind=="Floor" or kind=="Roof" then
			local right,up,back=localFrame.RightVector,localFrame.UpVector,localFrame.LookVector
			local halfX=(math.abs(right.X)*part.Size.X+math.abs(up.X)*part.Size.Y+math.abs(back.X)*part.Size.Z)/2
			local halfZ=(math.abs(right.Z)*part.Size.X+math.abs(up.Z)*part.Size.Y+math.abs(back.Z)*part.Size.Z)/2
			descriptor.X1,descriptor.X2=p.X-halfX,p.X+halfX
			descriptor.Z1,descriptor.Z2=p.Z-halfZ,p.Z+halfZ
			if kind=="Floor" then
				local base=if site=="Company" then 0 else 0.16
				descriptor.Level=math.clamp(math.round((p.Y+part.Size.Y/2-base)/Catalog.LEVEL_HEIGHT),0,Catalog.MAX_LEVEL)
			end
		end
		if kind=="Wall" and (math.abs(start.X-finish.X)<0.01 or math.abs(start.Z-finish.Z)<0.01) then
			if descriptor.X1>descriptor.X2+0.01 or descriptor.Z1>descriptor.Z2+0.01 then
				descriptor.X1,descriptor.X2,descriptor.Z1,descriptor.Z2=descriptor.X2,descriptor.X1,descriptor.Z2,descriptor.Z1
			end
		end
		records[id]={Part=part,Descriptor=descriptor,Color=part.Color,Material=part.Material,
			Transparency=part.Transparency,CanCollide=part.CanCollide,CanQuery=part.CanQuery,CanTouch=part.CanTouch}
		part:SetAttribute("BuildingId",id)
		part:SetAttribute("BuildingKind",kind)
	end
	local descriptors={}
	for id,record in records do
		if record.Part:IsDescendantOf(model) then descriptors[id]=record.Descriptor else records[id]=nil end
	end
	return descriptors
end
Renderer.describe=Renderer.capture
local function part(parent,name,size,cf,entry,id,kind)
	local result=Instance.new("Part")
	result.Name=name
	result.Size=size
	result.CFrame=cf
	result.Anchored=true
	result.TopSurface=Enum.SurfaceType.Smooth
	result.BottomSurface=Enum.SurfaceType.Smooth
	result.Material=Enum.Material[entry.Material] or Enum.Material.Plaster
	result.Color=color(entry.Color)
	result:SetAttribute("BuildingId",id or entry.Id)
	result:SetAttribute("BuildingKind",kind or entry.Kind)
	result.Parent=parent
	return result
end
local function hostFrame(frame,host)
	local dx,dz=host.X2-host.X1,host.Z2-host.Z1
	local length=math.sqrt(dx*dx+dz*dz)
	local right=Vector3.new(dx/length,0,dz/length)
	local y=host.BaseY or (0.16+(host.Level or 0)*Catalog.LEVEL_HEIGHT)
	local start=Vector3.new(host.X1,y,host.Z1)
	return frame*CFrame.fromMatrix(start,right,UP,right:Cross(UP)),length
end
local function drawWall(parent,frame,host,openings)
	local cf,length=hostFrame(frame,host)
	local height=host.Height or Catalog.WALL_HEIGHT
	local thickness=host.Thickness or 0.45
	local function slab(x1,x2,y1,y2)
		if x2-x1<0.01 or y2-y1<0.01 then return end
		part(parent,"Wall",Vector3.new(x2-x1,y2-y1,thickness),cf*CFrame.new((x1+x2)/2,(y1+y2)/2,0),host)
	end
	table.sort(openings,function(a,b) return a.Offset<b.Offset end)
	local cursor=0
	for _,opening in openings do
		local width,bottom,top=Catalog.opening(opening)
		local left,right=opening.Offset-width/2,opening.Offset+width/2
		slab(cursor,left,0,height)
		slab(left,right,0,bottom)
		slab(left,right,top,height)
		cursor=right
	end
	slab(cursor,length,0,height)
end
local function drawOpening(parent,frame,entry,host)
	if not host then return end
	local cf=hostFrame(frame,host)
	local width,bottom,top=Catalog.opening(entry)
	local t=math.max(0.6,host.Thickness or 0.45)
	local function piece(name,size,x,y,z)
		return part(parent,name,size,cf*CFrame.new(entry.Offset+x,y,z or 0),entry)
	end
	local trim=0.14
	for _,side in {-1,1} do
		piece("Frame",Vector3.new(trim,top-bottom+trim,t),side*(width-trim)/2,(bottom+top)/2)
	end
	piece("Header",Vector3.new(width,trim,t),0,top-trim/2)
	if entry.Kind=="Window" then
		piece("Sill",Vector3.new(width+0.2,trim,t+0.15),0,bottom+trim/2)
		local glass=piece("Glass",Vector3.new(width-trim*2,top-bottom-trim*2,0.1),0,(bottom+top)/2)
		glass.Material=Enum.Material.Glass
		glass.Color=Color3.fromRGB(163,205,215)
		glass.Transparency=0.6
		glass.Reflectance=0.1
		glass.CanCollide=false
		if entry.Style=="Classic" then
			piece("Mullion",Vector3.new(0.1,top-bottom,0.2),0,(bottom+top)/2)
			piece("Rail",Vector3.new(width,0.1,0.2),0,(bottom+top)/2)
		end
	elseif entry.Style=="Panel" then
		-- The panel is held open, leaving a walkable 3.2-stud opening without scripts.
		local panel=piece("OpenDoor",Vector3.new(0.18,top-0.2,width-0.3),-width/2,top/2,(width-0.3)/2)
		panel.CanCollide=false
		local handle=piece("Handle",Vector3.new(0.12,0.16,0.35),-width/2+0.15,4,width-0.7)
		handle.Material=Enum.Material.Metal
	end
end
local function floorRectangles(entry,pieces)
	local rectangles={{entry.X1,entry.Z1,entry.X2,entry.Z2}}
	local cut=false
	for _,stairs in pieces do
		if stairs.Kind~="Stairs" or stairs.Level+1~=(entry.Level or 0) then continue end
		local nextRectangles={}
		for _,rect in rectangles do
			local ax,az=math.max(rect[1],stairs.X1),math.max(rect[2],stairs.Z1)
			local bx,bz=math.min(rect[3],stairs.X2),math.min(rect[4],stairs.Z2)
			if bx<=ax+0.01 or bz<=az+0.01 then table.insert(nextRectangles,rect);continue end
			cut=true
			local function keep(x1,z1,x2,z2)
				if x2>x1+0.01 and z2>z1+0.01 then table.insert(nextRectangles,{x1,z1,x2,z2}) end
			end
			keep(rect[1],rect[2],ax,rect[4])
			keep(bx,rect[2],rect[3],rect[4])
			keep(ax,rect[2],bx,az)
			keep(ax,bz,bx,rect[4])
		end
		rectangles=nextRectangles
	end
	return rectangles,cut
end
local function drawFloor(parent,frame,entry,pieces,y,thickness,original)
	local rectangles=floorRectangles(entry,pieces)
	for _,rect in rectangles do
		local floor=part(parent,"Floor",Vector3.new(rect[3]-rect[1],thickness,rect[4]-rect[2]),
			frame*CFrame.new((rect[1]+rect[3])/2,y,(rect[2]+rect[4])/2),entry)
		if original then
			floor.Transparency=original.Transparency
			floor.CanCollide,floor.CanQuery,floor.CanTouch=original.CanCollide,original.CanQuery,original.CanTouch
		end
	end
end
local function drawStairs(parent,frame,entry,floor)
	local width,depth=entry.X2-entry.X1,entry.Z2-entry.Z1
	local alongX=entry.Style=="East" or entry.Style=="West"
	local run=if alongX then width else depth
	local tread=run/16
	for step=1,16 do
		local x,z=(entry.X1+entry.X2)/2,(entry.Z1+entry.Z2)/2
		local offset=(step-0.5)*tread
		if entry.Style=="East" then x=entry.X1+offset
		elseif entry.Style=="West" then x=entry.X2-offset
		elseif entry.Style=="South" then z=entry.Z1+offset
		else z=entry.Z2-offset end
		local height=(Catalog.LEVEL_HEIGHT+0.13)*step/16
		part(parent,"StairStep",Vector3.new(if alongX then tread else width,height,if alongX then depth else tread),
			frame*CFrame.new(x,floor+height/2,z),entry)
	end
end
local function drawPiece(parent,frame,entry,pieces,builtins,site)
	local level=(entry.Level or 0)*Catalog.LEVEL_HEIGHT
	local floor=(if site=="Company" then 0 else 0.16)+level
	if entry.Kind=="Wall" then
		local host=table.clone(entry)
		host.BaseY=floor
		local openings={}
		for _,other in pieces do if other.HostId==entry.Id then table.insert(openings,other) end end
		drawWall(parent,frame,host,openings)
	elseif entry.Kind=="Stairs" then
		drawStairs(parent,frame,entry,floor)
	elseif entry.HostId then
		local host=Catalog.host(pieces,builtins,entry.HostId)
		if host then
			host=table.clone(host)
			host.BaseY=host.BaseY or (if site=="Company" then 0 else 0.16)+(host.Level or 0)*Catalog.LEVEL_HEIGHT
			drawOpening(parent,frame,entry,host)
		end
	else
		local width,depth=entry.X2-entry.X1,entry.Z2-entry.Z1
		local x,z=(entry.X1+entry.X2)/2,(entry.Z1+entry.Z2)/2
		if entry.Kind=="Floor" then
			-- New finishes sit just above the original floor, avoiding coplanar flicker.
			drawFloor(parent,frame,entry,pieces,floor+0.07,0.12)
		else
			local eave=floor+Catalog.WALL_HEIGHT+0.15
			if entry.Style=="Flat" then
				part(parent,"FlatRoof",Vector3.new(width,0.3,depth),frame*CFrame.new(x,eave,z),entry)
			elseif entry.Style=="Shed" then
				local rise=math.min(5,depth*0.24)
				local pitch=math.atan2(rise,depth)
				part(parent,"ShedRoof",Vector3.new(width+0.4,0.3,math.sqrt(depth^2+rise^2)+0.4),frame*CFrame.new(x,eave+rise/2,z)*CFrame.Angles(pitch,0,0),entry)
			else
				local rise=math.min(6,width*0.24)
				local half=width/2
				local pitch=math.atan2(rise,half)
				for _,side in {-1,1} do
					part(parent,"RoofSlope",Vector3.new(math.sqrt(half^2+rise^2)+0.3,0.3,depth+0.4),frame*CFrame.new(x+side*width/4,eave+rise/2,z)*CFrame.Angles(0,0,-side*pitch),entry)
				end
				part(parent,"RidgeCap",Vector3.new(0.3,0.3,depth+0.5),frame*CFrame.new(x,eave+rise,z),entry)
				-- Thin stacked strips close both triangular gable ends.
				for _,side in {-1,1} do
					for row=0,11 do
						local fraction=(row+0.5)/12
						part(parent,"RoofGable",Vector3.new(width*(1-fraction),rise/12+0.02,0.24),
							frame*CFrame.new(x,eave+rise*fraction,z+side*depth/2),entry)
					end
				end
			end
		end
	end
end
function Renderer.sync(model,frame,site,data)
	local builtins=Renderer.capture(model,frame,site)
	local folder=model:FindFirstChild("BuildingPieces")
	if folder then folder:Destroy() end
	folder=Instance.new("Folder")
	folder.Name="BuildingPieces"
	-- Populate off-tree so viewers never see half of a reconstructed wall.
	for id,record in captures[model] do
		local original=record.Part
		local edit=data.Overrides[id] or {}
		original.Color=if edit.Color then color(edit.Color) else record.Color
		original.Material=if edit.Material then Enum.Material[edit.Material] else record.Material
		original.Transparency=record.Transparency
		original.CanCollide,original.CanQuery,original.CanTouch=record.CanCollide,record.CanQuery,record.CanTouch
		local openings={}
		if not edit.Removed and record.Descriptor.Kind=="Wall" then
			for _,entry in data.Pieces do if entry.HostId==id then table.insert(openings,entry) end end
		end
		local floorCut=false
		if record.Descriptor.Kind=="Floor" then
			local rectangles
			rectangles,floorCut=floorRectangles(record.Descriptor,data.Pieces)
		end
		local hidden=edit.Removed or #openings>0 or floorCut
		original:SetAttribute("BuildingRemoved",hidden==true)
		if hidden then
			original.Transparency=1
			original.CanCollide,original.CanQuery,original.CanTouch=false,false,false
		end
		if #openings>0 then
			local wall=table.clone(record.Descriptor)
			wall.Material=edit.Material or wall.Material
			wall.Color=edit.Color or wall.Color
			drawWall(folder,frame,wall,openings)
		end
		if floorCut and not edit.Removed then
			local floor=table.clone(record.Descriptor)
			floor.Material=edit.Material or floor.Material
			floor.Color=edit.Color or floor.Color
			drawFloor(folder,frame,floor,data.Pieces,floor.BaseY+floor.Height/2,floor.Height,record)
		end
	end
	for _,entry in data.Pieces do
		if entry.HostId and data.Overrides[entry.HostId] and data.Overrides[entry.HostId].Removed then continue end
		drawPiece(folder,frame,entry,data.Pieces,builtins,site)
	end
	folder.Parent=model
end
function Renderer.preview(parent,frame,entry,pieces,builtins,valid,site)
	local model=Instance.new("Model")
	model.Name="StructurePreview"
	local clean=Catalog.normalize(entry)
	if not clean then model.Parent=parent return model end
	clean.Id=clean.Id or "preview"
	drawPiece(model,frame,clean,pieces or {},builtins or {},site)
	for _,piece in model:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.Color=if valid then Color3.fromRGB(193,153,235) else Color3.fromRGB(239,87,94)
			piece.Material=Enum.Material.SmoothPlastic
			piece.Transparency=0.5
			piece.CanCollide,piece.CanQuery,piece.CanTouch=false,false,false
			piece.CastShadow=false
		end
	end
	model.Parent=parent
	return model
end
return Renderer
