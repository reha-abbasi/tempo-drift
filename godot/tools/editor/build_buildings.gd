extends RefCounted
## Builds the city blocks: each building is modelled once into a mesh (assets/meshes/buildings) and
## saved as its own scene (scenes/buildings/<city>/), which the street sections place.
##
## A building's front faces +Z and its origin is the bottom middle of the front wall; it runs back
## towards -Z. Streets turn them to face the road.

const MESHES := "res://assets/meshes/buildings/%s.res"
const SCENES := "res://scenes/buildings/%s/%s.tscn"

var rng := RandomNumberGenerator.new()


func build(_host: Node) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/meshes/buildings"))
	_london()


func mat(name: String) -> Material:
	return load("res://materials/%s.tres" % name)


func kit_for(wall: String, wall_tile: float, frame: String, roof: String, glass: String) -> MeshKit:
	var k := MeshKit.new()
	k.use("wall", mat(wall), wall_tile)
	k.use("side", mat(wall), wall_tile)
	k.use("trim", mat("stone_trim"), 1.0)
	k.use("frame", mat(frame), 1.0)
	k.use("glass", mat(glass), 1.0)
	k.use("roof", mat(roof), 2.0)
	k.use("metal", mat("iron"), 1.0)
	k.use("chimney", mat("brick_red"), 1.6)
	k.use("pot", mat("roof_tiles_clay"), 1.0)
	k.use("shop", mat("paint_dark_green"), 1.0)
	k.use("awning", mat("fabric_red"), 1.0)
	k.use("awning2", mat("fabric_cream"), 1.0)
	k.use("dark", mat("glass_dark"), 1.0)
	k.use("brass", mat("brass"), 1.0)
	k.use("bay", mat("wood_dark"), 1.0)
	k.use("tank", mat("wood_dark"), 1.0)
	k.use("column", mat("stone_trim"), 1.0)
	return k


# ------------------------------------------------------------------ facade pieces

func wall_with_hole(k: MeshKit, m: String, x0: float, x1: float, y0: float, y1: float, hx0: float, hx1: float, hy0: float, hy1: float) -> void:
	## the front wall of one bay and floor, around a window opening, at z = 0
	if hy0 > y0:
		k.quad(m, Vector3(x0, y0, 0), Vector3(x1, y0, 0), Vector3(x1, hy0, 0), Vector3(x0, hy0, 0))
	if y1 > hy1:
		k.quad(m, Vector3(x0, hy1, 0), Vector3(x1, hy1, 0), Vector3(x1, y1, 0), Vector3(x0, y1, 0))
	if hx0 > x0:
		k.quad(m, Vector3(x0, hy0, 0), Vector3(hx0, hy0, 0), Vector3(hx0, hy1, 0), Vector3(x0, hy1, 0))
	if x1 > hx1:
		k.quad(m, Vector3(hx1, hy0, 0), Vector3(x1, hy0, 0), Vector3(x1, hy1, 0), Vector3(hx1, hy1, 0))


