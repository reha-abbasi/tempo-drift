class_name Game
extends Node
## The rules of a run, carried over from the web game: three lanes and three heights, a ring for every melody note,
## each move graded by its timing, Flow and Overdrive, two lives (the car, then the jetpack) and the rescue meter.
## This node only keeps the state; the world, the car and the HUD draw from it.

signal judged(grade: String, note: Dictionary)
signal missed(note: Dictionary)
signal crashed(hazard: Dictionary, form_left: int)
signal delivered(form: int)
signal overdrive(on: bool)
signal finished
signal cleared(result: Dictionary)
signal game_over(result: Dictionary)
signal popped(text: String, kind: String)
signal shielded

# lanes left to right, heights low / skyway / high
var LX: Array = [-1.6, 0.0, 1.6]
var LY: Array = [-2.05, 0.0, 2.05]
var YS := 1.0
const HOME := 1
const ROW_COLORS := [Color("4aa8ff"), Color("ffe2b8"), Color("ff5a8c")]
const DROP_TAIL := 0.22
const RESPAWN := 1.6
const OD_BARS := 8
const RESCUE_PER := 2.75
const RESCUE_MISS := 2.4
# a move made just before its note is EXCELLENT (the car takes about 0.1 s to get there), a little earlier (or just
# in time) GOOD, waiting in the lane long before OK
const MOVE_BEST := 0.12
# four EXCELLENTs in a row and a second voice joins the melody (a duet); each of its notes scores DUET_PTS
const DUET_AFTER := 4
const DUET_PTS := 400
const TIMING := {
	"ex": {"say": "EXCELLENT", "pts": 300},
	"gd": {"say": "GOOD", "pts": 200},
	"ok": {"say": "OK", "pts": 100},
}

var course: Dictionary
var notes: Array = []
var hazards: Array = []
var bars: Array = []
var BAR := 2.0
var BEAT := 0.5
var SPEED := 18.0
var HANG := 0.5
var gate := 60.0
var kinds: Dictionary = {}

var t := 0.0
var running := false
var over := false
var done := false
var finished_flag := false

# where the car is: lane and height it's in, and where it's drawn (eased toward the lane)
var col := 1
var row := HOME
var x := 0.0
var y := 0.0
var vx := 0.0
var vy := 0.0
var vt := 0.0
var move_t := -9.0

var form := 2          # 2 = car, 1 = jetpack
var form_anim := {"kind": "", "t0": -9.0}
var respawn := 0.0
var invuln := 0.0
var rescue := 0.0
var deliver_at := INF

var score := 0
var combo := 0
var max_combo := 0
var flow := 0.0
var od_t := 0.0
var od_n := 0
var band := 1
var melody_on := true
var ex_streak := 0
var duets := 0
var J := {"c": 0, "m": 0, "ex": 0, "gd": 0, "ok": 0}
var lost := 0
var last_bar := -1
# the car's perk ("", "rescue", "reach", "shield", "coins"), set before a run, and the shield it may start with
var perk := ""
var shield := false

