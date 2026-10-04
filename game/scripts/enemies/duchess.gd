extends EnemyBase
## The Duchess, Disappointed. Every so often every painting in the museum looks at you.
## Warning (whispers, flickering lights) -> WATCHING for a few seconds: move and she steps out of the frame.

enum Phase { IDLE, WARN, WATCH }

const WARN_TIME := 2.2
const WATCH_TIME := 3.5

var enabled := false
var interval := Vector2(40, 60)
var phase := Phase.IDLE
var _timer := 30.0
var _whisper: AudioStreamPlayer
var _moved := 0.0


func _ready() -> void:
	super._ready()
	visible = false
	collision_layer = 0
	_whisper = AudioStreamPlayer.new()
	_whisper.bus = "SFX"
	var w: AudioStream = preload("res://audio/whisper.ogg")
	_whisper.stream = w
	add_child(_whisper)


func set_enabled(on: bool, first_delay: float = 20.0) -> void:
	enabled = on
	phase = Phase.IDLE
	_timer = first_delay
	if not on:
		_whisper.stop()


func is_watching() -> bool:
	return phase == Phase.WATCH


func _physics_process(delta: float) -> void:
	if not enabled or not Shift.running or not find_player():
		return
	_timer -= delta
	match phase:
		Phase.IDLE:
			if _timer <= 0.0:
				if player.is_safe() or player.is_hidden:
					_timer = 5.0
				else:
					phase = Phase.WARN
					_timer = WARN_TIME
					_whisper.volume_db = -12.0
					_whisper.play()
					create_tween().tween_property(_whisper, "volume_db", 0.0, WARN_TIME)
					for l in get_tree().get_nodes_in_group("flicker_lights"):
						l.burst(WARN_TIME)
					Shift.alert.emit("...the paintings are turning to look at you...")
		Phase.WARN:
			Music.report_danger(0.8)
			if _timer <= 0.0:
				phase = Phase.WATCH
				_timer = WATCH_TIME
				_moved = 0.0
				Shift.alert.emit("THEY ARE WATCHING. DON'T MOVE.")
		Phase.WATCH:
			Music.report_danger(1.0)
			var v := Vector2(player.velocity.x, player.velocity.z).length()
			if v > 0.35 and not player.is_safe():
				_moved += delta
			if _moved > 0.15:
				_strike()
			elif _timer <= 0.0:
				phase = Phase.IDLE
				_timer = randf_range(interval.x, interval.y)
				create_tween().tween_property(_whisper, "volume_db", -40.0, 1.0)
				Shift.alert.emit("She looks away. For now.")


func _strike() -> void:
	phase = Phase.IDLE
	enabled = false
	_whisper.stop()
	var cam: Camera3D = player.camera
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	global_position = player.global_position + fwd * 1.1
	look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
	visible = true
	rig.pose({"ShoulderL": Vector3(1.5, 0, -0.2), "ShoulderR": Vector3(1.5, 0, 0.2), "Head": Vector3(0.2, 0, 0.3)})
	Shift.catch_player(self, "duchess")
