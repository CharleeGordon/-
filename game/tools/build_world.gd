extends Node
## Builds scenes/museum.scn: architecture, props, lights, exhibits, enemies, gameplay markers,
## then bakes navigation. Run from the game/ folder (after textures + audio exist and are imported):
##   godot --headless --path . res://tools/build_world.tscn
## Running it OVERWRITES museum.scn. Once you hand-edit the museum in the editor, stop using it.

const OUT := "res://scenes/museum.scn"
const ML := preload("res://tools/meshlib.gd")
const PROPS := preload("res://tools/props.gd")
const H := 5.0 # wall height
const T := 0.3 # wall thickness
const DOOR_H := 2.7

# Levels: floor height (y) and wall band height.
const LEVELS := {
	0: {"y": 0.0, "wall": 5.5},
	1: {"y": 5.5, "wall": 4.3},
	-1: {"y": -4.5, "wall": 4.3},
}

# Rooms: rect (x0, z0, x1, z1), level, floor/wall materials, ceiling height (above the floor), wainscot, crown molding.
# "holes": floor openings (stairs, atrium). "ceil_hole": opening in the ceiling. "no_ceiling": room builds its own (dome).
const ROOMS := {
	# Ground floor
	"lobby":   {"r": [-12, -10, 12, 10], "lvl": 0, "floor": "marble", "wall": "plaster_cream", "ceil": 5.0, "wainscot": false, "crown": false, "reverb": 0.9, "ceil_hole": [-8.5, -6.5, 8.5, 6.5]},
	"office":  {"r": [-4, 10, 4, 17], "lvl": 0, "floor": "wood_floor", "wall": "plaster_white", "ceil": 3.0, "wainscot": true, "crown": false, "reverb": 0.15},
	"storage": {"r": [-22, -6, -12, 10], "lvl": 0, "floor": "concrete", "wall": "concrete", "ceil": 4.2, "wainscot": false, "crown": false, "reverb": 0.5, "holes": [[-21.75, -2.6, -19.45, 6.1]]},
	"gallery": {"r": [-12, -22, 0, -10], "lvl": 0, "floor": "wood_floor", "wall": "plaster_green", "ceil": 5.0, "wainscot": true, "crown": true, "reverb": 0.6},
	"egypt":   {"r": [0, -22, 12, -10], "lvl": 0, "floor": "sand_floor", "wall": "sandstone", "ceil": 5.0, "wainscot": false, "crown": false, "reverb": 0.7},
	"dino":    {"r": [12, -18, 30, 10], "lvl": 0, "floor": "stone_floor", "wall": "plaster_blue", "ceil": 5.0, "wainscot": false, "crown": true, "reverb": 0.9},
	"wax":     {"r": [-22, 10, -4, 20], "lvl": 0, "floor": "carpet", "wall": "wallpaper", "ceil": 4.2, "wainscot": true, "crown": true, "reverb": 0.3},
	"curio":   {"r": [4, 10, 20, 22], "lvl": 0, "floor": "wood_floor", "wall": "wallpaper_green", "ceil": 4.2, "wainscot": true, "crown": true, "reverb": 0.4},
	# Upper floor
	"balcony":     {"r": [-12, -10, 12, 10], "lvl": 1, "floor": "marble", "wall": "plaster_cream", "ceil": 3.8, "wainscot": false, "crown": true, "reverb": 0.9, "holes": [[-8.5, -6.5, 8.5, 6.5]], "ceil_hole": [-4, -3, 4, 3]},
	"library":     {"r": [-12, -22, 0, -10], "lvl": 1, "floor": "wood_floor", "wall": "plaster_red", "ceil": 3.8, "wainscot": true, "crown": true, "reverb": 0.35},
	"planetarium": {"r": [0, -22, 12, -10], "lvl": 1, "floor": "carpet", "wall": "plaster_dark", "ceil": 3.4, "wainscot": false, "crown": false, "reverb": 0.8, "no_ceiling": true},
	"natural":     {"r": [12, -18, 30, -4], "lvl": 1, "floor": "wood_floor", "wall": "plaster_green", "ceil": 3.8, "wainscot": true, "crown": true, "reverb": 0.5},
	"armory":      {"r": [12, -4, 30, 10], "lvl": 1, "floor": "stone_floor", "wall": "brick", "ceil": 3.8, "wainscot": false, "crown": false, "reverb": 0.8},
	"workshop":    {"r": [-22, -6, -12, 10], "lvl": 1, "floor": "concrete", "wall": "plaster_white", "ceil": 3.8, "wainscot": false, "crown": false, "reverb": 0.5},
	"costume":     {"r": [-22, 10, -4, 20], "lvl": 1, "floor": "carpet", "wall": "wallpaper", "ceil": 3.8, "wainscot": true, "crown": true, "reverb": 0.25},
	"director":    {"r": [-4, 10, 4, 17], "lvl": 1, "floor": "wood_floor", "wall": "wallpaper_green", "ceil": 3.8, "wainscot": true, "crown": true, "reverb": 0.2},
	"toyroom":     {"r": [4, 10, 20, 22], "lvl": 1, "floor": "wood_floor", "wall": "plaster_red", "ceil": 3.8, "wainscot": true, "crown": true, "reverb": 0.4},
	# Basement
	"boiler":   {"r": [-22, -22, -12, 10], "lvl": -1, "floor": "concrete", "wall": "brick", "ceil": 3.6, "wainscot": false, "crown": false, "reverb": 0.9},
	"archives": {"r": [-12, -22, 0, -10], "lvl": -1, "floor": "concrete", "wall": "concrete", "ceil": 3.6, "wainscot": false, "crown": false, "reverb": 0.6},
	"vault":    {"r": [0, -22, 12, -10], "lvl": -1, "floor": "stone_floor", "wall": "sandstone", "ceil": 3.6, "wainscot": false, "crown": false, "reverb": 1.0},
}

# Doors: [axis, line coordinate, from, to, level, locked door name or ""]
# axis "x": wall runs along X at z = line. axis "z": wall runs along Z at x = line.
const DOORS := [
	["x", 10, -1.0, 1.0, 0, ""],            # lobby - office
	["z", -12, -1.2, 1.2, 0, ""],           # lobby - storage
	["x", -10, -7.2, -4.8, 0, ""],          # lobby - gallery
	["x", -10, 4.8, 7.2, 0, ""],            # lobby - egypt
	["z", 0, -17.0, -15.0, 0, ""],          # gallery - egypt
	["z", 12, -1.6, 1.6, 0, ""],            # lobby - dino
	["z", 12, -15.0, -13.0, 0, ""],         # egypt - dino
	["x", 10, 6.8, 9.2, 0, "DoorCurio"],    # lobby - curiosities
	["x", 10, 15.0, 17.0, 0, "DoorCurio2"], # dino - curiosities
	["x", 10, -9.2, -6.8, 0, "DoorWax"],    # lobby - wax hall
	["x", 10, -18.0, -16.0, 0, "DoorWax2"], # storage - wax hall
	["x", -10, -7.2, -4.8, 1, "DoorLibrary"],   # balcony - library
	["x", -10, 4.8, 7.2, 1, "DoorPlanet"],      # balcony - planetarium
	["z", 0, -17.0, -15.0, 1, ""],              # library - planetarium
	["z", 12, -7.4, -5.4, 1, "DoorNatural"],    # balcony - natural history
	["z", 12, 3.0, 5.0, 1, "DoorArmory"],       # balcony - armory
	["x", -4, 20.0, 22.0, 1, ""],               # natural history - armory
	["z", -12, -1.2, 1.2, 1, "DoorWorkshop"],   # balcony - workshop
	["x", 10, -1.0, 1.0, 1, ""],                # balcony - director
	["z", -4, 12.5, 14.5, 1, "DoorCostume"],    # director - costume
	["z", 4, 12.5, 14.5, 1, ""],                # director - toy room
	["x", 10, -18.0, -16.0, 1, ""],             # workshop - costume
	["x", 10, 15.0, 17.0, 1, "DoorToyArmory"],  # toy room - armory
	["z", -12, -17.0, -15.0, -1, "DoorArchives"], # boiler - archives
	["z", 0, -17.0, -15.0, -1, "DoorVault"],      # archives - vault
]

# Windows: [axis, line, from, to, bottom, top, level]
const WINDOWS := [
	["z", 30, -14.0, -12.4, 1.1, 3.9, 0], ["z", 30, -7.0, -5.4, 1.1, 3.9, 0], ["z", 30, 0.2, 1.8, 1.1, 3.9, 0], ["z", 30, 6.0, 7.6, 1.1, 3.9, 0],
	["z", -12, -19.8, -18.2, 1.1, 3.9, 0], ["z", -12, -14.8, -13.2, 1.1, 3.9, 0], ["z", -12, -8.6, -7.4, 1.4, 3.6, 0],
	["x", 20, -19.8, -18.4, 1.2, 3.4, 0], ["x", 20, -14.2, -12.8, 1.2, 3.4, 0], ["x", 20, -8.6, -7.2, 1.2, 3.4, 0],
	["x", 22, 7.3, 8.7, 1.2, 3.4, 0], ["x", 22, 11.3, 12.7, 1.2, 3.4, 0], ["x", 22, 15.3, 16.7, 1.2, 3.4, 0],
	["z", -22, 1.4, 2.6, 1.8, 3.0, 0],
	["z", -12, -19.6, -18.4, 1.0, 3.2, 1], ["z", -12, -14.6, -13.4, 1.0, 3.2, 1], ["z", -12, -8.6, -7.4, 1.0, 3.2, 1],
	["z", 30, -15.0, -13.6, 1.0, 3.2, 1], ["z", 30, -9.0, -7.6, 1.0, 3.2, 1], ["z", 30, -0.8, 0.6, 1.0, 3.2, 1], ["z", 30, 5.0, 6.4, 1.0, 3.2, 1],
	["z", -22, -2.0, -0.6, 1.2, 3.0, 1], ["z", -22, 5.0, 6.4, 1.2, 3.0, 1],
	["x", 20, -19.0, -17.6, 1.2, 3.0, 1], ["x", 20, -11.0, -9.6, 1.2, 3.0, 1],
	["x", 17, -0.7, 0.7, 1.2, 3.0, 1],
	["x", 22, 7.3, 8.7, 1.2, 3.0, 1], ["x", 22, 15.3, 16.7, 1.2, 3.0, 1],
]

const SCRIPTS := {
	"interactable": preload("res://scripts/interactable.gd"),
	"room": preload("res://scripts/world/room_area.gd"),
	"door": preload("res://scripts/world/door.gd"),
	"flicker": preload("res://scripts/world/flicker_light.gd"),
	"pendulum": preload("res://scripts/world/pendulum.gd"),
	"emitter": preload("res://scripts/world/ambient_emitter.gd"),
	"knight": preload("res://scripts/enemies/knight.gd"),
	"mummy": preload("res://scripts/enemies/mummy.gd"),
	"dino": preload("res://scripts/enemies/dino.gd"),
	"automaton": preload("res://scripts/enemies/automaton.gd"),
	"duchess": preload("res://scripts/enemies/duchess.gd"),
	"guard": preload("res://scripts/enemies/wax_guard.gd"),
	"doll": preload("res://scripts/enemies/doll.gd"),
	"pemberton": preload("res://scripts/enemies/pemberton.gd"),
	"moths": preload("res://scripts/enemies/moths.gd"),
	"barrier": preload("res://scripts/world/barrier.gd"),
	"spinner": preload("res://scripts/world/spinner.gd"),
}

var P: Props
var museum: Node3D
var level: NavigationRegion3D
var visual: Node3D
var lights: Node3D
var items: Node3D
var _names := {}
var _scripts := []


func _ready() -> void:
	P = PROPS.new()
	museum = Node3D.new()
	museum.name = "Museum"
	add_child(museum)
	_environment()
	level = NavigationRegion3D.new()
	level.name = "Level"
	museum.add_child(level)
	visual = _group(museum, "Visual")
	lights = _group(museum, "Lights")
	items = _group(museum, "Interactables")

	_floors_and_ceilings()
	print("built _floors_and_ceilings()")
	_walls()
	print("built _walls()")
	_linings_and_moldings()
	print("built _linings_and_moldings()")
	_door_frames()
	print("built _door_frames()")
	_windows()
	print("built _windows()")
	_outside()
	print("built _outside()")
	_rooms()
	print("built _rooms()")
	_lobby()
	print("built _lobby()")
	_balcony()
	print("built _balcony()")
	_office()
	print("built _office()")
	_storage()
	print("built _storage()")
	_gallery()
	print("built _gallery()")
	_egypt()
	print("built _egypt()")
	_dino_hall()
	print("built _dino_hall()")
	_wax_hall()
	print("built _wax_hall()")
	_curiosities()
	print("built _curiosities()")
	_library()
	print("built _library()")
	_planetarium()
	print("built _planetarium()")
	_natural()
	print("built _natural()")
	_armory()
	print("built _armory()")
	_workshop()
	print("built _workshop()")
	_costume()
	print("built _costume()")
	_director()
	print("built _director()")
	_toyroom()
	print("built _toyroom()")
	_boiler()
	print("built _boiler()")
	_archives()
	print("built _archives()")
	_vault()
	print("built _vault()")
	_decals()
	print("built _decals()")
	_markers()
	print("built _markers()")

	_bake_navigation()
	remove_child(museum)
	for e in _scripts:
		e[0].set_script(e[1])
		for k in e[2]:
			e[0].set(k, e[2][k])
	_set_owner(museum)
	var packed := PackedScene.new()
	var err := packed.pack(museum)
	if err == OK:
		err = ResourceSaver.save(packed, OUT, ResourceSaver.FLAG_COMPRESS)
	print("Saved %s: %s" % [OUT, error_string(err)])
	museum.free()
	get_tree().quit(0 if err == OK else 1)


# ---------------------------------------------------------------- helpers ---

func _uname(base: String) -> String:
	_names[base] = _names.get(base, 0) + 1
	return base if _names[base] == 1 else "%s%d" % [base, _names[base]]


func _group(parent: Node, n: String) -> Node3D:
	var g := Node3D.new()
	g.name = n
	parent.add_child(g)
	return g


func _attach(node: Node, script_key: String, props: Dictionary = {}) -> void:
	_scripts.append([node, SCRIPTS[script_key], props])


func _set_owner(node: Node) -> void:
	for c in node.get_children():
		c.owner = museum
		_set_owner(c)


## Places a prop (from Props) in the world. rot_y in degrees. Returns the node.
func put(prop: Node3D, pos: Vector3, rot_y: float = 0.0, parent: Node = null) -> Node3D:
	prop.name = _uname(prop.name)
	prop.position = pos
	prop.rotation_degrees.y = rot_y
	(parent if parent else visual).add_child(prop)
	return prop


## Invisible static collider (blocks player + navigation).
func collider(size: Vector3, pos: Vector3, rot_y: float = 0.0, layer: int = 1) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = _uname("Collider")
	body.position = pos
	body.rotation_degrees.y = rot_y
	body.collision_layer = layer
	level.add_child(body)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	return body


## Solid prop: visual + box collider of `size` (centered at pos + size.y/2).
## For quarter turns (+-90) `size` is given in world axes (already rotated); other angles rotate the box.
func solid(prop: Node3D, pos: Vector3, size: Vector3, rot_y: float = 0.0) -> Node3D:
	put(prop, pos, rot_y)
	var quarter := is_equal_approx(absf(fmod(rot_y, 180.0)), 90.0)
	collider(size, pos + Vector3(0, size.y / 2.0, 0), 0.0 if quarter else rot_y)
	return prop


func mesh_at(mesh: Mesh, pos: Vector3, rot: Vector3 = Vector3.ZERO, parent: Node = null, n: String = "Mesh") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = _uname(n)
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	(parent if parent else visual).add_child(mi)
	return mi


