extends EnemyBase
## Sir Archibald Pemberton, the founder. The Duck's first servant, now its finest exhibit.
## Only appears on the last night: relentless, can be stunned with the camera flash,
## and if you get too far ahead he steps out of the dark behind you.

enum State { DORMANT, HUNT, SEARCH }

var state := State.DORMANT
var speed := 2.55
var _stun := 0.0
var _taunt_t := 6.0
var _blink_cd := 20.0
var _target := Vector3.ZERO
var _lost := 0.0
var _voice: AudioStreamPlayer3D
const TAUNTS := [
	"Give me my Duck, you dreadful little employee.",
	"You are trespassing in my collection.",
	"Every exhibit returns to its case. So will you.",
	"I have been waiting ninety years. I can wait behind you.",
]


func _ready() -> void:
	super._ready()
	add_to_group("stunnable")
	step_sounds = [preload("res://audio/boot_step_1.wav"), preload("res://audio/boot_step_2.wav")]
	_voice = make_3d_sound(null, 12.0, 4.0)
	visible = false
	collision_layer = 0
	Shift.noise.connect(func(pos: Vector3, radius: float) -> void:
		if state == State.SEARCH and pos.distance_to(global_position) < radius:
			_target = pos)


func awaken() -> void:
	if state != State.DORMANT:
		return
	state = State.HUNT
	visible = true
	collision_layer = 4
	Music.play_now("pemberton")
	Music.sting("sting_reveal", 0.0, 2.0)
	say("At last. Someone has come to return my Duck.")


func sleep_forever() -> void:
	state = State.DORMANT
	visible = false
	collision_layer = 0
	if Music.locked == "pemberton":
		Music.locked = ""


func stun(t: float) -> void:
	_stun = t
	say("Aargh! No photographs!")


func say(text: String) -> void:
	Shift.say(text, "SIR ARCHIBALD", 3.5)
	var v := Shift.voice_line(text)
	if v:
		_voice.stream = v
		_voice.play()


func _physics_process(delta: float) -> void:
	if state == State.DORMANT or not Shift.running or not find_player() or not nav_ready():
		stand_still(delta)
		return
	_stun = maxf(_stun - delta, 0.0)
	_blink_cd = maxf(_blink_cd - delta, 0.0)
	if _stun > 0.0:
		stand_still(delta)
		rig.pose({"ShoulderL": Vector3(2.4, 0, -0.3), "ShoulderR": Vector3(2.4, 0, 0.3), "Head": Vector3(0.4, 0, 0)})
		return
	var sees: bool = not player.is_hidden and can_see_point(player.camera.global_position)
	if sees:
		_target = player.global_position
		_lost = 0.0
		state = State.HUNT
	else:
		_lost += delta
	if player.is_hidden and _lost > 1.0:
		state = State.SEARCH
	var dist := flat_distance_to_player()
	# Too far behind? He steps out of the dark somewhere behind you.
	if state == State.HUNT and dist > 22.0 and _blink_cd <= 0.0 and not player.is_safe():
		_blink_behind()
	var goal: Vector3 = player.global_position if state == State.HUNT else _target
	walk_towards(goal, speed * Shift.speed_mult() * (1.0 if state == State.HUNT else 0.7), delta)
	rig.walk(walk_phase, 1.0, 0.6)
	if state == State.HUNT:
		Music.report_chase()
	_taunt_t -= delta
	if _taunt_t <= 0.0:
		_taunt_t = randf_range(9.0, 14.0)
		say(TAUNTS[randi() % TAUNTS.size()])
	if is_touching_player():
		Shift.catch_player(self, "pemberton")


func _blink_behind() -> void:
	_blink_cd = 25.0
	var back: Vector3 = player.camera.global_transform.basis.z
	back.y = 0.0
	var candidate: Vector3 = player.global_position + back.normalized() * 7.0
	var map := agent.get_navigation_map()
	var p := NavigationServer3D.map_get_closest_point(map, candidate)
	if absf(p.y - player.global_position.y) < 1.5:
		global_position = p
		for l in get_tree().get_nodes_in_group("flicker_lights"):
			l.burst(1.0)
		say("Behind you, dear boy.")
