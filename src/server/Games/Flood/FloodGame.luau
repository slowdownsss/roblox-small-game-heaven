-- FloodGame v2: COLOR FLOOD — claim tiles, flood-fill territory, survive the rising tide
-- Supports 1-4 players competing for tile ownership
local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")
local FloodGame  = {}

local CENTER      = Vector3.new(0, 1000, -600)
local GRID        = 20        -- 20×20 grid
local CELL        = 4         -- studs per tile
local DURATION    = 90        -- seconds
local FLOOD_EVERY = 18        -- seconds between flood wave expansions
local STEAL_SECS  = 0.4       -- seconds to stand on enemy tile to steal it
local JOIN_WINDOW = 10        -- seconds after start where new players can still join
local NEON        = Enum.Material.Neon
local SMOOTH      = Enum.Material.SmoothPlastic

local PCOLORS = {
	Color3.fromRGB(57,  255, 20),   -- lime
	Color3.fromRGB(0,   200, 255),  -- cyan
	Color3.fromRGB(255, 60,  60),   -- red
	Color3.fromRGB(255, 200, 0),    -- gold
}
local NEUTRAL_C = Color3.fromRGB(20,  20,  35)
local FLOOD_C   = Color3.fromRGB(50,   0, 120)  -- dark purple flood

local activeGame = nil  -- shared game instance (module-level, persists between calls)

-- ── Part factory ─────────────────────────────────────────────────────────────
local function mk(folder, sz, col, mat, pos, cc)
	local p = Instance.new("Part")
	p.Size=sz; p.Color=col; p.Material=mat; p.Anchored=true
	p.CanCollide=(cc~=false); p.CastShadow=false; p.Position=pos; p.Parent=folder
	return p
end

-- ── BFS through neutral (unowned, unflooded) tiles; returns cells + border bool ─
local function neutralBFS(tiles, sr, sc)
	local vis, q, cells, border = {}, {{sr,sc}}, {}, false
	while #q > 0 do
		local h = table.remove(q, 1)
		local r, c = h[1], h[2]
		local k = r*100+c
		if vis[k] then continue end
		vis[k]=true; table.insert(cells,{r,c})
		if r==1 or r==GRID or c==1 or c==GRID then border=true end
		for _,d in {{-1,0},{1,0},{0,-1},{0,1}} do
			local nr,nc = r+d[1],c+d[2]
			if nr<1 or nr>GRID or nc<1 or nc>GRID then
				border=true
			else
				local nk=nr*100+nc
				local t=tiles[nr][nc]
				if not vis[nk] and not t.owner and not t.flooded then
					table.insert(q,{nr,nc})
				end
			end
		end
	end
	return cells, border
end

-- ── After claiming (r0,c0), check whether any neutral pocket is now enclosed ──
local function checkEnclosure(g, claimer, r0, c0)
	local checked = {}
	for _,d in {{-1,0},{1,0},{0,-1},{0,1}} do
		local nr,nc = r0+d[1], c0+d[2]
		if nr>=1 and nr<=GRID and nc>=1 and nc<=GRID then
			local t = g.tiles[nr][nc]
			local k = nr*100+nc
			if not t.owner and not t.flooded and not checked[k] then
				checked[k]=true
				local cells, border = neutralBFS(g.tiles, nr, nc)
				if not border then
					local pdata = g.players[claimer]
					local bonus = #cells
					task.spawn(function()
						for _, cell in ipairs(cells) do
							if g.ended then return end
							task.wait(0.012)  -- ripple animation
							local t2 = g.tiles[cell[1]][cell[2]]
							if not t2.owner and not t2.flooded then
								t2.owner = claimer
								t2.part.Color = pdata.color
								t2.part.Material = NEON
								t2.part.Size = Vector3.new(CELL-0.3, 0.6, CELL-0.3)
								pdata.tileCount += 1
								g.ctx.ScoreUpdated:FireClient(claimer,{
									score=pdata.tileCount*10,
									comboCount=bonus,
									comboMultiplier=1+bonus*0.05
								})
							end
						end
					end)
				end
			end
		end
	end
end

