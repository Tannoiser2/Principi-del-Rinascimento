class_name MenuScreen
extends Control
## Menu iniziale con la copertina, titolo dorato, polvere d'oro e i ritratti delle famiglie.

var main

func _ready() -> void:
	clip_contents = true
	# copertina con lento zoom "Ken Burns"
	var cover := TextureRect.new()
	cover.texture = load("res://assets/ui/copertina.jpg")
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	cover.pivot_offset = Vector2(1400, 300)
	var tw := create_tween().set_loops()
	tw.tween_property(cover, "scale", Vector2(1.07, 1.07), 22.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(cover, "scale", Vector2(1.0, 1.0), 22.0).set_trans(Tween.TRANS_SINE)
	# velo scuro da sinistra
	var grad := Gradient.new()
	grad.set_color(0, Color(0.05, 0.03, 0.02, 0.96))
	grad.set_color(1, Color(0.05, 0.03, 0.02, 0.0))
	grad.add_point(0.45, Color(0.05, 0.03, 0.02, 0.82))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	gt.width = 512
	gt.height = 8
	var veil := TextureRect.new()
	veil.texture = gt
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.anchor_right = 0.72
	veil.anchor_bottom = 1.0
	add_child(veil)
	# velo in basso
	var g2 := Gradient.new()
	g2.set_color(0, Color(0.04, 0.02, 0.01, 0.0))
	g2.set_color(1, Color(0.04, 0.02, 0.01, 0.92))
	var gt2 := GradientTexture2D.new()
	gt2.gradient = g2
	gt2.fill_from = Vector2(0, 0)
	gt2.fill_to = Vector2(0, 1)
	gt2.width = 8
	gt2.height = 256
	var veil2 := TextureRect.new()
	veil2.texture = gt2
	veil2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil2.stretch_mode = TextureRect.STRETCH_SCALE
	veil2.anchor_top = 0.62
	veil2.anchor_right = 1.0
	veil2.anchor_bottom = 1.0
	add_child(veil2)
	_add_dust()
	# titolo
	var col := UI.vbox(6)
	col.position = Vector2(110, 60)
	add_child(col)
	var pre := UI.label("MARTIN WALLACE", 22, UI.GOLD_DARK, UI.f_head)
	pre.add_theme_constant_override("outline_size", 0)
	col.add_child(pre)
	var t1 := UI.label("Principi", 108, UI.GOLD, UI.f_title)
	_title_fx(t1)
	col.add_child(t1)
	var t2 := UI.label("del Rinascimento", 64, UI.GOLD, UI.f_title)
	_title_fx(t2)
	col.add_child(t2)
	var sub := UI.label("Italia, 1470 – 1500", 34, UI.PARCH, UI.f_italic)
	col.add_child(sub)
	var sub2 := UI.label("Condottieri  ·  Mecenati  ·  Tradimenti", 24, Color(0.85, 0.78, 0.62), UI.f_head)
	col.add_child(sub2)
	var sp := Control.new()
	sp.custom_minimum_size.y = 18
	col.add_child(sp)
	var btns := UI.vbox(7)
	col.add_child(btns)
	var items := []
	if main and main.has_save():
		items.append(["Continua Partita", func(): main.continue_game()])
	items += [
		["Nuova Partita", func(): main.show_setup()],
		["Partita Rapida", func(): _quick()],
		["Tutorial", func(): main.show_tutorial()],
		["Accordi e Trattative", func(): main.show_deals()],
		["Regole del Gioco", func(): main.show_rules()],
		["Esci", func(): get_tree().quit()],
	]
	var i := 0
	for it in items:
		var b := UI.button(it[0], it[1], 380)
		b.custom_minimum_size.y = 46
		b.add_theme_font_size_override("font_size", 24)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.mouse_entered.connect(func(): Sfx.play("card", -14, 1.3))
		btns.add_child(b)
		b.modulate.a = 0.0
		b.position.x = -40
		var tw2 := create_tween()
		tw2.tween_interval(0.35 + i * 0.12)
		tw2.tween_property(b, "modulate:a", 1.0, 0.4)
		i += 1
	if main and main.last_setup.size() > 0:
		var info := UI.label("Partita Rapida: riprende l'ultima configurazione", 17, Color(0.75, 0.68, 0.55), UI.f_italic)
		col.add_child(info)
	# famiglie in basso
	var fams := UI.hbox(26)
	fams.anchor_left = 0.0
	fams.anchor_right = 1.0
	fams.anchor_top = 1.0
	fams.anchor_bottom = 1.0
	fams.offset_top = -196
	fams.offset_bottom = -20
	fams.offset_left = 110
	fams.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(fams)
	var k := 0
	for f in Data.FAMILY_ORDER:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(80, 176)
		fams.add_child(holder)
		var st := UI.tex_rect(Data.screen_tex(f), Vector2(80, 176))
		st.tooltip_text = "%s (%s)\nA: %s\nB: %s" % [Data.FAMILIES[f].name, Data.FAMILIES[f].home, Data.FAMILIES[f].txtA, Data.FAMILIES[f].txtB]
		holder.add_child(st)
		var tw3 := create_tween().set_loops()
		tw3.tween_interval(k * 0.4)
		tw3.tween_property(st, "position:y", -8.0, 1.8).set_trans(Tween.TRANS_SINE)
		tw3.tween_property(st, "position:y", 0.0, 1.8).set_trans(Tween.TRANS_SINE)
		k += 1
	var credit := UI.label("Adattamento digitale amatoriale per uso personale · Grafica dalle componenti originali (Mercury Games)", 15, Color(0.7, 0.62, 0.5), UI.f_italic)
	credit.anchor_left = 1.0
	credit.anchor_right = 1.0
	credit.anchor_top = 1.0
	credit.anchor_bottom = 1.0
	credit.offset_left = -900
	credit.offset_right = -24
	credit.offset_top = -34
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(credit)
	Sfx.play("bell", -10)

func _title_fx(l: Label) -> void:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 4)
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.add_theme_color_override("font_outline_color", Color(0.25, 0.15, 0.05))
	l.add_theme_constant_override("outline_size", 6)

func _add_dust() -> void:
	var p := CPUParticles2D.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 0.9, 0.55, 1))
	grad.set_color(1, Color(1, 0.8, 0.3, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 16
	gt.height = 16
	p.texture = gt
	p.amount = 70
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(1000, 20)
	p.position = Vector2(960, 1100)
	p.direction = Vector2(0, -1)
	p.spread = 25
	p.gravity = Vector2(0, -6)
	p.initial_velocity_min = 25
	p.initial_velocity_max = 70
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.9
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.2, Color(1, 1, 1, 0.8))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	add_child(p)

func _quick() -> void:
	if main.last_setup.size() > 0:
		main.start_game(main.last_setup)
	else:
		var fams: Array = Data.FAMILY_ORDER.duplicate()
		fams.shuffle()
		var ps := [{"name": "Giocatore", "family": fams[0], "side": "A", "ai": false, "level": 1}]
		for i in 3:
			ps.append({"name": "Casa " + Data.FAMILIES[fams[i + 1]].name, "family": fams[i + 1], "side": "A", "ai": true, "level": 2})
		main.start_game({"players": ps})
