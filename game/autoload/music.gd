extends Node
## Adaptive music director + audio buses. Autoloaded as "Music".
##
## Gameplay code only *reports* what is happening; the director picks the track:
##   Music.set_base("calm")      - the night's background mood (calm / tense / blackout / storm / finale)
##   Music.report_chase()        - call every frame while something is chasing the player
##   Music.report_danger(0..1)   - call every frame while a threat is close
##   Music.set_safe(true)        - player is in the Security Office (music fades, the radio plays)
##   Music.sting("sting_task")   - one-shot musical cue on top of everything
## Priority: chase > danger > safe room > base.

const TRACKS := {
	"menu": "menu_theme", "calm": "explore_calm", "tense": "explore_tense", "danger": "danger_near",
	"chase": "chase", "blackout": "blackout", "storm": "duchess_theme", "finale": "finale",
	"dawn": "dawn", "credits": "credits", "silence": "", "upper": "upper_floor", "basement": "basement",
	"brenda": "brenda_theme", "pemberton": "pemberton_chase",
}
const ONE_SHOT := ["dawn", "credits"]
const FADE_FAST := 0.5
const FADE_SLOW := 3.0
const CHASE_HOLD := 4.0
const DANGER_HOLD := 3.0

var base := "silence"
var current := ""
var threat := 0.0 # smoothed 0..1, read by the player (heartbeat) and post FX
var in_safe := false
var locked := "" # forces a state (e.g. "credits"), ignores reports

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _targets := [0.0, 0.0] # linear volumes
var _fade_speed := [1.0, 1.0]
var _chase_t := 0.0
var _danger_t := 0.0
var _danger_level := 0.0
var _stings: Array[AudioStreamPlayer] = []
var _ui: AudioStreamPlayer
var _duck := 1.0
var _duck_t := 0.0
var _streams := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	for i in 3:
		var s := AudioStreamPlayer.new()
		s.bus = "Music"
		add_child(s)
		_stings.append(s)
	_ui = AudioStreamPlayer.new()
	_ui.bus = "UI"
	add_child(_ui)


func _setup_buses() -> void:
	var names := ["Music", "SFX", "Reverb", "UI", "Voice"]
	for n in names:
		if AudioServer.get_bus_index(n) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, n)
	AudioServer.set_bus_send(AudioServer.get_bus_index("Music"), "Master")
	AudioServer.set_bus_send(AudioServer.get_bus_index("SFX"), "Master")
	AudioServer.set_bus_send(AudioServer.get_bus_index("Reverb"), "SFX")
	AudioServer.set_bus_send(AudioServer.get_bus_index("UI"), "Master")
	AudioServer.set_bus_send(AudioServer.get_bus_index("Voice"), "Master")
	var rev_idx := AudioServer.get_bus_index("Reverb")
	if AudioServer.get_bus_effect_count(rev_idx) == 0:
		var rev := AudioEffectReverb.new()
		rev.room_size = 0.8
		rev.damping = 0.45
		rev.spread = 1.0
		rev.dry = 0.0
		rev.wet = 0.6
		rev.predelay_msec = 40.0
		AudioServer.add_bus_effect(rev_idx, rev)
	for bus in ["SFX", "Music"]:
		var idx := AudioServer.get_bus_index(bus)
		if AudioServer.get_bus_effect_count(idx) == 0:
			var lp := AudioEffectLowPassFilter.new()
			lp.cutoff_hz = 900.0
			AudioServer.add_bus_effect(idx, lp)
			AudioServer.set_bus_effect_enabled(idx, 0, false)


## Muffles sound effects (hiding in a locker) or music (pause menu).
func set_muffled(bus: String, on: bool) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0 and AudioServer.get_bus_effect_count(idx) > 0:
		AudioServer.set_bus_effect_enabled(idx, 0, on)


func set_base(state: String) -> void:
	base = state


func report_chase() -> void:
	_chase_t = CHASE_HOLD


func report_danger(level: float = 1.0) -> void:
	_danger_t = DANGER_HOLD
	_danger_level = maxf(_danger_level, level)


func set_safe(on: bool) -> void:
	in_safe = on


