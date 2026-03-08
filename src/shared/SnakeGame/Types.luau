export type GameState = "IDLE" | "COUNTDOWN" | "PLAYING" | "PAUSED" | "GAME_OVER"

export type PowerUpType = "SpeedBoost" | "Invincibility" | "Shrink"

export type SnakeState = {
	segments: {BasePart},
	direction: Vector3,
	pendingDirection: Vector3,
	isInvincible: boolean,
	activePowerUps: {[PowerUpType]: number},
	moveSpeed: number,
	moveInterval: number,
}

export type ScoreState = {
	score: number,
	comboCount: number,
	comboMultiplier: number,
	lastPickupTime: number,
}

return {}
