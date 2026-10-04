extends NightBase
## NIGHT 5 - Closing Time. The truth about the Duck, Brenda and the founder.
## Unlock the vault in the basement, carry the Duck down while the whole museum wakes up,
## and get past Sir Archibald Pemberton himself.

const DOORS := ["DoorCurio", "DoorCurio2", "DoorWax", "DoorWax2", "DoorLibrary", "DoorPlanet", "DoorNatural",
		"DoorArmory", "DoorWorkshop", "DoorCostume", "DoorToyArmory", "DoorArchives"]

var _awake := false


func note_ids() -> Array:
	return [9, 16]


func tape_ids() -> Array:
	return [10, 12]


func battery_count() -> int:
	return 6


func film_count() -> int:
	return 5


func scares() -> Array:
	return [
		{"room": "boiler", "hour": 0, "type": "radio", "text": "(an old man's voice, on a gramophone that isn't there) ...my Duck. My Duck. My Duck.", "voice": "My Duck. My Duck. My Duck."},
		{"room": "archives", "hour": 1, "type": "apparition", "pos": Vector3(-6.0, -4.5, -21.0)},
		{"room": "toyroom", "hour": 2, "type": "giggle", "pos": Vector3(12, 6.2, 16)},
		{"room": "lobby", "hour": 3, "type": "lights"},
	]


func banter() -> Array:
	if _awake:
		return []
	return [
		"Whatever happens tonight... thank you for coming back. Five nights. That's a record. Gary did four and a half.",
		"I used to bring Lucy here on Sundays. She called the T-Rex Uncle Gerald. He liked that. He still does.",
		"Do you ever get the feeling the building is holding its breath? Tonight it's been holding it since eleven.",
		"If you see a man in a top hat downstairs, don't shake his hand. Don't take his card. Don't answer his questions.",
	]


func setup(restoring: bool) -> void:
	Music.set_base("tense")
	open_doors(DOORS)
	open_stairs()
	start_basics(true, restoring)
	mummy().enabled = true
	player.has_camera = true
	player.film = maxi(player.film, 3)
	set_active("BrendaReveal", true)
	set_active("WindCrank", true)
	if restoring:
		if flag("vault_open", false):
			open_door("DoorVault", true)
		_restore_duck_state()
		return
	brenda("Last night of your first week. Clock in. Then we need to talk. Properly.", 5.0)