## Which floor the player is on (-1 basement, 0 ground, 1 upper). Floors have their own mood
## that replaces the calm/tense night mood (blackout, storm and the finale still win).
var floor_level := 0
func set_floor(lvl: int) -> void:
	floor_level = lvl


func reset_reports() -> void:
	_chase_t = 0.0
	_danger_t = 0.0
	_danger_level = 0.0
	threat = 0.0
	in_safe = false
	locked = ""


func play_now(state: String) -> void:
	locked = state
	_switch(state, FADE_FAST)


func _process(delta: float) -> void:
	if get_tree().paused and locked == "":
		_apply_volumes(delta)
		return
	_chase_t = maxf(_chase_t - delta, 0.0)
	_danger_t = maxf(_danger_t - delta, 0.0)
	if _danger_t <= 0.0:
		_danger_level = 0.0
	var target_threat := 1.0 if _chase_t > 0.0 else (_danger_level if _danger_t > 0.0 else 0.0)
	threat = move_toward(threat, target_threat, delta * (1.5 if target_threat > threat else 0.4))
	var want := base
	if (base == "calm" or base == "tense") and floor_level == 1:
		want = "upper"
	elif base != "finale" and floor_level == -1:
		want = "basement"
	if locked != "":
		want = locked
	elif _chase_t > 0.0:
		want = "chase"
	elif _danger_t > 0.0 and _danger_level > 0.35:
		want = "danger"
	elif in_safe:
		want = "silence"
	if want != current:
		var fast := want == "chase" or want == "danger"
		if want == "chase":
			sting("sting_chase", -4.0)
		_switch(want, FADE_FAST if fast else FADE_SLOW)
	_duck_t = maxf(_duck_t - delta, 0.0)
	_duck = move_toward(_duck, 0.45 if _duck_t > 0.0 else 1.0, delta * 2.0)
	_apply_volumes(delta)


func _switch(state: String, fade: float) -> void:
	current = state
	var old := _active
	_targets[old] = 0.0
	_fade_speed[old] = 1.0 / maxf(fade, 0.05)
	var track: String = TRACKS.get(state, "")
	if track == "":
		return
	_active = 1 - _active
	var p := _players[_active]
	p.stream = _load(track, not ONE_SHOT.has(state))
	p.volume_db = -60.0
	p.play()
	_targets[_active] = 1.0
	_fade_speed[_active] = 1.0 / maxf(fade, 0.05)


func _apply_volumes(delta: float) -> void:
	for i in 2:
		var p := _players[i]
		var cur := db_to_linear(p.volume_db) if p.volume_db > -79.0 else 0.0
		cur = move_toward(cur, _targets[i], delta * _fade_speed[i])
		p.volume_db = linear_to_db(maxf(cur * _duck, 0.0001))
		if cur <= 0.001 and _targets[i] == 0.0 and p.playing:
			p.stop()


func _load(track: String, loop: bool) -> AudioStream:
	var key := track + ("_loop" if loop else "")
	if not _streams.has(key):
		var s: AudioStream = load("res://audio/music/%s.ogg" % track)
		if s is AudioStreamOggVorbis:
			s = s.duplicate()
			s.loop = loop
		_streams[key] = s
	return _streams[key]


## One-shot musical cue. Ducks the music briefly so it reads.
func sting(name: String, volume_db: float = 0.0, duck_time: float = 1.5) -> void:
	var path := "res://audio/music/%s.ogg" % name
	if not ResourceLoader.exists(path):
		return
	var free_player: AudioStreamPlayer = _stings[0]
	for s in _stings:
		if not s.playing:
			free_player = s
			break
	free_player.stream = _load(name, false)
	free_player.volume_db = volume_db
	free_player.play()
	_duck_t = duck_time


## Keep the music lowered (e.g. while a tape is playing).
func duck_for(seconds: float) -> void:
	_duck_t = maxf(_duck_t, seconds)


func ui(name: String = "ui_click") -> void:
	_ui.stream = load("res://audio/%s.wav" % name)
	_ui.play()


func stop_all() -> void:
	locked = ""
	base = "silence"
	_switch("silence", 1.0)
