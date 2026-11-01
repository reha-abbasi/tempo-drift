class_name Rules
extends RefCounted
## The rules of a run, as in the web game (web/game.html, v26 "Note Mode"). No drawing here: the run scene reads this
## state and listens to its signals. Numbers and names follow the web game so the two can be compared line by line.
##
## Three lanes and three heights; the car cruises on the skyway (the middle height) and hops up or dives down for
## one note. Every melody note is a ring: being in it at its note plays the note, and a move made just before its
## note is graded EXCELLENT, a little earlier (or just in time) GOOD, long before OK. Lives: the car, then (after a
## crash) the jetpack; a rescue meter filled by played notes wins the car back. Flow builds the band and, when full,
## gives eight bars of OVERDRIVE at x8.

signal judged(grade: String, note: Dictionary)   # "ex", "gd", "ok" or "" (a plain catch)
signal missed(note: Dictionary)
signal crashed(hazard: Dictionary)
signal shield_saved(hazard: Dictionary)
signal form_lost(form: int)                       # the form you're left in: 1 jetpack, 0 out of lives
signal delivered(form: int)
signal rescue_inbound(at: float)
signal overdrive(on: bool)
signal tier_up(tier: int)
signal popped(text: String, kind: String, priority: int)
signal power_up(kind: String)
signal edge_bump(dir: int)
signal moved(dc: int, dr: int)
signal finish_line
signal cleared
signal game_over

const LX := [-1.6, 0.0, 1.6]
const LY := [-1.7, 0.0, 1.7]
const HOME := 1
const MID := 1
const NL := 3
const ROAD_Y := -2.3
const RESPAWN := 1.6
const DROP_TAIL := 0.22
const OD_BARS := 8
const SYNC_START := 75.0
const SYNC_MISS := 5.0
const RESCUE_PER := 2.75
const RESCUE_MISS := 2.4
const RESCUE_GLASS := 4.4
const MOVE_BEST := 0.12
const CUE_T := 0.6
const TIMING := {"ex": {"say": "EXCELLENT", "pts": 300}, "gd": {"say": "GOOD", "pts": 200}, "ok": {"say": "OK", "pts": 100}}
## traffic: length along the street and speed relative to the world (1 = standing still in the street)
const KINDS := {
	"taxi": {"len": 2.2, "rel": 0.5}, "truck": {"len": 4.0, "rel": 0.45}, "bus": {"len": 4.2, "rel": 0.42},
	"hovercab": {"len": 2.0, "rel": 0.5}, "drone": {"len": 1.2, "rel": 0.5}, "barrier": {"len": 0.5, "rel": 1.0},
	"oldcar": {"len": 2.2, "rel": 0.5}, "dbus": {"len": 4.2, "rel": 0.42}, "biplane": {"len": 2.2, "rel": 0.5},
}

# ---- the course
var course: Dictionary
var notes: Array = []      # {t, col, row, note, len, dir, mv, pu, i, state 0 waiting / 1 played / 2 missed / 3 lost in a crash}
var hazards: Array = []    # {t, col, row, kind, over, under, state 0 coming / 1 hit / 2 passed, near}
var ghosts: Array = []
var BAR := 2.0
var BEAT := 0.5
var SPEED := 18.0
var HANG := 0.5
var gate := 60.0
var first_t := 0.0         # the first note's bar line: the count-in lands on it
var ep := 0
var tutorial := false
var rescue_k := 1.6
var sync_k := 1.0

# ---- the car (where it counts as being, and where it is drawn)
var col := MID
var row := HOME
var x := 0.0
var y := 0.0
var vx := 0.0
var vy := 0.0
var vt := 0.0              # how long a hop or dive has left
var move_t := -9.0         # when the car last changed lane or height
var reach_car := 0.62      # the car's perk can widen it (Retro)
var magnet_k := 1.0
var start_shield := false

# ---- the run
var t := 0.0
var score := 0
var combo := 0
var max_combo := 0
var sync := SYNC_START
var flow := 0.0
var od_t := 0.0
var od_n := 0
var band := 1
var form := 2              # 2 car, 1 jetpack (0 = out of lives)
var rescue := 0.0
var deliver_at := INF
var invuln := 0.0
var respawn := 0.0
var magnet_t := 0.0
var x2_t := 0.0
var shield_on := false
var melody_on := true
var J := {"c": 0, "m": 0, "ex": 0, "gd": 0, "ok": 0}
var hits := 0              # notes played (pays coins)
var lost := 0              # crashes
var overs := 0             # roadblocks hopped
var finished := false
var over := false
var done := false
var last_judged := -9.0
var autopilot := false     # the menu backdrop and the tests fly themselves
var autopilot_lead := 0.5  # how early the autopilot moves to the next note (tests use a well-timed 0.13)


