extends Node
## Measures the controls with simulated fingers at 60 frames a second: the run's earlier input (run.gd's own) against
## the swipes on a phone (scripts/swipes.gd), each tweak on its own and all three together, and fails if the new
## swipes ever make a move a finger didn't mean or play worse than the earlier controls.
## godot --headless --path godot res://tests/swipe_check.tscn

const FPS := 60.0
const LEVEL := "res://scenes/levels/sunset_1.tscn"
const HOME_AT := Vector2(195, 640)
## the input to compare: null = run.gd as it is, an Array = the new swipes with those tweaks on
const KINDS := {"as now": null, "new, none on": [], "sure_swipe": ["sure_swipe"], "drag_on": ["drag_on"],
	"swipe_memory": ["swipe_memory"], "all three": ["sure_swipe", "drag_on", "swipe_memory"]}
var failures := 0
var flat := {"bar": 2.0, "beat": 0.5, "speed": 18.0, "hang": 0.5, "gate": 999.0, "notes": [], "hazards": []}


class Pad:
	## a run's input (run.gd's own, or the new swipes) driving the rules on a 60 fps clock; events go in at a frame's start
	var run: Node3D
	var rules: Rules
	var feel: Swipes
	var frame := 0
	var fps := FPS
	var moves: Array = []      # [frame, dc, dr]
	var bumps := 0
	var _events := {}

	func _init(course: Dictionary, tweaks, tut := false) -> void:
		run = load("res://scripts/run.gd").new()
		run.started = true
		rules = run.rules
		rules.load_course(course, tut)
		if tweaks is Array:
			feel = Swipes.new(rules)
			feel.sure_swipe = "sure_swipe" in tweaks
			feel.drag_on = "drag_on" in tweaks
			feel.swipe_memory = "swipe_memory" in tweaks
			run._feel = feel
		rules.moved.connect(_on_moved)
		rules.edge_bump.connect(_on_bump)

	func _on_moved(dc: int, dr: int) -> void:
		moves.append([frame, dc, dr])

	func _on_bump(_d: int) -> void:
		bumps += 1

	func at(f: int, e: InputEvent) -> void:
		if not _events.has(f):
			_events[f] = []
		_events[f].append(e)

	func tick() -> void:
		frame += 1
		for e in _events.get(frame, []):
			run._unhandled_input(e)
		_events.erase(frame)
		rules.step(frame / fps)
		if feel:
			feel.tick()

	func run_to(f: int) -> void:
		while frame < f:
			tick()

	func done() -> void:
		run.free()

	static func touch(i: int, p: Vector2, down: bool) -> InputEventScreenTouch:
		var e := InputEventScreenTouch.new()
		e.index = i
		e.position = p
		e.pressed = down
		return e

	static func drag(i: int, p: Vector2) -> InputEventScreenDrag:
		var e := InputEventScreenDrag.new()
		e.index = i
		e.position = p
		return e

	static func key(k: Key) -> InputEventKey:
		var e := InputEventKey.new()
		e.keycode = k
		e.pressed = true
		return e


	func stroke(i: int, f0: int, from: Vector2, to: Vector2, frames: int, press := true, lift := true, arc := 0.0, hook := Vector2.ZERO) -> Vector2:
		## finger i strokes from `from` to `to` over `frames` frames (smooth start and stop); arc bows it sideways,
		## hook pulls the last two frames off course; returns where it ends
		if press:
			at(f0, touch(i, from, true))
		var side := (to - from).orthogonal().normalized()
		var p := from
		for k in range(1, frames + 1):
			var s := float(k) / frames
			p = from + (to - from) * (s * s * s * (10.0 - 15.0 * s + 6.0 * s * s)) + side * arc * sin(PI * s)
			if k > frames - 2:
				p += hook * float(k - frames + 2) / 2.0
			at(f0 + k, drag(i, p))
		if lift:
			at(f0 + frames, touch(i, p, false))
		return p


