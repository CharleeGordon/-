extends NightBase
## NIGHT 2 - Clockwork. The Hall of Curiosities and the first rooms upstairs open.
## Keep Little Wolfgang wound, fix the lights, meet the Tea Party, get the camera.

var _sword: Interactable
var _return_spot: Interactable


func note_ids() -> Array:
	return [4, 5, 8, 9]


func tape_ids() -> Array:
	return [4, 11]


func battery_count() -> int:
	return 5


func film_count() -> int:
	return 3


func scares() -> Array:
	return [
		{"room": "toyroom", "hour": 0, "type": "giggle", "pos": Vector3(12, 6.2, 16)},
		{"room": "curio", "hour": 2, "type": "slam"},
		{"room": "director", "hour": 3, "type": "steps"},
		{"room": "lobby", "hour": 4, "type": "apparition", "pos": Vector3(0, 5.5, -8.5)},
	]


func banter() -> Array:
	return [
		"Little Wolfgang's song is called The Pemberton Waltz. It's the only song he knows. He has played it four hundred thousand times. He is not tired of it. I am.",
		"The Director says hello. I've never actually met the Director. She leaves notes. Lovely handwriting.",
		"If a doll asks you to tea, the correct answer is no thank you, I'm driving.",
		"Did you know the Tea Party has six cups and five dolls? Please don't think about that too hard.",
		"The sword incident is the third this month. Sir Clanksworth is very careless with his pointy things.",
		"Upstairs is lovely. Upstairs has carpets. Upstairs also has the dolls. Swings and roundabouts.",
	]


func setup(restoring: bool) -> void:
	Music.set_base("calm")
	open_doors(["DoorCurio", "DoorCurio2"])
	open_stairs()
	start_basics(true, restoring)
	mummy().enabled = true
	set_active("WindCrank", true)
	set_active("CameraPickup", true)
	if restoring:
		restore_checkpoints()
		_restore_bulbs()
		_restore_items()
		return
	brenda("Night two! You came back. Most people don't. That's a joke. Mostly.", 4.5)
	brenda("Big night. The Curiosities hall is open, and so is part of upstairs. Clock in and I'll explain.", 5.0)


func handle(action: String, n: Node) -> bool:
	match action:
		"clock_in":
			if Shift.is_task_done("clock_in"):
				return true
			player.play_sfx(preload("res://audio/stamp.wav"))
			Shift.complete_task("clock_in")
			Shift.add_task("camera", "Collect your new equipment from the Director's office (upstairs)")
			Shift.add_task("patrol", "Patrol: scan the checkpoints (Gallery, Egyptian Hall, Dinosaur Hall, Curiosities)", 4)
			Shift.add_task("bulbs", "Replace the 3 dead bulbs in the Hall of Curiosities (spares are in Storage)", 3)
			Shift.add_task("wind", "Keep Little Wolfgang wound up (Hall of Curiosities)")
			Shift.add_task("survive", "Survive until 6:00 AM")
			set_active("BulbBox", true)
			for i in 3:
				set_active("Socket%d" % (i + 1), true)
			brenda("First: the Director left you a present upstairs. Grand staircase, then the office at the back.", 5.0)
			brenda("Then: in the Curiosities hall there's a clockwork boy, Little Wolfgang. When his music slows down, wind him. When it stops... hide.", 6.0)
			return true
		"camera":
			player.has_camera = true
			player.film += 3
			n.queue_free()
			player.play_sfx(preload("res://audio/pickup.wav"), -2.0)
			Shift.complete_task("camera")
			Shift.alert.emit("Instant camera! R (or right mouse) for a blinding flash that stuns exhibits.")
			brenda("An instant camera! Museum photography is strictly forbidden. Use it anyway. Just never on Gerald.", 5.0)
			brenda("While you're up there, pop into the Toy Room and check on the Tea Party. Don't take your eyes off them.", 5.0)
			Shift.add_task("teaparty", "Check on the Tea Party in the Toy Room (upstairs)")
			set_flag("camera", true)
			return true
		"checkpoint_gallery", "checkpoint_egypt", "checkpoint_dino", "checkpoint_curio":
			scan_checkpoint(n)
			return true
		"wind_automaton":
			if automaton().is_hunting():
				Shift.alert.emit("He's not in his booth. WHERE IS HE.")
				return true
			automaton().wind()
			Shift.alert.emit("Wound up. The music perks up. So does he.")
			return true
		"take_bulbs":
			if player.carrying == "bulbs":
				return true
			var left := 3 - int(flag("bulbs_done", 0))
			if left <= 0:
				return true
			player.carrying = "bulbs"
			player.carry_count = left
			player.play_sfx(preload("res://audio/pickup.wav"), -4.0)
			Shift.alert.emit("Took %d light bulbs." % left)
			return true
		"install_bulb":
			if player.carrying != "bulbs":
				Shift.alert.emit("You need a light bulb. Spares are in Storage.")
				return true
			n.active = false
			player.carry_count -= 1
			if player.carry_count <= 0:
				player.carrying = ""
			set_flag("bulbs_done", int(flag("bulbs_done", 0)) + 1)
			var lit: Array = flag("bulbs_lit", [])
			lit.append(String(n.name))
			set_flag("bulbs_lit", lit)
			_light_socket(n)
			player.play_sfx(preload("res://audio/bulb.wav"), -2.0)
			Shift.progress_task("bulbs")
			return true
		"sword":
			player.carrying = "sword"
			n.queue_free()
			_sword = null
			player.play_sfx(preload("res://audio/pickup.wav"), -4.0)
			_return_spot.active = true
			Shift.alert.emit("Got the sword. Now give it back to Sir Clanksworth. Carefully. Keep looking at him.")
			return true
		"return_sword":
			if player.carrying != "sword":
				return true
			player.carrying = ""
			_return_spot.active = false
			player.play_sfx(preload("res://audio/knight_step_1.wav"))
			Shift.complete_task("sword")
			brenda("He took it. Did he say thank you? He never says thank you. Raised in a forge.", 4.0)
			return true
	return false


