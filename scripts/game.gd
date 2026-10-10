class_name GameEngine
extends Node
## Motore delle regole di Principi del Rinascimento.
## Il flusso di gioco è una coroutine: ogni decisione passa da ask(), che per l'IA
## risponde subito (con un piccolo ritardo scenico) e per l'umano attende la GUI.

signal log_msg(text: String, kind: String)
signal changed
signal decision_requested(pid: int, kind: String, ctx: Dictionary)
signal decision_made(result)
signal game_over(results: Array)
signal dice_rolled(info: Dictionary)
signal war_changed(info: Dictionary)
signal auction_changed(info: Dictionary)
signal decade_started(decade: int)
signal deal_event(text: String, kind: String)

var players: Array = []
var status := {}
var artists := {}          # città -> numero di Artisti "+1" assegnati
var sta_tiles := {}        # città -> [id eventi +1]
var city_pool: Array = []
var troop_pool := {}
var event_pool: Array = []
var events_by_decade := {1: [], 2: [], 3: []}
var removed_events: Array = []
var pope_available := true
var pope_holder := -1
var wars_fought := 0
var war_limit := 4
var decade := 1
var current := 0
var deck: Array = []
var discards: Array = []
var war := {}
var auction := {}
var pending := {}
var ai_delay := 0.55
var final_order: Array = []
var final_ranking := {}
var paused := false   # il tutorial sospende il gioco mentre mostra un suggerimento
var rng := RandomNumberGenerator.new()
var consecutive_passes := 0
var finished := false
var decade_over := false
var results: Array = []
var auction_history: Array = []
var turn_number := 0
var last_actor := 0
var headless := false
var action_stats := {}   # pid -> {tipo: n}
# --- trattative
var negotiation := true
var deals: Array = []          # patti attivi (non vincolanti)
var reputation := {}           # pid -> fiducia 0..1
var deal_seq := 0
var auction_seq := 0
var war_seq := 0
var bounties: Array = []       # taglie sul Veto della guerra in corso
var deal_stats := {"proposed": 0, "accepted": 0, "kept": 0, "broken": 0, "welched": 0}
var deals_cfg := {}            # tipo di accordo -> attivo
var reroll_seq := 0
var turn_log := {}

# ------------------------------------------------------------------ setup

## cfg: {"players":[{"name","family","side","ai":bool,"level":0..2}], "seed":int}
var cfg_used := {}

func setup(cfg: Dictionary) -> void:
	cfg_used = cfg.duplicate(true)
	if cfg.has("seed"):
		rng.seed = int(cfg.seed)
	else:
		rng.randomize()
	players.clear()
	var i := 0
	for pc in cfg.players:
		var p := {
			"id": i, "name": pc.name, "family": pc.family, "side": pc.get("side", "A"),
			"is_ai": pc.ai, "level": pc.get("level", 1), "ai": null,
			"gold": Data.START_GOLD, "inf": Data.START_INF,
			"cities": [], "troops": [], "events": [], "treach": [],
			"vp_counters": 0, "home_gold": 0, "used": {}, "baglioni_cur": "gold",
			"passed": false, "color": Data.FAMILIES[pc.family].color,
		}
		players.append(p)
		i += 1
	for p in players:
		if p.is_ai:
			var b := AIBrain.new()
			b.setup(self, p.id, p.level, rng.randi(), cfg.players[p.id].get("ai_prm", {}))
			p.ai = b
	for c in Data.CITIES:
		status[c] = Data.CITY_START[c]
		artists[c] = 0
		sta_tiles[c] = []
	city_pool.clear()
	for t in Data.CITY_TILES:
		city_pool.append(t.id)
	troop_pool.clear()
	for k in Data.TROOPS:
		troop_pool[k] = Data.TROOPS[k].count
	for d in [1, 2, 3]:
		events_by_decade[d] = []
	for e in Data.EVENTS:
		events_by_decade[e.dec].append(e.id)
	deck.clear()
	for k in Data.TREACHERY:
		for n in Data.TREACHERY[k].count:
			deck.append(k)
	_shuffle(deck)
	war_limit = 5 if players.size() >= 5 else 4
	current = rng.randi_range(0, players.size() - 1)
	negotiation = cfg.get("negotiation", true)
	deals_cfg = cfg.get("deals", {})
	for p in players:
		reputation[p.id] = 1.0

func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

func say(text: String, kind := "info") -> void:
	log_msg.emit(text, kind)

func pname(pid: int) -> String:
	if pid < 0:
		return "Neutrale"
	return players[pid].name

# ------------------------------------------------------------------ decisioni

func hold() -> void:
	while paused and is_inside_tree():
		await get_tree().process_frame

func ask(pid: int, kind: String, ctx: Dictionary):
	await hold()
	var p = players[pid]
	if p.is_ai:
		if ai_delay > 0.0 and is_inside_tree():
			var mult := 1.0
			if kind in ["bid", "condo_bid"]:
				mult = 0.8
			elif kind == "turn":
				mult = 1.4
			await get_tree().create_timer(ai_delay * mult).timeout
		return p.ai.decide(kind, ctx)
	pending = {"pid": pid, "kind": kind, "ctx": ctx}
	decision_requested.emit(pid, kind, ctx)
	var r = await decision_made
	pending = {}
	return r

func submit(result) -> void:
	decision_made.emit(result)

# ------------------------------------------------------------------ salvataggio

func to_dict() -> Dictionary:
	var ps: Array = []
	for p in players:
		var q := {}
		for k in p:
			if k == "ai" or k == "color":
				continue
			q[k] = p[k]
		ps.append(q)
	return {"version": 1, "cfg": cfg_used, "players": ps, "status": status, "artists": artists, "sta_tiles": sta_tiles,
		"city_pool": city_pool, "troop_pool": troop_pool, "event_pool": event_pool,
		"events_by_decade": {"1": events_by_decade[1], "2": events_by_decade[2], "3": events_by_decade[3]},
		"removed_events": removed_events, "pope_available": pope_available, "pope_holder": pope_holder,
		"wars_fought": wars_fought, "war_limit": war_limit, "decade": decade, "current": current,
		"deck": deck, "discards": discards, "consecutive_passes": consecutive_passes, "turn_number": turn_number,
		"last_actor": last_actor, "auction_history": auction_history, "reputation": reputation, "deals": deals, "deal_seq": deal_seq}

func load_dict(d: Dictionary) -> void:
	for i in players.size():
		var src: Dictionary = d.players[i]
		var p = players[i]
		for k in src:
			var v = src[k]
			if typeof(v) == TYPE_FLOAT and k in ["id", "level", "gold", "inf", "vp_counters", "home_gold"]:
				v = int(v)
			p[k] = v
	for c in Data.CITIES:
		status[c] = int(d.status[c])
		artists[c] = int(d.artists[c])
		sta_tiles[c] = d.sta_tiles[c]
	city_pool = d.city_pool
	for k in d.troop_pool:
		troop_pool[k] = int(d.troop_pool[k])
	event_pool = d.event_pool
	for k in [1, 2, 3]:
		events_by_decade[k] = d.events_by_decade[str(k)]
	removed_events = d.removed_events
	pope_available = d.pope_available
	pope_holder = int(d.pope_holder)
	wars_fought = int(d.wars_fought)
	war_limit = int(d.war_limit)
	decade = int(d.decade)
	current = int(d.current)
	deck = d.deck
	discards = d.discards
	consecutive_passes = int(d.consecutive_passes)
	turn_number = int(d.turn_number)
	last_actor = int(d.last_actor)
	auction_history = d.get("auction_history", [])
	deals = []
	for dd in d.get("deals", []):
		var x := {}
		for k in dd:
			var v = dd[k]
			if typeof(v) == TYPE_FLOAT and v == floor(v):
				v = int(v)
			x[k] = v
		deals.append(x)
	deal_seq = int(d.get("deal_seq", 0))
	var rep = d.get("reputation", {})
	for k in rep:
		reputation[int(k)] = float(rep[k])

# ------------------------------------------------------------------ partita

func run(resume := false) -> void:
	var start_dec := decade if resume else 1
	if resume:
		say("Partita ripresa: Decade %s, turno di %s." % [["I", "II", "III"][decade - 1], pname(current)], "important")
	else:
		say("Inizia la partita. Primo giocatore: %s." % pname(current), "important")
	for d in range(start_dec, 4):
		decade = d
		if resume and d == start_dec:
			decade_started.emit(decade)
			changed.emit()
		else:
			await _start_decade()
			decade_over = false
			consecutive_passes = 0
		while not decade_over:
			var pid := current
			last_actor = pid
			await take_turn(pid)
			changed.emit()
			current = (pid + 1) % players.size()
		await _end_decade()
		current = (last_actor + 1) % players.size()
	results = await final_scoring()
	finished = true
	changed.emit()
	game_over.emit(results)

func _start_decade() -> void:
	event_pool = events_by_decade[decade].duplicate()
	wars_fought = 0
	for p in players:
		p.used = {}
	say("—— DECADE %s ——" % ["I", "II", "III"][decade - 1], "decade")
	decade_started.emit(decade)
	changed.emit()
	for p in players:
		if p.family == "baglioni" and p.side == "B":
			var r = await ask(p.id, "baglioni_cur", {})
			p.baglioni_cur = "inf" if str(r) == "inf" else "gold"
			say("%s sceglie lo sconto in %s per questa Decade." % [p.name, Data.cur_name(p.baglioni_cur)])

func _end_decade() -> void:
	if negotiation:
		await _settle_decade()
	say("Fine della Decade %s: riscossione delle rendite." % ["I", "II", "III"][decade - 1], "decade")
	for p in players:
		var inc := income_of(p.id)
		p.gold += inc.gold
		p.inf += inc.inf
		p.home_gold = 0
		say("%s riceve %d Oro e %d Influenza%s." % [p.name, inc.gold, inc.inf,
			(" (di cui %d Oro dalle guerre)" % inc.war) if inc.war > 0 else ""], "income")
	if decade < 3 and pope_holder >= 0:
		say("Il Papa torna disponibile per la prossima Decade.")
		pope_holder = -1
		pope_available = true
	changed.emit()

