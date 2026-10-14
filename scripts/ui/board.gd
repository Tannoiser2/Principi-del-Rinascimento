class_name BoardScreen
extends Control
## Tavolo di gioco: mappa, mercato delle tessere, giocatori, registro, dialoghi d'asta e di guerra.

var main
var cfg: Dictionary
var g: GameEngine
var map: MapView
var viewer := -1

const MAP_W := 734.0
const CX := 744.0          # colonna centrale
const CW := 736.0
const RX := 1490.0         # colonna destra
const RW := 422.0

var hdr_decade: Label
var hdr_turn: Label
var hdr_info: Label
var events_box: HBoxContainer
var pope_view: TileView
var future_box: HBoxContainer
var city_rows := {}
var city_chips := {}
var troop_views := {}
var market_views := {}
var players_box: VBoxContainer
var panels: Array = []
var log_rt: RichTextLabel
var prompt_label: Label
var actions_box: HFlowContainer
var hand_box: HBoxContainer
var zoom: PanelContainer
var zoom_tex: TextureRect
var zoom_txt: RichTextLabel
var auction_dlg: PanelContainer
var auction_ui := {}
var war_dlg: PanelContainer
var war_ui := {}
var choice_layer: Control
var menu_layer: Control
var toast_layer: Control
var cur := {}              # decisione umana in corso
var bid_value := 0
var freeze_target := -1
var _last_roll := {}
var _war_hide_timer: SceneTreeTimer
var _last_hist := ""
var _last_auction_item := "~"
var _last_auction_kind := ""
var deals_rt: RichTextLabel
var actions_scroll: ScrollContainer
var hand_title: Label
var muted := {}
var _turn_deals := 0
var _last_turn_seen := -1
var _extra_text := ""
var _condo_note_seen := ""
# tutorial
var tut := false
var tut_off := false
var tut_seen := {}
var tut_queue: Array = []
var tut_open: TutorialOverlay = null
var areas := {}            # zone dello schermo spiegate dal tutorial

func _ready() -> void:
	clip_contents = true
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/copertina.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.18, 0.14, 0.11)
	add_child(bg)
	g = GameEngine.new()
	add_child(g)
	g.ai_delay = 0.55 * main.settings.ai_speed
	var load_d = cfg.get("load", null)
	var setup_cfg := cfg.duplicate()
	setup_cfg.erase("load")
	g.setup(setup_cfg)
	if load_d != null:
		g.load_dict(load_d)
		cfg = setup_cfg
	for p in g.players:
		if not p.is_ai:
			viewer = p.id
			break
	_build()
	g.log_msg.connect(_on_log)
	g.changed.connect(refresh)
	g.decision_requested.connect(_on_decision)
	g.auction_changed.connect(_on_auction)
	g.war_changed.connect(_on_war)
	g.dice_rolled.connect(_on_dice)
	g.game_over.connect(_on_game_over)
	g.deal_event.connect(func(t, k):
		var mine: bool = viewer >= 0 and g.players[viewer].name in t
		if k == "betray":
			Sfx.play("drum", -6, 1.4)
			_toast(t)
		elif mine:
			Sfx.play("coin", -8)
			_toast(t))
	g.decade_started.connect(_on_decade)
	refresh()
	await get_tree().create_timer(0.6).timeout
	if cfg.get("autohuman", false):
		_audit_loop()
	tut = bool(cfg.get("tutorial", false)) and load_d == null
	if tut:
		await _tut_intro()
	g.run(load_d != null)

# ================================================================= costruzione

func _build() -> void:
	map = MapView.new()
	map.g = g
	map.position = Vector2.ZERO
	map.size = Vector2(MAP_W, 1080)
	add_child(map)
	map.city_clicked.connect(_on_city_clicked)
	map.city_hover.connect(_on_city_hover)
	# --- intestazione
	var hdr := UI.panel(Color(0.1, 0.07, 0.05, 0.95))
	hdr.position = Vector2(CX, 8)
	hdr.size = Vector2(CW, 56)
	add_child(hdr)
	areas["header"] = Rect2(hdr.position, hdr.size)
	areas["map"] = Rect2(0, 0, MAP_W, 1080)
	var hh := UI.hbox(18)
	hdr.add_child(hh)
	hdr_decade = UI.label("Decade I", 28, UI.GOLD, UI.f_title)
	hh.add_child(hdr_decade)
	hdr_turn = UI.label("", 20, UI.PARCH, UI.f_head)
	hdr_turn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(hdr_turn)
	hdr_info = UI.label("", 17, Color(0.85, 0.78, 0.62))
	hh.add_child(hdr_info)
	var mb := UI.button("Menu", _open_menu)
	hh.add_child(mb)
	# --- eventi e Papa
	var ep := UI.panel(Color(0.12, 0.08, 0.05, 0.9))
	ep.position = Vector2(CX, 70)
	ep.size = Vector2(CW, 170)
	add_child(ep)
	areas["events"] = Rect2(ep.position, ep.size)
	var ev := UI.hbox(10)
	ep.add_child(ev)
	var evl := UI.vbox(2)
	evl.custom_minimum_size.x = 92
	evl.add_child(UI.head("Eventi", 20))
	evl.add_child(UI.label("Si vince all'asta.\nL'ultimo chiude\nla Decade.", 15, Color(0.8, 0.72, 0.58), UI.f_italic))
	ev.add_child(evl)
	events_box = UI.hbox(8)
	events_box.custom_minimum_size.x = 4 * 114
	ev.add_child(events_box)
	var sep := VSeparator.new()
	ev.add_child(sep)
	pope_view = _make_tile("POPE", Vector2(104, 130))
	ev.add_child(pope_view)
	# --- città
	var cp := UI.panel(Color(0.12, 0.08, 0.05, 0.9))
	cp.position = Vector2(CX, 246)
	cp.size = Vector2(CW, 472)
	add_child(cp)
	areas["cities"] = Rect2(cp.position, cp.size)
	var cv := UI.vbox(2)
	cp.add_child(cv)
	for c in Data.CITIES:
		var row := UI.hbox(6)
		row.custom_minimum_size.y = 88
		var chip := PanelContainer.new()
		var csb := UI.sb(Data.CITY_COLOR[c].darkened(0.35), Data.CITY_COLOR[c].lightened(0.3), 2, 6, 5)
		chip.add_theme_stylebox_override("panel", csb)
		chip.custom_minimum_size = Vector2(118, 84)
		var chv := UI.vbox(0)
		chip.add_child(chv)
		chv.add_child(UI.label(Data.CITY_NAME[c], 20, Color(1, 0.95, 0.85), UI.f_head, HORIZONTAL_ALIGNMENT_CENTER))
		var sl := UI.label("", 16, Color(1, 0.9, 0.65), UI.f_body, HORIZONTAL_ALIGNMENT_CENTER)
		chv.add_child(sl)
		city_chips[c] = sl
		row.add_child(chip)
		var tiles := UI.hbox(5)
		row.add_child(tiles)
		city_rows[c] = tiles
		cv.add_child(row)
	# --- truppe
	var tp := UI.panel(Color(0.12, 0.08, 0.05, 0.9))
	tp.position = Vector2(CX, 724)
	tp.size = Vector2(CW, 116)
	add_child(tp)
	areas["troops"] = Rect2(tp.position, tp.size)
	var th := UI.hbox(6)
	tp.add_child(th)
	var tl := UI.vbox(0)
	tl.custom_minimum_size.x = 70
	tl.add_child(UI.head("Truppe", 18))
	tl.add_child(UI.label("in Oro", 15, Color(0.8, 0.72, 0.58), UI.f_italic))
	th.add_child(tl)
	for t in Data.TROOP_ORDER:
		var tv := _make_tile(t, Vector2(76, 94))
		th.add_child(tv)
		troop_views[t] = tv
	# --- barra azioni + mano (dimensione fissa: niente pulsanti fuori schermo)
	var ap := Panel.new()
	ap.add_theme_stylebox_override("panel", UI.sb(Color(0.16, 0.10, 0.06, 0.96), UI.GOLD, 2, 8, 10))
	ap.position = Vector2(CX, 846)
	ap.size = Vector2(CW, 226)
	ap.clip_contents = true
	add_child(ap)
	areas["actions"] = Rect2(ap.position, Vector2(CW - 246, ap.size.y))
	areas["hand"] = Rect2(ap.position + Vector2(CW - 246, 0), Vector2(246, ap.size.y))
	prompt_label = UI.label("", 16, UI.GOLD, UI.f_head)
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.max_lines_visible = 3
	prompt_label.position = Vector2(12, 6)
	prompt_label.size = Vector2(CW - 260, 64)
	prompt_label.clip_text = true
	ap.add_child(prompt_label)
	actions_scroll = ScrollContainer.new()
	actions_scroll.position = Vector2(10, 74)
	actions_scroll.size = Vector2(CW - 256, 146)
	actions_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ap.add_child(actions_scroll)
	actions_box = HFlowContainer.new()
	actions_box.custom_minimum_size.x = CW - 270
	actions_box.add_theme_constant_override("h_separation", 6)
	actions_box.add_theme_constant_override("v_separation", 6)
	actions_scroll.add_child(actions_box)
	var hp := UI.vbox(2)
	hp.position = Vector2(CW - 240, 6)
	hp.size = Vector2(232, 214)
	ap.add_child(hp)
	hand_title = UI.label("Le tue carte Tradimento", 15, Color(0.85, 0.75, 0.6), UI.f_italic)
	hp.add_child(hand_title)
	hand_box = UI.hbox(4)
	hp.add_child(hand_box)
	# --- giocatori
	var n: int = g.players.size()
	var deals_h := 128 if g.negotiation else 0
	var log_min := 150
	var avail: float = 1064.0 - deals_h - log_min - 12
	var ph: float = min(232.0, floor((avail - 6 * (n - 1)) / n))
	players_box = UI.vbox(6)
	players_box.position = Vector2(RX, 8)
	players_box.size = Vector2(RW, n * ph + 6 * (n - 1))
	add_child(players_box)
	for p in g.players:
		var pp := _make_player_panel(p.id, ph)
		players_box.add_child(pp.root)
		panels.append(pp)
	var y: float = 8 + n * ph + 6 * (n - 1) + 6
	areas["players"] = Rect2(RX, 8, RW, n * ph + 6 * (n - 1))
	areas["ph"] = ph
	# --- patti in corso
	if g.negotiation:
		var dp := UI.panel(Color(0.10, 0.07, 0.04, 0.94), Color(0.75, 0.6, 0.3))
		dp.position = Vector2(RX, y)
		dp.size = Vector2(RW, deals_h)
		dp.clip_contents = true
		add_child(dp)
		areas["deals"] = Rect2(dp.position, dp.size)
		var dv := UI.vbox(2)
		dp.add_child(dv)
		dv.add_child(UI.head("Patti in corso", 16))
		deals_rt = RichTextLabel.new()
		deals_rt.bbcode_enabled = true
		deals_rt.size_flags_vertical = Control.SIZE_EXPAND_FILL
		deals_rt.add_theme_font_size_override("normal_font_size", 14)
		deals_rt.add_theme_font_size_override("bold_font_size", 14)
		dv.add_child(deals_rt)
		y += deals_h + 6
	# --- registro (compatto)
	var lp := UI.panel(Color(0.08, 0.06, 0.04, 0.92))
	lp.position = Vector2(RX, y)
	lp.size = Vector2(RW, 1072 - y)
	lp.clip_contents = true
	add_child(lp)
	areas["log"] = Rect2(lp.position, lp.size)
	var lv := UI.vbox(2)
	lp.add_child(lv)
	lv.add_child(UI.head("Cronaca", 16))
	log_rt = RichTextLabel.new()
	log_rt.bbcode_enabled = true
	log_rt.scroll_following = true
	log_rt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_rt.add_theme_font_size_override("normal_font_size", 14)
	log_rt.add_theme_font_size_override("bold_font_size", 15)
	lv.add_child(log_rt)
	# --- dialoghi
	_build_auction_dialog()
	_build_war_dialog()
	move_child(auction_dlg, war_dlg.get_index())   # l'asta (anche dei Condottieri) sta sopra il riquadro della guerra
	choice_layer = Control.new()
	choice_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	choice_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(choice_layer)
	toast_layer = Control.new()
	toast_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_layer)
	menu_layer = Control.new()
	menu_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu_layer)
	# --- anteprima ingrandita
	zoom = UI.panel(Color(0.08, 0.05, 0.03, 0.97), UI.GOLD, 8, 10)
	zoom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom.visible = false
	zoom.z_index = 50
	var zv := UI.vbox(6)
	zoom.add_child(zv)
	zoom_tex = UI.tex_rect(null, Vector2(240, 300))
	zoom_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zv.add_child(zoom_tex)
	zoom_txt = RichTextLabel.new()
	zoom_txt.bbcode_enabled = true
	zoom_txt.fit_content = true
	zoom_txt.custom_minimum_size = Vector2(240, 10)
	zoom_txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom_txt.add_theme_font_size_override("normal_font_size", 17)
	zv.add_child(zoom_txt)
	add_child(zoom)

func _make_tile(id: String, sz: Vector2) -> TileView:
	var tv := TileView.new(id, Data.item_tex(id), sz)
	tv.clicked.connect(_on_tile_clicked)
	tv.hover.connect(_on_tile_hover)
	return tv

