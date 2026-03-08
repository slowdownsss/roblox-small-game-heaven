local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("SnakeGame"):WaitForChild("Config"))
local Events = ReplicatedStorage:WaitForChild("SnakeGame"):WaitForChild("Events")
local GameStateChangedEvent = Events:WaitForChild("GameStateChanged")
local ScoreUpdatedEvent = Events:WaitForChild("ScoreUpdated")
local PowerUpActivatedEvent = Events:WaitForChild("PowerUpActivated")
local StartGameEvent = Events:WaitForChild("StartGame")
local LevelUpdatedEvent = Events:WaitForChild("LevelUpdated")
local GetLeaderboardFunc = Events:WaitForChild("GetLeaderboard")
local DirectionInputEvent = Events:WaitForChild("DirectionInput")
local LobbyUpdateEvent = Events:WaitForChild("LobbyUpdate")
local PlayerEliminatedEvent = Events:WaitForChild("PlayerEliminated")
local SpectateTargetEvent = Events:WaitForChild("SpectateTarget")
local MultiRoundEndEvent = Events:WaitForChild("MultiRoundEnd")
local ReturnToWorldEvent = Events:WaitForChild("ReturnToWorld")
local StartMiniGameEvent = Events:WaitForChild("StartMiniGame")

local isTouchDevice = UserInputService.TouchEnabled
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "SnakeGameUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local function mkFrame(p)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = p.bg or Color3.new(0,0,0)
	f.BackgroundTransparency = p.bgT or 0
	f.Size = p.size or UDim2.new(1,0,1,0)
	f.Position = p.pos or UDim2.new(0,0,0,0)
	f.AnchorPoint = p.anchor or Vector2.zero
	f.BorderSizePixel = 0
	f.Name = p.name or "Frame"
	f.Visible = p.visible ~= false
	if p.parent then f.Parent = p.parent end
	if p.corner then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, p.corner)
		c.Parent = f
	end
	return f
end

local function mkLabel(p)
	local l = Instance.new("TextLabel")
	l.Text = p.text or ""
	l.TextColor3 = p.color or Color3.new(1,1,1)
	l.TextScaled = true
	l.Font = p.font or Enum.Font.GothamBold
	l.BackgroundTransparency = 1
	l.Size = p.size or UDim2.new(1,0,0.1,0)
	l.Position = p.pos or UDim2.new(0,0,0,0)
	l.AnchorPoint = p.anchor or Vector2.zero
	l.Name = p.name or "Label"
	l.TextStrokeTransparency = p.stroke or 0.7
	if p.parent then l.Parent = p.parent end
	return l
end

local function mkButton(p)
	local b = Instance.new("TextButton")
	b.Text = p.text or "Button"
	b.TextColor3 = p.textColor or Color3.new(1,1,1)
	b.TextScaled = true
	b.Font = p.font or Enum.Font.GothamBold
	b.BackgroundColor3 = p.bg or Color3.fromRGB(57,255,20)
	b.Size = p.size or UDim2.new(0.3,0,0.08,0)
	b.Position = p.pos or UDim2.new(0.5,0,0.5,0)
	b.AnchorPoint = p.anchor or Vector2.new(0.5,0.5)
	b.BorderSizePixel = 0
	b.Name = p.name or "Button"
	if p.parent then b.Parent = p.parent end
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = b
	return b
end

-- =============================================
-- MAIN MENU
-- =============================================
local menuFrame = mkFrame({name="MainMenu", bg=Color3.fromRGB(5,5,18), bgT=0.05, parent=gui, visible=false})
do
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   Color3.fromRGB(3, 10, 25)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(6,  6, 20)),
		ColorSequenceKeypoint.new(1,   Color3.fromRGB(3, 18,  8)),
	})
	grad.Rotation = 135
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0.02),
		NumberSequenceKeypoint.new(0.5, 0.0),
		NumberSequenceKeypoint.new(1,   0.02),
	})
	grad.Parent = menuFrame
	local ms = Instance.new("UIStroke")
	ms.Thickness = 1.5
	ms.Color = Color3.fromRGB(57, 255, 20)
	ms.Transparency = 0.65
	ms.Parent = menuFrame
end

-- Animated snake-dot preview above title
local snakeDotRow = mkFrame({name="SnakeDots", bg=Color3.new(0,0,0), bgT=1,
	size=UDim2.new(0,264,0,20), pos=UDim2.new(0.5,0,0.028,0),
	anchor=Vector2.new(0.5,0), parent=menuFrame})
local snakeDotColors = {
	Color3.fromRGB(57,255,20), Color3.fromRGB(44,210,16), Color3.fromRGB(32,170,12),
	Color3.fromRGB(22,130,9),  Color3.fromRGB(14,90,6),   Color3.fromRGB(9,60,4),
	Color3.fromRGB(6,40,3),    Color3.fromRGB(4,26,2),
}
local snakeDots = {}
for i, dotColor in snakeDotColors do
	local dot = mkFrame({bg=dotColor, bgT=0, size=UDim2.new(0,18,0,18),
		pos=UDim2.new(0,(i-1)*33,0,1), corner=9, parent=snakeDotRow})
	table.insert(snakeDots, dot)
end
task.spawn(function()
	local frame = 0
	while true do
		task.wait(0.07)
		frame += 1
		for i, dot in snakeDots do
			local pulse = math.sin((frame - i * 1.8) * 0.38)
			dot.BackgroundTransparency = 1 - math.clamp((pulse + 1) / 2, 0.08, 1) * 0.92
		end
	end
end)

-- Title: glow layer + crisp layer
local titleGlow = mkLabel({text="NEON SNAKE", color=Color3.fromRGB(57,255,20),
	size=UDim2.new(0.65,0,0.098,0), pos=UDim2.new(0.5,0,0.092,0),
	anchor=Vector2.new(0.5,0.5), font=Enum.Font.GothamBlack, parent=menuFrame, stroke=0})
titleGlow.TextTransparency = 0.52
titleGlow.TextStrokeColor3 = Color3.fromRGB(57,255,20)
titleGlow.TextStrokeTransparency = 0.0
local titleLabel = mkLabel({text="NEON SNAKE", color=Color3.fromRGB(80,255,40),
	size=UDim2.new(0.65,0,0.098,0), pos=UDim2.new(0.5,0,0.092,0),
	anchor=Vector2.new(0.5,0.5), font=Enum.Font.GothamBlack, parent=menuFrame, stroke=0})
titleLabel.TextStrokeColor3 = Color3.fromRGB(10,60,5)
titleLabel.TextStrokeTransparency = 0.25
-- Subtitle
mkLabel({text="A R E N A", color=Color3.fromRGB(0,200,255),
	size=UDim2.new(0.22,0,0.024,0), pos=UDim2.new(0.5,0,0.148,0),
	anchor=Vector2.new(0.5,0.5), font=Enum.Font.GothamBlack, parent=menuFrame, stroke=0.4})
