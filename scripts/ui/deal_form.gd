class_name DealForm
extends PanelContainer
## Modulo generico per comporre una proposta d'accordo (tutti i tipi).
## spec: {title, text, types: [..], ctx: {...}, cancel, allow_mute}
## Emette done(result): un Dictionary con i campi dell'accordo (pronto per il motore) oppure null.

signal done(result)

var g: GameEngine
var me := 0
var spec := {}
var type_sel: OptionButton
var fields_box: VBoxContainer
var desc_label: Label
var err: Label
var mute_cb: CheckBox
var w := {}            # widget dei campi
var types: Array = []

func setup(engine: GameEngine, pid: int, s: Dictionary) -> DealForm:
	g = engine
	me = pid
	spec = s
	types = s.get("types", [])
	return self

func _ready() -> void:
	add_theme_stylebox_override("panel", UI.sb(Color(0.14, 0.09, 0.05, 0.98), Color(1.0, 0.8, 0.4), 3, 10, 18))
	custom_minimum_size = Vector2(680, 10)
	var v := UI.vbox(10)
	add_child(v)
	v.add_child(UI.head(spec.get("title", "Proponi un accordo"), 26))
	if spec.get("text", "") != "":
		var t := UI.label(spec.text, 18, UI.PARCH)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size.x = 640
		v.add_child(t)
	if types.size() > 1:
		var row := UI.hbox(8)
		row.add_child(UI.label("Accordo:", 19, UI.GOLD))
		type_sel = OptionButton.new()
		for tp in types:
			type_sel.add_item(Data.DEAL_INFO[tp].name)
		type_sel.custom_minimum_size.x = 420
		type_sel.item_selected.connect(func(_i): _rebuild())
		row.add_child(type_sel)
		v.add_child(row)
	desc_label = UI.label("", 16, Color(0.85, 0.78, 0.62), UI.f_italic)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size.x = 640
	v.add_child(desc_label)
	fields_box = UI.vbox(8)
	v.add_child(fields_box)
	err = UI.label("", 17, Color(1, 0.5, 0.4))
	v.add_child(err)
	if spec.get("allow_mute", false):
		mute_cb = CheckBox.new()
		mute_cb.text = "Non chiedermelo più in questa partita"
		v.add_child(mute_cb)
	var row3 := UI.hbox(10)
	v.add_child(row3)
	row3.add_child(UI.button("Proponi", _on_ok, 170))
	row3.add_child(UI.button(spec.get("cancel", "Annulla"), func(): _finish(null), 220))
	_rebuild()

func cur_type() -> String:
	if types.is_empty():
		return ""
	if type_sel:
		return types[type_sel.selected]
	return types[0]

func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

# ---------------------------------------------------------------- widget

func _row(label: String) -> HBoxContainer:
	var r := UI.hbox(8)
	var l := UI.label(label, 18, UI.GOLD)
	l.custom_minimum_size.x = 170
	r.add_child(l)
	fields_box.add_child(r)
	return r

func _opt(label: String, items: Array, key: String, sel := 0) -> OptionButton:
	var r := _row(label)
	var ob := OptionButton.new()
	for it in items:
		ob.add_item(str(it[0]))
	ob.selected = clampi(sel, 0, max(0, items.size() - 1))
	ob.custom_minimum_size.x = 380
	r.add_child(ob)
	w[key] = {"node": ob, "items": items}
	return ob

func _amount(label: String, key: String, def_amt: int, minv := 1, cur_key := "", cur_def := "gold") -> void:
	var r := _row(label)
	var sp := SpinBox.new()
	sp.min_value = minv
	sp.max_value = 80
	sp.value = def_amt
	sp.custom_minimum_size.x = 110
	r.add_child(sp)
	w[key] = {"node": sp}
	if cur_key != "":
		var ob := OptionButton.new()
		ob.add_item("Oro")
		ob.add_item("Influenza")
		ob.selected = 0 if cur_def == "gold" else 1
		r.add_child(ob)
		w[cur_key] = {"node": ob, "items": [["Oro", "gold"], ["Influenza", "inf"]]}
	else:
		r.add_child(UI.label("Oro", 18, UI.PARCH))

