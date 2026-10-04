class_name EnemyBase
extends CharacterBody3D
## Shared movement for walking exhibits: follows the navigation mesh.

const GRAVITY := 20.0
const CATCH_DISTANCE := 1.25

@onready var agent: NavigationAgent3D = $Agent
var player = null # the Player node (scripts/player.gd)
var home: Vector3
var home_yaw := 0.0
var _repath := 0.0


func _ready() -> void:
	home = global_position
	home_yaw = rotation.y


func find_player() -> bool:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	return player != null


func nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) > 0


## Walks one physics step towards `target`. Returns true when arrived.
func walk_towards(target: Vector3, speed: float, delta: float) -> bool:
	_repath -= delta
	if _repath <= 0.0:
		_repath = 0.25
		agent.target_position = target
	if agent.is_navigation_finished():
		stand_still(delta)
		return true
	var next := agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0.0
	if dir.length() > 0.01:
		dir = dir.normalized()
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 8.0, 0.0, 1.0))
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_apply_gravity(delta)
	move_and_slide()
	return false


func stand_still(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_apply_gravity(delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta


func is_touching_player() -> bool:
	if player == null or player.is_safe():
		return false
	var a := Vector2(global_position.x, global_position.z)
	var b := Vector2(player.global_position.x, player.global_position.z)
	return a.distance_to(b) < CATCH_DISTANCE


func make_3d_sound(stream: AudioStream, unit_size: float = 6.0, volume_db: float = 0.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.unit_size = unit_size
	p.volume_db = volume_db
	p.position = Vector3(0, 1.5, 0)
	add_child(p)
	return p
