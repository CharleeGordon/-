extends CanvasLayer
## All on-screen UI for the shift: clock, tasks, bars, prompts, radio subtitles,
## journal (Tab), pause menu (Esc) and the end screen. Built in code to keep the scene simple.

const SND_RADIO := preload("res://audio/radio.wav")
const SND_WRITEUP := preload("res://audio/writeup.wav")

var player: Node = null

var _clock: Label
var _tasks: Label
var _battery: ProgressBar
var _battery_box: Control
var _stamina: ProgressBar
var _prompt: Label
var _crosshair: Control
var _subtitle_panel: PanelContainer
var _subtitle: Label
var _alert: Label
var _carry: Label
var _journal: PanelContainer
var _journal_text: RichTextLabel
var _pause: Control
var _end: Control
var _end_title: Label
var _end_text: Label
var _fade: ColorRect
var _flash: ColorRect
var _sfx: AudioStreamPlayer

var _messages: Array[Dictionary] = []
var _msg_time := 0.0
var _alert_time := 0.0
var _ended := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()
	Shift.clock_changed.connect(func(t: String) -> void: _clock.text = t)
	Shift.tasks_changed.connect(_refresh_tasks)
	Shift.message.connect(_queue_message)
	Shift.alert.connect(_show_alert)
	Shift.writeup_added.connect(_on_writeup)
	Shift.game_ended.connect(_on_game_ended)
	_refresh_tasks()


# --- Building ------------------------------------------------------------

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_clock = _label(root, "12:00 AM", 40)
	_place(_clock, Control.PRESET_TOP_RIGHT, Vector2(-260, 18), Vector2(240, 50))
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var night := _label(root, "NIGHT 1", 18, Color(0.8, 0.75, 0.6))
	_place(night, Control.PRESET_TOP_RIGHT, Vector2(-260, 66), Vector2(240, 24))
	night.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_tasks = _label(root, "", 20)
	_tasks.position = Vector2(24, 18)
	_tasks.size = Vector2(620, 300)

	_battery_box = VBoxContainer.new()
	_place(_battery_box, Control.PRESET_BOTTOM_LEFT, Vector2(24, -96), Vector2(260, 80))
	root.add_child(_battery_box)
	_label(_battery_box, "FLASHLIGHT", 14, Color(0.85, 0.85, 0.7))
	_battery = _bar(_battery_box, Color(1.0, 0.85, 0.3))
	_label(_battery_box, "STAMINA", 14, Color(0.7, 0.85, 1.0))
	_stamina = _bar(_battery_box, Color(0.45, 0.75, 1.0))

	_crosshair = ColorRect.new()
	_crosshair.color = Color(1, 1, 1, 0.6)
	_place(_crosshair, Control.PRESET_CENTER, Vector2(-2, -2), Vector2(4, 4))
	root.add_child(_crosshair)

	_prompt = _label(root, "", 22)
	_place(_prompt, Control.PRESET_CENTER, Vector2(-400, 30), Vector2(800, 40))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_carry = _label(root, "", 18, Color(1.0, 0.85, 0.3))
	_place(_carry, Control.PRESET_BOTTOM_RIGHT, Vector2(-420, -50), Vector2(400, 30))
	_carry.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_alert = _label(root, "", 26, Color(1.0, 0.9, 0.5))
	_place(_alert, Control.PRESET_CENTER_TOP, Vector2(-500, 110), Vector2(1000, 80))
	_alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_subtitle_panel = PanelContainer.new()
	_subtitle_panel.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.65), 10))
	_place(_subtitle_panel, Control.PRESET_CENTER_BOTTOM, Vector2(-450, -150), Vector2(900, 60))
	_subtitle_panel.visible = false
	root.add_child(_subtitle_panel)
	_subtitle = _label(_subtitle_panel, "", 22)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.custom_minimum_size = Vector2(880, 0)

	var hint := _label(root, "WASD move   SHIFT run   F flashlight   E use   TAB journal   ESC pause", 16, Color(1, 1, 1, 0.45))
	_place(hint, Control.PRESET_CENTER_BOTTOM, Vector2(-450, -36), Vector2(900, 24))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint_tween := create_tween()
	hint_tween.tween_interval(40.0)
	hint_tween.tween_property(hint, "modulate:a", 0.0, 3.0)

	# Journal
	_journal = PanelContainer.new()
	_journal.add_theme_stylebox_override("panel", _box(Color(0.93, 0.89, 0.78, 0.97), 16))
	_place(_journal, Control.PRESET_CENTER, Vector2(-430, -290), Vector2(860, 580))
	_journal.visible = false
	root.add_child(_journal)
	_journal_text = RichTextLabel.new()
	_journal_text.bbcode_enabled = true
	_journal_text.add_theme_color_override("default_color", Color(0.15, 0.12, 0.1))
	_journal_text.add_theme_font_size_override("normal_font_size", 19)
	_journal_text.add_theme_font_size_override("bold_font_size", 24)
	_journal.add_child(_journal_text)

	# Pause menu
	_pause = _overlay(root, Color(0, 0, 0, 0.75))
	var pbox := _center_box(_pause)
	_label(pbox, "PAUSED", 48).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(pbox, "Coffee break. The exhibits are also on break. Probably.", 18, Color(0.8, 0.8, 0.8)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(pbox, "Resume", _toggle_pause)
	_button(pbox, "Restart night", _restart)
	_button(pbox, "Main menu", _main_menu)
	_button(pbox, "Quit to desktop", func() -> void: get_tree().quit())

	# End screen
	_end = _overlay(root, Color(0, 0, 0, 0.85))
	var ebox := _center_box(_end)
	_end_title = _label(ebox, "", 64)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_text = _label(ebox, "", 20)
	_end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_text.custom_minimum_size = Vector2(760, 0)
	_button(ebox, "Try again", _restart)
	_button(ebox, "Main menu", _main_menu)

	_flash = ColorRect.new()
	_flash.color = Color(0.8, 0.0, 0.0, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)

	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)


