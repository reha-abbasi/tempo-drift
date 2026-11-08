extends RefCounted
class_name GfxWorldBack
## The view behind the car, seen when the garage camera turns round it: each dressed city's other landmark, a
## different one from the one ahead, with the roofs or hills around it. Built like the view ahead (GfxWorld) and
## baked with it (scenes/gfx_world/<city>/horizon_back.scn). Behind the car is +z.
##   London 1890   the Monument to the Great Fire straight down the street, its gilded urn of flames over the
##                 roofs; further back the Tower of London's White Tower, and Tower Bridge being built (1886–1894):
##                 its two towers half clad in stone, the steel frames above them, a steam crane on each
##   Rio           Dois Irmãos and Pedra da Gávea closing the beach, Vidigal's lights at their foot; the promenade,
##                 the beach and the sea go on behind the car
##   Berlin 2075   the Victory Column (Siegessäule) straight down the street, its gilded Victoria lit over the
##                 neon, with the floodlit Brandenburg Gate and its quadriga in front, the Reichstag's dome aside

const SH := "res://materials/gfx_world/"


static func build(key: String, city_builder: RefCounted) -> Node3D:
	match key:
		"old_0":
			return london()
		"sunset_1":
			return rio(city_builder)
		"rain_5":
			return berlin()
	return null


# ------------------------------------------------------------------ London 1890

