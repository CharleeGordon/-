extends Node
## Regression test: mouse movement must turn the camera.

func _ready() -> void:
	var game: Node = preload("res://scenes/game.tscn").instantiate()
	add_child(game)
	for i in 10:
		await get_tree().process_frame
	var player: Node3D = game.get_node("Player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var yaw0 := player.rotation.y
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(200, 0)
	ev.position = get_viewport().get_visible_rect().size * 0.5
	ev.global_position = ev.position
	Input.parse_input_event(ev)
	for i in 5:
		await get_tree().process_frame
	print("mouse_mode=", Input.mouse_mode)
	var ok := absf(player.rotation.y - yaw0) > 0.1
	print("PASS  mouse turns camera" if ok else "FAIL  mouse turns camera")
	get_tree().quit(0 if ok else 1)