func window(k: MeshKit, x0: float, x1: float, y0: float, y1: float, depth: float, opts: Dictionary) -> void:
	## a recessed window: reveals, glass, a frame with glazing bars, a sill and a lintel
	var m: String = opts.get("reveal", "wall")
	# reveals (the inside faces of the opening)
	k.quad(m, Vector3(x0, y0, 0), Vector3(x0, y0, -depth), Vector3(x0, y1, -depth), Vector3(x0, y1, 0))
	k.quad(m, Vector3(x1, y0, -depth), Vector3(x1, y0, 0), Vector3(x1, y1, 0), Vector3(x1, y1, -depth))
	k.quad(m, Vector3(x0, y1, 0), Vector3(x0, y1, -depth), Vector3(x1, y1, -depth), Vector3(x1, y1, 0))
	k.quad("trim", Vector3(x0, y0, -depth), Vector3(x0, y0, 0), Vector3(x1, y0, 0), Vector3(x1, y0, -depth))
	# glass, lit or dark behind; UV spans the pane once so the room glow sits inside it
	var lit := 1.0 if rng.randf() < float(opts.get("lit", 0.35)) else 0.0
	k.color = Color(lit, rng.randf(), 0)
	k.quad(opts.get("glass", "glass"), Vector3(x0, y0, -depth), Vector3(x1, y0, -depth), Vector3(x1, y1, -depth), Vector3(x0, y1, -depth),
		[Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	k.color = Color.WHITE
	# frame and glazing bars, just in front of the glass
	var f := 0.06
	var zf := -depth + 0.03
	var fm: String = opts.get("frame", "frame")
	k.box(fm, Vector3((x0 + x1) / 2, y0 + f / 2, zf), Vector3(x1 - x0, f, 0.06), ["-z"])
	k.box(fm, Vector3((x0 + x1) / 2, y1 - f / 2, zf), Vector3(x1 - x0, f, 0.06), ["-z"])
	k.box(fm, Vector3(x0 + f / 2, (y0 + y1) / 2, zf), Vector3(f, y1 - y0, 0.06), ["-z"])
	k.box(fm, Vector3(x1 - f / 2, (y0 + y1) / 2, zf), Vector3(f, y1 - y0, 0.06), ["-z"])
	var bars_x: int = opts.get("bars_x", 1)
	var bars_y: int = opts.get("bars_y", 2)
	for i in range(1, bars_x + 1):
		var x := lerpf(x0, x1, float(i) / (bars_x + 1))
		k.box(fm, Vector3(x, (y0 + y1) / 2, zf), Vector3(0.035, y1 - y0, 0.04), ["-z"])
	for i in range(1, bars_y + 1):
		var y := lerpf(y0, y1, float(i) / (bars_y + 1))
		var thick := 0.07 if (bars_y == 1 and opts.get("sash", true)) else 0.035  # a sash window's meeting rail is heavier
		k.box(fm, Vector3((x0 + x1) / 2, y, zf), Vector3(x1 - x0, thick, 0.04), ["-z"])
	# sill and lintel
	if opts.get("sill", true):
		k.box("trim", Vector3((x0 + x1) / 2, y0 - 0.05, 0.06), Vector3(x1 - x0 + 0.24, 0.1, 0.16), ["-z"])
	match opts.get("head", "lintel"):
		"lintel":
			k.box("trim", Vector3((x0 + x1) / 2, y1 + 0.12, 0.03), Vector3(x1 - x0 + 0.18, 0.24, 0.08), ["-z"])
		"pediment":
			k.box("trim", Vector3((x0 + x1) / 2, y1 + 0.1, 0.05), Vector3(x1 - x0 + 0.3, 0.12, 0.14), ["-z"])
			var w := (x1 - x0) / 2 + 0.2
			var cx := (x0 + x1) / 2
			k.prism("trim", PackedVector2Array([Vector2(cx - w, y1 + 0.16), Vector2(cx + w, y1 + 0.16), Vector2(cx, y1 + 0.5)]), 0.0, 0.12)
		"keystone":
			k.box("trim", Vector3((x0 + x1) / 2, y1 + 0.1, 0.03), Vector3(x1 - x0 + 0.1, 0.2, 0.06), ["-z"])
			k.box("trim", Vector3((x0 + x1) / 2, y1 + 0.14, 0.05), Vector3(0.22, 0.3, 0.1), ["-z"])


func shopfront(k: MeshKit, x0: float, x1: float, h: float, opts: Dictionary) -> void:
	## a ground-floor shop: stall riser, big glazing, a door, a painted fascia and an awning
	var sm: String = opts.get("paint", "shop")
	var riser := 0.6
	var fascia_y := h - 0.9
	# pilasters at both ends
	for x: float in [x0 + 0.18, x1 - 0.18]:
		k.box(sm, Vector3(x, h / 2, 0.08), Vector3(0.36, h, 0.16))
	# fascia board with a cornice
	k.box(sm, Vector3((x0 + x1) / 2, fascia_y + 0.35, 0.1), Vector3(x1 - x0, 0.7, 0.2))
	k.box(sm, Vector3((x0 + x1) / 2, h - 0.12, 0.22), Vector3(x1 - x0 + 0.1, 0.18, 0.44))
	# a brass name strip on the fascia
	k.box("brass", Vector3((x0 + x1) / 2, fascia_y + 0.35, 0.21), Vector3((x1 - x0) * 0.55, 0.16, 0.02))
	# riser, glazing and door
	var gx0 := x0 + 0.36
	var gx1 := x1 - 0.36
	var door_w := 1.0
	var door_left := rng.randf() < 0.5
	var dx0 := gx0 if door_left else gx1 - door_w
	var dx1 := dx0 + door_w
	var wx0 := dx1 if door_left else gx0
	var wx1 := gx1 if door_left else dx0
	k.box(sm, Vector3((wx0 + wx1) / 2, riser / 2, 0.02), Vector3(wx1 - wx0, riser, 0.1))
	k.quad("wall", Vector3(gx0, fascia_y, 0), Vector3(gx1, fascia_y, 0), Vector3(gx1, fascia_y, -0.01), Vector3(gx0, fascia_y, -0.01))
	window(k, wx0, wx1, riser, fascia_y, 0.12, {"reveal": sm, "frame": sm, "bars_x": 2, "bars_y": 1, "sill": false, "head": "none", "lit": opts.get("lit", 0.7), "sash": false})
	# the door: a dark panel with a glazed top and a brass handle
	k.box(sm, Vector3((dx0 + dx1) / 2, (fascia_y) / 2, -0.25), Vector3(door_w - 0.1, fascia_y, 0.06))
	k.color = Color(1.0 if rng.randf() < 0.6 else 0.0, rng.randf(), 0)
	k.quad("glass", Vector3(dx0 + 0.15, fascia_y * 0.55, -0.21), Vector3(dx1 - 0.15, fascia_y * 0.55, -0.21), Vector3(dx1 - 0.15, fascia_y - 0.2, -0.21), Vector3(dx0 + 0.15, fascia_y - 0.2, -0.21),
		[Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	k.color = Color.WHITE
	k.box("brass", Vector3(dx1 - 0.2 if door_left else dx0 + 0.2, fascia_y * 0.45, -0.19), Vector3(0.05, 0.05, 0.05))
	# door reveals
	k.quad(sm, Vector3(dx0, 0, 0), Vector3(dx0, 0, -0.28), Vector3(dx0, fascia_y, -0.28), Vector3(dx0, fascia_y, 0))
	k.quad(sm, Vector3(dx1, 0, -0.28), Vector3(dx1, 0, 0), Vector3(dx1, fascia_y, 0), Vector3(dx1, fascia_y, -0.28))
	k.quad(sm, Vector3(dx0, fascia_y, 0), Vector3(dx0, fascia_y, -0.28), Vector3(dx1, fascia_y, -0.28), Vector3(dx1, fascia_y, 0))
	# a striped canvas awning, sloping out over the pavement
	if opts.get("awning", true):
		var ay := fascia_y - 0.02
		var out := 1.6
		var drop := 0.7
		var stripes := int((x1 - x0) / 0.45)
		for i in stripes:
			var sx0 := lerpf(x0 + 0.05, x1 - 0.05, float(i) / stripes)
			var sx1 := lerpf(x0 + 0.05, x1 - 0.05, float(i + 1) / stripes)
			var m := "awning" if i % 2 == 0 else "awning2"
			k.quad(m, Vector3(sx0, ay - drop, out), Vector3(sx1, ay - drop, out), Vector3(sx1, ay, 0.15), Vector3(sx0, ay, 0.15))
			k.quad(m, Vector3(sx1, ay - drop, out), Vector3(sx0, ay - drop, out), Vector3(sx0, ay, 0.15), Vector3(sx1, ay, 0.15))
			# the scalloped valance hanging from the front edge
			k.quad(m, Vector3(sx0, ay - drop - 0.28, out), Vector3(sx1, ay - drop - 0.28, out), Vector3(sx1, ay - drop, out), Vector3(sx0, ay - drop, out))
			k.quad(m, Vector3(sx1, ay - drop - 0.28, out), Vector3(sx0, ay - drop - 0.28, out), Vector3(sx0, ay - drop, out), Vector3(sx1, ay - drop, out))


func front_door(k: MeshKit, x0: float, x1: float, h: float, opts: Dictionary) -> void:
	## a residential entrance: steps, a panelled door with a fanlight and a stone surround
	var cx := (x0 + x1) / 2
	var dw := 1.1
	var dh := 2.6
	var step_h := 0.18
	for i in 3:
		k.box("trim", Vector3(cx, step_h * (i + 0.5), 0.6 - i * 0.3), Vector3(dw + 0.8 - i * 0.1, step_h, 0.3 + i * 0.0))
	var base := step_h * 3
	wall_with_hole(k, "wall", x0, x1, 0, h, cx - dw / 2, cx + dw / 2, base, base + dh)
	k.box(opts.get("door_paint", "frame"), Vector3(cx, base + dh * 0.4, -0.3), Vector3(dw, dh * 0.8, 0.06))
	k.color = Color(1.0 if rng.randf() < 0.5 else 0.0, rng.randf(), 0)
	k.quad("glass", Vector3(cx - dw / 2, base + dh * 0.8, -0.3), Vector3(cx + dw / 2, base + dh * 0.8, -0.3), Vector3(cx + dw / 2, base + dh, -0.3), Vector3(cx - dw / 2, base + dh, -0.3),
		[Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	k.color = Color.WHITE
	for s: int in [-1, 1]:
		k.quad("wall", Vector3(cx + s * dw / 2, 0 if s < 0 else base, 0 if s < 0 else -0.32), Vector3(cx + s * dw / 2, base if s < 0 else 0, -0.32 if s < 0 else 0), Vector3(cx + s * dw / 2, base + dh, -0.32 if s < 0 else 0), Vector3(cx + s * dw / 2, base + dh, 0 if s < 0 else -0.32))
		k.box("trim", Vector3(cx + s * (dw / 2 + 0.16), base + dh / 2, 0.08), Vector3(0.28, dh, 0.16))
	k.quad("wall", Vector3(cx - dw / 2, base + dh, 0), Vector3(cx - dw / 2, base + dh, -0.32), Vector3(cx + dw / 2, base + dh, -0.32), Vector3(cx + dw / 2, base + dh, 0))
	k.box("trim", Vector3(cx, base + dh + 0.2, 0.12), Vector3(dw + 0.7, 0.3, 0.24))
	k.box("brass", Vector3(cx, base + dh * 0.45, -0.26), Vector3(0.12, 0.05, 0.04))


# ------------------------------------------------------------------ a whole London building

func london_building(name: String, p: Dictionary) -> void:
	classic_building("london", name, p)


var widths := {}  # style -> {name: width}


func classic_building(style: String, name: String, p: Dictionary) -> void:
	## a classical street front: shops, an arcade or a house door below; rows of windows, with balconies, bay
	## windows or brick piers by style; a cornice; and a mansard, pitched, eaved, flat or water-tank roof
	rng.seed = hash(name)
	var k := kit_for(p.wall, p.get("tile", 1.6), p.get("frame", "paint_white"), p.get("roof", "slate"), "window_warm")
	if p.has("shop_paint"):
		k.use("shop", mat(p.shop_paint), 1.0)
	if p.has("awning"):
		k.use("awning", mat(p.awning), 1.0)
	var W: float = p.width
	var D: float = p.get("depth", 11.0)
	var bays: int = p.get("bays", maxi(2, roundi(W / 2.5)))
	var g_h: float = p.get("ground", 4.4)
	var floors: int = p.floors
	var fh: float = p.get("floor_h", 3.3)
	var x0 := -W / 2
	var bw := W / bays
	var y := 0.0
	var lit: float = p.get("lit", 0.35)

	# ground floor: an arcade, shops across the front, or a house front with a door
	if p.get("arcade", false):
		_arcade(k, x0, W, bays, g_h, lit)
		y = g_h
	elif p.get("shops", true):
		var per: int = p.get("shop_bays", bays)
		var i := 0
		while i < bays:
			var n := mini(per, bays - i)
			shopfront(k, x0 + i * bw, x0 + (i + n) * bw, g_h, {"awning": p.get("awnings", true) and rng.randf() < 0.8, "lit": 0.75})
			i += n
		# the wall between the shop cornice and the first floor
		k.quad("wall", Vector3(x0, g_h, 0), Vector3(-x0, g_h, 0), Vector3(-x0, g_h + 0.3, 0), Vector3(x0, g_h + 0.3, 0))
		y = g_h + 0.3
	else:
		var door_bay := bays / 2
		for b in bays:
			var bx0 := x0 + b * bw
			var bx1 := bx0 + bw
			if b == door_bay:
				front_door(k, bx0, bx1, g_h, {"door_paint": p.get("door", "paint_black")})
			else:
				var ww := minf(1.2, bw * 0.55)
				var cx := (bx0 + bx1) / 2
				wall_with_hole(k, "wall", bx0, bx1, 0, g_h, cx - ww / 2, cx + ww / 2, 1.0, g_h - 0.8)
				window(k, cx - ww / 2, cx + ww / 2, 1.0, g_h - 0.8, 0.2, {"lit": lit, "head": "keystone"})
		y = g_h
	# a stone band over the ground floor
	k.box("trim", Vector3(0, y + 0.12, 0.1), Vector3(W + 0.1, 0.24, 0.2))

	# upper floors
	for f in floors:
		var h := fh * (1.0 - 0.06 * f)
		var top_floor := f == floors - 1
		var head: String = p.get("heads", ["pediment", "lintel", "keystone"])[mini(f, 2)]
		for b in bays:
			var bx0 := x0 + b * bw
			var bx1 := bx0 + bw
			var cx := (bx0 + bx1) / 2
			var ww := minf(p.get("win_w", 1.15), bw * 0.56)
			var wy0 := y + 0.7
			var wy1 := y + h - 0.55
			wall_with_hole(k, "wall", bx0, bx1, y, y + h, cx - ww / 2, cx + ww / 2, wy0, wy1)
			window(k, cx - ww / 2, cx + ww / 2, wy0, wy1, 0.2, {"lit": lit, "head": head, "bars_x": 1, "bars_y": 1 if not top_floor else 2})
			# iron balconettes on the first floor
			if f == 0 and p.get("balconies", false) and not p.has("balcony_floors"):
				k.box("metal", Vector3(cx, wy0 + 0.02, 0.32), Vector3(ww + 0.5, 0.06, 0.5))
				k.box("metal", Vector3(cx, wy0 + 0.55, 0.55), Vector3(ww + 0.5, 0.04, 0.04))
				for j in 9:
					k.box("metal", Vector3(cx - (ww + 0.5) / 2 + (ww + 0.5) * j / 8.0, wy0 + 0.3, 0.55), Vector3(0.025, 0.5, 0.025))
		# a continuous iron balcony right across the front (Paris: the second and fifth floors)
		if f in p.get("balcony_floors", []):
			k.box("trim", Vector3(0, y + 0.08, 0.45), Vector3(W - 0.1, 0.16, 0.9))
			k.box("metal", Vector3(0, y + 1.05, 0.88), Vector3(W - 0.1, 0.05, 0.05))
			for j in int(W / 0.22):
				k.box("metal", Vector3(x0 + 0.08 + j * 0.22, y + 0.6, 0.88), Vector3(0.025, 0.9, 0.025))
		# timber bay windows jutting over the street (Istanbul, Cairo)
		if p.get("bay_windows", false) and f < floors - 1:
			var bww := minf(W * 0.5, 4.0)
			k.box("bay", Vector3(0, y + h * 0.5, 0.55), Vector3(bww, h * 0.92, 1.1))
			for j in 3:
				var cx2 := lerpf(-bww / 2 + 0.5, bww / 2 - 0.5, j / 2.0)
				k.color = Color(1.0 if rng.randf() < lit else 0.0, rng.randf(), 0)
				k.quad("glass", Vector3(cx2 - 0.35, y + h * 0.3, 1.11), Vector3(cx2 + 0.35, y + h * 0.3, 1.11), Vector3(cx2 + 0.35, y + h * 0.85, 1.11), Vector3(cx2 - 0.35, y + h * 0.85, 1.11),
					[Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
				k.color = Color.WHITE
			k.box("trim", Vector3(0, y + 0.05, 0.6), Vector3(bww + 0.2, 0.1, 1.25))
		# brick piers running up between the bays (New York deco)
		if p.get("piers", false):
			for b in bays + 1:
				k.box("trim", Vector3(x0 + b * bw, y + h / 2, 0.12), Vector3(0.32, h, 0.24))
		y += h
		if not top_floor and p.get("bands", true):
			k.box("trim", Vector3(0, y + 0.06, 0.06), Vector3(W + 0.04, 0.12, 0.12))
		# quoins (stone blocks up the corners) on brick fronts
		if p.get("quoins", false):
			for s: int in [-1, 1]:
				for q in int(h / 0.6):
					var qw := 0.7 if q % 2 == 0 else 0.45
					k.box("trim", Vector3(s * (W / 2 - qw / 2), y - h + 0.3 + q * 0.6, 0.03), Vector3(qw, 0.54, 0.06), ["-z"])

	# the cornice and parapet
	k.box("trim", Vector3(0, y + 0.2, 0.25), Vector3(W + 0.5, 0.4, 0.5))
	k.box("trim", Vector3(0, y + 0.03, 0.12), Vector3(W + 0.24, 0.14, 0.24))
	# dentils under the cornice
	for i in int(W / 0.3):
		k.box("trim", Vector3(x0 + 0.15 + i * 0.3, y - 0.06, 0.05), Vector3(0.14, 0.14, 0.1), ["-z"])
	y += 0.4
	var parapet: float = p.get("parapet", 0.7)
	k.box("wall", Vector3(0, y + parapet / 2, -0.15), Vector3(W, parapet, 0.3))
	k.box("trim", Vector3(0, y + parapet + 0.06, -0.15), Vector3(W + 0.1, 0.12, 0.42))

	# sides and back (simple walls; neighbours usually hide them)
	k.quad("side", Vector3(x0, 0, -D), Vector3(x0, 0, 0), Vector3(x0, y, 0), Vector3(x0, y, -D))
	k.quad("side", Vector3(-x0, 0, 0), Vector3(-x0, 0, -D), Vector3(-x0, y, -D), Vector3(-x0, y, 0))
	k.quad("side", Vector3(-x0, 0, -D), Vector3(x0, 0, -D), Vector3(x0, y, -D), Vector3(-x0, y, -D))

	# the roof
	match p.get("roof_type", "mansard"):
		"mansard":
			var rh := 3.0
			var inset := 1.1
			k.quad("roof", Vector3(x0, y, -0.3), Vector3(-x0, y, -0.3), Vector3(-x0, y + rh, -0.3 - inset), Vector3(x0, y + rh, -0.3 - inset))
			k.quad("roof", Vector3(x0, y + rh, -0.3 - inset), Vector3(-x0, y + rh, -0.3 - inset), Vector3(-x0, y + rh, -D + inset), Vector3(x0, y + rh, -D + inset))
			k.quad("roof", Vector3(-x0, y, -D), Vector3(x0, y, -D), Vector3(x0, y + rh, -D + inset), Vector3(-x0, y + rh, -D + inset))
			for s: int in [-1, 1]:
				var sx := s * W / 2
				var pts := [Vector3(sx, y, -0.3), Vector3(sx, y + rh, -0.3 - inset), Vector3(sx, y + rh, -D + inset), Vector3(sx, y, -D)]
				if s > 0:
					k.quad("side", pts[0], pts[3], pts[2], pts[1])
				else:
					k.quad("side", pts[0], pts[1], pts[2], pts[3])
			# dormer windows: a stone-cheeked box with an open front, the window set into it
			for b in bays:
				var cx := x0 + (b + 0.5) * bw
				var dw := minf(1.1, bw * 0.5)
				var front := -0.45
				var back := -1.4
				var dy0 := y + 0.45
				var dy1 := y + 2.2
				var hw := dw / 2 + 0.22
				k.box("trim", Vector3(cx, (dy0 + dy1) / 2, (front + back) / 2), Vector3(hw * 2, dy1 - dy0, front - back), ["+z"])
				k.prism("roof", PackedVector2Array([Vector2(cx - hw - 0.12, dy1), Vector2(cx + hw + 0.12, dy1), Vector2(cx, dy1 + 0.55)]), back, front + 0.12)
				k.xform = Transform3D(Basis(), Vector3(0, 0, front))
				wall_with_hole(k, "trim", cx - hw, cx + hw, dy0, dy1, cx - dw / 2, cx + dw / 2, dy0 + 0.15, dy1 - 0.12)
				window(k, cx - dw / 2, cx + dw / 2, dy0 + 0.15, dy1 - 0.12, 0.14, {"lit": lit, "head": "none", "sill": false, "reveal": "trim"})
				k.xform = Transform3D.IDENTITY
		"pitched":
			var rh := 3.4
			k.quad("roof", Vector3(x0 - 0.2, y, 0.1), Vector3(-x0 + 0.2, y, 0.1), Vector3(-x0 + 0.2, y + rh, -D / 2), Vector3(x0 - 0.2, y + rh, -D / 2))
			k.quad("roof", Vector3(-x0 + 0.2, y, -D - 0.1), Vector3(x0 - 0.2, y, -D - 0.1), Vector3(x0 - 0.2, y + rh, -D / 2), Vector3(-x0 + 0.2, y + rh, -D / 2))
			for s: int in [-1, 1]:
				var sx := s * W / 2
				var tri_pts := [Vector3(sx, y, 0), Vector3(sx, y + rh, -D / 2), Vector3(sx, y, -D)]
				if s > 0:
					k.tri("side", tri_pts[0], tri_pts[2], tri_pts[1])
				else:
					k.tri("side", tri_pts[0], tri_pts[1], tri_pts[2])
		"flat":
			k.quad("roof", Vector3(x0, y, 0), Vector3(-x0, y, 0), Vector3(-x0, y, -D), Vector3(x0, y, -D))
		"eaves":
			# a low tiled roof with deep eaves over the street
			var rh := 1.8
			k.quad("roof", Vector3(x0 - 0.3, y - 0.2, 1.1), Vector3(-x0 + 0.3, y - 0.2, 1.1), Vector3(-x0 + 0.3, y + rh, -D / 2), Vector3(x0 - 0.3, y + rh, -D / 2))
			k.quad("roof", Vector3(-x0 + 0.3, y - 0.2, -D - 0.6), Vector3(x0 - 0.3, y - 0.2, -D - 0.6), Vector3(x0 - 0.3, y + rh, -D / 2), Vector3(-x0 + 0.3, y + rh, -D / 2))
			k.box("trim", Vector3(0, y - 0.25, 1.1), Vector3(W + 0.6, 0.12, 0.12))
			for sgn: int in [-1, 1]:
				var sx := sgn * (W / 2 + 0.3)
				var tri := [Vector3(sx, y - 0.2, 1.1), Vector3(sx, y + rh, -D / 2), Vector3(sx, y - 0.2, -D - 0.6)]
				if sgn > 0:
					k.tri("side", tri[0], tri[2], tri[1])
				else:
					k.tri("side", tri[0], tri[1], tri[2])
		"tank":
			# a flat roof with a timber water tank on legs (New York)
			k.quad("roof", Vector3(x0, y, 0), Vector3(-x0, y, 0), Vector3(-x0, y, -D), Vector3(x0, y, -D))
			var tx := x0 + W * (0.3 + rng.randf() * 0.4)
			for lx: float in [-0.7, 0.7]:
				for lz: float in [-0.7, 0.7]:
					k.box("metal", Vector3(tx + lx, y + 0.9, -D * 0.5 + lz), Vector3(0.1, 1.8, 0.1))
			k.lathe("tank", PackedVector2Array([Vector2(0.001, y + 1.8), Vector2(1.1, y + 1.8), Vector2(1.1, y + 3.6), Vector2(1.18, y + 3.65), Vector2(0.001, y + 4.6)]), Vector3(tx, 0, -D * 0.5), 12)
	# chimney stacks on the party walls, with clay pots
	for s: int in [-1, 1]:
		if p.get("chimneys", true) and rng.randf() < 0.85:
			var cx := s * (W / 2 - 0.5)
			var cz := -D * 0.45
			var ch := y + 3.8 + rng.randf() * 0.8
			k.box("chimney", Vector3(cx, (y + ch) / 2, cz), Vector3(0.9, ch - y, 2.2))
			k.box("trim", Vector3(cx, ch + 0.06, cz), Vector3(1.04, 0.12, 2.34))
			for j in 3:
				k.cylinder("pot", Vector3(cx, ch + 0.38, cz - 0.7 + j * 0.7), 0.13, 0.55, 8)

	_save(name, style, k)
	widths.get_or_add(style, {})[name] = p.width


func _arcade(k: MeshKit, x0: float, W: float, bays: int, h: float, lit: float) -> void:
	## a colonnade: round arches on square piers, with shops in the shade behind (Havana, Rome, Barcelona)
	var bw := W / bays
	var depth := 2.2
	k.quad("wall", Vector3(x0, 0.0, -depth), Vector3(-x0, 0.0, -depth), Vector3(-x0, h, -depth), Vector3(x0, h, -depth))
	for b in bays:
		var cx := x0 + (b + 0.5) * bw
		k.color = Color(1.0 if rng.randf() < 0.8 else 0.0, rng.randf(), 0)
		k.quad("glass", Vector3(cx - bw * 0.3, 0.3, -depth + 0.02), Vector3(cx + bw * 0.3, 0.3, -depth + 0.02), Vector3(cx + bw * 0.3, h * 0.7, -depth + 0.02), Vector3(cx - bw * 0.3, h * 0.7, -depth + 0.02),
			[Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
		k.color = Color.WHITE
	k.quad("wall", Vector3(x0, h, 0.0), Vector3(x0, h, -depth), Vector3(-x0, h, -depth), Vector3(-x0, h, 0.0))
	for b in bays + 1:
		var px := x0 + b * bw
		k.box("column", Vector3(px, h / 2, -0.25), Vector3(0.5, h, 0.5))
	# the arches: a wall over each opening with a round head cut out
	for b in bays:
		var a0 := x0 + b * bw + 0.25
		var a1 := x0 + (b + 1) * bw - 0.25
		var r := (a1 - a0) / 2.0
		var spring := h - r - 0.3
		var pts := PackedVector2Array()
		pts.append(Vector2(a0, spring))
		for i in 9:
			var a := PI - PI * i / 8.0
			pts.append(Vector2((a0 + a1) / 2 + cos(a) * r, spring + sin(a) * r))
		pts.append(Vector2(a1, spring))
		pts.append(Vector2(a1, h))
		pts.append(Vector2(a0, h))
		pts.reverse()
		k.prism("wall", pts, -0.5, 0.0)


func _save(name: String, city: String, k: MeshKit) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/buildings/" + city))
	var mesh := k.bake()
	var mpath := MESHES % name
	ResourceSaver.save(mesh, mpath)
	var root := Node3D.new()
	root.name = name.to_pascal_case()
	var mi := MeshInstance3D.new()
	mi.name = "Building"
	# streets cast the buildings' shadows from simple blocks (build_cities), which costs far less
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.mesh = load(mpath)
	mi.visibility_range_end = 250.0
	mi.visibility_range_end_margin = 30.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	root.add_child(mi)
	Kit.save(root, SCENES % [city, name])
	print("   %s: %d triangles" % [name, k.triangles()])


func _london() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/buildings/london"))
	# Portland stone fronts (Regent Street), brick terraces with stone dressings, cream stucco
	london_building("london_stone_wide", {"wall": "portland_stone", "tile": 2.2, "width": 14.0, "floors": 4, "bays": 5, "roof_type": "mansard", "frame": "paint_black", "balconies": true, "shop_bays": 1})
	london_building("london_stone_corner", {"wall": "portland_stone", "tile": 2.2, "width": 10.0, "floors": 5, "bays": 4, "roof_type": "mansard", "frame": "paint_black", "shop_paint": "paint_black", "awning": "fabric_green", "shop_bays": 2})
	london_building("london_brick_terrace", {"wall": "brick_red", "tile": 1.5, "width": 7.5, "floors": 3, "bays": 3, "roof_type": "pitched", "shops": false, "quoins": true, "door": "paint_dark_green"})
	london_building("london_brick_shops", {"wall": "brick_red", "tile": 1.5, "width": 9.0, "floors": 3, "bays": 3, "roof_type": "mansard", "quoins": true, "shop_bays": 3, "shop_paint": "paint_red", "awning": "fabric_cream"})
	london_building("london_stucco", {"wall": "plaster_cream", "tile": 3.0, "width": 8.0, "floors": 4, "bays": 3, "roof_type": "flat", "shops": false, "balconies": true, "door": "paint_black", "frame": "paint_white"})
	london_building("london_brick_tall", {"wall": "brick_patched", "tile": 1.8, "width": 11.0, "floors": 5, "bays": 4, "roof_type": "mansard", "quoins": true, "shop_bays": 2, "shop_paint": "paint_black", "awning": "fabric_navy"})
	london_building("london_stone_narrow", {"wall": "sandstone", "tile": 2.4, "width": 6.5, "floors": 4, "bays": 2, "roof_type": "pitched", "frame": "paint_white", "shop_paint": "wood_dark", "awning": "fabric_red"})
	london_building("london_stucco_shops", {"wall": "plaster_white", "tile": 3.0, "width": 12.0, "floors": 3, "bays": 4, "roof_type": "mansard", "shop_bays": 2, "shop_paint": "paint_dark_green", "awning": "fabric_cream", "balconies": true})
