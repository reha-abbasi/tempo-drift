extends RefCounted
## The landmark at the end of every city's street (scenes/landmarks/<bg>.tscn), as the web game paints them on its
## horizon. They stand about 340 m ahead of the car (the city's Horizon node keeps them there); their colours carry
## the city's haze and they ignore the street fog, so they stay on the horizon like the painted backdrop did.
## Sizes are real where they fit the view (about 110 m tall at that distance), smaller where they would not.
## Also the set pieces (scenes/deco): the Singapore Flyer, fireworks, searchlights, lightning and police drones.

var looks := {}
var k: MeshKit
var fog := Color.GRAY
var haze := 0.3
var _mats := {}


func build(_host: Node) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/meshes/landmarks"))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/looks.json"))
	for map in ["old", "sunset", "rain"]:
		var th: Dictionary = data[map].theme
		for ep in data[map].episodes:
			var L: Dictionary = (th.look as Dictionary).duplicate()
			L.merge(ep.look, true)
			looks[L.bg] = L
	for bg in looks:
		var L: Dictionary = looks[bg]
		fog = hex(L.fog)
		var night := float(L.get("sunY", 0.07)) < 0.0
		haze = 0.18 if night else 0.32
		k = MeshKit.new()
		_mats = {}
		call("lm_" + bg)
		save(bg, L)
	deco()


static func hex(v) -> Color:
	var n := int(v)
	return Color8((n >> 16) & 255, (n >> 8) & 255, n & 255)


## a material by colour; `glow` makes it shine (lit windows, clock faces, neon)
func m(col, glow := 0.0, metal := 0.0) -> String:
	var c: Color = col if col is Color else Color(col)
	var key := "%s_%.2f_%.1f" % [c.to_html(false), glow, metal]
	if not _mats.has(key):
		var sm := StandardMaterial3D.new()
		sm.albedo_color = c.lerp(fog, haze) if glow == 0.0 else c
		sm.roughness = 0.8 if metal == 0.0 else 0.35
		sm.metallic = metal
		sm.disable_fog = true
		if glow > 0.0:
			sm.emission_enabled = true
			sm.emission = c
			sm.emission_energy_multiplier = glow
		k.use(key, sm)
		_mats[key] = true
	return key


func save(bg: String, L: Dictionary) -> void:
	var path := "res://assets/meshes/landmarks/%s.res" % bg
	ResourceSaver.save(k.bake(), path)
	var root := Node3D.new()
	root.name = bg.capitalize().replace(" ", "")
	var mi := MeshInstance3D.new()
	mi.name = "Model"
	mi.mesh = load(path)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	if bg in ["dubai", "newyork"]:
		var beacon := OmniLight3D.new()
		beacon.name = "Beacon"
		beacon.light_color = Color(1, 0.3, 0.25)
		beacon.position = Vector3(0, 128 if bg == "dubai" else 112, -40 if bg == "dubai" else 0)
		root.add_child(beacon)
	Kit.save(root, "res://scenes/landmarks/%s.tscn" % bg)


# --- shapes ---------------------------------------------------------------------------------------------------

func box(mat: String, c: Vector3, s: Vector3) -> void:
	k.box(mat, c + Vector3(0, s.y / 2, 0), s, ["-y"])


func cone(mat: String, c: Vector3, r: float, h: float, sides := 4, rot := PI / 4) -> void:
	var old := k.at(k.xform * Transform3D(Basis(Vector3.UP, rot), c))
	k.lathe(mat, PackedVector2Array([Vector2(r, 0), Vector2(0, h)]), Vector3.ZERO, sides, false)
	k.xform = old


func dome(mat: String, c: Vector3, r: float, h := -1.0, segs := 20) -> void:
	h = r if h < 0 else h
	var prof := PackedVector2Array()
	for i in 9:
		var a := PI / 2 * i / 8.0
		prof.append(Vector2(cos(a) * r, sin(a) * h))
	k.lathe(mat, prof, c, segs)


func drum(mat: String, c: Vector3, r: float, h: float, segs := 20) -> void:
	k.lathe(mat, PackedVector2Array([Vector2(r, 0), Vector2(r, h), Vector2(0, h)]), c, segs)


func turned(mat: String, c: Vector3, prof: Array, segs := 16, smooth := true) -> void:
	var p := PackedVector2Array()
	for v in prof:
		p.append(Vector2(v[0], v[1]))
	k.lathe(mat, p, c, segs, smooth)


func windows(mat: String, c: Vector3, w: float, h: float, cols: int, rows: int, face := 1.0) -> void:
	## rows of lit windows on a front facing +Z (face = 1) at c (bottom middle)
	for r in rows:
		for i in cols:
			var x := c.x - w / 2 + w * (i + 0.5) / cols
			var y := c.y + h * (r + 0.35) / rows
			k.quad(mat, Vector3(x - w / cols * 0.22, y, c.z + 0.05 * face), Vector3(x + w / cols * 0.22, y, c.z + 0.05 * face),
				Vector3(x + w / cols * 0.22, y + h / rows * 0.4, c.z + 0.05 * face), Vector3(x - w / cols * 0.22, y + h / rows * 0.4, c.z + 0.05 * face))


func mountain(mat: String, c: Vector3, w: float, h: float, profile: Array, depth := 60.0) -> void:
	## a ridge: profile is [x 0..1, y 0..1] pairs, extruded back from the front at c
	var pts := PackedVector2Array()
	pts.append(Vector2(c.x - w / 2, c.y))
	for p in profile:
		pts.append(Vector2(c.x - w / 2 + w * p[0], c.y + h * p[1]))
	pts.append(Vector2(c.x + w / 2, c.y))
	k.prism(mat, pts, c.z - depth, c.z)


func gothic_front(mat: String, trim: String, glass: String, c: Vector3, w: float, h: float, bays: int) -> void:
	box(mat, c, Vector3(w, h, 14))
	for i in bays + 1:
		var x := c.x - w / 2 + w * i / bays
		box(trim, Vector3(x, c.y, c.z + 7.2), Vector3(1.2, h + 2, 1.2))
		cone(trim, Vector3(x, c.y + h + 2, c.z + 7.2), 0.9, 4)
	windows(glass, Vector3(c.x, c.y + 2, c.z + 7), w, h - 4, bays * 2, 3)


# --- the Past -----------------------------------------------------------------------------------------------------

