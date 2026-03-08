-- GameManager
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("SnakeGame"):WaitForChild("Config"))

-- Ensure Events exist
local sgRS = ReplicatedStorage:WaitForChild("SnakeGame")
local ev = sgRS:FindFirstChild("Events") or Instance.new("Folder", sgRS)
ev.Name = "Events"
local function getOrMakeRE(name)
	return ev:FindFirstChild(name) or (function() local r=Instance.new("RemoteEvent"); r.Name=name; r.Parent=ev; return r end)()
end
local function getOrMakeRF(name)
	return ev:FindFirstChild(name) or (function() local r=Instance.new("RemoteFunction"); r.Name=name; r.Parent=ev; return r end)()
end
local GameStateChanged = getOrMakeRE("GameStateChanged")
local ScoreUpdated     = getOrMakeRE("ScoreUpdated")
getOrMakeRE("PowerUpActivated"); getOrMakeRE("LobbyUpdate"); getOrMakeRE("PlayerEliminated")
getOrMakeRE("SpectateTarget"); getOrMakeRE("MultiRoundEnd")
local StartGameEvent   = getOrMakeRE("StartGame")
local LevelUpdated     = getOrMakeRE("LevelUpdated")
local DirectionInput   = getOrMakeRE("DirectionInput")
local ReturnToWorld    = getOrMakeRE("ReturnToWorld")
local StartMiniGameEvent = getOrMakeRE("StartMiniGame")
local GetLeaderboard   = getOrMakeRF("GetLeaderboard")

-- Legacy per-game leaderboard (snake scores + history)
local LeaderboardService = require(script.Parent:WaitForChild("LeaderboardService"))
-- SGH unified scoring (hub totals + per-game best, persisted via DataStore)
local ScoreService   = require(script.Parent.Parent:WaitForChild("SGH_Core"):WaitForChild("ScoreService"))
local GameRegistry   = require(game:GetService("ReplicatedStorage"):WaitForChild("SGH"):WaitForChild("GameRegistry"))

GetLeaderboard.OnServerInvoke = function(player)
	local data = LeaderboardService.GetLeaderboard({maxEntries=10, forUserId=player.UserId})
	-- Remap userName -> name for UIController compatibility
	local entries = {}
	for _, e in ipairs(data.entries or {}) do
		table.insert(entries, {
			rank = e.rank, name = e.userName or e.name or "Player",
			score = e.score, isYou = (e.userId == player.UserId)
		})
	end
	return {entries=entries, playerRank=data.playerRank, playerBestScore=data.playerBestScore, totalCount=data.totalCount}
end

-- Sessions
local sessions = {}
local function getSession(player)
	if not sessions[player] then sessions[player] = {state="OPEN_WORLD"} end
	return sessions[player]
end

-- hideCharacter: anchor HRP so it doesn't fall and auto-respawn
local function hideCharacter(player)
	local char = player.Character; if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local s = getSession(player)
	if hrp then
		-- Only save if character is in the real world (Y > -10), not already hidden
		if hrp.Position.Y > -10 then
			s.savedCharCF = hrp.CFrame
		end
		hrp.Anchored = true
		hrp.CFrame = CFrame.new(0, -100, 0)
	end
	for _, p in char:GetDescendants() do
		if p:IsA("BasePart") then p.Transparency=1; p.CanCollide=false end
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed=0; hum.JumpHeight=0 end
end

-- showCharacter: restore HRP and un-anchor
local function showCharacter(player, savedCF)
	local char = player.Character
	if not char then
		player:LoadCharacter(); task.wait(1)
		char = player.Character; if not char then return end
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local cf = savedCF or CFrame.new(Config.CITY_SPAWN)
	if hrp then
		hrp.Anchored = true   -- anchor first so physics can't pull during teleport
		hrp.CFrame = cf
		hrp.Anchored = false
	end
	for _, p in char:GetDescendants() do
		if p:IsA("BasePart") then
			p.Transparency = 0
			p.CanCollide = (p.Name ~= "HumanoidRootPart")
		end
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.Health=hum.MaxHealth; hum.WalkSpeed=16; hum.JumpHeight=7.2 end
end

