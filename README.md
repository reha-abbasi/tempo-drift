# Tempo Drift

A flying-car rhythm runner for iPhone by [@reha-abbasi](https://github.com/reha-abbasi) and
[@muratbyk](https://github.com/muratbyk). Fly through 24 cities across three eras, swiping into a ring on every note
of the song.

> **This is the `music-test-berlin` branch**, a test of the new music. Only Berlin 2075 can be played; every other city
> is locked and its old music is taken out. Berlin plays the new melodic-techno soundtrack, and so do the menus. The
> tools that make the music are in [`godot/tools/music/`](godot/tools/music). Everything else is as on
> `murat-godot-remake`.

The branch it's built on (`murat-godot-remake`) holds two versions of the same game:

| Version | Folder | Open or play it |
|---|---|---|
| **Godot** (the one to build on) | [`godot/`](godot) | Open `godot/project.godot` in [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/). Guide: [`godot/README.md`](godot/README.md) |
| **Web** (the original, one HTML file) | [`web/`](web) | https://reha-abbasi.github.io/tempo-drift/ · edit `web/game.html` |

The Godot version follows the web version **v26 "Note Mode"**: the same rules, menus, garage, map, missions and
music. Its courses and the music that is not a recording were made by running the web game's own code
(`godot/tools/bake/`).

## Open the Godot version

1. Install **Godot 4.7.2** (standard, not .NET).
2. In Godot's Project Manager: **Import** → pick `godot/project.godot` → **Import & Edit**. The first import takes a
   few minutes.
3. Press **F5** to play from the start (intro, then menus), or open a level from `godot/scenes/levels/` and press
   **F6** to fly just that level.

## The other folders

- `web/`: the web game and its iPhone home-screen version (`web/app/`), see [`web/README.md`](web/README.md).
- `tools/`: the scripts that make and publish that iPhone version, see [`tools/README.md`](tools/README.md).

The `gh-pages` branch is the published web game; the publish script updates it.
