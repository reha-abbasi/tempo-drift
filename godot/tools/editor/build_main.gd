extends RefCounted
## The main scene (scenes/main.tscn): the menus over the live city, and the studio intro on first launch.


func build(_host: Node) -> void:
	var root := Node.new()
	root.name = "Main"
	root.set_script(load("res://scripts/main.gd"))
	Kit.instance_any(root, "res://scenes/ui/menus.tscn", "Menus")
	if ResourceLoader.exists("res://scenes/intro/intro.tscn"):
		Kit.instance_any(root, "res://scenes/intro/intro.tscn", "Intro")
	Kit.save(root, "res://scenes/main.tscn")