func handle(action: String, n: Node) -> bool:
	match action:
		"clock_in":
			if Shift.is_task_done("clock_in"):
				return true
			player.play_sfx(preload("res://audio/stamp.wav"))
			Shift.complete_task("clock_in")
			brenda("Okay. The truth. The Golden Duck isn't just valuable. It's cursed. It wakes everything it owns.", 6.0)
			brenda("Everything in this museum. Everyone who stays too long. Gary. ...Others.", 5.0)
			brenda("Pemberton built a vault under the museum. Basement, past the Archives. There's an altar. The Duck has to go there.", 6.5)
			if bool(Save.progress.get("keycard", false)):
				Shift.add_task("vault", "Unlock the Founder's Vault (basement, past the Archives) with Gary's keycard")
			else:
				Shift.add_task("locker", "Get the vault keycard from Gary's locker (Wax Hall)")
				set_active("GaryLocker", true)
			Shift.add_task("survive", "Finish before 6:00 AM")
			return true
		"gary_locker":
			n.active = false
			Save.progress["keycard"] = true
			Save.save_all()
			Save.add_note(10)
			hud.show_note(10)
			Shift.complete_task("locker")
			Shift.add_task("vault", "Unlock the Founder's Vault (basement, past the Archives) with Gary's keycard")
			return true
		"locked_door":
			if n.get_parent().get_parent().name == "DoorVault" and Shift.is_task_active("vault"):
				open_door("DoorVault")
				set_flag("vault_open", true)
				Shift.complete_task("vault")
				Shift.add_task("take_duck", "Take the Golden Duck from its pedestal in the lobby")
				set_active("Duck", true)
				brenda("The vault's open. Now the Duck. The moment you lift it, everything wakes up. EVERYTHING.", 5.5)
				brenda("Don't stop. Don't drop it. Don't look back. Well - look back at the armour.", 4.5)
				return true
			return false
		"duck":
			player.carrying = "duck"
			n.visible = false
			n.active = false
			player.play_sfx(preload("res://audio/quack.wav"))
			Shift.complete_task("take_duck")
			Shift.add_task("altar", "Carry the Golden Duck down to the altar in the Vault (basement)")
			set_flag("has_duck", true)
			_wake_everything()
			return true
		"brenda_figure":
			Music.sting("sting_reveal", -4.0, 2.0)
			Shift.say("Her plaque reads: BRENDA HOLLOWAY, HEAD OF NIGHT SECURITY, 1962-1963. The radio in her hand is warm.", "", 6.0)
			get_tree().create_timer(6.0).timeout.connect(func() -> void:
				brenda("...Hi, new guy. Yes. That's me. I didn't know how to tell you. Please keep going.", 5.0))
			n.active = false
			return true
		"wind_automaton":
			automaton().wind()
			return true
		"ending_melt":
			set_active("AltarMelt", false)
			set_active("AltarKeep", false)
			brenda("Thank you. Tell Lucy... tell her Mummy's finally clocking out.", 5.0)
			get_tree().create_timer(5.5).timeout.connect(func() -> void:
				game.play_ending([
					["6:00 AM", "The Duck melts with a very small, very sad quack."],
					["", "Somewhere upstairs, a radio clicks off for the first time in sixty years."],
					["THE MORNING AFTER", "The armour stayed empty. The mummy stayed asleep. Gary's wax was found folded neatly in his locker, with a thank-you note."],
					["", "The Director found a yellow raincoat on the coat hook in the lobby. It was dry. It was warm.\nShe sat with it for a long time."],
					["", "You were fired for destroying the most valuable object in the museum.\nThe next day, you were rehired. As Head of Night Security."],
					["THANK YOU FOR CLOCKING IN", "- B."],
				], "dawn", "melt"))
			return true
		"ending_keep":
			set_active("AltarMelt", false)
			set_active("AltarKeep", false)
			pemberton().say("Splendid. Splendid! Welcome to the collection.")
			get_tree().create_timer(4.5).timeout.connect(func() -> void:
				game.play_ending([
					["THE NIGHT SHIFT NEVER ENDS", "You kept the Duck. The Duck kept you."],
					["", "Brenda never clocked out. Neither did you."],
					["SIXTY YEARS LATER", "A new guard clocks in. A voice on the radio says: 'Evening, new guy.'"],
					["", "It's your voice."],
				], "credits", "keep"))
			return true
	return false


func _wake_everything() -> void:
	_awake = true
	Music.set_base("finale")
	Music.sting("sting_reveal", -2.0, 2.0)
	player.shake(0.8)
	knight().activate()
	knight().speed = 2.8
	mummy().wake("duck")
	automaton().set_enabled(true)
	automaton().spring = 15.0
	automaton().drain = 2.0
	duchess().set_enabled(true, 20.0)
	duchess().interval = Vector2(28, 40)
	gary().set_enabled(true)
	gary().chase_speed = 3.9
	for d in dolls():
		d.active = true
	for room in ["library", "natural"]:
		var m := moths(room)
		if m:
			m.set_enabled(true)
	for l in get_tree().get_nodes_in_group("flicker_lights"):
		l.burst(3.0)
	Shift.say("Every exhibit in the museum turns its head toward you.", "", 4.0)
	get_tree().create_timer(4.5).timeout.connect(func() -> void:
		brenda("GO. Storage, down the stairs, through the Archives. Use the camera if anything gets close!", 5.0))