func load_course(c: Dictionary, tut := false) -> void:
	course = c
	tutorial = tut
	BAR = float(c.bar)
	BEAT = float(c.beat)
	SPEED = float(c.speed)
	HANG = float(c.hang)
	gate = float(c.gate)
	ep = int(c.get("ep", 0))
	rescue_k = float(c.get("rescueK", 1.6))
	sync_k = 0.8 + 0.15 * float(c.get("diff", {}).get("L", 0.0))
	first_t = float(c.get("intro", 2)) * BAR
	reset()


func reset() -> void:
	notes = []
	var i := 0
	for n in course.notes:
		var m: Dictionary = n.duplicate()
		m.i = i
		m.state = 0
		notes.append(m)
		i += 1
	hazards = []
	for h in course.hazards:
		var m: Dictionary = h.duplicate()
		m.state = 0
		m.near = false
		hazards.append(m)
	ghosts = course.get("ghosts", [])
	col = MID
	row = HOME
	x = LX[col]
	y = LY[row]
	vx = 0.0
	vy = 0.0
	vt = 0.0
	move_t = -9.0
	t = 0.0
	score = 0
	combo = 0
	max_combo = 0
	sync = SYNC_START
	flow = 0.0
	od_t = 0.0
	od_n = 0
	band = 1
	form = 2
	rescue = 0.0
	deliver_at = INF
	invuln = 0.0
	respawn = 0.0
	magnet_t = 0.0
	x2_t = 0.0
	shield_on = start_shield and not tutorial
	melody_on = true
	J = {"c": 0, "m": 0, "ex": 0, "gd": 0, "ok": 0}
	hits = 0
	lost = 0
	overs = 0
	finished = false
	over = false
	done = false
	last_judged = -9.0


# ------------------------------------------------------------------ input

func move(dx: int, dy: int) -> bool:
	## left/right change lane; up hops off the skyway and down dives under it for one beat; the opposite swipe ends a
	## hop early, the same swipe again re-fires the thrusters
	if over or respawn > 0.45:
		return false
	var pc := col
	var pr := row
	if dx != 0 and (col + dx < 0 or col + dx > NL - 1):
		edge_bump.emit(dx)
	col = clampi(col + dx, 0, NL - 1)
	if dy != 0:
		if row == HOME:
			row = HOME + dy
			vt = HANG
		elif row == HOME + dy:
			vt = HANG
		else:
			row = HOME
			vt = 0.0
	if col != pc or row != pr:
		move_t = t
		moved.emit(col - pc, row - pr)
	return true


# ------------------------------------------------------------------ helpers

func tier() -> int:
	return 8 if od_t > 0.0 else 1 + mini(3, int(flow / 30.0))


func score_mult() -> int:
	return tier() * (2 if x2_t > 0.0 else 1)


func reach_now() -> float:
	return reach_car if form == 2 else 0.56


func accuracy() -> float:
	var n: int = J.c + J.m
	return float(J.c) / n if n > 0 else 1.0


static func grade_of(a: float, clean: bool) -> String:
	if a >= 0.99 and clean:
		return "S"
	if a >= 0.95:
		return "A"
	if a >= 0.88:
		return "B"
	if a >= 0.78:
		return "C"
	return "D"


static func stars_for(g: String) -> int:
	return {"S": 3, "A": 2}.get(g, 1)


static func move_grade(e: float) -> String:
	if e > 0.36:
		return "ok"
	if e > 0.2 or e < 0.05:
		return "gd"
	return "ex"


func hazard_z(h: Dictionary) -> float:
	## where a vehicle is along the street, relative to the car (negative = ahead); traffic moves, blocks stand still
	return -(float(h.t) - t) * SPEED * float(KINDS[h.kind].rel)


func band_at() -> int:
	## the band changes only on bar lines: 1 drums and bass, 2 the whole band, 3 + arpeggio, 4 + claps and shaker.
	## It steps up as Flow passes 30 / 60 / 90 and only steps down 12 below that mark
	if od_t > 0.0:
		return 4
	var cap: int = [3, 3, 4][form]
	var up := mini(cap, 1 + mini(3, int(flow / 30.0)))
	if up > band:
		return up
	var b := mini(band, cap)
	while b > 1 and flow < (b - 1) * 30 - 12:
		b -= 1
	return b


