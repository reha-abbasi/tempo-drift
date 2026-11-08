extends RefCounted
## Rio de Janeiro for the city look (GfxWorld): Copacabana's black and white wave promenade, a beach with
## surf rolling in, real palms, parasols, kiosks and lifeguard posts along the shore, brighter facades, and Sugarloaf,
## Corcovado and the hills layered behind the sea.

const SH := "res://materials/gfx_world/"
## facade colours of Copacabana (over the buildings' own plaster)
const WALLS := ["fff4e0", "ffd06a", "ff8a66", "e8563c", "48c8b4", "64a6f2", "f27cb2", "b8e264", "ffae42", "fffaf2"]
## words on the shop and hotel signs
const SIGNS := ["HOTEL", "BAR", "CAFE", "SUCOS", "CHOPP", "SAMBA", "PIZZA", "PRAIA", "CINEMA", "BOATE", "RIO", "LANCHE"]
const SIGN_COLORS := ["ff4a5a", "ffd23c", "3cf0ff", "ff7ad8", "7dff6a", "ffffff"]
const PARASOLS := ["e8443a", "f6c22c", "1f8fd6", "f0f0ea", "f07ab0", "2fb38a", "ff8a2a"]

## awning stripes
const AWNINGS := [["e8443a", "f4f0e6"], ["1f8fd6", "f4f0e6"], ["2fb38a", "f6e8b0"], ["ff8a2a", "fff2d6"], ["f07ab0", "ffffff"], ["f6c22c", "e8443a"]]

var _walk: ShaderMaterial
var _sign: ShaderMaterial
var _walls := {}


func restyle_horizon(h: Node3D) -> void:
	GfxWorld.vanish(h.get_node_or_null("Landmark"))


func horizon() -> Node3D:
	## the far view: the promenade beyond the street, the beach and the sea (one sheet travelling with the car, drawn in
	## world space), and the hills of Rio in layers, Sugarloaf over the sea
	var n := Node3D.new()
	n.name = "GfxWorld"
	var k := MeshKit.new()
	k.use("walk", _walk_mat())
	k.use("sea", GfxWorld.shader_mat(SH + "rio_sea.gdshader"))
	var near := 40.0
	var far := -2600.0
	k.quad("walk", Vector3(7.7, 0.16, near), Vector3(9.0, 0.16, near), Vector3(9.0, 0.16, far), Vector3(7.7, 0.16, far))
	GfxWorld.paint(k, "seawall", Color("cfc2ad"), 0.9)
	k.quad("seawall", Vector3(9.0, -0.45, near), Vector3(9.0, -0.45, far), Vector3(9.0, 0.16, far), Vector3(9.0, 0.16, near))
	k.quad("sea", Vector3(9.0, -0.45, near), Vector3(3000, -0.45, near), Vector3(3000, -0.45, far), Vector3(9.0, -0.45, far))
	GfxWorld.add_mesh(n, k.bake(), "Shore")
	GfxWorld.add_mesh(n, _hills(), "Hills")
	return n


