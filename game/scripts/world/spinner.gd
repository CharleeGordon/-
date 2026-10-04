extends Node3D
## Slowly rotates around Y (planetarium projector, toy train).

@export var speed := 0.2 # turns per... radians per second

func _process(delta: float) -> void:
	rotation.y += speed * delta
