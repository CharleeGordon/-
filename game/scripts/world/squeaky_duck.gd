extends RigidBody3D
## A thrown squeaky rubber duck from the gift shop. Squeaks on landing: every exhibit that can hear goes to look.

var _armed := 0.15
var _squeaked := false
var _life := 20.0


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 2
	body_entered.connect(_on_hit)


func _process(delta: float) -> void:
	_armed -= delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_hit(_body: Node) -> void:
	if _armed > 0.0 or _squeaked:
		return
	_squeaked = true
	var p := AudioStreamPlayer3D.new()
	p.stream = preload("res://audio/squeak.wav")
	p.unit_size = 8.0
	p.bus = "SFX"
	add_child(p)
	p.play()
	Shift.make_noise(global_position, 16.0)