func _make_player_panel(pid: int, ph: float) -> Dictionary:
	var p = g.players[pid]
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(RW, ph)
	root.clip_contents = true
	var sbx := UI.sb(Color(0.12, 0.08, 0.05, 0.93), p.color.darkened(0.2), 2, 8, 6)
	root.add_theme_stylebox_override("panel", sbx)
	var v := UI.vbox(3)
	root.add_child(v)
	var head := UI.hbox(6)
	v.add_child(head)
	var st := UI.tex_rect(Data.screen_tex(p.family), Vector2(30, 62))
	head.add_child(st)
	var hv := UI.vbox(0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	var top := UI.hbox(6)
	hv.add_child(top)
	var nm := UI.label(p.name, 18, Color(1, 0.94, 0.8), UI.f_head)
	nm.clip_text = true
	nm.custom_minimum_size.x = 130
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	var tag := UI.label("", 14, Color(0.8, 0.72, 0.58), UI.f_italic)
	top.add_child(tag)
	var res := UI.hbox(4)
	hv.add_child(res)
	res.add_theme_constant_override("separation", 6)
	var gtk := _token("res://assets/ui/gold.png", 36, 19, Color(1, 0.97, 0.85))
	gtk.root.tooltip_text = "Oro"
	res.add_child(gtk.root)
	var gl: Label = gtk.label
	var itk := _token("res://assets/ui/influence.png", 36, 19, Color(0.9, 0.93, 1.0))
	itk.root.tooltip_text = "Influenza"
	res.add_child(itk.root)
	var il: Label = itk.label
	var ltk := _token("res://assets/ui/laurel.png", 36, 19, Color(0.92, 1.0, 0.88))
	ltk.root.tooltip_text = "Pedine Vittoria (PV dalle guerre vinte come Condottiero)"
	res.add_child(ltk.root)
	var ll: Label = ltk.label
	var ci := UI.tex_rect(load("res://assets/cards/TC_back.png"), Vector2(20, 30))
	res.add_child(ci)
	var cl := UI.label("0", 19, Color(0.95, 0.75, 0.75), UI.f_head)
	cl.custom_minimum_size.x = 14
	res.add_child(cl)
	# forza militare come Condottiero (Truppe + bonus di famiglia e tessere)
	var mil := UI.hbox(1)
	mil.mouse_filter = Control.MOUSE_FILTER_PASS
	var swi := UI.tex_rect(load("res://assets/ui/sword.png"), Vector2(20, 20))
	mil.add_child(swi)
	var al := UI.label("0", 19, Color(1.0, 0.62, 0.55), UI.f_head)
	al.custom_minimum_size.x = 20
	mil.add_child(al)
	var shi := UI.tex_rect(load("res://assets/ui/shield.png"), Vector2(20, 20))
	mil.add_child(shi)
	var dl := UI.label("0", 19, Color(0.62, 0.78, 1.0), UI.f_head)
	dl.custom_minimum_size.x = 20
	mil.add_child(dl)
	for c in [swi, al, shi, dl]:
		c.mouse_filter = Control.MOUSE_FILTER_PASS
	res.add_child(mil)
	var pv := UI.label("", 16, Color(0.85, 0.78, 0.62), UI.f_italic)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	res.add_child(pv)
	# tessere possedute: riga città (raggruppate) e riga truppe/eventi
	var th: float = clampf(floor((ph - 12 - 64 - 8) / 2.0), 26.0, 80.0)
	var crow := UI.hbox(3)
	crow.custom_minimum_size.y = th
	v.add_child(crow)
	var orow := UI.hbox(3)
	orow.custom_minimum_size.y = th
	v.add_child(orow)
	return {"root": root, "sb": sbx, "standee": st, "name": nm, "tag": tag, "gold": gl, "inf": il, "laurel": ll, "cards": cl, "pv": pv, "att": al, "def": dl, "mil": mil,
		"crow": crow, "orow": orow, "th": th, "sig": "", "pid": pid}

## Gettone (moneta, Influenza, alloro) con il numero scritto al centro
func _token(tex_path: String, sz: float, fsize: int, col := Color(1, 1, 1)) -> Dictionary:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(sz, sz)
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	var tr := UI.tex_rect(load(tex_path), Vector2(sz, sz))
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(tr)
	var l := UI.label("", fsize, col, UI.f_head, HORIZONTAL_ALIGNMENT_CENTER)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.02))
	l.add_theme_constant_override("outline_size", max(4, fsize / 4))
	l.position = Vector2(-6, 0)
	l.size = Vector2(sz + 12, sz)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(l)
	return {"root": holder, "tex": tr, "label": l}

## Testo d'aiuto sulla forza militare di una famiglia
func _mil_tip(p: Dictionary, sa: int, sd: int) -> String:
	var t := "Forza militare di %s come Condottiero\nAttacco %d · Difesa %d" % [p.name, sa, sd]
	if p.troops.is_empty():
		t += "\nNessuna Truppa: non può guidare un esercito (e i bonus di difesa non contano)."
	else:
		var parts: Array = []
		for tr in p.troops:
			parts.append("%s %d/%d" % [Data.TROOPS[tr].name, Data.TROOPS[tr].att, Data.TROOPS[tr].def])
		t += "\nTruppe (Att/Dif): " + ", ".join(parts)
		var bon: int = sa + sd
		for tr in p.troops:
			bon -= Data.TROOPS[tr].att + Data.TROOPS[tr].def
		if bon > 0:
			t += "\nBonus di famiglia e tessere: +%d" % bon
	t += "\nIn battaglia si aggiunge un dado (1-6)."
	return t

func _player_tiles(pp: Dictionary) -> void:
	var p = g.players[pp.pid]
	var evs: Array = p.events + (["POPE"] if g.pope_holder == p.id else [])
	var sig := "%s|%s|%s" % [",".join(p.cities), ",".join(evs), ",".join(p.troops)]
	if sig == pp.sig:
		return
	pp.sig = sig
	_clear(pp.crow)
	_clear(pp.orow)
	var th: float = pp.th
	var tw: float = floor(th * 0.8)
	var maxw: float = RW - 16
	# città: gruppi con etichetta colorata
	var groups: Array = []
	for c in Data.CITIES:
		var ts: Array = p.cities.filter(func(t): return Data.city_tile(t).city == c)
		if not ts.is_empty():
			groups.append([c, ts])
	var n_c: int = p.cities.size()
	var cw: float = tw
	if n_c > 0:
		cw = min(tw, floor((maxw - groups.size() * 20 - n_c * 3) / n_c))
	for gr in groups:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UI.sb(Data.CITY_COLOR[gr[0]], Data.CITY_COLOR[gr[0]].lightened(0.4), 1, 3, 1))
		chip.custom_minimum_size = Vector2(16, th)
		chip.tooltip_text = Data.CITY_NAME[gr[0]]
		var cl := UI.label(Data.CITY_NAME[gr[0]].substr(0, 1), 14, Color(1, 1, 1), UI.f_head, HORIZONTAL_ALIGNMENT_CENTER)
		cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_child(cl)
		pp.crow.add_child(chip)
		for t in gr[1]:
			pp.crow.add_child(_make_tile(t, Vector2(cw, th)))
	if n_c == 0:
		pp.crow.add_child(UI.label("nessuna tessera Città", 14, Color(0.6, 0.55, 0.45), UI.f_italic))
	# truppe | eventi e Papa
	var n_o: int = p.troops.size() + evs.size()
	var ow: float = tw
	if n_o > 0:
		ow = min(tw, floor((maxw - (14 if not evs.is_empty() and not p.troops.is_empty() else 0) - n_o * 3) / n_o))
	for t in p.troops:
		pp.orow.add_child(_make_tile(t, Vector2(ow, th)))
	if not evs.is_empty() and not p.troops.is_empty():
		var sp := VSeparator.new()
		sp.custom_minimum_size.x = 8
		pp.orow.add_child(sp)
	for e in evs:
		pp.orow.add_child(_make_tile(e, Vector2(ow, th)))

# ================================================================= aggiornamento

func refresh() -> void:
	if g == null:
		return
	hdr_decade.text = "Decade " + UI.roman(g.decade)
	var cp = g.players[g.current]
	hdr_turn.text = "Turno: " + cp.name
	hdr_info.text = "Guerre %d/%d · Tradimento: %d" % [g.wars_fought, g.war_limit, g.deck.size()]
	# eventi
	_sync_tiles(events_box, g.event_pool, Vector2(104, 130))
	pope_view.visible = g.pope_available
	# città
	for c in Data.CITIES:
		var avail: Array = []
		for t in g.city_pool:
			if Data.city_tile(t).city == c:
				avail.append(t)
		_sync_tiles(city_rows[c], avail, Vector2(68, 84))
		city_chips[c].text = "Status %d\nmin. %d Oro" % [g.status[c], 2 * g.status[c]]
	for t in troop_views:
		var tv: TileView = troop_views[t]
		tv.badge = "x%d" % g.troop_pool[t]
		tv.dim = g.troop_pool[t] <= 0
		tv.queue_redraw()
	_apply_selectables()
	if cur.is_empty() and not g.finished:
		var ap = g.players[g.current]
		if g.war.size() > 0:
			prompt_label.text = "Guerra in corso…"
		elif g.auction.size() > 0:
			prompt_label.text = "Asta in corso…"
		elif ap.is_ai:
			prompt_label.text = "%s sta tramando…" % ap.name
	# giocatori
	for pp in panels:
		var p = g.players[pp.pid]
		pp.gold.text = str(p.gold)
		pp.inf.text = str(p.inf)
		pp.laurel.text = str(p.vp_counters)
		pp.cards.text = str(p.treach.size())
		var tg := "Lato %s" % p.side
		if g.pope_holder == p.id:
			tg = "Papa · " + tg
		if p.is_ai:
			tg += " · IA " + ["Facile", "Normale", "Machiavelli"][p.level]
		if g.negotiation and g.reputation.get(p.id, 1.0) < 0.9:
			tg = g.reputation_txt(p.id).capitalize() + " · " + tg
		pp.tag.text = tg
		pp.pv.text = "≈%d PV" % g.provisional_score(p.id)
		var sa: int = g.condo_strength(p.id, "att", [])
		var sd: int = g.condo_strength(p.id, "def", [])
		pp.att.text = str(sa)
		pp.def.text = str(sd)
		var mt := _mil_tip(p, sa, sd)
		pp.mil.tooltip_text = mt
		for c in pp.mil.get_children():
			c.tooltip_text = mt
		pp.standee.texture = Data.screen_tex(p.family, p.passed and g.auction.size() > 0)
		var active: bool = p.id == g.current
		var hb: bool = g.auction.size() > 0 and g.auction.get("high", -1) == p.id
		pp.sb.border_color = UI.GOLD if active else (Color(0.4, 0.9, 0.4) if hb else p.color.darkened(0.2))
		pp.sb.set_border_width_all(4 if active or hb else 2)
		pp.sb.bg_color = Color(0.22, 0.15, 0.08, 0.96) if active else Color(0.12, 0.08, 0.05, 0.93)
		_player_tiles(pp)
	_refresh_hand()
	_refresh_deals()
	map.queue_redraw()

func _sync_tiles(box: Container, ids: Array, sz: Vector2, mini := false) -> void:
	var existing := {}
	for c in box.get_children():
		if c is TileView:
			existing[c.id] = c
	for c in box.get_children():
		if c is TileView and not c.id in ids:
			if not mini:
				var owner := _owner_of(c.id)
				if c.id == "POPE":
					owner = g.pope_holder
				if owner >= 0:
					_fly(c.tex, c.get_global_rect(), panels[owner].root.get_global_rect())
			box.remove_child(c)
			c.queue_free()
			if market_views.get(c.id) == c:
				market_views.erase(c.id)
	var i := 0
	for id in ids:
		var tv: TileView
		if existing.has(id):
			tv = existing[id]
		else:
			tv = _make_tile(id, sz)
			box.add_child(tv)
			if not mini:
				market_views[id] = tv
		box.move_child(tv, i)
		i += 1

func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

