-- HubGameManager: central orchestrator for all games (Snake + mini-games)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("SnakeGame"):WaitForChild("Config"))
local Workspace = game:GetService("Workspace")
local CharacterUtils = require(ServerScriptService:WaitForChild("SGH_Core"):WaitForChild("CharacterUtils"))
local ScoreService = require(ServerScriptService:WaitForChild("SGH_Core"):WaitForChild("ScoreService"))
local GameRegistry = require(ReplicatedStorage:WaitForChild("SGH"):WaitForChild("GameRegistry"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))

-- Build map first so OpenWorld exists before any game logic runs
local WorldPrompts
local buildOk, buildErr = pcall(function()
	WorldPrompts = WorldBuilder.Build()
end)
if not buildOk then
	warn("[SGH] WorldBuilder.Build() failed:", buildErr)
	WorldPrompts = {}
end

-- Fix spawn: remove default SpawnLocations (often at origin inside Snake arena) and create one at open world plaza
for _, obj in Workspace:GetChildren() do
	if obj:IsA("SpawnLocation") then
		obj:Destroy()
	end
end
local spawn = Instance.new("SpawnLocation")
spawn.Size = Vector3.new(6, 1, 6)
-- Sit the SpawnLocation on the plaza floor (y=0.5 top surface)
spawn.Position = Vector3.new(Config.CITY_SPAWN.X, 1, Config.CITY_SPAWN.Z)
spawn.Anchored = true
spawn.Transparency = 1
spawn.CanCollide = true
spawn.Neutral = true  -- must be true so all players can use it
spawn.Parent = Workspace

local Games = ServerScriptService:WaitForChild("Games")
local Snake = Games:WaitForChild("Snake")
local LeaderboardService = require(Snake:WaitForChild("LeaderboardService"))
local SnakeController = require(Snake:WaitForChild("SnakeController"))
local FoodManager = require(Snake:WaitForChild("FoodManager"))
local ObstacleManager = require(Snake:WaitForChild("ObstacleManager"))
local ScoreManagerMod = require(Snake:WaitForChild("ScoreManager"))

local LavaGame = require(Games:WaitForChild("Lava"):WaitForChild("LavaGame"))
local MazeGame = require(Games:WaitForChild("Maze"):WaitForChild("MazeGame"))
local RhythmGame = require(Games:WaitForChild("Rhythm"):WaitForChild("RhythmGame"))
local FloodGame = require(Games:WaitForChild("Flood"):WaitForChild("FloodGame"))
local AsteroidGame = require(Games:WaitForChild("Asteroid"):WaitForChild("AsteroidGame"))
local MiniGames = { LAVA = LavaGame, MAZE = MazeGame, RHYTHM = RhythmGame, FLOOD = FloodGame, ASTEROID = AsteroidGame }

-- Ensure Events exist (SnakeGame.Events — client expects this path)
local sgRS = ReplicatedStorage:WaitForChild("SnakeGame")
local ev = sgRS:FindFirstChild("Events") or Instance.new("Folder", sgRS)
ev.Name = "Events"
local function getOrMakeRE(name)
	return ev:FindFirstChild(name) or (function()
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = ev
		return r
	end)()
end
local function getOrMakeRF(name)
	return ev:FindFirstChild(name) or (function()
		local r = Instance.new("RemoteFunction")
		r.Name = name
		r.Parent = ev
		return r
	end)()
end

local GameStateChanged = getOrMakeRE("GameStateChanged")
local ScoreUpdated = getOrMakeRE("ScoreUpdated")
getOrMakeRE("PowerUpActivated"); getOrMakeRE("LobbyUpdate"); getOrMakeRE("PlayerEliminated")
getOrMakeRE("SpectateTarget"); getOrMakeRE("MultiRoundEnd")
local StartGameEvent = getOrMakeRE("StartGame")
local LevelUpdated = getOrMakeRE("LevelUpdated")
local DirectionInput = getOrMakeRE("DirectionInput")
local ReturnToWorld = getOrMakeRE("ReturnToWorld")
local StartMiniGameEvent = getOrMakeRE("StartMiniGame")
local GetLeaderboard = getOrMakeRF("GetLeaderboard")

