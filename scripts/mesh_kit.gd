class_name MeshKit
extends RefCounted

## Small helpers for building the placeholder art out of primitive shapes.
## Meshes and materials are cached so hundreds of coins share one resource.

static var _mats := {}
static var _meshes := {}


## Drop cached resources (called on exit so Godot doesn't report leaks).
static func clear_cache() -> void:
	_mats.clear()
	_meshes.clear()


static func mat(color: Color, roughness := 0.8, glow := 0.0, metallic := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [color.to_html(), roughness, glow, metallic]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	_mats[key] = m
	return m


static func _cached(key: String, make: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = make.call()
	return _meshes[key]


static func _add(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, rot: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, material: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := _cached("box%s" % size, func():
		var b := BoxMesh.new()
		b.size = size
		return b)
	return _add(parent, mesh, material, pos, rot)


static func sphere(parent: Node3D, radius: float, material: Material, pos := Vector3.ZERO, squash := 1.0) -> MeshInstance3D:
	var mesh := _cached("sph%.3f|%.3f" % [radius, squash], func():
		var s := SphereMesh.new()
		s.radius = radius
		s.height = radius * 2.0 * squash
		s.radial_segments = 16
		s.rings = 8
		return s)
	return _add(parent, mesh, material, pos, Vector3.ZERO)


static func cylinder(parent: Node3D, top_r: float, bottom_r: float, height: float, material: Material,
		pos := Vector3.ZERO, rot := Vector3.ZERO, sides := 12) -> MeshInstance3D:
	var mesh := _cached("cyl%.3f|%.3f|%.3f|%d" % [top_r, bottom_r, height, sides], func():
		var c := CylinderMesh.new()
		c.top_radius = top_r
		c.bottom_radius = bottom_r
		c.height = height
		c.radial_segments = sides
		c.rings = 1
		return c)
	return _add(parent, mesh, material, pos, rot)


static func torus(parent: Node3D, inner: float, outer: float, material: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := _cached("tor%.3f|%.3f" % [inner, outer], func():
		var t := TorusMesh.new()
		t.inner_radius = inner
		t.outer_radius = outer
		t.rings = 16
		t.ring_segments = 8
		return t)
	return _add(parent, mesh, material, pos, rot)