func label(text: String, pos: Vector3, rot_y: float, size: float = 0.0016, color: Color = Color(0.92, 0.88, 0.75), parent: Node = null) -> Label3D:
	var l := Label3D.new()
	l.name = _uname("Label")
	l.text = text
	l.font_size = 64
	l.pixel_size = size
	l.outline_size = 0
	l.modulate = color
	l.double_sided = false
	l.shaded = true
	l.position = pos
	l.rotation_degrees.y = rot_y
	(parent if parent else visual).add_child(l)
	return l


## Brass plaque with engraved text, facing +Z of the given rotation.
func plaque(text: String, pos: Vector3, rot_y: float, w: float = 0.5) -> void:
	var holder := Node3D.new()
	holder.name = _uname("Plaque")
	holder.position = pos
	holder.rotation_degrees.y = rot_y
	visual.add_child(holder)
	mesh_at(P.bbox(Vector3(w, w * 0.32, 0.012), 0.003, "brass"), Vector3.ZERO, Vector3.ZERO, holder, "Plate")
	var l := label(text, Vector3(0, 0, 0.008), 0.0, w * 0.0021, Color(0.1, 0.07, 0.03), holder)
	l.width = w / (w * 0.0021) * 0.92
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func light_omni(pos: Vector3, color: Color, energy: float, rng: float, room: String, shadow: bool = false, group: String = "room_lights") -> OmniLight3D:
	var o := OmniLight3D.new()
	o.name = _uname("Omni")
	o.position = pos
	o.light_color = color
	o.light_energy = energy
	o.omni_range = rng
	o.omni_attenuation = 1.4
	o.shadow_enabled = shadow
	o.light_volumetric_fog_energy = 0.6
	if group != "":
		o.add_to_group(group, true)
	if room != "":
		o.add_to_group("lights_" + room, true)
	lights.add_child(o)
	return o


func light_spot(pos: Vector3, target: Vector3, color: Color, energy: float, rng: float, angle: float, room: String, shadow: bool = false, group: String = "room_lights") -> SpotLight3D:
	var s := SpotLight3D.new()
	s.name = _uname("Spot")
	s.position = pos
	s.basis = Basis.looking_at((target - pos).normalized(), Vector3.UP if absf((target - pos).normalized().y) < 0.99 else Vector3.FORWARD)
	s.light_color = color
	s.light_energy = energy
	s.spot_range = rng
	s.spot_angle = angle
	s.spot_attenuation = 1.0
	s.spot_angle_attenuation = 2.0
	s.shadow_enabled = shadow
	s.light_volumetric_fog_energy = 1.2
	if group != "":
		s.add_to_group(group, true)
	if room != "":
		s.add_to_group("lights_" + room, true)
	lights.add_child(s)
	return s


func emergency(pos: Vector3, room: String) -> void:
	var o := light_omni(pos, Color(1.0, 0.08, 0.05), 1.2, 12.0, room, false, "emergency_lights")
	o.visible = false
	var box := mesh_at(P.bbox(Vector3(0.3, 0.12, 0.12), 0.01, "e_red"), pos + Vector3(0, 0.15, 0))
	box.visible = false
	box.add_to_group("emergency_lights", true)


func interactable(n: String, action: String, prompt: String, pos: Vector3, size: Vector3, offset: Vector3 = Vector3.ZERO, is_active: bool = true, parent: Node = null) -> Area3D:
	var a := Area3D.new()
	a.name = n
	_attach(a, "interactable", {"action_id": action, "prompt": prompt, "active": is_active})
	a.collision_layer = 8 if is_active else 0
	a.collision_mask = 0
	a.monitoring = false
	a.position = pos
	(parent if parent else items).add_child(a)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = offset
	a.add_child(cs)
	return a


func emitter(stream_name: String, pos: Vector3, volume_db: float, unit_size: float, parent: Node = null) -> void:
	var path := "res://audio/%s.wav" % stream_name
	if not ResourceLoader.exists(path):
		path = "res://audio/%s.ogg" % stream_name
	if not ResourceLoader.exists(path):
		path = "res://audio/music/%s.ogg" % stream_name
	if not ResourceLoader.exists(path):
		push_warning("missing audio " + stream_name)
		return
	var e := AudioStreamPlayer3D.new()
	e.name = _uname("Sound_" + stream_name)
	e.stream = load(path)
	e.position = pos
	e.volume_db = volume_db
	e.unit_size = unit_size
	e.max_distance = unit_size * 8.0
	e.bus = "SFX"
	_attach(e, "emitter")
	(parent if parent else museum).add_child(e)


func marker(parent: Node, n: String, pos: Vector3, rot_y: float = 0.0) -> Marker3D:
	var m := Marker3D.new()
	m.name = n
	m.position = pos
	m.rotation_degrees.y = rot_y
	parent.add_child(m)
	return m


func rect(room: String) -> Rect2:
	var r: Array = ROOMS[room]["r"]
	return Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1])


# ------------------------------------------------------------ environment ---

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = load("res://textures/night_sky.jpg")
	sky_mat.energy_multiplier = 0.6
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.25, 0.35)
	env.ambient_light_energy = 0.22
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.35
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.0
	env.ssil_enabled = false
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.2
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.028
	env.volumetric_fog_albedo = Color(0.7, 0.72, 0.78)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_ambient_inject = 0.15
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.85
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	museum.add_child(we)

	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.basis = Basis.looking_at(Vector3(-1.0, -0.75, 0.35).normalized(), Vector3.UP)
	moon.light_color = Color(0.55, 0.66, 0.95)
	moon.light_energy = 0.8
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 70.0
	moon.light_volumetric_fog_energy = 4.0
	museum.add_child(moon)


# --------------------------------------------------------------- structure ---

func ly(lvl: int) -> float:
	return LEVELS[lvl]["y"]


func room_y(id: String) -> float:
	return ly(ROOMS[id]["lvl"])


## Rectangle minus one optional hole -> list of [x0, z0, x1, z1] pieces.
func _rect_minus(r: Array, hole) -> Array:
	if hole == null:
		return [r]
	var out := []
	out.append([r[0], r[1], r[2], hole[1]])
	out.append([r[0], hole[3], r[2], r[3]])
	out.append([r[0], hole[1], hole[0], hole[3]])
	out.append([hole[2], hole[1], r[2], hole[3]])
	var clean := []
	for q in out:
		if q[2] - q[0] > 0.01 and q[3] - q[1] > 0.01:
			clean.append(q)
	return clean


func _slab(r: Array, y_top: float, thick: float, mat: String, collide: bool, n: String) -> void:
	var w: float = r[2] - r[0]
	var d: float = r[3] - r[1]
	var pos := Vector3(r[0] + w / 2.0, y_top - thick / 2.0, r[1] + d / 2.0)
	var mesh := ML.bevel_box(Vector3(w, thick, d), 0.001, P.M[mat], 1)
	if collide:
		var body := StaticBody3D.new()
		body.name = _uname(n)
		body.position = pos
		level.add_child(body)
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = mesh
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		var sh := BoxShape3D.new()
		sh.size = Vector3(w, thick, d)
		cs.shape = sh
		body.add_child(cs)
	else:
		mesh_at(mesh, pos, Vector3.ZERO, null, n)


func _floors_and_ceilings() -> void:
	for id in ROOMS:
		var info: Dictionary = ROOMS[id]
		var r: Array = info["r"]
		var y0 := room_y(id)
		var holes: Array = info.get("holes", [])
		var hole = holes[0] if not holes.is_empty() else null
		var thick := 0.3 if info["lvl"] == 1 else 0.2
		for q in _rect_minus(r, hole):
			_slab(q, y0, thick, info["floor"], true, "Floor_" + id)
		if info.get("no_ceiling", false):
			continue
		var ch: float = y0 + info["ceil"]
		for q in _rect_minus(r, info.get("ceil_hole", null)):
			_slab(q, ch + 0.2, 0.2, "ceiling", false, "Ceiling")
		if info["lvl"] == 1:
			_slab(r, ly(1) + LEVELS[1]["wall"] + 0.2, 0.2, "ceiling", false, "RoofCap")
	# Close the gap above the skylight curb and around the planetarium dome top with the roof.


## Collects all room edges per level, merges them per wall line and cuts doors + windows.
func _walls() -> void:
	var lines := {} # "axis|c|lvl" -> Array of [a, b]
	for id in ROOMS:
		var r := rect(id)
		var lvl: int = ROOMS[id]["lvl"]
		for e in [["x", r.position.y, r.position.x, r.end.x], ["x", r.end.y, r.position.x, r.end.x], ["z", r.position.x, r.position.y, r.end.y], ["z", r.end.x, r.position.y, r.end.y]]:
			var key := "%s|%s|%d" % [e[0], e[1], lvl]
			if not lines.has(key):
				lines[key] = []
			lines[key].append([e[2], e[3]])
	for key in lines:
		var parts: PackedStringArray = key.split("|")
		var axis := parts[0]
		var c := float(parts[1])
		var lvl := int(parts[2])
		var y0 := ly(lvl)
		var top: float = y0 + LEVELS[lvl]["wall"]
		for iv in _merge_intervals(lines[key]):
			var openings := _openings_on(axis, c, iv[0], iv[1], lvl)
			var a: float = iv[0] - T / 2.0
			var b: float = iv[1] + T / 2.0
			for piece in _cut(a, b, y0, top, openings):
				_wall_box(axis, c, piece[0], piece[1], piece[2], piece[3])


func _merge_intervals(list: Array) -> Array:
	list.sort_custom(func(p, q): return p[0] < q[0])
	var out := []
	for iv in list:
		if out.is_empty() or iv[0] > out[-1][1] + 0.001:
			out.append([iv[0], iv[1]])
		else:
			out[-1][1] = maxf(out[-1][1], iv[1])
	return out


## Openings on a wall line within [a,b] at a level: Array of [from, to, bottom, top] (absolute y).
func _openings_on(axis: String, c: float, a: float, b: float, lvl: int) -> Array:
	var out := []
	var y0 := ly(lvl)
	for d in DOORS:
		if d[0] == axis and int(d[4]) == lvl and is_equal_approx(float(d[1]), c) and d[2] >= a - 0.01 and d[3] <= b + 0.01:
			out.append([float(d[2]), float(d[3]), y0, y0 + DOOR_H])
	for w in WINDOWS:
		if w[0] == axis and int(w[6]) == lvl and is_equal_approx(float(w[1]), c) and w[2] >= a - 0.01 and w[3] <= b + 0.01:
			out.append([float(w[2]), float(w[3]), y0 + float(w[4]), y0 + float(w[5])])
	out.sort_custom(func(p, q): return p[0] < q[0])
	return out


## Splits the rectangle [a,b] x [y0,y1] around openings. Returns pieces [u0, u1, y0, y1].
func _cut(a: float, b: float, y0: float, y1: float, openings: Array) -> Array:
	var pieces := []
	var cur := a
	for o in openings:
		if o[0] > cur:
			pieces.append([cur, o[0], y0, y1])
		if o[2] > y0:
			pieces.append([o[0], o[1], y0, minf(o[2], y1)])
		if o[3] < y1:
			pieces.append([o[0], o[1], maxf(o[3], y0), y1])
		cur = o[1]
	if cur < b:
		pieces.append([cur, b, y0, y1])
	return pieces


func _wall_box(axis: String, c: float, u0: float, u1: float, y0: float, y1: float) -> void:
	var length := u1 - u0
	var height := y1 - y0
	if length < 0.01 or height < 0.01:
		return
	var size := Vector3(length, height, T) if axis == "x" else Vector3(T, height, length)
	var pos := Vector3((u0 + u1) / 2.0, (y0 + y1) / 2.0, c) if axis == "x" else Vector3(c, (y0 + y1) / 2.0, (u0 + u1) / 2.0)
	var body := StaticBody3D.new()
	body.name = _uname("Wall")
	body.position = pos
	level.add_child(body)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = P.bbox(size, 0.002, "plaster_cream")
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)


## Room-facing wall surfaces + baseboards, wainscot, chair rail and crown molding.
func _linings_and_moldings() -> void:
	var base_prof := ML.prof([0.022, 0.0, 0.022, 0.12, 0.017, 0.14, 0.012, 0.155, 0.0, 0.165])
	var rail_prof := ML.prof([0.0, -0.035, 0.02, -0.028, 0.032, 0.0, 0.02, 0.028, 0.0, 0.035])
	var crown_prof := ML.prof([0.0, -0.28, 0.025, -0.25, 0.05, -0.2, 0.1, -0.14, 0.16, -0.07, 0.2, -0.04, 0.24, 0.0])
	for id in ROOMS:
		var info: Dictionary = ROOMS[id]
		var r := rect(id)
		var lvl: int = info["lvl"]
		var y0 := ly(lvl)
		var ch: float = y0 + info["ceil"]
		if id == "lobby":
			ch = y0 + LEVELS[0]["wall"] - 0.3 # atrium walls run up to the balcony floor
		var edges := [
			["x", r.position.y, r.position.x, r.end.x, Vector3(0, 0, 1), 0.0],
			["x", r.end.y, r.position.x, r.end.x, Vector3(0, 0, -1), 180.0],
			["z", r.position.x, r.position.y, r.end.y, Vector3(1, 0, 0), 90.0],
			["z", r.end.x, r.position.y, r.end.y, Vector3(-1, 0, 0), -90.0],
		]
		for e in edges:
			var axis: String = e[0]
			var c: float = e[1]
			var a: float = e[2] + T / 2.0
			var b: float = e[3] - T / 2.0
			var inward: Vector3 = e[4]
			var theta: float = e[5]
			var openings := _openings_on(axis, c, e[2], e[3], lvl)
			for piece in _cut(a, b, y0, ch, openings):
				_lining(axis, c, inward, piece, info["wall"], 0.006)
			if info["wainscot"]:
				for piece in _cut(a, b, y0, y0 + 1.05, openings):
					_lining(axis, c, inward, piece, "dark_wood", 0.02)
			_molding_runs(axis, c, a, b, inward, theta, openings, y0, base_prof, "dark_wood_obj" if info["wainscot"] else info["wall"])
			if info["wainscot"]:
				_molding_runs(axis, c, a, b, inward, theta, openings, y0 + 1.05, rail_prof, "dark_wood_obj")
			if info["crown"]:
				_molding_runs(axis, c, a, b, inward, theta, openings, ch, crown_prof, "plaster_white")


func _lining(axis: String, c: float, inward: Vector3, piece: Array, mat: String, depth: float) -> void:
	var u0: float = piece[0]
	var u1: float = piece[1]
	var y0: float = piece[2]
	var y1: float = piece[3]
	if u1 - u0 < 0.01 or y1 - y0 < 0.01:
		return
	var off := T / 2.0 + depth / 2.0
	var size := Vector3(u1 - u0, y1 - y0, depth) if axis == "x" else Vector3(depth, y1 - y0, u1 - u0)
	var pos := Vector3((u0 + u1) / 2.0, (y0 + y1) / 2.0, c) if axis == "x" else Vector3(c, (y0 + y1) / 2.0, (u0 + u1) / 2.0)
	pos += inward * off
	mesh_at(P.bbox(size, 0.001, mat), pos, Vector3.ZERO, null, "Lining")


func _molding_runs(axis: String, c: float, a: float, b: float, inward: Vector3, theta: float, openings: Array, y: float, prof: PackedVector2Array, mat: String) -> void:
	var cuts := []
	for o in openings:
		if y >= o[2] - 0.01 and y <= o[3] + 0.3:
			cuts.append(o)
	var runs := []
	var cur := a
	var k_cur := -1.0
	for o in cuts:
		if o[0] > cur + 0.02:
			runs.append([cur, o[0], k_cur, 0.0])
		cur = o[1]
		k_cur = 0.0
	if b > cur + 0.02:
		runs.append([cur, b, k_cur, -1.0])
	for run in runs:
		var u0: float = run[0]
		var u1: float = run[1]
		var length := u1 - u0
		var dir := Vector3(cos(deg_to_rad(theta)), 0, -sin(deg_to_rad(theta)))
		var along_positive := dir.x + dir.z > 0.0
		var start_u := u0 if along_positive else u1
		var k_start: float = run[2] if along_positive else run[3]
		var k_end: float = run[3] if along_positive else run[2]
		var origin := Vector3(start_u, y, c) if axis == "x" else Vector3(c, y, start_u)
		origin += inward * (T / 2.0 + 0.004)
		var key := "mold_%s_%s_%s_%s_%s" % [length, k_start, k_end, mat, prof]
		var mesh: Mesh = P.cached(key, func() -> Mesh: return ML.extrude(prof, length, P.M[mat], k_start, k_end))
		mesh_at(mesh, origin, Vector3(0, theta, 0), null, "Molding")


