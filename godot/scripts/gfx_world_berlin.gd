extends RefCounted
## Berlin 2075 for the city look (GfxWorld): towers whose curtain walls light up floor by floor, signs that
## read as signs (real words in pixel letters, lit frames, glowing tubes), holograms hanging in the air off the towers,
## skybridges and a maglev line high over the street, and a TV tower with a lit sphere over the skyline.

const SH := "res://materials/gfx_world/"
const WORDS := ["HOTEL", "BAR", "KLUB", "TECHNO", "KEBAB", "SPATI", "BERLIN", "KINO", "DATA", "NEON", "TAXI", "UBAHN", "RAVE", "SUSHI", "KAFFEE", "2075"]
const HOLO := ["2ef2ff", "ff3fb4", "8a7bff"]

var _sign: ShaderMaterial
var _holo: ShaderMaterial
var _towers := {}


func restyle_horizon(h: Node3D) -> void:
	GfxWorld.vanish(h.get_node_or_null("Landmark"))


func horizon() -> Node3D:
	## the TV tower, straight down the street: a tapering shaft lined with LEDs, the sphere with its lit decks, the red
	## and white mast with blinking beacons
	var n := Node3D.new()
	n.name = "GfxWorld"
	var k := MeshKit.new()
	k.use("tower", GfxWorld.shader_mat(SH + "tv_tower.gdshader"))
	var o := Vector3(0.0, -2.0, -300.0)
	var concrete := Color(0.2, 0.2, 0.25, 0.0)
	k.color = concrete
	k.lathe("tower", PackedVector2Array([Vector2(6.0, 0), Vector2(3.6, 7), Vector2(2.8, 35), Vector2(2.1, 82), Vector2(1.9, 92)]), o, 12)
	k.color = Color(0.14, 0.15, 0.19, 0.0)
	k.sphere("tower", o + Vector3(0, 100, 0), Vector3(9.0, 9.0, 9.0), 20, 14)
	k.color = Color(0.2, 0.2, 0.25, 0.0)
	k.lathe("tower", PackedVector2Array([Vector2(1.8, 108), Vector2(1.4, 120)]), o, 10)
	for i in 7:
		var y0 := 120.0 + i * 4.5
		k.color = Color(0.55, 0.12, 0.14, 0.0) if i % 2 == 0 else Color(0.5, 0.5, 0.55, 0.0)
		k.lathe("tower", PackedVector2Array([Vector2(0.95 - i * 0.09, y0), Vector2(0.9 - i * 0.09, y0 + 4.5)]), o, 8)
	# the lit decks round the sphere, LED lines up the shaft, the beacons
	k.color = Color(Color("ff3fb4"), 0.85)
	k.lathe("tower", PackedVector2Array([Vector2(9.15, 98.6), Vector2(9.15, 100.0)]), o, 28, false)
	k.color = Color(Color("2ef2ff"), 0.7)
	k.lathe("tower", PackedVector2Array([Vector2(8.3, 104.2), Vector2(8.3, 104.9)]), o, 28, false)
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		var d := Vector3(cos(a), 0, sin(a))
		var sd := d.cross(Vector3.UP)
		k.quad("tower", o + d * 3.62 + Vector3(0, 7, 0) + sd * 0.18, o + d * 3.62 + Vector3(0, 7, 0) - sd * 0.18,
			o + d * 1.92 + Vector3(0, 91, 0) - sd * 0.12, o + d * 1.92 + Vector3(0, 91, 0) + sd * 0.12)
	k.color = Color(Color("ff2a2a"), 1.0)
	for y: float in [92.0, 121.0, 139.0, 152.0]:
		k.sphere("tower", o + Vector3(0, y, 0), Vector3.ONE * 0.9, 6, 4)
	k.color = Color.WHITE
	GfxWorld.add_mesh(n, k.bake(), "TVTower")
	return n


