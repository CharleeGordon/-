extends EnemyBase
## The Pharaoh's Neighbour: sleeps in the Egyptian Hall. Running there (or loud noise) wakes it.

enum State { SLEEP, WAKING, CHASE, RETURN }

const CHASE_SPEED := 2.3
const RETURN_SPEED := 1.6
const GIVE_UP_DISTANCE := 20.0
const MAX_CHASE_TIME := 30.0

var state := State.SLEEP
var _timer := 0.0
var _groan: AudioStreamPlayer3D
var _groan_timer := 0.0


func _ready() -> void:
	super._ready()
	_groan = make_3d_sound(preload("res://audio/groan.wav"), 8.0, 0.0)
	Shift.noise.connect(func(_pos: Vector3) -> void: wake("noise"))


func wake(_reason: String = "") -> void:
	if state != State.SLEEP and state != State.RETURN:
		return
	if not Shift.running:
		return
	state = State.WAKING
	_timer = 1.6
	_groan.play()
	Shift.say("*ancient, deeply offended groaning*", "THE MUMMY", 3.0)


func _physics_process(delta: float) -> void:
	if not Shift.running or not find_player() or not nav_ready():
		stand_still(delta)
		return

	match state:
		State.SLEEP:
			stand_still(delta)
			if player.current_room == "egypt" and player.is_sprinting:
				wake("running")
		State.WAKING:
			stand_still(delta)
			_timer -= delta
			if _timer <= 0.0:
				state = State.CHASE
				_timer = MAX_CHASE_TIME
		State.CHASE:
			_timer -= delta
			var speed := CHASE_SPEED + (0.4 if Shift.hour >= 5 else 0.0)
			walk_towards(player.global_position, speed, delta)
			_groan_timer -= delta
			if _groan_timer <= 0.0:
				_groan_timer = randf_range(3.0, 5.0)
				_groan.play()
			var too_far := global_position.distance_to(player.global_position) > GIVE_UP_DISTANCE
			if player.is_safe() or too_far or _timer <= 0.0:
				state = State.RETURN
			elif is_touching_player():
				Shift.catch_player(self, "mummy")
		State.RETURN:
			if walk_towards(home, RETURN_SPEED, delta):
				state = State.SLEEP
				rotation.y = home_yaw
			elif player.current_room == "egypt" and player.is_sprinting:
				wake("running")
