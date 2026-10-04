extends Node
## Automated playthrough of the MVP (no graphics needed).
## Run from the game/ folder:  godot --headless --path . res://tests/smoke_test.tscn
## Prints PASS/FAIL per check and exits with code 0 only if everything passed.

const GAME := preload("res://scenes/game.tscn")

var game: Node
var player: Node
var museum: Node
var failures := 0
var ended_won := false
var ended_title := ""


func _ready() -> void:
	Shift.game_ended.connect(func(won: bool, title: String, _r: String) -> void:
		ended_won = won
		ended_title = title)
	await _run_win_flow()
	await _run_knight_catch()
	await _run_fired()
	print("\n==== %s (%d failures) ====" % ["ALL PASSED" if failures == 0 else "FAILED", failures])
	get_tree().paused = false
	get_tree().quit(0 if failures == 0 else 1)


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func seconds(t: float) -> void:
	await get_tree().create_timer(t, true, true).timeout


func start_game() -> void:
	if game:
		game.queue_free()
		await frames(2)
	get_tree().paused = false
	ended_title = ""
	game = GAME.instantiate()
	add_child(game)
	player = game.get_node("Player")
	museum = game.get_node("Museum")
	await frames(10)


func use(path: String) -> void:
	var n: Node = museum.get_node(path)
	n.interact(player)
	await frames(2)


func put_player(pos: Vector3, look_at_point: Vector3) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	var d := look_at_point - pos
	player.rotation.y = atan2(-d.x, -d.z)
	player.get_node("Head").rotation.x = atan2(d.y - 1.6, Vector2(d.x, d.z).length())
	await frames(6)


func _run_win_flow() -> void:
	print("\n--- Full night ---")
	await start_game()
	check(Shift.running, "shift is running")
	check(Shift.is_task_active("clock_in"), "first task is clock in")
	check(player.current_room == "office", "player starts in the office (safe zone)")

	# Interaction ray: stand in front of the punch clock and look at it.
	var clock: Node3D = museum.get_node("Interactables/PunchClock")
	await put_player(Vector3(2.2, 0.05, 11.0), clock.global_position)
	check(player.focus == clock, "use-ray finds the punch clock")

	await use("Interactables/PunchClock")
	check(Shift.is_task_done("clock_in"), "clock in done")
	await use("Interactables/RulesPoster")
	await use("Interactables/Flashlight")
	check(player.has_flashlight, "flashlight picked up")
	check(Shift.is_task_active("patrol"), "patrol task given")

	# Navigation must connect all rooms.
	var map: RID = player.get_world_3d().navigation_map
	var from := Vector3(0, 0, -3)
	for target in [Vector3(0, 0, 10), Vector3(-15, 0, 0), Vector3(-5, 0, -18), Vector3(5, 0, -16), Vector3(20, 0, -12)]:
		var path := NavigationServer3D.map_get_path(map, from, target, true)
		var ok := path.size() > 0 and path[path.size() - 1].distance_to(target) < 1.0
		check(ok, "navigation path lobby -> %s" % str(target))

	for cp in ["Interactables/CheckpointGallery", "Interactables/CheckpointEgypt", "Interactables/CheckpointDino"]:
		await use(cp)
	check(Shift.is_task_done("patrol"), "patrol done after 3 checkpoints")

	# 01:00 - the knight wakes up.
	Shift.skip_hour()
	await frames(2)
	var knight: Node3D = museum.get_node("Knight")
	check(knight.active, "knight active at 1 AM")
	await put_player(Vector3(0, 0.05, 5.5), knight.global_position + Vector3(0, 1.2, 0))
	var k0 := knight.global_position
	await seconds(1.5)
	check(knight.global_position.distance_to(k0) < 0.05, "knight frozen while watched")
	player.rotation.y += PI # look away
	await seconds(1.0)
	check(knight.global_position.distance_to(k0) > 0.5, "knight moves when not watched")
	await put_player(Vector3(0, 0.05, 12.5), Vector3(0, 1.6, 14))
	await seconds(1.0)
	check(Shift.running, "player safe in office")

	# Mummy: running in the Egyptian Hall wakes it.
	var mummy: Node3D = museum.get_node("Mummy")
	await put_player(Vector3(5, 0.05, -10), Vector3(5, 1.6, -9))
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await frames(20)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	check(mummy.state != 0, "mummy wakes when player runs in Egyptian Hall")
	await put_player(Vector3(0, 0.05, 12.5), Vector3(0, 1.6, 14))
	await seconds(2.5)
	check(mummy.state == 3 or mummy.state == 0, "mummy gives up when player is in the office")

	# 03:00 - blackout.
	Shift.skip_hour()
	Shift.skip_hour()
	await frames(2)
	check(not Shift.power_on and Shift.is_task_active("breaker"), "blackout at 3 AM")
	await use("Interactables/Breaker")
	check(Shift.power_on and Shift.is_task_done("breaker"), "breaker restores power")

	# 04:00 - the Golden Duck.
	Shift.skip_hour()
	await frames(2)
	var duck: Node = museum.get_node("Duck")
	check(duck.active and duck.visible, "duck stolen and placed somewhere at 4 AM")
	await use("Duck")
	check(player.carrying_duck, "carrying the duck")
	await use("DuckPedestal")
	check(Shift.is_task_done("duck"), "duck returned")

	# Rule 5
	await use("Interactables/Vase")
	check(Shift.writeups.size() == 1, "touching the vase gives a write-up")

	Shift.skip_hour()
	Shift.skip_hour()
	await frames(5)
	check(ended_title == "SHIFT COMPLETE" and ended_won, "surviving until 6 AM wins")


func _run_knight_catch() -> void:
	print("\n--- Knight catch ---")
	await start_game()
	var knight: Node3D = museum.get_node("Knight")
	knight.activate()
	# Stand right behind the knight, looking away from it.
	await put_player(knight.global_position + Vector3(0, 0, 2.2), knight.global_position + Vector3(0, 1.6, 10))
	await seconds(3.0)
	check(ended_title == "KNIGHTED" and not ended_won, "knight catches a player who looks away")


func _run_fired() -> void:
	print("\n--- Three write-ups ---")
	await start_game()
	Shift.add_writeup("test 1")
	Shift.add_writeup("test 2")
	Shift.add_writeup("test 3")
	await frames(2)
	check(ended_title == "YOU'RE FIRED", "three write-ups = fired")
