extends Node3D
## Title screen: the museum lobby at night in the background, slow camera drift, menu on top.

const MUSEUM := preload("res://scenes/museum.scn")

var _cam: Camera3D
var _t := 0.0
var _main: VBoxContainer
var _nights: VBoxContainer
var _settings: PanelContainer


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Shift.stop()
	Music.reset_reports()
	Music.play_now("menu")
	var museum := MUSEUM.instantiate()
	add_child(museum)
	var env: WorldEnvironment = museum.get_node("WorldEnvironment")
	Save.apply_quality(env.environment, get_viewport())
	_cam = Camera3D.new()
	_cam.fov = 60.0
	add_child(_cam)
	_cam.current = true
	add_child(preload("res://scripts/post_fx.gd").new())
	_build_ui()


func _process(delta: float) -> void:
	_t += delta * 0.025
	var a := sin(_t * TAU)
	_cam.global_position = Vector3(lerpf(-5.0, 5.0, a * 0.5 + 0.5), 1.75 + sin(_t * 9.0) * 0.05, 7.5 + cos(_t * TAU) * 0.8)
	_cam.look_at(Vector3(0, 1.5, -3.0), Vector3.UP)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var fade := ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color.BLACK
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var left := VBoxContainer.new()
	UIKit.place(left, Control.PRESET_CENTER_LEFT, Vector2(90, -330), Vector2(560, 600))
	left.add_theme_constant_override("separation", 10)
	root.add_child(left)
	UIKit.label(left, "DO NOT TOUCH\nTHE EXHIBITS", 62, UIKit.GOLD)
	UIKit.label(left, "A night-shift survival horror comedy", 22, UIKit.DIM)
	left.add_child(Control.new())

	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 8)
	left.add_child(_main)
	var unlocked := int(Save.progress["night_unlocked"])
	var cont := mini(unlocked, Shift.LAST_NIGHT)
	if unlocked > 1:
		_btn(_main, "Continue  -  Night %d" % cont, func() -> void: _start(cont))
	_btn(_main, "New Game" if unlocked > 1 else "Start Night 1", func() -> void: _start(1))
	if unlocked > 1:
		_btn(_main, "Select Night", func() -> void:
			_main.visible = false
			_nights.visible = true)
	_btn(_main, "Settings", func() -> void: _settings.visible = true)
	_btn(_main, "Credits", func() -> void: get_tree().change_scene_to_file("res://scenes/credits.tscn"))
	_btn(_main, "Quit", func() -> void: get_tree().quit())

	_nights = VBoxContainer.new()
	_nights.add_theme_constant_override("separation", 10)
	_nights.visible = false
	left.add_child(_nights)
	for n in range(1, Shift.LAST_NIGHT + 1):
		var title: Array = Shift.NIGHT_TITLES[n]
		var b := _btn(_nights, "%s  -  %s" % [title[0], title[1]], func() -> void: _start(n))
		b.disabled = n > unlocked
	_btn(_nights, "Back", func() -> void:
		_nights.visible = false
		_main.visible = true)

	var endings: Array = Save.progress["endings"]
	var info := "Documents found: %d / %d" % [Save.progress["notes"].size(), Notes.LIST.size()]
	if not endings.is_empty():
		info += "     Endings seen: %d / 2" % endings.size()
	var foot := UIKit.label(root, info + "\nv0.2 - all art, music and sound are procedurally generated placeholders", 15, UIKit.DIM)
	UIKit.place(foot, Control.PRESET_BOTTOM_LEFT, Vector2(90, -52), Vector2(900, 46))

	var sc := CenterContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sc)
	_settings = preload("res://scripts/ui/settings_panel.gd").new()
	_settings.visible = false
	sc.add_child(_settings)
	root.add_child(fade)
	create_tween().tween_property(fade, "color:a", 0.0, 2.0)


func _btn(parent: Node, text: String, cb: Callable) -> Button:
	var b := UIKit.button(parent, text, cb, 380.0)
	b.custom_minimum_size.y = 44
	b.get_parent().size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b


func _start(n: int) -> void:
	Shift.night = n
	Shift.pending_checkpoint = {}
	Music.stop_all()
	get_tree().change_scene_to_file("res://scenes/game.tscn")
