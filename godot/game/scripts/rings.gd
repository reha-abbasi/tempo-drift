class_name Rings
extends Node3D
## The note rings: one glowing ring per melody note, in its height's colour, brighter as it nears and on the beat
## when it's next. An arrow shows the swipe; on the next ring a cue ring closes in at the best moment to swipe.
## A caught ring flares white-hot and shrinks into the car, as if the car swallowed it.

const POOL := 28
const CUE_T := 0.6
const VIEW := 115.0

var game: Game
var items := []
var chevron: ImageTexture
var ring_mesh: TorusMesh
var cue_mesh: TorusMesh
var disc_mesh: CylinderMesh
var arrow_mesh: QuadMesh
var mat_add: ShaderMaterial
var mat_arrow: ShaderMaterial
const CATCH_T := 0.24
var caught := []     # {m, t0, rel, col}
var caught_i := 0

func setup(g: Game) -> void:
	game = g
	chevron = _chevron_tex()
	ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.5
	ring_mesh.outer_radius = 0.62
	ring_mesh.rings = 48
	ring_mesh.ring_segments = 10
	cue_mesh = TorusMesh.new()
	cue_mesh.inner_radius = 0.54
	cue_mesh.outer_radius = 0.585
	cue_mesh.rings = 48
	cue_mesh.ring_segments = 6
	disc_mesh = CylinderMesh.new()
	disc_mesh.top_radius = 0.5
	disc_mesh.bottom_radius = 0.5
	disc_mesh.height = 0.005
	disc_mesh.radial_segments = 40
	arrow_mesh = QuadMesh.new()
	arrow_mesh.size = Vector2(0.62, 0.62)
	mat_add = ShaderMaterial.new()
	mat_add.shader = load("res://shaders/ring.gdshader")
	mat_arrow = ShaderMaterial.new()
	mat_arrow.shader = load("res://shaders/ring.gdshader")
	mat_arrow.set_shader_parameter("use_mask", true)
	mat_arrow.set_shader_parameter("mask", chevron)
	for i in POOL:
		var root := Node3D.new()
		root.visible = false
		add_child(root)
		var ring := _mi(ring_mesh, mat_add, root)
		ring.rotation.x = PI * 0.5
		var disc := _mi(disc_mesh, mat_add, root)
		disc.rotation.x = PI * 0.5
		var arrow := _mi(arrow_mesh, mat_arrow, root)
		arrow.position.z = 0.01
		var cue := _mi(cue_mesh, mat_add, root)
		cue.rotation.x = PI * 0.5
		items.append({"root": root, "ring": ring, "disc": disc, "arrow": arrow, "cue": cue, "note": null})
	for i in 6:
		var m := _mi(ring_mesh, mat_add, self)
		m.visible = false
		caught.append({"m": m, "t0": -9.0, "rel": Vector3.ZERO, "col": Color.WHITE})

func _mi(mesh: Mesh, m: Material, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

## two chevrons, the back one fainter (like the web game's arrow)
func _chevron_tex() -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for py in n:
		for px in n:
			var a := 0.0
			for k in 2:
				var x0 := 34.0 + k * 36.0
				# distance to the two strokes of a ">" from (x0, 28) to (x0 + 30, 64) to (x0, 100)
				var d := minf(_seg(Vector2(px, py), Vector2(x0, 28), Vector2(x0 + 30, 64)), _seg(Vector2(px, py), Vector2(x0 + 30, 64), Vector2(x0, 100)))
				var v := clampf((9.0 - d) / 2.0, 0.0, 1.0) * (0.55 if k == 0 else 1.0)
				a = maxf(a, v)
			img.set_pixel(px, py, Color(1, 1, 1, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var h := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (p - a - ab * h).length()

## a ring caught: it carries on from where it was, relative to the car
func catch(n: Dictionary, car_pos: Vector3) -> void:
	var c: Dictionary = caught[caught_i % caught.size()]
	caught_i += 1
	c.t0 = game.t
	c.rel = Vector3(game.LX[n.col], game.LY[n.row], -n.t * game.SPEED) - car_pos
	c.col = Game.ROW_COLORS[n.row]

func update_rings(beat_pulse: float, car_pos := Vector3.ZERO) -> void:
	var t := game.t
	for c in caught:
		var k: float = (t - c.t0) / CATCH_T
		c.m.visible = k >= 0.0 and k < 1.0
		if not c.m.visible:
			continue
		# a quick swell, then it collapses into the car
		var e := 1.0 - k
		c.m.position = car_pos + c.rel * e * e
		c.m.rotation = Vector3(PI * 0.5, 0, k * 2.0)
		c.m.scale = Vector3.ONE * (1.0 + 0.25 * sin(minf(k * 3.0, 1.0) * PI) - 0.75 * k * k)
		c.m.set_instance_shader_parameter("tint", c.col.lerp(Color.WHITE, 0.6 * e))
		c.m.set_instance_shader_parameter("glow", 4.5 * e)
	var shown := {}
	var nxt = null
	for n in game.notes:
		if n.state == 0 and n.t > t - 0.05:
			nxt = n
			break
	# notes in view, nearest first
	var want := []
	for n in game.notes:
		var z := game.note_z(n)
		if z > 3.0:
			continue
		if z < -VIEW:
			break
		if n.state == 1 or n.state == 3:
			continue
		want.append(n)
	for it in items:
		if it.note != null and not want.has(it.note):
			it.note = null
			it.root.visible = false
	for n in want:
		var it = null
		for c in items:
			if c.note == n:
				it = c
				break
		if it == null:
			for c in items:
				if c.note == null:
					it = c
					c.note = n
					break
		if it == null:
			continue
		_draw(it, n, n == nxt, beat_pulse, t)

func _draw(it: Dictionary, n: Dictionary, is_next: bool, pulse: float, t: float) -> void:
	var root: Node3D = it.root
	root.visible = true
	root.position = Vector3(game.LX[n.col], game.LY[n.row], -n.t * game.SPEED)
	var lead: float = n.t - t
	var nr := clampf(1.0 - lead / 1.4, 0.0, 1.0)
	var miss: bool = n.state == 2
	var c: Color = Game.ROW_COLORS[n.row]
	var g := 0.35 if miss else 1.25 + nr * 1.5 + (pulse * 0.9 if is_next else 0.0)
	it.ring.set_instance_shader_parameter("tint", c)
	it.ring.set_instance_shader_parameter("glow", g)
	it.disc.set_instance_shader_parameter("tint", c)
	it.disc.set_instance_shader_parameter("glow", 0.0 if miss else 0.1 + nr * 0.22)
	it.arrow.visible = n.dir != "" and not miss
	it.arrow.rotation.z = {"R": 0.0, "L": PI, "U": PI * 0.5, "D": -PI * 0.5}.get(n.dir, 0.0)
	it.arrow.set_instance_shader_parameter("tint", Color(1, 1, 1))
	it.arrow.set_instance_shader_parameter("glow", 0.9 + nr * 1.3)
	root.scale = Vector3.ONE * (1.08 if is_next else 1.0)
	var cl := lead - Game.MOVE_BEST
	var cue_on: bool = is_next and n.mv and not miss and cl > -0.05 and cl < CUE_T
	it.cue.visible = cue_on
	if cue_on:
		it.cue.scale = Vector3.ONE * (1.0 + maxf(0.0, cl) / CUE_T * 1.6)
		it.cue.set_instance_shader_parameter("tint", c)
		it.cue.set_instance_shader_parameter("glow", 0.5 + 1.8 * clampf(1.0 - cl / CUE_T, 0.0, 1.0))
