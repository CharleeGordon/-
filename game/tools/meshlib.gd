class_name MeshLib
extends RefCounted
## Procedural mesh primitives used by the world builder (build time only).
## Everything returns an ArrayMesh with normals, UVs and tangents (normal-map ready).


# Adds a triangle making sure it faces along `n_hint` (Godot front faces are clockwise).
static func _tri(st: SurfaceTool, p: Array, n: Array, uv: Array, n_hint: Vector3) -> void:
	var order := [0, 1, 2]
	if (p[1] - p[0]).cross(p[2] - p[0]).dot(n_hint) > 0.0:
		order = [0, 2, 1]
	for i in order:
		st.set_normal(n[i])
		st.set_uv(uv[i])
		st.add_vertex(p[i])


static func _quad(st: SurfaceTool, p: Array, n: Array, uv: Array) -> void:
	var hint: Vector3 = (n[0] + n[1] + n[2] + n[3])
	if hint.length_squared() < 1e-8:
		hint = (p[1] - p[0]).cross(p[3] - p[0])
	_tri(st, [p[0], p[1], p[2]], [n[0], n[1], n[2]], [uv[0], uv[1], uv[2]], hint)
	_tri(st, [p[0], p[2], p[3]], [n[0], n[2], n[3]], [uv[0], uv[2], uv[3]], hint)


static func _commit(st: SurfaceTool, mat: Material, existing: ArrayMesh = null) -> ArrayMesh:
	st.generate_tangents()
	if mat:
		st.set_material(mat)
	return st.commit(existing)


# Splits a polyline into strips at sharp corners (> angle_deg) so they get hard edges.
static func _split_sharp(points: PackedVector2Array, angle_deg: float) -> Array:
	var strips := []
	var cur := PackedVector2Array([points[0]])
	for i in range(1, points.size()):
		cur.append(points[i])
		if i < points.size() - 1:
			var d0 := (points[i] - points[i - 1]).normalized()
			var d1 := (points[i + 1] - points[i]).normalized()
			if rad_to_deg(acos(clampf(d0.dot(d1), -1.0, 1.0))) > angle_deg:
				strips.append(cur)
				cur = PackedVector2Array([points[i]])
	strips.append(cur)
	return strips


# Generic grid -> triangles with finite-difference normals. grid[i][j] = Vector3, j wraps if wrap_j.
static func _grid(st: SurfaceTool, grid: Array, wrap_j: bool, u_scale: float, v_scale: float, flip: bool = false) -> void:
	var rows := grid.size()
	var cols: int = grid[0].size()
	var normals := []
	for i in rows:
		var nrow := []
		for j in cols:
			var jp := (j + 1) % cols if wrap_j else mini(j + 1, cols - 1)
			var jm := (j - 1 + cols) % cols if wrap_j else maxi(j - 1, 0)
			var ip := mini(i + 1, rows - 1)
			var im := maxi(i - 1, 0)
			var ti: Vector3 = grid[ip][j] - grid[im][j]
			var tj: Vector3 = grid[i][jp] - grid[i][jm]
			var n := ti.cross(tj)
			if n.length_squared() < 1e-12:
				n = Vector3.UP
			n = n.normalized()
			nrow.append(-n if flip else n)
		normals.append(nrow)
	var jcount := cols if wrap_j else cols - 1
	for i in rows - 1:
		for j in jcount:
			var j1 := (j + 1) % cols
			var u0 := float(j) / jcount * u_scale
			var u1 := float(j + 1) / jcount * u_scale
			var v0 := float(i) / (rows - 1) * v_scale
			var v1 := float(i + 1) / (rows - 1) * v_scale
			_quad(st, [grid[i][j], grid[i][j1], grid[i + 1][j1], grid[i + 1][j]],
				[normals[i][j], normals[i][j1], normals[i + 1][j1], normals[i + 1][j]],
				[Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)])