local function cleanupSession(player)
	local s = sessions[player]; if not s then return end
	pcall(function() if s.snake     then s.snake:cleanup()     end end)
	pcall(function() if s.food      then s.food:cleanup()      end end)
	pcall(function() if s.obstacles then s.obstacles:cleanup() end end)
	pcall(function() if s.cleanup   then s.cleanup()           end end)
	sessions[player] = nil
end

Players.PlayerAdded:Connect(function(player)
	sessions[player] = {state="OPEN_WORLD"}
	player.CharacterAdded:Connect(function(char)
		local s = sessions[player]
		if s and s.state == "OPEN_WORLD" then
			task.wait(0.5)
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then hrp.CFrame = CFrame.new(Config.CITY_SPAWN) end
		end
	end)
	task.wait(2); GameStateChanged:FireClient(player, "OPEN_WORLD")
end)
Players.PlayerRemoving:Connect(function(player) cleanupSession(player) end)

ReturnToWorld.OnServerEvent:Connect(function(player)
	local s = sessions[player]; local savedCF = s and s.savedCharCF
	cleanupSession(player); sessions[player] = {state="OPEN_WORLD"}
	showCharacter(player, savedCF)
	GameStateChanged:FireClient(player, "OPEN_WORLD")
end)

-- Snake game
local SnakeController  = require(script.Parent:WaitForChild("SnakeController"))
local FoodManager      = require(script.Parent:WaitForChild("FoodManager"))
local ObstacleManager  = require(script.Parent:WaitForChild("ObstacleManager"))
local ScoreManagerMod  = require(script.Parent:WaitForChild("ScoreManager"))

local function startSnakeGame(player)
	local s = getSession(player); s.state="COUNTDOWN"; s.gameType="SNAKE"
	hideCharacter(player); GameStateChanged:FireClient(player,"COUNTDOWN",{gameType="SNAKE"})
	task.wait(3.5); if sessions[player] ~= s then return end

	local scoreMgr = ScoreManagerMod.new(); scoreMgr:reset(player)
	local food = FoodManager.new(); local obstacles = ObstacleManager.new()
	local snake = SnakeController.new(player, Config.SNAKE_STYLES[s.styleIndex or 1])
	s.snake=snake; s.food=food; s.obstacles=obstacles; s.scoreMgr=scoreMgr
	s.state="PLAYING"; s.level=1; s.timeInLevel=0

	snake:spawn(); food:spawn(Config.FOOD_COUNT); obstacles:spawn(Config.INITIAL_OBSTACLES)
	GameStateChanged:FireClient(player,"PLAYING",{isMulti=false,playerCount=1,gameType="SNAKE"})

	local conn; conn = RunService.Heartbeat:Connect(function(dt)
		if sessions[player]~=s or s.state~="PLAYING" then conn:Disconnect(); return end
		local alive,hitFood,foodType = snake:tick(dt,food,obstacles)
		if not alive then
			conn:Disconnect()
			local finalScore = scoreMgr.score
			local finalLength = snake:length()     -- capture before cleanup
			scoreMgr:submitHighScore(player)
			LeaderboardService.SubmitScore(player.UserId, player.Name, finalScore)
			ScoreService.Submit(player, finalScore, "SNAKE")
			pcall(function() snake:cleanup() end)  -- remove dead snake segments immediately
			s.state="GAME_OVER"
			GameStateChanged:FireClient(player,"GAME_OVER",{score=finalScore,length=finalLength,level=s.level})
			return
		end
		if hitFood then
			scoreMgr:addScore(foodType and foodType.score or 10)
			food:respawnOne(hitFood)
		end
		s.timeInLevel += dt; local dur = Config.LEVEL_UP_INTERVAL
		if s.timeInLevel >= dur then
			s.timeInLevel -= dur; s.level += 1
			snake:setSpeedLevel(s.level); obstacles:spawnBatch(Config.OBSTACLES_PER_LEVEL)
		end
		LevelUpdated:FireClient(player,{level=s.level,timeInLevel=s.timeInLevel,levelDuration=dur})
	end)
