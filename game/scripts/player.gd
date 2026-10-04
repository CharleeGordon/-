extends CharacterBody3D
## First-person night guard: walk / sprint / crouch, flashlight with battery, interact, hide in lockers.

const WALK_SPEED := 3.0
const SPRINT_SPEED := 5.6
const CROUCH_SPEED := 1.5
const ACCEL := 10.0
const GRAVITY := 20.0
const BASE_SENSITIVITY := 0.0022
const STAMINA_DRAIN := 20.0
const STAMINA_REGEN := 13.0
const BATTERY_DRAIN := 0.3 # % per second -> ~5.5 minutes per full battery
const STAND_HEAD := 1.62
const CROUCH_HEAD := 1.0

const SURFACES := {
	"lobby": "marble", "office": "wood", "storage": "concrete", "gallery": "wood", "egypt": "stone",
	"vault": "stone", "dino": "stone", "wax": "carpet", "curio": "wood",
}

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var hand: Node3D = $Head/Camera/Hand
@onready var flashlight: SpotLight3D = $Head/Camera/Hand/Flashlight
@onready var ray: RayCast3D = $Head/Camera/InteractRay
@onready var collision: CollisionShape3D = $Collision
@onready var sfx: AudioStreamPlayer = $Sfx
@onready var steps: AudioStreamPlayer = $Steps
@onready var breath: AudioStreamPlayer = $Breath
@onready var heart: AudioStreamPlayer = $Heart

var has_flashlight := false
var flashlight_on := false
var battery := 100.0
var stamina := 100.0
var exhausted := false
var is_sprinting := false
var is_crouching := false
var is_moving := false
var is_hidden := false
var hide_spot: Node = null
var current_room := ""
var carrying := "" # "duck", "bulbs", "sword"... (shown on the HUD)
var carry_count := 0
var controls_locked := false
var focus: Interactable = null

var _rooms: Array[String] = []
var _step_timer := 0.0
var _bob_time := 0.0
var _shake := 0.0
var _flicker_timer := 0.0
var _base_light_energy := 0.0
var _sway := Vector2.ZERO
var _head_height := STAND_HEAD
var _step_streams := {}
var _hide_return := Transform3D()
var _heart_timer := 0.0


func _ready() -> void:
	add_to_group("player")
	_base_light_energy = flashlight.light_energy
	flashlight.visible = false
	hand.visible = false
	for part in ["Body", "Head", "Lens"]:
		(hand.get_node(part) as Node3D).rotation_degrees = Vector3(-90, 0, 0) # cylinder top points forward
	for s in ["marble", "wood", "stone", "carpet", "concrete"]:
		var arr: Array[AudioStream] = []
		for i in range(1, 5):
			arr.append(load("res://audio/step_%s_%d.wav" % [s, i]))
		_step_streams[s] = arr
	breath.stream = _looping(preload("res://audio/breathing.ogg"))
	heart.stream = preload("res://audio/heartbeat.wav")
	camera.fov = float(Save.settings["fov"])
	Save.settings_changed.connect(_on_settings)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_settings() -> void:
	camera.fov = float(Save.settings["fov"])


func _looping(s: AudioStream) -> AudioStream:
	if s is AudioStreamOggVorbis:
		var c: AudioStreamOggVorbis = s.duplicate()
		c.loop = true
		return c
	return s


# Mouse look uses _input (not _unhandled_input) so UI elements can never swallow it.
func _input(event: InputEvent) -> void:
	if controls_locked and not is_hidden:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := BASE_SENSITIVITY * float(Save.settings["mouse_sens"])
		var dy: float = event.relative.y * (-1.0 if bool(Save.settings["invert_y"]) else 1.0)
		if is_hidden:
			# Peek through the locker slats: limited look range.
			head.rotation.y = clampf(head.rotation.y - event.relative.x * sens, -0.6, 0.6)
			head.rotation.x = clampf(head.rotation.x - dy * sens, -0.4, 0.3)
			return
		rotate_y(-event.relative.x * sens)
		head.rotate_x(-dy * sens)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))
		_sway += event.relative * 0.0004


func _unhandled_input(event: InputEvent) -> void:
	if is_hidden:
		if event.is_action_pressed("interact") or event.is_action_pressed("interact_mouse"):
			exit_hide()
		return
	if controls_locked:
		return
	if event.is_action_pressed("flashlight"):
		toggle_flashlight()
	elif event.is_action_pressed("interact") or event.is_action_pressed("interact_mouse"):
		if focus and focus.active:
			focus.interact(self)


