extends Control
## Scrolling credits. Any key / click returns to the menu.

const TEXT := """DO NOT TOUCH THE EXHIBITS



A night-shift survival horror comedy


~


Design, code, art, music and sound
procedurally generated for this build

Story
The Pemberton Museum of Questionable History


Starring

THE NEW GUY  ...  You
BRENDA HOLLOWAY  ...  Head of Night Security (1962 - forever)
SIR CLANKSWORTH  ...  Himself (empty)
THE PHARAOH'S NEIGHBOUR  ...  A light sleeper
GERALD  ...  A very shy Tyrannosaurus
LITTLE WOLFGANG  ...  Clockwork, one song
THE DUCHESS  ...  Disappointed
GARY FINCH  ...  Night Guard, still technically employed
THE GOLDEN DUCK OF UR-QUACK  ...  The Duck


~


Made with Godot Engine
Godot Engine is MIT licensed  -  (c) 2014-present Godot Engine contributors,
(c) 2007-2014 Juan Linietsky, Ariel Manzur.


No exhibits were harmed in the making of this game.
Several were touched. They know who you are.



Thank you for clocking in.
"""

var _label: Label
var _speed := 45.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Music.current != "credits" and Music.current != "dawn":
		Music.play_now("credits")
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.025)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_label = UIKit.label(self, TEXT, 26, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_label.size = Vector2(get_viewport_rect().size.x, 2400)
	_label.position = Vector2(0, get_viewport_rect().size.y)


func _process(delta: float) -> void:
	_label.position.y -= _speed * delta
	if _label.position.y < -_label.get_minimum_size().y - 100:
		_exit()


func _input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed):
		_exit()


func _exit() -> void:
	set_process(false)
	set_process_input(false)
	Music.stop_all()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
