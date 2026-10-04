extends EnemyBase
## Sir Clanksworth: an empty suit of armor. Moves only when nobody is looking.

const SEE_DISTANCE := 40.0

var active := false
var speed := 1.8 # 4 AM: game.gd raises it
var _clank: AudioStreamPlayer3D
var _clank_timer := 0.0


func _ready() -> void:
	super._ready()
	_clank = make_3d_sound(preload("res://audio/clank.wav"), 7.0, -2.0)


func activate() -> void:
	active = true


func _physics_process(delta: float) -> void:
	if not active or not Shift.running or not find_player() or not nav_ready():
		stand_still(delta)
		return
	if is_seen():
		stand_still(delta) # frozen like a statue
		return

	var target: Vector3 = home if player.is_safe() else player.global_position
	var arrived := walk_towards(target, speed, delta)
	if not arrived:
		_clank_timer -= delta
		if _clank_timer <= 0.0:
			_clank_timer = 0.55
			_clank.pitch_scale = randf_range(0.9, 1.1)
			_clank.play()
	elif player.is_safe():
		rotation.y = lerp_angle(rotation.y, home_yaw, clampf(delta * 4.0, 0.0, 1.0))

	if is_touching_player():
		Shift.catch_player(self, "knight")


## Seen = on screen + not behind a wall + actually lit (room lights or the flashlight).
func is_seen() -> bool:
	var cam: Camera3D = player.camera
	if cam.global_position.distance_to(global_position) > SEE_DISTANCE:
		return false
	var points := [global_position + Vector3(0, 0.4, 0), global_position + Vector3(0, 1.1, 0), global_position + Vector3(0, 1.75, 0)]
	for p in points:
		if not cam.is_position_in_frustum(p):
			continue
		if not player.has_line_of_sight(p):
			continue
		if Shift.power_on or player.flashlight_hits(p, 1.15):
			return true
	return false
