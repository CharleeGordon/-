extends Node
## Builds scenes/museum.tscn (geometry, props, lights, exhibits, enemies) and bakes navigation.
## Run from the game/ folder:
##   godot --headless --path . res://tools/build_museum.tscn
## NOTE: running this OVERWRITES museum.tscn. After you start hand-editing the museum in
## the Godot editor, treat museum.tscn as the source and stop using this script.

const OUT := "res://scenes/museum.tscn"
const H := 4.0 # wall height
const T := 0.3 # wall thickness
const DOOR_H := 2.6

const INTERACTABLE := preload("res://scripts/interactable.gd")
const ROOM_AREA := preload("res://scripts/room_area.gd")
const KNIGHT := preload("res://scripts/knight.gd")
const MUMMY := preload("res://scripts/mummy.gd")
const DINO := preload("res://scripts/dino.gd")
const SHIFT := preload("res://autoload/shift.gd")

var museum: Node3D
var level: NavigationRegion3D
var decor: Node3D
var lights: Node3D
var items: Node3D
var _names := {}
var _scripts := [] # [node, script, props] - attached after baking so no gameplay code runs here
var M := {}


func _ready() -> void:
	museum = Node3D.new()
	museum.name = "Museum"
	add_child(museum) # must be inside the tree for navigation baking
	_materials()
	_environment()
	level = NavigationRegion3D.new()
	level.name = "Level"
	museum.add_child(level)
	decor = _group(museum, "Decor")
	lights = _group(museum, "Lights")
	items = _group(museum, "Interactables")

	_shell()
	_office()
	_lobby()
	_storage()
	_gallery()
	_egypt()
	_dino_hall()
	_rooms()
	_knight()
	_mummy()

	_bake_navigation()
	remove_child(museum)
	for entry in _scripts:
		entry[0].set_script(entry[1])
		for key in entry[2]:
			entry[0].set(key, entry[2][key])
	_set_owner(museum)
	var packed := PackedScene.new()
	var err := packed.pack(museum)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("Saved %s: %s" % [OUT, error_string(err)])
	museum.free()
	get_tree().quit(0 if err == OK else 1)


# --- Helpers -------------------------------------------------------------

func _uname(base: String) -> String:
	_names[base] = _names.get(base, 0) + 1
	return base if _names[base] == 1 else "%s%d" % [base, _names[base]]


func _attach(node: Node, script: Script, props: Dictionary = {}) -> void:
	_scripts.append([node, script, props])


func _group(parent: Node, n: String) -> Node3D:
	var g := Node3D.new()
	g.name = n
	parent.add_child(g)
	return g


func _mat(color: Color, emission: float = 0.0, metallic: float = 0.0, roughness: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


func _materials() -> void:
	M.wall = _mat(Color(0.74, 0.7, 0.62))
	M.wall_trim = _mat(Color(0.3, 0.22, 0.16))
	M.ceiling = _mat(Color(0.16, 0.16, 0.18))
	M.base = _mat(Color(0.25, 0.25, 0.25))
	M.f_lobby = _mat(Color(0.62, 0.6, 0.55), 0.0, 0.0, 0.35)
	M.f_office = _mat(Color(0.18, 0.22, 0.3))
	M.f_storage = _mat(Color(0.32, 0.32, 0.32))
	M.f_gallery = _mat(Color(0.42, 0.27, 0.16), 0.0, 0.0, 0.5)
	M.f_egypt = _mat(Color(0.72, 0.6, 0.38))
	M.f_dino = _mat(Color(0.3, 0.36, 0.3))
	M.wood = _mat(Color(0.38, 0.24, 0.13))
	M.metal = _mat(Color(0.7, 0.72, 0.76), 0.0, 0.45, 0.4)
	M.dark = _mat(Color(0.07, 0.07, 0.09))
	M.gold = _mat(Color(0.92, 0.72, 0.2), 0.0, 0.9, 0.3)
	M.bone = _mat(Color(0.86, 0.82, 0.7))
	M.bandage = _mat(Color(0.8, 0.76, 0.62))
	M.bandage_dark = _mat(Color(0.6, 0.55, 0.42))
	M.crate = _mat(Color(0.55, 0.4, 0.22))
	M.stone = _mat(Color(0.7, 0.62, 0.45))
	M.paper = _mat(Color(0.95, 0.93, 0.85))
	M.red = _mat(Color(0.7, 0.08, 0.08))
	M.plant = _mat(Color(0.15, 0.4, 0.15))
	M.glass = _mat(Color(0.7, 0.85, 1.0, 0.25))
	M.glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	M.e_red = _mat(Color(1.0, 0.1, 0.05), 3.0)
	M.e_green = _mat(Color(0.3, 1.0, 0.3), 3.0)
	M.e_screen = _mat(Color(0.4, 0.6, 0.9), 1.5)
	M.e_visor = _mat(Color(1.0, 0.15, 0.1), 4.0)
	M.e_mummy_eye = _mat(Color(0.4, 1.0, 0.5), 5.0)
	M.e_dino_eye = _mat(Color(1.0, 0.75, 0.2), 0.4)
	M.e_portrait_eye = _mat(Color(1.0, 1.0, 0.9), 2.0)
	M.battery = _mat(Color(0.95, 0.75, 0.1))


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.01, 0.015)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.28, 0.4)
	env.ambient_light_energy = 0.12
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.03, 0.05)
	env.fog_density = 0.015
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	museum.add_child(we)