func _fly(tex: Texture2D, from: Rect2, to: Rect2) -> void:
	if tex == null or from.size.x <= 0:
		return
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.position = from.position
	tr.size = from.size
	tr.z_index = 30
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(tr, "position", from.position - Vector2(20, 30), 0.25).set_trans(Tween.TRANS_SINE)
	tw.tween_property(tr, "size", from.size * 1.4, 0.25)
	tw.chain().tween_property(tr, "position", to.get_center() - Vector2(20, 25), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(tr, "size", Vector2(40, 50), 0.6)
	tw.chain().tween_property(tr, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(tr.queue_free)
	Sfx.play("coin", -8)

func _refresh_hand() -> void:
	_clear(hand_box)
	if viewer < 0:
		hand_title.text = ""
		return
	var p = g.players[viewer]
	hand_title.text = "Le tue carte Tradimento (%d/%d)" % [p.treach.size(), g.treach_limit(viewer)]
	var n: int = max(1, p.treach.size())
	var cw: float = min(74.0, floor((228.0 - 4 * (n - 1)) / n))
	for card in p.treach:
		var tv := _make_tile(card, Vector2(cw, cw * 1.64))
		hand_box.add_child(tv)

func _refresh_deals() -> void:
	if deals_rt == null:
		return
	var lines: Array = []
	for d in g.active_deals():
		var mine: bool = viewer >= 0 and (int(d.to) == viewer or int(d.from) == viewer)
		var t := g.deal_text(d)
		if mine:
			lines.append("[color=#ffd36b]• %s[/color]" % t)
		else:
			lines.append("[color=#d8c8a8]• %s[/color]" % t)
	if lines.is_empty():
		deals_rt.text = "[i][color=#9a8a70]Nessun patto in corso.[/color][/i]"
	else:
		deals_rt.text = "\n".join(lines)

func _apply_selectables() -> void:
	var sel_items: Array = []
	var sel_troops: Array = []
	if cur.get("kind", "") == "turn":
		sel_items = cur.ctx.get("auction", [])
		sel_troops = cur.ctx.get("troops", [])
	for id in market_views:
		var tv: TileView = market_views[id]
		if is_instance_valid(tv):
			tv.selectable = id in sel_items
	pope_view.selectable = "POPE" in sel_items
	for t in troop_views:
		troop_views[t].selectable = t in sel_troops

# ================================================================= registro

func _on_log(text: String, kind: String) -> void:
	if kind == "private" and (viewer < 0):
		return
	var col := "#e9dcc0"
	match kind:
		"important": col = "#ffd36b"
		"decade": col = "#f0b44a"
		"war": col = "#ff9b86"
		"dice": col = "#ffc9a8"
		"auction": col = "#bfe3ff"
		"bid": col = "#9fb7cc"
		"treach": col = "#e8a0ff"
		"income": col = "#b6f0a0"
		"buy": col = "#d8f0c8"
		"private": col = "#c8a0ff"
		"deal": col = "#ffd98a"
		"betray": col = "#ff5a4a"
	if kind == "decade":
		log_rt.append_text("\n[b][color=%s]%s[/color][/b]\n" % [col, text])
	else:
		log_rt.append_text("[color=%s]%s[/color]\n" % [col, text])
	match kind:
		"income":
			if viewer >= 0 and text.begins_with(g.players[viewer].name + " riceve"):
				_toast(text.replace(g.players[viewer].name + " riceve", "Rendita:"))
		"buy":
			Sfx.play("coin", -6)
		"treach":
			Sfx.play("card", -2)
		"important":
			if "vince" in text:
				Sfx.play("drum", -4)

func _on_decade(d: int) -> void:
	Sfx.play("bell", -4)
	if tut and d >= 2:
		get_tree().create_timer(2.0).timeout.connect(func(): _tut_tip("decade%d" % d))
	var l := UI.label("Decade " + UI.roman(d), 120, UI.GOLD, UI.f_title, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 5)
	l.add_theme_constant_override("shadow_offset_y", 5)
	l.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.02))
	l.add_theme_constant_override("outline_size", 10)
	l.position = Vector2(CX - 100, 380)
	l.size = Vector2(CW + 200, 160)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.4)
	tw.tween_interval(1.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)

# ================================================================= anteprime

func _on_tile_hover(id: String, on: bool, view: Control) -> void:
	if not on:
		zoom.visible = false
		return
	zoom_tex.texture = Data.item_tex(id)
	var sz := Vector2(240, 300)
	if Data.TREACHERY.has(id):
		sz = Vector2(200, 330)
	zoom_tex.custom_minimum_size = sz
	zoom_txt.text = item_desc(id)
	zoom.visible = true
	zoom.reset_size()
	var vr := view.get_global_rect()
	var pos := Vector2(vr.end.x + 12, vr.position.y - 60)
	if pos.x + 280 > 1920:
		pos.x = vr.position.x - 280
	pos.y = clampf(pos.y, 4, 1080 - zoom.size.y - 4)
	zoom.position = pos

func _on_city_hover(c: String, on: bool) -> void:
	if not on:
		zoom.visible = false
		return
	var txt := "[b]%s[/b]\nStatus attuale: %d\nArtisti assegnati: %d\nValore attuale: %d PV per tessera\n" % [Data.CITY_NAME[c], g.status[c], g.artists[c], g.city_ranking()[c]]
	for p in g.players:
		var n := 0
		for t in p.cities:
			if Data.city_tile(t).city == c:
				n += 1
		if n > 0:
			txt += "\n%s: %d tessere" % [p.name, n]
	zoom_tex.texture = Data.back_tex(Data.CITY_BACK[c])
	zoom_tex.custom_minimum_size = Vector2(160, 200)
	zoom_txt.text = txt
	zoom.visible = true
	zoom.reset_size()
	var r := map.city_rect(c)
	zoom.position = Vector2(clampf(r.end.x + 10, 0, 1920 - 280), clampf(r.position.y, 4, 1080 - zoom.size.y - 4))

func item_desc(id: String) -> String:
	if id == "POPE":
		return "[b]Il Papa[/b]\nAsta in Influenza.\n+3 Oro di rendita a fine Decade.\nLega Santa: una volta per Decade unisci le tue Truppe a una parte in guerra.\n+3 PV se lo possiedi alla fine della partita.\nTorna all'asta a fine Decade."
	if Data.is_city_tile(id):
		var t := Data.city_tile(id)
		var s := "[b]%s[/b] — %s\n" % [t.name, Data.CITY_NAME[t.city]]
		if t.gold > 0:
			s += "Rendita: %d Oro\n" % t.gold
		if t.inf > 0:
			s += "Rendita: %d Influenza\n" % t.inf
		if t.get("merchant", false):
			s += "[i]Mercante[/i]\n"
		for ab in t.ab:
			s += "• " + Data.AB_TEXT[ab] + "\n"
		s += "Vale i PV della città a fine partita (ora %d).\nApertura d'asta: %d Oro." % [g.city_ranking()[t.city], 2 * g.status[t.city]]
		var owner := _owner_of(id)
		if owner >= 0:
			s += "\n[i]Di %s[/i]" % g.players[owner].name
		return s
	if Data.is_event(id):
		var e := Data.event(id)
		var s2 := "[b]%s[/b] — Decade %s\nSi paga in %s.\n" % [e.name, UI.roman(e.dec), Data.cur_name(e.cur)]
		match str(e.kind):
			"vp": s2 += "Artista: %d PV a fine partita." % e.value
			"sta": s2 += "Artista: assegnalo a una città, il suo Status sale di 1 (conta anche per gli spareggi)."
			"merchant": s2 += "+1 Oro per ogni tuo Mercante a ogni Decade e +1 PV per Mercante a fine partita."
			"french": s2 += "Gioca subito contro una città (Status -2) o scartala."
		return s2
	if Data.TROOPS.has(id):
		var d: Dictionary = Data.TROOPS[id]
		var s3 := "[b]%s[/b]\nCosto: %d Oro\nAttacco %d · Difesa %d\n" % [d.name, d.cost, d.att, d.def]
		if d.inf > 0:
			s3 += "Rendita: %d Influenza\n" % d.inf
		if d.noI:
			s3 += "Non acquistabile nella Decade I.\n"
		s3 += "Disponibili: %d" % g.troop_pool.get(id, 0)
		return s3
	if Data.TREACHERY.has(id):
		return "[b]%s[/b]\n%s" % [Data.TREACHERY[id].name, Data.TREACHERY[id].txt]
	return id

func _owner_of(id: String) -> int:
	for p in g.players:
		if id in p.cities or id in p.events or id in p.troops:
			return p.id
	return -1

# ================================================================= decisioni umane

var _autobot: AIBrain

func _autoanswer(pid: int, kind: String, ctx: Dictionary) -> void:
	# modalità di prova: un'IA risponde al posto dell'umano passando dalla GUI
	await get_tree().create_timer(float(cfg.get("autohuman_delay", 0.8))).timeout
	if cur.is_empty() or cur.kind != kind:
		return
	if _autobot == null:
		_autobot = AIBrain.new()
		_autobot.setup(g, pid, 2, 99)
	var r = _autobot.decide(kind, ctx)
	if cfg.get("auto_notroops", false) and kind == "turn" and typeof(r) == TYPE_DICTIONARY and str(r.get("type", "")) == "buy_troop":
		r = {"type": "pass"}   # solo per le prove: il giocatore automatico resta senza Truppe
	_submit(r)

func _on_decision(pid: int, kind: String, ctx: Dictionary) -> void:
	if cfg.get("autohuman", false):
		_autoanswer(pid, kind, ctx)
	cur = {"pid": pid, "kind": kind, "ctx": ctx}
	viewer = pid
	refresh()
	if kind in ["moment_offer", "holy_offer", "veto_bounty"]:
		var mk: String = kind if kind != "moment_offer" else str(ctx.get("kind", ""))
		if muted.has(mk) or not main.settings.get("prompt_moments", true) or cfg.get("autohuman", false):
			_defer_null()
			return
	_extra_text = _deals_note(ctx) if kind in ["bribe", "maltempo", "reroll", "place_sta", "french", "artist_ties"] else ""
	Sfx.play("card", -10, 0.8)
	var who: String = g.players[pid].name
	match kind:
		"turn":
			if not cfg.get("autohuman", false) and not tut:
				main.save_game(g.to_dict())   # salvataggio automatico a ogni tuo turno
			_turn_ui(ctx)
		"bid", "condo_bid":
			_auction_controls(ctx)
		"veto":
			var opts: Array = []
			if "card" in ctx.sources:
				opts.append({"label": "Gioca la carta Veto", "value": "card", "tex": Data.item_tex("veto")})
			if "lorenzo" in ctx.sources:
				opts.append({"label": "Veto di Lorenzo de' Medici", "value": "lorenzo", "tex": Data.item_tex("FIR_lorenzo")})
			opts.append({"label": "Lascia combattere", "value": ""})
			var vt := "%s ha dichiarato guerra: %s attacca %s." % [g.pname(ctx.starter), Data.CITY_NAME[ctx.att], Data.CITY_NAME[ctx.def]]
			var bty: Dictionary = ctx.get("bounty", {})
			if int(bty.get("gold", 0)) + int(bty.get("inf", 0)) > 0:
				vt += "\nTaglia promessa a chi pone il Veto: %d Oro, %d Influenza." % [int(bty.get("gold", 0)), int(bty.get("inf", 0))]
			_choose("%s: porre il Veto?" % who, vt, opts)
		"holy":
			var w: Dictionary = ctx.war
			var ht := "Come Papa puoi unire le tue Truppe (solo forza base) a una delle parti. Non ricevi paga né pedine Vittoria."
			for hd in ctx.get("deals", []):
				ht += "\nPatto con %s: %d %s per schierarti con %s (%s)." % [g.pname(int(hd.from)), int(hd.pay_amt), Data.cur_name(hd.pay_cur), Data.CITY_NAME[w[hd.side]], "già pagati" if hd.get("paid", false) else "a cose fatte"]
			_choose("Lega Santa", ht, [
				{"label": "Con %s (attacca)" % Data.CITY_NAME[w.att], "value": "att"},
				{"label": "Con %s (difende)" % Data.CITY_NAME[w.def], "value": "def"},
				{"label": "Non partecipare", "value": ""}])
		"bribe":
			var opts2: Array = []
			var i := 0
			for t in ctx.targets:
				opts2.append({"label": "%s di %s" % [Data.TROOPS[t[1]].name, g.pname(t[0])], "value": i, "tex": Data.item_tex(t[1])})
				i += 1
			opts2.append({"label": "Non corrompere", "value": -1})
			_choose("Corrompere Truppe", "Scegli una Truppa che non combatterà in questa guerra.", opts2)
		"maltempo":
			var w2: Dictionary = ctx.war
			_choose("Maltempo", "Puoi giocare Maltempo: -1 a una delle parti per tutta la guerra.", [
				{"label": "-1 a %s (attacco)" % Data.CITY_NAME[w2.att], "value": "att"},
				{"label": "-1 a %s (difesa)" % Data.CITY_NAME[w2.def], "value": "def"},
				{"label": "Non giocarla", "value": ""}])
		"reroll":
			var r: Dictionary = ctx.roll
			_choose("Ludovico Sforza", "%s: %s %d contro %s %d. Vuoi far rilanciare entrambi i dadi? (una volta per Decade)" % [r.label, Data.CITY_NAME[ctx.war[r.a_side]], r.ta, Data.CITY_NAME[ctx.war[r.d_side]], r.td], [
				{"label": "Rilancia i dadi", "value": true}, {"label": "Accetta il risultato", "value": false}])
		"place_sta":
			_choose_city("Assegna l'Artista", "Scegli la città che riceve %s: il suo Status sale di 1." % Data.item_name(ctx.item), Data.CITIES, false)
		"french":
			_choose_city("Invasione Francese", "Scegli la città da colpire (Status -2), oppure scarta la tessera.", Data.CITIES, true)
		"keep_treach":
			var o3: Array = []
			for k in 2:
				o3.append({"label": Data.TREACHERY[ctx.cards[k]].name, "value": k, "tex": Data.item_tex(ctx.cards[k])})
			_choose("Bentivoglio: scegli una carta", "Hai pescato due carte Tradimento: tienine una.", o3)
		"discard_treach":
			var o4: Array = []
			for c in ctx.cards:
				o4.append({"label": "Scarta " + Data.TREACHERY[c].name, "value": c, "tex": Data.item_tex(c)})
			_choose("Troppe carte Tradimento", "Il tuo limite è %d: scegli una carta da scartare." % ctx.limit, o4)
		"start_war_card":
			_choose("Iniziare una Guerra", "Vuoi giocare ora la carta per iniziare una guerra aggiuntiva?", [
				{"label": "Sì, dichiara guerra", "value": "yes"}, {"label": "Non ora", "value": "no"}], func(v):
					if v == "yes":
						_pick_war(func(a, d): _submit({"att": a, "def": d}), func(): _submit(null))
					else:
						_submit(null))
		"baglioni_cur":
			_choose("Baglioni", "Per questa Decade il tuo sconto di 1 si applica alle offerte in:", [
				{"label": "Oro", "value": "gold", "tex": load("res://assets/ui/gold.png")},
				{"label": "Influenza", "value": "inf", "tex": load("res://assets/ui/influence.png")}])
		"artist_ties":
			_artist_ties(ctx.order)
		"deal_offer":
			_deal_offer_ui(ctx)
		"deal_counter":
			_choose("Controproposta", "%s risponde con una controproposta:\n%s.\nAccetti?" % [g.pname(int(ctx.deal.to)), g.deal_text(ctx.deal)], [
				{"label": "Accetta", "value": true}, {"label": "Rifiuta", "value": false}])
		"deal_pay":
			var dd: Dictionary = ctx.deal
			var why := "per il patto" if dd.get("type", "") != "bounty" else "come taglia per il Veto"
			_choose("Mantieni la parola?", "Hai promesso %d %s a %s %s. Il patto è stato rispettato: paghi?" % [int(ctx.amount), Data.cur_name(ctx.cur), g.pname(int(ctx.to)), why], [
				{"label": "Paga", "value": true}, {"label": "Non pagare (tradimento: la tua reputazione crolla)", "value": false}])
		"holy_offer":
			var w3: Dictionary = ctx.war
			_moment_bar({"title": "Offerta al Papa", "mute_key": "holy_offer", "types": ["holy"], "ctx": {"to": int(ctx.pope)}, "allow_mute": true, "cancel": "Nessuna offerta",
				"text": "Puoi offrire denaro al Papa (%s) perché formi la Lega Santa a fianco di %s." % [g.pname(int(ctx.pope)), Data.CITY_NAME[w3[ctx.side]]]}, func(d):
					_moment_result("holy_offer", d))
		"veto_bounty":
			_moment_bar({"title": "Taglia sul Veto", "types": ["veto_bounty"], "allow_mute": true, "cancel": "Nessuna taglia",
				"text": "%s attacca %s e hai tessere in gioco. Vuoi promettere una ricompensa a chi porrà il Veto?" % [Data.CITY_NAME[ctx.att], Data.CITY_NAME[ctx.def]]}, func(d):
					_moment_result("veto_bounty", d))
		"moment_offer":
			var mk2: String = ctx.kind
			var titles := {"card_req": "Corruzione o Maltempo su commissione", "reroll_req": "Rilancio dei dadi", "artist_req": "Artista su commissione",
				"french_req": "Invasione Francese su commissione", "ties_req": "Spareggio tra le città"}
			var texts := {"card_req": "Durante questa guerra puoi pagare un giocatore perché giochi una carta Tradimento a tuo favore (se ce l'ha!).",
				"reroll_req": "%s può far rilanciare i dadi con Ludovico Sforza. Offri qualcosa perché lo faccia?" % g.pname(int(ctx.get("to", -1))),
				"artist_req": "%s ha vinto %s e deve assegnarlo a una città. Paghi perché scelga la tua?" % [g.pname(int(ctx.get("to", -1))), Data.item_name(str(ctx.get("item", "")))],
				"french_req": "%s ha vinto l'Invasione Francese. Paghi perché colpisca una città a tua scelta (o la scarti)?" % g.pname(int(ctx.get("to", -1))),
				"ties_req": "%s (Bentivoglio) decide gli spareggi tra città. Paghi perché favorisca una città?" % g.pname(int(ctx.get("to", -1)))}
			if mk2 == "reroll_req" and ctx.has("roll"):
				var rr: Dictionary = ctx.roll
				texts[mk2] += "\n%s: %s %d contro %s %d." % [rr.label, Data.CITY_NAME[ctx.war[rr.a_side]], rr.ta, Data.CITY_NAME[ctx.war[rr.d_side]], rr.td]
			_moment_bar({"title": titles.get(mk2, "Accordo"), "types": [mk2], "ctx": ctx, "allow_mute": true, "cancel": "Nessuna offerta",
				"text": texts.get(mk2, "")}, func(d):
					_moment_result(mk2, d))
		_:
			_submit(null)
	if tut:
		_tut_decision(kind, ctx)

