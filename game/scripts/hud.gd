extends CanvasLayer
## All on-screen UI for a night: clock, tasks, bars, prompts, radio subtitles, journal (Tab),
## note reader, CCTV, pause menu (Esc), night title card and the end / death screens.

signal retry_requested(from_checkpoint: bool)
signal next_night_requested
signal menu_requested

const BABBLE := [preload("res://audio/babble_1.wav"), preload("res://audio/babble_2.wav"), preload("res://audio/babble_3.wav"), preload("res://audio/babble_4.wav")]

var player: Node = null

var _root: Control
var _clock: Label
var _night_label: Label
var _tasks: Label
var _battery: ProgressBar
var _battery_box: Control
var _stamina: ProgressBar
var _prompt: Label
var _crosshair: ColorRect
var _subtitle_panel: PanelContainer
var _subtitle: Label
var _alert: Label
var _carry: Label
var _meter_box: VBoxContainer
var _meter_label: Label
var _meter: ProgressBar
var _journal: PanelContainer
var _journal_text: RichTextLabel
var _note: PanelContainer
var _note_title: Label
var _note_text: Label
var _pause: ColorRect
var _settings: PanelContainer
var _end: ColorRect
var _end_title: Label
var _end_text: Label
var _end_buttons: VBoxContainer
var _title_card: Control
var _title_big: Label
var _title_small: Label
var _fade: ColorRect
var _cctv: Control
var _cctv_vp: SubViewport
var _cctv_cam: Camera3D
var _cctv_label: Label
var _cctv_points: Array = []
var _cctv_idx := 0
var _sfx: AudioStreamPlayer
var _voice: AudioStreamPlayer
var _inventory: Label
var _tape_panel: PanelContainer
var _tape_title: Label
var _tape_line: Label
var _tape_player: AudioStreamPlayer
var _tape_timings: Array = []

var _messages: Array[Dictionary] = []
var _msg_time := 0.0
var _alert_time := 0.0
var _ended := false
var _reading := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()
	Shift.clock_changed.connect(func(t: String) -> void: _clock.text = t)
	Shift.tasks_changed.connect(_refresh_tasks)
	Shift.message.connect(_queue_message)
	Shift.alert.connect(_show_alert)
	Shift.writeup_added.connect(_on_writeup)
	_refresh_tasks()


