extends Node3D
## A city's set piece, kept in time with the music: the Flyer turning, fireworks two beats apart, searchlights
## sweeping, lightning every few bars, police drones crossing. The run sets `song_t` and `beat` each frame;
## without a run (the editor, menus) it keeps its own clock.

@export_enum("ferris", "fireworks", "searchlights", "lightning", "police") var kind := "ferris"
@export var beat := 0.5
@export var colors: Array[Color] = [Color("ffd45c"), Color("ff3fb4"), Color("2ef2ff"), Color("ff7a3c"), Color("b062ff"), Color.WHITE]

var song_t := -1.0
var _t := 0.0
var _last := -1
var _flash := 9.0
var _bi := 0


func _ready() -> void:
	add_to_group("deco")


func _process(delta: float) -> void:
	_t = song_t if song_t >= 0.0 else _t + delta
	match kind:
		"ferris":
			$Wheel.rotation.z = _t * 0.08
		"fireworks":
			var k := int(_t / (beat * 2.0))
			if k != _last:
				_last = k
				var b := get_child(_bi % get_child_count()) as GPUParticles3D
				_bi += 1
				b.position = Vector3((_h(k, 1) - 0.5) * 30.0, 28.0 + _h(k, 2) * 20.0, -_h(k, 3) * 40.0)
				var c: Color = colors[k % colors.size()]
				(b.draw_pass_1.surface_get_material(0) as StandardMaterial3D).albedo_color = c * 2.0
				b.restart()
		"searchlights":
			for i in get_child_count():
				var beam := get_child(i) as Node3D
				var d := Vector3(sin(_t * 0.35 + i * 2.1) * 0.55, 1.0, 0.25 + 0.15 * sin(_t * 0.27 + i)).normalized()
				beam.basis = Basis(Quaternion(Vector3.UP, d))
				beam.position = Vector3((i - 1) * 36.0, -8.0, -260.0) + d * 150.0
		"lightning":
			var k := int(_t / (beat * 4.0))
			if k != _last:
				_last = k
				if _h(k, 5) < 0.4:
					_flash = 0.0
					_bolt(k)
			_flash += delta
			var on := _flash < 0.07 or (_flash > 0.13 and _flash < 0.19)
			$Bolt.visible = on
			$Flash.light_energy = 3.0 if on else 0.0
		"police":
			for i in get_child_count():
				var d := get_child(i) as Node3D
				var z := -fposmod(i * 43.4 + _t * 9.0, 130.0) + 10.0
				d.position = Vector3([-3.6, 3.4, 0.0][i % 3] + sin(_t * 0.6 + i) * 1.1, 10.0 + i * 0.7 + sin(_t * 1.3 + i) * 0.3, z)
				var on := int(_t * 6.0 + i) % 2 == 0
				d.get_node("Red").light_energy = 3.0 if on else 0.4
				d.get_node("Blue").light_energy = 0.4 if on else 3.0


func _h(a: int, b: int) -> float:
	return fposmod(sin(a * 127.1 + b * 311.7) * 43758.5453, 1.0)


func _bolt(k: int) -> void:
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.85, 1.0, 0.95) * 3.0
	mat.disable_fog = true
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	var p := Vector3((_h(k, 6) - 0.5) * 60.0, 130.0, 0.0)
	for i in 14:
		var q := p + Vector3(randf_range(-7, 7), -9.5, 0)
		im.surface_add_vertex(p)
		im.surface_add_vertex(q)
		p = q
	im.surface_end()
	$Bolt.mesh = im
