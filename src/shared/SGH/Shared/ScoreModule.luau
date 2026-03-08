-- ScoreModule: per-player score tracking for mini-games
local ScoreModule = {}
ScoreModule.__index = ScoreModule

function ScoreModule.new()
	local self = setmetatable({}, ScoreModule)
	self._scores = {}
	return self
end

function ScoreModule:Reset(player)
	self._scores[player] = 0
end

function ScoreModule:Add(player, points)
	self._scores[player] = (self._scores[player] or 0) + math.max(0, points)
end

function ScoreModule:Get(player)
	return self._scores[player] or 0
end

-- callback(player, score) called for each tracked player
function ScoreModule:Submit(callback)
	for player, score in pairs(self._scores) do
		pcall(callback, player, score)
	end
end

return ScoreModule
