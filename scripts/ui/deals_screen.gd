class_name DealsScreen
extends Control
## Pagina del menu: attiva o disattiva i singoli tipi di accordo tra giocatori.

var main
var toggles := {}
var updaters := {}
var master: CheckButton
var prompts: CheckButton

func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/copertina.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.3, 0.24, 0.2)
	add_child(bg)
	var root := UI.vbox(14)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 110
	root.offset_right = -110
	root.offset_top = 36
	root.offset_bottom = -30
	add_child(root)
	var title := UI.label("Accordi e Trattative", 58, UI.GOLD, UI.f_title)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	root.add_child(title)
	var intro := UI.label("Si possono scambiare solo Oro e Influenza, mai tessere, e nessun accordo è vincolante: chi tradisce perde reputazione e le IA se ne ricordano. Scegli quali accordi sono ammessi nelle tue partite (vale per te e per le IA).", 20, UI.PARCH, UI.f_italic)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(intro)
	var top := UI.hbox(24)
	root.add_child(top)
	master = CheckButton.new()
	master.text = "Trattative attive"
	master.add_theme_font_size_override("font_size", 22)
	master.button_pressed = main.settings.get("negotiation", true)
	master.toggled.connect(func(_on): _save())
	top.add_child(master)
	prompts = CheckButton.new()
	prompts.text = "Chiedimi di proporre accordi nei momenti chiave (guerre, Artisti, dadi, spareggi)"
	prompts.add_theme_font_size_override("font_size", 18)
	prompts.button_pressed = main.settings.get("prompt_moments", true)
	prompts.toggled.connect(func(_on): _save())
	top.add_child(prompts)
	var pnl := UI.panel(Color(0.1, 0.07, 0.05, 0.9))
	pnl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(pnl)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pnl.add_child(sc)
	var cols := UI.hbox(30)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(cols)
	var groups := {}
	var col_of := {"Denaro": 0, "Aste": 0, "Guerre": 1, "Eventi": 1}
	var colv: Array = [UI.vbox(6), UI.vbox(6)]
	for c in colv:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.custom_minimum_size.x = 780
		cols.add_child(c)
	var cfg: Dictionary = main.settings.get("deals", {})
	for t in Data.DEAL_ORDER:
		var info: Dictionary = Data.DEAL_INFO[t]
		var gname: String = info.group
		var cv: VBoxContainer = colv[col_of[gname]]
		if not groups.has(gname):
			groups[gname] = true
			var gl := UI.head(gname, 26)
			cv.add_child(gl)
		var row := UI.hbox(10)
		var cb := CheckButton.new()
		cb.button_pressed = bool(cfg.get(t, true))
		row.add_child(cb)
		toggles[t] = cb
		var tv := UI.vbox(0)
		var st := UI.label("", 15, Color(0.6, 1, 0.6), UI.f_head)
		st.custom_minimum_size.x = 40
		row.add_child(st)
		var upd := func(on: bool):
			st.text = "SÌ" if on else "NO"
			st.add_theme_color_override("font_color", Color(0.6, 1, 0.6) if on else Color(1, 0.5, 0.45))
			tv.modulate = Color(1, 1, 1, 1.0 if on else 0.45)
		upd.call(cb.button_pressed)
		cb.toggled.connect(func(on):
			upd.call(on)
			_save())
		updaters[t] = upd
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UI.label(info.name, 21, Color(1, 0.92, 0.75), UI.f_head))
		var d := UI.label(info.desc, 17, Color(0.85, 0.78, 0.62), UI.f_italic)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 680
		tv.add_child(d)
		row.add_child(tv)
		cv.add_child(row)
	var bot := UI.hbox(16)
	bot.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(bot)
	bot.add_child(UI.button("Attiva tutti", func(): _set_all(true), 200))
	bot.add_child(UI.button("Disattiva tutti", func(): _set_all(false), 200))
	var back := UI.button("Torna al menu", func():
		_save()
		main.show_menu(), 260)
	bot.add_child(back)

func _set_all(on: bool) -> void:
	for t in toggles:
		toggles[t].set_pressed_no_signal(on)
		updaters[t].call(on)
	_save()

func _save() -> void:
	var d := {}
	for t in toggles:
		d[t] = toggles[t].button_pressed
	main.settings.deals = d
	main.settings.negotiation = master.button_pressed
	main.settings.prompt_moments = prompts.button_pressed
	main.save_settings()
