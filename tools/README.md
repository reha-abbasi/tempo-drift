# tools/

Scripts for the **web** version's iPhone home-screen app. (The Godot version's tools are in `godot/tools/`.)

| File | What it does |
|---|---|
| `make_phone.py` | Turns `web/game.html` into the full-screen iPhone version in `web/app/` (icon, offline support) |
| `publish_phone.sh` | Copies `web/app/` to the `gh-pages` branch, which serves https://reha-abbasi.github.io/tempo-drift/ |
| `import_phone.py` | The reverse of `make_phone.py`: takes a change made in the published page back into `web/game.html` |

```
python3 tools/make_phone.py web/game.html web/app
tools/publish_phone.sh
```
