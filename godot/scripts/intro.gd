extends Node3D
## The studio intro: waits for the first tap (which also lets the sound start), plays, and hands over to the menus.
## A second tap, a key or SKIP ends it early. The motion is the AnimationPlayer's "intro" track.

signal finished

const LEN := 5.4

## where the camera looks (animated)
@export var look := Vector3(0, 1.25, 0)
## the TV's picture, 0 off .. 1 on (animated)
@export var tv_on := 0.0

var _waiting := true
var _done := false


func _ready() -> void:
	$Overlay/UI/Skip.pressed.connect(_end)
	$Overlay/UI/Fade.color.a = 1.0
	$Camera3D.look_at(look)
	$Camera3D.current = true


func _process(_delta: float) -> void:
	if _done:
		return
	$Camera3D.look_at(look)
	var flick := 0.92 + 0.08 * sin(Time.get_ticks_msec() * 0.04)
	($TV/Screen.mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter("on", tv_on * flick)
	for n in ["House", "Name", "Tagline"]:
		$TV.get_node(n).visible = tv_on > 0.05
		if $TV.get_node(n) is Label3D:
			$TV.get_node(n).modulate.a = tv_on
	$TVLight.light_energy = tv_on * 2.4
	if _waiting:
		$Overlay/UI/Fade.color.a = 0.55
		return
	var T: float = $AnimationPlayer.current_animation_position
	$Overlay/UI/Fade.color.a = maxf(1.0 - T / 0.35, _e((T - (LEN - 0.45)) / 0.45))
	if not $AnimationPlayer.is_playing():
		_end()


func _unhandled_input(e: InputEvent) -> void:
	var tap: bool = (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed) or (e is InputEventKey and e.pressed)
	if not tap or _done:
		return
	if _waiting:
		_waiting = false
		$Overlay/UI/Tap.visible = false
		$AnimationPlayer.play("intro")
		if has_node("Music"):
			$Music.play()
	else:
		_end()


func _end() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()


static func _e(x: float) -> float:
	return 0.0 if x <= 0.0 else (1.0 if x >= 1.0 else x * x * (3.0 - 2.0 * x))
