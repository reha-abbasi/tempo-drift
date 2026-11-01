class_name MeshKit
extends RefCounted
## A small modelling kit for the builders: collects triangles per material and bakes them into one
## ArrayMesh with a surface per material. UVs are in metres divided by each material's tile size,
## so photographic textures keep their real scale on every part.
##
## Hard-edged parts (boxes, extrusions) get flat normals; round parts (lathes, lofts, spheres) get
## smooth ones.

var _parts := {}  # material name -> {"v": PackedVector3Array, "n": ..., "uv": ..., "c": PackedColorArray}
var materials := {}  # material name -> Material
var tiles := {}  # material name -> metres per texture repeat
var xform := Transform3D.IDENTITY  # applied to everything added (push/pop with `at`)
var color := Color.WHITE  # vertex colour for what is added next (window glow, tinting)


func use(mat_name: String, mat: Material, tile := 1.0) -> void:
	materials[mat_name] = mat
	tiles[mat_name] = tile


func _p(mat_name: String) -> Dictionary:
	if not _parts.has(mat_name):
		_parts[mat_name] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "c": PackedColorArray()}
	return _parts[mat_name]


func tri(m: String, a: Vector3, b: Vector3, c: Vector3, na := Vector3.ZERO, nb := Vector3.ZERO, nc := Vector3.ZERO, ua := Vector2.INF, ub := Vector2.INF, uc := Vector2.INF) -> void:
	## one triangle, counter-clockwise seen from the front. Missing normals = flat; missing UVs = box-projected
	var A := xform * a
	var B := xform * b
	var C := xform * c
	var flat := (B - A).cross(C - A).normalized()
	var nm := xform.basis.inverse().transposed()
	var NA := (nm * na).normalized() if na != Vector3.ZERO else flat
	var NB := (nm * nb).normalized() if nb != Vector3.ZERO else flat
	var NC := (nm * nc).normalized() if nc != Vector3.ZERO else flat
	var t: float = tiles.get(m, 1.0)
	var p := _p(m)
	# Godot's front faces are clockwise: store b and c swapped
	for item in [[A, NA, ua], [C, NC, uc], [B, NB, ub]]:
		p.v.append(item[0])
		p.n.append(item[1])
		p.uv.append(item[2] / t if item[2] != Vector2.INF else _project(item[0], flat) / t)
		p.c.append(color)


func quad(m: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uvs := []) -> void:
	## a flat quad a-b-c-d counter-clockwise from the front
	if uvs.size() == 4:
		tri(m, a, b, c, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, uvs[0], uvs[1], uvs[2])
		tri(m, a, c, d, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, uvs[0], uvs[2], uvs[3])
	else:
		tri(m, a, b, c)
		tri(m, a, c, d)


static func _project(p: Vector3, n: Vector3) -> Vector2:
	## box projection in world metres: walls take (x or z, y), floors take (x, z)
	var an := n.abs()
	if an.y >= an.x and an.y >= an.z:
		return Vector2(p.x, p.z)
	if an.x >= an.z:
		return Vector2(p.z, -p.y)
	return Vector2(p.x, -p.y)


func box(m: String, center: Vector3, size: Vector3, skip := []) -> void:
	## an axis-aligned box (in the current transform). skip: faces to leave out, e.g. ["-y"]
	var h := size / 2.0
	var c := center
	var faces := {
		"+x": [Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z)],
		"-x": [Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, h.y, -h.z)],
		"+y": [Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z)],
		"-y": [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z)],
		"+z": [Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)],
		"-z": [Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z)],
	}
	for k in faces:
		if k in skip:
			continue
		var f: Array = faces[k]
		quad(m, c + f[0], c + f[1], c + f[2], c + f[3])