GetLeaderboard.OnServerInvoke = function(player)
	local data = LeaderboardService.GetLeaderboard({ maxEntries = 10, forUserId = player.UserId })
	local entries = {}
	for _, e in ipairs(data.entries or {}) do
		table.insert(entries, {
			rank = e.rank, name = e.userName or e.name or "Player",
			score = e.score, isYou = (e.userId == player.UserId),
		})
	end
	return { entries = entries, playerRank = data.playerRank, playerBestScore = data.playerBestScore, totalCount = data.totalCount }
end

-- Sessions
local sessions = {}
local function getSession(player)
	if not sessions[player] then sessions[player] = { state = "OPEN_WORLD" } end
	return sessions[player]
end

local function hideCharacter(player)
	local s = getSession(player)
	local savedCF = CharacterUtils.Hide(player, true)
	if savedCF then s.savedCharCF = savedCF end
end

local function showCharacter(player, savedCF)
	-- Default spawn above the plaza floor so the character lands cleanly
	CharacterUtils.Show(player, savedCF, CFrame.new(Config.CITY_SPAWN.X, Config.CITY_SPAWN.Y + 3, Config.CITY_SPAWN.Z))
end

local function cleanupSession(player)
	local s = sessions[player]
	if not s then return end
	pcall(function() if s.snake then s.snake:cleanup() end end)
	pcall(function() if s.food then s.food:cleanup() end end)
	pcall(function() if s.obstacles then s.obstacles:cleanup() end end)
	pcall(function() if s.cleanup then s.cleanup() end end)
	sessions[player] = nil
end

Players.PlayerAdded:Connect(function(player)
	sessions[player] = { state = "OPEN_WORLD" }
	player.CharacterAdded:Connect(function(char)
		local s = sessions[player]
		if s and s.state == "OPEN_WORLD" then
			task.wait(1)  -- wait for character to fully load
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				-- Set Y above floor so character lands cleanly (floor is at y=0.5)
				hrp.Anchored = true
				hrp.CFrame = CFrame.new(Config.CITY_SPAWN.X, Config.CITY_SPAWN.Y + 3, Config.CITY_SPAWN.Z)
				hrp.Anchored = false
			end
		end
	end)
	task.wait(2)
	GameStateChanged:FireClient(player, "OPEN_WORLD")
end)
Players.PlayerRemoving:Connect(function(player) cleanupSession(player) end)

ReturnToWorld.OnServerEvent:Connect(function(player)
	local s = sessions[player]
	local savedCF = s and s.savedCharCF
	cleanupSession(player)
	sessions[player] = { state = "OPEN_WORLD" }
	showCharacter(player, savedCF)
	GameStateChanged:FireClient(player, "OPEN_WORLD")
end)

local function startSnakeGame(player)
	local s = getSession(player)
	s.state = "COUNTDOWN"
	s.gameType = "SNAKE"
	hideCharacter(player)
	GameStateChanged:FireClient(player, "COUNTDOWN", { gameType = "SNAKE" })
	task.wait(3.5)
	if sessions[player] ~= s then return end

	local scoreMgr = ScoreManagerMod.new()
	scoreMgr:reset(player)
	local food = FoodManager.new()
	local obstacles = ObstacleManager.new()
	local snake = SnakeController.new(player, Config.SNAKE_STYLES[s.styleIndex or 1])
	s.snake = snake
	s.food = food
	s.obstacles = obstacles
	s.scoreMgr = scoreMgr
	s.state = "PLAYING"
	s.level = 1
	s.timeInLevel = 0

	snake:spawn()
	food:spawn(Config.FOOD_COUNT)
	obstacles:spawn(Config.INITIAL_OBSTACLES)
	GameStateChanged:FireClient(player, "PLAYING", { isMulti = false, playerCount = 1, gameType = "SNAKE" })

	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if sessions[player] ~= s or s.state ~= "PLAYING" then conn:Disconnect(); return end
		local alive, hitFood, foodType = snake:tick(dt, food, obstacles)
		if not alive then
			conn:Disconnect()
			local finalScore = scoreMgr.score
			local finalLength = snake:length()
			scoreMgr:submitHighScore(player)
			LeaderboardService.SubmitScore(player.UserId, player.Name, finalScore)
			ScoreService.Submit(player, finalScore, "SNAKE")
			pcall(function() snake:cleanup() end)
			s.state = "GAME_OVER"
			GameStateChanged:FireClient(player, "GAME_OVER", { score = finalScore, length = finalLength, level = s.level })
			return
		end
		if hitFood then
			scoreMgr:addScore(foodType and foodType.score or 10)
			food:respawnOne(hitFood)
		end
		s.timeInLevel += dt
		local dur = Config.LEVEL_UP_INTERVAL
		if s.timeInLevel >= dur then
			s.timeInLevel -= dur
			s.level += 1
			snake:setSpeedLevel(s.level)
			obstacles:spawnBatch(Config.OBSTACLES_PER_LEVEL)
		end
		LevelUpdated:FireClient(player, { level = s.level, timeInLevel = s.timeInLevel, levelDuration = dur })
	end)
