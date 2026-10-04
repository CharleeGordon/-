extends NightBase
## NIGHT 4 - The Other Guard. Budget cuts (dark wings), every door open, both floors.
## Gary, the waxed-up previous guard, patrols upstairs and down. His locker holds the vault keycard.

const DOORS := ["DoorCurio", "DoorCurio2", "DoorWax", "DoorWax2", "DoorLibrary", "DoorPlanet", "DoorNatural",
		"DoorArmory", "DoorWorkshop", "DoorCostume", "DoorToyArmory", "DoorArchives"]


func note_ids() -> Array:
	return [11, 15, 16]


func tape_ids() -> Array:
	return [5, 6, 8, 9]


func battery_count() -> int:
	return 6


func film_count() -> int:
	return 4


func scares() -> Array:
	return [
		{"room": "costume", "hour": 1, "type": "giggle", "pos": Vector3(-13, 6.0, 15)},
		{"room": "workshop", "hour": 2, "type": "slam"},
		{"room": "archives", "hour": 3, "type": "radio", "text": "(a woman's voice, very far away, very scared) ...Lucy? Lucy, is that you...?", "voice": "Lucy? Lucy, is that you?"},
		{"room": "natural", "hour": 4, "type": "lights"},
		{"room": "wax", "hour": 5, "type": "apparition", "pos": Vector3(-20, 0, 12)},
	]


func banter() -> Array:
	return [
		"Gary was a good guard. Punctual. Polite. Slightly flammable now, but nobody's perfect.",
		"If Gary asks to see your ID, just show him. It confuses him. He forgets what an ID is.",
		"The squeaky ducks in the gift shop are two for a pound. Gary can't resist a squeak. Nobody can, really.",
		"The Costume Gallery has forty empty costumes. Count them. If there are forty-one, don't count again.",
		"The Archives are open for the first time in sixty years. Mind the dust. Some of it is... previous staff.",
		"Budget cuts note: we've replaced the alarm system with me. I am the alarm system. Aaaah. See? Works.",
	]


func setup(restoring: bool) -> void:
	Music.set_base("tense")
	open_doors(DOORS)
	open_stairs()
	start_basics(true, restoring)
	mummy().enabled = true
	player.has_camera = true
	player.film = maxi(player.film, 2)
	set_active("WindCrank", true)
	set_flag("dark_rooms", ["wax", "storage", "curio", "costume", "workshop"])
	game.apply_lights()
	set_active("GaryLocker", not bool(Save.progress.get("keycard", false)))
	if restoring:
		restore_checkpoints()
		return
	brenda("Bad news: budget cuts. Half the lights are off, on both floors. Good news: there's no good news.", 6.0)
	brenda("Every door is open tonight. Even the Archives in the basement. Clock in.", 4.0)


func handle(action: String, n: Node) -> bool:
	match action:
		"clock_in":
			if Shift.is_task_done("clock_in"):
				return true
			player.play_sfx(preload("res://audio/stamp.wav"))
			Shift.complete_task("clock_in")
			Shift.add_task("patrol", "Patrol: scan the checkpoints (Gallery, Egyptian Hall, Dinosaur Hall, Curiosities)", 4)
			Shift.add_task("ducks", "Grab a crate of squeaky ducks from the gift shop (lobby). Throw them (G) to distract")
			if not bool(Save.progress.get("keycard", false)):
				Shift.add_task("locker", "Search Gary's old locker in the Wax Hall")
			Shift.add_task("archives", "Find the 1963 staff file in the Archives (basement)")
			Shift.add_task("survive", "Survive until 6:00 AM")
			set_active("ArchiveFile", true)
			brenda("Gary's things are still in his locker in the Wax Hall. HR wants them. Grab whatever's in there.", 5.0)
			brenda("And... could you look in the Archives for me? There's a staff file from 1963. Holloway. It's personal.", 6.0)
			return true
		"take_ducks":
			Shift.complete_task("ducks")
			return false
		"checkpoint_gallery", "checkpoint_egypt", "checkpoint_dino", "checkpoint_curio":
			scan_checkpoint(n)
			return true
		"wind_automaton":
			automaton().wind()
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
		"archive_file":
			n.active = false
			Shift.complete_task("archives")
			player.play_sfx(preload("res://audio/pickup.wav"), -4.0)
			Music.sting("sting_reveal", -6.0, 2.0)
			Shift.say("STAFF FILE: B. HOLLOWAY. Head of Night Security. Hired 1962. Status: MISSING, 12 Nov 1963. Next of kin: Lucy Holloway (daughter, age 7).", "", 8.0)
			get_tree().create_timer(8.5).timeout.connect(func() -> void:
				brenda("...Thank you. I just wanted to know someone wrote it down.", 4.5)
				brenda("Lucy had a yellow raincoat. She wore it every day. Even when it was sunny. Especially then.", 5.5))
			return true
		"brenda_figure":
			return false
	return false


func on_hour(h: int, silent: bool) -> void:
	match h:
		1:
			gary().set_enabled(true)
			for d in dolls():
				d.active = true
			if not silent:
				Music.sting("sting_reveal", -6.0, 2.0)
				brenda("Someone's on the cameras. Wearing OUR uniform. Walking OUR route. Whistling.", 5.0)
				brenda("...That's Gary. Or what's left of him. Stay out of his flashlight. Hide in a locker if he spots you.", 6.0)
		2:
			var m := moths("natural")
			if m:
				m.set_enabled(true)
			if not silent:
				brenda("Tip: he can hear you run. Walk. Crouch if he's close. Throw a squeaky duck and he'll go and check on it. Every time.", 6.0)
		3:
			knight().activate()
			Music.set_base("blackout")
			Shift.set_power(false)
			Shift.add_task("breaker", "Power is out! Flip the main breaker in the basement boiler room")
			brenda("Power's out. And the armour just woke up. And Gary's still out there. I'm so sorry.", 5.0)
		4:
			Music.set_base("tense")
			knight().speed = 2.4
			if not silent:
				brenda("Four AM. Is it me or is the museum... listening? It's been listening since you got that keycard.", 5.0)
		5:
			gary().walk_speed = 2.0
			gary().chase_speed = 4.1
			brenda("Last hour. Gary's walking faster. I think he wants to clock out too. We all do.", 4.5)


func tick(_delta: float) -> void:
	if Shift.power_on and Music.base == "blackout":
		Music.set_base("tense")
		game.apply_lights()


func finish() -> void:
	gary().set_enabled(false)
	var m := moths("natural")
	if m:
		m.set_enabled(false)
	super.finish()