func income_of(pid: int) -> Dictionary:
	var p = players[pid]
	var g := Data.FAMILY_GOLD
	var i := Data.FAMILY_INF
	var merch := 0
	for t in p.cities:
		var d := Data.city_tile(t)
		g += d.gold
		i += d.inf
		if d.get("merchant", false):
			merch += 1
	var vini := 0
	for e in p.events:
		if Data.event(e).kind == "merchant":
			vini += 1
	g += merch * vini
	for tr in p.troops:
		i += Data.TROOPS[tr].inf
	if pope_holder == pid:
		g += Data.POPE.gold
	var w: int = p.home_gold
	g += w
	return {"gold": g, "inf": i, "war": w}

# ------------------------------------------------------------------ turno

func take_turn(pid: int) -> void:
	turn_number += 1
	var start_turn := turn_number
	var tlog := {"wars": [], "auction": "", "closed": false, "could_war": wars_fought < war_limit, "available": legal_actions(pid).auction}
	turn_log = tlog
	var p = players[pid]
	for q in players:
		q.passed = false
	changed.emit()
	var must_act := consecutive_passes >= players.size() * 2
	while true:
		var opts := legal_actions(pid)
		opts["must_act"] = must_act
		var choice = await ask(pid, "turn", opts)
		if typeof(choice) != TYPE_DICTIONARY:
			choice = {"type": "pass"}
		if not action_stats.has(pid):
			action_stats[pid] = {}
		var akey := str(choice.get("type", "pass"))
		if akey == "auction":
			akey += "_" + item_kind(str(choice.get("item", "")))
		action_stats[pid][akey] = action_stats[pid].get(akey, 0) + 1
		match str(choice.get("type", "pass")):
			"free":
				await do_free(pid, choice)
				changed.emit()
				continue
			"buy_troop":
				var t: String = choice.troop
				if t in opts.troops:
					p.gold -= Data.TROOPS[t].cost
					p.troops.append(t)
					troop_pool[t] -= 1
					var note := " (abilità d'Este: Artiglieria già nella Decade I)" if decade == 1 and Data.TROOPS[t].noI else ""
					say("%s acquista %s per %d Oro%s." % [p.name, Data.TROOPS[t].name, Data.TROOPS[t].cost, note], "buy")
					consecutive_passes = 0
				else:
					say("%s passa." % p.name)
					consecutive_passes += 1
			"discard_troop":
				var t2: String = choice.troop
				if t2 in p.troops:
					p.troops.erase(t2)
					troop_pool[t2] += 1
					say("%s scarta %s." % [p.name, Data.TROOPS[t2].name], "buy")
				consecutive_passes = 0
			"buy_treach":
				if opts.treach:
					p.gold -= 1
					p.inf -= 1
					say("%s acquista una carta Tradimento." % p.name, "treach")
					await gain_treachery(pid)
				consecutive_passes = 0
			"auction":
				consecutive_passes = 0
				tlog.auction = str(choice.item)
				if event_pool.size() == 1 and str(choice.item) in event_pool:
					tlog.closed = true
				await run_auction(pid, str(choice.item))
			"war":
				consecutive_passes = 0
				tlog.wars.append([str(choice.att), str(choice.def)])
				await run_war(pid, str(choice.att), str(choice.def), true)
			_:
				say("%s passa." % p.name)
				consecutive_passes += 1
		break
	changed.emit()
	# carta Iniziare una Guerra a fine turno
	if not decade_over and "inizia_guerra" in p.treach:
		var r = await ask(pid, "start_war_card", {"cities": Data.CITIES})
		if typeof(r) == TYPE_DICTIONARY and r.has("att") and r.has("def") and r.att != r.def:
			p.treach.erase("inizia_guerra")
			discards.append("inizia_guerra")
			say("%s gioca «Iniziare una Guerra»!" % p.name, "treach")
			tlog.wars.append([str(r.att), str(r.def)])
			await run_war(pid, str(r.att), str(r.def), false)
	if negotiation:
		await _settle_turn(pid, start_turn, tlog)
	changed.emit()

func legal_actions(pid: int) -> Dictionary:
	var p = players[pid]
	var troops: Array = []
	for t in Data.TROOP_ORDER:
		if troop_pool[t] <= 0 or t in p.troops:
			continue
		if p.gold < Data.TROOPS[t].cost:
			continue
		if decade == 1 and Data.TROOPS[t].noI:
			if not (t == "artiglieria" and fam_ab(pid).get("artillery_I", false)):
				continue
		troops.append(t)
	var auc: Array = []
	for t in city_pool:
		if can_hold_city(pid, t) and max_payable(pid, t, "gold", "city") >= 2 * status[Data.city_tile(t).city]:
			auc.append(t)
	for e in event_pool:
		auc.append(e)
	if pope_available:
		auc.append("POPE")
	var free: Array = []
	if "ruba_oro" in p.treach:
		free.append({"what": "ruba_oro"})
	if "ruba_inf" in p.treach:
		free.append({"what": "ruba_inf"})
	for t in p.cities:
		var ab: Array = Data.city_tile(t).ab
		if "steal_inf" in ab and not p.used.has("lucrezia"):
			free.append({"what": "lucrezia"})
		if "free_treach" in ab and not p.used.has("ft_" + t) and deck.size() > 0:
			free.append({"what": "free_treach", "src": t})
		if "bank" in ab and not p.used.has("bank_" + t):
			free.append({"what": "bank", "src": t})
	if fam_ab(pid).get("free_treach", false) and not p.used.has("ft_family") and deck.size() > 0:
		free.append({"what": "free_treach", "src": "family"})
	return {
		"troops": troops, "discard": p.troops.duplicate(),
		"treach": p.gold >= 1 and p.inf >= 1 and deck.size() > 0,
		"auction": auc, "war": wars_fought < war_limit, "free": free,
		"obligations": obligations_of(pid) if negotiation else [],
		"deal_types": TURN_TYPES.filter(func(t): return deal_on(t) and not (t == "loan" and decade >= 3)),
	}

func do_free(pid: int, choice: Dictionary) -> void:
	var p = players[pid]
	var what := str(choice.get("what", ""))
	var target := int(choice.get("target", -1))
	if what in ["ruba_oro", "ruba_inf", "lucrezia"] and target >= 0:
		for d in deals:
			if d.status == "active" and d.type == "protection" and int(d.to) == pid and int(d.from) == target:
				_break_deal(d, "deruba %s nonostante la protezione pagata" % pname(target))
	match what:
		"ruba_oro":
			if "ruba_oro" in p.treach and target >= 0 and target != pid:
				var n: int = min(3, players[target].gold)
				players[target].gold -= n
				p.gold += n
				p.treach.erase("ruba_oro")
				discards.append("ruba_oro")
				say("%s gioca «Rubare Oro» e sottrae %d Oro a %s." % [p.name, n, pname(target)], "treach")
				_notify_ai_hostile(pid, target, 1.0)
		"ruba_inf":
			if "ruba_inf" in p.treach and target >= 0 and target != pid:
				var n2: int = min(2, players[target].inf)
				players[target].inf -= n2
				p.inf += n2
				p.treach.erase("ruba_inf")
				discards.append("ruba_inf")
				say("%s gioca «Rubare Influenza» e sottrae %d Influenza a %s." % [p.name, n2, pname(target)], "treach")
				_notify_ai_hostile(pid, target, 1.0)
		"lucrezia":
			if not p.used.has("lucrezia") and target >= 0 and target != pid and owns_ability(pid, "steal_inf"):
				var n3: int = min(2, players[target].inf)
				players[target].inf -= n3
				p.inf += n3
				p.used["lucrezia"] = true
				say("Lucrezia Borgia: %s sottrae %d Influenza a %s." % [p.name, n3, pname(target)], "treach")
				_notify_ai_hostile(pid, target, 0.8)
		"free_treach":
			var src := str(choice.get("src", ""))
			var key := "ft_" + src
			if not p.used.has(key):
				p.used[key] = true
				var who := "la famiglia" if src == "family" else Data.city_tile(src).get("name", src)
				say("%s prende una carta Tradimento gratuita (%s)." % [p.name, who], "treach")
				await gain_treachery(pid)
		"deal":
			if negotiation and typeof(choice.get("deal")) == TYPE_DICTIONARY:
				var d: Dictionary = choice.deal
				d["from"] = pid
				if not d.has("type"):
					d["type"] = "exchange"
				p.used["deal_t%d_%d" % [turn_number, int(d.get("to", -1))]] = true
				await propose(d)
		"bank":
			var src2 := str(choice.get("src", ""))
			var amt := clampi(int(choice.get("amount", 0)), 0, 3)
			if not p.used.has("bank_" + src2) and amt > 0:
				if choice.get("dir", "g2i") == "g2i":
					amt = min(amt, p.gold)
					p.gold -= amt
					p.inf += amt
					say("%s (Banchiere) cambia %d Oro in Influenza." % [p.name, amt])
				else:
					amt = min(amt, p.inf)
					p.inf -= amt
					p.gold += amt
					say("%s (Banchiere) cambia %d Influenza in Oro." % [p.name, amt])
				p.used["bank_" + src2] = true

func _notify_ai_hostile(src: int, target: int, w: float) -> void:
	for p in players:
		if p.is_ai and p.ai:
			p.ai.observe_hostility(src, target, w)

# ------------------------------------------------------------------ abilità

func fam_ab(pid: int) -> Dictionary:
	var p = players[pid]
	return Data.FAMILIES[p.family][p.side]

