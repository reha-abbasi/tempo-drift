extends RefCounted
## The studio intro (scenes/intro/intro.tscn), the web game's: a door opens, the camera walks in to a TV that reads
## "CREATIVE HOUSE · we make cool stuff", backs out, and the door closes (about 5.4 s). The first tap starts it; a
## second tap, a key or SKIP ends it. Every piece is a node and the motion is an AnimationPlayer track, so both can
## be changed in the editor.

const LEN := 5.4

var k: MeshKit


func build(_host: Node) -> void:
	var root := Node3D.new()
	root.name = "Intro"
	root.set_script(load("res://scripts/intro.gd"))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0b0907")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("ffe8d0").lerp(Color("201810"), 0.5)
	env.ambient_light_energy = 0.35
	env.fog_enabled = true
	env.fog_light_color = Color("0b0907")
	env.fog_density = 0.05
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_hdr_threshold = 0.82
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	root.add_child(we)
	var room := MeshInstance3D.new()
	room.name = "Room"
	room.mesh = room_mesh()
	root.add_child(room)
	# the door, on its hinge
	var door := Node3D.new()
	door.name = "Door"
	door.position = Vector3(-0.5, 0, 0)
	root.add_child(door)
	var leaf := MeshInstance3D.new()
	leaf.name = "Leaf"
	leaf.mesh = door_mesh()
	door.add_child(leaf)
	# light spilling under the door until it opens
	var spill := MeshInstance3D.new()
	spill.name = "Spill"
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.02)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(1.6, 1.2, 0.8)
	q.material = sm
	spill.mesh = q
	spill.position = Vector3(0, 0.012, 0.09)
	root.add_child(spill)
	# the TV's picture
	var screen := Node3D.new()
	screen.name = "TV"
	screen.position = Vector3(0, 1.06, -4.79)
	root.add_child(screen)
	var face := MeshInstance3D.new()
	face.name = "Screen"
	var fq := QuadMesh.new()
	fq.size = Vector2(1.4, 0.8)
	var fm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded;
