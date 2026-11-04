-- Pure, shared construction rules. All saved values are numbers/strings/tables.
local Building = {}
Building.GRID = 4.5
Building.WALL_HEIGHT = 11.5
Building.LEVEL_HEIGHT = 12
Building.MAX_LEVEL = 3
Building.MAX_PIECES = 350
Building.MAX_OVERRIDES = 600
-- Drawing and snapping use the same visible plane and lattice everywhere.
Building.GRID_PLANE_OFFSET = 0.16
function Building.gridOffset(site)
	return if site == "Company" then 0 else Building.GRID / 2
end
function Building.snap(value, size, site)
	local offset = Building.gridOffset(site)
	return math.round((value - offset) / size) * size + offset
end
function Building.planeHeight(site, level)
	return (if site == "Company" then 0 else 0.16) + level * Building.LEVEL_HEIGHT + Building.GRID_PLANE_OFFSET
end
Building.Materials = { "Plaster", "Brick", "WoodPlanks", "Wood", "Concrete", "Slate", "Marble", "CeramicTiles", "Cobblestone", "Metal", "RoofShingles", "SmoothPlastic", "Glass" }
Building.Colors = {
	{Name="Ivory",Color={235,229,211}}, {Name="White",Color={246,246,242}},
	{Name="Sand",Color={196,172,137}}, {Name="Clay",Color={166,82,59}},
	{Name="Oak",Color={128,88,54}}, {Name="Walnut",Color={69,47,38}},
	{Name="Charcoal",Color={43,47,53}}, {Name="Stone",Color={135,142,146}},
	{Name="Sage",Color={118,145,119}}, {Name="Seafoam",Color={137,192,180}},
	{Name="Ocean",Color={55,108,146}}, {Name="Navy",Color={42,58,83}},
	{Name="Rose",Color={195,133,139}}, {Name="Lilac",Color={153,132,180}},
	{Name="Gold",Color={213,176,82}}, {Name="Black",Color={24,25,29}},
}
Building.Bounds = {
	Home = { {-24.75,-33.75,24.75,15.75}, {-24.75,65.25,24.75,83.25} },
	Company = { {-54,-31.5,54,31.5} },
}
-- Catalogues show actual shapes; R controls orientation independently of style.
Building.Variants = {
	Wall = {{Id="Solid",Name="Wall",Style="Solid",Price=12}},
	Room = {{Id="Room",Name="Room",Style="Solid",Price=54}},
	Floor = {{Id="Tile",Name="Floor tile",Style="Tile",Price=6}},
	Roof = {{Id="Gable",Name="Gable roof",Style="Gable",Price=10},{Id="Flat",Name="Flat roof",Style="Flat",Price=10},{Id="Shed",Name="Sloped roof",Style="Shed",Price=10}},
	Window = {
		{Id="Classic",Name="Classic window",Style="Classic",Price=45}, {Id="Picture",Name="Picture window",Style="Picture",Price=50},
		{Id="Tall",Name="Tall window",Style="Tall",Price=65}, {Id="Wide",Name="Wide window",Style="Wide",Price=80},
		{Id="Arched",Name="Arched window",Style="Arched",Price=85}, {Id="Round",Name="Round window",Style="Round",Price=75},
	},
	Door = {{Id="Open",Name="Open doorway",Style="Open",Price=60},{Id="Panel",Name="Timber door",Style="Panel",Price=75},{Id="Double",Name="Double doorway",Style="Double",Price=100}},
}
local kinds = {Wall=true,Floor=true,Roof=true,Window=true,Door=true,Stairs=true}
local styles = {Wall={Solid=true},Floor={Tile=true},Roof={Flat=true,Gable=true,Shed=true},Window={Picture=true,Classic=true,Tall=true,Wide=true,Arched=true,Round=true},Door={Open=true,Panel=true,Double=true},Stairs={North=true,East=true,South=true,West=true}}
local defaultStyles = {Wall="Solid",Floor="Tile",Roof="Gable",Window="Classic",Door="Open",Stairs="North"}
local defaults = {Wall="Plaster",Floor="WoodPlanks",Roof="RoofShingles",Window="Wood",Door="Wood",Stairs="WoodPlanks"}
local function finite(n)
	return type(n)=="number" and n==n and math.abs(n)<10000
