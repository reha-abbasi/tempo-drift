extends Node
## The main scene: the studio intro (first launch), then the menus over the live city of the chosen era
## (a run in menu mode: the car flies the era's first course by itself).

const RUN := preload("res://scenes/run/run.tscn")

var backdrop: Node


var menu_music: AudioStreamPlayer


func _ready() -> void:
	AudioServer.set_bus_mute(0, not bool(Save.setting("sound")))
	# the main-menu theme: two bars of pads, then sixteen that loop (100 BPM: a bar is 2.4 s)
	var s: AudioStreamWAV = (load("res://audio/menu/menu.res") as AudioStreamWAV).duplicate()
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = int(4.8 * s.mix_rate)
	s.loop_end = int(s.get_length() * s.mix_rate)
	menu_music = AudioStreamPlayer.new()
	menu_music.stream = s
	menu_music.volume_db = 6.0
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
	if backdrop:
		backdrop.queue_free()
	Launch.mode = "menu"
	Launch.map = map
	Launch.index = 0
	backdrop = RUN.instantiate()
	backdrop.name = "Backdrop"
	add_child(backdrop)
	move_child(backdrop, 0)
