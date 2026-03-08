-- GameRegistry v1  |  ReplicatedStorage.SGH.GameRegistry
-- Master list of all registered SmallGameHeaven mini-games.
--
-- To add a new game, add one entry here + create its server/client scripts.
-- Portal colour, name, and player limits are all driven from this table.

local GameRegistry = {}

GameRegistry.Games = {
	SNAKE = {
		key        = "SNAKE",
		name       = "Snake World",
		color      = Color3.fromRGB(57, 255, 20),
		minPlayers = 1,
		maxPlayers = 4,
		desc       = "Eat, grow, survive.",
	},
	MAZE = {
		key        = "MAZE",
		name       = "Maze World",
		color      = Color3.fromRGB(180, 0, 255),
		minPlayers = 1,
		maxPlayers = 4,
		desc       = "Escape the labyrinth before time runs out.",
	},
	LAVA = {
		key        = "LAVA",
		name       = "Lava Floor",
		color      = Color3.fromRGB(255, 80, 0),
		minPlayers = 1,
		maxPlayers = 4,
		desc       = "Don't touch the lava.",
	},
	RHYTHM = {
		key        = "RHYTHM",
		name       = "Rhythm Tiles",
		color      = Color3.fromRGB(255, 50, 200),
		minPlayers = 1,
		maxPlayers = 4,
		desc       = "Hit the tiles on the beat.",
	},
	FLOOD = {
		key        = "FLOOD",
		name       = "Color Flood",
		color      = Color3.fromRGB(0, 255, 150),
		minPlayers = 1,
		maxPlayers = 4,
		desc       = "Flood the board with your color.",
	},
	ASTEROID = {
		key        = "ASTEROID",
		name       = "Asteroid Blast",
		color      = Color3.fromRGB(0, 200, 255),
		minPlayers = 1,
		maxPlayers = 4,
		desc       = "Blast the asteroids before they hit you.",
	},
}

function GameRegistry.Get(key)
	return GameRegistry.Games[key]
end

function GameRegistry.GetAll()
	local list = {}
	for _, g in GameRegistry.Games do table.insert(list, g) end
	return list
end

return GameRegistry
