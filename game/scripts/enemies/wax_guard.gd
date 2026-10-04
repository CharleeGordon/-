extends EnemyBase
## Gary, the previous night guard, now a wax figure who still does his rounds.
## Patrols with a flashlight and whistles. If his beam finds you he chases you. Hide or break line of sight.

enum State { IDLE, PATROL, INVESTIGATE, ALERT, CHASE, SEARCH }

const VIEW_DISTANCE := 13.0
const VIEW_ANGLE := 28.0

var enabled := false
var state := State.IDLE
var walk_speed := 1.6
var chase_speed := 3.7
var _points: Array[Vector3] = []
var _idx := 0
var _timer := 0.0
var _target := Vector3.ZERO
var _lost := 0.0
var _whistle: AudioStreamPlayer3D
var _voice: AudioStreamPlayer3D
var _beam: SpotLight3D
var _saw_hide_spot: Node = null


func _ready() -> void:
	super._ready()
	add_to_group("guards")
	add_to_group("stunnable")
	step_sounds = [preload("res://audio/boot_step_1.wav"), preload("res://audio/boot_step_2.wav"), preload("res://audio/boot_step_3.wav")]
	_whistle = make_3d_sound(null, 7.0, -3.0)
	var w: AudioStreamOggVorbis = preload("res://audio/music/gary_whistle.ogg").duplicate()
	w.loop = true
	_whistle.stream = w
	_voice = make_3d_sound(null, 10.0, 2.0)
	_beam = $Model.find_child("Beam", true, false)
	var pts := get_parent().get_node_or_null("PatrolPoints")
	if pts:
		for m in pts.get_children():
			_points.append(m.global_position)
	Shift.noise.connect(_on_noise)
	_set_beam(false)


var _stun := 0.0


func stun(t: float) -> void:
	_stun = t
	if state == State.CHASE or state == State.ALERT:
		state = State.SEARCH
		_timer = t + 2.0
	_gary_say("ARGH! My eyes! My... wax eyes!", preload("res://audio/babble_gary_2.wav"))


func set_enabled(on: bool) -> void:
	enabled = on
	_set_beam(on)
	if on:
		state = State.PATROL
		_whistle.play()
	else:
		state = State.IDLE
		_whistle.stop()
		reset_home()


func _set_beam(on: bool) -> void:
	if _beam:
		_beam.visible = on


func _on_noise(pos: Vector3, radius: float) -> void:
	if enabled and (state == State.PATROL or state == State.SEARCH) and pos.distance_to(global_position) <= radius:
		state = State.INVESTIGATE
		_target = pos
		_timer = 8.0


func _physics_process(delta: float) -> void:
	_stun = maxf(_stun - delta, 0.0)
	if not enabled or not Shift.running or not find_player() or not nav_ready() or _points.is_empty() or _stun > 0.0:
		stand_still(delta)
		return
	var sees := _sees_player()
	match state:
		State.PATROL:
			rig.rot("ShoulderR", 1.2, 0, 0.1)
			if walk_towards(_points[_idx], walk_speed * Shift.speed_mult(), delta):
				_idx = (_idx + 1) % _points.size()
			_hear_footsteps()
			if sees:
				_alert()
		State.INVESTIGATE:
			_timer -= delta
			if walk_towards(_target, walk_speed * 1.3 * Shift.speed_mult(), delta) or _timer <= 0.0:
				state = State.SEARCH
				_timer = 5.0
			if sees:
				_alert()
		State.ALERT:
			stand_still(delta)
			look_at_flat(player.global_position)
			_timer -= delta
			if _timer <= 0.0:
				state = State.CHASE
				_lost = 0.0
		State.CHASE:
			Music.report_chase()
			if sees:
				_target = player.global_position
				_lost = 0.0
			else:
				_lost += delta
			if player.is_hidden:
				if _saw_hide_spot != null and player.hide_spot == _saw_hide_spot:
					_target = player.global_position
					if flat_distance_to_player() < 1.6:
						Shift.catch_player(self, "guard")
						return
				else:
					_lost += delta * 2.0
			walk_towards(_target, chase_speed * Shift.speed_mult(), delta)
			rig.walk(walk_phase, 1.0, 1.0)
			if is_touching_player():
				Shift.catch_player(self, "guard")
			if _lost > 6.0 or player.is_safe():
				state = State.SEARCH
				_timer = 6.0
				_saw_hide_spot = null
				_whistle.play()
		State.SEARCH:
			_timer -= delta
			stand_still(delta)
			rotation.y += delta * 0.9
			if sees:
				_alert()
			elif _timer <= 0.0:
				state = State.PATROL
				_idx = _nearest_point()
	if state == State.PATROL and flat_distance_to_player() < 10.0 and not player.is_safe():
		Music.report_danger(0.5)


## Called by the player when they hide - if Gary is chasing and close enough to see it, he knows.
func notice_hiding(spot: Node) -> void:
	if state == State.CHASE and flat_distance_to_player() < 6.0 and can_see_point(player.camera.global_position):
		_saw_hide_spot = spot


func _alert() -> void:
	state = State.ALERT
	_timer = 0.7
	_whistle.stop()
	_gary_say(["HEY! Museum's closed, pal!", "Sir? Sir! The museum is CLOSED!", "Hold it right there! I'm... I'm security!"][randi() % 3],
		[preload("res://audio/babble_gary_1.wav"), preload("res://audio/babble_gary_2.wav"), preload("res://audio/babble_gary_3.wav")][randi() % 3])


func _gary_say(text: String, fallback: AudioStream) -> void:
	var v := Shift.voice_line(text)
	_voice.stream = v if v else fallback
	_voice.play()
	Shift.say(text, "GARY", 2.5)


func _hear_footsteps() -> void:
	var r: float = player.noise_radius()
	if r > 0.0 and global_position.distance_to(player.global_position) < r:
		state = State.INVESTIGATE
		_target = player.global_position
		_timer = 8.0


func _sees_player() -> bool:
	if player.is_hidden or player.is_safe():
		return false
	var head: Vector3 = player.camera.global_position
	var to_p := head - (global_position + Vector3(0, 1.6, 0))
	var dist := to_p.length()
	var fwd := -global_transform.basis.z
	var angle := rad_to_deg(fwd.angle_to(Vector3(to_p.x, 0, to_p.z)))
	var in_beam := dist < VIEW_DISTANCE and angle < VIEW_ANGLE
	var close := dist < 2.5 and angle < 80.0
	var sees_light: bool = player.flashlight_on and dist < 18.0 and angle < 70.0
	if not (in_beam or close or sees_light):
		return false
	return can_see_point(head)


func look_at_flat(p: Vector3) -> void:
	var d := p - global_position
	rotation.y = atan2(-d.x, -d.z)


func _nearest_point() -> int:
	var best := 0
	var bd := INF
	for i in _points.size():
		var d := _points[i].distance_to(global_position)
		if d < bd:
			bd = d
			best = i
	return best