-- Neon divider
do
	local div = mkFrame({bg=Color3.fromRGB(57,255,20), bgT=0,
		size=UDim2.new(0.38,0,0,2), pos=UDim2.new(0.5,0,0.167,0),
		anchor=Vector2.new(0.5,0), parent=menuFrame})
	local dg = Instance.new("UIGradient")
	dg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0),
		NumberSequenceKeypoint.new(0.75, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	dg.Parent = div
end
mkLabel({text=isTouchDevice and "D-pad (bottom-left) or swipe to move" or "WASD / Arrow Keys to move",
	color=Color3.fromRGB(150,155,175),
	size=UDim2.new(0.6,0,0.027,0), pos=UDim2.new(0.5,0,0.185,0),
	anchor=Vector2.new(0.5,0.5), font=Enum.Font.Gotham, parent=menuFrame})
mkLabel({text="▸  Choose Your Snake  ◂", color=Color3.fromRGB(190,210,255),
	size=UDim2.new(0.34,0,0.027,0), pos=UDim2.new(0.5,0,0.215,0),
	anchor=Vector2.new(0.5,0.5), font=Enum.Font.GothamBold, parent=menuFrame})

local styleContainer = mkFrame({name="StyleSelect", bg=Color3.new(0,0,0), bgT=1,
	size=UDim2.new(0,440,0,110), pos=UDim2.new(0.5,0,0.335,0),
	anchor=Vector2.new(0.5,0.5), parent=menuFrame})
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0,8)
layout.Parent = styleContainer

local selectedStyle = 1
local styleCards = {}
for i, style in Config.SNAKE_STYLES do
	local card = mkFrame({name="Style_"..i, bg=Color3.fromRGB(14,14,30), bgT=0,
		size=UDim2.new(0,80,0,106), corner=10, parent=styleContainer})
	do
		local cg = Instance.new("UIGradient")
		cg.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(22,22,44)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(10,10,24)),
		})
		cg.Rotation = 180
		cg.Parent = card
	end
	-- Head circle preview
	local headPreview = mkFrame({name="HeadPreview", bg=style.headColor,
		size=UDim2.new(0,36,0,36), pos=UDim2.new(0.5,0,0,10),
		anchor=Vector2.new(0.5,0), corner=18, parent=card})
	-- Inner highlight
	mkFrame({bg=Color3.new(1,1,1), bgT=0.68, size=UDim2.new(0.45,0,0.35,0),
		pos=UDim2.new(0.12,0,0.1,0), corner=6, parent=headPreview})
	-- Body strip
	local bodyPreview = mkFrame({name="BodyPreview", bg=style.bodyColor,
		size=UDim2.new(0.72,0,0,10), pos=UDim2.new(0.5,0,0,60),
		anchor=Vector2.new(0.5,0), corner=5, parent=card})
	do
		local bg = Instance.new("UIGradient")
		bg.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(0.5, 0.25),
			NumberSequenceKeypoint.new(1, 0.6),
		})
		bg.Parent = bodyPreview
	end
	mkLabel({text=style.name, color=Color3.new(1,1,1),
		size=UDim2.new(0.95,0,0,20), pos=UDim2.new(0.5,0,1,-24),
		anchor=Vector2.new(0.5,0), font=Enum.Font.GothamBold, parent=card})
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = (i==1) and 2.5 or 0
	stroke.Color = Color3.fromRGB(57,255,20)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = card
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1,0,1,0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.ZIndex = 10
	btn.Parent = card
	btn.MouseButton1Click:Connect(function()
		selectedStyle = i
		for j, data in styleCards do data.stroke.Thickness = (j==i) and 2.5 or 0 end
	end)
	table.insert(styleCards, {card=card, stroke=stroke})
end

local soloBtn = mkButton({text="SOLO", bg=Color3.fromRGB(40,200,10), textColor=Color3.new(0,0,0),
	size=UDim2.new(0.18,0,0.058,0), pos=UDim2.new(0.35,0,0.485,0),
	anchor=Vector2.new(0.5,0.5), parent=menuFrame})
do
	local sg = Instance.new("UIGradient")
	sg.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(80,255,40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(30,180,5)),
	})
	sg.Rotation = 90
	sg.Parent = soloBtn
	local ss = Instance.new("UIStroke")
	ss.Thickness = 1; ss.Color = Color3.fromRGB(57,255,20); ss.Transparency = 0.5; ss.Parent = soloBtn
end
soloBtn.MouseButton1Click:Connect(function()
	StartGameEvent:FireServer(selectedStyle, "solo")
end)

local multiBtn = mkButton({text="MULTIPLAYER", bg=Color3.fromRGB(0,140,210), textColor=Color3.new(1,1,1),
	size=UDim2.new(0.18,0,0.058,0), pos=UDim2.new(0.65,0,0.485,0),
	anchor=Vector2.new(0.5,0.5), parent=menuFrame})
do
	local mg = Instance.new("UIGradient")
	mg.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0,200,255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0,100,180)),
	})
	mg.Rotation = 90
	mg.Parent = multiBtn
	local ms2 = Instance.new("UIStroke")
	ms2.Thickness = 1; ms2.Color = Color3.fromRGB(0,200,255); ms2.Transparency = 0.5; ms2.Parent = multiBtn
end
multiBtn.MouseButton1Click:Connect(function()
	StartGameEvent:FireServer(selectedStyle, "multi")
end)

local menuLbBtn = mkButton({text="LEADERBOARD", bg=Color3.fromRGB(45,45,70), textColor=Color3.fromRGB(180,190,220),
	size=UDim2.new(0.22,0,0.042,0), pos=UDim2.new(0.5,0,0.558,0),
	anchor=Vector2.new(0.5,0.5), parent=menuFrame})
do
	local ls = Instance.new("UIStroke")
	ls.Thickness = 1; ls.Color = Color3.fromRGB(100,110,160); ls.Transparency = 0.5; ls.Parent = menuLbBtn
end

local menuBackBtn = mkButton({text="← BACK TO WORLD", bg=Color3.fromRGB(55,55,68), textColor=Color3.fromRGB(200,200,220),
	size=UDim2.new(0.22,0,0.042,0), pos=UDim2.new(0.5,0,0.622,0),
	anchor=Vector2.new(0.5,0.5), parent=menuFrame})
menuBackBtn.MouseButton1Click:Connect(function()
	menuFrame.Visible = false
	minimapFrame.Visible = true
	ReturnToWorldEvent:FireServer()
end)

-- =============================================
-- LOBBY
-- =============================================
local lobbyFrame = mkFrame({name="Lobby", bg=Color3.new(0,0,0), bgT=0.4, parent=gui, visible=false})

mkLabel({text="MULTIPLAYER LOBBY", color=Color3.fromRGB(0,220,255),
	size=UDim2.new(0.5,0,0.08,0), pos=UDim2.new(0.5,0,0.1,0),
	anchor=Vector2.new(0.5,0.5), font=Enum.Font.GothamBlack, parent=lobbyFrame, stroke=0})

local lobbyCountLabel = mkLabel({text="Waiting for players... (0/2)",
	color=Color3.fromRGB(180,180,180),
	size=UDim2.new(0.5,0,0.04,0), pos=UDim2.new(0.5,0,0.2,0),
	anchor=Vector2.new(0.5,0.5), font=Enum.Font.GothamBold, parent=lobbyFrame})