func _ready() -> void:
	_response()
	_cases()
	_flicks()
	_memory()
	_bots()
	_replay()
	print("FAILURES: %d" % failures)
	get_tree().quit(1 if failures else 0)


func _fail(why: String) -> void:
	failures += 1
	print("  FAIL: " + why)


# ------------------------------------------------------------------ how fast a swipe moves the car

func _response() -> void:
	print("\n== Response: finger starts at frame 0 and flicks right from the middle lane (60 fps)")
	print("   flick           | swipe counts | car counts in the lane | car looks there (95%)")
	for f in [[40, 80], [80, 120], [150, 200], [60, 250]]:
		var row := []
		for kind in ["as now", "all three"]:
			var pad := Pad.new(flat, KINDS[kind])
			pad.stroke(0, 1, HOME_AT, HOME_AT + Vector2(f[0], 0), roundi(f[1] / 1000.0 * FPS))
			var fire := -1
			var count := -1
			var there := -1
			while pad.frame < 80:
				pad.tick()
				if fire < 0 and not pad.moves.is_empty():
					fire = pad.frame - 1
				if fire >= 0 and count < 0 and absf(pad.rules.x - Rules.LX[2]) < pad.rules.reach_car:
					count = pad.frame - 1
				if fire >= 0 and there < 0 and absf(pad.rules.x - Rules.LX[2]) < 0.08:
					there = pad.frame - 1
			pad.done()
			row.append([fire, count, there])
		if row[0] != row[1]:
			_fail("a plain flick responds differently with the new swipes")
		var r: Array = row[0]
		print("   %3d px in %3d ms | %2d fr %3d ms | +%2d fr (+%3d ms)       | +%2d fr (+%3d ms)   same with the new swipes: %s" % [f[0], f[1], r[0], r[0] * 1000 / 60, r[1] - r[0], (r[1] - r[0]) * 1000 / 60, r[2] - r[0], (r[2] - r[0]) * 1000 / 60, "yes" if row[0] == row[1] else "NO"])


# ------------------------------------------------------------------ hand-made finger cases

func _case(kind: String, start_col: int, build: Callable, to := 60) -> Dictionary:
	var pad := Pad.new(flat, KINDS[kind])
	pad.rules.col = start_col
	pad.rules.x = Rules.LX[start_col]
	build.call(pad)
	pad.run_to(to)
	var r := {"moves": pad.moves.map(func(m): return "%s%s" % ["L" if m[1] < 0 else "R" if m[1] > 0 else "", "U" if m[2] > 0 else "D" if m[2] < 0 else ""]), "col": pad.rules.col, "bumps": pad.bumps}
	pad.done()
	return r


func _cases() -> void:
	print("\n== Finger cases (moves made, the lane the car ends in, edge bumps)")
	var cases := [
		["two thumbs: the left one swipes left and rests, the right one then swipes right", 1, "LR", 1, _two_thumbs],
		["two thumbs: the left one lifts while the right one swipes up", 1, "LU", 0, _thumb_lifts],
		["a quick flick whose drags stop at 18 px, lifted at 34 px", 1, "R", 2, _short_drags],
		["a tap that slides 6 px", 1, "", 1, _tap],
		["one finger: right 60 px, holds, then back left 60 px", 0, "RL", 0, _back],
		["one finger: right, left, right without lifting (60 px each)", 0, "RLR", 1, _zigzag],
		["one long drag right, 200 px, from the left lane", 0, "RR", 2, _long_left],
		["one long drag right, 260 px, from the middle lane", 1, "R", 2, _long_mid],
		["a flick right into the right edge", 2, "", 2, _edge],
		["swipe up, then left 0.2 s later (mid-hop)", 1, "UL", 0, _mid_hop],
	]
	for c in cases:
		print("   %s (meant: %s)" % [c[0], c[2] if c[2] != "" else "no move"])
		var now := _case("as now", c[1], c[4])
		var off := _case("new, none on", c[1], c[4])
		for kind in ["as now", "sure_swipe", "drag_on", "all three"]:
			var r := _case(kind, c[1], c[4])
			print("      %-12s %-4s lane %d  bumps %d" % [kind, "".join(r.moves) if not r.moves.is_empty() else "-", r.col, r.bumps])
		if off.hash() != now.hash():
			_fail("the new swipes with no tweak on differs from the controls as they are: %s" % c[0])
		var all := _case("all three", c[1], c[4])
		if "".join(all.moves) != c[2] or all.col != c[3]:
			_fail("with the new swipes: %s" % c[0])
		if all.bumps > now.bumps:
			_fail("the new swipes bump the edge more: %s" % c[0])


