# Tempo Drift (Godot)

The game in Godot 4.7.2, now at **v28 New Music** (see [`../PATCH-NOTES.md`](../PATCH-NOTES.md)). It started from
the web game's last version, v26 "Note Mode" (`../web/game.html`): the same rules, menus, garage, map and missions. Open this folder's `project.godot` in Godot 4.7.2. Play (F5) starts at the studio intro,
then the menus.

## Where things are

| Folder | What is in it |
|---|---|
| `scenes/levels/` | **The levels.** `old_0` … `old_7` (Past), `sunset_0` … `sunset_7` (Present), `rain_0` … `rain_7` (Future), and `school_old`, `school_sunset`, `school_rain` (Flight School) |
| `scenes/cities/` | The 24 cities: sky, light, fog, landmark, traffic colours. `<city>/section_0..3` are its street pieces |
| `scenes/landmarks/`, `scenes/buildings/`, `scenes/props/` | Landmarks, buildings, lamps, trees, signs |
| `scenes/cars/`, `scenes/pilots/`, `scenes/traffic/` | The garage's cars and pilots, and the traffic |
| `scenes/ui/` | `menus.tscn` (every menu screen, under Root), `hud.tscn`, `panels.tscn` (pause, results) |
| `scenes/run/run.tscn` | The run: camera, effects, HUD |
| `scenes/intro/intro.tscn` | The studio intro |
| `scenes/main.tscn` | What Play starts: the intro, then the menus over the live city |

## Editing a level

Open a level from `scenes/levels/`. It holds:

- **City**: the city scene (open it to change the sky, the light or the landmark for this city).
- **Street**: the whole street, piece by piece. Move, delete or duplicate pieces. To move a single building inside
  a piece, right-click the piece → *Editable Children*.
- **Notes**: one ring per note, where the car meets it. Drag a ring sideways or up and down to change its lane or
  height (it snaps to the three lanes and three heights); drag it along the street to change when it comes. The
  swipe arrow updates by itself. In the Inspector: power-up, Flight School's wait, and the note it plays.
- **Traffic**: every vehicle and roadblock where it meets the car, with its kind and whether it is hopped over
  or flown under.

Yellow lines across the road mark each bar of the song, with its number and time (editor only).
Play the open level with **F6**.

The melody is a recording, so a ring moved in time no longer lands on its note; lane and height changes are free.
The song's tempo, speed and difficulty are in the level's `course_file` (in `data/`). Endless is a generated loop
and stays in `data/endless_*.json`.

## How it fits together

- `scripts/rules.gd`: the game rules, a line-by-line port of the web game's (flying, rings, timing grades, Flow,
  Overdrive, lives and rescue, power-ups, scoring, stars). `scripts/run.gd` plays a level with them.
- `scripts/catalog.gd`: the eras, cities, cars, pilots, prices and missions, with the web game's names and words.
- `data/`: each song's timing (`<map>_<i>.json`, `school_<map>.json`), the Endless loops, the city looks.
- `audio/`: Reha's recordings for the 24 episodes (`.ogg`, one file per layer of the band), and the rendered
  loop songs, menu theme, intro music and sound effects (`.res`).

## Tools

| Tool | What it does |
|---|---|
| `tools/bake/bake_courses.mjs` | Makes the Flight School and Endless courses by running the web game's own generator: `node tools/bake/bake_courses.mjs ../web/game.html data` |
| `tools/bake/render_audio.mjs` | Renders the music the web game plays live (loop songs, menu, intro, effects) with its own code: `node tools/bake/render_audio.mjs ../web/game.html <wav dir>`, then `tools/editor/pack_baked.gd` packs the WAVs |
| `tools/fetch_polyhaven.py` | Downloads the CC0 textures (Poly Haven) the streets and buildings use |
| `tests/` | Checks: `rules_sim` (every course flown perfectly), `level_check` (levels match their courses), `load_all` (every scene opens), and picture tests (`run_shot`, `city_shot`, `menu_shot`, …) |

Run a check with `godot --headless --path godot res://tests/<name>.tscn` from the repo folder.

## Rebuilding from the tools

The scenes were first laid out by the builders in `tools/editor/` (run through `tools/editor/runner.tscn`).
**Running a builder again overwrites the scenes it makes**, including edits made in the editor; after the first
build the scenes are the source.
