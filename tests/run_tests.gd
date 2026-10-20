extends SceneTree

## Gameplay tests. Run from the project folder:
##   godot --headless --path . --script res://tests/run_tests.gd
## Each test builds a tiny hand-made track and simulates frames.

const DT := 1.0 / 60.0

var game: Node
var failures := 0
var passed := 0


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.save_scores = false
	root.add_child(game)
	_run_all.call_deferred()


func _run_all() -> void:
	_test("standing still into a hurdle crashes", func():
		_fresh()
		_add(WorldKit.hurdle(1), 1, -10.0)
		_run(60)
		return _dead())

	_test("jumping clears a hurdle", func():
		_fresh()
		_add(WorldKit.hurdle(1), 1, -10.0)
		_run(24)
		game.call("_action", "jump")
		_run(90)
		return not _dead())

	_test("sliding goes under a bar", func():
		_fresh()
		_add(WorldKit.bar(1), 1, -10.0)
		_run(30)
		game.call("_action", "slide")
		_run(60)
		return not _dead())

	_test("jumping into a bar crashes", func():
		_fresh()
		_add(WorldKit.bar(1), 1, -10.0)
		_run(30)
		game.call("_action", "jump")
		_run(60)
		return _dead())

	_test("train head-on crashes", func():
		_fresh()
		_add(WorldKit.train(1, 20.0, false, game.track.rng), 1, -10.0)
		_run(60)
		return _dead())

	_test("ramp carries you onto the roof and back down", func():
		_fresh()
		_add(WorldKit.train(1, 20.0, true, game.track.rng), 1, -15.0)
		var top := 0.0
		for i in 200:
			_run(1)
			top = maxf(top, game.player.position.y)
		return not _dead() and top >= GameConfig.TRAIN_HEIGHT - 0.01 and game.player.position.y < 0.01)

	_test("bumping a train from the side stumbles back", func():
		_fresh()
		_add(WorldKit.train(0, 30.0, false, game.track.rng), 0, 8.0)
		game.call("_action", "left")
		_run(40)
		return not _dead() and game.player.lane == 1 and game.get("stumble_left") > 0.0)

	_test("second side bump soon after ends the run", func():
		_fresh()
		_add(WorldKit.train(0, 60.0, false, game.track.rng), 0, 8.0)
		game.call("_action", "left")
		_run(40)
		game.call("_action", "left")
		_run(40)
		return _dead())

	_test("changing lanes in the open is safe", func():
		_fresh()
		game.call("_action", "left")
		_run(20)
		game.call("_action", "right")
		_run(20)
		game.call("_action", "right")
		_run(20)
		return not _dead() and game.player.lane == 2 and is_equal_approx(game.player.position.x, GameConfig.LANE_WIDTH))

	_test("coins are collected", func():
		_fresh()
		game.track.call("_add_coin", Vector3(0, 0.9, -5.0))
		game.track.call("_add_coin", Vector3(GameConfig.LANE_WIDTH, 0.9, -5.0))  # other lane: missed
		_run(40)
		return game.get("run_coins") == 1)

	_test("magnet pulls in coins from other lanes", func():
		_fresh()
		game.set("magnet_left", 5.0)
		game.track.call("_add_coin", Vector3(GameConfig.LANE_WIDTH, 0.9, -10.0))
		_run(60)
		return game.get("run_coins") == 1)

	_test("jump pressed just before landing still jumps", func():
		_fresh()
		game.call("_action", "jump")
		_run(38)  # almost back on the ground
		game.call("_action", "jump")
		_run(8)
		return game.player.position.y > 0.5)

	print("\n%d passed, %d failed" % [passed, failures])
	quit(1 if failures > 0 else 0)


func _test(title: String, body: Callable) -> void:
	var ok: bool = body.call()
	if ok:
		passed += 1
		print("  PASS  ", title)
	else:
		failures += 1
		print("  FAIL  ", title, "   (state=", game.get("state"), " y=", game.player.position.y,
			" lane=", game.player.lane, " cause=", game.get("_death_cause"), ")")


func _fresh() -> void:
	game.track.spawning = false
	game.call("_go_menu")
	game.call("_start_run")
	# remove scenery-free leftovers so each test starts on an empty track
	for o: Node in game.track.obstacles:
		o.free()
	game.track.obstacles.clear()


func _add(o: Obstacle, lane: int, z: float) -> void:
	game.track.add_obstacle(o, lane, z)


func _run(frames: int) -> void:
	for i in frames:
		game.call("_physics_process", DT)


func _dead() -> bool:
	return game.get("state") == 3  # State.DEAD
