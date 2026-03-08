local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Events = ReplicatedStorage:WaitForChild("SnakeGame"):WaitForChild("Events")
local DirectionInputEvent = Events:WaitForChild("DirectionInput")
local SpectateTarget = Events:WaitForChild("SpectateTarget")

local keyMap = {
	[Enum.KeyCode.W]     = Vector3.new(0, 0, -1),
	[Enum.KeyCode.Up]    = Vector3.new(0, 0, -1),
	[Enum.KeyCode.S]     = Vector3.new(0, 0,  1),
	[Enum.KeyCode.Down]  = Vector3.new(0, 0,  1),
	[Enum.KeyCode.A]     = Vector3.new(-1, 0, 0),
	[Enum.KeyCode.Left]  = Vector3.new(-1, 0, 0),
	[Enum.KeyCode.D]     = Vector3.new( 1, 0, 0),
	[Enum.KeyCode.Right] = Vector3.new( 1, 0, 0),
}

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	local dir = keyMap[input.KeyCode]
	if dir then
		DirectionInputEvent:FireServer(dir)
	end
	if input.KeyCode == Enum.KeyCode.Tab then
		SpectateTarget:FireServer("next")
	end
end)

if UserInputService.TouchEnabled then
	local player = Players.LocalPlayer

	task.spawn(function()
		local ok, PlayerModule = pcall(function()
			return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
		end)
		if not ok or not PlayerModule then return end

		local controls = PlayerModule:GetControls()
		local lastQuantized = nil
		local DEAD_ZONE = 0.3
		local cam = workspace.CurrentCamera

		RunService.Heartbeat:Connect(function()
			local mv = controls:GetMoveVector()
			if mv.Magnitude < DEAD_ZONE then
				lastQuantized = nil
				return
			end

			local worldDir = cam.CFrame:VectorToWorldSpace(mv)
			worldDir = Vector3.new(worldDir.X, 0, worldDir.Z)
			if worldDir.Magnitude < 0.01 then return end

			local dir
			if math.abs(worldDir.X) > math.abs(worldDir.Z) then
				dir = worldDir.X > 0 and Vector3.new(1, 0, 0) or Vector3.new(-1, 0, 0)
			else
				dir = worldDir.Z > 0 and Vector3.new(0, 0, 1) or Vector3.new(0, 0, -1)
			end

			if lastQuantized and dir.X == lastQuantized.X and dir.Z == lastQuantized.Z then
				return
			end

			lastQuantized = dir
			DirectionInputEvent:FireServer(dir)
		end)
	end)

	local SWIPE_THRESHOLD = 30
	local MAX_SWIPE_TIME = 0.5
	local activeTouch = nil
	local touchStartPos = nil
	local touchStartTime = 0

	UserInputService.TouchStarted:Connect(function(input, processed)
		if processed then return end
		if activeTouch then return end
		activeTouch = input
		touchStartPos = input.Position
		touchStartTime = tick()
	end)

	UserInputService.TouchEnded:Connect(function(input, processed)
		if input ~= activeTouch then return end
		activeTouch = nil

		local delta = input.Position - touchStartPos
		local elapsed = tick() - touchStartTime
		touchStartPos = nil

		if delta.Magnitude < SWIPE_THRESHOLD then return end
		if elapsed > MAX_SWIPE_TIME then return end

		local dir
		if math.abs(delta.X) > math.abs(delta.Y) then
			dir = delta.X > 0 and Vector3.new(1, 0, 0) or Vector3.new(-1, 0, 0)
		else
			dir = delta.Y > 0 and Vector3.new(0, 0, 1) or Vector3.new(0, 0, -1)
		end

		DirectionInputEvent:FireServer(dir)
	end)
end

print("[SnakeGame] InputHandler loaded")
