class_name Autopilot
extends RefCounted

## A simple bot that plays the game. Used for automated testing
## (run with `-- --autoplay`) to check that obstacle patterns are beatable.
## Not meant to be perfect - if it dies a lot on one pattern, look at that pattern.

const LOOKAHEAD := 70.0


## Returns one of "", "left", "right", "jump", "slide".
func think(player: Player, track: Track, speed: float) -> String:
	if player.is_changing_lane():
		return ""
	var feet := player.position.y
	var lane := player.lane

	# 1) How far can we run in each lane before something we can't jump/slide?
	var clear: Array[float] = []
	for l in 3:
		clear.append(_clear_distance(l, track, feet, player.lane == l))

	# 2) Deal with the next jump/slide obstacle in the current lane.
	var action := _react(lane, track, speed, player)

	# 3) Change lanes if another lane is clearly better and it is safe to step into.
	var best := lane
	for l in 3:
		if clear[l] > clear[best] + 4.0:
			best = l
	if best != lane and clear[lane] < LOOKAHEAD:
		var dir := signi(best - lane)
		if _safe_to_enter(lane + dir, track, feet, speed):
			return "left" if dir < 0 else "right"
	return action


func _clear_distance(lane: int, track: Track, feet: float, is_current: bool) -> float:
	var nearest := LOOKAHEAD
	var px := -GameConfig.PLAYER_HALF_DEPTH
	for o in track.obstacles:
		if o.lane != lane or o.kind != Obstacle.Kind.TRAIN:
			continue
		var front := o.position.z
		if o.position.z - _length(o) > px:
			continue  # already behind us
		if front > px:
			# we are alongside it: fine if we're on its roof, deadly otherwise
			if is_current and feet >= GameConfig.TRAIN_HEIGHT - 0.5:
				continue
			nearest = 0.0
			continue
		if o.has_ramp:
			continue
		if feet >= GameConfig.TRAIN_HEIGHT - 0.5 and is_current and front > -3.0:
			continue
		nearest = minf(nearest, px - front)
	return nearest


func _react(lane: int, track: Track, speed: float, player: Player) -> String:
	var px := -GameConfig.PLAYER_HALF_DEPTH
	var best_d := INF
	var best: Obstacle = null
	for o in track.obstacles:
		if o.lane != lane or o.kind == Obstacle.Kind.TRAIN:
			continue
		var d := px - (o.position.z + 0.25)
		if d > -0.6 and d < best_d:
			best_d = d
			best = o
	if best == null:
		return ""
	if best.kind == Obstacle.Kind.HURDLE and player.grounded and best_d < speed * 0.30:
		return "jump"
	if best.kind == Obstacle.Kind.BAR and best_d < speed * 0.18 and player.slide_left < 0.3:
		return "slide"
	return ""


func _safe_to_enter(lane: int, track: Track, feet: float, speed: float) -> bool:
	var window_far := -1.0 - speed * GameConfig.LANE_CHANGE_TIME * 1.5
	for o in track.obstacles:
		if o.lane != lane:
			continue
		var near := o.near_z()
		var far := o.far_z()
		if far > 1.0 or near < window_far:
			continue
		if o.kind == Obstacle.Kind.TRAIN and feet >= GameConfig.TRAIN_HEIGHT - 0.5:
			continue  # roof-to-roof is fine
		return false
	return true


func _length(o: Obstacle) -> float:
	return o.position.z - o.far_z()
