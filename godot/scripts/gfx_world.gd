extends Node
class_name GfxWorld
## The city look: London 1890, Rio de Janeiro and Berlin 2075 dressed with richer
## streets, facades, props and skylines. Added to the city when a run starts: it leaves the city's scenes as they are,
## adds its own detail to each street section and to the far skyline, restyles a few materials, and hides the few old
## parts it replaces (Rio's flat sea and old palms, the old landmarks). The detail is baked into scenes beforehand
## (gfx_world_bake.gd); if a baked scene is missing it is built here instead.

## the dressed cities: city scene -> its builder
const BUILDERS := {
	"old_0": "res://scripts/gfx_world_london.gd",
	"sunset_1": "res://scripts/gfx_world_rio.gd",
	"rain_5": "res://scripts/gfx_world_berlin.gd",
}
## where the baked detail lives: <city>/section_<n>.scn and <city>/horizon.scn
const BAKED := "res://scenes/gfx_world/"

var city: City
## the city's builder (gfx_world_<city>.gd): what goes on a section and on the horizon, what to restyle
var builder: RefCounted
## Reduce effects is on: the costly parts (each detail scene's "Rich" child) stay out
var low := false
var _key := ""
## detail scene path -> its PackedScene, kept for later runs
static var _scenes := {}


static func dresses(map: String, i: int) -> bool:
	## is the city of this episode one that gets the new detail?
	return BUILDERS.has("%s_%d" % [map, i])


func setup(c: City, laid_out: Node3D, map: String, i: int, reduce: bool) -> void:
	## dress city c: the level's laid-out street (laid_out), or each section as the city places it
	city = c
	low = reduce
	_key = "%s_%d" % [map, i]
	builder = (load(BUILDERS[_key]) as GDScript).new()
	if city.horizon:
		builder.restyle_horizon(city.horizon)
		city.horizon.add_child(_detail(BAKED + _key + "/horizon.scn", func() -> Node3D: return builder.horizon()))
	if laid_out:
		for s in laid_out.get_children():
			_dress(s as Node3D)
	else:
		city.street.child_entered_tree.connect(func(n: Node) -> void: _dress.call_deferred(n as Node3D))
		for s in city.street.get_children():
			_dress(s as Node3D)


func _dress(sec: Node3D) -> void:
	## a street section: the detail for its kind (baked, or built the first time) and its restyled parts
	if sec == null or not is_instance_valid(sec) or sec.has_meta("gfx_world"):
		return
	sec.set_meta("gfx_world", true)
	var path := BAKED + _key + "/" + sec.scene_file_path.get_file().get_basename() + ".scn"
	sec.add_child(_detail(path, func() -> Node3D: return section_node(builder, sec)))
	builder.restyle(sec)


func _detail(path: String, build: Callable) -> Node3D:
	## one detail scene, its costly part left out when effects are reduced
	if not _scenes.has(path):
		if ResourceLoader.exists(path):
			_scenes[path] = load(path)
		else:
			_scenes[path] = pack(build.call())
	var n := (_scenes[path] as PackedScene).instantiate() as Node3D
	var rich := n.get_node_or_null("Rich")
	if low and rich:
		rich.free()
	return n


static func section_node(b: RefCounted, sec: Node3D) -> Node3D:
	## a section's detail as a node: "Base" and the costly "Rich" (each one merged mesh)
	var parts: Dictionary = b.section(survey(sec))
	var n := Node3D.new()
	n.name = "GfxWorld"
	for k in ["Base", "Rich"]:
		if parts.get(k) is Mesh:
			add_mesh(n, parts[k], k)
	return n


static func add_mesh(parent: Node3D, mesh: Mesh, nm: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func pack(n: Node3D) -> PackedScene:
	for c in n.find_children("*", "", true, false):
		c.owner = n
	var ps := PackedScene.new()
	ps.pack(n)
	n.free()
	return ps


static func survey(sec: Node3D) -> Dictionary:
	## what stands on a section, in its own space: each building's box and street side, and where its lamps stand
	var b := []
	for side_name in ["Left", "Right"]:
		var side := sec.get_node_or_null(side_name) as Node3D
		if side == null:
			continue
		for c in side.get_children():
			if c.name == "ShadowBlocks" or not c is Node3D:
				continue
			var box := AABB()
			var first := true
			for mi in c.find_children("*", "MeshInstance3D", true, false):
				var t := sec.global_transform.affine_inverse() * (mi as Node3D).global_transform if sec.is_inside_tree() \
					else _local(sec, mi as Node3D)
				var a: AABB = t * (mi as MeshInstance3D).get_aabb()
				box = a if first else box.merge(a)
				first = false
			if not first:
				b.append({"box": box, "side": -1 if side_name == "Left" else 1, "scene": (c as Node).scene_file_path, "name": String(c.name)})
	var lamps := []
	for c in sec.get_children():
		if c is Node3D and (c as Node).scene_file_path.ends_with("lamp.tscn"):
			lamps.append((c as Node3D).position)
	return {"buildings": b, "scene": sec.scene_file_path, "lamps": lamps}


static func _local(sec: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var p: Node = n
	while p != sec and p is Node3D:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


static func paint(kit: MeshKit, mat_name: String, col: Color, rough := 0.8, metal := 0.0, glow := 0.0) -> String:
	## a plain colour for a builder's kit (merged into one painted or one glowing surface when baked)
	if not kit.materials.has(mat_name):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = rough
		m.metallic = metal
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = col
			m.emission_energy_multiplier = glow
		kit.use(mat_name, m)
	return mat_name


static func shader_mat(path: String, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


static func vanish(n: Node) -> void:
	if n is Node3D:
		(n as Node3D).visible = false


## the letters the sign shader can draw, in the order of its pixel font
const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ-2075"


static func sign_mat(words: PackedStringArray, energy := 3.2, painted := false) -> ShaderMaterial:
	## the sign material showing these words (up to 16, six letters each; lit, or painted boards); each sign picks
	## one by its seed
	var w := PackedInt32Array()
	var n := PackedInt32Array()
	for word in words.slice(0, 16):
		var v := 0
		var t := word.substr(0, 6)
		for i in t.length():
			v |= (LETTERS.find(t[i]) + 1) << (5 * i)
		w.append(v)
		n.append(t.length())
	w.resize(16)
	n.resize(16)
	if painted:
		return shader_mat("res://materials/gfx_world/sign_painted.gdshader", {"words": w, "lens": n, "count": mini(words.size(), 16)})
	return shader_mat("res://materials/gfx_world/sign.gdshader", {"words": w, "lens": n, "count": mini(words.size(), 16), "energy": energy})
