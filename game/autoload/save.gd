extends Node
## Settings + progress, stored in user://save.cfg. Autoloaded as "Save".

signal settings_changed

const PATH := "user://save.cfg"
const QUALITY_NAMES := ["Low", "Medium", "High", "Ultra"]

var settings := {
	"mouse_sens": 1.0,
	"invert_y": false,
	"fov": 75.0,
	"head_bob": true,
	"master": 0.9,
	"music": 0.8,
	"sfx": 1.0,
	"fullscreen": true,
	"quality": 2,
	"difficulty": 1, # 0 = Story (easier), 1 = Normal
	"subtitles": true,
}
var progress := {
	"night_unlocked": 1,
	"endings": [],
	"notes": [],
	"keycard": false,
	"tapes": [],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_all()
	# Apply after the Music autoload created its buses.
	call_deferred("apply_settings")


func load_all() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for k in settings:
		settings[k] = cfg.get_value("settings", k, settings[k])
	for k in progress:
		progress[k] = cfg.get_value("progress", k, progress[k])


func save_all() -> void:
	var cfg := ConfigFile.new()
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	for k in progress:
		cfg.set_value("progress", k, progress[k])
	cfg.save(PATH)


func set_setting(key: String, value) -> void:
	settings[key] = value
	apply_settings()
	save_all()


func apply_settings() -> void:
	for bus in [["Master", "master"], ["Music", "music"], ["SFX", "sfx"]]:
		var idx := AudioServer.get_bus_index(bus[0])
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(float(settings[bus[1]]), 0.0001)))
	if not Engine.is_editor_hint() and DisplayServer.get_name() != "headless":
		var want_full: bool = settings["fullscreen"]
		var mode := DisplayServer.window_get_mode()
		var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if want_full != is_full:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if want_full else DisplayServer.WINDOW_MODE_WINDOWED)
	settings_changed.emit()


## Applies the graphics preset to an Environment + viewport.
func apply_quality(env: Environment, viewport: Viewport) -> void:
	var q: int = settings["quality"]
	if env:
		env.ssao_enabled = q >= 1
		env.volumetric_fog_enabled = q >= 1
		env.glow_enabled = true
		env.ssil_enabled = q >= 3
		# Real-time global illumination (light bouncing off walls) from High up.
		env.sdfgi_enabled = q >= 2
		env.sdfgi_cascades = 4 if q == 2 else 6
		env.sdfgi_use_occlusion = true
		env.sdfgi_bounce_feedback = 0.4
		env.sdfgi_energy = 0.7
		env.ssr_enabled = q >= 2
	if viewport:
		viewport.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_2X, Viewport.MSAA_4X][q]
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if q == 0 else Viewport.SCALING_3D_MODE_BILINEAR
		viewport.scaling_3d_scale = 0.75 if q == 0 else 1.0
		viewport.positional_shadow_atlas_size = [1024, 2048, 4096, 4096][q]
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 4096, 4096][q], true)
	RenderingServer.environment_set_sdfgi_ray_count(RenderingServer.ENV_SDFGI_RAY_COUNT_32 if q == 2 else RenderingServer.ENV_SDFGI_RAY_COUNT_64)
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM if q < 3 else RenderingServer.ENV_SSAO_QUALITY_HIGH, true, 0.5, 2, 50, 300)
	RenderingServer.environment_set_volumetric_fog_volume_size(64 if q < 2 else 128, 64 if q < 2 else 128)


func unlock_night(n: int) -> void:
	progress["night_unlocked"] = maxi(int(progress["night_unlocked"]), n)
	save_all()


func add_note(id: int) -> void:
	if not progress["notes"].has(id):
		progress["notes"].append(id)
		save_all()


func add_tape(id: int) -> void:
	if not progress["tapes"].has(id):
		progress["tapes"].append(id)
		save_all()


func add_ending(id: String) -> void:
	if not progress["endings"].has(id):
		progress["endings"].append(id)
		save_all()
