extends Node3D
## Runs one night: loads the night script, routes interactions, spawns pickups,
## handles deaths, checkpoints, ambience and scene transitions.

const NIGHT_SCRIPTS := {
	1: preload("res://scripts/nights/night_1.gd"),
	2: preload("res://scripts/nights/night_2.gd"),
	3: preload("res://scripts/nights/night_3.gd"),
	4: preload("res://scripts/nights/night_4.gd"),
	5: preload("res://scripts/nights/night_5.gd"),
}
const OFFICE_WARN_TIME := 45.0
const OFFICE_WRITEUP_TIME := 80.0
const DEATHS := {
	"knight": ["KNIGHTED", "Sir Clanksworth got you while you weren't looking.\nRule 3 exists for a reason."],
	"mummy": ["WRAPPED UP", "The Mummy caught you. You will now be on display until roughly 2400 AD.\nRule 2: walk, don't run."],
	"automaton": ["WOUND UP", "Little Wolfgang found you. He'd like you to wind HIM up next time.\nRule 7: keep him wound."],
	"duchess": ["FRAMED", "You moved while the Duchess was watching. Your portrait will hang next to hers.\nRule 8: stand perfectly still."],
	"guard": ["ESCORTED OUT", "Gary escorted you to the Wax Hall. Permanently.\nRule 9: stay out of his flashlight."],
}

@onready var museum: Node3D = $Museum
@onready var player = $Player # scripts/player.gd
@onready var hud = $HUD # scripts/hud.gd
@onready var post = $PostFX
@onready var sfx: AudioStreamPlayer = $Sfx
@onready var ambience_player: AudioStreamPlayer = $Ambience

var night: NightBase
var _office_time := 0.0
var _office_warned := false
var _coffee_cd := 0.0
var _amb_timer := 12.0
var _amb_one_shot: AudioStreamPlayer3D
var _restoring := false


func _ready() -> void:
	get_tree().paused = false
	Music.reset_reports()
	var n: int = clampi(Shift.night, 1, Shift.LAST_NIGHT)
	hud.player = player
	hud.retry_requested.connect(_retry)
	hud.menu_requested.connect(_to_menu)
	player.global_transform = museum.get_node("PlayerSpawn").global_transform
	Shift.hour_changed.connect(_on_hour)
	Shift.interact_requested.connect(_on_interact)
	Shift.power_changed.connect(_on_power)
	Shift.caught.connect(_on_caught)
	Shift.game_ended.connect(_on_game_ended)

	if not Shift.pending_checkpoint.is_empty() and int(Shift.pending_checkpoint["night"]) == n:
		_restoring = true
		Shift.resume_from(Shift.pending_checkpoint)
	else:
		Shift.start_shift(n)
	Shift.pending_checkpoint = {}

	var env: WorldEnvironment = museum.get_node("WorldEnvironment")
	Save.apply_quality(env.environment, get_viewport())

	night = NIGHT_SCRIPTS[n].new()
	night.name = "Night"
	night.game = self
	night.museum = museum
	night.player = player
	night.hud = hud
	add_child(night)

	_spawn_batteries(night.battery_count())
	_spawn_notes(night.note_ids())
	night.setup(_restoring)
	if _restoring:
		for h in range(1, Shift.CHECKPOINT_HOUR):
			night.on_hour(h, true)
		player.battery = 70.0
		Shift.say("Resuming from 3:00 AM. Deep breaths.", "", 3.0)

	var title: Array = Shift.NIGHT_TITLES[n]
	hud.set_night_label("%s  -  %s" % [title[0], title[1].to_upper()])
	hud.fade_in(2.5)
	if not _restoring:
		hud.title_card(title[0], title[1])
		Music.sting("sting_night", -2.0, 3.0)
	_start_ambience(night.ambience())
	_amb_one_shot = AudioStreamPlayer3D.new()
	_amb_one_shot.bus = "SFX"
	_amb_one_shot.unit_size = 10.0
	add_child(_amb_one_shot)


func _process(delta: float) -> void:
	_coffee_cd = maxf(_coffee_cd - delta, 0.0)
	if not Shift.running:
		return
	_check_office_camping(delta)
	_random_ambience(delta)
	night.tick(delta)


## The office is safe, but Brenda watches the cameras.
func _check_office_camping(delta: float) -> void:
	if not Shift.is_task_done("clock_in"):
		return
	if player.is_safe() and not hud.is_busy():
		_office_time += delta
	else:
		_office_time = maxf(_office_time - delta * 0.5, 0.0)
		if _office_time < OFFICE_WARN_TIME * 0.5:
			_office_warned = false
	if _office_time > OFFICE_WARN_TIME and not _office_warned:
		_office_warned = true
		night.brenda("I can see you on camera. The exhibits won't patrol themselves. Well. They might.", 5.0)
	if _office_time > OFFICE_WRITEUP_TIME:
		_office_time = 0.0
		_office_warned = false
		Shift.add_writeup("Hiding in the office instead of working")