func _submit(v) -> void:
	_close_choice()
	cur = {}
	prompt_label.text = ""
	_clear(actions_box)
	_set_bid_controls(false)
	map.selectable_cities = []
	_apply_selectables()
	g.submit(v)

# ---------------------------------------------------------------- turno

func _compact_actions() -> void:
	for b in actions_box.get_children():
		if b is Button:
			b.add_theme_font_size_override("font_size", 15)
			var sbn := UI.sb(Color("4a3220"), UI.GOLD_DARK, 2, 6, 8)
			sbn.content_margin_top = 5
			sbn.content_margin_bottom = 5
			b.add_theme_stylebox_override("normal", sbn)
			var sbh := UI.sb(Color("6a4628"), UI.GOLD, 2, 6, 8)
			sbh.content_margin_top = 5
			sbh.content_margin_bottom = 5
			b.add_theme_stylebox_override("hover", sbh)
			var sbd := UI.sb(Color("2a221c"), Color("5a4a38"), 2, 6, 8)
			sbd.content_margin_top = 5
			sbd.content_margin_bottom = 5
			b.add_theme_stylebox_override("disabled", sbd)

func _turn_ui(ctx: Dictionary) -> void:
	_clear(actions_box)
	var p = g.players[cur.pid]
	if _last_turn_seen != g.turn_number:
		_last_turn_seen = g.turn_number
		_turn_deals = 0
	prompt_label.text = "%s, tocca a te: clicca una tessera evidenziata (asta) o una Truppa (acquisto), oppure scegli un'azione." % p.name
	if ctx.get("must_act", false):
		prompt_label.text += " Dopo due giri di passaggi devi agire."
	var ob: Array = ctx.get("obligations", [])
	if not ob.is_empty():
		var o0: Dictionary = ob[0]
		prompt_label.text += "\nPatto: " + g.deal_text(o0) + ("" if ob.size() == 1 else " (+%d)" % (ob.size() - 1))
	var bt := UI.button("Carta Tradimento (1 Oro + 1 Inf.)", func(): _submit({"type": "buy_treach"}))
	bt.disabled = not ctx.treach
	actions_box.add_child(bt)
	var bw := UI.button("Dichiara Guerra", func(): _pick_war(func(a, d): _submit({"type": "war", "att": a, "def": d}), func(): _turn_ui(ctx)))
	bw.disabled = not ctx.war
	actions_box.add_child(bw)
	if not ctx.discard.is_empty():
		actions_box.add_child(UI.button("Scarta Truppa", func():
			var o: Array = []
			for t in ctx.discard:
				o.append({"label": Data.TROOPS[t].name, "value": t, "tex": Data.item_tex(t)})
			o.append({"label": "Annulla", "value": ""})
			_choose("Scarta una Truppa", "La Truppa torna disponibile. È la tua azione del turno.", o, func(v):
				if v != "":
					_submit({"type": "discard_troop", "troop": v})
				else:
					_close_choice())))
	if g.negotiation and not ctx.get("deal_types", []).is_empty() and _turn_deals < 3:
		var bx := UI.button("Proponi accordo…", func():
			_deal_form({"title": "Proponi un accordo", "types": ctx.deal_types,
				"text": "Nel tuo turno puoi fare fino a tre proposte. Gli accordi non sono vincolanti."}, func(d):
					if d == null:
						_turn_ui(ctx)
						return
					_turn_deals += 1
					_submit({"type": "free", "what": "deal", "deal": d})))
		bx.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
		actions_box.add_child(bx)
	var bp := UI.button("Passa", func(): _submit({"type": "pass"}))
	bp.disabled = ctx.get("must_act", false)
	actions_box.add_child(bp)
	for f in ctx.free:
		var fb: Button
		match str(f.what):
			"ruba_oro":
				fb = UI.button("Rubare Oro", func(): _pick_player("Rubare Oro: a chi sottrai 3 Oro?", func(t): _submit({"type": "free", "what": "ruba_oro", "target": t})))
			"ruba_inf":
				fb = UI.button("Rubare Influenza", func(): _pick_player("Rubare Influenza: a chi sottrai 2 Influenza?", func(t): _submit({"type": "free", "what": "ruba_inf", "target": t})))
			"lucrezia":
				fb = UI.button("Lucrezia Borgia", func(): _pick_player("Lucrezia Borgia: a chi sottrai 2 Influenza?", func(t): _submit({"type": "free", "what": "lucrezia", "target": t})))
			"free_treach":
				var src: String = f.src
				fb = UI.button("Carta gratuita (%s)" % ("famiglia" if src == "family" else Data.city_tile(src).name), func(): _submit({"type": "free", "what": "free_treach", "src": src}))
			"bank":
				var src2: String = f.src
				fb = UI.button("Banchiere", func(): _bank_dialog(src2))
		if fb:
			fb.add_theme_color_override("font_color", Color(0.9, 0.75, 1.0))
			actions_box.add_child(fb)
	_compact_actions()
	_apply_selectables()

func _on_tile_clicked(id: String) -> void:
	if cur.get("kind", "") != "turn":
		return
	var ctx: Dictionary = cur.ctx
	if id in ctx.troops:
		var d: Dictionary = Data.TROOPS[id]
		_choose("Acquistare %s?" % d.name, "Costo %d Oro · Attacco %d · Difesa %d%s" % [d.cost, d.att, d.def, (" · +%d Influenza per Decade" % d.inf) if d.inf > 0 else ""],
			[{"label": "Acquista", "value": "y", "tex": Data.item_tex(id)}, {"label": "Annulla", "value": "n"}], func(v):
				if v == "y":
					_submit({"type": "buy_troop", "troop": id})
				else:
					_close_choice())
	elif id in ctx.auction:
		var kind := g.item_kind(id)
		var cur_c := g.item_currency(id)
		var txt := "Si paga in %s." % Data.cur_name(cur_c)
		if kind == "city":
			txt += " Devi aprire con almeno %d Oro (doppio dello Status)." % (2 * g.status[Data.city_tile(id).city])
		elif kind == "event" and g.event_pool.size() == 1:
			txt += " È l'ultimo Evento: la Decade terminerà dopo quest'asta!"
		else:
			txt += " Puoi aprire anche con 0."
		_choose("Mettere all'asta %s?" % Data.item_name(id), txt, [{"label": "Metti all'asta", "value": "y", "tex": Data.item_tex(id)}, {"label": "Annulla", "value": "n"}], func(v):
			if v == "y":
				Sfx.play("gavel")
				_submit({"type": "auction", "item": id})
			else:
				_close_choice())

func _deal_offer_ui(ctx: Dictionary) -> void:
	var d: Dictionary = ctx.deal
	var from: int = int(d.from)
	var rep := g.reputation_txt(from)
	_close_choice()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.position = Vector2(CX, 0)
	dim.size = Vector2(CW, 1080)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	choice_layer.add_child(dim)
	var pnl := UI.panel(Color(0.14, 0.09, 0.05, 0.98), Color(1.0, 0.8, 0.4), 10, 18)
	pnl.custom_minimum_size = Vector2(640, 10)
	choice_layer.add_child(pnl)
	var v := UI.vbox(10)
	pnl.add_child(v)
	var h := UI.hbox(14)
	v.add_child(h)
	h.add_child(UI.tex_rect(Data.screen_tex(g.players[from].family), Vector2(56, 120)))
	var tv := UI.vbox(6)
	h.add_child(tv)
	tv.add_child(UI.head("Proposta di %s" % g.pname(from), 26))
	var t := UI.label(g.deal_text(d) + ".", 20, UI.PARCH)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = 520
	tv.add_child(t)
	tv.add_child(UI.label("Reputazione di %s: %s. Gli accordi non sono vincolanti." % [g.pname(from), rep], 17, Color(0.85, 0.78, 0.62), UI.f_italic))
	var row := UI.hbox(8)
	v.add_child(row)
	row.add_child(UI.button("Accetta", func(): _submit({"accept": true}), 130))
	row.add_child(UI.button("Rifiuta", func(): _submit({"accept": false}), 130))
	var row2 := UI.hbox(8)
	v.add_child(row2)
	row2.add_child(UI.label("Controproposta:", 18, UI.GOLD))
	var sp := SpinBox.new()
	sp.min_value = 1
	sp.max_value = 60
	var base: int = int(d.get_amt) if d.type == "exchange" else int(d.pay_amt)
	sp.value = base + (0 if d.type == "exchange" else 2)
	sp.custom_minimum_size.x = 110
	row2.add_child(sp)
	var unit := UI.label(Data.cur_name(d.get_cur if d.type == "exchange" else d.pay_cur) + (" da dare" if d.type == "exchange" else ""), 18, UI.PARCH)
	row2.add_child(unit)
	var now_cb := CheckBox.new()
	now_cb.text = "pagamento subito"
	now_cb.visible = d.type != "exchange"
	row2.add_child(now_cb)
	row2.add_child(UI.button("Proponi", func():
		var r := {"accept": false, "counter": int(sp.value)}
		if now_cb.button_pressed:
			r["timing"] = "now"
		_submit(r)))
	await get_tree().process_frame
	if is_instance_valid(pnl):
		_fit_place(pnl, 600)
		pnl.resized.connect(func(): _fit_place(pnl, 600))

