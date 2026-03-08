-- ScoreService v1  |  ServerScriptService.SGH_Core.ScoreService
-- Unified persistent scoring for SmallGameHeaven.
-- ALL game score writes route through here — no game script calls DataStore directly.
--
-- DataStore layout:
--   SGH_Players_v1  / "p_{userId}"     → { hub=N, ts=epoch }  (standard DS)
--   SGH_Hub_v1      / "{userId}"       → hubTotal              (ordered DS)
--   SGH_Game_{key}_v1 / "{userId}"     → bestScore per game    (ordered DS)

local DataStoreService  = game:GetService("DataStoreService")
local Players           = game:GetService("Players")

local HubStore    = DataStoreService:GetOrderedDataStore("SGH_Hub_v1")
local PlayerStore = DataStoreService:GetDataStore("SGH_Players_v1")

local gameStoreCache = {}
local function gameStore(key)
	if not gameStoreCache[key] then
		gameStoreCache[key] = DataStoreService:GetOrderedDataStore("SGH_Game_"..key.."_v1")
	end
	return gameStoreCache[key]
end

-- Retry wrapper (max 3 attempts, exponential backoff)
local function try(fn)
	for i = 1, 3 do
		local ok, r = pcall(fn)
		if ok then return r end
		warn("[ScoreService] DS attempt "..i.." failed: "..tostring(r))
		if i < 3 then task.wait(2 ^ i) end
	end
end

-- In-memory hub score cache (server-authoritative)
local cache = {}   -- [userId] = hubTotal

local function load(player)
	local data = try(function()
		return PlayerStore:GetAsync("p_"..player.UserId)
	end)
	cache[player.UserId] = (data and data.hub) or 0
end

local function flush(player)
	local score = cache[player.UserId] or 0
	try(function()
		PlayerStore:SetAsync("p_"..player.UserId, { hub=score, ts=os.time() })
	end)
	try(function()
		HubStore:SetAsync(tostring(player.UserId), score)
	end)
end

-- ── Public API ──────────────────────────────────────────────────────────────────
local ScoreService = {}

-- Returns the player's cached hub total (0 if not yet loaded).
function ScoreService.GetHub(player)
	return cache[player.UserId] or 0
end

-- Called by GameManager after each session ends.
function ScoreService.Submit(player, points, gameKey)
	points = math.max(0, math.floor(points or 0))
	cache[player.UserId] = (cache[player.UserId] or 0) + points
	flush(player)
	if gameKey then
		local prev = try(function()
			return gameStore(gameKey):GetAsync(tostring(player.UserId))
		end) or 0
		if points > prev then
			try(function()
				gameStore(gameKey):SetAsync(tostring(player.UserId), points)
			end)
		end
	end
	print(("[ScoreService] %s +%d pts (%s) → hub=%d"):format(
		player.Name, points, gameKey or "?", cache[player.UserId]))
end

-- Returns top-N hub leaderboard: { rank, userId, name, score }
function ScoreService.GetHubLeaderboard(n)
	n = math.min(n or 10, 100)
	local pages = try(function() return HubStore:GetSortedAsync(false, n) end)
	if not pages then return {} end
	local ok, pg = pcall(function() return pages:GetCurrentPage() end)
	if not ok then return {} end
	local out = {}
	for rank, e in ipairs(pg) do
		local uid  = tonumber(e.key)
		local name = "Player"
		pcall(function() name = Players:GetNameFromUserIdAsync(uid) end)
		table.insert(out, { rank=rank, userId=uid, name=name, score=e.value })
	end
	return out
end

-- Returns top-N leaderboard for a specific game key.
function ScoreService.GetGameLeaderboard(gameKey, n)
	n = math.min(n or 10, 100)
	local pages = try(function() return gameStore(gameKey):GetSortedAsync(false, n) end)
	if not pages then return {} end
	local ok, pg = pcall(function() return pages:GetCurrentPage() end)
	if not ok then return {} end
	local out = {}
	for rank, e in ipairs(pg) do
		local uid  = tonumber(e.key)
		local name = "Player"
		pcall(function() name = Players:GetNameFromUserIdAsync(uid) end)
		table.insert(out, { rank=rank, userId=uid, name=name, score=e.value })
	end
	return out
end

-- ── Player lifecycle ───────────────────────────────────────────────────────────────
Players.PlayerAdded:Connect(function(p)   task.spawn(load, p) end)
Players.PlayerRemoving:Connect(function(p) flush(p); cache[p.UserId] = nil end)
for _, p in Players:GetPlayers() do task.spawn(load, p) end

print("[SGH] ScoreService loaded")
return ScoreService
