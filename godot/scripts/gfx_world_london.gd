extends RefCounted
## London 1890 for the city look (GfxWorld): wet cobbles with puddles, gutters and the horse tram's rails;
## painted shop boards and hanging signs with gilt lettering, bay windows, pillar boxes, bollards and flower baskets on
## the gas lamps; and behind Big Ben, rows of roofs and chimney stacks, St Paul's dome and church spires, with smoke
## drifting up from the chimneys.

const SH := "res://materials/gfx_world/"
const SHOPS := ["TEA", "BAKER", "TAILOR", "INN", "ALE", "HATTER", "COFFEE", "BOOKS", "WINE", "GROCER", "OYSTER", "BANK", "PIANOS", "TOYS", "CIGARS", "GIN"]
const BOARDS := ["1f3a2a", "5a1a1e", "151515", "1c2640", "3b2a1a", "2a4a3a"]
const FLOWERS := ["d8344a", "e86aa0", "8a4ad0", "f0d040", "ffffff"]
## shopfront paint
const SHOPS_PAINT := ["1f4a30", "6a1a20", "1a1a1a", "1c2a50", "e8e0c8", "4a2a18"]
## brick and stucco tints for the houses (over their own textures): red, sooty, London stock yellow, cream, pastels
const BRICKS := ["ffffff", "c8a090", "e8d0a0", "b0b8b8", "ffe0c8"]
const STUCCO := ["ffffff", "f4e6c8", "d8e8d8", "d8e0f0", "f0d8d0", "e8e0b8"]
## market stall canopies and the goods on them
const STALLS := [["2a6a3a", "f0e8d0"], ["a02028", "f0e8d0"], ["1c2a5a", "e8d8a8"]]
const GOODS := ["e8801c", "c81c1c", "6aa830", "f0c830", "7a3a8a"]

var _road: ShaderMaterial
var _sign: ShaderMaterial
var _walls := {}


func restyle_horizon(_h: Node3D) -> void:
	pass


