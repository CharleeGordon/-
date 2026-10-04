extends Node
## Automated playthrough of all five nights (no graphics needed).
## Run from the game/ folder:  godot --headless --path . res://tests/smoke_test.tscn
## Prints PASS/FAIL per check and exits with code 0 only if everything passed.

const GAME := preload("res://scenes/game.tscn")

var game: Node
var player: Node
var museum: Node
var hud: Node
var failures := 0


func _ready() -> void:
	var saved_progress := Save.progress.duplicate(true)
	Save.progress = {"night_unlocked": 1, "endings": [], "notes": [], "keycard": false}
	await _night1()
	await _checkpoint()
	await _night2()
	await _night3()
	await _night4()
	await _night5()
	Save.progress = saved_progress # don't leave test progress in the player's save
	Save.save_all()
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


func start_night(n: int, checkpoint: Dictionary = {}) -> void:
	if game:
		game.queue_free()
		await frames(2)
	get_tree().paused = false
	Shift.night = n
	Shift.pending_checkpoint = checkpoint
	game = GAME.instantiate()
	add_child(game)
	player = game.get_node("Player")
	museum = game.get_node("Museum")
	hud = game.get_node("HUD")
	await frames(10)


func use(path: String) -> void:
	var nd: Node = museum.get_node(path)
	nd.interact(player)
	await frames(2)
	if hud._reading:
		hud.close_note()


func put_player(pos: Vector3, look_at_point: Vector3) -> void:
	if player.is_hidden:
		player.exit_hide()
	player.global_position = pos
	player.velocity = Vector3.ZERO
	var d := look_at_point - pos
	player.rotation.y = atan2(-d.x, -d.z)
	player.get_node("Head").rotation.x = atan2(d.y - 1.6, Vector2(d.x, d.z).length())
	await frames(6)


func end_title() -> String:
	return hud._end_title.text if hud._end.visible else ""


func to_office() -> void:
	await put_player(Vector3(0, 0.05, 12.5), Vector3(0, 1.6, 16))


# --------------------------------------------------------------------------