local lobbyPlayerList = mkFrame({name="LobbyPlayers", bg=Color3.fromRGB(10,10,25), bgT=0.3,
	size=UDim2.new(0.4,0,0.35,0), pos=UDim2.new(0.5,0,0.45,0),
	anchor=Vector2.new(0.5,0.5), corner=12, parent=lobbyFrame})

local lobbyListLayout = Instance.new("UIListLayout")
lobbyListLayout.Padding = UDim.new(0,4)
lobbyListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
lobbyListLayout.Parent = lobbyPlayerList

local lobbyCountdownLabel = mkLabel({text="",
	color=Color3.fromRGB(57,255,20),
	size=UDim2.new(0.3,0,0.06,0), pos=UDim2.new(0.5,0,0.7,0),
	anchor=Vector2.new(0.5,0.5), font=Enum.Font.GothamBlack, parent=lobbyFrame, stroke=0})

local lobbyBackBtn = mkButton({text="BACK", bg=Color3.fromRGB(80,80,80),
	size=UDim2.new(0.15,0,0.04,0), pos=UDim2.new(0.5,0,0.8,0),
	anchor=Vector2.new(0.5,0.5), parent=lobbyFrame})
lobbyBackBtn.MouseButton1Click:Connect(function()
	lobbyFrame.Visible = false
	menuFrame.Visible = true
end)

LobbyUpdateEvent.OnClientEvent:Connect(function(data)
	lobbyCountLabel.Text = "Players: " .. data.count .. "/" .. data.minPlayers .. " (max " .. data.maxPlayers .. ")"

	for _, child in lobbyPlayerList:GetChildren() do
		if child:IsA("TextLabel") then child:Destroy() end
	end
	for i, p in data.players do
		local styleName = Config.SNAKE_STYLES[p.style] and Config.SNAKE_STYLES[p.style].name or "?"
		local row = mkLabel({text=p.name .. " - " .. styleName,
			color=Color3.fromRGB(200,220,255),
			size=UDim2.new(0.9,0,0,28), font=Enum.Font.GothamBold, parent=lobbyPlayerList})
		row.TextXAlignment = Enum.TextXAlignment.Left
	end

	if data.countdown then
		lobbyCountdownLabel.Text = "Starting in " .. data.countdown .. "..."
	else
		lobbyCountdownLabel.Text = "Waiting for more players..."
	end
end)

-- =============================================
-- COUNTDOWN
-- =============================================
local countdownLabel = mkLabel({text="", color=Color3.new(1,1,1),
	size=UDim2.new(0.3,0,0.2,0), pos=UDim2.new(0.5,0,0.5,0),
	anchor=Vector2.new(0.5,0.5), font=Enum.Font.GothamBlack, parent=gui, name="Countdown"})
countdownLabel.Visible = false

-- =============================================
-- HUD
-- =============================================
local hudFrame = mkFrame({name="HUD", bg=Color3.new(0,0,0), bgT=1, parent=gui, visible=false})

local scoreLabel = mkLabel({text="Score: 0", size=UDim2.new(0.2,0,0.05,0),
	pos=UDim2.new(0.02,0,0.02,0), parent=hudFrame, name="Score"})

local comboLabel = mkLabel({text="", color=Color3.fromRGB(255,200,0),
	size=UDim2.new(0.25,0,0.04,0), pos=UDim2.new(0.02,0,0.075,0), parent=hudFrame, name="Combo"})

local powerUpLabel = mkLabel({text="", color=Color3.fromRGB(180,0,255),
	size=UDim2.new(0.25,0,0.04,0), pos=UDim2.new(0.98,0,0.02,0),
	anchor=Vector2.new(1,0), parent=hudFrame, name="PowerUp"})

local levelFrame = mkFrame({name="LevelFrame", bg=Color3.fromRGB(10,10,25), bgT=0.4,
	size=UDim2.new(0,220,0,60), pos=UDim2.new(0.5,0,0.01,0),
	anchor=Vector2.new(0.5,0), corner=10, parent=hudFrame})
local levelLabel = mkLabel({text="Level 1", color=Color3.fromRGB(0,220,255),
	size=UDim2.new(0.9,0,0.5,0), pos=UDim2.new(0.5,0,0.05,0),
	anchor=Vector2.new(0.5,0), font=Enum.Font.GothamBlack, parent=levelFrame, name="LevelLabel"})
local timerLabel = mkLabel({text="2:00", color=Color3.fromRGB(200,200,200),
	size=UDim2.new(0.9,0,0.35,0), pos=UDim2.new(0.5,0,0.58,0),
	anchor=Vector2.new(0.5,0), font=Enum.Font.GothamBold, parent=levelFrame, name="TimerLabel"})
local timerBarBg = mkFrame({name="TimerBarBg", bg=Color3.fromRGB(40,40,60), bgT=0.3,
	size=UDim2.new(0.85,0,0,4), pos=UDim2.new(0.5,0,0.92,0),
	anchor=Vector2.new(0.5,0.5), corner=2, parent=levelFrame})
local timerBarFill = mkFrame({name="TimerBarFill", bg=Color3.fromRGB(0,220,255),
	size=UDim2.new(1,0,1,0), pos=UDim2.new(0,0,0,0), corner=2, parent=timerBarBg})

local aliveLabel = mkLabel({text="", color=Color3.fromRGB(255,200,0),
	size=UDim2.new(0.2,0,0.035,0), pos=UDim2.new(0.98,0,0.07,0),
	anchor=Vector2.new(1,0), font=Enum.Font.GothamBold, parent=hudFrame, name="AliveCount"})

local spectateLabel = mkLabel({text="", color=Color3.fromRGB(200,200,200),
	size=UDim2.new(0.3,0,0.03,0), pos=UDim2.new(0.5,0,0.95,0),
	anchor=Vector2.new(0.5,0.5), font=Enum.Font.Gotham, parent=hudFrame, name="SpectateInfo"})
spectateLabel.Visible = false

local spectateNextBtn = mkButton({text="Next Player [Tab]", bg=Color3.fromRGB(60,60,80),
	size=UDim2.new(0.15,0,0.035,0), pos=UDim2.new(0.5,0,0.9,0),
	anchor=Vector2.new(0.5,0.5), parent=hudFrame})
spectateNextBtn.Visible = false
spectateNextBtn.MouseButton1Click:Connect(function()
	SpectateTargetEvent:FireServer("next")
end)

local minimapFrame -- forward declaration (defined below)
local quitGameBtn = mkButton({text="QUIT [ESC]", bg=Color3.fromRGB(200,60,60), textColor=Color3.new(1,1,1),
	size=UDim2.new(0.12,0,0.04,0), pos=UDim2.new(0.98,0,0.02,0),
	anchor=Vector2.new(1,0), parent=hudFrame})
quitGameBtn.MouseButton1Click:Connect(function()
	hudFrame.Visible = false
	ReturnToWorldEvent:FireServer()
end)

