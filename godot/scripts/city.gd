@tool
extends Node3D
class_name City
## A city: its sky and light (the Sky and Sun children), its landmark on the horizon, the street sections that line
## up ahead of the car, its traffic and its colours. Everything visible is a scene edited in the editor; this only
## places sections as the car flies and tells the windows how dark it is.

@export var display_name := "City"
## street sections, each section_length long, from their origin towards -Z, picked in a shuffled order
@export var sections: Array[PackedScene] = []
@export var section_length := 48.0
@export var view_ahead := 190.0
## traffic by kind (as in the course data): oldcar, dbus, biplane, taxi, truck, bus, hovercab, drone, barrier
@export var traffic: Dictionary = {}
## body colours for cars and buses here
@export var car_colors: Array[Color] = []
@export var bus_color := Color(0.69, 0.12, 0.14)
## how dark it is (0 day .. 1 night): lit windows glow more
@export var night := 0.4
## the city's two neon colours (signs, wet-road shine)
@export var accent_a := Color("ff3fb4")
@export var accent_b := Color("2ef2ff")
## in the editor, lay a stretch of street out in front of the camera (not saved). A level scene turns this off: it
## has its whole street laid out already
@export var preview_street := true

var _placed := {}
var _fixed: Node3D = null
var _order: Array[int] = []
@onready var street: Node3D = get_node_or_null("Street")
## the far skyline, the landmark, the sky shows and the rain: they travel with the car
@onready var horizon: Node3D = get_node_or_null("Horizon")


func _ready() -> void:
	RenderingServer.global_shader_parameter_set("city_night", night)
	RenderingServer.global_shader_parameter_set("accent_a", accent_a)
	RenderingServer.global_shader_parameter_set("accent_b", accent_b)
	if street == null:
		street = Node3D.new()
		street.name = "Street"
		add_child(street)
	for c in street.get_children():
		c.queue_free()
	for i in 64:
		_order.append(section_at(i))
	if Engine.is_editor_hint() and preview_street and not sections.is_empty():
		for i in 6:
			var s := sections[_order[i]].instantiate() as Node3D
			s.position.z = -i * section_length
			street.add_child(s)


func section_at(i: int) -> int:
	## which section stands i sections down the street (a shuffle seeded by the city's name, no section twice in a row)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(display_name)
	var last := -1
	var k := 0
	for j in (i % 64) + 1:
		k = rng.randi_range(0, sections.size() - 1)
		if sections.size() > 1 and k == last:
			k = (k + 1) % sections.size()
		last = k
	return k


func use_street(laid_out: Node3D) -> void:
	## a level's own street, laid out end to end: shown near the car instead of placed as it goes
	_fixed = laid_out
	for s in _fixed.get_children():
		(s as Node3D).visible = false


func follow(car_z: float) -> void:
	## keep sections from just behind the camera to view_ahead in front of the car
	if _fixed:
		for s in _fixed.get_children():
			var z: float = (s as Node3D).position.z
			(s as Node3D).visible = z < car_z + 20.0 + section_length and z >= car_z - view_ahead
		if horizon:
			horizon.position.z = car_z
		return
	var first := maxi(0, int(floor(-(car_z + 20.0) / section_length)))
	var last := int(floor(-(car_z - view_ahead) / section_length))
	for i in _placed.keys():
		if i < first or i > last:
			_placed[i].queue_free()
			_placed.erase(i)
	for i in range(first, last + 1):
		if not _placed.has(i):
			var s := sections[_order[i % _order.size()]].instantiate() as Node3D
			s.position.z = -i * section_length
			street.add_child(s)
			_placed[i] = s
	if horizon:
		horizon.position.z = car_z


func vehicle(kind: String, pick: int) -> Node3D:
	if not traffic.has(kind):
		return null
	var n := (traffic[kind] as PackedScene).instantiate() as Node3D
	paint(n, kind, pick)
	return n


func paint(n: Node3D, kind: String, pick: int) -> void:
	## a vehicle in this city's colours (buses in the bus colour, cars in turn)
	if n.has_method("paint"):
		if kind == "dbus" or kind == "bus":
			n.paint(bus_color)
		elif not car_colors.is_empty():
			n.paint(car_colors[pick % car_colors.size()])
