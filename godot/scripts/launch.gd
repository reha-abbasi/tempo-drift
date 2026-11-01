class_name Launch
extends RefCounted
## What the next run is: picked on the menus, read by the run scene.

## "episode", "school" (Flight School) or "endless"
static var mode := "episode"
static var map := "old"
static var index := 0


static func episode(m: String, i: int) -> void:
	mode = "episode"
	map = m
	index = i