-- =============================================
-- MINIMAP  (cartoony world map)
-- =============================================
minimapFrame = mkFrame({
	name="Minimap", bg=Color3.fromRGB(10,20,38), bgT=0.05,
	size=UDim2.new(0,228,0,244), pos=UDim2.new(1,-14,0,14),
	anchor=Vector2.new(1,0), corner=16, parent=gui, visible=false,
})
-- Thick gold border
local mmStroke = Instance.new("UIStroke")
mmStroke.Thickness=3; mmStroke.Color=Color3.fromRGB(255,200,50)
mmStroke.Transparency=0.15; mmStroke.Parent=minimapFrame

-- Title bar
local mmTitleBg = mkFrame({name="TitleBg", bg=Color3.fromRGB(8,14,30), bgT=0,
	size=UDim2.new(1,0,0,30), pos=UDim2.new(0,0,0,0), corner=14, parent=minimapFrame})
local mmDivider = mkFrame({name="Divider", bg=Color3.fromRGB(255,200,50), bgT=0.45,
	size=UDim2.new(0.85,0,0,1), pos=UDim2.new(0.075,0,0,30), parent=minimapFrame})
local mmTitleLbl = Instance.new("TextLabel")
mmTitleLbl.Size=UDim2.new(1,0,1,0); mmTitleLbl.BackgroundTransparency=1
mmTitleLbl.Text="WORLD MAP"; mmTitleLbl.TextColor3=Color3.fromRGB(255,210,55)
mmTitleLbl.Font=Enum.Font.GothamBlack; mmTitleLbl.TextScaled=false; mmTitleLbl.TextSize=14
mmTitleLbl.TextXAlignment=Enum.TextXAlignment.Center; mmTitleLbl.ZIndex=3
mmTitleLbl.Parent=mmTitleBg

-- Map content area (below title)
local mapContent = Instance.new("Frame")
mapContent.Name="MapContent"; mapContent.Size=UDim2.new(1,0,1,-32)
mapContent.Position=UDim2.new(0,0,0,32); mapContent.BackgroundTransparency=1
mapContent.BorderSizePixel=0; mapContent.Parent=minimapFrame

-- Snake Arena center zone
local arenaZone = mkFrame({bg=Color3.fromRGB(15,80,28), bgT=0.2,
	size=UDim2.new(0,56,0,46), pos=UDim2.new(0.5,-28,0.5,-23),
	corner=10, parent=mapContent})
local arenaStroke = Instance.new("UIStroke")
arenaStroke.Thickness=2; arenaStroke.Color=Color3.fromRGB(57,255,20)
arenaStroke.Transparency=0.15; arenaStroke.Parent=arenaZone
local azLbl = Instance.new("TextLabel")
azLbl.Size=UDim2.new(1,0,0.52,0); azLbl.Position=UDim2.new(0,0,0.06,0)
azLbl.BackgroundTransparency=1; azLbl.Text="SNAKE"
azLbl.TextColor3=Color3.fromRGB(100,255,110); azLbl.Font=Enum.Font.GothamBlack
azLbl.TextScaled=false; azLbl.TextSize=12
azLbl.TextXAlignment=Enum.TextXAlignment.Center; azLbl.Parent=arenaZone
local azLbl2 = Instance.new("TextLabel")
azLbl2.Size=UDim2.new(1,0,0.38,0); azLbl2.Position=UDim2.new(0,0,0.57,0)
azLbl2.BackgroundTransparency=1; azLbl2.Text="ARENA"
azLbl2.TextColor3=Color3.fromRGB(65,185,70); azLbl2.Font=Enum.Font.GothamBold
azLbl2.TextScaled=false; azLbl2.TextSize=10
azLbl2.TextXAlignment=Enum.TextXAlignment.Center; azLbl2.Parent=arenaZone

-- Zone dot maker: pill-shaped tags with colored stroke and clear font
local function mmDot(name, color, nx, nz)
	local dot = mkFrame({bg=color, bgT=0.22,
		size=UDim2.new(0,58,0,22), pos=UDim2.new(nx,-29,nz,-11),
		corner=11, parent=mapContent})
	local ds = Instance.new("UIStroke")
	ds.Thickness=1.5; ds.Color=color; ds.Transparency=0.2; ds.Parent=dot
	local lbl = Instance.new("TextLabel")
	lbl.Size=UDim2.new(1,0,1,0); lbl.BackgroundTransparency=1
	lbl.Text=name; lbl.TextColor3=Color3.new(1,1,1)
	lbl.Font=Enum.Font.GothamBlack; lbl.TextScaled=false; lbl.TextSize=12
	lbl.TextXAlignment=Enum.TextXAlignment.Center; lbl.Parent=dot
	return dot
end
mmDot("LAVA",   Color3.fromRGB(255,90,15),   0.5,    0.1875)
mmDot("MAZE",   Color3.fromRGB(185,50,255),  0.8125, 0.25)
mmDot("RHYTHM", Color3.fromRGB(255,40,190),  0.1875, 0.25)
mmDot("FLOOD",  Color3.fromRGB(0,210,130),   0.15,   0.5625)
mmDot("BLAST",  Color3.fromRGB(30,190,255),  0.85,   0.5625)
mmDot("START",  Color3.fromRGB(210,200,255), 0.5,    0.78)

-- Player dot (glowing white circle with cyan ring)
local playerDot = mkFrame({bg=Color3.fromRGB(255,255,255), bgT=0,
	size=UDim2.new(0,11,0,11), pos=UDim2.new(0.5,-5,0.5,-5),
	corner=6, parent=mapContent})
local pdStroke = Instance.new("UIStroke")
pdStroke.Thickness=2; pdStroke.Color=Color3.fromRGB(80,200,255); pdStroke.Parent=playerDot
playerDot.ZIndex=10

-- Minimap update loop
RunService.Heartbeat:Connect(function()
	if not minimapFrame.Visible then return end
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local bound = Config.WORLD_HALF
	local nx = math.clamp((hrp.Position.X + bound) / (bound * 2), 0.02, 0.97)
	local nz = math.clamp((hrp.Position.Z + bound) / (bound * 2), 0.02, 0.97)
	playerDot.Position = UDim2.new(nx, -5, nz, -5)
end)

-- =============================================
-- MOBILE: ON-SCREEN D-PAD (arrow controls)
-- =============================================
local mobileDpadFrame = nil
if isTouchDevice then
	local dpadSize = 160
	local btnSize = 48
	local pad = mkFrame({name="MobileDpad", bg=Color3.fromRGB(15,18,28), bgT=0.3,
		size=UDim2.new(0, dpadSize, 0, dpadSize), pos=UDim2.new(0, 24, 1, -dpadSize-24),
		anchor=Vector2.new(0, 1), corner=14, parent=hudFrame})
	pad.Visible = false
	mobileDpadFrame = pad
	local mid = (dpadSize - btnSize) / 2
	local function addArrow(dir, symbol, px, py)
		local btn = mkButton({text=symbol, bg=Color3.fromRGB(50,60,90), textColor=Color3.fromRGB(200,220,255),
			size=UDim2.new(0,btnSize,0,btnSize), pos=UDim2.new(0,px,0,py), anchor=Vector2.new(0,0), parent=pad})
		btn.Font = Enum.Font.GothamBlack
		btn.MouseButton1Click:Connect(function() DirectionInputEvent:FireServer(dir) end)
		return btn
	end
	addArrow(Vector3.new(0,0,-1), "▲", mid, 0)
	addArrow(Vector3.new(0,0,1), "▼", mid, dpadSize-btnSize)
	addArrow(Vector3.new(-1,0,0), "◀", 0, mid)
	addArrow(Vector3.new(1,0,0), "▶", dpadSize-btnSize, mid)
