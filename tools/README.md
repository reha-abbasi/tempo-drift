# tools/

Helper scripts. They're not part of the game itself and aren't included when you export it.
You run them from a **terminal** opened in the project folder (the folder with `project.godot`).
New to terminals? See [`docs/START-HERE.md`](../docs/START-HERE.md).

| File | What it does | When you need it |
|---|---|---|
| `web_preview.sh` | Builds the browser version of the game and gets it ready to publish to the web preview link | After new code is merged into `main` |
| `web_artifact.py` | The packaging step that `web_preview.sh` runs for you | Never directly |
| `screenshots.sh` | Takes screenshots of the menu, gameplay and game-over screen automatically | Updating `docs/screenshots.png` (Linux only) |
| `make_audio.py` | Recreates the placeholder beeps and music in `assets/audio/` | Only if you want the original placeholder sounds back |

## Updating the web preview, step by step

The web preview is a private page on claude.ai where the game runs in a browser:
https://claude.ai/artifact/HmgViG5EE7wUr46QJXHNBE. You can open it on a phone to test without installing anything.
To change it you need **edit** access to that page (Reha can give it from the page's Share menu).

**Easiest:** open the project in Claude Code and say *"update the web preview"*. Claude does all the steps below.

**By hand:**

1. **Get the latest `main`:** `git switch main` then `git pull`.
2. **One-time setup:** in Godot, *Editor > Manage Export Templates > Download and Install*.
   This downloads the extra files Godot needs to make a browser version.
3. **Build:**
   ```bash
   tools/web_preview.sh build/web_artifact "/path/to/Godot"
   ```
   Replace `/path/to/Godot` with where Godot is on your computer, for example
   `/Applications/Godot.app/Contents/MacOS/Godot` on a Mac or `"C:/Godot/Godot_v4.7.2-stable_win64.exe"` on Windows.
   On Windows, run it in **Git Bash** (installed with Git), not the normal Command Prompt.
   When it finishes it lists about 10 files in `build/web_artifact/`.
4. **Publish:** ask Claude:
   > Publish `build/web_artifact/index.html` with all the other files in that folder as supporting files,
   > to the existing artifact https://claude.ai/artifact/HmgViG5EE7wUr46QJXHNBE

   The link stays the same, so everyone who has it sees the new version.

### Why there's a packaging step at all

Godot's browser version doesn't fit on a claude.ai page as it comes out:
- the game engine file is about 40 MB, but a page only accepts files up to 15 MB, and
- the game data file ends in `.pck`, a file type the page doesn't accept.

So `web_artifact.py` cuts the engine file into three pieces (`index.part0.wasm`, `part1`, `part2`), renames the data file to
`index.pck.wasm`, and adds a few lines to the web page that join the pieces back together in the browser.
None of this changes the game itself.

`build/` and `export/` are made fresh every time and are never saved to GitHub, so it's safe to delete them.

## The iPhone version of Tempo Drift

- `make_phone.py` turns `web/game.html` into the full-screen iPhone version in `web/app/` (icon, offline support).
- `publish_phone.sh` copies `web/app/` to the public project that serves https://reha-abbasi.github.io/tempo-drift/.

```
python3 tools/make_phone.py web/game.html web/app
tools/publish_phone.sh
```