func bevel_box(m: String, center: Vector3, size: Vector3, r: float) -> void:
	## a box with chamfered edges: catches highlights the way real objects do
	var h := size / 2.0 - Vector3.ONE * r
	box(m, center, Vector3(size.x, h.y * 2, h.z * 2), ["+y", "-y", "+z", "-z"])
	box(m, center, Vector3(h.x * 2, size.y, h.z * 2), ["+x", "-x", "+z", "-z"])
	box(m, center, Vector3(h.x * 2, h.y * 2, size.z), ["+x", "-x", "+y", "-y"])
	var s: Array[int] = [-1, 1]
	for sx: int in s:
		for sy: int in s:
			# edges along z
			var a := center + Vector3(sx * h.x, sy * (h.y + r), 0)
			var b := center + Vector3(sx * (h.x + r), sy * h.y, 0)
			_strip(m, a, b, Vector3(0, 0, h.z), sx * sy > 0)
	for sx: int in s:
		for sz: int in s:
			var a := center + Vector3(sx * h.x, 0, sz * (h.z + r))
			var b := center + Vector3(sx * (h.x + r), 0, sz * h.z)
			_strip(m, a, b, Vector3(0, h.y, 0), sx * sz < 0)
	for sy: int in s:
		for sz: int in s:
			var a := center + Vector3(0, sy * h.y, sz * (h.z + r))
			var b := center + Vector3(0, sy * (h.y + r), sz * h.z)
			_strip(m, a, b, Vector3(h.x, 0, 0), sy * sz > 0)
	for sx: int in s:
		for sy: int in s:
			for sz: int in s:
				var p1 := center + Vector3(sx * (h.x + r), sy * h.y, sz * h.z)
				var p2 := center + Vector3(sx * h.x, sy * (h.y + r), sz * h.z)
				var p3 := center + Vector3(sx * h.x, sy * h.y, sz * (h.z + r))
				if sx * sy * sz > 0:
					tri(m, p1, p2, p3)
				else:
					tri(m, p1, p3, p2)


func _strip(m: String, a: Vector3, b: Vector3, half: Vector3, flip: bool) -> void:
	var q := [a - half, b - half, b + half, a + half]
	if flip:
		quad(m, q[0], q[1], q[2], q[3])
	else:
		quad(m, q[3], q[2], q[1], q[0])


func lathe(m: String, profile: PackedVector2Array, center: Vector3, segments := 16, smooth := true, uv_v := 1.0) -> void:
	## turns a profile [(radius, height), ...] (bottom to top) around the Y axis
	var n := profile.size()
	for i in n - 1:
		var p0 := profile[i]
		var p1 := profile[i + 1]
		for s in segments:
			var a0 := TAU * s / segments
			var a1 := TAU * (s + 1) / segments
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var v00 := center + d0 * p0.x + Vector3.UP * p0.y
			var v01 := center + d1 * p0.x + Vector3.UP * p0.y
			var v10 := center + d0 * p1.x + Vector3.UP * p1.y
			var v11 := center + d1 * p1.x + Vector3.UP * p1.y
			var slope := Vector2(p1.y - p0.y, -(p1.x - p0.x)).normalized()
			var n0 := (d0 * slope.x + Vector3.UP * slope.y) if smooth else Vector3.ZERO
			var n1 := (d1 * slope.x + Vector3.UP * slope.y) if smooth else Vector3.ZERO
			var u0 := float(s) / segments * TAU * maxf(p0.x, 0.05)
			var u1 := float(s + 1) / segments * TAU * maxf(p0.x, 0.05)
			var uv00 := Vector2(u0, -p0.y * uv_v)
			var uv01 := Vector2(u1, -p0.y * uv_v)
			var uv10 := Vector2(u0, -p1.y * uv_v)
			var uv11 := Vector2(u1, -p1.y * uv_v)
			if p0.x > 0.0001:
				tri(m, v00, v10, v01, n0, n0, n1, uv00, uv10, uv01)
			if p1.x > 0.0001:
				tri(m, v01, v10, v11, n1, n0, n1, uv01, uv10, uv11)


func cylinder(m: String, center: Vector3, r: float, h: float, segments := 16, caps := true) -> void:
	var prof := PackedVector2Array()
	if caps:
		prof.append(Vector2(0, -h / 2))
		prof.append(Vector2(r, -h / 2))
	prof.append(Vector2(r, -h / 2))
	prof.append(Vector2(r, h / 2))
	if caps:
		prof.append(Vector2(r, h / 2))
		prof.append(Vector2(0, h / 2))
	# caps flat, sides smooth
	if caps:
		lathe(m, PackedVector2Array([Vector2(0, -h / 2), Vector2(r, -h / 2)]), center, segments, false)
		lathe(m, PackedVector2Array([Vector2(r, h / 2), Vector2(0, h / 2)]), center, segments, false)
	lathe(m, PackedVector2Array([Vector2(r, -h / 2), Vector2(r, h / 2)]), center, segments, true)


func sphere(m: String, center: Vector3, radius: Vector3, segments := 16, rings := 10) -> void:
	## an ellipsoid with smooth normals
	for i in rings:
		var t0 := PI * i / rings - PI / 2
		var t1 := PI * (i + 1) / rings - PI / 2
		for s in segments:
			var a0 := TAU * s / segments
			var a1 := TAU * (s + 1) / segments
			var pts := []
			for pair in [[t0, a0], [t1, a0], [t1, a1], [t0, a1]]:
				var u := Vector3(cos(pair[0]) * cos(pair[1]), sin(pair[0]), cos(pair[0]) * sin(pair[1]))
				pts.append([center + u * radius, (u / radius).normalized()])
			if i > 0:
				tri(m, pts[0][0], pts[1][0], pts[3][0], pts[0][1], pts[1][1], pts[3][1])
			if i < rings - 1:
				tri(m, pts[1][0], pts[2][0], pts[3][0], pts[1][1], pts[2][1], pts[3][1])


