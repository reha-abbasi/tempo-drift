# scenes/

Godot "scenes" are files that place things in the game world.

- `main.tscn` is the only scene. It holds the camera, the sunlight, the sky, and three parts that run on scripts:
  **Track** (`scripts/track.gd`), **Player** (`scripts/player.gd`) and **HUD**, the on-screen display (`scripts/hud.gd`).
  The game starts here.

Open it by double-clicking it in Godot's *FileSystem* panel. You'll see the 3D view.
Most of the world (trains, buildings, coins) is created by the scripts while the game runs,
so it won't show up in the editor. That's normal.

Tip for working together: scene files don't merge as cleanly as scripts, so tell each other before
you edit `main.tscn`, and don't both change it at the same time.
