-- ObstacleManager
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Config = require(ReplicatedStorage:WaitForChild("SnakeGame"):WaitForChild("Config"))
local HALF = Config.ARENA_SIZE.X/2 - 8
local GY   = Config.GAME_Y
local NEON = Enum.Material.Neon
local obsFolder = workspace:FindFirstChild("ObstacleItems") or (function()
	local f = Instance.new("Folder"); f.Name="ObstacleItems"; f.Parent=workspace; return f
end)()
local ObstacleManager = {}; ObstacleManager.__index = ObstacleManager
local function weightedRandom(types)
	local total = 0
	for _, t in types do total += t.weight end
	local r = math.random() * total
	for _, t in types do r -= t.weight; if r <= 0 then return t end end
	return types[1]
end
local function rpos() return math.random(-HALF,HALF), math.random(-HALF,HALF) end
local function mk(sz,col,mat,x,y,z,cc,tr)
	local p=Instance.new("Part"); p.Size=sz; p.Color=col; p.Material=mat
	p.Anchored=true; p.CanCollide=(cc~=false); p.CastShadow=false; p.Transparency=tr or 0
	p.Position=Vector3.new(x,y,z); p.Parent=obsFolder; return p
end
local function gl(par,col,rng,br)
	local l=Instance.new("PointLight"); l.Color=col; l.Range=rng; l.Brightness=br; l.Parent=par
end
local function makeObs(otype)
	local x,z = rpos()
	local n   = otype.name
	local col = otype.color or otype.trunkColor or Color3.fromRGB(50,50,50)
	local mat = otype.material or otype.trunkMat or Enum.Material.SmoothPlastic
	local all = {}
	local function track(p) if p then table.insert(all, p) end end
	if n == "NeonTree" then
		local th=math.random(4,7)
		track(mk(Vector3.new(1.5,th,1.5), otype.trunkColor or Color3.fromRGB(60,35,20),
			otype.trunkMat or Enum.Material.Wood, x,GY+th/2,z))
		local cr=math.random(3,5)
		local can=mk(Vector3.new(cr*2,cr*1.5,cr*2), otype.canopyColor or Color3.fromRGB(20,90,35),
			otype.canopyMat or Enum.Material.Grass, x,GY+th+cr*0.65,z,false)
		can.Shape=Enum.PartType.Ball; track(can)
	elseif n == "CrystalPillar" then
		local h=math.random(8,16)
		track(mk(Vector3.new(2,h,2),col,mat,x,GY+h/2,z))
		local cap=mk(Vector3.new(2,2,2),Color3.fromRGB(100,70,170),NEON,x,GY+h+1,z,false)
		cap.Shape=Enum.PartType.Ball; gl(cap,Color3.fromRGB(130,80,230),18,2.5); track(cap)
	elseif n == "NeonPillar" then
		local h=math.random(6,14)
		local p=mk(Vector3.new(1.5,h,1.5),col,mat,x,GY+h/2,z)
		gl(p, otype.glowColor or col, 22,3); track(p)
	elseif n == "Wall" then
		local s=math.random(4,8)
		track(mk(Vector3.new(s,s*1.5,s),col,mat,x,GY+s*0.75,z))
	elseif n == "Barrier" then
		local s=math.random(3,5)
		local p=mk(Vector3.new(s,s,s),col,mat,x,GY+s/2,z)
		gl(p,Color3.fromRGB(255,60,60),16,2.5); track(p)
	elseif n == "Rock" then
		local s=math.random(3,6)
		local p=mk(Vector3.new(s,s*0.7,s),col,mat,x,GY+s*0.35,z)
		p.Shape=Enum.PartType.Ball; track(p)
	elseif n == "IceBlock" then
		local s=math.random(4,8)
		local p=mk(Vector3.new(s,s,s),col,mat,x,GY+s/2,z,true,0.4)
		gl(p,Color3.fromRGB(150,210,255),14,1.5); track(p)
	elseif n == "Ruins" then
		local bw=math.random(4,7)
		for i=1,math.random(2,4) do
			local w=math.max(2,bw-(i-1)*1.5)
			track(mk(Vector3.new(w,2,w),col,mat,x,GY+(i-1)*2+1,z,i==1))
		end
	else
		local h=math.random(3,8)
		track(mk(Vector3.new(math.random(2,4),h,math.random(2,4)),col,mat,x,GY+h/2,z))
	end
	for _, p in all do p:SetAttribute("IsObstacle",true) end
	return all
end
function ObstacleManager.new()
	local self = setmetatable({}, ObstacleManager); self.parts = {}; return self
end
function ObstacleManager:spawn(count)
	for i = 1, count do
		local parts = makeObs(weightedRandom(Config.OBSTACLE_TYPES))
		for _, p in ipairs(parts) do table.insert(self.parts, p) end
	end
end
function ObstacleManager:spawnBatch(count)
	self:spawn(math.min(count, Config.MAX_OBSTACLES - #self.parts))
end
function ObstacleManager:check(pos)
	for _, p in self.parts do
		if p and p.Parent then
			local r = math.max(p.Size.X, p.Size.Z) / 2 + 0.5
			if (p.Position - pos).Magnitude < r then return true end
		end
	end
	for _, p in CollectionService:GetTagged("SnakeDecorKillable") do
		if p and p.Parent then
			local r = math.max(p.Size.X, p.Size.Z) / 2 + 0.5
			if (p.Position - pos).Magnitude < r then return true end
		end
	end
	return false
end
function ObstacleManager:cleanup()
	pcall(function() obsFolder:ClearAllChildren() end)
	self.parts = {}
end
return ObstacleManager