func _night1() -> void:
	print("\n--- Night 1 ---")
	await start_night(1)
	check(Shift.running and Shift.night == 1, "night 1 running")
	check(Shift.is_task_active("clock_in"), "first task is clock in")
	check(player.current_room == "office", "player starts in the office (safe zone)")
	var clock: Node3D = museum.get_node("Interactables/PunchClock")
	await put_player(Vector3(2.4, 0.05, 12.0), clock.global_position)
	check(player.focus == clock, "use-ray finds the punch clock")
	await use("Interactables/PunchClock")
	await use("Interactables/RulesPoster")
	await use("Interactables/Flashlight")
	check(player.has_flashlight, "flashlight picked up")
	check(Shift.is_task_active("patrol"), "patrol task given")

	var map: RID = player.get_world_3d().navigation_map
	for target in [Vector3(0, 0, 13), Vector3(-17, 0, 2), Vector3(-6, 0, -17), Vector3(6, 0, -16), Vector3(21, 0, -12),
			Vector3(-13, 0, 15), Vector3(12, 0, 16), Vector3(6, 0, -26)]:
		var path := NavigationServer3D.map_get_path(map, Vector3(0, 0, 0), target, true)
		check(path.size() > 0 and path[path.size() - 1].distance_to(target) < 1.0, "navigation lobby -> %s" % str(target))

	for cp in ["CheckpointGallery", "CheckpointEgypt", "CheckpointDino"]:
		await use("Interactables/" + cp)
	check(Shift.is_task_done("patrol"), "patrol done after 3 checkpoints")
	check(museum.find_child("DoorCurio", false, false).is_open() == false, "curiosities door locked on night 1")

	Shift.skip_hour()
	await frames(2)
	var knight: Node3D = museum.get_node("Knight")
	check(knight.active, "knight active at 1 AM")
	await put_player(Vector3(0, 0.05, 5.5), knight.global_position + Vector3(0, 1.2, 0))
	var k0 := knight.global_position
	await seconds(1.5)
	check(knight.global_position.distance_to(k0) < 0.05, "knight frozen while watched")
	player.rotation.y += PI
	await seconds(1.2)
	check(knight.global_position.distance_to(k0) > 0.5, "knight moves when not watched")
	await to_office()
	await seconds(1.0)
	check(Shift.running, "player safe in office")

	var mummy: Node3D = museum.get_node("Mummy")
	await put_player(Vector3(6, 0.05, -12), Vector3(6, 1.6, -11))
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await frames(20)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	check(mummy.state != 0, "mummy wakes when player runs in Egyptian Hall")
	await to_office()
	await seconds(2.5)
	check(mummy.state == 3 or mummy.state == 0, "mummy gives up when player is in the office")

	Shift.skip_hour()
	Shift.skip_hour()
	await frames(2)
	check(not Shift.power_on and Shift.is_task_active("breaker"), "blackout at 3 AM")
	check(Shift.has_checkpoint(), "checkpoint saved at 3 AM")
	await use("Interactables/Breaker")
	check(Shift.power_on and Shift.is_task_done("breaker"), "breaker restores power")

	Shift.skip_hour()
	await frames(2)
	var duck: Node = museum.get_node("Duck")
	check(duck.active and duck.visible, "duck stolen at 4 AM")
	await use("Duck")
	check(player.carrying == "duck", "carrying the duck")
	await use("DuckPedestal")
	check(Shift.is_task_done("duck"), "duck returned")

	await use("Interactables/Vase")
	check(Shift.writeups.size() == 1, "touching the vase gives a write-up")
	await use("Note1")
	check(Save.progress["notes"].has(1), "reading a note stores it")

	Shift.skip_hour()
	Shift.skip_hour()
	await frames(5)
	check(end_title() == "NIGHT 1 COMPLETE", "surviving until 6 AM completes night 1")
	check(int(Save.progress["night_unlocked"]) >= 2, "night 2 unlocked")


func _checkpoint() -> void:
	print("\n--- Checkpoint retry ---")
	await start_night(1)
	await use("Interactables/PunchClock")
	for i in 3:
		Shift.skip_hour()
	await frames(2)
	check(Shift.has_checkpoint(), "checkpoint exists")
	var cp := Shift.checkpoint.duplicate(true)
	await start_night(1, cp)
	check(Shift.hour == 2 and Shift.elapsed > 290.0, "resumed just before 3:00 AM")
	check(Shift.is_task_done("clock_in"), "tasks restored from checkpoint")
	check(museum.get_node("Knight").active, "hour-1 events re-applied (knight active)")
	await seconds(5.0)
	check(Shift.hour == 3 and not Shift.power_on, "3 AM blackout fires after resume")


func _night2() -> void:
	print("\n--- Night 2 ---")
	await start_night(2)
	check(player.has_flashlight, "night 2 starts with flashlight")
	check(museum.find_child("DoorCurio", false, false).is_open(), "curiosities open on night 2")
	await use("Interactables/PunchClock")
	check(Shift.is_task_active("bulbs") and Shift.is_task_active("wind"), "night 2 tasks given")
	Shift.skip_hour()
	await frames(2)
	var auto: Node3D = museum.get_node("Automaton")
	check(auto.enabled, "automaton running at 1 AM")
	await seconds(1.0)
	check(auto.spring < 100.0, "spring runs down")
	await use("Interactables/WindCrank")
	check(auto.spring > 99.0, "winding restores the spring")
	await use("Interactables/BulbBox")
	check(player.carrying == "bulbs", "took bulbs")
	for i in 3:
		await use("Interactables/Socket%d" % (i + 1))
	check(Shift.is_task_done("bulbs"), "3 bulbs installed")
	# Let him run down while the player hides in a locker
	await put_player(Vector3(18.5, 0.05, 21.0), Vector3(17, 1.6, 21))
	await use("Interactables/HideCurio")
	check(player.is_hidden, "player hides in locker")
	auto.spring = 0.0
	await seconds(0.5)
	check(auto.is_hunting(), "automaton hunts when unwound")
	auto._timer = 1.0
	await seconds(3.0)
	check(Shift.running, "hidden player is not caught")
	player.exit_hide()
	Shift.skip_hour()
	await frames(3)
	var sword := museum.get_node_or_null("Sword")
	check(sword != null and Shift.is_task_active("sword"), "sword dropped at 2 AM")
	if sword:
		await use("Sword")
		check(player.carrying == "sword", "carrying the sword")
		var ret: Node = museum.get_node("Knight/ReturnSword")
		ret.interact(player)
		await frames(2)
		check(Shift.is_task_done("sword"), "sword returned")


