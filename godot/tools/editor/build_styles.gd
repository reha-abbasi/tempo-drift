extends RefCounted
## The building styles of the 24 cities, named as in the web game's looks (fac): each style is a set of buildings
## saved under scenes/buildings/<style>/, plus data/styles.json with their widths for the street builder.
##   Past: london, paris, ottoman, deco, havana. Present: glass, rio, sg, sf, sydney. Future: cyber.

const BB := preload("res://tools/editor/build_buildings.gd")

var b := BB.new()


func build(_host: Node) -> void:
	_plasters()
	_past()
	_modern()
	var f := FileAccess.open("res://data/styles.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(b.widths, "\t"))
	print("styles: ", ", ".join(b.widths.keys()))


func _plasters() -> void:
	## painted plaster in the colours of the warm cities (tinted Poly Haven plaster)
	var tex := "res://assets/polyhaven/textures/painted_plaster_wall/painted_plaster_wall_%s.jpg"
	for pair in [["plaster_rose", Color(0.95, 0.66, 0.6)], ["plaster_ochre", Color(0.95, 0.78, 0.48)], ["plaster_teal", Color(0.55, 0.82, 0.8)],
			["plaster_lemon", Color(0.98, 0.9, 0.55)], ["plaster_blue", Color(0.62, 0.74, 0.92)], ["plaster_sand", Color(0.9, 0.8, 0.64)],
			["plaster_terracotta", Color(0.86, 0.52, 0.36)], ["plaster_mint", Color(0.7, 0.9, 0.74)], ["plaster_lilac", Color(0.8, 0.7, 0.9)]]:
		var m := ORMMaterial3D.new()
		m.albedo_texture = load(tex % "albedo")
		m.albedo_color = pair[1]
		m.normal_enabled = true
		m.normal_texture = load(tex % "normal")
		m.orm_texture = load(tex % "arm")
		ResourceSaver.save(m, "res://materials/%s.tres" % pair[0])


func _past() -> void:
	var c := func(style: String, name: String, p: Dictionary): b.classic_building(style, name, p)
	# London: brick terraces and Portland stone, sash windows, slate and chimneys
	c.call("london", "london_stone_wide", {"wall": "portland_stone", "tile": 2.2, "width": 14.0, "floors": 4, "bays": 5, "roof_type": "mansard", "frame": "paint_black", "balconies": true, "shop_bays": 1})
	c.call("london", "london_brick_terrace", {"wall": "brick_red", "tile": 1.5, "width": 7.5, "floors": 3, "bays": 3, "roof_type": "pitched", "shops": false, "quoins": true, "door": "paint_dark_green"})
	c.call("london", "london_brick_shops", {"wall": "brick_red", "tile": 1.5, "width": 9.0, "floors": 3, "bays": 3, "roof_type": "mansard", "quoins": true, "shop_bays": 3, "shop_paint": "paint_red", "awning": "fabric_cream"})
	c.call("london", "london_stucco", {"wall": "plaster_cream", "tile": 3.0, "width": 8.0, "floors": 4, "bays": 3, "roof_type": "flat", "shops": false, "balconies": true, "door": "paint_black"})
	c.call("london", "london_brick_tall", {"wall": "brick_patched", "tile": 1.8, "width": 11.0, "floors": 5, "bays": 4, "roof_type": "mansard", "quoins": true, "shop_bays": 2, "shop_paint": "paint_black", "awning": "fabric_navy"})
	c.call("london", "london_stone_narrow", {"wall": "sandstone", "tile": 2.4, "width": 6.5, "floors": 4, "bays": 2, "roof_type": "pitched", "shop_paint": "wood_dark", "awning": "fabric_red"})
	# Paris (and Vienna): Haussmann fronts, cream stone, iron balconies on the 2nd and 5th floors, zinc mansards
	for i in 4:
		c.call("paris", "paris_%d" % i, {"wall": ["plaster_white", "sandstone", "portland_stone", "plaster_white"][i] if i != 0 else "plaster_cream", "tile": 2.6,
			"width": [12.0, 9.0, 14.0, 10.0][i], "floors": [5, 4, 5, 4][i], "bays": [5, 3, 6, 4][i], "roof_type": "mansard", "frame": "paint_black",
			"balcony_floors": [1, 4] if i % 2 == 0 else [1, 3], "shop_paint": ["paint_dark_green", "paint_black", "wood_dark", "paint_navy"][i], "awning": ["fabric_red", "fabric_green", "fabric_cream", "fabric_red"][i],
			"chimneys": true, "heads": ["pediment", "lintel", "lintel"], "quoins": false, "lit": 0.45})
	# Istanbul and Cairo: pastel plaster, jutting timber bay windows, low tiled roofs with deep eaves
	for i in 4:
		c.call("ottoman", "ottoman_%d" % i, {"wall": ["plaster_ochre", "plaster_rose", "plaster_sand", "plaster_teal"][i], "tile": 3.0,
			"width": [8.0, 10.0, 7.0, 9.0][i], "floors": [3, 3, 2, 3][i], "bays": [3, 3, 2, 3][i], "roof_type": "eaves", "roof": "roof_tiles_clay",
			"bay_windows": true, "frame": "wood_dark", "shop_paint": "wood_dark", "awning": ["fabric_red", "fabric_cream", "fabric_green", "fabric_red"][i],
			"chimneys": false, "bands": false, "lit": 0.4})
	# New York: tall brick and limestone with brick piers, cornices and water tanks
	for i in 4:
		c.call("deco", "deco_%d" % i, {"wall": ["brick_red", "portland_stone", "brick_patched", "sandstone"][i], "tile": 1.8,
			"width": [12.0, 14.0, 10.0, 11.0][i], "floors": [8, 10, 7, 9][i], "bays": [4, 5, 3, 4][i], "floor_h": 3.2, "roof_type": "tank", "piers": true,
			"frame": "paint_black", "shop_paint": ["paint_black", "wood_dark", "paint_dark_green", "paint_black"][i], "awning": "fabric_navy",
			"chimneys": false, "bands": false, "lit": 0.55})
	# Havana, Rome and Barcelona: pastel colonial fronts over an arcade, iron balconies, flat roofs with parapets
	for i in 5:
		c.call("havana", "havana_%d" % i, {"wall": ["plaster_teal", "plaster_lemon", "plaster_rose", "plaster_blue", "plaster_terracotta"][i], "tile": 3.0,
			"width": [9.0, 11.0, 8.0, 10.0, 12.0][i], "floors": [2, 3, 2, 3, 3][i], "bays": [3, 4, 3, 4, 4][i], "roof_type": "flat", "arcade": true,
			"ground": 4.6, "balconies": true, "frame": "paint_white", "chimneys": false, "parapet": 1.0, "lit": 0.4})


func _tower(style: String, name: String, p: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	var k := TowerKit.kit(p)
	TowerKit.tower(k, p, rng)
	var path := "res://assets/meshes/buildings/%s.res" % name
	ResourceSaver.save(k.bake(), path)
	var root := Node3D.new()
	root.name = name.to_pascal_case()
	var mi := MeshInstance3D.new()
	mi.name = "Building"
	# streets cast the buildings' shadows from simple blocks (build_cities), which costs far less
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.mesh = load(path)
	mi.visibility_range_end = 520.0
	root.add_child(mi)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/buildings/" + style))
	Kit.save(root, "res://scenes/buildings/%s/%s.tscn" % [style, name])
	b.widths.get_or_add(style, {})[name] = p.width
	print("   %s: %d triangles" % [name, k.triangles()])


func _modern() -> void:
	var c := func(style: String, name: String, p: Dictionary): b.classic_building(style, name, p)
	# Dubai: glass and sandstone towers with fins, bands, halos and spires
	_tower("glass", "glass_fins", {"width": 16.0, "floors": 22, "curtain": "curtain_dubai", "detail": "fins", "fin": "stone_trim_warm", "crown": "halo", "led": "led_gold"})
	_tower("glass", "glass_gold", {"width": 20.0, "floors": 30, "curtain": "curtain_dubai_gold", "detail": "bands", "band_every": 4, "fin": "paint_gold", "stages": [0.5, 0.3, 0.2], "step": 2.2, "crown": "spire", "spire": 20.0, "led": "led_gold"})
	_tower("glass", "glass_silver", {"width": 15.0, "floors": 26, "curtain": "curtain_dubai_silver", "detail": "bands", "band_every": 1, "fin": "paint_silver", "crown": "helipad", "led": "led_white"})
	_tower("glass", "glass_stone", {"width": 18.0, "floors": 10, "curtain": "curtain_dubai", "detail": "mashrabiya", "fin": "stone_trim_warm", "crown": "flat", "led": "led_gold"})
	_tower("glass", "glass_slim", {"width": 12.0, "floors": 36, "curtain": "curtain_dubai_silver", "detail": "fins", "fin": "paint_white", "stages": [0.7, 0.3], "step": 1.4, "crown": "spire", "spire": 26.0, "led": "led_white"})
	# Rio and Cape Town: low pastel modernist blocks with balconies and flat roofs
	for i in 4:
		c.call("rio", "rio_%d" % i, {"wall": ["plaster_mint", "plaster_white", "plaster_ochre", "plaster_blue"][i], "tile": 3.0, "width": [10.0, 12.0, 9.0, 11.0][i],
			"floors": [3, 5, 4, 3][i], "bays": [4, 5, 3, 4][i], "roof_type": "flat", "balcony_floors": [1, 2, 3], "frame": "paint_white",
			"shop_paint": "paint_white", "awning": ["fabric_green", "fabric_red", "fabric_navy", "fabric_cream"][i], "chimneys": false, "heads": ["none", "none", "none"], "lit": 0.4})
	# Singapore: towers with lit crowns and garden terraces
	_tower("sg", "sg_crown", {"width": 18.0, "floors": 28, "curtain": "curtain_dubai_silver", "detail": "bands", "band_every": 2, "fin": "paint_white", "stages": [0.6, 0.4], "step": 2.4, "crown": "halo", "led": "led_cyan"})
	_tower("sg", "sg_fins", {"width": 14.0, "floors": 24, "curtain": "curtain_dubai", "detail": "fins", "fin": "paint_white", "crown": "spire", "spire": 12.0, "led": "led_white"})
	_tower("sg", "sg_low", {"width": 20.0, "floors": 8, "curtain": "curtain_dubai_silver", "detail": "bands", "band_every": 1, "fin": "leaves", "crown": "flat", "led": "led_white"})
	_tower("sg", "sg_tall", {"width": 13.0, "floors": 40, "curtain": "curtain_dubai_silver", "detail": "fins", "fin": "paint_silver", "stages": [0.75, 0.25], "step": 1.5, "crown": "helipad", "led": "led_cyan"})
	# San Francisco: painted Victorians with bay windows, and a few towers behind
	for i in 4:
		c.call("sf", "sf_%d" % i, {"wall": ["plaster_lilac", "plaster_lemon", "plaster_teal", "plaster_rose"][i], "tile": 3.0, "width": [7.0, 8.0, 7.0, 8.0][i],
			"floors": 2, "bays": 2, "roof_type": "pitched", "roof": "slate", "bay_windows": true, "shops": false, "frame": "paint_white",
			"door": "paint_navy", "chimneys": false, "quoins": true, "lit": 0.5})
	_tower("sf", "sf_tower", {"width": 16.0, "floors": 24, "curtain": "curtain_dubai_silver", "detail": "bands", "band_every": 1, "fin": "concrete_panels", "crown": "flat", "led": "led_white"})
	# Sydney and Reykjavik: modern mid-rise in sandstone and glass
	_tower("sydney", "syd_0", {"width": 16.0, "floors": 12, "curtain": "curtain_dubai_silver", "detail": "fins", "fin": "sandstone", "crown": "flat", "led": "led_white", "podium_mat": "sandstone"})
	_tower("sydney", "syd_1", {"width": 14.0, "floors": 16, "curtain": "curtain_dubai", "detail": "bands", "band_every": 1, "fin": "concrete_panels", "crown": "halo", "led": "led_white"})
	_tower("sydney", "syd_2", {"width": 18.0, "floors": 9, "curtain": "curtain_dubai_silver", "detail": "bands", "band_every": 3, "fin": "sandstone", "crown": "flat", "led": "led_gold", "podium_mat": "sandstone"})
	_tower("sydney", "syd_3", {"width": 12.0, "floors": 20, "curtain": "curtain_dubai_silver", "detail": "fins", "fin": "paint_white", "crown": "spire", "spire": 10.0, "led": "led_white"})
	# the Future: dark towers crowded with neon signs
	var neon := {"podium_mat": "concrete_panels", "shop": "window_neon", "canopy": "paint_graphite"}
	_tower("cyber", "cyber_a", neon.merged({"width": 14.0, "floors": 26, "curtain": "curtain_tokyo", "detail": "bands", "band_every": 3, "fin": "paint_graphite", "neon": 6, "crown": "halo", "led": "led_magenta"}))
	_tower("cyber", "cyber_b", neon.merged({"width": 12.0, "floors": 34, "curtain": "curtain_tokyo_warm", "detail": "fins", "fin": "paint_black_gloss", "neon": 7, "crown": "spire", "spire": 18.0, "led": "led_cyan"}))
	_tower("cyber", "cyber_wide", neon.merged({"width": 20.0, "floors": 22, "curtain": "curtain_tokyo", "detail": "bands", "band_every": 1, "fin": "paint_graphite", "neon": 8, "stages": [0.6, 0.4], "step": 2.0, "crown": "helipad", "led": "led_cyan"}))
	_tower("cyber", "cyber_mid", neon.merged({"width": 10.0, "floors": 9, "curtain": "curtain_tokyo_warm", "detail": "bands", "band_every": 1, "fin": "concrete_panels", "neon": 5, "podium": 5.0, "crown": "flat", "led": "led_magenta"}))
	_tower("cyber", "cyber_slim", neon.merged({"width": 11.0, "floors": 44, "curtain": "curtain_tokyo", "detail": "fins", "fin": "paint_graphite", "neon": 5, "stages": [0.75, 0.25], "step": 1.4, "crown": "spire", "spire": 26.0, "led": "led_magenta"}))
	_tower("cyber", "cyber_mid_b", neon.merged({"width": 13.0, "floors": 12, "curtain": "curtain_tokyo_warm", "detail": "fins", "fin": "metal_plate", "neon": 7, "podium": 5.0, "crown": "halo", "led": "led_cyan"}))
