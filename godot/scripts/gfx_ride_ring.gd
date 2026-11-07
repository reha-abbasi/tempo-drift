extends Node3D
## A note ring in the new look (scenes/gfx_ride/note_ring.tscn): the same note, timing
## and calls as scripts/note_ring.gd, drawn by one shader (materials/gfx_ride/ride_ring.gdshader): a glowing band in
## its height's colour (blue low, cream on the skyway, pink high) with a soft inside, the move's chevron, the cue ring
## closing in and flashing as it lands, a white burst when the note is played and a grey broken ring when it's missed.

const ROW_COLORS := [Color("3d9bff"), Color("ffc670"), Color("ff4f8f")]
const CUE_T := 0.6
const MOVE_BEST := 0.12
const DIRS := {"R": 0.0, "L": PI, "U": PI / 2, "D": -PI / 2}

var note := {}
var _state := 0
var _t := 0.0
var _alpha := 1.0
@onready var disc: MeshInstance3D = $Disc
@onready var cue: MeshInstance3D = $Cue
@onready var glow: OmniLight3D = $Glow


func setup(n: Dictionary) -> void:
	note = n
	var c: Color = ROW_COLORS[int(n.row)]
	disc.set_instance_shader_parameter("color", c)
	cue.set_instance_shader_parameter("color", c)
	glow.light_color = c
	var d: String = n.get("dir", "")
	var pu = n.get("pu", "")
	var has_pu: bool = pu != "" and pu != null
	disc.set_instance_shader_parameter("chev", 1.0 if d != "" and not has_pu else 0.0)
	disc.set_instance_shader_parameter("dir", DIRS.get(d, 0.0))
	$Magnet.visible = pu == "magnet"
	$Shield.visible = pu == "shield"
	$Double.visible = pu == "x2"


func set_distance(d: float) -> void:
	## rings far down the street come in softly, so the horizon isn't a pile of lights
	if _state != 0:
		return
	var k := clampf(1.0 - (d - 45.0) / 110.0, 0.0, 1.0)
	_alpha = k * k
	disc.set_instance_shader_parameter("alpha", _alpha)
	glow.light_energy = 0.8 * k
	visible = k > 0.01


func show_cue(song_t: float) -> void:
	## the cue ring: from far out to the band's size, landing MOVE_BEST before the note, with a flash as it lands
	if _state != 0:
		cue.visible = false
		return
	# passed without being played (the rules judge it a moment later): it starts to grey at once
	disc.set_instance_shader_parameter("dead", clampf((song_t - float(note.t)) / 0.15, 0.0, 1.0) * 0.6)
	var land: float = float(note.t) - MOVE_BEST
	var k := (land - song_t) / CUE_T
	cue.visible = k > -0.1 and k < 1.0
	if not cue.visible:
		return
	var s := 1.0 + maxf(k, 0.0) * 1.6
	cue.scale = Vector3.ONE * s
	cue.set_instance_shader_parameter("grow", s)
	cue.set_instance_shader_parameter("land", clampf(1.0 - absf(k) / 0.12, 0.0, 1.0))
	cue.set_instance_shader_parameter("alpha", clampf(1.0 - k, 0.0, 1.0) * (1.0 if k >= 0.0 else 1.0 + k * 10.0))


func played() -> void:
	_state = 1
	_t = 0.0
	disc.set_instance_shader_parameter("dead", 0.0)
	cue.visible = false
	for n in ["Magnet", "Shield", "Double"]:
		(get_node(n) as Node3D).visible = false


func missed() -> void:
	_state = 2
	_t = 0.0
	cue.visible = false


func _process(delta: float) -> void:
	if _state == 0:
		return
	_t += delta
	if _state == 1:
		# a played note flares out white and throws off a shock ring
		var k := clampf(_t / 0.22, 0.0, 1.0)
		disc.set_instance_shader_parameter("pop", k)
		glow.light_energy = 2.6 * (1.0 - k)
		if k >= 1.0:
			visible = false
	else:
		# a missed one turns grey, breaks up, sinks and fades
		var k := clampf(_t / 0.42, 0.0, 1.0)
		disc.set_instance_shader_parameter("dead", 0.6 + 0.4 * minf(1.0, _t / 0.1))
		disc.set_instance_shader_parameter("alpha", _alpha * (1.0 - smoothstep(0.35, 1.0, k)))
		position.y -= delta * 2.0
		scale = Vector3.ONE * (1.0 - k * 0.3)
		glow.light_energy = 0.0
		for n in ["Magnet", "Shield", "Double"]:
			(get_node(n) as Node3D).visible = false
		if k >= 1.0:
			visible = false