func section(facts: Dictionary) -> Dictionary:
	## what a street section gets: a skybridge on every other kind, the maglev line along the left, and (the costly
	## part) holograms hanging off the towers, kept out of the middle where the TV tower and the rings are
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(facts.scene)
	var k := MeshKit.new()
	GfxWorld.paint(k, "steel", Color("1c1f26"), 0.35, 1.0)
	GfxWorld.paint(k, "under", Color("0d0e12"), 0.6)
	GfxWorld.paint(k, "led_c", Color("2ef2ff"), 0.4, 0.0, 4.0)
	GfxWorld.paint(k, "led_m", Color("ff3fb4"), 0.4, 0.0, 4.0)
	GfxWorld.paint(k, "led_w", Color("dfe8ff"), 0.4, 0.0, 3.0)
	var kind := int(String(facts.scene).get_file().get_basename().right(1))
	if kind % 2 == 0:
		var bz := -24.0 + rng.randf_range(-8.0, 8.0)
		var by := rng.randf_range(13.5, 16.0)
		k.use("bridge_glass", _tower_mat(load("res://materials/curtain_tokyo_warm.tres")))
		var x0 := -7.0
		var x1 := 7.0
		var d := 2.4
		k.quad("bridge_glass", Vector3(x0, by, bz + d), Vector3(x1, by, bz + d), Vector3(x1, by + 3.2, bz + d), Vector3(x0, by + 3.2, bz + d),
			[Vector2(0, 1), Vector2((x1 - x0) / 1.6, 1), Vector2((x1 - x0) / 1.6, 0), Vector2(0, 0)])
		k.box("under", Vector3(0, by - 0.3, bz), Vector3(x1 - x0, 0.6, d * 2.0 + 0.4))
		k.box("steel", Vector3(0, by + 3.45, bz), Vector3(x1 - x0, 0.5, d * 2.0 + 0.4))
		k.box("led_c", Vector3(0, by - 0.62, bz + d + 0.1), Vector3(x1 - x0, 0.08, 0.08))
		k.box("led_m", Vector3(0, by + 3.72, bz + d + 0.1), Vector3(x1 - x0, 0.06, 0.06))
	# the maglev guideway along the left, on arms from the towers
	var gy := 12.5
	var gx := -3.9
	k.box("steel", Vector3(gx, gy, -24.0), Vector3(1.1, 0.8, 48.0))
	k.box("under", Vector3(gx, gy - 0.45, -24.0), Vector3(0.7, 0.12, 48.0))
	k.box("led_c", Vector3(gx + 0.56, gy + 0.1, -24.0), Vector3(0.05, 0.08, 48.0))
	k.box("led_w", Vector3(gx, gy - 0.53, -24.0), Vector3(0.12, 0.04, 48.0))
	for z: float in [-12.0, -36.0]:
		k.box("steel", Vector3((gx - 5.2) * 0.5, gy - 0.2, z), Vector3(absf(-5.2 - gx), 0.35, 0.4))
		k.box("steel", Vector3(-5.0, gy - 2.0, z), Vector3(0.4, 4.0, 0.4))
	var hk := MeshKit.new()
	hk.use("holo", _holo_mat())
	for i in 2:
		var side := -1.0 if (i + int(hash(facts.scene))) % 2 == 0 else 1.0
		var hz := -10.0 - 24.0 * i + rng.randf_range(-4.0, 4.0)
		var hy := rng.randf_range(15.0, 22.0)
		var w := rng.randf_range(2.6, 3.1)
		var hh := w * rng.randf_range(1.1, 1.4)
		var inner := side * 4.6 - side * w
		var a := minf(inner, side * 4.6)
		var b := maxf(inner, side * 4.6)
		hk.color = Color(Color(HOLO[rng.randi() % HOLO.size()]), rng.randf())
		hk.quad("holo", Vector3(a, hy, hz), Vector3(b, hy, hz), Vector3(b, hy + hh, hz), Vector3(a, hy + hh, hz),
			[Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	hk.color = Color.WHITE
	return {"Base": k.bake(), "Rich": hk.bake()}


func restyle(sec: Node3D) -> void:
	## the towers' curtain walls light up; their neon boards become real signs
	for side_name in ["Left", "Right"]:
		var side := sec.get_node_or_null(side_name)
		if side == null:
			continue
		for b in side.get_children():
			var mi := b.get_node_or_null("Building") as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				var nm: String = mi.mesh.surface_get_name(s)
				if nm == "glass" or nm == "curtain":
					mi.set_surface_override_material(s, _tower_mat(mi.mesh.surface_get_material(s)))
				elif nm == "~neon":
					mi.set_surface_override_material(s, _sign_mat())


func _sign_mat() -> ShaderMaterial:
	if _sign == null:
		_sign = GfxWorld.sign_mat(PackedStringArray(WORDS), 3.4)
	return _sign


func _holo_mat() -> ShaderMaterial:
	if _holo == null:
		_holo = GfxWorld.shader_mat(SH + "hologram.gdshader", {"energy": 1.1})
	return _holo


func _tower_mat(base: Material) -> Material:
	## the lit-window version of a tower's curtain wall (its glass and slab spacing kept)
	if not _towers.has(base):
		var m := GfxWorld.shader_mat(SH + "berlin_tower.gdshader")
		var sm := base as ShaderMaterial
		if sm:
			var g = sm.get_shader_parameter("glass_color")
			if g is Color:
				m.set_shader_parameter("glass_color", g)
			var sp = sm.get_shader_parameter("spandrel")
			if sp is float:
				m.set_shader_parameter("spandrel", maxf(sp, 0.18))
		_towers[base] = m
	return _towers[base]