## Modulo di proposta d'accordo (tutti i tipi)
func _deal_form(spec: Dictionary, cb: Callable) -> void:
	_close_choice()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.position = Vector2(CX, 0)
	dim.size = Vector2(CW, 1080)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	choice_layer.add_child(dim)
	var f := DealForm.new().setup(g, cur.pid, spec)
	choice_layer.add_child(f)
	f.done.connect(func(r):
		_close_choice()
		cb.call(r))
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(f):
		_fit_place(f, 560)
		f.resized.connect(func(): _fit_place(f, 560))

func _deals_note(ctx: Dictionary) -> String:
	var ds: Array = ctx.get("deals", [])
	if ds.is_empty():
		return ""
	var t := "\n\nPatti che ti riguardano:"
	for d in ds:
		t += "\n• " + g.deal_text(d)
	return t

## Momento di trattativa: invece di aprire subito il modulo, la barra delle azioni suggerisce
## gli accordi possibili; sei tu a scegliere se e quale proporre.
func _moment_bar(spec: Dictionary, cb: Callable) -> void:
	_close_choice()
	_clear(actions_box)
	var types: Array = spec.get("types", [])
	var mk: String = str(spec.get("mute_key", types[0] if not types.is_empty() else ""))
	prompt_label.text = "Momento per trattare: %s (facoltativo)" % spec.get("title", "Accordo")
	var dl := UI.label(str(spec.get("text", "")), 15, Color(0.88, 0.8, 0.64), UI.f_italic)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size.x = CW - 280
	actions_box.add_child(dl)
	var first := true
	for t in types:
		var info: Dictionary = Data.DEAL_INFO.get(t, {"name": str(t), "desc": ""})
		var b := UI.button(("★ " if first else "") + "Proponi: " + info.name + "…", func():
			var sp: Dictionary = spec.duplicate()
			sp["types"] = [t]
			_deal_form(sp, func(d):
				if d == null:
					_moment_bar(spec, cb)
				else:
					cb.call(d)))
		b.tooltip_text = info.desc + ("\n(Suggerito ora)" if first else "")
		actions_box.add_child(b)
		first = false
	actions_box.add_child(UI.button(spec.get("cancel", "Nessuna offerta"), func(): _submit(null)))
	if spec.get("allow_mute", false):
		actions_box.add_child(UI.button("Non chiedermelo più in questa partita", func():
			muted[mk] = true
			_submit(null)))
	_compact_actions()
	Sfx.play("coin", -14, 1.3)

func _moment_result(mk: String, d) -> void:
	if typeof(d) == TYPE_DICTIONARY and d.get("_mute", false):
		muted[mk] = true
		if d.get("_null", false):
			d = null
		else:
			d.erase("_mute")
	_submit(d)

func _defer_null() -> void:
	call_deferred("_submit", null)

func _bank_dialog(src: String) -> void:
	var o: Array = []
	for n in [1, 2, 3]:
		o.append({"label": "%d Oro → %d Influenza" % [n, n], "value": ["g2i", n]})
	for n in [1, 2, 3]:
		o.append({"label": "%d Influenza → %d Oro" % [n, n], "value": ["i2g", n]})
	o.append({"label": "Annulla", "value": null})
	_choose("Banchiere", "Una volta per Decade puoi cambiare fino a 3 Oro in Influenza o viceversa.", o, func(v):
		if v == null:
			_close_choice()
		else:
			_submit({"type": "free", "what": "bank", "src": src, "dir": v[0], "amount": v[1]}))

func _pick_player(title: String, cb: Callable) -> void:
	var o: Array = []
	for p in g.players:
		if p.id != cur.pid:
			o.append({"label": "%s (%d Oro, %d Inf.)" % [p.name, p.gold, p.inf], "value": p.id, "tex": Data.screen_tex(p.family)})
	o.append({"label": "Annulla", "value": -1})
	_choose(title, "", o, func(v):
		if v >= 0:
			cb.call(v)
		else:
			_close_choice())

func _pick_war(cb: Callable, cancel: Callable) -> void:
	_close_choice()
	prompt_label.text = "Guerra: clicca sulla mappa la città che ATTACCA."
	map.selectable_cities = Data.CITIES.duplicate()
	var opts: Array = []
	for c in Data.CITIES:
		opts.append({"label": "%s (Status %d)" % [Data.CITY_NAME[c], g.status[c]], "value": c})
	opts.append({"label": "Annulla", "value": ""})
	_choose("Dichiara Guerra (1/2)", "Quale città attacca?", opts, func(a):
		if a == "":
			map.selectable_cities = []
			cancel.call()
			return
		var o2: Array = []
		for c in Data.CITIES:
			if c != a:
				o2.append({"label": "%s (Status %d)" % [Data.CITY_NAME[c], g.status[c]], "value": c})
		o2.append({"label": "Annulla", "value": ""})
		map.selectable_cities = Data.CITIES.filter(func(x): return x != a)
		map.highlight = {a: Color(0.9, 0.1, 0.05)}
		prompt_label.text = "Guerra: %s attacca… clicca la città che DIFENDE." % Data.CITY_NAME[a]
		_choose("Dichiara Guerra (2/2)", "%s attacca. Quale città difende?" % Data.CITY_NAME[a], o2, func(d):
			map.selectable_cities = []
			map.highlight = {}
			if d == "":
				cancel.call()
			else:
				Sfx.play("drum", -6)
				cb.call(a, d)), true)

var _city_pick_cb: Callable

func _on_city_clicked(c: String) -> void:
	if _city_pick_cb.is_valid():
		var cb := _city_pick_cb
		cb.call(c)

func _choose_city(title: String, text: String, cities: Array, allow_discard: bool) -> void:
	map.selectable_cities = cities.duplicate()
	var o: Array = []
	for c in cities:
		o.append({"label": "%s (Status %d)" % [Data.CITY_NAME[c], g.status[c]], "value": c})
	if allow_discard:
		o.append({"label": "Scarta", "value": ""})
	_choose(title, text, o)

func _artist_ties(order: Array) -> void:
	# per semplicità: proponi l'ordine migliore per le tue tessere oppure quello attuale
	var mine := order.duplicate()
	var p = g.players[cur.pid]
	var cnt := func(c):
		var n := 0
		for t in p.cities:
			if Data.city_tile(t).city == c:
				n += 1
		return n
	var i := 0
	while i < mine.size():
		var j := i
		while j + 1 < mine.size() and g.status[mine[j + 1]] == g.status[mine[i]] and g.artists[mine[j + 1]] == g.artists[mine[i]]:
			j += 1
		if j > i:
			var grp: Array = mine.slice(i, j + 1)
			grp.sort_custom(func(a, b): return cnt.call(a) > cnt.call(b))
			for k in grp.size():
				mine[i + k] = grp[k]
		i = j + 1
	var names := ", ".join(mine.map(func(c): return Data.CITY_NAME[c]))
	_choose("Bentivoglio decide le parità", "Ordine proposto (favorisce le tue tessere): " + names, [
		{"label": "Conferma quest'ordine", "value": mine}, {"label": "Lascia le parità (valore più basso a tutte)", "value": null}])

# ---------------------------------------------------------------- dialogo di scelta

func _choose(title: String, text: String, opts: Array, cb: Callable = Callable(), keep_map := false) -> void:
	_close_choice()
	if not keep_map:
		_city_pick_cb = Callable()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.position = Vector2(CX, 0)
	dim.size = Vector2(CW, 1080)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	choice_layer.add_child(dim)
	var pnl := UI.panel(Color(0.14, 0.09, 0.05, 0.98), UI.GOLD, 10, 18)
	pnl.custom_minimum_size = Vector2(620, 10)
	choice_layer.add_child(pnl)
	var v := UI.vbox(10)
	pnl.add_child(v)
	v.add_child(UI.head(title, 26))
	if _extra_text != "":
		text += _extra_text
		_extra_text = ""
	if text != "":
		var t := UI.label(text, 20, UI.PARCH)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size.x = 600
		v.add_child(t)
	var has_tex := false
	for o in opts:
		if o.has("tex") and o.tex != null:
			has_tex = true
	var done := func(val):
		if cb.is_valid():
			cb.call(val)
		else:
			_submit(val)
	if has_tex:
		var flow := HFlowContainer.new()
		flow.custom_minimum_size.x = 600
		flow.add_theme_constant_override("h_separation", 12)
		flow.add_theme_constant_override("v_separation", 10)
		v.add_child(flow)
		for o in opts:
			var b := UI.vbox(4)
			if o.has("tex") and o.tex != null:
				var tex: Texture2D = o.tex
				var ts := tex.get_size()
				var h := 150.0 if opts.size() <= 3 else (110.0 if opts.size() <= 6 else 84.0)
				var tr := UI.tex_rect(tex, Vector2(h * ts.x / ts.y, h))
				tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				b.add_child(tr)
			var btn := UI.button(o.label, func(): done.call(o.value))
			btn.disabled = o.get("disabled", false)
			b.add_child(btn)
			flow.add_child(b)
	else:
		for o in opts:
			var btn2 := UI.button(o.label, func(): done.call(o.value))
			btn2.disabled = o.get("disabled", false)
			btn2.custom_minimum_size.y = 46
			v.add_child(btn2)
	# selezione città anche dalla mappa
	var city_vals: Array = []
	for o in opts:
		if typeof(o.value) == TYPE_STRING and o.value in Data.CITIES:
			city_vals.append(o.value)
	if not city_vals.is_empty():
		_city_pick_cb = func(c):
			if c in city_vals:
				done.call(c)
		dim.position = Vector2(CX, 0)
	pnl.reset_size()
	await get_tree().process_frame
	if is_instance_valid(pnl):
		_fit_place(pnl, 1072 - pnl.size.y / 2 - 200)
		pnl.resized.connect(func(): _fit_place(pnl, 1072 - pnl.size.y / 2 - 200))
		pnl.modulate.a = 0
		create_tween().tween_property(pnl, "modulate:a", 1.0, 0.18)

## Colloca un riquadro centrato nella colonna centrale attorno a cy, riducendolo se non entra nello schermo
func _fit_place(pnl: Control, cy: float) -> void:
	if not is_instance_valid(pnl):
		return
	var sz: Vector2 = pnl.size
	var k: float = min(1.0, min(1060.0 / max(1.0, sz.y), 1900.0 / max(1.0, sz.x)))
	pnl.scale = Vector2(k, k)
	var w: float = sz.x * k
	var h: float = sz.y * k
	var x: float = clampf(CX + (CW - w) / 2.0, 10.0, 1910.0 - w)
	var y: float = clampf(cy - h / 2.0, 10.0, max(10.0, 1070.0 - h))
	pnl.position = Vector2(x, y)

func _close_choice() -> void:
	_clear(choice_layer)

# ================================================================= ASTA

func _build_auction_dialog() -> void:
	auction_dlg = UI.panel(Color(0.12, 0.08, 0.05, 0.98), UI.GOLD, 10, 16)
	auction_dlg.position = Vector2(CX + 8, 150)
	auction_dlg.size = Vector2(CW - 16, 560)
	auction_dlg.visible = false
	add_child(auction_dlg)
	var v := UI.vbox(10)
	auction_dlg.add_child(v)
	var title := UI.head("Asta", 30)
	title.clip_text = true
	title.custom_minimum_size.x = 660
	v.add_child(title)
	var h := UI.hbox(18)
	v.add_child(h)
	var img := UI.tex_rect(null, Vector2(170, 212))
	h.add_child(img)
	var right := UI.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	var cur_l := UI.label("", 21, UI.PARCH, UI.f_italic)
	cur_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cur_l.custom_minimum_size.x = 420
	right.add_child(cur_l)
	var bid_l := UI.label("", 38, Color(1, 0.86, 0.45), UI.f_title)
	right.add_child(bid_l)
	var high_l := UI.label("", 22, Color(0.6, 1, 0.6), UI.f_head)
	right.add_child(high_l)
	var parts := UI.hbox(18)
	right.add_child(parts)
	# controlli
	var ctr := UI.vbox(6)
	v.add_child(ctr)
	var info := UI.label("", 18, Color(0.85, 0.78, 0.62), UI.f_italic)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 660
	ctr.add_child(info)
	var row := UI.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	ctr.add_child(row)
	var row2 := UI.hbox(8)
	var cur_ic := UI.tex_rect(load("res://assets/ui/gold.png"), Vector2(40, 40))
	var minus := UI.button(" - ", func(): _bid_step(-1))
	var val := UI.label("0", 34, UI.GOLD, UI.f_head, HORIZONTAL_ALIGNMENT_CENTER)
	val.custom_minimum_size.x = 80
	var plus := UI.button(" + ", func(): _bid_step(1))
	var plus5 := UI.button("+5", func(): _bid_step(5))
	var offer := UI.button("Offri", _bid_offer, 140)
	offer.add_theme_color_override("font_color", Color(0.7, 1, 0.7))
	var pss := UI.button("Passa", _bid_pass, 120)
	var frz := UI.button("Congela…", _bid_freeze, 140)
	frz.add_theme_color_override("font_color", Color(0.9, 0.75, 1.0))
	var dl := UI.button("Trattativa…", _bid_deal, 150)
	dl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	var gap := Control.new()
	gap.custom_minimum_size.x = 18
	for c in [minus, cur_ic, val, plus, plus5, gap, offer, pss]:
		row.add_child(c)
	ctr.add_child(row2)
	for c in [frz, dl]:
		row2.add_child(c)
	minus.custom_minimum_size = Vector2(48, 48)
	plus.custom_minimum_size = Vector2(48, 48)
	plus5.custom_minimum_size = Vector2(56, 48)
	offer.custom_minimum_size = Vector2(150, 52)
	offer.add_theme_font_size_override("font_size", 22)
	pss.custom_minimum_size = Vector2(130, 52)
	pss.add_theme_font_size_override("font_size", 22)
	val.custom_minimum_size.x = 64
	auction_ui = {"title": title, "img": img, "cur": cur_l, "bid": bid_l, "high": high_l, "parts": parts, "cur_ic": cur_ic, "info": info, "row": row, "val": val, "offer": offer, "pass": pss, "freeze": frz, "minus": minus, "plus": plus, "plus5": plus5, "row2": row2, "deal": dl}
	_set_bid_controls(false)

