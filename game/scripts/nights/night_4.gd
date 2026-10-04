extends NightBase
## NIGHT 4 - The Other Guard. Budget cuts (dark wings). Gary, the waxed-up previous guard, does his rounds.


func note_ids() -> Array:
	return [11]


func battery_count() -> int:
	return 6


func setup(restoring: bool) -> void:
	Music.set_base("tense")
	for d in ["DoorCurio", "DoorCurio2", "DoorWax", "DoorWax2"]:
		open_door(d, true)
	start_basics(true, restoring)
	mummy().enabled = true
	set_flag("dark_rooms", ["wax", "storage", "curio"])
	game.apply_lights()
	set_active("GaryLocker", not bool(Save.progress.get("keycard", false)))
	if restoring:
		restore_checkpoints()
		return
	brenda("Bad news: budget cuts. Half the lights are off in the west and south wings. Good news: there's no good news.", 6.0)
	brenda("The Wax Hall reopened today. Clock in.", 3.5)


func handle(action: String, n: Node) -> bool:
	match action:
		"clock_in":
			if Shift.is_task_done("clock_in"):
				return true
			player.play_sfx(preload("res://audio/stamp.wav"))
			Shift.complete_task("clock_in")
			Shift.add_task("patrol", "Patrol: scan the checkpoints (Gallery, Egyptian Hall, Dinosaur Hall, Curiosities)", 4)
			if not bool(Save.progress.get("keycard", false)):
				Shift.add_task("locker", "Search Gary's old locker in the Wax Hall")
			Shift.add_task("survive", "Survive until 6:00 AM")
			brenda("Gary's things are still in his locker in the Wax Hall. HR wants them. Grab whatever's in there.", 5.0)
			return true
		"checkpoint_gallery", "checkpoint_egypt", "checkpoint_dino", "checkpoint_curio":
			scan_checkpoint(n)
			return true
		"gary_locker":
			n.active = false
			Save.progress["keycard"] = true
			Save.save_all()
			Shift.complete_task("locker")
			Save.add_note(10)
			hud.show_note(10)
			player.play_sfx(preload("res://audio/locker_open.wav"), -4.0)
			Shift.alert.emit("Found a vault keycard and a note.")
			get_tree().create_timer(0.5).timeout.connect(func() -> void:
				brenda("...A keycard. To the vault. Hold onto that. We'll talk tomorrow.", 4.5))
			return true
		"brenda_figure":
			return false
	return false


func on_hour(h: int, silent: bool) -> void:
	match h:
		1:
			gary().set_enabled(true)
			if not silent:
				Music.sting("sting_reveal", -6.0, 2.0)
				brenda("Someone's on the cameras. Wearing OUR uniform. Walking OUR route. Whistling.", 5.0)
				brenda("...That's Gary. Or what's left of him. Stay out of his flashlight. Hide in a locker if he spots you.", 6.0)
		2:
			if not silent:
				brenda("Tip: he can hear you run. Walk. Crouch if he's close. The office cameras can show you where he is.", 5.5)
		3:
			knight().activate()
			Music.set_base("blackout")
			Shift.set_power(false)
			Shift.add_task("breaker", "Power is out! Flip the main breaker in Storage")
			brenda("Power's out. And the armour just woke up. And Gary's still out there. I'm so sorry.", 5.0)
		4:
			Music.set_base("tense")
			knight().speed = 2.4
		5:
			gary().walk_speed = 2.0
			gary().chase_speed = 4.1
			brenda("Last hour. Gary's walking faster. I think he wants to clock out too.", 4.5)


func tick(_delta: float) -> void:
	if Shift.power_on and Music.base == "blackout":
		Music.set_base("tense")
		game.apply_lights()


func finish() -> void:
	gary().set_enabled(false)
	super.finish()