func _val(key: String):
	var e: Dictionary = w.get(key, {})
	if e.is_empty():
		return null
	var n = e.node
	if n is SpinBox:
		return int(n.value)
	if n is OptionButton:
		if n.item_count == 0:
			return null
		return e.items[n.selected][1]
	return null

func _partners(exclude: Array) -> Array:
	var out: Array = []
	for p in g.players:
		if p.id != me and not p.id in exclude:
			out.append(["%s (%d Oro, %d Inf. · %s)" % [p.name, p.gold, p.inf, g.reputation_txt(p.id)], p.id])
	return out

func _cities(excl := "") -> Array:
	var out: Array = []
	for c in Data.CITIES:
		if c != excl:
			out.append(["%s (Status %d)" % [Data.CITY_NAME[c], g.status[c]], c])
	return out

func _pay_fields(minv := 1, def_amt := 3) -> void:
	_amount("Pago:", "pay_amt", def_amt, minv, "pay_cur")
	_opt("Pagamento:", [["A cose fatte", "after"], ["Subito (più convincente)", "now"]], "timing")

# ---------------------------------------------------------------- campi per tipo

func _rebuild() -> void:
	_clear(fields_box)
	w.clear()
	err.text = ""
	var tp := cur_type()
	if tp == "":
		return
	desc_label.text = Data.DEAL_INFO[tp].desc
	var ctx: Dictionary = spec.get("ctx", {})
	match tp:
		"exchange":
			_opt("Con:", _partners([]), "to")
			_amount("Do:", "give_amt", 4, 1, "give_cur", "gold")
			_amount("Chiedo:", "get_amt", 3, 1, "get_cur", "inf")
		"loan":
			_opt("Con:", _partners([]), "to")
			_opt("Tipo:", [["Chiedo un prestito", "borrow"], ["Offro un prestito", "lend"]], "mode")
			_amount("Importo (Oro):", "amount", 8)
			_amount("Da restituire:", "repay", 10)
		"war_req":
			_opt("A chi:", _partners([]), "to")
			_opt("Città che attacca:", _cities(), "att")
			_opt("Città che difende:", _cities(), "def", 1)
			_pay_fields()
		"no_attack":
			_opt("A chi:", _partners([]), "to")
			var mine := 0
			for i in Data.CITIES.size():
				var n := 0
				for t in g.players[me].cities:
					if Data.city_tile(t).city == Data.CITIES[i]:
						n += 1
				if n > 0:
					mine = i
			_opt("Città da non attaccare:", _cities(), "city", mine)
			_pay_fields(1, 2)
		"auction_req":
			_opt("A chi:", _partners([]), "to")
			var items: Array = []
			for e in g.event_pool:
				items.append([Data.item_name(e), e])
			if g.pope_available:
				items.append(["Il Papa", "POPE"])
			for t in g.city_pool:
				items.append([Data.item_name(t), t])
			_opt("Tessera:", items, "item")
			_pay_fields(1, 2)
		"no_close":
			_opt("A chi:", _partners([]), "to")
			_pay_fields(1, 2)
		"city_pact":
			_opt("Con:", _partners([]), "to")
			_opt("Città:", _cities(), "city")
			_pay_fields(0, 0)
		"protection":
			_opt("A chi:", _partners([]), "to")
			_pay_fields(1, 2)
		"abstain":
			_opt("A chi:", _list_ids(ctx.get("targets", [])), "to")
			_pay_fields()
		"freeze_req":
			_opt("Chi congela:", _list_ids(ctx.get("targets", [])), "to")
			_opt("Chi va congelato:", _list_ids(ctx.get("targets", [])), "victim", 1)
			_pay_fields()
		"condo_split":
			_opt("Con:", _list_ids(ctx.get("targets", [])), "to")
			_pay_fields(0, 0)
		"card_req":
			var wr: Dictionary = ctx.get("war", {})
			var holders: Array = []
			for h in ctx.get("holders", []):
				if h >= 0 and h != me:
					holders.append(h)
			var opts: Array = []
			for h in holders:
				for vv in [wr.get("ca", -1), wr.get("cd", -1)]:
					if vv >= 0 and vv != h and not g.players[vv].troops.is_empty():
						opts.append(["%s corrompa una Truppa di %s" % [g.pname(h), g.pname(vv)], ["corrompi_truppe", h, vv]])
			for q in g.players:
				if q.id != me and not q.treach.is_empty():
					for side in ["att", "def"]:
						opts.append(["%s giochi Maltempo contro %s" % [q.name, Data.CITY_NAME[wr[side]]], ["maltempo", q.id, wr[side]]])
			_opt("Richiesta:", opts, "card")
			_pay_fields()
		"reroll_req", "artist_req", "french_req", "ties_req", "holy":
			var to: int = int(ctx.get("to", -1))
			var r := _row("A:")
			r.add_child(UI.label(g.pname(to) + " (" + g.reputation_txt(to) + ")", 18, UI.PARCH))
			if tp == "artist_req":
				_opt("Città:", _cities(), "city")
			elif tp == "french_req":
				var fc := _cities()
				fc.append(["Scartare l'Invasione", ""])
				_opt("Città da colpire:", fc, "city")
			elif tp == "ties_req":
				var tc: Array = []
				for c in ctx.get("tied", []):
					tc.append([Data.CITY_NAME[c], c])
				_opt("Città che vince lo spareggio:", tc, "city")
			_pay_fields(1, 3)
		"veto_bounty":
			_amount("Taglia:", "amount", 3, 1, "cur")

