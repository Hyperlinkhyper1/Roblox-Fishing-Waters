-- Production construction rules: run directly with `lute run scripts/building.luau`.
local Building = require('../src/shared/BuildingCatalog')
local checks = 0
local function check(condition, message)
	assert(condition, message)
	checks += 1
end
local function piece(kind, extra)
	local entry = {Kind=kind, X1=-9, Z1=-9, X2=9, Z2=9, Level=0, Material='Plaster', Color={200,170,140}}
	if kind == 'Wall' then entry.Z2 = -9 end
	for key, value in extra or {} do entry[key] = value end
	return entry
end
local function valid(entry, pieces, site, builtins, skip)
	return Building.check(pieces or {}, entry, site, builtins or {}, skip) == nil
end

-- Remote data must remain finite and use approved kinds, materials, styles, and RGB values.
for _, kind in {'Wall','Floor','Roof'} do
	local raw = piece(kind)
	local clean = assert(Building.normalize(raw))
	check(valid(clean), kind .. ' must fit in the home')
	check(valid(clean, {}, 'Company'), kind .. ' must fit on a company plot')
	check(Building.price(clean) > 0 and Building.price(clean) % 1 == 0, kind .. ' price must be a positive whole amount')
	check(clean.Color ~= raw.Color, 'Normalization must copy color values')
end
for _, value in {0/0, math.huge, -math.huge, 1000000, '9'} do
	check(Building.normalize(piece('Wall', {X1=value})) == nil, 'Invalid coordinate reached construction')
	check(Building.normalize(piece('Wall', {Level=value})) == nil, 'Invalid floor reached construction')
end
for _, level in {-1, 0.5, Building.MAX_LEVEL+1} do
	check(Building.normalize(piece('Floor', {Level=level})) == nil, 'Invalid level accepted')
end
for _, color in {{-1,0,0}, {0,256,0}, {1.5,2,3}, {1,2}, {0/0,1,2}, 'red'} do
	check(Building.normalize(piece('Wall', {Color=color})) == nil, 'Invalid RGB accepted')
end
check(Building.normalize(piece('Wall', {Material='UntrustedMaterial'})) == nil, 'Material whitelist bypassed')
check(Building.normalize(piece('MeshPart')) == nil, 'Unknown construction kind accepted')
check(Building.normalize(piece('Roof', {Style='UntrustedStyle'})) == nil, 'Unknown roof style accepted')
for _, id in {'', string.rep('x', 221), 'bad id', '../unsafe?'} do
	check(Building.normalize(piece('Wall', {Id=id})) == nil, 'Malformed ID accepted')
end
local stripped = assert(Building.normalize(piece('Wall', {Price=-500, OwnerUserId=42, CanCollide=false})))
check(stripped.Price == nil and stripped.OwnerUserId == nil and stripped.CanCollide == nil, 'Client properties must not enter saved pieces')

-- Whole pieces stay on one owned plot; crossing the road is never valid.
check(not valid(piece('Wall', {X1=0,Z1=0,X2=0,Z2=72})), 'Road-crossing wall accepted')
check(not valid(piece('Floor', {X1=-9,Z1=0,X2=9,Z2=72})), 'Road-crossing floor accepted')
check(not valid(piece('Roof', {X1=-9,Z1=45,X2=9,Z2=54})), 'Roof over public road accepted')
check(not valid(piece('Wall', {X1=-90,X2=-81})), 'Construction outside home accepted')
check(not valid(piece('Wall', {X1=-90,X2=-81}), {}, 'Company'), 'Construction outside company plot accepted')
check(not valid(piece('Wall', {X1=-4.5,Z1=-31.5,X2=4.5,Z2=-31.5}), {}, 'Company'), 'Company entrance was blocked')
check(valid(piece('Floor', {X1=-9,Z1=67.5,X2=9,Z2=81})), 'Owner shop must remain buildable across the road')
check(Building.normalize(piece('Wall', {X1=0,Z1=0,X2=9,Z2=9})) == nil, 'Diagonal wall accepted')
check(not valid(piece('Wall', {X1=0,Z1=0,X2=0,Z2=0})), 'Empty wall accepted')
check(not valid(piece('Floor', {X1=0,X2=0})), 'Empty floor accepted')
local reversed = assert(Building.normalize(piece('Floor', {X1=9,Z1=9,X2=-9,Z2=-9})))
check(reversed.X1 == -9 and reversed.Z1 == -9 and reversed.X2 == 9 and reversed.Z2 == 9, 'Rectangle direction changed geometry')