# ------------------------------------------------------------------ the frame

func step(now: float) -> void:
	var dt := clampf(now - t, 0.0, 0.1)
	var prev_bar := int(floor(t / BAR))
	t = now
	invuln = maxf(0.0, invuln - dt)
	respawn = maxf(0.0, respawn - dt)
	if int(floor(t / BAR)) != prev_bar:
		band = band_at()
	# the skyway pulls the car back once the hop is over
	if row != HOME:
		vt -= dt
		if vt <= 0.0:
			row = HOME
			vt = 0.0
	if autopilot:
		_autopilot()
	var sx := _smooth(x, LX[col], vx, 0.11, dt)
	x = sx.x
	vx = sx.y
	var sy := _smooth(y, LY[row], vy, 0.11, dt)
	y = sy.x
	vy = sy.y
	if deliver_at < INF and t >= deliver_at and not over:
		_deliver()
	magnet_t = maxf(0.0, magnet_t - dt)
	x2_t = maxf(0.0, x2_t - dt)
	if od_t > 0.0:
		od_t -= dt
		if od_t <= 0.0:
			_end_overdrive(false)
	_judge_notes()
	_check_hazards()
	if not finished and t > gate:
		finished = true
		popped.emit("FINISH!", "gold big", 3)
		finish_line.emit()
	if not over and t > gate + BAR + 0.15:
		over = true
		done = true
		cleared.emit()


func _judge_notes() -> void:
	for n in notes:
		if n.state != 0:
			continue
		if respawn > 0.45:
			# notes during a crash are lost (no extra penalty)
			if t > n.t + 0.08:
				n.state = 3
				last_judged = n.t
				_judge_coin("m", n, true)
			continue
		var near: bool = absf(x - LX[n.col]) < (2.4 if magnet_t > 0.0 else reach_now()) and absf(y - LY[n.row]) < (2.2 if magnet_t > 0.0 else 0.7)
		if near and t >= n.t - 0.05:
			n.state = 1
			last_judged = n.t
			combo += 1
			hits += 1
			if n.get("pu", "") != "" and n.pu != null:
				_power_up(n.pu)
			var tg := move_grade(n.t - move_t) if n.mv and not n.get("wait", false) else ""
			_judge_coin("c", n, false, tg)
			# a note up there (or down there) ends the hop: the car drops straight back to the skyway
			if n.row != HOME:
				vt = DROP_TAIL
			melody_on = true
		elif t > n.t + 0.08:
			n.state = 2
			last_judged = n.t
			combo = 0
			melody_on = false
			_judge_coin("m", n, false)


func _judge_coin(g: String, n: Dictionary, was_lost: bool, tg := "") -> void:
	if over and not autopilot:
		return
	J[g] += 1
	if g != "m":
		max_combo = maxi(max_combo, combo)
		if tg != "":
			J[tg] += 1
		score += (int(TIMING[tg].pts) if tg != "" else 100) * score_mult()
		_rescue_gain(RESCUE_PER)
		if not tutorial:
			sync = minf(100.0, sync + 1.5)
		if od_t <= 0.0:
			var t0 := tier()
			flow = minf(100.0, flow + 3.0 * (1.6 if tutorial else 1.0))
			if flow >= 100.0:
				_start_overdrive()
			elif tier() > t0:
				tier_up.emit(tier())
		if combo > 0 and combo % 50 == 0:
			popped.emit("%d COMBO" % combo, "gold", 1)
		judged.emit(tg, n)
	else:
		if not was_lost:
			flow = maxf(0.0, flow - 25.0)
			_hurt(SYNC_MISS * sync_k)
		missed.emit(n)


func _hurt(n: float) -> void:
	if tutorial or od_t > 0.0:
		return
	sync = maxf(0.0, sync - n)
	rescue = maxf(0.0, rescue - RESCUE_MISS)


func _check_hazards() -> void:
	var row_gap: float = LY[1] - LY[0]
	for h in hazards:
		if h.state != 0:
			continue
		var z := hazard_z(h)
		var r: float = float(KINDS[h.kind].len) / 2.0 + 0.9
		if z < -r:
			continue
		if z > r:
			h.state = 2
			if h.over and not over:
				overs += 1
			if h.near and not over:
				score += 25 * score_mult()
			continue
		var dx := absf(x - LX[h.col])
		var dy := absf(y - LY[h.row])
		if invuln <= 0.0 and dx < 0.75 and dy < (0.45 if h.over else 0.8):
			_crash(h)
			continue
		if (dx < 1.9 and dy < 0.5) or (dx < 0.5 and dy < row_gap + 0.3):
			h.near = true