func lm_london() -> void:
	## the Houses of Parliament's long gothic front, the Victoria Tower, the clock tower; Tower Bridge far left
	var stone := m(Color(0.78, 0.68, 0.5))
	var roof := m(Color(0.25, 0.27, 0.3))
	var glass := m(Color(1.0, 0.8, 0.5), 1.2)
	var face := m(Color(1.0, 0.93, 0.75), 2.2)
	gothic_front(stone, stone, glass, Vector3(-10, -4, 0), 90, 22, 14)
	box(roof, Vector3(-10, 18, -2), Vector3(88, 3, 10))
	# the Victoria Tower
	box(stone, Vector3(-62, -4, 0), Vector3(18, 76, 18))
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			box(stone, Vector3(-62 + sx * 8.5, -4, sz * 8.5), Vector3(2, 82, 2))
			cone(stone, Vector3(-62 + sx * 8.5, 78, sz * 8.5), 1.4, 6)
	windows(glass, Vector3(-62, 10, 9.05), 14, 56, 4, 8)
	# the Elizabeth Tower (Big Ben): shaft, clock stage with four faces, belfry, spire
	var x := 34.0
	box(stone, Vector3(x, -4, 0), Vector3(12, 60, 12))
	windows(glass, Vector3(x, 4, 6.05), 9, 46, 3, 9)
	box(stone, Vector3(x, 56, 0), Vector3(14, 14, 14))
	for f in 4:
		var old := k.at(Transform3D(Basis(Vector3.UP, f * PI / 2), Vector3(x, 0, 0)))
		k.xform = k.xform * Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 63, 7.1))
		k.lathe(face, PackedVector2Array([Vector2(5.2, 0), Vector2(0, 0)]), Vector3.ZERO, 24, false)
		k.xform = old
	box(stone, Vector3(x, 70, 0), Vector3(12, 8, 12))
	cone(roof, Vector3(x, 78, 0), 8.6, 18)
	cone(m(Color(0.75, 0.62, 0.3), 0.0, 0.6), Vector3(x, 95, 0), 1.2, 9)
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			cone(stone, Vector3(x + sx * 6, 78, sz * 6), 1.2, 7)
	# Tower Bridge, far off to the left
	for tx: float in [-120.0, -90.0]:
		box(stone, Vector3(tx, -4, -60), Vector3(10, 44, 10))
		cone(roof, Vector3(tx, 40, -60), 6.5, 10)
	box(m(Color(0.35, 0.45, 0.55)), Vector3(-105, 30, -60), Vector3(20, 3, 4))
	box(m(Color(0.35, 0.45, 0.55)), Vector3(-105, 4, -60), Vector3(40, 3, 8))


func lm_istanbul() -> void:
	## a great mosque: the dome on cascading half domes, small domes and four minarets; Galata Tower to the left
	var stone := m(Color(0.86, 0.8, 0.72))
	var lead := m(Color(0.5, 0.55, 0.6), 0.0, 0.4)
	var gold := m(Color(1.0, 0.8, 0.4), 1.5)
	box(stone, Vector3(0, -4, 0), Vector3(64, 26, 64))
	drum(stone, Vector3(0, 22, 0), 17, 8, 24)
	dome(lead, Vector3(0, 30, 0), 17, 13, 24)
	for d: Vector3 in [Vector3(0, 0, 24), Vector3(0, 0, -24), Vector3(24, 0, 0), Vector3(-24, 0, 0)]:
		dome(lead, d + Vector3(0, 20, 0), 11, 8)
	for d: Vector3 in [Vector3(26, 0, 26), Vector3(-26, 0, 26), Vector3(26, 0, -26), Vector3(-26, 0, -26)]:
		dome(lead, d + Vector3(0, 21, 0), 6, 5)
	turned(gold, Vector3(0, 43, 0), [[0.6, 0], [0.4, 5], [0, 7]], 6)
	for d: Vector3 in [Vector3(40, 0, 36), Vector3(-40, 0, 36), Vector3(40, 0, -36), Vector3(-40, 0, -36)]:
		turned(stone, d + Vector3(0, -4, 0), [[2.2, 0], [1.8, 50], [2.6, 51], [2.6, 52], [1.5, 53], [1.4, 64], [2.2, 65], [0, 72]], 10, false)
		turned(gold, d + Vector3(0, 52, 0), [[2.7, 0], [2.7, 0.6], [0, 0.6]], 10)
	# Galata Tower on its hill
	mountain(m(Color(0.42, 0.36, 0.34)), Vector3(-95, -4, -30), 90, 22, [[0.2, 0.6], [0.5, 1.0], [0.8, 0.6]])
	drum(stone, Vector3(-95, 18, -40), 6, 34, 16)
	cone(lead, Vector3(-95, 52, -40), 7, 12, 16, 0)


func lm_paris() -> void:
	## the Eiffel Tower lit gold; Sacré-Cœur on Montmartre to the left
	var iron := m(Color(0.62, 0.45, 0.28), 0.0, 0.5)
	var lit := m(Color(1.0, 0.75, 0.38), 1.6)
	var x := 20.0
	# four legs that lean in and meet at the second floor, then the shaft
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			var a := Vector3(x + sx * 26, -4, sz * 26)
			var b := Vector3(x + sx * 6, 46, sz * 6)
			var y := (b - a).normalized()
			var xa := y.cross(Vector3.BACK).normalized() if absf(y.z) < 0.99 else Vector3.RIGHT
			var old := k.at(Transform3D(Basis(xa, y, xa.cross(y)), (a + b) / 2))
			k.box(iron, Vector3.ZERO, Vector3(4.5, a.distance_to(b), 4.5))
			k.xform = old
	# the arches and the platforms
	box(iron, Vector3(x, 14, 0), Vector3(40, 2.4, 40))
	box(lit, Vector3(x, 16.4, 0), Vector3(36, 0.6, 36))
	box(iron, Vector3(x, 44, 0), Vector3(16, 2, 16))
	turned(iron, Vector3(x, 46, 0), [[6.5, 0], [3.2, 30], [1.6, 52], [1.2, 58], [0, 66]], 4, false)
	turned(lit, Vector3(x, 46, 0), [[6.6, 0], [6.6, 0.4], [0, 0.4]], 4, false)
	for y: float in [10.0, 26.0, 40.0]:
		var w := 30.0 - y * 0.55
		box(lit, Vector3(x, y, 0), Vector3(w, 0.4, w))
	turned(lit, Vector3(x, 98, 0), [[0.6, 0], [0.3, 6], [0, 8]], 6)
	# Montmartre and Sacré-Cœur, white
	mountain(m(Color(0.42, 0.42, 0.48)), Vector3(-80, -4, -50), 110, 26, [[0.25, 0.7], [0.5, 1.0], [0.75, 0.7]])
	var white := m(Color(0.95, 0.93, 0.88))
	box(white, Vector3(-80, 20, -60), Vector3(28, 12, 20))
	drum(white, Vector3(-80, 32, -60), 6, 6)
	turned(white, Vector3(-80, 38, -60), [[6.4, 0], [6, 4], [4, 8], [0, 10]], 16)
	turned(white, Vector3(-80, 48, -60), [[0.8, 0], [0.8, 3], [0, 5]], 8)
	for sx: int in [-1, 1]:
		drum(white, Vector3(-80 + sx * 11, 32, -55), 3, 3)
		dome(white, Vector3(-80 + sx * 11, 35, -55), 3, 4)