func owns_ability(pid: int, ab: String) -> bool:
	for t in players[pid].cities:
		if ab in Data.city_tile(t).ab:
			return true
	return false

func count_ability(pid: int, ab: String) -> int:
	var n := 0
	for t in players[pid].cities:
		if ab in Data.city_tile(t).ab:
			n += 1
	return n

func treach_limit(pid: int) -> int:
	var base: int = fam_ab(pid).get("treach_limit", 2)
	return base + count_ability(pid, "treach_limit1")

func player_city_set(pid: int) -> Array:
	var s: Array = []
	for t in players[pid].cities:
		var c: String = Data.city_tile(t).city
		if not c in s:
			s.append(c)
	return s

func can_hold_city(pid: int, tile: String) -> bool:
	var p = players[pid]
	if p.cities.size() >= 6:
		return false
	var c: String = Data.city_tile(tile).city
	var cs := player_city_set(pid)
	return c in cs or cs.size() < 3

## sconto complessivo applicabile quando si vince un'offerta
func discount(pid: int, cur: String, kind: String) -> int:
	var p = players[pid]
	var f := fam_ab(pid)
	var d := 0
	if cur == "gold":
		d += int(f.get("gold_disc", 0))
	else:
		d += int(f.get("inf_disc", 0))
	d += int(f.get("any_disc", 0))
	if f.has("choose_disc") and p.baglioni_cur == cur:
		d += int(f.choose_disc)
	if kind == "condo":
		d += count_ability(pid, "condo_disc1")
	if kind == "pope":
		d += count_ability(pid, "pope_disc1")
	return d

func bank_potential(pid: int, cur: String) -> int:
	var p = players[pid]
	var other: int = p.inf if cur == "gold" else p.gold
	var n := 0
	for t in p.cities:
		if "bank" in Data.city_tile(t).ab and not p.used.has("bank_" + t):
			var c: int = min(3, other)
			n += c
			other -= c
	return n

func item_kind(item: String) -> String:
	if item == "POPE":
		return "pope"
	if Data.is_city_tile(item):
		return "city"
	return "event"

func item_currency(item: String) -> String:
	if item == "POPE":
		return "inf"
	if Data.is_city_tile(item):
		return "gold"
	return Data.event(item).cur

func max_payable(pid: int, item: String, cur: String, kind: String) -> int:
	var p = players[pid]
	var base: int = p.gold if cur == "gold" else p.inf
	base += discount(pid, cur, kind)
	if kind == "pope":
		base += 3 * p.treach.count("cardinale")
	base += bank_potential(pid, cur)
	return base

## paga un'offerta; ritorna l'importo effettivamente pagato
func pay_bid(pid: int, amount: int, cur: String, kind: String) -> int:
	var p = players[pid]
	var due: int = max(0, amount - discount(pid, cur, kind))
	if kind == "pope":
		while due > 0 and "cardinale" in p.treach and (p.inf < due or due >= 3):
			p.treach.erase("cardinale")
			discards.append("cardinale")
			due = max(0, due - 3)
			say("%s usa «Corrompere Cardinale» (vale 3 Influenza)." % p.name, "treach")
	var have: int = p.gold if cur == "gold" else p.inf
	if have < due:
		for t in p.cities:
			if have >= due:
				break
			if "bank" in Data.city_tile(t).ab and not p.used.has("bank_" + t):
				var need: int = min(3, due - have)
				if cur == "gold":
					need = min(need, p.inf)
					p.inf -= need
					p.gold += need
				else:
					need = min(need, p.gold)
					p.gold -= need
					p.inf += need
				have += need
				p.used["bank_" + t] = true
				say("%s usa il Banchiere per convertire %d in %s." % [p.name, need, Data.cur_name(cur)])
	due = min(due, have)
	if cur == "gold":
		p.gold -= due
	else:
		p.inf -= due
	return due

# ------------------------------------------------------------------ tradimento

func gain_treachery(pid: int) -> void:
	var p = players[pid]
	if deck.is_empty():
		say("Il mazzo Tradimento è esaurito.")
		return
	var card: String
	if fam_ab(pid).get("draw2", false) and deck.size() >= 2:
		var a: String = deck.pop_back()
		var b: String = deck.pop_back()
		var r = await ask(pid, "keep_treach", {"cards": [a, b]})
		var idx := 1 if int(r) == 1 else 0
		card = [a, b][idx]
		deck.push_front([a, b][1 - idx])
	else:
		card = deck.pop_back()
	p.treach.append(card)
	if not p.is_ai:
		say("Hai pescato: %s." % Data.TREACHERY[card].name, "private")
	changed.emit()
	while p.treach.size() > treach_limit(pid):
		var r2 = await ask(pid, "discard_treach", {"cards": p.treach.duplicate(), "limit": treach_limit(pid)})
		var c := str(r2)
		if not c in p.treach:
			c = p.treach[0]
		p.treach.erase(c)
		discards.append(c)
		say("%s scarta una carta Tradimento (limite %d)." % [p.name, treach_limit(pid)], "treach")
	changed.emit()

# ------------------------------------------------------------------ aste

func order_from(start: int) -> Array:
	var o: Array = []
	for k in players.size():
		o.append((start + k) % players.size())
	return o

func run_auction(starter: int, item: String) -> void:
	var kind := item_kind(item)
	var cur := item_currency(item)
	var min_open := 0
	if kind == "city":
		min_open = 2 * status[Data.city_tile(item).city]
	say("%s mette all'asta %s (in %s%s)." % [pname(starter), Data.item_name(item), Data.cur_name(cur),
		(", offerta minima %d" % min_open) if min_open > 0 else ""], "auction")
	var res = await _bidding(starter, item, kind, cur, min_open, -1, true)
	var winner: int = res.winner
	var price: int = res.price
	if winner < 0:
		say("Nessuno si aggiudica %s." % Data.item_name(item), "auction")
		auction = {}
		auction_changed.emit(auction)
		return
	var paid := pay_bid(winner, price, cur, kind)
	say("%s si aggiudica %s per %d %s%s." % [pname(winner), Data.item_name(item), price, Data.cur_name(cur),
		(" (paga %d grazie agli sconti)" % paid) if paid != price else ""], "auction")
	auction_history.append({"item": item, "winner": winner, "price": price, "bids": res.bids, "decade": decade, "starter": starter})
	for p in players:
		if p.is_ai and p.ai:
			p.ai.observe_auction(auction_history.back())
	auction = {}
	auction_changed.emit(auction)
	await _acquire(winner, item)
	changed.emit()

func _acquire(pid: int, item: String) -> void:
	var p = players[pid]
	if item == "POPE":
		pope_holder = pid
		pope_available = false
		return
	if Data.is_city_tile(item):
		city_pool.erase(item)
		p.cities.append(item)
		return
	var e := Data.event(item)
	event_pool.erase(item)
	match str(e.kind):
		"vp", "merchant":
			p.events.append(item)
		"sta":
			await _offer_round("artist_req", {"to": pid, "item": item}, [pid])
			var adeals: Array = deals.filter(func(x): return x.status == "active" and x.type == "artist_req" and x.item == item)
			var r = await ask(pid, "place_sta", {"item": item, "deals": adeals})
			var c := str(r)
			if not c in Data.CITIES:
				c = Data.CITIES[0]
			var before: int = status[c]
			status[c] = min(Data.STATUS_MAX, status[c] + 1)
			artists[c] += 1
			sta_tiles[c].append(item)
			say("%s assegna %s a %s: Status %d → %d." % [p.name, e.name, Data.CITY_NAME[c], before, status[c]], "important")
			await _settle(func(x): return x.type == "artist_req" and x.item == item, func(x):
				if x.city == c:
					return true
				x["_why"] = "assegna l'Artista a %s invece che a %s" % [_cityn(c), _cityn(x.city)]
				return false)
		"french":
			await _offer_round("french_req", {"to": pid, "item": item}, [pid])
			var fdeals: Array = deals.filter(func(x): return x.status == "active" and x.type == "french_req" and x.item == item)
			var r2 = await ask(pid, "french", {"deals": fdeals})
			var c2 := str(r2)
			if not c2 in Data.CITIES:
				c2 = ""
			if c2 in Data.CITIES:
				var b2: int = status[c2]
				status[c2] = max(Data.STATUS_MIN, status[c2] - 2)
				say("Invasione Francese contro %s: Status %d → %d!" % [Data.CITY_NAME[c2], b2, status[c2]], "important")
			else:
				say("%s scarta l'Invasione Francese." % p.name)
			removed_events.append(item)
			await _settle(func(x): return x.type == "french_req" and x.item == item, func(x):
				if str(x.city) == c2:
					return true
				x["_why"] = "non usa l'Invasione Francese come promesso"
				return false)
	if event_pool.is_empty():
		decade_over = true