func _list_ids(ids: Array) -> Array:
	var out: Array = []
	for q in ids:
		out.append(["%s (%s)" % [g.pname(q), g.reputation_txt(q)], q])
	return out

# ---------------------------------------------------------------- conferma

func _on_ok() -> void:
	var tp := cur_type()
	var d := {"type": tp}
	for k in w:
		d[k] = _val(k)
	var ctx: Dictionary = spec.get("ctx", {})
	var p = g.players[me]
	if d.has("to") and d.to == null:
		err.text = "Nessun giocatore disponibile."
		return
	match tp:
		"exchange":
			if d.give_cur == d.get_cur:
				err.text = "Scambia valute diverse."
				return
			if (p.gold if d.give_cur == "gold" else p.inf) < d.give_amt:
				err.text = "Non hai abbastanza %s." % Data.cur_name(d.give_cur)
				return
		"loan":
			if d.repay < d.amount:
				err.text = "La restituzione deve essere almeno pari all'importo."
				return
			if d.mode == "lend":
				d["lender"] = me
				d["borrower"] = d.to
				if p.gold < d.amount:
					err.text = "Non hai abbastanza Oro."
					return
			else:
				d["lender"] = d.to
				d["borrower"] = me
			d.erase("mode")
		"war_req":
			if d.att == d.def:
				err.text = "Scegli due città diverse."
				return
		"freeze_req":
			if d.to == d.victim:
				err.text = "Chi congela e chi viene congelato devono essere diversi."
				return
		"card_req":
			if d.card == null:
				err.text = "Nessuna richiesta possibile."
				return
			var c: Array = d.card
			d["card"] = c[0]
			d["to"] = c[1]
			if c[0] == "maltempo":
				d["city"] = c[2]
			else:
				d["victim"] = c[2]
		"veto_bounty":
			if (p.gold if d.cur == "gold" else p.inf) < d.amount:
				err.text = "Non hai abbastanza %s." % Data.cur_name(d.cur)
				return
	if ctx.has("to") and not d.has("to"):
		d["to"] = ctx.to
	if d.has("pay_amt") and d.pay_amt > 0 and (p.gold if d.pay_cur == "gold" else p.inf) < d.pay_amt:
		err.text = "Non hai abbastanza %s." % Data.cur_name(d.pay_cur)
		return
	_finish(d)

func _finish(r) -> void:
	if mute_cb and mute_cb.button_pressed:
		if r == null:
			r = {"_mute": true, "_null": true}
		else:
			r["_mute"] = true
	done.emit(r)