static func london() -> Node3D:
	var n := Node3D.new()
	n.name = "GfxWorldBack"
	var k := MeshKit.new()
	GfxWorld.paint(k, "roofs_near", Color("4a4440"), 0.9)
	GfxWorld.paint(k, "roofs_far", Color("5c5854"), 0.9)
	GfxWorld.paint(k, "caen", Color("c9bfa8"), 0.85)
	GfxWorld.paint(k, "granite", Color("8c8a86"), 0.85)
	GfxWorld.paint(k, "lead", Color("5e6468"), 0.5, 0.6)
	GfxWorld.paint(k, "gold", Color("d8b060"), 0.3, 1.0)
	GfxWorld.paint(k, "iron", Color("2a2c30"), 0.5, 0.8)
	GfxWorld.paint(k, "timber", Color("6a5038"), 0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1894
	# two rows of roofs and chimneys, as ahead
	for row in 2:
		var z := 215.0 + row * 45.0
		var m := "roofs_near" if row == 0 else "roofs_far"
		var x := -160.0
		while x < 160.0:
			var w := rng.randf_range(8.0, 16.0)
			var ht := rng.randf_range(13.0, 21.0) + row * 3.0
			k.box(m, Vector3(x + w / 2, ht / 2 - 2.0, z), Vector3(w, ht, 10.0))
			k.prism(m, PackedVector2Array([Vector2(x, ht - 2.0), Vector2(x + w, ht - 2.0), Vector2(x + w / 2, ht + 2.5)]), z - 5.0, z + 5.0, false)
			for c in rng.randi_range(1, 3):
				k.box(m, Vector3(x + rng.randf_range(1.0, w - 1.0), ht + 2.0, z + rng.randf_range(-3.0, 3.0)), Vector3(1.4, 4.0 + rng.randf() * 2.0, 0.9))
			x += w
	# the Monument (1677), straight down the street between the two rows of roofs: the pedestal, the fluted Doric
	# column of Portland stone, the gallery with its iron cage, the drum and the gilded urn of flames
	GfxWorld.paint(k, "portland", Color("ddd4c0"), 0.8, 0.0, 0.15)
	var mo := Vector3(0.0, -2.0, 238.0)
	k.box("portland", mo + Vector3(0, 6.5, 0), Vector3(8.6, 13, 8.6))
	k.box("portland", mo + Vector3(0, 13.4, 0), Vector3(9.4, 0.8, 9.4))
	k.box("portland", mo + Vector3(0, 0.6, 0), Vector3(10.4, 1.2, 10.4))
	k.lathe("portland", PackedVector2Array([Vector2(2.6, 13.8), Vector2(2.45, 30), Vector2(2.25, 46), Vector2(2.15, 51.5)]), mo, 20)
	for f in 20:
		var a := TAU * f / 20.0
		k.box("caen", mo + Vector3(cos(a) * 2.42, 32.5, sin(a) * 2.42), Vector3(0.18, 37.0, 0.18))
	k.box("portland", mo + Vector3(0, 52.2, 0), Vector3(6.0, 1.4, 6.0))
	for e in 12:
		var a := TAU * e / 12.0
		k.box("iron", mo + Vector3(cos(a) * 2.9, 54.0, sin(a) * 2.9), Vector3(0.08, 2.4, 0.08))
	k.cylinder("portland", mo + Vector3(0, 55.2, 0), 1.25, 4.6, 14)
	k.lathe("gold", PackedVector2Array([Vector2(0.9, 57.5), Vector2(1.3, 58.4), Vector2(1.1, 59.2), Vector2(0.6, 59.6)]), mo, 12)
	for fl in 7:
		var a := TAU * fl / 7.0
		var root := mo + Vector3(cos(a) * 0.5, 59.4, sin(a) * 0.5)
		k.tri("gold", root + Vector3(-0.35, 0, 0), root + Vector3(0.35, 0, 0), root + Vector3(cos(a) * 0.4, 2.3 + 0.6 * (fl % 2), sin(a) * 0.4))
		k.tri("gold", root + Vector3(0.35, 0, 0), root + Vector3(-0.35, 0, 0), root + Vector3(cos(a) * 0.4, 2.3 + 0.6 * (fl % 2), sin(a) * 0.4))
	# the White Tower (off to the side): the Norman keep, its battlements, four corner turrets with their lead cupolas and vanes
	var wt := Vector3(92.0, -2.0, 330.0)
	k.box("caen", wt + Vector3(0, 15, 0), Vector3(36, 30, 32))
	for i in 9:
		for side in [-1, 1]:
			k.box("caen", wt + Vector3(-16 + i * 4.0, 31, side * 15.6), Vector3(2.0, 2.0, 0.8))
			k.box("caen", wt + Vector3(side * 17.6, 31, -14 + i * 3.5), Vector3(0.8, 2.0, 2.0))
	for cx in [-1, 1]:
		for cz in [-1, 1]:
			var t := wt + Vector3(cx * 17.0, 0, cz * 15.0)
			if cx > 0 and cz < 0:
				k.cylinder("caen", t + Vector3(0, 18, 0), 4.2, 36.0, 14)
			else:
				k.box("caen", t + Vector3(0, 18, 0), Vector3(7, 36, 7))
			k.lathe("lead", PackedVector2Array([Vector2(3.6, 36), Vector2(4.0, 38), Vector2(3.0, 40.5), Vector2(1.2, 42.5), Vector2(0.2, 44)]), t, 12)
			k.box("gold", t + Vector3(0, 45.5, 0), Vector3(0.25, 3.0, 0.25))
			k.box("gold", t + Vector3(0.6, 46.5, 0), Vector3(1.2, 0.7, 0.1))
	# Tower Bridge in 1890: the two river piers, the towers clad in stone to half their height, the steel frames
	# above with their bracing, a timber stage and a steam crane on each, and the shore spans not yet joined
	for tx in [-30.5, 30.5]:
		var b := Vector3(tx, -2.0, 330.0)
		k.box("granite", b + Vector3(0, 3, 0), Vector3(22, 6, 30))
		k.box("granite", b + Vector3(0, 18, 0), Vector3(16, 24, 18))
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			k.box("granite", b + Vector3(corner.x * 7.2, 18, corner.y * 8.2), Vector3(3.2, 26, 3.2))
		# the steel frame: four columns, girders every 6 m, crossed bracing on the faces
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			k.box("iron", b + Vector3(corner.x * 6.5, 44, corner.y * 7.5), Vector3(0.9, 28, 0.9))
		for lv in 5:
			var y := 32.0 + lv * 6.0
			k.box("iron", b + Vector3(0, y, -7.5), Vector3(13.8, 0.6, 0.5))
			k.box("iron", b + Vector3(0, y, 7.5), Vector3(13.8, 0.6, 0.5))
			k.box("iron", b + Vector3(-6.5, y, 0), Vector3(0.5, 0.6, 15.8))
			k.box("iron", b + Vector3(6.5, y, 0), Vector3(0.5, 0.6, 15.8))
			if lv < 4:
				for side in [-1, 1]:
					var p0 := b + Vector3(-6.5, y, side * 7.5)
					var p1 := b + Vector3(6.5, y + 6.0, side * 7.5)
					_beam(k, "iron", p0, p1, 0.35)
					_beam(k, "iron", Vector3(p1.x, p0.y, p0.z), Vector3(p0.x, p1.y, p0.z), 0.35)
		# the stage at the top and the crane's jib swung out over the river
		k.box("timber", b + Vector3(0, 58.5, 0), Vector3(15, 0.8, 17))
		k.box("iron", b + Vector3(2.0, 62.0, 0), Vector3(1.2, 7.0, 1.2))
		_beam(k, "iron", b + Vector3(2.0, 65.0, 0), b + Vector3(-18.0 if tx < 0.0 else 18.0, 60.0, 4.0), 0.5)
		_beam(k, "iron", b + Vector3(2.0, 65.5, 0), b + Vector3(-18.0 if tx < 0.0 else 18.0, 60.5, 4.0), 0.15)
	# the shore spans reach out from each bank, the middle still open
	k.box("granite", Vector3(-68.0, 5.0, 330.0), Vector3(54, 3.0, 12))
	k.box("granite", Vector3(68.0, 5.0, 330.0), Vector3(54, 3.0, 12))
	GfxWorld.add_mesh(n, k.bake(), "Landmark")
	return n


# ------------------------------------------------------------------ Rio de Janeiro

static func rio(city_builder: RefCounted) -> Node3D:
	var n := Node3D.new()
	n.name = "GfxWorldBack"
	# the promenade, the beach and the sea go on behind the car (the view ahead stops 40 m back)
	var k := MeshKit.new()
	if city_builder and city_builder.has_method("_walk_mat"):
		k.use("walk", city_builder._walk_mat())
		k.use("sea", GfxWorld.shader_mat(SH + "rio_sea.gdshader"))
		var near := 40.0
		var far := 2600.0
		k.quad("walk", Vector3(7.7, 0.16, far), Vector3(9.0, 0.16, far), Vector3(9.0, 0.16, near), Vector3(7.7, 0.16, near))
		GfxWorld.paint(k, "seawall", Color("cfc2ad"), 0.9)
		k.quad("seawall", Vector3(9.0, -0.45, far), Vector3(9.0, -0.45, near), Vector3(9.0, 0.16, near), Vector3(9.0, 0.16, far))
		k.quad("sea", Vector3(9.0, -0.45, far), Vector3(3000, -0.45, far), Vector3(3000, -0.45, near), Vector3(9.0, -0.45, near))
		GfxWorld.add_mesh(n, k.bake(), "Shore")
	var h := MeshKit.new()
	GfxWorld.paint(h, "far", Color("4a5a6a"), 1.0)
	GfxWorld.paint(h, "forest", Color("2f4a32"), 1.0)
	GfxWorld.paint(h, "forest_near", Color("26402a"), 1.0)
	GfxWorld.paint(h, "rock", Color("6e6660"), 0.9)
	# Pedra da Gávea: the great flat-topped block of granite behind
	_terrain(h, "rock", -120.0, 160.0, 520.0, 640.0, 36, 6, func(x: float, z: float) -> float:
		var top := 150.0 * _mesa((x - 30.0) / 70.0)
		return top * _bell((z - 580.0) / 42.0) - 4.0)
	# the long ridge of hills from the city to the sea
	_terrain(h, "far", -520.0, 260.0, 480.0, 560.0, 40, 4, func(x: float, z: float) -> float:
		var ridge := 48.0 + 18.0 * sin(x * 0.013 + 0.7) + 10.0 * sin(x * 0.041)
		return ridge * _bell((z - 520.0) / 40.0) * smoothstep(260.0, 120.0, x) - 6.0)
	# Dois Irmãos, the two brothers, the taller on the sea side, standing at the end of the beach
	_terrain(h, "forest", -30.0, 150.0, 380.0, 470.0, 40, 10, func(x: float, z: float) -> float:
		var peaks := 108.0 * exp(-pow((x - 92.0) / 20.0, 2.0)) + 86.0 * exp(-pow((x - 48.0) / 18.0, 2.0)) + 36.0 * _bell((x - 70.0) / 46.0)
		return peaks * _bell((z - 425.0) / 26.0) - 3.0)
	# their bare rock faces on the sea side
	_terrain(h, "rock", 88.0, 128.0, 405.0, 422.0, 10, 4, func(x: float, z: float) -> float:
		return (104.0 * exp(-pow((x - 96.0) / 14.0, 2.0)) - 18.0) * _bell((z - 413.0) / 8.0))
	GfxWorld.add_mesh(n, h.bake(), "Hills")
	# Vidigal: the houses climbing the foot of the hill, their windows lit
	var v := MeshKit.new()
	var walls := ["f2e6cf", "e8a87c", "d86a4a", "6fb3c8", "f0d070", "c8c0b0"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 2016
	for i in 150:
		var x := rng.randf_range(10.0, 125.0)
		var z := rng.randf_range(395.0, 412.0)
		var ground := 108.0 * exp(-pow((x - 92.0) / 20.0, 2.0)) + 86.0 * exp(-pow((x - 48.0) / 18.0, 2.0)) + 36.0 * exp(-pow((x - 70.0) / 46.0, 2.0))
		ground = ground * _bell((z - 425.0) / 26.0) - 3.0
		var y := minf(ground, rng.randf_range(0.0, 34.0))
		if y < 0.5:
			continue
		var c: String = walls[i % walls.size()]
		GfxWorld.paint(v, "w" + c, Color(c), 0.9)
		var sz := Vector3(rng.randf_range(3.0, 6.0), rng.randf_range(2.6, 5.0), rng.randf_range(3.0, 5.0))
		v.box("w" + c, Vector3(x, y + sz.y / 2.0 - 0.6, z), sz)
		if rng.randf() < 0.55:
			GfxWorld.paint(v, "lit", Color("ffc870"), 0.4, 0.0, 3.0)
			v.box("lit", Vector3(x + rng.randf_range(-1.0, 1.0), y + sz.y * 0.55, z - sz.z / 2.0 - 0.05), Vector3(0.8, 0.8, 0.1))
	GfxWorld.add_mesh(n, v.bake(), "Vidigal")
	return n


static func _mesa(u: float) -> float:
	## a flat top with steep sides
	return 1.0 / (1.0 + pow(absf(u), 6.0))


# ------------------------------------------------------------------ Berlin 2075

static func berlin() -> Node3D:
	var n := Node3D.new()
	n.name = "GfxWorldBack"
	var k := MeshKit.new()
	# floodlit sandstone, lit from below; the quadriga's green copper; the Reichstag's glass and its LED ring
	GfxWorld.paint(k, "stone", Color("e8d6ae"), 0.8, 0.0, 1.3)
	GfxWorld.paint(k, "stone_dark", Color("a08a66"), 0.8, 0.0, 0.7)
	GfxWorld.paint(k, "copper", Color("4f9a84"), 0.5, 0.6, 0.35)
	GfxWorld.paint(k, "glass", Color("9ad8ff"), 0.15, 0.4, 1.4)
	GfxWorld.paint(k, "steel", Color("2a2e38"), 0.4, 0.8)
	GfxWorld.paint(k, "neon_a", Color("ff3fb4"), 0.3, 0.0, 5.0)
	GfxWorld.paint(k, "neon_b", Color("2ef2ff"), 0.3, 0.0, 5.0)
	# the Brandenburg Gate, straight down the street behind: the base, six pairs of Doric columns, the
	# entablature, the attic with the quadriga on top, the side wings
	# (a little over life size, at the end of the avenue)
	var old_at := k.at(Transform3D(Basis.from_scale(Vector3.ONE * 1.2), Vector3(0.0, -2.0, 205.0)))
	var g := Vector3.ZERO
	k.box("stone_dark", g + Vector3(0, 1.0, 0), Vector3(66, 2, 14))
	for i in 6:
		var x := -27.5 + i * 11.0
		for zz in [-4.5, 4.5]:
			k.cylinder("stone", g + Vector3(x, 2.0 + 7.5, zz), 0.95, 15.0, 12)
			k.box("stone", g + Vector3(x, 2.4, zz), Vector3(2.4, 0.8, 2.4))
	k.box("stone", g + Vector3(0, 18.6, 0), Vector3(64, 3.2, 12))
	k.box("stone_dark", g + Vector3(0, 20.4, 0), Vector3(65, 0.6, 12.6))
	k.box("stone", g + Vector3(0, 23.0, 0), Vector3(30, 4.6, 10))
	k.prism("stone", PackedVector2Array([Vector2(-15, 25.3), Vector2(15, 25.3), Vector2(9, 27.3), Vector2(-9, 27.3)]), g.z - 5.0, g.z + 5.0)
	for side in [-1, 1]:
		k.box("stone", g + Vector3(side * 41.0, 8.0, 0), Vector3(14, 16, 12))
		k.box("stone_dark", g + Vector3(side * 41.0, 16.6, 0), Vector3(15, 1.2, 13))
	# the quadriga: Victoria in her chariot, four horses abreast
	var q := g + Vector3(0, 27.3, -1.0)
	k.box("copper", q + Vector3(0, 1.4, 1.6), Vector3(3.0, 2.8, 2.2))
	k.box("copper", q + Vector3(0, 4.6, 1.6), Vector3(0.9, 3.6, 0.9))
	k.box("copper", q + Vector3(0.9, 7.2, 1.6), Vector3(0.3, 4.0, 0.3))
	k.box("copper", q + Vector3(0.9, 9.4, 1.6), Vector3(1.6, 1.2, 0.2))
	for i in 4:
		var hx := -2.7 + i * 1.8
		k.box("copper", q + Vector3(hx, 1.8, -1.6), Vector3(0.9, 1.6, 3.4))
		k.box("copper", q + Vector3(hx, 3.0, -3.4), Vector3(0.7, 1.8, 1.0))
		for lz in [-0.4, -2.8]:
			k.box("copper", q + Vector3(hx, 0.5, lz), Vector3(0.6, 1.0, 0.4))
	# a thin ring of light round the attic and LED lines along the columns' feet: 2075
	k.box("neon_b", g + Vector3(0, 20.85, -6.4), Vector3(64, 0.18, 0.1))
	k.box("neon_a", g + Vector3(0, 2.05, -7.05), Vector3(66, 0.14, 0.1))
	k.at(old_at)
	# the Victory Column beyond it, down the same axis: the granite base, the hall of columns with its mosaic, the
	# column in four drums ringed with gilded bands, the gallery, and Victoria in gold with her wreath and wings
	GfxWorld.paint(k, "granite_red", Color("8a4a42"), 0.7, 0.0, 0.5)
	GfxWorld.paint(k, "sand", Color("e8d6ae"), 0.7, 0.0, 1.1)
	GfxWorld.paint(k, "gilt", Color("ffcf5a"), 0.25, 1.0, 2.2)
	var sc := Vector3(0.0, -2.0, 300.0)
	k.box("granite_red", sc + Vector3(0, 3.5, 0), Vector3(22, 7, 22))
	k.cylinder("granite_red", sc + Vector3(0, 10.0, 0), 8.5, 6.0, 20)
	for c in 16:
		var a := TAU * c / 16.0
		k.cylinder("sand", sc + Vector3(cos(a) * 8.9, 10.0, sin(a) * 8.9), 0.45, 6.0, 8)
	k.cylinder("sand", sc + Vector3(0, 13.6, 0), 9.4, 1.2, 20)
	for drum in 4:
		var y0 := 14.2 + drum * 9.5
		var r := 3.4 - drum * 0.15
		k.cylinder("sand", sc + Vector3(0, y0 + 4.3, 0), r, 8.6, 18)
		k.cylinder("gilt", sc + Vector3(0, y0 + 9.0, 0), r + 0.25, 0.9, 18)
	k.box("sand", sc + Vector3(0, 53.4, 0), Vector3(7.2, 1.2, 7.2))
	k.cylinder("sand", sc + Vector3(0, 55.0, 0), 2.0, 2.4, 14)
	k.box("gilt", sc + Vector3(0, 58.3, 0), Vector3(1.6, 4.4, 1.2))
	k.sphere("gilt", sc + Vector3(0, 61.0, 0), Vector3.ONE * 0.75, 8, 6)
	k.box("gilt", sc + Vector3(0.9, 62.2, 0), Vector3(0.25, 2.6, 0.25))
	k.lathe("gilt", PackedVector2Array([Vector2(0.55, 63.4), Vector2(0.15, 63.6)]), sc + Vector3(0.9, 0, 0), 10)
	for wing in [-1, 1]:
		k.tri("gilt", sc + Vector3(wing * 0.5, 60.6, -0.2), sc + Vector3(wing * 2.6, 63.6, -0.7), sc + Vector3(wing * 0.6, 58.2, -0.3))
		k.tri("gilt", sc + Vector3(wing * 0.6, 58.2, -0.3), sc + Vector3(wing * 2.6, 63.6, -0.7), sc + Vector3(wing * 0.5, 60.6, -0.2))
	# the Reichstag off to the side beyond the trees, its glass dome glowing
	var r := Vector3(-92.0, -2.0, 390.0)
	k.box("stone_dark", r + Vector3(0, 12, 0), Vector3(96, 24, 50))
	for cx in [-1, 1]:
		for cz in [-1, 1]:
			k.box("stone_dark", r + Vector3(cx * 44, 15, cz * 22), Vector3(12, 30, 12))
	k.lathe("glass", PackedVector2Array([Vector2(19, 24), Vector2(18.4, 29), Vector2(16.4, 34), Vector2(12.6, 38.5), Vector2(7.0, 41.5), Vector2(0, 42.5)]), r, 20)
	for i in 12:
		var a := TAU * i / 12.0
		_beam(k, "steel", r + Vector3(cos(a) * 19.1, 24, sin(a) * 19.1), r + Vector3(cos(a) * 7.1, 41.6, sin(a) * 7.1), 0.25)
	GfxWorld.add_mesh(n, k.bake(), "Landmark")
	return n


# ------------------------------------------------------------------ helpers

static func _beam(k: MeshKit, m: String, a: Vector3, b: Vector3, w: float) -> void:
	## a square beam from a to b
	var d := b - a
	var len := d.length()
	if len < 0.001:
		return
	var y := d / len
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var old := k.at(Transform3D(Basis(x, y, z), (a + b) * 0.5))
	k.box(m, Vector3.ZERO, Vector3(w, len, w))
	k.at(old)


static func _bell(u: float) -> float:
	return exp(-u * u)


static func _terrain(k: MeshKit, m: String, x0: float, x1: float, z0: float, z1: float, nx: int, nz: int, fn: Callable) -> void:
	## a height field over a rectangle (the same as the view ahead's hills)
	for i in nx:
		for j in nz:
			var xa := lerpf(x0, x1, float(i) / nx)
			var xb := lerpf(x0, x1, float(i + 1) / nx)
			var za := lerpf(z0, z1, float(j) / nz)
			var zb := lerpf(z0, z1, float(j + 1) / nz)
			var a := Vector3(xa, fn.call(xa, za), za)
			var b := Vector3(xb, fn.call(xb, za), za)
			var c := Vector3(xb, fn.call(xb, zb), zb)
			var d := Vector3(xa, fn.call(xa, zb), zb)
			k.quad(m, a, b, c, d)