## Procedura generica d'asta all'inglese con abbandono definitivo.
## Ritorna {"winner","price","bids"}
func _bidding(starter: int, item: String, kind: String, cur: String, min_open: int, exclude: int, opener_must: bool) -> Dictionary:
	var order := order_from(starter)
	var part: Array = []
	for pid in order:
		if pid == exclude:
			continue
		if kind == "city" and not can_hold_city(pid, item):
			continue
		if kind == "condo" and players[pid].troops.is_empty():
			continue
		part.append(pid)
	for p in players:
		p.passed = not (p.id in part)
	var out := {}
	var frozen := {}
	auction_seq += 1
	var aseq := auction_seq
	var proposed := {}
	var high := -1
	var bid := -1
	var bids: Array = []
	auction = {"item": item, "kind": kind, "cur": cur, "high": -1, "bid": -1, "part": part, "out": out, "min_open": min_open, "starter": starter, "exclude": exclude, "bids": bids}
	auction_changed.emit(auction)
	if part.is_empty():
		return {"winner": -1, "price": 0, "bids": bids}
	var idx := 0
	var safety := 0
	while true:
		safety += 1
		if safety > 500:
			break
		var remaining: Array = []
		for pid in part:
			if not out.has(pid):
				remaining.append(pid)
		if remaining.is_empty():
			break
		if remaining.size() == 1 and remaining[0] == high:
			break
		var pid: int = part[idx % part.size()]
		idx += 1
		if out.has(pid) or pid == high:
			continue
		var minb := min_open if high < 0 else bid + 1
		var maxb := max_payable(pid, item if kind != "condo" else "", cur, kind)
		var must := opener_must and high < 0 and pid == starter
		if frozen.has(pid):
			frozen.erase(pid)
			out[pid] = true
			players[pid].passed = true
			say("%s è congelato e non può rilanciare: esce dall'asta." % pname(pid), "auction")
			auction.out = out
			auction_changed.emit(auction)
			changed.emit()
			continue
		if maxb < minb:
			if must:
				minb = maxb
			else:
				out[pid] = true
				players[pid].passed = true
				say("%s non può permettersi di rilanciare e passa." % pname(pid), "auction")
				auction.out = out
				auction_changed.emit(auction)
				changed.emit()
				continue
		var ctx := {"item": item, "kind": kind, "cur": cur, "high": high, "bid": bid, "min": minb, "max": maxb,
			"must": must, "remaining": remaining, "part": part, "can_freeze": "congela" in players[pid].treach,
			"starter": starter, "exclude": exclude, "discount": discount(pid, cur, kind), "aseq": aseq}
		if kind == "condo":
			ctx["war"] = war.duplicate()
		# trattative: chi è di turno può proporre un accordo a un altro partecipante
		var targets: Array = []
		var atypes: Array = []
		if negotiation and not proposed.has(pid):
			for q in remaining:
				if q != pid and q != high:
					targets.append(q)
			if deal_on("abstain"):
				atypes.append("abstain")
			if deal_on("freeze_req") and remaining.size() >= 3:
				atypes.append("freeze_req")
			if deal_on("condo_split") and kind == "condo" and war.get("phase", "") == "condo_att":
				atypes.append("condo_split")
		if atypes.is_empty():
			targets = []
		ctx["deal_targets"] = targets
		ctx["deal_types"] = atypes
		var promise := bid_promise(pid, aseq, kind, item, high)
		if not promise.is_empty():
			ctx["promise"] = promise
		# congelamenti promessi
		for d in deals:
			if d.status == "active" and d.type == "freeze_req" and int(d.aseq) == aseq and int(d.to) == pid:
				if "congela" in players[pid].treach and int(d.victim) in remaining:
					d["chance"] = true
					ctx["freeze_promise"] = d
		var r = null
		while true:
			if players[pid].is_ai and not targets.is_empty() and not proposed.has(pid):
				proposed[pid] = true
				var plan = players[pid].ai.plan_auction_deal(ctx)
				if typeof(plan) == TYPE_DICTIONARY:
					plan["from"] = pid
					if not plan.has("type"):
						plan["type"] = "abstain"
					plan["aseq"] = aseq
					plan["item"] = item
					plan["kind"] = kind
					if plan.type == "condo_split":
						plan["wseq"] = war_seq
						plan["att"] = war.att
						plan["def"] = war.def
					await propose(plan)
					auction_changed.emit(auction)
			r = await ask(pid, "bid" if kind != "condo" else "condo_bid", ctx)
			if typeof(r) == TYPE_DICTIONARY and r.has("deal") and not proposed.has(pid) and negotiation:
				proposed[pid] = true
				var hd: Dictionary = r.deal
				hd["from"] = pid
				if not hd.has("type"):
					hd["type"] = "abstain"
				hd["aseq"] = aseq
				hd["item"] = item
				hd["kind"] = kind
				if hd.type == "condo_split":
					hd["wseq"] = war_seq
					hd["att"] = war.att
					hd["def"] = war.def
				await propose(hd)
				ctx["deal_targets"] = []
				var pr2 := bid_promise(pid, aseq, kind, item, high)
				if not pr2.is_empty():
					ctx["promise"] = pr2
				auction_changed.emit(auction)
				continue
			break
		if typeof(r) != TYPE_DICTIONARY:
			r = {"pass": true}
		if r.has("freeze") and "congela" in players[pid].treach:
			var ft := int(r.freeze)
			if ft >= 0 and ft != pid and ft in remaining:
				players[pid].treach.erase("congela")
				discards.append("congela")
				frozen[ft] = true
				say("%s gioca «Congelare un'Offerta» contro %s!" % [pname(pid), pname(ft)], "treach")
				_notify_ai_hostile(pid, ft, 0.6)
				for d in deals:
					if d.status == "active" and d.type == "freeze_req" and int(d.aseq) == aseq and int(d.to) == pid and int(d.victim) == ft:
						d["done"] = true
		if r.get("pass", false) and not must:
			out[pid] = true
			players[pid].passed = true
			bids.append([pid, -1])
			say("%s passa." % pname(pid), "auction")
		else:
			var b := clampi(int(r.get("bid", minb)), minb, max(minb, maxb))
			bid = b
			high = pid
			bids.append([pid, b])
			say("%s offre %d %s." % [pname(pid), b, Data.cur_name(cur)], "bid")
			if not promise.is_empty() and promise.status == "active" and not must:
				_break_deal(promise, "rilancia nonostante il patto", pid)
		auction.high = high
		auction.bid = bid
		auction.out = out
		auction_changed.emit(auction)
		changed.emit()
	if negotiation:
		await _settle_abstain(aseq)
	return {"winner": high, "price": max(0, bid), "bids": bids}

# ------------------------------------------------------------------ trattative
#
# Tipi di accordo (chiave per gli interruttori nel menu "Accordi"):
#   exchange      Scambio Oro <-> Influenza (immediato)
#   loan          Prestito: Oro ora, restituzione maggiorata a fine Decade
#   abstain       Astensione: ti pago perché non rilanci più in quest'asta
#   condo_split   Spartizione dei Condottieri: tu non mi contendi l'attacco; io non ti contendo la difesa
#                 (vincolo reale solo se perdo l'attacco contro un terzo: chi vince l'attacco è già escluso)
#   freeze_req    Congelamento su commissione: ti pago perché congeli un rivale
#   holy          Lega Santa a pagamento
#   veto_bounty   Taglia su chi pone il Veto
#   card_req      Corruzione/Maltempo su commissione
#   reroll_req    Rilancio dei dadi (Ludovico Sforza) a pagamento
#   war_req       Guerra su commissione: dichiara la guerra A->B nel tuo prossimo turno
#   no_attack     Non aggressione: non dichiarare guerra contro la città X per questa Decade
#   auction_req   Metti all'asta una certa tessera nel tuo prossimo turno
#   no_close      Non chiudere la Decade nel tuo prossimo turno
#   city_pact     Spartizione di una città: non ci rilanciamo contro sulle sue tessere per questa Decade
#   protection    Protezione: niente furti (Rubare Oro/Influenza, Lucrezia) contro di me per questa Decade
#   artist_req    Artista "+1" assegnato alla città che chiedo
#   french_req    Invasione Francese contro la città che chiedo (o scartata)
#   ties_req      Bentivoglio decide uno spareggio a mio favore

const DEAL_TYPES := ["exchange", "loan", "abstain", "condo_split", "freeze_req", "holy", "veto_bounty", "card_req", "reroll_req",
	"war_req", "no_attack", "auction_req", "no_close", "city_pact", "protection", "artist_req", "french_req", "ties_req"]
const PAID_TYPES := ["abstain", "condo_split", "freeze_req", "holy", "card_req", "reroll_req", "war_req", "no_attack",
	"auction_req", "no_close", "city_pact", "protection", "artist_req", "french_req", "ties_req"]
const FREE_OK := ["condo_split", "city_pact"]   # possono avere pagamento 0
const TURN_TYPES := ["exchange", "loan", "war_req", "no_attack", "auction_req", "no_close", "city_pact", "protection"]

func deal_on(t: String) -> bool:
	return negotiation and bool(deals_cfg.get(t, true))

func _cityn(c) -> String:
	return Data.CITY_NAME.get(str(c), str(c))