func _door_frames() -> void:
	var casing := ML.prof([0.0, 0.0, 0.0, 0.03, 0.05, 0.03, 0.08, 0.02, 0.1, 0.0])
	for d in DOORS:
		var axis: String = d[0]
		var c: float = d[1]
		var y0 := ly(int(d[4]))
		var w: float = d[3] - d[2]
		var mid: float = (d[2] + d[3]) / 2.0
		var frame_mesh: Mesh = P.cached("casing_%s" % w, func() -> Mesh: return ML.frame(w, DOOR_H * 2.0, casing, P.M["dark_wood_obj"]))
		for side in [-1, 1]:
			var pos := Vector3(mid, y0, c + side * T / 2.0) if axis == "x" else Vector3(c + side * T / 2.0, y0, mid)
			var rot := (0.0 if side > 0 else 180.0) if axis == "x" else (90.0 if side > 0 else -90.0)
			mesh_at(frame_mesh, pos, Vector3(0, rot, 0), null, "Casing")
		var jamb := Vector3(0.03, DOOR_H, T) if axis == "x" else Vector3(T, DOOR_H, 0.03)
		for end in [d[2], d[3]]:
			var p := Vector3(end, y0 + DOOR_H / 2.0, c) if axis == "x" else Vector3(c, y0 + DOOR_H / 2.0, end)
			mesh_at(P.bbox(jamb, 0.003, "dark_wood_obj"), p, Vector3.ZERO, null, "Jamb")
		var head := Vector3(w, 0.03, T) if axis == "x" else Vector3(T, 0.03, w)
		mesh_at(P.bbox(head, 0.003, "dark_wood_obj"), Vector3(mid, y0 + DOOR_H, c) if axis == "x" else Vector3(c, y0 + DOOR_H, mid), Vector3.ZERO, null, "DoorHead")
		var sill := Vector3(w, 0.02, T + 0.06) if axis == "x" else Vector3(T + 0.06, 0.02, w)
		mesh_at(P.bbox(sill, 0.005, "dark_wood_obj"), Vector3(mid, y0 + 0.01, c) if axis == "x" else Vector3(c, y0 + 0.01, mid), Vector3.ZERO, null, "Threshold")
		if d[5] != "":
			_locked_door(d[5], axis, c, d[2], d[3], y0)


func _locked_door(n: String, axis: String, c: float, a: float, b: float, y0: float) -> void:
	var w := b - a
	var hinge := Node3D.new()
	hinge.name = n
	hinge.position = Vector3(a, y0, c) if axis == "x" else Vector3(c, y0, a)
	hinge.rotation_degrees.y = 0.0 if axis == "x" else -90.0
	museum.add_child(hinge)
	_attach(hinge, "door")
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 16 # doors: block player/enemies, ignored by navigation baking
	hinge.add_child(body)
	var leaf := MeshInstance3D.new()
	leaf.name = "Leaf"
	leaf.mesh = P.bbox(Vector3(w - 0.02, DOOR_H - 0.02, 0.06), 0.01, "dark_wood_obj")
	leaf.position = Vector3(w / 2.0, DOOR_H / 2.0, 0)
	body.add_child(leaf)
	for py in [0.7, 1.9]:
		var panel := MeshInstance3D.new()
		panel.name = "Panel"
		panel.mesh = P.bbox(Vector3(w * 0.7, 0.8, 0.08), 0.02, "dark_wood_obj")
		panel.position = Vector3(w / 2.0, py, 0)
		body.add_child(panel)
	var knob := MeshInstance3D.new()
	knob.name = "Knob"
	knob.mesh = P.sphere(0.04, "brass")
	knob.position = Vector3(w - 0.12, 1.0, 0.06)
	body.add_child(knob)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var sh := BoxShape3D.new()
	sh.size = Vector3(w, DOOR_H, 0.12)
	cs.shape = sh
	cs.position = Vector3(w / 2.0, DOOR_H / 2.0, 0)
	body.add_child(cs)
	for side in [-1.0, 1.0]:
		var sign := Label3D.new()
		sign.name = "Sign" if side < 0 else "Sign2"
		sign.text = "CLOSED\nFOR RENOVATION" if n != "DoorVault" else "PRIVATE\nDO NOT ENTER"
		sign.font = load("res://fonts/Cinzel-Bold.woff2")
		sign.font_size = 64
		sign.pixel_size = 0.0016
		sign.modulate = Color(0.85, 0.2, 0.15)
		sign.outline_size = 8
		sign.position = Vector3(w / 2.0, 1.45, side * 0.05)
		sign.rotation_degrees.y = 180 if side < 0 else 0
		sign.double_sided = false
		body.add_child(sign)
	var it := interactable("Use", "locked_door", "Locked", Vector3(w / 2.0, 1.2, 0), Vector3(w, 2.0, 0.6), Vector3.ZERO, true, body)
	it.name = "Use"


func _windows() -> void:
	var casing := ML.prof([0.0, 0.0, 0.0, 0.03, 0.06, 0.03, 0.09, 0.018, 0.11, 0.0])
	for wnd in WINDOWS:
		var axis: String = wnd[0]
		var c: float = wnd[1]
		var a: float = wnd[2]
		var b: float = wnd[3]
		var y0: float = ly(int(wnd[6])) + float(wnd[4])
		var y1: float = ly(int(wnd[6])) + float(wnd[5])
		var w := b - a
		var h := y1 - y0
		var mid := (a + b) / 2.0
		var ym := (y0 + y1) / 2.0
		var frame_mesh: Mesh = P.cached("wcasing_%s_%s" % [w, h], func() -> Mesh: return ML.frame(w, h, casing, P.M["dark_wood_obj"]))
		for side in [-1, 1]:
			var pos := Vector3(mid, ym, c + side * T / 2.0) if axis == "x" else Vector3(c + side * T / 2.0, ym, mid)
			var rot := (0.0 if side > 0 else 180.0) if axis == "x" else (90.0 if side > 0 else -90.0)
			mesh_at(frame_mesh, pos, Vector3(0, rot, 0), null, "WindowCasing")
		var rot_y := 0.0 if axis == "x" else 90.0
		var center := Vector3(mid, ym, c) if axis == "x" else Vector3(c, ym, mid)
		var holder := Node3D.new()
		holder.name = _uname("Window")
		holder.position = center
		holder.rotation_degrees.y = rot_y
		holder.add_to_group("windows", true)
		visual.add_child(holder)
		var glass := mesh_at(ML.plane(w, h, P.M["glass"]), Vector3.ZERO, Vector3.ZERO, holder, "Glass")
		glass.name = "Glass"
		mesh_at(P.bbox(Vector3(0.05, h, 0.08), 0.008, "dark_wood_obj"), Vector3.ZERO, Vector3.ZERO, holder, "Mullion")
		for k in [0.33, 0.66]:
			mesh_at(P.bbox(Vector3(w, 0.04, 0.07), 0.008, "dark_wood_obj"), Vector3(0, -h / 2.0 + h * k, 0), Vector3.ZERO, holder, "Transom")
		mesh_at(P.bbox(Vector3(w + 0.2, 0.05, T + 0.12), 0.01, "dark_wood_obj"), Vector3(0, -h / 2.0 - 0.02, 0), Vector3.ZERO, holder, "Sill")
		for end in [-w / 2.0, w / 2.0]:
			mesh_at(P.bbox(Vector3(0.03, h, T), 0.003, "dark_wood_obj"), Vector3(end, 0, 0), Vector3.ZERO, holder, "WJamb")
		mesh_at(P.bbox(Vector3(w, 0.03, T), 0.003, "dark_wood_obj"), Vector3(0, h / 2.0, 0), Vector3.ZERO, holder, "WHead")


func _outside() -> void:
	mesh_at(ML.bevel_box(Vector3(200, 0.1, 200), 0.001, P.M["ground"], 1), Vector3(4, -0.25, -4), Vector3.ZERO, null, "Ground")
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var spots := []
	for i in 14:
		spots.append(Vector3(r.randf_range(34, 60), 0, r.randf_range(-30, 22)))
		spots.append(Vector3(r.randf_range(-50, -26), 0, r.randf_range(-30, 18)))
		spots.append(Vector3(r.randf_range(-24, 26), 0, r.randf_range(26, 50)))
	for i in spots.size():
		var tree := P.pine_tree(r.randf_range(10.0, 17.0), i)
		put(tree, spots[i], r.randf_range(0, 360))
	# Skylight lantern over the atrium (x -4..4, z -3..3), on top of the upper floor
	var sky := _group(visual, "Skylight")
	var top := ly(1) + 3.8 + 0.3
	for i in 9:
		var x := -4.0 + i
		mesh_at(P.bbox(Vector3(0.08, 0.12, 6.0), 0.01, "steel_dark"), Vector3(x, top + 0.9, 0), Vector3.ZERO, sky, "Rafter")
	for z in [-3.0, -1.5, 0.0, 1.5, 3.0]:
		mesh_at(P.bbox(Vector3(8.0, 0.1, 0.08), 0.01, "steel_dark"), Vector3(0, top + 0.9, z), Vector3.ZERO, sky, "Purlin")
	mesh_at(ML.plane(8.0, 6.0, P.M["glass"]), Vector3(0, top + 0.97, 0), Vector3(-90, 0, 0), sky, "SkyGlass")
	for side in [-1, 1]:
		mesh_at(P.bbox(Vector3(8.3, 1.0, 0.15), 0.01, "plaster_white"), Vector3(0, top + 0.4, side * 3.07), Vector3.ZERO, sky, "Curb")
		mesh_at(P.bbox(Vector3(0.15, 1.0, 6.3), 0.01, "plaster_white"), Vector3(side * 4.07, top + 0.4, 0), Vector3.ZERO, sky, "Curb")


func _rooms() -> void:
	var group := _group(museum, "Rooms")
	for id in ROOMS:
		var r := rect(id)
		var lvl: int = ROOMS[id]["lvl"]
		var a := Area3D.new()
		a.name = "Room_" + id
		_attach(a, "room", {"room_id": id, "level": lvl})
		a.collision_layer = 0
		a.collision_mask = 2
		a.monitorable = false
		a.reverb_bus_enabled = true
		a.reverb_bus_name = "Reverb"
		a.reverb_bus_amount = ROOMS[id]["reverb"]
		a.reverb_bus_uniformity = 0.6
		var band: float = LEVELS[lvl]["wall"]
		a.position = Vector3(r.get_center().x, ly(lvl) + band / 2.0, r.get_center().y)
		group.add_child(a)
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		var sh := BoxShape3D.new()
		sh.size = Vector3(r.size.x - 0.1, band - 0.2, r.size.y - 0.1)
		cs.shape = sh
		a.add_child(cs)
		# Reflection probe per room: much better marble / metal / glass
		var probe := ReflectionProbe.new()
		probe.name = "Probe_" + id
		probe.size = Vector3(r.size.x, minf(band, 5.0), r.size.y)
		probe.position = a.position
		probe.box_projection = true
		probe.interior = true
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
		probe.ambient_color = Color(0.05, 0.05, 0.07)
		probe.max_distance = 40.0
		visual.add_child(probe)


## Straight staircase from bottom (x, y_bottom, z_bottom) climbing `rise` over `run` toward local -Z (rotated by rot_y).
func staircase(bottom: Vector3, width: float, run: float, rise: float, rot_y: float, mat: String) -> void:
	var holder := Node3D.new()
	holder.name = _uname("Staircase")
	holder.position = bottom
	holder.rotation_degrees.y = rot_y
	visual.add_child(holder)
	var st := P.stairs(width, run, rise, mat)
	holder.add_child(st)
	var length := sqrt(run * run + rise * rise)
	var ang := atan2(rise, run)
	var thick := 0.3
	var basis := Basis(Vector3.UP, deg_to_rad(rot_y)) * Basis(Vector3.RIGHT, ang)
	var center_local := Vector3(0, rise / 2.0 - thick / 2.0 / cos(ang) + 0.06, -run / 2.0)
	var center := bottom + Basis(Vector3.UP, deg_to_rad(rot_y)) * center_local
	var body := StaticBody3D.new()
	body.name = _uname("StairRamp")
	body.transform = Transform3D(basis, center)
	level.add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(width, thick, length + 0.4)
	cs.shape = sh
	body.add_child(cs)
	# Invisible side guards so nobody walks off the side of the stairs
	for sx in [-1, 1]:
		var guard := StaticBody3D.new()
		guard.name = _uname("StairGuard")
		var gc := Basis(Vector3.UP, deg_to_rad(rot_y)) * Vector3(sx * (width / 2.0 + 0.08), rise / 2.0 + 0.6, -run / 2.0)
		guard.transform = Transform3D(basis, bottom + gc)
		guard.collision_layer = 1
		level.add_child(guard)
		var gcs := CollisionShape3D.new()
		var gsh := BoxShape3D.new()
		gsh.size = Vector3(0.12, 1.4, length)
		gcs.shape = gsh
		guard.add_child(gcs)


# ------------------------------------------------------------------ rooms ---

