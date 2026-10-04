extends NightBase
## NIGHT 3 - Portrait Night. A storm. The Library and the Star Theatre open upstairs.
## Close the windows, re-shelve the books, switch off the 3 AM show. The Duchess watches.

const WINDOWS := ["WindowGallery", "WindowGallery2", "WindowDino1", "WindowDino2", "WindowLibrary1", "WindowLibrary2"]

var _lightning := 12.0
var _thunder: AudioStreamPlayer
var _moon: DirectionalLight3D
var _moon_energy := 0.55


func note_ids() -> Array:
	return [12, 13, 14]


func tape_ids() -> Array:
	return [7]


func film_count() -> int:
	return 3


func scares() -> Array:
	return [
		{"room": "library", "hour": 1, "type": "slam"},
		{"room": "planetarium", "hour": 2, "type": "radio", "text": "(the projector's speaker crackles) ...the three o'clock show is about to begin. Please take your seat. Forever.", "voice": "The three o'clock show is about to begin. Please take your seat. Forever."},
		{"room": "gallery", "hour": 4, "type": "apparition", "pos": Vector3(-11.0, 0, -11.5)},
		{"room": "balcony", "hour": 5, "type": "steps"},
	]


func banter() -> Array:
	return [
		"The Duchess was painted in 1790. She has been offended ever since. Nobody knows by what.",
		"Library rule: whisper. Library rule two: if the books whisper back, leave.",
		"Fun fact: the moths in the Library escaped in 1974. We consider them staff now. They don't get a pension.",
		"The Star Theatre runs a show at 3 AM. Nobody books it. The seats are always warm afterwards. Don't sit down.",
		"Sir Clanksworth wrote the Duchess a poem once. She had him repainted out of her background. Brutal.",
		"Lovely weather for it. For what? I'd rather not say.",
	]


func battery_count() -> int:
	return 5


func ambience() -> String:
	return "amb_rain"


func setup(restoring: bool) -> void:
	Music.set_base("storm")
	open_doors(["DoorCurio", "DoorCurio2", "DoorLibrary", "DoorPlanet"])
	open_stairs()
	set_active("WindCrank", true)
	start_basics(true, restoring)
	mummy().enabled = true
	_moon = museum.get_node("Moon")
	_moon_energy = _moon.light_energy
	_moon.light_color = Color(0.5, 0.58, 0.8)
	_moon.light_energy = 0.25
	_thunder = AudioStreamPlayer.new()
	_thunder.bus = "SFX"
	add_child(_thunder)
	if restoring:
		restore_checkpoints()
		player.has_camera = true
		player.film = maxi(player.film, 2)
		for w in WINDOWS:
			_set_window(w, not flag("closed", []).has(w))
		for b in ["Books1", "Books2", "Books3"]:
			set_active(b, not flag("shelved", []).has(b))
			_hide_pile(b, flag("shelved", []).has(b))
		return
	player.has_camera = true
	player.film = maxi(player.film, 2)
	for w in WINDOWS:
		_set_window(w, true)
	brenda("Big storm tonight. The wind blew windows open downstairs AND in the Library. Close them before the paintings get wet.", 6.0)
	brenda("Paintings HATE getting wet. You'll see. Clock in first.", 4.0)


func handle(action: String, n: Node) -> bool:
	match action:
		"clock_in":
			if Shift.is_task_done("clock_in"):
				return true
			player.play_sfx(preload("res://audio/stamp.wav"))
			Shift.complete_task("clock_in")
			Shift.add_task("windows", "Close the open windows (Gallery, Dinosaur Hall, Library upstairs)", WINDOWS.size())
			Shift.add_task("books", "Put the fallen books back on the shelves (Library)", 3)
			Shift.add_task("survive", "Survive until 6:00 AM")
			for b in ["Books1", "Books2", "Books3"]:
				set_active(b, true)
			brenda("The Library's open tonight. Somebody knocked the books off the shelves. Somebody with no hands. Please tidy up.", 6.0)
			brenda("One more thing. During storms the Duchess gets... attentive. If you hear whispering, FREEZE.", 5.5)
			brenda("And in the Library: if a cloud of moths comes for you, turn your flashlight OFF. They love it more than you do.", 6.0)
			return true
		"close_window":
			_set_window(String(n.name), false)
			var closed: Array = flag("closed", [])
			if not closed.has(String(n.name)):
				closed.append(String(n.name))
				set_flag("closed", closed)
			player.play_sfx(preload("res://audio/window_close.wav"), -2.0)
			if Shift.is_task_active("windows"):
				Shift.progress_task("windows")
			elif Shift.is_task_active("windows2"):
				Shift.progress_task("windows2")
			return true
		"reshelve":
			n.active = false
			var shelved: Array = flag("shelved", [])
			shelved.append(String(n.name))
			set_flag("shelved", shelved)
			_hide_pile(String(n.name), true)
			player.play_sfx(preload("res://audio/pickup.wav"), -6.0)
			Shift.make_noise(player.global_position, 6.0)
			Shift.progress_task("books")
			if Shift.is_task_done("books"):
				brenda("Books back. The Library sighs. Libraries can sigh. This one's been through a lot.", 4.5)
			return true
		"projector":
			n.active = false
			var proj := museum.get_node_or_null("Projector")
			if proj:
				proj.set("speed", 0.0)
				for c in proj.get_children():
					if c is SpotLight3D:
						c.visible = false
			player.play_sfx(preload("res://audio/breaker.wav"), -4.0)
			Shift.complete_task("projector")
			brenda("Show's over. Somewhere a ghost audience is very disappointed. Tough.", 4.0)
			return true
		"wind_automaton":
			automaton().wind()
			return true
		"checkpoint_gallery", "checkpoint_egypt", "checkpoint_dino", "checkpoint_curio":
			scan_checkpoint(n)
			return true
	return false


