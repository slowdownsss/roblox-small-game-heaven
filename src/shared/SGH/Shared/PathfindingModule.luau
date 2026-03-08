-- PathfindingModule: returns straight-line waypoints between two positions.
-- MazeGame enemies fall back gracefully (patrollers use waypoints,
-- chasers move directly toward the player) so simple point-to-point is fine.
local PathfindingModule = {}

function PathfindingModule.computePath(from, to)
	return {from, to}
end

return PathfindingModule
