class_name UIKit
extends RefCounted
## Small helpers to build consistent UI in code (dark panels, gold accents).

const GOLD := Color(0.92, 0.80, 0.52)
const TEXT := Color(0.93, 0.92, 0.88)
const DIM := Color(0.62, 0.6, 0.56)


static func label(parent: Node, text: String, size: int, color: Color = TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


static func box(color: Color, margin: float, radius: int = 6, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.7
	s.content_margin_bottom = margin * 0.7
	if border.a > 0.0:
		s.set_border_width_all(1)
		s.border_color = border
	return s


static func button(parent: Node, text: String, callback: Callable, width: float = 340.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 50)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_focus_color", GOLD)
	b.add_theme_stylebox_override("normal", box(Color(0.06, 0.06, 0.07, 0.85), 12, 4, Color(0.4, 0.34, 0.22, 0.6)))
	b.add_theme_stylebox_override("hover", box(Color(0.14, 0.12, 0.09, 0.95), 12, 4, GOLD))
	b.add_theme_stylebox_override("focus", box(Color(0.14, 0.12, 0.09, 0.95), 12, 4, GOLD))
	b.add_theme_stylebox_override("pressed", box(Color(0.2, 0.17, 0.1, 0.95), 12, 4, GOLD))
	b.pressed.connect(func() -> void:
		Music.ui("ui_click")
		callback.call())
	b.mouse_entered.connect(func() -> void: Music.ui("ui_hover"))
	var c := CenterContainer.new()
	c.add_child(b)
	parent.add_child(c)
	return b


static func place(c: Control, preset: Control.LayoutPreset, offset: Vector2, size: Vector2) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + size.x
	c.offset_bottom = offset.y + size.y


static func overlay(parent: Node, color: Color) -> ColorRect:
	var o := ColorRect.new()
	o.color = color
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.visible = false
	parent.add_child(o)
	return o


static func center_box(parent: Node, separation: int = 14) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", separation)
	center.add_child(vb)
	return vb
