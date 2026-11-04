-- Shared geometry for authoritative construction and the client's placement ghost.
-- Original shells stay in place so upgrades and functional room references survive.
local Catalog = require(script.Parent.BuildingCatalog)
local Renderer = {}
local captures = setmetatable({}, {__mode="k"})
local layouts = setmetatable({}, {__mode="k"})
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
		if opening.Kind=="Window" and (opening.Style=="Round" or opening.Style=="Arched") then
			local baseWidth,baseBottom,baseTop=Catalog.baseOpening(opening)
			local radius=baseWidth/2
			local middle=(baseBottom+baseTop)/2
			local spring=baseTop-radius-middle
			local r=(opening.R or 0)%4
			for row=0,23 do
				local y1=bottom+(top-bottom)*row/24
				local y2=bottom+(top-bottom)*(row+1)/24
				local y=(y1+y2)/2-middle
				local low,high=-radius,radius
				if opening.Style=="Round" then
					local reach=math.sqrt(math.max(0,radius^2-y^2));low,high=-reach,reach
				elseif r%2==0 then
					local originalY=if r==0 then y else -y
					if originalY>spring then
						local reach=math.sqrt(math.max(0,radius^2-(originalY-spring)^2));low,high=-reach,reach
					end
				else
					local cap=spring+math.sqrt(math.max(0,radius^2-y^2))
					local base=baseBottom-middle
					low,high=if r==1 then -cap else base,if r==1 then -base else cap
				end
				slab(left,opening.Offset+low,y1,y2)
				slab(opening.Offset+high,right,y1,y2)
			end
		end
		cursor=right
	end
	slab(cursor,length,0,height)
