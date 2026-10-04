class_name EnemyBase
extends CharacterBody3D
## Shared code for walking exhibits: navigation, rig animation, footsteps, catching.

const GRAVITY := 20.0
const CATCH_DISTANCE := 1.2

var agent: NavigationAgent3D
var rig: Rig
var player = null # scripts/player.gd
var home: Vector3
var home_yaw := 0.0
var walk_phase := 0.0
var step_sounds: Array[AudioStream] = []
var _step_player: AudioStreamPlayer3D
var _repath := 0.0
var _last_step_side := 0.0


func _ready() -> void:
	agent = $Agent
	rig = Rig.new($Model)
	home = global_position
	home_yaw = rotation.y
	_step_player = make_3d_sound(null, 6.0, -4.0)
	_step_player.position = Vector3(0, 0.1, 0)


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
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 7.0, 0.0, 1.0))
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_apply_gravity(delta)
	move_and_slide()
	animate_walk(speed, delta)
	return false


func animate_walk(speed: float, delta: float, arms: float = 0.0) -> void:
	var stride := 2.2 if speed < 2.5 else 2.8
	walk_phase += delta * speed / stride * TAU * 0.5
	rig.walk(walk_phase, clampf(speed / 2.0, 0.3, 1.0), arms)
	var side := signf(sin(walk_phase))
	if side != _last_step_side:
		_last_step_side = side
		play_step()


func play_step() -> void:
	if step_sounds.is_empty():
		return
	_step_player.stream = step_sounds[randi() % step_sounds.size()]
	_step_player.pitch_scale = randf_range(0.9, 1.1)
	_step_player.play()


func stand_still(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_apply_gravity(delta)
	move_and_slide()


func face(yaw: float, delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * 4.0, 0.0, 1.0))


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta


func flat_distance_to_player() -> float:
	var a := Vector2(global_position.x, global_position.z)
	var b := Vector2(player.global_position.x, player.global_position.z)
	return a.distance_to(b)


func is_touching_player() -> bool:
	if player == null or player.is_safe() or player.is_hidden:
		return false
	return flat_distance_to_player() < CATCH_DISTANCE


## Line of sight from this enemy's eyes to the player's head (walls block it).
func can_see_point(point: Vector3, eye_height: float = 1.6) -> bool:
	var from := global_position + Vector3(0, eye_height, 0)
	var q := PhysicsRayQueryParameters3D.create(from, point, 1 | 16)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func make_3d_sound(stream: AudioStream, unit_size: float = 6.0, volume_db: float = 0.0) -> AudioStreamPlayer3D:
	var s := AudioStreamPlayer3D.new()
	s.stream = stream
	s.unit_size = unit_size
	s.volume_db = volume_db
	s.bus = "SFX"
	s.position = Vector3(0, 1.5, 0)
	add_child(s)
	return s


func reset_home() -> void:
	global_position = home
	rotation.y = home_yaw
	velocity = Vector3.ZERO