func lm_newyork() -> void:
	## the Empire State Building's setbacks and mast, then the Chrysler Building's crown of arches
	var stone := m(Color(0.62, 0.6, 0.58))
	var lit := m(Color(1.0, 0.82, 0.55), 1.4)
	var steel := m(Color(0.85, 0.85, 0.9), 0.0, 0.8)
	var x := -10.0
	for step in [[40, 30, 0], [34, 26, 42], [24, 20, 74], [16, 14, 88], [10, 10, 96]]:
		box(stone, Vector3(x, -4 + step[2], 0), Vector3(step[0], (42 if step[2] == 0 else 32 if step[2] == 42 else 14 if step[2] == 74 else 8 if step[2] == 88 else 6), step[1]))
	windows(lit, Vector3(x, 0, 15.05), 36, 36, 9, 10)
	windows(lit, Vector3(x, 40, 13.05), 30, 28, 8, 8)
	turned(steel, Vector3(x, 98, 0), [[3.5, 0], [2.4, 6], [1.0, 12], [0.4, 18], [0, 22]], 8)
	# Chrysler
	var cx := 52.0
	box(stone, Vector3(cx, -4, -30), Vector3(22, 70, 22))
	windows(lit, Vector3(cx, 0, -18.95), 20, 62, 6, 14)
	for i in 6:
		var r := 9.0 - i * 1.4
		var y := 66.0 + i * 4.0
		turned(steel, Vector3(cx, y, -30), [[r, 0], [r, 2.2], [r * 0.82, 4.0], [0, 4.0]], 4, false)
		turned(lit, Vector3(cx, y + 2.2, -30), [[r + 0.05, 0], [r * 0.85, 1.3], [0, 1.3]], 4, false)
	turned(steel, Vector3(cx, 90, -30), [[1.2, 0], [0, 18]], 8)
	# searchlit towers either side
	box(m(Color(0.22, 0.22, 0.28)), Vector3(-60, -4, -20), Vector3(20, 60, 20))
	windows(lit, Vector3(-60, 0, -9.95), 18, 54, 5, 12)
	box(m(Color(0.25, 0.24, 0.3)), Vector3(90, -4, -40), Vector3(24, 48, 20))
	windows(lit, Vector3(90, 0, -29.95), 22, 44, 6, 10)


func lm_havana() -> void:
	## El Capitolio's dome over the old town, El Morro and its lighthouse on the point
	var stone := m(Color(0.88, 0.84, 0.74))
	var dome_m := m(Color(0.82, 0.8, 0.74))
	box(stone, Vector3(10, -4, 0), Vector3(130, 20, 30))
	for i in 12:
		box(stone, Vector3(-14 + i * 4.4, 4, 16), Vector3(1.6, 14, 1.6))
	box(stone, Vector3(10, 16, 0), Vector3(36, 10, 22))
	drum(stone, Vector3(10, 22, 0), 13, 12, 24)
	for i in 16:
		var a := TAU * i / 16
		box(stone, Vector3(10 + cos(a) * 13.6, 22, sin(a) * 13.6), Vector3(1.2, 10, 1.2))
	turned(dome_m, Vector3(10, 34, 0), [[13, 0], [12, 8], [9, 16], [5, 22], [2.5, 24]], 24)
	drum(stone, Vector3(10, 58, 0), 2.5, 5, 12)
	turned(m(Color(1.0, 0.85, 0.5), 1.2), Vector3(10, 63, 0), [[2.6, 0], [0, 4]], 12)
	# El Morro on the point
	mountain(m(Color(0.55, 0.48, 0.4)), Vector3(-95, -4, -40), 70, 12, [[0.3, 1.0], [0.9, 0.9]])
	box(m(Color(0.72, 0.64, 0.5)), Vector3(-100, 8, -45), Vector3(30, 8, 20))
	drum(m(Color(0.9, 0.86, 0.78)), Vector3(-82, 8, -45), 2.6, 26, 12)
	drum(m(Color(1.0, 0.92, 0.7), 2.5), Vector3(-82, 34, -45), 2.2, 3, 12)


func lm_vienna() -> void:
	## St. Stephen's: the nave under its steep tiled roof and the tall south spire; the Riesenrad on the right
	var stone := m(Color(0.66, 0.6, 0.52))
	var tile := m(Color(0.62, 0.48, 0.3))
	box(stone, Vector3(0, -4, 0), Vector3(80, 28, 34))
	k.prism(tile, PackedVector2Array([Vector2(-41, 24), Vector2(41, 24), Vector2(0, 58)]), -17, 17)
	# zigzag stripes on the roof
	var tile2 := m(Color(0.2, 0.36, 0.3))
	for i in 6:
		var y := 28.0 + i * 5.0
		var w := 41.0 * (1.0 - (y - 24.0) / 34.0)
		k.quad(tile2, Vector3(-w, y, 17.05), Vector3(w, y, 17.05), Vector3(w * 0.9, y + 1.4, 17.05), Vector3(-w * 0.9, y + 1.4, 17.05))
	var sx := 46.0
	box(stone, Vector3(sx, -4, 6), Vector3(16, 50, 16))
	turned(stone, Vector3(sx, 46, 6), [[8, 0], [7, 12], [5, 20], [3.5, 34], [2, 46], [0.8, 58], [0, 66]], 8, false)
	turned(stone, Vector3(-44, 24, 6), [[6, 0], [4.5, 10], [0, 26]], 8, false)
	# the Riesenrad
	var wheel := m(Color(0.75, 0.25, 0.2))
	var old := k.at(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(100, 34, -40)))
	k.lathe(wheel, PackedVector2Array([Vector2(30, -0.6), Vector2(30.8, -0.6), Vector2(30.8, 0.6), Vector2(30, 0.6), Vector2(30, -0.6)]), Vector3.ZERO, 40, false)
	k.xform = old
	for i in 15:
		var a := TAU * i / 15
		var c := Vector3(100 + cos(a) * 15, 34 + sin(a) * 15, -40)
		var o := k.at(Transform3D(Basis(Vector3.BACK, a), c))
		k.box(wheel, Vector3.ZERO, Vector3(30, 0.4, 0.4))
		k.xform = o
		box(m(Color(0.85, 0.3, 0.25)), Vector3(100 + cos(a) * 31, 34 + sin(a) * 31 - 2.6, -40), Vector3(3, 2.6, 2))
	box(wheel, Vector3(92, -4, -40), Vector3(1.2, 38, 1.2))
	box(wheel, Vector3(108, -4, -40), Vector3(1.2, 38, 1.2))


