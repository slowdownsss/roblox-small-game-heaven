local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Config = require(ReplicatedStorage:WaitForChild("SnakeGame"):WaitForChild("Config"))
local Events = ReplicatedStorage:WaitForChild("SnakeGame"):WaitForChild("Events")
local ScoreUpdatedEvent = Events:WaitForChild("ScoreUpdated")

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
		ScoreUpdatedEvent:FireClient(self.player, {
			score = self.score,
			comboCount = self.comboCount,
			comboMultiplier = self.comboMultiplier,
		})
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
