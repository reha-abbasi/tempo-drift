@tool
extends Control
## The episode map, as the web game draws it: the whole world at the same scale for every era (the Americas left,
## Europe and Africa in the middle, Asia and Australia right; the Pacific is the seam), in the era's style (an old
## paper chart, a night-blue atlas, a neon grid), the route between the era's cities (flown legs solid, the rest
## dashed and moving), and a numbered pin on each city with its name where there is room.
## Land: Natural Earth (public domain), data/world.json.

signal picked(i: int)

const STYLES := {
	"old": {"sea": [Color("e8d9b8"), Color("d8c39a")], "land": Color("c6a273"), "coast": Color("7a5634"), "grid": Color(110 / 255.0, 70 / 255.0, 40 / 255.0, 0.18), "route": Color("8a2a1e"), "pin": Color("b8382a"), "dots": false},
	"sunset": {"sea": [Color("1a2e4c"), Color("0e1a30")], "land": Color("2f4a68"), "coast": Color("9cc2ec"), "grid": Color(160 / 255.0, 200 / 255.0, 1.0, 0.08), "route": Color("ffd45c"), "pin": Color("ffd45c"), "dots": false},
	"rain": {"sea": [Color("07060e"), Color("0d0a1c")], "land": Color("ff3fb4"), "coast": Color("2ef2ff"), "grid": Color(46 / 255.0, 242 / 255.0, 1.0, 0.1), "route": Color("ff3fb4"), "pin": Color("2ef2ff"), "dots": true},
}

@export var map := "old":
	set(v):
		map = v
		queue_redraw()
var selected := 0
var next_ep := 0
var stars: Array = [0, 0, 0, 0, 0, 0, 0, 0]
var unlocked: Array = [true, true, true, true, true, true, true, true]
var names: Array = []

var _world := {}
var _land: Array = []        # projected rings for the current size
var _land_size := Vector2.ZERO
var _pins: Array = []        # [Vector2] where each pin sits
var _true: Array = []        # [Vector2] the city's real spot
var _t := 0.0
var _font: Font


func _ready() -> void:
	_world = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
	_font = load("res://ui/font_display.tres") if ResourceLoader.exists("res://ui/font_display.tres") else get_theme_default_font()
	resized.connect(func(): _land_size = Vector2.ZERO; queue_redraw())


func _process(delta: float) -> void:
	_t += delta
	if is_visible_in_tree():
		queue_redraw()


func _view() -> Dictionary:
	var w := maxf(1.0, size.x)
	var h := maxf(1.0, size.y)
	var x0 := -180.0
	var x1 := 180.0
	var y0 := -78.0
	var y1 := 58.0
	var want := w / h
	var have := (x1 - x0) / (y1 - y0)
	if have < want:
		var d := ((y1 - y0) * want - (x1 - x0)) / 2.0
		x0 -= d
		x1 += d
	else:
		var d := ((x1 - x0) / want - (y1 - y0)) / 2.0
		y0 -= d
		y1 += d
	return {"x0": x0, "y0": y0, "S": w / (x1 - x0), "c0": 12.0}


func _proj(V: Dictionary, la: float, lo: float) -> Vector2:
	var sh := fposmod(lo - V.c0 + 540.0, 360.0) - 180.0
	return Vector2((sh - V.x0) * V.S, (-la - V.y0) * V.S)