func _physics_process(delta: float) -> void:
	if is_hidden:
		_update_flashlight(delta)
		_update_threat_audio(delta)
		_regen_stamina(delta)
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	var input := Vector2.ZERO
	if not controls_locked:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	is_moving = input.length() > 0.1

	var want_crouch := Input.is_action_pressed("crouch") and not controls_locked
	if not want_crouch and is_crouching and _ceiling_blocked():
		want_crouch = true
	is_crouching = want_crouch

	var wants_sprint := Input.is_action_pressed("sprint") and is_moving and input.y < 0.3 and not controls_locked and not is_crouching
	is_sprinting = wants_sprint and not exhausted and stamina > 0.0
	if is_sprinting:
		stamina = maxf(stamina - STAMINA_DRAIN * delta, 0.0)
		if stamina <= 0.0:
			exhausted = true
	else:
		_regen_stamina(delta)

	var speed := CROUCH_SPEED if is_crouching else (SPRINT_SPEED if is_sprinting else WALK_SPEED)
	if carrying == "duck":
		speed *= 0.92
	var target := wish * speed
	var a := clampf(ACCEL * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, target.x, a)
	velocity.z = lerpf(velocity.z, target.z, a)
	move_and_slide()

	_update_footsteps(delta)
	_update_camera_fx(delta)
	_update_flashlight(delta)
	_update_focus()
	_update_threat_audio(delta)


func _regen_stamina(delta: float) -> void:
	stamina = minf(stamina + STAMINA_REGEN * delta, 100.0)
	if exhausted and stamina > 35.0:
		exhausted = false


func _ceiling_blocked() -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0, global_position + Vector3.UP * 1.85, 1 | 16)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## How far away enemies can hear you right now (0 = silent).
func noise_radius() -> float:
	if is_hidden or not is_moving:
		return 0.0
	if is_sprinting:
		return 14.0
	if is_crouching:
		return 1.5
	return 5.5


func _update_footsteps(delta: float) -> void:
	var horizontal := Vector2(velocity.x, velocity.z).length()
	if horizontal < 0.4 or not is_on_floor():
		_step_timer = 0.0
		return
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = 0.31 if is_sprinting else (0.7 if is_crouching else 0.5)
		var surface: String = SURFACES.get(current_room, "stone")
		var arr: Array = _step_streams[surface]
		steps.stream = arr[randi() % arr.size()]
		steps.pitch_scale = randf_range(0.9, 1.1)
		steps.volume_db = -3.0 if is_sprinting else (-18.0 if is_crouching else -9.0)
		steps.play()


func _update_camera_fx(delta: float) -> void:
	var horizontal := Vector2(velocity.x, velocity.z).length()
	if horizontal > 0.4:
		_bob_time += delta * horizontal * 2.2
	var bob_amt := 0.035 if bool(Save.settings["head_bob"]) else 0.0
	var bob := sin(_bob_time) * bob_amt * clampf(horizontal / WALK_SPEED, 0.0, 1.5)
	_head_height = lerpf(_head_height, CROUCH_HEAD if is_crouching else STAND_HEAD, clampf(delta * 10.0, 0.0, 1.0))
	head.position.y = _head_height + bob
	(collision.shape as CapsuleShape3D).height = 1.2 if is_crouching else 1.8
	collision.position.y = 0.6 if is_crouching else 0.9
	# Hand sway + bob
	_sway = _sway.lerp(Vector2.ZERO, clampf(delta * 6.0, 0.0, 1.0))
	hand.position = Vector3(0.26 - _sway.x * 0.5 + cos(_bob_time * 0.5) * bob_amt * 0.4, -0.26 + _sway.y * 0.5 - absf(bob) * 0.5, -0.5)
	hand.rotation = Vector3(_sway.y * 1.5 + 0.06, -_sway.x * 1.5 + 0.16, 0)
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 1.5, 0.0)
		camera.h_offset = randf_range(-1, 1) * 0.07 * _shake
		camera.v_offset = randf_range(-1, 1) * 0.07 * _shake
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
	if battery < 15.0:
		_flicker_timer -= delta
		if _flicker_timer <= 0.0:
			_flicker_timer = randf_range(0.05, 0.6)
			flashlight.light_energy = _base_light_energy * (0.1 if randf() < 0.35 else 0.7)
	else:
		flashlight.light_energy = _base_light_energy