end

-- =============================================
-- ELIMINATION NOTIFICATION
-- =============================================
local function showElimination(data)
	local msg = data.eliminated .. " eliminated"
	if data.killedBy and data.killedBy ~= "wall" and data.killedBy ~= "self" and data.killedBy ~= "obstacle" then
		msg = data.eliminated .. " eliminated by " .. data.killedBy
	end
	aliveLabel.Text = data.remaining .. " alive"

	local notif = mkLabel({text=msg, color=Color3.fromRGB(255,80,80),
		size=UDim2.new(0.4,0,0.04,0), pos=UDim2.new(0.5,0,0.15,0),
		anchor=Vector2.new(0.5,0.5), font=Enum.Font.GothamBold, parent=gui, stroke=0})
	notif.TextTransparency = 0
	TweenService:Create(notif, TweenInfo.new(2), {TextTransparency=1, Position=UDim2.new(0.5,0,0.12,0)}):Play()
	task.delay(2.1, function() notif:Destroy() end)
end

PlayerEliminatedEvent.OnClientEvent:Connect(showElimination)

-- =============================================
-- GAME OVER
-- =============================================
local currentMiniGameKey = nil  -- tracks active mini-game for PLAY AGAIN
local goFrame = mkFrame({name="GameOver", bg=Color3.fromRGB(5,3,12), bgT=0.04, parent=gui, visible=false})
do
	local gg = Instance.new("UIGradient")
	gg.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   Color3.fromRGB(20, 4, 4)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(6,  3, 14)),
		ColorSequenceKeypoint.new(1,   Color3.fromRGB(20, 4, 4)),
	})
	gg.Rotation = 135
	gg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0.04),
		NumberSequenceKeypoint.new(0.5, 0.0),
		NumberSequenceKeypoint.new(1,   0.04),
	})
	gg.Parent = goFrame
	local gs = Instance.new("UIStroke")
	gs.Thickness = 1.5; gs.Color = Color3.fromRGB(200,40,40); gs.Transparency = 0.65; gs.Parent = goFrame
end
-- Game over title: glow layer + crisp layer
local goGlow = mkLabel({text="GAME OVER", color=Color3.fromRGB(255,60,60),
	size=UDim2.new(0.58,0,0.115,0), pos=UDim2.new(0.5,0,0.12,0),
	anchor=Vector2.new(0.5,0.5), font=Enum.Font.GothamBlack, parent=goFrame, stroke=0})
goGlow.TextTransparency = 0.5
goGlow.TextStrokeColor3 = Color3.fromRGB(255,60,60)
goGlow.TextStrokeTransparency = 0
mkLabel({text="GAME OVER", color=Color3.fromRGB(255,80,80),
	size=UDim2.new(0.52,0,0.1,0), pos=UDim2.new(0.5,0,0.12,0),
	anchor=Vector2.new(0.5,0.5), font=Enum.Font.GothamBlack, parent=goFrame, stroke=0})

local winnerLabel = mkLabel({text="", color=Color3.fromRGB(255,215,0),
	size=UDim2.new(0.4,0,0.05,0), pos=UDim2.new(0.5,0,0.2,0),
	anchor=Vector2.new(0.5,0.5), font=Enum.Font.GothamBold, parent=goFrame, name="WinnerLabel"})

local finalScoreLabel = mkLabel({text="Score: 0", size=UDim2.new(0.4,0,0.05,0),
	pos=UDim2.new(0.5,0,0.27,0), anchor=Vector2.new(0.5,0.5), parent=goFrame, name="FinalScore"})
local finalLengthLabel = mkLabel({text="Length: 0", color=Color3.fromRGB(200,200,200),
	size=UDim2.new(0.3,0,0.035,0), pos=UDim2.new(0.5,0,0.32,0),
	anchor=Vector2.new(0.5,0.5), parent=goFrame, name="FinalLength", font=Enum.Font.Gotham})
local finalLevelLabel = mkLabel({text="Level: 1", color=Color3.fromRGB(0,220,255),
	size=UDim2.new(0.3,0,0.04,0), pos=UDim2.new(0.5,0,0.37,0),
	anchor=Vector2.new(0.5,0.5), parent=goFrame, name="FinalLevel", font=Enum.Font.GothamBold})

local multiResultsFrame = mkFrame({name="MultiResults", bg=Color3.fromRGB(10,10,25), bgT=0.3,
	size=UDim2.new(0.4,0,0.2,0), pos=UDim2.new(0.5,0,0.52,0),
	anchor=Vector2.new(0.5,0.5), corner=10, parent=goFrame, visible=false})
local multiResultsLayout = Instance.new("UIListLayout")
multiResultsLayout.Padding = UDim.new(0,3)
multiResultsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
multiResultsLayout.Parent = multiResultsFrame

local goBtnW, goBtnH = isTouchDevice and 0.32 or 0.22, isTouchDevice and 0.07 or 0.05
local goBtnH2 = isTouchDevice and 0.06 or 0.04
local restartBtn = mkButton({text="PLAY AGAIN", bg=Color3.fromRGB(57,255,20), textColor=Color3.new(0,0,0),
	size=UDim2.new(goBtnW,0,goBtnH,0), pos=UDim2.new(0.5,0,0.66,0),
	anchor=Vector2.new(0.5,0.5), parent=goFrame})
local goLbBtn = mkButton({text="LEADERBOARD", bg=Color3.fromRGB(0,160,220), textColor=Color3.new(1,1,1),
	size=UDim2.new(goBtnW,0,goBtnH2,0), pos=UDim2.new(0.5,0,0.74,0),
	anchor=Vector2.new(0.5,0.5), parent=goFrame})
local quitBtn = mkButton({text="RETURN TO WORLD", bg=Color3.fromRGB(80,80,80),
	size=UDim2.new(isTouchDevice and 0.26 or 0.18,0,goBtnH2,0), pos=UDim2.new(0.5,0,0.82,0),
	anchor=Vector2.new(0.5,0.5), parent=goFrame})
restartBtn.MouseButton1Click:Connect(function()
	if currentMiniGameKey then
		StartMiniGameEvent:FireServer(currentMiniGameKey)
	else
		StartGameEvent:FireServer(selectedStyle, "solo")
	end
end)
quitBtn.MouseButton1Click:Connect(function()
	goFrame.Visible = false
	ReturnToWorldEvent:FireServer()
end)