end

StartGameEvent.OnServerEvent:Connect(function(player, styleIndex, mode)
	local s = getSession(player)
	if s.state ~= "IDLE" and s.state ~= "GAME_OVER" then return end
	local si = tonumber(styleIndex) or 1
	local savedCF = s.savedCharCF
	cleanupSession(player)
	sessions[player] = { state = "IDLE", styleIndex = si, savedCharCF = savedCF }
	startSnakeGame(player)
end)
DirectionInput.OnServerEvent:Connect(function(player, dir)
	local s = sessions[player]
	if s and s.snake then s.snake:setDirection(dir) end
end)

local ctx = {
	GameStateChanged = GameStateChanged,
	ScoreUpdated = ScoreUpdated,
	LevelUpdated = LevelUpdated,
	saveScore = function(p, sc)
		local s = sessions[p]
		local gkey = s and s.gameType
		LeaderboardService.SubmitScore(p.UserId, p.Name, sc)
		ScoreService.Submit(p, sc, gkey)
	end,
	showCharacter = showCharacter,
	sessions = sessions,
	GameRegistry = GameRegistry,
}

local function startMiniGame(player, key, skipHide)
	local s = getSession(player)
	if not skipHide then
		hideCharacter(player)
	else
		CharacterUtils.HideWithoutSaving(player)
	end
	s.state = "PLAYING"
	s.gameType = key
	local mod = MiniGames[key]
	if mod then mod.start(player, s, ctx) end
end

StartMiniGameEvent.OnServerEvent:Connect(function(player, key)
	local s = getSession(player)
	if s.state ~= "GAME_OVER" then return end
	if not MiniGames[key] then return end
	local savedCF = s.savedCharCF
	cleanupSession(player)
	sessions[player] = { state = "OPEN_WORLD", savedCharCF = savedCF }
	startMiniGame(player, key, true)
end)

task.spawn(function()
	local prompts = WorldPrompts
	if prompts and prompts.SNAKE then
		prompts.SNAKE.Triggered:Connect(function(player)
			local s = getSession(player)
			if s.state ~= "OPEN_WORLD" then return end
			-- Save position so BACK TO WORLD returns the player near the kiosk
			local char = player.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp then s.savedCharCF = hrp.CFrame end
			end
			s.state = "IDLE"
			GameStateChanged:FireClient(player, "IDLE")
		end)
	end
	for _, g in GameRegistry.GetAll() do
		local key = g.key
		if key ~= "SNAKE" and MiniGames[key] and prompts then
			local p = prompts[key]
			if p then
				local k = key
				p.Triggered:Connect(function(player)
					local s = getSession(player)
					if s.state ~= "OPEN_WORLD" then return end
					startMiniGame(player, k)
				end)
			end
		end
	end
end)

task.spawn(function()
	local DragonFlight = require(Games:WaitForChild("DragonFlight"):WaitForChild("DragonFlight"))
	DragonFlight.Start()
end)

print("[SGH] HubGameManager loaded — ", #GameRegistry.GetAll(), "games registered")
