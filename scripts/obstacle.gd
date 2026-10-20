class_name Obstacle
extends Node3D

## Something on the track. Holds the collision shapes the game checks by hand:
## - boxes: touching one ends the run (or is a "stumble" if you bump it from the side)
## - walks: surfaces you can run on (train roofs, ramps)
## All shapes are in local space; the node's position moves with the world.

enum Kind { HURDLE, BAR, TRAIN }


class Walk:
	var z_min := 0.0       # far end (more negative z)
	var z_max := 0.0       # near end (closest to the player)
	var h_near := 0.0      # height at z_max
	var h_far := 0.0       # height at z_min
	var climb_any := false # ramps can be stepped onto from any height


var kind := Kind.HURDLE
var lane := 1
var has_ramp := false
var pattern := ""          # which pattern spawned it (handy when debugging deaths)
var boxes: Array[AABB] = []
var walks: Array[Walk] = []


func add_walk(z_min: float, z_max: float, h_near: float, h_far: float, climb_any := false) -> void:
	var w := Walk.new()
	w.z_min = z_min
	w.z_max = z_max
	w.h_near = h_near
	w.h_far = h_far
	w.climb_any = climb_any
	walks.append(w)


func world_box(i: int) -> AABB:
	return AABB(boxes[i].position + position, boxes[i].size)


## Nearest z (closest to the player) of anything solid or walkable.
func near_z() -> float:
	var z := -INF
	for b in boxes:
		z = maxf(z, position.z + b.end.z)
	for w in walks:
		z = maxf(z, position.z + w.z_max)
	return z


## Furthest z of the obstacle (used for clean-up).
func far_z() -> float:
	var z := INF
	for b in boxes:
		z = minf(z, position.z + b.position.z)
	for w in walks:
		z = minf(z, position.z + w.z_min)
	return z


## Height of the surface under (x, z), or -INF if there is none.
## `feet` is the player's current height: surfaces too far above are ignored.
func surface_height(x: float, z: float, feet: float, step_up: float) -> float:
	if absf(x - position.x) > GameConfig.TRAIN_WIDTH * 0.5 + 0.05:
		return -INF
	var best := -INF
	var lz := z - position.z
	for w in walks:
		if lz < w.z_min or lz > w.z_max:
			continue
		var t := (w.z_max - lz) / maxf(w.z_max - w.z_min, 0.001)
		var h := lerpf(w.h_near, w.h_far, t)
		if h <= feet + step_up or w.climb_any:
			best = maxf(best, h)
	return best