func _lobby() -> void:
	# Atrium: balcony columns, grand staircase, chandeliers hanging from the upper ceiling
	for x in [-8.5, 8.5]:
		for z in [-6.5, 0.0, 6.5]:
			solid(P.column(5.2), Vector3(x, 0, z), Vector3(0.9, 5.2, 0.9))
	mesh_at(P.bbox(Vector3(3.8, 0.012, 5.2), 0.004, "velvet"), Vector3(0, 0.006, 7.3), Vector3.ZERO, null, "Rug")
	staircase(Vector3(0, 0, 4.5), 3.6, 11.0, 5.5, 0.0, "marble")
	var block := Node3D.new()
	block.name = "StairBlock"
	block.position = Vector3(0, 0, 5.3)
	museum.add_child(block)
	_attach(block, "barrier")
	var bb := StaticBody3D.new()
	bb.name = "Body"
	bb.collision_layer = 16
	block.add_child(bb)
	var bcs := CollisionShape3D.new()
	var bsh := BoxShape3D.new()
	bsh.size = Vector3(4.2, 1.4, 0.3)
	bcs.shape = bsh
	bcs.position = Vector3(0, 0.7, 0)
	bb.add_child(bcs)
	for sx in [-2.05, 2.05]:
		var post := P.rope_post()
		post.position = Vector3(sx, 0, 0)
		block.add_child(post)
	var rp := P.rope(Vector3(-2.05, 0.92, 0), Vector3(2.05, 0.92, 0))
	block.add_child(rp)
	var bl := label("UPPER FLOOR CLOSED\n(staff only, which is you, but still no)", Vector3(0, 1.25, 0.05), 180, 0.0011, Color(0.95, 0.85, 0.6), block)
	bl.double_sided = true
	# Knight on display near the office
	var kp := Vector3(-5.5, 0, 6.0)
	for o in [Vector3(-1.3, 0, -1.3), Vector3(1.3, 0, -1.3), Vector3(-1.3, 0, 1.3), Vector3(1.3, 0, 1.3)]:
		put(P.rope_post(), kp + o)
	put(P.rope(kp + Vector3(-1.3, 0.92, -1.3), kp + Vector3(1.3, 0.92, -1.3)), Vector3.ZERO)
	put(P.rope(kp + Vector3(-1.3, 0.92, -1.3), kp + Vector3(-1.3, 0.92, 1.3)), Vector3.ZERO)
	put(P.rope(kp + Vector3(1.3, 0.92, -1.3), kp + Vector3(1.3, 0.92, 1.3)), Vector3.ZERO)
	plaque("SIR CLANKSWORTH. Suit of armour, c. 1450. Empty. Definitely empty. Please do not make eye contact. Actually, do.", kp + Vector3(1.9, 1.0, 1.3), 0.0)
	put(P.pedestal(0.3, 0.9, "brass"), kp + Vector3(1.9, 0, 1.25))
	light_spot(Vector3(-5.5, 4.9, 7.5), kp + Vector3(0, 1.2, 0), Color(1.0, 0.9, 0.75), 6.0, 7.0, 28.0, "lobby", true)
	# Golden Duck
	solid(P.pedestal(0.7, 1.1, "marble"), Vector3(-5, 0, 1.5), Vector3(0.82, 1.1, 0.82))
	put(P.display_case(0.8, 0.8, 0.0, 0.6), Vector3(-5, 1.1, 1.5))
	plaque("THE GOLDEN DUCK OF UR-QUACK. Gold, c. 2400 BC. The most valuable object in the museum. Do not lose it.", Vector3(-5, 0.75, 1.92), 0.0, 0.45)
	light_spot(Vector3(-5, 9.2, 1.5), Vector3(-5, 1.2, 1.5), Color(1.0, 0.85, 0.6), 7.0, 11.0, 12.0, "lobby", false)
	var ped := interactable("DuckPedestal", "duck_pedestal", "Return the Golden Duck", Vector3(-5, 0, 1.5), Vector3(1.0, 1.6, 1.0), Vector3(0, 0.9, 0), false, museum)
	ped.name = "DuckPedestal"
	var duck := interactable("Duck", "duck", "Take the Golden Duck", Vector3(-5, 1.12, 1.5), Vector3(0.5, 0.5, 0.5), Vector3(0, 0.25, 0), false, museum)
	duck.name = "Duck"
	duck.add_child(P.golden_duck())
	# Benches, info desk, clock, gift shop, vending machine, signage
	solid(P.bench(2.2), Vector3(5, 0, 2), Vector3(2.2, 0.55, 0.5))
	solid(P.bench(2.2), Vector3(5, 0, -1.5), Vector3(2.2, 0.55, 0.5))
	solid(P.desk(), Vector3(7.5, 0, 7.2), Vector3(2.0, 0.8, 0.9), 180)
	label("INFORMATION\n(none available)", Vector3(7.5, 1.0, 6.7), 180, 0.0016)
	var clock := P.grandfather_clock()
	solid(clock, Vector3(-11.4, 0, 2.5), Vector3(0.6, 2.3, 0.45), 90)
	_attach(clock.get_node("Pendulum"), "pendulum")
	emitter("clock_tick", Vector3(-11.3, 1.8, 2.5), -6.0, 4.0)
	solid(P.rubber_duck_crate(), Vector3(10.6, 0, -8.6), Vector3(0.6, 0.6, 0.6))
	solid(P.shelf(1.6, 1.6, 0.4), Vector3(11.6, 0, -6.5), Vector3(0.45, 1.6, 1.6), -90)
	label("GIFT SHOP\nHonesty box. Squeaky ducks: 1 each.", Vector3(10.6, 1.25, -8.25), 180, 0.0011)
	interactable("DuckCrate", "take_ducks", "Take squeaky rubber ducks", Vector3(10.6, 0.7, -8.6), Vector3(0.7, 0.5, 0.7))
	solid(P.vending_machine(), Vector3(-11.4, 0, -3.5), Vector3(0.75, 1.9, 0.9), 90)
	interactable("Vending", "vending", "Buy a snack", Vector3(-10.9, 1.1, -3.5), Vector3(0.4, 1.0, 0.8))
	solid(P.pedestal(0.6, 1.0, "marble"), Vector3(-7, 0, -8.0), Vector3(0.72, 1.0, 0.72))
	put(P.urn("lapis"), Vector3(-7, 1.0, -8.0))
	plaque("ANCIENT SPOON (missing). It was here a minute ago.", Vector3(-7, 0.6, -7.62), 0.0, 0.4)
	solid(P.pedestal(0.6, 1.0, "marble"), Vector3(7, 0, -8.0), Vector3(0.72, 1.0, 0.72))
	put(P.vase_amphora(), Vector3(7, 1.0, -8.0))
	label("WELCOME TO THE PEMBERTON MUSEUM\nOF QUESTIONABLE HISTORY", Vector3(0, 3.7, -9.83), 0, 0.0032, Color(0.85, 0.7, 0.35))
	label("SECURITY", Vector3(0, 3.05, 9.83), 180, 0.002)
	label("STORAGE  &  BASEMENT", Vector3(-11.83, 3.05, 0), 90, 0.002)
	label("GALLERY OF FINE-ISH ART", Vector3(-6, 3.05, -9.83), 0, 0.002)
	label("EGYPTIAN HALL  -  QUIET PLEASE", Vector3(6, 3.05, -9.83), 0, 0.002)
	label("DINOSAURS", Vector3(11.83, 3.05, 0), -90, 0.002)
	label("HALL OF CURIOSITIES", Vector3(8, 3.05, 9.83), 180, 0.002)
	label("WAX FIGURES", Vector3(-8, 3.05, 9.83), 180, 0.002)
	for p in [[Vector3(0, 2.95, 9.8), 180.0], [Vector3(-11.8, 2.95, 0), 90.0], [Vector3(11.8, 2.95, 0), -90.0]]:
		put(P.exit_sign(), p[0], p[1])
	put(P.fire_extinguisher(), Vector3(11.6, 0, 6.0))
	for x in [-4.5, 4.5]:
		put(P.chandelier(3.0), Vector3(x, 9.3, 1.5))
		light_omni(Vector3(x, 5.8, 1.5), Color(1.0, 0.75, 0.48), 3.6, 15.0, "lobby", false)
	for p in [[Vector3(-11.8, 2.6, -6), 90.0], [Vector3(11.8, 2.6, -3), -90.0], [Vector3(-11.8, 2.6, 6), 90.0], [Vector3(11.8, 2.6, 4), -90.0]]:
		put(P.sconce(), p[0], p[1])
		var dir := Vector3(sin(deg_to_rad(p[1])), 0, cos(deg_to_rad(p[1])))
		light_omni(p[0] + dir * 0.3 + Vector3(0, 0.1, 0), Color(1.0, 0.7, 0.45), 1.1, 6.0, "lobby")
	for z in [-8.3, 8.3]:
		light_spot(Vector3(0, 4.9, z), Vector3(0, 0, z), Color(1.0, 0.82, 0.6), 2.0, 6.0, 60.0, "lobby")
	emergency(Vector3(0, 4.6, 9.6), "lobby")
	emergency(Vector3(0, 4.6, -9.6), "lobby")


func _balcony() -> void:
	var y := ly(1)
	# Balustrade around the atrium (gap at the top of the grand staircase)
	var edges := [[Vector3(-8.5, y, -6.5), Vector3(-2.0, y, -6.5)], [Vector3(2.0, y, -6.5), Vector3(8.5, y, -6.5)],
		[Vector3(-8.5, y, 6.5), Vector3(8.5, y, 6.5)], [Vector3(-8.5, y, -6.5), Vector3(-8.5, y, 6.5)], [Vector3(8.5, y, -6.5), Vector3(8.5, y, 6.5)]]
	for e in edges:
		put(P.railing(e[0], e[1]), Vector3.ZERO)
		var mid: Vector3 = (e[0] + e[1]) / 2.0
		var length: float = e[0].distance_to(e[1])
		var along_x: bool = absf(e[0].z - e[1].z) < 0.01
		collider(Vector3(length, 1.1, 0.15) if along_x else Vector3(0.15, 1.1, length), mid + Vector3(0, 0.55, 0))
	label("LIBRARY", Vector3(-6, y + 2.95, -9.83), 0, 0.0018)
	label("PLANETARIUM", Vector3(6, y + 2.95, -9.83), 0, 0.0018)
	label("NATURAL HISTORY", Vector3(11.83, y + 2.95, -6.4), -90, 0.0018)
	label("ARMOURY", Vector3(11.83, y + 2.95, 4), -90, 0.0018)
	label("RESTORATION WORKSHOP", Vector3(-11.83, y + 2.95, 0), 90, 0.0018)
	label("DIRECTOR", Vector3(0, y + 2.95, 9.83), 180, 0.0018)
	solid(P.bench(2.0), Vector3(-10.4, y, -3.5), Vector3(0.5, 0.55, 2.0), 90)
	solid(P.bench(2.0), Vector3(10.4, y, -1.0), Vector3(0.5, 0.55, 2.0), 90)
	for p in [Vector3(-10.5, y, 8.5), Vector3(10.5, y, 8.5), Vector3(-10.5, y, -8.5), Vector3(10.5, y, -8.5)]:
		solid(P.pedestal(0.6, 1.1, "marble"), p, Vector3(0.7, 1.1, 0.7))
		put(P.sheet_statue(1.2, int(p.x * 3 + p.z)), p + Vector3(0, 1.1, 0))
	for p in [[Vector3(-11.8, y + 2.3, -4), 90.0], [Vector3(11.8, y + 2.3, 0), -90.0], [Vector3(-11.8, y + 2.3, 5), 90.0], [Vector3(-3, y + 2.3, -9.8), 0.0], [Vector3(3, y + 2.3, 9.8), 180.0]]:
		put(P.sconce(), p[0], p[1])
		var dir := Vector3(sin(deg_to_rad(p[1])), 0, cos(deg_to_rad(p[1])))
		light_omni(p[0] + dir * 0.3 + Vector3(0, 0.1, 0), Color(1.0, 0.7, 0.45), 1.0, 6.0, "balcony")
	emergency(Vector3(0, y + 3.5, 9.6), "balcony")


func _office() -> void:
	var spawn := marker(museum, "PlayerSpawn", Vector3(0, 0.05, 12.2), 180)
	spawn.name = "PlayerSpawn"
	solid(P.desk(), Vector3(0, 0, 15.9), Vector3(2.0, 0.8, 0.9))
	put(P.chair(), Vector3(0, 0, 15.0), 180)
	for x in [-0.55, 0.0, 0.55]:
		put(P.crt_monitor(), Vector3(x, 0.785, 16.05), 180)
	label("CCTV", Vector3(0, 1.3, 16.32), 180, 0.0012)
	var lamp := P.desk_lamp()
	put(lamp, Vector3(0.85, 0.785, 15.9), 200)
	light_spot(Vector3(0.85, 1.15, 15.85), Vector3(0.5, 0.78, 15.6), Color(1.0, 0.8, 0.55), 2.5, 2.5, 50.0, "", true, "")
	var fl := interactable("Flashlight", "flashlight", "Take the flashlight", Vector3(-0.7, 0.785, 15.7), Vector3(0.5, 0.35, 0.5), Vector3(0, 0.12, 0))
	var torch := Node3D.new()
	torch.name = "Model"
	torch.rotation_degrees = Vector3(0, 30, 90)
	torch.position = Vector3(0, 0.05, 0)
	fl.add_child(torch)
	P.part(torch, "Body", P.cyl(0.03, 0.03, 0.22, "black_plastic", 12))
	P.part(torch, "Head", P.cyl(0.03, 0.045, 0.06, "metal", 14), Vector3(0, 0.22, 0))
	# Punch clock (east wall)
	var clock := P.punch_clock()
	put(clock, Vector3(3.85, 1.4, 12.0), -90)
	interactable("PunchClock", "clock_in", "Clock in", Vector3(3.55, 1.4, 12.0), Vector3(0.5, 0.7, 0.6))
	label("PUNCH CLOCK", Vector3(3.84, 1.8, 12.0), -90, 0.0012)
	# Rules poster (west wall)
	mesh_at(P.bbox(Vector3(0.02, 1.5, 1.1), 0.003, "porcelain"), Vector3(-3.83, 1.65, 12.5), Vector3.ZERO, null, "Poster")
	var rules := "MUSEUM RULES FOR NIGHT STAFF\n\n" + "\n\n".join(preload("res://autoload/shift.gd").RULES)
	var rl := label(rules, Vector3(-3.815, 1.65, 12.5), 90, 0.00085, Color(0.1, 0.08, 0.06))
	rl.width = 1150
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	interactable("RulesPoster", "rules", "Read the Museum Rules", Vector3(-3.6, 1.65, 12.5), Vector3(0.4, 1.5, 1.2))
	# Coffee, locker, radio, corkboard
	solid(P.coffee_machine(), Vector3(-3.4, 0, 16.4), Vector3(0.55, 0.9, 0.45), 180)
	interactable("Coffee", "coffee", "Drink terrible coffee", Vector3(-3.4, 0.7, 16.1), Vector3(0.6, 0.6, 0.4))
	solid(P.locker(), Vector3(3.3, 0, 16.4), Vector3(0.6, 1.95, 0.55), 180)
	interactable("HideOffice", "hide", "Hide in locker", Vector3(3.3, 1.0, 16.0), Vector3(0.6, 1.8, 0.3))
	marker(museum, "HideOfficeView", Vector3(3.3, 1.55, 16.42), 0)
	solid(P.shelf(1.2, 1.8, 0.4), Vector3(-3.6, 0, 14.0), Vector3(0.45, 1.8, 1.2), 90)
	emitter("office_radio", Vector3(-3.5, 1.2, 14.0), -10.0, 3.0)
	mesh_at(P.bbox(Vector3(1.2, 0.8, 0.03), 0.01, "crate"), Vector3(1.8, 1.7, 16.83), Vector3.ZERO, null, "Corkboard")
	interactable("Cctv", "cctv", "Check the cameras", Vector3(0, 1.0, 15.9), Vector3(1.6, 0.5, 0.5))
	# Fluorescent ceiling panel (on its own generator: no group, survives blackouts)
	mesh_at(P.bbox(Vector3(1.2, 0.04, 0.6), 0.01, "e_bulb_cold"), Vector3(0, 2.98, 13.5))
	var main := light_omni(Vector3(0, 2.8, 13.5), Color(0.9, 0.95, 1.0), 2.6, 9.0, "", true, "")
	main.add_to_group("office_light", true)
	_attach(main, "flicker", {"strength": 0.08})


