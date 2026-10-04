extends EnemyBase
## One of the five Tea Party dolls. Like the knight, they only move when nobody is looking -
## but there are five of them, they are fast, and they never leave the Toy Room.

var active := false
var speed := 1.8
var _stun := 0.0
var _giggle: AudioStreamPlayer3D
var _giggle_t := 0.0


func _ready() -> void:
	super._ready()
	add_to_group("stunnable")
	step_sounds = [preload("res://audio/automaton_step_1.wav"), preload("res://audio/automaton_step_2.wav")]
	_giggle = make_3d_sound(null, 5.0, -4.0)
	_giggle.position = Vector3(0, 0.7, 0)
	rig.pose({"ShoulderL": Vector3(0.9, 0, -0.2), "ShoulderR": Vector3(0.9, 0, 0.2), "ElbowL": Vector3(0.6, 0, 0), "ElbowR": Vector3(0.6, 0, 0)})


func stun(t: float) -> void:
	_stun = t


func _physics_process(delta: float) -> void:
	_stun = maxf(_stun - delta, 0.0)
	if not active or not Shift.running or not find_player() or not nav_ready() or _stun > 0.0:
		stand_still(delta)
		return
	var in_room: bool = player.current_room == "toyroom" and not player.is_hidden
	if is_seen():
		stand_still(delta)
		# Heads always turn to face you
		var d: Vector3 = player.global_position - global_position
		rig.look(wrapf(atan2(-d.x, -d.z) - rotation.y, -PI, PI) * 0.8, 0.0)
		return
	var target: Vector3 = player.global_position if in_room else home
	var arrived := walk_towards(target, speed * Shift.speed_mult(), delta)
	if arrived and not in_room:
		face(home_yaw, delta)
	_giggle_t -= delta
	if not arrived and _giggle_t <= 0.0:
		_giggle_t = randf_range(3.0, 7.0)
		_giggle.stream = preload("res://audio/doll_giggle.wav")
		_giggle.pitch_scale = randf_range(0.9, 1.25)
		_giggle.play()
	if in_room and flat_distance_to_player() < 6.0:
		Music.report_danger(0.8)
	if in_room and is_touching_player():
		Shift.catch_player(self, "dolls")


func is_seen() -> bool:
	if player.is_hidden:
		return false
	var cam: Camera3D = player.camera
	if cam.global_position.distance_to(global_position) > 25.0:
		return false
	for h in [0.3, 0.6, 0.85]:
		var p := global_position + Vector3(0, h, 0)
		if cam.is_position_in_frustum(p) and player.has_line_of_sight(p) and ((Shift.power_on and player.room_lit()) or player.flashlight_hits(p, 1.15)):
			return true
	return false
