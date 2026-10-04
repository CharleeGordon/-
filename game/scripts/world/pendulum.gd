extends Node3D
## Grandfather clock pendulum swing (1 second period).

func _process(_delta: float) -> void:
	rotation.z = sin(Time.get_ticks_msec() / 1000.0 * PI) * 0.12