func _on_auction(a: Dictionary) -> void:
	if a.is_empty():
		var tw := create_tween()
		tw.tween_interval(0.9)
		tw.tween_callback(func():
			if g.auction.is_empty():
				auction_dlg.visible = false
				refresh())
		return
	var ui := auction_ui
	var item: String = a.get("item", "")
	if not auction_dlg.visible or item != _last_auction_item or a.kind != _last_auction_kind:
		if not auction_dlg.visible:
			Sfx.play("gavel", -3)
		_last_hist = ""
	_last_auction_item = item
	_last_auction_kind = a.kind
	auction_dlg.visible = true
	var condo: bool = a.kind == "condo"
	if condo and g.war.size() > 0:
		var city: String = g.war.att if g.war.get("phase", "") == "condo_att" else g.war.def
		ui.title.text = "Condottiero di %s" % Data.CITY_NAME[city]
		ui.img.texture = Data.back_tex(Data.CITY_BACK[city])
		ui.cur.text = "Si paga in Influenza · la città paga %d Oro al vincitore" % g.status[city]
		ui.img.custom_minimum_size = Vector2(96, 120)
		# perché non ti viene chiesto di offrire?
		if viewer >= 0 and not (viewer in a.part):
			var why := ""
			if viewer == int(a.get("exclude", -1)):
				why = "Non partecipi: comandi già l'esercito dell'attaccante."
			elif g.players[viewer].troops.is_empty():
				why = "Non partecipi: per concorrere al comando serve almeno una Truppa (compra una Truppa nel tuo turno)."
			if why != "":
				ui.cur.text += "\n" + why
				var wkey := "%d_%s" % [g.war_seq, g.war.get("phase", "")]
				if _condo_note_seen != wkey:
					_condo_note_seen = wkey
					_toast(why)
				if tut and g.players[viewer].troops.is_empty():
					_tut_tip("no_troops", func(): return auction_dlg.get_global_rect() if auction_dlg.visible else Rect2())
	else:
		ui.title.text = "Asta: " + Data.item_name(item)
		ui.img.texture = Data.item_tex(item)
		ui.cur.text = "Si paga in %s%s" % [Data.cur_name(a.cur), (" · apertura minima %d" % a.min_open) if a.min_open > 0 else ""]
		ui.img.custom_minimum_size = Vector2(170, 212)
	if a.high >= 0:
		ui.bid.text = "%d %s" % [a.bid, "Oro" if a.cur == "gold" else "Inf."]
		ui.high.text = "Miglior offerta: " + g.pname(a.high)
	else:
		ui.bid.text = "—"
		ui.high.text = "Nessuna offerta"
	# paraventi dei partecipanti: l'ultima offerta di ciascuno è scritta sul gettone
	# (moneta per l'Oro, gettone quadrato per l'Influenza) appoggiato alla base
	var last_bid := {}
	for b in a.get("bids", []):
		if int(b[1]) >= 0:
			last_bid[int(b[0])] = int(b[1])
	var tok_path := "res://assets/ui/gold.png" if a.cur == "gold" else "res://assets/ui/influence.png"
	ui.cur_ic.texture = load(tok_path)
	_clear(ui.parts)
	var np: int = a.part.size()
	var sw: float = 66.0 if np <= 5 else 58.0
	var sh: float = sw * 2.2
	var tk: float = 56.0 if np <= 5 else 48.0
	for pid in a.part:
		var p = g.players[pid]
		var out: bool = a.out.has(pid)
		var col := UI.vbox(2)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(max(sw, tk) + 8, sh + tk * 0.45)
		col.add_child(holder)
		var st := UI.tex_rect(Data.screen_tex(p.family, out), Vector2(sw, sh))
		st.position = Vector2((holder.custom_minimum_size.x - sw) / 2.0, 0)
		if pid == a.high:
			st.modulate = Color(1.25, 1.2, 0.9)
		elif out:
			st.modulate = Color(0.75, 0.75, 0.75)
		holder.add_child(st)
		if pid == a.high:
			var glow := Panel.new()
			glow.add_theme_stylebox_override("panel", UI.sb(Color(0, 0, 0, 0), Color(0.5, 1, 0.5), 3, 6, 0))
			glow.position = st.position - Vector2(4, 4)
			glow.size = Vector2(sw + 8, sh + 8)
			glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(glow)
		if last_bid.has(pid):
			var t := _token(tok_path, tk, 26 if tk >= 56 else 22, Color(1, 1, 1))
			t.label.text = str(last_bid[pid])
			t.root.position = Vector2((holder.custom_minimum_size.x - tk) / 2.0, sh - tk * 0.55)
			if out:
				t.root.modulate = Color(0.7, 0.7, 0.7, 0.85)
			holder.add_child(t.root)
		var nl := UI.label(p.name.replace("Casa ", ""), 13, Color(0.55, 0.55, 0.55) if out else (Color(0.6, 1, 0.6) if pid == a.high else UI.PARCH), UI.f_head, HORIZONTAL_ALIGNMENT_CENTER)
		nl.custom_minimum_size.x = holder.custom_minimum_size.x
		col.add_child(nl)
		ui.parts.add_child(col)
	_place_auction_dialog()
	if a.high >= 0:
		var last := "%s: %d" % [g.pname(a.high), a.bid]
		if last != _last_hist:
			_last_hist = last
			Sfx.play("coin", -12, 1.2)
	refresh()

func _place_auction_dialog() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(auction_dlg) or not auction_dlg.visible:
		return
	auction_dlg.size = Vector2(CW - 16, 0)
	auction_dlg.reset_size()
	auction_dlg.size.x = CW - 16
	var condo: bool = g.auction.get("kind", "") == "condo"
	var want: float = 1072.0 - auction_dlg.size.y if condo else 150.0
	var k: float = min(1.0, 1064.0 / max(1.0, auction_dlg.size.y))
	auction_dlg.scale = Vector2(k, k)
	auction_dlg.position = Vector2(CX + 8 + (CW - 16) * (1.0 - k) / 2.0, clampf(want, 8, max(8.0, 1072.0 - auction_dlg.size.y * k)))

func _auction_controls(ctx: Dictionary) -> void:
	_set_bid_controls(true)
	freeze_target = -1
	_place_auction_dialog()
	bid_value = ctx.min
	auction_ui.val.text = str(bid_value)
	var p = g.players[cur.pid]
	var cn := Data.cur_name(ctx.cur)
	var txt := "%s, tocca a te. Minimo %d, puoi arrivare a %d %s" % [p.name, ctx.min, ctx.max, cn]
	if ctx.discount > 0:
		txt += " (sconto %d già incluso)" % ctx.discount
	if ctx.must:
		txt += ". Devi aprire l'asta."
	if ctx.kind == "condo":
		txt += ". Le tue Truppe: Attacco %d, Difesa %d." % [g.condo_strength(cur.pid, "att", []), g.condo_strength(cur.pid, "def", [])]
	if ctx.has("promise"):
		var pr: Dictionary = ctx.promise
		var other: int = int(pr.from) if int(pr.to) == cur.pid else int(pr.to)
		txt += "\nATTENZIONE: hai un patto con %s che ti vieta di rilanciare ora. Se offri, lo tradisci!" % g.pname(other)
	if ctx.has("freeze_promise"):
		var fp: Dictionary = ctx.freeze_promise
		freeze_target = int(fp.victim)
		txt += "\nHai promesso a %s di congelare %s: il Congelamento è già selezionato." % [g.pname(int(fp.from)), g.pname(int(fp.victim))]
	auction_ui.info.text = txt
	auction_ui.pass.disabled = ctx.must
	auction_ui.freeze.visible = ctx.can_freeze
	auction_ui.deal.visible = not ctx.get("deal_targets", []).is_empty()
	auction_ui.row2.visible = auction_ui.freeze.visible or auction_ui.deal.visible
	prompt_label.text = "Asta in corso: fai la tua offerta nel riquadro."

func _set_bid_controls(on: bool) -> void:
	if auction_ui.is_empty():
		return
	for k in ["minus", "plus", "plus5", "offer", "pass", "freeze", "deal"]:
		auction_ui[k].disabled = not on
	auction_ui.row.visible = on
	auction_ui.row2.visible = on
	if not on:
		auction_ui.info.text = ""

func _bid_step(d: int) -> void:
	if cur.is_empty():
		return
	bid_value = clampi(bid_value + d, cur.ctx.min, max(cur.ctx.min, cur.ctx.max))
	auction_ui.val.text = str(bid_value)

func _bid_offer() -> void:
	var r := {"bid": bid_value}
	if freeze_target >= 0:
		r["freeze"] = freeze_target
	Sfx.play("coin", -4)
	_submit(r)

func _bid_pass() -> void:
	var r := {"pass": true}
	if freeze_target >= 0:
		r["freeze"] = freeze_target
	_submit(r)

func _bid_deal() -> void:
	var ctx: Dictionary = cur.ctx
	_deal_form({"title": "Trattativa nell'asta", "types": ctx.get("deal_types", ["abstain"]), "ctx": {"targets": ctx.deal_targets},
		"text": "Puoi proporre un accordo una sola volta per asta. Non è vincolante: l'altro può accettare, rifiutare, controproporre… o tradirti."}, func(d):
			if d == null:
				return
			_set_bid_controls(false)
			_submit({"deal": d}))

func _bid_freeze() -> void:
	var o: Array = []
	for q in cur.ctx.remaining:
		if q != cur.pid:
			o.append({"label": g.pname(q), "value": q, "tex": Data.screen_tex(g.players[q].family)})
	o.append({"label": "Annulla", "value": -1})
	_choose("Congelare un'Offerta", "Il giocatore scelto non potrà rialzare la prossima volta che tocca a lui. Poi fai la tua offerta o passa.", o, func(v):
		freeze_target = v
		_close_choice()
		if v >= 0:
			auction_ui.info.text = "Congelerai %s. Ora offri o passa." % g.pname(v))

# ================================================================= GUERRA