func on_hour(h: int, silent: bool) -> void:
	match h:
		1:
			if not _awake:
				knight().activate()
				if not silent:
					brenda("The armour's up early tonight. It knows something's happening.", 4.5)
		2:
			if not _awake:
				gary().set_enabled(true)
				if not silent:
					brenda("Gary's on his rounds. Of course he is. Even tonight. Especially tonight.", 4.0)
		3:
			if not _awake:
				automaton().set_enabled(true)
				automaton().drain = 1.4
				brenda("Wolfgang's spring is running. One more thing to juggle. Sorry.", 4.0)
		4:
			if not silent and not _awake:
				brenda("Two hours left. Please. I've waited sixty years. I can't wait another week.", 5.0)
		5:
			brenda("One hour left. If the sun comes up with the Duck awake... we all stay. Forever. Hurry.", 5.5)


func tick(_delta: float) -> void:
	var a := automaton()
	if a.enabled:
		hud.set_meter("LITTLE WOLFGANG'S SPRING" if not a.is_hunting() else "WOLFGANG IS LOOSE", a.spring, true)
	if player.carrying == "duck" and player.current_level < 0 and not flag("pemberton", false):
		set_flag("pemberton", true)
		pemberton().awaken()
		get_tree().create_timer(4.0).timeout.connect(func() -> void:
			brenda("That's HIM. Pemberton. Flash him with the camera - he hates photographs. Then RUN.", 5.0))
	if player.carrying == "duck" and player.current_room == "vault" and Shift.is_task_active("altar"):
		var spot: Node3D = node("DuckAltarSpot")
		if player.global_position.distance_to(spot.global_position) < 3.2:
			_place_on_altar()


func _place_on_altar() -> void:
	player.carrying = ""
	Shift.complete_task("altar")
	var duck := node("Duck")
	duck.global_position = node("DuckAltarSpot").global_position
	duck.visible = true
	duck.active = false
	knight().active = false
	gary().set_enabled(false)
	automaton().set_enabled(false)
	duchess().set_enabled(false)
	pemberton().sleep_forever()
	for d in dolls():
		d.active = false
	for room in ["library", "natural"]:
		var m := moths(room)
		if m:
			m.set_enabled(false)
	mummy().enabled = false
	hud.set_meter("", 0.0, false)
	Music.set_base("silence")
	Music.play_now("brenda")
	Music.sting("sting_reveal", -2.0, 3.0)
	Shift.say("The museum falls silent. Everything is waiting for you.", "", 5.0)
	get_tree().create_timer(5.5).timeout.connect(func() -> void:
		brenda("...You did it. I can feel my hands again. I'd forgotten what that was like.", 5.0)
		brenda("Listen. If you melt it, it's over. All of it. Gary. Me. We get to go home.", 5.5)
		brenda("If you keep it... you'll never be fired. You'll never be anything else, either. Your choice. I mean it.", 6.0)
		Save.add_note(17)
		hud.show_note(17)
		set_active("AltarMelt", true)
		set_active("AltarKeep", true)
		Shift.add_task("choice", "Decide the Duck's fate"))


func _restore_duck_state() -> void:
	if flag("vault_open", false) and not flag("has_duck", false):
		set_active("Duck", true)
	elif flag("has_duck", false):
		# Resuming mid-run: the Duck goes back to its pedestal, everything stays asleep until it's lifted again.
		set_active("Duck", true)
		set_flag("has_duck", false)
		set_flag("pemberton", false)
		Shift.remove_task("altar")
		Shift.remove_task("take_duck")
		Shift.flags.erase("take_duck")
		var t := Shift._find_task("take_duck")
		if t == {}:
			Shift.tasks.append({"id": "take_duck", "text": "Take the Golden Duck from its pedestal in the lobby", "goal": 1, "progress": 0, "done": false})
			Shift.tasks_changed.emit()


func finish() -> void:
	game._death_screen("TOO LATE", "The sun came up with the Duck still awake.\nYou are now Exhibit #47: 'Night Guard, Slightly Surprised.'")
