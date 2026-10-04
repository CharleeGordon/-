extends Node
## Close-up screenshots of every enemy (needs a display).

const GAME := preload("res://scenes/game.tscn")
const SHOTS := [
	["e1_knight", "Knight", Vector3(0.6, 0.05, -1.0), Vector3(0, 1.4, -3)],
	["e2_mummy", "Mummy", Vector3(6.6, 0.05, -18.4), Vector3(6, 1.4, -20.5)],
	["e3_automaton", "Automaton", Vector3(12.4, 0.05, 18.6), Vector3(12, 1.2, 20.9)],
	["e4_gary", "Gary", Vector3(-12.5, 0.05, 12.2), Vector3(-13, 1.4, 14)],
	["e5_duchess", "Duchess", Vector3(-6.4, 0.05, -12.3), Vector3(-6, 1.4, -14)],
	["e6_dino_head", "Dino", Vector3(15.5, 0.05, -2.5), Vector3(18.6, 3.2, -4)],
]


func _ready() -> void:
	Shift.night = 4
	var game := GAME.instantiate()
	add_child(game)
	var player: Node = game.get_node("Player")
	var museum: Node = game.get_node("Museum")
	game.get_node("HUD").visible = false
	museum.get_node("DoorCurio").open(true)
	await get_tree().create_timer(3.0).timeout
	Shift.flags["dark_rooms"] = []
	game.apply_lights()
	var duchess: Node3D = museum.get_node("Duchess")
	duchess.visible = true
	duchess.global_position = Vector3(-6, 0, -14)
	duchess.rotation.y = PI
	museum.get_node("Gary")._set_beam(true)
	for s in SHOTS:
		player.global_position = s[2]
		var d: Vector3 = s[3] - s[2]
		player.rotation.y = atan2(-d.x, -d.z)
		player.get_node("Head").rotation.x = atan2(d.y - 1.6, Vector2(d.x, d.z).length())
		player.set_flashlight(true)
		for i in 40:
			await get_tree().process_frame
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../build/screenshots"))
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/screenshots/%s.png" % s[0]))
		print("saved ", s[0])
	get_tree().quit()
