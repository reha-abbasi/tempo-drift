# web/ — Tempo Drift, the browser version

This is the game as it is now: a flying-car rhythm runner made with Three.js (a 3D library for web pages).
The Godot version of the same game, built on this one, is in [`godot/`](../godot).

| File | What it is |
|---|---|
| `game.html` | **The game.** One file with everything in it. The same page as the claude.ai preview (game screen + notes). Edit this one. |
| `app/` | **The iPhone version**, made from `game.html`: only the game, full screen, with an app icon, and it keeps working offline. Don't edit by hand; rebuild it. |

## Play it on an iPhone

1. Open **https://reha-abbasi.github.io/tempo-drift/** in **Safari** (not Chrome).
2. Tap the **Share** button (square with an arrow), scroll down, tap **Add to Home Screen**, then **Add**.
3. Open **Tempo Drift** from the home screen. It runs full screen like an app.

Turn the ringer switch on if there's no sound. The first launch needs internet; after that it also works offline.

## Update the iPhone version after changing the game

```
python3 tools/make_phone.py web/game.html web/app
tools/publish_phone.sh
```

The first line rebuilds `app/`. The second copies it to the `gh-pages` branch of this repo, which GitHub serves at
the link above (about a minute later).
Or ask Claude: *"Update the iPhone version."*

## If someone edits the iPhone page directly

If a change is made straight in `index.html` on the `gh-pages` branch, bring it back here first,
so the next update doesn't overwrite it:

```
python3 tools/import_phone.py path/to/gh-pages-copy/index.html web/game.html
```