func deal_text(d: Dictionary) -> String:
	var a := pname(int(d.get("from", -1)))
	var b := pname(int(d.get("to", -1)))
	var pay := ""
	if int(d.get("pay_amt", 0)) > 0:
		pay = "%s paga %d %s a %s " % [a, int(d.pay_amt), Data.cur_name(str(d.get("pay_cur", "gold"))), b]
	else:
		pay = "%s e %s si accordano: " % [a, b]
	var t := ""
	match str(d.get("type", "")):
		"exchange":
			return "%s dà %d %s a %s in cambio di %d %s" % [a, int(d.give_amt), Data.cur_name(d.give_cur), b, int(d.get_amt), Data.cur_name(d.get_cur)]
		"loan":
			return "%s presta %d Oro a %s, che ne restituirà %d a fine Decade" % [pname(int(d.lender)), int(d.amount), pname(int(d.borrower)), int(d.repay)]
		"abstain":
			var what := "nell'asta per il Condottiero"
			if d.get("kind", "") != "condo":
				what = "nell'asta per " + Data.item_name(str(d.get("item", "")))
			t = pay + "perché non rilanci più " + what
		"condo_split":
			t = pay + "%s non contende a %s il comando di %s (attacco); in cambio %s, anche se perdesse quell'asta, non gli contenderà il comando di %s (difesa)" % [b, a, _cityn(d.get("att", "")), a, _cityn(d.get("def", ""))]
		"freeze_req":
			t = pay + "perché giochi «Congelare un'Offerta» contro %s in quest'asta" % pname(int(d.victim))
		"holy":
			t = pay + "perché il Papa formi la Lega Santa a fianco di %s" % _cityn(war.get(d.side, d.side) if war.size() > 0 else d.side)
		"card_req":
			if d.card == "maltempo":
				t = pay + "perché giochi «Maltempo» contro %s" % _cityn(d.get("city", ""))
			else:
				t = pay + "perché corrompa una Truppa di %s" % pname(int(d.victim))
		"reroll_req":
			t = pay + "perché Ludovico Sforza faccia rilanciare i dadi"
		"war_req":
			t = pay + "perché nel suo prossimo turno dichiari guerra: %s contro %s" % [_cityn(d.att), _cityn(d.def)]
		"no_attack":
			t = pay + "perché in questa Decade non dichiari guerra contro %s" % _cityn(d.city)
		"auction_req":
			t = pay + "perché nel suo prossimo turno metta all'asta %s" % Data.item_name(str(d.item))
		"no_close":
			t = pay + "perché nel suo prossimo turno non chiuda la Decade (niente asta dell'ultimo Evento)"
		"city_pact":
			t = pay + "in questa Decade non si rilanciano contro sulle tessere di %s" % _cityn(d.city)
		"protection":
			t = pay + "perché in questa Decade non gli rubi Oro o Influenza"
		"artist_req":
			t = pay + "perché assegni %s a %s" % [Data.item_name(str(d.get("item", ""))), _cityn(d.city)]
		"french_req":
			if str(d.city) == "":
				t = pay + "perché scarti l'Invasione Francese"
			else:
				t = pay + "perché l'Invasione Francese colpisca %s" % _cityn(d.city)
		"ties_req":
			t = pay + "perché %s vinca lo spareggio tra le città" % _cityn(d.city)
		_:
			t = str(d)
	if int(d.get("pay_amt", 0)) > 0:
		t += " (pagamento %s)" % ("subito" if d.get("timing", "after") == "now" else "a cose fatte")
	return t

func reputation_txt(pid: int) -> String:
	var r: float = reputation.get(pid, 1.0)
	if r >= 0.9:
		return "affidabile"
	if r >= 0.6:
		return "discutibile"
	if r >= 0.3:
		return "infido"
	return "traditore"

func _money(pid: int, cur: String) -> int:
	return players[pid].gold if cur == "gold" else players[pid].inf

func _transfer(a: int, b: int, cur: String, amt: int) -> int:
	var n: int = clampi(amt, 0, _money(a, cur))
	if cur == "gold":
		players[a].gold -= n
		players[b].gold += n
	else:
		players[a].inf -= n
		players[b].inf += n
	return n

func _affordable(d: Dictionary) -> bool:
	var a: int = int(d.from)
	var b: int = int(d.to)
	match str(d.type):
		"exchange":
			return int(d.give_amt) > 0 and int(d.get_amt) > 0 and _money(a, d.give_cur) >= int(d.give_amt) and _money(b, d.get_cur) >= int(d.get_amt)
		"loan":
			return int(d.amount) > 0 and int(d.repay) >= int(d.amount) and _money(int(d.lender), "gold") >= int(d.amount)
	var amt := int(d.get("pay_amt", 0))
	if amt <= 0:
		return d.type in FREE_OK and amt == 0
	return _money(a, str(d.get("pay_cur", "gold"))) >= amt

## Accordi attivi in cui pid deve fare (o non fare) qualcosa
func obligations_of(pid: int) -> Array:
	var out: Array = []
	for d in deals:
		if d.status != "active":
			continue
		if int(d.to) == pid or (d.type in ["city_pact", "condo_split"] and int(d.from) == pid):
			out.append(d)
	return out

func active_deals() -> Array:
	return deals.filter(func(x): return x.status == "active")

## Proposta di accordo: chiede al destinatario, gestisce una controproposta
func propose(d: Dictionary) -> bool:
	var tp := str(d.get("type", ""))
	if not deal_on(tp):
		return false
	var a: int = int(d.get("from", -1))
	var b: int = int(d.get("to", -1))
	if a < 0 or b < 0 or a == b or b >= players.size():
		return false
	if tp == "loan":
		if decade >= 3:
			return false
		if not d.has("lender"):
			d["lender"] = a
			d["borrower"] = b
	if not d.has("timing"):
		d["timing"] = "after"
	if tp == "exchange" or tp == "loan":
		d["timing"] = "now"
	if not _affordable(d):
		return false
	deal_seq += 1
	d["id"] = deal_seq
	d["status"] = "proposed"
	d["decade"] = decade
	d["turn"] = turn_number
	deal_stats.proposed += 1
	say("Trattativa — %s propone a %s: %s." % [pname(a), pname(b), deal_text(d)], "deal")
	var r = await ask(b, "deal_offer", {"deal": d.duplicate(), "reputation": reputation.get(a, 1.0)})
	var ok := false
	if typeof(r) == TYPE_DICTIONARY:
		if r.get("accept", false):
			ok = true
		elif r.has("counter") or r.has("timing"):
			var d2 := d.duplicate()
			if r.has("counter"):
				var cv: int = max(0, int(r.counter))
				match tp:
					"exchange":
						d2.get_amt = max(1, cv)
					"loan":
						d2.repay = max(int(d2.amount), cv)
					_:
						d2.pay_amt = cv
			if r.has("timing") and tp in PAID_TYPES:
				d2.timing = str(r.timing)
			if _affordable(d2):
				say("%s fa una controproposta: %s." % [pname(b), deal_text(d2)], "deal")
				var r2 = await ask(a, "deal_counter", {"deal": d2.duplicate(), "original": d.duplicate()})
				if r2 == true:
					for k in d2:
						d[k] = d2[k]
					ok = true
	if not ok:
		say("%s rifiuta l'accordo." % pname(b), "deal")
		deal_event.emit("%s rifiuta la proposta di %s" % [pname(b), pname(a)], "no")
		return false
	deal_stats.accepted += 1
	match tp:
		"exchange":
			_transfer(a, b, d.give_cur, int(d.give_amt))
			_transfer(b, a, d.get_cur, int(d.get_amt))
			d.status = "done"
			say("Accordo concluso: %s." % deal_text(d), "deal")
			deal_event.emit("Scambio concluso tra %s e %s" % [pname(a), pname(b)], "ok")
		"loan":
			_transfer(int(d.lender), int(d.borrower), "gold", int(d.amount))
			d.status = "active"
			deals.append(d)
			say("Prestito concesso: %s." % deal_text(d), "deal")
			deal_event.emit("Prestito tra %s e %s" % [pname(a), pname(b)], "ok")
		_:
			d.status = "active"
			if d.timing == "now" and int(d.get("pay_amt", 0)) > 0:
				_transfer(a, b, d.pay_cur, int(d.pay_amt))
				d["paid"] = true
			deals.append(d)
			say("Patto stretto: %s." % deal_text(d), "deal")
			deal_event.emit("Patto stretto tra %s e %s" % [pname(a), pname(b)], "ok")
	for p in players:
		if p.is_ai and p.ai:
			p.ai.observe_deal(d, "accepted")
	changed.emit()
	return true

## pid sta per offrire in un'asta: c'è un patto che glielo vieta?
func bid_promise(pid: int, aseq: int, kind: String, item: String, high: int) -> Dictionary:
	for d in deals:
		if d.status != "active":
			continue
		match str(d.type):
			"abstain":
				if int(d.to) == pid and int(d.aseq) == aseq:
					return d
			"condo_split":
				if int(d.to) == pid and int(d.aseq) == aseq:
					return d
				if int(d.from) == pid and kind == "condo" and war.get("phase", "") == "condo_def" and int(d.wseq) == war_seq:
					return d
			"city_pact":
				if kind == "city" and Data.city_tile(item).get("city", "") == d.city and high >= 0:
					if (int(d.from) == pid and int(d.to) == high) or (int(d.to) == pid and int(d.from) == high):
						return d
	return {}

func _break_deal(d: Dictionary, why: String, traitor := -1) -> void:
	if traitor < 0:
		traitor = int(d.to)
	var victim: int = int(d.from) if traitor == int(d.to) else int(d.to)
	d.status = "broken"
	d["traitor"] = traitor
	deal_stats.broken += 1
	reputation[traitor] = max(0.0, reputation.get(traitor, 1.0) - 0.35)
	say("TRADIMENTO! %s %s (patto con %s)." % [pname(traitor), why, pname(victim)], "betray")
	deal_event.emit("%s tradisce il patto con %s!" % [pname(traitor), pname(victim)], "betray")
	for p in players:
		if p.is_ai and p.ai:
			p.ai.observe_deal({"type": d.type, "from": victim, "to": traitor}, "broken")
	changed.emit()

func _void_deal(d: Dictionary, why: String) -> void:
	d.status = "void"
	if d.get("paid", false) and int(d.get("pay_amt", 0)) > 0:
		_transfer(int(d.to), int(d.from), d.pay_cur, int(d.pay_amt))
		say("Accordo annullato (%s): %s restituisce il pagamento." % [why, pname(int(d.to))], "deal")
	else:
		say("Accordo annullato (%s)." % why, "deal")

func _keep_deal(d: Dictionary) -> void:
	d.status = "kept"
	deal_stats.kept += 1
	var t: int = int(d.to)
	reputation[t] = min(1.0, reputation.get(t, 1.0) + 0.05)
	if d.type == "city_pact" or d.type == "condo_split":
		reputation[int(d.from)] = min(1.0, reputation.get(int(d.from), 1.0) + 0.03)
	if d.get("timing", "after") == "after" and not d.get("paid", false) and int(d.get("pay_amt", 0)) > 0:
		await _pay_after(int(d.from), t, d.pay_cur, int(d.pay_amt), d)
	changed.emit()

