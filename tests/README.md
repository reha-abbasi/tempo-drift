# tests/

Automatic checks that the game still works after a change, so you don't have to replay everything by hand.

`run_tests.gd` builds tiny test tracks and pretends to play them. For example, it checks that jumping clears a hurdle,
sliding goes under a sign, ramps take you onto a train roof, two side bumps end the run, and coins get collected.

**Run them** in a terminal in the project folder (replace `godot` with the path to your Godot program if needed):

```bash
godot --headless --path . --script res://tests/run_tests.gd
```

It prints a line per test and a summary at the end, like `12 passed, 0 failed`. Anything marked **FAIL** means a change broke something.
Godot then prints a couple of `WARNING`/`ERROR ... still in use at exit` lines while it shuts down. Those are harmless; only the summary matters.
Copy the output and give it to Claude if you're not sure why.

The main `README.md` (section *Testing*) also shows how to let the robot player (`scripts/autopilot.gd`)
play whole runs, to check that every obstacle layout can be beaten.

Tests are never included in the exported game.