-- Overlap checks reject duplicates while preserving adjacent rooms and independent levels.
local wall = assert(Building.normalize(piece('Wall', {Id='p1', X1=-9,Z1=0,X2=9,Z2=0})))
check(not valid(wall, {wall}), 'Duplicate wall accepted')
check(valid(wall, {wall}, nil, {}, 'p1'), 'Moving a wall must ignore its own prior position')
check(valid(piece('Wall', {X1=9,Z1=0,X2=18,Z2=0}), {wall}), 'Adjacent wall segments must share an end post')
check(valid(piece('Wall', {X1=-9,Z1=0,X2=9,Z2=0,Level=1}), {wall}), 'Upper floor wall conflicts with lower floor')
local floor = assert(Building.normalize(piece('Floor', {Id='p2'})))
check(not valid(piece('Floor'), {floor}), 'Duplicate floor accepted')
check(valid(piece('Floor', {X1=9,X2=18}), {floor}), 'Adjacent floor areas must meet')
check(valid(piece('Roof'), {floor}), 'A roof may cover a floor')
local full = {}
for index=1,Building.MAX_PIECES do table.insert(full, {Id='p'..index,Kind='Wall',X1=-9,Z1=0,X2=9,Z2=0,Level=1}) end
check(not valid(piece('Wall'), full), 'Per-plot construction limit bypassed')

-- Openings bind to a real wall, fit its width/height, and cannot overlap each other.
local window = {Kind='Window',HostId='p1',Offset=9,Style='Classic',Color={220,220,220}}
check(valid(window, {wall}), 'Window must fit in the middle of its host wall')
check(valid({Kind='Door',HostId='p1',Offset=9,Style='Open'}, {wall}), 'Door must fit in the middle of its host wall')
for _, offset in {-1,0,18,100} do
	check(not valid({Kind='Window',HostId='p1',Offset=offset}, {wall}), 'Opening exceeded wall ends')
end
check(not valid({Kind='Door',HostId='missing',Offset=9}, {wall}), 'Orphan door accepted')
check(not valid({Kind='Window',HostId='p2',Offset=9}, {floor}), 'Opening attached to a floor')
local existingWindow = assert(Building.normalize(window)); existingWindow.Id = 'p3'
check(not valid(window, {wall,existingWindow}), 'Overlapping windows accepted')
check(not valid({Kind='Door',HostId='p1',Offset=9}, {wall,existingWindow}), 'Overlapping door and window accepted')
check(valid(window, {wall,existingWindow}, nil, {}, 'p3'), 'Updating a window must ignore itself')
check(valid({Kind='Window',HostId='p1',Offset=4.5}, {wall,existingWindow}), 'Separate openings must fit on one wall')
local builtin = table.clone(wall); builtin.Id='b:Shell/Wall'; builtin.Height=Building.WALL_HEIGHT
check(valid({Kind='Window',HostId=builtin.Id,Offset=9}, {}, nil, {[builtin.Id]=builtin}), 'Existing base walls must accept real openings')
builtin.Height=5
check(not valid({Kind='Door',HostId=builtin.Id,Offset=9}, {}, nil, {[builtin.Id]=builtin}), 'Door exceeded existing wall height')

