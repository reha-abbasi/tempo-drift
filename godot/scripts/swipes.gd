class_name Swipes
extends RefCounted
## Swipes on a phone, made to land more surely. In a run, run.gd hands its keys, touches and drags here instead of
## reading them itself (its own swipe code is the earlier way, kept as the reference tests/swipe_check.tscn compares
## against). Three small tweaks, each with its own flag so they can be judged one by one:
## - sure_swipe: every finger has its own swipe, so two thumbs never mix each other up, and a quick flick that only
##   got long enough as the finger lifted still counts
## - drag_on: a finger that has swiped left or right can keep steering without lifting: coming back moves back a
##   lane, dragging on about half the screen moves one lane more (never past the outer lanes)
## - swipe_memory: a swipe made a moment before the car can move again (the end of a crash) is kept and made as
##   soon as it can
## The rules are untouched: every move still goes through Rules.move, so catches, crashes and scoring are the same.

const SWIPE := 22.0          # how far a finger moves before it is a swipe (as run.gd)
const LIFT := 30.0           # a flick this long when the finger lifts counts even if no drag got there (the web game's)
const TURN := 30.0           # how far a finger comes back to steer back a lane
const DRAG_LANE := 150.0     # how much further a finger drags on to move one lane more
const KEEP := 0.12           # how long a swipe the car can't make yet is kept (s)
const LOCK := 0.45           # Rules.move refuses moves while the crash's respawn is above this
const KEYS := {KEY_LEFT: Vector2i(-1, 0), KEY_A: Vector2i(-1, 0), KEY_RIGHT: Vector2i(1, 0), KEY_D: Vector2i(1, 0),
	KEY_UP: Vector2i(0, 1), KEY_W: Vector2i(0, 1), KEY_DOWN: Vector2i(0, -1), KEY_S: Vector2i(0, -1)}

var rules: Rules
var sure_swipe := true
var drag_on := true
var swipe_memory := true
var _fingers := {}           # finger -> {i: the finger that swiped, from, fired, dir: the way it steers (-1/1, 0 after a hop), at: where it last moved the car, peak}
var _kept := Vector2i.ZERO
var _kept_until := -INF


func _init(r: Rules) -> void:
	rules = r


func input(e: InputEvent) -> bool:
	## a key, touch or drag of the run; true when it was used here
	if e is InputEventKey:
		if not e.pressed or e.echo or not KEYS.has(e.keycode):
			return false
		var m: Vector2i = KEYS[e.keycode]
		_move(m.x, m.y)
		return true
	if e is InputEventScreenTouch:
		var f: int = e.index if sure_swipe else 0
		if e.pressed:
			_fingers[f] = {"i": -1, "from": e.position, "fired": false, "dir": 0, "at": 0.0, "peak": 0.0}
		elif sure_swipe:
			var s: Dictionary = _fingers.get(f, {})
			if not s.is_empty() and not s.fired and not e.canceled:
				var d: Vector2 = e.position - s.from
				if maxf(absf(d.x), absf(d.y)) >= LIFT:
					_swipe(d)
			_fingers.erase(f)
		else:
			_fingers.clear()
		return true
	if e is InputEventScreenDrag:
		var s: Dictionary = _fingers.get(e.index if sure_swipe else 0, {})
		if s.is_empty():
			return true
		var px: float = e.position.x
		if not s.fired:
			var d: Vector2 = e.position - s.from
			if d.length() > SWIPE:
				s.fired = true
				s.i = e.index
				s.dir = signi(int(d.x)) if absf(d.x) > absf(d.y) else 0
				s.at = px
				s.peak = px
				_swipe(d)
		elif drag_on and s.dir != 0 and e.index == s.i:
			if (px - s.peak) * s.dir > 0.0:
				s.peak = px
			if (px - s.at) * s.dir >= DRAG_LANE:
				_steer(s.dir)
				s.at = px
				s.peak = px
			elif (s.peak - px) * s.dir >= TURN:
				s.dir = -s.dir
				_steer(s.dir)
				s.at = px
				s.peak = px
		return true
	return false


func tick() -> void:
	## once a frame, after the rules' step: a kept swipe is made as soon as the car can move
	if _kept == Vector2i.ZERO:
		return
	if rules.t > _kept_until or rules.move(_kept.x, _kept.y):
		_kept = Vector2i.ZERO


func _swipe(d: Vector2) -> void:
	if absf(d.x) > absf(d.y):
		_move(signi(int(d.x)), 0)
	else:
		_move(0, -signi(int(d.y)))


func _steer(dx: int) -> void:
	## a lane more (or back) while dragging on; never past the outer lanes, so it never bumps the edge
	if rules.col + dx >= 0 and rules.col + dx <= Rules.NL - 1:
		_move(dx, 0)


func _move(dx: int, dy: int) -> void:
	if rules.move(dx, dy):
		_kept = Vector2i.ZERO
	elif swipe_memory and not rules.over and rules.respawn <= LOCK + KEEP:
		_kept = Vector2i(dx, dy)
		_kept_until = rules.t + KEEP
