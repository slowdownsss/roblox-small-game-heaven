# Roblox Game Development with Studio MCP

A practical guide for using the Roblox Studio MCP to build Roblox games with AI assistance.

---

## 1. Studio MCP Workflow

### Available Tools

| Tool | Purpose |
|---|---|
| `list_roblox_studios` | List open Studio instances — always call first |
| `set_active_studio` | Switch target when multiple studios are open |
| `search_game_tree` | Explore the DataModel hierarchy |
| `inspect_instance` | Read properties/attributes of a specific instance |
| `script_read` | Read a script's full source |
| `script_search` | Find scripts by name (fuzzy match) |
| `script_grep` | Search script contents by pattern |
| `multi_edit` | Edit multiple scripts in one call |
| `execute_luau` | Run Luau code in Studio (server context) |
| `get_console_output` | Read output/error logs |
| `start_stop_play` | Toggle playtest mode |
| `character_navigation` | Move a character during playtesting |
| `user_keyboard_input` / `user_mouse_input` | Simulate input during playtesting |

### Recommended Starting Workflow

```
1. list_roblox_studios          → confirm which game is active
2. search_game_tree             → get the high-level DataModel structure
3. search_game_tree (focused)   → drill into ServerScriptService, ReplicatedStorage, StarterPlayer
4. script_search / script_grep  → locate scripts related to the feature you're working on
5. script_read                  → read full source before making any edits
6. multi_edit                   → apply changes
7. execute_luau                 → verify state or test logic live
8. get_console_output           → check for errors
```

Always read a script fully before editing it. Never guess at structure — use `search_game_tree` first.

---

## 2. Roblox DataModel — Where Things Live

Understanding which container to use is fundamental. Scripts only run in the right context.

```
game (DataModel)
├── Workspace                   — 3D world; Parts, Models visible to all
├── ServerScriptService         — Server Scripts only; never replicated to clients
├── ServerStorage               — Server-only assets; never replicated
├── ReplicatedStorage           — Shared by server AND clients; ModuleScripts, RemoteEvents
├── ReplicatedFirst             — Loaded on client BEFORE anything else (loading screens)
├── StarterGui                  — LocalScripts + UI; cloned into each player's PlayerGui
├── StarterPlayer
│   ├── StarterPlayerScripts    — LocalScripts that run when player joins
│   └── StarterCharacterScripts — LocalScripts that run each time character spawns
├── StarterPack                 — Tools given to players on spawn
├── SoundService                — Global sounds
├── Players                     — Runtime player data (not a storage location)
└── Lighting                    — Atmosphere, sky, post-processing
```

### Script Type Rules

| Script Type | Runs On | Typical Location |
|---|---|---|
| `Script` | Server | `ServerScriptService`, `Workspace` |
| `LocalScript` | Client | `StarterGui`, `StarterPlayerScripts`, `StarterCharacterScripts` |
| `ModuleScript` | Whichever requires it | `ReplicatedStorage` (shared), `ServerScriptService` (server-only) |

---

## 3. Recommended Project Structure

```
ServerScriptService/
└── Server/
    ├── Main.server.luau         — Entry point: wires up services
    ├── PlayerService.luau       — Player join/leave, data loading
    ├── GameService.luau         — Core game loop
    └── ...

ReplicatedStorage/
├── Shared/
│   ├── Config.luau              — Shared constants (no instances, pure data)
│   ├── Types.luau               — Luau type exports
│   └── Utils.luau               — Pure utility functions
├── Network/
│   └── Remotes.luau             — Single module that owns all RemoteEvents/Functions
└── Packages/                    — Third-party modules (ProfileStore, etc.)

StarterPlayer/StarterPlayerScripts/
└── Client/
    ├── Main.client.luau         — Entry point
    ├── UIController.luau        — All UI logic
    ├── InputHandler.luau        — Input mapping
    └── CameraController.luau    — Camera behavior
```

Key principles:
- One entry-point script per side (server/client) that `require`s everything else.
- ModuleScripts contain all real logic; Scripts/LocalScripts are thin bootstrappers.
- Config and Types live in `ReplicatedStorage/Shared` so both sides can read them.

---

## 4. Server–Client Communication

### The Golden Rule
**Never trust the client.** All game state lives on the server. Clients send *intent*, servers validate and act.

### RemoteEvent vs RemoteFunction

| | `RemoteEvent` | `RemoteFunction` |
|---|---|---|
| Direction | Fire-and-forget (both directions) | Request/response |
| Blocks caller? | No | Yes (client blocks waiting) |
| Use for | Actions, notifications | Queries that need a return value |
| Risk | None | Server crash if client disconnects mid-call |

Prefer `RemoteEvent` for most things. Use `RemoteFunction` sparingly — only for short queries where you need a return value (e.g., fetching leaderboard data).

### Centralize Remotes in One Module

Instead of scattering RemoteEvents across the DataModel, own them in one place:

