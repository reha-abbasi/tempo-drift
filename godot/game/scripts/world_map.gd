class_name WorldMap
extends Control
## The era map: an old explorer's chart of the world, zoomed to where the era's cities are. Parchment sea, inked
## coastlines, a red route from city to city in the order you fly them, and a pin for each city (gold when chosen,
## grey while it's locked). Tap a pin to choose it.

signal pin_pressed(i: int)

const SEA := Color("e8d9b8")
const SEA_DEEP := Color("d8c39a")
const LAND := Color("c6a273")
const COAST := Color("7a5634")
const GRID := Color(0.43, 0.27, 0.16, 0.16)
const ROUTE := Color("8a2a1e")
const PIN := Color("b8382a")
const GOLD := Color(1.0, 0.83, 0.36)

var rings: Array = []
var cities: Array = []      # {name, lat, lon, stars, open}
var selected := 0
var font: Font
var land_mesh: ArrayMesh
var lon_c := -25.0
var kx := 0.72              # cos of the middle latitude, so the chart isn't stretched sideways
var view := Rect2()         # the chart area in map units
var _t := 0.0

func setup(world_json: String, f: Font) -> void:
	font = f
	var d: Dictionary = JSON.parse_string(FileAccess.open(world_json, FileAccess.READ).get_as_text())
	rings = d.rings
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP

## the cities of the era, in flying order; the chart frames them with some room around
func set_cities(list: Array, sel: int) -> void:
	cities = list
	selected = sel
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c in cities:
		lo.x = minf(lo.x, c.lon); lo.y = minf(lo.y, c.lat)
		hi.x = maxf(hi.x, c.lon); hi.y = maxf(hi.y, c.lat)
	lon_c = (lo.x + hi.x) * 0.5
	kx = cos(deg_to_rad((lo.y + hi.y) * 0.5))
	var a := _proj(hi.y + 9.0, lo.x - 14.0)
	var b := _proj(lo.y - 9.0, hi.x + 14.0)
	view = Rect2(a, b - a)
	_build_land()
	queue_redraw()

func _proj(lat: float, lon: float) -> Vector2:
	return Vector2((lon - lon_c) * kx, -lat)

## the land, as one mesh in map units (each coastline drawn at its longitude and a world to either side)
func _build_land() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for r in rings:
		for shift in [-360.0, 0.0, 360.0]:
			var pts := PackedVector2Array()
			for q in r:
				pts.append(_proj(q[1], q[0] + shift))
			# big coastlines cross themselves here and there: clean each into simple shapes first, then fill them
			for poly in Geometry2D.offset_polygon(pts, 0.02):
				var idx := Geometry2D.triangulate_polygon(poly)
				for k in idx:
					st.set_color(Color.WHITE)
					st.add_vertex(Vector3(poly[k].x, poly[k].y, 0))
					any = true
	land_mesh = st.commit() if any else null

## map units to the screen: the chart fills the control, keeping its proportions (the larger side may show more)
func _xf() -> Transform2D:
	var s := minf(size.x / view.size.x, size.y / view.size.y)
	var off := size * 0.5 - (view.position + view.size * 0.5) * s
	return Transform2D(0.0, Vector2(s, s), 0.0, off)

func _to_screen(lat: float, lon: float) -> Vector2:
	return _xf() * _proj(lat, lon)

func _process(dt: float) -> void:
	if visible:
		_t += dt
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SEA)
	var xf := _xf()
	var s := xf.get_scale().x
	# the graticule every 10 degrees
	for lat in range(-80, 90, 10):
		var a := xf * _proj(lat, lon_c - 200.0)
		var b := xf * _proj(lat, lon_c + 200.0)
		draw_line(a, b, GRID, 1.0)
	for lon in range(-180, 190, 10):
		var a := xf * _proj(85.0, lon)
		var b := xf * _proj(-85.0, lon)
		draw_line(a, b, GRID, 1.0)
	if land_mesh:
		draw_set_transform_matrix(xf)
		draw_mesh(land_mesh, null, Transform2D.IDENTITY, LAND)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	for r in rings:
		for shift in [-360.0, 0.0]:
			var pts := PackedVector2Array()
			for q in r:
				pts.append(xf * _proj(q[1], q[0] + shift))
			pts.append(pts[0])
			draw_polyline(pts, COAST, 1.2, true)
	# the route between the cities, in ink, dashed past the last open one
	for i in range(1, cities.size()):
		var a := _to_screen(cities[i - 1].lat, cities[i - 1].lon)
		var b := _to_screen(cities[i].lat, cities[i].lon)
		var open: bool = cities[i].open
		draw_dashed_line(a, b, Color(ROUTE, 0.85 if open else 0.4), 2.0, 9.0 if open else 5.0, true)
	# the pins, then their names, each placed on the first side where it doesn't cover another name or pin
	var taken := []
	for c in cities:
		var p := _to_screen(c.lat, c.lon)
		taken.append(Rect2(p - Vector2(8, 8), Vector2(16, 16)))
	for i in cities.size():
		var c: Dictionary = cities[i]
		var p := _to_screen(c.lat, c.lon)
		var sel := i == selected
		var col := GOLD if sel else (PIN if c.open else Color(0.45, 0.4, 0.36))
		if sel:
			var pr := 14.0 + 6.0 * (0.5 + 0.5 * sin(_t * 4.0))
			draw_arc(p, pr, 0, TAU, 32, Color(GOLD, 0.7), 2.0, true)
		draw_circle(p, 9.0 if sel else 7.0, Color(0.15, 0.08, 0.04, 0.85))
		draw_circle(p, 6.0 if sel else 4.5, col)
		var label: String = c.name.to_upper()
		var fs := 15 if sel else 13
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var lp := p + Vector2(12, 5)
		for off in [Vector2(12, 5), Vector2(-12 - w, 5), Vector2(-w * 0.5, -12), Vector2(-w * 0.5, 22), Vector2(12, -9), Vector2(-12 - w, -9), Vector2(12, 19), Vector2(-12 - w, 19)]:
			var r := Rect2(p + off - Vector2(0, fs), Vector2(w, fs + 4))
			var ok := r.position.x > 4 and r.end.x < size.x - 4
			for t in taken:
				if t.intersects(r):
					ok = false
					break
			if ok:
				lp = p + off
				break
		taken.append(Rect2(lp - Vector2(0, fs), Vector2(w, fs + 4 + (14 if c.stars > 0 else 0))))
		draw_string(font, lp + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.96, 0.86, 0.7))
		draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.2, 0.1, 0.05) if c.open else Color(0.4, 0.36, 0.32))
		if c.stars > 0:
			draw_string(font, lp + Vector2(0, 15), "★".repeat(c.stars), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ROUTE)

func _gui_input(e: InputEvent) -> void:
	var pressed: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed)
	if not pressed:
		return
	var best := -1
	var bd := 40.0
	for i in cities.size():
		var d := _to_screen(cities[i].lat, cities[i].lon).distance_to(e.position)
		if d < bd:
			bd = d
			best = i
	if best >= 0:
		selected = best
		pin_pressed.emit(best)
		accept_event()