-- =============================================
local lbOverlay = mkFrame({name="LBOverlay", bg=Color3.new(0,0,0), bgT=0.5, parent=gui, visible=false})
lbOverlay.ZIndex = 50
local lbPanelSize = isTouchDevice and UDim2.new(0.92,0,0.92,0) or UDim2.new(0,480,0,620)
local lbPanel = mkFrame({name="LBPanel", bg=Color3.fromRGB(8,8,24), bgT=0.05,
	size=lbPanelSize, pos=UDim2.new(0.5,0,0.5,0),
	anchor=Vector2.new(0.5,0.5), corner=16, parent=lbOverlay})
lbPanel.ZIndex = 51

local lbBorderStroke = Instance.new("UIStroke")
lbBorderStroke.Thickness = 2
lbBorderStroke.Color = Color3.fromRGB(0,180,255)
lbBorderStroke.Transparency = 0.4
lbBorderStroke.Parent = lbPanel

local lbTitle = mkLabel({text="LEADERBOARD", color=Color3.fromRGB(0,220,255),
	size=UDim2.new(0.8,0,0,36), pos=UDim2.new(0.5,0,0,22),
	anchor=Vector2.new(0.5,0), font=Enum.Font.GothamBlack, parent=lbPanel, stroke=0})
lbTitle.ZIndex = 52

local lbCloseBtn = Instance.new("TextButton")
lbCloseBtn.Text = "X"
lbCloseBtn.TextColor3 = Color3.fromRGB(200,200,200)
lbCloseBtn.TextScaled = true
lbCloseBtn.Font = Enum.Font.GothamBold
lbCloseBtn.BackgroundColor3 = Color3.fromRGB(60,20,20)
lbCloseBtn.Size = isTouchDevice and UDim2.new(0,48,0,48) or UDim2.new(0,32,0,32)
lbCloseBtn.Position = isTouchDevice and UDim2.new(1,-16,0,16) or UDim2.new(1,-12,0,12)
lbCloseBtn.AnchorPoint = Vector2.new(1,0)
lbCloseBtn.BorderSizePixel = 0
lbCloseBtn.ZIndex = 53
lbCloseBtn.Parent = lbPanel
Instance.new("UICorner", lbCloseBtn).CornerRadius = UDim.new(0,8)
lbCloseBtn.MouseButton1Click:Connect(function() lbOverlay.Visible = false end)
local lbHeaderBg = mkFrame({name="HeaderBg", bg=Color3.fromRGB(15,15,40), bgT=0,
	size=UDim2.new(0.9,0,0,30), pos=UDim2.new(0.5,0,0,68),
	anchor=Vector2.new(0.5,0), corner=6, parent=lbPanel})
lbHeaderBg.ZIndex = 52

local function headerLabel(text, xPos, xSize, align)
	local l = mkLabel({text=text, color=Color3.fromRGB(120,140,180),
		size=UDim2.new(xSize,0,1,0), pos=UDim2.new(xPos,0,0.5,0),
		anchor=Vector2.new(0,0.5), font=Enum.Font.GothamBold, parent=lbHeaderBg})
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextScaled = true
	l.ZIndex = 53
	return l
end
headerLabel("#", 0.04, 0.1, Enum.TextXAlignment.Center)
headerLabel("PLAYER", 0.18, 0.5, Enum.TextXAlignment.Left)
headerLabel("SCORE", 0.7, 0.26, Enum.TextXAlignment.Right)
local lbRowContainer = mkFrame({name="RowContainer", bg=Color3.new(0,0,0), bgT=1,
	size=isTouchDevice and UDim2.new(0.9,0,0.52,0) or UDim2.new(0.9,0,0,360),
	pos=isTouchDevice and UDim2.new(0.5,0,0.18,0) or UDim2.new(0.5,0,0,104),
	anchor=Vector2.new(0.5,0), parent=lbPanel})
lbRowContainer.ZIndex = 52
local ROW_HEIGHT = isTouchDevice and 0.1 or 36
local RANK_COLORS = {[1]=Color3.fromRGB(255,215,0), [2]=Color3.fromRGB(192,192,192), [3]=Color3.fromRGB(205,127,50)}
local lbRows = {}
for i = 1, 10 do
	local rowBg = mkFrame({name="Row_"..i,
		bg = if i%2==0 then Color3.fromRGB(18,18,42) else Color3.fromRGB(12,12,32),
		bgT=0.15, size=isTouchDevice and UDim2.new(1,0,0.1,0) or UDim2.new(1,0,0,36),
		pos=isTouchDevice and UDim2.new(0,0,(i-1)*0.1,0) or UDim2.new(0,0,0,(i-1)*36), corner=4, parent=lbRowContainer})
	rowBg.ZIndex = 53
	local rankL = mkLabel({text=tostring(i), color=Color3.fromRGB(100,100,130),
		size=UDim2.new(0.1,0,0.7,0), pos=UDim2.new(0.04,0,0.5,0),
		anchor=Vector2.new(0,0.5), font=Enum.Font.GothamBlack, parent=rowBg})
	rankL.TextXAlignment = Enum.TextXAlignment.Center
	rankL.ZIndex = 54
	local nameL = mkLabel({text="---", color=Color3.fromRGB(180,180,200),
		size=UDim2.new(0.5,0,0.7,0), pos=UDim2.new(0.18,0,0.5,0),
		anchor=Vector2.new(0,0.5), font=Enum.Font.GothamBold, parent=rowBg})
	nameL.TextXAlignment = Enum.TextXAlignment.Left
	nameL.ZIndex = 54
	local scoreL = mkLabel({text="-", color=Color3.fromRGB(160,160,180),
		size=UDim2.new(0.26,0,0.7,0), pos=UDim2.new(0.96,0,0.5,0),
		anchor=Vector2.new(1,0.5), font=Enum.Font.GothamBold, parent=rowBg})
	scoreL.TextXAlignment = Enum.TextXAlignment.Right
	scoreL.ZIndex = 54
	table.insert(lbRows, {bg=rowBg, rank=rankL, name=nameL, score=scoreL})
end
local lbYourBestLabel = mkLabel({text="YOUR RANK", color=Color3.fromRGB(120,140,180),
	size=UDim2.new(0.4,0,0,24), pos=isTouchDevice and UDim2.new(0.1,0,0.72,0) or UDim2.new(0.1,0,0,480),
	anchor=Vector2.new(0,0), font=Enum.Font.GothamBold, parent=lbPanel})
lbYourBestLabel.ZIndex = 52
local lbYourScoreLabel = mkLabel({text="---", color=Color3.fromRGB(57,255,20),
	size=UDim2.new(0.35,0,0,28), pos=isTouchDevice and UDim2.new(0.1,0,0.76,0) or UDim2.new(0.1,0,0,504),
	anchor=Vector2.new(0,0), font=Enum.Font.GothamBlack, parent=lbPanel, stroke=0})
