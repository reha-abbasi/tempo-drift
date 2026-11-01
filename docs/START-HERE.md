# Start here (no coding experience needed)

This page explains the project in plain words: what the folders are, what the jargon means,
and how to do the common jobs. Every folder also has its own `README.md` saying what's inside it.

## The easiest way to do anything: ask Claude

Open this folder in Claude Code and ask in normal words, for example:

- *"Update the web preview."* Claude pulls the latest code, rebuilds the game for the browser and
  republishes it to the shared link.
- *"Make the game start slower."* / *"Add a new obstacle pattern with two trains."*
- *"Pull Murat's latest changes."* / *"Open a pull request with my changes."*

The rest of this page is for when you want to understand or do things yourself.

## Do I need to install Godot?

Not to play or test: just open the web preview link in a browser.
To change the code and try your change, see the options table in the main [`README.md`](../README.md#do-i-need-to-download-godot).
Some options don't need any download.

## Words you'll see

| Word | What it means |
|---|---|
| **Godot** | The free program we build the game in (version **4.7.2**). Like Photoshop, but for games. |
| **Repo / repository** | The project folder, stored on GitHub so both of us have the same copy. |
| **GitHub** | The website that keeps the repo and its history: https://github.com/reha-abbasi/tempo-drift (code on `main`, the built game on `gh-pages`) |
| **Commit** | A saved checkpoint of your changes, with a short note about what you changed. |
| **Push** | Upload your commits from your computer to GitHub. |
| **Pull** | Download the other person's commits from GitHub to your computer. Do this before you start working. |
| **Branch** | A separate copy of the code to try a change without touching the main version. |
| **`main`** | The main, agreed version of the game. |
| **Pull request (PR)** | A request on GitHub to merge your branch into `main`, so the other person can look first. |
| **Merge** | Accept a pull request. Its changes become part of `main`. |
| **Export** | Turn the Godot project into a playable app: for iPhone, Android, or a web browser. |
| **Web preview / artifact** | A private web page on claude.ai where the game runs in the browser, so you can test it on a phone without installing anything: https://claude.ai/artifact/HmgViG5EE7wUr46QJXHNBE |
| **Terminal** | The text window where you type commands (Mac: *Terminal* app; Windows: *Git Bash*; VS Code: *Terminal > New Terminal*). |
| **Script (`.gd`)** | A text file of game code in Godot's language, GDScript. |
| **Scene (`.tscn`)** | A Godot file that places things in the game world (camera, lights, the player…). |

## What each folder is for

| Folder | In one line |
|---|---|
| `scripts/` | All the game code: rules, movement, obstacles, menus. Two files are safe to tweak: see its README. |
| `scenes/` | The game world layout Godot opens. |
| `shaders/` | Small effects that colour the ground and the building windows. |
| `assets/` | Sounds and music (later: 3D models, images). |
| `tests/` | Automatic checks that the game still works after a change. |
| `web/` | **The current game, Tempo Drift** (a web page), and its iPhone version. See its README. |
| `tools/` | Helper scripts: make sounds, take screenshots, **build the web preview**, **build the iPhone version**. |
| `docs/` | This guide and the screenshots shown on GitHub. |
| `export/`, `build/` | Made by the computer when you export. Never saved to GitHub, safe to delete. |
| `.godot/` | Godot's own cache. Never saved to GitHub, safe to delete. |

Files at the top level: `project.godot` (the file you open in Godot), `export_presets.cfg` (iPhone/web export settings),
`icon.svg` (placeholder app icon), `README.md` (the main project page on GitHub), `.gitignore` (tells git which files to skip).

## Common jobs, step by step

**Play Tempo Drift on an iPhone:** open https://reha-abbasi.github.io/tempo-drift/ in Safari, tap Share, then
**Add to Home Screen**. Details and how to update it: [`web/README.md`](../web/README.md).

**Play the game:** open Godot, *Import*, pick `project.godot`, press **F5**.

**Get the latest code (before you start):** in a terminal in the project folder, type `git pull`.
In VS Code you can instead click the circle-arrows icon in the bottom-left corner.

**Share your changes:**
1. `git switch -c my-change-name` (makes a branch)
2. `git add -A` then `git commit -m "what I changed"`
3. `git push -u origin my-change-name`
4. GitHub shows a yellow **Compare & pull request** button. Click it, then **Create pull request**.
5. The other person opens it, clicks **Merge pull request**, then **Confirm merge**.

In VS Code: the *Source Control* tab (third icon on the left) does steps 2 and 3 with buttons.

**Update the web preview:** see [`tools/README.md`](../tools/README.md). Short version: after a merge into `main`,
ask Claude *"update the web preview"*.

**Change game speed, jump height, etc.:** open `scripts/config.gd` and change the numbers. See [`scripts/README.md`](../scripts/README.md).

## If something goes wrong

- **Godot shows red errors:** copy the message and give it to Claude.
- **`git pull` says "conflict":** you and your partner changed the same lines. Don't panic, ask Claude to sort it out.
- **The web preview is stuck on the loading bar:** refresh the page. If it still doesn't load, ask Claude to rebuild it.
- **You want to undo everything since your last commit:** ask Claude first. Undo commands delete work for good.