end
function Building.color(raw)
	if type(raw)~="table" then return nil end
	local result={}
	for i=1,3 do
		local n=raw[i]
		if not finite(n) or n<0 or n>255 or n%1~=0 then return nil end
		result[i]=n
	end
	return result
end
function Building.id(id)
	return type(id)=="string" and #id>0 and #id<=220 and id:match("^[%w_:%.%-%/]+$")~=nil
end
function Building.normalize(raw)
	if type(raw)~="table" or not kinds[raw.Kind] then return nil,"Choose a building piece." end
	local kind=raw.Kind
	local material=raw.Material or defaults[kind]
	if not table.find(Building.Materials,material) then return nil,"Choose a material from the palette." end
	local color=Building.color(raw.Color or Building.Colors[1].Color)
	if not color then return nil,"Choose a valid RGB color (0–255)." end
	local level=raw.Level or 0
	if not finite(level) or level%1~=0 or level<0 or level>Building.MAX_LEVEL then return nil,"Choose a floor from 1 to 4." end
	local clean={Kind=kind,Material=material,Color=color,Level=level}
	local rotation=raw.R or 0
	if not finite(rotation) or rotation%1~=0 or rotation<0 or rotation>3 then return nil,"Rotation must be a quarter turn." end
	clean.R=rotation
	if raw.Id~=nil then
		if not Building.id(raw.Id) then return nil,"Invalid piece ID." end
		clean.Id=raw.Id
	end
	if styles[kind] then
		local style=raw.Style or defaultStyles[kind]
		if not styles[kind][style] then return nil,"Choose a valid style." end
		clean.Style=style
	end
	if kind=="Window" or kind=="Door" then
		if not Building.id(raw.HostId) or not finite(raw.Offset) or math.abs(raw.Offset)>150 then return nil,"Place this on a wall." end
		clean.HostId,clean.Offset=raw.HostId,math.round(raw.Offset*1000)/1000
	else
		for _,key in {"X1","Z1","X2","Z2"} do
			if not finite(raw[key]) or math.abs(raw[key])>150 then return nil,"Keep construction inside your plot." end
			clean[key]=math.round(raw[key]*1000)/1000
		end
		if kind=="Wall" then
			if math.abs(clean.X1-clean.X2)>0.01 and math.abs(clean.Z1-clean.Z2)>0.01 then return nil,"Walls follow horizontal or vertical grid lines." end
			if clean.X1>clean.X2 or clean.Z1>clean.Z2 then clean.X1,clean.X2,clean.Z1,clean.Z2=clean.X2,clean.X1,clean.Z2,clean.Z1 end
		else
			clean.X1,clean.X2=math.min(clean.X1,clean.X2),math.max(clean.X1,clean.X2)
			clean.Z1,clean.Z2=math.min(clean.Z1,clean.Z2),math.max(clean.Z1,clean.Z2)
		end
	end
	return clean,nil
end
function Building.host(pieces,builtins,id)
	if builtins and builtins[id] then return builtins[id] end
	for _,entry in pieces or {} do if entry.Id==id then return entry end end
	return nil
end
function Building.length(entry)
	return math.sqrt((entry.X2-entry.X1)^2+(entry.Z2-entry.Z1)^2)
end
function Building.baseOpening(entry)
	if entry.Kind=="Window" then
		if entry.Style=="Tall" then return 3.5,1.5,9.5 end
		if entry.Style=="Wide" then return 7.5,3,8.5 end
		if entry.Style=="Arched" then return 3.5,2,9 end
		if entry.Style=="Round" then return 3.5,3,6.5 end
	elseif entry.Style=="Double" then return 7.5,0,8.8 end
	return 3.5, (if entry.Kind=="Door" then 0 else 3), (if entry.Kind=="Door" then 8.8 else 8.5)
end
function Building.opening(entry)
	local width,bottom,top=Building.baseOpening(entry)
	if entry.Kind=="Window" and (entry.R or 0)%2==1 then
		local middle=(bottom+top)/2
		return top-bottom,middle-width/2,middle+width/2
	end
	return width,bottom,top