func lm_cairoOld() -> void:
	## the pyramids of Giza in the haze, the Citadel's great dome and its two pencil minarets in front
	var sand := m(Color(0.86, 0.68, 0.46))
	for p in [[-40.0, -160.0, 140.0, 90.0], [50.0, -200.0, 130.0, 84.0], [110.0, -170.0, 70.0, 44.0]]:
		cone(sand, Vector3(p[0], -4, p[1]), p[2] * 0.72, p[3])
	var stone := m(Color(0.88, 0.82, 0.7))
	box(stone, Vector3(-20, -4, 0), Vector3(60, 22, 40))
	drum(stone, Vector3(-20, 18, 0), 12, 6, 24)
	dome(m(Color(0.6, 0.66, 0.66), 0.0, 0.4), Vector3(-20, 24, 0), 12, 13)
	turned(m(Color(1.0, 0.82, 0.5), 1.3), Vector3(-20, 37, 0), [[0.6, 0], [0, 6]], 6)
	for d: float in [-48.0, 8.0]:
		turned(stone, Vector3(d, -4, 16), [[2.0, 0], [1.6, 56], [2.4, 57], [2.4, 58], [1.3, 59], [1.1, 70], [0, 82]], 10, false)
	for i in 5:
		dome(stone, Vector3(-44 + i * 12, 18, 18), 4, 4, 12)


func lm_rome() -> void:
	## the Colosseum on the left, its broken outer ring stepping down; St Peter's dome and lantern on the right
	var trav := m(Color(0.82, 0.68, 0.5))
	var dark := m(Color(0.32, 0.24, 0.18))
	var cx := -40.0
	for i in 40:
		var a0 := TAU * i / 40
		var a1 := TAU * (i + 1) / 40
		var h := 44.0 if (i < 14 or i > 34) else 32.0 - (i % 3) * 3.0
		var p0 := Vector3(cx + cos(a0) * 52, -4, sin(a0) * 42 - 20)
		var p1 := Vector3(cx + cos(a1) * 52, -4, sin(a1) * 42 - 20)
		var n := (p0 + p1) / 2 - Vector3(cx, -4, -20)
		var old := k.at(Transform3D(Basis.looking_at(n.normalized()), (p0 + p1) / 2))
		var w := p0.distance_to(p1)
		k.box(trav, Vector3(0, h / 2, 0), Vector3(w, h, 4))
		for f in 4:
			if f * 11 + 9 < h:
				k.box(dark, Vector3(0, f * 11 + 5.5, -2.05), Vector3(w * 0.5, 6.5, 0.2))
		k.xform = old
	# St Peter's
	var stone := m(Color(0.9, 0.86, 0.78))
	var lead := m(Color(0.52, 0.58, 0.6), 0.0, 0.3)
	box(stone, Vector3(60, -4, -30), Vector3(70, 30, 40))
	drum(stone, Vector3(60, 26, -30), 16, 14, 24)
	turned(lead, Vector3(60, 40, -30), [[16.5, 0], [16, 6], [13, 14], [8, 21], [3.2, 25]], 24)
	drum(stone, Vector3(60, 65, -30), 3.2, 6, 12)
	turned(lead, Vector3(60, 71, -30), [[3.4, 0], [0, 6]], 12)
	# umbrella pines
	var pine := m(Color(0.18, 0.26, 0.16))
	for x: float in [-95.0, 10.0, 25.0, 100.0]:
		box(m(Color(0.3, 0.22, 0.16)), Vector3(x, -4, 20), Vector3(1.2, 16, 1.2))
		k.sphere(pine, Vector3(x, 14, 20), Vector3(9, 3.5, 9), 12, 6)


# --- the Present --------------------------------------------------------------------------------------------------

func lm_dubai() -> void:
	## the Burj Khalifa in tiers with a beacon on top; the Burj Al Arab's sail far to the left
	var glass := m(Color(0.7, 0.76, 0.84), 0.0, 0.7)
	var lit := m(Color(1.0, 0.86, 0.62), 1.2)
	var z := -40.0
	# three wings around a hexagonal core, stepping back as they rise
	var h := 0.0
	for tier in 9:
		var r := 15.0 - tier * 1.5
		var th := 14.0 - tier * 0.6
		turned(glass, Vector3(0, -4 + h, z), [[r, 0], [r, th], [r * 0.92, th]], 6, false)
		turned(lit, Vector3(0, -4 + h + th * 0.5, z), [[r + 0.05, 0], [r + 0.05, 0.4], [0, 0.4]], 6, false)
		h += th
	turned(glass, Vector3(0, -4 + h, z), [[1.8, 0], [0.9, 18], [0.2, 30], [0, 32]], 8)
	# the sail
	var white := m(Color(0.96, 0.95, 0.93))
	k.prism(white, PackedVector2Array([Vector2(-108, -4), Vector2(-86, -4), Vector2(-86, 54), Vector2(-90, 62), Vector2(-104, 34)]), -82, -70)
	box(white, Vector3(-88, -4, -76), Vector3(2, 66, 2))


func lm_rio() -> void:
	## Corcovado with the Christ statue (left), Sugarloaf and its cable car (right)
	var rock := m(Color(0.3, 0.36, 0.3))
	mountain(rock, Vector3(-70, -4, -60), 130, 70, [[0.15, 0.3], [0.35, 0.75], [0.5, 1.0], [0.62, 0.9], [0.8, 0.35]])
	var white := m(Color(0.96, 0.95, 0.9))
	box(white, Vector3(-70, 66, -80), Vector3(2.2, 10, 2.2))
	box(white, Vector3(-70, 74, -80), Vector3(13, 1.6, 1.8))
	k.sphere(white, Vector3(-70, 77.6, -80), Vector3(1, 1.3, 1), 8, 6)
	turned(rock, Vector3(70, -4, -50), [[30, 0], [26, 20], [18, 46], [10, 62], [0, 68]], 18)
	turned(rock, Vector3(30, -4, -40), [[20, 0], [14, 20], [0, 34]], 14)
	var cable := m(Color(0.1, 0.1, 0.1))
	var o := k.at(Transform3D(Basis(Vector3.BACK, atan2(34.0, 40.0)), Vector3(50, 47, -45)))
	k.box(cable, Vector3.ZERO, Vector3(52, 0.15, 0.15))
	k.xform = o
	box(m(Color(1.0, 0.85, 0.4), 1.2), Vector3(46, 40, -45), Vector3(2, 1.6, 1.6))


