-- DragonFlight
local RunService = game:GetService("RunService")
local DragonFlight = {}
local SEG_COUNT=20; local SEG_LAG=0.16; local ORBIT_R=160; local ORBIT_Y=90; local ORBIT_SPEED=0.18
local HEAD_COLOR=Color3.fromRGB(0,200,255); local MID_COLOR=Color3.fromRGB(0,255,120)
local TAIL_COLOR=Color3.fromRGB(160,0,255); local SPINE_COLOR=Color3.fromRGB(255,220,0)
local EYE_COLOR=Color3.fromRGB(255,50,0); local NEON=Enum.Material.Neon
local function lerp3(a,b,t) return Color3.new(a.R+(b.R-a.R)*t,a.G+(b.G-a.G)*t,a.B+(b.B-a.B)*t) end
local function segColor(i)
	local t=(i-1)/(SEG_COUNT-1)
	if t<0.5 then return lerp3(HEAD_COLOR,MID_COLOR,t*2) else return lerp3(MID_COLOR,TAIL_COLOR,(t-0.5)*2) end
end
local function mp(size,color)
	local p=Instance.new("Part"); p.Size=size; p.Color=color; p.Material=NEON
	p.Anchored=true; p.CanCollide=false; p.CastShadow=false; return p
end
function DragonFlight.Start()
	local folder=workspace:FindFirstChild("Dragon")
	if not folder then folder=Instance.new("Folder"); folder.Name="Dragon"; folder.Parent=workspace end
	for _,c in folder:GetChildren() do c:Destroy() end
	local segs={}; local positions={}
	-- Extra data tables (can't store on Part userdata)
	local spines={}   -- [i] = spine Part or nil
	local wingsL={}   -- [i] = wing Part or nil
	local wingsR={}   -- [i] = wing Part or nil
	local head=mp(Vector3.new(4,3.5,5),HEAD_COLOR); head.Parent=folder
	local eye1=mp(Vector3.new(0.8,0.8,0.5),EYE_COLOR); eye1.Parent=folder
	local eye2=mp(Vector3.new(0.8,0.8,0.5),EYE_COLOR); eye2.Parent=folder
	local el1=Instance.new("PointLight"); el1.Color=EYE_COLOR; el1.Range=20; el1.Brightness=4; el1.Parent=eye1
	local el2=Instance.new("PointLight"); el2.Color=EYE_COLOR; el2.Range=20; el2.Brightness=4; el2.Parent=eye2
	local gl=Instance.new("PointLight"); gl.Color=HEAD_COLOR; gl.Range=40; gl.Brightness=3; gl.Parent=head
	for i=1,SEG_COUNT do
		local t=(i-1)/(SEG_COUNT-1); local w=3.5-t*2
		local seg=mp(Vector3.new(w,w*0.85,w*1.1),segColor(i)); seg.Parent=folder
		table.insert(segs,seg); table.insert(positions,Vector3.new(ORBIT_R,ORBIT_Y,0))
		if i>=3 and i<=SEG_COUNT-3 and i%2==0 then
			local spine=mp(Vector3.new(w*0.3,w*0.6,w*0.3),SPINE_COLOR); spine.Parent=folder; spines[i]=spine
		end
		if i==3 or i==5 then
			local wL=mp(Vector3.new(w*1.2,0.25,28),Color3.fromRGB(0,140,200)); wL.Transparency=0.25; wL.Parent=folder; wingsL[i]=wL
			local wR=mp(Vector3.new(w*1.2,0.25,28),Color3.fromRGB(0,140,200)); wR.Transparency=0.25; wR.Parent=folder; wingsR[i]=wR
		end
	end
	local t=0
	RunService.Heartbeat:Connect(function(dt)
		t+=dt
		local angle=t*ORBIT_SPEED; local wave=math.sin(t*1.2)*18
		local headPos=Vector3.new(math.cos(angle)*ORBIT_R, ORBIT_Y+wave, math.sin(angle)*ORBIT_R)
		for i=SEG_COUNT,2,-1 do positions[i]=positions[i]:Lerp(positions[i-1],1-math.exp(-dt/SEG_LAG)) end
		positions[1]=headPos
		local fwd=(headPos-(SEG_COUNT>1 and positions[2] or headPos-Vector3.new(1,0,0))).Unit
		head.CFrame=CFrame.lookAt(headPos,headPos+fwd)
		eye1.CFrame=head.CFrame*CFrame.new(1.1,0.4,-2.2)
		eye2.CFrame=head.CFrame*CFrame.new(-1.1,0.4,-2.2)
		for i=1,SEG_COUNT do
			local seg=segs[i]; local pos=positions[i]
			local nextPos=i<SEG_COUNT and positions[i+1] or pos-fwd
			local dir=pos-nextPos; if dir.Magnitude>0.01 then dir=dir.Unit end
			seg.CFrame=CFrame.lookAt(pos,pos+dir)
			if spines[i] then spines[i].CFrame=seg.CFrame*CFrame.new(0,seg.Size.Y*0.8,0) end
			if wingsL[i] then
				local flap=math.sin(t*3+i*0.5)*0.35
				wingsL[i].CFrame=seg.CFrame*CFrame.new(0,0,14)*CFrame.Angles(flap,0,0)
				wingsR[i].CFrame=seg.CFrame*CFrame.new(0,0,-14)*CFrame.Angles(-flap,0,0)
			end
		end
	end)
end
return DragonFlight
