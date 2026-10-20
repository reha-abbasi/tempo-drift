# scripts/

All the game code, written in GDScript (Godot's own language, files ending in `.gd`).
You can open them in Godot (double-click in the *FileSystem* panel) or in VS Code.

## Safe to tweak without coding knowledge

**`config.gd`: the tuning numbers.** Change a number, save, press **F5** in Godot to try it.

| Setting | What it controls | Now |
|---|---|---|
| `START_SPEED` | How fast a run starts (metres per second) | 14 |
| `MAX_SPEED` | The top speed the game builds up to | 32 |
| `SPEED_RAMP_TIME` | How quickly it speeds up. Bigger = slower build-up | 110 |
| `JUMP_VELOCITY` | Jump height. Bigger = higher jumps | 12 |
| `GRAVITY` | How quickly you fall back down | 34 |
| `SLIDE_TIME` | How long a slide lasts (seconds) | 0.75 |
| `LANE_CHANGE_TIME` | How long a lane switch takes (seconds) | 0.14 |
| `STUMBLE_WINDOW` | Two side bumps within this many seconds = game over | 4 |
| `MAGNET_TIME`, `DOUBLE_TIME` | How long the power-ups last (seconds) | 10, 12 |

Only change the number after `:=`. Leave the names and the `#` notes alone.

**`patterns.gd`: the obstacle layouts.** Each block in `LIST` is one short stretch of track.
The notes at the top of the file explain the format. The easiest way to add one is to copy an existing block,
give it a new `"name"`, and move things around. Or ask Claude: *"add a pattern with a train in the left lane and a sign in the middle"*.

## What the other files do

| File | What it handles |
|---|---|
| `game.gd` | The main rules: start/pause/game over, swipes and keys, crashes, score, camera |
| `player.gd` | The runner: switching lanes, jumping, sliding, the running animation, the character's look |
| `track.gd` | Creating obstacles, coins and scenery ahead of you and removing them behind you |
| `obstacle.gd` | The invisible boxes used to detect crashes and the surfaces you can run on |
| `world_kit.gd` | Builds the placeholder 3D objects (trains, hurdles, buildings, palm trees) from simple shapes |
| `mesh_kit.gd` | Small helpers for shapes and colours used by `world_kit.gd` and `player.gd` |
| `hud.gd` | Everything on screen: menu, score, coins, pause and game-over panels |
| `save_data.gd` | Remembers the best score and coins between plays |
| `sfx.gd` | Plays the sounds from `assets/audio/` |
| `autopilot.gd` | A robot player used by the tests to check that every layout can be beaten |

If you change one of these and the game breaks, ask Claude, or undo your edit with *Ctrl+Z* / *Cmd+Z*.