end
local function drawOpening(parent,frame,entry,host)
	if not host then return end
	local cf=hostFrame(frame,host)
	if entry.Kind=="Window" and (entry.R or 0)~=0 then
		local upright=table.clone(entry)
		upright.R=0
		local group=Instance.new("Model")
		group.Name="RotatedWindow"
		drawOpening(group,frame,upright,host)
		local _,bottom,top=Catalog.baseOpening(entry)
		local pivot=cf*CFrame.new(entry.Offset,(bottom+top)/2,0)
		for _,piece in group:GetDescendants() do
			if piece:IsA("BasePart") then piece.CFrame=pivot*CFrame.Angles(0,0,entry.R*math.pi/2)*pivot:ToObjectSpace(piece.CFrame) end
		end
		group.Parent=parent
		return
	end
	local width,bottom,top=Catalog.opening(entry)
	local t=math.max(0.6,host.Thickness or 0.45)
	local function piece(name,size,x,y,z,rotation)
		return part(parent,name,size,cf*CFrame.new(entry.Offset+x,y,z or 0)*(rotation or CFrame.identity),entry)
	end
	local trim=0.14
	local function glass(size,x,y,rotation)
		local pane=piece("Glass",size,x,y,0,rotation)
		pane.Material=Enum.Material.Glass
		pane.Color=Color3.fromRGB(163,205,215)
		pane.Transparency,pane.Reflectance,pane.CanCollide=0.6,0.1,false
		pane:SetAttribute("BuildingFixedFinish",true)
		return pane
	end
	local function arc(centerY,radius,startAngle,endAngle,count)
		for index=0,count-1 do
			local a=startAngle+(endAngle-startAngle)*index/count
			local b=startAngle+(endAngle-startAngle)*(index+1)/count
			local mid=(a+b)/2
			piece("CurvedFrame",Vector3.new(2*radius*math.sin((b-a)/2)+0.04,trim,t),radius*math.cos(mid),centerY+radius*math.sin(mid),0,CFrame.Angles(0,0,mid+math.pi/2))
		end
	end
	if entry.Kind=="Window" and entry.Style=="Round" then
		local mid=(bottom+top)/2
		arc(mid,width/2-trim/2,0,math.pi*2,32)
		local pane=glass(Vector3.new(0.1,width-trim*2,width-trim*2),0,mid,CFrame.Angles(0,math.pi/2,0))
		pane.Shape=Enum.PartType.Cylinder
		piece("Mullion",Vector3.new(0.1,top-bottom-trim,0.2),0,mid)
		piece("Rail",Vector3.new(width-trim,0.1,0.2),0,mid)
		return
	end
	local spring=if entry.Style=="Arched" then top-width/2 else top
	for _,side in {-1,1} do
		piece("Frame",Vector3.new(trim,spring-bottom+trim,t),side*(width-trim)/2,(bottom+spring)/2)
	end
	if entry.Style=="Arched" then
		arc(spring,width/2-trim/2,0,math.pi,24)
		for row=0,15 do
			local radius=width/2-trim
			local y=radius*(row+0.5)/16
			local reach=math.sqrt(math.max(0,radius^2-y^2))
			glass(Vector3.new(math.max(0.05,reach*2),radius/16+0.01,0.1),0,spring+y)
		end
	else piece("Header",Vector3.new(width,trim,t),0,top-trim/2) end
	if entry.Kind=="Window" then
		piece("Sill",Vector3.new(width+0.2,trim,t+0.15),0,bottom+trim/2)
		glass(Vector3.new(width-trim*2,spring-bottom-trim*2,0.1),0,(bottom+spring)/2)
		if entry.Style=="Classic" or entry.Style=="Arched" or entry.Style=="Wide" then
			piece("Mullion",Vector3.new(0.1,top-bottom,0.2),0,(bottom+top)/2)
			piece("Rail",Vector3.new(width,0.1,0.2),0,(bottom+top)/2)
		end
	elseif entry.Style=="Panel" or entry.Style=="Double" then
		-- The panel is held open, leaving a walkable 3.2-stud opening without scripts.
		local facing=if (entry.R or 0)%2==0 then 1 else -1
		local hinge=if (entry.R or 0)<2 then -1 else 1
		local panelWidth=if entry.Style=="Double" then width/2-0.2 else width-0.3
		for _,side in if entry.Style=="Double" then {-1,1} else {hinge} do
			local panel=piece("OpenDoor",Vector3.new(0.18,top-0.2,panelWidth),side*width/2,top/2,facing*panelWidth/2)
			panel.CanCollide=false
			local handle=piece("Handle",Vector3.new(0.12,0.16,0.35),side*width/2-side*0.15,4,facing*(panelWidth-0.4))
			handle.Material=Enum.Material.Metal
			handle:SetAttribute("BuildingFixedFinish",true)
		end
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
		local r=entry.R or 0
		local width,depth=rect[3]-rect[1],rect[4]-rect[2]
		local floor=part(parent,"Floor",Vector3.new(if r%2==0 then width else depth,thickness,if r%2==0 then depth else width),
			frame*CFrame.new((rect[1]+rect[3])/2,y,(rect[2]+rect[4])/2)*CFrame.Angles(0,r*math.pi/2,0),entry)
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
			local rotation=entry.R or 0
			if rotation~=0 then
				frame=frame*CFrame.new(x,0,z)*CFrame.Angles(0,rotation*math.pi/2,0)*CFrame.new(-x,0,-z)
				if rotation%2==1 then width,depth=depth,width end
			end
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
local function layoutKey(data,builtins)
	local rows={}
	for id in builtins do table.insert(rows,"b:"..id) end
	for id,edit in data.Overrides do if edit.Removed then table.insert(rows,"removed:"..id) end end
	for _,entry in data.Pieces do
		local fields={}
		for _,key in {"Id","Kind","X1","Z1","X2","Z2","Level","Style","R","HostId","Offset"} do table.insert(fields,tostring(entry[key])) end
		table.insert(rows,table.concat(fields,"|"))
	end
	table.sort(rows)
	return table.concat(rows,"\n")
end
function Renderer.paint(model,data)
	local finishes={}
	for _,entry in data.Pieces do finishes[entry.Id]=entry end
	for id,record in captures[model] or {} do
		local edit=data.Overrides[id] or {}
		finishes[id]={Material=edit.Material or record.Descriptor.Material,Color=edit.Color or record.Descriptor.Color}
	end
	for _,piece in model:GetDescendants() do
		if not piece:IsA("BasePart") or piece:GetAttribute("BuildingFixedFinish") then continue end
		local finish=finishes[piece:GetAttribute("BuildingId")]
		if finish then piece.Color=color(finish.Color);piece.Material=Enum.Material[finish.Material] end
	end
