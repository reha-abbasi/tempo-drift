extends Node3D
## The run's effects. Each one is a node in run.tscn under Effects (sparkles, crash burst, smoke, speed lines,
## shield bubble, magnet aura, rescue flash); this script fires them when the rules report something.

const ROW_COLORS := [Color("4aa8ff"), Color("ffe2b8"), Color("ff5a8c")]

var _rules: Rules
var _t := 0.0
var _bump := 0.0
var _od := false
var _deliver_t := 9.0

@onready var sparkles: GPUParticles3D = $Sparkles
@onready var crash_burst: GPUParticles3D = $CrashBurst
@onready var smoke: GPUParticles3D = $Smoke
@onready var speed_lines: GPUParticles3D = $SpeedLines
@onready var shield: MeshInstance3D = $Shield
@onready var magnet: MeshInstance3D = $Magnet
@onready var rescue: MeshInstance3D = $Rescue


func _ready() -> void:
	speed_lines.emitting = false
	shield.visible = false
	magnet.visible = false
	rescue.visible = false


func follow(camera: Camera3D, ride: Node3D, rules: Rules) -> void:
	_rules = rules
	var dt := get_process_delta_time()
	_t += dt
	speed_lines.global_position = camera.global_position + camera.global_basis * Vector3(0, 0, -16)
	speed_lines.global_basis = camera.global_basis
	shield.global_position = ride.global_position
	shield.visible = rules.shield_on and ride.visible
	shield.scale = Vector3.ONE * (1.0 + 0.04 * sin(_t * 6.0))
	magnet.global_position = ride.global_position
	magnet.visible = rules.magnet_t > 0.0 and ride.visible
	magnet.rotation.y = _t * 2.0
	if magnet.visible and rules.magnet_t < 2.0:
		magnet.visible = fmod(rules.magnet_t, 0.3) < 0.2
	_deliver_t += dt
	rescue.visible = _deliver_t < 0.6
	if rescue.visible:
		rescue.global_position = ride.global_position
		rescue.scale = Vector3.ONE * (0.5 + _deliver_t * 4.0)
		(rescue.material_override as ShaderMaterial).set_shader_parameter("alpha", 1.0 - _deliver_t / 0.6)
	_bump = move_toward(_bump, 0.0, dt * 6.0)


func catch(at: Vector3, row: int) -> void:
	## a played note: a burst of glints in the ring's colour
	var p := sparkles.duplicate() as GPUParticles3D
	add_child(p)
	p.global_position = at
	p.draw_pass_1 = p.draw_pass_1.duplicate()
	var m := (p.draw_pass_1.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.albedo_color = ROW_COLORS[row].lerp(Color.WHITE, 0.25) * 1.6
	p.draw_pass_1.surface_set_material(0, m)
	p.amount = 8 if Save.data.settings.get("fx_low", false) else 16
	p.emitting = true
	p.finished.connect(p.queue_free)


func crash(at: Vector3, _form: int) -> void:
	for src in [crash_burst, smoke]:
		var p := (src as GPUParticles3D).duplicate() as GPUParticles3D
		add_child(p)
		p.global_position = at
		p.emitting = true
		p.finished.connect(p.queue_free)


func shield_hit(at: Vector3) -> void:
	var p := sparkles.duplicate() as GPUParticles3D
	add_child(p)
	p.global_position = at
	(p.draw_pass_1.surface_get_material(0) as StandardMaterial3D).albedo_color = Color("2ef2ff") * 2.4
	p.emitting = true
	p.finished.connect(p.queue_free)


func delivered(_at: Vector3, _form: int) -> void:
	_deliver_t = 0.0


func power_up(at: Vector3, _k: String) -> void:
	catch(at, 1)


func overdrive(on: bool) -> void:
	_od = on
	speed_lines.emitting = on and not Save.data.settings.get("fx_low", false)


func edge_bump(_dir: int) -> void:
	_bump = 1.0


func moved(_dc: int, _dr: int) -> void:
	pass