func _storage() -> void:
	solid(P.crate(1.0), Vector3(-20.5, 0, -4.5), Vector3(1.0, 1.0, 1.0), 10)
	solid(P.crate(0.9), Vector3(-20.4, 1.0, -4.4), Vector3(0.9, 0.9, 0.9), 35)
	solid(P.crate(1.1), Vector3(-19.2, 0, -4.8), Vector3(1.1, 1.1, 1.1), -5)
	solid(P.crate(1.2), Vector3(-20.6, 0, 8.4), Vector3(1.2, 1.2, 1.2), 20)
	solid(P.crate(0.8), Vector3(-14.0, 0, 8.8), Vector3(0.8, 0.8, 0.8), 0)
	solid(P.barrel(), Vector3(-13.2, 0, -5.0), Vector3(0.65, 0.9, 0.65))
	solid(P.barrel(), Vector3(-13.9, 0, -5.2), Vector3(0.65, 0.9, 0.65))
	solid(P.shelf(3.0, 2.2, 0.6), Vector3(-17.0, 0, -5.45), Vector3(3.0, 2.2, 0.6))
	for k in 4:
		put(P.urn("terracotta" if k % 2 == 0 else "lapis"), Vector3(-17.9 + k * 0.6, 1.17, -5.45))
	put(P.sarcophagus(), Vector3(-15.0, 0.0, 9.4), 180) # a spare one, as you do
	label("LOST & FOUND: 3 umbrellas, 1 sarcophagus lid,\n1 left shoe (size: pharaoh)", Vector3(-17.0, 2.9, -5.83), 0, 0.0014)
	# Stairs down to the basement (floor hole x -21.75..-19.45, z -2.6..6.1)
	staircase(Vector3(-20.6, ly(-1), -2.5), 2.0, 8.5, 4.5, 180.0, "concrete")
	for e in [[Vector3(-19.45, 0, -2.6), Vector3(-19.45, 0, 6.0)], [Vector3(-21.75, 0, -2.6), Vector3(-19.45, 0, -2.6)], [Vector3(-21.75, 0, -2.6), Vector3(-21.75, 0, 6.0)]]:
		put(P.railing(e[0], e[1]), Vector3.ZERO)
		var mid: Vector3 = (e[0] + e[1]) / 2.0
		var length: float = e[0].distance_to(e[1])
		var along_x: bool = absf(e[0].z - e[1].z) < 0.01
		collider(Vector3(length, 1.1, 0.12) if along_x else Vector3(0.12, 1.1, length), mid + Vector3(0, 0.55, 0))
	label("BASEMENT\nBoiler room / Main breaker", Vector3(-19.2, 2.6, 6.5), 180, 0.0016, Color(0.95, 0.8, 0.5))
	solid(P.locker(), Vector3(-12.45, 0, 6.5), Vector3(0.55, 1.95, 0.6), -90)
	interactable("HideStorage", "hide", "Hide in locker", Vector3(-12.85, 1.0, 6.5), Vector3(0.3, 1.8, 0.6))
	marker(museum, "HideStorageView", Vector3(-12.42, 1.55, 6.5), 90)
	put(P.wet_floor_sign(), Vector3(-16, 0, 2), 30)
	put(P.crate(0.4), Vector3(-16.2, 1.17, -5.45), 15)
	label("SPARE BULBS", Vector3(-16.2, 1.45, -5.2), 0, 0.0009)
	interactable("BulbBox", "take_bulbs", "Take spare light bulbs", Vector3(-16.2, 1.3, -5.2), Vector3(0.6, 0.5, 0.6), Vector3.ZERO, false)
	var bulb := light_omni(Vector3(-17, 3.6, 1.5), Color(1.0, 0.82, 0.6), 2.2, 12.0, "storage", true)
	_attach(bulb, "flicker", {"strength": 0.35})
	mesh_at(P.sphere(0.06, "e_bulb"), Vector3(-17, 3.75, 1.5))
	mesh_at(P.cyl(0.006, 0.006, 0.4, "black_plastic", 4), Vector3(-17, 3.8, 1.5))
	emitter("drip", Vector3(-20, 0.2, -3), -8.0, 3.0)
	emergency(Vector3(-17, 3.9, 9.6), "storage")


func _gallery() -> void:
	var paintings := [
		["painting_founder", Vector3(-11.83, 2.3, -16.0), 90.0, Vector2(1.6, 2.0), "SIR ARCHIBALD PEMBERTON, FOUNDER (1871-1931). Collector of curiosities. Owner of one duck."],
		["painting_man", Vector3(-11.83, 2.1, -20.6), 90.0, Vector2(1.0, 1.3), "PORTRAIT OF A MAN WHO SAW SOMETHING. Oil on canvas, 1823."],
		["painting_pear", Vector3(-8.5, 2.1, -21.83), 0.0, Vector2(1.4, 1.1), "STILL LIFE WITH ANGRY PEAR. Artist unknown (in hiding)."],
		["painting_night", Vector3(-4.0, 2.1, -21.83), 0.0, Vector2(1.6, 1.1), "LANDSCAPE, BUT AT NIGHT. It is just black. It was very expensive."],
		["painting_landscape", Vector3(-0.17, 2.1, -12.5), -90.0, Vector2(1.4, 1.0), "THE HILLS ARE WATCHING. Oil on canvas, 1866."],
		["painting_lady", Vector3(-0.17, 2.1, -20.2), -90.0, Vector2(1.0, 1.3), "LADY WITH NO PATIENCE. 1790."],
	]
	for p in paintings:
		var dir := Vector3(sin(deg_to_rad(p[2])), 0, cos(deg_to_rad(p[2])))
		var pt := P.painting(p[3].x, p[3].y, p[0])
		put(pt, p[1] + dir * 0.02, p[2])
		pt.add_to_group("portraits", true)
		var pl := P.picture_light(p[3].x * 0.6)
		put(pl, p[1] + Vector3(0, p[3].y / 2.0 + 0.2, 0) + dir * 0.0, p[2])
		light_spot(p[1] + Vector3(0, p[3].y / 2.0 + 0.2, 0) + dir * 0.35, p[1] - Vector3(0, 0.1, 0), Color(1.0, 0.85, 0.65), 4.0, 4.5, 50.0, "gallery")
		plaque(p[4], p[1] + Vector3(0, -p[3].y / 2.0 - 0.3, 0) + dir * 0.02, p[2], 0.42)
	# The Duchess: the big one, facing the entrance
	var duchess_pos := Vector3(-6.0, 2.4, -21.83)
	var dp := P.painting(1.5, 2.1, "painting_duchess")
	dp.name = "DuchessPainting"
	put(dp, duchess_pos + Vector3(0, 0, 0.02), 0)
	plaque("THE DUCHESS, DISAPPOINTED (1788). She has read your performance review.", duchess_pos + Vector3(0, -1.4, 0.02), 0.0, 0.45)
	light_spot(duchess_pos + Vector3(0, 1.3, 0.45), duchess_pos, Color(1.0, 0.8, 0.6), 3.0, 3.5, 40.0, "gallery")
	# Displays
	solid(P.pedestal(0.7, 1.0), Vector3(-6, 0, -15.5), Vector3(0.82, 1.0, 0.82))
	put(P.urn("lapis"), Vector3(-6, 1.0, -15.5))
	plaque("PRICELESS VASE. Please do not touch. Seriously.", Vector3(-6, 0.6, -15.11), 0.0, 0.4)
	interactable("Vase", "touch_vase", "Touch the Priceless Vase", Vector3(-6, 1.0, -15.5), Vector3(0.5, 0.6, 0.5), Vector3(0, 0.3, 0))
	solid(P.bench(2.4), Vector3(-6, 0, -12.5), Vector3(2.4, 0.55, 0.5))
	solid(P.bench(2.4), Vector3(-6, 0, -18.5), Vector3(2.4, 0.55, 0.5))
	interactable("CheckpointGallery", "checkpoint_gallery", "Scan patrol checkpoint", Vector3(-11.55, 1.4, -11.2), Vector3(0.4, 0.6, 0.5))
	_checkpoint_panel(Vector3(-11.83, 1.4, -11.2), 90)
	interactable("WindowGallery", "close_window", "Close the window", Vector3(-11.6, 2.4, -19.0), Vector3(0.6, 2.8, 1.6), Vector3.ZERO, false)
	interactable("WindowGallery2", "close_window", "Close the window", Vector3(-11.6, 2.4, -14.0), Vector3(0.6, 2.8, 1.6), Vector3.ZERO, false)
	light_omni(Vector3(-6, 4.2, -13), Color(1.0, 0.85, 0.7), 1.4, 10.0, "gallery")
	light_omni(Vector3(-6, 4.2, -19), Color(1.0, 0.85, 0.7), 1.4, 10.0, "gallery")
	emergency(Vector3(-6, 4.6, -10.4), "gallery")


func _checkpoint_panel(pos: Vector3, rot_y: float) -> void:
	var holder := Node3D.new()
	holder.name = _uname("CheckpointPanel")
	holder.position = pos
	holder.rotation_degrees.y = rot_y
	visual.add_child(holder)
	mesh_at(P.bbox(Vector3(0.28, 0.4, 0.06), 0.01, "black_plastic"), Vector3(0, 0, 0.03), Vector3.ZERO, holder, "Box")
	var lamp := mesh_at(P.sphere(0.03, "e_red"), Vector3(0, 0.12, 0.07), Vector3.ZERO, holder, "Lamp")
	lamp.add_to_group("checkpoint_lamps", true)
	label("PATROL\nCHECKPOINT", Vector3(0, -0.05, 0.065), 0, 0.0009, Color(0.85, 0.85, 0.85), holder)


func _egypt() -> void:
	put(P.sarcophagus(), Vector3(6, 0, -21.4))
	collider(Vector3(1.0, 2.2, 0.7), Vector3(6, 1.1, -21.4))
	put(P.sarcophagus(), Vector3(10.2, 0, -21.4), -10)
	collider(Vector3(1.0, 2.2, 0.7), Vector3(10.2, 1.1, -21.4))
	plaque("THE PHARAOH'S NEIGHBOUR. Not a pharaoh. Lived next door to one. LIGHT SLEEPER.", Vector3(7.7, 1.5, -21.83), 0.0, 0.45)
	light_spot(Vector3(6, H - 0.1, -19.5), Vector3(6, 1.2, -21), Color(1.0, 0.75, 0.45), 4.0, 6.0, 25.0, "egypt", true)
	for p in [Vector3(1.6, 0, -19.5), Vector3(10.4, 0, -19.5), Vector3(1.6, 0, -12.5), Vector3(10.4, 0, -12.5)]:
		solid(P.obelisk(H - 0.3), p, Vector3(0.8, H - 0.3, 0.8))
	solid(P.pyramid_model(2.2), Vector3(3.5, 0, -15.5), Vector3(2.4, 1.4, 2.4))
	plaque("MODEL PYRAMID. Scale 1:100. Built by interns.", Vector3(3.5, 0.5, -14.2), 0.0, 0.35)
	put(P.pedestal(0.3, 0.45, "stone_obj"), Vector3(3.5, 0, -14.2))
	solid(P.display_case(1.6, 0.6, 0.85, 0.45), Vector3(8.5, 0, -15.5), Vector3(1.6, 1.3, 0.6))
	for k in 4:
		put(P.canopic_jar(k % 3), Vector3(7.9 + k * 0.4, 0.85, -15.5))
	plaque("CURSED CANOPIC JARS. Contents: classified.", Vector3(8.5, 0.55, -15.19), 0.0, 0.4)
	interactable("Jar", "touch_jar", "Touch the Cursed Canopic Jar", Vector3(8.5, 0.85, -15.5), Vector3(1.5, 0.5, 0.6), Vector3(0, 0.25, 0))
	label("SHHH. NO RUNNING.\nHE'S SLEEPING.", Vector3(2.0, 2.0, -10.17), 180, 0.0022, Color(0.95, 0.75, 0.45))
	interactable("CheckpointEgypt", "checkpoint_egypt", "Scan patrol checkpoint", Vector3(11.55, 1.4, -20.0), Vector3(0.4, 0.6, 0.5))
	_checkpoint_panel(Vector3(11.83, 1.4, -20.0), -90)
	for p in [[Vector3(0.17, 2.4, -13), 90.0], [Vector3(0.17, 2.4, -19), 90.0], [Vector3(11.83, 2.4, -16), -90.0]]:
		put(P.sconce(), p[0], p[1])
		var dir := Vector3(sin(deg_to_rad(p[1])), 0, cos(deg_to_rad(p[1])))
		var torch := light_omni(p[0] + dir * 0.35 + Vector3(0, 0.1, 0), Color(1.0, 0.55, 0.25), 1.7, 9.0, "egypt")
		_attach(torch, "flicker", {"strength": 0.2, "speed": 9.0})
	light_omni(Vector3(6, 4.4, -15), Color(1.0, 0.6, 0.35), 0.7, 10.0, "egypt")
	emergency(Vector3(6, 4.6, -10.4), "egypt")


func _library() -> void:
	var y := ly(1)
	for z in [-21.0, -16.0]:
		solid(P.bookshelf(2.4, 3.0, int(z)), Vector3(-11.6, y, z + 1.5), Vector3(0.45, 3.0, 2.4), 90)
	for k in 5:
		solid(P.bookshelf(2.2, 3.2, 10 + k), Vector3(-10.5 + k * 2.3, y, -21.6), Vector3(2.2, 3.2, 0.45))
	for k in 3:
		solid(P.bookshelf(2.2, 2.4, 30 + k), Vector3(-9.0 + k * 3.0, y, -12.6), Vector3(2.2, 2.4, 0.45), 180)
		solid(P.bookshelf(2.2, 2.4, 40 + k), Vector3(-9.0 + k * 3.0, y, -13.05), Vector3(2.2, 2.4, 0.45))
	solid(P.reading_desk(), Vector3(-7.0, y, -17.5), Vector3(1.6, 0.8, 0.8))
	solid(P.reading_desk(), Vector3(-3.0, y, -17.5), Vector3(1.6, 0.8, 0.8))
	for x in [-7.0, -3.0]:
		light_spot(Vector3(x + 0.5, y + 1.15, -17.65), Vector3(x + 0.2, y + 0.78, -17.4), Color(1.0, 0.85, 0.55), 2.0, 2.5, 50.0, "library", false)
		put(P.chair(), Vector3(x, y, -16.8), 180)
	put(P.globe(), Vector3(-1.2, y, -20.8))
	for i in 3:
		var pos: Vector3 = [Vector3(-9.5, y, -15.5), Vector3(-4.5, y, -19.8), Vector3(-1.3, y, -11.4)][i]
		var pile := P.node("BookPile")
		for k in 4:
			P.part(pile, "Book", P.bbox(Vector3(0.3, 0.05, 0.22), 0.008, "book_%d" % ((i + k) % 6)), Vector3(0, 0.025 + k * 0.05, 0), Vector3(0, k * 23, 0))
		put(pile, pos)
		interactable("Books%d" % (i + 1), "reshelve", "Put the books back", pos, Vector3(0.6, 0.5, 0.6), Vector3(0, 0.2, 0), false)
	label("SILENCE.\nThe books are listening.", Vector3(-0.17, y + 2.4, -12.0), -90, 0.0016)
	put(P.chandelier(1.0), Vector3(-6, y + 3.8, -16))
	light_omni(Vector3(-6, y + 2.6, -16), Color(1.0, 0.72, 0.45), 1.8, 10.0, "library")
	light_omni(Vector3(-6, y + 2.6, -11.5), Color(1.0, 0.72, 0.45), 0.9, 7.0, "library")
	var moths := Node3D.new()
	moths.name = "MothsLibrary"
	moths.position = Vector3(-6, y + 2.2, -16)
	_attach(moths, "moths", {"room_id": "library"})
	museum.add_child(moths)
	interactable("WindowLibrary1", "close_window", "Close the window", Vector3(-11.6, y + 2.1, -19.0), Vector3(0.6, 2.4, 1.4), Vector3.ZERO, false)
	interactable("WindowLibrary2", "close_window", "Close the window", Vector3(-11.6, y + 2.1, -14.0), Vector3(0.6, 2.4, 1.4), Vector3.ZERO, false)
	emergency(Vector3(-6, y + 3.4, -10.4), "library")


