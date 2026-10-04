extends Control
## Title screen.

func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	_label(box, "DO NOT TOUCH\nTHE EXHIBITS", 72, Color(0.92, 0.82, 0.55))
	_label(box, "A night-shift survival horror comedy", 22, Color(0.75, 0.75, 0.8))
	box.add_child(Control.new())

	var start := _button(box, "Start Night 1")
	start.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/game.tscn"))
	var help := _button(box, "How to play")
	var quit := _button(box, "Quit")
	quit.pressed.connect(func() -> void: get_tree().quit())

	var help_text := _label(box,
		"You are the new night guard. Survive until 6:00 AM (about 10 minutes).\n" +
		"Do your tasks, follow the museum rules, and keep an eye on the exhibits.\n\n" +
		"WASD - move    SHIFT - run    F - flashlight    E - use\n" +
		"TAB - journal (tasks + rules)    ESC - pause    F11 - fullscreen",
		18, Color(0.85, 0.85, 0.85))
	help_text.visible = false
	help.pressed.connect(func() -> void: help_text.visible = not help_text.visible)

	_label(box, "MVP build 0.1 - placeholder art", 14, Color(0.45, 0.45, 0.5))
	start.grab_focus()


func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _button(parent: Node, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 52)
	b.add_theme_font_size_override("font_size", 24)
	var c := CenterContainer.new()
	c.add_child(b)
	parent.add_child(c)
	return b
