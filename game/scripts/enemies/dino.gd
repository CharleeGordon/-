extends Node3D
## Gerald, a very shy Tyrannosaurus skeleton. Flashlight in the eyes = ROAR + write-up + noise.

const STARE_LIMIT := 1.4
const COOLDOWN := 15.0

var enabled := true
var head: Node3D
var jaw: Node3D
var eye_point: Marker3D
var eye_mat: StandardMaterial3D
var _stare := 0.0
var _cooldown := 0.0
var _warned := false
var _roar: AudioStreamPlayer3D


func _ready() -> void:
	head = $Model/Head
	jaw = $Model/Head/Jaw
	eye_point = $Model/Head/EyePoint
	var eye: MeshInstance3D = $Model/Head/EyeL
	eye_mat = eye.mesh.surface_get_material(0)
	_roar = AudioStreamPlayer3D.new()
	_roar.stream = preload("res://audio/roar.ogg")
	_roar.unit_size = 25.0
	_roar.volume_db = 6.0
	_roar.bus = "SFX"
	eye_point.add_child(_roar)


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not Shift.running or not enabled:
		return
	if _cooldown <= 0.0 and player.flashlight_hits(eye_point.global_position, 0.85):
		_stare += delta
		if _stare > 0.5 and not _warned:
			_warned = true
			Shift.alert.emit("Gerald looks... uncomfortable.")
	else:
		_stare = maxf(_stare - delta * 0.5, 0.0)
	if eye_mat:
		eye_mat.emission_energy_multiplier = 0.6 + _stare * 6.0
	if _stare >= STARE_LIMIT:
		_do_roar(player)


func _do_roar(player: Node) -> void:
	_stare = 0.0
	_warned = false
	_cooldown = COOLDOWN
	_roar.play()
	player.shake(1.5)
	var t := create_tween().set_parallel()
	t.tween_property(head, "rotation:z", deg_to_rad(-20), 0.2)
	t.tween_property(jaw, "rotation:z", deg_to_rad(-25), 0.2)
	t.chain().tween_interval(1.0)
	t.chain().tween_property(head, "rotation:z", 0.0, 1.2)
	t.parallel().tween_property(jaw, "rotation:z", 0.0, 1.2)
	Shift.say("RRRAAAAWWWRRR!!!", "GERALD", 2.5)
	Shift.add_writeup("Shone a flashlight in Gerald's eyes (Rule 4)")
	Shift.make_noise(global_position, 60.0)
