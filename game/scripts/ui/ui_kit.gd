class_name UIKit
extends RefCounted
## Small helpers to build consistent UI in code (dark panels, gold accents).

const GOLD := Color(0.92, 0.80, 0.52)
const TEXT := Color(0.93, 0.92, 0.88)
const DIM := Color(0.62, 0.6, 0.56)

## Fonts: TITLE (Cinzel Decorative), HEAD (Cinzel), BODY (EB Garamond), TYPE (typewriter), HAND (handwriting), MONO (CRT)
const FONTS := {
	"title": "res://fonts/CinzelDecorative-Black.woff2",
	"title_bold": "res://fonts/CinzelDecorative-Bold.woff2",
	"head": "res://fonts/Cinzel-Bold.woff2",
	"head_light": "res://fonts/Cinzel-Regular.woff2",
	"body": "res://fonts/EBGaramond-Regular.woff2",
	"italic": "res://fonts/EBGaramond-Italic.woff2",
	"bold": "res://fonts/EBGaramond-Bold.woff2",
	"type": "res://fonts/SpecialElite.woff2",
	"hand": "res://fonts/Caveat-Bold.woff2",
	"mono": "res://fonts/VT323.woff2",
}
static var _font_cache := {}


static func font(key: String) -> Font:
	if not _font_cache.has(key):
		_font_cache[key] = load(FONTS.get(key, FONTS["body"]))
	return _font_cache[key]


## Label with a specific font.
static func flabel(parent: Node, text: String, size: int, font_key: String, color: Color = TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := label(parent, text, size, color, align)
	l.add_theme_font_override("font", font(font_key))
	return l


## The game's logo: gold engraved title with a moving glint.
static func title_logo(parent: Node, size: int = 64) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", -6)
	parent.add_child(vb)
	var top := flabel(vb, "THE PEMBERTON MUSEUM PRESENTS", int(size * 0.24), "head_light", Color(0.75, 0.68, 0.5))
	top.add_theme_constant_override("shadow_offset_y", 1)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/gold_text.gdshader")
	for line in ["Do Not Touch", "the Exhibits"]:
		var l := flabel(vb, line, size, "title", Color.WHITE)
		l.material = mat
		l.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.02))
		l.add_theme_constant_override("outline_size", int(size * 0.08))
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("shadow_offset_x", 3)
		l.add_theme_constant_override("shadow_offset_y", 5)
	return vb


## Thin gold rule with a diamond in the middle.
static func divider(parent: Node, width: float = 420.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, 18)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	for side in [0, 1]:
		var r := ColorRect.new()
		r.color = Color(GOLD, 0.6)
		r.size = Vector2(width * 0.45, 1)
		r.position = Vector2(side * width * 0.55, 9)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(r)
	var d := ColorRect.new()
	d.color = GOLD
	d.size = Vector2(8, 8)
	d.pivot_offset = Vector2(4, 4)
	d.rotation = PI / 4
	d.position = Vector2(width * 0.5 - 4, 5)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(d)
	return c


## Text-only menu entry (museum style): gold on hover with a leading dash.
static func menu_button(parent: Node, text: String, callback: Callable, size: int = 26) -> Button:
	var b := Button.new()
	b.text = "   " + text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", font("head"))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color(0.86, 0.83, 0.76))
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_focus_color", GOLD)
	b.add_theme_color_override("font_pressed_color", Color(1, 0.9, 0.6))
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.38, 0.35))
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, empty)
	b.custom_minimum_size = Vector2(380, size * 1.7)
	b.mouse_entered.connect(func() -> void:
		b.text = "-  " + text
		Music.ui("ui_hover"))
	b.mouse_exited.connect(func() -> void: b.text = "   " + text)
	b.focus_entered.connect(func() -> void: b.text = "-  " + text)
	b.focus_exited.connect(func() -> void: b.text = "   " + text)
	b.pressed.connect(func() -> void:
		Music.ui("ui_click")
		callback.call())
	parent.add_child(b)
	return b


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
	b.add_theme_font_override("font", font("head"))
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