## pagamento promesso "a cose fatte": chi paga può anche rimangiarsi la parola
func _pay_after(a: int, b: int, cur: String, amt: int, d) -> void:
	var r = await ask(a, "deal_pay", {"deal": d.duplicate() if d is Dictionary else {}, "to": b, "cur": cur, "amount": amt})
	if r == true and _money(a, cur) > 0:
		var n := _transfer(a, b, cur, amt)
		if d is Dictionary:
			d["paid"] = true
		say("%s paga %d %s a %s come promesso." % [pname(a), n, Data.cur_name(cur), pname(b)], "deal")
		reputation[a] = min(1.0, reputation.get(a, 1.0) + 0.05)
		if n < amt:
			reputation[a] = max(0.0, reputation.get(a, 1.0) - 0.15)
	else:
		deal_stats.welched += 1
		reputation[a] = max(0.0, reputation.get(a, 1.0) - 0.35)
		say("TRADIMENTO! %s non paga i %d %s promessi a %s." % [pname(a), amt, Data.cur_name(cur), pname(b)], "betray")
		deal_event.emit("%s non paga %s!" % [pname(a), pname(b)], "betray")
		var fake := {"type": "payment", "from": b, "to": a}
		for p in players:
			if p.is_ai and p.ai:
				p.ai.observe_deal(fake, "broken")
	changed.emit()

func _settle(filter: Callable, kept: Callable) -> void:
	for d in deals.duplicate():
		if d.status == "active" and filter.call(d):
			var k = kept.call(d)
			if typeof(k) == TYPE_STRING:
				_void_deal(d, k)
			elif k == true:
				await _keep_deal(d)
			else:
				_break_deal(d, d.get("_why", "non rispetta il patto"))

func _settle_abstain(aseq: int) -> void:
	await _settle(func(d): return d.type == "abstain" and int(d.aseq) == aseq, func(_d): return true)
	# congelamento su commissione
	await _settle(func(d): return d.type == "freeze_req" and int(d.aseq) == aseq, func(d):
		if d.get("done", false):
			return true
		if d.get("chance", false):
			d["_why"] = "non congela %s come promesso" % pname(int(d.victim))
			return false
		return "non ha avuto occasione")

func _settle_holy(wseq: int, side: String) -> void:
	await _settle(func(d): return d.type == "holy" and int(d.wseq) == wseq, func(d):
		if d.side == side:
			return true
		d["_why"] = "non forma la Lega Santa promessa"
		return false)

func _collect_veto_bounties(starter: int, att: String, def: String) -> void:
	var possible := false
	for p in players:
		if (owns_ability(p.id, "veto") and not p.used.has("veto")) or not p.treach.is_empty():
			possible = true
	if not possible:
		return
	for pid in order_from(starter):
		if pid == starter:
			continue
		var b = null
		if players[pid].is_ai:
			b = players[pid].ai.plan_veto_bounty(att, def, starter)
		else:
			var involved := false
			for t in players[pid].cities:
				if Data.city_tile(t).city in [att, def]:
					involved = true
			if involved:
				b = await ask(pid, "veto_bounty", {"att": att, "def": def, "starter": starter})
		if typeof(b) == TYPE_DICTIONARY and int(b.get("amount", 0)) > 0 and _money(pid, str(b.get("cur", "gold"))) >= int(b.amount):
			var bt := {"from": pid, "amount": int(b.amount), "cur": str(b.get("cur", "gold"))}
			bounties.append(bt)
			say("Trattativa — %s offre %d %s a chi porrà il Veto su questa guerra!" % [pname(pid), bt.amount, Data.cur_name(bt.cur)], "deal")
			deal_event.emit("%s mette una taglia sul Veto" % pname(pid), "ok")

func _bounty_for(pid: int) -> Dictionary:
	var gg := 0
	var i := 0
	for b in bounties:
		if b.from != pid:
			if b.cur == "gold":
				gg += b.amount
			else:
				i += b.amount
	return {"gold": gg, "inf": i}

func _pay_bounties(vetoer: int) -> void:
	for b in bounties:
		if b.from != vetoer:
			await _pay_after(b.from, vetoer, b.cur, b.amount, {"type": "bounty", "from": b.from, "to": vetoer, "pay_cur": b.cur, "pay_amt": b.amount})

## Giro di proposte in un momento chiave: ogni giocatore (tranne excl) può proporre
## un accordo al giocatore "to". kind: card_req / reroll_req / artist_req / french_req / ties_req
func _offer_round(kind: String, ctx: Dictionary, excl: Array) -> void:
	if not deal_on(kind):
		return
	for pid in order_from(current):
		if pid in excl:
			continue
		var plan = null
		var c2 := ctx.duplicate()
		c2["kind"] = kind
		if players[pid].is_ai:
			plan = players[pid].ai.plan_moment_deal(kind, c2)
		elif _money(pid, "gold") + _money(pid, "inf") > 0:
			plan = await ask(pid, "moment_offer", c2)
		if typeof(plan) == TYPE_DICTIONARY:
			plan["from"] = pid
			plan["type"] = kind
			for k in ["wseq", "rseq", "item"]:
				if ctx.has(k) and not plan.has(k):
					plan[k] = ctx[k]
			if not plan.has("to") and ctx.has("to"):
				plan["to"] = ctx.to
			await propose(plan)

## Accordi da saldare a fine Decade
func _settle_decade() -> void:
	# patti di durata decennale rispettati
	await _settle(func(d): return d.type in ["no_attack", "protection", "city_pact"] and int(d.decade) == decade, func(_d): return true)
	# impegni per il "prossimo turno" mai arrivato
	await _settle(func(d): return d.type in ["war_req", "auction_req", "no_close"], func(_d): return "la Decade è finita")
	# prestiti: restituzione
	for d in deals.duplicate():
		if d.type == "loan" and d.status == "active":
			d.status = "kept"
			await _pay_after(int(d.borrower), int(d.lender), "gold", int(d.repay), d)
	deals = deals.filter(func(x): return x.status == "active")

## Accordi legati al "prossimo turno" del giocatore pid (dopo la sua azione)
func _settle_turn(pid: int, start_turn: int, tlog: Dictionary) -> void:
	await _settle(func(d): return int(d.to) == pid and d.type in ["war_req", "auction_req", "no_close"] and int(d.turn) < start_turn, func(d):
		match str(d.type):
			"war_req":
				for w in tlog.wars:
					if w[0] == d.att and w[1] == d.def:
						return true
				if not tlog.could_war:
					return "limite di guerre raggiunto"
				d["_why"] = "non dichiara la guerra promessa (%s contro %s)" % [_cityn(d.att), _cityn(d.def)]
				return false
			"auction_req":
				if tlog.auction == d.item:
					return true
				if not d.item in tlog.available:
					return "tessera non più disponibile"
				d["_why"] = "non mette all'asta %s come promesso" % Data.item_name(str(d.item))
				return false
			"no_close":
				if tlog.closed:
					d["_why"] = "chiude la Decade nonostante il patto"
					return false
				return true
		return true)

# ------------------------------------------------------------------ guerre

