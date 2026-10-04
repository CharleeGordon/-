extends Node
## Takes screenshots from a few viewpoints (needs a real display / GPU, not --headless).
## godot --path . res://tests/screenshots.tscn   -> saves PNGs into ../build/screenshots/

const GAME := preload("res://scenes/game.tscn")
const SHOTS := [
	["00_prompt_clock", Vector3(2.2, 0.05, 11.0), Vector3(3.6, 1.4, 11.0), false],
	["01_office", Vector3(0, 0.05, 10.0), Vector3(0, 1.3, 14.5), false],
	["02_office_rules", Vector3(-1.5, 0.05, 11.5), Vector3(-3.8, 1.7, 11.5), false],
	["03_lobby_knight", Vector3(0, 0.05, 6.5), Vector3(0, 1.4, -3), false],
	["04_lobby_wide", Vector3(7, 0.05, 6.5), Vector3(-5, 1.0, -6), false],
	["05_egypt", Vector3(5, 0.05, -9.5), Vector3(5, 1.2, -21), false],
	["06_gallery", Vector3(-2, 0.05, -10), Vector3(-9, 1.6, -17), false],
	["07_dino", Vector3(11.5, 0.05, 1.5), Vector3(18, 2.2, -4), false],
	["08_blackout_lobby", Vector3(0, 0.05, 6.5), Vector3(0, 1.4, -3), true],
	["09_storage", Vector3(-11, 0.05, 1.5), Vector3(-17, 1.2, -1), true],
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../build/screenshots"))
	var game := GAME.instantiate()
	add_child(game)
	var player: Node = game.get_node("Player")
	player.has_flashlight = true
	await get_tree().create_timer(3.0).timeout # let the fade-in finish
	for s in SHOTS:
		if s[3] and Shift.power_on:
			Shift.set_power(false)
			player.set_flashlight(true)
		player.global_position = s[1]
		var d: Vector3 = s[2] - s[1]
		player.rotation.y = atan2(-d.x, -d.z)
		player.get_node("Head").rotation.x = atan2(d.y - 1.6, Vector2(d.x, d.z).length())
		for i in 30:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://../build/screenshots/%s.png" % s[0]))
		print("saved ", s[0])
	game.get_node("HUD").open_journal()
	Shift.say("Journal test line.", "BRENDA (radio)", 5.0)
	for i in 30:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/screenshots/10_journal.png"))
	get_tree().quit()
