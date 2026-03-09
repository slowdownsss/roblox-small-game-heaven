-- WorldBuilder
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Config = require(ReplicatedStorage:WaitForChild("SnakeGame"):WaitForChild("Config"))
local GameRegistry = require(ReplicatedStorage:WaitForChild("SGH"):WaitForChild("GameRegistry"))
local WorldBuilder = {}
local folder; local NEON=Enum.Material.Neon; local SMOOTH=Enum.Material.SmoothPlastic; local CONCRETE=Enum.Material.Concrete
local W=Config.WORLD_HALF

local function part(size,color,mat,pos)
	local p=Instance.new("Part"); p.Size=size; p.Color=color; p.Material=mat; p.Position=pos
	p.Anchored=true; p.CanCollide=true; p.CastShadow=false; p.Parent=folder; return p
end
local function ns(size,color,pos) -- neon strip
	local p=part(size,color,NEON,pos); p.CanCollide=false; return p
end
local function light(parent,color,range,brightness)
	local l=Instance.new("PointLight"); l.Color=color; l.Range=range or 20; l.Brightness=brightness or 2; l.Parent=parent; return l
end
local function prompt(parent,text,key,dist)
	local pp=Instance.new("ProximityPrompt"); pp.ObjectText=text; pp.ActionText="Enter"
	pp.KeyboardKeyCode=key or Enum.KeyCode.E; pp.MaxActivationDistance=dist or 10; pp.HoldDuration=0; pp.Parent=parent; return pp
end
local function buildGround()
	part(Vector3.new(W*2,1,W*2),Color3.fromRGB(18,18,30),SMOOTH,Vector3.new(0,-0.5,0))
	for _,z in {-100,0,100} do
		part(Vector3.new(W*2,0.2,22),Color3.fromRGB(25,25,35),CONCRETE,Vector3.new(0,0.1,z))
		for x=-350,350,40 do ns(Vector3.new(8,0.15,2),Color3.fromRGB(220,220,100),Vector3.new(x,0.15,z)) end
	end
	for _,x in {-100,0,100} do
		part(Vector3.new(22,0.2,W*2),Color3.fromRGB(25,25,35),CONCRETE,Vector3.new(x,0.1,0))
		for z=-350,350,40 do ns(Vector3.new(2,0.15,8),Color3.fromRGB(220,220,100),Vector3.new(x,0.15,z)) end
	end
end
local ACCENTS={Color3.fromRGB(0,220,255),Color3.fromRGB(57,255,20),Color3.fromRGB(160,0,255),
	Color3.fromRGB(255,100,0),Color3.fromRGB(255,50,150),Color3.fromRGB(0,255,180)}
local function building(cx,cz,w,d,h,accent)
	part(Vector3.new(w,h,d),Color3.fromRGB(20,20,32),SMOOTH,Vector3.new(cx,h/2,cz))
	for _,sx in {-w/2,w/2} do for _,sz in {-d/2,d/2} do ns(Vector3.new(0.4,h,0.4),accent,Vector3.new(cx+sx,h/2,cz+sz)) end end
	ns(Vector3.new(w+0.4,0.4,0.4),accent,Vector3.new(cx,h+0.2,cz-d/2)); ns(Vector3.new(w+0.4,0.4,0.4),accent,Vector3.new(cx,h+0.2,cz+d/2))
	ns(Vector3.new(0.4,0.4,d+0.4),accent,Vector3.new(cx-w/2,h+0.2,cz)); ns(Vector3.new(0.4,0.4,d+0.4),accent,Vector3.new(cx+w/2,h+0.2,cz))
	local cap=part(Vector3.new(1.5,1.5,1.5),accent,NEON,Vector3.new(cx,h+1,cz)); light(cap,accent,30,3)
	for yy=4,h-4,6 do for xx=-w/2+3,w/2-3,5 do
		ns(Vector3.new(1.5,2,0.1), math.random()>0.3 and Color3.fromRGB(200,220,255) or Color3.fromRGB(255,200,100), Vector3.new(cx+xx,yy,cz+d/2+0.1))
	end end