func run_war(starter: int, att: String, def: String, counts: bool) -> void:
	if counts:
		wars_fought += 1
	war = {"att": att, "def": def, "ca": -1, "cd": -1, "ally": -1, "ally_side": "", "bribed": [], "mal_att": 0, "mal_def": 0, "phase": "declared", "starter": starter}
	say("%s dichiara guerra: %s attacca %s!" % [pname(starter), Data.CITY_NAME[att], Data.CITY_NAME[def]], "war")
	war_changed.emit(war)
	changed.emit()
	war_seq += 1
	bounties = []
	for d in deals:
		if d.status == "active" and d.type == "no_attack" and int(d.to) == starter and d.city == def:
			_break_deal(d, "attacca %s nonostante il patto di non aggressione" % _cityn(def))
	if negotiation:
		await _collect_veto_bounties(starter, att, def)
	# Veto
	for pid in order_from(starter):
		var p = players[pid]
		var srcs: Array = []
		if "veto" in p.treach:
			srcs.append("card")
		if owns_ability(pid, "veto") and not p.used.has("veto"):
			srcs.append("lorenzo")
		if srcs.is_empty():
			continue
		var r = await ask(pid, "veto", {"att": att, "def": def, "sources": srcs, "starter": starter, "bounty": _bounty_for(pid)})
		var s := str(r)
		if s in srcs:
			if s == "card":
				p.treach.erase("veto")
				discards.append("veto")
				say("%s gioca il «Veto»: la guerra non ha luogo!" % p.name, "treach")
			else:
				p.used["veto"] = true
				say("Lorenzo de' Medici: %s pone il veto, la guerra non ha luogo!" % p.name, "treach")
			_notify_ai_hostile(pid, starter, 0.4)
			await _pay_bounties(pid)
			bounties = []
			war = {}
			war_changed.emit(war)
			changed.emit()
			return
	# Aste per i Condottieri
	war.phase = "condo_att"
	war_changed.emit(war)
	say("Asta per il Condottiero di %s (attaccante)." % Data.CITY_NAME[att], "war")
	var ra = await _bidding(starter, "", "condo", "inf", 0, -1, false)
	var ca: int = ra.winner
	if ca >= 0:
		var paid := pay_bid(ca, ra.price, "inf", "condo")
		say("%s è il Condottiero di %s (paga %d Influenza)." % [pname(ca), Data.CITY_NAME[att], paid], "war")
	else:
		say("Nessun Condottiero per %s." % Data.CITY_NAME[att], "war")
	war.ca = ca
	war.phase = "condo_def"
	war_changed.emit(war)
	say("Asta per il Condottiero di %s (difensore)." % Data.CITY_NAME[def], "war")
	var rd = await _bidding(starter, "", "condo", "inf", 0, ca, false)
	var cd: int = rd.winner
	if cd >= 0:
		var paid2 := pay_bid(cd, rd.price, "inf", "condo")
		say("%s è il Condottiero di %s (paga %d Influenza)." % [pname(cd), Data.CITY_NAME[def], paid2], "war")
	else:
		say("Nessun Condottiero per %s." % Data.CITY_NAME[def], "war")
	war.cd = cd
	if negotiation:
		await _settle(func(x): return x.type == "condo_split" and int(x.wseq) == war_seq, func(_x): return true)
	auction = {}
	auction_changed.emit(auction)
	for p in players:
		p.passed = false
	if ca < 0 and cd < 0:
		say("Nessun Condottiero: la guerra finisce in stallo.", "war")
		war = {}
		war_changed.emit(war)
		changed.emit()
		return
	if ca >= 0:
		players[ca].home_gold += status[att]
		say("%s riceverà %d Oro a %s a fine Decade." % [pname(ca), status[att], Data.FAMILIES[players[ca].family].home])
	if cd >= 0:
		players[cd].home_gold += status[def]
		say("%s riceverà %d Oro a %s a fine Decade." % [pname(cd), status[def], Data.FAMILIES[players[cd].family].home])
	for p in players:
		if p.is_ai and p.ai:
			p.ai.observe_condo(war.duplicate(), ra, rd)
	# Lega Santa
	if pope_holder >= 0 and pope_holder != ca and pope_holder != cd and not players[pope_holder].used.has("holy") and not players[pope_holder].troops.is_empty():
		war.phase = "holy"
		war_changed.emit(war)
		if negotiation:
			for cpid in [ca, cd]:
				if cpid < 0:
					continue
				var hdeal = null
				if players[cpid].is_ai:
					hdeal = players[cpid].ai.plan_holy_deal(war.duplicate(), "att" if cpid == ca else "def")
				else:
					hdeal = await ask(cpid, "holy_offer", {"war": war.duplicate(), "side": "att" if cpid == ca else "def", "pope": pope_holder})
				if typeof(hdeal) == TYPE_DICTIONARY:
					hdeal["from"] = cpid
					hdeal["to"] = pope_holder
					hdeal["type"] = "holy"
					hdeal["side"] = "att" if cpid == ca else "def"
					hdeal["wseq"] = war_seq
					await propose(hdeal)
		var hdeals: Array = deals.filter(func(x): return x.type == "holy" and x.wseq == war_seq and x.status == "active")
		var r = await ask(pope_holder, "holy", {"war": war.duplicate(), "deals": hdeals})
		var side := str(r)
		if side == "att" or side == "def":
			war.ally = pope_holder
			war.ally_side = side
			players[pope_holder].used["holy"] = true
			say("Il Papa (%s) forma la Lega Santa a fianco di %s!" % [pname(pope_holder), Data.CITY_NAME[att if side == "att" else def]], "war")
		await _settle_holy(war_seq, war.ally_side if war.ally >= 0 else "")
	# Corrompere Truppe: attaccante, difensore, Papa alleato
	war.phase = "bribe"
	war_changed.emit(war)
	if deal_on("card_req"):
		await _offer_round("card_req", {"war": war.duplicate(), "wseq": war_seq, "holders": [ca, cd, war.ally]}, [])
	for pid in [ca, cd, war.ally]:
		if pid < 0:
			continue
		while "corrompi_truppe" in players[pid].treach:
			var targets := bribe_targets()
			if targets.is_empty():
				break
			var bdeals: Array = deals.filter(func(x): return x.status == "active" and x.type == "card_req" and x.card == "corrompi_truppe" and int(x.to) == pid and int(x.wseq) == war_seq)
			var r = await ask(pid, "bribe", {"war": war.duplicate(), "targets": targets, "deals": bdeals})
			var ti := int(r) if r != null else -1
			if ti < 0 or ti >= targets.size():
				break
			var tg = targets[ti]
			players[pid].treach.erase("corrompi_truppe")
			discards.append("corrompi_truppe")
			war.bribed.append([tg[0], tg[1]])
			for x in deals:
				if x.status == "active" and x.type == "card_req" and x.card == "corrompi_truppe" and int(x.to) == pid and int(x.wseq) == war_seq and int(x.victim) == int(tg[0]):
					x["done"] = true
			say("%s corrompe le truppe di %s: %s non combatte!" % [pname(pid), pname(tg[0]), Data.TROOPS[tg[1]].name], "treach")
			_notify_ai_hostile(pid, tg[0], 0.7)
			war_changed.emit(war)
			changed.emit()
	# Maltempo: chiunque lo possieda, in ordine dal giocatore di turno
	for pid in order_from(starter):
		while "maltempo" in players[pid].treach:
			var mdeals: Array = deals.filter(func(x): return x.status == "active" and x.type == "card_req" and x.card == "maltempo" and int(x.to) == pid and int(x.wseq) == war_seq)
			var r = await ask(pid, "maltempo", {"war": war.duplicate(), "deals": mdeals})
			var s2 := str(r)
			if s2 != "att" and s2 != "def":
				break
			players[pid].treach.erase("maltempo")
			discards.append("maltempo")
			if s2 == "att":
				war.mal_att += 1
			else:
				war.mal_def += 1
			say("%s gioca «Maltempo»: -1 a %s per questa guerra." % [pname(pid), Data.CITY_NAME[att if s2 == "att" else def]], "treach")
			for x in deals:
				if x.status == "active" and x.type == "card_req" and x.card == "maltempo" and int(x.to) == pid and int(x.wseq) == war_seq and x.city == (att if s2 == "att" else def):
					x["done"] = true
			war_changed.emit(war)
	if negotiation:
		await _settle(func(x): return x.type == "card_req" and int(x.wseq) == war_seq, func(x):
			if x.get("done", false):
				return true
			x["_why"] = "non gioca la carta promessa (%s)" % ("Maltempo" if x.card == "maltempo" else "Corrompere Truppe")
			return false)
	await _battle()
	war = {}
	war_changed.emit(war)
	changed.emit()

## Probabilità esatte dei risultati di una guerra con la configurazione attuale
func war_odds(w: Dictionary) -> Dictionary:
	var a_att := side_strength(w, "att", "att")
	var d_def := side_strength(w, "def", "def")
	var d_att := side_strength(w, "def", "att")
	var a_def := side_strength(w, "att", "def")
	var cw := 0.0
	for x in range(1, 7):
		for y in range(1, 7):
			if d_att + x > a_def + y:
				cw += 1.0
	cw /= 36.0
	var pa := 0.0
	for x in range(1, 7):
		for y in range(1, 7):
			if a_att + x > d_def + y:
				pa += 1.0
	pa /= 36.0
	var pd := (1.0 - pa) * cw
	return {"att": pa, "def": pd, "draw": 1.0 - pa - pd}

func bribe_targets() -> Array:
	var t: Array = []
	for pid in [war.ca, war.cd, war.ally]:
		if pid < 0:
			continue
		for tr in players[pid].troops:
			if not _is_bribed(pid, tr):
				t.append([pid, tr])
	return t

func _is_bribed(pid: int, tr: String) -> bool:
	for b in war.get("bribed", []):
		if b[0] == pid and b[1] == tr:
			return true
	return false

## Forza di un lato. side = "att"/"def" (città), mode = "att"/"def" (valore usato)
func side_strength(w: Dictionary, side: String, mode: String) -> int:
	var pid: int = w.ca if side == "att" else w.cd
	var s := 0
	if pid < 0:
		s = 3
	else:
		s = condo_strength(pid, mode, w.get("bribed", []))
	if w.get("ally", -1) >= 0 and w.get("ally_side", "") == side:
		for tr in players[w.ally].troops:
			if not _bribed_in(w, w.ally, tr):
				s += Data.TROOPS[tr][mode]
	s -= int(w.get("mal_att", 0)) if side == "att" else int(w.get("mal_def", 0))
	return s

func _bribed_in(w: Dictionary, pid: int, tr: String) -> bool:
	for b in w.get("bribed", []):
		if b[0] == pid and b[1] == tr:
			return true
	return false

func condo_strength(pid: int, mode: String, bribed: Array, troops_override = null) -> int:
	var troops: Array = troops_override if troops_override != null else players[pid].troops
	var act: Array = []
	for tr in troops:
		var b := false
		for x in bribed:
			if x[0] == pid and x[1] == tr:
				b = true
		if not b:
			act.append(tr)
	var s := 0
	for tr in act:
		s += Data.TROOPS[tr][mode]
	var owned := not troops.is_empty()
	if mode == "att":
		if "cavalleria" in act and owns_ability(pid, "cav_att1"):
			s += 1
		if "picchieri" in act and owns_ability(pid, "pike_ad1"):
			s += 1
		if "fanteria" in act and owns_ability(pid, "li_ad1"):
			s += 1
	else:
		if owned and owns_ability(pid, "def2"):
			s += 2
		if "balestrieri" in act and owns_ability(pid, "cross_def1"):
			s += 1
		if "picchieri" in act and owns_ability(pid, "pike_ad1"):
			s += 1
		if "fanteria" in act and owns_ability(pid, "li_ad1"):
			s += 1
		if owned:
			s += int(fam_ab(pid).get("def", 0))
	return s

