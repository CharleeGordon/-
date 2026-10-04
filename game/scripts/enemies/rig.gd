class_name Rig
extends RefCounted
## Procedural animation for the humanoid rigs built by tools/props.gd.
## Models face -Z. rotation.x > 0 swings a hanging limb forward.

const PIVOTS := ["Hips", "Spine", "Chest", "Neck", "Head", "ShoulderL", "ShoulderR", "ElbowL", "ElbowR", "HipL", "HipR", "KneeL", "KneeR"]

var p := {}
var _hips_y := 0.95


func _init(model: Node3D) -> void:
	for n in PIVOTS:
		var node := model.find_child(n, true, false)
		if node:
			p[n] = node
	if p.has("Hips"):
		_hips_y = p["Hips"].position.y


func has(n: String) -> bool:
	return p.has(n)


func rot(n: String, x: float, y: float = 0.0, z: float = 0.0) -> void:
	if p.has(n):
		p[n].rotation = Vector3(x, y, z)


## Walk cycle. phase in radians, amount 0..1. arms: extra forward raise (zombie arms ~1.4).
func walk(phase: float, amount: float, arms: float = 0.0, stiff: float = 1.0) -> void:
	var s := sin(phase)
	var c := cos(phase)
	rot("HipL", s * 0.45 * amount)
	rot("HipR", -s * 0.45 * amount)
	rot("KneeL", -maxf(0.0, c) * 0.8 * amount * stiff)
	rot("KneeR", -maxf(0.0, -c) * 0.8 * amount * stiff)
	rot("ShoulderL", arms - s * 0.35 * amount * (1.0 - clampf(arms, 0, 1) * 0.8), 0, -0.05)
	rot("ShoulderR", arms + s * 0.35 * amount * (1.0 - clampf(arms, 0, 1) * 0.8), 0, 0.05)
	rot("ElbowL", 0.15 + amount * 0.2)
	rot("ElbowR", 0.15 + amount * 0.2)
	rot("Spine", 0.04 * amount, s * 0.08 * amount)
	if p.has("Hips"):
		p["Hips"].position.y = _hips_y + absf(c) * 0.035 * amount


## Static pose from a dictionary {pivot: Vector3(rx, ry, rz)}.
func pose(d: Dictionary) -> void:
	for k in d:
		if p.has(k):
			p[k].rotation = d[k]


func look(yaw: float, pitch: float) -> void:
	if p.has("Head"):
		p["Head"].rotation = Vector3(pitch, yaw, 0)
