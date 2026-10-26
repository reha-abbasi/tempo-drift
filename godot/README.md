# Tempo Drift — Godot version

The game remade in Godot 4.7. The whole Past: **London 1890, Istanbul 1910, Paris 1925, New York 1935, Havana 1955, Vienna 1905, Cairo 1925 and Rome 1948**, picked on the title card. Each city has its own street, light, landmark and band.

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

**Duet:** four EXCELLENTs in a row and a second instrument harmonises your melody (400 a note) until a GOOD, OK or miss.

**Settings** (title card): picture quality (Auto, Low, Medium, High; phones start on Medium and the game steps down if it runs slow) and the audio offset for wireless headphones, with a tap-along test that measures it.

## What's where

| Folder | What |
|---|---|
| `game/scripts/game.gd` | the rules (lanes, grades, Flow, Overdrive, car → jetpack, rescue), carried over from the web game |
| `game/scripts/music.gd` | the soundtrack: 9 layers played in sync; the band follows your Flow, each note plays only when you're in its ring |
| `game/scripts/world.gd` | the streets, one "look" per city: houses, roofs, lamps, trees, landmarks, light and weather (batched, so it's fast) |
| `game/scripts/quality.gd` | the quality levels |
| `game/scripts/models.gd` | the car, the pilot, motor cars, the bus, airships, barriers, the finish arch |
| `game/scripts/rings.gd`, `traffic.gd`, `fx.gd`, `hud.gd` | rings, vehicles, effects, HUD and cards |
| `game/shaders/` | bricks and windows, wet cobbles, slate, sky, glows, rain, smoke |
| `game/data/old_N.json` | each course: every ring and vehicle, baked from the web game |
| `game/audio/old_N/` | each soundtrack, 11 layers played in sync |
| `tools/bake.mjs` | bakes a course from `web/game.html`: `node godot/tools/bake.mjs old 0` |
| `tools/arrange.py` | arranges a song for its city's band and renders it with real instruments: `python3 godot/tools/arrange.py old 0` (needs `fluidsynth` and the MuseScore General soundfont) |

## Tests (command line)

```
godot --headless --path godot/game -- --sim --ep=0               # plays an episode with a perfect pilot, prints the result
godot --path godot/game -- --shots=DIR --at=9,14,30 [--title] [--crash=12] [--results]   # screenshots
```
