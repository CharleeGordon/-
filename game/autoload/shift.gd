extends Node
## Global state of the night shift: clock, tasks, write-ups, power, messages.
## Autoloaded as "Shift". Story reactions live in scripts/game.gd.

signal clock_changed(text: String)
signal hour_changed(hour: int)
signal tasks_changed
signal writeup_added(count: int, reason: String)
signal message(text: String, speaker: String, duration: float)
signal alert(text: String)
signal power_changed(on: bool)
signal noise(position: Vector3)
signal interact_requested(action_id: String, node: Node)
signal caught(enemy: Node3D, cause: String)
signal game_ended(won: bool, title: String, reason: String)

const SECONDS_PER_HOUR := 100.0 # 6 in-game hours = 10 real minutes
const END_HOUR := 6
const MAX_WRITEUPS := 3

var running := false
var elapsed := 0.0
var hour := 0
var power_on := true
var tasks: Array[Dictionary] = []
var writeups: Array[String] = []
var _last_clock_text := ""

const RULES := [
	"1. The Security Office is a safe zone. Exhibits are not allowed inside (union rules).",
	"2. Do NOT run in the Egyptian Hall. The Mummy is a light sleeper.",
	"3. Sir Clanksworth (the armor) only moves when nobody is looking. So keep looking.",
	"4. Do not shine your flashlight into Gerald's eyes. Gerald is very shy.",
	"5. Do not touch the exhibits. Yes, this means you.",
	"6. Three write-ups and you're fired. Clock out at 6:00 AM sharp.",
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # so F11 works in menus; the clock checks pause itself
	_setup_input()


func start_shift() -> void:
	running = true
	elapsed = 0.0
	hour = 0
	power_on = true
	tasks.clear()
	writeups.clear()
	_last_clock_text = ""
	tasks_changed.emit()
	_emit_clock()


func stop() -> void:
	running = false


func _process(delta: float) -> void:
	if not running or get_tree().paused:
		return
	elapsed += delta
	_update_hour()


func _update_hour() -> void:
	var new_hour := int(elapsed / SECONDS_PER_HOUR)
	_emit_clock()
	if new_hour != hour:
		hour = new_hour
		hour_changed.emit(hour)


func _emit_clock() -> void:
	var text := get_clock_text()
	if text != _last_clock_text:
		_last_clock_text = text
		clock_changed.emit(text)


func get_clock_text() -> String:
	var h := int(elapsed / SECONDS_PER_HOUR)
	var m := int(fmod(elapsed, SECONDS_PER_HOUR) / SECONDS_PER_HOUR * 60.0)
	var shown_h := 12 if h == 0 else h
	return "%d:%02d AM" % [shown_h, m]


## Debug helper: jump to the next hour (F9, only in debug builds).
func skip_hour() -> void:
	if not running:
		return
	elapsed = (hour + 1) * SECONDS_PER_HOUR + 0.01
	_update_hour()


# --- Tasks ---------------------------------------------------------------

func add_task(id: String, text: String, goal: int = 1) -> void:
	if has_task(id):
		return
	tasks.append({"id": id, "text": text, "goal": goal, "progress": 0, "done": false})
	alert.emit("NEW TASK: " + text)
	tasks_changed.emit()


func has_task(id: String) -> bool:
	return _find_task(id) != {}


func is_task_active(id: String) -> bool:
	var t := _find_task(id)
	return t != {} and not t["done"]


func is_task_done(id: String) -> bool:
	var t := _find_task(id)
	return t != {} and t["done"]


func progress_task(id: String, amount: int = 1) -> void:
	var t := _find_task(id)
	if t == {} or t["done"]:
		return
	t["progress"] = mini(t["progress"] + amount, t["goal"])
	if t["progress"] >= t["goal"]:
		complete_task(id)
	else:
		tasks_changed.emit()


func complete_task(id: String) -> void:
	var t := _find_task(id)
	if t == {} or t["done"]:
		return
	t["done"] = true
	t["progress"] = t["goal"]
	alert.emit("TASK COMPLETE: " + t["text"])
	tasks_changed.emit()


func task_label(t: Dictionary) -> String:
	if t["goal"] > 1:
		return "%s (%d/%d)" % [t["text"], t["progress"], t["goal"]]
	return t["text"]


func count_done() -> int:
	var n := 0
	for t in tasks:
		if t["done"]:
			n += 1
	return n


func _find_task(id: String) -> Dictionary:
	for t in tasks:
		if t["id"] == id:
			return t
	return {}


# --- Write-ups (strikes) -------------------------------------------------

func add_writeup(reason: String) -> void:
	if not running:
		return
	writeups.append(reason)
	writeup_added.emit(writeups.size(), reason)
	if writeups.size() >= MAX_WRITEUPS:
		end_game(false, "YOU'RE FIRED",
			"Three write-ups in one night. Brenda has already put your photo on the wall of shame.\nLast straw: " + reason)


# --- Misc ----------------------------------------------------------------

func say(text: String, speaker: String = "", duration: float = 4.0) -> void:
	message.emit(text, speaker, duration)


func set_power(on: bool) -> void:
	if power_on == on:
		return
	power_on = on
	power_changed.emit(on)


func make_noise(pos: Vector3) -> void:
	noise.emit(pos)


## Called by an enemy that reached the player. game.gd plays the scare, then calls end_game.
func catch_player(enemy: Node3D, cause: String) -> void:
	if not running:
		return
	running = false
	caught.emit(enemy, cause)


func end_game(won: bool, title: String, reason: String) -> void:
	running = false
	game_ended.emit(won, title, reason)


# --- Input map (physical keys, so it works on any keyboard layout) -------

func _setup_input() -> void:
	_bind("move_forward", [KEY_W, KEY_UP])
	_bind("move_back", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("sprint", [KEY_SHIFT])
	_bind("interact", [KEY_E])
	_bind("flashlight", [KEY_F])
	_bind("journal", [KEY_TAB, KEY_J])
	_bind("pause", [KEY_ESCAPE])
	_bind("fullscreen", [KEY_F11])
	_bind("debug_skip_hour", [KEY_F9])


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var mode := DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