func _planetarium() -> void:
	var y := ly(1)
	var center := Vector3(6, y, -16)
	put(P.dome(5.95), center + Vector3(0, 3.4, 0))
	var proj := P.star_projector()
	proj.name = "Projector"
	proj.position = center
	museum.add_child(proj)
	_attach(proj, "spinner", {"speed": 0.06})
	collider(Vector3(1.0, 1.6, 1.0), center + Vector3(0, 0.8, 0))
	for k in 8:
		var a := TAU * k / 8.0 + 0.2
		var p := center + Vector3(cos(a) * 3.6, 0, sin(a) * 3.6)
		solid(P.bench(1.6), p, Vector3(1.6, 0.55, 0.5), -rad_to_deg(a) + 90.0)
	for s in [-1, 1]:
		var sp := SpotLight3D.new()
		sp.name = "StarBeam%d" % (s + 2)
		sp.position = Vector3(s * 0.75, 1.55, 0.15)
		sp.rotation_degrees = Vector3(60, s * 30, 0)
		sp.light_color = Color(0.55, 0.65, 1.0)
		sp.light_energy = 1.6
		sp.spot_range = 9.0
		sp.spot_angle = 50.0
		sp.light_projector = load("res://textures/flashlight_cookie.png")
		sp.light_volumetric_fog_energy = 3.0
		proj.add_child(sp)
	interactable("ProjectorSwitch", "projector", "Turn off the star projector", center + Vector3(0, 1.0, 0.8), Vector3(0.8, 0.8, 0.5), Vector3.ZERO, false)
	plaque("THE PEMBERTON STAR THEATRE. Shows hourly. Nobody books the 3 AM show. Somebody watches it anyway.", Vector3(1.0, y + 1.4, -10.17), 180.0, 0.45)
	var fog := FogVolume.new()
	fog.name = "PlanetariumHaze"
	fog.size = Vector3(11.0, 6.0, 11.0)
	fog.position = center + Vector3(0, 3.0, 0)
	var fm := FogMaterial.new()
	fm.density = 0.06
	fm.albedo = Color(0.45, 0.5, 0.8)
	fog.material = fm
	visual.add_child(fog)
	light_omni(center + Vector3(0, 3.0, 0), Color(0.45, 0.5, 0.9), 0.7, 9.0, "planetarium")
	emergency(Vector3(6, y + 3.2, -10.4), "planetarium")


func _natural() -> void:
	var y := ly(1)
	solid(P.pedestal(1.8, 0.4, "dark_wood_obj"), Vector3(24, y, -11), Vector3(1.9, 0.4, 1.9))
	put(P.bear(), Vector3(24, y + 0.4, -11), 210)
	plaque("MR. SNUGGLES. Grizzly bear, 1911. Name chosen by a child. The bear did not consent.", Vector3(24, y + 0.3, -9.95), 0.0, 0.45)
	light_spot(Vector3(22.5, y + 3.7, -9), Vector3(24, y + 1.8, -11), Color(1.0, 0.85, 0.65), 5.0, 6.0, 32.0, "natural", true)
	solid(P.pedestal(1.6, 0.3, "dark_wood_obj"), Vector3(17, y, -15), Vector3(1.0, 0.3, 1.8))
	put(P.deer(), Vector3(17, y + 0.3, -15), 160)
	put(P.owl(), Vector3(14.0, y, -5.5))
	put(P.owl(), Vector3(28.5, y, -5.0), 200)
	for k in 4:
		put(P.butterfly_case(), Vector3(15.0 + k * 3.5, y + 1.8, -17.83))
	plaque("LEPIDOPTERA COLLECTION. Several specimens escaped in 1974. They never left the building.", Vector3(20.0, y + 1.0, -17.83), 0.0, 0.45)
	solid(P.display_case(1.4, 0.7, 0.9, 0.5), Vector3(20, y, -6), Vector3(1.4, 1.4, 0.7))
	put(P.specimen_jar(0.3), Vector3(19.6, y + 0.9, -6))
	put(P.specimen_jar(0.25), Vector3(20.4, y + 0.9, -6))
	light_omni(Vector3(18, y + 3.2, -11), Color(0.9, 0.95, 0.85), 1.4, 11.0, "natural")
	light_omni(Vector3(26, y + 3.2, -6), Color(0.9, 0.95, 0.85), 1.0, 9.0, "natural")
	var moths := Node3D.new()
	moths.name = "MothsNatural"
	moths.position = Vector3(20, y + 2.2, -11)
	_attach(moths, "moths", {"room_id": "natural"})
	museum.add_child(moths)
	emergency(Vector3(21, y + 3.4, -4.4), "natural")


func _armory() -> void:
	var y := ly(1)
	for k in 4:
		var holder := Node3D.new()
		holder.name = _uname("ArmourDisplay")
		holder.position = Vector3(29.0, y, -2.0 + k * 3.2)
		holder.rotation_degrees.y = 90
		visual.add_child(holder)
		holder.add_child(P.knight_model())
		put(P.pedestal(0.9, 0.12, "stone_obj"), holder.position - Vector3(0, 0.12, 0))
		collider(Vector3(0.9, 2.0, 0.9), holder.position + Vector3(0, 1.0, 0))
		light_spot(holder.position + Vector3(-1.5, 3.6, 0), holder.position + Vector3(0, 1.3, 0), Color(1.0, 0.85, 0.7), 3.0, 5.0, 28.0, "armory")
	plaque("THE CLANKSWORTH FAMILY. Four more suits. Relax. These ones are definitely empty. Probably.", Vector3(27.6, y + 1.2, 8.8), -90.0, 0.45)
	for k in 3:
		solid(P.weapon_rack(), Vector3(14.0 + k * 3.5, y, -3.6), Vector3(1.6, 2.2, 0.35))
	solid(P.cannon(), Vector3(21, y, 3), Vector3(0.7, 1.0, 2.0))
	plaque("CANNON, 1690. Unloaded. We checked twice. Then once more.", Vector3(21, y + 0.4, 4.4), 0.0, 0.4)
	for p in [[Vector3(12.17, y + 3.2, -1.0), 90.0], [Vector3(12.17, y + 3.2, 7.0), 90.0]]:
		put(P.banner("cloth_red"), p[0], p[1])
	light_omni(Vector3(18, y + 3.2, 3), Color(1.0, 0.7, 0.45), 1.6, 12.0, "armory")
	emergency(Vector3(21, y + 3.4, 9.6), "armory")


func _workshop() -> void:
	var y := ly(1)
	solid(P.workbench(), Vector3(-17.5, y, -5.2), Vector3(2.0, 0.95, 0.8))
	solid(P.workbench(), Vector3(-21.4, y, 3.0), Vector3(0.8, 0.95, 2.0), 90)
	put(P.easel(), Vector3(-14.5, y, 3.5), 200)
	for k in 3:
		put(P.sheet_statue(1.9, 100 + k), Vector3(-18.5 + k * 1.6, y, 7.5))
	solid(P.shelf(2.2, 2.0, 0.5), Vector3(-13.0, y, -5.4), Vector3(2.2, 2.0, 0.5))
	for k in 4:
		put(P.urn("wax"), Vector3(-13.8 + k * 0.55, y + 0.12, -5.4))
	label("RESTORATION IN PROGRESS\nDo not unwrap. Do not ask what is under the sheets.", Vector3(-17.0, y + 2.6, -5.83), 0, 0.0014)
	solid(P.locker(), Vector3(-12.45, y, 7.0), Vector3(0.55, 1.95, 0.6), -90)
	interactable("HideWorkshop", "hide", "Hide in locker", Vector3(-12.85, y + 1.0, 7.0), Vector3(0.3, 1.8, 0.6))
	marker(museum, "HideWorkshopView", Vector3(-12.42, y + 1.55, 7.0), 90)
	var lamp := light_omni(Vector3(-17, y + 3.3, 1.5), Color(0.95, 0.95, 1.0), 1.6, 11.0, "workshop", true)
	_attach(lamp, "flicker", {"strength": 0.2})
	emergency(Vector3(-17, y + 3.4, 9.6), "workshop")


func _costume() -> void:
	var y := ly(1)
	var colors := ["cloth_red", "cloth_green", "uniform", "cloth_black", "sheet"]
	for k in 6:
		var holder := Node3D.new()
		holder.name = _uname("Mannequin")
		holder.position = Vector3(-19.5 + (k % 3) * 3.0, y, 12.5 + (k / 3) * 4.0)
		holder.rotation_degrees.y = 180 + k * 37
		visual.add_child(holder)
		holder.add_child(P.mannequin({"top": colors[k % 5], "legs": colors[(k + 2) % 5], "dress": k % 2 == 0}))
		collider(Vector3(0.6, 1.8, 0.6), holder.position + Vector3(0, 0.9, 0))
	for k in 2:
		solid(P.clothes_rack(), Vector3(-9.5, y, 12.0 + k * 5.0), Vector3(1.8, 1.8, 0.5))
	for x in [-19.0, -13.0]:
		put(P.mirror(1.0, 1.8), Vector3(x, y + 1.6, 19.83), 180)
	solid(P.locker(), Vector3(-21.45, y, 18.6), Vector3(0.55, 1.95, 0.6), 90)
	interactable("HideCostume", "hide", "Hide in the wardrobe", Vector3(-21.05, y + 1.0, 18.6), Vector3(0.3, 1.8, 0.6))
	marker(museum, "HideCostumeView", Vector3(-21.48, y + 1.55, 18.6), -90)
	label("COSTUME ARCHIVE\nThe mannequins are not looking at you. They have no faces.", Vector3(-13, y + 2.8, 10.17), 0, 0.0014)
	for x in [-17.0, -10.0]:
		put(P.chandelier(0.6), Vector3(x, y + 3.8, 15))
		light_omni(Vector3(x, y + 2.8, 15), Color(1.0, 0.6, 0.45), 1.4, 9.0, "costume")
	emergency(Vector3(-13, y + 3.4, 10.4), "costume")


func _director() -> void:
	var y := ly(1)
	solid(P.desk(), Vector3(0, y, 15.4), Vector3(2.0, 0.8, 0.9))
	put(P.chair(), Vector3(0, y, 16.3), 0)
	put(P.desk_lamp(), Vector3(-0.7, y + 0.785, 15.5), 160)
	light_spot(Vector3(-0.7, y + 1.15, 15.45), Vector3(-0.3, y + 0.78, 15.2), Color(1.0, 0.8, 0.55), 2.5, 2.5, 50.0, "director", true)
	var photo := P.painting(0.35, 0.45, "photo_brenda")
	put(photo, Vector3(0.6, y + 1.0, 15.65), 200)
	plaque("For Mum. Still waiting. - L.", Vector3(0.6, y + 0.8, 15.5), 200.0, 0.2)
	put(P.camera_item(), Vector3(-0.2, y + 0.785, 15.2))
	interactable("CameraPickup", "camera", "Take the instant camera", Vector3(-0.2, y + 0.785, 15.2), Vector3(0.4, 0.3, 0.4), Vector3(0, 0.1, 0), false)
	for k in 2:
		solid(P.filing_cabinet(), Vector3(-3.4, y, 11.0 + k * 0.6), Vector3(0.6, 1.3, 0.5), 90)
	solid(P.bookshelf(1.8, 2.6, 77), Vector3(3.6, y, 13.0), Vector3(0.45, 2.6, 1.8), -90)
	put(P.painting(1.2, 1.5, "painting_founder"), Vector3(-2.0, y + 2.2, 16.82), 180)
	label("L. HOLLOWAY - MUSEUM DIRECTOR", Vector3(0, y + 2.5, 10.17), 0, 0.0014)
	light_omni(Vector3(0, y + 3.2, 13.5), Color(1.0, 0.8, 0.6), 1.0, 7.0, "director")
	emergency(Vector3(0, y + 3.4, 10.4), "director")


func _toyroom() -> void:
	var y := ly(1)
	var table := Vector3(12, y, 16)
	solid(P.pedestal(1.2, 0.55, "porcelain"), table, Vector3(1.0, 0.55, 1.0))
	for k in 5:
		var a := TAU * k / 5.0
		mesh_at(P.cyl(0.04, 0.05, 0.06, "porcelain", 10), table + Vector3(cos(a) * 0.4, 0.58, sin(a) * 0.4), Vector3.ZERO, null, "Teacup")
	put(P.rocking_horse(), Vector3(6.5, y, 20.5), 30)
	solid(P.dollhouse(), Vector3(18.5, y, 20.8), Vector3(1.0, 1.2, 0.6), 180)
	var train := P.toy_train()
	train.position = Vector3(16, y + 0.01, 13)
	visual.add_child(train)
	_attach(train.get_node("Train"), "spinner", {"speed": 0.35})
	put(P.music_box(), Vector3(5.2, y + 0.9, 11.2))
	solid(P.shelf(2.0, 1.6, 0.4), Vector3(5.0, y, 11.0), Vector3(2.0, 1.6, 0.4))
	for k in 6:
		mesh_at(P.bbox(Vector3(0.2, 0.2, 0.2), 0.02, ["toy_red", "toy_blue", "toy_yellow"][k % 3]), Vector3(8.0 + (k % 3) * 0.35, y + 0.1 + (k / 3) * 0.2, 19.5), Vector3(0, k * 17, 0), null, "Block")
	label("THE TEA PARTY (1902)\nFive porcelain dolls. Please do not join them.", Vector3(12, y + 2.6, 21.83), 180, 0.0015)
	light_spot(Vector3(12, y + 3.7, 14.5), table + Vector3(0, 0.6, 0), Color(1.0, 0.85, 0.75), 4.0, 5.0, 35.0, "toyroom", true)
	light_omni(Vector3(9, y + 3.0, 16), Color(1.0, 0.75, 0.7), 0.9, 9.0, "toyroom")
	light_omni(Vector3(17, y + 3.0, 16), Color(1.0, 0.75, 0.7), 0.9, 9.0, "toyroom")
	emitter("music_box_loop", Vector3(5.2, y + 1.0, 11.2), -14.0, 3.0)
	emergency(Vector3(12, y + 3.4, 10.4), "toyroom")


func _boiler() -> void:
	var y := ly(-1)
	for z in [-8.0, -14.5]:
		solid(P.boiler(), Vector3(-16.5, y, z), Vector3(2.0, 3.0, 2.0))
		var glow := light_omni(Vector3(-16.5, y + 0.8, z - 1.4), Color(1.0, 0.45, 0.12), 1.6, 6.0, "boiler")
		_attach(glow, "flicker", {"strength": 0.3, "speed": 10.0})
	solid(P.generator(), Vector3(-14.0, y, 4.5), Vector3(1.6, 1.5, 0.9))
	var br := P.breaker_panel()
	put(br, Vector3(-12.15, y + 1.4, 1.0), -90)
	interactable("Breaker", "breaker", "Flip the main breaker", Vector3(-12.45, y + 1.4, 1.0), Vector3(0.5, 0.9, 0.7))
	label("MAIN BREAKER", Vector3(-12.16, y + 1.95, 1.0), -90, 0.0014)
	for x in [-21.4, -12.7]:
		put(P.pipe_run(Vector3(x, y + 3.2, -21.6), Vector3(x, y + 3.2, 9.6)), Vector3.ZERO)
	for z in [-18.0, -2.0, 7.0]:
		put(P.pipe_run(Vector3(-21.4, y + 3.0, z), Vector3(-12.7, y + 3.0, z), 0.06), Vector3.ZERO)
	for p in [Vector3(-21.82, y + 1.5, -10.0), Vector3(-21.82, y + 1.5, -5.0)]:
		put(P.valve_wheel(), p, 90)
	solid(P.workbench(), Vector3(-14.0, y, -20.6), Vector3(2.0, 0.95, 0.8))
	solid(P.barrel(), Vector3(-21.2, y, -20.8), Vector3(0.65, 0.9, 0.65))
	solid(P.barrel(), Vector3(-20.4, y, -21.2), Vector3(0.65, 0.9, 0.65))
	solid(P.crate(1.0), Vector3(-13.2, y, 8.8), Vector3(1.0, 1.0, 1.0))
	solid(P.locker(), Vector3(-21.45, y, -15.5), Vector3(0.55, 1.95, 0.6), 90)
	interactable("HideBoiler", "hide", "Hide in locker", Vector3(-21.05, y + 1.0, -15.5), Vector3(0.3, 1.8, 0.6))
	marker(museum, "HideBoilerView", Vector3(-21.48, y + 1.55, -15.5), -90)
	label("BOILER ROOM\nIf the boiler starts singing, leave.", Vector3(-17, y + 2.6, 9.83), 180, 0.0015, Color(0.95, 0.8, 0.5))
	for z in [-18.0, -9.0, 0.0, 7.0]:
		var bulb := light_omni(Vector3(-17, y + 3.2, z), Color(1.0, 0.75, 0.45), 1.1, 8.0, "boiler", z == 0.0)
		_attach(bulb, "flicker", {"strength": 0.3})
		mesh_at(P.sphere(0.06, "e_bulb"), Vector3(-17, y + 3.35, z))
	var fog := FogVolume.new()
	fog.name = "BasementFog"
	fog.size = Vector3(34.0, 4.0, 34.0)
	fog.position = Vector3(-5, y + 2.0, -6)
	var fm := FogMaterial.new()
	fm.density = 0.035
	fm.albedo = Color(0.6, 0.55, 0.5)
	fog.material = fm
	visual.add_child(fog)
	emitter("boiler_hum", Vector3(-16.5, y + 1.5, -11), -6.0, 8.0)
	emitter("drip", Vector3(-20, y + 0.2, -3), -8.0, 3.0)
	emergency(Vector3(-17, y + 3.3, -21.6), "boiler")