func lm_singapore() -> void:
	## Marina Bay Sands: three towers and the ship-shaped park across their tops; Supertrees glowing to the left
	var tower := m(Color(0.78, 0.8, 0.84), 0.0, 0.5)
	var lit := m(Color(1.0, 0.86, 0.6), 1.1)
	for i in 3:
		var x := -26.0 + i * 26.0
		var old := k.at(Transform3D(Basis.IDENTITY, Vector3(x, -4, 0)))
		k.prism(tower, PackedVector2Array([Vector2(-7, 0), Vector2(7, 0), Vector2(5, 70), Vector2(-5, 70)]), -6, 6)
		windows(lit, Vector3(0, 2, 6.05), 10, 64, 4, 18)
		k.xform = old
	box(tower, Vector3(4, 66, 0), Vector3(96, 3, 14))
	box(m(Color(0.3, 0.45, 0.3)), Vector3(0, 69, 0), Vector3(80, 1, 12))
	# Supertrees
	for p in [[-80.0, 30.0], [-64.0, 22.0], [-96.0, 18.0], [-72.0, 40.0]]:
		turned(m(Color(0.3, 0.2, 0.4)), Vector3(p[0], -4, -10), [[1.5, 0], [1.0, p[1] * 0.7], [7, p[1]], [0, p[1]]], 10)
		turned(m(Color(1.0, 0.4, 0.8), 1.6), Vector3(p[0], p[1] - 4.2, -10), [[7.1, 0], [7.1, 0.5], [0, 0.5]], 10)


func lm_sf() -> void:
	## the Golden Gate in international orange, the Transamerica Pyramid on the right
	var orange := m(Color(0.75, 0.25, 0.14))
	var z := -40.0
	for tx: float in [-60.0, 40.0]:
		for sx: int in [-1, 1]:
			box(orange, Vector3(tx + sx * 5, -4, z), Vector3(3, 84, 3))
		for y: float in [30.0, 54.0, 72.0, 80.0]:
			box(orange, Vector3(tx, y, z), Vector3(13, 2.4, 2.6))
	box(orange, Vector3(-10, 22, z), Vector3(220, 2.6, 4))
	# the main cables sag between the towers and run down to the shores
	for seg in 24:
		var x0 := -60.0 + seg * 100.0 / 24
		var x1 := x0 + 100.0 / 24
		var y0 := 80.0 - 52.0 * (1.0 - pow((x0 + 10) / 50.0, 2.0))
		var y1 := 80.0 - 52.0 * (1.0 - pow((x1 + 10) / 50.0, 2.0))
		var o := k.at(Transform3D(Basis(Vector3.BACK, atan2(y1 - y0, x1 - x0)), Vector3((x0 + x1) / 2, (y0 + y1) / 2, z)))
		k.box(orange, Vector3.ZERO, Vector3(Vector2(x1 - x0, y1 - y0).length() + 0.2, 0.7, 0.7))
		k.xform = o
		if seg % 2 == 0:
			box(orange, Vector3(x0, 24, z), Vector3(0.25, y0 - 24, 0.25))
	# the fog bank under it and the hills behind
	mountain(m(Color(0.22, 0.22, 0.34)), Vector3(-10, -4, -120), 300, 34, [[0.1, 0.6], [0.3, 1.0], [0.55, 0.7], [0.8, 0.9]])
	# Transamerica
	cone(m(Color(0.82, 0.82, 0.85)), Vector3(90, -4, -20), 12, 90)
	windows(m(Color(1.0, 0.85, 0.6), 1.3), Vector3(90, 0, -8), 14, 50, 4, 14)


func lm_sydney() -> void:
	## the Harbour Bridge's arch (left) and the Opera House sails (right of centre)
	var steel := m(Color(0.45, 0.47, 0.52))
	var lit := m(Color(1.0, 0.85, 0.6), 1.4)
	for seg in 30:
		var t0 := float(seg) / 30
		var t1 := float(seg + 1) / 30
		var x0 := -130.0 + t0 * 110
		var x1 := -130.0 + t1 * 110
		var y0 := 8.0 + 46.0 * sin(t0 * PI)
		var y1 := 8.0 + 46.0 * sin(t1 * PI)
		var o := k.at(Transform3D(Basis(Vector3.BACK, atan2(y1 - y0, x1 - x0)), Vector3((x0 + x1) / 2, (y0 + y1) / 2, -40)))
		k.box(steel, Vector3.ZERO, Vector3(Vector2(x1 - x0, y1 - y0).length() + 0.3, 3.2, 3))
		k.box(lit, Vector3(0, 1.7, 1.6), Vector3(Vector2(x1 - x0, y1 - y0).length() * 0.4, 0.4, 0.2))
		k.xform = o
		if seg % 3 == 0 and y0 > 22:
			box(steel, Vector3(x0, 22, -40), Vector3(0.6, y0 - 22, 0.6))
	box(steel, Vector3(-75, 20, -40), Vector3(150, 2, 6))
	for px: float in [-134.0, -16.0]:
		box(m(Color(0.7, 0.62, 0.5)), Vector3(px, -4, -40), Vector3(10, 34, 10))
	# the sails: shells that rise and lean, two rows
	var white := m(Color(0.97, 0.95, 0.9))
	box(m(Color(0.62, 0.5, 0.42)), Vector3(40, -4, 0), Vector3(80, 8, 30))
	for row in 2:
		for i in 4:
			var h := 26.0 - i * 4.0 - row * 6.0
			var x := 14.0 + i * 13.0
			var z := -6.0 + row * 12.0
			var o := k.at(Transform3D(Basis(Vector3.BACK, -0.35), Vector3(x, 4, z)))
			k.prism(white, PackedVector2Array([Vector2(-8, 0), Vector2(8, 0), Vector2(2, h), Vector2(-6, h * 0.7)]), -5, 5)
			k.xform = o


func lm_capetown() -> void:
	## Table Mountain's long flat top with its tablecloth of cloud, Devil's Peak left, Lion's Head right
	var rock := m(Color(0.38, 0.36, 0.4))
	mountain(rock, Vector3(0, -4, -120), 300, 90, [[0.08, 0.5], [0.16, 0.95], [0.2, 1.0], [0.8, 1.0], [0.88, 0.7], [0.95, 0.3]], 80)
	mountain(rock, Vector3(-150, -4, -110), 90, 80, [[0.45, 1.0], [0.7, 0.6]])
	mountain(rock, Vector3(150, -4, -80), 70, 60, [[0.4, 0.9], [0.55, 1.0], [0.8, 0.5]])
	var cloud := m(Color(0.98, 0.96, 0.95))
	for i in 12:
		k.sphere(cloud, Vector3(-110 + i * 20, 84, -120), Vector3(14, 4, 10), 10, 5)
	# harbour cranes
	var crane := m(Color(0.75, 0.3, 0.2))
	for x: float in [40.0, 70.0]:
		box(crane, Vector3(x, -4, 0), Vector3(1.6, 26, 1.6))
		box(crane, Vector3(x + 6, 20, 0), Vector3(22, 1.6, 1.6))


