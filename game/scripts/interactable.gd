class_name Interactable
extends Area3D
## Anything the player can use with [E]. The actual logic lives in game.gd,
## which receives `action_id` through Shift.interact_requested.

@export var action_id := ""
@export var prompt := "Use"
@export var active := true:
	set(value):
		active = value
		collision_layer = 8 if value else 0 # inactive = invisible to the use-ray


func interact(_player: Node) -> void:
	if active:
		Shift.interact_requested.emit(action_id, self)