end
function Renderer.sync(model,frame,site,data)
	local builtins=Renderer.capture(model,frame,site)
	local folder=model:FindFirstChild("BuildingPieces")
	local key=layoutKey(data,builtins)
	local previous=layouts[model]
	if previous and previous.Key==key and previous.Frame==frame and previous.Folder==folder and folder then
		Renderer.paint(model,data)
		return
	end
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
	layouts[model]={Key=key,Frame=frame,Folder=folder}
end
function Renderer.preview(parent,frame,entry,pieces,builtins,valid,site)
	local model=Instance.new("Model")
	model.Name="StructurePreview"
	local clean=Catalog.normalize(entry)
	if not clean then model.Parent=parent return model end
	clean.Id=clean.Id or "preview"
	local shape=Instance.new("Model")
	shape.Name="PlacementShape"
	drawPiece(shape,frame,clean,pieces or {},builtins or {},site)
	shape.Parent=model
	if clean.HostId then
		local host=Catalog.host(pieces or {},builtins or {},clean.HostId)
		if host then
			host=table.clone(host)
			host.BaseY=host.BaseY or (if site=="Company" then 0 else 0.16)+(host.Level or 0)*Catalog.LEVEL_HEIGHT
			local walls=Instance.new("Model")
			walls.Name="PreviewWallOpening"
			drawWall(walls,frame,host,{clean})
			for _,wall in walls:GetDescendants() do if wall:IsA("BasePart") then wall:SetAttribute("BuildingPreviewHost",true) end end
			walls.Parent=model
		end
	end
	for _,piece in model:GetDescendants() do
		if piece:IsA("BasePart") then
			if not piece:GetAttribute("BuildingPreviewHost") then
				if not valid then piece.Color=Color3.fromRGB(239,87,94) end
				piece.Transparency=math.max(piece.Transparency,0.35)
			end
			piece.CanCollide,piece.CanQuery,piece.CanTouch=false,false,false
			piece.CastShadow=false
		end
	end
	local outline=Instance.new("Highlight")
	outline.Name="PlacementOutline"
	outline.Adornee=shape
	outline.FillTransparency=1
	outline.OutlineColor=if valid then Color3.fromRGB(193,153,235) else Color3.fromRGB(239,87,94)
	outline.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
	outline.Parent=model
	model.Parent=parent
	return model
end
function Renderer.thumbnail(view,raw)
	if not view.Parent then return end
	local old=view:FindFirstChild("BuildingThumbnail")
	if old then old:Destroy() end
	local entry=table.clone(raw)
	entry.Level,entry.R,entry.Id=0,0,"thumbnail"
	entry.X1,entry.Z1,entry.X2,entry.Z2=-4.5,-3,4.5,3
	if entry.Kind=="Room" then entry.Kind,entry.Style="Wall","Solid" end
	if entry.Kind=="Wall" then entry.Z1,entry.Z2=0,0 end
	local hosts={}
	if entry.Kind=="Window" or entry.Kind=="Door" then
		entry.HostId,entry.Offset="thumbnail-wall",9
		hosts[entry.HostId]={Id=entry.HostId,Kind="Wall",X1=-9,Z1=0,X2=9,Z2=0,Level=0,Height=Catalog.WALL_HEIGHT,Thickness=0.45}
	end
	local clean=Catalog.normalize(entry)
	if not clean then return end
	local world=Instance.new("WorldModel")
	world.Name="BuildingThumbnail"
	world.Parent=view
	local model=Instance.new("Model")
	drawPiece(model,CFrame.identity,clean,{},hosts,nil)
	model.Parent=world
	local box,size=model:GetBoundingBox()
	local camera=Instance.new("Camera")
	camera.FieldOfView=32
	camera.Parent=world
	view.CurrentCamera=camera
	view.Ambient=Color3.fromRGB(200,200,210)
	view.LightColor=Color3.fromRGB(255,245,230)
	view.LightDirection=Vector3.new(-1,-2,-3)
	local function fit()
		local aspect=math.max(0.2,view.AbsoluteSize.X/math.max(1,view.AbsoluteSize.Y))
		local fov=math.atan(math.tan(math.rad(16))*math.min(1,aspect))
		local distance=math.max(1,size.Magnitude/2)/math.sin(fov)*1.06
		local direction=if clean.HostId then Vector3.new(0.25,0.12,1).Unit else Vector3.new(1,0.7,1).Unit
		camera.CFrame=CFrame.lookAt(box.Position+direction*distance,box.Position)
	end
	view:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
end
return Renderer