func _update_focus() -> void:
	var new_focus: Interactable = null
	if not controls_locked and ray.is_colliding():
		var hit := ray.get_collider()
		if hit is Interactable and hit.active:
			new_focus = hit
	focus = new_focus


func _update_threat_audio(delta: float) -> void:
	# Heartbeat speeds up with danger; breathing when out of breath or terrified.
	var t := Music.threat
	if t > 0.2:
		_heart_timer -= delta
		if _heart_timer <= 0.0:
			_heart_timer = lerpf(0.95, 0.45, t)
			heart.volume_db = lerpf(-14.0, -2.0, t)
			heart.play()
	var want_breath := stamina < 40.0 or t > 0.7
	if want_breath and not breath.playing:
		breath.volume_db = -8.0
		breath.play()
	elif not want_breath and breath.playing:
		breath.volume_db -= delta * 20.0
		if breath.volume_db < -30.0:
			breath.stop()


func toggle_flashlight() -> void:
	if not has_flashlight:
		Shift.alert.emit("You don't have a flashlight yet. (It's on the desk in the Security Office.)")
		return
	set_flashlight(not flashlight_on)


func set_flashlight(on: bool) -> void:
	if on and battery <= 0.0:
		Shift.alert.emit("Battery is dead.")
		on = false
	flashlight_on = on
	flashlight.visible = on
	sfx.stream = preload("res://audio/flashlight_on.wav") if on else preload("res://audio/flashlight_off.wav")
	sfx.volume_db = -4.0
	sfx.play()


func give_flashlight() -> void:
	has_flashlight = true
	hand.visible = true


func add_battery(amount: float) -> void:
	battery = minf(battery + amount, 100.0)
	play_sfx(preload("res://audio/battery.wav"), -4.0)


func refill_stamina() -> void:
	stamina = 100.0
	exhausted = false


func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	sfx.stream = stream
	sfx.volume_db = volume_db
	sfx.play()


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
	if rad_to_deg(forward.angle_to(to_point)) > flashlight.spot_angle * cone_factor:
		return false
	return has_line_of_sight(point)


func has_line_of_sight(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, point, 1 | 16)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Are the lights on where the player is? (blackouts and "budget cuts" make rooms dark)
func room_lit() -> bool:
	if not Shift.power_on:
		return false
	var dark: Array = Shift.flags.get("dark_rooms", [])
	return not dark.has(current_room)


func is_safe() -> bool:
	return current_room == "office" and not is_hidden


func enter_room(id: String) -> void:
	_rooms.erase(id)
	_rooms.append(id)
	current_room = id
	Music.set_safe(id == "office")


func exit_room(id: String) -> void:
	_rooms.erase(id)
	if not _rooms.is_empty():
		current_room = _rooms.back()
	Music.set_safe(current_room == "office")


# --- Hiding --------------------------------------------------------------

func enter_hide(spot: Node3D, view: Node3D) -> void:
	if is_hidden:
		return
	is_hidden = true
	hide_spot = spot
	controls_locked = true
	focus = null
	velocity = Vector3.ZERO
	_hide_return = global_transform
	collision.disabled = true
	global_position = Vector3(view.global_position.x, view.global_position.y - STAND_HEAD, view.global_position.z)
	rotation.y = view.global_rotation.y
	head.rotation = Vector3.ZERO
	if flashlight_on:
		set_flashlight(false)
	play_sfx(preload("res://audio/locker_open.wav"), -6.0)
	Music.set_muffled("SFX", true)
	for g in get_tree().get_nodes_in_group("guards"):
		g.notice_hiding(spot)


func exit_hide() -> void:
	if not is_hidden:
		return
	is_hidden = false
	hide_spot = null
	controls_locked = false
	global_transform = _hide_return
	head.rotation = Vector3.ZERO
	collision.disabled = false
	play_sfx(preload("res://audio/locker_close.wav"), -6.0)
	Music.set_muffled("SFX", false)


## Used for the jumpscare: freeze controls and snap the view to `point`.
func lock_and_look_at(point: Vector3) -> void:
	if is_hidden:
		exit_hide()
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
	shake(1.4)
