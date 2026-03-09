-- AsteroidGame: Dodge and tag incoming neon asteroids
local RunService = game:GetService("RunService")

local AsteroidGame = {}

local CENTER = Vector3.new(-600, 1000, 0)
local ARENA_R = 35
local NEON = Enum.Material.Neon
local SMOOTH = Enum.Material.SmoothPlastic
local GAME_DURATION = 60

local ASTEROID_COLORS = {
	Color3.fromRGB(0, 200, 255), Color3.fromRGB(255, 80, 0),
	Color3.fromRGB(160, 0, 255), Color3.fromRGB(57, 255, 20),
}

local function makePart(size, color, mat, pos)
	local p = Instance.new("Part")
	p.Size=size; p.Color=color; p.Material=mat
	p.Anchored=false; p.CanCollide=true; p.CastShadow=false
	p.Position=pos; p.Parent=workspace
	return p
end

function AsteroidGame.start(player, session, ctx)
	local folder = Instance.new("Folder"); folder.Name="AsteroidGame"; folder.Parent=workspace

	-- Starfield backdrop (static dots)
	for _ = 1, 40 do
		local star = Instance.new("Part")
		star.Size = Vector3.new(0.3,0.3,0.3)
		star.Shape = Enum.PartType.Ball
		star.Color = Color3.fromRGB(200,220,255)
		star.Material = NEON
		star.Anchored = true
		star.CanCollide = false
		star.CastShadow = false
		star.Position = CENTER + Vector3.new(
			math.random(-50,50), math.random(5,40), math.random(-50,50))
		star.Parent = folder
	end

	-- Arena floor and boundary walls
	local floor = Instance.new("Part")
	floor.Size=Vector3.new(ARENA_R*2+20,1,ARENA_R*2+20); floor.Color=Color3.fromRGB(8,8,20); floor.Material=SMOOTH
	floor.Anchored=true; floor.CanCollide=true; floor.CastShadow=false; floor.Position=CENTER; floor.Parent=folder
	for _,d in ipairs({
		{Vector3.new(ARENA_R*2+22,30,1),CENTER+Vector3.new(0,15,-ARENA_R-11)},
		{Vector3.new(ARENA_R*2+22,30,1),CENTER+Vector3.new(0,15,ARENA_R+11)},
		{Vector3.new(1,30,ARENA_R*2+22),CENTER+Vector3.new(-ARENA_R-11,15,0)},
		{Vector3.new(1,30,ARENA_R*2+22),CENTER+Vector3.new(ARENA_R+11,15,0)},
	}) do
		local w=Instance.new("Part"); w.Size=d[1]; w.Anchored=true; w.CanCollide=true
		w.Transparency=1; w.CastShadow=false; w.Position=d[2]; w.Parent=folder
	end
	-- Spawn player
	local char = player.Character
	if char then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then hrp.Anchored=false; hrp.CFrame = CFrame.new(CENTER + Vector3.new(0,3,0)) end
		for _, p in char:GetDescendants() do
			if p:IsA("BasePart") then p.Transparency=0; p.CanCollide=(p.Name~="HumanoidRootPart") end
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed=16; hum.JumpHeight=7.2 end
	end

	ctx.GameStateChanged:FireClient(player, "PLAYING", {isMulti=false, playerCount=1})

	local score = 0
	local startTime = tick()
	local asteroids = {}
	local spawnInterval = 2.5
	local lastSpawn = tick()
	local touched = {}

	local function spawnAsteroid()
		local angle = math.random()*math.pi*2
		local spawnPos = CENTER + Vector3.new(math.cos(angle)*ARENA_R*1.5, math.random(2,15), math.sin(angle)*ARENA_R*1.5)
		local color = ASTEROID_COLORS[math.random(#ASTEROID_COLORS)]
		local sz = math.random(15,35)/10
		local ast = makePart(Vector3.new(sz,sz,sz), color, NEON, spawnPos)
		ast.Shape = Enum.PartType.Ball
		ast.Parent = folder
		-- velocity toward center
		local vel = (CENTER - spawnPos).Unit * (18 + score/100)
		ast.AssemblyLinearVelocity = vel
		local light = Instance.new("PointLight"); light.Color=color; light.Range=15; light.Brightness=3; light.Parent=ast
		table.insert(asteroids, ast)
		-- touch detection
		ast.Touched:Connect(function(hit)
			if touched[ast] then return end
			local ch = hit.Parent
			if ch == player.Character then
				touched[ast] = true
				score += 25
				ctx.ScoreUpdated:FireClient(player, {score=score, comboCount=1, comboMultiplier=1})
				ast:Destroy()
			end
		end)
		-- auto-destroy after 8 seconds
		task.delay(8, function() pcall(function() ast:Destroy() end) end)
	end

	local checkConn
	checkConn = RunService.Heartbeat:Connect(function()
		if not ctx.sessions[player] or ctx.sessions[player].gameType ~= "ASTEROID" then
			checkConn:Disconnect(); return
		end
		local now = tick()
		-- spawn asteroids
		if now - lastSpawn >= spawnInterval then
			lastSpawn = now
			spawnInterval = math.max(0.8, spawnInterval - 0.05)
			spawnAsteroid()
		end
		-- game over timer
		if now - startTime >= GAME_DURATION then
			checkConn:Disconnect()
			ctx.saveScore(player, score)
			if ctx.sessions[player] then ctx.sessions[player].state = "GAME_OVER" end
			ctx.GameStateChanged:FireClient(player, "GAME_OVER", {score=score, length=1, level=1, gameType="ASTEROID"})
		end
	end)

	session.cleanup = function()
		checkConn:Disconnect()
		pcall(function() folder:Destroy() end)
	end
end

return AsteroidGame