-- ── Build the arena ───────────────────────────────────────────────────────────
local function buildArena(ctx)
	local g = {
		ended=false, players={}, tiles={},
		floodFront={}, ctx=ctx,
		folder=Instance.new("Folder"),
		timerFire=0, startTime=nil, lastFlood=nil, conn=nil,
	}
	g.folder.Name="FloodGame"; g.folder.Parent=workspace
	local ox = CENTER.X - GRID*CELL/2
	local oz = CENTER.Z - GRID*CELL/2
	g.ox=ox; g.oz=oz

	-- Tiles
	for r=1,GRID do
		g.tiles[r]={}
		for c=1,GRID do
			local p=mk(g.folder,
				Vector3.new(CELL-0.3, 0.4, CELL-0.3), NEUTRAL_C, SMOOTH,
				Vector3.new(ox+(c-0.5)*CELL, CENTER.Y+0.2, oz+(r-0.5)*CELL))
			g.tiles[r][c]={part=p, owner=nil, flooded=false}
		end
	end

	-- Neon border
	local bs=GRID*CELL
	for _,e in ipairs({
		{Vector3.new(bs+1,0.5,0.5),Vector3.new(CENTER.X,CENTER.Y+0.5,oz)},
		{Vector3.new(bs+1,0.5,0.5),Vector3.new(CENTER.X,CENTER.Y+0.5,oz+bs)},
		{Vector3.new(0.5,0.5,bs+1),Vector3.new(ox,CENTER.Y+0.5,CENTER.Z)},
		{Vector3.new(0.5,0.5,bs+1),Vector3.new(ox+bs,CENTER.Y+0.5,CENTER.Z)},
	}) do mk(g.folder,e[1],Color3.fromRGB(0,200,255),NEON,e[2],false) end

	-- Invisible boundary walls
	for _,d in ipairs({
		{Vector3.new(bs+2,20,1),Vector3.new(CENTER.X,CENTER.Y+10,oz-0.5)},
		{Vector3.new(bs+2,20,1),Vector3.new(CENTER.X,CENTER.Y+10,oz+bs+0.5)},
		{Vector3.new(1,20,bs+2),Vector3.new(ox-0.5,CENTER.Y+10,CENTER.Z)},
		{Vector3.new(1,20,bs+2),Vector3.new(ox+bs+0.5,CENTER.Y+10,CENTER.Z)},
	}) do local w=mk(g.folder,d[1],Color3.new(0,0,0),SMOOTH,d[2]); w.Transparency=1 end

	-- Flood seeded from 4 corners
	g.floodFront={{1,1},{1,GRID},{GRID,1},{GRID,GRID}}
	return g
end

-- ── Spawn a player at their assigned corner ───────────────────────────────────
local function spawnPlayer(g, player)
	local idx=0; for _ in pairs(g.players) do idx+=1 end; idx+=1
	local corners={{1,1},{GRID,GRID},{1,GRID},{GRID,1}}
	local cor=corners[((idx-1)%4)+1]
	g.players[player]={
		color=PCOLORS[((idx-1)%4)+1],
		tileCount=0,
		stand=nil,
	}
	local char=player.Character
	if char then
		local hrp=char:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Anchored=false
			hrp.CFrame=CFrame.new(g.ox+(cor[2]-0.5)*CELL, CENTER.Y+3, g.oz+(cor[1]-0.5)*CELL)
		end
		for _,p in char:GetDescendants() do
			if p:IsA("BasePart") then p.Transparency=0; p.CanCollide=(p.Name~="HumanoidRootPart") end
		end
		local hum=char:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed=22; hum.JumpHeight=7.2 end
	end
end

-- ── World→grid coordinate ─────────────────────────────────────────────────────
local function w2g(g, pos)
	local c=math.floor((pos.X-g.ox)/CELL)+1
	local r=math.floor((pos.Z-g.oz)/CELL)+1
	if r>=1 and r<=GRID and c>=1 and c<=GRID then return r,c end
	return nil,nil
end