func lm_barcelona() -> void:
	## the Sagrada Família's cluster of spires, Torre Glòries lit in colour, Montjuïc behind
	mountain(m(Color(0.32, 0.34, 0.36)), Vector3(-40, -4, -140), 240, 40, [[0.3, 0.8], [0.5, 1.0], [0.7, 0.8]])
	var stone := m(Color(0.72, 0.62, 0.5))
	box(stone, Vector3(-10, -4, 0), Vector3(60, 34, 30))
	for i in 4:
		for side: int in [-1, 1]:
			var x := -10.0 + side * (8 + i * 6.5)
			var h := 74.0 - absf(i - 1.5) * 8.0
			turned(stone, Vector3(x, -4, 15), [[3.6, 0], [3.0, h * 0.6], [2.2, h * 0.85], [0.6, h], [0, h + 4]], 10)
			k.sphere(m(Color(0.9, 0.8, 0.5)), Vector3(x, h + 0.6, 15), Vector3(1.4, 1.4, 1.4), 8, 6)
	turned(stone, Vector3(-10, -4, -6), [[7, 0], [6, 60], [3, 96], [0, 110]], 12)
	k.sphere(m(Color(1.0, 0.9, 0.7), 1.2), Vector3(-10, 110, -6), Vector3(2.4, 2.4, 2.4), 10, 6)
	# Torre Glòries
	turned(m(Color(0.25, 0.4, 0.8), 1.2), Vector3(70, -4, -20), [[11, 0], [11, 70], [9, 84], [5, 92], [0, 95]], 20)


func lm_reykjavik() -> void:
	## Esja's snowy ridge, and Hallgrímskirkja's stepped concrete tower; the aurora is in the sky
	mountain(m(Color(0.25, 0.28, 0.34)), Vector3(0, -4, -200), 400, 60, [[0.1, 0.5], [0.25, 0.85], [0.4, 1.0], [0.55, 0.9], [0.75, 0.95], [0.9, 0.6]], 80)
	k.prism(m(Color(0.86, 0.9, 0.96)), PackedVector2Array([Vector2(-60, 46), Vector2(-40, 56), Vector2(-20, 52), Vector2(20, 54), Vector2(60, 50), Vector2(80, 45), Vector2(60, 48), Vector2(10, 50), Vector2(-30, 50)]), -205, -199)
	var concrete := m(Color(0.86, 0.86, 0.84))
	# the basalt-column wings step down either side of the tower
	for i in 7:
		for side: int in [-1, 1]:
			box(concrete, Vector3(side * (i * 4.0 + 6), -4, 0), Vector3(4, 70 - i * 9.0, 8))
	box(concrete, Vector3(0, -4, 0), Vector3(10, 74, 10))
	cone(concrete, Vector3(0, 70, 0), 6.5, 12)
	box(m(Color(1.0, 0.86, 0.6), 1.2), Vector3(0, 40, 5.05), Vector3(4, 14, 0.1))
	box(concrete, Vector3(0, -4, -24), Vector3(20, 16, 40))


# --- the Future ---------------------------------------------------------------------------------------------------

func neon(col, energy := 2.4) -> String:
	return m(col, energy)


func lm_hongkong() -> void:
	## the Bank of China tower with its crossed bracing, and IFC with its stepped crown
	var glass := m(Color(0.16, 0.2, 0.28), 0.0, 0.6)
	var a := neon(Color("2ef2ff"))
	var x := -20.0
	var old := k.at(Transform3D(Basis.IDENTITY, Vector3(x, -4, 0)))
	k.prism(glass, PackedVector2Array([Vector2(-14, 0), Vector2(14, 0), Vector2(14, 70), Vector2(0, 108), Vector2(-14, 82)]), -14, 14)
	for y: float in [0.0, 28.0, 56.0]:
		k.quad(a, Vector3(-14, y, 14.05), Vector3(-12.6, y, 14.05), Vector3(14, y + 27, 14.05), Vector3(12.6, y + 27, 14.05))
		k.quad(a, Vector3(12.6, y, 14.05), Vector3(14, y, 14.05), Vector3(-12.6, y + 27, 14.05), Vector3(-14, y + 27, 14.05))
	k.xform = old
	k.box(glass, Vector3(x - 3, 102, 0), Vector3(0.6, 24, 0.6))
	# IFC
	var ix := 50.0
	box(glass, Vector3(ix, -4, -40), Vector3(22, 92, 22))
	for i in 4:
		box(glass, Vector3(ix, 88 + i * 4, -40), Vector3(18 - i * 3.5, 4, 18 - i * 3.5))
	for y in 10:
		box(neon(Color("ff3fb4"), 1.4), Vector3(ix, 4 + y * 9, -28.9), Vector3(20, 0.3, 0.1))
	box(glass, Vector3(-75, -4, -30), Vector3(20, 66, 20))
	box(neon(Color("ff3fb4"), 1.8), Vector3(-75, 62, -19.9), Vector3(18, 1, 0.1))


func lm_tokyo() -> void:
	## Mount Fuji behind the city, Tokyo Tower lit orange, a pagoda
	turned(m(Color(0.16, 0.2, 0.28)), Vector3(-20, -4, -260), [[200, 0], [120, 40], [40, 100], [26, 108], [0, 110]], 28)
	turned(m(Color(0.86, 0.9, 0.96)), Vector3(-20, 81, -260), [[41, 0], [26, 14], [0, 16]], 28)
	var orange := neon(Color("ff8a3c"), 1.8)
	var white := neon(Color("ffffff"), 1.4)
	var x := 30.0
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			turned(orange, Vector3(x + sx * 9, -4, sz * 9), [[1.3, 0], [0.9, 40]], 6)
	turned(orange, Vector3(x, 30, 0), [[8, 0], [5, 30], [3, 50], [1.4, 72], [0.4, 84], [0, 90]], 4, false)
	for y: float in [32.0, 64.0]:
		box(white, Vector3(x, y, 0), Vector3(12 - y * 0.12, 3, 12 - y * 0.12))
	# a pagoda
	var wood := m(Color(0.4, 0.12, 0.1))
	for i in 5:
		var w := 16.0 - i * 2.2
		box(wood, Vector3(-60, -4 + i * 8, -10), Vector3(w * 0.6, 6, w * 0.6))
		turned(m(Color(0.15, 0.15, 0.18)), Vector3(-60, 2 + i * 8, -10), [[w * 0.8, 0], [w * 0.3, 2.4], [0, 2.4]], 4, false)
	turned(m(Color(0.7, 0.55, 0.3)), Vector3(-60, 40, -10), [[0.4, 0], [0, 10]], 6)


func lm_losangeles() -> void:
	## the arcology: a stepped pyramid with rows of lights, flame stacks either side
	var dark := m(Color(0.08, 0.06, 0.08))
	var lit := neon(Color("ffb070"), 1.4)
	for i in 10:
		var w := 150.0 - i * 14.0
		box(dark, Vector3(0, -4 + i * 9, -60), Vector3(w, 9, w * 0.7))
		box(lit, Vector3(0, -4 + i * 9 + 4, -60 + w * 0.35 + 0.05), Vector3(w * 0.96, 0.6, 0.1))
	for sx: int in [-1, 1]:
		box(dark, Vector3(sx * 95, -4, -30), Vector3(5, 50, 5))
	# palms on the hills
	mountain(m(Color(0.1, 0.06, 0.08)), Vector3(0, -4, -20), 260, 14, [[0.2, 0.8], [0.5, 0.4], [0.8, 1.0]], 20)


