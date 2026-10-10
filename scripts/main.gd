extends Control
## Gestore delle schermate: menu → impostazione → tavolo → fine partita.

var screen: Control
var settings := {"ai_speed": 1.0, "sfx": true, "negotiation": true, "prompt_moments": true, "deals": {}}
var last_setup := {}

func _ready() -> void:
	theme = UI.theme()
	_load_settings()
	var bg := ColorRect.new()
	bg.color = UI.WOOD
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	if args.has("demo"):
		_demo(args)
	else:
		show_menu()

## Modalità di prova (screenshot automatici): -- demo=menu|setup|rules|board shots=1,5,9 human=1
func _demo(args: Dictionary) -> void:
	settings.ai_speed = float(args.get("speed", "0.3"))
	Sfx.enabled = false
	match str(args.demo):
		"setup":
			show_setup()
		"rules":
			show_rules()
		"deals":
			show_deals()
		"tutorial":
			show_tutorial(args.get("auto", "1") == "1")
		"continue":
			continue_game()
		"dialogs":
			var ps2 := []
			var fams2: Array = ["montefeltro", "este", "gonzaga", "baglioni"]
			for i in 4:
				ps2.append({"name": ("Giocatore" if i == 0 else "Casa " + Data.FAMILIES[fams2[i]].name), "family": fams2[i], "side": "A", "ai": i != 0, "level": 2})
			start_game({"players": ps2, "seed": 3})
			await get_tree().create_timer(2.0).timeout
			var b: BoardScreen = screen
			var w := {"att": "VEN", "def": "MIL", "ca": 1, "cd": 2, "ally": -1, "ally_side": "", "bribed": [], "mal_att": 0, "mal_def": 0, "phase": "bribe", "starter": 1}
			b.g.players[1].troops = ["cavalleria", "campo"]
			b.g.players[2].troops = ["picchieri", "artiglieria"]
			b.g.war = w
			b._on_war(w)
			var kinds := [
				["bribe", {"war": w, "targets": [[1, "cavalleria"], [1, "campo"], [2, "picchieri"], [2, "artiglieria"]]}],
				["veto", {"att": "VEN", "def": "MIL", "sources": ["card", "lorenzo"], "starter": 1}],
				["keep_treach", {"cards": ["congela", "veto"]}],
				["place_sta", {"item": "EV_botticelli"}],
				["deal_offer", {"deal": {"type": "abstain", "from": 2, "to": 0, "pay_cur": "gold", "pay_amt": 4, "timing": "after", "kind": "city", "item": "VEN_doge"}, "reputation": 1.0}],
				["holy_offer", {"war": w, "side": "att", "pope": 3}],
				["deal_pay", {"deal": {"type": "abstain"}, "to": 1, "cur": "gold", "amount": 3}],
				["moment_offer", {"kind": "artist_req", "to": 1, "item": "EV_botticelli"}],
				["turnform", {}],
			]
			var dir2: String = args.get("dir", "user://")
			var k2 := 0
			for kd in kinds:
				if kd[0] == "turnform":
					b.cur = {"pid": 0, "kind": "turn", "ctx": {}}
					b._deal_form({"title": "Proponi un accordo", "types": GameEngine.TURN_TYPES, "text": "Prova del modulo."}, func(_d): pass)
					var dfs := b.choice_layer.get_children()
					await get_tree().create_timer(0.3).timeout
					for c in b.choice_layer.get_children():
						if c is DealForm:
							c.type_sel.selected = 2
							c._rebuild()
				else:
					b._on_decision(0, kd[0], kd[1])
				await get_tree().create_timer(1.0).timeout
				get_viewport().get_texture().get_image().save_png("%s/dlg_%d.png" % [dir2, k2])
				print("dialogo ", kd[0])
				b._audit(b)
				k2 += 1
				b._close_choice()
			get_tree().quit()
			return
		"board":
			var fams: Array = ["montefeltro", "este", "gonzaga", "baglioni"]
			var ps := []
			for i in 4:
				ps.append({"name": ("Giocatore" if i == 0 else "Casa " + Data.FAMILIES[fams[i]].name), "family": fams[i], "side": "A", "ai": not (i == 0 and args.get("human", "1") == "1"), "level": 2})
			start_game({"players": ps, "seed": int(args.get("seed", "7")), "autohuman": args.get("auto", "0") == "1", "autohuman_delay": float(args.get("adelay", "0.8"))})
		_:
			show_menu()
	get_viewport().warp_mouse(Vector2(1910, 1075))
	var dir: String = args.get("dir", "user://")
	if args.has("end") and screen is BoardScreen:
		await get_tree().process_frame
		await get_tree().process_frame
		await screen.g.game_over
		await get_tree().create_timer(3.0).timeout
		get_viewport().get_texture().get_image().save_png("%s/shot_end.png" % dir)
		get_tree().quit()
		return
	var times: Array = str(args.get("shots", "2")).split(",")
	var last := 0.0
	var k := 0
	for t in times:
		await get_tree().create_timer(float(t) - last).timeout
		last = float(t)
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/shot_%s_%d.png" % [dir, args.demo, k])
		k += 1
	get_tree().quit()

