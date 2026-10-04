class_name Props
extends RefCounted
## Procedural models for the museum (build time only). Each function returns a Node3D
## whose children are MeshInstance3D parts. Materials are saved to res://materials/.

const ML := preload("res://tools/meshlib.gd")

var M := {}          # name -> Material
var _cache := {}     # key -> Mesh (reuse identical meshes)


func _init() -> void:
	_make_materials()


# ------------------------------------------------------------ materials ---

func _tex(name: String) -> Texture2D:
	return load("res://textures/%s.jpg" % name)


func tex_mat(key: String, tex: String, scale: float, opts: Dictionary = {}) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.albedo_texture = _tex(tex + "_albedo")
	m.albedo_color = opts.get("tint", Color.WHITE)
	m.normal_enabled = true
	m.normal_texture = _tex(tex + "_normal")
	m.normal_scale = opts.get("normal", 1.0)
	m.roughness_texture = _tex(tex + "_rough")
	m.roughness = opts.get("roughness", 1.0)
	m.metallic = opts.get("metallic", 0.0)
	if opts.has("metallic_tex"):
		m.metallic_texture = _tex(opts["metallic_tex"])
		m.metallic = 1.0
	m.uv1_triplanar = true
	m.uv1_world_triplanar = opts.get("world", true)
	m.uv1_scale = Vector3.ONE * scale
	m.uv1_triplanar_sharpness = 4.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return _save(m, key)


func flat_mat(key: String, color: Color, rough: float, metallic: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return _save(m, key)


func _save(m: Material, key: String) -> Material:
	var path := "res://materials/%s.tres" % key
	ResourceSaver.save(m, path)
	m.take_over_path(path)
	M[key] = m
	return m


func _make_materials() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://materials"))
	# Floors
	tex_mat("marble", "marble_floor", 0.33, {"normal": 0.6})
	tex_mat("wood_floor", "wood_floor", 0.35)
	tex_mat("stone_floor", "stone_tiles", 0.3)
	tex_mat("sand_floor", "stone_tiles", 0.3, {"tint": Color(1.35, 1.05, 0.7)})
	tex_mat("concrete", "concrete", 0.3)
	tex_mat("carpet", "velvet", 0.6, {"tint": Color(0.75, 0.75, 0.8)})
	# Walls
	tex_mat("plaster_cream", "plaster", 0.3, {"tint": Color(1.0, 0.96, 0.9)})
	tex_mat("plaster_green", "plaster", 0.3, {"tint": Color(0.45, 0.55, 0.5)})
	tex_mat("plaster_blue", "plaster", 0.3, {"tint": Color(0.55, 0.62, 0.72)})
	tex_mat("plaster_white", "plaster", 0.3, {"tint": Color(1.15, 1.15, 1.12)})
	tex_mat("sandstone", "sandstone", 0.25)
	tex_mat("wallpaper", "wallpaper", 0.6)
	tex_mat("wallpaper_green", "wallpaper", 0.6, {"tint": Color(0.5, 1.6, 1.0)})
	tex_mat("ceiling", "ceiling", 0.35)
	tex_mat("dark_wood", "dark_wood", 0.6)
	tex_mat("dark_wood_obj", "dark_wood", 1.5, {"world": false})
	tex_mat("crate", "crate", 0.8, {"world": false})
	# Objects (object-space triplanar so textures move with the object)
	tex_mat("metal", "metal", 1.5, {"world": false, "metallic_tex": "metal_metallic", "roughness": 1.0})
	tex_mat("steel_dark", "metal", 1.5, {"world": false, "metallic_tex": "metal_metallic", "tint": Color(0.45, 0.45, 0.48)})
	tex_mat("gold", "gold", 1.2, {"world": false, "metallic": 1.0})
	tex_mat("brass", "gold", 2.0, {"world": false, "metallic": 0.9, "tint": Color(0.75, 0.6, 0.4)})
	tex_mat("velvet", "velvet", 2.0, {"world": false})
	tex_mat("linen", "linen", 2.5, {"world": false, "normal": 1.5})
	tex_mat("linen_dark", "linen", 2.5, {"world": false, "tint": Color(0.6, 0.55, 0.45)})
	tex_mat("bone", "bone", 1.2, {"world": false})
	tex_mat("wax", "wax", 1.0, {"world": false})
	tex_mat("porcelain", "porcelain", 1.5, {"world": false})
	tex_mat("uniform", "uniform", 2.0, {"world": false})
	tex_mat("terracotta", "plaster", 1.5, {"world": false, "tint": Color(0.85, 0.42, 0.22)})
	tex_mat("lapis", "plaster", 1.5, {"world": false, "tint": Color(0.18, 0.28, 0.65)})
	tex_mat("stone_obj", "sandstone", 0.8, {"world": false})
	tex_mat("cloth_red", "velvet", 2.0, {"world": false, "tint": Color(0.9, 0.7, 0.7)})
	tex_mat("cloth_black", "uniform", 2.0, {"world": false, "tint": Color(0.35, 0.3, 0.3)})
	tex_mat("cloth_green", "velvet", 2.0, {"world": false, "tint": Color(0.25, 0.9, 0.35)})
	tex_mat("pine", "velvet", 1.0, {"world": false, "tint": Color(0.12, 0.35, 0.18)})
	tex_mat("bark", "dark_wood", 2.0, {"world": false})
	tex_mat("ground", "stone_tiles", 0.1, {"tint": Color(0.35, 0.45, 0.35)})
	flat_mat("leather", Color(0.12, 0.08, 0.06), 0.55)
	flat_mat("rubber", Color(0.03, 0.03, 0.03), 0.8)
	flat_mat("black_plastic", Color(0.04, 0.04, 0.045), 0.45)
	flat_mat("skin", Color(0.78, 0.6, 0.5), 0.6)
	flat_mat("eye_white", Color(0.9, 0.88, 0.82), 0.15)
	flat_mat("eye_dark", Color(0.02, 0.02, 0.02), 0.1)
	flat_mat("hair", Color(0.08, 0.05, 0.03), 0.7)
	flat_mat("socket", Color(0.01, 0.01, 0.01), 1.0)
	flat_mat("e_bulb", Color(1.0, 0.82, 0.55), 0.5, 0.0, 6.0)
	flat_mat("e_bulb_cold", Color(0.85, 0.92, 1.0), 0.5, 0.0, 5.0)
	flat_mat("e_red", Color(1.0, 0.05, 0.03), 0.5, 0.0, 6.0)
	flat_mat("e_green", Color(0.2, 1.0, 0.35), 0.5, 0.0, 4.0)
	flat_mat("e_visor", Color(1.0, 0.12, 0.05), 0.5, 0.0, 8.0)
	flat_mat("e_mummy_eye", Color(0.35, 1.0, 0.45), 0.5, 0.0, 9.0)
	flat_mat("e_dino_eye", Color(1.0, 0.6, 0.15), 0.5, 0.0, 1.0)
	flat_mat("e_screen", Color(0.35, 0.55, 0.5), 0.3, 0.0, 1.6)
	flat_mat("e_amber", Color(1.0, 0.55, 0.1), 0.5, 0.0, 4.0)
	var glass := StandardMaterial3D.new()
	glass.resource_name = "glass"
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.75, 0.85, 0.9, 0.12)
	glass.roughness = 0.03
	glass.metallic = 0.2
	glass.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_save(glass, "glass")
	var specimen := StandardMaterial3D.new()
	specimen.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	specimen.albedo_color = Color(0.5, 0.75, 0.3, 0.45)
	specimen.roughness = 0.1
	specimen.emission_enabled = true
	specimen.emission = Color(0.2, 0.35, 0.1)
	_save(specimen, "specimen_liquid")
	for p in ["painting_man", "painting_duchess", "painting_pear", "painting_landscape", "painting_night", "painting_founder", "painting_lady", "painting_hills"]:
		var pm := StandardMaterial3D.new()
		pm.albedo_texture = _tex(p)
		pm.roughness = 0.55
		pm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_save(pm, p)


