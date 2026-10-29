# Tempo Drift — Godot version

The game remade in Godot 4.7: three eras of eight cities, each with its own street, light, landmark and band, picked on the world map.

- **The Past:** London, Istanbul, Paris, New York, Havana, Vienna, Cairo, Rome (1890–1955)
- **The Present:** Dubai, Rio, Singapore, San Francisco, Sydney, Cape Town, Barcelona, Reykjavik
- **The Future:** Hong Kong, Tokyo, Los Angeles, Shanghai, Seoul, Berlin, Miami, Las Vegas (2049–2099)

An era opens with 10 stars in the one before (or all at once with the testing switch in Settings). The **garage** has five cars with perks and six pilots, bought with the coins you earn: one per note played, 100 per new star.

## Play it on a phone

https://reha-abbasi.github.io/tempo-drift/godot/ (the web build, runs in Safari; about 120 MB to load, and the Present and the Future download about 75 MB each the first time you fly there). Publish a new one with `tools/publish_godot_web.sh`.

## Open it

1. Start Godot 4.7.2 (Reha's is in `D:\Claude-sandbox\Software`).
2. **Import** → pick `godot/game/project.godot` inside your copy of this repo → **Import & Edit**.
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