func loft(m: String, sections: Array, closed_ends := true, smooth := true) -> void:
	## a skin through cross-sections: each section is {"z": float, "pts": PackedVector2Array (x, y),
	## same point count, counter-clockwise seen from +z}. Builds car bodies, hulls, fuselages.
	var n: int = sections[0].pts.size()
	var normals := []
	for si in sections.size():
		var row := []
		for i in n:
			var prev: Vector2 = sections[si].pts[(i - 1 + n) % n]
			var nxt: Vector2 = sections[si].pts[(i + 1) % n]
			var tang := (nxt - prev).normalized()
			var out := Vector3(tang.y, -tang.x, 0)
			# lean the normal along z where the section is growing or shrinking
			var zs := 0.0
			if si > 0 and si < sections.size() - 1:
				var ra: float = sections[si - 1].pts[i].length()
				var rb: float = sections[si + 1].pts[i].length()
				var dz: float = sections[si + 1].z - sections[si - 1].z
				zs = -(rb - ra) / maxf(absf(dz), 0.001) * signf(dz)
			row.append((out + Vector3(0, 0, zs * 0.8)).normalized())
		normals.append(row)
	for si in sections.size() - 1:
		var a: Dictionary = sections[si]
		var b: Dictionary = sections[si + 1]
		var ua := 0.0
		for i in n:
			var j := (i + 1) % n
			var pa0 := Vector3(a.pts[i].x, a.pts[i].y, a.z)
			var pa1 := Vector3(a.pts[j].x, a.pts[j].y, a.z)
			var pb0 := Vector3(b.pts[i].x, b.pts[i].y, b.z)
			var pb1 := Vector3(b.pts[j].x, b.pts[j].y, b.z)
			var seg: float = a.pts[i].distance_to(a.pts[j])
			var uv_a0 := Vector2(ua, a.z)
			var uv_a1 := Vector2(ua + seg, a.z)
			var uv_b0 := Vector2(ua, b.z)
			var uv_b1 := Vector2(ua + seg, b.z)
			ua += seg
			if smooth:
				tri(m, pa0, pa1, pb1, normals[si][i], normals[si][j], normals[si + 1][j], uv_a0, uv_a1, uv_b1)
				tri(m, pa0, pb1, pb0, normals[si][i], normals[si + 1][j], normals[si + 1][i], uv_a0, uv_b1, uv_b0)
			else:
				quad(m, pa0, pa1, pb1, pb0)
	if closed_ends:
		for end in [0, sections.size() - 1]:
			var s: Dictionary = sections[end]
			var c := Vector2.ZERO
			for p in s.pts:
				c += p
			c /= n
			for i in n:
				var j := (i + 1) % n
				var A := Vector3(c.x, c.y, s.z)
				var B := Vector3(s.pts[i].x, s.pts[i].y, s.z)
				var C := Vector3(s.pts[j].x, s.pts[j].y, s.z)
				if end == 0:
					tri(m, A, C, B)
				else:
					tri(m, A, B, C)


func prism(m: String, outline: PackedVector2Array, z0: float, z1: float, caps := true) -> void:
	## extrudes a counter-clockwise outline in the XY plane from z0 to z1 (gables, roofs, fins)
	var n := outline.size()
	for i in n:
		var a := outline[i]
		var b := outline[(i + 1) % n]
		quad(m, Vector3(a.x, a.y, z1), Vector3(b.x, b.y, z1), Vector3(b.x, b.y, z0), Vector3(a.x, a.y, z0))
	if caps:
		var idx := Geometry2D.triangulate_polygon(outline)
		for k in range(0, idx.size(), 3):
			var A := outline[idx[k]]
			var B := outline[idx[k + 1]]
			var C := outline[idx[k + 2]]
			tri(m, Vector3(A.x, A.y, z1), Vector3(B.x, B.y, z1), Vector3(C.x, C.y, z1))
			tri(m, Vector3(A.x, A.y, z0), Vector3(C.x, C.y, z0), Vector3(B.x, B.y, z0))


