extends CharacterBody3D
## First-person night guard: walk, sprint (stamina), flashlight (battery), interact.

const WALK_SPEED := 3.2
const SPRINT_SPEED := 5.8
const ACCEL := 10.0
const GRAVITY := 20.0
const MOUSE_SENSITIVITY := 0.0022
const STAMINA_DRAIN := 22.0 # per second while sprinting
const STAMINA_REGEN := 14.0
const BATTERY_DRAIN := 0.33 # percent per second -> about 5 minutes per full battery

const SND_STEP := preload("res://audio/footstep.wav")
const SND_CLICK := preload("res://audio/click.wav")

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var flashlight: SpotLight3D = $Head/Camera/Flashlight
@onready var ray: RayCast3D = $Head/Camera/InteractRay
@onready var sfx: AudioStreamPlayer = $Sfx
@onready var steps: AudioStreamPlayer = $Steps

var has_flashlight := false
var flashlight_on := false
var battery := 100.0
var stamina := 100.0
var exhausted := false
var is_sprinting := false
var is_moving := false
var current_room := ""
var carrying_duck := false
var controls_locked := false
var focus: Interactable = null

var _rooms: Array[String] = []
var _step_timer := 0.0
var _bob_time := 0.0
var _shake := 0.0
var _flicker_timer := 0.0
var _base_light_energy := 0.0


func _ready() -> void:
	add_to_group("player")
	_base_light_energy = flashlight.light_energy
	flashlight.visible = false
	steps.stream = SND_STEP
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if controls_locked:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))
	elif event.is_action_pressed("flashlight"):
		toggle_flashlight()
	elif event.is_action_pressed("interact"):
		if focus and focus.active:
			focus.interact(self)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	var input := Vector2.ZERO
	if not controls_locked:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	is_moving = input.length() > 0.1

	# Sprint + stamina
	var wants_sprint := Input.is_action_pressed("sprint") and is_moving and input.y < 0.3 and not controls_locked
	is_sprinting = wants_sprint and not exhausted and stamina > 0.0
	if is_sprinting:
		stamina = maxf(stamina - STAMINA_DRAIN * delta, 0.0)
		if stamina <= 0.0:
			exhausted = true
	else:
		stamina = minf(stamina + STAMINA_REGEN * delta, 100.0)
		if exhausted and stamina > 35.0:
			exhausted = false

	var speed := SPRINT_SPEED if is_sprinting else WALK_SPEED
	var target := wish * speed
	velocity.x = lerpf(velocity.x, target.x, clampf(ACCEL * delta, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, target.z, clampf(ACCEL * delta, 0.0, 1.0))
	move_and_slide()

	_update_footsteps(delta)
	_update_camera_fx(delta)
	_update_flashlight(delta)
	_update_focus()


func _update_footsteps(delta: float) -> void:
	var horizontal := Vector2(velocity.x, velocity.z).length()
	if horizontal < 0.5 or not is_on_floor():
		_step_timer = 0.0
		return
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = 0.32 if is_sprinting else 0.52
		steps.pitch_scale = randf_range(0.85, 1.15)
		steps.volume_db = -4.0 if is_sprinting else -10.0
		steps.play()


func _update_camera_fx(delta: float) -> void:
	var horizontal := Vector2(velocity.x, velocity.z).length()
	if horizontal > 0.5:
		_bob_time += delta * horizontal * 2.2
	var bob := sin(_bob_time) * 0.03 * clampf(horizontal / WALK_SPEED, 0.0, 1.5)
	head.position.y = 1.6 + bob
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 1.5, 0.0)
		camera.h_offset = randf_range(-1, 1) * 0.08 * _shake
		camera.v_offset = randf_range(-1, 1) * 0.08 * _shake
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


func _update_flashlight(delta: float) -> void:
	if not flashlight_on:
		return
	battery = maxf(battery - BATTERY_DRAIN * delta, 0.0)
	if battery <= 0.0:
		set_flashlight(false)
		Shift.alert.emit("Flashlight battery is dead. Find batteries!")
		return
	# Low battery flicker
	if battery < 15.0:
		_flicker_timer -= delta
		if _flicker_timer <= 0.0:
			_flicker_timer = randf_range(0.05, 0.6)
			flashlight.light_energy = _base_light_energy * (0.15 if randf() < 0.35 else 0.7)
	else:
		flashlight.light_energy = _base_light_energy


func _update_focus() -> void:
	var new_focus: Interactable = null
	if not controls_locked and ray.is_colliding():
		var hit := ray.get_collider()
		if hit is Interactable and hit.active:
			new_focus = hit
	focus = new_focus


func toggle_flashlight() -> void:
	if not has_flashlight:
		Shift.alert.emit("You don't have a flashlight yet. (It's in the Security Office.)")
		return
	set_flashlight(not flashlight_on)


func set_flashlight(on: bool) -> void:
	if on and battery <= 0.0:
		Shift.alert.emit("Battery is dead.")
		on = false
	flashlight_on = on
	flashlight.visible = on
	sfx.stream = SND_CLICK
	sfx.play()


func add_battery(amount: float) -> void:
	battery = minf(battery + amount, 100.0)


func refill_stamina() -> void:
	stamina = 100.0
	exhausted = false


func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


## True if the flashlight beam actually hits `point` (cone + range + line of sight).
func flashlight_hits(point: Vector3, cone_factor: float = 1.0) -> bool:
	if not flashlight_on:
		return false
	var origin := camera.global_position
	var to_point := point - origin
	var dist := to_point.length()
	if dist > flashlight.spot_range:
		return false
	var forward := -camera.global_transform.basis.z
	var angle := rad_to_deg(forward.angle_to(to_point))
	if angle > flashlight.spot_angle * cone_factor:
		return false
	return has_line_of_sight(point)


func has_line_of_sight(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, point, 1)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return result.is_empty()


func is_safe() -> bool:
	return current_room == "office"


func enter_room(id: String) -> void:
	_rooms.erase(id)
	_rooms.append(id)
	current_room = id


func exit_room(id: String) -> void:
	_rooms.erase(id)
	current_room = _rooms.back() if not _rooms.is_empty() else ""


## Used for the jumpscare: freeze controls and snap the view to `point`.
func lock_and_look_at(point: Vector3) -> void:
	controls_locked = true
	focus = null
	velocity = Vector3.ZERO
	var tween := create_tween().set_parallel()
	var flat := Vector3(point.x, global_position.y, point.z)
	if flat.distance_to(global_position) > 0.05:
		var yaw := atan2(-(flat - global_position).x, -(flat - global_position).z)
		tween.tween_property(self, "rotation:y", rotation.y + wrapf(yaw - rotation.y, -PI, PI), 0.12)
	var cam_pos := camera.global_position
	var pitch := atan2(point.y - cam_pos.y, Vector2(point.x - cam_pos.x, point.z - cam_pos.z).length())
	tween.tween_property(head, "rotation:x", pitch, 0.12)
	shake(1.2)
