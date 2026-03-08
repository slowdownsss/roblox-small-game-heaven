-- MusicController: plays background music tracks in a shuffled loop
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Config = require(ReplicatedStorage:WaitForChild("SnakeGame"):WaitForChild("Config"))

local MUSIC_IDS = Config.MUSIC_IDS
local VOLUME = Config.MUSIC_VOLUME or 0.25

-- Create sound objects
local sounds = {}
for i, id in MUSIC_IDS do
	local s = Instance.new("Sound")
	s.Name = "BGMusic_" .. i
	s.SoundId = id
	s.Volume = VOLUME
	s.RollOffMaxDistance = 0
	s.Parent = SoundService
	table.insert(sounds, s)
end

-- Shuffle helper
local function shuffle(t)
	for i = #t, 2, -1 do
		local j = math.random(i)
		t[i], t[j] = t[j], t[i]
	end
end

-- Play in a continuous shuffled loop
local function playLoop()
	local order = {}
	for i = 1, #sounds do order[i] = i end
	shuffle(order)
	local idx = 1
	while true do
		local snd = sounds[order[idx]]
		snd:Play()
		snd.Ended:Wait()
		idx += 1
		if idx > #order then
			shuffle(order)
			idx = 1
		end
	end
end

task.spawn(playLoop)
