class_name TileView
extends Control
## Una tessera cliccabile con evidenziazione, oscuramento e anteprima ingrandita.

signal clicked(id: String)
signal hover(id: String, on: bool, view: Control)

var id := ""
var tex: Texture2D
var selectable := false:
	set(v):
		selectable = v
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if v else Control.CURSOR_ARROW
		queue_redraw()
var dim := false:
	set(v):
		dim = v
		queue_redraw()
var badge := ""
var badge_color := Color(0.55, 0.1, 0.1)
var marked := false
var _hover := false
var _t := 0.0

func _init(item_id := "", texture: Texture2D = null, sz := Vector2(80, 100)) -> void:
	id = item_id
	tex = texture
	custom_minimum_size = sz
	size = sz
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	mouse_entered.connect(func():
		_hover = true
		hover.emit(id, true, self)
		queue_redraw())
	mouse_exited.connect(func():
		_hover = false
		hover.emit(id, false, self)
		queue_redraw())
	set_process(true)
	tree_exiting.connect(func():
		if _hover:
			hover.emit(id, false, self))

func _process(delta: float) -> void:
	if selectable:
		_t += delta
		queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if selectable:
			Sfx.play("card", -8)
			clicked.emit(id)
		accept_event()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if tex:
		var ts := tex.get_size()
		var sc: float = min(size.x / ts.x, size.y / ts.y)
		var ds := ts * sc
		var off := (size - ds) / 2.0
		r = Rect2(off, ds)
		# ombra
		draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.45), true)
		draw_texture_rect(tex, r, false, Color(0.42, 0.40, 0.38) if dim else Color.WHITE)
	if selectable:
		var a := 0.55 + 0.45 * sin(_t * 4.0)
		draw_rect(r.grow(2), Color(1.0, 0.82, 0.3, a), false, 3.0)
	if _hover and (selectable or not dim):
		draw_rect(r.grow(1), Color(1, 0.95, 0.75, 0.9), false, 2.0)
	if marked:
		draw_rect(r.grow(3), Color(0.9, 0.2, 0.15, 0.95), false, 4.0)
	if badge != "":
		var f: Font = UI.f_head
		var fs := 16
		var w := f.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12
		var br := Rect2(Vector2(r.end.x - w + 4, r.position.y - 6), Vector2(w, 22))
		draw_rect(br, badge_color, true)
		draw_rect(br, Color(0.9, 0.75, 0.4), false, 1.5)
		draw_string(f, br.position + Vector2(6, 17), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.95, 0.85))
