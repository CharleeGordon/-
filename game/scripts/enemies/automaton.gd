extends EnemyBase
## Little Wolfgang, clockwork automaton (1784). Keep him wound up.
## The spring runs down; his tune slows and detunes. At zero he leaves the booth and hunts by sound.

enum State { BOOTH, HUNT, RETURN }

const BOOTH_EXIT := Vector3(12, 0, 19.2)
const HUNT_TIME := 25.0

var enabled := false
var spring := 100.0
var drain := 1.2 # per second (~83 s from full)
var state := State.BOOTH
var _timer := 0.0
var _target := Vector3.ZERO
var _tune: AudioStreamPlayer3D
var _fx: AudioStreamPlayer3D
var _booth_pos := Vector3.ZERO
var _key: Node3D


var _stun := 0.0


func stun(t: float) -> void:
	_stun = t


func _ready() -> void:
	super._ready()
	add_to_group("stunnable")
	_booth_pos = global_position
	step_sounds = [preload("res://audio/automaton_step_1.wav"), preload("res://audio/automaton_step_2.wav")]
	_tune = make_3d_sound(null, 5.0, -2.0)
	var tune: AudioStreamOggVorbis = preload("res://audio/music/automaton_tune.ogg").duplicate()
	tune.loop = true
	_tune.stream = tune
	_fx = make_3d_sound(null, 8.0, 0.0)
	_key = $Model.find_child("WindKey", true, false)
	Shift.noise.connect(_on_noise)
	_booth_pose()


func _booth_pose() -> void:
	rig.pose({"ShoulderL": Vector3(0.6, 0, -0.3), "ShoulderR": Vector3(0.6, 0, 0.3), "ElbowL": Vector3(0.9, 0, 0), "ElbowR": Vector3(0.9, 0, 0)})


func set_enabled(on: bool) -> void:
	enabled = on
	if on and state == State.BOOTH and not _tune.playing:
		_tune.play()
	elif not on:
		_tune.stop()


func wind() -> void:
	spring = 100.0
	_fx.stream = preload("res://audio/wind_ratchet.wav")
	_fx.play()
	if state == State.BOOTH and enabled and not _tune.playing:
		_tune.play()


func _on_noise(pos: Vector3, radius: float) -> void:
	if state == State.HUNT and pos.distance_to(global_position) <= radius:
		_target = pos


func _physics_process(delta: float) -> void:
	if not enabled or not Shift.running or not find_player() or not nav_ready():
		if state == State.BOOTH:
			stand_still(delta)
		return
	match state:
		State.BOOTH:
			spring = maxf(spring - drain * delta, 0.0)
			_tune.pitch_scale = lerpf(0.55, 1.0, clampf(spring / 40.0, 0.0, 1.0))
			if _key:
				_key.rotation.z += delta * spring * 0.03
			var head_turn := sin(Time.get_ticks_msec() / 700.0) * 0.4 * (spring / 100.0)
			rig.look(head_turn, 0.0)
			if spring <= 0.0:
				_unwind()
		State.HUNT:
			_timer -= delta
			if _stun > 0.0:
				_stun -= delta
				stand_still(delta)
				return
			if flat_distance_to_player() < 12.0 and can_see_point(player.camera.global_position, 1.1) and not player.is_hidden:
				_target = player.global_position
			if player.noise_radius() > 0.0 and global_position.distance_to(player.global_position) < player.noise_radius() * 1.2:
				_target = player.global_position
			walk_towards(_target, 3.3 * Shift.speed_mult(), delta)
			if flat_distance_to_player() < 14.0:
				Music.report_chase()
			if is_touching_player():
				Shift.catch_player(self, "automaton")
			if _timer <= 0.0 or player.is_safe():
				state = State.RETURN
		State.RETURN:
			if walk_towards(BOOTH_EXIT, 2.0, delta):
				global_position = _booth_pos
				rotation.y = home_yaw
				state = State.BOOTH
				spring = 35.0
				_booth_pose()
				_tune.play()


func _unwind() -> void:
	state = State.HUNT
	_timer = HUNT_TIME
	_tune.stop()
	_fx.stream = preload("res://audio/automaton_unwound.wav")
	_fx.play()
	global_position = BOOTH_EXIT
	_target = player.global_position
	Shift.say("*the music stops*", "", 2.5)
	Shift.alert.emit("Little Wolfgang has run down. Hide!")


func is_hunting() -> bool:
	return state == State.HUNT
