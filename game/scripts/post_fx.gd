extends CanvasLayer
## Full-screen post effects. Reads Music.threat for fear-driven distortion.

var _mat: ShaderMaterial
var _flash := 0.0


func _ready() -> void:
	layer = 5
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/post.gdshader")
	rect.material = _mat
	add_child(rect)


func flash(color: Color, strength: float = 0.6) -> void:
	_flash = strength
	_mat.set_shader_parameter("flash_color", Vector3(color.r, color.g, color.b))


func _process(delta: float) -> void:
	_flash = move_toward(_flash, 0.0, delta * 1.2)
	_mat.set_shader_parameter("flash", _flash)
	_mat.set_shader_parameter("threat", Music.threat)
	var p = get_tree().get_first_node_in_group("player")
	var hidden: float = 1.0 if (p and p.is_hidden) else 0.0
	_mat.set_shader_parameter("hidden", hidden)
