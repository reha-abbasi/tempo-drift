# Tempo Drift — Godot version

The game remade in Godot 4.7, starting with one slice: **Past · Episode 1 · London 1890**.

## Open it

1. Start Godot 4.7 (`D:\Claude-sandbox\Software`).
2. **Import** → pick `D:\Claude-sandbox\2026-10-20_AI-Claude_Runner-Game\godot\game\project.godot` → **Import & Edit**.
3. Press **F5** (or the ▶ button) to play.

The first open takes a minute while Godot imports the music.

## Controls

| | Phone | PC |
|---|---|---|
| Change lane | swipe left / right | ← → or A D |
| Hop up / dive down | swipe up / down | ↑ ↓ or W S |

Every note is a ring: swipe into it just before its note for **EXCELLENT** (300), a little earlier for **GOOD** (200), long before for **OK** (100). The closing cue ring shows the best moment.

## What's where

| Folder | What |
|---|---|
| `game/scripts/game.gd` | the rules (lanes, grades, Flow, Overdrive, car → jetpack, rescue), carried over from the web game |
| `game/scripts/music.gd` | the soundtrack: 9 layers played in sync; the band follows your Flow, each note plays only when you're in its ring |
| `game/scripts/world_london.gd` | the street: terraces, roofs, chimneys, lamps, trees, Big Ben, rain and smoke (batched, so it's fast) |
| `game/scripts/models.gd` | the car, the pilot, motor cars, the bus, airships, barriers, the finish arch |
| `game/scripts/rings.gd`, `traffic.gd`, `fx.gd`, `hud.gd` | rings, vehicles, effects, HUD and cards |
| `game/shaders/` | bricks and windows, wet cobbles, slate, sky, glows, rain, smoke |
| `game/data/old_0.json` | the course: every ring and vehicle, baked from the web game |
| `game/audio/old_0/` | the soundtrack layers, baked from the web game's synth |
| `tools/bake.mjs` | bakes an episode from `web/game.html`: `node godot/tools/bake.mjs old 0` |

## Tests (command line)

```
godot --headless --path godot/game -- --sim                      # plays the episode with a perfect pilot, prints the result
godot --path godot/game -- --shots=DIR --at=9,14,30 [--title] [--crash=12] [--results]   # screenshots
```
