extends Node
## State of the current night: clock, tasks, write-ups, power, flags, checkpoint.
## Autoloaded as "Shift". Story logic lives in scripts/nights/night_*.gd.

signal clock_changed(text: String)
signal hour_changed(hour: int)
signal tasks_changed
signal writeup_added(count: int, reason: String)
signal message(text: String, speaker: String, duration: float)
signal alert(text: String)
signal power_changed(on: bool)
signal noise(position: Vector3, radius: float)
signal interact_requested(action_id: String, node: Node)
signal caught(enemy: Node3D, cause: String)
signal game_ended(won: bool, title: String, reason: String)

const SECONDS_PER_HOUR := 100.0 # 6 in-game hours = 10 real minutes
const END_HOUR := 6
const CHECKPOINT_HOUR := 3
const LAST_NIGHT := 5

const NIGHT_TITLES := {
	1: ["NIGHT 1", "Orientation"],
	2: ["NIGHT 2", "Clockwork"],
	3: ["NIGHT 3", "Portrait Night"],
	4: ["NIGHT 4", "The Other Guard"],
	5: ["NIGHT 5", "Closing Time"],
}

const RULES := [
	"1. The Security Office is a safe zone. Exhibits are not allowed inside (union rules).",
	"2. Do NOT run in the Egyptian Hall. The Mummy is a light sleeper.",
	"3. Sir Clanksworth (the armour) only moves when nobody is looking. So keep looking.",
	"4. Do not shine your flashlight into Gerald's eyes. Gerald is very shy.",
	"5. Do not touch the exhibits. Yes, this means you.",
	"6. Three write-ups and you're fired. Clock out at 6:00 AM sharp.",
]
const NIGHT_RULES := {
	2: "7. Keep Little Wolfgang wound up. Always. ALWAYS.",
	3: "8. When the paintings are watching, stand perfectly still.",
	4: "9. The Night Guard in the Wax Hall is NOT a colleague. Stay out of his flashlight.",
	5: "10. Whatever happens tonight: do not drop the Duck.",
}

var night := 1
var running := false
var elapsed := 0.0
var hour := 0
var power_on := true
var tasks: Array[Dictionary] = []
var writeups: Array[String] = []
var flags := {}
var checkpoint := {}          # snapshot taken when the clock hits CHECKPOINT_HOUR
var pending_checkpoint := {}  # set before reloading the scene to resume from it
var _last_clock_text := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()


func start_shift(n: int) -> void:
	night = n
	running = true
	elapsed = 0.0
	hour = 0
	power_on = true
	tasks.clear()
	writeups.clear()
	flags.clear()
	checkpoint = {}
	_last_clock_text = ""
	tasks_changed.emit()
	_emit_clock()


func stop() -> void:
	running = false


func difficulty() -> int:
	return int(Save.settings.get("difficulty", 1))


## Enemy speed multiplier from the difficulty setting.
func speed_mult() -> float:
	return 0.8 if difficulty() == 0 else 1.0


func max_writeups() -> int:
	return 5 if difficulty() == 0 else 3


func rules_for_night() -> Array:
	var out := RULES.duplicate()
	for n in range(2, night + 1):
		if NIGHT_RULES.has(n):
			out.append(NIGHT_RULES[n])
	return out


func _process(delta: float) -> void:
	if not running or get_tree().paused:
		return
	elapsed += delta
	_update_hour()


func _update_hour() -> void:
	var new_hour := int(elapsed / SECONDS_PER_HOUR)
	_emit_clock()
	while new_hour > hour:
		hour += 1
		if hour == CHECKPOINT_HOUR and checkpoint.is_empty():
			take_checkpoint()
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


# --- Checkpoint ----------------------------------------------------------

func take_checkpoint() -> void:
	checkpoint = {
		"night": night,
		"hour": CHECKPOINT_HOUR,
		"tasks": tasks.duplicate(true),
		"writeups": writeups.duplicate(),
		"flags": flags.duplicate(true),
	}


func has_checkpoint() -> bool:
	return not checkpoint.is_empty() and int(checkpoint.get("night", 0)) == night


## Restores tasks/flags from a checkpoint and sets the clock a few seconds before it.
func resume_from(cp: Dictionary) -> void:
	night = int(cp["night"])
	running = true
	tasks.clear()
	for t in cp["tasks"]:
		tasks.append(t.duplicate(true))
	writeups.clear()
	for w in cp["writeups"]:
		writeups.append(w)
	flags = cp["flags"].duplicate(true)
	checkpoint = cp.duplicate(true)
	hour = int(cp["hour"]) - 1
	elapsed = cp["hour"] * SECONDS_PER_HOUR - 4.0
	power_on = true
	tasks_changed.emit()
	_emit_clock()


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
	if id != "survive":
		Music.sting("sting_task", -6.0, 0.5)


func remove_task(id: String) -> void:
	var t := _find_task(id)
	if t != {}:
		tasks.erase(t)
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
	Music.sting("sting_writeup", -4.0, 2.0)
	if writeups.size() >= max_writeups():
		end_game(false, "YOU'RE FIRED",
			"Too many write-ups in one night. Brenda has already put your photo on the Wall of Shame.\nLast straw: " + reason)


# --- Misc ----------------------------------------------------------------

func say(text: String, speaker: String = "", duration: float = 4.0) -> void:
	message.emit(text, speaker, duration)


## Voiced version of a spoken line (audio/voice/line_<md5>.ogg, made by tools/gen_voice.py), or null.
func voice_line(text: String) -> AudioStream:
	var path := "res://audio/voice/line_%s.ogg" % text.md5_text().substr(0, 10)
	return load(path) if ResourceLoader.exists(path) else null


func set_power(on: bool) -> void:
	if power_on == on:
		return
	power_on = on
	power_changed.emit(on)


func make_noise(pos: Vector3, radius: float = 30.0) -> void:
	noise.emit(pos, radius)


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
	_bind("crouch", [KEY_CTRL, KEY_C])
	_bind("interact", [KEY_E])
	_bind("flashlight", [KEY_F])
	_bind("journal", [KEY_TAB, KEY_J])
	_bind("pause", [KEY_ESCAPE])
	_bind("fullscreen", [KEY_F11])
	_bind("debug_skip_hour", [KEY_F9])
	_bind("camera_flash", [KEY_R])
	_bind("throw", [KEY_G])
	_mouse("camera_flash", MOUSE_BUTTON_RIGHT)
	_mouse("throw", MOUSE_BUTTON_MIDDLE)
	# Gamepad (Xbox layout)
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	_axis("camera_flash", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_axis("throw", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_joy("interact", JOY_BUTTON_A)
	_joy("flashlight", JOY_BUTTON_X)
	_joy("journal", JOY_BUTTON_Y)
	_joy("crouch", JOY_BUTTON_B)
	_joy("sprint", JOY_BUTTON_LEFT_STICK)
	_joy("sprint", JOY_BUTTON_LEFT_SHOULDER)
	_joy("pause", JOY_BUTTON_START)
	if not InputMap.has_action("interact_mouse"):
		InputMap.add_action("interact_mouse")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("interact_mouse", mb)


func _mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _joy(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _axis(action: String, axis: JoyAxis, dir: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = dir
	InputMap.action_add_event(action, ev)


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		Save.set_setting("fullscreen", not bool(Save.settings["fullscreen"]))
