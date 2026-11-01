extends Node3D
## A car in flight: its paint for the era (the web game paints the car per era), engine flames that flicker and
## stretch when it climbs or drifts, and fans in the "spin" group turning.

var _t := 0.0
var _paint: StandardMaterial3D
var _strip: StandardMaterial3D
var _pods: StandardMaterial3D


func paint(body: Color, strip: Color, pods: Color) -> void:
	var mesh := ($Body as MeshInstance3D).mesh
	for i in mesh.get_surface_count():
		var mat := mesh.surface_get_material(i)
		if mat == null or mat.resource_path == "":
			continue
		var file := mat.resource_path.get_file()
		if file == "car_paint.tres":
			_paint = mat.duplicate()
			_paint.albedo_color = body
			$Body.set_surface_override_material(i, _paint)
		elif file == "car_strip.tres":
			_strip = mat.duplicate()
			_strip.albedo_color = strip
			_strip.emission = strip
			$Body.set_surface_override_material(i, _strip)
		elif file == "car_pods.tres":
			_pods = mat.duplicate()
			_pods.albedo_color = pods
			_pods.emission = pods
			$Body.set_surface_override_material(i, _pods)
	for f in find_children("Flame*", "", true, false):
		for c in f.get_children():
			var mi := c as MeshInstance3D
			if mi and mi.mesh and mi.mesh.surface_get_material(0) is ShaderMaterial:
				var sm: ShaderMaterial = mi.mesh.surface_get_material(0).duplicate()
				if sm.shader.resource_path.ends_with("flame.gdshader"):
					sm.set_shader_parameter("outer", pods)
				else:
					sm.set_shader_parameter("color", pods)
				mi.material_override = sm
	if has_node("Underglow"):
		$Underglow.light_color = pods


func motion(vel: Vector2, boost: float) -> void:
	## vel: sideways and vertical speed (m/s); boost 0..1 (Overdrive)
	_t += get_process_delta_time()
	var flick := 0.9 + 0.1 * sin(_t * 47.0) + 0.05 * sin(_t * 23.0)
	var s := (0.9 + maxf(vel.y, 0.0) * 0.08 + absf(vel.x) * 0.03 + boost * 0.6) * flick
	for f in find_children("Flame*", "", true, false):
		(f as Node3D).scale = Vector3(1, 1, s)


func _process(delta: float) -> void:
	for n in get_tree().get_nodes_in_group("spin"):
		if is_ancestor_of(n):
			(n as Node3D).rotate_y(40.0 * delta)