## Surface of revolution around Y. profile: Vector2(radius, height), bottom to top.
## opts: flutes (int), flute_depth (0..1), scale_z, noise, segments, sharp (deg), uv_u, uv_v
static func lathe(profile: PackedVector2Array, mat: Material, opts: Dictionary = {}) -> ArrayMesh:
	var segments: int = opts.get("segments", 24)
	var flutes: int = opts.get("flutes", 0)
	var flute_depth: float = opts.get("flute_depth", 0.0)
	var scale_z: float = opts.get("scale_z", 1.0)
	var scale_x: float = opts.get("scale_x", 1.0)
	var noise_amt: float = opts.get("noise", 0.0)
	var noise_seed: int = opts.get("seed", 1)
	var sharp: float = opts.get("sharp", 35.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var total_len := 0.0
	for i in range(1, profile.size()):
		total_len += profile[i].distance_to(profile[i - 1])
	var v_acc := 0.0
	for strip in _split_sharp(profile, sharp):
		var grid := []
		for k in strip.size():
			var row := []
			for s in segments:
				var a := TAU * s / segments
				var r: float = strip[k].x
				if flutes > 0:
					r *= 1.0 - flute_depth * pow(maxf(0.0, cos(a * flutes)), 2.0)
				if noise_amt > 0.0:
					r *= 1.0 + noise_amt * (sin(a * 3.0 + noise_seed + strip[k].y * 7.0) * 0.5 + sin(a * 7.0 - strip[k].y * 13.0 + noise_seed * 2.0) * 0.5)
				row.append(Vector3(cos(a) * r * scale_x, strip[k].y, sin(a) * r * scale_z))
			grid.append(row)
		var strip_len := 0.0
		for k in range(1, strip.size()):
			strip_len += strip[k].distance_to(strip[k - 1])
		_grid(st, grid, true, opts.get("uv_u", 2.0), maxf(strip_len, 0.01) * opts.get("uv_v", 1.0))
		v_acc += strip_len
	return _commit(st, mat)


## Tube along a path. radii: one per point (or a single value).
static func tube(points: PackedVector3Array, radii: Array, mat: Material, opts: Dictionary = {}) -> ArrayMesh:
	var sides: int = opts.get("sides", 10)
	var caps: bool = opts.get("caps", true)
	var noise_amt: float = opts.get("noise", 0.0)
	var twist: float = opts.get("twist", 0.0) # extra UV spiral for bandages
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := points.size()
	var tangents := []
	for i in n:
		var t: Vector3
		if i == 0:
			t = points[1] - points[0]
		elif i == n - 1:
			t = points[n - 1] - points[n - 2]
		else:
			t = points[i + 1] - points[i - 1]
		tangents.append(t.normalized())
	# Parallel transport frames
	var ref := Vector3.UP if absf(tangents[0].dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var normal: Vector3 = (ref - tangents[0] * ref.dot(tangents[0])).normalized()
	var grid := []
	var length_acc := 0.0
	for i in n:
		if i > 0:
			var axis: Vector3 = tangents[i - 1].cross(tangents[i])
			if axis.length() > 1e-6:
				var ang := acos(clampf(tangents[i - 1].dot(tangents[i]), -1.0, 1.0))
				normal = normal.rotated(axis.normalized(), ang)
			length_acc += points[i].distance_to(points[i - 1])
		var binormal: Vector3 = tangents[i].cross(normal)
		var r: float = radii[i] if radii.size() > 1 else radii[0]
		var row := []
		for s in sides:
			var a := TAU * s / sides
			var rr := r
			if noise_amt > 0.0:
				rr *= 1.0 + noise_amt * sin(a * 3.0 + i * 1.7) * cos(a * 5.0 - i * 0.9)
			row.append(points[i] + (normal * cos(a) + binormal * sin(a)) * rr)
		grid.append(row)
	_grid(st, grid, true, 1.0 + twist, maxf(length_acc, 0.01))
	if caps:
		for end in [0, n - 1]:
			var c: Vector3 = points[end]
			var dir: Vector3 = -tangents[0] if end == 0 else tangents[n - 1]
			for s in sides:
				var p0: Vector3 = grid[end][s]
				var p1: Vector3 = grid[end][(s + 1) % sides]
				_tri(st, [c, p0, p1], [dir, dir, dir], [Vector2(0.5, 0.5), Vector2(0, 0), Vector2(1, 0)], dir)
	return _commit(st, mat)


## Box with rounded/bevelled edges. Normals are exact; UVs are box-projected (meters).
static func bevel_box(size: Vector3, bevel: float, mat: Material, steps: int = 2) -> ArrayMesh:
	var h := size * 0.5
	bevel = minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.95)
	var inner := h - Vector3.ONE * bevel
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Per axis coordinate list: -h .. bevel arc .. -inner, inner .. arc .. h
	var axes := [[], [], []]
	for ax in 3:
		var hv: float = h[ax]
		var iv: float = inner[ax]
		var list := [-hv]
		for k in range(1, steps):
			list.append(-hv + (hv - iv) * float(k) / steps)
		list.append(-iv)
		list.append(iv)
		for k in range(1, steps):
			list.append(iv + (hv - iv) * float(k) / steps)
		list.append(hv)
		axes[ax] = list
	# 6 faces: (axis, sign)
	for face in [[0, 1], [0, -1], [1, 1], [1, -1], [2, 1], [2, -1]]:
		var ax: int = face[0]
		var sg: int = face[1]
		var a1 := (ax + 1) % 3
		var a2 := (ax + 2) % 3
		var grid := []
		for i in axes[a1].size():
			var row := []
			for j in axes[a2].size():
				var q := Vector3.ZERO
				q[ax] = h[ax] * sg
				q[a1] = axes[a1][i]
				q[a2] = axes[a2][j]
				row.append(q)
			grid.append(row)
		for i in grid.size() - 1:
			for j in grid[0].size() - 1:
				var ps := []
				var ns := []
				var uvs := []
				for q in [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]:
					var cl := Vector3(clampf(q.x, -inner.x, inner.x), clampf(q.y, -inner.y, inner.y), clampf(q.z, -inner.z, inner.z))
					var d: Vector3 = q - cl
					var nrm := d.normalized() if d.length() > 1e-6 else Vector3.ZERO
					if nrm == Vector3.ZERO:
						nrm[ax] = sg
					var p := cl + nrm * bevel
					ps.append(p)
					ns.append(nrm)
					uvs.append(Vector2(p[a1], p[a2]))
				_quad(st, ps, ns, uvs)
	return _commit(st, mat)


## Straight extrusion of a 2D profile (x = outward, y = up) along local +X from 0 to `length`.
## Ends are mitered: k_start/k_end = +1 convex corner, -1 concave corner, 0 square cut.
## The outward direction is local +Z.
static func extrude(profile: PackedVector2Array, length: float, mat: Material, k_start: float = 0.0, k_end: float = 0.0, caps: bool = true) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for strip in _split_sharp(profile, 30.0):
		var grid := []
		for k in strip.size():
			var p2: Vector2 = strip[k]
			var x0 := -p2.x * k_start
			var x1 := length + p2.x * k_end
			grid.append([Vector3(x0, p2.y, p2.x), Vector3(x1, p2.y, p2.x)])
		# normals from profile direction
		for k in grid.size() - 1:
			var a: Vector3 = grid[k][0]
			var b: Vector3 = grid[k][1]
			var c: Vector3 = grid[k + 1][1]
			var d: Vector3 = grid[k + 1][0]
			var dir2: Vector2 = (strip[k + 1] - strip[k]).normalized()
			var nrm := Vector3(0, -dir2.x, dir2.y).normalized() # perpendicular in the YZ plane
			if nrm.dot(Vector3(0, 0.0001, 1)) < -0.99:
				pass
			var v0: float = strip[k].length()
			var v1: float = strip[k + 1].length()
			_quad(st, [a, b, c, d], [nrm, nrm, nrm, nrm], [Vector2(a.x, v0), Vector2(b.x, v0), Vector2(c.x, v1), Vector2(d.x, v1)])
	if caps:
		# Fan caps (profiles are expected to be roughly convex toward the wall)
		for side in [0, 1]:
			var center := Vector3.ZERO
			var pts := []
			for p2 in profile:
				var x := -p2.x * k_start if side == 0 else length + p2.x * k_end
				var v := Vector3(x, p2.y, p2.x)
				pts.append(v)
				center += v
			center /= pts.size()
			var nrm := Vector3(-1, 0, 0) if side == 0 else Vector3(1, 0, 0)
			for k in pts.size() - 1:
				_tri(st, [center, pts[k], pts[k + 1]], [nrm, nrm, nrm], [Vector2(0, 0), Vector2(pts[k].z, pts[k].y), Vector2(pts[k + 1].z, pts[k + 1].y)], nrm)
	return _commit(st, mat)


## Picture frame: profile (x = outward from canvas edge, y = depth toward viewer) around a w x h opening.
## Lies in the XY plane, facing +Z.
static func frame(w: float, h: float, profile: PackedVector2Array, mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector2(-w / 2, -h / 2), Vector2(w / 2, -h / 2), Vector2(w / 2, h / 2), Vector2(-w / 2, h / 2)]
	var outs := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	for e in 4:
		var a: Vector2 = corners[e]
		var b: Vector2 = corners[(e + 1) % 4]
		var out: Vector2 = outs[e]
		var along := (b - a).normalized()
		for k in profile.size() - 1:
			var ps := []
			for pk in [k, k + 1]:
				var p2: Vector2 = profile[pk]
				var pa := a + out * p2.x - along * p2.x
				var pb := b + out * p2.x + along * p2.x
				ps.append([Vector3(pa.x, pa.y, p2.y), Vector3(pb.x, pb.y, p2.y)])
			var dir2 := (profile[k + 1] - profile[k]).normalized()
			var n3 := Vector3(out.x * -dir2.y, out.y * -dir2.y, dir2.x)
			if n3.z < 0 and absf(dir2.x) < 0.01:
				pass
			n3 = n3.normalized()
			var quad := [ps[0][0], ps[0][1], ps[1][1], ps[1][0]]
			_quad(st, quad, [n3, n3, n3, n3], [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	return _commit(st, mat)


## Flat quad in XY plane facing +Z (for canvases, posters, signs).
static func plane(w: float, h: float, mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := Vector3(0, 0, 1)
	_quad(st, [Vector3(-w / 2, -h / 2, 0), Vector3(w / 2, -h / 2, 0), Vector3(w / 2, h / 2, 0), Vector3(-w / 2, h / 2, 0)],
		[n, n, n, n], [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	return _commit(st, mat)


## Merges several meshes (each with a transform) into one multi-surface ArrayMesh.
static func merge(parts: Array) -> ArrayMesh:
	var out := ArrayMesh.new()
	for part in parts:
		var mesh: ArrayMesh = part[0]
		var xf: Transform3D = part[1]
		for s in mesh.get_surface_count():
			var st := SurfaceTool.new()
			st.create_from(mesh, s)
			var arrays := st.commit_to_arrays()
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var tans: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			for i in verts.size():
				verts[i] = xf * verts[i]
				norms[i] = (xf.basis * norms[i]).normalized()
				if tans.size() >= (i + 1) * 4:
					var t := (xf.basis * Vector3(tans[i * 4], tans[i * 4 + 1], tans[i * 4 + 2])).normalized()
					tans[i * 4] = t.x
					tans[i * 4 + 1] = t.y
					tans[i * 4 + 2] = t.z
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_NORMAL] = norms
			arrays[Mesh.ARRAY_TANGENT] = tans
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.surface_set_material(out.get_surface_count() - 1, mesh.surface_get_material(s))
	return out


## Helper: build a profile from a flat list of numbers [r0, y0, r1, y1, ...].
static func prof(values: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, values.size(), 2):
		out.append(Vector2(values[i], values[i + 1]))
	return out


## Smooth profile helper: samples a function f(t)->Vector2 for t in [0,1].
static func curve(f: Callable, samples: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in samples + 1:
		out.append(f.call(float(i) / samples))
	return out
