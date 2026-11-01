class_name TowerKit
extends RefCounted
## Modern towers for the Present and the Future. A tower's street front faces +Z and its origin is
## the bottom middle of the front; curtain walls are single surfaces drawn by the window shader.


static func m(name: String) -> Material:
	return load("res://materials/%s.tres" % name)


static func curtain(k: MeshKit, mat: String, a: Vector3, b: Vector3, h: float, bay: float, fh: float, lit: float) -> void:
	## a curtain wall from a to b (along the ground, left to right seen from outside), h tall
	var w := a.distance_to(b)
	k.color = Color(lit, 0.5, 1.0)
	k.quad(mat, a, b, b + Vector3.UP * h, a + Vector3.UP * h, [Vector2(0, h / fh), Vector2(w / bay, h / fh), Vector2(w / bay, 0), Vector2(0, 0)])
	k.color = Color.WHITE


static func block(k: MeshKit, mat: String, x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, bay: float, fh: float, lit: float, roof := "roof") -> void:
	## a box clad in curtain wall on four sides (z0 front, z1 back), with a flat roof
	var h := y1 - y0
	curtain(k, mat, Vector3(x0, y0, z0), Vector3(x1, y0, z0), h, bay, fh, lit)
	curtain(k, mat, Vector3(x1, y0, z0), Vector3(x1, y0, z1), h, bay, fh, lit)
	curtain(k, mat, Vector3(x1, y0, z1), Vector3(x0, y0, z1), h, bay, fh, lit)
	curtain(k, mat, Vector3(x0, y0, z1), Vector3(x0, y0, z0), h, bay, fh, lit)
	k.quad(roof, Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1))


