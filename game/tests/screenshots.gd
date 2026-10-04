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
	["12_atrium_stairs", Vector3(0, 0.05, 9.0), Vector3(0, 5.5, -6), false],
	["13_balcony", Vector3(10, 5.55, 8.5), Vector3(-6, 6.5, -6), false],
	["14_library", Vector3(-1.5, 5.55, -11.0), Vector3(-9, 6.6, -19), false],
	["15_planetarium", Vector3(1.5, 5.55, -11.5), Vector3(7, 7.5, -17), false],
	["16_toyroom", Vector3(6, 5.55, 11.5), Vector3(12, 6.0, 16), false],
	["17_director", Vector3(0, 5.55, 10.8), Vector3(0, 6.5, 16.5), false],
	["18_natural", Vector3(13.5, 5.55, -5.5), Vector3(24, 6.5, -14), false],
	["19_armory", Vector3(13.5, 5.55, 8.5), Vector3(24, 6.5, -1), false],
	["20_workshop", Vector3(-13, 5.55, -5), Vector3(-20, 6.5, 6), false],
	["21_costume", Vector3(-5, 5.55, 11), Vector3(-18, 6.5, 17), false],
	["22_boiler", Vector3(-13.5, -4.45, 8), Vector3(-18, -3.5, -12), false],
	["23_archives", Vector3(-11, -4.45, -11), Vector3(-2, -3.5, -18), false],
	["24_vault", Vector3(6, -4.45, -11), Vector3(6, -3.5, -20), false],
	["25_blackout_library", Vector3(-1.5, 5.55, -11.0), Vector3(-9, 6.6, -19), true],
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
	if args.has("q"):
		Save.settings["quality"] = int(args["q"])
		Save.apply_quality(game.get_node("Museum/WorldEnvironment").environment, get_viewport())
	for d in ["DoorCurio", "DoorCurio2", "DoorWax", "DoorWax2", "DoorLibrary", "DoorPlanet", "DoorNatural", "DoorArmory",
			"DoorWorkshop", "DoorCostume", "DoorToyArmory", "DoorArchives", "DoorVault"]:
		game.get_node("Museum/" + d).open(true)
	game.get_node("Museum/StairBlock").open()
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
