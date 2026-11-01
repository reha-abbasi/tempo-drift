class_name Kit
extends RefCounted
## Helpers for the scene builders in tools/editor: they assemble node trees once and save them as
## ordinary .tscn scenes, which are then edited in the editor like any other scene. The game never
## runs these builders.


static func own(n: Node, owner: Node) -> void:
	for c in n.get_children():
		c.owner = owner
		# instanced scenes keep their own insides
		if c.scene_file_path.is_empty():
			own(c, owner)


static func save(root: Node, path: String) -> void:
	own(root, root)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	assert(err == OK, "pack failed: %s" % path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	err = ResourceSaver.save(ps, path)
	assert(err == OK, "save failed: %s" % path)
	print("saved ", path)
	root.free()


static func add(parent: Node, n: Node, name := "") -> Node:
	if name != "":
		n.name = name
	parent.add_child(n)
	return n


static func instance(parent: Node, path: String, name := "", pos := Vector3.ZERO, rot_y := 0.0, scl := 1.0) -> Node3D:
	var n := (load(path) as PackedScene).instantiate() as Node3D
	if name != "":
		n.name = name
	parent.add_child(n)
	n.position = pos
	n.rotation.y = rot_y
	n.scale = Vector3.ONE * scl
	return n


static func instance_any(parent: Node, path: String, name := "") -> Node:
	var n := (load(path) as PackedScene).instantiate()
	if name != "":
		n.name = name
	parent.add_child(n)
	return n
