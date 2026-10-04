extends Node
## Screenshot of the main menu (needs a display).

func _ready() -> void:
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().create_timer(5.0).timeout
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../build/screenshots"))
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/screenshots/00_menu.png"))
	print("saved menu")
	get_tree().quit()