func section(facts: Dictionary) -> Dictionary:
	## what a street section gets: palms, lamps, a kiosk and a lifeguard post along the shore, parasols on the sand
	## (the costly part), and on the city side striped awnings, café tables and signs
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(facts.scene)
	var k := MeshKit.new()
	k.use("leaf", GfxWorld.shader_mat(SH + "foliage.gdshader"))
	for i in 4:
		_palm(k, Vector3(6.9 + rng.randf_range(-0.1, 0.15), 0.16, -4.0 - 12.0 * i + rng.randf_range(-1.5, 1.5)), rng.randf_range(8.5, 10.5), rng)
		_palm(k, Vector3(8.5 + rng.randf_range(-0.1, 0.1), 0.16, -10.0 - 12.0 * i + rng.randf_range(-1.5, 1.5)), rng.randf_range(9.0, 11.5), rng)
	_kiosk(k, Vector3(7.7, 0.16, -22.0 + rng.randf_range(-2.0, 2.0)), rng)
	if hash(facts.scene) % 2 == 0:
		_posto(k, Vector3(11.4, -0.45, -40.0))
	for z: float in [-7.0, -31.0]:
		_lamp(k, Vector3(5.05, 0.16, z))
	# on the city side: a striped awning over each ground floor, café tables under some, and hotel and shop signs
	if _sign == null:
		_sign = GfxWorld.sign_mat(PackedStringArray(SIGNS), 2.6)
	k.use("sign", _sign)
	GfxWorld.paint(k, "bracket", Color("2a2a2e"), 0.5, 1.0)
	GfxWorld.paint(k, "table", Color("f6f3ec"), 0.6)
	GfxWorld.paint(k, "chair", Color("c8442a"), 0.6)
	for b in facts.buildings:
		if b.side > 0:
			continue
		var box: AABB = b.box
		var fx := box.end.x
		var z0 := box.position.z + 0.6
		var z1 := box.end.z - 0.6
		var aw: Array = AWNINGS[rng.randi() % AWNINGS.size()]
		_awning(k, fx, z0, z1, aw)
		if rng.randf() < 0.6:
			var nt := int((z1 - z0) / 2.4)
			for t in nt:
				_table(k, Vector3(fx + 0.55, 0.16, z0 + 1.2 + t * 2.4))
		if rng.randf() < 0.35:
			continue
		var z := box.get_center().z + rng.randf_range(-1.5, 1.5)
		var y0 := rng.randf_range(3.9, 4.6)
		var tall := rng.randf_range(3.2, 5.5)
		var c := Color(SIGN_COLORS[rng.randi() % SIGN_COLORS.size()])
		k.color = Color(c, rng.randf())
		k.quad("sign", Vector3(fx + 0.25, y0, z), Vector3(fx + 1.25, y0, z), Vector3(fx + 1.25, y0 + tall, z), Vector3(fx + 0.25, y0 + tall, z),
			[Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
		k.color = Color.WHITE
		k.box("bracket", Vector3(fx + 0.15, y0 + tall * 0.5, z - 0.03), Vector3(0.3, tall, 0.05))
	var rich := MeshKit.new()
	for i in 10:
		_parasol(rich, Vector3(rng.randf_range(9.8, 12.6), -0.45, rng.randf_range(-47.0, -1.0)), rng)
	return {"Base": k.bake(), "Rich": rich.bake()}


func restyle(sec: Node3D) -> void:
	## the sea front, flat sea and old palms give way to the new shore; the pavement takes the wave stones;
	## the facades take Copacabana's colours
	for n in sec.get_children():
		if n.scene_file_path.ends_with("palm.tscn"):
			GfxWorld.vanish(n)
	GfxWorld.vanish(sec.get_node_or_null("Right/SeaFront"))
	var road := sec.get_node_or_null("Road") as MeshInstance3D
	if road and road.mesh and road.mesh.get_surface_count() > 2:
		road.set_surface_override_material(2, _walk_mat())
	var i := 0
	for b in sec.get_node("Left").get_children():
		var mi := b.get_node_or_null("Building") as MeshInstance3D
		i += 1
		if mi == null or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			if mi.mesh.surface_get_name(s) == "wall":
				var pick: int = absi(hash(String(sec.name) + String(b.name) + str(i))) % WALLS.size()
				mi.set_surface_override_material(s, _wall(mi.mesh.surface_get_material(s), WALLS[pick]))


func _awning(k: MeshKit, fx: float, z0: float, z1: float, aw: Array) -> void:
	## a striped awning sloping out from a ground floor on the city side, with a scalloped valance
	var m1 := GfxWorld.paint(k, "aw_" + aw[0], Color(aw[0]), 0.85)
	var m2 := GfxWorld.paint(k, "aw_" + aw[1], Color(aw[1]), 0.85)
	var n := maxi(2, int((z1 - z0) / 0.55))
	var top := Vector2(fx + 0.02, 3.45)
	var low := Vector2(fx + 1.2, 2.8)
	for j in n:
		var za := lerpf(z0, z1, float(j) / n)
		var zb := lerpf(z0, z1, float(j + 1) / n)
		var m := m1 if j % 2 == 0 else m2
		k.quad(m, Vector3(low.x, low.y, zb), Vector3(low.x, low.y, za), Vector3(top.x, top.y, za), Vector3(top.x, top.y, zb))
		k.quad(m, Vector3(low.x, low.y - 0.28, zb), Vector3(low.x, low.y - 0.28, za), Vector3(low.x, low.y, za), Vector3(low.x, low.y, zb))


func _table(k: MeshKit, p: Vector3) -> void:
	## a café table with two chairs
	k.cylinder("table", p + Vector3(0, 0.72, 0), 0.32, 0.04, 10)
	k.box("table", p + Vector3(0, 0.36, 0), Vector3(0.05, 0.72, 0.05))
	for e: float in [-0.5, 0.5]:
		k.box("chair", p + Vector3(0, 0.45, e), Vector3(0.36, 0.05, 0.36))
		k.box("chair", p + Vector3(0, 0.7, e + signf(e) * 0.17), Vector3(0.36, 0.5, 0.04))
		k.box("chair", p + Vector3(0, 0.22, e), Vector3(0.04, 0.44, 0.04))


func _walk_mat() -> ShaderMaterial:
	if _walk == null:
		_walk = GfxWorld.shader_mat(SH + "calcadao.gdshader")
	return _walk


func _wall(base: Material, hex: String) -> Material:
	if not _walls.has(hex):
		var m := base.duplicate() as BaseMaterial3D
		if m == null:
			return base
		m.albedo_color = Color(hex)
		_walls[hex] = m
	return _walls[hex]


func _palm(k: MeshKit, base: Vector3, h: float, rng: RandomNumberGenerator) -> void:
	## a coconut palm: a ringed, gently bent trunk and a crown of drooping, feathered fronds
	GfxWorld.paint(k, "bark_a", Color("8a7a66"), 0.95)
	GfxWorld.paint(k, "bark_b", Color("6c5e4e"), 0.95)
	GfxWorld.paint(k, "nut", Color("6b4a22"), 0.7)
	var lean := Vector3(rng.randf_range(-0.9, 0.7), 0, rng.randf_range(-0.8, 0.8))
	var sides := 7
	var prev := []
	var n := 10
	for i in n + 1:
		var t := float(i) / n
		var c := base + Vector3(0, h * t, 0) + lean * t * t
		var r := lerpf(0.27, 0.16, t)
		var ring := []
		for s in sides:
			var a := TAU * s / sides
			ring.append(c + Vector3(cos(a) * r, 0, sin(a) * r))
		if i > 0:
			var m := "bark_a" if i % 2 == 0 else "bark_b"
			for s in sides:
				var s2 := (s + 1) % sides
				k.quad(m, prev[s2], prev[s], ring[s], ring[s2])
		prev = ring
	var top := base + Vector3(0, h, 0) + lean
	for j in 4:
		var a := TAU * j / 4 + 0.4
		k.sphere("nut", top + Vector3(cos(a) * 0.22, -0.35, sin(a) * 0.22), Vector3.ONE * 0.13, 5, 3)
	var nf := 15
	for f in nf:
		var a := TAU * f / nf + rng.randf_range(-0.18, 0.18)
		var u := Vector3(cos(a), 0, sin(a))
		var length := rng.randf_range(3.0, 3.8)
		var rise := rng.randf_range(0.3, 1.05)
		var droop := rng.randf_range(0.2, 0.3) * (1.25 if rise < 0.5 else 1.0)
		var dry := rise < 0.4 and rng.randf() < 0.5
		var pts: Array[Vector3] = []
		for j in 9:
			var s := float(j) / 8.0 * length
			pts.append(top + u * s * 0.92 + Vector3.UP * (s * sin(rise) - droop * s * s))
		var green := Color("4f8a2c").lerp(Color("2f6a2a"), rng.randf())
		if dry:
			green = Color("9a7a3a")
		for j in range(1, 9):
			var p := pts[j]
			var tg := (pts[mini(j + 1, 8)] - pts[j - 1]).normalized()
			var side := tg.cross(Vector3.UP).normalized()
			var sway := float(j) / 8.0
			k.color = Color(green.lightened(0.1 * sway), sway)
			k.tri("leaf", pts[j - 1] - side * 0.05, p + side * 0.05, p - side * 0.05)
			k.tri("leaf", pts[j - 1] - side * 0.05, pts[j - 1] + side * 0.05, p + side * 0.05)
			var span := 1.15 * pow(sin(PI * (float(j) - 0.3) / 8.0), 0.7) + 0.12
			for sg: float in [-1.0, 1.0]:
				var d := (side * sg * 0.85 + Vector3.DOWN * 0.5 + tg * 0.3).normalized()
				k.color = Color(green.lerp(Color("a9b84a"), 0.25 * sway), sway)
				k.tri("leaf", p - tg * 0.11, p + tg * 0.11, p + d * span)
	k.color = Color.WHITE


func _parasol(k: MeshKit, p: Vector3, rng: RandomNumberGenerator) -> void:
	## a striped beach parasol, a towel on the sand under it
	var c1: String = PARASOLS[rng.randi() % PARASOLS.size()]
	var c2: String = PARASOLS[rng.randi() % PARASOLS.size()]
	var m1 := GfxWorld.paint(k, "para_" + c1, Color(c1), 0.8)
	var m2 := GfxWorld.paint(k, "para_" + c2, Color(c2), 0.8) if c2 != c1 else GfxWorld.paint(k, "para_white", Color("f4f1e8"), 0.8)
	GfxWorld.paint(k, "pole", Color("e8e4dc"), 0.5)
	k.box("pole", p + Vector3(0, 1.1, 0), Vector3(0.05, 2.2, 0.05))
	var apex := p + Vector3(0, 2.45, 0)
	var seg := 8
	var tilt := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
	for s in seg:
		var a0 := TAU * s / seg
		var a1 := TAU * (s + 1) / seg
		var r0 := p + Vector3(cos(a0) * 1.15, 2.05, sin(a0) * 1.15) + tilt * cos(a0)
		var r1 := p + Vector3(cos(a1) * 1.15, 2.05, sin(a1) * 1.15) + tilt * cos(a1)
		k.tri(m1 if s % 2 == 0 else m2, apex, r1, r0)
	var tc: String = PARASOLS[rng.randi() % PARASOLS.size()]
	var mt := GfxWorld.paint(k, "para_" + tc, Color(tc), 0.8)
	var o := p + Vector3(rng.randf_range(0.6, 1.2), 0.03, rng.randf_range(-0.5, 0.5))
	k.quad(mt, o + Vector3(-0.45, 0, 0.85), o + Vector3(0.45, 0, 0.85), o + Vector3(0.45, 0, -0.85), o + Vector3(-0.45, 0, -0.85))


func _kiosk(k: MeshKit, p: Vector3, rng: RandomNumberGenerator) -> void:
	## a round beach kiosk: glass counter, a lit sign band and a striped roof
	GfxWorld.paint(k, "kiosk_glass", Color("1d4b52"), 0.1, 0.0)
	GfxWorld.paint(k, "kiosk_base", Color("e9e2d2"), 0.7)
	GfxWorld.paint(k, "kiosk_sign", Color("ffcf6a"), 0.4, 0.0, 2.5)
	GfxWorld.paint(k, "roof_a", Color("2c8a4a"), 0.7)
	GfxWorld.paint(k, "roof_b", Color("f3efe4"), 0.7)
	k.cylinder("kiosk_base", p + Vector3(0, 0.5, 0), 1.25, 1.0, 10)
	k.cylinder("kiosk_glass", p + Vector3(0, 1.6, 0), 1.15, 1.2, 10, false)
	k.cylinder("kiosk_sign", p + Vector3(0, 2.4, 0), 1.3, 0.4, 10, false)
	var apex := p + Vector3(0, 3.5, 0)
	var seg := 12
	for s in seg:
		var a0 := TAU * s / seg
		var a1 := TAU * (s + 1) / seg
		k.tri("roof_a" if s % 2 == 0 else "roof_b", apex, p + Vector3(cos(a1) * 2.0, 2.65, sin(a1) * 2.0), p + Vector3(cos(a0) * 2.0, 2.65, sin(a0) * 2.0))
	# a few tables and sunshades by it
	for j in 2:
		var q := p + Vector3(rng.randf_range(0.6, 1.4), 0, -2.6 - 2.4 * j)
		GfxWorld.paint(k, "table", Color("f6f3ec"), 0.6)
		k.box("table", q + Vector3(0, 0.38, 0), Vector3(0.7, 0.05, 0.7))
		k.box("table", q + Vector3(0, 0.18, 0), Vector3(0.06, 0.36, 0.06))


func _posto(k: MeshKit, p: Vector3) -> void:
	## a lifeguard post on the sand: a white cabin on stilts, an orange band and a flag
	GfxWorld.paint(k, "posto", Color("f4f2ec"), 0.6)
	GfxWorld.paint(k, "posto_band", Color("ff6a1f"), 0.6)
	GfxWorld.paint(k, "flag", Color("ffd21f"), 0.7)
	for sx: float in [-0.8, 0.8]:
		for sz: float in [-0.8, 0.8]:
			k.box("posto", p + Vector3(sx, 1.1, sz), Vector3(0.12, 2.2, 0.12))
	k.box("posto", p + Vector3(0, 2.9, 0), Vector3(2.0, 1.4, 2.0))
	k.box("posto_band", p + Vector3(0, 3.7, 0), Vector3(2.2, 0.25, 2.2))
	k.box("posto", p + Vector3(0, 5.0, 0), Vector3(0.06, 2.4, 0.06))
	k.box("flag", p + Vector3(0, 5.8, -0.45), Vector3(0.02, 0.5, 0.85))


func _lamp(k: MeshKit, p: Vector3) -> void:
	## a tall promenade lamp: a fluted base, a slim pole and two swan necks, each holding a lit lantern, one over the
	## road and one over the promenade
	GfxWorld.paint(k, "lamp_pole", Color("1f4a4a"), 0.35, 1.0)
	GfxWorld.paint(k, "lamp_head", Color("ffe2a8"), 0.4, 0.0, 3.5)
	k.lathe("lamp_pole", PackedVector2Array([Vector2(0.26, 0.0), Vector2(0.24, 0.5), Vector2(0.15, 0.62), Vector2(0.13, 1.6), Vector2(0.17, 1.7),
		Vector2(0.1, 1.8), Vector2(0.075, 6.6), Vector2(0.11, 6.7), Vector2(0.06, 6.8)]), p, 8)
	for sx: float in [-1.0, 1.0]:
		var c := p + Vector3(sx * 0.85, 6.8, 0)
		var prev := p + Vector3(0, 6.8, 0)
		for j in range(1, 7):
			var a := PI * 0.5 * j / 6.0
			var q := c + Vector3(-sx * cos(a) * 0.85, sin(a) * 0.85, 0)
			_rod(k, "lamp_pole", prev, q, 0.05)
			prev = q
		var tip := prev + Vector3(sx * 0.25, 0, 0)
		_rod(k, "lamp_pole", prev, tip, 0.05)
		k.lathe("lamp_pole", PackedVector2Array([Vector2(0.24, -0.2), Vector2(0.3, -0.12), Vector2(0.06, 0.0)]), tip, 8)
		k.lathe("lamp_head", PackedVector2Array([Vector2(0.0, -0.62), Vector2(0.2, -0.55), Vector2(0.24, -0.2)]), tip, 8)


func _rod(k: MeshKit, m: String, a: Vector3, b: Vector3, r: float) -> void:
	## a thin six-sided tube from a to b
	var d := (b - a).normalized()
	var u := d.cross(Vector3.FORWARD if absf(d.z) < 0.9 else Vector3.UP).normalized()
	var v := d.cross(u)
	for i in 6:
		var a0 := TAU * i / 6.0
		var a1 := TAU * (i + 1) / 6.0
		var o0 := (u * cos(a0) + v * sin(a0)) * r
		var o1 := (u * cos(a1) + v * sin(a1)) * r
		k.quad(m, a + o0, a + o1, b + o1, b + o0)


func _hills() -> Mesh:
	## Rio's hills in layers: the Tijuca range with Corcovado and its statue far behind the city, Sugarloaf and Urca
	## over the sea, Leme's hill closing the beach, islands offshore
	var k := MeshKit.new()
	GfxWorld.paint(k, "far", Color("4a5a6a"), 1.0)
	GfxWorld.paint(k, "forest", Color("2f4a32"), 1.0)
	GfxWorld.paint(k, "forest_near", Color("26402a"), 1.0)
	k.use("rock", load("res://materials/granite.tres"), 6.0)
	GfxWorld.paint(k, "statue", Color("f4efe6"), 0.6, 0.0, 0.6)
	# the far range
	_terrain(k, "far", -520.0, 520.0, -520.0, -640.0, 40, 4, func(x: float, z: float) -> float:
		var ridge := 55.0 + 22.0 * sin(x * 0.011) + 14.0 * sin(x * 0.031 + 1.0) + 8.0 * sin(x * 0.07)
		return ridge * _bell((z + 580.0) / 60.0) - 6.0)
	# the Tijuca range and Corcovado's needle, behind the city on the left
	_terrain(k, "forest", -480.0, 40.0, -400.0, -520.0, 44, 6, func(x: float, z: float) -> float:
		var ridge := 62.0 + 18.0 * sin(x * 0.019 + 0.5) + 10.0 * sin(x * 0.053)
		ridge *= smoothstep(40.0, -60.0, x)
		ridge += 95.0 * exp(-pow((x + 120.0) / 26.0, 2.0))
		return ridge * _bell((z + 450.0) / 45.0) - 4.0)
	# Christ the Redeemer stands on Corcovado's summit (the needle's top, from the same height as the hill)
	var cx := -120.0
	var cz := -450.0
	var summit := (62.0 + 18.0 * sin(cx * 0.019 + 0.5) + 10.0 * sin(cx * 0.053)) * smoothstep(40.0, -60.0, cx) + 95.0
	var top := Vector3(cx, summit * _bell((cz + 450.0) / 45.0) - 4.0 - 0.5, cz)
	k.box("statue", top + Vector3(0, 4.0, 0), Vector3(2.2, 8.0, 1.6))
	k.box("statue", top + Vector3(0, 6.6, 0), Vector3(9.5, 1.2, 1.2))
	k.box("statue", top + Vector3(0, 8.6, 0), Vector3(1.1, 1.2, 1.1))
	# Sugarloaf and Urca over the sea, joined by the cable car
	var old := k.at(Transform3D(Basis.from_scale(Vector3(0.7, 1.0, 0.8)).rotated(Vector3.UP, 0.3), Vector3(62.0, -2.0, -400.0)))
	k.lathe("rock", PackedVector2Array([Vector2(44, 0), Vector2(43, 10), Vector2(40, 26), Vector2(35, 44), Vector2(28, 62), Vector2(20, 76), Vector2(11, 85), Vector2(0, 88)]), Vector3.ZERO, 18)
	k.at(Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.8)), Vector3(22.0, -2.0, -360.0)))
	k.lathe("forest", PackedVector2Array([Vector2(34, 0), Vector2(31, 10), Vector2(24, 22), Vector2(13, 30), Vector2(0, 33)]), Vector3.ZERO, 14)
	k.at(old)
	GfxWorld.paint(k, "cable", Color("2a2a2a"), 0.8)
	var a := Vector3(22.0, 31.0, -360.0)
	var b := Vector3(62.0, 86.0, -400.0)
	k.quad("cable", a + Vector3(0, -0.35, 0), b + Vector3(0, -0.35, 0), b + Vector3(0, 0.35, 0), a + Vector3(0, 0.35, 0))
	# Leme's hill at the end of the beach, islands out at sea
	_terrain(k, "forest_near", -10.0, 70.0, -280.0, -320.0, 16, 6, func(x: float, z: float) -> float:
		return 46.0 * _bell((x - 28.0) / 34.0) * _bell((z + 300.0) / 18.0) - 3.0)
	_terrain(k, "far", 120.0, 330.0, -400.0, -460.0, 20, 4, func(x: float, z: float) -> float:
		return (24.0 * _bell((x - 170.0) / 30.0) + 16.0 * _bell((x - 260.0) / 40.0)) * _bell((z + 430.0) / 22.0) - 3.0)
	return k.bake()