-- Save decoding preserves independent sites and stable IDs without aliasing source tables.
wall.Id='p8'
local source={Home={NextId=20,Pieces={wall,wall,piece('MeshPart')},Overrides={['b:Shell/Wall']={Material='Brick',Color={50,60,70},Removed=true}}},Company={Pieces={piece('Roof',{Id='p2'})}}}
local decoded=Building.decode(source)
check(#decoded.Home.Pieces == 1 and decoded.Home.Pieces[1].Id == 'p8', 'Decode lost a valid piece or duplicated its ID')
check(decoded.Home.NextId == 20 and decoded.Company.NextId >= 3, 'Decode must never reuse stable IDs')
check(#decoded.Company.Pieces == 1 and decoded.Company.Pieces[1].Kind == 'Roof', 'Home and company buildings mixed')
check(decoded.Home.Overrides['b:Shell/Wall'].Removed == true and decoded.Home.Overrides['b:Shell/Wall'].Material == 'Brick', 'Existing shell edits were lost')
decoded.Home.Pieces[1].Color[1]=0
check(source.Home.Pieces[1].Color[1] == 200, 'Decode mutated live profile data')
local empty=Building.decode(nil)
check(#empty.Home.Pieces == 0 and #empty.Company.Pieces == 0 and empty.Home.NextId == 1, 'Legacy profiles must start with an untouched shell')
local malicious=Building.decode({Home={Pieces={piece('Wall',{Id='bad id'}),piece('Wall',{Id='p1',Color={-1,0,0}})},Overrides={['p1']={Removed=true},['b:Shell/Wall']={Material='bad',Color={999,0,0}}}}})
check(#malicious.Home.Pieces == 0 and malicious.Home.Overrides.p1 == nil, 'Malformed saved data survived sanitation')
check(malicious.Home.Overrides['b:Shell/Wall'].Material == nil and malicious.Home.Overrides['b:Shell/Wall'].Color == nil, 'Invalid override appearance survived sanitation')
local overflow=Building.decode({Home={Pieces={piece('Wall',{Id='p999999999999999999999999999999999999999999999999999999999999'})}}})
check(#overflow.Home.Pieces==0 and overflow.Home.NextId==1,'Oversized stable IDs must not overflow future piece allocation')
local existingWall=table.clone(wall); existingWall.Id='b:Shell/Wall'; existingWall.BaseY=0; existingWall.Height=Building.WALL_HEIGHT
check(not valid(piece('Wall',{X1=-9,Z1=0,X2=9,Z2=0}),{},nil,{[existingWall.Id]=existingWall}),'New wall must not duplicate an untouched base wall')
existingWall.BaseY=5
check(not valid({Kind='Window',HostId=existingWall.Id,Offset=9},{},nil,{[existingWall.Id]=existingWall}),'Opening must not attach to a high wall lintel')
for _,direction in {'North','East','South','West'} do
	local stairs=piece('Stairs',{Id='p20',X1=-4.5,Z1=-4.5,X2=4.5,Z2=4.5,Style=direction})
	check(valid(stairs),direction..' staircase must fit on the home plot')
	check(Building.price(assert(Building.normalize(stairs)))==80,'Stairs price must use twenty dollars per grid square')
	check(not valid(piece('Stairs',{X1=-4.5,Z1=-4.5,X2=4.5,Z2=4.5,Style=direction,Level=Building.MAX_LEVEL})),'Staircase must not climb beyond the top construction level')
	check(not valid(stairs,{piece('Roof',{Id='p30'})}),'A roof over the staircase must be removed first')
	check(not valid(stairs,{piece('Wall',{Id='p31',X1=-9,Z1=0,X2=9,Z2=0,Level=1})}),'Upper walls must leave staircase headroom')
	check(valid(stairs,{piece('Floor',{Id='p32',Level=1})}),'Upper floors must accept automatic staircase openings')
	check(not valid(piece('Stairs',{X1=-4.5,Z1=-4.5,X2=4.5,Z2=4.5,Style=direction,Level=1}),{stairs}),'Stacked overlapping stairs must not block the lower landing')
end
check(not valid(piece('Stairs',{X1=0,Z1=0,X2=2.25,Z2=9,Style='North'})),'Staircase narrower than an avatar was accepted')
check(not valid(piece('Stairs',{X1=0,Z1=0,X2=4.5,Z2=4.5,Style='North'})),'Staircase without enough run was accepted')
check(Building.normalize(piece('Stairs',{Style='BadDirection'}))==nil,'Invalid staircase direction accepted')
print('Building rules: '..checks..' construction, ownership bounds, opening, and save checks passed.')
