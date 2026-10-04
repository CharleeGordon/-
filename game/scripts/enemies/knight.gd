extends EnemyBase
## Sir Clanksworth: an empty suit of armour. Moves only when nobody is looking.
## When you look back it freezes mid-stride - in a new, slightly more threatening pose.

const SEE_DISTANCE := 45.0

var active := false
var speed := 1.8 # night scripts raise it later in the night
var _moved_since_seen := 0.0
var _sting_cd := 0.0
var _was_seen := true


func _ready() -> void:
	super._ready()
	add_to_group("knight")
	step_sounds = [preload("res://audio/knight_step_1.wav"), preload("res://audio/knight_step_2.wav"), preload("res://audio/knight_step_3.wav")]
	rig.pose({"ShoulderR": Vector3(0.1, 0, 0.05), "ElbowR": Vector3(0.3, 0, 0), "ShoulderL": Vector3(0.2, 0, -0.1)})


func activate() -> void:
	active = true


func deactivate() -> void:
	active = false
	reset_home()


func _physics_process(delta: float) -> void:
	_sting_cd = maxf(_sting_cd - delta, 0.0)
	if not active or not Shift.running or not find_player() or not nav_ready():
		stand_still(delta)
		return
	var seen := is_seen()
	if seen:
		stand_still(delta) # frozen like a statue, pose kept
		if not _was_seen and _moved_since_seen > 1.5 and flat_distance_to_player() < 7.0 and _sting_cd <= 0.0:
			Music.sting("sting_knight", -2.0, 1.0)
			_sting_cd = 20.0
		_was_seen = true
		_moved_since_seen = 0.0
		_report_threat()
		return
	_was_seen = false
	var target: Vector3 = home if (player.is_safe() or player.is_hidden) else player.global_position
	var before := global_position
	var arrived := walk_towards(target, speed * Shift.speed_mult(), delta)
	_moved_since_seen += before.distance_to(global_position)
	if arrived and (player.is_safe() or player.is_hidden):
		face(home_yaw, delta)
	_report_threat()
	if is_touching_player():
		Shift.catch_player(self, "knight")


func _report_threat() -> void:
	var d := flat_distance_to_player()
	if d < 9.0 and not player.is_safe():
		Music.report_danger(clampf(1.0 - d / 9.0, 0.0, 1.0) + 0.3)


## Seen = on screen + not behind a wall + actually lit (room lights or the flashlight).
func is_seen() -> bool:
	if player.is_hidden:
		return false
	var cam: Camera3D = player.camera
	if cam.global_position.distance_to(global_position) > SEE_DISTANCE:
		return false
	for h in [0.4, 1.1, 1.75]:
		var p := global_position + Vector3(0, h, 0)
		if not cam.is_position_in_frustum(p):
			continue
		if not player.has_line_of_sight(p):
			continue
		if (Shift.power_on and player.room_lit()) or player.flashlight_hits(p, 1.15):
			return true
	return false