end

-- Client sends (styleIndex, mode) per UIController line 256
StartGameEvent.OnServerEvent:Connect(function(player, styleIndex, mode)
	local s = getSession(player)
	-- Allow starting from IDLE (kiosk) or replaying from GAME_OVER
	if s.state ~= "IDLE" and s.state ~= "GAME_OVER" then return end
	local si = tonumber(styleIndex) or 1
	local savedCF = s.savedCharCF                      -- preserve across session reset
	cleanupSession(player)                             -- destroy old snake/food/obstacles
	sessions[player] = {state="IDLE", styleIndex=si, savedCharCF=savedCF}
	startSnakeGame(player)
end)
DirectionInput.OnServerEvent:Connect(function(player,dir)
	local s = sessions[player]; if s and s.snake then s.snake:setDirection(dir) end
end)
-- Mini-games
local LavaGame     = require(script.Parent:WaitForChild("LavaGame"))
local MazeGame     = require(script.Parent:WaitForChild("MazeGame"))
local RhythmGame   = require(script.Parent:WaitForChild("RhythmGame"))
local FloodGame    = require(script.Parent:WaitForChild("FloodGame"))
local AsteroidGame = require(script.Parent:WaitForChild("AsteroidGame"))
local MiniGames = {LAVA=LavaGame,MAZE=MazeGame,RHYTHM=RhythmGame,FLOOD=FloodGame,ASTEROID=AsteroidGame}
local ctx = {GameStateChanged=GameStateChanged,ScoreUpdated=ScoreUpdated,LevelUpdated=LevelUpdated,
	saveScore=function(p,sc)
		local s = sessions[p]; local gkey = s and s.gameType
		LeaderboardService.SubmitScore(p.UserId, p.Name, sc)
		ScoreService.Submit(p, sc, gkey)
	end,
	showCharacter=showCharacter, sessions=sessions, GameRegistry=GameRegistry}

local function startMiniGame(player, key, skipHide)
	local s = getSession(player)
	if not skipHide then
		hideCharacter(player)  -- saves savedCharCF from open-world position
	else
		-- Replay: hide without overwriting saved open-world position
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then hrp.Anchored=true; hrp.CFrame=CFrame.new(0,-100,0) end
			for _,p in char:GetDescendants() do
				if p:IsA("BasePart") then p.Transparency=1; p.CanCollide=false end
			end
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then hum.WalkSpeed=0; hum.JumpHeight=0 end
		end
	end
	s.state="PLAYING"; s.gameType=key
	local mod = MiniGames[key]; if mod then mod.start(player,s,ctx) end
end

StartMiniGameEvent.OnServerEvent:Connect(function(player, key)
	local s = getSession(player)
	if s.state ~= "GAME_OVER" then return end
	if not MiniGames[key] then return end
	local savedCF = s.savedCharCF
	cleanupSession(player)
	sessions[player] = {state="OPEN_WORLD", savedCharCF=savedCF}
	startMiniGame(player, key, true)
end)

local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
task.spawn(function()
	local prompts = WorldBuilder.Build()
	if prompts.SNAKE then
		prompts.SNAKE.Triggered:Connect(function(player)
			local s = getSession(player); if s.state~="OPEN_WORLD" then return end
			s.state="IDLE"; GameStateChanged:FireClient(player,"IDLE")
		end)
	end
	for _, key in {"LAVA","MAZE","RHYTHM","FLOOD","ASTEROID"} do
		local p = prompts[key]
		if p then
			local k=key; p.Triggered:Connect(function(player)
				local s = getSession(player); if s.state~="OPEN_WORLD" then return end
				startMiniGame(player,k)
			end)
		end
	end
end)
task.spawn(function()
	local DragonFlight = require(script.Parent:WaitForChild("DragonFlight"))
	DragonFlight.Start()
end)
print("[SGH] GameManager loaded — ", #GameRegistry.GetAll(), "games registered")
