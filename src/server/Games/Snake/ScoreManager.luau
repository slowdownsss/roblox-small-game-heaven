local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Config = require(ReplicatedStorage:WaitForChild("SnakeGame"):WaitForChild("Config"))

-- Lazy lookup: Events folder is created by HubGameManager after all modules are required.
-- Looking it up at module load time causes a deadlock, so we find it on first use instead.
local _scoreUpdatedEvent
local function getScoreUpdatedEvent()
	if not _scoreUpdatedEvent then
		local ev = ReplicatedStorage:FindFirstChild("SnakeGame")
		ev = ev and ev:FindFirstChild("Events")
		_scoreUpdatedEvent = ev and ev:FindFirstChild("ScoreUpdated")
	end
	return _scoreUpdatedEvent
end

local ScoreManager = {}
ScoreManager.__index = ScoreManager

function ScoreManager.new()
	local self = setmetatable({}, ScoreManager)
	self.score = 0
	self.comboCount = 0
	self.comboMultiplier = 1.0
	self.lastPickupTime = 0
	self.player = nil
	return self
end

function ScoreManager:reset(player)
	self.score = 0
	self.comboCount = 0
	self.comboMultiplier = 1.0
	self.lastPickupTime = 0
	self.player = player
	self:_fireUpdate()
end

function ScoreManager:addScore(basePoints)
	local now = tick()
	if now - self.lastPickupTime < Config.COMBO_WINDOW then
		self.comboCount += 1
		self.comboMultiplier = math.min(
			1 + self.comboCount * Config.COMBO_MULTIPLIER_INCREMENT,
			Config.MAX_COMBO_MULTIPLIER
		)
	else
		self.comboCount = 0
		self.comboMultiplier = 1.0
	end
	self.lastPickupTime = now

	local points = math.floor(basePoints * self.comboMultiplier)
	self.score += points

	self:_fireUpdate()

	return points, self.comboCount, self.comboMultiplier
end

function ScoreManager:_fireUpdate()
	if self.player then
		local ev = getScoreUpdatedEvent()
		if ev then
			ev:FireClient(self.player, {
				score = self.score,
				comboCount = self.comboCount,
				comboMultiplier = self.comboMultiplier,
			})
		end
	end
end

function ScoreManager:submitHighScore(player)
	pcall(function()
		local store = DataStoreService:GetOrderedDataStore("SnakeHighScores_v1")
		local currentBest = 0
		pcall(function()
			currentBest = store:GetAsync(tostring(player.UserId)) or 0
		end)
		if self.score > currentBest then
			store:SetAsync(tostring(player.UserId), self.score)
		end
	end)
end

function ScoreManager:getLeaderboard()
	local entries = {}
	pcall(function()
		local store = DataStoreService:GetOrderedDataStore("SnakeHighScores_v1")
		local pages = store:GetSortedAsync(false, 10)
		local data = pages:GetCurrentPage()
		for rank, entry in data do
			table.insert(entries, {
				rank = rank,
				userId = entry.key,
				score = entry.value,
			})
		end
	end)
	return entries
end

return ScoreManager
