@tool
extends Node3D
class_name Level
## One level of the game, laid out to edit: its city (sky, light, landmark), its whole street, every note ring and
## every vehicle where they meet the car. A ring's lane and height are where it sits and its timing is how far
## down the street it is, so moving a ring along the street moves its note in time (the recorded melody stays where
## it is). Rings and vehicles snap to the three lanes and three heights. Bar lines with their bar number and time
## mark the road in the editor (they are not saved).
## Playing this scene (F6) flies the level as it is now. The song's timing (tempo, bars, speed) comes from
## course_file; everything that can be seen comes from this scene.

const K := 1.4

@export var display_name := ""
## the song's timing and the run's settings (tempo, bar length, speed, difficulty)
@export_file("*.json") var course_file := ""
## the folder with the song's recordings
@export_dir var song := ""
@export var map := "old"
@export var index := 0
@export var flight_school := false

var _meta := {}
var _tick := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		_paint_traffic()
		_bar_lines()
		_refresh()
	else:
		_play_if_alone.call_deferred()


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_tick += delta
	if _tick > 0.25:
		_tick = 0.0
		_refresh()


func meta() -> Dictionary:
	if _meta.is_empty():
		_meta = JSON.parse_string(FileAccess.get_file_as_string(course_file))
	return _meta


func speed() -> float:
	## metres per second down the street
	return float(meta().speed) * K


func course() -> Dictionary:
	## the course as the rules read it: the song's timing from course_file, the notes and traffic from this scene
	var c: Dictionary = meta().duplicate()
	c.notes = notes()
	c.hazards = hazards()
	return c


func notes() -> Array:
	var list := []
	for p in _ring_notes():
		list.append(p[1])
	return list


func _ring_notes() -> Array:
	## [ring, note] for every ring, in time order
	var list := []
	for r in get_node("Notes").get_children():
		var n := {"t": snappedf(-r.position.z / speed(), 0.0001), "col": _lane(r.position.x), "row": _row(r.position.y),
			"note": r.pitch, "len": r.length, "pu": "" if r.power_up == "none" else r.power_up,
			"wait": "" if r.waits_for == "none" else r.waits_for}
		if r.layer >= 0:
			n.layer = r.layer
		list.append([r, n, list.size()])
	# in time order; at the same moment, in scene order
	list.sort_custom(func(a, b): return a[1].t < b[1].t or (a[1].t == b[1].t and a[2] < b[2]))
	# the swipe each ring asks for follows from the ring before it (the web game's rule)
	var last = null
	for p in list:
		var n: Dictionary = p[1]
		n.dir = _dir(n, last)
		n.mv = last != null and (n.col != last.col or (n.row != last.row and n.row != Rules.HOME))
		last = n
	return list


func hazards() -> Array:
	var list := []
	for h in get_node("Traffic").get_children():
		list.append({"t": snappedf(-h.position.z / speed(), 0.0001), "col": _lane(h.position.x), "row": _row(h.position.y),
			"kind": h.kind, "over": h.over, "under": h.under, "k": list.size()})
	list.sort_custom(func(a, b): return a.t < b.t or (a.t == b.t and a.k < b.k))
	for h in list:
		h.erase("k")
	return list


static func place(col: int, row: int, t: float, metres_per_s: float) -> Vector3:
	return Vector3(Rules.LX[col] * K, (Rules.LY[row] - Rules.ROAD_Y) * K, -t * metres_per_s)


static func _dir(n: Dictionary, last) -> String:
	if last == null:
		return ""
	if n.row == 2 and last.row != 2:
		return "U"
	if n.row == 0 and last.row != 0:
		return "D"
	if n.col > last.col:
		return "R"
	if n.col < last.col:
		return "L"
	return ""


static func _lane(x: float) -> int:
	var best := 0
	for i in Rules.LX.size():
		if absf(Rules.LX[i] * K - x) < absf(Rules.LX[best] * K - x):
			best = i
	return best


static func _row(y: float) -> int:
	var best := 0
	for i in Rules.LY.size():
		var yi: float = (Rules.LY[i] - Rules.ROAD_Y) * K
		if absf(yi - y) < absf((Rules.LY[best] - Rules.ROAD_Y) * K - y):
			best = i
	return best


# ------------------------------------------------------------------ the editor

func _refresh() -> void:
	## snap what was moved to its lane and height, and show each ring's colour and swipe
	if not has_node("Notes") or course_file == "":
		return
	for pair in _ring_notes():
		var r: Node3D = pair[0]
		var n: Dictionary = pair[1]
		var p := place(n.col, n.row, 0.0, 1.0)
		if not is_equal_approx(r.position.x, p.x) or not is_equal_approx(r.position.y, p.y):
			r.position = Vector3(p.x, p.y, r.position.z)
		if r.note.get("row") != n.row or r.note.get("dir") != n.dir or r.note.get("pu") != n.pu:
			r.setup(n)
	for h in get_node("Traffic").get_children():
		var p := place(_lane(h.position.x), _row(h.position.y), 0.0, 1.0)
		if not is_equal_approx(h.position.x, p.x) or not is_equal_approx(h.position.y, p.y):
			h.position = Vector3(p.x, p.y, h.position.z)


func _paint_traffic() -> void:
	var city := get_node_or_null("City") as City
	if city == null or not has_node("Traffic"):
		return
	var i := 0
	for h in get_node("Traffic").get_children():
		if h.get_child_count() > 0:
			city.paint(h.get_child(0), h.kind, i)
		i += 1


func _bar_lines() -> void:
	## a line across the road at every bar, with the bar number and the time in the song
	if course_file == "":
		return
	var m := meta()
	var bar := float(m.bar)
	var line := BoxMesh.new()
	line.size = Vector3(Rules.LX[2] * K * 2.0 + 2.6, 0.02, 0.08)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.83, 0.36, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line.material = mat
	for b in int(m.len) + 1:
		var z := -b * bar * speed()
		var mi := MeshInstance3D.new()
		mi.mesh = line
		mi.position = Vector3(0, 0.03, z)
		add_child(mi, false, Node.INTERNAL_MODE_BACK)
		var l := Label3D.new()
		l.text = "bar %d  ·  %d:%04.1f" % [b, int(b * bar) / 60, fmod(b * bar, 60.0)]
		l.font_size = 64
		l.pixel_size = 0.01
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.modulate = Color(1.0, 0.83, 0.36)
		l.outline_size = 12
		l.position = Vector3(-Rules.LX[2] * K - 2.4, 1.2, z)
		add_child(l, false, Node.INTERNAL_MODE_BACK)


# ------------------------------------------------------------------ playing it

func _play_if_alone() -> void:
	## opened on its own (F6): fly it
	if get_tree().current_scene != self:
		return
	Launch.mode = "school" if flight_school else "episode"
	Launch.map = map
	Launch.index = index
	get_tree().change_scene_to_file("res://scenes/run/run.tscn")
