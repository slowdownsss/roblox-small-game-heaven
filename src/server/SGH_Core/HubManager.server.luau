-- HubManager v1  |  ServerScriptService.SGH_Core.HubManager
-- Bootstraps SGH infrastructure:
--   • Ensures ReplicatedStorage.SGH.Events folder + RemoteEvents exist (idempotent)
--   • Wires GetLeaderboard RemoteFunction to ScoreService
--   • Logs hub score on player join for name-tag display

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Ensure SGH folder + events exist (idempotent — safe if already created)
local sgh = ReplicatedStorage:FindFirstChild("SGH")
if not sgh then
	sgh = Instance.new("Folder"); sgh.Name = "SGH"; sgh.Parent = ReplicatedStorage
end
local ev = sgh:FindFirstChild("Events")
if not ev then
	ev = Instance.new("Folder"); ev.Name = "Events"; ev.Parent = sgh
end

local function mkRE(name)
	if not ev:FindFirstChild(name) then
		local r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = ev
	end
	return ev:FindFirstChild(name)
end
local function mkRF(name)
	if not ev:FindFirstChild(name) then
		local r = Instance.new("RemoteFunction"); r.Name = name; r.Parent = ev
	end
	return ev:FindFirstChild(name)
end

mkRE("ScoreUpdated")    -- Server → Client: a player's hub score changed
mkRE("GameStateChanged") -- Server → Client: SGH-namespaced game state
mkRE("ReturnToHub")     -- Server → Client: force return to hub
local GetLeaderboardRF = mkRF("GetLeaderboard")  -- Client → Server query

-- Wire GetLeaderboard RF to ScoreService
local ScoreService = require(script.Parent:WaitForChild("ScoreService"))
GetLeaderboardRF.OnServerInvoke = function(player, gameKey)
	if gameKey and gameKey ~= "" then
		return ScoreService.GetGameLeaderboard(gameKey)
	end
	return ScoreService.GetHubLeaderboard()
end

-- Broadcast hub score to each player when they join so their name tag
-- can display the correct total immediately.
local ScoreUpdated = ev:WaitForChild("ScoreUpdated")
Players.PlayerAdded:Connect(function(player)
	task.wait(3)  -- wait for ScoreService to finish loading the player's data
	local score = ScoreService.GetHub(player)
	ScoreUpdated:FireClient(player, { hubScore = score })
end)

print("[SGH] HubManager loaded")