# --------------------------------------------------------------- helpers ---

func node(name: String) -> Node3D:
	var n := Node3D.new()
	n.name = name
	return n


func part(parent: Node3D, name: String, mesh: Mesh, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scale
	parent.add_child(mi)
	return mi


func cached(key: String, maker: Callable) -> Mesh:
	if not _cache.has(key):
		_cache[key] = maker.call()
	return _cache[key]


func bbox(size: Vector3, bevel: float, mat_key: String) -> Mesh:
	var key := "bbox_%s_%s_%s" % [size, bevel, mat_key]
	return cached(key, func() -> Mesh: return ML.bevel_box(size, bevel, M[mat_key]))


func sphere(r: float, mat_key: String, rings: int = 10) -> Mesh:
	var key := "sphere_%s_%s" % [r, mat_key]
	return cached(key, func() -> Mesh:
		return ML.lathe(ML.curve(func(t: float) -> Vector2: return Vector2(sin(t * PI) * r, -cos(t * PI) * r), rings), M[mat_key], {"segments": 16, "sharp": 80.0}))


func cyl(r_bottom: float, r_top: float, h: float, mat_key: String, segments: int = 16) -> Mesh:
	var key := "cyl_%s_%s_%s_%s_%s" % [r_bottom, r_top, h, mat_key, segments]
	return cached(key, func() -> Mesh:
		return ML.lathe(ML.prof([0.0, 0.0, r_bottom, 0.0, r_top, h, 0.0, h]), M[mat_key], {"segments": segments}))


func limb(length: float, r0: float, r1: float, mat_key: String, noise: float = 0.0, sides: int = 10) -> Mesh:
	## Tapered segment hanging down from its pivot (along -Y), rounded ends.
	var key := "limb_%s_%s_%s_%s_%s" % [length, r0, r1, mat_key, noise]
	return cached(key, func() -> Mesh:
		var pts := PackedVector3Array()
		var radii := []
		var steps := 8
		for i in steps + 1:
			var t := float(i) / steps
			pts.append(Vector3(0, -t * length, 0))
			var r := lerpf(r0, r1, t)
			if i == 0 or i == steps:
				r *= 0.75
			radii.append(r)
		return ML.tube(pts, radii, M[mat_key], {"sides": sides, "noise": noise, "twist": 3.0 if noise > 0.0 else 0.0}))


# ---------------------------------------------------------- architecture ---

func column(height: float) -> Node3D:
	var root := node("Column")
	var base_h := 0.35
	part(root, "Plinth", bbox(Vector3(1.0, 0.25, 1.0), 0.02, "marble"), Vector3(0, 0.125, 0))
	part(root, "Base", cached("col_base", func() -> Mesh:
		return ML.lathe(ML.prof([0.0, 0.0, 0.46, 0.0, 0.46, 0.04, 0.42, 0.08, 0.44, 0.12, 0.38, 0.16, 0.36, 0.2]), M["plaster_white"], {"segments": 28})), Vector3(0, 0.25, 0))
	var shaft_h := height - base_h - 0.6
	part(root, "Shaft", cached("col_shaft_%s" % shaft_h, func() -> Mesh:
		var prof := PackedVector2Array()
		for i in 13:
			var t := float(i) / 12.0
			prof.append(Vector2(0.34 - 0.04 * t * t, t * shaft_h)) # entasis
		return ML.lathe(prof, M["plaster_white"], {"segments": 48, "flutes": 16, "flute_depth": 0.07, "sharp": 80.0})), Vector3(0, base_h + 0.1, 0))
	part(root, "Capital", cached("col_cap", func() -> Mesh:
		return ML.lathe(ML.prof([0.30, 0.0, 0.32, 0.05, 0.30, 0.1, 0.33, 0.14, 0.45, 0.3, 0.5, 0.36]), M["plaster_white"], {"segments": 28})), Vector3(0, height - 0.5, 0))
	part(root, "Abacus", bbox(Vector3(1.1, 0.14, 1.1), 0.02, "plaster_white"), Vector3(0, height - 0.07, 0))
	return root


func pedestal(w: float, h: float, mat: String = "marble") -> Node3D:
	var root := node("Pedestal")
	part(root, "Foot", bbox(Vector3(w + 0.12, 0.1, w + 0.12), 0.02, mat), Vector3(0, 0.05, 0))
	part(root, "Body", bbox(Vector3(w, h - 0.18, w), 0.015, mat), Vector3(0, 0.1 + (h - 0.18) / 2.0, 0))
	part(root, "Top", bbox(Vector3(w + 0.1, 0.08, w + 0.1), 0.02, mat), Vector3(0, h - 0.04, 0))
	return root


func display_case(w: float, d: float, h: float, case_h: float = 0.6) -> Node3D:
	var root := node("DisplayCase")
	part(root, "Base", bbox(Vector3(w, h, d), 0.02, "dark_wood"), Vector3(0, h / 2.0, 0))
	part(root, "Glass", cached("glassbox_%s_%s_%s" % [w, d, case_h], func() -> Mesh:
		return ML.bevel_box(Vector3(w - 0.04, case_h, d - 0.04), 0.005, M["glass"], 1)), Vector3(0, h + case_h / 2.0, 0))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			part(root, "Edge", bbox(Vector3(0.025, case_h, 0.025), 0.005, "brass"), Vector3(sx * (w / 2.0 - 0.02), h + case_h / 2.0, sz * (d / 2.0 - 0.02)))
	part(root, "TopTrim", bbox(Vector3(w, 0.025, d), 0.005, "brass"), Vector3(0, h + case_h, 0))
	return root


func bench(length: float) -> Node3D:
	var root := node("Bench")
	part(root, "Seat", bbox(Vector3(length, 0.08, 0.5), 0.02, "dark_wood_obj"), Vector3(0, 0.42, 0))
	part(root, "Cushion", bbox(Vector3(length - 0.08, 0.07, 0.44), 0.03, "velvet"), Vector3(0, 0.49, 0))
	var leg := cached("bench_leg", func() -> Mesh:
		return ML.lathe(ML.prof([0.0, 0.0, 0.035, 0.0, 0.045, 0.05, 0.03, 0.12, 0.04, 0.2, 0.028, 0.32, 0.04, 0.38, 0.0, 0.38]), M["brass"], {"segments": 12}))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			part(root, "Leg", leg, Vector3(sx * (length / 2.0 - 0.12), 0, sz * 0.18))
	return root


func rope_post() -> Node3D:
	var root := node("RopePost")
	part(root, "Post", cached("rope_post", func() -> Mesh:
		return ML.lathe(ML.prof([0.0, 0.0, 0.17, 0.0, 0.17, 0.03, 0.12, 0.06, 0.03, 0.1, 0.022, 0.85, 0.035, 0.88, 0.04, 0.93, 0.0, 0.99]), M["brass"], {"segments": 18})))
	return root


func rope(a: Vector3, b: Vector3, sag: float = 0.18) -> Node3D:
	var root := node("Rope")
	var pts := PackedVector3Array()
	for i in 13:
		var t := float(i) / 12.0
		var p := a.lerp(b, t)
		p.y -= sag * 4.0 * t * (1.0 - t)
		pts.append(p)
	part(root, "Rope", ML.tube(pts, [0.022], M["velvet"], {"sides": 8}))
	return root


func chandelier() -> Node3D:
	var root := node("Chandelier")
	part(root, "Chain", cyl(0.012, 0.012, 1.0, "brass", 6), Vector3(0, -1.0, 0))
	part(root, "Body", cached("chand_body", func() -> Mesh:
		return ML.lathe(ML.prof([0.0, -0.5, 0.06, -0.48, 0.12, -0.35, 0.08, -0.2, 0.14, -0.1, 0.05, 0.0, 0.0, 0.0]), M["brass"], {"segments": 18})), Vector3(0, -1.0, 0))
	var arm := cached("chand_arm", func() -> Mesh:
		var pts := PackedVector3Array()
		for i in 9:
			var t := float(i) / 8.0
			pts.append(Vector3(t * 0.55, -0.3 - sin(t * PI) * 0.12 + t * 0.1, 0))
		return ML.tube(pts, [0.014], M["brass"], {"sides": 6}))
	var cup := cached("chand_cup", func() -> Mesh:
		return ML.lathe(ML.prof([0.0, 0.0, 0.035, 0.0, 0.05, 0.05, 0.045, 0.06, 0.0, 0.06]), M["brass"], {"segments": 10}))
	var bulb := cached("chand_bulb", func() -> Mesh:
		return ML.lathe(ML.curve(func(t: float) -> Vector2: return Vector2(sin(t * PI) * (0.025 + 0.012 * t), t * 0.09), 8), M["e_bulb"], {"segments": 10, "sharp": 80.0}))
	for k in 8:
		var a := TAU * k / 8.0
		var pivot := node("Arm%d" % k)
		pivot.rotation.y = a
		pivot.position = Vector3(0, -1.0, 0)
		root.add_child(pivot)
		part(pivot, "Arm", arm)
		part(pivot, "Cup", cup, Vector3(0.55, -0.2, 0))
		part(pivot, "Bulb", bulb, Vector3(0.55, -0.15, 0))
	return root


func sconce() -> Node3D:
	## Wall lamp facing +Z (mount on a wall, local +Z points into the room).
	var root := node("Sconce")
	part(root, "Plate", cached("sconce_plate", func() -> Mesh:
		return ML.lathe(ML.prof([0.0, 0.0, 0.07, 0.0, 0.08, 0.015, 0.05, 0.03, 0.0, 0.03]), M["brass"], {"segments": 14})), Vector3.ZERO, Vector3(90, 0, 0))
	part(root, "Arm", cached("sconce_arm", func() -> Mesh:
		var pts := PackedVector3Array()
		for i in 7:
			var t := float(i) / 6.0
			pts.append(Vector3(0, -sin(t * PI) * 0.06 + t * 0.08, t * 0.22))
		return ML.tube(pts, [0.012], M["brass"], {"sides": 6})))
	part(root, "Shade", cached("sconce_shade", func() -> Mesh:
		return ML.lathe(ML.prof([0.03, 0.0, 0.09, 0.14, 0.085, 0.15]), M["e_bulb"], {"segments": 16})), Vector3(0, 0.08, 0.22))
	return root


func painting(w: float, h: float, mat_key: String) -> Node3D:
	## Framed canvas facing +Z, centered at origin.
	var root := node("Painting")
	var fw := maxf(0.08, minf(w, h) * 0.09)
	var prof := ML.prof([0.0, 0.015, fw * 0.25, 0.05, fw * 0.5, 0.045, fw * 0.75, 0.06, fw, 0.04, fw, 0.0])
	part(root, "Frame", cached("frame_%s_%s" % [w, h], func() -> Mesh: return ML.frame(w, h, prof, M["gold"])))
	part(root, "Canvas", ML.plane(w, h, M[mat_key]), Vector3(0, 0, 0.012))
	part(root, "Back", bbox(Vector3(w, h, 0.02), 0.002, "dark_wood_obj"), Vector3(0, 0, 0.0))
	return root


func picture_light(w: float) -> Node3D:
	var root := node("PictureLight")
	part(root, "Arm", cyl(0.01, 0.01, 0.25, "brass", 6), Vector3(0, 0, 0.0), Vector3(90, 0, 0))
	part(root, "Bar", cached("plight_%s" % w, func() -> Mesh:
		return ML.lathe(ML.prof([0.0, 0.0, 0.035, 0.0, 0.035, w, 0.0, w]), M["brass"], {"segments": 12})), Vector3(-w / 2.0, -0.02, 0.26), Vector3(0, 0, -90))
	return root


func vase_amphora() -> Node3D:
	var root := node("Amphora")
	var prof := ML.curve(func(t: float) -> Vector2:
		var y := t * 0.7
		var r := 0.05 + 0.16 * sin(clampf(t * 1.25, 0.0, 1.0) * PI) * (1.0 - t * 0.35)
		if t > 0.8:
			r = 0.06 + (t - 0.8) * 0.15
		return Vector2(r, y), 20)
	prof.insert(0, Vector2(0.0, 0.0))
	part(root, "Body", ML.lathe(prof, M["terracotta"], {"segments": 24, "sharp": 70.0}))
	for s in [-1, 1]:
		var pts := PackedVector3Array()
		for i in 9:
			var a := float(i) / 8.0 * PI
			pts.append(Vector3(s * (0.07 + sin(a) * 0.1), 0.62 - (1.0 - cos(a)) * 0.08, 0))
		part(root, "Handle", ML.tube(pts, [0.014], M["terracotta"], {"sides": 6}))
	return root


func urn(mat_key: String = "lapis") -> Node3D:
	var root := node("Urn")
	part(root, "Body", ML.lathe(ML.prof([0.0, 0.0, 0.1, 0.0, 0.1, 0.03, 0.06, 0.06, 0.07, 0.1, 0.18, 0.25, 0.2, 0.35, 0.16, 0.45, 0.08, 0.5, 0.09, 0.55, 0.0, 0.55]), M[mat_key], {"segments": 24}))
	return root


func canopic_jar(head: int) -> Node3D:
	var root := node("CanopicJar")
	part(root, "Jar", cached("canopic", func() -> Mesh:
		return ML.lathe(ML.prof([0.0, 0.0, 0.07, 0.0, 0.09, 0.08, 0.1, 0.18, 0.08, 0.28, 0.07, 0.3, 0.0, 0.3]), M["stone_obj"], {"segments": 18})))
	var lid := node("Lid")
	lid.position = Vector3(0, 0.3, 0)
	root.add_child(lid)
	part(lid, "Head", sphere(0.07, "stone_obj"), Vector3(0, 0.06, 0), Vector3.ZERO, Vector3(0.9, 1.1, 1.0) if head != 2 else Vector3(0.8, 0.9, 1.4))
	if head == 1: # jackal ears
		for s in [-1, 1]:
			part(lid, "Ear", cyl(0.025, 0.0, 0.08, "stone_obj", 4), Vector3(s * 0.035, 0.11, 0))
	elif head == 2: # falcon beak
		part(lid, "Beak", cyl(0.025, 0.0, 0.06, "gold", 6), Vector3(0, 0.05, 0.08), Vector3(90, 0, 0))
	part(lid, "Stripe", cyl(0.072, 0.072, 0.015, "gold", 16), Vector3(0, 0.0, 0))
	return root


func sarcophagus() -> Node3D:
	## Upright anthropoid coffin facing +Z (lid removed on the right).
	var root := node("Sarcophagus")
	var prof := ML.curve(func(t: float) -> Vector2:
		var y := t * 2.2
		var r := 0.22 + 0.2 * smoothstep(0.0, 0.75, t) - 0.18 * smoothstep(0.8, 0.86, t) + 0.05 * smoothstep(0.86, 0.92, t) - 0.12 * smoothstep(0.95, 1.0, t)
		return Vector2(r, y), 30)
	prof.insert(0, Vector2(0.0, 0.0))
	prof.append(Vector2(0.0, 2.2))
	part(root, "Case", ML.lathe(prof, M["gold"], {"segments": 28, "scale_z": 0.55, "sharp": 70.0}))
	for i in 5:
		var y := 0.5 + i * 0.25
		part(root, "Band", cached("sarc_band_%d" % i, func() -> Mesh:
			var r := 0.22 + 0.2 * smoothstep(0.0, 0.75, y / 2.2) + 0.012
			return ML.lathe(ML.prof([r, 0.0, r, 0.06]), M["lapis"], {"segments": 28, "scale_z": 0.56})), Vector3(0, y, 0))
	part(root, "Face", sphere(0.13, "gold"), Vector3(0, 1.95, 0.1), Vector3.ZERO, Vector3(0.9, 1.15, 0.6))
	for s in [-1, 1]:
		part(root, "Eye", sphere(0.018, "eye_dark"), Vector3(s * 0.045, 1.99, 0.175))
	part(root, "Headdress", cached("sarc_headdress", func() -> Mesh:
		return ML.lathe(ML.prof([0.0, 0.0, 0.25, 0.0, 0.2, 0.35, 0.12, 0.45, 0.0, 0.47]), M["lapis"], {"segments": 20, "scale_z": 0.6})), Vector3(0, 1.7, -0.02))
	return root


func obelisk(h: float) -> Node3D:
	var root := node("Obelisk")
	part(root, "Shaft", ML.lathe(ML.prof([0.0, 0.0, 0.4, 0.0, 0.3, h * 0.9, 0.0, h]), M["sandstone"], {"segments": 4}), Vector3.ZERO, Vector3(0, 45, 0))
	return root


func pyramid_model(size: float) -> Node3D:
	var root := node("Pyramid")
	part(root, "Body", ML.lathe(ML.prof([0.0, 0.0, size * 0.7, 0.0, 0.0, size * 0.65]), M["stone_obj"], {"segments": 4}), Vector3.ZERO, Vector3(0, 45, 0))
	part(root, "Cap", ML.lathe(ML.prof([0.0, 0.0, size * 0.08, 0.0, 0.0, size * 0.075]), M["gold"], {"segments": 4}), Vector3(0, size * 0.575, 0), Vector3(0, 45, 0))
	return root


func crate(s: float) -> Node3D:
	var root := node("Crate")
	part(root, "Box", bbox(Vector3(s, s, s), 0.02, "crate"), Vector3(0, s / 2.0, 0))
	for y in [0.06, s - 0.06]:
		part(root, "Strap", bbox(Vector3(s + 0.02, 0.06, s + 0.02), 0.01, "dark_wood_obj"), Vector3(0, y, 0))
	return root


func barrel() -> Node3D:
	var root := node("Barrel")
	part(root, "Body", cached("barrel", func() -> Mesh:
		return ML.lathe(ML.curve(func(t: float) -> Vector2: return Vector2(0.28 + sin(t * PI) * 0.05, t * 0.9), 10), M["crate"], {"segments": 20})))
	for y in [0.12, 0.45, 0.78]:
		part(root, "Hoop", cached("hoop_%s" % y, func() -> Mesh:
			var r := 0.28 + sin(y / 0.9 * PI) * 0.05 + 0.006
			return ML.lathe(ML.prof([r, 0.0, r, 0.04]), M["steel_dark"], {"segments": 20})), Vector3(0, y, 0))
	return root


func shelf(w: float, h: float, d: float) -> Node3D:
	var root := node("Shelf")
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			part(root, "Post", bbox(Vector3(0.04, h, 0.04), 0.004, "steel_dark"), Vector3(sx * w / 2.0, h / 2.0, sz * d / 2.0))
	for i in 4:
		part(root, "Board", bbox(Vector3(w, 0.03, d), 0.004, "steel_dark"), Vector3(0, 0.1 + i * (h - 0.2) / 3.0, 0))
	return root


func desk() -> Node3D:
	var root := node("Desk")
	part(root, "Top", bbox(Vector3(2.0, 0.05, 0.85), 0.01, "dark_wood_obj"), Vector3(0, 0.76, 0))
	for sx in [-1, 1]:
		part(root, "Drawers", bbox(Vector3(0.45, 0.72, 0.8), 0.01, "dark_wood_obj"), Vector3(sx * 0.75, 0.37, 0))
		for k in 3:
			part(root, "Handle", bbox(Vector3(0.12, 0.015, 0.02), 0.004, "brass"), Vector3(sx * 0.75, 0.15 + k * 0.22, 0.41))
	part(root, "Modesty", bbox(Vector3(1.05, 0.5, 0.03), 0.005, "dark_wood_obj"), Vector3(0, 0.48, -0.38))
	return root


func chair() -> Node3D:
	var root := node("Chair")
	part(root, "Seat", bbox(Vector3(0.48, 0.08, 0.46), 0.03, "leather"), Vector3(0, 0.48, 0))
	part(root, "Back", bbox(Vector3(0.46, 0.55, 0.07), 0.03, "leather"), Vector3(0, 0.82, -0.22), Vector3(-8, 0, 0))
	part(root, "Stem", cyl(0.025, 0.025, 0.4, "steel_dark", 8), Vector3(0, 0.05, 0))
	for k in 5:
		var a := TAU * k / 5.0
		part(root, "Foot", bbox(Vector3(0.3, 0.03, 0.04), 0.01, "black_plastic"), Vector3(cos(a) * 0.15, 0.04, sin(a) * 0.15), Vector3(0, -rad_to_deg(a), 0))
	return root


func crt_monitor() -> Node3D:
	var root := node("Monitor")
	part(root, "Case", bbox(Vector3(0.42, 0.36, 0.4), 0.03, "black_plastic"), Vector3(0, 0.18, 0))
	part(root, "Screen", bbox(Vector3(0.34, 0.26, 0.01), 0.005, "e_screen"), Vector3(0, 0.19, 0.2))
	return root


func desk_lamp() -> Node3D:
	var root := node("DeskLamp")
	part(root, "Base", cyl(0.09, 0.08, 0.025, "brass", 16))
	part(root, "Stem", cyl(0.012, 0.012, 0.35, "brass", 8), Vector3(0, 0.02, 0))
	part(root, "Shade", cached("lamp_shade", func() -> Mesh:
		return ML.lathe(ML.prof([0.03, 0.12, 0.13, 0.0, 0.135, -0.005]), M["cloth_green"], {"segments": 16})), Vector3(0, 0.3, 0.06), Vector3(30, 0, 0))
	part(root, "Bulb", sphere(0.03, "e_bulb"), Vector3(0, 0.33, 0.08))
	return root


func locker() -> Node3D:
	## Tall metal locker, door faces +Z. Players can hide inside.
	var root := node("Locker")
	part(root, "Body", bbox(Vector3(0.6, 1.95, 0.55), 0.015, "steel_dark"), Vector3(0, 0.975, 0))
	for k in 6:
		part(root, "Vent", bbox(Vector3(0.3, 0.012, 0.01), 0.003, "black_plastic"), Vector3(0, 1.55 + k * 0.035, 0.277))
	part(root, "Handle", bbox(Vector3(0.02, 0.12, 0.03), 0.005, "metal"), Vector3(0.22, 1.05, 0.29))
	return root


func coffee_machine() -> Node3D:
	var root := node("CoffeeMachine")
	part(root, "Body", bbox(Vector3(0.55, 0.9, 0.45), 0.03, "cloth_red"), Vector3(0, 0.45, 0))
	part(root, "Panel", bbox(Vector3(0.4, 0.3, 0.02), 0.01, "black_plastic"), Vector3(0, 0.7, 0.23))
	part(root, "Light", sphere(0.015, "e_green"), Vector3(0.15, 0.78, 0.245))
	part(root, "Cup", cyl(0.035, 0.04, 0.08, "porcelain", 12), Vector3(0, 0.25, 0.15))
	return root


func punch_clock() -> Node3D:
	## Wall-mounted, faces +Z.
	var root := node("PunchClock")
	part(root, "Box", bbox(Vector3(0.32, 0.45, 0.16), 0.02, "steel_dark"), Vector3(0, 0, 0.08))
	part(root, "Face", cyl(0.11, 0.11, 0.015, "porcelain", 24), Vector3(0, 0.08, 0.16), Vector3(90, 0, 0))
	part(root, "Slot", bbox(Vector3(0.12, 0.02, 0.02), 0.004, "black_plastic"), Vector3(0, -0.14, 0.165))
	return root


func breaker_panel() -> Node3D:
	var root := node("Breaker")
	part(root, "Box", bbox(Vector3(0.55, 0.8, 0.14), 0.015, "steel_dark"), Vector3(0, 0, 0.07))
	part(root, "Lever", bbox(Vector3(0.05, 0.22, 0.05), 0.01, "cloth_red"), Vector3(0.12, -0.05, 0.17))
	part(root, "Warning", bbox(Vector3(0.25, 0.12, 0.005), 0.002, "e_amber"), Vector3(-0.1, 0.25, 0.142))
	return root


func grandfather_clock() -> Node3D:
	var root := node("GrandfatherClock")
	part(root, "Base", bbox(Vector3(0.6, 0.5, 0.4), 0.02, "dark_wood_obj"), Vector3(0, 0.25, 0))
	part(root, "Trunk", bbox(Vector3(0.48, 1.2, 0.32), 0.015, "dark_wood_obj"), Vector3(0, 1.1, 0))
	part(root, "TrunkGlass", bbox(Vector3(0.3, 0.9, 0.01), 0.002, "glass"), Vector3(0, 1.1, 0.165))
	part(root, "Hood", bbox(Vector3(0.58, 0.55, 0.38), 0.02, "dark_wood_obj"), Vector3(0, 1.98, 0))
	part(root, "Crown", bbox(Vector3(0.64, 0.08, 0.42), 0.02, "dark_wood_obj"), Vector3(0, 2.29, 0))
	part(root, "Face", cyl(0.19, 0.19, 0.01, "porcelain", 28), Vector3(0, 2.0, 0.19), Vector3(90, 0, 0))
	var pend := node("Pendulum")
	pend.position = Vector3(0, 1.6, 0.1)
	root.add_child(pend)
	part(pend, "Rod", cyl(0.006, 0.006, 0.7, "brass", 6), Vector3(0, -0.7, 0))
	part(pend, "Bob", cyl(0.07, 0.07, 0.02, "brass", 18), Vector3(0, -0.72, 0), Vector3(90, 0, 0))
	return root


func exit_sign() -> Node3D:
	var root := node("ExitSign")
	part(root, "Box", bbox(Vector3(0.4, 0.16, 0.06), 0.01, "porcelain"))
	part(root, "Glow", bbox(Vector3(0.36, 0.12, 0.005), 0.002, "e_green"), Vector3(0, 0, 0.031))
	return root


func fire_extinguisher() -> Node3D:
	var root := node("Extinguisher")
	part(root, "Tank", ML.lathe(ML.prof([0.0, 0.0, 0.08, 0.0, 0.085, 0.02, 0.085, 0.45, 0.06, 0.52, 0.02, 0.55, 0.0, 0.55]), M["cloth_red"], {"segments": 16}))
	part(root, "Nozzle", cyl(0.015, 0.015, 0.1, "black_plastic", 6), Vector3(0, 0.55, 0))
	return root


func wet_floor_sign() -> Node3D:
	var root := node("WetFloorSign")
	part(root, "A", bbox(Vector3(0.3, 0.6, 0.01), 0.004, "e_amber"), Vector3(0, 0.3, 0.1), Vector3(-12, 0, 0))
	part(root, "B", bbox(Vector3(0.3, 0.6, 0.01), 0.004, "e_amber"), Vector3(0, 0.3, -0.1), Vector3(12, 0, 0))
	return root


func golden_duck() -> Node3D:
	var root := node("GoldenDuck")
	part(root, "Body", sphere(0.15, "gold"), Vector3(0, 0.13, 0), Vector3.ZERO, Vector3(1.0, 0.8, 1.35))
	part(root, "Tail", cyl(0.07, 0.0, 0.12, "gold", 10), Vector3(0, 0.17, 0.17), Vector3(-60, 0, 0))
	part(root, "Neck", cyl(0.06, 0.05, 0.14, "gold", 12), Vector3(0, 0.2, -0.12))
	part(root, "Head", sphere(0.085, "gold"), Vector3(0, 0.37, -0.14))
	part(root, "Beak", cyl(0.04, 0.012, 0.09, "gold", 10), Vector3(0, 0.355, -0.22), Vector3(-90, 0, 0), Vector3(1.4, 1, 0.6))
	for s in [-1, 1]:
		part(root, "Eye", sphere(0.012, "eye_dark"), Vector3(s * 0.06, 0.39, -0.19))
		part(root, "Wing", sphere(0.09, "gold"), Vector3(s * 0.12, 0.15, 0.02), Vector3.ZERO, Vector3(0.3, 0.6, 1.1))
	part(root, "Base", cyl(0.17, 0.18, 0.03, "dark_wood_obj", 20))
	return root


func pine_tree(h: float, seed: int) -> Node3D:
	var root := node("Pine")
	part(root, "Trunk", cyl(0.18, 0.08, h * 0.5, "bark", 8))
	var layers := 5
	for i in layers:
		var t := float(i) / layers
		var r := lerpf(1.8, 0.5, t) * h / 10.0
		var y := h * (0.18 + t * 0.7)
		part(root, "Needles", ML.lathe(ML.prof([0.0, 0.0, r, 0.0, r * 0.95, 0.12, 0.0, h * 0.28]), M["pine"], {"segments": 10, "noise": 0.15, "seed": seed + i}), Vector3(0, y, 0))
	return root


func specimen_jar(h: float) -> Node3D:
	var root := node("SpecimenJar")
	part(root, "Glass", ML.lathe(ML.prof([0.0, 0.0, 0.1, 0.0, 0.11, 0.02, 0.11, h - 0.03, 0.08, h, 0.0, h]), M["glass"], {"segments": 18}))
	part(root, "Liquid", ML.lathe(ML.prof([0.0, 0.01, 0.1, 0.01, 0.1, h * 0.8, 0.0, h * 0.8]), M["specimen_liquid"], {"segments": 14}))
	part(root, "Thing", sphere(0.05, "skin"), Vector3(0, h * 0.4, 0), Vector3(20, 30, 0), Vector3(1.0, 1.6, 0.8))
	part(root, "Lid", cyl(0.085, 0.085, 0.03, "brass", 16), Vector3(0, h, 0))
	return root


func globe() -> Node3D:
	var root := node("Globe")
	part(root, "Stand", ML.lathe(ML.prof([0.0, 0.0, 0.25, 0.0, 0.2, 0.05, 0.05, 0.1, 0.04, 0.7, 0.0, 0.7]), M["dark_wood_obj"], {"segments": 16}))
	part(root, "Ball", sphere(0.28, "terracotta", 14), Vector3(0, 1.0, 0), Vector3(0, 0, 23))
	part(root, "Ring", ML.lathe(ML.prof([0.3, -0.02, 0.31, -0.02, 0.31, 0.02, 0.3, 0.02]), M["brass"], {"segments": 32}), Vector3(0, 1.0, 0), Vector3(90, 0, 23))
	return root


# ------------------------------------------------------------ characters ---

## Humanoid rig built from tapered parts. Returns the "Model" node; pivots are named
## Hips, Spine, Chest, Neck, Head, ShoulderL/R, ElbowL/R, HipL/R, KneeL/R.
## Local forward is -Z (matches enemy scripts).
func humanoid(style: Dictionary) -> Node3D:
	var s: float = style.get("scale", 1.0)
	var skin: String = style.get("skin", "wax")
	var top: String = style.get("top", "uniform")
	var legs_mat: String = style.get("legs", "uniform")
	var shoes: String = style.get("shoes", "leather")
	var noise: float = style.get("noise", 0.0)
	var model := node("Model")
	model.scale = Vector3.ONE * s
	var hips := node("Hips")
	hips.position = Vector3(0, 0.95, 0)
	model.add_child(hips)
	part(hips, "Pelvis", cached("pelvis_%s_%s" % [legs_mat, noise], func() -> Mesh:
		return ML.lathe(ML.prof([0.0, -0.1, 0.13, -0.08, 0.17, 0.0, 0.16, 0.1, 0.0, 0.12]), M[legs_mat], {"segments": 16, "scale_z": 0.7, "noise": noise})))
	var spine := node("Spine")
	spine.position = Vector3(0, 0.08, 0)
	hips.add_child(spine)
	var chest := node("Chest")
	chest.position = Vector3(0, 0.0, 0)
	spine.add_child(chest)
	part(chest, "Torso", cached("torso_%s_%s" % [top, noise], func() -> Mesh:
		return ML.lathe(ML.prof([0.15, 0.0, 0.16, 0.12, 0.19, 0.3, 0.2, 0.42, 0.17, 0.5, 0.07, 0.56, 0.0, 0.57]), M[top], {"segments": 18, "scale_z": 0.62, "noise": noise})))
	var neck := node("Neck")
	neck.position = Vector3(0, 0.56, 0)
	chest.add_child(neck)
	part(neck, "NeckMesh", cyl(0.05, 0.045, 0.1, skin, 10))
	var head := node("Head")
	head.position = Vector3(0, 0.09, 0)
	neck.add_child(head)
	if style.get("plain_head", false) == false:
		part(head, "Skull", cached("skull_%s_%s" % [skin, noise], func() -> Mesh:
			return ML.lathe(ML.curve(func(t: float) -> Vector2:
				var y := t * 0.25
				var r := sin(t * PI) * (0.085 + 0.02 * t)
				return Vector2(r, y), 14), M[skin], {"segments": 18, "scale_z": 1.12, "sharp": 80.0, "noise": noise})))
		part(head, "Nose", cyl(0.018, 0.006, 0.04, skin, 6), Vector3(0, 0.1, -0.095), Vector3(-100, 0, 0))
		for sx in [-1, 1]:
			part(head, "Socket", sphere(0.022, "socket"), Vector3(sx * 0.035, 0.135, -0.083))
			part(head, "Eye", sphere(0.012, style.get("eye", "eye_white")), Vector3(sx * 0.035, 0.135, -0.092))
			part(head, "Ear", sphere(0.022, skin), Vector3(sx * 0.093, 0.12, 0.0), Vector3.ZERO, Vector3(0.4, 1.0, 0.7))
		if style.has("hair"):
			part(head, "Hair", cached("hair_%s" % style["hair"], func() -> Mesh:
				return ML.lathe(ML.curve(func(t: float) -> Vector2:
					return Vector2(sin(t * PI * 0.55 + PI * 0.45) * 0.1, 0.12 + t * 0.14), 8), M[style["hair"]], {"segments": 16, "scale_z": 1.15})), Vector3(0, 0, 0.008))
	for side in [-1, 1]:
		var tag := "L" if side < 0 else "R"
		var shoulder := node("Shoulder" + tag)
		shoulder.position = Vector3(side * 0.21, 0.48, 0)
		chest.add_child(shoulder)
		part(shoulder, "UpperArm", limb(0.3, 0.055, 0.045, top, noise))
		var elbow := node("Elbow" + tag)
		elbow.position = Vector3(0, -0.29, 0)
		shoulder.add_child(elbow)
		part(elbow, "Forearm", limb(0.27, 0.045, 0.035, style.get("sleeve", top), noise))
		part(elbow, "Hand", bbox(Vector3(0.06, 0.1, 0.035), 0.015, skin), Vector3(0, -0.31, 0))
		var hip := node("Hip" + tag)
		hip.position = Vector3(side * 0.09, -0.05, 0)
		hips.add_child(hip)
		part(hip, "Thigh", limb(0.45, 0.085, 0.06, legs_mat, noise))
		var knee := node("Knee" + tag)
		knee.position = Vector3(0, -0.44, 0)
		hip.add_child(knee)
		part(knee, "Shin", limb(0.42, 0.06, 0.04, legs_mat, noise))
		part(knee, "Foot", bbox(Vector3(0.09, 0.07, 0.24), 0.025, shoes), Vector3(0, -0.43, -0.05))
	return model


func knight_model() -> Node3D:
	var model := humanoid({"skin": "steel_dark", "top": "metal", "legs": "metal", "shoes": "metal", "plain_head": true, "scale": 1.05})
	var head: Node3D = model.find_child("Head", true, false)
	part(head, "Helm", ML.lathe(ML.prof([0.0, -0.02, 0.12, -0.02, 0.13, 0.05, 0.125, 0.2, 0.1, 0.27, 0.0, 0.29]), M["metal"], {"segments": 20, "scale_z": 1.1}))
	part(head, "Visor", bbox(Vector3(0.17, 0.018, 0.02), 0.004, "e_visor"), Vector3(0, 0.15, -0.135))
	part(head, "VisorRidge", bbox(Vector3(0.02, 0.2, 0.03), 0.006, "metal"), Vector3(0, 0.1, -0.135))
	part(head, "Plume", ML.tube(PackedVector3Array([Vector3(0, 0.28, 0), Vector3(0, 0.36, 0.05), Vector3(0, 0.38, 0.15), Vector3(0, 0.3, 0.27)]), [0.03, 0.05, 0.05, 0.02], M["cloth_red"], {"sides": 8}))
	var chest: Node3D = model.find_child("Chest", true, false)
	part(chest, "Breastplate", ML.lathe(ML.prof([0.17, 0.05, 0.215, 0.2, 0.22, 0.36, 0.19, 0.48, 0.08, 0.55]), M["metal"], {"segments": 22, "scale_z": 0.7}))
	part(chest, "Gorget", ML.lathe(ML.prof([0.1, 0.5, 0.13, 0.54, 0.07, 0.6]), M["metal"], {"segments": 18}))
	for i in 3:
		part(chest, "Fauld", ML.lathe(ML.prof([0.2 + i * 0.012, 0.0, 0.215 + i * 0.012, -0.07]), M["metal"], {"segments": 22, "scale_z": 0.7}), Vector3(0, 0.05 - i * 0.06, 0))
	for tag in ["L", "R"]:
		var sh: Node3D = model.find_child("Shoulder" + tag, true, false)
		for i in 3:
			part(sh, "Pauldron", ML.lathe(ML.curve(func(t: float) -> Vector2: return Vector2(sin(t * PI * 0.5) * (0.11 - i * 0.01), cos(t * PI * 0.5) * 0.08), 6), M["metal"], {"segments": 14}), Vector3(0, 0.02 - i * 0.05, 0))
		var el: Node3D = model.find_child("Elbow" + tag, true, false)
		part(el, "Couter", sphere(0.06, "metal"), Vector3(0, 0, 0.0))
		part(el, "Gauntlet", bbox(Vector3(0.08, 0.12, 0.06), 0.02, "metal"), Vector3(0, -0.31, 0))
		var kn: Node3D = model.find_child("Knee" + tag, true, false)
		part(kn, "Poleyn", sphere(0.075, "metal"), Vector3(0, 0, -0.02), Vector3.ZERO, Vector3(1, 1, 1.2))
		part(kn, "Sabaton", bbox(Vector3(0.11, 0.08, 0.28), 0.03, "metal"), Vector3(0, -0.43, -0.06))
	var hand_r: Node3D = model.find_child("ElbowR", true, false)
	var sword := node("Sword")
	sword.position = Vector3(0, -0.33, -0.02)
	hand_r.add_child(sword)
	part(sword, "Grip", cyl(0.016, 0.016, 0.16, "leather", 8), Vector3(0, -0.08, 0))
	part(sword, "Guard", bbox(Vector3(0.24, 0.025, 0.03), 0.008, "steel_dark"), Vector3(0, -0.09, 0))
	part(sword, "Pommel", sphere(0.025, "brass"), Vector3(0, 0.08, 0))
	part(sword, "Blade", ML.lathe(ML.prof([0.0, 0.0, 0.03, 0.0, 0.026, 0.85, 0.0, 0.95]), M["metal"], {"segments": 4, "scale_z": 0.15}), Vector3(0, -0.1, 0), Vector3(180, 0, 0))
	var hand_l: Node3D = model.find_child("ElbowL", true, false)
	part(hand_l, "Shield", ML.lathe(ML.prof([0.0, 0.0, 0.22, 0.0, 0.22, 0.35, 0.0, 0.62]), M["cloth_red"], {"segments": 3, "scale_z": 0.08}), Vector3(-0.07, -0.1, -0.05), Vector3(180, 90, 0))
	return model


func mummy_model() -> Node3D:
	var model := humanoid({"skin": "linen", "top": "linen", "legs": "linen", "shoes": "linen_dark", "sleeve": "linen", "plain_head": true, "noise": 0.12, "scale": 1.02})
	var head: Node3D = model.find_child("Head", true, false)
	part(head, "Wrapped", ML.lathe(ML.curve(func(t: float) -> Vector2: return Vector2(sin(t * PI) * 0.1, t * 0.25), 12), M["linen"], {"segments": 16, "scale_z": 1.1, "noise": 0.12, "sharp": 80.0}))
	for sx in [-1, 1]:
		part(head, "Socket", sphere(0.026, "socket"), Vector3(sx * 0.038, 0.14, -0.09))
		part(head, "Eye", sphere(0.011, "e_mummy_eye"), Vector3(sx * 0.038, 0.14, -0.105))
	# Loose hanging bandage strips
	var chest: Node3D = model.find_child("Chest", true, false)
	for k in 4:
		var a := TAU * (k + 0.3) / 4.0
		var base := Vector3(cos(a) * 0.17, 0.25 + k * 0.05, sin(a) * 0.11)
		var pts := PackedVector3Array([base, base + Vector3(0.02, -0.15, 0.01), base + Vector3(0.0, -0.32, 0.03), base + Vector3(0.03, -0.45, 0.0)])
		part(chest, "Strip", ML.tube(pts, [0.02, 0.018, 0.015, 0.01], M["linen_dark"], {"sides": 4}))
	return model


func wax_figure(style: Dictionary) -> Node3D:
	var st := {"skin": "wax", "top": style.get("top", "cloth_black"), "legs": style.get("legs", "cloth_black"), "shoes": "leather", "hair": "hair"}
	st.merge(style, true)
	var model := humanoid(st)
	var head: Node3D = model.find_child("Head", true, false)
	match style.get("hat", ""):
		"cap":
			part(head, "Cap", ML.lathe(ML.prof([0.0, 0.2, 0.105, 0.2, 0.11, 0.27, 0.09, 0.3, 0.0, 0.3]), M["uniform"], {"segments": 18, "scale_z": 1.1}))
			part(head, "Visor", bbox(Vector3(0.16, 0.012, 0.08), 0.004, "black_plastic"), Vector3(0, 0.205, -0.12), Vector3(-10, 0, 0))
		"tricorn":
			part(head, "Hat", ML.lathe(ML.prof([0.0, 0.2, 0.18, 0.21, 0.1, 0.24, 0.09, 0.32, 0.0, 0.33]), M["cloth_black"], {"segments": 3}), Vector3.ZERO, Vector3(0, 30, 0))
		"bicorne":
			part(head, "Hat", ML.lathe(ML.prof([0.0, 0.2, 0.2, 0.22, 0.05, 0.38, 0.0, 0.38]), M["cloth_black"], {"segments": 12, "scale_z": 0.3}), Vector3.ZERO, Vector3(0, 90, 0))
	if style.get("dress", false):
		var hips: Node3D = model.find_child("Hips", true, false)
		part(hips, "Dress", ML.lathe(ML.prof([0.17, 0.08, 0.2, -0.2, 0.32, -0.6, 0.42, -0.93, 0.0, -0.93]), M[style.get("top", "cloth_red")], {"segments": 22, "noise": 0.03}))
	return model


func automaton_model() -> Node3D:
	var model := humanoid({"skin": "porcelain", "top": "cloth_red", "legs": "cloth_black", "shoes": "leather", "scale": 0.72, "hair": "hair", "eye": "eye_dark"})
	var chest: Node3D = model.find_child("Chest", true, false)
	var key := node("WindKey")
	key.position = Vector3(0, 0.3, 0.14)
	chest.add_child(key)
	part(key, "Shaft", cyl(0.012, 0.012, 0.1, "brass", 6), Vector3.ZERO, Vector3(90, 0, 0))
	for s in [-1, 1]:
		part(key, "Bow", sphere(0.04, "brass"), Vector3(s * 0.045, 0, 0.1), Vector3.ZERO, Vector3(1.0, 0.7, 0.25))
	var head: Node3D = model.find_child("Head", true, false)
	for sx in [-1, 1]:
		part(head, "Cheek", sphere(0.018, "cloth_red"), Vector3(sx * 0.05, 0.09, -0.08), Vector3.ZERO, Vector3(1, 0.6, 0.3))
	return model


func dino_skeleton() -> Node3D:
	## T-Rex skeleton facing -X. Pivots: Head (with Jaw). Height ~4 m.
	var root := node("DinoModel")
	var spine := PackedVector3Array()
	for i in 21:
		var t := float(i) / 20.0
		var x := lerpf(-1.6, 4.2, t)
		var y := 2.6 + 0.35 * sin(t * PI * 0.9) - 1.4 * pow(maxf(t - 0.45, 0.0), 2.0) * 2.0
		spine.append(Vector3(x, y, 0))
	var radii := []
	for i in spine.size():
		var t := float(i) / (spine.size() - 1)
		radii.append(lerpf(0.11, 0.025, pow(t, 0.8)))
	part(root, "Spine", ML.tube(spine, radii, M["bone"], {"sides": 8}))
	var vert := cached("vertebra", func() -> Mesh:
		return ML.lathe(ML.prof([0.0, -0.05, 0.12, -0.04, 0.13, 0.0, 0.12, 0.04, 0.0, 0.05]), M["bone"], {"segments": 10, "noise": 0.1}))
	var spike := cached("spike", func() -> Mesh: return ML.lathe(ML.prof([0.0, 0.0, 0.035, 0.0, 0.0, 0.25]), M["bone"], {"segments": 6, "scale_z": 0.4}))
	for i in spine.size():
		var t := float(i) / (spine.size() - 1)
		var sc := lerpf(1.0, 0.25, t)
		part(root, "Vertebra", vert, spine[i], Vector3(0, 0, 90), Vector3.ONE * sc)
		part(root, "Spike", spike, spine[i], Vector3(0, 0, -10), Vector3.ONE * sc)
	# Ribs
	for i in 7:
		var x := -1.0 + i * 0.3
		var top := Vector3(x, 2.85 + 0.2 * sin(i * 0.4), 0)
		var depth := 0.9 + 0.35 * sin(float(i) / 6.0 * PI)
		for s in [-1, 1]:
			var pts := PackedVector3Array()
			for k in 9:
				var a := float(k) / 8.0 * PI * 0.85
				pts.append(top + Vector3(0.05 * k * 0.1, -sin(a * 0.9) * depth * 0.55 - (1.0 - cos(a)) * depth * 0.4, s * sin(a) * 0.55 * depth))
			part(root, "Rib", ML.tube(pts, [0.035, 0.03, 0.028, 0.025, 0.022, 0.02, 0.018, 0.015, 0.012], M["bone"], {"sides": 6}))
	# Legs
	for s in [-1, 1]:
		var hip := Vector3(0.9, 2.5, s * 0.45)
		var knee := Vector3(0.35, 1.45, s * 0.55)
		var ankle := Vector3(0.95, 0.55, s * 0.5)
		var toe := Vector3(0.45, 0.06, s * 0.5)
		part(root, "Femur", ML.tube(PackedVector3Array([hip, hip.lerp(knee, 0.5), knee]), [0.13, 0.09, 0.11], M["bone"], {"sides": 10}))
		part(root, "Tibia", ML.tube(PackedVector3Array([knee, knee.lerp(ankle, 0.5), ankle]), [0.1, 0.07, 0.08], M["bone"], {"sides": 10}))
		part(root, "Metatarsal", ML.tube(PackedVector3Array([ankle, toe]), [0.07, 0.05], M["bone"], {"sides": 8}))
		part(root, "Knee", sphere(0.12, "bone"), knee)
		part(root, "Ankle", sphere(0.08, "bone"), ankle)
		for c in 3:
			var dir := Vector3(-0.35, -0.02, (c - 1) * 0.12)
			part(root, "Toe", ML.tube(PackedVector3Array([toe, toe + dir, toe + dir * 1.5 + Vector3(-0.05, -0.04, 0)]), [0.04, 0.03, 0.005], M["bone"], {"sides": 6}))
		# Tiny arms
		var sh := Vector3(-1.0, 2.45, s * 0.3)
		part(root, "Arm", ML.tube(PackedVector3Array([sh, sh + Vector3(-0.15, -0.25, s * 0.05), sh + Vector3(-0.3, -0.2, s * 0.05)]), [0.04, 0.03, 0.01], M["bone"], {"sides": 6}))
		# Pelvis blade
		part(root, "Pelvis", sphere(0.3, "bone"), Vector3(0.9, 2.7, s * 0.25), Vector3.ZERO, Vector3(1.6, 0.9, 0.35))
	# Neck + head
	var head := node("Head")
	head.position = Vector3(-1.75, 2.95, 0)
	root.add_child(head)
	part(root, "Neck", ML.tube(PackedVector3Array([Vector3(-1.2, 2.75, 0), Vector3(-1.5, 2.95, 0), Vector3(-1.75, 2.95, 0)]), [0.12, 0.11, 0.1], M["bone"], {"sides": 8}))
	part(head, "Skull", ML.lathe(ML.prof([0.0, 0.0, 0.18, 0.05, 0.3, 0.25, 0.3, 0.5, 0.25, 0.8, 0.12, 1.15, 0.0, 1.2]), M["bone"], {"segments": 12, "scale_z": 0.65, "scale_x": 0.85, "noise": 0.05}), Vector3(0.1, 0.05, 0), Vector3(0, 0, 90))
	for sx in [-1, 1]:
		part(head, "Socket", sphere(0.09, "socket"), Vector3(-0.35, 0.18, sx * 0.17))
		var glow := part(head, "EyeGlow", sphere(0.035, "e_dino_eye"), Vector3(-0.38, 0.18, sx * 0.17))
		glow.name = "EyeL" if sx < 0 else "EyeR"
		part(head, "Fenestra", sphere(0.1, "socket"), Vector3(-0.7, 0.05, sx * 0.13), Vector3.ZERO, Vector3(1.5, 0.7, 0.3))
	var eye_point := Marker3D.new()
	eye_point.name = "EyePoint"
	eye_point.position = Vector3(-0.4, 0.18, 0)
	head.add_child(eye_point)
	var tooth := cached("tooth", func() -> Mesh: return ML.lathe(ML.prof([0.0, 0.0, 0.025, 0.0, 0.0, 0.11]), M["bone"], {"segments": 6}))
	for k in 9:
		var x := -0.15 - k * 0.11
		for sx in [-1, 1]:
			part(head, "Tooth", tooth, Vector3(x, -0.12, sx * (0.14 - k * 0.008)), Vector3(180, 0, 0))
	var jaw := node("Jaw")
	jaw.position = Vector3(0.05, -0.15, 0)
	head.add_child(jaw)
	part(jaw, "Mandible", ML.lathe(ML.prof([0.0, 0.0, 0.12, 0.05, 0.16, 0.4, 0.1, 1.0, 0.0, 1.05]), M["bone"], {"segments": 8, "scale_z": 1.1, "scale_x": 0.45}), Vector3(0.0, -0.05, 0), Vector3(0, 0, 90))
	for k in 8:
		for sx in [-1, 1]:
			part(jaw, "Tooth", tooth, Vector3(-0.2 - k * 0.1, 0.0, sx * (0.12 - k * 0.006)), Vector3(0, 0, 0), Vector3(0.8, 0.8, 0.8))
	# Steel support armature
	for x in [-1.3, 0.6, 2.4]:
		part(root, "Support", cyl(0.025, 0.025, 2.6, "steel_dark", 8), Vector3(x, 0.0, 0))
	return root