func _swap(c: Control) -> void:
	if screen:
		screen.queue_free()
	screen = c
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	c.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.45)

func show_menu() -> void:
	var m := MenuScreen.new()
	m.main = self
	_swap(m)

func show_setup() -> void:
	var s := SetupScreen.new()
	s.main = self
	_swap(s)

func show_deals() -> void:
	var d := DealsScreen.new()
	d.main = self
	_swap(d)

func show_rules() -> void:
	var r := RulesScreen.new()
	r.main = self
	_swap(r)

## Tutorial: partita guidata con la famiglia Montefeltro contro tre IA Facili
func show_tutorial(auto := false) -> void:
	var ps := [{"name": "Giocatore", "family": "montefeltro", "side": "A", "ai": false, "level": 1}]
	for f in ["gonzaga", "este", "baglioni"]:
		ps.append({"name": "Casa " + Data.FAMILIES[f].name, "family": f, "side": "A", "ai": true, "level": 0})
	var cfg := {"players": ps, "tutorial": true, "seed": 1470}
	if auto:
		cfg["autohuman"] = true
		cfg["autohuman_delay"] = 0.8
	start_game(cfg, false)

func start_game(cfg: Dictionary, remember := true) -> void:
	if not cfg.has("deals"):
		cfg["deals"] = settings.deals.duplicate()
	if not cfg.has("negotiation"):
		cfg["negotiation"] = settings.negotiation
	if remember:
		last_setup = cfg.duplicate(true)
		for k in ["load", "autohuman", "autohuman_delay", "seed", "tutorial"]:
			last_setup.erase(k)
	var b := BoardScreen.new()
	b.main = self
	b.cfg = cfg
	_swap(b)

const SAVE_PATH := "user://salvataggio.json"

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game(d: Dictionary) -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	return true

func continue_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	var cfg: Dictionary = d.cfg
	for pc in cfg.players:
		pc.level = int(pc.get("level", 1))
	cfg["load"] = d
	start_game(cfg)

func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		settings.ai_speed = cf.get_value("opt", "ai_speed", 1.0)
		settings.sfx = cf.get_value("opt", "sfx", true)
		settings.negotiation = cf.get_value("opt", "negotiation", true)
		settings.prompt_moments = cf.get_value("opt", "prompt_moments", true)
		settings.deals = cf.get_value("opt", "deals", {})
		last_setup = cf.get_value("opt", "last_setup", {})
	Sfx.enabled = settings.sfx

func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("opt", "ai_speed", settings.ai_speed)
	cf.set_value("opt", "sfx", settings.sfx)
	cf.set_value("opt", "negotiation", settings.negotiation)
	cf.set_value("opt", "prompt_moments", settings.prompt_moments)
	cf.set_value("opt", "deals", settings.deals)
	cf.set_value("opt", "last_setup", last_setup)
	cf.save("user://settings.cfg")
	Sfx.enabled = settings.sfx
