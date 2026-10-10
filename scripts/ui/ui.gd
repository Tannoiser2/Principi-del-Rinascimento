class_name UI
extends RefCounted
## Helper grafici: tema rinascimentale, pannelli, etichette, bottoni.

const GOLD := Color("e8c46a")
const GOLD_DARK := Color("9c7a2e")
const PARCH := Color("ecdcb8")
const PARCH_DARK := Color("cdb88d")
const INK := Color("2b1d10")
const WOOD := Color("24180f")
const WOOD2 := Color("3a281a")
const RED := Color("8e2020")
const GREEN := Color("2f6b3a")

static var _theme: Theme
static var f_title: Font
static var f_head: Font
static var f_body: Font
static var f_italic: Font
static var f_bold: Font

static func fonts() -> void:
	if f_body:
		return
	f_title = load("res://assets/fonts/CinzelDecorative-Bold.ttf")
	var cz: FontFile = load("res://assets/fonts/Cinzel.ttf")
	var hv := FontVariation.new()
	hv.base_font = cz
	hv.variation_opentype = {"wght": 700}
	f_head = hv
	var gb: FontFile = load("res://assets/fonts/EBGaramond.ttf")
	var bv := FontVariation.new()
	bv.base_font = gb
	bv.variation_opentype = {"wght": 500}
	f_body = bv
	f_italic = load("res://assets/fonts/EBGaramond-Italic.ttf")
	var bb := FontVariation.new()
	bb.base_font = gb
	bb.variation_opentype = {"wght": 750}
	f_bold = bb

static func sb(bg: Color, border: Color = GOLD_DARK, bw := 2, radius := 6, margin := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.7
	s.content_margin_bottom = margin * 0.7
	s.anti_aliasing = true
	return s

static func theme() -> Theme:
	if _theme:
		return _theme
	fonts()
	var t := Theme.new()
	t.default_font = f_body
	t.default_font_size = 20
	t.set_color("font_color", "Label", PARCH)
	# Bottoni
	var bn := sb(Color("4a3220"), GOLD_DARK, 2, 6, 14)
	bn.shadow_color = Color(0, 0, 0, 0.45)
	bn.shadow_size = 4
	var bh := sb(Color("6a4628"), GOLD, 2, 6, 14)
	bh.shadow_color = Color(0.9, 0.7, 0.2, 0.25)
	bh.shadow_size = 8
	var bp := sb(Color("2c1d12"), GOLD, 2, 6, 14)
	var bd := sb(Color("2a221c"), Color("5a4a38"), 2, 6, 14)
	t.set_stylebox("normal", "Button", bn)
	t.set_stylebox("hover", "Button", bh)
	t.set_stylebox("pressed", "Button", bp)
	t.set_stylebox("disabled", "Button", bd)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", PARCH)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color("7a6a58"))
	t.set_font("font", "Button", f_head)
	t.set_font_size("font_size", "Button", 18)
	# Pannelli
	t.set_stylebox("panel", "PanelContainer", sb(Color(0.13, 0.09, 0.06, 0.94), GOLD_DARK, 2, 8, 12))
	t.set_stylebox("panel", "Panel", sb(Color(0.13, 0.09, 0.06, 0.94), GOLD_DARK, 2, 8, 12))
	# OptionButton / SpinBox / LineEdit
	t.set_stylebox("normal", "OptionButton", bn)
	t.set_stylebox("hover", "OptionButton", bh)
	t.set_stylebox("pressed", "OptionButton", bp)
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_font("font", "OptionButton", f_body)
	t.set_color("font_color", "OptionButton", PARCH)
	var le := sb(Color("1a120b"), GOLD_DARK, 2, 4, 8)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", sb(Color("1a120b"), GOLD, 2, 4, 8))
	t.set_color("font_color", "LineEdit", PARCH)
	t.set_stylebox("panel", "PopupMenu", sb(Color("2a1d14"), GOLD_DARK, 2, 4, 6))
	t.set_color("font_color", "PopupMenu", PARCH)
	t.set_color("font_hover_color", "PopupMenu", GOLD)
	t.set_stylebox("hover", "PopupMenu", sb(Color("4a3220"), GOLD_DARK, 0, 2, 4))
	t.set_font("font", "PopupMenu", f_body)
	t.set_font_size("font_size", "PopupMenu", 20)
	# Scroll
	t.set_stylebox("scroll", "VScrollBar", sb(Color(0, 0, 0, 0.2), Color(0, 0, 0, 0), 0, 4, 2))
	t.set_stylebox("grabber", "VScrollBar", sb(GOLD_DARK, GOLD_DARK, 0, 4, 2))
	t.set_stylebox("grabber_highlight", "VScrollBar", sb(GOLD, GOLD, 0, 4, 2))
	t.set_stylebox("grabber_pressed", "VScrollBar", sb(GOLD, GOLD, 0, 4, 2))
	# Tooltip
	t.set_stylebox("panel", "TooltipPanel", sb(Color("1d140d"), GOLD, 2, 6, 10))
	t.set_color("font_color", "TooltipLabel", PARCH)
	t.set_font("font", "TooltipLabel", f_body)
	t.set_font_size("font_size", "TooltipLabel", 18)
	# RichText
	t.set_color("default_color", "RichTextLabel", PARCH)
	t.set_font("normal_font", "RichTextLabel", f_body)
	t.set_font("italics_font", "RichTextLabel", f_italic)
	t.set_font("bold_font", "RichTextLabel", f_bold)
	t.set_font_size("normal_font_size", "RichTextLabel", 18)
	t.set_font_size("bold_font_size", "RichTextLabel", 18)
	t.set_font_size("italics_font_size", "RichTextLabel", 18)
	# CheckButton
	t.set_color("font_color", "CheckBox", PARCH)
	t.set_color("font_color", "CheckButton", PARCH)
	_theme = t
	return t

static func label(text: String, size := 20, color := PARCH, font: Font = null, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	fonts()
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	l.horizontal_alignment = align
	return l

static func head(text: String, size := 24, color := GOLD) -> Label:
	fonts()
	var l := label(text, size, color, f_head)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l

static func button(text: String, cb: Callable = Callable(), min_w := 0) -> Button:
	var b := Button.new()
	b.text = text
	if min_w > 0:
		b.custom_minimum_size.x = min_w
	if cb.is_valid():
		b.pressed.connect(cb)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b

static func panel(bg := Color(0.13, 0.09, 0.06, 0.94), border := GOLD_DARK, radius := 8, margin := 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(bg, border, 2, radius, margin))
	return p

static func parchment_panel(margin := 14) -> PanelContainer:
	var p := PanelContainer.new()
	var s := sb(PARCH, GOLD_DARK, 3, 6, margin)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 10
	p.add_theme_stylebox_override("panel", s)
	return p

static func tex_rect(t: Texture2D, size: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = size
	r.size = size
	return r

static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func roman(n: int) -> String:
	return ["", "I", "II", "III"][clampi(n, 0, 3)]

static func coin_text(g: int) -> String:
	return "%d" % g