end
local function areaOverlap(a,b)
	return math.min(a.X2,b.X2)>math.max(a.X1,b.X1)+0.02 and math.min(a.Z2,b.Z2)>math.max(a.Z1,b.Z1)+0.02
end
local function wallArea(wall)
	local reach=(wall.Thickness or 0.45)/2
	return {X1=math.min(wall.X1,wall.X2)-reach,Z1=math.min(wall.Z1,wall.Z2)-reach,
		X2=math.max(wall.X1,wall.X2)+reach,Z2=math.max(wall.Z1,wall.Z2)+reach}
end
local function stairConflict(stair,other)
	local level=stair.Level or 0
	if other.Kind=="Wall" and ((other.Level or 0)==level or (other.Level or 0)==level+1) then
		return areaOverlap(stair,wallArea(other))
	elseif other.Kind=="Roof" and (other.Level or 0)==level then
		return areaOverlap(stair,other)
	elseif other.Kind=="Stairs" and math.abs((other.Level or 0)-level)<=1 then
		return areaOverlap(stair,other)
	end
	return false
end
function Building.check(pieces,entry,site,builtins,skipId)
	local clean,reason=Building.normalize(entry)
	if not clean then return reason end
	entry=clean
	if #pieces>=Building.MAX_PIECES and not skipId then return "Your plot has reached its building limit." end
	if entry.HostId then
		local host=Building.host(pieces,builtins,entry.HostId)
		if not host or host.Kind~="Wall" then return "Place doors and windows on a wall." end
		local width,bottom,top=Building.opening(entry)
		if entry.Offset-width/2<0.2 or entry.Offset+width/2>Building.length(host)-0.2 then return "Leave room for a post at each end of the wall." end
		if (host.Height or Building.WALL_HEIGHT)<top then return "This wall section is too low for that opening." end
		if host.BaseY and host.BaseY>0.3+(host.Level or 0)*Building.LEVEL_HEIGHT+bottom then return "Place this opening on a complete wall section." end
		for _,other in pieces do
			if other.Id~=skipId and other.HostId==entry.HostId then
				local w,b,t=Building.opening(other)
				if math.abs(other.Offset-entry.Offset)<(w+width)/2+0.15 and bottom<t and top>b then return "There is already an opening here." end
			end
		end
		return nil
	end
	local dx,dz=entry.X2-entry.X1,entry.Z2-entry.Z1
	if entry.Kind=="Wall" then
		if Building.length(entry)<1.125 then return "Draw at least one grid segment." end
	elseif entry.Kind=="Stairs" then
		if entry.Level>=Building.MAX_LEVEL then return "Stairs must start below the fourth floor." end
		local alongX=entry.Style=="East" or entry.Style=="West"
		local width,run=if alongX then dz else dx,if alongX then dx else dz
		if width<3.5 or run<8 then return "Stairs need at least 3.5 studs of width and 8 studs of run in their climb direction." end
	elseif dx<1.125 or dz<1.125 then return "Draw an area at least one grid square wide." end
	local inside=false
	for _,area in Building.Bounds[site or "Home"] or {} do
		if entry.X1>=area[1]-0.01 and entry.Z1>=area[2]-0.01 and entry.X2<=area[3]+0.01 and entry.Z2<=area[4]+0.01 then inside=true break end
	end
	if not inside then return "Keep the whole piece on your house, yard, shop, or company plot. Roads stay clear." end
	if site=="Company" and (entry.Kind=="Wall" or entry.Kind=="Stairs") and entry.Level==0 then
		if entry.Z1<=-27 and entry.X1<4.5 and entry.X2>-4.5 then return "Keep the company plot entrance clear." end
	end
	for _,collection in {pieces,builtins or {}} do
		for _,other in collection do
			if other.Id==skipId or other.HostId then continue end
			if (entry.Kind=="Stairs" and stairConflict(entry,other)) or (other.Kind=="Stairs" and stairConflict(other,entry)) then
				return "Keep the staircase clear through both floors. Move walls or remove the roof above it."
			end
		end
	end
	if entry.Kind=="Wall" then
		for _,other in builtins or {} do
			if other.Kind~="Wall" or other.Level~=entry.Level then continue end
			local xLine=math.abs(dx)<0.01 and math.abs(other.X2-other.X1)<0.01 and math.abs(entry.X1-other.X1)<0.05
			local zLine=math.abs(dz)<0.01 and math.abs(other.Z2-other.Z1)<0.01 and math.abs(entry.Z1-other.Z1)<0.05
			if (xLine and math.min(entry.Z2,other.Z2)>math.max(entry.Z1,other.Z1)+0.05)
				or (zLine and math.min(entry.X2,other.X2)>math.max(entry.X1,other.X1)+0.05) then return "An existing wall covers this line. Paint it or remove it first." end
		end
	end
	for _,other in pieces do
		if other.Id==skipId or other.HostId or other.Kind~=entry.Kind or other.Level~=entry.Level then continue end
		if entry.Kind=="Wall" then
			local xLine=math.abs(dx)<0.01 and math.abs(other.X2-other.X1)<0.01 and math.abs(entry.X1-other.X1)<0.05
			local zLine=math.abs(dz)<0.01 and math.abs(other.Z2-other.Z1)<0.01 and math.abs(entry.Z1-other.Z1)<0.05
			if (xLine and math.min(entry.Z2,other.Z2)>math.max(entry.Z1,other.Z1)+0.05)
				or (zLine and math.min(entry.X2,other.X2)>math.max(entry.X1,other.X1)+0.05) then return "A wall already covers this line." end
		elseif math.min(entry.X2,other.X2)>math.max(entry.X1,other.X1)+0.05 and math.min(entry.Z2,other.Z2)>math.max(entry.Z1,other.Z1)+0.05 then
			return "These building areas overlap. Paint or remove the existing piece first."
		end
	end
	return nil