func _roll_round(a_side: String, d_side: String, label: String) -> Dictionary:
	var sa := side_strength(war, a_side, "att")
	var sd := side_strength(war, d_side, "def")
	var da := rng.randi_range(1, 6)
	var dd := rng.randi_range(1, 6)
	var info := {"label": label, "a_side": a_side, "d_side": d_side, "sa": sa, "sd": sd, "da": da, "dd": dd, "ta": sa + da, "td": sd + dd, "rerolled": false}
	dice_rolled.emit(info)
	if ai_delay > 0.0 and is_inside_tree():
		await get_tree().create_timer(ai_delay * 2.2).timeout
	await hold()
	# Ludovico Sforza
	for p in players:
		if owns_ability(p.id, "reroll") and not p.used.has("reroll"):
			reroll_seq += 1
			var rs := reroll_seq
			await _offer_round("reroll_req", {"to": p.id, "rseq": rs, "war": war.duplicate(), "roll": info.duplicate()}, [p.id])
			var rdeals: Array = deals.filter(func(x): return x.status == "active" and x.type == "reroll_req" and int(x.rseq) == rs)
			var r = await ask(p.id, "reroll", {"war": war.duplicate(), "roll": info.duplicate(), "deals": rdeals})
			await _settle(func(x): return x.type == "reroll_req" and int(x.rseq) == rs, func(x):
				if r == true:
					return true
				x["_why"] = "non fa rilanciare i dadi come promesso"
				return false)
			if r == true:
				p.used["reroll"] = true
				da = rng.randi_range(1, 6)
				dd = rng.randi_range(1, 6)
				info.da = da
				info.dd = dd
				info.ta = sa + da
				info.td = sd + dd
				info.rerolled = true
				say("Ludovico Sforza: %s fa rilanciare i dadi!" % p.name, "treach")
				dice_rolled.emit(info)
				if ai_delay > 0.0 and is_inside_tree():
					await get_tree().create_timer(ai_delay * 2.2).timeout
				await hold()
			break
	say("%s: %s %d+%d=%d contro %s %d+%d=%d." % [label, Data.CITY_NAME[war[a_side]], sa, da, info.ta, Data.CITY_NAME[war[d_side]], sd, dd, info.td], "dice")
	return info

func _battle() -> void:
	war.phase = "battle"
	war_changed.emit(war)
	var att: String = war.att
	var def: String = war.def
	var winner_side := ""
	var decisive := false
	var r1 = await _roll_round("att", "def", "Assalto")
	if r1.ta > r1.td:
		winner_side = "att"
		decisive = r1.ta >= 2 * r1.td
	else:
		var r2 = await _roll_round("def", "att", "Contrattacco")
		if r2.ta > r2.td:
			winner_side = "def"
			decisive = r2.ta >= 2 * r2.td
	if winner_side == "":
		say("La guerra si conclude in stallo.", "war")
		war["result"] = {"winner": "", "decisive": false}
		war_changed.emit(war)
		return
	var wc: String = war[winner_side]
	var lc: String = war["def" if winner_side == "att" else "att"]
	var delta := 2 if decisive else 1
	var bw: int = status[wc]
	var bl: int = status[lc]
	status[wc] = min(Data.STATUS_MAX, status[wc] + delta)
	status[lc] = max(Data.STATUS_MIN, status[lc] - delta)
	var wp: int = war.ca if winner_side == "att" else war.cd
	say("%s vince%s! %s %d→%d, %s %d→%d." % [Data.CITY_NAME[wc], " in modo schiacciante" if decisive else "", Data.CITY_NAME[wc], bw, status[wc], Data.CITY_NAME[lc], bl, status[lc]], "important")
	if wp >= 0:
		players[wp].vp_counters += 1
		say("%s ottiene una pedina Vittoria (totale %d)." % [pname(wp), players[wp].vp_counters], "war")
	war["result"] = {"winner": winner_side, "decisive": decisive}
	war_changed.emit(war)
	if ai_delay > 0.0 and is_inside_tree():
		await get_tree().create_timer(ai_delay * 2.0).timeout
	await hold()

# ------------------------------------------------------------------ punteggio

## Classifica delle città: ritorna {città: PV per tessera}
func city_ranking(ask_ties := false) -> Dictionary:
	var cs: Array = Data.CITIES.duplicate()
	cs.sort_custom(func(a, b):
		if status[a] != status[b]:
			return status[a] > status[b]
		return artists[a] > artists[b])
	return _rank_values(cs, null)

func _rank_values(sorted_cities: Array, custom_order) -> Dictionary:
	var out := {}
	var i := 0
	while i < sorted_cities.size():
		var j := i
		while j + 1 < sorted_cities.size() and status[sorted_cities[j + 1]] == status[sorted_cities[i]] and artists[sorted_cities[j + 1]] == artists[sorted_cities[i]]:
			j += 1
		if custom_order != null and j > i:
			var grp: Array = custom_order.slice(i, j + 1)
			for k in grp.size():
				out[grp[k]] = Data.VP_RANK[i + k]
		else:
			for k in range(i, j + 1):
				out[sorted_cities[k]] = Data.VP_RANK[j]
		i = j + 1
	return out

func final_scoring() -> Array:
	say("—— FINE DELLA PARTITA: calcolo dei Punti Vittoria ——", "decade")
	var cs: Array = Data.CITIES.duplicate()
	cs.sort_custom(func(a, b):
		if status[a] != status[b]:
			return status[a] > status[b]
		return artists[a] > artists[b])
	var ranking := _rank_values(cs, null)
	# Bentivoglio (lato A) decide le parità
	var benti := -1
	for p in players:
		if p.family == "bentivoglio" and p.side == "A":
			benti = p.id
	if benti >= 0:
		var has_tie := false
		for k in range(cs.size() - 1):
			if status[cs[k]] == status[cs[k + 1]] and artists[cs[k]] == artists[cs[k + 1]]:
				has_tie = true
		if has_tie:
			var tied: Array = []
			for k in cs.size():
				var tie: bool = (k > 0 and status[cs[k]] == status[cs[k - 1]] and artists[cs[k]] == artists[cs[k - 1]]) or (k < cs.size() - 1 and status[cs[k]] == status[cs[k + 1]] and artists[cs[k]] == artists[cs[k + 1]])
				if tie:
					tied.append(cs[k])
			await _offer_round("ties_req", {"to": benti, "order": cs.duplicate(), "tied": tied}, [benti])
			var tdeals: Array = deals.filter(func(x): return x.status == "active" and x.type == "ties_req")
			var r = await ask(benti, "artist_ties", {"order": cs.duplicate(), "deals": tdeals})
			if typeof(r) == TYPE_ARRAY and r.size() == cs.size():
				# accetta solo permutazioni all'interno dei gruppi pari
				var ok := true
				for k in cs.size():
					if status[r[k]] != status[cs[k]] or artists[r[k]] != artists[cs[k]]:
						ok = false
				if ok:
					ranking = _rank_values(cs, r)
					say("%s (Bentivoglio) decide le parità tra le città." % pname(benti))
					await _settle(func(x): return x.type == "ties_req", func(x):
						# la città richiesta deve essere la prima del suo gruppo di parità
						var idx: int = r.find(x.city)
						if idx >= 0 and (idx == 0 or status[r[idx - 1]] != status[x.city] or artists[r[idx - 1]] != artists[x.city]):
							return true
						x["_why"] = "non fa vincere lo spareggio a %s" % _cityn(x.city)
						return false)
			if negotiation:
				await _settle(func(x): return x.type == "ties_req", func(x):
					x["_why"] = "non decide lo spareggio come promesso"
					return false)
	var res: Array = []
	var golds: Array = []
	for p in players:
		golds.append(p.gold)
	var maxg: int = golds.max()
	var second := -1
	for g in golds:
		if g < maxg and g > second:
			second = g
	var maxi := -1
	for p in players:
		maxi = max(maxi, p.inf)
	for p in players:
		var b := {"pid": p.id, "name": p.name, "family": p.family}
		var cv := 0
		var merch := 0
		for t in p.cities:
			cv += ranking[Data.city_tile(t).city]
			if Data.city_tile(t).get("merchant", false):
				merch += 1
		b["cities"] = cv
		var byc := {}
		for c in Data.CITIES:
			var ts: Array = p.cities.filter(func(t): return Data.city_tile(t).city == c)
			byc[c] = {"tiles": ts, "per": int(ranking[c]), "pts": ts.size() * int(ranking[c])}
		b["by_city"] = byc
		var ev_items: Array = []
		var ev := 0
		var vini := 0
		for e in p.events:
			var d := Data.event(e)
			if d.kind == "vp":
				ev += int(d.value)
				ev_items.append({"id": e, "pts": int(d.value)})
			elif d.kind == "merchant":
				vini += 1
		b["events"] = ev
		b["ev_items"] = ev_items
		b["vini"] = vini
		b["merch_tiles"] = merch
		b["counters_n"] = p.vp_counters
		b["merchants"] = vini * merch
		b["pope"] = 3 if pope_holder == p.id else 0
		b["gold"] = 6 if p.gold == maxg else (3 if p.gold == second else 0)
		b["inf"] = 4 if p.inf == maxi else 0
		b["counters"] = Data.tri(p.vp_counters)
		b["total"] = b.cities + b.events + b.merchants + b.pope + b.gold + b.inf + b.counters
		b["gold_left"] = p.gold
		b["inf_left"] = p.inf
		res.append(b)
	res.sort_custom(func(a, b2): return a.total > b2.total)
	var order: Array = Data.CITIES.duplicate()
	order.sort_custom(func(a, b3):
		if ranking[a] != ranking[b3]:
			return ranking[a] > ranking[b3]
		return status[a] > status[b3])
	final_order = order
	final_ranking = ranking
	var ranktxt := []
	for c in cs:
		ranktxt.append("%s %d PV" % [Data.CITY_NAME[c], ranking[c]])
	say("Valore delle città: " + ", ".join(ranktxt), "important")
	for b in res:
		say("%s: %d PV" % [b.name, b.total], "important")
	return res

## Punteggio provvisorio (se la partita finisse ora) — usato da GUI e IA
func provisional_score(pid: int) -> int:
	var ranking := city_ranking()
	var p = players[pid]
	var v := 0
	var merch := 0
	for t in p.cities:
		v += ranking[Data.city_tile(t).city]
		if Data.city_tile(t).get("merchant", false):
			merch += 1
	for e in p.events:
		var d := Data.event(e)
		if d.kind == "vp":
			v += int(d.value)
		elif d.kind == "merchant":
			v += merch
	v += Data.tri(p.vp_counters)
	if pope_holder == pid and decade == 3:
		v += 3
	return v
