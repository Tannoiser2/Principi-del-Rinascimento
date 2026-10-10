class_name SetupScreen
extends Control
## Configurazione della partita: numero di giocatori, famiglie, lato A/B, umano o IA.

var main
var n_players := 4
var rows_box: VBoxContainer
var seats: Array = []   # {name, family, side, ctrl}
var count_btns: Array = []
var err_label: Label
var neg_cb: CheckButton

const CTRL_TXT := ["Umano", "IA Facile", "IA Normale", "IA Machiavelli"]

func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/copertina.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.32, 0.26, 0.22)
	add_child(bg)
	var fams: Array = Data.FAMILY_ORDER.duplicate()
	fams.shuffle()
	# configurazione di partenza: ultima usata o predefinita
	if main and main.last_setup.size() > 0:
		for p in main.last_setup.players:
			seats.append({"name": p.name, "family": p.family, "side": p.get("side", "A"), "ctrl": 0 if not p.ai else int(p.get("level", 1)) + 1})
		n_players = seats.size()
	for i in range(seats.size(), 6):
		seats.append({"name": "Giocatore" if i == 0 else "Casa " + Data.FAMILIES[fams[i]].name, "family": fams[i], "side": "A", "ctrl": 0 if i == 0 else 3})
	var root := UI.vbox(18)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 120
	root.offset_right = -120
	root.offset_top = 30
	root.offset_bottom = -24
	add_child(root)
	var title := UI.label("Nuova Partita", 56, UI.GOLD, UI.f_title)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	root.add_child(title)
	var cnt := UI.hbox(12)
	root.add_child(cnt)
	cnt.add_child(UI.head("Giocatori:", 26, UI.PARCH))
	for n in [3, 4, 5, 6]:
		var b := UI.button(str(n), func(): _set_count(n), 64)
		b.toggle_mode = true
		cnt.add_child(b)
		count_btns.append(b)
	var hint := UI.label("   Le famiglie hanno due lati: A (più forte) e B (ridotto). Ogni famiglia può essere scelta una sola volta.", 19, Color(0.85, 0.78, 0.62), UI.f_italic)
	cnt.add_child(hint)
	var pnl := UI.panel(Color(0.1, 0.07, 0.05, 0.88))
	pnl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(pnl)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pnl.add_child(sc)
	rows_box = UI.vbox(8)
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(rows_box)
	err_label = UI.label("", 20, Color(1, 0.5, 0.4))
	root.add_child(err_label)
	var bot := UI.hbox(20)
	bot.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(bot)
	neg_cb = CheckButton.new()
	neg_cb.text = "Trattative tra giocatori (scegli i tipi di accordo nel menu «Accordi e Trattative»)"
	neg_cb.button_pressed = main.settings.get("negotiation", true) if main else true
	neg_cb.add_theme_font_size_override("font_size", 20)
	neg_cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot.add_child(neg_cb)
	bot.add_child(UI.button("Indietro", func(): main.show_menu(), 200))
	var go := UI.button("Inizia la partita", _start, 320)
	go.custom_minimum_size.y = 60
	go.add_theme_font_size_override("font_size", 24)
	bot.add_child(go)
	_set_count(n_players)

func _set_count(n: int) -> void:
	n_players = n
	for i in count_btns.size():
		count_btns[i].button_pressed = (i + 3 == n)
	_rebuild()

func _rebuild() -> void:
	for c in rows_box.get_children():
		c.queue_free()
	for i in n_players:
		rows_box.add_child(_row(i))

func _row(i: int) -> Control:
	var s: Dictionary = seats[i]
	var h := UI.hbox(16)
	h.custom_minimum_size.y = 104
	var st := UI.tex_rect(Data.screen_tex(s.family), Vector2(46, 100))
	h.add_child(st)
	var ft := UI.tex_rect(Data.family_tex(s.family, s.side), Vector2(80, 100))
	h.add_child(ft)
	var col := UI.vbox(6)
	col.custom_minimum_size.x = 300
	h.add_child(col)
	col.add_child(UI.head("Seggio %d" % (i + 1), 18, UI.GOLD_DARK))
	var name_e := LineEdit.new()
	name_e.text = s.name
	name_e.custom_minimum_size = Vector2(280, 40)
	name_e.add_theme_font_size_override("font_size", 20)
	name_e.text_changed.connect(func(t): s.name = t)
	col.add_child(name_e)
	var fam := OptionButton.new()
	for f in Data.FAMILY_ORDER:
		fam.add_item(Data.FAMILIES[f].name + " (" + Data.FAMILIES[f].home + ")")
	fam.selected = Data.FAMILY_ORDER.find(s.family)
	fam.custom_minimum_size = Vector2(250, 44)
	fam.item_selected.connect(func(idx): _set_family(i, Data.FAMILY_ORDER[idx]))
	var c2 := UI.vbox(6)
	c2.add_child(UI.head("Famiglia", 16, UI.GOLD_DARK))
	c2.add_child(fam)
	h.add_child(c2)
	var side := OptionButton.new()
	side.add_item("Lato A")
	side.add_item("Lato B")
	side.selected = 0 if s.side == "A" else 1
	side.custom_minimum_size = Vector2(130, 44)
	side.item_selected.connect(func(idx):
		s.side = "A" if idx == 0 else "B"
		_rebuild())
	var c3 := UI.vbox(6)
	c3.add_child(UI.head("Tessera", 16, UI.GOLD_DARK))
	c3.add_child(side)
	h.add_child(c3)
	var ctrl := OptionButton.new()
	for t in CTRL_TXT:
		ctrl.add_item(t)
	ctrl.selected = s.ctrl
	ctrl.custom_minimum_size = Vector2(200, 44)
	ctrl.item_selected.connect(func(idx): s.ctrl = idx)
	var c4 := UI.vbox(6)
	c4.add_child(UI.head("Controllo", 16, UI.GOLD_DARK))
	c4.add_child(ctrl)
	h.add_child(c4)
	var ab := UI.label(Data.FAMILIES[s.family]["txt" + s.side], 19, UI.PARCH, UI.f_italic)
	ab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ab.custom_minimum_size.y = 90
	h.add_child(ab)
	return h

func _set_family(i: int, f: String) -> void:
	# scambio con chi aveva già quella famiglia
	for j in seats.size():
		if j != i and seats[j].family == f:
			seats[j].family = seats[i].family
			if seats[j].name.begins_with("Casa "):
				seats[j].name = "Casa " + Data.FAMILIES[seats[j].family].name
	seats[i].family = f
	if seats[i].name.begins_with("Casa "):
		seats[i].name = "Casa " + Data.FAMILIES[f].name
	_rebuild()

func _start() -> void:
	var used := {}
	var ps: Array = []
	for i in n_players:
		var s: Dictionary = seats[i]
		if used.has(s.family):
			err_label.text = "Ogni famiglia può essere scelta una sola volta."
			return
		used[s.family] = true
		var nm: String = s.name.strip_edges()
		if nm == "":
			nm = Data.FAMILIES[s.family].name
		ps.append({"name": nm, "family": s.family, "side": s.side, "ai": s.ctrl > 0, "level": max(0, s.ctrl - 1)})
	Sfx.play("gavel")
	main.settings.negotiation = neg_cb.button_pressed
	main.start_game({"players": ps, "negotiation": neg_cb.button_pressed, "deals": main.settings.deals.duplicate()})
	main.save_settings()