uniform float on = 0.0;
void fragment() {
	vec3 bg = mix(vec3(0.063, 0.102, 0.227), vec3(0.039, 0.039, 0.094), UV.y);
	float scan = step(0.5, fract(UV.y * 72.0)) * 0.22;
	ALBEDO = bg * (1.0 - scan) * on;
}"""
	fm.shader = sh
	fq.material = fm
	face.mesh = fq
	screen.add_child(face)
	var house := MeshInstance3D.new()
	house.name = "House"
	house.mesh = house_mesh()
	house.position = Vector3(0, 0.12, 0.004)
	screen.add_child(house)
	for t in [["Name", "CREATIVE HOUSE", 0.11, Color("ffd2a8"), -0.13, "res://ui/font_display.tres", Color("ff78be")], ["Tagline", "we make cool stuff", 0.05, Color("bff8ff"), -0.27, "res://ui/font_mono.tres", Color("2ef2ff")]]:
		var l := Label3D.new()
		l.name = t[0]
		l.text = t[1]
		l.pixel_size = 0.0012
		l.font_size = int(t[2] / 0.0012)
		l.font = load(t[5])
		l.modulate = t[3]
		l.outline_modulate = Color(t[6], 0.6)
		l.outline_size = 10
		l.shaded = false
		l.position = Vector3(0, t[4] + 0.12, 0.006)
		l.double_sided = false
		screen.add_child(l)
	# lights: the hallway, the lamp, the TV's glow
	for L in [["Hall", Color("ffd8a8"), 2.6, 8.0, Vector3(0, 2.8, 2.6)], ["Lamp", Color("ffb870"), 2.4, 7.0, Vector3(1.65, 1.3, -4.1)], ["TVLight", Color("7ad8ff"), 0.0, 6.0, Vector3(0, 1.1, -4.2)]]:
		var o := OmniLight3D.new()
		o.name = L[0]
		o.light_color = L[1]
		o.light_energy = L[2]
		o.omni_range = L[3]
		o.position = L[4]
		o.shadow_enabled = L[0] == "Hall"
		root.add_child(o)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 55
	cam.near = 0.05
	cam.far = 40
	cam.current = true
	cam.position = Vector3(0, 1.55, 3.4)
	root.add_child(cam)
	root.add_child(anim())
	# the overlay: the fade, TAP TO START, SKIP
	var layer := CanvasLayer.new()
	layer.name = "Overlay"
	layer.layer = 5
	root.add_child(layer)
	var ui := Control.new()
	ui.name = "UI"
	ui.theme = load("res://ui/theme.tres")
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui)
	var fade := ColorRect.new()
	fade.name = "Fade"
	fade.color = Color.BLACK
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade)
	var tap := VBoxContainer.new()
	tap.name = "Tap"
	tap.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	tap.offset_left = -150
	tap.offset_right = 150
	tap.offset_top = -30
	tap.offset_bottom = 30
	tap.alignment = BoxContainer.ALIGNMENT_CENTER
	tap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(tap)
	var b := Label.new()
	b.name = "TapText"
	b.text = "TAP TO START"
	b.theme_type_variation = "Big"
	b.add_theme_font_size_override("font_size", 24)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap.add_child(b)
	var s := Label.new()
	s.name = "TapSub"
	s.text = "sound on"
	s.theme_type_variation = "Eyebrow"
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap.add_child(s)
	var skip := Button.new()
	skip.name = "Skip"
	skip.text = "SKIP ›"
	skip.theme_type_variation = "GhostButton"
	skip.focus_mode = Control.FOCUS_NONE
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.offset_left = -84
	skip.offset_right = -12
	skip.offset_top = 12
	skip.offset_bottom = 42
	ui.add_child(skip)
	if ResourceLoader.exists("res://audio/intro/intro.res"):
		var ap := AudioStreamPlayer.new()
		ap.name = "Music"
		ap.stream = load("res://audio/intro/intro.res")
		ap.volume_db = 6.0
		ap.bus = "Menu" if AudioServer.get_bus_index("Menu") >= 0 else "Master"
		root.add_child(ap)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/intro"))
	Kit.save(root, "res://scenes/intro/intro.tscn")


func mat(c: Color, rough := 0.85, metal := 0.0, emit := Color.BLACK, e := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if e > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = e
	return m


func room_mesh() -> Mesh:
	k = MeshKit.new()
	k.use("floor", load("res://materials/wood_dark.tres") if ResourceLoader.exists("res://materials/wood_dark.tres") else mat(Color("8a5a3a")), 1.2)
	k.use("wall", mat(Color("5a4636"), 0.9))
	k.use("trim", mat(Color("e8dcc8"), 0.6))
	k.use("wood", mat(Color("5a3a26"), 0.6))
	k.use("dark", mat(Color("1a1614"), 0.5, 0.3))
	k.use("rug", mat(Color("7a2e3a"), 0.95))
	k.use("rugline", mat(Color("e8c38a"), 0.9))
	k.use("shade", mat(Color("ffe0b0"), 0.8, 0.0, Color("ffb060"), 1.2))
	k.use("pot", mat(Color("b86a3a")))
	k.use("leaf", mat(Color("2e6a3a"), 0.8))
	k.use("poster", mat(Color("1c1430"), 0.6))
	k.use("sun", mat(Color("ff9a9a"), 0.6, 0.0, Color("ff8ab0"), 0.4))
	k.quad("floor", Vector3(-3, 0, 7), Vector3(3, 0, 7), Vector3(3, 0, -7), Vector3(-3, 0, -7))
	# the front wall with its doorway (1 x 2.1), the door frame
	for sx: int in [-1, 1]:
		k.box("wall", Vector3(sx * 1.8, 1.6, 0), Vector3(2.6, 3.2, 0.16))
		k.box("trim", Vector3(sx * 0.55, 1.1, 0), Vector3(0.1, 2.2, 0.22))
	k.box("wall", Vector3(0, 2.65, 0), Vector3(1, 1.1, 0.16))
	k.box("trim", Vector3(0, 2.16, 0), Vector3(1.2, 0.12, 0.22))
	# the room: walls round a 4.6 x 5 floor
	k.box("wall", Vector3(0, 1.6, -5.1), Vector3(4.6, 3.2, 0.1))
	for sx: int in [-1, 1]:
		k.box("wall", Vector3(sx * 2.35, 1.6, -2.6), Vector3(0.1, 3.2, 5))
	k.box("wall", Vector3(0, 3.25, -2.6), Vector3(4.6, 0.1, 5))
	# a rug, the TV on its cabinet, a lamp, a plant, a poster
	k.quad("rug", Vector3(-1.2, 0.005, -2.0), Vector3(1.2, 0.005, -2.0), Vector3(1.2, 0.005, -3.6), Vector3(-1.2, 0.005, -3.6))
	for inset: float in [0.12, 0.26]:
		var x0 := -1.2 + inset
		var x1 := 1.2 - inset
		var z0 := -2.0 - inset
		var z1 := -3.6 + inset
		for seg in [[Vector3(x0, 0, z0), Vector3(x1, 0, z0)], [Vector3(x0, 0, z1), Vector3(x1, 0, z1)]]:
			k.box("rugline", (seg[0] + seg[1]) / 2 + Vector3(0, 0.007, 0), Vector3(x1 - x0, 0.002, 0.035))
		for x: float in [x0, x1]:
			k.box("rugline", Vector3(x, 0.007, (z0 + z1) / 2), Vector3(0.035, 0.002, z0 - z1))
	k.bevel_box("wood", Vector3(0, 0.25, -4.75), Vector3(1.9, 0.5, 0.45), 0.05)
	k.bevel_box("dark", Vector3(0, 1.06, -4.84), Vector3(1.52, 0.92, 0.08), 0.03)
	k.bevel_box("dark", Vector3(0, 0.53, -4.8), Vector3(0.3, 0.08, 0.2), 0.03)
	k.cylinder("dark", Vector3(1.65, 0.65, -4.3), 0.045, 1.3, 10)
	k.lathe("shade", PackedVector2Array([Vector2(0.26, 1.27), Vector2(0.16, 1.57)]), Vector3(1.65, 0, -4.3), 20)
	k.lathe("pot", PackedVector2Array([Vector2(0.12, 0.0), Vector2(0.16, 0.3), Vector2(0, 0.3)]), Vector3(-1.7, 0, -4.4), 14)
	for i in 7:
		var h := fmod(sin(i * 12.9898) * 43758.5453, 1.0)
		k.sphere("leaf", Vector3(-1.7 + (absf(h) - 0.5) * 0.3, 0.45 + i * 0.1, -4.4 + (fmod(absf(h) * 7.0, 1.0) - 0.5) * 0.3), Vector3.ONE * (0.16 + absf(h) * 0.08), 12, 8)
	k.quad("poster", Vector3(-2.29, 1.27, -2.69), Vector3(-2.29, 1.27, -3.31), Vector3(-2.29, 2.13, -3.31), Vector3(-2.29, 2.13, -2.69))
	k.sphere("sun", Vector3(-2.28, 1.83, -3.0), Vector3(0.01, 0.17, 0.17), 16, 8)
	return k.bake()


func door_mesh() -> Mesh:
	k = MeshKit.new()
	k.use("door", mat(Color("7a2e22"), 0.55))
	k.use("panel", mat(Color("6a261c"), 0.5))
	k.use("brass", mat(Color("d8b060"), 0.3, 0.9))
	k.bevel_box("door", Vector3(0.5, 1.05, 0), Vector3(1, 2.1, 0.06), 0.02)
	for y in [0.55, 1.5]:
		k.bevel_box("panel", Vector3(0.5, y, 0.035), Vector3(0.66, 0.7, 0.02), 0.01)
	k.sphere("brass", Vector3(0.88, 1.02, 0.07), Vector3.ONE * 0.045, 16, 12)
	return k.bake()


func house_mesh() -> Mesh:
	## the studio's mark: a house outline in gold
	k = MeshKit.new()
	k.use("gold", mat(Color("ffd45c"), 0.5, 0.0, Color("ffd45c"), 2.2))
	var s := 0.0022
	var pts := [Vector2(-34, 92), Vector2(0, 62), Vector2(34, 92), Vector2(34, 126), Vector2(-34, 126)]
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		var ma := Vector3(a.x * s, -(a.y - 100) * s, 0)
		var mb := Vector3(b.x * s, -(b.y - 100) * s, 0)
		var d := (mb - ma)
		var n := Vector3(-d.y, d.x, 0).normalized() * 0.0055
		k.quad("gold", ma - n, mb - n, mb + n, ma + n)
	k.quad("gold", Vector3(-8 * s, -26 * s, 0), Vector3(8 * s, -26 * s, 0), Vector3(8 * s, -4 * s, 0), Vector3(-8 * s, -4 * s, 0))
	return k.bake()


func anim() -> AnimationPlayer:
	## the web game's timings: the door opens 0.4–1.4 s and closes 4.1–4.95 s; the walk in 1.1–2.7 s and out
	## 3.55–4.6 s; the TV comes on at 1.7 s
	var a := Animation.new()
	a.length = LEN
	var door := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(door, "Door:rotation:y")
	var cam := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(cam, "Camera3D:position")
	var look := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(look, ".:look")
	var tv := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tv, ".:tv_on")
	var spill := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(spill, "Spill:visible")
	var p0 := Vector3(0, 1.55, 3.4)
	var p1 := Vector3(0, 1.38, -1.2)
	var l0 := Vector3(0, 1.25, 0)
	var l1 := Vector3(0, 1.08, -4.8)
	var t := 0.0
	while t <= LEN + 0.001:
		var open := _e((t - 0.4) / 1.0) - _e((t - 4.1) / 0.85)
		var walk := _e((t - 1.1) / 1.6) - _e((t - 3.55) / 1.05)
		var p := p0.lerp(p1, walk)
		p.z -= 0.25 * _e((t - 2.7) / 0.9) * (1.0 - _e((t - 3.55) / 0.5))
		a.track_insert_key(door, t, 1.85 * open)
		a.track_insert_key(cam, t, p)
		a.track_insert_key(look, t, l0.lerp(l1, walk))
		a.track_insert_key(tv, t, _e((t - 1.7) / 0.35))
		t += 0.1
	a.value_track_set_update_mode(spill, Animation.UPDATE_DISCRETE)
	a.track_insert_key(spill, 0.0, true)
	a.track_insert_key(spill, 0.6, false)
	a.track_insert_key(spill, 4.9, true)
	var lib := AnimationLibrary.new()
	lib.add_animation("intro", a)
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	ap.add_animation_library("", lib)
	return ap


static func _e(x: float) -> float:
	return 0.0 if x <= 0.0 else (1.0 if x >= 1.0 else x * x * (3.0 - 2.0 * x))