func on_hour(h: int, silent: bool) -> void:
	match h:
		1:
			knight().activate()
			var m := moths("library")
			if m:
				m.set_enabled(true)
			if not silent:
				brenda("The armour's awake. The thunder doesn't bother him. Nothing bothers him.", 4.5)
				brenda("And the moths are up in the Library. Light off when they swarm. Light off.", 4.5)
		2:
			duchess().set_enabled(true, 8.0 if silent else 25.0)
			duchess().interval = Vector2(45, 60)
			if not silent:
				brenda("I'm hearing whispers on the gallery microphone. She's up. Remember: whispers, then FREEZE.", 5.5)
		3:
			_flash(true)
			Music.set_base("blackout")
			Shift.set_power(false)
			Shift.add_task("breaker", "Lightning knocked the power out! Flip the breaker in the basement boiler room")
			Shift.add_task("projector", "Something started the 3 AM show in the Star Theatre. Switch the projector off")
			set_active("ProjectorSwitch", true)
			brenda("That one hit the building. Breaker, basement, you know the drill.", 4.5)
			brenda("...Hang on. The Star Theatre's projector just turned itself on. With no power. Go and turn it off. Please.", 6.0)
		4:
			Music.set_base("storm")
			duchess().interval = Vector2(30, 45)
			var reopen: Array = WINDOWS.duplicate()
			reopen.shuffle()
			var closed: Array = flag("closed", [])
			for i in 2:
				_set_window(reopen[i], true)
				closed.erase(reopen[i])
			set_flag("closed", closed)
			Shift.add_task("windows2", "The wind blew two windows open again. Close them", 2)
			brenda("Two windows blew open again. This building is held together by optimism.", 4.5)
		5:
			knight().speed = 2.6
			mummy().wake("hour5")
			brenda("Last hour. The mummy's up. The Duchess is up. I'm up. Everyone's up.", 4.5)


func tick(delta: float) -> void:
	if Shift.power_on and Music.base == "blackout":
		Music.set_base("storm")
	_lightning -= delta
	if _lightning <= 0.0:
		_lightning = randf_range(14.0, 35.0)
		_flash(false)


func finish() -> void:
	duchess().set_enabled(false)
	var m := moths("library")
	if m:
		m.set_enabled(false)
	super.finish()


func _hide_pile(it_name: String, hidden: bool) -> void:
	var it := museum.get_node_or_null("Interactables/" + it_name)
	if it == null:
		return
	for p in museum.get_node("Visual").get_children():
		if String(p.name).begins_with("BookPile") and p is Node3D and p.global_position.distance_to(it.global_position) < 0.8:
			p.visible = not hidden


func _flash(big: bool) -> void:
	var t := create_tween()
	t.tween_property(_moon, "light_energy", 7.0 if big else 4.5, 0.05)
	t.tween_property(_moon, "light_energy", 0.4, 0.08)
	t.tween_property(_moon, "light_energy", 5.0 if big else 3.0, 0.05)
	t.tween_property(_moon, "light_energy", 0.25, 0.4)
	var delay := 0.2 if big else randf_range(0.6, 2.5)
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		_thunder.stream = load("res://audio/thunder_%d.ogg" % (randi() % 3 + 1))
		_thunder.volume_db = 2.0 if big else randf_range(-8.0, -2.0)
		_thunder.play()
		if big:
			player.shake(0.6))


## Open window = glass removed (rain gets in), interactable to close it.
func _set_window(n: String, open: bool) -> void:
	var it := museum.get_node_or_null("Interactables/" + n)
	if it == null:
		return
	it.active = open
	for w in get_tree().get_nodes_in_group("windows"):
		if w.global_position.distance_to(it.global_position) < 1.5:
			var glass := w.get_node_or_null("Glass")
			if glass:
				glass.visible = not open
