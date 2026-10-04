extends Node3D
## Title screen: the museum at night behind a gold title and a museum-plaque style menu.

const MUSEUM := preload("res://scenes/museum.scn")
const SHOTS := [
	[Vector3(-5.0, 1.7, 9.0), Vector3(5.0, 1.8, 7.5), Vector3(0, 1.4, 5.0)],   # lobby, the knight
	[Vector3(-8.0, 7.2, 7.5), Vector3(4.0, 7.4, 7.6), Vector3(0, 3.0, -2.0)],  # balcony over the atrium
	[Vector3(4.5, 1.6, -11.5), Vector3(7.5, 1.6, -12.5), Vector3(6, 1.3, -20.5)], # Egyptian hall
	[Vector3(14.0, 1.8, 5.0), Vector3(15.0, 2.4, -1.0), Vector3(19.5, 2.8, -4.0)], # Gerald
]

var _cam: Camera3D
var _t := 0.0
var _shot := 0
var _main: VBoxContainer
var _nights: VBoxContainer
var _settings: PanelContainer
var _fade: ColorRect


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
	_cam.fov = 55.0
	add_child(_cam)
	_cam.current = true
	add_child(preload("res://scripts/post_fx.gd").new())
	_build_ui()


func _process(delta: float) -> void:
	_t += delta / 14.0
	if _t >= 1.0:
		_t = 0.0
		_shot = (_shot + 1) % SHOTS.size()
		_fade.color.a = 1.0
		create_tween().tween_property(_fade, "color:a", 0.0, 1.2)
	var s: Array = SHOTS[_shot]
	var k := smoothstep(0.0, 1.0, _t)
	_cam.global_position = (s[0] as Vector3).lerp(s[1], k)
	_cam.look_at(s[2], Vector3.UP)
	if _t > 0.93:
		_fade.color.a = maxf(_fade.color.a, (_t - 0.93) / 0.07)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	# Left-side darkening so the text reads over the 3D scene
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.88))
	g.set_color(1, Color(0, 0, 0, 0.0))
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	grad.texture = gt
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	UIKit.place(grad, Control.PRESET_LEFT_WIDE, Vector2(0, 0), Vector2(900, 0))
	grad.offset_bottom = 0
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(grad)

	var left := VBoxContainer.new()
	UIKit.place(left, Control.PRESET_CENTER_LEFT, Vector2(80, -320), Vector2(620, 640))
	left.add_theme_constant_override("separation", 6)
	root.add_child(left)
	UIKit.title_logo(left, 66)
	UIKit.flabel(left, "A night-shift survival horror comedy", 22, "italic", Color(0.78, 0.74, 0.66))
	UIKit.divider(left, 440)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	left.add_child(spacer)

	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 0)
	left.add_child(_main)
	var unlocked := int(Save.progress["night_unlocked"])
	var cont := mini(unlocked, Shift.LAST_NIGHT)
	if unlocked > 1:
		UIKit.menu_button(_main, "Continue  -  Night %d" % cont, func() -> void: _start(cont))
	UIKit.menu_button(_main, "New Game" if unlocked > 1 else "Begin Your Shift", func() -> void: _start(1))
	if unlocked > 1:
		UIKit.menu_button(_main, "Select Night", func() -> void:
			_main.visible = false
			_nights.visible = true)
	UIKit.menu_button(_main, "Settings", func() -> void: _settings.visible = true)
	UIKit.menu_button(_main, "Credits", func() -> void: get_tree().change_scene_to_file("res://scenes/credits.tscn"))
	UIKit.menu_button(_main, "Quit", func() -> void: get_tree().quit())

	_nights = VBoxContainer.new()
	_nights.add_theme_constant_override("separation", 0)
	_nights.visible = false
	left.add_child(_nights)
	for n in range(1, Shift.LAST_NIGHT + 1):
		var title: Array = Shift.NIGHT_TITLES[n]
		var b := UIKit.menu_button(_nights, "%s  -  %s" % [title[0].capitalize(), title[1]], func() -> void: _start(n), 22)
		b.disabled = n > unlocked
	UIKit.menu_button(_nights, "Back", func() -> void:
		_nights.visible = false
		_main.visible = true, 22)

	var endings: Array = Save.progress["endings"]
	var info := "Documents %d / %d     Tapes %d / %d     Endings %d / 2" % [Save.progress["notes"].size(), Notes.LIST.size(), Save.progress.get("tapes", []).size(), Tapes.LIST.size(), endings.size()]
	var foot := UIKit.flabel(root, info, 17, "head_light", UIKit.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	UIKit.place(foot, Control.PRESET_BOTTOM_RIGHT, Vector2(-760, -64), Vector2(720, 26))
	var ver := UIKit.flabel(root, "v0.3   -   art, music and voices are procedurally generated placeholders", 14, "italic", Color(0.5, 0.48, 0.44), HORIZONTAL_ALIGNMENT_RIGHT)
	UIKit.place(ver, Control.PRESET_BOTTOM_RIGHT, Vector2(-760, -36), Vector2(720, 22))

	var sc := CenterContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sc)
	_settings = preload("res://scripts/ui/settings_panel.gd").new()
	_settings.visible = false
	sc.add_child(_settings)

	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 2.0)


func _start(n: int) -> void:
	Shift.night = n
	Shift.pending_checkpoint = {}
	Music.stop_all()
	get_tree().change_scene_to_file("res://scenes/game.tscn")