```lua
-- ReplicatedStorage/Network/Remotes.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function getOrCreate(parent, className, name)
    return parent:FindFirstChild(name) or (function()
        local r = Instance.new(className)
        r.Name = name
        r.Parent = parent
        return r
    end)()
end

local folder = getOrCreate(ReplicatedStorage, "Folder", "Remotes")

return {
    -- Client -> Server
    PlayerAction  = getOrCreate(folder, "RemoteEvent",    "PlayerAction"),
    StartGame     = getOrCreate(folder, "RemoteEvent",    "StartGame"),
    -- Server -> Client
    GameState     = getOrCreate(folder, "RemoteEvent",    "GameState"),
    ScoreUpdated  = getOrCreate(folder, "RemoteEvent",    "ScoreUpdated"),
    -- Queries
    GetLeaderboard = getOrCreate(folder, "RemoteFunction", "GetLeaderboard"),
}
```

Both server and client `require` this same module. No magic string lookups anywhere else.

### Server-Side Validation Pattern

```lua
-- Always validate on the server before acting
Remotes.PlayerAction.OnServerEvent:Connect(function(player, actionType, data)
    -- 1. Type-check inputs
    if type(actionType) ~= "string" then return end
    if type(data) ~= "table" then return end

    -- 2. Check player state (are they allowed to do this right now?)
    local session = Sessions[player]
    if not session or session.state ~= "PLAYING" then return end

    -- 3. Sanity-check the values
    if not VALID_ACTIONS[actionType] then return end

    -- 4. Act
    handleAction(player, actionType, data)
end)
```

---

## 5. ModuleScript OOP Pattern

Roblox's standard OOP pattern using metatables:

```lua
-- MySystem.luau
local MySystem = {}
MySystem.__index = MySystem

function MySystem.new(config)
    local self = setmetatable({}, MySystem)
    self.config = config
    self.active = false
    -- initialize fields here, not in methods
    return self
end

function MySystem:start()
    self.active = true
    -- logic
end

function MySystem:stop()
    self.active = false
    -- cleanup connections, instances, etc.
end

function MySystem:destroy()
    self:stop()
    -- destroy any Instances this object created
end

return MySystem
```

Usage:
```lua
local MySystem = require(ReplicatedStorage.Shared.MySystem)
local sys = MySystem.new({ speed = 10 })
sys:start()
```

### Connection Cleanup

Always store and disconnect `RBXScriptConnection`s when done, or you'll get memory leaks and ghost callbacks:

```lua
function MySystem:start()
    self._connections = {}
    table.insert(self._connections,
        RunService.Heartbeat:Connect(function(dt)
            self:_tick(dt)
        end)
    )
end

function MySystem:destroy()
    for _, conn in self._connections do
        conn:Disconnect()
    end
    self._connections = {}
end
```

---

## 6. Player Data Persistence

Use **ProfileStore** (the successor to ProfileService) rather than raw `DataStoreService`. It handles session locking, auto-save, and data migration safely.

```lua
-- Server/PlayerService.luau
local ProfileStore = require(ReplicatedStorage.Packages.ProfileStore)

local TEMPLATE = {
    coins = 0,
    level = 1,
    inventory = {},
}

local Store = ProfileStore.New("PlayerData_v1", TEMPLATE)
local Profiles = {}

local function onPlayerAdded(player)
    local profile = Store:StartSessionAsync("Player_" .. player.UserId, {
        Cancel = function()
            return not player:IsDescendantOf(Players)
        end,
    })

    if not profile then
        player:Kick("Data failed to load. Please rejoin.")
        return
    end

    profile:AddUserId(player.UserId) -- GDPR compliance
    Profiles[player] = profile

    -- Expose data to the rest of the server
    -- (replicate what the client needs via RemoteEvent)
end

local function onPlayerRemoving(player)
    local profile = Profiles[player]
    if profile then
        profile:EndSession()
        Profiles[player] = nil
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
-- Handle players already in-game when script loads
for _, player in Players:GetPlayers() do
    task.spawn(onPlayerAdded, player)
end
```

Rules:
- Never access DataStore directly from a LocalScript.
- Always kick a player if their data fails to load — don't let them play with no data.
- Prefix store keys with a version (`_v1`, `_v2`) so you can migrate safely.
- Never give the client a direct reference to the profile; replicate only what they need.

---

## 7. Performance Guidelines

### Use `task.*` not `spawn`/`wait`/`delay`

```lua
-- Bad (deprecated, unpredictable timing)
spawn(fn)
wait(1)
delay(1, fn)
coroutine.wrap(fn)()

-- Good
task.spawn(fn)
task.wait(1)
task.delay(1, fn)
```

### Heartbeat Accumulator (fixed timestep)

Don't move game objects every single Heartbeat if you want deterministic intervals:

