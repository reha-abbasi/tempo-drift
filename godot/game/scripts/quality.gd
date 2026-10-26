class_name Quality
extends Node
## Picture quality, three levels. Phones start on Medium and computers on High; while you play, if the frame rate
## stays under 50 for a few seconds the game steps down a level (once every few seconds, never back up by itself).
## A level chosen in Settings sticks; Auto lets the game decide.

const NAMES := ["LOW", "MEDIUM", "HIGH"]
const SAVE := "user://settings.cfg"

var choice := -1          # -1 = auto, else a level
var level := 2
var main: Node
var _slow := 0.0
var _cool := 0.0
var _frames := 0

func setup(m: Node) -> void:
	main = m
	var cf := ConfigFile.new()
	if cf.load(SAVE) == OK:
		choice = cf.get_value("video", "quality", -1)
	level = choice if choice >= 0 else (1 if OS.has_feature("mobile") else 2)
	apply()

func set_choice(c: int) -> void:
	choice = c
	if c >= 0:
		level = c
	var cf := ConfigFile.new()
	cf.load(SAVE)
	cf.set_value("video", "quality", c)
	cf.save(SAVE)
	apply()

func label() -> String:
	return ("AUTO · " if choice < 0 else "") + NAMES[level]

func apply() -> void:
	var vp: Viewport = main.get_viewport()
	var w: World = main.world
	# the 3D picture is drawn smaller and sharpened back up (FSR) on the lower levels; the HUD always stays crisp
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if level < 2 else Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = [0.62, 0.8, 1.0][level]
	vp.fsr_sharpness = 0.3
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_2X if OS.has_feature("mobile") else Viewport.MSAA_4X][level]
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 4096][level], true)
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][level])
	if w:
		w.sun.directional_shadow_max_distance = [32.0, 50.0, 70.0][level]
		w.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if level == 0 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		w.env.glow_enabled = level > 0
		w.env.set_glow_level(4, 0.5 if level == 2 else 0.0)
		w.rain.amount = [500, 1000, 1600][level]
		w.smoke.visible = level > 0 and w.look.smoke
		w.mist.visible = level == 2
		if w.big_halos:
			w.big_halos.visible = level > 0
	if main.car:
		(main.car.get_meta("beam") as Light3D).visible = level > 0
		(main.car.get_meta("under") as Light3D).visible = level > 0
	Engine.max_fps = 60 if OS.has_feature("mobile") else 0

## called every frame while playing
func watch(dt: float) -> void:
	if choice >= 0 or level == 0:
		return
	_frames += 1
	if _frames < 120:
		return
	_cool = maxf(0.0, _cool - dt)
	_slow = _slow + dt if dt > 1.0 / 50.0 else maxf(0.0, _slow - dt * 2.0)
	if _slow > 3.0 and _cool <= 0.0:
		level -= 1
		_slow = 0.0
		_cool = 8.0
		apply()
