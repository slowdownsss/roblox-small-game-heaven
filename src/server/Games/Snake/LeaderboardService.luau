--[[
  LeaderboardService (ModuleScript) — ServerScriptService.SnakeGame.LeaderboardService

  Stores ALL historical scores (every game session) and ranks across ALL players.
  - OrderedDataStore: best score per player (for quick top-N and "your rank").
  - DataStore: rolling history of every score (all players, single + multiplayer).
  Display: one global leaderboard ranking every score from every session.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

-- Keys and limits (Roblox: value max 4MB; keep history under ~1MB for safety)
local ORDERED_STORE_NAME = "SnakeHighScores_v1"   -- best score per player
local HISTORY_STORE_NAME = "SnakeScoreHistory_v1"
local HISTORY_KEY = "RecentScores"
local MAX_HISTORY_ENTRIES = 2000   -- last N scores across all players
local RETRY_COUNT = 3
local RETRY_DELAY = 1

local orderedStore = DataStoreService:GetOrderedDataStore(ORDERED_STORE_NAME)
local historyStore = DataStoreService:GetDataStore(HISTORY_STORE_NAME)

local function retryAsync(fn)
	for attempt = 1, RETRY_COUNT do
		local ok, result = pcall(fn)
		if ok then return result end
		if attempt < RETRY_COUNT then
			task.wait(RETRY_DELAY)
		else
			warn("[LeaderboardService] Failed after retries:", result)
			return nil
		end
	end
	return nil
end

-- Submit one score (call on game over for each player who played).
local function submitScore(userId, userName, score)
	if type(userId) ~= "number" or type(score) ~= "number" or score < 0 then
		return false
	end
	local key = tostring(userId)

	local scoreInt = math.floor(score)
	retryAsync(function()
		local current = orderedStore:GetAsync(key)
		if current == nil or scoreInt > current then
			orderedStore:SetAsync(key, scoreInt)
		end
	end)

	local entry = {
		userId = userId,
		userName = userName or ("Player_" .. userId),
		score = score,
		time = os.time(),
	}
	local historyOk = retryAsync(function()
		local raw = historyStore:GetAsync(HISTORY_KEY)
		local list = (type(raw) == "table" and raw.list) or {}
		table.insert(list, entry)
		while #list > MAX_HISTORY_ENTRIES do
			table.remove(list, 1)
		end
		historyStore:SetAsync(HISTORY_KEY, { list = list })
	end)
	return historyOk ~= nil
end

local function getLeaderboard(options)
	options = options or {}
	local maxEntries = math.min(tonumber(options.maxEntries) or 10, 500)
	local forUserId = options.forUserId

	local raw = retryAsync(function()
		return historyStore:GetAsync(HISTORY_KEY)
	end)
	local historyList = (raw and type(raw.list) == "table") and raw.list or {}

	local orderedEntries = {}
	local pages = retryAsync(function()
		return orderedStore:GetSortedAsync(false, 100)
	end)
	if pages then
		local ok2, page = pcall(function() return pages:GetCurrentPage() end)
		if ok2 and page then
			for _, data in ipairs(page) do
				local userId = tonumber(data.key)
				if userId then
					local name = "Player_" .. data.key
					local p = Players:GetPlayerByUserId(userId)
					if p then
						name = p.Name
					else
						local nameOk, n = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
						if nameOk and n then name = n end
					end
					table.insert(orderedEntries, {
						userId = userId,
						userName = name,
						score = data.value,
						time = 0,
					})
				end
			end
		end
	end

	local seen = {}
	for _, e in ipairs(historyList) do
		local key = tostring(e.userId) .. "_" .. tostring(math.floor(e.score))
		seen[key] = true
	end
	for _, e in ipairs(orderedEntries) do
		local key = tostring(e.userId) .. "_" .. tostring(math.floor(e.score))
		if not seen[key] then
			table.insert(historyList, e)
			seen[key] = true
		end
	end

	table.sort(historyList, function(a, b)
		if a.score ~= b.score then return a.score > b.score end
		return (a.time or 0) > (b.time or 0)
	end)

	local totalCount = #historyList
	local entries = {}
	local playerRank = nil
	local playerBestScore = nil
	for i = 1, #historyList do
		local e = historyList[i]
		if i <= maxEntries then
			entries[i] = {
				rank = i,
				userId = e.userId,
				userName = e.userName or ("Player_" .. tostring(e.userId)),
				score = e.score,
				time = e.time,
			}
		end
		if forUserId and e.userId == forUserId and playerRank == nil then
			playerRank = i
			playerBestScore = e.score
		end
	end
	return { totalCount = totalCount, entries = entries, playerRank = playerRank, playerBestScore = playerBestScore }
end

local function getTopBestScores(pageSize)
	pageSize = math.min(tonumber(pageSize) or 10, 100)
	local pages = retryAsync(function()
		return orderedStore:GetSortedAsync(false, pageSize)
	end)
	if not pages then
		warn("[LeaderboardService] GetSortedAsync returned nil")
		return {}
	end
	local ok2, page = pcall(function() return pages:GetCurrentPage() end)
	if not ok2 or not page then
		warn("[LeaderboardService] GetCurrentPage failed")
		return {}
	end
	local results = {}
	for rank, data in ipairs(page) do
		local userId = tonumber(data.key)
		local score = data.value
		local name = "Player_" .. data.key
		if userId then
			local p = Players:GetPlayerByUserId(userId)
			if p then
				name = p.Name
			else
				local nameOk, n = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
				if nameOk and n then name = n end
			end
		end
		table.insert(results, { rank = rank, userId = userId, userName = name, score = score })
	end
	print("[LeaderboardService] GetTopBestScores returned", #results, "entries")
	return results
end

local function getPlayerBest(userId)
	local key = tostring(userId)
	local best = retryAsync(function()
		return orderedStore:GetAsync(key)
	end)
	if best == nil then return nil, nil end
	local pages = retryAsync(function()
		return orderedStore:GetSortedAsync(false, 100)
	end)
	if not pages then return best, nil end
	local page = pages:GetCurrentPage()
	for rank, data in ipairs(page) do
		if data.key == key then
			return best, rank
		end
	end
	return best, nil
end

return {
	SubmitScore = submitScore,
	GetLeaderboard = getLeaderboard,
	GetTopBestScores = getTopBestScores,
	GetPlayerBest = getPlayerBest,
}
