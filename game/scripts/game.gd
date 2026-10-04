extends Node3D
## The night's script: what happens each hour and what every interactable does.
## Tweak timing/text here. Global state lives in autoload/shift.gd.

const SND_CHIME := preload("res://audio/chime.wav")
const SND_STING := preload("res://audio/sting.wav")
const SND_PICKUP := preload("res://audio/pickup.wav")
const SND_POWER_DOWN := preload("res://audio/power_down.wav")
const SND_QUACK := preload("res://audio/quack.wav")
const SND_STAMP := preload("res://audio/stamp.wav")

const BOSS := "BRENDA (radio)"
const OFFICE_WARN_TIME := 40.0
const OFFICE_WRITEUP_TIME := 70.0

@onready var museum: Node3D = $Museum
@onready var player = $Player # scripts/player.gd
@onready var hud = $HUD # scripts/hud.gd
@onready var sfx: AudioStreamPlayer = $Sfx
@onready var ambience: AudioStreamPlayer = $Ambience

var knight: Node
var mummy: Node
var duck: Interactable
var duck_pedestal: Interactable
var _office_time := 0.0
var _office_warned := false
var _coffee_cooldown := 0.0

const TOUCH_LINES := {
	"touch_vase": ["You touched the Priceless Vase.", "It is now slightly less priceless."],
	"touch_egg": ["You touched the Fossilized Egg.", "Something inside tapped back."],
	"touch_jar": ["You touched the Cursed Canopic Jar.", "The curse is mostly paperwork."],
}


func _ready() -> void:
	knight = museum.get_node("Knight")
	mummy = museum.get_node("Mummy")
	duck = museum.get_node("Duck")
	duck_pedestal = museum.get_node("DuckPedestal")
	hud.player = player
	player.global_transform = museum.get_node("PlayerSpawn").global_transform

	Shift.hour_changed.connect(_on_hour)
	Shift.interact_requested.connect(_on_interact)
	Shift.power_changed.connect(_on_power)
	Shift.caught.connect(_on_caught)
	Shift.start_shift()

	ambience.finished.connect(ambience.play)
	ambience.play()
	hud.fade_in(2.5)

	Shift.add_task("clock_in", "Clock in at the punch clock")
	Shift.say("Evening, new guy. Welcome to the Pemberton Museum of Questionable History.", BOSS, 5.0)
	Shift.say("First things first: clock in. The punch clock is on the wall of your office.", BOSS, 5.0)


func _process(delta: float) -> void:
	_coffee_cooldown = maxf(_coffee_cooldown - delta, 0.0)
	_check_office_camping(delta)


## Anti-camping: the office is safe, but Brenda watches the cameras.
func _check_office_camping(delta: float) -> void:
	if not Shift.running or not Shift.has_task("patrol"):
		return
	if player.is_safe():
		_office_time += delta
	else:
		_office_time = maxf(_office_time - delta * 0.5, 0.0)
		if _office_time < OFFICE_WARN_TIME * 0.5:
			_office_warned = false
	if _office_time > OFFICE_WARN_TIME and not _office_warned:
		_office_warned = true
		Shift.say("I can see you on camera. The exhibits won't patrol themselves. Well. They might.", BOSS, 5.0)
	if _office_time > OFFICE_WRITEUP_TIME:
		_office_time = 0.0
		_office_warned = false
		Shift.add_writeup("Hiding in the office instead of working")


# --- Timeline ------------------------------------------------------------

func _on_hour(hour: int) -> void:
	_play(SND_CHIME, -4.0)
	match hour:
		1:
			knight.activate()
			Shift.say("Quick heads-up. If the armor in the lobby moves... just keep looking at it.", BOSS, 5.0)
			Shift.say("Sir Clanksworth is shy too. Different kind of shy.", BOSS, 4.0)
		2:
			Shift.say("Two o'clock. Remember: no running in the Egyptian Hall. I'm serious. HR is serious.", BOSS, 5.0)
		3:
			Shift.set_power(false)
			Shift.add_task("breaker", "Power is out! Flip the breaker in Storage")
			Shift.say("Huh. Power's out. Breaker's in Storage, west of the lobby. Bring your flashlight.", BOSS, 5.0)
		4:
			_steal_duck()
			knight.speed = 2.6
		5:
			Shift.say("Last hour. Funny thing: the mummy just... sat up on camera. Not funny, actually.", BOSS, 5.0)
			mummy.wake("hour5")
		6:
			_finish_shift()


func _steal_duck() -> void:
	var spots := museum.get_node("DuckSpots").get_children()
	var spot: Node3D = spots[randi() % spots.size()]
	duck.global_position = spot.global_position
	duck.visible = true
	duck.active = true
	Shift.add_task("duck", "Someone stole the Golden Duck! Find it and put it back")
	Shift.say("The Golden Duck is gone. It's our most valuable exhibit. Find it. Don't ask how I know it's gone.", BOSS, 6.0)


func _finish_shift() -> void:
	_play(SND_CHIME, 0.0)
	Shift.complete_task("survive")
	var total := Shift.tasks.size()
	var done := Shift.count_done()
	var strikes := Shift.writeups.size()
	var grade := ""
	if done == total and strikes == 0:
		grade = "Employee of the Month (unpaid)."
	elif done == total:
		grade = "Adequate. See you tomorrow night."
	elif done >= total - 2:
		grade = "You survived. That's... technically the job."
	else:
		grade = "You mostly hid. Brenda noticed. Brenda always notices."
	var report := "6:00 AM. The exhibits are back in place. Mostly.\n\n"
	report += "Tasks completed: %d / %d\nWrite-ups: %d / %d\n\nPerformance review: %s\n\n" % [done, total, strikes, Shift.MAX_WRITEUPS, grade]
	report += "Thanks for playing the demo! Night 2 is coming soon."
	Shift.end_game(true, "SHIFT COMPLETE", report)


