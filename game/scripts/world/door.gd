extends Node3D
## A locked door that can be opened by the night script (swings open, stops blocking).

signal opened

@export var locked := true
var _open := false


func _ready() -> void:
	if not locked:
		open(true)


func open(instant: bool = false) -> void:
	if _open:
		return
	_open = true
	locked = false
	var body: StaticBody3D = $Body
	body.collision_layer = 0
	var use: Node = body.get_node_or_null("Use")
	if use:
		use.active = false
	var sign: Node3D = body.get_node_or_null("Sign")
	if sign:
		sign.visible = false
	if instant:
		rotation.y += deg_to_rad(-100)
	else:
		var p := AudioStreamPlayer3D.new()
		p.stream = preload("res://audio/door_open.wav")
		p.bus = "SFX"
		p.position = Vector3(0.6, 1.2, 0)
		add_child(p)
		p.play()
		create_tween().tween_property(self, "rotation:y", rotation.y + deg_to_rad(-100), 1.6).set_trans(Tween.TRANS_SINE)
	opened.emit()


func close_and_lock() -> void:
	if not _open:
		return
	_open = false
	locked = true
	rotation.y += deg_to_rad(100)
	var body: StaticBody3D = $Body
	body.collision_layer = 16
	var use: Node = body.get_node_or_null("Use")
	if use:
		use.active = true
	var sign: Node3D = body.get_node_or_null("Sign")
	if sign:
		sign.visible = true


func is_open() -> bool:
	return _open