-- ── Main heartbeat loop ───────────────────────────────────────────────────────
local function startLoop(g)
	g.startTime=tick()
	g.lastFlood=g.startTime+FLOOD_EVERY

	local conn; conn=RunService.Heartbeat:Connect(function(dt)
		if g.ended then conn:Disconnect(); return end
		local now=tick()
		local elapsed=now-g.startTime
		local remaining=math.max(0, DURATION-elapsed)

		-- Timer broadcast (once per second)
		if now-g.timerFire >= 1 then
			g.timerFire=now
			for p in pairs(g.players) do
				if p.Parent then
					g.ctx.LevelUpdated:FireClient(p,{
						level=1, timeInLevel=DURATION-remaining, levelDuration=DURATION
					})
				end
			end
		end

		-- Rising flood wave expansion
		if now >= g.lastFlood and #g.floodFront > 0 then
			g.lastFlood = now + FLOOD_EVERY
			local nextFront, vis = {}, {}
			for _,cell in ipairs(g.floodFront) do
				local r,c = cell[1],cell[2]
				local k = r*100+c
				if vis[k] then continue end
				vis[k]=true
				local t=g.tiles[r][c]
				if not t.flooded then
					if not t.owner then
						t.flooded=true
						t.part.Color=FLOOD_C
						t.part.Material=NEON
						t.part.Size=Vector3.new(CELL-0.3, 0.15, CELL-0.3)
					end
					for _,d in {{-1,0},{1,0},{0,-1},{0,1}} do
						local nr,nc=r+d[1],c+d[2]
						if nr>=1 and nr<=GRID and nc>=1 and nc<=GRID then
							local nk=nr*100+nc
							if not vis[nk] and not g.tiles[nr][nc].flooded then
								table.insert(nextFront,{nr,nc})
							end
						end
					end
				end
			end
			g.floodFront=nextFront
		end

		-- Per-player logic
		for player,pdata in pairs(g.players) do
			if not player.Parent then continue end
			local char=player.Character; if not char then continue end
			local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then continue end
			local hum=char:FindFirstChildOfClass("Humanoid")

			local r,c = w2g(g, hrp.Position)
			if not r then pdata.stand=nil; continue end
			local tile=g.tiles[r][c]

			-- Flood damage: standing on a flooded tile drains health
			if tile.flooded then
				if hum then hum.Health=math.max(0, hum.Health - dt*20) end
			end

			-- Tile interaction (only for non-flooded tiles)
			if not tile.flooded then
				if not tile.owner then
					-- Neutral: claim instantly
					tile.owner=player
					tile.part.Color=pdata.color
					tile.part.Material=NEON
					tile.part.Size=Vector3.new(CELL-0.3, 0.6, CELL-0.3)
					pdata.tileCount+=1
					g.ctx.ScoreUpdated:FireClient(player,{score=pdata.tileCount*10,comboCount=1,comboMultiplier=1})
					checkEnclosure(g, player, r, c)
					pdata.stand=nil
				elseif tile.owner==player then
					pdata.stand=nil
				else
					-- Enemy tile: stand for STEAL_SECS to steal it
					local edata=g.players[tile.owner]
					if pdata.stand and pdata.stand.r==r and pdata.stand.c==c then
						local frac=math.min(1,(now-pdata.stand.t)/STEAL_SECS)
						-- Visual: blend tile color toward attacker
						if edata then
							tile.part.Color=edata.color:Lerp(pdata.color, frac*0.85)
						end
						if frac>=1 then
							if edata then
								edata.tileCount=math.max(0,edata.tileCount-1)
								g.ctx.ScoreUpdated:FireClient(tile.owner,{score=edata.tileCount*10,comboCount=1,comboMultiplier=1})
							end
							tile.owner=player
							tile.part.Color=pdata.color
							pdata.tileCount+=1
							g.ctx.ScoreUpdated:FireClient(player,{score=pdata.tileCount*10,comboCount=1,comboMultiplier=1})
							pdata.stand=nil
							checkEnclosure(g, player, r, c)
						end
					else
						pdata.stand={r=r, c=c, t=now}
					end
				end
			end
		end

		-- Game over
		if elapsed >= DURATION then
			conn:Disconnect(); g.ended=true
			for p,pdata in pairs(g.players) do
				if not p.Parent then continue end
				local score=pdata.tileCount*10
				g.ctx.saveScore(p, score)
				if g.ctx.sessions[p] then g.ctx.sessions[p].state="GAME_OVER" end
				g.ctx.GameStateChanged:FireClient(p,"GAME_OVER",{
					score=score, length=pdata.tileCount, level=1, gameType="FLOOD"
				})
			end
			task.delay(1,function() pcall(function() g.folder:Destroy() end) end)
			activeGame=nil
		end
	end)
	g.conn=conn
end

-- ── Public API ────────────────────────────────────────────────────────────────
function FloodGame.start(player, session, ctx)
	-- Join existing game if within the join window
	if activeGame and not activeGame.ended and activeGame.startTime then
		local age=tick()-activeGame.startTime
		if age < JOIN_WINDOW and not activeGame.players[player] then
			local g=activeGame
			spawnPlayer(g, player)
			local n=0; for _ in pairs(g.players) do n+=1 end
			ctx.GameStateChanged:FireClient(player,"PLAYING",{isMulti=true,playerCount=n,gameType="FLOOD"})
			session.cleanup=function()
				if g.players then g.players[player]=nil end
			end
			return
		end
	end

	-- Create new game
	local g=buildArena(ctx)
	activeGame=g
	spawnPlayer(g, player)
	local n=0; for _ in pairs(g.players) do n+=1 end
	ctx.GameStateChanged:FireClient(player,"PLAYING",{isMulti=false,playerCount=n,gameType="FLOOD"})
	startLoop(g)

	session.cleanup=function()
		if g.players then g.players[player]=nil end
		local rem=0; for _ in pairs(g.players) do rem+=1 end
		if rem==0 and not g.ended then
			g.ended=true
			if g.conn then g.conn:Disconnect() end
			pcall(function() g.folder:Destroy() end)
			if activeGame==g then activeGame=nil end
		end
	end
end

return FloodGame