```lua
local INTERVAL = 0.2
local accum = 0

RunService.Heartbeat:Connect(function(dt)
    accum += dt
    if accum < INTERVAL then return end
    accum -= INTERVAL
    -- tick logic here
end)
```

### Instance Creation

- Batch `Instance.new` calls; set all properties before setting `.Parent` (parenting triggers replication).
- Use `workspace:BulkMoveTo()` for moving many parts at once.
- Pool frequently created/destroyed objects (bullets, particles anchors, etc.) rather than creating new ones.
- Tag reusable objects with `CollectionService` to find them efficiently.

### Avoid Per-Frame Searches

```lua
-- Bad: searches entire workspace every frame
RunService.Heartbeat:Connect(function()
    local parts = workspace:GetDescendants()
    ...
end)

-- Good: cache references at startup
local parts = workspace.MyFolder:GetChildren()
RunService.Heartbeat:Connect(function()
    for _, part in parts do ... end
end)
```

---

## 8. Security Checklist

- [ ] All game state (health, score, inventory, position) is authoritative on the **server**.
- [ ] Every `OnServerEvent` handler validates: correct types, correct player state, value ranges.
- [ ] `RemoteFunction.OnServerInvoke` always returns a value (never errors silently) and uses `pcall` internally.
- [ ] No sensitive logic or secrets exist in `ReplicatedStorage` or `StarterGui` — clients can read these.
- [ ] Rate-limit inputs: ignore or kick players who fire remotes faster than physically possible.
- [ ] Use `CollectionService` tags to mark server-managed objects; never trust a client-passed Instance reference.
- [ ] Player data is only modified server-side, never via RemoteEvent payload directly.

---

## 9. Common Patterns Quick Reference

### Waiting for a child safely
```lua
-- With timeout
local child = parent:WaitForChild("Name", 10)
if not child then warn("Not found") return end
```

### Tween a property
```lua
local TweenService = game:GetService("TweenService")
local tween = TweenService:Create(part, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
    CFrame = targetCFrame,
    Transparency = 1,
})
tween:Play()
tween.Completed:Wait() -- if you need to wait for it
```

### Fire to all clients except one
```lua
for _, player in Players:GetPlayers() do
    if player ~= excludePlayer then
        MyRemote:FireClient(player, data)
    end
end
```

### CollectionService tagging
```lua
-- Tag on creation (server)
CollectionService:AddTag(part, "Obstacle")

-- Query tagged objects (server or client)
for _, obj in CollectionService:GetTagged("Obstacle") do
    -- act on obj
end
```

### Attribute-based data on Instances
```lua
-- Set (server)
part:SetAttribute("Health", 100)
part:SetAttribute("Type", "Crystal")

-- Read (anywhere)
local hp = part:GetAttribute("Health")

-- Listen for changes (client)
part:GetAttributeChangedSignal("Health"):Connect(function()
    updateHealthBar(part:GetAttribute("Health"))
end)
```

---

## 10. MCP-Specific Tips

- **Read before editing.** Always call `script_read` on a file before using `multi_edit`.
- **Use `execute_luau` to inspect live state**, e.g.:
  ```lua
  -- Check what's currently in workspace
  for _, child in workspace:GetChildren() do print(child.Name, child.ClassName) end
  ```
- **`search_game_tree` with filters** is far faster than exploring the whole tree:
  ```
  search_game_tree(instance_type="BaseScript")    -- all scripts
  search_game_tree(keywords="snake, food")        -- by name keyword
  search_game_tree(path="ServerScriptService", max_depth=5)
  ```
- **`get_console_output` after any `execute_luau` call** to catch errors.
- **Don't edit scripts while a playtest is running** unless you intentionally want hot-reload behavior — it can produce confusing state.
- **Prefer `multi_edit` for related changes** across multiple scripts to keep them atomic and easier to review.

---

## Sources

- [Roblox Creator Docs — Remote Events](https://create.roblox.com/docs/scripting/events/remote)
- [Roblox Creator Docs — Module Scripts](https://github.com/Roblox/creator-docs/blob/main/content/en-us/scripting/module.md)
- [ProfileStore (DataStore Module)](https://devforum.roblox.com/t/profilestore-save-your-player-data-easy-datastore-module/3190543)
- [Best Practices Handbook — Roblox DevForum](https://devforum.roblox.com/t/best-practices-handbook/2593598)
- [Securing RemoteEvents — Roblox DevForum](https://devforum.roblox.com/t/how-to-secure-your-remoteevent-and-remotefunction/3345363)
- [Luau Optimizations — Roblox DevForum](https://devforum.roblox.com/t/luau-optimizations-make-your-game-run-faster/4378272)
- [Roblox Studio MCP — GitHub (boshyxd)](https://github.com/boshyxd/robloxstudio-mcp)
- [Vibecoding in Roblox (MCP + Cursor)](https://blog.justforward.co/vibecoding-in-roblox-mcp-cursor-ai-rojo-88be3f1d4035)