end
local function buildCity()
	local blocks={{-200,-200},{-260,-150},{-150,-260},{-310,-220},{-220,-310},
		{200,-200},{260,-150},{150,-260},{310,-220},{220,-310},
		{-200,200},{-260,150},{-150,260},{-310,220},{-220,310},
		{200,200},{260,150},{150,260},{310,220},{220,310},
		{-300,0},{300,0},{0,-300},{0,300},
		{-350,-80},{-350,80},{350,-80},{350,80},{-80,-350},{80,-350},{-80,350},{80,350}}
	for i,b in ipairs(blocks) do
		building(b[1],b[2],math.random(30,60),math.random(30,60),math.random(20,90),ACCENTS[((i-1)%#ACCENTS)+1])
	end
end
local function buildLamps()
	for x=-350,350,50 do for _,z in {-112,-88,88,112} do
		part(Vector3.new(0.5,10,0.5),Color3.fromRGB(80,80,90),SMOOTH,Vector3.new(x,5,z))
		part(Vector3.new(4,0.5,0.5),Color3.fromRGB(80,80,90),SMOOTH,Vector3.new(x,10.2,z+2))
		light(part(Vector3.new(1,1,1),Color3.fromRGB(255,240,200),NEON,Vector3.new(x,10.2,z+4)),Color3.fromRGB(255,240,180),35,3)
	end end
	for z=-350,350,50 do for _,x in {-112,-88,88,112} do
		part(Vector3.new(0.5,10,0.5),Color3.fromRGB(80,80,90),SMOOTH,Vector3.new(x,5,z))
		part(Vector3.new(0.5,0.5,4),Color3.fromRGB(80,80,90),SMOOTH,Vector3.new(x+2,10.2,z))
		light(part(Vector3.new(1,1,1),Color3.fromRGB(255,240,200),NEON,Vector3.new(x+4,10.2,z)),Color3.fromRGB(255,240,180),35,3)
	end end
end
local function buildPlaza()
	part(Vector3.new(80,0.5,80),Color3.fromRGB(25,25,45),SMOOTH,Vector3.new(0,0.25,225))
	for r=10,35,12 do
		ns(Vector3.new(r*2,0.3,0.3),Color3.fromRGB(0,200,255),Vector3.new(0,0.5,225-r))
		ns(Vector3.new(r*2,0.3,0.3),Color3.fromRGB(0,200,255),Vector3.new(0,0.5,225+r))
		ns(Vector3.new(0.3,0.3,r*2),Color3.fromRGB(0,200,255),Vector3.new(-r,0.5,225))
		ns(Vector3.new(0.3,0.3,r*2),Color3.fromRGB(0,200,255),Vector3.new(r,0.5,225))
	end
	part(Vector3.new(12,1,12),Color3.fromRGB(30,30,50),SMOOTH,Vector3.new(0,0.5,225))
	local orb=part(Vector3.new(2.5,2.5,2.5),Color3.fromRGB(0,220,255),NEON,Vector3.new(0,9,225)); light(orb,Color3.fromRGB(0,220,255),40,5)
	local sb=part(Vector3.new(30,6,1),Color3.fromRGB(10,10,25),SMOOTH,Vector3.new(0,6,193))
	ns(Vector3.new(30.4,0.4,0.4),Color3.fromRGB(0,220,255),Vector3.new(0,9.2,193))
	ns(Vector3.new(30.4,0.4,0.4),Color3.fromRGB(0,220,255),Vector3.new(0,3,193))
	local sg2=Instance.new("SurfaceGui"); sg2.Face=Enum.NormalId.Front; sg2.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud; sg2.PixelsPerStud=20; sg2.Parent=sb
	local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,0,1,0); lbl.BackgroundTransparency=1; lbl.Text="NEON WORLD"; lbl.TextColor3=Color3.fromRGB(0,220,255); lbl.Font=Enum.Font.GothamBlack; lbl.TextScaled=true; lbl.Parent=sg2
end
local function buildArena()
	local asz=Config.ARENA_SIZE; local hw=asz.X/2; local hd=asz.Z/2; local wt=Config.ARENA_WALL_THICKNESS; local wh=12
	part(Vector3.new(asz.X,2,asz.Z),Config.ARENA_COLOR,Config.ARENA_MATERIAL,Vector3.new(0,-1,0))
	local wc=Color3.fromRGB(15,15,30)
	part(Vector3.new(asz.X+wt*2,wh,wt),wc,SMOOTH,Vector3.new(0,wh/2,-hd-wt/2))
	part(Vector3.new(asz.X+wt*2,wh,wt),wc,SMOOTH,Vector3.new(0,wh/2,hd+wt/2))
	part(Vector3.new(wt,wh,asz.Z+wt*2),wc,SMOOTH,Vector3.new(-hw-wt/2,wh/2,0))
	part(Vector3.new(wt,wh,asz.Z+wt*2),wc,SMOOTH,Vector3.new(hw+wt/2,wh/2,0))
	local nc=Color3.fromRGB(0,180,255)
	ns(Vector3.new(asz.X+wt*2,0.5,wt),nc,Vector3.new(0,wh+0.25,-hd-wt/2))
	ns(Vector3.new(asz.X+wt*2,0.5,wt),nc,Vector3.new(0,wh+0.25,hd+wt/2))
	ns(Vector3.new(wt,0.5,asz.Z+wt*2),nc,Vector3.new(-hw-wt/2,wh+0.25,0))
	ns(Vector3.new(wt,0.5,asz.Z+wt*2),nc,Vector3.new(hw+wt/2,wh+0.25,0))
	-- Arch
	local AX,AZ=0,124
	for _,sx in {-24,24} do
		part(Vector3.new(4,40,4),Color3.fromRGB(15,15,25),SMOOTH,Vector3.new(AX+sx,20,AZ))
		for i=0,35,8 do ns(Vector3.new(4.2,0.4,4.2),Color3.fromRGB(0,200,255),Vector3.new(AX+sx,i+2,AZ)) end
		light(part(Vector3.new(6,2,6),Color3.fromRGB(0,180,255),NEON,Vector3.new(AX+sx,41,AZ)),Color3.fromRGB(0,200,255),40,4)
	end
	part(Vector3.new(48,2,4),Color3.fromRGB(15,15,25),SMOOTH,Vector3.new(AX,40,AZ))
	ns(Vector3.new(48.4,0.4,4.2),Color3.fromRGB(0,200,255),Vector3.new(AX,41.2,AZ))
	local sp=part(Vector3.new(38,5,1),Color3.fromRGB(8,8,20),SMOOTH,Vector3.new(AX,34,AZ))
	ns(Vector3.new(38.4,0.3,1),Color3.fromRGB(57,255,20),Vector3.new(AX,36.6,AZ))
	ns(Vector3.new(38.4,0.3,1),Color3.fromRGB(57,255,20),Vector3.new(AX,31.3,AZ))
	local sGui=Instance.new("SurfaceGui"); sGui.Face=Enum.NormalId.Front; sGui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud; sGui.PixelsPerStud=20; sGui.Parent=sp
	local sLbl=Instance.new("TextLabel"); sLbl.Size=UDim2.new(1,0,1,0); sLbl.BackgroundTransparency=1; sLbl.Text="SNAKE ARENA"; sLbl.TextColor3=Color3.fromRGB(57,255,20); sLbl.Font=Enum.Font.GothamBlack; sLbl.TextScaled=true; sLbl.Parent=sGui
	-- Beacon towers flanking arena entrance
	for _,sx in {-60,60} do
		part(Vector3.new(2,80,2),Color3.fromRGB(15,15,25),SMOOTH,Vector3.new(AX+sx,40,AZ))
		light(part(Vector3.new(5,5,5),Color3.fromRGB(57,255,20),NEON,Vector3.new(AX+sx,81,AZ)),Color3.fromRGB(57,255,20),70,7)
	end
	-- Approach signs
	for _,z in {165} do
		local sg=part(Vector3.new(20,5,1),Color3.fromRGB(8,8,20),SMOOTH,Vector3.new(AX,8,z))
		ns(Vector3.new(20.4,0.3,1),Color3.fromRGB(57,255,20),Vector3.new(AX,10.7,z))
		local sgg=Instance.new("SurfaceGui"); sgg.Face=Enum.NormalId.Front; sgg.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud; sgg.PixelsPerStud=20; sgg.Parent=sg
		local sgl=Instance.new("TextLabel"); sgl.Size=UDim2.new(1,0,1,0); sgl.BackgroundTransparency=1; sgl.Text="▼ SNAKE ARENA"; sgl.TextColor3=Color3.fromRGB(57,255,20); sgl.Font=Enum.Font.GothamBlack; sgl.TextScaled=true; sgl.Parent=sgg
	end
	-- Kiosk
	local kiosk=part(Vector3.new(5,7,3),Color3.fromRGB(15,15,30),SMOOTH,Vector3.new(AX,3.5,AZ+10))
	ns(Vector3.new(5.2,0.3,3.2),Color3.fromRGB(57,255,20),Vector3.new(AX,7.2,AZ+10))
	local screen=part(Vector3.new(3.5,4,0.2),Color3.fromRGB(0,50,30),SMOOTH,Vector3.new(AX,4.5,AZ+11.6))
	local sG2=Instance.new("SurfaceGui"); sG2.Face=Enum.NormalId.Front; sG2.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud; sG2.PixelsPerStud=30; sG2.Parent=screen
	local sL2=Instance.new("TextLabel"); sL2.Size=UDim2.new(1,0,1,0); sL2.BackgroundTransparency=1; sL2.Text="PLAY\nSNAKE"; sL2.TextColor3=Color3.fromRGB(57,255,20); sL2.Font=Enum.Font.GothamBlack; sL2.TextScaled=true; sL2.Parent=sG2
	local bb=Instance.new("BillboardGui"); bb.Size=UDim2.new(0,220,0,70); bb.StudsOffset=Vector3.new(0,6,0); bb.AlwaysOnTop=false; bb.MaxDistance=200; bb.Parent=kiosk
	local bbl=Instance.new("TextLabel"); bbl.Size=UDim2.new(1,0,1,0); bbl.BackgroundTransparency=1; bbl.Text="SNAKE ARENA\n[E] ENTER"; bbl.TextColor3=Color3.fromRGB(57,255,20); bbl.Font=Enum.Font.GothamBlack; bbl.TextScaled=true; bbl.Parent=bb
	return prompt(kiosk,"Snake Arena",Enum.KeyCode.E,35)
end
-- Shared arch entrance builder — used by every mini-game district.
-- Produces a 36-stud arch, large sign, approach marker, and kiosk with prompt.
-- To add a new game: call buildDistrict(cx,cz,name,color,size) and wire the prompt.
local ARCH_H = 36   -- pillar height (studs)
local ARCH_W = 15   -- pillar offset from arch center (span = ARCH_W*2)
local function buildArch(ex, ez, isXAxis, dir, name, color)
	-- ex/ez = position of arch center on the entry face
	-- isXAxis: true → arch spans Z axis; false → arch spans X axis
	-- dir: +1 or -1, direction pointing TOWARD origin from entry face
	local function pillarPos(offset)
		if isXAxis then return Vector3.new(ex, ARCH_H/2, ez+offset)
		else             return Vector3.new(ex+offset, ARCH_H/2, ez) end
	end
	local function stripPos(offset, y)
		if isXAxis then return Vector3.new(ex, y, ez+offset)
		else             return Vector3.new(ex+offset, y, ez) end
	end
	-- Pillars
	for _,off in {-ARCH_W, ARCH_W} do
		part(Vector3.new(4,ARCH_H,4), Color3.fromRGB(12,12,22), SMOOTH, pillarPos(off))
		for i=0, ARCH_H-4, 8 do
			ns(Vector3.new(4.4,0.5,4.4), color, stripPos(off, i+2))
		end
		light(part(Vector3.new(6,6,6), color, NEON, stripPos(off, ARCH_H+3)), color, 50, 6)
	end
	-- Crossbar
	local cbSz = isXAxis and Vector3.new(4, 3.5, ARCH_W*2+6) or Vector3.new(ARCH_W*2+6, 3.5, 4)
	part(cbSz, Color3.fromRGB(12,12,22), SMOOTH, Vector3.new(ex, ARCH_H+1.75, ez))
	local cbNSz = isXAxis and Vector3.new(4.4, 0.4, ARCH_W*2+6.4) or Vector3.new(ARCH_W*2+6.4, 0.4, 4.4)
	ns(cbNSz, color, Vector3.new(ex, ARCH_H+3.5, ez))
	ns(cbNSz, color, Vector3.new(ex, ARCH_H+0.1, ez))
	-- Sign panel
	local spSz = isXAxis and Vector3.new(3.5, 8, ARCH_W*2-2) or Vector3.new(ARCH_W*2-2, 8, 3.5)
	local sp = part(spSz, Color3.fromRGB(6,6,18), SMOOTH, Vector3.new(ex, ARCH_H-7, ez))
	local spNSz = isXAxis and Vector3.new(3.7, 0.3, ARCH_W*2-1.6) or Vector3.new(ARCH_W*2-1.6, 0.3, 3.7)
	ns(spNSz, color, Vector3.new(ex, ARCH_H-2.8, ez))
	ns(spNSz, color, Vector3.new(ex, ARCH_H-11.1, ez))
	local sgFace
	if isXAxis then sgFace = dir > 0 and Enum.NormalId.Right or Enum.NormalId.Left
	else            sgFace = dir > 0 and Enum.NormalId.Front or Enum.NormalId.Back end
	local sg = Instance.new("SurfaceGui"); sg.Face=sgFace
	sg.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud=20; sg.Parent=sp
	local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,0,1,0); lbl.BackgroundTransparency=1
	lbl.Text=name; lbl.TextColor3=color; lbl.Font=Enum.Font.GothamBlack; lbl.TextScaled=true; lbl.Parent=sg
	-- Approach sign (55 studs toward origin from arch)
	local ax = isXAxis and ex+dir*55 or ex
	local az = isXAxis and ez       or ez+dir*55
	local apSz = isXAxis and Vector3.new(3.5,5,22) or Vector3.new(22,5,3.5)
	local apNSz= isXAxis and Vector3.new(3.7,0.3,22.4) or Vector3.new(22.4,0.3,3.7)
	local ap=part(apSz, Color3.fromRGB(8,8,20), SMOOTH, Vector3.new(ax,8,az))
	ns(apNSz, color, Vector3.new(ax,10.6,az))
	local asg=Instance.new("SurfaceGui"); asg.Face=sgFace
	asg.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud; asg.PixelsPerStud=20; asg.Parent=ap
	local albl=Instance.new("TextLabel"); albl.Size=UDim2.new(1,0,1,0); albl.BackgroundTransparency=1
	local arrow
	if isXAxis then arrow = dir < 0 and "▶ " or "◀ "
	else            arrow = dir > 0 and "▼ " or "▲ " end
	albl.Text=arrow..name; albl.TextColor3=color; albl.Font=Enum.Font.GothamBlack; albl.TextScaled=true; albl.Parent=asg
end

local function buildDistrict(cx,cz,name,color,size)
	size=size or 80
	local half=size/2
	-- Ground platform
	part(Vector3.new(size,0.5,size),Color3.fromRGB(12,12,22),SMOOTH,Vector3.new(cx,0.25,cz))
	-- Neon border
	ns(Vector3.new(size+0.4,0.4,0.4),color,Vector3.new(cx,0.6,cz-half))
	ns(Vector3.new(size+0.4,0.4,0.4),color,Vector3.new(cx,0.6,cz+half))
	ns(Vector3.new(0.4,0.4,size+0.4),color,Vector3.new(cx-half,0.6,cz))
	ns(Vector3.new(0.4,0.4,size+0.4),color,Vector3.new(cx+half,0.6,cz))
	-- Corner beacon towers
	for _,sx in {-half,half} do for _,sz in {-half,half} do
		part(Vector3.new(2,50,2),Color3.fromRGB(15,15,25),SMOOTH,Vector3.new(cx+sx,25,cz+sz))
		light(part(Vector3.new(3,3,3),color,NEON,Vector3.new(cx+sx,51,cz+sz)),color,50,5)
	end end
	-- Center spire
	part(Vector3.new(1.5,80,1.5),Color3.fromRGB(15,15,25),SMOOTH,Vector3.new(cx,40,cz))
	light(part(Vector3.new(5,5,5),color,NEON,Vector3.new(cx,81,cz)),color,70,7)
	-- Arch entrance + approach sign
	local kx,kz,dir
	if math.abs(cx) >= math.abs(cz) then
		dir = cx > 0 and -1 or 1
		local ex = cx + dir*half
		buildArch(ex, cz, true, dir, name, color)
		kx = ex - dir*8; kz = cz  -- kiosk just inside arch
	else
		dir = cz > 0 and -1 or 1
		local ez = cz + dir*half
		buildArch(cx, ez, false, dir, name, color)
		kx = cx; kz = ez - dir*8
	end
	-- Kiosk with billboard + prompt
	local kiosk=part(Vector3.new(5,7,3),Color3.fromRGB(12,12,22),SMOOTH,Vector3.new(kx,3.5,kz))
	ns(Vector3.new(5.2,0.3,3.2),color,Vector3.new(kx,7.2,kz))
	local screen=part(Vector3.new(3.5,4,0.2),Color3.fromRGB(0,20,30),SMOOTH,Vector3.new(kx,4.5,kz+(dir*-1.6)))
	local sG=Instance.new("SurfaceGui"); sG.Face=Enum.NormalId.Front
	sG.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud; sG.PixelsPerStud=30; sG.Parent=screen
	local sL=Instance.new("TextLabel"); sL.Size=UDim2.new(1,0,1,0); sL.BackgroundTransparency=1
	sL.Text="PLAY\n"..name; sL.TextColor3=color; sL.Font=Enum.Font.GothamBlack; sL.TextScaled=true; sL.Parent=sG
	local bb=Instance.new("BillboardGui"); bb.Size=UDim2.new(0,240,0,80)
	bb.StudsOffset=Vector3.new(0,8,0); bb.AlwaysOnTop=false; bb.MaxDistance=250; bb.Parent=kiosk
	local bbl=Instance.new("TextLabel"); bbl.Size=UDim2.new(1,0,1,0); bbl.BackgroundTransparency=1
	bbl.Text=name.."\n[E] ENTER"; bbl.TextColor3=color; bbl.Font=Enum.Font.GothamBlack; bbl.TextScaled=true; bbl.Parent=bb
	return prompt(kiosk,name,Enum.KeyCode.E,35)
end
local function buildArenaDecor()
	local function dp(sz,col,mat,pos)  -- decorative, no collision
		local p=part(sz,col,mat,pos); p.CanCollide=false; return p
	end
	local function dball(sz,col,mat,pos)
		local p=dp(sz,col,mat,pos); p.Shape=Enum.PartType.Ball; return p
	end
	-- Corner crystal clusters
	local ccs={Color3.fromRGB(0,200,255),Color3.fromRGB(160,0,255),Color3.fromRGB(255,60,160),Color3.fromRGB(57,255,20)}
	for ci,corner in ipairs({{108,108},{108,-108},{-108,108},{-108,-108}}) do
		local cc=ccs[ci]
		for i=1,5 do
			local ox=corner[1]+math.random(-7,7); local oz=corner[2]+math.random(-7,7)
			local h=math.random(4,14)
			local cr=dp(Vector3.new(1,h,1),cc,NEON,Vector3.new(ox,h/2,oz))
			CollectionService:AddTag(cr,"SnakeDecorKillable")
			if i<=2 then light(cr,cc,22,2.5) end
			dball(Vector3.new(1.5,1.5,1.5),cc,NEON,Vector3.new(ox,h+0.8,oz))
		end
	end
	-- Decorative trees along inner arena walls
	for _,pos in ipairs({
		{95,112},{-95,112},{0,112},{50,112},{-50,112},
		{95,-112},{-95,-112},{0,-112},{50,-112},{-50,-112},
		{112,80},{112,-80},{112,20},{112,-20},{-112,80},{-112,-80},{-112,20},{-112,-20},
	}) do
		local th=math.random(5,12); local cr=math.random(4,7)
		local trunk=dp(Vector3.new(1.4,th,1.4),Color3.fromRGB(50,30,15),Enum.Material.Wood,Vector3.new(pos[1],th/2,pos[2]))
		CollectionService:AddTag(trunk,"SnakeDecorKillable")
		local lcs={{20,80,30},{30,100,20},{10,110,50}}; local lc=lcs[math.random(3)]
		dball(Vector3.new(cr*2,cr*1.4,cr*2),Color3.fromRGB(lc[1],lc[2],lc[3]),Enum.Material.Grass,Vector3.new(pos[1],th+cr*0.6,pos[2]))
		if math.random(100)<=40 then  -- neon blossom
			local bcs={{255,80,160},{80,200,255},{200,255,60}}; local bc=bcs[math.random(3)]
			local bl=dball(Vector3.new(cr,cr*0.8,cr),Color3.fromRGB(bc[1],bc[2],bc[3]),NEON,Vector3.new(pos[1],th+cr*1.05,pos[2]))
			light(bl,Color3.fromRGB(bc[1],bc[2],bc[3]),14,2)
		end
	end
	-- Mushroom patches near edges
	local mcs={{180,0,255},{255,50,160},{60,210,100},{0,180,255}}
	for i,sp in ipairs({
		{75,110},{-75,110},{75,-110},{-75,-110},
		{110,75},{-110,75},{110,-75},{-110,-75},
		{110,25},{-110,25},{110,-25},{-110,-25},
	}) do
		local mc=mcs[((i-1)%4)+1]
		for _=1,math.random(3,5) do
			local ox=sp[1]+math.random(-5,5); local oz=sp[2]+math.random(-5,5)
			local sh=math.random(10,25)*0.1
			local stem=dp(Vector3.new(0.7,sh,0.7),Color3.fromRGB(210,185,155),SMOOTH,Vector3.new(ox,sh/2,oz))
			CollectionService:AddTag(stem,"SnakeDecorKillable")
			local mr=math.random(12,30)*0.1
			local mc3=Color3.fromRGB(mc[1],mc[2],mc[3])
			local mcap=dball(Vector3.new(mr*2,mr*0.75,mr*2),mc3,NEON,Vector3.new(ox,sh+mr*0.25,oz))
			CollectionService:AddTag(mcap,"SnakeDecorKillable")
			light(mcap,mc3,10,1.5)
		end
	end
	-- Ambient glow orbs ringing the arena
	local orbC={Color3.fromRGB(0,220,255),Color3.fromRGB(255,80,200),Color3.fromRGB(57,255,20),Color3.fromRGB(255,200,0)}
	for i=0,15 do
		local ang=i/16*math.pi*2; local r=106
		local oc=orbC[(i%4)+1]
		local orb=dball(Vector3.new(1.2,1.2,1.2),oc,NEON,Vector3.new(math.cos(ang)*r,math.random(3,9),math.sin(ang)*r))
		light(orb,oc,24,3)
	end
end
-- District positions for mini-games (key -> {cx, cz, size}); name + color from GameRegistry
local MINI_GAME_DISTRICTS = {
	LAVA     = {cx=0,    cz=-250, size=90},
	MAZE     = {cx=250,  cz=-200, size=90},
	RHYTHM   = {cx=-250, cz=-200, size=90},
	FLOOD    = {cx=-280, cz=50,   size=80},
	ASTEROID = {cx=280,  cz=50,   size=80},
}

function WorldBuilder.Build()
	local existing=workspace:FindFirstChild("OpenWorld"); if existing then existing:Destroy() end
	folder=Instance.new("Folder"); folder.Name="OpenWorld"; folder.Parent=workspace
	buildGround(); buildCity(); buildLamps(); buildPlaza()
	local snakePrompt=buildArena()
	buildArenaDecor()
	for _,d in {
		{Vector3.new(W*2+4,60,4),Vector3.new(0,30,-W)},{Vector3.new(W*2+4,60,4),Vector3.new(0,30,W)},
		{Vector3.new(4,60,W*2+4),Vector3.new(-W,30,0)},{Vector3.new(4,60,W*2+4),Vector3.new(W,30,0)},
	} do local bw=part(d[1],Color3.new(0,0,0),SMOOTH,d[2]); bw.Transparency=1 end
	local prompts = {SNAKE=snakePrompt}
	for _, g in GameRegistry.GetAll() do
		local key = g.key
		if key ~= "SNAKE" then
			local district = MINI_GAME_DISTRICTS[key]
			if district then
				prompts[key] = buildDistrict(district.cx, district.cz, g.name, g.color, district.size)
			end
		end
	end
	part(Vector3.new(80,20,80),Color3.fromRGB(10,10,20),CONCRETE,Vector3.new(280,10,50))
	if not workspace:FindFirstChild("Dragon") then local df=Instance.new("Folder"); df.Name="Dragon"; df.Parent=workspace end
	return prompts
end
return WorldBuilder