func lm_shanghai() -> void:
	## the Oriental Pearl Tower, the twisting Shanghai Tower, Jin Mao's pagoda tiers
	var steel := m(Color(0.6, 0.62, 0.68), 0.0, 0.6)
	var pink := neon(Color("ff3fb4"), 1.6)
	var x := -30.0
	for i in 3:
		var a := TAU * i / 3
		var o := k.at(Transform3D(Basis(Vector3(cos(a), 0, sin(a)).cross(Vector3.UP).normalized(), 0.15), Vector3(x + cos(a) * 6, -4, sin(a) * 6)))
		k.lathe(steel, PackedVector2Array([Vector2(1.6, 0), Vector2(1.6, 30), Vector2(0, 30)]), Vector3.ZERO, 8)
		k.xform = o
	turned(steel, Vector3(x, -4, 0), [[2.2, 0], [2.2, 100], [0.6, 104], [0, 118]], 10)
	k.sphere(pink, Vector3(x, 28, 0), Vector3(11, 11, 11), 20, 12)
	k.sphere(pink, Vector3(x, 74, 0), Vector3(7, 7, 7), 16, 10)
	k.sphere(pink, Vector3(x, 98, 0), Vector3(2.6, 2.6, 2.6), 10, 6)
	# Shanghai Tower: a twisting, tapering triangle
	var glass := m(Color(0.28, 0.36, 0.42), 0.0, 0.6)
	for i in 14:
		var r0 := 15.0 - i * 0.75
		var o := k.at(Transform3D(Basis(Vector3.UP, i * 0.09), Vector3(45, -4 + i * 8.4, -60)))
		k.lathe(glass, PackedVector2Array([Vector2(r0, 0), Vector2(r0 - 0.75, 8.4)]), Vector3.ZERO, 3, false)
		k.xform = o
		box(neon(Color("39ff8a"), 1.4), Vector3(45, -4 + i * 8.4, -60 + r0 * 0.5), Vector3(r0 * 0.8, 0.3, 0.1))
	# Jin Mao
	for i in 9:
		var w := 22.0 - i * 2.0
		box(m(Color(0.42, 0.44, 0.5)), Vector3(80, -4 + i * 10, -30), Vector3(w, 10, w))
		box(neon(Color("ffd45c"), 1.2), Vector3(80, -4 + i * 10 + 9.5, -30), Vector3(w + 0.4, 0.4, w + 0.4))
	turned(steel, Vector3(80, 86, -30), [[2, 0], [0, 16]], 8)


func lm_seoul() -> void:
	## Namsan hill and N Seoul Tower against the moon, palace roofs along the horizon
	var hill := m(Color(0.08, 0.1, 0.14))
	turned(hill, Vector3(0, -4, -40), [[90, 0], [60, 18], [28, 36], [0, 42]], 24)
	var white := m(Color(0.86, 0.88, 0.92))
	turned(white, Vector3(0, 38, -40), [[3.4, 0], [2.6, 46], [7, 48], [7, 56], [3, 58], [1.6, 62], [0.6, 74], [0, 80]], 16)
	turned(neon(Color("5aa0ff"), 1.8), Vector3(0, 86, -40), [[7.1, 0], [7.1, 1.2], [0, 1.2]], 16)
	# palace roofs
	var roof := m(Color(0.12, 0.14, 0.16))
	for x: float in [-90.0, -60.0, 60.0, 90.0]:
		box(m(Color(0.4, 0.14, 0.12)), Vector3(x, -4, 10), Vector3(20, 6, 10))
		k.prism(roof, PackedVector2Array([Vector2(x - 14, 2), Vector2(x + 14, 2), Vector2(x + 9, 7), Vector2(x - 9, 7)]), 4, 16)


func lm_berlin() -> void:
	## the TV tower at the end of the street, the Brandenburg Gate below it
	var concrete := m(Color(0.7, 0.7, 0.72))
	var steel := m(Color(0.62, 0.64, 0.7), 0.0, 0.8)
	turned(concrete, Vector3(0, -4, -80), [[6, 0], [3.4, 14], [2.6, 80], [0, 80]], 16)
	k.sphere(steel, Vector3(0, 86, -80), Vector3(13, 13, 13), 24, 14)
	turned(neon(Color("ff2448"), 1.8), Vector3(0, 86, -80), [[13.1, -0.6], [13.1, 0.6], [0, 0.6]], 24)
	turned(concrete, Vector3(0, 99, -80), [[1.6, 0], [1.2, 18], [0.4, 32], [0, 36]], 10)
	# the Gate
	var stone := m(Color(0.75, 0.7, 0.6))
	for i in 6:
		box(stone, Vector3(-17.5 + i * 7, -4, 0), Vector3(2.4, 20, 8))
	box(stone, Vector3(0, 16, 0), Vector3(44, 5, 10))
	box(stone, Vector3(0, 21, 0), Vector3(16, 3, 6))
	box(neon(Color("ffffff"), 1.2), Vector3(0, 13, 4.1), Vector3(40, 0.3, 0.1))


func lm_miami() -> void:
	## Ocean Drive's Art Deco hotels outlined in neon
	var cols := [Color("ff3d8b"), Color("38e8ff"), Color("ffd45c"), Color("b062ff")]
	var pastel := [Color(0.95, 0.75, 0.82), Color(0.72, 0.9, 0.88), Color(0.98, 0.92, 0.72), Color(0.82, 0.78, 0.95)]
	for i in 6:
		var x := -100.0 + i * 40.0
		var h := 24.0 + float((i * 7) % 4) * 6.0
		box(m(pastel[i % 4]), Vector3(x, -4, -10), Vector3(30, h, 16))
		box(m(pastel[(i + 1) % 4]), Vector3(x, -4 + h, -10), Vector3(8, 10, 8))
		var n := neon(cols[i % 4], 2.0)
		box(n, Vector3(x, -4 + h - 0.4, -1.9), Vector3(30.4, 0.5, 0.1))
		box(n, Vector3(x - 15, -4, -1.9), Vector3(0.5, h, 0.1))
		box(n, Vector3(x + 15, -4, -1.9), Vector3(0.5, h, 0.1))
		box(n, Vector3(x, -4 + h, -5.9), Vector3(0.5, 10, 0.1))


