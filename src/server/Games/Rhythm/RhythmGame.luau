-- RhythmGame: Step on lit tiles in sequence
local RunService = game:GetService("RunService")

local RhythmGame = {}

local CENTER = Vector3.new(0, 1000, 600)
local TILE_COUNT = 16
local RING_R = 22
local NEON = Enum.Material.Neon
local SMOOTH = Enum.Material.SmoothPlastic

local COLORS = {
	Color3.fromRGB(255,50,200), Color3.fromRGB(0,220,255), Color3.fromRGB(57,255,20),
	Color3.fromRGB(255,200,0), Color3.fromRGB(160,0,255), Color3.fromRGB(255,80,0),
	Color3.fromRGB(0,255,150), Color3.fromRGB(255,50,100),
}

local function makePart(size, color, mat, pos)
	local p = Instance.new("Part")
	p.Size=size; p.Color=color; p.Material=mat
	p.Anchored=true; p.CanCollide=true; p.CastShadow=false
	p.Position=pos; p.Parent=workspace
	return p
end

function RhythmGame.start(player, session, ctx)
	local folder = Instance.new("Folder"); folder.Name="RhythmGame"; folder.Parent=workspace

	-- Floor
	local floor = makePart(Vector3.new(90,0.5,90), Color3.fromRGB(10,5,20), SMOOTH, CENTER)
	floor.Parent = folder

	-- DJ Booth center
	local booth = makePart(Vector3.new(8,4,8), Color3.fromRGB(20,10,40), SMOOTH, CENTER+Vector3.new(0,2,0))
	booth.Parent = folder
	local boothLight = Instance.new("PointLight"); boothLight.Color=Color3.fromRGB(255,50,200); boothLight.Range=50; boothLight.Brightness=4; boothLight.Parent=booth

	-- Tiles
	local tiles = {}
	for i = 1, TILE_COUNT do
		local angle = (i-1)/(TILE_COUNT)*math.pi*2
		local tx = CENTER.X + math.cos(angle)*RING_R
		local tz = CENTER.Z + math.sin(angle)*RING_R
		local col = COLORS[((i-1)%#COLORS)+1]
		local tile = makePart(Vector3.new(7,0.5,7), Color3.fromRGB(20,20,30), SMOOTH, Vector3.new(tx,CENTER.Y+0.5,tz))
		tile.Parent = folder
		table.insert(tiles, {part=tile, color=col, active=false})
	end

	-- Invisible boundary walls
	do local wh,sz=20,90
		for _,d in ipairs({
			{Vector3.new(sz+2,wh,1),Vector3.new(CENTER.X,CENTER.Y+wh/2,CENTER.Z-sz/2-0.5)},
			{Vector3.new(sz+2,wh,1),Vector3.new(CENTER.X,CENTER.Y+wh/2,CENTER.Z+sz/2+0.5)},
			{Vector3.new(1,wh,sz+2),Vector3.new(CENTER.X-sz/2-0.5,CENTER.Y+wh/2,CENTER.Z)},
			{Vector3.new(1,wh,sz+2),Vector3.new(CENTER.X+sz/2+0.5,CENTER.Y+wh/2,CENTER.Z)},
		}) do
			local w=makePart(d[1],Color3.new(0,0,0),SMOOTH,d[2]); w.Transparency=1; w.Parent=folder
		end
	end
	-- Spawn player
	local char = player.Character
	if char then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then hrp.Anchored=false; hrp.CFrame = CFrame.new(CENTER + Vector3.new(0,5,RING_R+10)) end
		for _, p in char:GetDescendants() do
			if p:IsA("BasePart") then p.Transparency=0; p.CanCollide=(p.Name~="HumanoidRootPart") end
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed=16; hum.JumpHeight=7.2 end
	end

	ctx.GameStateChanged:FireClient(player, "PLAYING", {isMulti=false, playerCount=1})

	local score = 0
	local combo = 0
	local startTime = tick()
	local GAME_DURATION = 60
	local currentTarget = nil
	local nextTargetTime = 0

	local function pickNextTile()
		local idx = math.random(1, #tiles)
		-- reset old
		if currentTarget then
			tiles[currentTarget].part.Color = Color3.fromRGB(20,20,30)
			tiles[currentTarget].part.Material = SMOOTH
		end
		currentTarget = idx
		tiles[idx].part.Color = tiles[idx].color
		tiles[idx].part.Material = NEON
		nextTargetTime = tick() + 2.5
	end
	pickNextTile()

	local checkConn
	checkConn = RunService.Heartbeat:Connect(function()
		local now = tick()
		if not ctx.sessions[player] or ctx.sessions[player].gameType ~= "RHYTHM" then
			checkConn:Disconnect(); return
		end
		-- timeout on tile
		if now >= nextTargetTime then
			combo = 0
			pickNextTile()
		end
		-- game over timer
		if now - startTime >= GAME_DURATION then
			checkConn:Disconnect()
			ctx.saveScore(player, score)
			if ctx.sessions[player] then ctx.sessions[player].state = "GAME_OVER" end
			ctx.GameStateChanged:FireClient(player, "GAME_OVER", {score=score, length=combo, level=1, gameType="RHYTHM"})
			return
		end
		-- check if player is on target tile
		if currentTarget then
			local char2 = player.Character
			if char2 then
				local hrp = char2:FindFirstChild("HumanoidRootPart")
				local tile = tiles[currentTarget]
				if hrp and tile then
					local dist = (hrp.Position - tile.part.Position)
					if math.abs(dist.X)<4 and math.abs(dist.Z)<4 and math.abs(dist.Y)<3 then
						combo += 1
						local pts = 10 * math.min(combo, 5)
						score += pts
						ctx.ScoreUpdated:FireClient(player, {score=score, comboCount=combo, comboMultiplier=math.min(combo,5)})
						pickNextTile()
					end
				end
			end
		end
	end)

	session.cleanup = function()
		checkConn:Disconnect()
		pcall(function() folder:Destroy() end)
	end
end

return RhythmGame