# --- Interactions --------------------------------------------------------

func _on_interact(action_id: String, node: Node) -> void:
	if action_id.begins_with("touch_"):
		_touch_exhibit(action_id, node)
		return
	if action_id.begins_with("checkpoint_"):
		_checkpoint(node)
		return
	match action_id:
		"clock_in":
			if Shift.is_task_done("clock_in"):
				Shift.alert.emit("You already clocked in. The clock looks proud of you.")
				return
			_play(SND_STAMP, 0.0)
			Shift.complete_task("clock_in")
			Shift.add_task("rules", "Read the Museum Rules poster")
			Shift.add_task("flashlight", "Take the flashlight from the desk")
			Shift.say("Good. Now read the rules poster. All of it. Especially the weird ones.", BOSS, 4.5)
		"rules":
			Shift.complete_task("rules")
			hud.open_journal()
			Shift.alert.emit("Rules added to your journal (TAB to open/close).")
			_after_basics()
		"flashlight":
			player.has_flashlight = true
			node.queue_free()
			_play(SND_PICKUP, -4.0)
			Shift.complete_task("flashlight")
			Shift.alert.emit("Got the flashlight. Press F to toggle it.")
			_after_basics()
		"coffee":
			if _coffee_cooldown > 0.0:
				Shift.alert.emit("The coffee machine is recharging. So are you.")
				return
			_coffee_cooldown = 45.0
			player.refill_stamina()
			Shift.alert.emit("Coffee. Tastes like 1987. Stamina restored.")
		"battery":
			player.add_battery(45.0)
			node.queue_free()
			_play(SND_PICKUP, -4.0)
			Shift.alert.emit("Batteries! +45% flashlight.")
		"breaker":
			if Shift.power_on:
				Shift.alert.emit("The breaker is fine. Don't poke it.")
				return
			Shift.set_power(true)
			Shift.complete_task("breaker")
			Shift.say("Lights are back. You're doing great. Statistically.", BOSS, 4.0)
		"duck":
			player.carrying_duck = true
			duck.visible = false
			duck.active = false
			duck_pedestal.active = true
			_play(SND_QUACK, 0.0)
			Shift.alert.emit("You found the Golden Duck. It quacked at you. Return it to its pedestal in the lobby.")
		"duck_pedestal":
			if not player.carrying_duck:
				return
			player.carrying_duck = false
			duck.global_position = duck_pedestal.global_position + Vector3(0, 1.0, 0)
			duck.visible = true
			duck_pedestal.active = false
			_play(SND_QUACK, -2.0)
			Shift.complete_task("duck")
			Shift.say("The Duck is back. The museum is whole again. I may cry.", BOSS, 4.0)


func _after_basics() -> void:
	if Shift.is_task_done("rules") and Shift.is_task_done("flashlight") and not Shift.has_task("patrol"):
		Shift.add_task("patrol", "Patrol: scan the checkpoints in Gallery, Egyptian Hall and Dinosaur Hall", 3)
		Shift.add_task("survive", "Survive until 6:00 AM")
		Shift.say("Now patrol. Scan the green-light panels in the Gallery, the Egyptian Hall and the Dinosaur Hall.", BOSS, 5.5)


func _checkpoint(node: Node) -> void:
	if not Shift.has_task("patrol"):
		Shift.alert.emit("Patrol checkpoint. Finish the basics in your office first.")
		return
	node.active = false
	var lamp: MeshInstance3D = node.get_node("Lamp")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 1.0, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 1.0, 0.3)
	mat.emission_energy_multiplier = 3.0
	lamp.material_override = mat
	_play(SND_STAMP, -4.0)
	Shift.progress_task("patrol")
	if Shift.is_task_done("patrol"):
		Shift.say("Patrol done. Now just... survive till six. Easy. Probably.", BOSS, 4.0)


func _touch_exhibit(action_id: String, node: Node) -> void:
	node.active = false
	var lines: Array = TOUCH_LINES.get(action_id, ["You touched an exhibit.", "Why."])
	Shift.say(lines[0] + " " + lines[1], "", 4.0)
	Shift.add_writeup("Touched an exhibit (Rule 5)")


# --- Power & scares ------------------------------------------------------

func _on_power(on: bool) -> void:
	for l in get_tree().get_nodes_in_group("room_lights"):
		l.visible = on
	for l in get_tree().get_nodes_in_group("emergency_lights"):
		l.visible = not on
	if not on:
		_play(SND_POWER_DOWN, 0.0)
		player.shake(0.4)
		ambience.stop()
	else:
		ambience.play()


func _on_caught(enemy: Node3D, cause: String) -> void:
	player.lock_and_look_at(enemy.global_position + Vector3(0, 1.6, 0))
	_play(SND_STING, 2.0)
	hud.flash(Color(0.7, 0.0, 0.0, 0.6))
	var title := "KNIGHTED"
	var reason := "Sir Clanksworth got you while you weren't looking.\nRule 3 exists for a reason."
	if cause == "mummy":
		title = "WRAPPED UP"
		reason = "The Mummy caught you. You will now be on display until roughly 2400 AD.\nRule 2: walk, don't run."
	get_tree().create_timer(1.4).timeout.connect(func() -> void: Shift.end_game(false, title, reason))


func _play(stream: AudioStream, volume_db: float) -> void:
	sfx.stream = stream
	sfx.volume_db = volume_db
	sfx.play()