func _jitter(pad: Pad, i: int, p: Vector2, f0: int, f1: int) -> void:
	## a resting thumb on real glass: a pixel this way or that now and then
	for f in range(f0, f1, 4):
		pad.at(f, Pad.drag(i, p + Vector2(1 if f % 8 == 0 else 0, 1 if f % 12 == 0 else 0)))


func _two_thumbs(pad: Pad) -> void:
	var p := pad.stroke(0, 1, Vector2(110, 650), Vector2(40, 650), 6, true, false)
	pad.stroke(1, 20, Vector2(300, 650), Vector2(370, 650), 6, true, false)
	_jitter(pad, 0, p, 21, 40)


func _thumb_lifts(pad: Pad) -> void:
	var p := pad.stroke(0, 1, Vector2(110, 650), Vector2(40, 650), 6, true, false)
	pad.stroke(1, 20, Vector2(300, 650), Vector2(300, 570), 6, true, false)
	pad.at(21, Pad.touch(0, p, false))


func _short_drags(pad: Pad) -> void:
	pad.at(1, Pad.touch(0, HOME_AT, true))
	pad.at(2, Pad.drag(0, HOME_AT + Vector2(9, 0)))
	pad.at(3, Pad.drag(0, HOME_AT + Vector2(18, 0)))
	pad.at(4, Pad.touch(0, HOME_AT + Vector2(34, 0), false))


func _tap(pad: Pad) -> void:
	pad.stroke(0, 1, HOME_AT, HOME_AT + Vector2(6, 3), 4)


func _back(pad: Pad) -> void:
	var p := pad.stroke(0, 1, HOME_AT, HOME_AT + Vector2(60, 0), 6, true, false)
	pad.stroke(0, 20, p, p - Vector2(60, 0), 6, false, true)


func _zigzag(pad: Pad) -> void:
	var p := pad.stroke(0, 1, HOME_AT, HOME_AT + Vector2(60, 0), 6, true, false)
	p = pad.stroke(0, 14, p, p - Vector2(60, 0), 6, false, false)
	pad.stroke(0, 27, p, p + Vector2(60, 0), 6, false, true)


func _long_left(pad: Pad) -> void:
	pad.stroke(0, 1, Vector2(90, 640), Vector2(290, 640), 15)


func _long_mid(pad: Pad) -> void:
	pad.stroke(0, 1, Vector2(60, 640), Vector2(320, 640), 18)


func _edge(pad: Pad) -> void:
	pad.stroke(0, 1, HOME_AT, HOME_AT + Vector2(80, 0), 6)


func _mid_hop(pad: Pad) -> void:
	pad.stroke(0, 1, HOME_AT, HOME_AT + Vector2(0, -70), 6)
	pad.stroke(0, 13, HOME_AT, HOME_AT + Vector2(-70, 0), 6)


# ------------------------------------------------------------------ ordinary flicks: never an extra move