func load_course(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	course = JSON.parse_string(f.get_as_text())
	LX = course.lanes
	# the three heights sit further apart than in the web game (low and high fly well clear of the skyway), and the
	# vertical tolerances scale with them
	LY = [-2.05, 0.0, 2.05]
	YS = 2.05 / absf(float(course.rows[0]))
	BAR = course.bar
	BEAT = course.beat
	SPEED = course.speed
	HANG = course.hang
	gate = course.gate
	kinds = course.kinds
	bars = course.bars
	reset()

func reset() -> void:
	notes = []
	for i in course.notes.size():
		var n: Dictionary = course.notes[i].duplicate()
		n.i = i
		n.state = 0
		notes.append(n)
	hazards = []
	for h0 in course.hazards:
		var h: Dictionary = h0.duplicate()
		h.state = 0
		h.near = false
		hazards.append(h)
	t = -0.05
	running = false
	over = false
	done = false
	finished_flag = false
	col = 1; row = HOME; x = LX[1]; y = LY[HOME]; vx = 0.0; vy = 0.0; vt = 0.0; move_t = -9.0
	form = 2; form_anim = {"kind": "", "t0": -9.0}; respawn = 0.0; invuln = 0.0; rescue = 0.0; deliver_at = INF
	score = 0; combo = 0; max_combo = 0; flow = 0.0; od_t = 0.0; od_n = 0; band = 1; melody_on = true; ex_streak = 0; duets = 0
	J = {"c": 0, "m": 0, "ex": 0, "gd": 0, "ok": 0}
	lost = 0
	last_bar = -1
	shield = perk == "shield"

func reach() -> float:
	if form != 2:
		return 0.56
	return 0.78 if perk == "reach" else 0.62

func tier() -> int:
	return 8 if od_t > 0.0 else 1 + mini(3, int(flow / 30.0))

## the bar the song is in (0 = the first intro bar)
func bar_at(time: float) -> int:
	return int(floor(time / BAR))

## a swipe: left/right changes lane, up hops off the skyway and down dives under it, for one beat;
## the opposite swipe ends a hop early, the same swipe again re-fires the thrusters
func move(dx: int, dy: int) -> bool:
	if not running or over or respawn > 0.45:
		return false
	var pc := col
	var pr := row
	col = clampi(col + dx, 0, 2)
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
		return true
	return false

func move_grade(e: float) -> String:
	if e > 0.36:
		return "ok"
	if e > 0.2 or e < 0.05:
		return "gd"
	return "ex"

func step(now: float, dt: float) -> void:
	t = now
	if not running or done:
		return
	invuln = maxf(0.0, invuln - dt)
	respawn = maxf(0.0, respawn - dt)
	# the hop runs out and the car drops back to the skyway
	if row != HOME:
		vt -= dt
		if vt <= 0.0:
			row = HOME
			vt = 0.0
	var r := _smooth(x, LX[col], vx, 0.11, dt)
	x = r.x; vx = r.y
	r = _smooth(y, LY[row], vy, 0.11, dt)
	y = r.x; vy = r.y
	if deliver_at < INF and t >= deliver_at and not over:
		_deliver()
	if od_t > 0.0:
		od_t -= dt
		if od_t <= 0.0:
			_end_overdrive(false)
	var b := bar_at(t)
	if b != last_bar:
		last_bar = b
		band = _band_at()
	_judge_notes()
	_check_hazards()
	if not finished_flag and t > gate:
		finished_flag = true
		finished.emit()
	if t > gate + BAR + 0.15 and not over:
		done = true
		cleared.emit(result())

func _judge_notes() -> void:
	for n in notes:
		if n.state != 0:
			continue
		if respawn > 0.45:
			# notes during a crash are lost (no extra penalty)
			if t > n.t + 0.08:
				n.state = 3
				_judge("m", n, true)
			continue
		var near: bool = absf(x - LX[n.col]) < reach() and absf(y - LY[n.row]) < 0.7 * YS
		if near and t >= n.t - 0.05:
			n.state = 1
			combo += 1
			var g := ""
			if n.mv:
				g = move_grade(n.t - move_t)
			_judge("c", n, false, g)
			# a note up there (or down there) ends the hop: the car drops straight back to the skyway
			if n.row != HOME:
				vt = DROP_TAIL
			melody_on = true
		elif t > n.t + 0.08:
			n.state = 2
			combo = 0
			melody_on = false
			_judge("m", n, false)
			missed.emit(n)
		if n.t > t + 1.0:
			break

func _judge(g: String, n: Dictionary, was_lost: bool, tg: String = "") -> void:
	J[g] += 1
	if g == "c":
		max_combo = maxi(max_combo, combo)
		var pts := 100
		if tg != "":
			J[tg] += 1
			pts = TIMING[tg].pts
			ex_streak = ex_streak + 1 if tg == "ex" else 0
			if ex_streak == DUET_AFTER:
				popped.emit("DUET!", "gold")
		# (notes that need no move, like dropping back after a hop, keep the duet going)
		n.duet = ex_streak >= DUET_AFTER
		if n.duet:
			duets += 1
			if tg == "ex":
				pts = DUET_PTS
		score += pts * tier()
		_rescue_gain(RESCUE_PER)
		if od_t <= 0.0:
			flow = minf(100.0, flow + 3.0)
			if flow >= 100.0:
				_start_overdrive()
		if combo > 0 and combo % 50 == 0:
			popped.emit("%d COMBO" % combo, "gold")
		judged.emit(tg, n)
	else:
		ex_streak = 0
	if g == "m" and not was_lost:
		flow = maxf(0.0, flow - 25.0)
		if od_t <= 0.0:
			rescue = maxf(0.0, rescue - RESCUE_MISS)

func _check_hazards() -> void:
	for h in hazards:
		if h.state != 0:
			continue
		var z := hazard_z(h)
		var rch: float = kinds[h.kind].len / 2.0 + 0.9
		if z < -rch:
			if z < -120.0:
				break
			continue
		if z > rch:
			h.state = 2
			if h.near:
				score += 25 * tier()
			continue
		var dx: float = absf(x - LX[h.col])
		var dy: float = absf(y - LY[h.row])
		if invuln <= 0.0 and dx < 0.75 and dy < (0.45 if h.over else 0.8) * YS:
			_crash(h)
			continue
		if (dx < 1.9 and dy < 0.5 * YS) or (dx < 0.5 and dy < 2.0 * YS):
			h.near = true

## where a vehicle is along the road, relative to the car (negative = ahead); traffic drives forward, so it closes slower
func hazard_z(h: Dictionary) -> float:
	return -(h.t - t) * SPEED * kinds[h.kind].rel

func note_z(n: Dictionary) -> float:
	return -(n.t - t) * SPEED

func _crash(h: Dictionary) -> void:
	h.state = 1
	if shield:
		# the shield takes the hit: no life lost, a moment to get clear
		shield = false
		invuln = 1.2
		shielded.emit()
		popped.emit("SHIELD SAVED YOU", "gold")
		return
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
	form -= 1
	rescue = 0.0
	deliver_at = INF
	form_anim = {"kind": "eject" if form >= 1 else "down", "t0": t}
	crashed.emit(h, form)
	if form < 1:
		form = 1
		over = true
		done = true
		popped.emit("OUT OF LIVES", "red")
		game_over.emit(result())
	else:
		popped.emit("CAR DOWN · JETPACK!", "red")

## the rescue meter fills with every note while you're out of the car; full, your car flies in on the next beat
func _rescue_gain(n: float) -> void:
	if form >= 2 or deliver_at < INF:
		return
	rescue = clampf(rescue + n * float(course.rescueK) * (1.3 if perk == "rescue" else 1.0), 0.0, 100.0)
	if rescue >= 100.0:
		deliver_at = ceil((t + 0.35) / BEAT) * BEAT
		popped.emit("RESCUE INBOUND · YOUR CAR", "gold")

func _deliver() -> void:
	deliver_at = INF
	rescue = 0.0
	form += 1
	form_anim = {"kind": "deliver", "t0": t}
	invuln = maxf(invuln, 0.9)
	delivered.emit(form)
	popped.emit("NEW CAR!", "gold")

func _start_overdrive() -> void:
	od_t = OD_BARS * BAR
	od_n += 1
	band = 4
	overdrive.emit(true)
	popped.emit("OVERDRIVE ×8", "od")

func _end_overdrive(cut: bool) -> void:
	od_t = 0.0
	flow = 0.0 if cut else 30.0
	overdrive.emit(false)

## the band changes only on bar lines: it steps up as Flow passes 30 / 60 / 90 and only steps down once Flow is
## 12 below that mark, so one miss doesn't gut it
func _band_at() -> int:
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

func accuracy() -> float:
	var n: int = J.c + J.m
	return float(J.c) / n if n > 0 else 1.0

func grade_of(a: float, clean: bool) -> String:
	if a >= 0.99 and clean:
		return "S"
	if a >= 0.95:
		return "A"
	if a >= 0.88:
		return "B"
	if a >= 0.78:
		return "C"
	return "D"

func result() -> Dictionary:
	var a := accuracy()
	var g := grade_of(a, lost == 0)
	return {"score": score, "acc": a, "grade": g, "stars": 3 if g == "S" else 2 if g == "A" else 1,
		"J": J.duplicate(), "max_combo": max_combo, "lost": lost, "od": od_n, "duets": duets, "failed": over}

## the same easing the web game uses for the car (a critically damped spring)
func _smooth(cur: float, target: float, vel: float, st: float, dt: float) -> Vector2:
	var w := 2.0 / st
	var xx := w * dt
	var e := 1.0 / (1.0 + xx + 0.48 * xx * xx + 0.235 * xx * xx * xx)
	var ch := cur - target
	var tmp := (vel + w * ch) * dt
	return Vector2(target + (ch + tmp) * e, (vel - w * tmp) * e)
