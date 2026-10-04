extends Area3D
## Tells the player which room they are in ("office" is the safe zone).

@export var room_id := ""
@export var level := 0


func _ready() -> void:
	body_entered.connect(func(body: Node3D) -> void:
		if body.has_method("enter_room"):
			body.enter_room(room_id, level))
	body_exited.connect(func(body: Node3D) -> void:
		if body.has_method("exit_room"):
			body.exit_room(room_id))