func _crash(h: Dictionary) -> void:
	if shield_on:
		shield_on = false
		h.state = 1
		invuln = 1.2
		popped.emit("SHIELD SAVED YOU", "gold", 2)
		shield_saved.emit(h)
		return
	h.state = 1
	combo = 0
	melody_on = false
	lost += 1
	respawn = RESPAWN
	invuln = RESPAWN + 0.9
	row = HOME
	vt = 0.0
	flow = 0.0
	if od_t > 0.0:
		_end_overdrive(true)
	crashed.emit(h)
	_lose_form()


func _lose_form() -> void:
	if tutorial:
		return
	form -= 1
	rescue = 0.0
	deliver_at = INF
	if form >= 1:
		popped.emit("CAR DOWN · JETPACK!", "red", 3)
		form_lost.emit(form)
	else:
		form = 1
		over = true
		popped.emit("OUT OF LIVES", "red", 3)
		form_lost.emit(0)
		game_over.emit()


func _rescue_gain(n: float) -> void:
	if form >= 2 or tutorial or deliver_at < INF:
		return
	rescue = clampf(rescue + n * rescue_k, 0.0, 100.0)
	if rescue >= 100.0:
		deliver_at = ceilf((t + 0.35) / BEAT) * BEAT
		popped.emit("RESCUE INBOUND · YOUR CAR" if form == 1 else "RESCUE INBOUND · JETPACK", "gold", 2)
		rescue_inbound.emit(deliver_at)


func _deliver() -> void:
	deliver_at = INF
	rescue = 0.0
	form += 1
	invuln = maxf(invuln, 0.9)
	popped.emit("NEW CAR!" if form == 2 else "JETPACK!", "gold", 3)
	delivered.emit(form)


func _power_up(k: String) -> void:
	match k:
		"magnet":
			magnet_t = 10.0 * magnet_k
		"x2":
			x2_t = 12.0
		_:
			shield_on = true
	popped.emit({"magnet": "MAGNET!", "x2": "DOUBLE SCORE!", "shield": "SHIELD!"}.get(k, "SHIELD!"), "gold", 2)
	power_up.emit(k)


func _start_overdrive() -> void:
	od_t = OD_BARS * BAR
	od_n += 1
	band = 4
	popped.emit("OVERDRIVE ×8", "od big", 3)
	overdrive.emit(true)


func _end_overdrive(cut: bool) -> void:
	od_t = 0.0
	flow = 0.0 if cut else 30.0
	if not cut:
		popped.emit("OVERDRIVE OVER", "", 1)
	overdrive.emit(false)


func revive() -> void:
	## back on your feet on the jetpack (paid for on the game-over screen); the song carries on from where you crashed
	form = 1
	rescue = 0.0
	flow = 0.0
	invuln = RESPAWN + 2.0
	respawn = 0.0
	over = false


# ------------------------------------------------------------------ the autopilot (menus, tests)

func _autopilot() -> void:
	var nx: Dictionary = {}
	for n in notes:
		if n.state == 0 and n.t > t - 0.05:
			nx = n
			break
	if nx.is_empty() or respawn >= 0.45:
		return
	# it lands back on the skyway late, as a person would, so it never drops onto a block it's clearing
	var lead := 0.2 if (nx.row == HOME and row != HOME) else autopilot_lead
	if nx.t - t < lead and (nx.col != col or nx.row != row):
		var dc: int = nx.col - col
		var dr: int = nx.row - row
		col = nx.col
		row = nx.row
		move_t = t
		vt = HANG
		moved.emit(signi(dc), signi(dr))
	if row != HOME and nx.row == row and nx.col == col:
		vt = maxf(vt, nx.t - t + 0.15)


static func _smooth(cur: float, target: float, vel: float, st: float, dt: float) -> Vector2:
	## a critically damped spring (Unity's SmoothDamp, as the web game uses): returns (value, velocity)
	var w := 2.0 / st
	var xx := w * dt
	var e := 1.0 / (1.0 + xx + 0.48 * xx * xx + 0.235 * xx * xx * xx)
	var ch := cur - target
	var tmp := (vel + w * ch) * dt
	return Vector2(target + (ch + tmp) * e, (vel - w * tmp) * e)