func _random_ambience(delta: float) -> void:
	_amb_timer -= delta
	if _amb_timer > 0.0:
		return
	_amb_timer = randf_range(9.0, 22.0)
	var pool := ["creak_1", "creak_2", "creak_3", "creak_4", "distant_steps_1", "distant_steps_2"]
	var pick: String = pool[randi() % pool.size()]
	_amb_one_shot.stream = load("res://audio/%s.wav" % pick)
	var dir := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	_amb_one_shot.global_position = player.global_position + dir * randf_range(6.0, 14.0) + Vector3(0, 2.0, 0)
	_amb_one_shot.volume_db = randf_range(-10.0, -2.0)
	_amb_one_shot.pitch_scale = randf_range(0.85, 1.1)
	_amb_one_shot.play()


func _start_ambience(name: String) -> void:
	var s: AudioStream = load("res://audio/%s.ogg" % name)
	if s is AudioStreamOggVorbis:
		s = s.duplicate()
		s.loop = true
	ambience_player.stream = s
	ambience_player.play()


func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	sfx.stream = stream
	sfx.volume_db = volume_db
	sfx.play()


# --- Pickups -----------------------------------------------------------------

func _spawn_batteries(count: int) -> void:
	var spots: Array = museum.get_node("BatterySpots").get_children()
	spots.shuffle()
	for i in mini(count, spots.size()):
		var a := _pickup("Battery%d" % i, "battery", "Take batteries", spots[i].global_position)
		for k in 2:
			var cell := MeshInstance3D.new()
			var m := CylinderMesh.new()
			m.top_radius = 0.016
			m.bottom_radius = 0.016
			m.height = 0.06
			m.material = preload("res://materials/e_amber.tres")
			cell.mesh = m
			cell.position = Vector3(k * 0.04 - 0.02, 0.03, 0)
			a.add_child(cell)


func _spawn_notes(ids: Array) -> void:
	for id in ids:
		var spot := museum.get_node_or_null("NoteSpots/Note%d" % id)
		if spot == null:
			continue
		var a := _pickup("Note%d" % id, "note_%d" % id, "Read: " + Notes.title(id), spot.global_position)
		var paper := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.21, 0.003, 0.29)
		pm.material = preload("res://materials/porcelain.tres")
		paper.mesh = pm
		paper.position = Vector3(0, 0.003, 0)
		paper.rotation.y = randf_range(-0.6, 0.6)
		a.add_child(paper)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.9, 0.7)
		glow.light_energy = 0.25
		glow.omni_range = 0.8
		glow.position = Vector3(0, 0.2, 0)
		a.add_child(glow)


func _pickup(n: String, action: String, prompt: String, pos: Vector3) -> Interactable:
	var a := Interactable.new()
	a.name = n
	a.action_id = action
	a.prompt = prompt
	a.collision_layer = 8
	a.collision_mask = 0
	a.monitoring = false
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.5, 0.35, 0.5)
	cs.shape = sh
	cs.position = Vector3(0, 0.15, 0)
	a.add_child(cs)
	museum.add_child(a)
	a.global_position = pos
	return a


func light_checkpoint(n: String) -> void:
	# The lamp is the nearest checkpoint panel to the interactable.
	var it := museum.get_node_or_null("Interactables/" + n)
	if it == null:
		return
	var best: Node3D = null
	var bd := INF
	for lamp in get_tree().get_nodes_in_group("checkpoint_lamps"):
		var d: float = lamp.global_position.distance_to(it.global_position)
		if d < bd:
			bd = d
			best = lamp
	if best:
		best.material_override = preload("res://materials/e_green.tres")


# --- Interactions ------------------------------------------------------------

func _on_interact(action: String, node: Node) -> void:
	if hud.is_busy():
		return
	if night.handle(action, node):
		return
	if action.begins_with("note_"):
		var id := int(action.trim_prefix("note_"))
		Save.add_note(id)
		hud.show_note(id)
		return
	if action.begins_with("touch_"):
		node.active = false
		var lines := {
			"touch_vase": "You touched the Priceless Vase. It is now slightly less priceless.",
			"touch_egg": "You touched the Fossilized Egg. Something inside tapped back.",
			"touch_jar": "You touched the Cursed Canopic Jar. The curse is mostly paperwork.",
			"touch_jar2": "You tapped the jar. The thing inside tapped back. Twice.",
		}
		Shift.say(lines.get(action, "You touched an exhibit. Why."), "", 4.0)
		Shift.add_writeup("Touched an exhibit (Rule 5)")
		return
	match action:
		"hide":
			var view := museum.get_node_or_null(String(node.name) + "View")
			if view:
				player.enter_hide(node, view)
		"battery":
			player.add_battery(45.0)
			node.queue_free()
			Shift.alert.emit("Batteries! +45% flashlight.")
		"coffee":
			if _coffee_cd > 0.0:
				Shift.alert.emit("The coffee machine is recharging. So are you.")
				return
			_coffee_cd = 45.0
			player.refill_stamina()
			player.play_sfx(preload("res://audio/coffee.wav"), -6.0)
			Shift.alert.emit("Coffee. Tastes like 1987. Stamina restored.")
		"rules":
			hud.open_journal()
			Shift.complete_task("rules")
		"locked_door":
			player.play_sfx(preload("res://audio/door_locked.wav"), -4.0)
			Shift.alert.emit("Locked. 'Closed for renovation.'")
		"cctv":
			var cams := museum.get_node_or_null("Cameras")
			if cams:
				hud.open_cctv(cams.get_children())
		"breaker":
			if Shift.power_on:
				Shift.alert.emit("The breaker is fine. Don't poke it.")
			else:
				restore_power()
		_:
			pass