lbYourScoreLabel.TextXAlignment = Enum.TextXAlignment.Left
lbYourScoreLabel.ZIndex = 52
local lbYourBestScoreHeader = mkLabel({text="BEST SCORE", color=Color3.fromRGB(120,140,180),
	size=UDim2.new(0.35,0,0,24), pos=isTouchDevice and UDim2.new(0.9,0,0.72,0) or UDim2.new(0.9,0,0,480),
	anchor=Vector2.new(1,0), font=Enum.Font.GothamBold, parent=lbPanel})
lbYourBestScoreHeader.TextXAlignment = Enum.TextXAlignment.Right
lbYourBestScoreHeader.ZIndex = 52
local lbYourRankLabel = mkLabel({text="", color=Color3.fromRGB(57,255,20),
	size=UDim2.new(0.35,0,0,28), pos=isTouchDevice and UDim2.new(0.9,0,0.76,0) or UDim2.new(0.9,0,0,504),
	anchor=Vector2.new(1,0), font=Enum.Font.GothamBlack, parent=lbPanel})
lbYourRankLabel.TextXAlignment = Enum.TextXAlignment.Right
lbYourRankLabel.ZIndex = 52
local lbTotalPlaysLabel = mkLabel({text="", color=Color3.fromRGB(80,80,120),
	size=UDim2.new(0.8,0,0,22), pos=isTouchDevice and UDim2.new(0.5,0,0.82,0) or UDim2.new(0.5,0,0,548),
	anchor=Vector2.new(0.5,0), font=Enum.Font.Gotham, parent=lbPanel})
lbTotalPlaysLabel.ZIndex = 52
local lbLoadingLabel = mkLabel({text="Loading...", color=Color3.fromRGB(100,100,140),
	size=UDim2.new(0.6,0,0,30), pos=UDim2.new(0.5,0,0.45,0),
	anchor=Vector2.new(0.5,0.5), font=Enum.Font.GothamBold, parent=lbPanel})
lbLoadingLabel.ZIndex = 55
lbLoadingLabel.Visible = false

