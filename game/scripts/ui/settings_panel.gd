extends PanelContainer
## Settings window (used from the main menu and the pause menu).

signal closed


func _ready() -> void:
	add_theme_stylebox_override("panel", UIKit.box(Color(0.04, 0.04, 0.05, 0.96), 28, 8, Color(0.5, 0.42, 0.25)))
	custom_minimum_size = Vector2(640, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)
	UIKit.label(vb, "SETTINGS", 34, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_slider(vb, "Mouse sensitivity", "mouse_sens", 0.2, 3.0, 0.05)
	_toggle(vb, "Invert mouse Y", "invert_y")
	_slider(vb, "Field of view", "fov", 60.0, 100.0, 1.0)
	_toggle(vb, "Head bob", "head_bob")
	_slider(vb, "Master volume", "master", 0.0, 1.0, 0.05)
	_slider(vb, "Music volume", "music", 0.0, 1.0, 0.05)
	_slider(vb, "Effects volume", "sfx", 0.0, 1.0, 0.05)
	_option(vb, "Graphics quality", "quality", Save.QUALITY_NAMES)
	_option(vb, "Difficulty", "difficulty", ["Story (forgiving)", "Normal"])
	_toggle(vb, "Fullscreen", "fullscreen")
	_toggle(vb, "Subtitles", "subtitles")
	UIKit.button(vb, "Back", func() -> void:
		visible = false
		closed.emit())


func _row(parent: Node, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var l := UIKit.label(row, text, 19)
	l.custom_minimum_size = Vector2(260, 0)
	return row


func _slider(parent: Node, text: String, key: String, lo: float, hi: float, step: float) -> void:
	var row := _row(parent, text)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Save.settings[key])
	s.custom_minimum_size = Vector2(260, 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var val := UIKit.label(row, _fmt(s.value), 18, UIKit.DIM)
	s.value_changed.connect(func(v: float) -> void:
		val.text = _fmt(v)
		Save.set_setting(key, v))


func _fmt(v: float) -> String:
	return str(int(v)) if v >= 10.0 else "%.2f" % v


func _toggle(parent: Node, text: String, key: String) -> void:
	var row := _row(parent, text)
	var c := CheckButton.new()
	c.button_pressed = bool(Save.settings[key])
	row.add_child(c)
	c.toggled.connect(func(on: bool) -> void:
		Music.ui("ui_click")
		Save.set_setting(key, on))


func _option(parent: Node, text: String, key: String, items: Array) -> void:
	var row := _row(parent, text)
	var o := OptionButton.new()
	for i in items.size():
		o.add_item(items[i], i)
	o.selected = int(Save.settings[key])
	o.custom_minimum_size = Vector2(260, 32)
	row.add_child(o)
	o.item_selected.connect(func(i: int) -> void:
		Save.set_setting(key, i)
		if key == "quality":
			var env := get_viewport().find_child("WorldEnvironment", true, false) as WorldEnvironment
			Save.apply_quality(env.environment if env else null, get_viewport()))
