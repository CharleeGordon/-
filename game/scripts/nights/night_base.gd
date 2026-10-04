class_name NightBase
extends Node
## Base class for a night's script. Override the hooks below in night_N.gd.
## The game (scripts/game.gd) calls: setup(restoring) -> on_hour(h, silent) -> handle(action, node) -> tick(delta) -> finish().

const BOSS := "BRENDA (radio)"

var game: Node
var museum: Node3D
var player: Node
var hud: Node


# --- Hooks -----------------------------------------------------------------

## Called once at the start of the night (restoring = resuming from the 3:00 AM checkpoint).
func setup(_restoring: bool) -> void:
	pass


## Called when the clock reaches a new hour. silent = re-applying state after a checkpoint.
func on_hour(_h: int, _silent: bool) -> void:
	pass


## Return true if this night handled the interaction.
func handle(_action: String, _node: Node) -> bool:
	return false


func tick(_delta: float) -> void:
	pass


## Lore note ids placed tonight.
func note_ids() -> Array:
	return []


## Audio tape ids placed tonight.
func tape_ids() -> Array:
	return []


## Film packs (camera) spawned tonight.
func film_count() -> int:
	return 0


## Scripted scares: Array of {room, hour, type, pos?, text?, voice?}
func scares() -> Array:
	return []


func pemberton() -> Node:
	return museum.get_node("Pemberton")


func dolls() -> Array:
	return museum.get_node("Dolls").get_children()


func moths(room: String) -> Node:
	return museum.get_node_or_null("Moths" + room.capitalize())


## Opens a list of locked doors (instantly, at night start).
func open_doors(names: Array) -> void:
	for d in names:
		open_door(d, true)


func open_stairs() -> void:
	var b := museum.get_node_or_null("StairBlock")
	if b:
		b.open()


## Idle radio chatter from Brenda (one every ~1.5 minutes when nothing else is said).
func banter() -> Array:
	return []


## How many batteries spawn tonight.
func battery_count() -> int:
	return 4


func ambience() -> String:
	return "amb_museum"


## 6:00 AM. Default: night complete.
func finish() -> void:
	game.night_complete(_report())


# --- Helpers ---------------------------------------------------------------

func brenda(text: String, duration: float = 4.5) -> void:
	Shift.say(text, BOSS, duration)


func node(path: String) -> Node:
	return museum.get_node_or_null(path)


func knight() -> Node:
	return museum.get_node("Knight")


func mummy() -> Node:
	return museum.get_node("Mummy")


func dino() -> Node:
	return museum.get_node("Dino")


func automaton() -> Node:
	return museum.get_node("Automaton")


func duchess() -> Node:
	return museum.get_node("Duchess")


func gary() -> Node:
	return museum.get_node("Gary")


func open_door(door_name: String, instant: bool = false) -> void:
	var d := museum.get_node_or_null(door_name)
	if d:
		d.open(instant)


func set_active(path: String, on: bool) -> void:
	var n := museum.get_node_or_null("Interactables/" + path)
	if n == null:
		n = museum.get_node_or_null(path)
	if n:
		n.active = on


func flag(key: String, default = null):
	return Shift.flags.get(key, default)


func set_flag(key: String, value) -> void:
	Shift.flags[key] = value


## Standard start: clock in first. Nights 2+ start with the flashlight in hand.
func start_basics(with_flashlight: bool, restoring: bool) -> void:
	if with_flashlight or restoring:
		player.give_flashlight()
		var fl := museum.get_node_or_null("Interactables/Flashlight")
		if fl:
			fl.queue_free()
	if not restoring:
		Shift.add_task("clock_in", "Clock in at the punch clock (Security Office)")


## Shared patrol logic: checkpoint ids done are stored in flags.
func scan_checkpoint(node_ref: Node, task_id: String = "patrol") -> void:
	if not Shift.is_task_active(task_id):
		Shift.alert.emit("Patrol checkpoint. (Not on your list right now.)")
		return
	var done: Array = flag("checkpoints", [])
	if done.has(String(node_ref.name)):
		return
	done.append(String(node_ref.name))
	set_flag("checkpoints", done)
	node_ref.active = false
	game.light_checkpoint(String(node_ref.name))
	player.play_sfx(preload("res://audio/stamp.wav"), -6.0)
	Shift.progress_task(task_id)


func restore_checkpoints() -> void:
	for n in flag("checkpoints", []):
		var it := museum.get_node_or_null("Interactables/" + n)
		if it:
			it.active = false
		game.light_checkpoint(n)


func _report() -> String:
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
	return "6:00 AM. The exhibits are back in place. Mostly.\n\nTasks completed: %d / %d\nWrite-ups: %d / %d\n\nPerformance review: %s" % [done, total, strikes, Shift.max_writeups(), grade]
