extends Node3D
## A removable barrier (velvet rope across the grand staircase).

func open() -> void:
	visible = false
	var body := get_node_or_null("Body") as StaticBody3D
	if body:
		body.collision_layer = 0


func close() -> void:
	visible = true
	var body := get_node_or_null("Body") as StaticBody3D
	if body:
		body.collision_layer = 16


func is_open() -> bool:
	return not visible
