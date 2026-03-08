--[[
  One-time test script for LeaderboardService.
  In Studio: Create a Script in ServerScriptService, paste this in, run Play, check Output.
  Delete or disable the script after testing.

  REQUIREMENT: File → Game Settings → Security → enable "Studio Access to API Services"
  (otherwise require(LeaderboardService) will fail because DataStore is disabled).
]]
local SnakeGame = game.ServerScriptService:FindFirstChild("SnakeGame")
if not SnakeGame then
	warn("[TestLeaderboard] ServerScriptService.SnakeGame not found")
	return
end
local LeaderboardService = SnakeGame:FindFirstChild("LeaderboardService")
if not LeaderboardService then
	warn("[TestLeaderboard] LeaderboardService ModuleScript not found")
	return
end
local ok, svc = pcall(function() return require(LeaderboardService) end)
if not ok or not svc then
	warn("[TestLeaderboard] require(LeaderboardService) failed:", svc)
	return
end

local Players = game:GetService("Players")
local player = Players:GetPlayers()[1]
if player then
	local subOk = pcall(function()
		svc.SubmitScore(player.UserId, player.Name, 999)
	end)
	print("[TestLeaderboard] SubmitScore(999):", subOk and "ok" or "fail")
	task.wait(1)
end

local result = svc.GetLeaderboard({ maxEntries = 20 })
print("[TestLeaderboard] Total scores in history:", result.totalCount)
for _, e in result.entries do
	print(string.format("  #%d %s %d", e.rank, e.userName or ("UserId_" .. tostring(e.userId)), e.score))
end
if player then
	local best, rank = svc.GetPlayerBest(player.UserId)
	print("[TestLeaderboard] Your best:", best, "rank:", rank)
end
print("[TestLeaderboard] Done. If totalCount >= 1 and entries show, leaderboard is working.")
