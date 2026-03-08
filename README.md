# Neon Snake Arena

A Roblox game featuring Snake Arena, Color Flood, Neon Maze, Lava Floor, Rhythm Tiles, and Asteroid Blast mini-games.

## Project Structure

```
src/
├── server/          → ServerScriptService
│   ├── SnakeGame/   → Game logic (GameManager, SnakeController, WorldBuilder, mini-games…)
│   └── SGH_Core/    → Shared hub services (ScoreService, HubManager)
├── shared/          → ReplicatedStorage
│   ├── SnakeGame/   → Config, Types
│   └── SGH/         → GameRegistry, shared modules
└── client/          → StarterPlayer/StarterPlayerScripts
    └── SnakeClient/ → UIController, CameraController, InputHandler, MusicController
```

## Setup

### Prerequisites
- [Aftman](https://github.com/LPGhatguy/aftman/releases) — Roblox toolchain manager
- Rojo Studio plugin (install once from Studio marketplace or manually)

### Install tools
```bash
aftman install          # installs rojo as specified in aftman.toml
```

### Sync from Studio → files (first time / after Studio edits)
Make sure Rojo plugin is running in Studio, then:
```bash
rojo syncback default.project.json
```

### Sync from files → Studio (ongoing development)
```bash
rojo serve default.project.json
```
Then click **Connect** in the Rojo Studio plugin. File saves auto-sync to Studio in real time.

## Workflow

```
Edit .luau files in VS Code
        ↓  (rojo serve is running)
Changes live-sync into Studio
        ↓
Playtest in Studio
        ↓
git add / commit / push
```

If you edit directly in Studio (e.g. quick tweaks via MCP/AI), run `rojo syncback` afterward to pull those changes back into files.