static func _bell(u: float) -> float:
	return exp(-u * u)


func _terrain(k: MeshKit, m: String, x0: float, x1: float, z0: float, z1: float, nx: int, nz: int, fn: Callable) -> void:
	## a patch of hills from a height function, smooth-shaded; its edges are faded down into the ground and the sea,
	## so no rim of the patch floats in the air (seen from a rooftop), at twice the detail
	nx *= 2
	nz *= 2
	var g := []
	for j in nz + 1:
		var row := []
		for i in nx + 1:
			var x := lerpf(x0, x1, float(i) / nx)
			var z := lerpf(z0, z1, float(j) / nz)
			var edge := smoothstep(0.0, 0.18, minf(float(i) / nx, 1.0 - float(i) / nx)) * smoothstep(0.0, 0.18, minf(float(j) / nz, 1.0 - float(j) / nz))
			var y: float = lerpf(-3.0, float(fn.call(x, z)), edge)
			var e := 2.0
			var nrm := Vector3(-(float(fn.call(x + e, z)) - float(fn.call(x - e, z))) / (2.0 * e), 1.0, -(float(fn.call(x, z + e)) - float(fn.call(x, z - e))) / (2.0 * e)).normalized()
			row.append([Vector3(x, maxf(y, -3.0), z), nrm])
		g.append(row)
	for j in nz:
		for i in nx:
			var a: Array = g[j][i]
			var b: Array = g[j][i + 1]
			var c: Array = g[j + 1][i + 1]
			var d: Array = g[j + 1][i]
			if maxf(maxf(a[0].y, b[0].y), maxf(c[0].y, d[0].y)) < -2.5:
				continue
			k.tri(m, a[0], b[0], c[0], a[1], b[1], c[1])
			k.tri(m, a[0], c[0], d[0], a[1], c[1], d[1])