end
function Building.price(entry)
	if entry.Kind=="Window" or entry.Kind=="Door" then
		for _,variant in Building.Variants[entry.Kind] do if variant.Style==entry.Style then return variant.Price end end
		return if entry.Kind=="Window" then 45 else 60
	end
	local units=if entry.Kind=="Wall" then Building.length(entry)/Building.GRID else math.abs((entry.X2-entry.X1)*(entry.Z2-entry.Z1))/(Building.GRID^2)
	return math.max(1,math.ceil(units*(if entry.Kind=="Wall" then 12 elseif entry.Kind=="Roof" then 10 elseif entry.Kind=="Stairs" then 20 else 6)))
end
function Building.decode(raw)
	local result={}
	for _,site in {"Home","Company"} do
		local source=if type(raw)=="table" and type(raw[site])=="table" then raw[site] else {}
		local data={NextId=1,Pieces={},Overrides={}}
		local seen={}
		if type(source.Pieces)=="table" then
			for _,entry in source.Pieces do
				if #data.Pieces>=Building.MAX_PIECES then break end
				local clean=Building.normalize(entry)
				local serial=clean and clean.Id and tonumber(clean.Id:sub(2))
				if clean and clean.Id and clean.Id:match("^p%d+$") and serial and serial<1000000000 and not seen[clean.Id] then
					seen[clean.Id]=true
					table.insert(data.Pieces,clean)
					data.NextId=math.max(data.NextId,(tonumber(clean.Id:sub(2)) or 0)+1)
				end
			end
		end
		if type(source.NextId)=="number" and source.NextId%1==0 and source.NextId>=data.NextId and source.NextId<1000000000 then data.NextId=source.NextId end
		local count=0
		if type(source.Overrides)=="table" then
			for id,edit in source.Overrides do
				if count>=Building.MAX_OVERRIDES then break end
				if not Building.id(id) or id:sub(1,2)~="b:" or type(edit)~="table" then continue end
				local patch={}
				if edit.Removed==true then patch.Removed=true end
				if table.find(Building.Materials,edit.Material) then patch.Material=edit.Material end
				patch.Color=Building.color(edit.Color)
				data.Overrides[id]=patch
				count+=1
			end
		end
		result[site]=data
	end
	return result
end
return Building
