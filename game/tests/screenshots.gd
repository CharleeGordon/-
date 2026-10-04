extends Node
## Takes screenshots from a few viewpoints (needs a display / GPU, not --headless).
## godot --path . res://tests/screenshots.tscn   -> saves PNGs into ../build/screenshots/
## Optional: -- night=3 only=lobby

const GAME := preload("res://scenes/game.tscn")
const SHOTS := [
	["01_office", Vector3(0, 0.05, 11.5), Vector3(0, 1.0, 16.5), false],
	["02_lobby_knight", Vector3(0, 0.05, 7.0), Vector3(0, 1.4, -3), false],
	["03_lobby_wide", Vector3(9, 0.05, 8), Vector3(-6, 2.0, -6), false],
	["04_gallery", Vector3(-1.5, 0.05, -11.5), Vector3(-8, 2.0, -20), false],
	["05_egypt", Vector3(6, 0.05, -11.0), Vector3(6, 1.3, -21), false],
	["06_dino", Vector3(13.5, 0.05, 3.5), Vector3(20, 2.4, -4), false],
	["07_curio", Vector3(6, 0.05, 12), Vector3(14, 1.4, 20), false],
	["08_wax", Vector3(-6, 0.05, 12), Vector3(-16, 1.4, 14), false],
	["09_storage", Vector3(-13.5, 0.05, 2), Vector3(-20, 1.3, -3), false],
	["10_blackout_lobby", Vector3(0, 0.05, 7.0), Vector3(0, 1.4, -3), true],
	["11_blackout_egypt", Vector3(6, 0.05, -12.0), Vector3(6, 1.3, -21), true],
]


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../build/screenshots"))
	Shift.night = int(args.get("night", "1"))
	var game := GAME.instantiate()
	add_child(game)
	var player: Node = game.get_node("Player")
	player.give_flashlight()
	for d in ["DoorCurio", "DoorWax"]:
		game.get_node("Museum/" + d).open(true)
	await get_tree().create_timer(3.5).timeout
	for s in SHOTS:
		if args.has("only") and not String(s[0]).contains(args["only"]):
			continue
		if s[3] and Shift.power_on:
			Shift.set_power(false)
			player.set_flashlight(true)
		player.global_position = s[1]
		var d: Vector3 = s[2] - s[1]
		player.rotation.y = atan2(-d.x, -d.z)
		player.get_node("Head").rotation.x = atan2(d.y - 1.6, Vector2(d.x, d.z).length())
		for i in 40:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://../build/screenshots/%s.png" % s[0]))
		print("saved ", s[0])
	get_tree().quit()
