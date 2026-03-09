-- LavaGame: Last platform standing
local RunService = game:GetService("RunService")

local LavaGame = {}

local PLATFORM_COLOR  = Color3.fromRGB(0, 220, 255)
local WARN_COLOR      = Color3.fromRGB(255, 180, 0)
local LAVA_COLOR      = Color3.fromRGB(255, 60, 0)
local NEON = Enum.Material.Neon
local CENTER = Vector3.new(0, 1000, 0)

local function makePart(size, color, mat, pos)
	local p = Instance.new("Part")
	p.Size=size; p.Color=color; p.Material=mat or NEON
	p.Anchored=true; p.CanCollide=true; p.CastShadow=false
	p.Position=pos; p.Parent=workspace
	return p
end

function LavaGame.start(player, session, ctx)
	local parts = {}
	local folder = Instance.new("Folder"); folder.Name="LavaGame"; folder.Parent=workspace

	-- Lava floor
	local lava = makePart(Vector3.new(90,1,90), LAVA_COLOR, NEON, CENTER + Vector3.new(0,-2,0))
	local lavLight = Instance.new("PointLight"); lavLight.Color=LAVA_COLOR; lavLight.Range=80; lavLight.Brightness=3; lavLight.Parent=lava
	lava.Parent = folder

	-- 12 floating platforms in a ring
	local PLAT_COUNT = 12
	local RING_R = 30
	for i = 1, PLAT_COUNT do
		local angle = (i-1)/(PLAT_COUNT) * math.pi*2
		local px = CENTER.X + math.cos(angle)*RING_R
		local pz = CENTER.Z + math.sin(angle)*RING_R
		local plat = makePart(Vector3.new(10,1,10), PLATFORM_COLOR, NEON, Vector3.new(px,CENTER.Y+2,pz))
		plat.Parent = folder
		table.insert(parts, plat)
	end
	-- Center platform
	local center = makePart(Vector3.new(14,1,14), Color3.fromRGB(0,255,150), NEON, CENTER + Vector3.new(0,2,0))
	center.Parent = folder
	table.insert(parts, center)

	-- Teleport player onto a platform
	local char = player.Character
	if char then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then hrp.Anchored=false; hrp.CFrame = CFrame.new(CENTER + Vector3.new(0, 5, 0)) end
		-- Show character
		for _, p in char:GetDescendants() do
			if p:IsA("BasePart") then p.Transparency=0; p.CanCollide=(p.Name~="HumanoidRootPart") end
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed=16; hum.JumpHeight=7.2 end
	end

	ctx.GameStateChanged:FireClient(player, "PLAYING", {isMulti=false, playerCount=1})

	-- Remove one platform every 8 seconds
	local idx = 1
	local conn
	conn = task.spawn(function()
		while #parts > 1 and ctx.sessions[player] and ctx.sessions[player].gameType == "LAVA" do
			task.wait(8)
			if not ctx.sessions[player] then break end
			-- warn
			if parts[idx] then
				parts[idx].Color = WARN_COLOR
				task.wait(2)
				if parts[idx] then
					parts[idx]:Destroy()
					table.remove(parts, idx)
					if idx > #parts then idx = 1 end
				end
			end
		end
		-- Game over
		if ctx.sessions[player] and ctx.sessions[player].gameType == "LAVA" then
			local score = math.floor(tick()) % 1000 + 200
			ctx.saveScore(player, score)
			ctx.sessions[player].state = "GAME_OVER"
			ctx.GameStateChanged:FireClient(player, "GAME_OVER", {score=score, length=1, level=1, gameType="LAVA"})
		end
	end)

	-- Detect fall into lava (y < 0)
	local checkConn
	checkConn = RunService.Heartbeat:Connect(function()
		if not ctx.sessions[player] or ctx.sessions[player].gameType ~= "LAVA" then
			checkConn:Disconnect(); return
		end
		local char2 = player.Character
		if char2 then
			local hrp = char2:FindFirstChild("HumanoidRootPart")
			-- Lava surface is at Y≈-0.5; player standing on it has HRP≈2. Use CENTER.Y+2 as threshold.
			if hrp and hrp.Position.Y < CENTER.Y + 2 then
				checkConn:Disconnect()
				local score = math.max(0, PLAT_COUNT - #parts) * 50 + 100
				ctx.saveScore(player, score)
				if ctx.sessions[player] then
					ctx.sessions[player].state = "GAME_OVER"
				end
				ctx.GameStateChanged:FireClient(player, "GAME_OVER", {score=score, length=1, level=1, gameType="LAVA"})
			end
		end
	end)

	session.cleanup = function()
		checkConn:Disconnect()
		pcall(function() folder:Destroy() end)
	end
end

return LavaGame