static func section(z: float, w: float, h: float, y0: float, n := 12, squareness := 2.6, top_w := 1.0) -> Dictionary:
	## a rounded-rectangle cross-section (superellipse) at z for loft(): half-width w, half-height h, centred at y0;
	## top_w narrows the upper half (a cabin that tucks in)
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var c := cos(a)
		var s := sin(a)
		var x := signf(c) * pow(absf(c), 2.0 / squareness) * w
		var y := signf(s) * pow(absf(s), 2.0 / squareness) * h
		if y > 0:
			x *= lerpf(1.0, top_w, y / h)
		pts.append(Vector2(x, y + y0))
	return {"z": z, "pts": pts}


func at(t: Transform3D) -> Transform3D:
	## sets the transform for what follows; returns the old one to restore
	var old := xform
	xform = t
	return old


static func _plain(mat: Material) -> bool:
	## a material that is just a colour (no textures, no transparency, no clear coat): mergeable
	var m := mat as StandardMaterial3D
	return m != null and m.albedo_texture == null and m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED \
		and not m.clearcoat_enabled and not m.has_meta("keep") and m.normal_texture == null and m.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL


func _merge_plain() -> void:
	## folds every plain-coloured part into one painted surface and every plain glowing part into one
	## glowing surface, with each part's look carried in its vertex colours
	var paint := {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "c": PackedColorArray()}
	var glow := {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "c": PackedColorArray()}
	for name in _parts.keys():
		if not materials.has(name) or not _plain(materials[name]):
			continue
		var m := materials[name] as StandardMaterial3D
		var p: Dictionary = _parts[name]
		var target := paint
		var c := Color(m.albedo_color, 0.5 * (1.0 if m.metallic >= 0.5 else 0.0) + 0.49 * m.roughness)
		if m.emission_enabled:
			target = glow
			c = Color(m.emission, clampf(m.emission_energy_multiplier / 8.0, 0.0, 1.0))
		target.v.append_array(p.v)
		target.n.append_array(p.n)
		target.uv.append_array(p.uv)
		for i in p.v.size():
			target.c.append(c)
		_parts.erase(name)
	# neon signs: one surface, each sign's colour and seed in its vertices
	var neon := {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "c": PackedColorArray()}
	for name in _parts.keys():
		var sm := materials.get(name) as ShaderMaterial
		if sm == null or sm.shader == null or not sm.shader.resource_path.ends_with("neon_sign.gdshader") or sm.get_shader_parameter("vertex_tint"):
			continue
		var p: Dictionary = _parts[name]
		var col: Color = sm.get_shader_parameter("color")
		var c := Color(col.r, col.g, col.b, float(sm.get_shader_parameter("seed")) / 10.0)
		neon.v.append_array(p.v)
		neon.n.append_array(p.n)
		neon.uv.append_array(p.uv)
		for i in p.v.size():
			neon.c.append(c)
		_parts.erase(name)
	if not neon.v.is_empty():
		_parts["~neon"] = neon
		materials["~neon"] = load("res://materials/neon_all.tres")
	if not paint.v.is_empty():
		_parts["~paint"] = paint
		materials["~paint"] = load("res://materials/vertex_paint.tres")
	if not glow.v.is_empty():
		_parts["~glow"] = glow
		materials["~glow"] = load("res://materials/vertex_glow.tres")


func _merge_same_material() -> void:
	## parts that use the very same material become one surface (their UVs are already scaled)
	var first := {}  # material -> part name that keeps it
	for name in _parts.keys():
		if not materials.has(name):
			continue
		var mat: Material = materials[name]
		if first.has(mat):
			var keep: Dictionary = _parts[first[mat]]
			var p: Dictionary = _parts[name]
			keep.v.append_array(p.v)
			keep.n.append_array(p.n)
			keep.uv.append_array(p.uv)
			keep.c.append_array(p.c)
			_parts.erase(name)
		else:
			first[mat] = name


func bake(mesh: ArrayMesh = null) -> ArrayMesh:
	if mesh == null:
		mesh = ArrayMesh.new()
	_merge_plain()
	_merge_same_material()
	var names := _parts.keys()
	names.sort()
	for name in names:
		var p: Dictionary = _parts[name]
		if p.v.is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = p.v
		arr[Mesh.ARRAY_NORMAL] = p.n
		arr[Mesh.ARRAY_TEX_UV] = p.uv
		arr[Mesh.ARRAY_COLOR] = p.c
		# tangents for normal maps
		var st := SurfaceTool.new()
		st.create_from_arrays(arr)
		st.index()
		st.generate_tangents()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
		var si := mesh.get_surface_count() - 1
		mesh.surface_set_name(si, name)
		if materials.has(name):
			mesh.surface_set_material(si, materials[name])
	return mesh


func triangles() -> int:
	var n := 0
	for p in _parts.values():
		n += p.v.size() / 3
	return n