func tick(_delta: float) -> void:
	if Shift.power_on and Music.base == "blackout":
		Music.set_base("tense")
		automaton().drain = 1.2 if Shift.hour < 5 else 2.2
	if Shift.is_task_active("teaparty") and player.current_room == "toyroom":
		Shift.complete_task("teaparty")
		brenda("There they are. Five dolls, six cups. Remember: they only move when you're not looking. So... look.", 5.0)
	var a := automaton()
	if a.enabled:
		hud.set_meter("LITTLE WOLFGANG'S SPRING" if not a.is_hunting() else "WOLFGANG IS LOOSE", a.spring, true)
	else:
		hud.set_meter("", 0.0, false)


func on_hour(h: int, silent: bool) -> void:
	match h:
		1:
			knight().activate()
			automaton().set_enabled(true)
			automaton().drain = 1.2
			for d in dolls():
				d.active = true
			if not silent:
				brenda("Wolfgang's spring is running. And the dolls upstairs are... awake. Don't go in there without looking.", 5.0)
		2:
			if not silent:
				_drop_sword(true)
			elif Shift.is_task_active("sword"):
				_drop_sword(false)
		3:
			Music.set_base("blackout")
			Shift.set_power(false)
			automaton().drain = 1.6
			Shift.add_task("breaker", "Power is out! Flip the main breaker in the basement boiler room")
			brenda("Power's out again. The breaker hates me personally. Basement, please. Mind the stairs. Mind everything.", 5.0)
		4:
			Music.set_base("tense")
			knight().speed = 2.6
			if not silent:
				brenda("Four o'clock. The armour is getting bolder. So am I. I had a second biscuit.", 4.5)
		5:
			automaton().drain = 2.2
			brenda("Wolfgang's getting impatient. Wind him more often. MUCH more often.", 4.5)


func finish() -> void:
	Shift.complete_task("wind")
	automaton().set_enabled(false)
	hud.set_meter("", 0.0, false)
	super.finish()


func _drop_sword(announce: bool) -> void:
	if announce:
		Shift.add_task("sword", "Sir Clanksworth dropped his sword. Find it and give it back to him")
		brenda("Sir Clanksworth dropped his sword. He won't stop clanking until he gets it back.", 5.0)
	var spots: Array = museum.get_node("DuckSpots").get_children()
	var spot: Node3D = spots[randi() % 5]
	_sword = game._pickup("Sword", "sword", "Take the sword", spot.global_position)
	var blade := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.06, 0.02, 1.0)
	m.material = preload("res://materials/metal.tres")
	blade.mesh = m
	blade.position = Vector3(0, 0.02, 0)
	blade.rotation.y = randf() * TAU
	_sword.add_child(blade)
	_return_spot = Interactable.new()
	_return_spot.name = "ReturnSword"
	_return_spot.action_id = "return_sword"
	_return_spot.prompt = "Give the sword back"
	_return_spot.active = false
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.0, 1.8, 1.0)
	cs.shape = sh
	cs.position = Vector3(0, 0.9, 0)
	_return_spot.add_child(cs)
	_return_spot.monitoring = false
	knight().add_child(_return_spot)


func _light_socket(n: Node) -> void:
	var bulb := OmniLight3D.new()
	bulb.light_color = Color(1.0, 0.85, 0.6)
	bulb.light_energy = 1.4
	bulb.omni_range = 7.0
	bulb.add_to_group("room_lights", true)
	bulb.add_to_group("lights_curio", true)
	museum.add_child(bulb)
	bulb.global_position = n.global_position + Vector3(0, 0.2, -0.2)


func _restore_bulbs() -> void:
	for nm in flag("bulbs_lit", []):
		var s := museum.get_node_or_null("Interactables/" + nm)
		if s:
			s.active = false
			_light_socket(s)


func _restore_items() -> void:
	if flag("camera", false):
		player.has_camera = true
		player.film = maxi(player.film, 2)
		var c := museum.get_node_or_null("Interactables/CameraPickup")
		if c:
			c.queue_free()