## Anchors `c` to a screen corner/edge, then offsets it by `offset` (pixels) with `size`.
func _place(c: Control, preset: Control.LayoutPreset, offset: Vector2, size: Vector2) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + size.x
	c.offset_bottom = offset.y + size.y


func _label(parent: Node, text: String, font_size: int, color: Color = Color(0.95, 0.95, 0.92)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _bar(parent: Node, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(240, 12)
	b.show_percentage = false
	b.add_theme_stylebox_override("background", _box(Color(0, 0, 0, 0.5), 3))
	b.add_theme_stylebox_override("fill", _box(color, 3))
	parent.add_child(b)
	return b


func _box(color: Color, margin: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(6)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.6
	s.content_margin_bottom = margin * 0.6
	return s


func _overlay(parent: Node, color: Color) -> ColorRect:
	var o := ColorRect.new()
	o.color = color
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.visible = false
	parent.add_child(o)
	return o


func _center_box(parent: Node) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	return box


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 48)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(callback)
	var c := CenterContainer.new()
	c.add_child(b)
	parent.add_child(c)
	return b


# --- Runtime -------------------------------------------------------------

func _process(delta: float) -> void:
	if player == null:
		return
	_battery.value = player.battery
	_battery.modulate.a = 1.0 if player.has_flashlight else 0.25
	_stamina.value = player.stamina
	_stamina.modulate = Color(1, 0.4, 0.4) if player.exhausted else Color.WHITE
	if player.focus != null and not player.controls_locked:
		_prompt.text = "[E]  " + player.focus.prompt
	else:
		_prompt.text = ""
	_carry.text = "Carrying: THE GOLDEN DUCK" if player.carrying_duck else ""
	if _journal.visible:
		_refresh_journal()

	if get_tree().paused:
		return
	if _alert_time > 0.0:
		_alert_time -= delta
		if _alert_time <= 0.0:
			_alert.text = ""
	if _msg_time > 0.0:
		_msg_time -= delta
		if _msg_time <= 0.0:
			_next_message()


func _unhandled_input(event: InputEvent) -> void:
	if _ended:
		return
	if event.is_action_pressed("pause"):
		_toggle_pause()
	elif event.is_action_pressed("journal") and not get_tree().paused:
		_journal.visible = not _journal.visible
	elif event.is_action_pressed("debug_skip_hour") and OS.is_debug_build() and not get_tree().paused:
		Shift.skip_hour()


func _toggle_pause() -> void:
	if _ended:
		return
	var paused := not get_tree().paused
	get_tree().paused = paused
	_pause.visible = paused
	_journal.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _main_menu() -> void:
	get_tree().paused = false
	Shift.stop()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _refresh_tasks() -> void:
	if _tasks == null:
		return
	var lines := PackedStringArray(["TASKS"])
	for t in Shift.tasks:
		if not t["done"]:
			lines.append("-  " + Shift.task_label(t))
	_tasks.text = "\n".join(lines) if lines.size() > 1 else ""


func _refresh_journal() -> void:
	var s := "[b]GUARD'S JOURNAL - NIGHT 1[/b]\n[i]Pemberton Museum of Questionable History[/i]\n\n[b]Tasks[/b]\n"
	for t in Shift.tasks:
		s += ("[s][lb]x[rb] %s[/s]\n" if t["done"] else "[lb]  [rb] %s\n") % Shift.task_label(t)
	s += "\n[b]Museum Rules[/b]\n"
	for r in Shift.RULES:
		s += r + "\n"
	s += "\n[b]Write-ups: %d / %d[/b]\n" % [Shift.writeups.size(), Shift.MAX_WRITEUPS]
	for w in Shift.writeups:
		s += "- " + w + "\n"
	_journal_text.text = s


func _queue_message(text: String, speaker: String, duration: float) -> void:
	_messages.append({"text": text, "speaker": speaker, "duration": duration})
	if _msg_time <= 0.0:
		_next_message()


func _next_message() -> void:
	if _messages.is_empty():
		_subtitle_panel.visible = false
		_msg_time = 0.0
		return
	var m: Dictionary = _messages.pop_front()
	var speaker: String = m["speaker"]
	_subtitle.text = (speaker + ":  " if speaker != "" else "") + m["text"]
	_subtitle_panel.visible = true
	_msg_time = m["duration"]
	if speaker.begins_with("BRENDA"):
		_play(SND_RADIO, -8.0)


func _show_alert(text: String) -> void:
	_alert.text = text
	_alert_time = 3.5


func _on_writeup(count: int, reason: String) -> void:
	_alert.text = "WRITE-UP %d/%d: %s" % [count, Shift.MAX_WRITEUPS, reason]
	_alert_time = 5.0
	_play(SND_WRITEUP, -2.0)
	flash(Color(1.0, 0.6, 0.0, 0.25))


func _play(stream: AudioStream, volume_db: float) -> void:
	_sfx.stream = stream
	_sfx.volume_db = volume_db
	_sfx.play()


func open_journal() -> void:
	_journal.visible = true


func flash(color: Color) -> void:
	_flash.color = color
	create_tween().tween_property(_flash, "color:a", 0.0, 0.6)


func fade_in(duration: float) -> void:
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, duration)


func _on_game_ended(won: bool, title: String, reason: String) -> void:
	_ended = true
	_journal.visible = false
	_pause.visible = false
	_subtitle_panel.visible = false
	_end_title.text = title
	_end_title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6) if won else Color(1.0, 0.35, 0.3))
	_end_text.text = reason
	_end.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