func _build_war_dialog() -> void:
	war_dlg = UI.panel(Color(0.10, 0.06, 0.04, 0.98), Color(0.75, 0.2, 0.15), 10, 16)
	war_dlg.position = Vector2(CX + 8, 70)
	war_dlg.size = Vector2(CW - 16, 480)
	war_dlg.clip_contents = true
	war_dlg.visible = false
	add_child(war_dlg)
	var v := UI.vbox(8)
	war_dlg.add_child(v)
	var title := UI.head("Guerra", 30, Color(1, 0.6, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var phase := UI.label("", 19, UI.PARCH, UI.f_italic, HORIZONTAL_ALIGNMENT_CENTER)
	phase.clip_text = true
	phase.custom_minimum_size.x = 640
	v.add_child(phase)
	var h := UI.hbox(10)
	v.add_child(h)
	var sides := {}
	for s in ["att", "def"]:
		var col := UI.vbox(4)
		col.custom_minimum_size.x = 250
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cname := UI.head("", 22, Color(1, 0.9, 0.7))
		cname.clip_text = true
		cname.custom_minimum_size.x = 240
		col.add_child(cname)
		var role := UI.label("", 16, Color(0.85, 0.78, 0.62), UI.f_italic)
		col.add_child(role)
		var ch := UI.hbox(6)
		col.add_child(ch)
		var st := UI.tex_rect(null, Vector2(48, 104))
		ch.add_child(st)
		var cv := UI.vbox(2)
		ch.add_child(cv)
		var condo := UI.label("", 19, UI.PARCH, UI.f_head)
		condo.clip_text = true
		condo.custom_minimum_size.x = 180
		cv.add_child(condo)
		var strength := UI.label("", 18, Color(1, 0.85, 0.6))
		cv.add_child(strength)
		var troops := UI.hbox(2)
		col.add_child(troops)
		var ally := UI.label("", 15, Color(0.9, 0.8, 1.0), UI.f_italic)
		col.add_child(ally)
		sides[s] = {"name": cname, "role": role, "st": st, "condo": condo, "str": strength, "troops": troops, "ally": ally}
		if s == "att":
			h.add_child(col)
			var mid := UI.vbox(6)
			mid.custom_minimum_size.x = 170
			mid.alignment = BoxContainer.ALIGNMENT_CENTER
			var dh := UI.hbox(10)
			dh.alignment = BoxContainer.ALIGNMENT_CENTER
			var d1 := DiceView.new(Color(0.15, 0.12, 0.1), Color(0.95, 0.9, 0.8))
			var d2 := DiceView.new()
			dh.add_child(d1)
			dh.add_child(d2)
			mid.add_child(dh)
			var tot := UI.label("", 26, UI.GOLD, UI.f_head, HORIZONTAL_ALIGNMENT_CENTER)
			mid.add_child(tot)
			var rl := UI.label("", 17, UI.PARCH, UI.f_italic, HORIZONTAL_ALIGNMENT_CENTER)
			rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rl.custom_minimum_size.x = 170
			mid.add_child(rl)
			h.add_child(mid)
			war_ui["d1"] = d1
			war_ui["d2"] = d2
			war_ui["tot"] = tot
			war_ui["round"] = rl
		else:
			h.add_child(col)
	var result := UI.label("", 26, Color(1, 0.85, 0.4), UI.f_head, HORIZONTAL_ALIGNMENT_CENTER)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(result)
	war_ui["title"] = title
	war_ui["phase"] = phase
	war_ui["sides"] = sides
	war_ui["result"] = result

func _on_war(w: Dictionary) -> void:
	if w.is_empty():
		var tw := create_tween()
		tw.tween_interval(1.8 * main.settings.ai_speed + 0.4)
		tw.tween_callback(func():
			if g.war.is_empty():
				war_dlg.visible = false
				refresh())
		return
	if tut and not tut_seen.has("war"):
		_tut_tip("war", func(): return war_dlg.get_global_rect().merge(Rect2(0, 0, MAP_W, 1080)) if war_dlg.visible else Rect2(0, 0, MAP_W, 1080))
	if not war_dlg.visible or w.get("phase", "") == "declared":
		if not war_dlg.visible:
			Sfx.play("drum", -6)
		war_ui.result.text = ""
		war_ui.tot.text = ""
		war_ui.round.text = ""
	war_dlg.visible = true
	war_ui.title.text = "%s  contro  %s" % [Data.CITY_NAME[w.att], Data.CITY_NAME[w.def]]
	var phases := {"declared": "Dichiarazione di guerra — si attende un eventuale Veto", "condo_att": "Asta per il Condottiero dell'attaccante", "condo_def": "Asta per il Condottiero del difensore",
		"holy": "Il Papa valuta la Lega Santa", "bribe": "Corruzioni e Maltempo", "battle": "Battaglia!"}
	war_ui.phase.text = phases.get(w.get("phase", ""), "")
	var battle: bool = w.get("phase", "") == "battle"
	war_ui.d1.visible = battle
	war_ui.d2.visible = battle
	for s in ["att", "def"]:
		var ui: Dictionary = war_ui.sides[s]
		var city: String = w[s]
		ui.name.text = "%s (Status %d)" % [Data.CITY_NAME[city], g.status[city]]
		ui.name.add_theme_color_override("font_color", Data.CITY_COLOR[city].lightened(0.45))
		ui.role.text = "ATTACCA" if s == "att" else "DIFENDE"
		ui.role.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4) if s == "att" else Color(0.55, 0.75, 1.0))
		ui.role.add_theme_font_override("font", UI.f_head)
		var pid: int = w.get("ca" if s == "att" else "cd", -1)
		_clear(ui.troops)
		if pid >= 0:
			ui.st.texture = Data.screen_tex(g.players[pid].family)
			ui.condo.text = g.players[pid].name
			for t in g.players[pid].troops:
				var tv := _make_tile(t, Vector2(40, 50))
				tv.dim = g._bribed_in(w, pid, t)
				tv.marked = tv.dim
				ui.troops.add_child(tv)
		else:
			ui.st.texture = null
			ui.condo.text = "—" if w.get("phase", "") in ["declared", "condo_att", "condo_def"] else "Neutrale (valore 3)"
		if w.get("phase", "") in ["holy", "bribe", "battle"]:
			ui.str.text = "Attacco %d · Difesa %d" % [g.side_strength(w, s, "att"), g.side_strength(w, s, "def")]
		else:
			ui.str.text = ""
		var al := ""
		if w.get("ally", -1) >= 0 and w.get("ally_side", "") == s:
			al = "Lega Santa: %s" % g.pname(w.ally)
		var mal: int = w.get("mal_att" if s == "att" else "mal_def", 0)
		if mal > 0:
			al += ("  " if al != "" else "") + "Maltempo -%d" % mal
		ui.ally.text = al
	if w.get("phase", "") in ["holy", "bribe", "battle"] and not w.has("result") and war_ui.result.text == "":
		var od := g.war_odds(w)
		war_ui.round.text = "Probabilità\n%s %d%%\n%s %d%%\nstallo %d%%" % [Data.CITY_NAME[w.att], int(round(od.att * 100)), Data.CITY_NAME[w.def], int(round(od.def * 100)), int(round(od.draw * 100))] if w.get("phase", "") != "battle" else war_ui.round.text
	if w.has("result"):
		var r: Dictionary = w.result
		if r.winner == "":
			war_ui.result.text = "Stallo: nessuno prevale."
		else:
			war_ui.result.text = "%s vince%s!" % [Data.CITY_NAME[w[r.winner]], " in modo schiacciante" if r.decisive else ""]
	map.queue_redraw()

func _on_dice(info: Dictionary) -> void:
	Sfx.play("dice")
	if tut and not tut_seen.has("dice"):
		get_tree().create_timer(1.2).timeout.connect(func(): _tut_tip("dice", func(): return war_dlg.get_global_rect() if war_dlg.visible else Rect2()))
	war_ui.d1.roll_to(info.da)
	war_ui.d2.roll_to(info.dd)
	war_ui.round.text = "%s%s" % [info.label, " (rilancio)" if info.rerolled else ""]
	var w := g.war
	var an: String = Data.CITY_NAME[w[info.a_side]]
	var dn: String = Data.CITY_NAME[w[info.d_side]]
	war_ui.tot.text = ""
	var tw := create_tween()
	tw.tween_interval(0.75)
	tw.tween_callback(func(): war_ui.tot.text = "%d  –  %d" % [info.ta, info.td])
	war_ui.round.text = "%s%s\n%s %d + dado\ncontro\n%s %d + dado" % [info.label, " (rilancio)" if info.rerolled else "", an, info.sa, dn, info.sd]

# ================================================================= menu e fine

func _open_menu() -> void:
	_clear(menu_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_layer.add_child(dim)
	var pnl := UI.panel(Color(0.14, 0.09, 0.05, 0.98), UI.GOLD, 10, 24)
	pnl.position = Vector2(760, 300)
	pnl.custom_minimum_size = Vector2(400, 10)
	menu_layer.add_child(pnl)
	var v := UI.vbox(12)
	pnl.add_child(v)
	v.add_child(UI.head("Menu", 32))
	v.add_child(UI.label("Velocità dell'IA", 18, UI.PARCH))
	var sp := OptionButton.new()
	var speeds := [["Lenta", 1.8], ["Normale", 1.0], ["Rapida", 0.45], ["Istantanea", 0.05]]
	for s in speeds:
		sp.add_item(s[0])
	var cur_i := 1
	for i in speeds.size():
		if absf(speeds[i][1] - main.settings.ai_speed) < 0.01:
			cur_i = i
	sp.selected = cur_i
	sp.item_selected.connect(func(i):
		main.settings.ai_speed = speeds[i][1]
		g.ai_delay = 0.55 * speeds[i][1]
		main.save_settings())
	v.add_child(sp)
	var snd := CheckButton.new()
	snd.text = "Effetti sonori"
	snd.button_pressed = main.settings.sfx
	snd.toggled.connect(func(on):
		main.settings.sfx = on
		main.save_settings())
	v.add_child(snd)
	v.add_child(UI.button("Riprendi", func():
		for c in menu_layer.get_children():
			c.queue_free()))
	var sv := UI.button("Salva partita", func():
		if main.save_game(g.to_dict()):
			_toast("Partita salvata.")
		for c in menu_layer.get_children():
			c.queue_free())
	sv.disabled = cur.get("kind", "") != "turn"
	sv.tooltip_text = "Si può salvare all'inizio del tuo turno"
	v.add_child(sv)
	v.add_child(UI.button("Regole del gioco", _show_rules_overlay))
	v.add_child(UI.button("Ricomincia (stessa configurazione)", func(): main.start_game(cfg)))
	v.add_child(UI.button("Abbandona e torna al menu", func(): main.show_menu()))

func _toast(t: String) -> void:
	var l := UI.label(t, 26, UI.GOLD, UI.f_head, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 560
	var p := UI.panel(Color(0.1, 0.06, 0.03, 0.95), UI.GOLD)
	p.add_child(l)
	p.position = Vector2(CX + CW / 2 - 300, 560)
	p.custom_minimum_size = Vector2(600, 70)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_layer.add_child(p)
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)

func _show_rules_overlay() -> void:
	_clear(menu_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_layer.add_child(dim)
	var pnl := UI.parchment_panel(26)
	pnl.position = Vector2(300, 40)
	pnl.size = Vector2(1320, 940)
	menu_layer.add_child(pnl)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.text = RulesScreen.RULES
	rt.add_theme_color_override("default_color", UI.INK)
	rt.add_theme_font_size_override("normal_font_size", 21)
	rt.add_theme_font_size_override("bold_font_size", 21)
	rt.add_theme_font_override("bold_font", UI.f_bold)
	pnl.add_child(rt)
	var close_cb := func():
		_clear(menu_layer)
	var b := UI.button("Chiudi", close_cb, 200)
	b.position = Vector2(860, 995)
	menu_layer.add_child(b)

func _on_game_over(res: Array) -> void:
	if main.has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(main.SAVE_PATH))
	Sfx.play("bell")
	await get_tree().create_timer(1.0).timeout
	_show_results(res)

const RES_COLS := [["", 46], ["Famiglia", 230], ["MIL", 128], ["VEN", 128], ["FIR", 128], ["ROM", 128], ["NAP", 128],
	["Artisti", 176], ["Mercanti", 104], ["Papa", 84], ["Oro", 100], ["Influenza", 108], ["Vittorie", 100], ["Totale", 104]]

func _show_results(res: Array) -> void:
	_clear(menu_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_layer.add_child(dim)
	var pnl := UI.parchment_panel(26)
	pnl.position = Vector2(36, 24)
	pnl.custom_minimum_size = Vector2(1848, 10)
	menu_layer.add_child(pnl)
	var v := UI.vbox(10)
	pnl.add_child(v)
	var red := Color(0.45, 0.08, 0.08)
	var winner: Dictionary = res[0]
	# --- intestazione: vincitore e classifica delle città
	var top := UI.hbox(22)
	v.add_child(top)
	var wst := UI.tex_rect(Data.screen_tex(winner.family), Vector2(84, 184))
	top.add_child(wst)
	var tv := UI.vbox(4)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tv)
	tv.add_child(UI.label("Fine della partita", 52, red, UI.f_title))
	var tied: Array = res.filter(func(r): return r.total == winner.total)
	var msg := ""
	if tied.size() > 1:
		msg = "Parità al vertice con %d Punti Vittoria: %s!" % [winner.total, ", ".join(tied.map(func(r): return r.name))]
	elif not g.players[winner.pid].is_ai:
		msg = "%s, hai dominato l'Italia con %d Punti Vittoria!" % [winner.name, winner.total]
	else:
		msg = "%s domina l'Italia con %d Punti Vittoria." % [winner.name, winner.total]
	var t2 := UI.label(msg, 28, UI.INK, UI.f_head)
	t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t2.custom_minimum_size.x = 820
	tv.add_child(t2)
	tv.add_child(UI.label("«Il fine giustifica i mezzi» — e Machiavelli prende appunti.", 21, Color(0.35, 0.25, 0.15), UI.f_italic))
	# classifica finale delle città
	var cbox := UI.vbox(4)
	top.add_child(cbox)
	cbox.add_child(UI.label("Classifica finale delle città", 20, red, UI.f_head))
	var crow := UI.hbox(8)
	cbox.add_child(crow)
	var order: Array = g.final_order if not g.final_order.is_empty() else Data.CITIES
	var k := 1
	for c in order:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UI.sb(Data.CITY_COLOR[c].darkened(0.3), Data.CITY_COLOR[c].lightened(0.35), 2, 8, 6))
		chip.custom_minimum_size = Vector2(122, 128)
		var cv := UI.vbox(0)
		chip.add_child(cv)
		cv.add_child(UI.label("%d°" % k, 16, Color(1, 0.9, 0.65), UI.f_head, HORIZONTAL_ALIGNMENT_CENTER))
		cv.add_child(UI.label(Data.CITY_NAME[c], 19, Color(1, 0.96, 0.88), UI.f_head, HORIZONTAL_ALIGNMENT_CENTER))
		cv.add_child(UI.label("Status %d" % g.status[c], 15, Color(1, 0.9, 0.7), UI.f_body, HORIZONTAL_ALIGNMENT_CENTER))
		cv.add_child(UI.label("%d PV" % int(g.final_ranking.get(c, 0)), 30, UI.GOLD, UI.f_title, HORIZONTAL_ALIGNMENT_CENTER))
		cv.add_child(UI.label("per tessera", 13, Color(1, 0.9, 0.7), UI.f_italic, HORIZONTAL_ALIGNMENT_CENTER))
		crow.add_child(chip)
		k += 1
	var line := ColorRect.new()
	line.color = Color(0.6, 0.45, 0.2, 0.6)
	line.custom_minimum_size.y = 2
	v.add_child(line)
	# --- tabella
	var hdr := UI.hbox(6)
	v.add_child(hdr)
	for col in RES_COLS:
		var hc := PanelContainer.new()
		hc.custom_minimum_size = Vector2(col[1], 40)
		var cname: String = col[0]
		if cname in Data.CITIES:
			hc.add_theme_stylebox_override("panel", UI.sb(Data.CITY_COLOR[cname].darkened(0.3), Data.CITY_COLOR[cname].lightened(0.3), 1, 6, 2))
			var hl := UI.label("%s · %d" % [Data.CITY_NAME[cname], int(g.final_ranking.get(cname, 0))], 16, Color(1, 0.96, 0.88), UI.f_head, HORIZONTAL_ALIGNMENT_CENTER)
			hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			hl.tooltip_text = "%s vale %d PV per ogni tessera" % [Data.CITY_NAME[cname], int(g.final_ranking.get(cname, 0))]
			hl.mouse_filter = Control.MOUSE_FILTER_PASS
			hc.add_child(hl)
		else:
			hc.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			var hl2 := UI.label(cname, 18, red, UI.f_head, HORIZONTAL_ALIGNMENT_CENTER)
			hl2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			hc.add_child(hl2)
		hdr.add_child(hc)
	var pos := 1
	var prev_total := -1
	var shown_pos := 1
	for r in res:
		if r.total != prev_total:
			shown_pos = pos
		prev_total = r.total
		v.add_child(_result_row(r, shown_pos, r.total == winner.total))
		pos += 1
	var legend := UI.label("Città: tessere possedute × PV della città nella classifica dello Status · Mercanti: carte «Mercante di Vini» × tessere Mercante · Oro: 6 PV al più ricco, 3 al secondo · Influenza: 4 PV a chi ne ha di più · Vittorie: 1, 3, 6, 10, 15… PV", 16, Color(0.4, 0.3, 0.18), UI.f_italic)
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.custom_minimum_size.x = 1780
	v.add_child(legend)
	var bh := UI.hbox(20)
	bh.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(bh)
	bh.add_child(UI.button("Guarda il tavolo", func():
		_clear(menu_layer)
		var back := UI.button("Risultati", func(): _show_results(res))
		back.position = Vector2(CX + CW - 160, 930)
		menu_layer.add_child(back)))
	bh.add_child(UI.button("Rivincita", func():
		var c2: Dictionary = cfg.duplicate(true)
		if c2.get("tutorial", false):
			c2.erase("tutorial")
			c2.erase("seed")
		main.start_game(c2)))
	bh.add_child(UI.button("Menu principale", func(): main.show_menu()))
	# entrata in scena e adattamento all'altezza dello schermo
	pnl.modulate.a = 0.0
	await get_tree().process_frame
	if not is_instance_valid(pnl):
		return
	pnl.reset_size()
	var h: float = pnl.get_combined_minimum_size().y
	if h > 1040:
		pnl.scale = Vector2.ONE * (1040.0 / h)
	pnl.position = Vector2((1920 - 1848 * pnl.scale.x) / 2.0, max(12.0, (1080 - h * pnl.scale.y) / 2.0))
	var tw := create_tween()
	tw.tween_property(pnl, "modulate:a", 1.0, 0.35)

