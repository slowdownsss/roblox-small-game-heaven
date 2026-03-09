-- SnakeController
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Config = require(ReplicatedStorage:WaitForChild("SnakeGame"):WaitForChild("Config"))

local HALF = Config.ARENA_SIZE.X/2 - 4
local SEG = Config.SEGMENT_SPACING
local SS = Config.SEGMENT_SIZE

local SnakeController = {}
SnakeController.__index = SnakeController

local segFolder = workspace:FindFirstChild("SnakeSegments") or (function()
	local f = Instance.new("Folder"); f.Name="SnakeSegments"; f.Parent=workspace; return f
end)()

local function makePart(color, size, mat, pos)
	local p = Instance.new("Part")
	p.Anchored=true; p.CanCollide=false; p.CastShadow=false
	p.Size=size or SS; p.Color=color; p.Material=mat or Enum.Material.Neon
	p.Position=pos or Vector3.zero; p.Parent=segFolder
	return p
end

local function attachNameTag(headPart, playerName, headColor)
	local bb = Instance.new("BillboardGui")
	bb.Name = "NameTag"
	bb.Size = UDim2.new(0,120,0,28)
	bb.StudsOffset = Vector3.new(0,3.5,0)
	bb.AlwaysOnTop = true
	bb.Parent = headPart
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1,0,1,0)
	lbl.BackgroundTransparency = 1
	lbl.Text = playerName
	lbl.TextColor3 = headColor or Color3.new(1,1,1)
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.TextStrokeTransparency = 0.3
	lbl.Parent = bb
end

function SnakeController.new(player, style)
	local self = setmetatable({}, SnakeController)
	self.player = player
	self.style = style or Config.SNAKE_STYLES[1]
	self.segments = {}
	self.direction = Vector3.new(1,0,0)
	self.pendingDir = nil
	self.moveTimer = 0
	self.speed = Config.BASE_MOVE_SPEED
	self.alive = true
	return self
end

function SnakeController:spawn()
	local style = self.style
	for i = 1, Config.INITIAL_LENGTH do
		local pos = Vector3.new(-(i-1)*SEG, Config.GAME_Y + SS.Y/2, 0)
		local color = (i==1) and style.headColor or style.bodyColor
		local part = makePart(color, SS, style.material or Enum.Material.Neon, pos)
		if i == 1 then
			-- Tag head for CameraController
			CollectionService:AddTag(part, "SnakeHead")
			attachNameTag(part, self.player.Name, style.headColor)
			-- Eyes
			self.eye1 = makePart(style.eyeColor or Color3.new(1,1,1), Vector3.new(0.4,0.4,0.1),
				Enum.Material.SmoothPlastic, pos + Vector3.new(0.3,0.3,SS.Z/2))
			self.eye2 = makePart(style.eyeColor or Color3.new(1,1,1), Vector3.new(0.4,0.4,0.1),
				Enum.Material.SmoothPlastic, pos + Vector3.new(-0.3,0.3,SS.Z/2))
		end
		table.insert(self.segments, part)
	end
end

function SnakeController:setDirection(dir)
	if not dir then return end
	if self.direction.X ~= 0 and dir.X ~= 0 then return end
	if self.direction.Z ~= 0 and dir.Z ~= 0 then return end
	self.pendingDir = Vector3.new(dir.X, 0, dir.Z).Unit
end

function SnakeController:setSpeedLevel(level)
	self.speed = Config.BASE_MOVE_SPEED * (Config.SPEED_LEVEL_MULTIPLIER ^ (level-1))
end

function SnakeController:length() return #self.segments end

function SnakeController:tick(dt, foodMgr, obsMgr)
	if not self.alive then return false end
	self.moveTimer += dt
	local interval = SEG / self.speed
	if self.moveTimer < interval then return true end
	self.moveTimer -= interval
	if self.pendingDir then self.direction = self.pendingDir; self.pendingDir = nil end
	local head = self.segments[1]
	local newPos = head.Position + self.direction * SEG
	if math.abs(newPos.X) > HALF or math.abs(newPos.Z) > HALF then
		self.alive = false; return false
	end
	for i = 3, #self.segments do
		if (self.segments[i].Position - newPos).Magnitude < SEG * 0.8 then
			self.alive = false; return false
		end
	end
	if obsMgr and obsMgr:check(newPos) then self.alive = false; return false end
	for i = #self.segments, 2, -1 do self.segments[i].Position = self.segments[i-1].Position end
	head.Position = newPos
	if self.eye1 then
		local fwd = self.direction; local right = Vector3.new(-fwd.Z,0,fwd.X)
		self.eye1.Position = newPos + right*0.3 + Vector3.new(0,0.3,0) + fwd*(SS.Z/2)
		self.eye2.Position = newPos - right*0.3 + Vector3.new(0,0.3,0) + fwd*(SS.Z/2)
	end
	if foodMgr then
		local hitFood, foodType = foodMgr:check(newPos)
		if hitFood then
			local tail = self.segments[#self.segments]
			local newSeg = makePart(self.style.bodyColor, SS, self.style.material or Enum.Material.Neon, tail.Position)
			table.insert(self.segments, newSeg)
			return true, hitFood, foodType
		end
	end
	return true
end

function SnakeController:cleanup()
	self.alive = false
	for _, p in self.segments do
		pcall(function()
			CollectionService:RemoveTag(p, "SnakeHead")
			p:Destroy()
		end)
	end
	self.segments = {}
	if self.eye1 then pcall(function() self.eye1:Destroy() end) end
	if self.eye2 then pcall(function() self.eye2:Destroy() end) end
end

return SnakeController
