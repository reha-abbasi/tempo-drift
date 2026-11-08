extends Node
## The main scene: the studio intro (first launch), then the menus over the chosen era's rooftop (your car parked
## high over the era's open city, scripts/rooftop.gd). The garage shows the car in the street instead: a run in
## menu mode (the car flies the era's course by itself), made while the garage is open.

const RUN := preload("res://scenes/run/run.tscn")
const ROOFTOP := preload("res://scenes/menu/rooftop.tscn")

## the street behind the garage's in-game view (the old turn round the car in the street), only while it shows
var backdrop: Node
## the garage shows the in-game view (else its showroom: the car and pilot on the rooftop)
var garage_street := false
## the rooftop behind the other menus (out of the scene while the garage is open)
var rooftop: Rooftop
var _map := ""


var menu_music: AudioStreamPlayer


func _ready() -> void:
	AudioServer.set_bus_mute(0, not bool(Save.setting("sound")))
	# the menus play their own theme, "Time Traveller" (strings, piano, violins then trumpet): a seamless 40 s loop
	var s := (load("res://audio/menu/theme.ogg") as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
	s.loop = true
	s.loop_offset = 0.0
	menu_music = AudioStreamPlayer.new()
	menu_music.stream = s
	menu_music.volume_db = -5.0
	menu_music.bus = "Menu" if AudioServer.get_bus_index("Menu") >= 0 else "Master"
	add_child(menu_music)
	# the city backdrop waits for the intro: they share one 3D world, and the backdrop's camera would take over
	if has_node("Intro") and not Intro_seen:
		$Intro.finished.connect(_after_intro)
		$Menus.visible = false
	else:
		if has_node("Intro"):
			$Intro.queue_free()
		show_era(Save.data.get("map", "old"))
		menu_music.play()


static var Intro_seen := false


func _after_intro() -> void:
	Intro_seen = true
	show_era(Save.data.get("map", "old"))
	$Menus.visible = true
	$Menus.open("Home")
	menu_music.play()


func show_era(map: String) -> void:
	## the chosen era behind the menus: its rooftop, or its street while the garage is open
	_map = map
	if rooftop == null:
		rooftop = ROOFTOP.instantiate() as Rooftop
		add_child(rooftop)
		move_child(rooftop, 0)
	rooftop.set_era(map)
	if backdrop:
		_street(true)


func _notification(what: int) -> void:
	# the rooftop may be out of the scene (garage open) when the menus close: free it with the main scene
	if what == NOTIFICATION_PREDELETE and rooftop and is_instance_valid(rooftop) and not rooftop.is_inside_tree():
		rooftop.free()


func screen(name: String) -> void:
	## the menus are opening a screen: every screen stands on the rooftop, the garage too (its showroom)
	garage_street = false
	_street(false)
	if rooftop:
		rooftop.set_garage(name == "Garage")


func garage_view() -> Node:
	## what the garage shows the car with: the rooftop's showroom, or the street's in-game view
	return backdrop if backdrop else rooftop


func toggle_garage_view() -> void:
	## the garage's button: from the showroom to the in-game view (the old turn round the car in the street) and back
	garage_street = not garage_street
	_street(garage_street)
	if backdrop:
		backdrop.set_garage(true)


func _street(on: bool) -> void:
	if backdrop:
		backdrop.queue_free()
		backdrop = null
	if on:
		Launch.mode = "menu"
		Launch.map = _map
		# the era's open city (with its new look), not its first city
		Launch.index = int(Save.OPEN.get(_map, [0])[0])
		backdrop = RUN.instantiate()
		backdrop.name = "Backdrop"
		# (the rooftop leaves the scene meanwhile: one city, one light and one camera at a time)
		if rooftop and rooftop.is_inside_tree():
			remove_child(rooftop)
		add_child(backdrop)
		move_child(backdrop, 0)
	elif rooftop and not rooftop.is_inside_tree():
		add_child(rooftop)
		move_child(rooftop, 0)
