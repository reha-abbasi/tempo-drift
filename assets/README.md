# assets/

Files the game uses that aren't code: sounds now, and later 3D models, images and fonts.

## audio/

The placeholder beeps and music, made by `tools/make_audio.py`.

| File | Plays when |
|---|---|
| `music.wav` | Background music loop |
| `coin.wav` | Picking up a coin |
| `jump.wav`, `land.wav` | Jumping and landing |
| `slide.wav` | Sliding |
| `swipe.wav` | Changing lanes |
| `bump.wav` | Bumping an obstacle from the side (the "CAREFUL!" stumble) |
| `crash.wav` | Game over crash |
| `power.wav` | Picking up a magnet or x2 power-up |
| `click.wav` | Pressing a menu button |

**To use your own sound:** save it as a `.wav` with the **same file name** and replace the old file.
Godot picks it up automatically. To use a different name or an `.ogg`/`.mp3`, ask Claude
(the names are listed in `scripts/sfx.gd`).

Only use sounds you're allowed to use in a published app, for example free ones from kenney.nl
or ones you made or bought.

The `.import` files next to the sounds are made by Godot. Leave them alone.