func restore_power() -> void:
	Shift.set_power(true)
	Shift.complete_task("breaker")
	player.play_sfx(preload("res://audio/power_up.wav"), -2.0)


# --- Time / power ------------------------------------------------------------

func _on_hour(h: int) -> void:
	if h < Shift.END_HOUR:
		Music.sting("sting_hour", -8.0, 1.0)
	night.on_hour(h, false)
	if h >= Shift.END_HOUR and Shift.running:
		night.finish()


func _on_power(on: bool) -> void:
	apply_lights()
	if not on:
		play_sfx(preload("res://audio/power_down.wav"), 0.0)
		player.shake(0.4)


## Room lights follow the power state and "dark_rooms" flag; emergency lights the opposite.
func apply_lights() -> void:
	var dark: Array = Shift.flags.get("dark_rooms", [])
	for l in get_tree().get_nodes_in_group("room_lights"):
		var lit := Shift.power_on
		for room in dark:
			if l.is_in_group("lights_" + room):
				lit = false
		l.visible = lit
	for l in get_tree().get_nodes_in_group("emergency_lights"):
		l.visible = not Shift.power_on


# --- Death / end -------------------------------------------------------------

func _on_caught(enemy: Node3D, cause: String) -> void:
	player.lock_and_look_at(enemy.global_position + Vector3(0, 1.55, 0))
	Music.play_now("silence")
	Music.sting("sting_scare", 2.0, 0.0)
	post.flash(Color(0.6, 0.0, 0.0), 0.5)
	var info: Array = DEATHS.get(cause, ["CAUGHT", "Something got you."])
	get_tree().create_timer(1.5).timeout.connect(func() -> void: _death_screen(info[0], info[1]))


func _on_game_ended(won: bool, title: String, reason: String) -> void:
	if not won:
		_death_screen(title, reason)


func _death_screen(title: String, reason: String) -> void:
	Music.sting("sting_death", -2.0, 0.0)
	var buttons := []
	if Shift.has_checkpoint():
		buttons.append(["Retry from 3:00 AM", func() -> void: _retry(true)])
	buttons.append(["Restart night", func() -> void: _retry(false)])
	buttons.append(["Main menu", _to_menu])
	hud.show_end(false, title, reason, buttons)


func night_complete(report: String) -> void:
	Shift.stop()
	var n := Shift.night
	Save.unlock_night(n + 1)
	Music.play_now("dawn")
	var buttons := []
	if n < Shift.LAST_NIGHT:
		buttons.append(["Continue to Night %d" % (n + 1), func() -> void: _goto_night(n + 1)])
	buttons.append(["Main menu", _to_menu])
	hud.show_end(true, "NIGHT %d COMPLETE" % n, report, buttons)


func _retry(from_checkpoint: bool) -> void:
	if from_checkpoint and Shift.has_checkpoint():
		Shift.pending_checkpoint = Shift.checkpoint.duplicate(true)
	_goto_night(Shift.night)


func _goto_night(n: int) -> void:
	get_tree().paused = false
	Music.set_muffled("Music", false)
	Music.set_muffled("SFX", false)
	Shift.night = n
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused = false
	Music.set_muffled("Music", false)
	Music.set_muffled("SFX", false)
	Shift.stop()
	Music.reset_reports()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


## Final sequence: text cards over black, music, then credits.
func play_ending(cards: Array, track: String, ending_id: String) -> void:
	Shift.stop()
	Save.add_ending(ending_id)
	player.controls_locked = true
	Music.play_now(track)
	hud.fade_out(2.5)
	var t := 3.0
	for c in cards:
		var card: Array = c
		get_tree().create_timer(t).timeout.connect(func() -> void: hud.title_card(card[0], card[1]))
		t += 5.5
	get_tree().create_timer(t + 0.5).timeout.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/credits.tscn"))