func _night3() -> void:
	print("\n--- Night 3 ---")
	await start_night(3)
	await use("Interactables/PunchClock")
	check(Shift.is_task_active("windows"), "windows task")
	await use("Interactables/WindowGallery")
	check(Shift.flags.get("closed", []).has("WindowGallery"), "window closed")
	var duchess: Node = museum.get_node("Duchess")
	duchess.set_enabled(true, 0.1)
	await put_player(Vector3(-6, 0.05, -14), Vector3(-6, 1.6, -20))
	await seconds(2.6)
	check(duchess.is_watching(), "the paintings watch after a warning")
	await seconds(4.0)
	check(Shift.running, "standing still survives the gaze")
	duchess.set_enabled(true, 0.1)
	await seconds(2.5)
	Input.action_press("move_forward")
	await seconds(0.8)
	Input.action_release("move_forward")
	await seconds(2.0)
	check(end_title() == "FRAMED", "moving while watched = framed")


func _night4() -> void:
	print("\n--- Night 4 ---")
	await start_night(4)
	check(museum.find_child("DoorWax", false, false).is_open(), "wax hall open on night 4")
	check(Shift.flags.get("dark_rooms", []).has("wax"), "budget cuts: wax hall dark")
	await use("Interactables/PunchClock")
	Shift.skip_hour()
	await frames(3)
	var gary: Node3D = museum.get_node("Gary")
	check(gary.enabled and gary.state == 1, "Gary patrols at 1 AM")
	# Stand in front of Gary, in his beam
	gary.global_position = Vector3(0, 0, 4)
	gary.rotation.y = 0.0 # facing -Z, down the lobby
	var saved_points: Array[Vector3] = gary._points.duplicate()
	gary._points = [Vector3(0, 0, -8)] as Array[Vector3] # walk toward the player
	await put_player(Vector3(0, 0.05, -1.0), Vector3(0, 1.6, 4))
	await seconds(1.5)
	gary._points = saved_points
	check(gary.state == 3 or gary.state == 4, "Gary spots the player in his beam")
	await to_office()
	await seconds(1.0)
	check(gary.state != 4, "Gary gives up when the player reaches the office")
	await use("Interactables/GaryLocker")
	check(bool(Save.progress["keycard"]), "keycard found in Gary's locker")


func _night5() -> void:
	print("\n--- Night 5 ---")
	await start_night(5)
	await use("Interactables/PunchClock")
	check(Shift.is_task_active("vault"), "unlock the vault task")
	await use("DoorVault/Body/Use")
	check(museum.get_node("DoorVault").is_open(), "vault opened with the keycard")
	await use("Duck")
	check(player.carrying == "duck", "took the Duck")
	check(museum.get_node("Knight").active and museum.get_node("Gary").enabled and museum.get_node("Duchess").enabled, "everything wakes up")
	await put_player(Vector3(6, 0.05, -26.5), Vector3(6, 1.0, -28.5))
	await frames(10)
	if hud._reading:
		hud.close_note()
	await frames(2)
	check(Shift.is_task_done("altar"), "Duck placed on the altar")
	await use("Interactables/AltarMelt")
	check(Save.progress["endings"].has("melt"), "melt ending reached")