func horizon() -> Node3D:
	## the far view behind Big Ben: rows of roofs and chimneys, St Paul's, spires, and (the costly part) chimney smoke
	var n := Node3D.new()
	n.name = "GfxWorld"
	var k := MeshKit.new()
	GfxWorld.paint(k, "roofs_near", Color("4a4440"), 0.9)
	GfxWorld.paint(k, "roofs_far", Color("5c5854"), 0.9)
	GfxWorld.paint(k, "stone", Color("a8a090"), 0.8)
	GfxWorld.paint(k, "lead", Color("5e6468"), 0.5, 0.6)
	GfxWorld.paint(k, "gold", Color("d8b060"), 0.3, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1890
	for row in 2:
		var z := -215.0 - row * 45.0
		var m := "roofs_near" if row == 0 else "roofs_far"
		var x := -160.0
		while x < 160.0:
			var w := rng.randf_range(8.0, 16.0)
			var ht := rng.randf_range(14.0, 22.0) + row * 3.0
			k.box(m, Vector3(x + w / 2, ht / 2 - 2.0, z), Vector3(w, ht, 10.0))
			k.prism(m, PackedVector2Array([Vector2(x, ht - 2.0), Vector2(x + w, ht - 2.0), Vector2(x + w / 2, ht + 2.5)]), z - 5.0, z + 5.0, false)
			for c in rng.randi_range(1, 3):
				var cx := x + rng.randf_range(1.0, w - 1.0)
				k.box(m, Vector3(cx, ht + 2.0, z + rng.randf_range(-3.0, 3.0)), Vector3(1.4, 4.0 + rng.randf() * 2.0, 0.9))
			x += w
	# St Paul's: the drum, the dome, the lantern and its golden cross
	var sp := Vector3(-62.0, -2.0, -300.0)
	k.box("stone", sp + Vector3(0, 13, 0), Vector3(44, 26, 30))
	k.cylinder("stone", sp + Vector3(0, 33, 0), 15.0, 14.0, 20)
	k.cylinder("stone", sp + Vector3(0, 41.5, 0), 13.5, 3.0, 20)
	k.lathe("lead", PackedVector2Array([Vector2(13.5, 43), Vector2(13, 48), Vector2(11, 53), Vector2(8, 57), Vector2(4, 59.5), Vector2(0, 60)]), sp, 20)
	k.cylinder("stone", sp + Vector3(0, 63, 0), 2.2, 6.0, 10)
	k.lathe("lead", PackedVector2Array([Vector2(2.2, 66), Vector2(0.4, 70)]), sp, 8)
	k.sphere("gold", sp + Vector3(0, 70.8, 0), Vector3.ONE * 0.9, 8, 6)
	k.box("gold", sp + Vector3(0, 73.0, 0), Vector3(0.3, 3.0, 0.3))
	k.box("gold", sp + Vector3(0, 73.6, 0), Vector3(1.6, 0.3, 0.3))
	# church spires over the roofs
	for s in [Vector3(48.0, -2.0, -250.0), Vector3(-118.0, -2.0, -270.0), Vector3(96.0, -2.0, -290.0)]:
		k.box("stone", s + Vector3(0, 14, 0), Vector3(6, 28, 6))
		k.lathe("lead", PackedVector2Array([Vector2(3.4, 28), Vector2(0.0, 52)]), s, 8, false)
	GfxWorld.add_mesh(n, k.bake(), "Roofs")
	# chimney smoke drifting up over the roofs
	var sk := MeshKit.new()
	sk.use("smoke", GfxWorld.shader_mat(SH + "smoke.gdshader"))
	for i in 9:
		var p := Vector3(rng.randf_range(-140.0, 140.0), rng.randf_range(18.0, 24.0), -215.0 - rng.randi_range(0, 1) * 45.0 - 6.0)
		if absf(p.x) < 14.0:
			continue
		var w := rng.randf_range(7.0, 11.0)
		var ht := rng.randf_range(28.0, 40.0)
		var lean := rng.randf_range(4.0, 10.0)
		sk.color = Color(1, 1, 1, rng.randf())
		sk.quad("smoke", p + Vector3(-w * 0.2, 0, 0), p + Vector3(w * 0.2, 0, 0), p + Vector3(w * 0.5 + lean, ht, 0), p + Vector3(-w * 0.5 + lean, ht, 0),
			[Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	GfxWorld.add_mesh(n, sk.bake(), "Rich")
	return n


func section(facts: Dictionary) -> Dictionary:
	## what a street section gets: lit shop windows canted towards the street, painted boards, a hanging sign on most
	## houses, bay windows, market stalls, barrels and crates by the kerb, a pillar box, bollards, and (the costly
	## part) flower baskets on the lamps
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(facts.scene)
	var k := MeshKit.new()
	if _sign == null:
		_sign = GfxWorld.sign_mat(PackedStringArray(SHOPS), 1.0, true)
	k.use("board", _sign)
	k.use("bay_glass", load("res://materials/window_warm.tres"))
	GfxWorld.paint(k, "iron", Color("16181a"), 0.45, 1.0)
	GfxWorld.paint(k, "bay", Color("e4dccb"), 0.8)
	GfxWorld.paint(k, "bay_roof", Color("4a5056"), 0.5, 0.5)
	GfxWorld.paint(k, "pillar", Color("b0161c"), 0.35)
	GfxWorld.paint(k, "shop_glow", Color("e8962e"), 0.3, 0.0, 0.8)
	GfxWorld.paint(k, "lantern", Color("ffd890"), 0.3, 0.0, 4.0)
	GfxWorld.paint(k, "wood", Color("3a2616"), 0.7)
	GfxWorld.paint(k, "barrel", Color("6a4426"), 0.7)
	for b in facts.buildings:
		var box: AABB = b.box
		var s: int = b.side
		var fx: float = box.end.x if s < 0 else box.position.x
		var out := -float(s)  # towards the street
		var z0 := box.position.z + 0.5
		var z1 := box.end.z - 0.5
		var zc := (z0 + z1) * 0.5
		var hexp: String = SHOPS_PAINT[rng.randi() % SHOPS_PAINT.size()]
		var paint := GfxWorld.paint(k, "shop_" + hexp, Color(hexp), 0.5)
		# a lit shop window standing out from the ground floor, its cants catching the eye down the street
		if z1 - z0 > 3.0 and rng.randf() < 0.85:
			_shopfront(k, fx, out, z0 + 0.4, z1 - 0.4, paint)
			k.color = Color(Color(BOARDS[rng.randi() % BOARDS.size()]), rng.randf())
			_face(k, "board", fx + out * 0.66, 3.3, 3.95, z0 + 0.3, z1 - 0.3, s)
			k.color = Color.WHITE
		# a hanging sign on an iron bracket, facing down the street, now and then with a lantern at its end
		if rng.randf() < 0.8:
			var sz := zc + rng.randf_range(-1.5, 1.5)
			var xa := fx + out * 0.45
			var xb := fx + out * 1.75
			k.color = Color(Color(BOARDS[rng.randi() % BOARDS.size()]), rng.randf())
			k.quad("board", Vector3(minf(xa, xb), 4.55, sz), Vector3(maxf(xa, xb), 4.55, sz), Vector3(maxf(xa, xb), 5.5, sz), Vector3(minf(xa, xb), 5.5, sz),
				[Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
			k.color = Color.WHITE
			k.box("iron", Vector3((fx + xb) * 0.5, 5.6, sz), Vector3(absf(xb - fx) + 0.1, 0.07, 0.07))
			k.box("iron", Vector3(fx + out * 0.1, 5.2, sz), Vector3(0.2, 0.9, 0.06))
			if rng.randf() < 0.5:
				k.box("iron", Vector3(xb + out * 0.12, 5.45, sz), Vector3(0.24, 0.3, 0.24))
				k.box("lantern", Vector3(xb + out * 0.12, 5.2, sz), Vector3(0.2, 0.26, 0.2))
		# a bay window over two floors on the taller houses
		if box.size.y > 15.0 and rng.randf() < 0.6:
			var bw := minf(2.8, (z1 - z0) * 0.45)
			var bz := zc + rng.randf_range(-0.8, 0.8)
			var d := 0.6
			var xf := fx + out * d
			k.box("bay", Vector3(fx + out * d * 0.5, 4.7, bz), Vector3(d, 0.5, bw + 0.2))
			k.box("bay_roof", Vector3(fx + out * d * 0.5, 10.4, bz), Vector3(d + 0.1, 0.35, bw + 0.3))
			k.color = Color(0.55, 0.5, 1.0)
			for f in 2:
				var y0 := 5.0 + f * 2.7
				_face(k, "bay_glass", xf, y0 + 0.25, y0 + 2.35, bz - bw * 0.5 + 0.15, bz + bw * 0.5 - 0.15, s, Vector2(3, 1))
				k.box("bay", Vector3(fx + out * d * 0.5, y0 + 2.5, bz), Vector3(d, 0.3, bw + 0.1))
			k.color = Color.WHITE
			for e: float in [-1.0, 1.0]:
				k.box("bay", Vector3(fx + out * d * 0.5, 7.6, bz + e * (bw * 0.5 + 0.02)), Vector3(d, 5.6, 0.16))
	# at the kerb: a market stall or two, barrels and crates, a pillar box, bollards
	for i in rng.randi_range(1, 2):
		_stall(k, -1.0 if rng.randf() < 0.5 else 1.0, rng.randf_range(-44.0, -4.0), rng)
	for i in 3:
		var bs := -1.0 if rng.randf() < 0.5 else 1.0
		var p := Vector3(bs * rng.randf_range(4.95, 5.2), 0.16, rng.randf_range(-46.0, -2.0))
		k.cylinder("barrel", p + Vector3(0, 0.42, 0), 0.3, 0.84, 10)
		k.box("wood", p + Vector3(0, 0.25, 0.75), Vector3(0.55, 0.5, 0.55))
		k.box("wood", p + Vector3(0, 0.7, 0.75), Vector3(0.5, 0.4, 0.5))
	var ps := -1.0 if rng.randf() < 0.5 else 1.0
	var pz := rng.randf_range(-40.0, -8.0)
	k.cylinder("pillar", Vector3(ps * 5.05, 0.16 + 0.7, pz), 0.3, 1.4, 12)
	k.lathe("pillar", PackedVector2Array([Vector2(0.34, 1.56), Vector2(0.3, 1.7), Vector2(0.15, 1.8), Vector2(0.0, 1.82)]), Vector3(ps * 5.05, 0.0, pz), 12)
	k.box("iron", Vector3(ps * 5.05 - ps * 0.29, 1.3, pz), Vector3(0.04, 0.06, 0.3))
	for i in 8:
		var bs := -1.0 if i % 2 == 0 else 1.0
		var bz := -3.0 - i * 6.0 + rng.randf_range(-1.0, 1.0)
		k.cylinder("iron", Vector3(bs * 4.9, 0.16 + 0.45, bz), 0.09, 0.9, 6)
		k.sphere("iron", Vector3(bs * 4.9, 1.08, bz), Vector3.ONE * 0.1, 6, 4)
	var rich := MeshKit.new()
	GfxWorld.paint(rich, "iron", Color("16181a"), 0.45, 1.0)
	GfxWorld.paint(rich, "leaves", Color("2e5a26"), 0.8)
	for c in facts.get("lamps", []):
		var lp: Vector3 = c
		var side := signf(lp.x)
		var bp := lp + Vector3(-side * 0.55, 2.35, 0)
		rich.box("iron", lp + Vector3(-side * 0.3, 2.9, 0), Vector3(0.6, 0.05, 0.05))
		rich.sphere("leaves", bp, Vector3(0.34, 0.26, 0.34), 8, 5)
		for j in 7:
			var fc: String = FLOWERS[rng.randi() % FLOWERS.size()]
			GfxWorld.paint(rich, "flower_" + fc, Color(fc), 0.8)
			var a := TAU * j / 7.0
			rich.sphere("flower_" + fc, bp + Vector3(cos(a) * 0.3, rng.randf_range(-0.1, 0.18), sin(a) * 0.3), Vector3.ONE * 0.1, 5, 3)
	return {"Base": k.bake(), "Rich": rich.bake()}


func restyle(sec: Node3D) -> void:
	## the cobbles get wet: puddles, gutters and tram rails; the houses vary in colour and height
	var road := sec.get_node_or_null("Road") as MeshInstance3D
	if road and road.mesh and road.mesh.get_surface_count() > 1:
		road.set_surface_override_material(1, _road_mat(road.mesh.surface_get_material(1)))
	for side_name in ["Left", "Right"]:
		var side := sec.get_node_or_null(side_name)
		if side == null:
			continue
		for b in side.get_children():
			var mi := b.get_node_or_null("Building") as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var hv := absi(hash(String(sec.name) + side_name + String(b.name)))
			(b as Node3D).scale.y *= 0.88 + float(hv % 7) * 0.05
			for si in mi.mesh.get_surface_count():
				if mi.mesh.surface_get_name(si) == "wall":
					var base := mi.mesh.surface_get_material(si)
					var brick := base != null and base.resource_path.contains("brick")
					var pal: Array = BRICKS if brick else STUCCO
					mi.set_surface_override_material(si, _wall(base, pal[(hv / 7) % pal.size()]))


func _wall(base: Material, hex: String) -> Material:
	var key := str(base.get_instance_id()) + hex
	if not _walls.has(key):
		var m := base.duplicate() as BaseMaterial3D
		if m == null:
			return base
		m.albedo_color = m.albedo_color * Color(hex)
		_walls[key] = m
	return _walls[key]


func _shopfront(k: MeshKit, fx: float, out: float, za: float, zb: float, paint: String) -> void:
	## a shop window standing 0.6 m out from the house: a painted stall riser, lit glass on the front and on the two
	## cants (one of them faces the camera coming up the street), a cornice on top
	var d := 0.6
	var c := 0.5
	var xf := fx + out * d
	var pts := [Vector2(fx, za), Vector2(xf, za + c), Vector2(xf, zb - c), Vector2(fx, zb)]
	for i in 3:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var p0 := Vector3(a.x, 0.16, a.y)
		var p1 := Vector3(b.x, 0.16, b.y)
		_strip(k, paint, p0, p1, 0.16, 0.75, out)
		_strip(k, "shop_glow", p0, p1, 0.75, 2.8, out)
		_strip(k, paint, p0, p1, 2.8, 3.2, out)
		var n := maxi(1, int(p0.distance_to(p1) / 0.7))
		for j in range(1, n):
			var q := p0.lerp(p1, float(j) / n)
			k.box("wood", Vector3(q.x, 1.78, q.z), Vector3(0.06, 2.06, 0.06))
	k.box(paint, Vector3(fx + out * d * 0.5, 3.25, (za + zb) * 0.5), Vector3(d + 0.12, 0.12, zb - za + 0.1))


func _strip(k: MeshKit, m: String, a: Vector3, b: Vector3, y0: float, y1: float, out: float) -> void:
	## an upright strip from a to b (along the street) between two heights, facing the street
	var A := Vector3(a.x, y0, a.z)
	var B := Vector3(b.x, y0, b.z)
	var up := Vector3.UP * (y1 - y0)
	if out > 0.0:
		k.quad(m, B, A, A + up, B + up)
	else:
		k.quad(m, A, B, B + up, A + up)


func _stall(k: MeshKit, side: float, z: float, rng: RandomNumberGenerator) -> void:
	## a market barrow at the kerb: a table of fruit and greens under a striped canopy on poles
	var st: Array = STALLS[rng.randi() % STALLS.size()]
	var m1 := GfxWorld.paint(k, "st_" + st[0], Color(st[0]), 0.85)
	var m2 := GfxWorld.paint(k, "st_" + st[1], Color(st[1]), 0.85)
	var x := side * 5.1
	k.box("wood", Vector3(x, 0.85, z), Vector3(0.8, 0.08, 2.2))
	for e: float in [-0.95, 0.95]:
		k.box("wood", Vector3(x, 0.5, z + e), Vector3(0.7, 0.7, 0.06))
		k.box("wood", Vector3(x - side * 0.38, 1.3, z + e), Vector3(0.05, 2.3, 0.05))
	for j in 14:
		var g: String = GOODS[rng.randi() % GOODS.size()]
		GfxWorld.paint(k, "good_" + g, Color(g), 0.6)
		k.sphere("good_" + g, Vector3(x + rng.randf_range(-0.3, 0.3), 0.96, z + rng.randf_range(-1.0, 1.0)), Vector3.ONE * rng.randf_range(0.08, 0.13), 5, 3)
	var n := 6
	for j in n:
		var za := z - 1.15 + 2.3 * j / n
		var zb := z - 1.15 + 2.3 * (j + 1) / n
		var hi := Vector2(x + side * 0.45, 2.55)
		var lo := Vector2(x - side * 0.6, 2.25)
		var m := m1 if j % 2 == 0 else m2
		if side < 0:
			k.quad(m, Vector3(lo.x, lo.y, zb), Vector3(lo.x, lo.y, za), Vector3(hi.x, hi.y, za), Vector3(hi.x, hi.y, zb))
		else:
			k.quad(m, Vector3(lo.x, lo.y, za), Vector3(lo.x, lo.y, zb), Vector3(hi.x, hi.y, zb), Vector3(hi.x, hi.y, za))


func _road_mat(base: Material) -> Material:
	if _road == null:
		var b := base as BaseMaterial3D
		if b == null:
			return base
		_road = GfxWorld.shader_mat(SH + "london_cobble.gdshader", {"albedo_tex": b.albedo_texture, "normal_tex": b.normal_texture, "orm_tex": (b as ORMMaterial3D).orm_texture if b is ORMMaterial3D else null})
	return _road


func _face(k: MeshKit, m: String, x: float, y0: float, y1: float, za: float, zb: float, side: int, cells := Vector2(1, 1)) -> void:
	## a flat panel on a facade (left houses face +x, right ones -x), its UVs running left to right, top to bottom
	var uvs := [Vector2(0, cells.y), Vector2(cells.x, cells.y), Vector2(cells.x, 0), Vector2(0, 0)]
	if side < 0:
		k.quad(m, Vector3(x, y0, zb), Vector3(x, y0, za), Vector3(x, y1, za), Vector3(x, y1, zb), uvs)
	else:
		k.quad(m, Vector3(x, y0, za), Vector3(x, y0, zb), Vector3(x, y1, zb), Vector3(x, y1, za), uvs)