func _draw() -> void:
	if _world.is_empty():
		_ready()
	var st: Dictionary = STYLES[map]
	var V := _view()
	var w := size.x
	var h := size.y
	# the sea
	var steps := 24
	for i in steps:
		var c: Color = (st.sea[0] as Color).lerp(st.sea[1], float(i) / steps)
		draw_rect(Rect2(0, h * i / steps, w, h / steps + 1), c)
	# lines of longitude and latitude every 15 degrees
	for lo in range(-180, 181, 15):
		var x: float = (fposmod(lo - V.c0 + 540.0, 360.0) - 180.0 - V.x0) * V.S
		draw_line(Vector2(x, 0), Vector2(x, h), st.grid, 1.0)
	for la in range(-75, 76, 15):
		var y: float = (-la - V.y0) * V.S
		draw_line(Vector2(0, y), Vector2(w, y), st.grid, 1.0)
	# land (each ring three times, a world apart, so the view can sit across the date line)
	if _land_size != size:
		_land_size = size
		_land = []
		for ring in _world.rings:
			for off in [-360.0, 0.0, 360.0]:
				var pts := PackedVector2Array()
				var r := Rect2()
				for p in ring:
					var q := Vector2((p[0] - V.c0 + off - V.x0) * V.S, (-p[1] - V.y0) * V.S)
					pts.append(q)
				r = Rect2(pts[0], Vector2.ZERO)
				for q in pts:
					r = r.expand(q)
				if r.end.x < -20 or r.position.x > w + 20 or r.end.y < -20 or r.position.y > h + 20:
					continue
				_land.append(pts)
	for pts in _land:
		if st.dots:
			# the neon map: dotted land with a glowing coast
			var tri := Geometry2D.triangulate_polygon(pts)
			if tri.size() > 0:
				draw_colored_polygon(pts, Color(st.land, 0.16))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(st.coast, 0.25), 4.0, true)
			draw_polyline(pts + PackedVector2Array([pts[0]]), st.coast, 0.9, true)
		else:
			if Geometry2D.triangulate_polygon(pts).size() > 0:
				draw_colored_polygon(pts, st.land)
			draw_polyline(pts + PackedVector2Array([pts[0]]), st.coast, 1.3 if map == "old" else 0.8, true)
	if map == "rain":
		for y in range(0, int(h), 3):
			draw_rect(Rect2(0, y, w, 1), Color(46 / 255.0, 242 / 255.0, 1.0, 0.05))
	if map == "old":
		# an old chart darkens at the edges
		for i in 10:
			var k := float(i) / 10.0
			draw_rect(Rect2(Vector2(w, h) * k * 0.05, Vector2(w, h) * (1.0 - k * 0.1)), Color(90 / 255.0, 50 / 255.0, 20 / 255.0, 0.035), false, 6.0)
	_place(V)
	# the route
	for i in _pins.size() - 1:
		var a: Vector2 = _pins[i]
		var b: Vector2 = _pins[i + 1]
		var mid := (a + b) / 2.0 - Vector2(0, a.distance_to(b) * 0.18)
		var curve := PackedVector2Array()
		for k in 25:
			var u := k / 24.0
			curve.append(a.lerp(mid, u).lerp(mid.lerp(b, u), u))
		if int(stars[i]) > 0:
			draw_polyline(curve, Color(st.route, 0.95), 2.2, true)
		else:
			_dashed(curve, Color(st.route, 0.7), 1.6, 5.0, 6.0, _t * 9.0)
	# thin lines from a nudged pin to its real spot
	for i in _pins.size():
		if (_pins[i] as Vector2).distance_to(_true[i]) > 6.0:
			draw_line(_pins[i], _true[i], Color(st.coast, 0.6), 1.0, true)
			draw_circle(_true[i], 2.2, st.route)
	# pins and names
	for i in _pins.size():
		var p: Vector2 = _pins[i]
		var open: bool = unlocked[i]
		var pc: Color = st.pin if open else Color("6a6670")
		if i == next_ep and open:
			var k := fmod(_t / 1.6, 1.0)
			draw_arc(p, 10.0 + k * 9.0, 0, TAU, 32, Color(pc, 1.0 - k), 2.0, true)
		if i == selected:
			draw_circle(p, 15.0, Color(pc, 0.6))
			draw_circle(p, 12.0, Color.WHITE)
		draw_circle(p, 12.0 if i != selected else 10.5, Color(0, 0, 0, 0.35))
		draw_circle(p, 10.0, pc)
		var label := str(i + 1) if open else "·"
		draw_string(_font, p + Vector2(-20, 4), label, HORIZONTAL_ALIGNMENT_CENTER, 40, 10, Color("140c06") if open else Color("e8e4ee"))
		_name(p, i, st)


func _name(p: Vector2, i: int, _st: Dictionary) -> void:
	if i >= names.size():
		return
	var text: String = names[i]
	var s := " " + "★".repeat(int(stars[i])) if int(stars[i]) > 0 else ""
	var fs := 10
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + (_font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x if s != "" else 0.0) + 10.0
	var th := 15.0
	# the label goes on whichever side is clear of the other pins and inside the map
	var best := Rect2()
	var best_cost := INF
	for o in [Vector2(13, -th / 2), Vector2(-13 - tw, -th / 2), Vector2(-tw / 2, 12), Vector2(-tw / 2, -12 - th), Vector2(10, 6), Vector2(-10 - tw, 6)]:
		var r := Rect2(p + o, Vector2(tw, th))
		var cost := 50.0 if (r.position.x < 2 or r.position.y < 2 or r.end.x > size.x - 2 or r.end.y > size.y - 2) else 0.0
		for q in _pins:
			if r.intersects(Rect2(q - Vector2(10, 10), Vector2(20, 20))):
				cost += 10.0
		if cost < best_cost:
			best_cost = cost
			best = r
		if cost == 0.0:
			break
	draw_style_box(_pill(), best)
	draw_string(_font, best.position + Vector2(5, 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE if unlocked[i] else Color("c9c2d8"))
	if s != "":
		var x := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, best.position + Vector2(5 + x, 11), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("ffd45c"))


var _pill_box: StyleBoxFlat


func _pill() -> StyleBoxFlat:
	if _pill_box == null:
		_pill_box = StyleBoxFlat.new()
		_pill_box.bg_color = Color(8 / 255.0, 6 / 255.0, 14 / 255.0, 0.62)
		_pill_box.set_corner_radius_all(99)
	return _pill_box


func _place(V: Dictionary) -> void:
	## each city's pin on the city itself; cities closer than a pin's width are eased apart, with a line to the true spot
	_pins = []
	_true = []
	for n in names:
		var g: Array = _world.cities.get(String(n), [0, 0])
		var q := _proj(V, g[0], g[1])
		_true.append(q)
		_pins.append(q)
	for it in 60:
		for a in _pins.size():
			for b in range(a + 1, _pins.size()):
				var d: Vector2 = _pins[b] - _pins[a]
				var l := maxf(d.length(), 0.01)
				if l < 24.0:
					var m := (24.0 - l) / 2.0 / l
					_pins[a] -= d * m
					_pins[b] += d * m
	for i in _pins.size():
		_pins[i] = (_pins[i] as Vector2).clamp(Vector2(12, 12), size - Vector2(12, 12))


func _dashed(pts: PackedVector2Array, c: Color, wdt: float, dash: float, gap: float, phase: float) -> void:
	var pos := -fmod(phase, dash + gap)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var l := a.distance_to(b)
		var u := 0.0
		while u < l:
			var on := fposmod(pos + u, dash + gap) < dash
			var step := minf(l - u, 1.5)
			if on:
				draw_line(a.lerp(b, u / l), a.lerp(b, (u + step) / l), c, wdt, true)
			u += step
		pos += l


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for i in _pins.size():
			if (e.position as Vector2).distance_to(_pins[i]) < 16.0:
				picked.emit(i)
				accept_event()
				return
