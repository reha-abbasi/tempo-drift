extends RefCounted
## The level scenes (scenes/levels/<map>_<i>.tscn and school_<map>.tscn), laid out from the baked courses: the
## city, its whole street section by section, a ring for every note and a vehicle for every hazard, each where it
## meets the car. After this the scenes are the levels; edit them in the editor.

const RING := "res://scenes/track/note_ring.tscn"


func build(_host: Node) -> void:
	for map in Catalog.MAPS:
		for e in Catalog.episodes(map):
			level(map, e.i, e.name, e.course, e.audio, false)
		level(map, 0, "Flight School", "res://data/school_%s.json" % map, "res://audio/school_%s" % map, true)


func level(map: String, i: int, title: String, course_file: String, song: String, school: bool) -> void:
	var c: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(course_file))
	var mps := float(c.speed) * Level.K
	var root = Node3D.new()
	root.name = title.replace(" ", "")
	root.set_script(load("res://scripts/level.gd"))
	root.display_name = title
	root.course_file = course_file
	root.song = song
	root.map = map
	root.index = i
	root.flight_school = school
	var city := Kit.instance(root, "res://scenes/cities/%s_%d.tscn" % [map, i], "City") as City
	city.preview_street = false
	# the street, end to end, past the last note by a view's length
	var street := Kit.add(root, Node3D.new(), "Street") as Node3D
	var last_t := 0.0
	for n in c.notes:
		last_t = maxf(last_t, float(n.t))
	for h in c.hazards:
		last_t = maxf(last_t, float(h.t))
	var count := int(ceil((last_t * mps + city.view_ahead + 40.0) / city.section_length)) + 1
	for j in count:
		var k := city.section_at(j)
		var s := Kit.instance(street, city.sections[k].resource_path, "S%02d_%s" % [j, city.sections[k].resource_path.get_file().get_basename()])
		s.position.z = -j * city.section_length
	# the rings
	var notes := Kit.add(root, Node3D.new(), "Notes") as Node3D
	var bar := float(c.bar)
	var idx := 0
	for n in c.notes:
		var r = Kit.instance(notes, RING, "N%03d_bar%02d" % [idx, int(float(n.t) / bar)])
		r.position = Level.place(int(n.col), int(n.row), float(n.t), mps)
		r.pitch = int(n.note)
		r.length = int(n.len)
		r.power_up = "none" if str(n.get("pu", "")) == "" else str(n.pu)
		r.waits_for = "none" if str(n.get("wait", "")) == "" else str(n.wait)
		r.layer = int(n.layer) if n.has("layer") else -1
		idx += 1
	# the traffic and roadblocks
	var traffic := Kit.add(root, Node3D.new(), "Traffic") as Node3D
	idx = 0
	for h in c.hazards:
		var hz := LevelHazard.new()
		hz.name = "H%03d_%s" % [idx, h.kind]
		hz.kind = h.kind
		hz.over = bool(h.over)
		hz.under = bool(h.under)
		traffic.add_child(hz)
		hz.position = Level.place(int(h.col), int(h.row), float(h.t), mps)
		if city.traffic.has(h.kind):
			hz.add_child((city.traffic[h.kind] as PackedScene).instantiate())
		idx += 1
	var path := "res://scenes/levels/%s.tscn" % ("school_" + map if school else "%s_%d" % [map, i])
	Kit.save(root, path)
