class_name DiceView
extends Control
## Un dado disegnato, con animazione di lancio.

var value := 1
var color := Color(0.96, 0.93, 0.85)
var pip := Color(0.12, 0.08, 0.05)
var _rolling := 0.0
var _shown := 1

func _init(c := Color(0.96, 0.93, 0.85), p := Color(0.12, 0.08, 0.05)) -> void:
	color = c
	pip = p
	custom_minimum_size = Vector2(64, 64)

func roll_to(v: int) -> void:
	value = v
	_rolling = 0.7
	set_process(true)

func _process(d: float) -> void:
	if _rolling > 0:
		_rolling -= d
		_shown = randi_range(1, 6)
		rotation = randf_range(-0.25, 0.25) * (_rolling / 0.7)
		if _rolling <= 0:
			_shown = value
			rotation = 0
		queue_redraw()

func _ready() -> void:
	pivot_offset = size / 2
	_shown = value

func _draw() -> void:
	var r := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(10)
	sb.border_color = color.darkened(0.4)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 5
	draw_style_box(sb, r)
	var c := r.get_center()
	var o := r.size.x * 0.26
	var pr := r.size.x * 0.085
	var pts := {
		1: [Vector2.ZERO],
		2: [Vector2(-o, -o), Vector2(o, o)],
		3: [Vector2(-o, -o), Vector2.ZERO, Vector2(o, o)],
		4: [Vector2(-o, -o), Vector2(o, -o), Vector2(-o, o), Vector2(o, o)],
		5: [Vector2(-o, -o), Vector2(o, -o), Vector2.ZERO, Vector2(-o, o), Vector2(o, o)],
		6: [Vector2(-o, -o), Vector2(o, -o), Vector2(-o, 0), Vector2(o, 0), Vector2(-o, o), Vector2(o, o)],
	}
	for p in pts[clampi(_shown, 1, 6)]:
		draw_circle(c + p, pr, pip)