static func tower(k: MeshKit, p: Dictionary, rng: RandomNumberGenerator) -> void:
	var W: float = p.width
	var D: float = p.get("depth", 18.0)
	var fh: float = p.get("floor_h", 3.6)
	var bay: float = p.get("bay", 1.6)
	var wall: String = p.get("wall", "curtain")
	var lit: float = p.get("lit", 0.3)
	var x0 := -W / 2
	var x1 := W / 2

	# podium: shopfronts behind a canopy, a stone or metal band above with an LED line
	var ph: float = p.get("podium", 9.0)
	k.box("podium", Vector3(0, ph / 2, -D / 2), Vector3(W, ph, D), ["+z", "-y"])
	k.color = Color(0.8, 0.5, 1.0)
	k.quad("shop", Vector3(x0 + 0.4, 0.1, 0.0), Vector3(x1 - 0.4, 0.1, 0.0), Vector3(x1 - 0.4, 4.2, 0.0), Vector3(x0 + 0.4, 4.2, 0.0),
		[Vector2(0, 1), Vector2((W - 0.8) / 2.2, 1), Vector2((W - 0.8) / 2.2, 0), Vector2(0, 0)])
	k.color = Color.WHITE
	k.quad("podium", Vector3(x0, 0, 0.0), Vector3(x0 + 0.4, 0, 0.0), Vector3(x0 + 0.4, ph, 0.0), Vector3(x0, ph, 0.0))
	k.quad("podium", Vector3(x1 - 0.4, 0, 0.0), Vector3(x1, 0, 0.0), Vector3(x1, ph, 0.0), Vector3(x1 - 0.4, ph, 0.0))
	k.quad("podium", Vector3(x0 + 0.4, 4.2, 0.0), Vector3(x1 - 0.4, 4.2, 0.0), Vector3(x1 - 0.4, ph, 0.0), Vector3(x0 + 0.4, ph, 0.0))
	# upper podium floors: windows set into the band
	if ph > 7.0:
		curtain(k, "glass", Vector3(x0 + 0.8, 5.0, 0.02), Vector3(x1 - 0.8, 5.0, 0.02), ph - 6.0, bay, fh, lit)
	k.bevel_box("canopy", Vector3(0, 4.45, 1.0), Vector3(W - 0.2, 0.28, 2.2), 0.05)
	k.box("led", Vector3(0, 4.3, 2.08), Vector3(W - 0.4, 0.05, 0.04))
	k.box("led", Vector3(0, ph - 0.25, 0.04), Vector3(W - 0.8, 0.08, 0.06))

	# the shaft: set back from the street, stepping in as it rises
	var floors: int = p.floors
	var setback: float = p.get("setback", 1.5)
	var y := ph
	var stages: Array = p.get("stages", [1.0])
	var inset := 0.0
	var remaining := floors
	for si in stages.size():
		var n: int = int(round(floors * stages[si])) if si < stages.size() - 1 else remaining
		remaining -= n
		var sx0 := x0 + 0.6 + inset
		var sx1 := x1 - 0.6 - inset
		var sz0 := -setback - inset * 0.6
		var sz1 := -D + 0.6 + inset * 0.6
		var top := y + n * fh
		block(k, wall, sx0, sx1, sz0, sz1, y, top, bay, fh, lit)
		match p.get("detail", "none"):
			"fins":
				var nf := int((sx1 - sx0) / (bay * 2.0))
				for i in nf + 1:
					var fx := lerpf(sx0, sx1, float(i) / nf)
					k.box("fin", Vector3(fx, (y + top) / 2, sz0 + 0.25), Vector3(0.18, top - y, 0.5))
			"bands":
				for f in range(0, n + 1, int(p.get("band_every", 1))):
					k.box("fin", Vector3((sx0 + sx1) / 2, y + f * fh, sz0 + 0.18), Vector3(sx1 - sx0 + 0.3, 0.22, 0.36))
			"mashrabiya":
				# a carved screen over every other bay: a lattice of thin stone bars
				var nb := int((sx1 - sx0) / bay)
				for i in range(1, nb, 3):
					var bx := sx0 + (i + 0.5) * bay
					for f in range(0, n, 2):
						var by := y + f * fh + 0.6
						for j in 4:
							k.box("fin", Vector3(bx, by + j * fh * 0.5, sz0 + 0.12), Vector3(bay * 0.9, 0.05, 0.08))
							k.box("fin", Vector3(bx - bay * 0.45 + j * bay * 0.3, by + fh, sz0 + 0.12), Vector3(0.05, fh * 2.0, 0.08))
		# an LED line where each stage steps back
		k.box("led", Vector3((sx0 + sx1) / 2, top - 0.15, sz0 + 0.06), Vector3(sx1 - sx0, 0.1, 0.06))
		y = top
		inset += p.get("step", 1.6)

	# crown: a parapet, plant on the roof, and perhaps a spire
	var cw: float = W - 1.2 - (inset - float(p.get("step", 1.6))) * 2.0
	k.box("fin", Vector3(0, y + 0.6, -D / 2), Vector3(cw * 0.6, 1.2, (D - setback) * 0.5))
	match p.get("crown", "flat"):
		"spire":
			k.lathe("fin", PackedVector2Array([Vector2(0.6, y + 1.2), Vector2(0.25, y + 1.2 + p.get("spire", 14.0) * 0.7), Vector2(0.0, y + 1.2 + p.get("spire", 14.0))]), Vector3(0, 0, -D / 2), 8)
			k.sphere("tip", Vector3(0, y + 1.3 + p.get("spire", 14.0), -D / 2), Vector3(0.25, 0.25, 0.25), 8, 6)
		"halo":
			var r := minf(cw, D - setback) * 0.4
			k.lathe("led", PackedVector2Array([Vector2(r, y + 2.0), Vector2(r + 0.3, y + 2.0), Vector2(r + 0.3, y + 2.4), Vector2(r, y + 2.4)]), Vector3(0, 0, -D / 2), 24)
		"helipad":
			k.cylinder("fin", Vector3(0, y + 1.5, -D / 2), minf(cw, D) * 0.35, 0.4, 20)
			k.lathe("led", PackedVector2Array([Vector2(minf(cw, D) * 0.33, y + 1.72), Vector2(minf(cw, D) * 0.35, y + 1.72)]), Vector3(0, 0, -D / 2), 24, false)

	# neon boards down the front (the Future)
	if p.get("neon", 0) > 0:
		for i in int(p.neon):
			var sx := lerpf(x0 + 1.2, x1 - 1.2, rng.randf())
			var sy := ph + rng.randf_range(1.0, 22.0)
			var sh := rng.randf_range(5.0, 11.0)
			var sw := rng.randf_range(1.2, 1.8)
			var mat := "neon%d" % rng.randi_range(0, 5)
			# a vertical sign standing off the wall on brackets, readable from down the street
			k.box("frame", Vector3(sx, sy + sh / 2, 0.55), Vector3(0.12, sh, 0.12))
			var a := Vector3(sx, sy, 0.62)
			var b := Vector3(sx, sy, 0.62 + sw)
			k.quad(mat, b, a, a + Vector3.UP * sh, b + Vector3.UP * sh, [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
			k.quad(mat, a, b, b + Vector3.UP * sh, a + Vector3.UP * sh, [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
		# a big billboard over the podium
		if rng.randf() < 0.6:
			var bw := minf(W - 2.0, 10.0)
			var mat2 := "neon%d" % rng.randi_range(0, 5)
			k.quad(mat2, Vector3(-bw / 2, ph + 0.8, 0.3), Vector3(bw / 2, ph + 0.8, 0.3), Vector3(bw / 2, ph + 5.0, 0.3), Vector3(-bw / 2, ph + 5.0, 0.3),
				[Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])


static func kit(p: Dictionary) -> MeshKit:
	var k := MeshKit.new()
	k.use("curtain", m(p.get("curtain", "curtain_dubai")), 1.0)
	k.use("glass", m(p.get("curtain", "curtain_dubai")), 1.0)
	k.use("shop", m(p.get("shop", "window_cool")), 1.0)
	k.use("podium", m(p.get("podium_mat", "sandstone")), 2.5)
	k.use("canopy", m(p.get("canopy", "paint_white")), 1.0)
	k.use("fin", m(p.get("fin", "stone_trim_warm")), 1.0)
	k.use("roof", m("concrete_panels"), 4.0)
	k.use("led", m(p.get("led", "led_white")), 1.0)
	k.use("tip", m("tail_glow"), 1.0)
	k.use("frame", m("iron"), 1.0)
	for i in 6:
		k.use("neon%d" % i, m("neon_%d" % i), 1.0)
	return k
