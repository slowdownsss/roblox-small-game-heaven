-- CharacterUtils: hide/show character, teleport — shared by all games
local CharacterUtils = {}

function CharacterUtils.Hide(player, savePosition)
	savePosition = savePosition ~= false
	local char = player.Character
	if not char then return nil end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local savedCF = nil
	if hrp then
		if savePosition and hrp.Position.Y > -10 then
			savedCF = hrp.CFrame
		end
		hrp.Anchored = true
		hrp.CFrame = CFrame.new(0, -100, 0)
	end
	for _, p in char:GetDescendants() do
		if p:IsA("BasePart") then
			p.Transparency = 1
			p.CanCollide = false
		end
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = 0
		hum.JumpHeight = 0
	end
	return savedCF
end

function CharacterUtils.Show(player, savedCF, defaultCF)
	local char = player.Character
	if not char then
		player:LoadCharacter()
		task.wait(1)
		char = player.Character
		if not char then return end
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local cf = savedCF or defaultCF or CFrame.new(0, 2, 0)
	if hrp then
		hrp.Anchored = true
		hrp.CFrame = cf
		hrp.Anchored = false
	end
	for _, p in char:GetDescendants() do
		if p:IsA("BasePart") then
			p.Transparency = 0
			p.CanCollide = (p.Name ~= "HumanoidRootPart")
		end
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Health = hum.MaxHealth
		hum.WalkSpeed = 16
		hum.JumpHeight = 7.2
	end
end

function CharacterUtils.HideWithoutSaving(player)
	CharacterUtils.Hide(player, false)
end

return CharacterUtils