# --- Building ------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_clock = UIKit.flabel(_root, "12:00 AM", 40, "head", UIKit.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	UIKit.place(_clock, Control.PRESET_TOP_RIGHT, Vector2(-300, 16), Vector2(280, 50))
	_night_label = UIKit.flabel(_root, "NIGHT 1", 17, "head_light", UIKit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	UIKit.place(_night_label, Control.PRESET_TOP_RIGHT, Vector2(-300, 64), Vector2(280, 24))

	_tasks = UIKit.flabel(_root, "", 21, "body")
	UIKit.place(_tasks, Control.PRESET_TOP_LEFT, Vector2(24, 18), Vector2(640, 320))

	_battery_box = VBoxContainer.new()
	UIKit.place(_battery_box, Control.PRESET_BOTTOM_LEFT, Vector2(24, -100), Vector2(260, 84))
	_battery_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_battery_box)
	UIKit.label(_battery_box, "FLASHLIGHT", 13, Color(0.85, 0.82, 0.65))
	_battery = _bar(_battery_box, Color(1.0, 0.82, 0.35))
	UIKit.label(_battery_box, "STAMINA", 13, Color(0.7, 0.82, 0.95))
	_stamina = _bar(_battery_box, Color(0.5, 0.72, 0.95))

	_meter_box = VBoxContainer.new()
	UIKit.place(_meter_box, Control.PRESET_CENTER_RIGHT, Vector2(-300, -40), Vector2(276, 60))
	_meter_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter_box.visible = false
	_root.add_child(_meter_box)
	_meter_label = UIKit.label(_meter_box, "", 15, UIKit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	_meter = _bar(_meter_box, Color(0.85, 0.6, 0.3))

	_crosshair = ColorRect.new()
	_crosshair.color = Color(1, 1, 1, 0.5)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE # sits under the captured cursor
	UIKit.place(_crosshair, Control.PRESET_CENTER, Vector2(-2, -2), Vector2(4, 4))
	_root.add_child(_crosshair)

	_prompt = UIKit.label(_root, "", 21, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	UIKit.place(_prompt, Control.PRESET_CENTER, Vector2(-400, 28), Vector2(800, 40))

	_carry = UIKit.label(_root, "", 17, UIKit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	UIKit.place(_carry, Control.PRESET_BOTTOM_RIGHT, Vector2(-520, -54), Vector2(500, 30))

	_alert = UIKit.label(_root, "", 24, Color(1.0, 0.88, 0.55), HORIZONTAL_ALIGNMENT_CENTER)
	UIKit.place(_alert, Control.PRESET_CENTER_TOP, Vector2(-520, 104), Vector2(1040, 90))
	_alert.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_subtitle_panel = PanelContainer.new()
	_subtitle_panel.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.62), 14))
	UIKit.place(_subtitle_panel, Control.PRESET_CENTER_BOTTOM, Vector2(-470, -160), Vector2(940, 60))
	_subtitle_panel.visible = false
	_subtitle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_subtitle_panel)
	_subtitle = UIKit.label(_subtitle_panel, "", 21, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.custom_minimum_size = Vector2(910, 0)

	var hint := UIKit.label(_root, "WASD move   SHIFT run   CTRL crouch   F flashlight   E use   TAB journal   ESC pause", 15, Color(1, 1, 1, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
	UIKit.place(hint, Control.PRESET_CENTER_BOTTOM, Vector2(-500, -34), Vector2(1000, 24))
	var ht := create_tween()
	ht.tween_interval(45.0)
	ht.tween_property(hint, "modulate:a", 0.0, 3.0)

	_inventory = UIKit.flabel(_root, "", 17, "head_light", Color(0.85, 0.82, 0.7))
	UIKit.place(_inventory, Control.PRESET_BOTTOM_LEFT, Vector2(300, -48), Vector2(400, 26))

	# Tape player
	_tape_panel = PanelContainer.new()
	_tape_panel.add_theme_stylebox_override("panel", UIKit.box(Color(0.02, 0.02, 0.02, 0.78), 16, 4, Color(0.5, 0.42, 0.25, 0.8)))
	UIKit.place(_tape_panel, Control.PRESET_BOTTOM_RIGHT, Vector2(-560, -230), Vector2(536, 120))
	_tape_panel.visible = false
	_tape_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_tape_panel)
	var tv := VBoxContainer.new()
	_tape_panel.add_child(tv)
	_tape_title = UIKit.flabel(tv, "", 18, "mono", Color(1.0, 0.75, 0.35))
	_tape_line = UIKit.flabel(tv, "", 19, "italic", UIKit.TEXT)
	_tape_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tape_line.custom_minimum_size = Vector2(500, 0)
	_tape_player = AudioStreamPlayer.new()
	_tape_player.bus = "Voice"
	add_child(_tape_player)

	# Journal
	_journal = PanelContainer.new()
	_journal.add_theme_stylebox_override("panel", UIKit.box(Color(0.9, 0.86, 0.75, 0.97), 22, 4))
	UIKit.place(_journal, Control.PRESET_CENTER, Vector2(-460, -310), Vector2(920, 620))
	_journal.visible = false
	_root.add_child(_journal)
	_journal_text = RichTextLabel.new()
	_journal_text.bbcode_enabled = true
	_journal_text.scroll_active = false
	_journal_text.add_theme_color_override("default_color", Color(0.15, 0.12, 0.1))
	_journal_text.add_theme_font_size_override("normal_font_size", 19)
	_journal_text.add_theme_font_override("normal_font", UIKit.font("body"))
	_journal_text.add_theme_font_override("bold_font", UIKit.font("head"))
	_journal_text.add_theme_font_override("italics_font", UIKit.font("italic"))
	_journal_text.add_theme_font_size_override("bold_font_size", 22)
	_journal.add_child(_journal_text)

	# Note reader
	_note = PanelContainer.new()
	_note.add_theme_stylebox_override("panel", UIKit.box(Color(0.93, 0.89, 0.78, 0.99), 34, 2))
	UIKit.place(_note, Control.PRESET_CENTER, Vector2(-380, -320), Vector2(760, 640))
	_note.visible = false
	_root.add_child(_note)
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 16)
	_note.add_child(nv)
	_note_title = UIKit.label(nv, "", 26, Color(0.25, 0.15, 0.08), HORIZONTAL_ALIGNMENT_CENTER)
	_note_title.remove_theme_color_override("font_shadow_color")
	_note_text = UIKit.label(nv, "", 18, Color(0.12, 0.1, 0.08))
	_note_text.remove_theme_color_override("font_shadow_color")
	_note_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_text.custom_minimum_size = Vector2(690, 0)
	var nclose := UIKit.label(nv, "[E] close", 15, Color(0.4, 0.35, 0.3), HORIZONTAL_ALIGNMENT_CENTER)
	nclose.remove_theme_color_override("font_shadow_color")

	# CCTV
	_cctv = Control.new()
	_cctv.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cctv.visible = false
	_root.add_child(_cctv)
	var container := SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.stretch_shrink = 3
	_cctv.add_child(container)
	_cctv_vp = SubViewport.new()
	_cctv_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	container.add_child(_cctv_vp)
	_cctv_cam = Camera3D.new()
	_cctv_cam.fov = 80.0
	_cctv_vp.add_child(_cctv_cam)
	var scan := ColorRect.new()
	scan.set_anchors_preset(Control.PRESET_FULL_RECT)
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/cctv.gdshader")
	scan.material = sm
	_cctv.add_child(scan)
	_cctv_label = UIKit.flabel(_cctv, "", 34, "mono", Color(0.75, 1.0, 0.8))
	UIKit.place(_cctv_label, Control.PRESET_TOP_LEFT, Vector2(40, 30), Vector2(900, 40))
	var ch := UIKit.label(_cctv, "A / D  switch camera      E  stop watching", 18, Color(0.75, 1.0, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	UIKit.place(ch, Control.PRESET_CENTER_BOTTOM, Vector2(-400, -60), Vector2(800, 30))

	# Night title card
	_title_card = Control.new()
	_title_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_card.modulate.a = 0.0
	_root.add_child(_title_card)
	var tvb := UIKit.center_box(_title_card, 6)
	tvb.get_parent().mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_big = UIKit.flabel(tvb, "", 76, "title", UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_title_small = UIKit.flabel(tvb, "", 30, "head_light", UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)

	# Pause
	_pause = UIKit.overlay(_root, Color(0, 0, 0, 0.78))
	var pbox := UIKit.center_box(_pause)
	UIKit.flabel(pbox, "Paused", 56, "title", UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	UIKit.label(pbox, "Coffee break. The exhibits are also on break. Probably.", 18, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	UIKit.button(pbox, "Resume", _toggle_pause)
	UIKit.button(pbox, "Settings", func() -> void: _settings.visible = true)
	UIKit.button(pbox, "Restart night", func() -> void: retry_requested.emit(false))
	UIKit.button(pbox, "Main menu", func() -> void: menu_requested.emit())
	UIKit.button(pbox, "Quit to desktop", func() -> void: get_tree().quit())
	var sc := CenterContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause.add_child(sc)
	_settings = preload("res://scripts/ui/settings_panel.gd").new()
	_settings.visible = false
	sc.add_child(_settings)

	# End screen
	_end = UIKit.overlay(_root, Color(0, 0, 0, 0.86))
	var ebox := UIKit.center_box(_end)
	_end_title = UIKit.flabel(ebox, "", 66, "title", UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_end_text = UIKit.label(ebox, "", 20, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_end_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_text.custom_minimum_size = Vector2(820, 0)
	_end_buttons = VBoxContainer.new()
	_end_buttons.add_theme_constant_override("separation", 12)
	ebox.add_child(_end_buttons)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)

	_root.move_child(_title_card, -1) # title cards show on top of the black fade

	_sfx = AudioStreamPlayer.new()
	_sfx.bus = "UI"
	add_child(_sfx)
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Voice"
	_voice.volume_db = -8.0
	add_child(_voice)


func _bar(parent: Node, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(240, 10)
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_stylebox_override("background", UIKit.box(Color(0, 0, 0, 0.5), 2, 3))
	b.add_theme_stylebox_override("fill", UIKit.box(color, 2, 3))
	parent.add_child(b)
	return b


# --- Runtime -------------------------------------------------------------

func _process(delta: float) -> void:
	if player == null:
		return
	_battery.value = player.battery
	_battery.modulate.a = 1.0 if player.has_flashlight else 0.25
	_stamina.value = player.stamina
	_stamina.modulate = Color(1, 0.4, 0.4) if player.exhausted else Color.WHITE
	var show_prompt: bool = player.focus != null and not player.controls_locked
	if show_prompt:
		_prompt.text = "[E]  " + player.focus.prompt
	elif player.is_hidden:
		_prompt.text = "[E]  Leave the locker"
	else:
		_prompt.text = ""
	_crosshair.color = Color(1, 0.9, 0.6, 0.9) if show_prompt else Color(1, 1, 1, 0.45)
	_crosshair.visible = not player.is_hidden
	match player.carrying:
		"duck":
			_carry.text = "Carrying: THE GOLDEN DUCK"
		"bulbs":
			_carry.text = "Carrying: light bulbs x%d" % player.carry_count
		"sword":
			_carry.text = "Carrying: Sir Clanksworth's sword"
		_:
			_carry.text = ""
	var inv := PackedStringArray()
	if player.has_camera:
		inv.append("FILM x%d  [R]" % player.film)
	if player.ducks > 0:
		inv.append("SQUEAKY DUCKS x%d  [G]" % player.ducks)
	_inventory.text = "      ".join(inv)
	if _tape_player.playing:
		var pos := _tape_player.get_playback_position()
		var line := ""
		for tl in _tape_timings:
			if pos >= float(tl[0]):
				line = tl[1]
		_tape_line.text = line
		Music.duck_for(0.3)
	elif _tape_panel.visible:
		_tape_panel.visible = false
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
	if _reading:
		if event.is_action_pressed("interact") or event.is_action_pressed("pause") or event.is_action_pressed("journal") or event.is_action_pressed("interact_mouse"):
			close_note()
			get_viewport().set_input_as_handled()
		return
	if _cctv.visible:
		if event.is_action_pressed("interact") or event.is_action_pressed("pause"):
			close_cctv()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("move_left"):
			_cctv_switch(-1)
		elif event.is_action_pressed("move_right"):
			_cctv_switch(1)
		return
	if event.is_action_pressed("pause"):
		if _settings.visible:
			_settings.visible = false
		else:
			_toggle_pause()
	elif event.is_action_pressed("journal") and not get_tree().paused:
		_journal.visible = not _journal.visible
		if _journal.visible and player:
			player.play_sfx(preload("res://audio/paper.wav"), -10.0)
	elif event.is_action_pressed("debug_skip_hour") and OS.is_debug_build() and not get_tree().paused:
		Shift.skip_hour()


func _toggle_pause() -> void:
	if _ended:
		return
	var paused := not get_tree().paused
	get_tree().paused = paused
	_pause.visible = paused
	_settings.visible = false
	_journal.visible = false
	Music.set_muffled("Music", paused)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED


func is_busy() -> bool:
	return _reading or _cctv.visible or _ended


# --- Tasks / journal / notes ----------------------------------------------

func _refresh_tasks() -> void:
	if _tasks == null:
		return
	var lines := PackedStringArray()
	for t in Shift.tasks:
		if not t["done"]:
			lines.append("-  " + Shift.task_label(t))
	_tasks.text = ("TASKS\n" + "\n".join(lines)) if lines.size() > 0 else ""


func _refresh_journal() -> void:
	var s := "[b]GUARD'S JOURNAL  -  NIGHT %d[/b]\n[i]Pemberton Museum of Questionable History[/i]\n\n[b]Tasks[/b]\n" % Shift.night
	for t in Shift.tasks:
		s += ("[s][lb]x[rb] %s[/s]\n" if t["done"] else "[lb]  [rb] %s\n") % Shift.task_label(t)
	s += "\n[b]Museum Rules[/b]\n"
	for r in Shift.rules_for_night():
		s += r + "\n"
	s += "\n[b]Write-ups: %d / %d[/b]\n" % [Shift.writeups.size(), Shift.max_writeups()]
	for w in Shift.writeups:
		s += "- " + w + "\n"
	var found: Array = Save.progress["notes"]
	s += "\n[b]Documents found: %d / %d[/b]\n" % [found.size(), Notes.LIST.size()]
	var titles := PackedStringArray()
	for id in found:
		titles.append(Notes.title(int(id)))
	s += ", ".join(titles)
	var tapes: Array = Save.progress.get("tapes", [])
	s += "\n\n[b]Tapes found: %d / %d[/b]\n" % [tapes.size(), Tapes.LIST.size()]
	var tt := PackedStringArray()
	for id in tapes:
		tt.append(Tapes.title(int(id)))
	s += ", ".join(tt)
	_journal_text.text = s


func open_journal() -> void:
	_journal.visible = true


func show_note(id: int) -> void:
	_note_title.text = Notes.title(id)
	_note_text.text = Notes.text(id)
	var st := Notes.style(id)
	_note_text.add_theme_font_override("font", UIKit.font({"type": "type", "hand": "hand", "print": "body"}.get(st, "body")))
	_note_text.add_theme_font_size_override("font_size", {"type": 17, "hand": 25, "print": 20}.get(st, 18))
	_note_title.add_theme_font_override("font", UIKit.font("head"))
	_note.visible = true
	_journal.visible = false
	_reading = true
	get_tree().paused = true
	if player:
		player.play_sfx(preload("res://audio/paper.wav"), -4.0)


func close_note() -> void:
	_note.visible = false
	_reading = false
	get_tree().paused = false


# --- CCTV -----------------------------------------------------------------

func open_cctv(points: Array) -> void:
	if points.is_empty():
		return
	_cctv_points = points
	_cctv.visible = true
	_cctv_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_cctv_switch(0)
	if player:
		player.controls_locked = true


func close_cctv() -> void:
	_cctv.visible = false
	_cctv_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if player:
		player.controls_locked = false


func _cctv_switch(step: int) -> void:
	_cctv_idx = wrapi(_cctv_idx + step, 0, _cctv_points.size())
	var m: Node3D = _cctv_points[_cctv_idx]
	_cctv_cam.global_transform = m.global_transform
	_cctv_label.text = "CAM %d  -  %s      %s" % [_cctv_idx + 1, String(m.name).to_upper().replace("_", " "), Shift.get_clock_text()]
	_play(preload("res://audio/ui_click.wav"), -6.0)


# --- Messages / alerts ----------------------------------------------------

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
	_subtitle_panel.visible = bool(Save.settings["subtitles"]) or speaker == ""
	_msg_time = m["duration"]
	if speaker.begins_with("BRENDA"):
		var path := "res://audio/voice/line_%s.ogg" % String(m["text"]).md5_text().substr(0, 10)
		if ResourceLoader.exists(path):
			_voice.stream = load(path)
			_voice.pitch_scale = 1.0
			_voice.volume_db = -2.0
			_msg_time = maxf(_msg_time, _voice.stream.get_length() + 0.4)
		else:
			_play(preload("res://audio/radio_squelch.wav"), -10.0)
			_voice.stream = BABBLE[randi() % BABBLE.size()]
			_voice.pitch_scale = randf_range(0.95, 1.08)
			_voice.volume_db = -8.0
		_voice.play()


func play_tape(id: int) -> void:
	var path := "res://audio/voice/tape_%d.ogg" % id
	if not ResourceLoader.exists(path):
		return
	_tape_player.stream = load(path)
	_tape_player.play()
	_tape_timings = []
	var f := FileAccess.open("res://audio/voice/tape_%d.json" % id, FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Array:
			_tape_timings = parsed
	_tape_title.text = "> PLAYING  %s  -  %s" % [Tapes.title(id).to_upper(), Tapes.who(id)]
	_tape_line.text = ""
	_tape_panel.visible = true


func is_tape_playing() -> bool:
	return _tape_player.playing


func _show_alert(text: String) -> void:
	_alert.text = text
	_alert_time = 3.5


func _on_writeup(count: int, reason: String) -> void:
	_alert.text = "WRITE-UP %d/%d: %s" % [count, Shift.max_writeups(), reason]
	_alert_time = 5.0


func set_meter(text: String, value: float, show: bool = true) -> void:
	_meter_box.visible = show
	_meter_label.text = text
	_meter.value = value
	_meter.modulate = Color(1, 0.35, 0.3) if value < 30.0 else Color.WHITE


func _play(stream: AudioStream, volume_db: float) -> void:
	_sfx.stream = stream
	_sfx.volume_db = volume_db
	_sfx.play()


func fade_in(duration: float) -> void:
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, duration)


func fade_out(duration: float) -> Tween:
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, duration)
	return t


func title_card(big: String, small: String) -> void:
	_title_big.text = big
	_title_small.text = small
	var t := create_tween()
	t.tween_property(_title_card, "modulate:a", 1.0, 1.2)
	t.tween_interval(2.5)
	t.tween_property(_title_card, "modulate:a", 0.0, 1.5)


func set_night_label(text: String) -> void:
	_night_label.text = text


# --- End screens ----------------------------------------------------------

func show_end(won: bool, title: String, text: String, buttons: Array) -> void:
	_ended = true
	_journal.visible = false
	_pause.visible = false
	_note.visible = false
	_cctv.visible = false
	_subtitle_panel.visible = false
	_end_title.text = title
	_end_title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.65) if won else Color(1.0, 0.35, 0.3))
	_end_text.text = text
	for c in _end_buttons.get_children():
		c.queue_free()
	for b in buttons:
		UIKit.button(_end_buttons, b[0], b[1])
	_end.visible = true
	_end.modulate.a = 0.0
	create_tween().tween_property(_end, "modulate:a", 1.0, 0.8)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