func _box_mesh(size: Vector3, mat: Material) -> BoxMesh:
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	return bm


## Solid box (mesh + collision), lives under Level so it blocks navigation.
func solid(n: String, size: Vector3, pos: Vector3, mat: Material, parent: Node = null, rot_y: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = _uname(n)
	body.position = pos
	body.rotation_degrees.y = rot_y
	(parent if parent else level).add_child(body)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _box_mesh(size, mat)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	return body


## Visual-only mesh.
func visual(n: String, mesh: Mesh, pos: Vector3, parent: Node = null, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = _uname(n)
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	(parent if parent else decor).add_child(mi)
	return mi


func vbox(n: String, size: Vector3, pos: Vector3, mat: Material, parent: Node = null, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return visual(n, _box_mesh(size, mat), pos, parent, rot)


func sphere(r: float, mat: Material) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	s.material = mat
	return s


func cylinder(top: float, bottom: float, height: float, mat: Material, segments: int = 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = segments
	c.material = mat
	return c


func label(text: String, pos: Vector3, rot_y: float, size: float = 0.0025, parent: Node = null, color: Color = Color(0.95, 0.92, 0.8)) -> Label3D:
	var l := Label3D.new()
	l.name = _uname("Label")
	l.text = text
	l.font_size = 64
	l.pixel_size = size
	l.outline_size = 12
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.double_sided = false
	l.position = pos
	l.rotation_degrees.y = rot_y
	(parent if parent else decor).add_child(l)
	return l


func omni(pos: Vector3, color: Color, energy: float, rng: float, group: String = "room_lights", visible_now: bool = true) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.name = _uname("Light")
	o.position = pos
	o.light_color = color
	o.light_energy = energy
	o.omni_range = rng
	o.omni_attenuation = 1.2
	o.visible = visible_now
	if group != "":
		o.add_to_group(group, true)
	lights.add_child(o)
	return o


func interactable(n: String, action: String, prompt: String, pos: Vector3, shape_size: Vector3, shape_offset: Vector3 = Vector3.ZERO, is_active: bool = true, parent: Node = null) -> Area3D:
	var a := Area3D.new()
	a.name = n
	_attach(a, INTERACTABLE, {"action_id": action, "prompt": prompt, "active": is_active})
	a.collision_layer = 8 if is_active else 0
	a.collision_mask = 0
	a.monitoring = false
	a.position = pos
	(parent if parent else items).add_child(a)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var sh := BoxShape3D.new()
	sh.size = shape_size
	cs.shape = sh
	cs.position = shape_offset
	a.add_child(cs)
	return a


## Wall-mounted interactable panel. `normal` points from the wall into the room.
func wall_panel(n: String, action: String, prompt: String, face_point: Vector3, normal: Vector3, title: String) -> Area3D:
	var a := interactable(n, action, prompt, face_point + normal * 0.25, Vector3(0.7, 0.9, 0.5))
	a.rotation.y = atan2(normal.x, normal.z)
	vbox("Panel", Vector3(0.5, 0.65, 0.08), Vector3(0, 0, -0.21), M.dark, a)
	var lamp := visual("Lamp", sphere(0.07, M.e_red), Vector3(0, 0.15, -0.16), a)
	lamp.name = "Lamp"
	label(title, Vector3(0, 0.55, -0.2), 0.0, 0.0018, a)
	return a


func battery(pos: Vector3) -> void:
	var a := interactable(_uname("Battery"), "battery", "Take batteries", pos, Vector3(0.5, 0.4, 0.5), Vector3(0, 0.2, 0))
	visual("Cell", cylinder(0.06, 0.06, 0.2, M.battery), Vector3(-0.06, 0.1, 0), a)
	visual("Cell", cylinder(0.06, 0.06, 0.2, M.battery), Vector3(0.07, 0.1, 0.02), a)


func pedestal(pos: Vector3, plaque: String, plaque_rot: float = 0.0) -> void:
	solid("Pedestal", Vector3(0.7, 1.0, 0.7), pos + Vector3(0, 0.5, 0), M.wall)
	vbox("PedestalTop", Vector3(0.8, 0.06, 0.8), pos + Vector3(0, 1.03, 0), M.wall_trim)
	var dir := Vector3(sin(deg_to_rad(plaque_rot)), 0, cos(deg_to_rad(plaque_rot)))
	label(plaque, pos + Vector3(0, 0.55, 0) + dir * 0.36, plaque_rot, 0.0015)


func sign_stand(pos: Vector3, rot_y: float, text: String) -> void:
	var holder := Node3D.new()
	holder.name = _uname("Sign")
	holder.position = pos
	holder.rotation_degrees.y = rot_y
	decor.add_child(holder)
	vbox("Post", Vector3(0.05, 0.9, 0.05), Vector3(0, 0.45, -0.03), M.dark, holder)
	vbox("Board", Vector3(0.8, 0.5, 0.03), Vector3(0, 1.0, 0), M.dark, holder, Vector3(-15, 0, 0))
	var l := label(text, Vector3(0, 1.0, 0.03), 0.0, 0.0014, holder)
	l.rotation_degrees.x = -15


func painting(pos: Vector3, rot_y: float, size: Vector2, canvas_color: Color, caption: String, creepy_eyes: bool = false) -> void:
	var holder := Node3D.new()
	holder.name = _uname("Painting")
	holder.position = pos
	holder.rotation_degrees.y = rot_y
	decor.add_child(holder)
	vbox("Frame", Vector3(size.x + 0.2, size.y + 0.2, 0.05), Vector3.ZERO, M.gold, holder)
	vbox("Canvas", Vector3(size.x, size.y, 0.05), Vector3(0, 0, 0.01), _mat(canvas_color, 0.05), holder)
	if creepy_eyes:
		vbox("Face", Vector3(size.x * 0.45, size.y * 0.5, 0.05), Vector3(0, 0.1, 0.02), _mat(Color(0.75, 0.6, 0.45)), holder)
		visual("Eye", sphere(0.03, M.e_portrait_eye), Vector3(-0.09, 0.22, 0.05), holder)
		visual("Eye", sphere(0.03, M.e_portrait_eye), Vector3(0.09, 0.22, 0.05), holder)
	else:
		vbox("Shape", Vector3(size.x * 0.4, size.y * 0.35, 0.05), Vector3(0.1, -0.05, 0.02), _mat(canvas_color.inverted().darkened(0.3)), holder)
	label(caption, Vector3(0, -size.y * 0.5 - 0.3, 0.03), 0.0, 0.0016, holder)


# --- Walls ---------------------------------------------------------------

func _segments(a: float, b: float, gaps: Array) -> Array:
	var out := []
	var cur := a
	for g in gaps:
		out.append(Vector2(cur, g[0]))
		cur = g[1]
	out.append(Vector2(cur, b))
	return out


## Wall along X at constant z.
func wall_x(z: float, x0: float, x1: float, gaps: Array = []) -> void:
	for s in _segments(x0, x1, gaps):
		var a: float = s.x - (T * 0.5 if is_equal_approx(s.x, x0) else 0.0)
		var b: float = s.y + (T * 0.5 if is_equal_approx(s.y, x1) else 0.0)
		solid("Wall", Vector3(b - a, H, T), Vector3((a + b) * 0.5, H * 0.5, z), M.wall)
	for g in gaps:
		solid("Lintel", Vector3(g[1] - g[0], H - DOOR_H, T), Vector3((g[0] + g[1]) * 0.5, DOOR_H + (H - DOOR_H) * 0.5, z), M.wall)
		vbox("DoorTrim", Vector3(g[1] - g[0] + 0.3, 0.12, T + 0.06), Vector3((g[0] + g[1]) * 0.5, DOOR_H, z), M.wall_trim)


## Wall along Z at constant x.
func wall_z(x: float, z0: float, z1: float, gaps: Array = []) -> void:
	for s in _segments(z0, z1, gaps):
		var a: float = s.x - (T * 0.5 if is_equal_approx(s.x, z0) else 0.0)
		var b: float = s.y + (T * 0.5 if is_equal_approx(s.y, z1) else 0.0)
		solid("Wall", Vector3(T, H, b - a), Vector3(x, H * 0.5, (a + b) * 0.5), M.wall)
	for g in gaps:
		solid("Lintel", Vector3(T, H - DOOR_H, g[1] - g[0]), Vector3(x, DOOR_H + (H - DOOR_H) * 0.5, (g[0] + g[1]) * 0.5), M.wall)
		vbox("DoorTrim", Vector3(T + 0.06, 0.12, g[1] - g[0] + 0.3), Vector3(x, DOOR_H, (g[0] + g[1]) * 0.5), M.wall_trim)


func floor_tile(x0: float, z0: float, x1: float, z1: float, mat: Material) -> void:
	vbox("Floor", Vector3(x1 - x0, 0.02, z1 - z0), Vector3((x0 + x1) * 0.5, 0.0, (z0 + z1) * 0.5), mat)


func _shell() -> void:
	# One big collision floor + per-room colored floor visuals.
	solid("BaseFloor", Vector3(44, 0.2, 37), Vector3(4, -0.1, -3.5), M.base)
	vbox("Ceiling", Vector3(44, 0.2, 37), Vector3(4, H + 0.1, -3.5), M.ceiling)
	floor_tile(-10, -8, 10, 8, M.f_lobby)
	floor_tile(-4, 8, 4, 15, M.f_office)
	floor_tile(-18, -4, -10, 4, M.f_storage)
	floor_tile(-10, -22, 0, -8, M.f_gallery)
	floor_tile(0, -22, 10, -8, M.f_egypt)
	floor_tile(10, -16, 26, 8, M.f_dino)

	wall_x(15, -4, 4)
	wall_x(8, -10, 26, [[-1.2, 1.2]])
	wall_x(4, -18, -10)
	wall_x(-4, -18, -10)
	wall_x(-8, -10, 10, [[-6.2, -3.8], [3.8, 6.2]])
	wall_x(-16, 10, 26)
	wall_x(-22, -10, 10)
	wall_z(-18, -4, 4)
	wall_z(-10, -22, 8, [[-1.2, 1.2]])
	wall_z(-4, 8, 15)
	wall_z(4, 8, 15)
	wall_z(0, -22, -8, [[-16, -14]])
	wall_z(10, -22, 8, [[-13, -11], [-1.5, 1.5]])
	wall_z(26, -16, 8)

	# Signs above doors (lobby side)
	label("SECURITY OFFICE\n(SAFE ZONE)", Vector3(0, 3.2, 7.83), 180)
	label("STORAGE", Vector3(-9.83, 3.2, 0), 90)
	label("GALLERY OF FINE-ISH ART", Vector3(-5, 3.2, -7.83), 0)
	label("EGYPTIAN HALL\nQUIET ZONE - NO RUNNING", Vector3(5, 3.2, -7.83), 0)
	label("DINOSAUR HALL", Vector3(9.83, 3.2, 0), -90)


# --- Rooms ---------------------------------------------------------------

func _office() -> void:
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector3(0, 0.05, 11)
	spawn.rotation.y = PI # facing the desk
	museum.add_child(spawn)

	solid("Desk", Vector3(3.0, 0.8, 0.9), Vector3(0, 0.4, 14.3), M.wood)
	for x in [-0.8, 0.0, 0.8]:
		vbox("Monitor", Vector3(0.6, 0.45, 0.1), Vector3(x, 1.05, 14.55), M.dark)
		vbox("Screen", Vector3(0.52, 0.37, 0.02), Vector3(x, 1.05, 14.49), M.e_screen)
	label("CCTV: ALL QUIET (probably)", Vector3(0, 1.4, 14.48), 180, 0.0012)
	label("SECURITY OFFICE\nThe only room the exhibits can't enter. (Union rules.)", Vector3(0, 2.6, 14.83), 180, 0.002)

	var fl := interactable("Flashlight", "flashlight", "Take the flashlight", Vector3(1.15, 0.8, 14.1), Vector3(0.6, 0.4, 0.6), Vector3(0, 0.15, 0))
	visual("Body", cylinder(0.05, 0.05, 0.3, M.dark), Vector3(0, 0.06, 0), fl, Vector3(0, 0, 90))
	visual("Head", cylinder(0.075, 0.055, 0.08, M.metal), Vector3(-0.18, 0.06, 0), fl, Vector3(0, 0, 90))

	var clock := interactable("PunchClock", "clock_in", "Clock in", Vector3(3.6, 1.4, 11.0), Vector3(0.6, 0.8, 0.8))
	vbox("Box", Vector3(0.15, 0.6, 0.45), Vector3(0.17, 0, 0), M.metal, clock)
	vbox("Face", Vector3(0.02, 0.25, 0.25), Vector3(0.085, 0.12, 0), M.paper, clock)
	label("PUNCH CLOCK", Vector3(3.83, 1.9, 11.0), -90, 0.0018)

	var rules_text := "MUSEUM RULES FOR NIGHT STAFF\n\n" + "\n".join(SHIFT.RULES)
	vbox("Poster", Vector3(0.03, 1.9, 2.5), Vector3(-3.83, 1.75, 11.5), M.paper)
	var rl := label(rules_text, Vector3(-3.81, 1.75, 11.5), 90, 0.0016, null, Color(0.12, 0.1, 0.1))
	rl.outline_size = 0
	rl.width = 1450
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interactable("RulesPoster", "rules", "Read the Museum Rules", Vector3(-3.6, 1.75, 11.5), Vector3(0.5, 1.9, 2.5))

	solid("CoffeeMachine", Vector3(0.6, 1.2, 0.5), Vector3(-3.4, 0.6, 14.45), M.red)
	visual("CoffeeLight", sphere(0.04, M.e_green), Vector3(-3.25, 1.0, 14.18))
	interactable("Coffee", "coffee", "Drink terrible coffee", Vector3(-3.4, 0.9, 14.0), Vector3(0.8, 0.8, 0.5))
	label("COFFEE\nest. 1987", Vector3(-3.4, 1.45, 14.19), 180, 0.0015)
	solid("Locker", Vector3(0.9, 2.0, 0.6), Vector3(3.2, 1.0, 14.5), M.metal)

	# The office light is on its own generator: it stays on during the blackout.
	omni(Vector3(0, 3.3, 11.5), Color(1.0, 0.88, 0.7), 1.3, 9.0, "")


func _lobby() -> void:
	for x in [-6.0, 6.0]:
		for z in [-4.5, 4.5]:
			solid("Column", Vector3(0.8, H, 0.8), Vector3(x, H * 0.5, z), M.wall)
	vbox("Carpet", Vector3(1.8, 0.01, 1.8), Vector3(0, 0.015, -3), M.red)
	sign_stand(Vector3(1.4, 0, -2.0), 20, "SIR CLANKSWORTH\nSuit of armor, c. 1450.\nEmpty. Definitely empty.")

	# Golden Duck pedestal
	pedestal(Vector3(-5, 0, 1), "THE GOLDEN DUCK\nPriceless. Do not lose.")
	var ped := interactable("DuckPedestal", "duck_pedestal", "Return the Golden Duck", Vector3(-5, 0, 1), Vector3(1.0, 1.4, 1.0), Vector3(0, 0.8, 0), false, museum)
	ped.name = "DuckPedestal"
	var duck := interactable("Duck", "duck", "Take the Golden Duck", Vector3(-5, 1.06, 1), Vector3(0.5, 0.5, 0.5), Vector3(0, 0.25, 0), false, museum)
	duck.name = "Duck"
	visual("Body", sphere(0.17, M.gold), Vector3(0, 0.15, 0), duck)
	visual("Head", sphere(0.1, M.gold), Vector3(0, 0.36, -0.1), duck)
	vbox("Beak", Vector3(0.08, 0.03, 0.08), Vector3(0, 0.35, -0.21), M.e_red, duck)
	var spots := _group(museum, "DuckSpots")
	for p in [Vector3(-11.2, 0, -3.2), Vector3(-1.0, 0, -21.0), Vector3(9.0, 0, -9.2), Vector3(12.0, 0, 7.0)]:
		var m := Marker3D.new()
		m.name = _uname("Spot")
		m.position = p
		spots.add_child(m)

	solid("Bench", Vector3(2.2, 0.5, 0.6), Vector3(5, 0.25, 2), M.wood)
	solid("Bench", Vector3(2.2, 0.5, 0.6), Vector3(5, 0.25, -1), M.wood)
	solid("InfoDesk", Vector3(3.0, 1.1, 1.0), Vector3(6.5, 0.55, 6.2), M.wood)
	label("INFORMATION\n(none available)", Vector3(6.5, 0.7, 5.69), 180, 0.0018)
	battery(Vector3(6.0, 1.1, 6.2))

	pedestal(Vector3(-6.5, 0, -5.5), "ANCIENT SPOON\nBronze Age, probably.\nDonated by someone's aunt.")
	vbox("Case", Vector3(0.6, 0.5, 0.6), Vector3(-6.5, 1.31, -5.5), M.glass)
	vbox("Spoon", Vector3(0.3, 0.02, 0.05), Vector3(-6.5, 1.1, -5.5), M.metal)

	for p in [Vector3(-9.3, 0, 7.3), Vector3(9.3, 0, -7.3)]:
		solid("Planter", Vector3(0.6, 0.5, 0.6), p + Vector3(0, 0.25, 0), M.wood)
		visual("Plant", sphere(0.4, M.plant), p + Vector3(0, 0.9, 0))
	label("WELCOME TO THE PEMBERTON MUSEUM\nOF QUESTIONABLE HISTORY", Vector3(0, 3.0, -7.83), 0, 0.003)

	for x in [-5.0, 5.0]:
		for z in [-4.0, 4.0]:
			omni(Vector3(x, 3.5, z), Color(1.0, 0.85, 0.65), 0.9, 9.0)
	omni(Vector3(0, 3.6, 0), Color(1, 0.05, 0.05), 0.5, 10.0, "emergency_lights", false)


func _storage() -> void:
	solid("Crate", Vector3(1, 1, 1), Vector3(-16.5, 0.5, -2.8), M.crate)
	solid("Crate", Vector3(0.9, 0.9, 0.9), Vector3(-16.4, 1.45, -2.8), M.crate)
	solid("Crate", Vector3(1, 1, 1), Vector3(-15.3, 0.5, -2.9), M.crate)
	solid("Crate", Vector3(1.2, 1.2, 1.2), Vector3(-16.8, 0.6, 2.8), M.crate)
	solid("Crate", Vector3(0.8, 0.8, 0.8), Vector3(-12.5, 0.4, 3.0), M.crate)
	solid("Shelf", Vector3(3, 2, 0.6), Vector3(-13.0, 1.0, -3.55), M.metal)
	label("LOST & FOUND: 3 umbrellas, 1 sarcophagus lid,\n1 left shoe (size: pharaoh)", Vector3(-13.0, 2.6, -3.83), 0, 0.0018)
	battery(Vector3(-12.5, 0.8, 3.0))

	var br := interactable("Breaker", "breaker", "Flip the breaker", Vector3(-17.55, 1.4, 0), Vector3(0.6, 1.0, 0.9))
	vbox("Box", Vector3(0.2, 0.9, 0.7), Vector3(-0.2, 0, 0), M.metal, br)
	vbox("Lever", Vector3(0.12, 0.3, 0.08), Vector3(-0.05, 0.05, 0), M.red, br)
	visual("Indicator", sphere(0.05, M.e_red), Vector3(-0.08, 0.32, 0.22), br)
	label("BREAKER\nFlip only if the power is out.\nOr if bored.", Vector3(-17.83, 2.25, 0), 90, 0.0018)

	omni(Vector3(-14, 3.3, 0), Color(0.75, 0.85, 1.0), 0.6, 7.0)
	omni(Vector3(-14, 3.6, 0), Color(1, 0.05, 0.05), 0.4, 7.0, "emergency_lights", false)


func _gallery() -> void:
	painting(Vector3(-9.82, 1.9, -18), 90, Vector2(1.2, 1.5), Color(0.25, 0.2, 0.15), "PORTRAIT OF A MAN WHO SAW SOMETHING\nOil on canvas, 1823", true)
	painting(Vector3(-9.82, 1.9, -12.5), 90, Vector2(1.6, 1.1), Color(0.5, 0.6, 0.3), "STILL LIFE WITH ANGRY PEAR\nArtist unknown (in hiding)")
	painting(Vector3(-7, 1.9, -21.82), 0, Vector2(1.8, 1.2), Color(0.02, 0.02, 0.03), "LANDSCAPE, BUT AT NIGHT\nIt's just black. It was very expensive.")
	painting(Vector3(-3, 1.9, -21.82), 0, Vector2(1.1, 1.5), Color(0.4, 0.15, 0.25), "THE DUCHESS, DISAPPOINTED\nShe has read your performance review.", true)

	pedestal(Vector3(-5, 0, -15), "PRICELESS VASE\nPlease do not touch.\nSeriously.")
	visual("Vase", cylinder(0.12, 0.2, 0.5, _mat(Color(0.2, 0.35, 0.8), 0.0, 0.2, 0.3)), Vector3(-5, 1.31, -15))
	interactable("Vase", "touch_vase", "Touch the Priceless Vase", Vector3(-5, 1.1, -15), Vector3(0.6, 0.6, 0.6), Vector3(0, 0.2, 0))
	solid("Bench", Vector3(2.2, 0.5, 0.6), Vector3(-5, 0.25, -11), M.wood)

	wall_panel("CheckpointGallery", "checkpoint_gallery", "Scan patrol checkpoint", Vector3(-0.15, 1.4, -19.5), Vector3(-1, 0, 0), "PATROL CHECKPOINT")
	battery(Vector3(-9.2, 0.0, -21.2))

	omni(Vector3(-5, 3.4, -18), Color(1.0, 0.85, 0.65), 0.7, 8.0)
	omni(Vector3(-5, 3.4, -11.5), Color(1.0, 0.85, 0.65), 0.7, 8.0)
	omni(Vector3(-5, 3.6, -15), Color(1, 0.05, 0.05), 0.4, 8.0, "emergency_lights", false)


func _egypt() -> void:
	solid("Sarcophagus", Vector3(1.3, 2.4, 0.7), Vector3(5, 1.2, -21.45), M.gold)
	vbox("Mask", Vector3(0.5, 0.6, 0.05), Vector3(5, 1.9, -21.08), M.stone)
	vbox("Lid", Vector3(1.2, 2.2, 0.15), Vector3(6.7, 1.1, -21.3), M.gold, null, Vector3(0, 0, -8))
	label("THE PHARAOH'S NEIGHBOUR\nNot a pharaoh. Lived next to one.\nLIGHT SLEEPER.", Vector3(3.3, 1.8, -21.83), 0, 0.0018)

	for p in [Vector3(1.6, 0, -20), Vector3(8.4, 0, -20), Vector3(1.6, 0, -10.5), Vector3(8.4, 0, -10.5)]:
		solid("Pillar", Vector3(0.9, H, 0.9), p + Vector3(0, H * 0.5, 0), M.stone)

	var pyr := StaticBody3D.new()
	pyr.name = "Pyramid"
	pyr.position = Vector3(2.8, 0.75, -15)
	level.add_child(pyr)
	visual("Mesh", cylinder(0.0, 1.1, 1.5, M.stone, 4), Vector3.ZERO, pyr, Vector3(0, 45, 0))
	var pcs := CollisionShape3D.new()
	pcs.name = "Shape"
	var psh := BoxShape3D.new()
	psh.size = Vector3(1.5, 1.5, 1.5)
	pcs.shape = psh
	pyr.add_child(pcs)
	var pl := label("MODEL PYRAMID\nScale 1:100. Built by interns.", Vector3(2.8, 1.8, -15), 0, 0.0016)
	pl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y

	solid("JarTable", Vector3(1.6, 0.8, 0.6), Vector3(7.5, 0.4, -15), M.wood)
	for x in [7.0, 7.5, 8.0]:
		visual("Jar", cylinder(0.08, 0.11, 0.32, M.stone), Vector3(x, 0.96, -15))
		visual("JarLid", sphere(0.07, M.gold), Vector3(x, 1.15, -15))
	label("CURSED CANOPIC JARS\nContents: classified.", Vector3(7.5, 0.55, -14.69), 0, 0.0015)
	interactable("Jar", "touch_jar", "Touch the Cursed Canopic Jar", Vector3(7.5, 0.8, -15), Vector3(1.6, 0.5, 0.6), Vector3(0, 0.25, 0))

	label("SHHH.\nNO RUNNING.\nHE'S SLEEPING.", Vector3(2.0, 2.0, -8.17), 180, 0.0025, null, Color(1.0, 0.8, 0.5))
	wall_panel("CheckpointEgypt", "checkpoint_egypt", "Scan patrol checkpoint", Vector3(9.85, 1.4, -19.5), Vector3(-1, 0, 0), "PATROL CHECKPOINT")

	omni(Vector3(5, 3.4, -18), Color(1.0, 0.65, 0.35), 0.8, 8.0)
	omni(Vector3(5, 3.4, -11), Color(1.0, 0.65, 0.35), 0.8, 8.0)
	omni(Vector3(5, 3.6, -15), Color(1, 0.05, 0.05), 0.4, 8.0, "emergency_lights", false)


func _dino_hall() -> void:
	solid("DinoPlatform", Vector3(7, 0.3, 3.2), Vector3(19.5, 0.15, -4), M.dark)

	var dino := Node3D.new()
	dino.name = "Dino"
	dino.position = Vector3(19.5, 0.3, -4)
	_attach(dino, DINO)
	museum.add_child(dino)
	for z in [-0.6, 0.6]:
		vbox("Leg", Vector3(0.35, 1.6, 0.35), Vector3(0, 0.8, z), M.bone, dino)
		vbox("Foot", Vector3(0.8, 0.1, 0.35), Vector3(-0.3, 0.05, z), M.bone, dino)
		vbox("Arm", Vector3(0.45, 0.12, 0.12), Vector3(-1.0, 1.75, z * 0.75), M.bone, dino)
	vbox("Body", Vector3(2.6, 1.1, 1.1), Vector3(0, 2.0, 0), M.bone, dino)
	for i in 5:
		vbox("Rib", Vector3(0.12, 1.2, 1.25), Vector3(-0.9 + i * 0.45, 1.95, 0), M.bone, dino)
	vbox("Tail", Vector3(1.6, 0.55, 0.55), Vector3(2.1, 1.9, 0), M.bone, dino)
	vbox("Tail", Vector3(1.4, 0.4, 0.4), Vector3(3.6, 1.65, 0), M.bone, dino)
	vbox("Tail", Vector3(1.0, 0.25, 0.25), Vector3(4.8, 1.4, 0), M.bone, dino)
	vbox("Neck", Vector3(0.9, 0.5, 0.5), Vector3(-1.6, 2.5, 0), M.bone, dino)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(-2.1, 2.7, 0)
	dino.add_child(head)
	vbox("Skull", Vector3(1.3, 0.75, 0.8), Vector3(-0.55, 0.1, 0), M.bone, head)
	vbox("Jaw", Vector3(1.2, 0.18, 0.7), Vector3(-0.5, -0.4, 0), M.bone, head)
	var eye_mesh := sphere(0.09, M.e_dino_eye)
	var eye_l := visual("EyeL", eye_mesh, Vector3(-0.75, 0.25, 0.41), head)
	eye_l.name = "EyeL"
	var eye_r := visual("EyeR", eye_mesh, Vector3(-0.75, 0.25, -0.41), head)
	eye_r.name = "EyeR"
	var eye_point := Marker3D.new()
	eye_point.name = "EyePoint"
	eye_point.position = Vector3(-0.75, 0.25, 0)
	head.add_child(eye_point)
	sign_stand(Vector3(15.2, 0, -1.8), -90, "GERALD\nTyrannosaurus rex (juvenile)\nVery shy. NO FLASH PHOTOGRAPHY.")

	pedestal(Vector3(13.5, 0, 5), "FOSSILIZED EGG\nMay still hatch.\nPlease don't.", -90)
	var egg := visual("Egg", sphere(0.18, _mat(Color(0.7, 0.65, 0.55))), Vector3(13.5, 1.25, 5))
	egg.scale = Vector3(1, 1.3, 1)
	interactable("Egg", "touch_egg", "Touch the Fossilized Egg", Vector3(13.5, 1.05, 5), Vector3(0.6, 0.6, 0.6), Vector3(0, 0.2, 0))

	var meteor := solid("Meteor", Vector3(1.2, 1.0, 1.2), Vector3(23, 0.5, 5), M.dark)
	(meteor.get_node("Mesh") as MeshInstance3D).mesh = sphere(0.7, _mat(Color(0.2, 0.17, 0.15)))
	var ml := label("METEOR FRAGMENT\nThe original party pooper.", Vector3(23, 1.7, 5), -90, 0.0018)
	ml.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y

	wall_panel("CheckpointDino", "checkpoint_dino", "Scan patrol checkpoint", Vector3(25.85, 1.4, 0), Vector3(-1, 0, 0), "PATROL CHECKPOINT")
	battery(Vector3(24.6, 0.0, -15.0))

	omni(Vector3(14, 3.5, -4), Color(0.75, 0.85, 1.0), 1.1, 11.0)
	omni(Vector3(19.5, 3.5, 3), Color(0.75, 0.85, 1.0), 1.1, 11.0)
	omni(Vector3(23, 3.5, -10), Color(0.75, 0.85, 1.0), 1.1, 11.0)
	omni(Vector3(18, 3.6, -4), Color(1, 0.05, 0.05), 0.5, 11.0, "emergency_lights", false)


func _rooms() -> void:
	var rooms := _group(museum, "Rooms")
	var data := {
		"lobby": Rect2(-10, -8, 20, 16),
		"office": Rect2(-4, 8, 8, 7),
		"storage": Rect2(-18, -4, 8, 8),
		"gallery": Rect2(-10, -22, 10, 14),
		"egypt": Rect2(0, -22, 10, 14),
		"dino": Rect2(10, -16, 16, 24),
	}
	for id in data:
		var r: Rect2 = data[id]
		var a := Area3D.new()
		a.name = "Room_" + id
		_attach(a, ROOM_AREA, {"room_id": id})
		a.collision_layer = 0
		a.collision_mask = 2
		a.monitorable = false
		a.position = Vector3(r.position.x + r.size.x * 0.5, H * 0.5, r.position.y + r.size.y * 0.5)
		rooms.add_child(a)
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		var sh := BoxShape3D.new()
		sh.size = Vector3(r.size.x, H, r.size.y)
		cs.shape = sh
		a.add_child(cs)


# --- Enemies -------------------------------------------------------------

func _enemy_body(n: String, script: Script, pos: Vector3, yaw: float) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = n
	_attach(body, script)
	body.position = pos
	body.rotation.y = yaw
	body.collision_layer = 4
	body.collision_mask = 1
	museum.add_child(body)
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.9
	cs.shape = cap
	cs.position = Vector3(0, 0.95, 0)
	body.add_child(cs)
	var agent := NavigationAgent3D.new()
	agent.name = "Agent"
	agent.radius = 0.5
	agent.height = 1.9
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 0.9
	body.add_child(agent)
	return body


func _knight() -> void:
	var k := _enemy_body("Knight", KNIGHT, Vector3(0, 0.02, -3), PI)
	var m := _group(k, "Model")
	for x in [-0.15, 0.15]:
		vbox("Leg", Vector3(0.18, 0.9, 0.2), Vector3(x, 0.45, 0), M.metal, m)
	vbox("Torso", Vector3(0.6, 0.75, 0.35), Vector3(0, 1.25, 0), M.metal, m)
	vbox("Belt", Vector3(0.62, 0.12, 0.37), Vector3(0, 0.9, 0), M.dark, m)
	for x in [-0.38, 0.38]:
		visual("Shoulder", sphere(0.14, M.metal), Vector3(x, 1.55, 0), m)
		vbox("Arm", Vector3(0.14, 0.7, 0.16), Vector3(x, 1.15, 0), M.metal, m)
	vbox("Helmet", Vector3(0.34, 0.38, 0.36), Vector3(0, 1.82, 0), M.metal, m)
	vbox("Visor", Vector3(0.24, 0.04, 0.02), Vector3(0, 1.84, -0.185), M.e_visor, m)
	vbox("Plume", Vector3(0.06, 0.2, 0.3), Vector3(0, 2.1, 0.05), M.red, m)
	vbox("Sword", Vector3(0.06, 1.1, 0.04), Vector3(0.5, 0.7, -0.15), M.metal, m)
	vbox("Hilt", Vector3(0.25, 0.05, 0.05), Vector3(0.5, 1.28, -0.15), M.gold, m)
	vbox("Shield", Vector3(0.06, 0.6, 0.45), Vector3(-0.48, 1.1, -0.05), M.red, m)


func _mummy() -> void:
	var mu := _enemy_body("Mummy", MUMMY, Vector3(5, 0.02, -20.5), PI)
	var m := _group(mu, "Model")
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.3
	body_mesh.height = 1.6
	body_mesh.material = M.bandage
	visual("Body", body_mesh, Vector3(0, 0.85, 0), m)
	visual("Head", sphere(0.2, M.bandage), Vector3(0, 1.78, 0), m)
	for x in [-0.07, 0.07]:
		visual("Eye", sphere(0.03, M.e_mummy_eye), Vector3(x, 1.8, -0.18), m)
	for x in [-0.22, 0.22]:
		vbox("Arm", Vector3(0.12, 0.12, 0.6), Vector3(x, 1.35, -0.35), M.bandage, m)
	for y in [0.4, 0.75, 1.1, 1.4]:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.28
		torus.outer_radius = 0.33
		torus.material = M.bandage_dark
		visual("Wrap", torus, Vector3(0, y, 0), m)
	vbox("LooseBandage", Vector3(0.06, 0.5, 0.02), Vector3(0.2, 1.0, -0.31), M.bandage_dark, m, Vector3(0, 0, 12))


# --- Finish --------------------------------------------------------------

func _bake_navigation() -> void:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.25
	level.navigation_mesh = nm
	level.bake_navigation_mesh(false)
	print("Navigation polygons: ", nm.get_polygon_count())


func _set_owner(node: Node) -> void:
	for c in node.get_children():
		c.owner = museum
		_set_owner(c)