func _result_row(r: Dictionary, pos: int, win: bool) -> PanelContainer:
	var p = g.players[r.pid]
	var row := PanelContainer.new()
	var bg := Color(0.95, 0.83, 0.5, 0.55) if win else Color(0.55, 0.42, 0.25, 0.10 if pos % 2 == 0 else 0.18)
	row.add_theme_stylebox_override("panel", UI.sb(bg, p.color.darkened(0.25) if not p.is_ai else Color(0, 0, 0, 0), 2 if not p.is_ai else 0, 8, 4))
	var h := UI.hbox(6)
	row.add_child(h)
	var ink := UI.INK
	var faint := Color(0.5, 0.42, 0.32, 0.6)
	var cells: Array = []
	for col in RES_COLS:
		var c := UI.vbox(0)
		c.custom_minimum_size = Vector2(col[1], 74)
		c.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(c)
		cells.append(c)
	# posizione e famiglia
	cells[0].add_child(UI.label("%d°" % pos, 28 if pos == 1 else 24, Color(0.45, 0.08, 0.08), UI.f_title, HORIZONTAL_ALIGNMENT_CENTER))
	var fh := UI.hbox(8)
	fh.add_child(UI.tex_rect(Data.screen_tex(p.family), Vector2(30, 66)))
	var fv := UI.vbox(0)
	fv.alignment = BoxContainer.ALIGNMENT_CENTER
	var nl := UI.label(r.name, 20, ink, UI.f_head)
	nl.clip_text = true
	nl.custom_minimum_size.x = 186
	fv.add_child(nl)
	var sub := "%s · lato %s" % [Data.FAMILIES[p.family].name, p.side]
	if p.is_ai:
		sub += " · IA " + ["Facile", "Normale", "Machiavelli"][p.level]
	fv.add_child(UI.label(sub, 13, Color(0.4, 0.3, 0.18), UI.f_italic))
	fh.add_child(fv)
	cells[1].add_child(fh)
	# città
	var i := 2
	for c in Data.CITIES:
		var bc: Dictionary = r.get("by_city", {}).get(c, {"tiles": [], "per": 0, "pts": 0})
		var cell: VBoxContainer = cells[i]
		if bc.tiles.is_empty():
			cell.add_child(UI.label("—", 22, faint, UI.f_head, HORIZONTAL_ALIGNMENT_CENTER))
		else:
			cell.add_child(_thumbs(bc.tiles, 128))
			cell.add_child(UI.label("%d × %d = %d" % [bc.tiles.size(), bc.per, bc.pts], 17, ink, UI.f_head, HORIZONTAL_ALIGNMENT_CENTER))
		i += 1
	# artisti (eventi con PV)
	var items: Array = r.get("ev_items", [])
	if items.is_empty():
		cells[7].add_child(UI.label("—", 22, faint, UI.f_head, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		cells[7].add_child(_thumbs(items.map(func(x): return x.id), 176))
		cells[7].add_child(UI.label(" + ".join(items.map(func(x): return str(x.pts))) + (" = %d" % r.events if items.size() > 1 else ""), 17, ink, UI.f_head, HORIZONTAL_ALIGNMENT_CENTER))
	# mercanti
	if r.merchants > 0 or int(r.get("vini", 0)) > 0:
		cells[8].add_child(_thumbs(["EV_vini1"], 104))
		cells[8].add_child(UI.label("%d × %d = %d" % [int(r.get("vini", 0)), int(r.get("merch_tiles", 0)), r.merchants], 16, ink, UI.f_head, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		cells[8].add_child(UI.label("—", 22, faint, UI.f_head, HORIZONTAL_ALIGNMENT_CENTER))
	# papa
	if r.pope > 0:
		cells[9].add_child(_thumbs(["POPE"], 84))
		cells[9].add_child(UI.label("3", 18, ink, UI.f_head, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		cells[9].add_child(UI.label("—", 22, faint, UI.f_head, HORIZONTAL_ALIGNMENT_CENTER))
	# oro, influenza, vittorie: gettone con la quantità, sotto i PV
	var specs := [[10, "res://assets/ui/gold.png", int(r.get("gold_left", 0)), r.gold], [11, "res://assets/ui/influence.png", int(r.get("inf_left", 0)), r.inf],
		[12, "res://assets/ui/laurel.png", int(r.get("counters_n", 0)), r.counters]]
	for sp in specs:
		var tk := _token(sp[1], 44, 19, Color(1, 1, 1))
		tk.label.text = str(sp[2])
		var cc := CenterContainer.new()
		cc.add_child(tk.root)
		cells[sp[0]].add_child(cc)
		cells[sp[0]].add_child(UI.label(("%d PV" % sp[3]) if sp[3] > 0 else "—", 17, ink if sp[3] > 0 else faint, UI.f_head, HORIZONTAL_ALIGNMENT_CENTER))
	# totale
	var tot := UI.label(str(r.total), 40 if win else 34, Color(0.45, 0.08, 0.08), UI.f_title, HORIZONTAL_ALIGNMENT_CENTER)
	cells[13].add_child(tot)
	return row

## Miniature di tessere affiancate (si sovrappongono se non c'è spazio)
func _thumbs(ids: Array, w: float) -> Control:
	var tw := 34.0
	var th := 42.0
	var n := ids.size()
	var step: float = tw + 3 if n * (tw + 3) <= w - 6 else (w - 6 - tw) / max(1, n - 1)
	var total: float = tw + step * (n - 1)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(w, th)
	var x0: float = (w - total) / 2.0
	var j := 0
	for id in ids:
		var t := UI.tex_rect(Data.item_tex(id), Vector2(tw, th))
		t.position = Vector2(x0 + j * step, 0)
		t.tooltip_text = Data.item_name(id)
		holder.add_child(t)
		j += 1
	return holder

# ================================================================= tutorial

func _tut_intro() -> void:
	var r := areas.duplicate()
	var me: int = max(viewer, 0)
	var ph: float = areas.ph
	r["mine"] = Rect2(RX, 8 + me * (ph + 6), RW, ph)
	var p = g.players[me]
	var ov := TutorialOverlay.new()
	ov.steps = TutorialOverlay.intro_steps(r, p.family, p.side)
	if cfg.get("autohuman", false):
		ov.auto_advance = float(cfg.get("tut_auto", 1.2))
	add_child(ov)
	await ov.closed

func _tut_decision(kind: String, ctx: Dictionary) -> void:
	var key := ""
	match kind:
		"turn": key = "turn"
		"bid": key = "condo_bid" if str(ctx.get("kind", "")) == "condo" else "bid"
		"condo_bid": key = "condo_bid"
		"veto": key = "veto"
		"bribe": key = "bribe"
		"maltempo": key = "maltempo"
		"holy": key = "holy"
		"reroll": key = "reroll"
		"place_sta": key = "artist"
		"french": key = "french"
		"discard_treach": key = "discard"
		"deal_offer", "deal_counter": key = "deal_offer"
		"deal_pay": key = "deal_pay"
		"moment_offer", "holy_offer", "veto_bounty": key = "moment"
	if key == "":
		return
	var rect = null
	match key:
		"turn":
			rect = Rect2(CX, 70, CW, 1002)
		"bid", "condo_bid":
			rect = func(): return auction_dlg.get_global_rect() if auction_dlg.visible else Rect2()
		"veto", "bribe", "maltempo", "holy", "reroll":
			rect = func(): return war_dlg.get_global_rect() if war_dlg.visible else Rect2()
	_tut_tip(key, rect)

## Mostra un suggerimento (una sola volta per tipo) e sospende il gioco finché non viene chiuso.
func _tut_tip(key: String, rect = null) -> void:
	if not tut or tut_off or tut_seen.has(key) or not TutorialOverlay.TIPS.has(key):
		return
	tut_seen[key] = true
	tut_queue.append([key, rect])
	if tut_open == null:
		_tut_next()

func _tut_next() -> void:
	if tut_queue.is_empty() or tut_off:
		tut_queue.clear()
		tut_open = null
		g.paused = false
		return
	var it: Array = tut_queue.pop_front()
	var tip: Array = TutorialOverlay.TIPS[it[0]]
	g.paused = true
	var ov := TutorialOverlay.new()
	ov.tip_mode = true
	ov.steps = [{"title": tip[0], "text": tip[1], "rect": it[1]}]
	if cfg.get("autohuman", false):
		ov.auto_advance = float(cfg.get("tut_auto", 1.2))
	tut_open = ov
	add_child(ov)
	ov.closed.connect(func(stop: bool):
		if stop:
			tut_off = true
		tut_open = null
		_tut_next())

# ================================================================= verifica (prove automatiche)

var _audit_seen := {}

## Segnala i pulsanti visibili che escono dallo schermo o sono tagliati da un riquadro.
func _audit_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(0.35).timeout
		_audit(self)

func _audit(n: Node) -> void:
	for c in n.get_children():
		if c is CanvasItem and not c.visible:
			continue
		if c is BaseButton and c.is_visible_in_tree():
			var r: Rect2 = c.get_global_rect()
			var bad := ""
			if r.size.x < 1 or r.size.y < 1:
				pass
			elif not Rect2(0, 0, 1920, 1080).grow(1).encloses(r):
				bad = "fuori schermo"
			else:
				var a := c.get_parent()
				while a is Control:
					if a.clip_contents and not (a is ScrollContainer) and not a.get_global_rect().grow(1).encloses(r):
						bad = "tagliato da " + a.name
						break
					if a is ScrollContainer:
						break
					a = a.get_parent()
			if bad != "":
				var key := "%s|%s|%s" % [c.get("text"), bad, str(cur.get("kind", ""))]
				if not _audit_seen.has(key):
					_audit_seen[key] = true
					print("AUDIT %s: '%s' %s (decisione: %s)" % [bad, c.get("text"), str(r), str(cur.get("kind", ""))])
		_audit(c)