func _archives() -> void:
	var y := ly(-1)
	for z in [-20.6, -19.0, -12.8, -11.2]:
		for x in [-9.0, -4.5]:
			solid(P.shelf(3.6, 2.4, 0.6), Vector3(x, y, z), Vector3(3.6, 2.4, 0.6))
			for k in 3:
				put(P.crate(0.45), Vector3(x - 1.2 + k * 1.2, y + 0.1 + (k % 2) * 0.77, z))
	for k in 3:
		put(P.sheet_statue(1.7, 200 + k), Vector3(-10.5 + k * 1.5, y, -16.0 + (k - 1) * 0.6))
	solid(P.desk(), Vector3(-1.6, y, -12.0), Vector3(0.9, 0.8, 2.0), 90)
	solid(P.filing_cabinet(), Vector3(-11.4, y, -10.6), Vector3(0.6, 1.3, 0.5), 90)
	mesh_at(P.bbox(Vector3(0.24, 0.025, 0.32), 0.004, "linen"), Vector3(-1.5, y + 0.8, -12.1), Vector3(0, 12, 0))
	mesh_at(P.bbox(Vector3(0.26, 0.012, 0.34), 0.003, "crate"), Vector3(-1.5, y + 0.79, -12.1), Vector3(0, 12, 0))
	interactable("ArchiveFile", "archive_file", "Read the staff file (1963)", Vector3(-1.5, y + 0.85, -12.1), Vector3(0.5, 0.3, 0.5), Vector3.ZERO, false)
	solid(P.locker(), Vector3(-0.45, y, -20.5), Vector3(0.55, 1.95, 0.6), -90)
	interactable("HideArchives", "hide", "Hide in locker", Vector3(-0.85, y + 1.0, -20.5), Vector3(0.3, 1.8, 0.6))
	marker(museum, "HideArchivesView", Vector3(-0.42, y + 1.55, -20.5), 90)
	label("ARCHIVES\nEverything we were told to forget.", Vector3(-6, y + 2.6, -10.17), 180, 0.0015, Color(0.95, 0.8, 0.5))
	for x in [-9.0, -3.0]:
		var bulb := light_omni(Vector3(x, y + 3.2, -16.0), Color(1.0, 0.75, 0.45), 1.0, 8.0, "archives", x < -5.0)
		_attach(bulb, "flicker", {"strength": 0.25})
		mesh_at(P.sphere(0.06, "e_bulb"), Vector3(x, y + 3.35, -16.0))
	emergency(Vector3(-6, y + 3.3, -21.6), "archives")


func _vault() -> void:
	var y := ly(-1)
	var altar := P.pedestal(1.4, 1.0, "stone_obj")
	solid(altar, Vector3(6, y, -19.5), Vector3(1.55, 1.0, 1.55))
	put(P.brazier(), Vector3(3.5, y, -20.5))
	put(P.brazier(), Vector3(8.5, y, -20.5))
	collider(Vector3(0.9, 1.0, 0.9), Vector3(3.5, y + 0.5, -20.5))
	collider(Vector3(0.9, 1.0, 0.9), Vector3(8.5, y + 0.5, -20.5))
	for k in 4:
		put(P.gold_pile(k), Vector3([1.5, 10.5, 1.5, 10.5][k], y, [-21.0, -21.0, -11.5, -11.5][k]))
	put(P.painting(1.4, 1.8, "painting_founder"), Vector3(6, y + 2.2, -21.82))
	label("THE FOUNDER'S VAULT", Vector3(6, y + 3.35, -21.83), 0, 0.0022, Color(0.95, 0.75, 0.35))
	plaque("Here the Duck was first awakened. Here it may sleep again. - A.P., 1931", Vector3(6, y + 0.6, -18.7), 0.0, 0.5)
	interactable("AltarMelt", "ending_melt", "Melt the Golden Duck (end the curse)", Vector3(5.5, y + 1.2, -19.0), Vector3(0.6, 0.6, 0.6), Vector3.ZERO, false)
	interactable("AltarKeep", "ending_keep", "Keep the Golden Duck (become Head of Night Security)", Vector3(6.5, y + 1.2, -19.0), Vector3(0.6, 0.6, 0.6), Vector3.ZERO, false)
	marker(museum, "DuckAltarSpot", Vector3(6, y + 1.0, -19.5))
	var ritual := Decal.new()
	ritual.name = "RitualCircle"
	ritual.size = Vector3(7.0, 1.0, 7.0)
	ritual.position = Vector3(6, y + 0.1, -16.5)
	ritual.texture_albedo = load("res://textures/decal_ritual.png")
	ritual.emission_energy = 0.6
	ritual.texture_emission = load("res://textures/decal_ritual.png")
	visual.add_child(ritual)
	for x in [3.5, 8.5]:
		var fire := light_omni(Vector3(x, y + 1.3, -20.5), Color(1.0, 0.5, 0.15), 1.8, 8.0, "vault")
		_attach(fire, "flicker", {"strength": 0.35, "speed": 12.0})
	for k in 6:
		put(P.candle(), Vector3(2.0 + k * 1.6, y, -12.0))
	light_omni(Vector3(6, y + 1.0, -12.4), Color(1.0, 0.6, 0.25), 0.8, 6.0, "vault")


func _dino_hall() -> void:
	solid(P.pedestal(7.5, 0.35, "stone_obj"), Vector3(21, 0, -4), Vector3(7.6, 0.35, 3.6))
	var dino := Node3D.new()
	dino.name = "Dino"
	dino.position = Vector3(21, 0.35, -4)
	_attach(dino, "dino")
	museum.add_child(dino)
	var model := P.dino_skeleton()
	model.name = "Model"
	dino.add_child(model)
	plaque("GERALD. Tyrannosaurus rex (juvenile). 66 million years old. Very shy. NO FLASH PHOTOGRAPHY.", Vector3(16.8, 0.6, -2.0), -60.0, 0.5)
	put(P.pedestal(0.3, 0.6, "brass"), Vector3(16.8, 0, -2.0))
	for p in [Vector3(16, 0, -6.5), Vector3(16, 0, -1.5), Vector3(26, 0, -6.5), Vector3(26, 0, -1.5)]:
		put(P.rope_post(), p)
	put(P.rope(Vector3(16, 0.92, -6.5), Vector3(16, 0.92, -1.5)), Vector3.ZERO)
	put(P.rope(Vector3(26, 0.92, -6.5), Vector3(26, 0.92, -1.5)), Vector3.ZERO)
	light_spot(Vector3(17, H - 0.1, -1), Vector3(19.5, 2.5, -4), Color(0.8, 0.88, 1.0), 6.0, 10.0, 30.0, "dino", true)
	light_spot(Vector3(25, H - 0.1, -7), Vector3(22, 2.0, -4), Color(0.8, 0.88, 1.0), 4.0, 10.0, 30.0, "dino", false)
	solid(P.pedestal(0.7, 1.0), Vector3(15.5, 0, 6.0), Vector3(0.82, 1.0, 0.82))
	var egg := P.part(P.node("Egg"), "Egg", P.sphere(0.18, "bone"), Vector3.ZERO, Vector3.ZERO, Vector3(1, 1.3, 1))
	put(egg.get_parent(), Vector3(15.5, 1.23, 6.0))
	plaque("FOSSILIZED EGG. May still hatch. Please don't.", Vector3(15.5, 0.6, 6.41), 0.0, 0.4)
	interactable("Egg", "touch_egg", "Touch the Fossilized Egg", Vector3(15.5, 1.0, 6.0), Vector3(0.5, 0.6, 0.5), Vector3(0, 0.25, 0))
	solid(P.pedestal(1.2, 0.5, "stone_obj"), Vector3(26, 0, 6), Vector3(1.3, 0.5, 1.3))
	var meteor := P.node("Meteor")
	P.part(meteor, "Rock", ML.lathe(ML.curve(func(t: float) -> Vector2: return Vector2(sin(t * PI) * 0.55, -cos(t * PI) * 0.5), 10), P.M["steel_dark"], {"segments": 14, "noise": 0.25, "seed": 5}))
	put(meteor, Vector3(26, 1.0, 6))
	plaque("METEOR FRAGMENT. The original party pooper.", Vector3(26, 0.3, 6.66), 0.0, 0.4)
	interactable("CheckpointDino", "checkpoint_dino", "Scan patrol checkpoint", Vector3(29.55, 1.4, -16.0), Vector3(0.4, 0.6, 0.5))
	_checkpoint_panel(Vector3(29.83, 1.4, -16.0), -90)
	for i in 4:
		interactable("WindowDino%d" % (i + 1), "close_window", "Close the window", Vector3(29.6, 2.5, [-13.2, -6.2, 1.0, 6.8][i]), Vector3(0.6, 2.8, 1.6), Vector3.ZERO, false)
	emitter("wind", Vector3(29.5, 2.5, -2), -6.0, 6.0)
	light_omni(Vector3(21, 4.6, 5), Color(0.75, 0.85, 1.0), 1.4, 12.0, "dino")
	light_omni(Vector3(16, 4.6, -12), Color(0.75, 0.85, 1.0), 1.2, 12.0, "dino")
	emergency(Vector3(12.4, 4.6, -4), "dino")


func _wax_hall() -> void:
	var figures := [
		[{"top": "cloth_red", "legs": "cloth_black", "hat": "bicorne"}, Vector3(-19, 0, 12.5), 160.0, "NAPOLEON'S NEIGHBOUR. Also short. Less famous."],
		[{"top": "cloth_black", "legs": "cloth_black", "hat": "tricorn"}, Vector3(-15, 0, 12.5), 200.0, "A PIRATE (ALLEGEDLY). Never found the treasure. Or the sea."],
		[{"top": "cloth_green", "legs": "uniform", "dress": true}, Vector3(-11, 0, 12.5), 180.0, "THE INVENTOR OF THE SPOON. Probably."],
		[{"top": "uniform", "legs": "uniform", "hat": "cap", "dress": true}, Vector3(-19, 0, 18.5), 0.0, "BRENDA HOLLOWAY. Head of Night Security, 1962 - 1963. Never left."],
	]
	for f in figures:
		var holder := Node3D.new()
		holder.name = _uname("WaxFigure")
		visual.add_child(holder)
		holder.position = f[1]
		holder.rotation_degrees.y = f[2]
		var m := P.wax_figure(f[0])
		holder.add_child(m)
		put(P.pedestal(0.9, 0.25, "dark_wood_obj"), f[1] + Vector3(0, -0.25, 0))
		collider(Vector3(0.9, 1.9, 0.9), f[1] + Vector3(0, 0.95, 0))
		var face := -Vector3(sin(deg_to_rad(f[2])), 0, cos(deg_to_rad(f[2]))) # models look along local -Z
		plaque(f[3], f[1] + face * 0.75 + Vector3(0, 0.5, 0), f[2] + 180.0, 0.4)
		put(P.pedestal(0.25, 0.45, "brass"), f[1] + face * 0.75)
		light_spot(f[1] + Vector3(0, 3.9, 0) + face * 1.2, f[1] + Vector3(0, 1.4, 0), Color(1.0, 0.82, 0.7), 5.0, 5.5, 30.0, "wax")
		if f[3].begins_with("BRENDA"):
			holder.name = "BrendaFigure"
			var radio := P.bbox(Vector3(0.06, 0.16, 0.04), 0.01, "black_plastic")
			mesh_at(radio, Vector3(0, -0.3, -0.04), Vector3.ZERO, m.find_child("ElbowR", true, false), "Radio")
			interactable("BrendaReveal", "brenda_figure", "Look closer", f[1] + Vector3(0, 1.0, 0), Vector3(1.0, 1.8, 1.0), Vector3.ZERO, false)
	solid(P.locker(), Vector3(-4.45, 0, 18.8), Vector3(0.55, 1.95, 0.6), -90)
	interactable("HideWax", "hide", "Hide in locker", Vector3(-4.85, 1.0, 18.8), Vector3(0.3, 1.8, 0.6))
	marker(museum, "HideWaxView", Vector3(-4.42, 1.55, 18.8), 90)
	solid(P.locker(), Vector3(-21.55, 0, 15.5), Vector3(0.55, 1.95, 0.6), 90)
	interactable("HideWax2", "hide", "Hide in locker", Vector3(-21.15, 1.0, 15.5), Vector3(0.3, 1.8, 0.6))
	marker(museum, "HideWax2View", Vector3(-21.58, 1.55, 15.5), -90)
	solid(P.locker(), Vector3(-7.0, 0, 19.55), Vector3(0.6, 1.95, 0.55), 180)
	interactable("GaryLocker", "gary_locker", "Search Gary's locker", Vector3(-7.0, 1.0, 19.15), Vector3(0.6, 1.8, 0.3), Vector3.ZERO, false)
	label("G. FINCH - NIGHT GUARD", Vector3(-7.0, 1.75, 19.26), 180, 0.0009)
	solid(P.bench(2.0), Vector3(-13, 0, 16.5), Vector3(2.0, 0.55, 0.5))
	for x in [-18.0, -10.0]:
		put(P.chandelier(), Vector3(x, 4.2, 15))
		light_omni(Vector3(x, 3.1, 15), Color(1.0, 0.6, 0.4), 1.8, 10.0, "wax")
	emergency(Vector3(-13, 3.9, 10.4), "wax")
	emitter("gramophone", Vector3(-5, 1.0, 11), -14.0, 4.0)


