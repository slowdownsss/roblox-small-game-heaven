-- FoodManager
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("SnakeGame"):WaitForChild("Config"))
local HALF = Config.ARENA_SIZE.X/2 - 6
local FOOD_Y = Config.FOOD_FLOAT_Y
local foodFolder = workspace:FindFirstChild("FoodItems") or (function()
	local f = Instance.new("Folder"); f.Name="FoodItems"; f.Parent=workspace; return f
end)()
local FoodManager = {}; FoodManager.__index = FoodManager
local function weightedRandom(types)
	local total = 0
	for _, t in types do total += t.weight end
	local r = math.random() * total
	for _, t in types do r -= t.weight; if r <= 0 then return t end end
	return types[1]
end
local function randomPos()
	return Vector3.new(math.random(-HALF*10,HALF*10)/10, FOOD_Y, math.random(-HALF*10,HALF*10)/10)
end
local function makeFood(ftype)
	local part = Instance.new("Part")
	part.Shape = ftype.shape=="Ball" and Enum.PartType.Ball or Enum.PartType.Block
	part.Size=ftype.size; part.Color=ftype.color; part.Material=Enum.Material.Neon
	part.Anchored=true; part.CanCollide=false; part.CastShadow=false
	part.Position=randomPos(); part:SetAttribute("FoodType", ftype.name)
	local light = Instance.new("PointLight")
	light.Color=ftype.glowColor; light.Range=ftype.lightRange; light.Brightness=ftype.lightBrightness; light.Parent=part
	part.Parent=foodFolder; return part
end
function FoodManager.new()
	local self = setmetatable({}, FoodManager); self.items = {}; return self
end
function FoodManager:spawn(count)
	for i = 1, count do
		local ftype = weightedRandom(Config.FOOD_TYPES)
		self.items[makeFood(ftype)] = ftype
	end
end
function FoodManager:check(pos)
	for part, ftype in self.items do
		if (part.Position - pos).Magnitude < 2.5 then return part, ftype end
	end
	return nil
end
function FoodManager:respawnOne(oldPart)
	local ftype = self.items[oldPart]; self.items[oldPart] = nil
	pcall(function() oldPart:Destroy() end)
	if ftype then
		task.delay(Config.FOOD_RESPAWN_DELAY, function()
			self.items[makeFood(ftype)] = ftype
		end)
	end
end
function FoodManager:cleanup()
	for part in self.items do pcall(function() part:Destroy() end) end; self.items = {}
end
return FoodManager