func _flicks() -> void:
	print("\n== 600 ordinary flicks (30-150 px, 60-220 ms, up to 25 deg off, bowed, hooked at the end)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var same := 0
	var extra := 0
	var n := 600
	for k in n:
		var vertical := k % 3 == 0
		var length := rng.randf_range(30.0, 150.0)
		var ang := deg_to_rad(rng.randf_range(-25.0, 25.0))
		var dir := Vector2(0, -1 if k % 2 else 1) if vertical else Vector2(1 if k % 2 else -1, 0)
		var v := dir.rotated(ang) * length
		var frames := maxi(2, roundi(rng.randf_range(0.06, 0.22) * FPS))
		var arc := rng.randf_range(-0.15, 0.15) * length
		var hook := Vector2(rng.randf_range(-12, 12), rng.randf_range(-12, 12))
		var res := []
		for kind in ["as now", "all three"]:
			var pad := Pad.new(flat, KINDS[kind])
			pad.stroke(0, 1, HOME_AT, HOME_AT + v, frames, true, true, arc, hook)
			pad.run_to(frames + 6)
			res.append(pad.moves.map(func(m): return [m[1], m[2]]))
			pad.done()
		if res[0] == res[1]:
			same += 1
		if res[1].size() > res[0].size():
			extra += 1
	print("   same moves as now: %d/%d   an extra move with the new swipes: %d" % [same, n, extra])
	if same != n:
		_fail("ordinary flicks move differently with the new swipes")
	# the longest flick that still moves one lane with drag_on
	var longest := 0
	for length in range(150, 260, 5):
		var pad := Pad.new(flat, KINDS["all three"])
		pad.rules.col = 0
		pad.stroke(0, 1, Vector2(60, 640), Vector2(60 + length, 640), 7)
		pad.run_to(14)
		if pad.moves.size() == 1:
			longest = length
		pad.done()
	print("   with drag_on a flick or drag up to %d px moves one lane; a longer one moves two (the screen is 390 wide)" % longest)


# ------------------------------------------------------------------ a swipe at the end of a crash

func _memory() -> void:
	print("\n== A swipe (right) just before the car can move again after a crash (it can 1.15 s after the crash)")
	var first_ok := -1
	for f in range(60, 140):
		var pad := Pad.new(flat, KINDS["as now"])
		pad.run_to(10)
		pad.rules._crash({"t": pad.rules.t, "col": 1, "row": 1, "kind": "taxi", "over": false, "under": false, "state": 0})
		pad.at(10 + f, Pad.key(KEY_RIGHT))
		pad.run_to(10 + f + 2)
		var ok := not pad.moves.is_empty()
		pad.done()
		if ok:
			first_ok = f
			break
	print("   a swipe is made from %d frames (%d ms) after the crash" % [first_ok, first_ok * 1000 / 60])
	print("   swipe made     | as now          | swipe_memory")
	for early in [1, 2, 4, 6, 7, 8, 10, 15]:
		var row := []
		for kind in ["as now", "swipe_memory"]:
			var pad := Pad.new(flat, KINDS[kind])
			pad.run_to(10)
			pad.rules._crash({"t": pad.rules.t, "col": 1, "row": 1, "kind": "taxi", "over": false, "under": false, "state": 0})
			pad.at(10 + first_ok - early, Pad.key(KEY_RIGHT))
			pad.run_to(10 + first_ok + 30)
			row.append("lost" if pad.moves.is_empty() else "made %+d ms" % ((pad.moves[0][0] - (10 + first_ok)) * 1000 / 60))
			pad.done()
		print("   %3d ms early   | %-15s | %s" % [early * 1000 / 60, row[0], row[1]])
		if early <= 7 and not row[1].begins_with("made"):
			_fail("swipe_memory missed a swipe %d frames early" % early)
		if early >= 8 and row[1] != "lost":
			_fail("swipe_memory kept a swipe %d frames early" % early)


# ------------------------------------------------------------------ simulated players on Rio de Janeiro

func _bots() -> void:
	var lv := (load(LEVEL) as PackedScene).instantiate() as Level
	var course := lv.course()
	lv.free()
	print("\n== Simulated players flying Rio de Janeiro by swipes (one swipe per lane or height; crashes don't end the run)")
	print("   lift: one thumb, lifted after every swipe | thumbs: left swipes with the left thumb, right swipes with the right,")
	print("   each resting on the glass between swipes | steer: one finger that stays down and drags back to turn back")
	print("   (swipes: strokes made; did nothing; moved the wrong way; moves more than one)")
	print("   still thumbs: the same two thumbs held dead still while resting (no pixel moves at all)")
	for style in ["lift", "thumbs", "still thumbs", "steer"]:
		print("   %s" % style)
		var base := {}
		for kind in ["as now", "sure_swipe", "drag_on", "swipe_memory", "all three"]:
			var r := _play(course, KINDS[kind], style)
			print("      %-12s notes %3d/%3d  crashes %d  swipes %3d  did nothing %2d  wrong way %2d  extra %2d" % [kind, r.c, r.n, r.lost, r.swipes, r.dud, r.wrong, r.extra])
			if kind == "as now":
				base = r
			elif kind == "all three" and (r.c < base.c or r.lost > base.lost or r.wrong > base.wrong or r.extra > base.extra or r.dud > base.dud):
				_fail("the %s player does worse with the new swipes" % style)


func _play(course: Dictionary, tweaks, style: String) -> Dictionary:
	var pad := Pad.new(course, tweaks, true)
	var r := pad.rules
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var busy := 0
	var active := -1           # the finger in a stroke until `busy`
	var meant := Vector2i.ZERO # the move the stroke is for
	var m0 := 0                # moves made before it
	var tally := {"swipes": 0, "dud": 0, "wrong": 0, "extra": 0}
	var used := 1              # the thumb that swiped last
	# fingers: down, where it is, the way it last swiped left/right (0 after up or down)
	var fing := [{"down": false, "p": Vector2.ZERO, "dir": 0}, {"down": false, "p": Vector2.ZERO, "dir": 0}]
	var homes := [Vector2(110, 650), Vector2(290, 650)]
	while not r.over and pad.frame < 60 * 400:
		# a resting finger moves a pixel now and then
		for i in 2:
			if style != "still thumbs" and fing[i].down and (pad.frame >= busy or i != active) and rng.randf() < 0.2:
				pad.at(pad.frame + 1, Pad.drag(i, fing[i].p + Vector2(rng.randi_range(-1, 1), rng.randi_range(-1, 1))))
		if pad.frame == busy and meant != Vector2i.ZERO:
			# how the stroke went; a swipe that did nothing is noticed a reaction time later (0.25 s)
			var made: Array = pad.moves.slice(m0)
			if made.is_empty():
				tally.dud += 1
				busy += 15
			else:
				if Vector2i(made[0][1], made[0][2]) != meant:
					tally.wrong += 1
				tally.extra += made.size() - 1
			meant = Vector2i.ZERO
		if pad.frame >= busy:
			var nx := {}
			for n in r.notes:
				if n.state == 0 and n.t > r.t - 0.05:
					nx = n
					break
			if not nx.is_empty():
				var dc: int = nx.col - r.col
				var dr: int = nx.row - r.row
				var steps := absi(dc) + absi(dr)
				if steps > 0 and nx.t - r.t < 0.1 + 0.2 * steps and r.respawn <= 0.45:
					var v := Vector2(signi(dc) * 70, 0) if dc != 0 else Vector2(0, -signi(dr) * 70)
					var f := pad.frame + 1
					var i := 0
					meant = Vector2i(signi(dc), 0) if dc != 0 else Vector2i(0, signi(dr))
					m0 = pad.moves.size()
					tally.swipes += 1
					if style.ends_with("thumbs"):
						i = (0 if dc < 0 else 1) if dc != 0 else 1 - used
						used = i
					var fg: Dictionary = fing[i]
					if style == "steer" and fg.down and dc != 0 and fg.dir == -signi(dc):
						# turn back by dragging the resting finger back
						fg.p = pad.stroke(i, f, fg.p, fg.p + v * 0.85, 6, false, false)
						fg.dir = signi(dc)
						busy = f + 6
						active = i
					else:
						if fg.down:
							pad.at(f, Pad.touch(i, fg.p, false))
							f += 1
						var keep := style != "lift"
						var from: Vector2 = homes[i] if style.ends_with("thumbs") else HOME_AT - v * 0.4
						fg.p = pad.stroke(i, f, from, from + v, 6, true, not keep)
						fg.down = keep
						fg.dir = signi(dc) if dc != 0 else 0
						busy = f + 6
						active = i
		pad.tick()
	var res := {"c": r.J.c, "n": r.notes.size(), "lost": r.lost}
	res.merge(tally)
	pad.done()
	return res


# ------------------------------------------------------------------ a real event stream, replayed

func _replay() -> void:
	## the touch events logged from a film (a filmed run played by touch, the new swipes on), fed to both inputs: every
	## stroke's move is checked against what the stroke meant (a press and its drags, or the drags after a pause)
	var lv := (load(LEVEL) as PackedScene).instantiate() as Level
	var course := lv.course()
	lv.free()
	var evs := []
	for line in FileAccess.get_file_as_string("res://tests/swipe_stream_rio.txt").split("\n"):
		var w := line.split(" ", false)
		if w.size() >= 5 and not line.begins_with("#"):
			evs.append([int(w[0]), w[1], int(w[2]), Vector2(float(w[3]), float(w[4])), w.size() > 5 and w[5] == "true"])
	# the strokes: [first frame, last frame, the move meant]
	var strokes := []
	var last := {}             # finger -> [frame, where]
	for e in evs:
		var i: int = e[2]
		var starts: bool = (e[1] == "touch" and e[4]) or (e[1] == "drag" and (not last.has(i) or e[0] - last[i][0] > 1))
		if starts:
			strokes.append([e[0], e[0], last[i][1] if e[1] == "drag" and last.has(i) else e[3], e[3]])
		elif not strokes.is_empty():
			strokes[-1][1] = e[0]
			strokes[-1][3] = e[3]
		last[i] = [e[0], e[3]]
	var meant := []
	for st in strokes:
		var d: Vector2 = st[3] - st[2]
		if d.length() > 22.0:
			meant.append([st[0], st[1], Vector2i(signi(int(d.x)), 0) if absf(d.x) > absf(d.y) else Vector2i(0, -signi(int(d.y)))])
	print("\n== The film's own touch stream (%d events, %d strokes) replayed into both inputs, 30 fps" % [evs.size(), meant.size()])
	for kind in ["as now", "all three"]:
		var pad := Pad.new(course, KINDS[kind], true)
		pad.fps = 30.0
		for e in evs:
			pad.at(e[0], Pad.touch(e[2], e[3], e[4]) if e[1] == "touch" else Pad.drag(e[2], e[3]))
		pad.run_to(evs[-1][0] + 10)
		var t := {"did nothing": 0, "wrong way": 0, "extra": 0, "unmeant": 0}
		var used := {}
		for m in meant:
			var made := pad.moves.filter(func(v): return v[0] >= m[0] and v[0] <= m[1] + 2)
			for v in made:
				used[v] = true
			if made.is_empty():
				t["did nothing"] += 1
			else:
				if Vector2i(made[0][1], made[0][2]) != m[2]:
					t["wrong way"] += 1
				t.extra += made.size() - 1
		t.unmeant = pad.moves.filter(func(v): return not used.has(v)).size()
		var caught := 0
		var due := 0
		for n in pad.rules.notes:
			if float(n.t) > evs[0][0] / 30.0 and float(n.t) < evs[-1][0] / 30.0:
				due += 1
				caught += 1 if n.state == 1 else 0
		print("   %-10s moves %2d  did nothing %2d  wrong way %d  extra %d  unmeant %d   notes in the stretch %d/%d" % [kind, pad.moves.size(), t["did nothing"], t["wrong way"], t.extra, t.unmeant, caught, due])
		if kind == "all three" and (t["did nothing"] > 0 or t["wrong way"] > 0 or t.extra > 0 or t.unmeant > 0):
			_fail("the new swipes on the film's own stream: %s" % str(t))
		pad.done()
