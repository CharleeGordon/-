extends Node3D
## A swarm of escaped moths (Lepidoptera collection, 1974). Drawn to your flashlight.
## When they reach you they smother the light and drain the battery fast. Turn the light off.

@export var room_id := ""
const COUNT := 48
const SPEED := 2.4

var enabled := false
var _center := Vector3.ZERO
var _home := Vector3.ZERO
var _mm: MultiMeshInstance3D
var _phase := []
var _flutter: AudioStreamPlayer3D
var _on_player := 0.0


func _ready() -> void:
	_home = global_position
	_center = _home
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.05)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.5, 0.42)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = COUNT
	_mm = MultiMeshInstance3D.new()
	_mm.multimesh = mm
	_mm.top_level = true
	add_child(_mm)
	for i in COUNT:
		_phase.append(Vector3(randf() * TAU, randf() * TAU, randf_range(0.6, 1.4)))
	_flutter = AudioStreamPlayer3D.new()
	_flutter.stream = preload("res://audio/moths.wav")
	_flutter.unit_size = 3.0
	_flutter.bus = "SFX"
	_flutter.volume_db = -6.0
	add_child(_flutter)
	visible = false


func set_enabled(on: bool) -> void:
	enabled = on
	visible = on
	if not on:
		_flutter.stop()


func _process(delta: float) -> void:
	if not enabled:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var target := _home
	var chasing: bool = player.flashlight_on and player.current_room == room_id and Shift.running
	if chasing:
		target = player.camera.global_position + (-player.camera.global_transform.basis.z) * 0.6
	_center = _center.move_toward(target, delta * (SPEED if chasing else 1.0))
	var t := Time.get_ticks_msec() / 1000.0
	var spread := 0.35 if _center.distance_to(target) < 0.8 and chasing else 1.2
	for i in COUNT:
		var ph: Vector3 = _phase[i]
		var o := Vector3(sin(t * 2.3 * ph.z + ph.x), sin(t * 3.1 * ph.z + ph.y) * 0.6, cos(t * 1.9 * ph.z + ph.x * 0.7)) * spread
		var xf := Transform3D(Basis(Vector3.UP, t * 6.0 * ph.z + i).rotated(Vector3.RIGHT, sin(t * 30.0 + i) * 0.8), _center + o)
		_mm.multimesh.set_instance_transform(i, xf)
	global_position = _center
	var near: bool = chasing and _center.distance_to(player.camera.global_position) < 1.5
	if near:
		player.battery = maxf(player.battery - 4.0 * delta, 0.0)
		_on_player += delta
		if _on_player > 0.5 and int(_on_player * 2.0) % 6 == 1:
			Shift.alert.emit("Moths! They're smothering the flashlight - turn it OFF!")
	else:
		_on_player = 0.0
	if (chasing or _center.distance_to(_home) > 0.5) and not _flutter.playing:
		_flutter.play()
	elif not chasing and _center.distance_to(_home) < 0.5 and _flutter.playing:
		_flutter.stop()
