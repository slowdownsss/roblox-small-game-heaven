local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("SnakeGame"):WaitForChild("Config"))
local Events = ReplicatedStorage:WaitForChild("SnakeGame"):WaitForChild("Events")
local GameStateChangedEvent = Events:WaitForChild("GameStateChanged")
local SpectateTargetEvent = Events:WaitForChild("SpectateTarget")

local camera = workspace.CurrentCamera
local player = Players.LocalPlayer
local OFFSET = Config.CAMERA_OFFSET
local SMOOTH_RATE = 15

local isActive = false
local spectateTargetName = nil

GameStateChangedEvent.OnClientEvent:Connect(function(state, data)
	-- Only take over camera for snake game states
	local isSnake = data and data.gameType == "SNAKE"
	if (state == "PLAYING" or state == "COUNTDOWN" or state == "SPECTATING") and isSnake then
		isActive = true
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CameraSubject = nil
		if state == "SPECTATING" and data and data.targetName then
			spectateTargetName = data.targetName
		else
			spectateTargetName = nil
		end
	else
		isActive = false
		spectateTargetName = nil
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	end
end)

SpectateTargetEvent.OnClientEvent:Connect(function(targetName)
	spectateTargetName = targetName
end)

local function findSnakeHead(ownerName)
	local heads = CollectionService:GetTagged("SnakeHead")
	for _, head in heads do
		if not head.Parent then continue end
		if ownerName then
			local tag = head:FindFirstChild("NameTag")
			if tag then
				local lbl = tag:FindFirstChildOfClass("TextLabel")
				if lbl and lbl.Text == ownerName then return head end
			end
		else
			return head
		end
	end
	return nil
end

RunService.RenderStepped:Connect(function(dt)
	if not isActive then return end

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CameraSubject = nil

	local head
	if spectateTargetName then
		head = findSnakeHead(spectateTargetName)
	end
	if not head then
		head = findSnakeHead(player.Name)
	end
	if not head then
		head = findSnakeHead(nil)
	end

	local lookAt
	if head and head.Parent then
		lookAt = head.Position
	else
		lookAt = Vector3.new(0, Config.GAME_Y, 0)
	end

	local targetPos = lookAt + OFFSET
	local targetCF = CFrame.lookAt(targetPos, lookAt)
	local alpha = 1 - math.exp(-SMOOTH_RATE * dt)
	camera.CFrame = camera.CFrame:Lerp(targetCF, alpha)
end)

print("[SnakeGame] CameraController loaded")
