extends Node3D
## Gerald, a very shy Tyrannosaurus skeleton. Flashlight in the eyes = ROAR + write-up.

const STARE_LIMIT := 1.4
const COOLDOWN := 15.0

@onready var head: Node3D = $Head
@onready var eye_point: Marker3D = $Head/EyePoint
@onready var eye_mat: StandardMaterial3D = ($Head/EyeL as MeshInstance3D).mesh.material

var _stare := 0.0
var _cooldown := 0.0
var _warned := false
var _roar: AudioStreamPlayer3D


func _ready() -> void:
	_roar = AudioStreamPlayer3D.new()
	_roar.stream = preload("res://audio/roar.wav")
	_roar.unit_size = 20.0
	_roar.volume_db = 6.0
	eye_point.add_child(_roar)


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not Shift.running:
		return
	if _cooldown <= 0.0 and player.flashlight_hits(eye_point.global_position, 0.8):
		_stare += delta
		if _stare > 0.5 and not _warned:
			_warned = true
			Shift.alert.emit("Gerald looks... uncomfortable.")
	else:
		_stare = maxf(_stare - delta * 0.5, 0.0)
	eye_mat.emission_energy_multiplier = 0.4 + _stare * 4.0
	if _stare >= STARE_LIMIT:
		_do_roar(player)


func _do_roar(player: Node) -> void:
	_stare = 0.0
	_warned = false
	_cooldown = COOLDOWN
	_roar.play()
	player.shake(1.5)
	var t := create_tween()
	t.tween_property(head, "rotation:z", deg_to_rad(-18), 0.15)
	t.tween_property(head, "rotation:z", 0.0, 1.2).set_delay(0.8)
	Shift.say("RRRAAAAWWWRRR!!!", "GERALD", 2.5)
	Shift.add_writeup("Shone a flashlight in Gerald's eyes (Rule 4)")
	Shift.make_noise(global_position)