local function formatScore(n)
	local s = tostring(n)
	local result = ""
	for i = #s, 1, -1 do
		result = s:sub(i,i) .. result
		if (#s-i+1)%3==0 and i>1 then result = ","..result end
	end
	return result
end

local function populateLeaderboard()
	lbLoadingLabel.Visible = true
	for _, row in lbRows do row.bg.Visible = false end
	lbYourScoreLabel.Text = "..."
	lbYourRankLabel.Text = ""
	lbTotalPlaysLabel.Text = ""
	task.spawn(function()
		local ok, result = pcall(function()
			return GetLeaderboardFunc:InvokeServer()
		end)
		lbLoadingLabel.Visible = false
		if not ok or not result then
			lbLoadingLabel.Visible = true
			lbLoadingLabel.Text = "No data yet"
			for _, row in lbRows do row.bg.Visible = true end
			return
		end
		local entries = result.entries or {}
		local entryList = {}
		for _, v in pairs(entries) do
			if type(v) == "table" then
				table.insert(entryList, v)
			end
		end
		table.sort(entryList, function(a, b)
			return (tonumber(a.rank) or 0) < (tonumber(b.rank) or 0)
		end)
		local playerRank = result.playerRank
		local playerBestScore = result.playerBestScore or 0
		local totalCount = result.totalCount or 0
		if playerRank == nil then
			for _, e in ipairs(entryList) do
				if e.isYou then
					playerRank = e.rank
					break
				end
			end
		end
		for i, row in ipairs(lbRows) do
			row.bg.Visible = true
			local entry = entryList[i]
			if entry then
				row.rank.Text = tostring(entry.rank or i)
				row.name.Text = tostring(entry.name or entry.userName or "Player")
				local scoreNum = tonumber(entry.score) or 0
				row.score.Text = formatScore(scoreNum)
				row.score.Visible = true
				local rankColor = RANK_COLORS[entry.rank]
				if rankColor then
					row.rank.TextColor3 = rankColor
					row.name.TextColor3 = rankColor
					row.score.TextColor3 = rankColor
				elseif entry.isYou then
					row.rank.TextColor3 = Color3.fromRGB(57, 255, 20)
					row.name.TextColor3 = Color3.fromRGB(57, 255, 20)
					row.score.TextColor3 = Color3.fromRGB(57, 255, 20)
				else
					row.rank.TextColor3 = Color3.fromRGB(100, 100, 130)
					row.name.TextColor3 = Color3.fromRGB(180, 180, 200)
					row.score.TextColor3 = Color3.fromRGB(160, 160, 180)
				end
				if entry.isYou then
					row.bg.BackgroundColor3 = Color3.fromRGB(10, 40, 15)
					row.bg.BackgroundTransparency = 0.1
				else
					row.bg.BackgroundColor3 = if i % 2 == 0 then Color3.fromRGB(18, 18, 42) else Color3.fromRGB(12, 12, 32)
					row.bg.BackgroundTransparency = 0.15
				end
			else
				row.rank.Text = tostring(i)
				row.name.Text = "---"
				row.score.Text = "-"
				row.score.Visible = true
				row.rank.TextColor3 = Color3.fromRGB(50, 50, 70)
				row.name.TextColor3 = Color3.fromRGB(50, 50, 70)
				row.score.TextColor3 = Color3.fromRGB(50, 50, 70)
				row.bg.BackgroundColor3 = if i % 2 == 0 then Color3.fromRGB(18, 18, 42) else Color3.fromRGB(12, 12, 32)
				row.bg.BackgroundTransparency = 0.15
			end
		end
		if playerRank then
			lbYourScoreLabel.Text = "#" .. formatScore(playerRank)
			lbYourScoreLabel.TextColor3 = Color3.fromRGB(57, 255, 20)
		else
			lbYourScoreLabel.Text = "---"
			lbYourScoreLabel.TextColor3 = Color3.fromRGB(120, 120, 150)
		end
		if playerBestScore > 0 then
			lbYourRankLabel.Text = formatScore(playerBestScore)
			lbYourRankLabel.TextColor3 = Color3.fromRGB(57, 255, 20)
		else
			lbYourRankLabel.Text = "Play to rank!"
			lbYourRankLabel.TextColor3 = Color3.fromRGB(120, 120, 150)
		end
		if totalCount > 0 then
			lbTotalPlaysLabel.Text = "Total plays: " .. formatScore(totalCount)
		else
			lbTotalPlaysLabel.Text = ""
		end
	end)
end

local function showLeaderboard()
	lbOverlay.Visible = true
	populateLeaderboard()
end
menuLbBtn.MouseButton1Click:Connect(showLeaderboard)
goLbBtn.MouseButton1Click:Connect(showLeaderboard)

-- =============================================
-- OPEN WORLD VISIBILITY
-- =============================================
local function setOpenWorldVisible(visible)
	local openWorld = workspace:FindFirstChild("OpenWorld")
	if not openWorld then return end
	local val = visible and 0 or 1
	for _, part in openWorld:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = val
		end
	end
end

-- =============================================
-- STATE HANDLING
-- =============================================
local function hideAll()
	menuFrame.Visible = false
	lobbyFrame.Visible = false
	countdownLabel.Visible = false
	hudFrame.Visible = false
	goFrame.Visible = false
	lbOverlay.Visible = false
	spectateLabel.Visible = false
	spectateNextBtn.Visible = false
	aliveLabel.Text = ""
	if mobileDpadFrame then mobileDpadFrame.Visible = false end
	minimapFrame.Visible = false
end

local isMultiGame = false

GameStateChangedEvent.OnClientEvent:Connect(function(state, data)
	hideAll()

	if state == "OPEN_WORLD" then
		setOpenWorldVisible(true)
		task.delay(0.5, function() setOpenWorldVisible(true) end)
		minimapFrame.Visible = true
		isMultiGame = false

	elseif state == "IDLE" then
		setOpenWorldVisible(false)
		menuFrame.Visible = true
		isMultiGame = false

	elseif state == "LOBBY" then
		lobbyFrame.Visible = true

	elseif state == "COUNTDOWN" then
		countdownLabel.Visible = true
		for i = 3, 1, -1 do
			countdownLabel.Text = tostring(i)
			countdownLabel.TextColor3 = Color3.new(1,1,1)
			countdownLabel.TextTransparency = 0
			TweenService:Create(countdownLabel, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {TextTransparency=0.8}):Play()
			task.wait(1)
		end
		countdownLabel.Text = "GO!"
		countdownLabel.TextColor3 = Color3.fromRGB(57,255,20)
		countdownLabel.TextTransparency = 0
		task.wait(0.5)
		countdownLabel.Visible = false

	elseif state == "PLAYING" then
		hudFrame.Visible = true
		scoreLabel.Text = "Score: 0"
		comboLabel.Text = ""
		powerUpLabel.Text = ""
		levelLabel.Text = "Level 1"
		timerLabel.Text = "2:00"
		timerBarFill.Size = UDim2.new(1,0,1,0)
		spectateLabel.Visible = false
		spectateNextBtn.Visible = false
		quitGameBtn.Visible = true
		if mobileDpadFrame then mobileDpadFrame.Visible = true end
		if data and data.isMulti then
			isMultiGame = true
			aliveLabel.Text = (data.playerCount or "?") .. " alive"
		else
			isMultiGame = false
			aliveLabel.Text = ""
		end
	elseif state == "SPECTATING" then
		hudFrame.Visible = true
		spectateLabel.Visible = true
		spectateNextBtn.Visible = true
		quitGameBtn.Visible = true
		if mobileDpadFrame then mobileDpadFrame.Visible = true end
		local tgt = data and data.targetName or "?"
		spectateLabel.Text = "Spectating: " .. tgt
	elseif state == "GAME_OVER" then
		setOpenWorldVisible(true)
		currentMiniGameKey = (data and data.gameType and data.gameType ~= "SNAKE") and data.gameType or nil
		goFrame.Visible = true
		if data then
			finalScoreLabel.Text = "Score: " .. tostring(data.score or 0)
			finalLengthLabel.Text = "Length: " .. tostring(data.length or 0)
			finalLevelLabel.Text = "Level: " .. tostring(data.level or 1)

			if data.isMulti and data.results then
				winnerLabel.Text = "Winner: " .. (data.winner or "Nobody")
				winnerLabel.Visible = true
				multiResultsFrame.Visible = true
				for _, child in multiResultsFrame:GetChildren() do
					if child:IsA("TextLabel") then child:Destroy() end
				end
				local PLACE_COLORS = {Color3.fromRGB(255,215,0), Color3.fromRGB(192,192,192), Color3.fromRGB(205,127,50)}
				for _, r in data.results do
					local color = PLACE_COLORS[r.placement] or Color3.fromRGB(180,180,200)
					if r.name == player.Name then color = Color3.fromRGB(57,255,20) end
					local row = mkLabel({text="#"..r.placement.." "..r.name.." - "..formatScore(r.score),
						color=color, size=UDim2.new(0.95,0,0,24),
						font=Enum.Font.GothamBold, parent=multiResultsFrame})
					row.TextXAlignment = Enum.TextXAlignment.Left
				end
			else
				winnerLabel.Visible = false
				multiResultsFrame.Visible = false
			end
		end
	end
end)

SpectateTargetEvent.OnClientEvent:Connect(function(targetName)
	spectateLabel.Text = "Spectating: " .. targetName
end)

ScoreUpdatedEvent.OnClientEvent:Connect(function(data)
	scoreLabel.Text = "Score: " .. tostring(data.score)
	if data.comboCount >= 2 then
		comboLabel.Text = data.comboCount.."x COMBO! (x"..string.format("%.1f", data.comboMultiplier)..")"
		comboLabel.TextTransparency = 0
		TweenService:Create(comboLabel, TweenInfo.new(2), {TextTransparency=0.5}):Play()
	else
		comboLabel.Text = ""
	end
end)

PowerUpActivatedEvent.OnClientEvent:Connect(function(puType, duration)
	if duration <= 0 then
		powerUpLabel.Text = puType .. " activated!"
		task.delay(1, function() powerUpLabel.Text = "" end)
		return
	end
	powerUpLabel.TextColor3 = if puType == "SpeedBoost"
		then Color3.fromRGB(255,200,0) else Color3.fromRGB(180,0,255)
	local endTime = tick() + duration
	task.spawn(function()
		while tick() < endTime do
			powerUpLabel.Text = puType..": "..math.ceil(endTime-tick()).."s"
			task.wait(0.5)
		end
		powerUpLabel.Text = ""
	end)
end)

local prevLevel = 1
LevelUpdatedEvent.OnClientEvent:Connect(function(data)
	local remaining = data.levelDuration - data.timeInLevel
	local mins = math.floor(remaining / 60)
	local secs = remaining % 60
	levelLabel.Text = "Level " .. data.level
	timerLabel.Text = string.format("%d:%02d", mins, secs)
	timerBarFill.Size = UDim2.new(math.clamp(remaining/data.levelDuration, 0, 1), 0, 1, 0)
	if data.level > prevLevel then
		prevLevel = data.level
		levelLabel.TextColor3 = Color3.fromRGB(255,255,50)
		TweenService:Create(levelLabel, TweenInfo.new(1), {TextColor3=Color3.fromRGB(0,220,255)}):Play()
		local flash = mkLabel({text="LEVEL "..data.level.."!", color=Color3.fromRGB(255,255,50),
			size=UDim2.new(0.4,0,0.1,0), pos=UDim2.new(0.5,0,0.4,0),
			anchor=Vector2.new(0.5,0.5), font=Enum.Font.GothamBlack, parent=gui, stroke=0})
		flash.TextTransparency = 0
		TweenService:Create(flash, TweenInfo.new(1.5, Enum.EasingStyle.Quad), {TextTransparency=1, Position=UDim2.new(0.5,0,0.35,0)}):Play()
		task.delay(1.6, function() flash:Destroy() end)
	end
end)

-- Handle Escape key to quit game
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Escape then
		hudFrame.Visible = false
		goFrame.Visible = false
		ReturnToWorldEvent:FireServer()
	end
end)

print("[SnakeGame] UIController loaded")