func _curiosities() -> void:
	# Automaton booth
	solid(P.display_case(1.6, 1.4, 0.5, 2.0), Vector3(12, 0, 20.9), Vector3(1.6, 2.5, 1.4))
	var booth_light := light_spot(Vector3(12, 4.1, 19.0), Vector3(12, 1.0, 20.9), Color(1.0, 0.85, 0.6), 4.0, 5.0, 28.0, "curio", true)
	booth_light.name = "BoothLight"
	label("LITTLE WOLFGANG\nClockwork automaton, 1784.\nPlays one song. Forever.", Vector3(12, 2.8, 20.17), 180, 0.0015, Color(0.95, 0.85, 0.6))
	interactable("WindCrank", "wind_automaton", "Wind up Little Wolfgang", Vector3(13.0, 0.9, 20.1), Vector3(0.6, 0.6, 0.4), Vector3.ZERO, false)
	put(P.pedestal(0.2, 0.75, "brass"), Vector3(13.0, 0, 20.1))
	mesh_at(P.cyl(0.08, 0.08, 0.03, "brass", 16), Vector3(13.0, 0.85, 19.98), Vector3(90, 0, 0), null, "Crank")
	# Cabinet of curiosities
	solid(P.shelf(2.5, 2.4, 0.5), Vector3(4.55, 0, 16), Vector3(0.5, 2.4, 2.5), 90)
	for k in 3:
		for row in 3:
			put(P.specimen_jar(0.28 + row * 0.04), Vector3(4.6, 0.12 + row * 0.73, 15.2 + k * 0.75))
	solid(P.display_case(1.2, 0.8, 0.9, 0.5), Vector3(8, 0, 14.5), Vector3(1.2, 1.4, 0.8))
	put(P.globe(), Vector3(8, 0.9, 14.5))
	solid(P.display_case(1.2, 0.8, 0.9, 0.5), Vector3(16, 0, 14.5), Vector3(1.2, 1.4, 0.8))
	put(P.specimen_jar(0.35), Vector3(16, 0.9, 14.5))
	plaque("A JAR OF SOMETHING. We stopped asking.", Vector3(16, 0.55, 14.91), 0.0, 0.35)
	interactable("JarCurio", "touch_jar2", "Tap the jar", Vector3(16, 1.0, 14.5), Vector3(0.5, 0.6, 0.5), Vector3(0, 0.2, 0))
	solid(P.grandfather_clock(), Vector3(19.5, 0, 12.0), Vector3(0.6, 2.3, 0.45), -90)
	interactable("CheckpointCurio", "checkpoint_curio", "Scan patrol checkpoint", Vector3(19.55, 1.4, 17.5), Vector3(0.4, 0.6, 0.5))
	_checkpoint_panel(Vector3(19.83, 1.4, 17.5), -90)
	for i in 3:
		var socket := Vector3([7.0, 12.0, 17.0][i], 3.4, 10.25)
		mesh_at(P.bbox(Vector3(0.25, 0.25, 0.08), 0.02, "brass"), socket, Vector3.ZERO, null, "LampSocket")
		interactable("Socket%d" % (i + 1), "install_bulb", "Install a light bulb", socket + Vector3(0, -0.3, 0.3), Vector3(0.8, 1.0, 0.6), Vector3.ZERO, false)
	solid(P.locker(), Vector3(19.45, 0, 21.0), Vector3(0.55, 1.95, 0.6), -90)
	interactable("HideCurio", "hide", "Hide in locker", Vector3(19.05, 1.0, 21.0), Vector3(0.3, 1.8, 0.6))
	marker(museum, "HideCurioView", Vector3(19.48, 1.55, 21.0), 90)
	for x in [8.0, 16.0]:
		light_omni(Vector3(x, 3.6, 16), Color(0.85, 1.0, 0.8), 1.5, 10.0, "curio")
	emergency(Vector3(12, 3.9, 10.4), "curio")
	emitter("clockwork", Vector3(12, 1.0, 20.9), -10.0, 3.0)


# ---------------------------------------------------------- enemies + markers --

func _enemy(n: String, script_key: String, model: Node3D, pos: Vector3, yaw_deg: float) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = n
	body.position = pos
	body.rotation_degrees.y = yaw_deg
	body.collision_layer = 4
	body.collision_mask = 1 | 16
	_attach(body, script_key)
	museum.add_child(body)
	model.name = "Model"
	body.add_child(model)
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	body.add_child(cs)
	var agent := NavigationAgent3D.new()
	agent.name = "Agent"
	agent.radius = 0.45
	agent.height = 1.8
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 0.8
	body.add_child(agent)
	return body


func _decals() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 1234
	var grime: Texture2D = load("res://textures/decal_grime.png")
	var crack: Texture2D = load("res://textures/decal_crack.png")
	for id in ROOMS:
		var rc := rect(id)
		var y := room_y(id)
		var count := 2 if ROOMS[id]["lvl"] >= 0 else 6
		for k in count:
			var d := Decal.new()
			d.name = _uname("Grime")
			var sz := r.randf_range(1.2, 3.0)
			d.size = Vector3(sz, 0.8, sz)
			d.position = Vector3(r.randf_range(rc.position.x + 1, rc.end.x - 1), y + 0.2, r.randf_range(rc.position.y + 1, rc.end.y - 1))
			d.rotation.y = r.randf() * TAU
			d.texture_albedo = grime
			d.modulate = Color(1, 1, 1, r.randf_range(0.4, 0.8))
			visual.add_child(d)
		# A crack on one wall
		var w := Decal.new()
		w.name = _uname("Crack")
		w.size = Vector3(1.6, 0.6, 1.6)
		w.texture_albedo = crack
		w.position = Vector3(rc.position.x + T / 2.0 + 0.05, y + r.randf_range(1.2, 2.6), r.randf_range(rc.position.y + 1, rc.end.y - 1))
		w.rotation_degrees = Vector3(0, 0, -90) # project along +X into the west wall
		visual.add_child(w)
	# Cobwebs in upper corners (double-sided quads)
	var web := StandardMaterial3D.new()
	web.albedo_texture = load("res://textures/decal_cobweb.png")
	web.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	web.cull_mode = BaseMaterial3D.CULL_DISABLED
	web.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	web.roughness = 1.0
	for id in ["storage", "gallery", "egypt", "dino", "wax", "workshop", "library", "boiler", "archives", "vault", "costume", "toyroom"]:
		var rc := rect(id)
		var top: float = room_y(id) + ROOMS[id]["ceil"] - 0.02
		var corner := Vector3(rc.position.x + T / 2.0 + 0.01, top, rc.position.y + T / 2.0 + 0.01)
		var q := ML.plane(1.2, 1.2, web)
		mesh_at(q, corner + Vector3(0.42, -0.42, 0.42), Vector3(-45, -45, 0), null, "Cobweb")
	# Dusty footprints: someone keeps walking from the Wax Hall to the basement stairs...
	var fp: Texture2D = load("res://textures/decal_footprints.png")
	for p in [[Vector3(-14.5, 0.2, 8.0), 20.0], [Vector3(-17.0, 0.2, 7.0), 60.0], [Vector3(-19.5, 0.2, 6.6), 90.0], [Vector3(-8.0, 0.2, 7.5), -10.0]]:
		var d := Decal.new()
		d.name = _uname("Footprints")
		d.size = Vector3(1.0, 0.6, 2.0)
		d.position = p[0]
		d.rotation_degrees.y = p[1]
		d.texture_albedo = fp
		visual.add_child(d)


func _markers() -> void:
	var y1 := ly(1)
	var yb := ly(-1)
	_enemy("Knight", "knight", P.knight_model(), Vector3(-5.5, 0.0, 6.0), 180.0)
	_enemy("Mummy", "mummy", P.mummy_model(), Vector3(6, 0.0, -20.5), 180.0)
	var auto := _enemy("Automaton", "automaton", P.automaton_model(), Vector3(12, 0.5, 20.9), 0.0)
	auto.get_node("Collision").position.y = 0.65
	var duchess := _enemy("Duchess", "duchess", P.wax_figure({"top": "cloth_red", "legs": "cloth_red", "dress": true, "skin": "porcelain", "eye": "eye_dark"}), Vector3(-6, 0, -20.6), 0.0)
	duchess.visible = false
	var gary := _enemy("Gary", "guard", P.wax_figure({"top": "uniform", "legs": "uniform", "hat": "cap"}), Vector3(-13, 0, 14.0), 0.0)
	var torch_pivot: Node3D = gary.get_node("Model").find_child("ElbowR", true, false)
	var beam := SpotLight3D.new()
	beam.name = "Beam"
	beam.position = Vector3(0, -0.33, -0.1)
	beam.rotation_degrees = Vector3(-80, 0, 0)
	beam.light_color = Color(1.0, 0.95, 0.75)
	beam.light_energy = 4.0
	beam.spot_range = 12.0
	beam.spot_angle = 22.0
	beam.shadow_enabled = true
	beam.light_volumetric_fog_energy = 2.0
	torch_pivot.add_child(beam)
	var torch_mesh := MeshInstance3D.new()
	torch_mesh.name = "Torch"
	torch_mesh.mesh = P.cyl(0.03, 0.04, 0.22, "black_plastic", 10)
	torch_mesh.position = Vector3(0, -0.3, -0.05)
	torch_mesh.rotation_degrees = Vector3(-80, 0, 0)
	torch_pivot.add_child(torch_mesh)
	var pem := _enemy("Pemberton", "pemberton", P.wax_figure({"top": "cloth_black", "legs": "cloth_black", "hat": "tophat", "skin": "wax", "scale": 1.08}), Vector3(6, yb, -13.5), 180.0)
	pem.visible = false
	var ghost := P.wax_figure({"top": "cloth_black", "legs": "cloth_black", "skin": "socket", "eye": "e_red", "scale": 1.1})
	ghost.name = "Apparition"
	ghost.visible = false
	museum.add_child(ghost)
	var dolls := _group(museum, "Dolls")
	for k in 5:
		var a := TAU * k / 5.0
		var pos := Vector3(12 + cos(a) * 1.05, y1, 16 + sin(a) * 1.05)
		var yaw := rad_to_deg(atan2(cos(a), sin(a)))
		var doll := _enemy("Doll%d" % (k + 1), "doll", P.mannequin({"top": ["cloth_red", "cloth_green", "toy_blue", "toy_yellow", "sheet"][k], "legs": "porcelain", "dress": true, "scale": 0.5, "plain_head": false, "skin": "porcelain", "hair": "hair", "eye": "eye_dark"}), pos, yaw)
		doll.get_node("Collision").shape.height = 0.9
		doll.get_node("Collision").shape.radius = 0.18
		doll.get_node("Collision").position.y = 0.45
		museum.remove_child(doll)
		dolls.add_child(doll)

	var cams := _group(museum, "Cameras")
	for c in [["Lobby", Vector3(11.0, 4.6, 9.0), Vector3(-2, 0, -4)], ["Balcony", Vector3(11.0, y1 + 3.4, 9.0), Vector3(-4, y1, -5)],
			["Gallery", Vector3(-0.8, 4.6, -10.8), Vector3(-8, 0, -18)], ["Egyptian_Hall", Vector3(11.2, 4.6, -10.8), Vector3(4, 0, -18)],
			["Dinosaur_Hall", Vector3(29.0, 4.6, 9.0), Vector3(19, 0, -8)], ["Wax_Hall", Vector3(-4.8, 3.9, 10.8), Vector3(-16, 0, 17)],
			["Curiosities", Vector3(19.2, 3.9, 10.8), Vector3(9, 0, 19)], ["Library", Vector3(-0.8, y1 + 3.4, -10.8), Vector3(-8, y1, -18)],
			["Toy_Room", Vector3(19.2, y1 + 3.4, 10.8), Vector3(10, y1, 18)], ["Natural_History", Vector3(29.0, y1 + 3.4, -4.6), Vector3(18, y1, -14)],
			["Boiler_Room", Vector3(-12.8, yb + 3.3, 9.2), Vector3(-19, yb, -6)], ["Archives", Vector3(-0.8, yb + 3.3, -10.8), Vector3(-9, yb, -18)]]:
		var m := Marker3D.new()
		m.name = c[0]
		cams.add_child(m)
		m.position = c[1]
		m.basis = Basis.looking_at((c[2] - c[1]).normalized(), Vector3.UP)
		mesh_at(P.bbox(Vector3(0.12, 0.1, 0.25), 0.02, "porcelain"), c[1] + Vector3(0, 0.05, 0), Vector3(0, rad_to_deg(m.basis.get_euler().y), 0), null, "Camera")
	var spots := _group(museum, "DuckSpots")
	for p in [Vector3(-20.5, 0, 8.6), Vector3(-1.0, 0, -21.2), Vector3(11.2, 0, -10.9), Vector3(13.0, 0, 9.0), Vector3(28.8, 0, -17.0),
			Vector3(-10.0, y1, 9.0), Vector3(19.0, y1, 21.0), Vector3(-3.0, y1, 16.5)]:
		marker(spots, _uname("Spot"), p)
	var bat := _group(museum, "BatterySpots")
	for p in [Vector3(7.0, 0.82, 7.2), Vector3(-13.0, 0.0, 8.8), Vector3(-20.0, 1.0, -4.4), Vector3(-11.3, 0, -21.3), Vector3(-0.6, 0, -10.6),
			Vector3(11.3, 0, -21.3), Vector3(29.3, 0, 9.3), Vector3(12.6, 0, -17.3), Vector3(-21.3, 0, 19.3), Vector3(4.6, 0, 21.3), Vector3(19.3, 0, 10.6),
			Vector3(-11.2, y1, -21.2), Vector3(11.0, y1, -11.0), Vector3(29.2, y1, -17.2), Vector3(13.0, y1, 9.2), Vector3(-21.2, y1, -5.2),
			Vector3(-21.2, y1, 11.0), Vector3(3.3, y1, 11.0), Vector3(-21.2, yb, 9.2), Vector3(-0.8, yb, -21.2), Vector3(-13.0, yb, -21.0)]:
		marker(bat, _uname("Bat"), p)
	var film := _group(museum, "FilmSpots")
	for p in [Vector3(6.5, 0.82, 7.0), Vector3(15.5, 0.05, 5.2), Vector3(-6.0, y1, -11.0), Vector3(24.0, y1, 8.5), Vector3(-14.0, y1, 9.0),
			Vector3(-13.5, yb, 9.0), Vector3(2.5, y1, 13.5), Vector3(-1.0, 0.05, -11.0)]:
		marker(film, _uname("Film"), p)
	var notes := _group(museum, "NoteSpots")
	var note_pos := [Vector3(1.6, 0.81, 15.6), Vector3(-6.0, 0.55, -12.5), Vector3(4.5, 0.05, -10.9), Vector3(9.0, 0.95, 14.6),
		Vector3(-14.0, 0.85, 9.0), Vector3(7.0, 0.82, 7.4), Vector3(20.0, 0.4, -2.2), Vector3(12.0, y1 + 0.58, 15.4),
		Vector3(0.4, y1 + 0.8, 15.1), Vector3(-7.0, 0.05, 18.9), Vector3(-13.0, 0.6, 16.5), Vector3(-3.0, y1 + 0.82, -17.6),
		Vector3(6.0, y1 + 0.05, -12.4), Vector3(19.6, y1 + 0.05, -8.0), Vector3(-17.5, y1 + 0.93, -5.2), Vector3(-1.6, yb + 0.81, -12.0),
		Vector3(6.0, yb + 1.02, -18.9)]
	for i in note_pos.size():
		marker(notes, "Note%d" % (i + 1), note_pos[i])
	var tapes := _group(museum, "TapeSpots")
	var tape_pos := [Vector3(-3.6, 0.72, 14.0), Vector3(10.2, 0.62, -8.2), Vector3(-14.0, yb + 0.93, -20.6), Vector3(-3.4, y1 + 1.31, 11.3),
		Vector3(-9.5, y1 + 0.05, 14.5), Vector3(21.0, y1 + 0.05, 5.2), Vector3(-1.0, y1 + 0.05, -13.6), Vector3(-1.6, yb + 0.81, -11.4),
		Vector3(-19.0, 0.05, 17.0), Vector3(6.0, yb + 0.05, -12.8), Vector3(12.0, y1 + 0.58, 16.6), Vector3(0.3, 0.81, 15.9)]
	for i in tape_pos.size():
		marker(tapes, "Tape%d" % (i + 1), tape_pos[i])
	var patrol := _group(museum, "PatrolPoints")
	for p in [Vector3(-13, 0, 15), Vector3(-7, 0, 15), Vector3(-8, 0, 6), Vector3(-6, 0, -6), Vector3(-6, 0, -14), Vector3(-2, 0, -16),
			Vector3(6, 0, -14), Vector3(10, 0, -18), Vector3(16, 0, -14), Vector3(24, 0, -12), Vector3(24, 0, 4), Vector3(16, 0, 2),
			Vector3(14, 0, 16), Vector3(8, 0, 18), Vector3(8, 0, 6), Vector3(0, 0, 6.5),
			Vector3(0, y1, -8.0), Vector3(-6, y1, -16), Vector3(6, y1, -12.5), Vector3(-10.2, y1, 0), Vector3(-17, y1, 2), Vector3(-15, y1, 15),
			Vector3(0, y1, 13), Vector3(12, y1, 19.5), Vector3(20, y1, 3), Vector3(20, y1, -10), Vector3(10.2, y1, 0), Vector3(0, y1, -8.0),
			Vector3(0, 0, 6.5), Vector3(-16, 0, 2), Vector3(-17, 0, 8)]:
		marker(patrol, _uname("P"), p)


func _bake_navigation() -> void:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.25
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	level.navigation_mesh = nm
	level.bake_navigation_mesh(false)
	print("Navigation polygons: ", nm.get_polygon_count())
