-- MazeGame v4: Labyrinth Escape
-- Refactored to use SGH shared modules: TimerModule, ScoreModule, PathfindingModule
local RunService        = game:GetService('RunService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local _Shared     = ReplicatedStorage:WaitForChild('SGH'):WaitForChild('Shared')
local TimerModule = require(_Shared:WaitForChild('TimerModule'))
local ScoreModule = require(_Shared:WaitForChild('ScoreModule'))
local PathModule  = require(_Shared:WaitForChild('PathfindingModule'))
local computePath = PathModule.computePath

local MazeGame = {}

local NEON_M = Enum.Material.Neon
local SMOOTH = Enum.Material.SmoothPlastic

local CENTER = Vector3.new(600, 1000, 0)

local LOG_N  = 15
local CELL   = 8
local PHYS_N = LOG_N * 2 + 1
local WALL_H = 10
local TIMER  = 90

local WALL_C  = Color3.fromRGB(65, 50, 42)
local FLOOR_C = Color3.fromRGB(48, 36, 22)
local NEON_C  = Color3.fromRGB(90, 0, 180)
local TORCH_C = Color3.fromRGB(255, 145, 30)
local EXIT_C  = Color3.fromRGB(57, 255, 20)
local BODY_C  = Color3.fromRGB(60, 100, 40)
local EYE_C   = Color3.fromRGB(255, 200, 0)

local function mkp(folder, sz, col, mat, pos, cc)
	local p = Instance.new('Part')
	p.Size=sz; p.Color=col; p.Material=mat
	p.Anchored=true; p.CanCollide=(cc~=false); p.CastShadow=false
	p.Position=pos; p.Parent=folder
	return p
end

local function generateMaze(rng)
	local g = {}
	for r=1,PHYS_N do g[r]={} for c=1,PHYS_N do g[r][c]=1 end end
	local vis = {}
	local function carve(lr,lc)
		vis[lr*100+lc]=true
		g[2*lr-1][2*lc-1]=0
		local dirs={{0,1},{0,-1},{1,0},{-1,0}}
		for i=#dirs,2,-1 do local j=rng:NextInteger(1,i); dirs[i],dirs[j]=dirs[j],dirs[i] end
		for _,d in ipairs(dirs) do
			local nr,nc=lr+d[1],lc+d[2]
			if nr>=1 and nr<=LOG_N and nc>=1 and nc<=LOG_N and not vis[nr*100+nc] then
				local wr=2*lr-1+d[1]; local wc=2*lc-1+d[2]
				g[wr][wc]=0
				carve(nr,nc)
			end
		end
	end
	carve(1,1)
	return g
end

local function cellPos(ox,oz,lr,lc)
	return Vector3.new(ox+(2*lc-1-0.5)*CELL, CENTER.Y+2, oz+(2*lr-1-0.5)*CELL)
end

local function moveEnemy(e, delta)
	for _,p in e.model:GetChildren() do
		if p:IsA('BasePart') then p.Position = p.Position + delta end
	end
end

local function makeEnemyModel(folder, spawnPos)
	local model = Instance.new('Model'); model.Name='Enemy'; model.Parent=folder
	local body = Instance.new('Part')
	body.Size=Vector3.new(2.4,3.5,2.4); body.Color=BODY_C; body.Material=SMOOTH
	body.Anchored=true; body.CanCollide=false; body.CastShadow=false
	body.Position=spawnPos+Vector3.new(0,1.75,0); body.Parent=model
	model.PrimaryPart=body
	for _,ex in ipairs({-0.55,0.55}) do
		local eye=Instance.new('Part')
		eye.Size=Vector3.new(0.5,0.5,0.35); eye.Shape=Enum.PartType.Ball
		eye.Color=EYE_C; eye.Material=NEON_M
		eye.Anchored=true; eye.CanCollide=false; eye.CastShadow=false
		eye.Position=spawnPos+Vector3.new(ex,2.8,-1.15); eye.Parent=model
	end
	local pl=Instance.new('PointLight')
	pl.Color=EYE_C; pl.Range=18; pl.Brightness=3; pl.Parent=body
	return model, body
end

function MazeGame.start(player, session, ctx)
	local folder=Instance.new('Folder'); folder.Name='MazeGame'; folder.Parent=workspace
	local rng=Random.new(math.floor(tick()))
	local maze=generateMaze(rng)
	local mSz=PHYS_N*CELL
	local ox=CENTER.X-mSz/2
	local oz=CENTER.Z-mSz/2

	mkp(folder,Vector3.new(mSz+12,1,mSz+12),FLOOR_C,SMOOTH,Vector3.new(CENTER.X,CENTER.Y-0.5,CENTER.Z))

	for _,v in ipairs({
		{Vector3.new(mSz+12,0.4,0.4),Vector3.new(CENTER.X,CENTER.Y+0.2,oz-0.2)},
		{Vector3.new(mSz+12,0.4,0.4),Vector3.new(CENTER.X,CENTER.Y+0.2,oz+mSz+0.2)},
		{Vector3.new(0.4,0.4,mSz+12),Vector3.new(ox-0.2,CENTER.Y+0.2,CENTER.Z)},
		{Vector3.new(0.4,0.4,mSz+12),Vector3.new(ox+mSz+0.2,CENTER.Y+0.2,CENTER.Z)},
	}) do mkp(folder,v[1],NEON_C,NEON_M,v[2],false) end

	for _,v in ipairs({
		{Vector3.new(mSz+14,30,1),Vector3.new(CENTER.X,CENTER.Y+15,oz-1)},
		{Vector3.new(mSz+14,30,1),Vector3.new(CENTER.X,CENTER.Y+15,oz+mSz+1)},
		{Vector3.new(1,30,mSz+14),Vector3.new(ox-1,CENTER.Y+15,CENTER.Z)},
		{Vector3.new(1,30,mSz+14),Vector3.new(ox+mSz+1,CENTER.Y+15,CENTER.Z)},
	}) do local w=mkp(folder,v[1],Color3.new(0,0,0),SMOOTH,v[2]); w.Transparency=1 end

	local torchN=0
	for r=1,PHYS_N do
		for c=1,PHYS_N do
			local wx=ox+(c-0.5)*CELL
			local wz=oz+(r-0.5)*CELL
			if maze[r][c]==1 then
				mkp(folder,Vector3.new(CELL,WALL_H,CELL),WALL_C,SMOOTH,Vector3.new(wx,CENTER.Y+WALL_H/2,wz))
				mkp(folder,Vector3.new(CELL,0.3,CELL),NEON_C,NEON_M,Vector3.new(wx,CENTER.Y+WALL_H+0.15,wz),false)
				local nearOpen=(r>1 and maze[r-1][c]==0) or (r<PHYS_N and maze[r+1][c]==0)
				local nearOpen2=(c>1 and maze[r][c-1]==0) or (c<PHYS_N and maze[r][c+1]==0)
				if (nearOpen or nearOpen2) and torchN<60 and (r+c)%6==0 then
					local t=mkp(folder,Vector3.new(0.4,1.2,0.4),TORCH_C,NEON_M,Vector3.new(wx,CENTER.Y+WALL_H*0.55,wz),false)
					local tl=Instance.new('PointLight'); tl.Color=TORCH_C; tl.Range=18; tl.Brightness=1.5; tl.Parent=t
					torchN+=1
				end
			else
				mkp(folder,Vector3.new(CELL-0.3,0.3,CELL-0.3),FLOOR_C,SMOOTH,Vector3.new(wx,CENTER.Y+0.15,wz))
			end
		end
	end

	local exitX=ox+(2*LOG_N-1-0.5)*CELL
	local exitZ=oz+(2*LOG_N-1-0.5)*CELL
	mkp(folder,Vector3.new(CELL-0.5,0.5,CELL-0.5),EXIT_C,NEON_M,Vector3.new(exitX,CENTER.Y+0.25,exitZ),false)
	local ep=mkp(folder,Vector3.new(0.5,0.5,0.5),EXIT_C,NEON_M,Vector3.new(exitX,CENTER.Y+1,exitZ),false)
	local el=Instance.new('PointLight'); el.Color=EXIT_C; el.Range=35; el.Brightness=5; el.Parent=ep
	local beacon=Instance.new('Part')
	beacon.Size=Vector3.new(3,3,3); beacon.Shape=Enum.PartType.Ball
	beacon.Color=EXIT_C; beacon.Material=NEON_M
	beacon.Anchored=true; beacon.CanCollide=false; beacon.CastShadow=false
	beacon.Position=Vector3.new(exitX,CENTER.Y+WALL_H*0.65,exitZ); beacon.Parent=folder
	local bl=Instance.new('PointLight'); bl.Color=EXIT_C; bl.Range=40; bl.Brightness=6; bl.Parent=beacon
	local bb=Instance.new('BillboardGui')
	bb.Size=UDim2.new(0,120,0,40); bb.StudsOffset=Vector3.new(0,5,0); bb.MaxDistance=250; bb.Parent=beacon
	local bbl=Instance.new('TextLabel')
	bbl.Size=UDim2.new(1,0,1,0); bbl.BackgroundTransparency=1; bbl.Text='EXIT'
	bbl.TextColor3=EXIT_C; bbl.Font=Enum.Font.GothamBlack; bbl.TextScaled=true; bbl.Parent=bb
	task.spawn(function()
		local t=0
		while beacon.Parent do
			task.wait(0.05); t+=0.05
			local s=2.5+math.sin(t*3)*0.7; beacon.Size=Vector3.new(s,s,s)
		end
	end)

	local spawnPos=cellPos(ox,oz,1,1)
	local char=player.Character
	if char then
		local hrp=char:FindFirstChild('HumanoidRootPart')
		if hrp then hrp.Anchored=false; hrp.CFrame=CFrame.new(spawnPos+Vector3.new(0,2,0)) end
		for _,p in char:GetDescendants() do
			if p:IsA('BasePart') then p.Transparency=0; p.CanCollide=(p.Name~='HumanoidRootPart') end
		end
		local hum=char:FindFirstChildOfClass('Humanoid')
		if hum then hum.WalkSpeed=16; hum.JumpHeight=7.2 end
	end

	local function hideChar(p)
		local c2=p.Character
		if c2 then
			local h=c2:FindFirstChild('HumanoidRootPart')
			if h then h.Anchored=true; h.CFrame=CFrame.new(0,-100,0) end
			for _,pt in c2:GetDescendants() do
				if pt:IsA('BasePart') then pt.Transparency=1; pt.CanCollide=false end
			end
			local hm=c2:FindFirstChildOfClass('Humanoid')
			if hm then hm.WalkSpeed=0; hm.JumpHeight=0 end
		end
	end
	local over=false
	local conn
	local timer  = TimerModule.new(TIMER)
	local scores = ScoreModule.new()
	scores:Reset(player)

	-- Timer fires Tick each second → HUD update (efficient vs every-frame)
	timer.Tick:Connect(function(remaining)
		if ctx.LevelUpdated then
			ctx.LevelUpdated:FireClient(player,{
				level=1, timeInLevel=TIMER-remaining, levelDuration=TIMER,
			})
		end
	end)
	-- Timer expiry → timeout GAME_OVER
	timer.Expired:Connect(function()
		if over then return end
		over = true
		pcall(function() conn:Disconnect() end)
		hideChar(player)
		scores:Submit(function(p,_) ctx.saveScore(p,0) end)
		ctx.sessions[player].state = 'GAME_OVER'
		ctx.GameStateChanged:FireClient(player,'GAME_OVER',
			{score=0,length=0,level=1,gameType='MAZE'})
	end)

	session.cleanup=function()
		over=true
		pcall(function() if conn then conn:Disconnect() end end)
		pcall(function() timer:Destroy() end)
		pcall(function() folder:Destroy() end)
	end
	ctx.GameStateChanged:FireClient(player,'PLAYING',{isMulti=false,playerCount=1,gameType='MAZE'})
	task.wait(0.3)

	local enemies={}

	local function makePatroller(slr, slc, spd)
		local sp=cellPos(ox,oz,slr,slc)
		local mdl,body=makeEnemyModel(folder,sp)
		local wps={sp}
		local tries=0
		while #wps<4 and tries<40 do
			tries+=1
			local nr=math.clamp(slr+rng:NextInteger(-6,6),1,LOG_N)
			local nc=math.clamp(slc+rng:NextInteger(-6,6),1,LOG_N)
			local pr2,pc2=2*nr-1,2*nc-1
			if maze[pr2][pc2]==0 then
				local cand=cellPos(ox,oz,nr,nc)
				local ok2=true
				for _,existing in ipairs(wps) do
					if (cand-existing).Magnitude<20 then ok2=false; break end
				end
				if ok2 and (cand-sp).Magnitude>20 then table.insert(wps,cand) end
			end
		end
		return {model=mdl,body=body,type='PATROLLER',waypoints=wps,wpIdx=1,speed=spd,pathPts={},pathIdx=1,pathReady=false}
	end

	local function makeChaser(slr, slc, spd)
		local sp=cellPos(ox,oz,slr,slc)
		local mdl,body=makeEnemyModel(folder,sp)
		return {model=mdl,body=body,type='CHASER',speed=spd,state='IDLE',pathPts={},pathIdx=1,lastPath=0}
	end

	table.insert(enemies,makePatroller(8,1,10))
	table.insert(enemies,makePatroller(1,8,10))
	table.insert(enemies,makeChaser(8,8,14))
	table.insert(enemies,makeChaser(3,12,12))
	table.insert(enemies,makeChaser(12,3,12))

	task.spawn(function()
		for _,e in ipairs(enemies) do
			if e.type=='PATROLLER' then
				local full={}
				local wps=e.waypoints
				for i=1,#wps do
					local a=wps[i]; local b=wps[(i%#wps)+1]
					local pts=computePath(a,b)
					if pts then for _,p in ipairs(pts) do table.insert(full,p) end
					else table.insert(full,b) end
				end
				if #full>0 then e.pathPts=full; e.pathIdx=1; e.pathReady=true end
			end
		end
	end)

	local rcP=RaycastParams.new()
	rcP.FilterDescendantsInstances={folder}
	rcP.FilterType=Enum.RaycastFilterType.Include

	local function hasLOS(from,to)
		local dir=to-from
		local res=workspace:Raycast(from+dir.Unit*0.5, dir*0.92, rcP)
		return res==nil
	end

	local CATCH_DIST=3.5
	local DETECT_RANGE=20
	local PATH_REFRESH=2.0

	timer:Start()
	conn=RunService.Heartbeat:Connect(function(dt)
		if over then conn:Disconnect(); return end
		if not ctx.sessions[player] or ctx.sessions[player].gameType~='MAZE' then
			over=true; conn:Disconnect(); return
		end
		local now=tick()
		local char2=player.Character
		local hrp2=char2 and char2:FindFirstChild('HumanoidRootPart')
		if not hrp2 then return end
		local pPos=hrp2.Position
		if Vector3.new(pPos.X-exitX,0,pPos.Z-exitZ).Magnitude<6 then
			over=true; conn:Disconnect()
			hideChar(player)
			local timeBonus=math.floor(timer:GetRemaining()*50)+100
			scores:Add(player,timeBonus)
			scores:Submit(function(p,s) ctx.saveScore(p,s) end)
			ctx.sessions[player].state='GAME_OVER'
			ctx.GameStateChanged:FireClient(player,'GAME_OVER',
				{score=timeBonus,length=1,level=1,gameType='MAZE'})
			return
		end
		for _,e in ipairs(enemies) do
			if not e.body or not e.body.Parent then continue end
			local ePos=e.body.Position
			local distToPlayer=(ePos-pPos).Magnitude
			if distToPlayer<CATCH_DIST then
				over=true; conn:Disconnect()
				hideChar(player)
				scores:Submit(function(p,_) ctx.saveScore(p,0) end)
				ctx.sessions[player].state='GAME_OVER'
				ctx.GameStateChanged:FireClient(player,'GAME_OVER',
					{score=0,length=0,level=1,gameType='MAZE'})
				return
			end
			if e.type=='PATROLLER' then
				local pts=e.pathReady and e.pathPts or e.waypoints
				local wp=pts[e.pathIdx]
				if wp then
					local delta=Vector3.new(wp.X-ePos.X,0,wp.Z-ePos.Z)
					if delta.Magnitude<2.5 then
						e.pathIdx=(e.pathIdx%#pts)+1
					else
						moveEnemy(e, delta.Unit*math.min(e.speed*dt,delta.Magnitude))
					end
				end
			elseif e.type=='CHASER' then
				if e.state=='IDLE' then
					if distToPlayer<=DETECT_RANGE and hasLOS(ePos+Vector3.new(0,1,0),pPos) then
						e.state='CHASE'; e.lastPath=0
					end
				end
				if e.state=='CHASE' then
					if now-e.lastPath>=PATH_REFRESH then
						e.lastPath=now
						task.spawn(function()
							local pts=computePath(ePos,pPos)
							if pts and #pts>1 then e.pathPts=pts; e.pathIdx=2
							else e.pathPts={ePos,pPos}; e.pathIdx=2 end
						end)
					end
					if e.pathIdx<=#e.pathPts then
						local wp=e.pathPts[e.pathIdx]
						local delta=Vector3.new(wp.X-ePos.X,0,wp.Z-ePos.Z)
						if delta.Magnitude<2.5 then e.pathIdx+=1
						else moveEnemy(e, delta.Unit*math.min(e.speed*dt,delta.Magnitude)) end
					end
					if distToPlayer>DETECT_RANGE*1.5 and not hasLOS(ePos,pPos) then
						e.state='IDLE'; e.pathPts={}
					end
				end
			end
		end
	end)

end

return MazeGame
