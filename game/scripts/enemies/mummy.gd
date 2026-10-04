extends EnemyBase
## The Pharaoh's Neighbour: sleeps in the Egyptian Hall. Running there (or loud noise) wakes it.

enum State { SLEEP, WAKING, CHASE, RETURN }

const CHASE_SPEED := 2.3
const RETURN_SPEED := 1.5
const GIVE_UP_DISTANCE := 22.0
const MAX_CHASE_TIME := 30.0

var enabled := true
var state := State.SLEEP
var _timer := 0.0
var _groan: AudioStreamPlayer3D
var _groan_timer := 0.0
var _groans: Array[AudioStream] = []


func _ready() -> void:
	super._ready()
	step_sounds = [preload("res://audio/mummy_shuffle.wav")]
	_groans = [preload("res://audio/mummy_groan_1.wav"), preload("res://audio/mummy_groan_2.wav"), preload("res://audio/mummy_groan_3.wav")]
	_groan = make_3d_sound(null, 9.0, 2.0)
	Shift.noise.connect(_on_noise)
	_sleep_pose()


func _sleep_pose() -> void:
	rig.pose({"ShoulderL": Vector3(0.3, 0, 0.6), "ShoulderR": Vector3(0.3, 0, -0.6), "ElbowL": Vector3(1.9, 0, 0), "ElbowR": Vector3(1.9, 0, 0), "Head": Vector3(0.25, 0, 0)})


func _on_noise(pos: Vector3, radius: float) -> void:
	if pos.distance_to(global_position) <= radius:
		wake("noise")


func wake(_reason: String = "") -> void:
	if not enabled or not Shift.running:
		return
	if state != State.SLEEP and state != State.RETURN:
		return
	state = State.WAKING
	_timer = 1.6
	_groan_once()
	Shift.say("*ancient, deeply offended groaning*", "THE MUMMY", 3.0)


func _groan_once() -> void:
	_groan.stream = _groans[randi() % _groans.size()]
	_groan.pitch_scale = randf_range(0.85, 1.05)
	_groan.play()


func put_to_sleep() -> void:
	state = State.SLEEP
	reset_home()
	_sleep_pose()


func _physics_process(delta: float) -> void:
	if not Shift.running or not find_player() or not nav_ready():
		stand_still(delta)
		return
	match state:
		State.SLEEP:
			stand_still(delta)
			if enabled and player.current_room == "egypt" and player.is_sprinting:
				wake("running")
		State.WAKING:
			stand_still(delta)
			rig.pose({"Head": Vector3(-0.2, sin(_timer * 6.0) * 0.3, 0), "ShoulderL": Vector3(1.3, 0, 0), "ShoulderR": Vector3(1.3, 0, 0)})
			_timer -= delta
			if _timer <= 0.0:
				state = State.CHASE
				_timer = MAX_CHASE_TIME
		State.CHASE:
			_timer -= delta
			var speed := (CHASE_SPEED + (0.4 if Shift.hour >= 5 else 0.0)) * Shift.speed_mult()
			if player.is_hidden:
				speed *= 0.6
			walk_towards(player.global_position, speed, delta)
			rig.walk(walk_phase, 0.8, 1.35, 0.4)
			_groan_timer -= delta
			if _groan_timer <= 0.0:
				_groan_timer = randf_range(3.0, 5.0)
				_groan_once()
			var too_far := global_position.distance_to(player.global_position) > GIVE_UP_DISTANCE
			if player.is_safe() or player.is_hidden or too_far or _timer <= 0.0:
				state = State.RETURN
			else:
				Music.report_chase()
				if is_touching_player():
					Shift.catch_player(self, "mummy")
		State.RETURN:
			if walk_towards(home, RETURN_SPEED, delta):
				state = State.SLEEP
				rotation.y = home_yaw
				_sleep_pose()
			else:
				rig.walk(walk_phase, 0.6, 1.2, 0.4)
				if enabled and player.current_room == "egypt" and player.is_sprinting:
					wake("running")
