@tool
extends EditorPlugin
## Test tool: EDITOR_SHOT=1 SCENE=res://... OUT=/file.png godot -e --path .
## Opens the scene, waits for the editor to settle, saves a picture of the whole editor window and quits.
## Does nothing in normal use.


func _enter_tree() -> void:
	if OS.get_environment("EDITOR_SHOT") == "":
		return
	_shoot.call_deferred()


func _shoot() -> void:
	var tree := get_tree()
	tree.create_timer(240.0).timeout.connect(tree.quit.bind(1))
	await tree.create_timer(4.0).timeout
	EditorInterface.open_scene_from_path(OS.get_environment("SCENE"))
	EditorInterface.set_main_screen_editor(OS.get_environment("SCREEN") if OS.get_environment("SCREEN") != "" else "3D")
	await tree.create_timer(float(OS.get_environment("WAIT")) if OS.get_environment("WAIT") != "" else 10.0).timeout
	var root := EditorInterface.get_edited_scene_root()
	print("EDITOR_SHOT opened ", root.name if root else "nothing", " · ", root.get_child_count() if root else 0, " children")
	if DisplayServer.get_name() == "headless":
		tree.quit()
		return
	await RenderingServer.frame_post_draw
	EditorInterface.get_base_control().get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT"))
	print("EDITOR_SHOT saved ", OS.get_environment("OUT"))
	tree.quit()
