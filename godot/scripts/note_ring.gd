@tool
extends Node3D
## A note ring. Its colour says its height (blue below the skyway, warm white on it, rose above), the chevron says
## the swipe, and the cue ring closes in to land on it just before the note: the EXCELLENT moment.
## In a level scene (scenes/levels) each ring is placed where it meets the car: its lane and height are where it
## sits, its timing is how far down the street it is. The level reads the rest of the note from these fields.

const ROW_COLORS := [Color("4aa8ff"), Color("ffe2b8"), Color("ff5a8c")]
const CUE_T := 0.6
const MOVE_BEST := 0.12

## the melody note it plays (MIDI number) and how long it rings, in eighths: the recording plays it, so these
## describe the note rather than change the sound
@export var pitch := 60
@export var length := 1
## a power-up inside the ring
@export_enum("none", "magnet", "shield", "x2") var power_up := "none"
## Flight School: the run waits at this ring until this swipe is made
@export_enum("none", "left", "right", "up", "down") var waits_for := "none"
## which of the two lead recordings plays it (Flight School); -1 alternates within the bar
@export var layer := -1

var note := {}
var _local := false
var _state := 0
var _t := 0.0
@onready var band: MeshInstance3D = $Band
@onready var fill: MeshInstance3D = $Fill
@onready var cue: MeshInstance3D = $Cue
@onready var chevron: MeshInstance3D = $Chevron
@onready var glow: OmniLight3D = $Glow


func setup(n: Dictionary) -> void:
	note = n
	var c: Color = ROW_COLORS[int(n.row)]
	if not _local:
		# its own copies, so fading one ring leaves the others
		_local = true
		for mi in [band, fill]:
			mi.material_override = (mi.mesh.surface_get_material(0) as ShaderMaterial).duplicate()
		cue.material_override = (cue.mesh.surface_get_material(0) as ShaderMaterial).duplicate()
		chevron.material_override = chevron.material_override.duplicate()
	for mi in [band, fill]:
		mi.material_override.set_shader_parameter("color", c)
	glow.light_color = c
	var d: String = n.get("dir", "")
	chevron.visible = d != ""
	chevron.rotation = Vector3(0, 0, {"R": 0.0, "L": PI, "U": PI / 2, "D": -PI / 2}.get(d, 0.0))
	var pu = n.get("pu", "")
	$Magnet.visible = pu == "magnet"
	$Shield.visible = pu == "shield"
	$Double.visible = pu == "x2"
	if pu != "" and pu != null:
		chevron.visible = false


func set_distance(d: float) -> void:
	## rings far down the street come in softly, so the horizon isn't a pile of lights
	if _state != 0:
		return
	var k := clampf(1.0 - (d - 45.0) / 110.0, 0.0, 1.0)
	for mi in [band, fill, chevron]:
		var m := mi.material_override as ShaderMaterial
		if m:
			m.set_shader_parameter("alpha", k * k)
	glow.light_energy = 0.8 * k
	visible = k > 0.01


func show_cue(song_t: float) -> void:
	## the cue ring: from far out to the band's size, landing MOVE_BEST before the note
	if _state != 0:
		cue.visible = false
		return
	var land: float = float(note.t) - MOVE_BEST
	var k := (land - song_t) / CUE_T
	cue.visible = k > -0.1 and k < 1.0
	cue.scale = Vector3.ONE * (1.0 + maxf(k, 0.0) * 1.6)
	(cue.material_override as ShaderMaterial).set_shader_parameter("alpha", clampf(1.0 - k, 0.0, 1.0) * (1.0 if k >= 0.0 else 1.0 + k * 10.0))


func played() -> void:
	_state = 1
	_t = 0.0


func missed() -> void:
	_state = 2
	_t = 0.0


func _process(delta: float) -> void:
	if _state == 0 or Engine.is_editor_hint():
		return
	_t += delta
	var k := clampf(_t / (0.22 if _state == 1 else 0.45), 0.0, 1.0)
	if _state == 1:
		# a played note flares out
		scale = Vector3.ONE * (1.0 + k * 0.9)
	else:
		# a missed one sinks and fades grey
		position.y -= delta * 2.0
		scale = Vector3.ONE * (1.0 - k * 0.4)
	for mi in [band, fill, chevron]:
		var m := mi.material_override as ShaderMaterial
		m.set_shader_parameter("alpha", (1.0 - k) * (1.0 - k))
		if _state == 2:
			m.set_shader_parameter("color", Color(0.5, 0.5, 0.55))
	glow.light_energy = 0.8 * (1.0 - k) * (3.0 if _state == 1 else 0.0)
	cue.visible = false
	if k >= 1.0:
		visible = false
