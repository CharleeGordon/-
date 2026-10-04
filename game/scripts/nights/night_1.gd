extends NightBase
## NIGHT 1 - Orientation. Ground floor and the boiler room. Learn the rules: the armour,
## the mummy, the shy T-Rex, the blackout (the breaker is in the basement...), the Duck.


func note_ids() -> Array:
	return [1, 2, 3, 6, 7]


func tape_ids() -> Array:
	return [1, 2, 3]


func battery_count() -> int:
	return 5


func scares() -> Array:
	return [
		{"room": "gallery", "hour": 2, "type": "apparition", "pos": Vector3(-9.5, 0, -20.5)},
		{"room": "boiler", "hour": 3, "type": "radio", "text": "(a voice on the radio that is not Brenda) ...is that... my Duck...?", "voice": "Is that my Duck? Who is touching my Duck?"},
		{"room": "egypt", "hour": 4, "type": "lights"},
		{"room": "storage", "hour": 1, "type": "steps"},
	]


func banter() -> Array:
	return [
		"Fun fact: we were voted third most haunted building in the county. We were robbed. We are easily first.",
		"If you hear clanking, that's the armour. If you hear tap dancing... that's also the armour. He's been practising.",
		"Don't feed Gerald. He has no stomach. It just falls straight through. We learned that the hard way.",
		"The vending machine in the lobby is not haunted. It's just evil. Different department.",
		"Reminder: the gift shop runs on an honesty box. The exhibits have never paid. Not once.",
		"You're doing great. Statistically you should have screamed twice by now. I'm impressed.",
	]


func setup(restoring: bool) -> void:
	Music.set_base("calm")
	start_basics(false, restoring)
	mummy().enabled = true
	if restoring:
		player.give_flashlight()
		restore_checkpoints()
		return
	brenda("Evening, new guy. Welcome to the Pemberton Museum of Questionable History. I'm Brenda, Head of Night Security.", 6.0)
	brenda("First things first: clock in. The punch clock is on the wall of your office.", 5.0)


func handle(action: String, n: Node) -> bool:
	match action:
		"clock_in":
			if Shift.is_task_done("clock_in"):
				Shift.alert.emit("You already clocked in. The clock looks proud of you.")
				return true
			player.play_sfx(preload("res://audio/stamp.wav"))
			Shift.complete_task("clock_in")
			Shift.add_task("rules", "Read the Museum Rules poster")
			Shift.add_task("flashlight", "Take the flashlight from the desk")
			brenda("Good. Now read the rules poster. All of it. Especially the weird ones. They're all weird.", 4.5)
			return true
		"rules":
			hud.open_journal()
			Shift.complete_task("rules")
			Shift.alert.emit("Rules added to your journal (TAB).")
			_after_basics()
			return true
		"flashlight":
			player.give_flashlight()
			n.queue_free()
			player.play_sfx(preload("res://audio/pickup.wav"), -4.0)
			Shift.complete_task("flashlight")
			Shift.alert.emit("Got the flashlight. F to toggle. Mind the battery.")
			_after_basics()
			return true
		"checkpoint_gallery", "checkpoint_egypt", "checkpoint_dino":
			if not Shift.has_task("patrol"):
				Shift.alert.emit("Patrol checkpoint. Finish the basics in your office first.")
				return true
			scan_checkpoint(n)
			if Shift.is_task_done("patrol"):
				brenda("Patrol done. Now just survive till six. Easy. Probably. Mostly. Sort of.", 4.0)
			return true
		"checkpoint_curio":
			return false
		"duck":
			player.carrying = "duck"
			n.visible = false
			n.active = false
			set_active("DuckPedestal", true)
			player.play_sfx(preload("res://audio/quack.wav"))
			Shift.alert.emit("You found the Golden Duck. It quacked at you. Return it to its pedestal in the lobby.")
			return true
		"duck_pedestal":
			if player.carrying != "duck":
				return true
			player.carrying = ""
			var duck := node("Duck")
			duck.global_position = node("DuckPedestal").global_position + Vector3(0, 1.12, 0)
			duck.visible = true
			set_active("DuckPedestal", false)
			player.play_sfx(preload("res://audio/quack.wav"), -2.0)
			Shift.complete_task("duck")
			set_flag("duck_returned", true)
			brenda("The Duck is back. The museum is whole again. I may cry. I won't. But I may.", 4.0)
			return true
	return false


func _after_basics() -> void:
	if Shift.is_task_done("rules") and Shift.is_task_done("flashlight") and not Shift.has_task("patrol"):
		Shift.add_task("patrol", "Patrol: scan the checkpoints in the Gallery, Egyptian Hall and Dinosaur Hall", 3)
		Shift.add_task("survive", "Survive until 6:00 AM")
		brenda("Now patrol. Scan the checkpoint panels in the Gallery, the Egyptian Hall and the Dinosaur Hall.", 5.5)
		brenda("And look around. Previous guards left notes and tapes everywhere. Messy people. Lovely people. Mostly wax now. Joking.", 5.5)


func on_hour(h: int, silent: bool) -> void:
	match h:
		1:
			knight().activate()
			if not silent:
				brenda("Quick heads-up. If the armour by the office moves... just keep looking at it.", 5.0)
				brenda("Sir Clanksworth is shy too. A different kind of shy. The stabby kind.", 4.0)
		2:
			if not silent:
				brenda("Two o'clock. Remember: no running in the Egyptian Hall. I'm serious. HR is serious. HR is a mummy.", 5.0)
		3:
			Music.set_base("blackout")
			Shift.set_power(false)
			Shift.add_task("breaker", "Power is out! Flip the main breaker in the BASEMENT boiler room (stairs in Storage)")
			brenda("Power's out. The main breaker is in the basement. Through Storage, down the stairs. Bring your flashlight.", 5.5)
			brenda("I'm sorry. Nobody likes the basement. The basement doesn't like anybody either.", 4.0)
		4:
			Music.set_base("tense")
			knight().speed = 2.6
			_steal_duck()
		5:
			brenda("Last hour. Funny thing: the mummy just sat up on camera. Not funny, actually. Not at all.", 5.0)
			mummy().wake("hour5")


func tick(_delta: float) -> void:
	if Shift.power_on and Music.base == "blackout":
		Music.set_base("tense")


func _steal_duck() -> void:
	var spots: Array = museum.get_node("DuckSpots").get_children().slice(0, 5)
	var spot: Node3D = spots[randi() % spots.size()]
	var duck := node("Duck")
	duck.global_position = spot.global_position
	duck.visible = true
	duck.active = true
	Shift.add_task("duck", "Someone stole the Golden Duck! Find it and put it back")
	brenda("The Golden Duck is gone. Our most valuable exhibit. Find it. Don't ask how I know. I always know.", 6.0)
