extends NightBase
## NIGHT 3 - Portrait Night. A storm. Open windows. The Duchess watches from every frame.

const WINDOWS := ["WindowGallery", "WindowGallery2", "WindowDino1", "WindowDino2", "WindowDino3", "WindowDino4"]

var _lightning := 12.0
var _thunder: AudioStreamPlayer
var _moon: DirectionalLight3D
var _moon_energy := 0.55


func note_ids() -> Array:
	return [7, 8, 9]


func battery_count() -> int:
	return 5


func ambience() -> String:
	return "amb_rain"


func setup(restoring: bool) -> void:
	Music.set_base("storm")
	open_door("DoorCurio", true)
	open_door("DoorCurio2", true)
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
		for w in WINDOWS:
			_set_window(w, not flag("closed", []).has(w))
		return
	for w in WINDOWS:
		_set_window(w, true)
	brenda("Big storm tonight. The wind blew some windows open. Close them before the paintings get wet.", 5.5)
	brenda("Paintings HATE getting wet. You'll see. Clock in first.", 4.0)


func handle(action: String, n: Node) -> bool:
	match action:
		"clock_in":
			if Shift.is_task_done("clock_in"):
				return true
			player.play_sfx(preload("res://audio/stamp.wav"))
			Shift.complete_task("clock_in")
			Shift.add_task("windows", "Close the open windows (Gallery, Dinosaur Hall)", WINDOWS.size())
			Shift.add_task("patrol", "Patrol: scan the checkpoints (Gallery, Egyptian Hall, Dinosaur Hall, Curiosities)", 4)
			Shift.add_task("survive", "Survive until 6:00 AM")
			brenda("One more thing. During storms the Duchess gets... attentive. If you hear whispering, FREEZE.", 5.5)
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
		"checkpoint_gallery", "checkpoint_egypt", "checkpoint_dino", "checkpoint_curio":
			scan_checkpoint(n)
			return true
	return false


func on_hour(h: int, silent: bool) -> void:
	match h:
		1:
			knight().activate()
			if not silent:
				brenda("The armour's awake. The thunder doesn't bother him. Nothing bothers him.", 4.5)
		2:
			duchess().set_enabled(true, 8.0 if silent else 25.0)
			duchess().interval = Vector2(45, 60)
			if not silent:
				brenda("I'm hearing whispers on the gallery microphone. She's up. Remember: whispers, then FREEZE.", 5.5)
		3:
			_flash(true)
			Music.set_base("blackout")
			Shift.set_power(false)
			Shift.add_task("breaker", "Lightning knocked the power out! Flip the breaker in Storage")
			brenda("That one hit the building. Breaker, Storage, you know the drill.", 4.5)
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
	super.finish()


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