func lm_vegas() -> void:
	## the strip in neon: a black glass pyramid, a needle tower with its pod, castle turrets, marquees
	var black := m(Color(0.04, 0.04, 0.06), 0.0, 0.9)
	cone(black, Vector3(-30, -4, -40), 50, 70)
	turned(neon(Color("fff4c0"), 3.0), Vector3(-30, 66, -40), [[0.3, 0], [0.3, 200], [0, 200]], 6)
	var n := neon(Color("ff3fb4"), 1.8)
	turned(m(Color(0.7, 0.7, 0.74)), Vector3(60, -4, -20), [[5, 0], [3, 60], [3, 86], [0, 86]], 12)
	turned(n, Vector3(60, 78, -20), [[3, 0], [10, 3], [10, 7], [3, 10], [0, 10]], 16)
	turned(m(Color(0.7, 0.7, 0.74)), Vector3(60, 88, -20), [[0.8, 0], [0, 20]], 6)
	for t in 5:
		var x := 100.0 + (t % 3) * 10.0
		drum(m(Color(0.9, 0.86, 0.8)), Vector3(x, -4, 0 - t * 6), 3.4, 26 + t * 3, 10)
		cone(neon(Color(["ff3f3f", "3f7fff", "ffd45c"][t % 3]), 1.6), Vector3(x, 22 + t * 3, -t * 6), 4.2, 9, 10, 0)
	box(neon(Color("ffd45c"), 2.0), Vector3(-90, -4, 0), Vector3(26, 12, 2))


# --- set pieces -------------------------------------------------------------------------------------------------

func deco() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/deco"))
	var script := load("res://scripts/deco.gd")
	# Singapore's Flyer over the rooftops, left of the street
	fog = Color.WHITE
	haze = 0.0
	k = MeshKit.new()
	_mats = {}
	var white := m(Color(0.95, 0.92, 0.96), 0.4)
	var o := k.at(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO))
	k.lathe(white, PackedVector2Array([Vector2(40, -0.5), Vector2(41, -0.5), Vector2(41, 0.5), Vector2(40, 0.5), Vector2(40, -0.5)]), Vector3.ZERO, 48, false)
	k.xform = o
	for i in 16:
		var a := TAU * i / 16
		var oo := k.at(Transform3D(Basis(Vector3.BACK, a), Vector3.ZERO))
		k.box(white, Vector3(20, 0, 0), Vector3(40, 0.35, 0.35))
		k.box(m(Color("ffd45c") if i % 2 else Color("ff7ab8"), 2.0), Vector3(41.5, 0, 0), Vector3(2.6, 2.6, 2.6))
		k.xform = oo
	var root := Node3D.new()
	root.name = "Ferris"
	root.set_script(script)
	root.kind = "ferris"
	root.position = Vector3(-30, 50, -160)
	var wheel := MeshInstance3D.new()
	wheel.name = "Wheel"
	wheel.mesh = k.bake()
	root.add_child(wheel)
	var k2 := MeshKit.new()
	k = k2
	_mats = {}
	white = m(Color(0.9, 0.88, 0.92))
	for sx: int in [-1, 1]:
		var oo := k.at(Transform3D(Basis(Vector3.BACK, sx * 0.4), Vector3(sx * 11, -27, 0)))
		k.box(white, Vector3.ZERO, Vector3(1.6, 58, 1.6))
		k.xform = oo
	var stand := MeshInstance3D.new()
	stand.name = "Stand"
	stand.mesh = k.bake()
	root.add_child(stand)
	Kit.save(root, "res://scenes/deco/ferris.tscn")
	# fireworks over the harbour, two beats apart
	root = Node3D.new()
	root.name = "Fireworks"
	root.set_script(script)
	root.kind = "fireworks"
	root.position = Vector3(0, 0, -150)
	for i in 4:
		var p := GPUParticles3D.new()
		p.name = "Burst%d" % i
		p.amount = 90
		p.lifetime = 2.2
		p.one_shot = true
		p.explosiveness = 1.0
		p.emitting = false
		p.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3.UP
		pm.spread = 180.0
		pm.initial_velocity_min = 12.0
		pm.initial_velocity_max = 16.0
		pm.gravity = Vector3(0, -4, 0)
		pm.damping_min = 4.0
		pm.damping_max = 6.0
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 1))
		fade.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture1D.new()
		gt.gradient = fade
		pm.color_ramp = gt
		p.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(1.2, 1.2)
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		sm.vertex_color_use_as_albedo = true
		sm.disable_fog = true
		var dot := GradientTexture2D.new()
		dot.fill = GradientTexture2D.FILL_RADIAL
		dot.fill_from = Vector2(0.5, 0.5)
		dot.fill_to = Vector2(0.5, 0.0)
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		dot.gradient = g
		sm.albedo_texture = dot
		q.material = sm
		p.draw_pass_1 = q
		root.add_child(p)
	Kit.save(root, "res://scenes/deco/fireworks.tscn")
	# searchlights sweeping the sky
	root = Node3D.new()
	root.name = "Searchlights"
	root.set_script(script)
	root.kind = "searchlights"
	for i in 3:
		var beam := MeshInstance3D.new()
		beam.name = "Beam%d" % i
		var cm := CylinderMesh.new()
		cm.top_radius = 0.6
		cm.bottom_radius = 14.0
		cm.height = 300.0
		cm.cap_top = false
		cm.cap_bottom = false
		var bm := StandardMaterial3D.new()
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		bm.cull_mode = BaseMaterial3D.CULL_DISABLED
		bm.albedo_color = Color(0.9, 0.92, 1.0, 0.06)
		bm.disable_fog = true
		cm.material = bm
		beam.mesh = cm
		beam.position = Vector3((i - 1) * 36, -8, -260)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(beam)
	Kit.save(root, "res://scenes/deco/searchlights.tscn")
	# lightning every few bars, with a flash across the sky
	root = Node3D.new()
	root.name = "Lightning"
	root.set_script(script)
	root.kind = "lightning"
	var bolt := MeshInstance3D.new()
	bolt.name = "Bolt"
	bolt.position = Vector3(0, 0, -240)
	bolt.visible = false
	root.add_child(bolt)
	var flash := OmniLight3D.new()
	flash.name = "Flash"
	flash.position = Vector3(0, 80, -120)
	flash.light_color = Color(0.85, 1.0, 0.95)
	flash.omni_range = 400.0
	flash.light_energy = 0.0
	root.add_child(flash)
	Kit.save(root, "res://scenes/deco/lightning.tscn")
	# police drones crossing overhead, red and blue lights
	root = Node3D.new()
	root.name = "Police"
	root.set_script(script)
	root.kind = "police"
	for i in 3:
		var dr := Node3D.new()
		dr.name = "Drone%d" % i
		root.add_child(dr)
		Kit.instance(dr, "res://scenes/traffic/drone.tscn", "Body")
		for c: Color in [Color(1, 0.12, 0.18), Color(0.16, 0.42, 1)]:
			var l := OmniLight3D.new()
			l.name = "Red" if c.r > 0.5 else "Blue"
			l.light_color = c
			l.light_energy = 3.0
			l.omni_range = 5.0
			l.position = Vector3(-0.6 if c.r > 0.5 else 0.6, 0.3, 0)
			dr.add_child(l)
	Kit.save(root, "res://scenes/deco/police.tscn")
