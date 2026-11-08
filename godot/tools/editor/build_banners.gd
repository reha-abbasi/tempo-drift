extends RefCounted
## The street banners: draws each city's three banners (data/banners.json, drawn by scripts/banner_art.gd) and saves
## them as textures, assets/banners/<city>_<n>.webp; saves the art scene to try words in the editor
## (scenes/gfx_banner/banner_art.tscn) and the banner itself (scenes/gfx_ride/traffic/barrier.tscn). Needs a screen
## to draw on (not --headless):
##   xvfb-run godot --path godot --rendering-driver opengl3 res://tools/editor/runner.tscn -- build_banners
## ONLY=old_0,rain_5 draws just those cities.

const OUT := "res://assets/banners"


func build(host: Node) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/banners.json"))
	var only := OS.get_environment("ONLY").split(",", false)
	var vp := SubViewport.new()
	vp.size = Vector2i(BannerArt.W, BannerArt.H)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(vp)
	for key in data:
		if key.begins_with("_") or (not only.is_empty() and not key in only):
			continue
		var c: Dictionary = data[key]
		for n in c.banners.size():
			var art := BannerArt.new()
			art.style = c.style
			art.cloth = Color(c.colors[0])
			art.second = Color(c.colors[1])
			art.trim = Color(c.colors[2])
			art.ink = Color(c.colors[3])
			art.top = c.banners[n][0]
			art.headline = c.banners[n][1]
			art.sub = c.banners[n][2]
			vp.add_child(art)
			for i in 3:
				await host.get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			var path := "%s/%s_%d.webp" % [OUT, key, n]
			img.save_webp(ProjectSettings.globalize_path(path), true, 0.9)
			print("drew ", path)
			art.free()
	vp.queue_free()
	_art_scene()
	_banner_scene()


func _art_scene() -> void:
	var art := BannerArt.new()
	art.name = "BannerArt"
	Kit.save(art, "res://scenes/gfx_banner/banner_art.tscn")


func _banner_scene() -> void:
	## the banner: the cloth on its hanger (the top edge, so it can sway and tear off) and the rig (masts, cable,
	## bunting), built for its lane by scripts/street_banner.gd
	var root := Node3D.new()
	root.name = "Banner"
	root.set_script(load("res://scripts/street_banner.gd"))
	var hang := Node3D.new()
	hang.name = "Hang"
	hang.position.y = StreetBanner.SIZE.y / 2.0
	root.add_child(hang)
	var cloth := MeshInstance3D.new()
	cloth.name = "Cloth"
	var pm := PlaneMesh.new()
	pm.orientation = PlaneMesh.FACE_Z
	pm.size = StreetBanner.SIZE
	pm.subdivide_width = 18
	pm.subdivide_depth = 12
	var m := ShaderMaterial.new()
	m.shader = load("res://materials/gfx_banner/banner_cloth.gdshader")
	m.set_shader_parameter("art", load("res://assets/banners/old_0_0.webp"))
	pm.material = m
	cloth.mesh = pm
	cloth.position.y = -StreetBanner.SIZE.y / 2.0
	cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hang.add_child(cloth)
	var rig := MeshInstance3D.new()
	rig.name = "Rig"
	rig.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(rig)
	Kit.save(root, "res://scenes/gfx_ride/traffic/barrier.tscn")
	# the old roadblock's place (the cities' traffic lists and the level scenes point here) shows the banner too
	var wrap := (load("res://scenes/gfx_ride/traffic/barrier.tscn") as PackedScene).instantiate()
	wrap.name = "Barrier"
	var ps := PackedScene.new()
	ps.pack(wrap)
	ResourceSaver.save(ps, "res://scenes/traffic/barrier.tscn")
	wrap.free()
	print("saved res://scenes/traffic/barrier.tscn")
