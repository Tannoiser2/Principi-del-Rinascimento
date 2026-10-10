class_name AIBrain
extends RefCounted
## Intelligenza artificiale per Principi del Rinascimento.
##
## Idee principali:
##  * Tutto viene valutato in "Punti Vittoria attesi" (PV). Oro e Influenza vengono
##    convertiti con un tasso che cambia nel corso della partita.
##  * Il valore finale delle città è stimato con una simulazione Monte Carlo dello
##    Status (numeri casuali comuni → confronti stabili tra scenari).
##  * Ogni decisione considera anche il guadagno degli avversari (soprattutto del
##    leader): l'IA nega, spinge i prezzi, colpisce chi è in testa.
##  * Bluff: rilanci "di spinta" oltre il proprio valore quando stima che il rivale
##    pagherà comunque di più; salti d'offerta per mettersi al riparo dal «Congelare».
##  * Controbluff: un modello per ogni avversario registra quanto spesso spinge senza
##    volere davvero il lotto, quanto paga oltre il valore stimato e quanto è ostile.

var g: GameEngine
var me := 0
var level := 1          # 0 = Facile, 1 = Normale, 2 = Machiavelli
var rng := RandomNumberGenerator.new()
var traits := {}
var opp := {}           # pid -> modello
var _mc_noise: Array = []
var _noise_key := ""
var _ev_cache := {}
var _cur_est := {}      # stime correnti nell'asta in corso
var _auction_plan := {}
var _last_exchange_turn := -1
var _plan_max := {}     # massimo che sono disposto a pagare per un accordo proposto

const SAMPLES := 220

## parametri per livello (sovrascrivibili per i test)
var prm := {}
const LEVEL_PRM := [
	{"noise": 1.6, "lead_w": 0.0, "opp_base": 0.3, "deny": 0.0, "bluff_lo": 0.0, "bluff_hi": 0.0, "freeze_p": 0.25, "drain": 0.0, "R": [3.0, 2.6, 2.0], "Ri_scale": 1.0, "deal_p": 0.0, "honesty": 99.0},
	{"noise": 0.55, "lead_w": 0.1, "opp_base": 0.6, "deny": 0.05, "bluff_lo": 0.05, "bluff_hi": 0.2, "freeze_p": 0.5, "drain": 0.0, "R": [2.6, 3.0, 3.8], "Ri_scale": 1.1, "deal_p": 0.6, "honesty": 6.0},
	# Machiavelli: parametri tarati con simulazioni IA contro IA
	{"noise": 0.3, "lead_w": 0.15, "opp_base": 0.45, "deny": 0.1, "bluff_lo": 0.15, "bluff_hi": 0.35, "freeze_p": 0.7, "drain": 0.0, "R": [2.4, 3.0, 4.5], "Ri_scale": 1.2, "deal_p": 0.9, "honesty": 2.2, "turn_deal_p": 0.4},
]

func setup(engine: GameEngine, pid: int, lvl: int, seed: int, overrides := {}) -> void:
	g = engine
	me = pid
	level = lvl
	rng.seed = seed
	prm = LEVEL_PRM[clampi(lvl, 0, 2)].duplicate()
	for k in overrides:
		prm[k] = overrides[k]
	traits = {
		"greed": rng.randf_range(0.93, 1.12),
		"bluff": rng.randf_range(prm.bluff_lo, prm.bluff_hi),
		"aggr": rng.randf_range(0.8, 1.35),
		"vengeance": rng.randf_range(0.2, 0.8),
		"patience": rng.randf_range(0.0, 0.35),
	}
	for p in g.players:
		if p.id != pid:
			opp[p.id] = {"push": 0.0, "overpay": 0.0, "aggr": 1.0, "host": 0.0, "n": 0}

# =============================================================== utilità

func P(pid: int) -> Dictionary:
	return g.players[pid]

func noise_sd() -> float:
	return prm.noise

func n_inc() -> int:
	return 4 - g.decade

func R() -> float:
	return prm.get("R", [3.0, 2.6, 2.0])[g.decade - 1]

func Ri(pid: int) -> float:
	var p := P(pid)
	var r := 1.25
	if p.inf < 8:
		r = 1.6
	elif p.inf > 25:
		r = 0.95
	if g.decade == 3:
		r *= 0.8
	return r * float(prm.get("Ri_scale", 1.0))

func wars_left() -> int:
	return (g.war_limit - g.wars_fought) + (3 - g.decade) * g.war_limit

func others() -> Array:
	var o: Array = []
	for p in g.players:
		if p.id != me:
			o.append(p.id)
	return o

# --------------------------------------------------------------- Monte Carlo città

func _ensure_noise() -> void:
	var key := "%d_%d" % [g.decade, g.wars_fought]
	if key == _noise_key:
		return
	_noise_key = key
	_ev_cache.clear()
	var r := RandomNumberGenerator.new()
	r.seed = 1234 + g.decade * 17 + g.wars_fought
	var wl := float(wars_left())
	var sta_left := 0
	for d in range(g.decade, 4):
		for e in g.events_by_decade[d]:
			if Data.event(e).kind == "sta" and (d > g.decade or e in g.event_pool):
				sta_left += 1
	var sd := sqrt(wl * 0.4 * 1.5) * 0.85 + sta_left * 0.12 + 0.15
	_mc_noise.clear()
	for s in SAMPLES:
		var row := {}
		for c in Data.CITIES:
			row[c] = r.randfn(0.0, sd)
		_mc_noise.append(row)

## Valore atteso in PV di una tessera per ogni città, dato uno Status
func city_ev(st: Dictionary, art: Dictionary) -> Dictionary:
	_ensure_noise()
	var key := ""
	for c in Data.CITIES:
		key += "%d.%d," % [st[c], art[c]]
	if _ev_cache.has(key):
		return _ev_cache[key]
	var acc := {}
	for c in Data.CITIES:
		acc[c] = 0.0
	for row in _mc_noise:
		var vals: Array = []
		for c in Data.CITIES:
			var v: float = clampf(st[c] + row[c], 3.0, 10.0) + art[c] * 0.05
			vals.append([v, c])
		vals.sort_custom(func(a, b): return a[0] > b[0])
		for k in 5:
			acc[vals[k][1]] += Data.VP_RANK[k]
	var out := {}
	for c in Data.CITIES:
		out[c] = acc[c] / float(SAMPLES)
	_ev_cache[key] = out
	return out

func ev_now() -> Dictionary:
	return city_ev(g.status, g.artists)

func ev_with(changes: Dictionary, art_changes := {}) -> Dictionary:
	var st := g.status.duplicate()
	var ar := g.artists.duplicate()
	for c in changes:
		st[c] = clampi(st[c] + changes[c], Data.STATUS_MIN, Data.STATUS_MAX)
	for c in art_changes:
		ar[c] += art_changes[c]
	return city_ev(st, ar)

func city_count(pid: int, c: String) -> int:
	var n := 0
	for t in P(pid).cities:
		if Data.city_tile(t).city == c:
			n += 1
	return n

func merch_count(pid: int) -> int:
	var n := 0
	for t in P(pid).cities:
		if Data.city_tile(t).get("merchant", false):
			n += 1
	return n

func vini_count(pid: int) -> int:
	var n := 0
	for e in P(pid).events:
		if Data.event(e).kind == "merchant":
			n += 1
	return n

func vini_remaining() -> int:
	var n := 0
	for d in range(g.decade, 4):
		for e in g.events_by_decade[d]:
			if Data.event(e).kind == "merchant" and (d > g.decade or e in g.event_pool):
				n += 1
	return n

## Δ PV (sulle città) di un giocatore per un cambio di valori città
func city_delta(pid: int, ev0: Dictionary, ev1: Dictionary) -> float:
	var d := 0.0
	for t in P(pid).cities:
		var c: String = Data.city_tile(t).city
		d += ev1[c] - ev0[c]
	return d

## Proiezione dei PV finali di un giocatore
func projection(pid: int) -> float:
	var p := P(pid)
	var ev := ev_now()
	var v := 0.0
	for t in p.cities:
		v += ev[Data.city_tile(t).city]
	for e in p.events:
		var d := Data.event(e)
		if d.kind == "vp":
			v += d.value
	v += vini_count(pid) * merch_count(pid)
	v += Data.tri(p.vp_counters)
	if g.pope_holder == pid and g.decade == 3:
		v += 3
	var inc := g.income_of(pid)
	var future_g: float = p.gold + inc.gold * n_inc()
	var future_i: float = p.inf + inc.inf * n_inc()
	v += future_g / R() * 0.55 + future_i * Ri(pid) / R() * 0.45
	return v

## Peso con cui considero il guadagno di un avversario (il leader pesa di più)
var _wts_cache = null

func opp_weights() -> Dictionary:
	if _wts_cache != null:
		return _wts_cache
	var w := {}
	var projs := {}
	var best := -1
	var bestv := -1e9
	var mine := projection(me)
	for q in others():
		projs[q] = projection(q)
		if projs[q] > bestv:
			bestv = projs[q]
			best = q
	var n := float(max(1, others().size()))
	for q in others():
		var base: float = prm.opp_base / n
		if q == best:
			base += prm.lead_w
			if bestv < mine - 4:
				base *= 0.7
		base += 0.08 * min(3.0, opp[q].host) * traits.vengeance
		w[q] = base
	_wts_cache = w
	return w

func leader() -> int:
	var best := -1
	var bestv := -1e9
	for q in others():
		var v := projection(q)
		if v > bestv:
			bestv = v
			best = q
	return best

# =============================================================== valutazione oggetti

func war_factor() -> float:
	return clampf(wars_left() / 8.0, 0.15, 1.2)

func has_troop(pid: int, t: String) -> bool:
	return t in P(pid).troops

func ability_value(pid: int, ab: String) -> float:
	var ni := n_inc()
	var wf := war_factor()
	var troops: bool = not P(pid).troops.is_empty()
	match ab:
		"def2": return (1.0 if troops else 0.4) * wf
		"reroll": return 0.35 * ni
		"cav_att1": return (0.6 if has_troop(pid, "cavalleria") else 0.15) * wf
		"condo_disc1": return 0.25 * ni * (1.0 if troops else 0.4)
		"cross_def1": return (0.5 if has_troop(pid, "balestrieri") else 0.12) * wf
		"pike_ad1": return (0.8 if has_troop(pid, "picchieri") else 0.2) * wf
		"li_ad1": return (0.8 if has_troop(pid, "fanteria") else 0.2) * wf
		"treach_limit1": return 0.25
		"free_treach": return 0.5 * ni
		"pope_disc1": return 0.25 * ni
		"steal_inf": return (2.0 * Ri(pid) / R() + 0.25) * ni
		"bank": return 0.3 * ni
		"veto": return 0.55 * ni
	return 0.0

## valore (PV) di una tessera Città per un giocatore
func tile_value(pid: int, tile: String) -> float:
	if not g.can_hold_city(pid, tile):
		return -99.0
	var d := Data.city_tile(tile)
	var ev := ev_now()
	var c: String = d.city
	var v: float = ev[c]
	var ni := n_inc()
	v += d.gold * ni / R() + d.inf * ni * Ri(pid) / R()
	if d.get("merchant", false):
		v += vini_count(pid) * (1.0 + ni / R())
		v += vini_remaining() * 0.35
	for ab in d.ab:
		v += ability_value(pid, ab)
	var cs := g.player_city_set(pid)
	if not c in cs and cs.size() == 2:
		v -= 0.7
	if P(pid).cities.size() == 5:
		v -= 0.4
	# concentrazione: più tessere nella stessa città = più interesse a guidarla
	v += 0.15 * city_count(pid, c)
	return v

func best_sta_city(pid: int) -> Array:
	var ev0 := ev_now()
	var w := opp_weights() if pid == me else {}
	var best := ""
	var bestv := -1e9
	for c in Data.CITIES:
		if g.status[c] >= Data.STATUS_MAX and g.artists[c] > 3:
			continue
		var ev1 := ev_with({c: 1}, {c: 1})
		var v := city_delta(pid, ev0, ev1)
		if pid == me:
			for q in w:
				v -= w[q] * city_delta(q, ev0, ev1)
		if v > bestv:
			bestv = v
			best = c
	return [best, bestv]

func best_french_city(pid: int) -> Array:
	var ev0 := ev_now()
	var w := opp_weights() if pid == me else {}
	var best := ""
	var bestv := 0.0
	for c in Data.CITIES:
		var ev1 := ev_with({c: -2})
		var v := city_delta(pid, ev0, ev1)
		if pid == me:
			for q in w:
				v -= w[q] * city_delta(q, ev0, ev1)
		else:
			for q in g.players:
				if q.id != pid:
					v -= 0.3 * city_delta(q.id, ev0, ev1)
		if v > bestv:
			bestv = v
			best = c
	return [best, bestv]

func event_value(pid: int, item: String) -> float:
	if item == "POPE":
		var v := Data.POPE.gold / R() + 0.6 * war_factor() * (1.0 if not P(pid).troops.is_empty() else 0.3)
		if g.decade == 3:
			v += 3.0
		v += 0.3 * P(pid).treach.count("cardinale")
		return v
	var e := Data.event(item)
	match str(e.kind):
		"vp":
			return float(e.value) + 0.1
		"merchant":
			return merch_count(pid) * (1.0 + n_inc() / R()) + 0.45 * (6 - P(pid).cities.size()) * 0.3
		"sta":
			return max(0.1, best_sta_city(pid)[1]) + 0.15
		"french":
			return max(0.0, best_french_city(pid)[1])
	return 0.0

func item_value(pid: int, item: String) -> float:
	if Data.is_city_tile(item):
		return tile_value(pid, item)
	return event_value(pid, item)

## massimo che il giocatore pid sarebbe disposto a offrire (valuta dell'oggetto)
func willingness(pid: int, item: String, kind: String, cur: String, vp_value: float) -> int:
	var rate := R() if cur == "gold" else R() / Ri(pid)
	var w := vp_value * rate
	if pid == me:
		w *= traits.greed
	w += g.discount(pid, cur, kind)
	if kind == "pope":
		w += 3 * P(pid).treach.count("cardinale") * 0.6
	# Ultima Decade: considera la maggioranza di Oro/Influenza a fine partita
	if g.decade == 3 and pid == me:
		w = _cap_by_majority(cur, w, vp_value, rate)
	return int(floor(w))

func _final_money(pid: int, cur: String) -> int:
	var inc := g.income_of(pid)
	return P(pid).gold + inc.gold if cur == "gold" else P(pid).inf + inc.inf

func majority_vp(cur: String, spend: int) -> float:
	var mine := _final_money(me, cur) - spend
	var vals: Array = []
	for q in others():
		vals.append(_final_money(q, cur))
	var mx: int = vals.max() if not vals.is_empty() else 0
	if cur == "gold":
		if mine >= mx:
			return 6.0
		var second := -1
		for v in vals:
			if v > second and v != mx:
				second = v
		if mine >= second:
			return 3.0
		return 0.0
	return 4.0 if mine >= mx else 0.0

func _cap_by_majority(cur: String, w: float, vp_value: float, rate: float) -> float:
	var base := majority_vp(cur, 0)
	var x := 0
	var best := 0
	while x <= int(w) + 1:
		var loss := base - majority_vp(cur, max(0, x - g.discount(me, cur, "event")))
		var net := vp_value - x / rate - loss
		if net >= 0:
			best = x
		x += 1
	return float(best)

# --------------------------------------------------------------- guerre: probabilità

## Probabilità dei risultati di una guerra
## ritorna {"aw":p vittoria att 1 livello,"aW":decisiva,"dw","dW","draw"}
func war_probs(a_att: int, d_def: int, d_att: int, a_def: int) -> Dictionary:
	var r := {"aw": 0.0, "aW": 0.0, "dw": 0.0, "dW": 0.0, "draw": 0.0}
	var p_cnt := 0.0
	var counter := _counter_probs(d_att, a_def)
	for x in range(1, 7):
		for y in range(1, 7):
			var ta := a_att + x
			var td := d_def + y
			if ta > td:
				if ta >= 2 * td:
					r.aW += 1.0 / 36.0
				else:
					r.aw += 1.0 / 36.0
			else:
				r.dw += counter.w / 36.0
				r.dW += counter.W / 36.0
				r.draw += counter.d / 36.0
	return r

func _counter_probs(att: int, def: int) -> Dictionary:
	var w := 0.0
	var W := 0.0
	var d := 0.0
	for x in range(1, 7):
		for y in range(1, 7):
			var ta := att + x
			var td := def + y
			if ta > td:
				if ta >= 2 * td:
					W += 1.0
				else:
					w += 1.0
			else:
				d += 1.0
	return {"w": w / 36.0, "W": W / 36.0, "d": d / 36.0}

func strength_of(pid: int, mode: String, bribed := []) -> int:
	if pid < 0:
		return 3
	return g.condo_strength(pid, mode, bribed)

## Valore atteso (per pid, ponderato sugli avversari se pid == me) di una guerra
## con Condottieri ca/cd (-1 = neutrale)
func war_outcome_value(pid: int, att: String, def: String, w: Dictionary, include_others := true) -> Dictionary:
	var sa_att := g.side_strength(w, "att", "att")
	var sd_def := g.side_strength(w, "def", "def")
	var sd_att := g.side_strength(w, "def", "att")
	var sa_def := g.side_strength(w, "att", "def")
	var pr := war_probs(sa_att, sd_def, sd_att, sa_def)
	var ev0 := ev_now()
	var outs := {
		"aw": ev_with({att: 1, def: -1}), "aW": ev_with({att: 2, def: -2}),
		"dw": ev_with({def: 1, att: -1}), "dW": ev_with({def: 2, att: -2})}
	var val := 0.0
	var wts := opp_weights() if (pid == me and include_others) else {}
	for k in outs:
		var d := city_delta(pid, ev0, outs[k])
		for q in wts:
			d -= wts[q] * city_delta(q, ev0, outs[k])
		val += pr[k] * d
	# pedine Vittoria
	var p_att_win: float = pr.aw + pr.aW
	var p_def_win: float = pr.dw + pr.dW
	if w.ca == pid:
		val += p_att_win * (P(pid).vp_counters + 1)
	if w.cd == pid:
		val += p_def_win * (P(pid).vp_counters + 1)
	for q in wts:
		if w.ca == q:
			val -= wts[q] * p_att_win * (P(q).vp_counters + 1)
		if w.cd == q:
			val -= wts[q] * p_def_win * (P(q).vp_counters + 1)
	return {"value": val, "p_att": p_att_win, "p_def": p_def_win, "probs": pr}

func _war_dict(att: String, def: String, ca: int, cd: int) -> Dictionary:
	return {"att": att, "def": def, "ca": ca, "cd": cd, "ally": -1, "ally_side": "", "bribed": [], "mal_att": 0, "mal_def": 0}

## valore di diventare condottiero per una parte (pid generico)
func condo_value(pid: int, side: String, w: Dictionary) -> float:
	var att: String = w.att
	var def: String = w.def
	var city: String = att if side == "att" else def
	var pay: float = g.status[city] / R()
	var w_with := w.duplicate(true)
	var w_without := w.duplicate(true)
	if side == "att":
		w_with.ca = pid
		w_without.ca = _likely_other_condo(pid, "att", w)
	else:
		w_with.cd = pid
		w_without.cd = _likely_other_condo(pid, "def", w)
	if side == "att" and w_with.cd < 0:
		# difensore non ancora noto: stima
		w_with.cd = _likely_other_condo(pid, "def", w_with)
		w_without.cd = _likely_other_condo(w_without.ca, "def", w_without) if w_without.ca >= 0 else _likely_other_condo(-9, "def", w_without)
	var with_v := war_outcome_value(pid, att, def, w_with, pid == me)
	var without_v := war_outcome_value(pid, att, def, w_without, pid == me)
	return pay + with_v.value - without_v.value

func _likely_other_condo(excl: int, side: String, w: Dictionary) -> int:
	var best := -1
	var bestv := -1
	for p in g.players:
		if p.id == excl or p.id == w.get("ca", -1) or p.troops.is_empty():
			continue
		var s := g.condo_strength(p.id, "att", []) + g.condo_strength(p.id, "def", [])
		s += int(p.inf / 4)
		if s > bestv:
			bestv = s
			best = p.id
	return best

## Valore complessivo (per me) di dichiarare una guerra att->def
func war_declare_value(att: String, def: String) -> float:
	var w := _war_dict(att, def, -1, -1)
	# chi diventerà condottiero? stimiamo con il valore che ognuno ne ricava
	var best_a := -1
	var best_av := 0.0
	for p in g.players:
		if p.troops.is_empty():
			continue
		var v: float = condo_value(p.id, "att", w) * (traits.greed if p.id == me else 1.0)
		if v > best_av:
			best_av = v
			best_a = p.id
	w.ca = best_a
	var best_d := -1
	var best_dv := 0.0
	for p in g.players:
		if p.troops.is_empty() or p.id == best_a:
			continue
		var v2 := condo_value(p.id, "def", w)
		if v2 > best_dv:
			best_dv = v2
			best_d = p.id
	w.cd = best_d
	var res := war_outcome_value(me, att, def, w)
	var v3: float = res.value
	if w.ca == me:
		v3 += g.status[att] / R() - 2.0 * Ri(me) / R()
	if w.cd == me:
		v3 += g.status[def] / R() - 2.0 * Ri(me) / R()
	# il rischio di veto riduce il valore
	var veto_risk := 0.0
	for q in others():
		if g.owns_ability(q, "veto") and not P(q).used.has("veto"):
			veto_risk += 0.3
		veto_risk += 0.05 * P(q).treach.size()
	v3 *= (1.0 - clampf(veto_risk, 0.0, 0.6) * 0.5)
	return v3 * traits.aggr

# --------------------------------------------------------------- truppe e tradimenti

func troop_value(pid: int, t: String) -> float:
	var d: Dictionary = Data.TROOPS[t]
	var p := P(pid)
	var wl := float(wars_left())
	var a0 := g.condo_strength(pid, "att", [])
	var d0 := g.condo_strength(pid, "def", [])
	var tr2: Array = p.troops.duplicate()
	tr2.append(t)
	var a1 := g.condo_strength(pid, "att", [], tr2)
	var d1 := g.condo_strength(pid, "def", [], tr2)
	var gain := (a1 - a0) + (d1 - d0)
	var per := 0.055 * wl
	if a0 + d0 >= 12:
		per *= 0.5
	var v := gain * per
	if p.troops.is_empty():
		v += 0.12 * wl
	v += d.inf * n_inc() * Ri(pid) / R()
	return v

func treach_card_value(card: String) -> float:
	match card:
		"congela": return 1.1
		"corrompi_truppe": return 0.8 if not P(me).troops.is_empty() else 0.45
		"maltempo": return 0.7
		"ruba_oro": return 3.0 / R() + 0.4
		"ruba_inf": return 2.0 * Ri(me) / R() + 0.3
		"veto": return 1.2
		"cardinale": return 0.9 if g.pope_available else 0.4
		"inizia_guerra": return 0.9 * traits.aggr
	return 0.5

# =============================================================== decisioni

var _oblig: Array = []

func decide(kind: String, ctx: Dictionary):
	_wts_cache = null
	_oblig = g.obligations_of(me) if g.negotiation else []
	match kind:
		"turn": return decide_turn(ctx)
		"bid": return decide_bid(ctx)
		"condo_bid": return decide_condo_bid(ctx)
		"veto": return decide_veto(ctx)
		"holy": return decide_holy(ctx)
		"bribe": return decide_bribe(ctx)
		"maltempo": return decide_maltempo(ctx)
		"reroll": return decide_reroll(ctx)
		"place_sta": return decide_place_sta(ctx)
		"french": return decide_french(ctx)
		"keep_treach": return decide_keep(ctx)
		"discard_treach": return decide_discard(ctx)
		"start_war_card": return decide_start_war_card(ctx)
		"baglioni_cur": return "gold" if P(me).gold < P(me).inf * 2 else "inf"
		"artist_ties": return decide_artist_ties(ctx)
		"deal_offer": return decide_deal_offer(ctx)
		"deal_counter": return decide_deal_counter(ctx)
		"deal_pay": return decide_deal_pay(ctx)
	return null

func _noise() -> float:
	return rng.randfn(0.0, noise_sd())

# --------------------------------------------------------------- turno

func decide_turn(opts: Dictionary) -> Dictionary:
	var p := P(me)
	# 1) azioni gratuite
	for f in opts.free:
		match str(f.what):
			"free_treach":
				return {"type": "free", "what": "free_treach", "src": f.src}
			"ruba_oro":
				var t := _steal_target("gold")
				if t >= 0 and P(t).gold >= 2:
					return {"type": "free", "what": "ruba_oro", "target": t}
			"ruba_inf":
				var t2 := _steal_target("inf")
				if t2 >= 0 and P(t2).inf >= 2:
					return {"type": "free", "what": "ruba_inf", "target": t2}
			"lucrezia":
				var t3 := _steal_target("inf")
				if t3 >= 0 and P(t3).inf >= 1:
					return {"type": "free", "what": "lucrezia", "target": t3}
	if g.negotiation and _last_exchange_turn != g.turn_number:
		_last_exchange_turn = g.turn_number
		var ex = plan_turn_deal(opts)
		if ex != null:
			return {"type": "free", "what": "deal", "deal": ex}
	# 2) azione principale
	var cands: Array = []   # [score, action]
	var wts := opp_weights()
	for item in opts.auction:
		var s := _auction_score(item, wts)
		for d in _oblig:
			if d.type == "auction_req" and d.item == item:
				s += _comply_value(d)
			elif d.type == "no_close" and g.event_pool.size() == 1 and item in g.event_pool:
				s -= _comply_value(d)
		cands.append([s + _noise(), {"type": "auction", "item": item}])
	for t in opts.troops:
		var s2: float = troop_value(me, t) - Data.TROOPS[t].cost / R()
		cands.append([s2 + _noise() * 0.6, {"type": "buy_troop", "troop": t}])
	if opts.treach and p.treach.size() < g.treach_limit(me):
		var s3: float = 1.05 + 0.3 * traits.bluff - (1.0 + Ri(me)) / R()
		cands.append([s3 + _noise() * 0.5, {"type": "buy_treach"}])
	if opts.war:
		var bw := _best_war()
		if bw.size() > 0:
			cands.append([bw[0] + _noise(), {"type": "war", "att": bw[1], "def": bw[2]}])
	# scartare una truppa: raramente utile (libera il tipo, nessun rimborso)
	var pass_score: float = 0.12 + traits.patience * 0.4
	if g.consecutive_passes >= g.players.size() - 1:
		pass_score -= 0.6   # evita lo stallo
	if not opts.get("must_act", false):
		cands.append([pass_score, {"type": "pass"}])
	if cands.is_empty():
		return {"type": "pass"}
	cands.sort_custom(func(a, b): return a[0] > b[0])
	var choice: Dictionary = cands[0][1]
	if choice.type == "pass" and (opts.get("must_act", false) or g.consecutive_passes >= g.players.size() * 2 - 1):
		for c in cands:
			if c[1].type == "auction" and not Data.is_city_tile(c[1].item):
				return c[1]
	return choice

func _steal_target(cur: String) -> int:
	var best := -1
	var bestv := -1e9
	var wts := opp_weights()
	for q in others():
		var amt: float = P(q).gold if cur == "gold" else P(q).inf
		var v: float = wts[q] * 3.0 + min(amt, 3.0) * 0.2
		for o in _oblig:
			if o.type == "protection" and int(o.from) == q:
				v -= _comply_value(o)
		if v > bestv:
			bestv = v
			best = q
	return best

func _auction_score(item: String, wts: Dictionary) -> float:
	var kind := g.item_kind(item)
	var cur := g.item_currency(item)
	var myv := item_value(me, item)
	var mywill := willingness(me, item, kind, cur, myv)
	var min_open := 0
	if kind == "city":
		min_open = 2 * g.status[Data.city_tile(item).city]
	var mymax := g.max_payable(me, item, cur, kind)
	# chi altro lo vuole e quanto?
	var top_other := -1
	var top_val := 0
	var second := min_open
	for q in others():
		if kind == "city" and not g.can_hold_city(q, item):
			continue
		var qv := item_value(q, item)
		var qw: int = min(_est_willingness(q, item, kind, cur, qv), g.max_payable(q, item, cur, kind))
		if qw > top_val:
			top_val = qw
			top_other = q
	second = max(second, top_val + 1)
	var rate := R() if cur == "gold" else R() / Ri(me)
	var score := 0.0
	var will: int = min(mywill, mymax)
	if will >= second:
		var price := second
		score = myv - (price - g.discount(me, cur, kind)) / rate
	elif will >= min_open and top_other < 0:
		score = myv - (min_open - g.discount(me, cur, kind)) / rate
	else:
		# lo prenderà un altro: perdo terreno se è il leader, ma posso spingere il prezzo
		var their_surplus := 0.0
		if top_other >= 0:
			var qv2 := item_value(top_other, item)
			var price2: int = max(min_open, will)
			var qrate := R() if cur == "gold" else R() / Ri(top_other)
			their_surplus = qv2 - price2 / qrate
			score = -wts.get(top_other, 0.3) * max(0.0, their_surplus) - 0.2
			if prm.drain > 0.0 and will > min_open:
				score += prm.drain * (will - min_open) / qrate   # drenaggio di risorse al rivale
		else:
			score = -1.0
	# Eventi: chi mette all'asta l'ultimo evento chiude la Decade
	if kind == "event" and g.event_pool.size() == 1:
		score -= _end_decade_penalty()
	if kind == "event" and g.event_pool.size() > 1:
		score += 0.05
	return score

func _end_decade_penalty() -> float:
	var p := P(me)
	var pen := 0.0
	for t in p.cities:
		var ab: Array = Data.city_tile(t).ab
		if "steal_inf" in ab and not p.used.has("lucrezia"):
			pen += 0.4
		if "free_treach" in ab and not p.used.has("ft_" + t):
			pen += 0.3
	if g.wars_fought < g.war_limit and not p.troops.is_empty():
		pen += 0.25
	# se posso ancora comprare città convenienti, non chiudere
	for t in g.city_pool:
		if g.can_hold_city(me, t) and tile_value(me, t) * R() > 2 * g.status[Data.city_tile(t).city] + 4 and p.gold >= 2 * g.status[Data.city_tile(t).city]:
			pen += 0.5
			break
	if g.pope_holder == me:
		pen -= 0.3
	return pen

func _best_war() -> Array:
	var best: Array = []
	var bestv := 0.15
	for a in Data.CITIES:
		for d in Data.CITIES:
			if a == d:
				continue
			var v := war_declare_value(a, d)
			for o in _oblig:
				if o.type == "war_req" and o.att == a and o.def == d:
					v += _comply_value(o)
				elif o.type == "no_attack" and o.city == d:
					v -= _comply_value(o)
			if v > bestv:
				bestv = v
				best = [v, a, d]
	return best

# --------------------------------------------------------------- aste

func _est_willingness(q: int, item: String, kind: String, cur: String, qv: float) -> int:
	var base := willingness(q, item, kind, cur, qv)
	var m: Dictionary = opp[q]
	var adj: float = 1.0 + 0.5 * (m.aggr - 1.0)
	return int(round(base * adj))

func decide_bid(ctx: Dictionary) -> Dictionary:
	var r := _decide_bid_raw(ctx)
	return _apply_promise(ctx, r)

func _decide_bid_raw(ctx: Dictionary) -> Dictionary:
	var item: String = ctx.item
	var kind: String = ctx.kind
	var cur: String = ctx.cur
	var minb: int = ctx.min
	var maxb: int = ctx.max
	var high: int = ctx.high
	var myv := item_value(me, item)
	var will: int = min(willingness(me, item, kind, cur, myv), maxb)
	var wts := opp_weights()
	# denial: quanto mi costa lasciarlo al rivale più pericoloso ancora in gara
	var ests := {}
	var top_q := -1
	var top_est := -1
	for q in ctx.remaining:
		if q == me:
			continue
		var qv := item_value(q, item)
		var e: int = min(_est_willingness(q, item, kind, cur, qv), g.max_payable(q, item, cur, kind))
		ests[q] = e
		if e > top_est:
			top_est = e
			top_q = q
	_cur_est[item] = ests
	if top_q >= 0 and prm.deny > 0.0:
		var qv2 := item_value(top_q, item)
		var deny: float = wts.get(top_q, 0.3) * max(0.0, qv2) * prm.deny
		var rate := R() if cur == "gold" else R() / Ri(me)
		will = min(maxb, will + int(deny * rate))
	will += int(round(_noise() * 1.2))
	var res := {}
	# Congelare un'Offerta: blocca il rivale più forte se il lotto mi interessa davvero
	if ctx.can_freeze and level >= 1 and top_q >= 0 and will >= minb:
		var surplus := will - minb
		var threat := top_est >= minb
		if threat and (myv >= 3.0 or surplus >= 4) and rng.randf() < prm.freeze_p:
			res["freeze"] = top_q
	if ctx.must:
		var open := minb
		if will > minb and level >= 1:
			# apertura: bassa per sondare, oppure salto se temo il congelamento
			if _freeze_risk(ctx) > 0.45 and will - minb >= 3:
				open = minb + int((will - minb) * rng.randf_range(0.4, 0.7))
			elif kind == "event" and rng.randf() < 0.2:
				open = minb + rng.randi_range(1, 2)
		res["bid"] = clampi(open, minb, max(minb, maxb))
		return res
	if minb <= will:
		var b := minb
		if level >= 1:
			var fr := _freeze_risk(ctx)
			var gap := will - minb
			if fr > 0.4 and gap >= 3 and rng.randf() < 0.5:
				b = minb + int(gap * rng.randf_range(0.3, 0.6))
			elif gap >= 6 and rng.randf() < traits.bluff * 0.35:
				# salto d'intimidazione
				b = minb + rng.randi_range(1, 3)
		res["bid"] = clampi(b, minb, maxb)
		return res
	# sopra il mio valore: bluff di spinta?
	if level >= 1 and high >= 0 and high != me and rng.randf() < traits.bluff:
		var m: Dictionary = opp[high]
		var their: int = ests.get(high, top_est)
		var margin := 3 if m.push < 1.5 else 5
		var overpay := minb - will
		var rate2 := R() if cur == "gold" else R() / Ri(me)
		var target_w: float = wts.get(high, 0.2)
		if their - minb >= margin and overpay <= 2 + int(level) and myv > 0.5 and target_w > 0.25:
			res["bid"] = minb
			return res
	res["pass"] = true
	return res

func _freeze_risk(ctx: Dictionary) -> float:
	var n := 0
	for q in ctx.remaining:
		if q != me and P(q).treach.size() > 0:
			n += P(q).treach.size()
	var known_freeze := 0
	for c in g.discards:
		if c == "congela":
			known_freeze += 1
	var remaining_freeze: float = Data.TREACHERY.congela.count - known_freeze - P(me).treach.count("congela")
	var unknown: float = max(1.0, g.deck.size() + _cards_in_others())
	var pcard := remaining_freeze / unknown
	return 1.0 - pow(1.0 - pcard, n)

func _cards_in_others() -> int:
	var n := 0
	for q in others():
		n += P(q).treach.size()
	return n

func decide_condo_bid(ctx: Dictionary) -> Dictionary:
	var r := _decide_condo_raw(ctx)
	return _apply_promise(ctx, r)

func _decide_condo_raw(ctx: Dictionary) -> Dictionary:
	var w: Dictionary = ctx.war
	var side := "att" if w.phase == "condo_att" else "def"
	var v := condo_value(me, side, w)
	var rate := R() / Ri(me)
	var will := int(floor(v * rate * traits.greed)) + g.discount(me, "inf", "condo")
	will = min(will, ctx.max)
	will += int(round(_noise()))
	var res := {}
	var minb: int = ctx.min
	if ctx.can_freeze and level >= 1 and v > 2.5 and ctx.remaining.size() > 1:
		var rival := -1
		var rv := -1e9
		for q in ctx.remaining:
			if q == me:
				continue
			var qv := condo_value(q, side, w)
			if qv > rv:
				rv = qv
				rival = q
		if rival >= 0 and rv * R() / Ri(rival) >= minb and rng.randf() < 0.5:
			res["freeze"] = rival
	if will >= minb and v > 0.0:
		res["bid"] = minb
		return res
	# bluff: spingi il prezzo dell'Influenza al leader
	if level >= 1 and ctx.high >= 0 and ctx.high != me and rng.randf() < traits.bluff * 0.6:
		var hq: int = ctx.high
		var hv := condo_value(hq, side, w) * R() / Ri(hq)
		if hv - minb >= 3 and minb - will <= 1 and v > -0.5:
			res["bid"] = minb
			return res
	res["pass"] = true
	return res

# --------------------------------------------------------------- guerra

func decide_veto(ctx: Dictionary) -> String:
	var w := _war_dict(ctx.att, ctx.def, -1, -1)
	# stima pessimistica: i condottieri probabili
	var ca := _likely_other_condo(-9, "att", w)
	w.ca = ca
	w.cd = _likely_other_condo(ca, "def", w)
	var v: float = war_outcome_value(me, ctx.att, ctx.def, w).value
	# se sono io il probabile condottiero, la guerra mi conviene di più
	if w.ca == me or w.cd == me:
		v += 1.5
	var threshold := -1.2 if "lorenzo" in ctx.sources else -2.0
	var bt: Dictionary = ctx.get("bounty", {})
	v -= 0.85 * (_vp("gold", int(bt.get("gold", 0))) + _vp("inf", int(bt.get("inf", 0))))
	if v < threshold:
		return "lorenzo" if "lorenzo" in ctx.sources else "card"
	return ""

func decide_holy(ctx: Dictionary) -> String:
	var w: Dictionary = ctx.war
	var dls: Array = ctx.get("deals", [])
	var vals := _holy_values(w)
	var best := ""
	var bestv := -1e9
	for side in ["", "att", "def"]:
		var v: float = vals[side] + (0.3 if side == "" else 0.0)
		for d in dls:
			if d.side == side:
				if not d.get("paid", false):
					v += _vp(d.pay_cur, int(d.pay_amt)) * 0.9
			elif d.get("paid", false):
				v -= _honor_cost()
		if v > bestv:
			bestv = v
			best = side
	return best

func _holy_values(w: Dictionary) -> Dictionary:
	var out := {"": war_outcome_value(me, w.att, w.def, w).value}
	for side in ["att", "def"]:
		var w2 := w.duplicate(true)
		w2.ally = me
		w2.ally_side = side
		out[side] = war_outcome_value(me, w.att, w.def, w2).value
	return out

func decide_bribe(ctx: Dictionary) -> int:
	var w: Dictionary = ctx.war
	var base: float = war_outcome_value(me, w.att, w.def, w).value
	var best := -1
	var bestv := base + 0.45
	for i in ctx.targets.size():
		var tg = ctx.targets[i]
		if tg[0] == me:
			continue
		var w2 := w.duplicate(true)
		w2.bribed.append([tg[0], tg[1]])
		var v: float = war_outcome_value(me, w.att, w.def, w2).value
		v += _deal_choice_bonus(ctx.get("deals", []), func(x): return int(x.victim) == int(tg[0]))
		if v > bestv:
			bestv = v
			best = i
	return best

func decide_maltempo(ctx: Dictionary) -> String:
	var w: Dictionary = ctx.war
	var base: float = war_outcome_value(me, w.att, w.def, w).value
	var best := ""
	var bestv := base + 0.4
	for side in ["att", "def"]:
		var w2 := w.duplicate(true)
		if side == "att":
			w2.mal_att += 1
		else:
			w2.mal_def += 1
		var v: float = war_outcome_value(me, w.att, w.def, w2).value
		v += _deal_choice_bonus(ctx.get("deals", []), func(x): return x.city == w[side])
		if v > bestv:
			bestv = v
			best = side
	return best

func decide_reroll(ctx: Dictionary) -> bool:
	var w: Dictionary = ctx.war
	var roll: Dictionary = ctx.roll
	var ev0 := ev_now()
	var wts := opp_weights()
	var a_side: String = roll.a_side
	var att: String = w.att
	var def: String = w.def
	var first_round: bool = a_side == "att"
	# valore del risultato attuale
	var cur_v := _round_result_value(roll.ta, roll.td, first_round, w, ev0, wts)
	# valore atteso di un rilancio
	var exp_v := 0.0
	for x in range(1, 7):
		for y in range(1, 7):
			exp_v += _round_result_value(roll.sa + x, roll.sd + y, first_round, w, ev0, wts) / 36.0
	var bonus := _deal_choice_bonus(ctx.get("deals", []), func(_x): return true)
	return exp_v + bonus > cur_v + 0.35

func _round_result_value(ta: int, td: int, first_round: bool, w: Dictionary, ev0: Dictionary, wts: Dictionary) -> float:
	var att: String = w.att
	var def: String = w.def
	if first_round:
		if ta > td:
			var dd := 2 if ta >= 2 * td else 1
			return _outcome_val({att: dd, def: -dd}, w.ca, ev0, wts)
		# contrattacco: valore atteso del secondo round
		var sd_att := g.side_strength(w, "def", "att")
		var sa_def := g.side_strength(w, "att", "def")
		var c := _counter_probs(sd_att, sa_def)
		return c.w * _outcome_val({def: 1, att: -1}, w.cd, ev0, wts) + c.W * _outcome_val({def: 2, att: -2}, w.cd, ev0, wts)
	else:
		if ta > td:
			var dd2 := 2 if ta >= 2 * td else 1
			return _outcome_val({def: dd2, att: -dd2}, w.cd, ev0, wts)
		return 0.0

func _outcome_val(ch: Dictionary, winner_pid: int, ev0: Dictionary, wts: Dictionary) -> float:
	var ev1 := ev_with(ch)
	var v := city_delta(me, ev0, ev1)
	for q in wts:
		v -= wts[q] * city_delta(q, ev0, ev1)
	if winner_pid == me:
		v += P(me).vp_counters + 1
	elif winner_pid >= 0 and wts.has(winner_pid):
		v -= wts[winner_pid] * (P(winner_pid).vp_counters + 1)
	return v

func decide_french(ctx := {}) -> String:
	var dls: Array = ctx.get("deals", [])
	var r := best_french_city(me)
	if dls.is_empty():
		return r[0] if r[1] > 0.05 else ""
	var ev0 := ev_now()
	var wts := opp_weights()
	var best := ""
	var bestv := _deal_choice_bonus(dls, func(x): return str(x.city) == "")
	for c in Data.CITIES:
		var ev1 := ev_with({c: -2})
		var v := city_delta(me, ev0, ev1)
		for q in wts:
			v -= wts[q] * city_delta(q, ev0, ev1)
		v += _deal_choice_bonus(dls, func(x): return str(x.city) == c)
		if v > bestv:
			bestv = v
			best = c
	return best

func decide_place_sta(ctx: Dictionary) -> String:
	var dls: Array = ctx.get("deals", [])
	if dls.is_empty():
		return best_sta_city(me)[0]
	var ev0 := ev_now()
	var wts := opp_weights()
	var best := Data.CITIES[0]
	var bestv := -1e9
	for c in Data.CITIES:
		var ev1 := ev_with({c: 1}, {c: 1})
		var v := city_delta(me, ev0, ev1)
		for q in wts:
			v -= wts[q] * city_delta(q, ev0, ev1)
		v += _deal_choice_bonus(dls, func(x): return x.city == c)
		if v > bestv:
			bestv = v
			best = c
	return best

func decide_keep(ctx: Dictionary) -> int:
	var a: String = ctx.cards[0]
	var b: String = ctx.cards[1]
	return 0 if treach_card_value(a) >= treach_card_value(b) else 1

func decide_discard(ctx: Dictionary) -> String:
	var worst := ""
	var wv := 1e9
	for c in ctx.cards:
		var v := treach_card_value(c)
		if v < wv:
			wv = v
			worst = c
	return worst

func decide_start_war_card(_ctx: Dictionary):
	var bw := _best_war()
	if bw.size() > 0 and bw[0] > 0.6:
		return {"att": bw[1], "def": bw[2]}
	return null

func decide_artist_ties(ctx: Dictionary) -> Array:
	# riordina all'interno dei gruppi pari per massimizzare i miei PV
	var order: Array = ctx.order.duplicate()
	var i := 0
	while i < order.size():
		var j := i
		while j + 1 < order.size() and g.status[order[j + 1]] == g.status[order[i]] and g.artists[order[j + 1]] == g.artists[order[i]]:
			j += 1
		if j > i:
			var grp: Array = order.slice(i, j + 1)
			var dls: Array = ctx.get("deals", [])
			var score := func(c):
				var v := city_count(me, c) * 2.0
				for x in dls:
					if x.city == c:
						v += _vp(str(x.pay_cur), int(x.pay_amt)) + (_honor_cost() if x.get("paid", false) else 0.3)
				return v
			grp.sort_custom(func(a, b): return score.call(a) > score.call(b))
			for k in grp.size():
				order[i + k] = grp[k]
		i = j + 1
	return order

# =============================================================== osservazioni

func observe_auction(rec: Dictionary) -> void:
	var item: String = rec.item
	var ests: Dictionary = _cur_est.get(item, {})
	var maxbid := {}
	for b in rec.bids:
		if b[1] >= 0:
			maxbid[b[0]] = max(maxbid.get(b[0], 0), b[1])
	for q in maxbid:
		if q == me or not opp.has(q):
			continue
		var m: Dictionary = opp[q]
		var est: float = float(ests.get(q, -1))
		if est <= 0:
			continue
		var ratio: float = maxbid[q] / max(1.0, est)
		m.n += 1
		if q == rec.winner:
			# disponibilità a pagare rivelata: aggiorna il modello
			m.aggr = lerpf(m.aggr, clampf(ratio, 0.6, 1.8), 0.3)
			if ratio > 1.25:
				m.overpay += 1.0
		elif ratio > 1.15:
			# ha rilanciato oltre il suo valore e poi ha mollato: probabile bluff
			m.push += 1.0
		elif ratio < 0.7:
			m.aggr = lerpf(m.aggr, clampf(ratio + 0.2, 0.6, 1.8), 0.15)
	_cur_est.erase(item)

func observe_condo(_w: Dictionary, _ra: Dictionary, _rd: Dictionary) -> void:
	pass

func observe_hostility(src: int, target: int, w: float) -> void:
	if target == me and opp.has(src):
		opp[src].host += w


# =============================================================== trattative

## valore in PV di una somma di denaro
func _vp(cur: String, amt: int) -> float:
	return amt / R() if cur == "gold" else amt * Ri(me) / R()

func _amt_for(cur: String, vp: float) -> int:
	return int(ceil(vp * R())) if cur == "gold" else int(ceil(vp * R() / Ri(me)))

func _remaining_frac() -> float:
	return clampf(((3 - g.decade) + g.event_pool.size() / 4.0) / 3.0, 0.0, 1.0)

## quanto "costa" (in PV futuri) farsi una reputazione da traditore
func _honor_cost() -> float:
	return prm.get("honesty", 5.0) * (0.45 + _remaining_frac())

func _key(d: Dictionary) -> String:
	return "%s_%d_%d" % [d.get("type", ""), int(d.get("to", -1)), int(d.get("aseq", d.get("wseq", 0)))]

# --------------------------------------------------------------- aste

## mio surplus atteso in un'asta, con un insieme di concorrenti
func _surplus_in(ctx: Dictionary, rivals: Array) -> float:
	var kind: String = ctx.kind
	var cur: String = ctx.cur
	var myv: float
	var my_will: int
	var rate: float
	if kind == "condo":
		var side := "att" if ctx.war.phase == "condo_att" else "def"
		myv = condo_value(me, side, ctx.war)
		rate = R() / Ri(me)
		my_will = int(floor(myv * rate)) + g.discount(me, "inf", "condo")
	else:
		myv = item_value(me, ctx.item)
		rate = R() if cur == "gold" else R() / Ri(me)
		my_will = willingness(me, ctx.item, kind, cur, myv)
	my_will = min(my_will, int(ctx.max))
	var top := int(ctx.bid) if int(ctx.high) >= 0 and int(ctx.high) != me else -1
	for q in rivals:
		if q == me:
			continue
		top = max(top, _rival_will(q, ctx))
	var price: int = max(int(ctx.min), top + 1)
	if my_will < price:
		return 0.0
	return max(0.0, myv - (price - g.discount(me, cur, kind)) / rate)

func _rival_will(q: int, ctx: Dictionary) -> int:
	if ctx.kind == "condo":
		var side := "att" if ctx.war.phase == "condo_att" else "def"
		return int(floor(condo_value(q, side, ctx.war) * R() / Ri(q))) + g.discount(q, "inf", "condo")
	var qv := item_value(q, ctx.item)
	return min(_est_willingness(q, ctx.item, ctx.kind, ctx.cur, qv), g.max_payable(q, ctx.item, ctx.cur, ctx.kind))


func _rival_surplus(q: int, ctx: Dictionary) -> float:
	var qw := _rival_will(q, ctx)
	var top := -1
	for x in ctx.remaining:
		if x != q:
			top = max(top, _rival_will(x, ctx) if x != me else min(willingness(me, ctx.item, ctx.kind, ctx.cur, item_value(me, ctx.item)) if ctx.kind != "condo" else 0, int(ctx.max)))
	var price: int = max(int(ctx.min), top + 1)
	if qw < price:
		return 0.2
	var qrate: float = (R() / Ri(q)) if ctx.cur == "inf" else R()
	var qv: float = condo_value(q, "att" if ctx.kind == "condo" and ctx.war.phase == "condo_att" else "def", ctx.war) if ctx.kind == "condo" else item_value(q, ctx.item)
	return max(0.2, qv - price / qrate)


# --------------------------------------------------------------- offerte ricevute




# --------------------------------------------------------------- proposte attive

func plan_holy_deal(w: Dictionary, side: String):
	if rng.randf() >= prm.get("deal_p", 0.0) or g.pope_holder < 0:
		return null
	_wts_cache = null
	var pope := g.pope_holder
	var w_with := w.duplicate(true)
	w_with.ally = pope
	w_with.ally_side = side
	var gain: float = war_outcome_value(me, w.att, w.def, w_with).value - war_outcome_value(me, w.att, w.def, w).value
	if gain < 0.7:
		return null
	# quanto vorrà il Papa? stima dal suo punto di vista
	var pv0: float = war_outcome_value(pope, w.att, w.def, w, false).value
	var pv_side: float = war_outcome_value(pope, w.att, w.def, w_with, false).value
	var w_other := w.duplicate(true)
	w_other.ally = pope
	w_other.ally_side = "def" if side == "att" else "att"
	var pv_other: float = war_outcome_value(pope, w.att, w.def, w_other, false).value
	var needed: float = max(0.0, max(pv0 + 0.3, pv_other) - pv_side) + 0.3
	var offer: float = max(needed, gain * 0.3)
	if offer > gain * 0.75:
		return null
	var amt := _amt_for("gold", offer)
	if amt > P(me).gold:
		return null
	_plan_max["holy_%d" % pope] = gain * 0.85
	return {"pay_cur": "gold", "pay_amt": amt, "timing": "after"}

func plan_veto_bounty(att: String, def: String, starter: int):
	if rng.randf() >= prm.get("deal_p", 0.0):
		return null
	if "veto" in P(me).treach or (g.owns_ability(me, "veto") and not P(me).used.has("veto")):
		return null
	_wts_cache = null
	var w := _war_dict(att, def, -1, -1)
	var ca := _likely_other_condo(-9, "att", w)
	w.ca = ca
	w.cd = _likely_other_condo(ca, "def", w)
	var v: float = war_outcome_value(me, att, def, w).value
	if w.ca == me or w.cd == me:
		v += 1.5
	if v > -1.6:
		return null
	var amt: int = clampi(_amt_for("gold", -v * 0.45), 2, int(P(me).gold / 3))
	if amt < 2:
		return null
	return {"amount": amt, "cur": "gold"}

func plan_exchange():
	if rng.randf() >= prm.get("deal_p", 0.0) * 0.7:
		return null
	var p := P(me)
	var want := ""
	if p.inf < 5 and p.gold >= 16 and g.decade < 3:
		want = "inf"
	elif p.gold < 8 and p.inf >= 16:
		want = "gold"
	if want == "":
		return null
	var best := -1
	var bestm := -1
	var wts := opp_weights()
	for q in others():
		var m: int = P(q).inf if want == "inf" else P(q).gold
		var score := m - int(wts.get(q, 0.3) * 10)
		if m >= 10 and score > bestm:
			bestm = score
			best = q
	if best < 0:
		return null
	var n := 4
	var give_cur := "gold" if want == "inf" else "inf"
	# offro un cambio leggermente favorevole al partner
	var give_amt: int = int(ceil(n * (Ri(me) if want == "inf" else 1.0 / Ri(me)) * 1.1))
	give_amt = max(give_amt, n)
	if (p.gold if give_cur == "gold" else p.inf) < give_amt:
		return null
	return {"to": best, "type": "exchange", "give_cur": give_cur, "give_amt": give_amt, "get_cur": want, "get_amt": n}

func observe_deal(d: Dictionary, ev: String) -> void:
	if ev != "broken":
		return
	var traitor: int = int(d.get("to", -1))
	var victim: int = int(d.get("from", -1))
	if opp.has(traitor):
		opp[traitor].host += 1.2 if victim == me else 0.3

## Valore (PV) di rispettare un accordo in cui devo fare qualcosa
func _comply_value(d: Dictionary) -> float:
	var v := _honor_cost()
	if d.get("paid", false):
		v *= 0.8
	elif int(d.get("to", -1)) == me and int(d.get("pay_amt", 0)) > 0:
		v += _vp(str(d.get("pay_cur", "gold")), int(d.pay_amt))
	return v

## Accordi che mi pagano se faccio una certa scelta: bonus per la scelta "giusta",
## malus (onore) se l'accordo è già pagato e non lo rispetto.
func _deal_choice_bonus(dls: Array, matches: Callable) -> float:
	var b := 0.0
	for d in dls:
		if matches.call(d):
			b += (0.0 if d.get("paid", false) else _vp(str(d.pay_cur), int(d.pay_amt))) * 0.95
			b += _honor_cost() * 0.5
		elif d.get("paid", false):
			b -= _honor_cost() * 0.3
	return b

## Ho promesso di non rilanciare: rispetto il patto?
func _apply_promise(ctx: Dictionary, r: Dictionary) -> Dictionary:
	var out := r
	if ctx.has("promise") and not r.get("pass", false) and not ctx.get("must", false):
		var d: Dictionary = ctx.promise
		var gain := _surplus_in(ctx, ctx.remaining)
		if gain <= _comply_value(d):
			out = {"pass": true}
			if r.has("freeze"):
				out["freeze"] = r.freeze
	# congelamento promesso su commissione
	if ctx.has("freeze_promise") and ctx.get("can_freeze", false):
		var fd: Dictionary = ctx.freeze_promise
		if _comply_value(fd) > treach_card_value("congela") * 0.7:
			out = out.duplicate()
			out["freeze"] = int(fd.victim)
	return out

# --------------------------------------------------------------- aste: proposte

## Offro un accordo a un rival in quest'asta? (astensione, congelamento, spartizione Condottieri)
func plan_auction_deal(ctx: Dictionary):
	if rng.randf() >= prm.get("deal_p", 0.0):
		return null
	_wts_cache = null
	var types: Array = ctx.get("deal_types", ["abstain"])
	var rivals: Array = ctx.remaining
	var a := _surplus_in(ctx, rivals)
	var best := -1
	var bestg := 0.0
	for q in ctx.deal_targets:
		var without: Array = rivals.filter(func(x): return x != q)
		var gain := _surplus_in(ctx, without) - a
		if gain > bestg:
			bestg = gain
			best = q
	if best < 0 or bestg < prm.get("deal_gain", 1.8):
		return null
	if _rival_will(best, ctx) < int(ctx.min) + 2:
		return null    # smetterebbe comunque di rilanciare: non pago per niente
	var dkey := "abst_dec%d" % g.decade
	if int(_plan_max.get(dkey, 0)) >= 3:
		return null
	var qs := _rival_surplus(best, ctx)
	var offer: float = max(qs * 1.1 + 0.3, bestg * 0.25)
	if offer > bestg * 0.5:
		return null
	_plan_max[dkey] = int(_plan_max.get(dkey, 0)) + 1
	# 1) Condottieri: spartizione (io attacco, tu difendi) — costa meno
	if "condo_split" in types and ctx.kind == "condo":
		var mydef := condo_value(me, "def", ctx.war)
		if mydef < 1.5:
			var cut: int = max(0, _amt_for("gold", offer * 0.5))
			_plan_max["condo_split_%d" % best] = bestg * 0.8
			return {"type": "condo_split", "to": best, "pay_cur": "gold", "pay_amt": cut, "timing": "after"}
	# 2) Congelamento su commissione: un terzo con carte Tradimento congela il rivale
	if "freeze_req" in types and not "congela" in P(me).treach and rng.randf() < 0.45:
		var holder := -1
		var hc := 0
		for q in ctx.deal_targets:
			if q != best and P(q).treach.size() > hc:
				hc = P(q).treach.size()
				holder = q
		if holder >= 0:
			var famt := _amt_for("gold", max(0.8, offer * 0.6))
			if famt <= P(me).gold - int(ctx.min) or ctx.cur != "gold":
				_plan_max["freeze_req_%d" % holder] = bestg * 0.6
				return {"type": "freeze_req", "to": holder, "victim": best, "pay_cur": "gold", "pay_amt": famt, "timing": "after"}
	if not "abstain" in types:
		return null
	var cur := "gold"
	var amt := _amt_for("gold", offer)
	if P(me).gold - amt < int(ctx.min) and ctx.cur == "gold":
		cur = "inf"
		amt = _amt_for("inf", offer)
	if amt <= 0 or (P(me).gold if cur == "gold" else P(me).inf) < amt:
		return null
	_plan_max["abstain_%d" % best] = bestg * 0.85
	return {"type": "abstain", "to": best, "pay_cur": cur, "pay_amt": amt, "timing": "after"}

# --------------------------------------------------------------- offerte ricevute

func _auction_ctx_now() -> Dictionary:
	var a: Dictionary = g.auction
	var ctx2 := {"item": a.get("item", ""), "kind": a.get("kind", ""), "cur": a.get("cur", "gold"), "high": a.get("high", -1),
		"bid": a.get("bid", -1), "min": max(int(a.get("min_open", 0)), int(a.get("bid", -1)) + 1), "remaining": [], "war": g.war}
	ctx2["max"] = g.max_payable(me, ctx2.item if ctx2.kind != "condo" else "", ctx2.cur, ctx2.kind)
	for q in a.get("part", []):
		if not a.get("out", {}).has(q):
			ctx2.remaining.append(q)
	return ctx2

## risposta standard: accetto se l'offerta copre il mio costo, altrimenti controproposta
func _answer(d: Dictionary, needed: float, rep: float, allow_bluff := false) -> Dictionary:
	var offer := _vp(str(d.get("pay_cur", "gold")), int(d.get("pay_amt", 0)))
	var from: int = int(d.from)
	var cur: String = str(d.get("pay_cur", "gold"))
	if allow_bluff and level >= 2 and d.get("timing", "after") == "now" and offer > 0.4 and needed > _honor_cost() * 1.2:
		return {"accept": true}   # intasco e poi… si vedrà
	if d.get("timing", "after") == "after" and rep < 0.55 and int(d.get("pay_amt", 0)) > 0:
		if offer >= needed:
			return {"accept": false, "timing": "now"}
		return {"accept": false, "timing": "now", "counter": _amt_for(cur, needed)}
	if offer >= needed:
		return {"accept": true}
	var c := _amt_for(cur, needed)
	if c >= 1 and c <= (P(from).gold if cur == "gold" else P(from).inf):
		return {"accept": false, "counter": c}
	return {"accept": false}

func decide_deal_offer(ctx: Dictionary) -> Dictionary:
	_wts_cache = null
	var d: Dictionary = ctx.deal
	var from: int = int(d.from)
	var rep: float = ctx.get("reputation", 1.0)
	var wts := opp_weights()
	var hostility: float = 0.3 * min(3.0, opp.get(from, {}).get("host", 0.0))
	match str(d.type):
		"exchange":
			var recv := _vp(d.give_cur, int(d.give_amt))
			var give := _vp(d.get_cur, int(d.get_amt))
			var harm: float = 0.35 * wts.get(from, 0.3) * give + hostility * 0.3
			if (P(me).gold if d.get_cur == "gold" else P(me).inf) < int(d.get_amt):
				return {"accept": false}
			if recv - give - harm >= 0.05:
				return {"accept": true}
			var max_give: float = (recv - harm - 0.05)
			var c := int(floor(max_give * (R() if d.get_cur == "gold" else R() / Ri(me))))
			if c >= 1 and c < int(d.get_amt):
				return {"accept": false, "counter": c}
			return {"accept": false}
		"loan":
			if int(d.lender) == me:
				# mi chiedono un prestito
				var interest := int(d.repay) - int(d.amount)
				var risk := 1.0 - rep
				if P(me).gold - int(d.amount) < 10 or wts.get(from, 0.3) > 0.5 or hostility > 0.6:
					return {"accept": false}
				var need_int: int = int(ceil(int(d.amount) * (0.2 + risk * 0.6)))
				if interest >= need_int and rep >= 0.5:
					return {"accept": true}
				if rep >= 0.5:
					return {"accept": false, "counter": int(d.amount) + need_int}
				return {"accept": false}
			else:
				# mi offrono un prestito
				var need: bool = P(me).gold < 15 and g.decade < 3
				var interest2: float = float(int(d.repay) - int(d.amount)) / max(1.0, float(int(d.amount)))
				if need and interest2 <= 0.3:
					return {"accept": true}
				return {"accept": false}
		"abstain":
			var ctx2 := _auction_ctx_now()
			var mys := _surplus_in(ctx2, ctx2.remaining)
			var their_gain: float = max(0.0, mys) * 0.8 + 0.3
			var needed: float = mys + 0.4 * wts.get(from, 0.3) * their_gain + 0.25 + hostility
			return _answer(d, needed, rep, mys > _honor_cost() * 1.2)
		"condo_split":
			var ctx3 := _auction_ctx_now()
			var mys2 := _surplus_in(ctx3, ctx3.remaining)
			var def_v: float = max(0.0, condo_value(me, "def", g.war))
			var needed3: float = mys2 - 0.6 * def_v + 0.25 + hostility
			return _answer(d, max(0.0, needed3), rep)
		"freeze_req":
			if not "congela" in P(me).treach:
				if level >= 2 and d.get("timing", "after") == "now" and int(d.pay_amt) >= 2 and rng.randf() < 0.5:
					return {"accept": true}   # bluff: non ho la carta, ma intasco
				return {"accept": false}
			var harm2: float = 0.3 * wts.get(int(d.victim), 0.3)
			return _answer(d, max(0.3, treach_card_value("congela") - harm2) + hostility, rep)
		"holy":
			var vals := _holy_values(g.war)
			var bestalt: float = max(vals[""], vals["att" if d.side == "def" else "def"])
			return _answer(d, bestalt - vals[d.side] + 0.3 + hostility, rep)
		"card_req":
			var card: String = d.card
			if not card in P(me).treach:
				if level >= 2 and d.get("timing", "after") == "now" and int(d.pay_amt) >= 2 and rng.randf() < 0.4:
					return {"accept": true}
				return {"accept": false}
			var w: Dictionary = g.war
			var base: float = war_outcome_value(me, w.att, w.def, w).value
			var w2 := w.duplicate(true)
			if card == "maltempo":
				if d.city == w.att:
					w2.mal_att += 1
				else:
					w2.mal_def += 1
			else:
				var tr := _best_troop_of(int(d.victim), w)
				if tr == "":
					return {"accept": false}
				w2.bribed.append([int(d.victim), tr])
			var after: float = war_outcome_value(me, w.att, w.def, w2).value
			return _answer(d, max(0.2, base - after + treach_card_value(card) * 0.8) + hostility, rep)
		"reroll_req":
			var roll: Dictionary = ctx.get("roll", {})
			var loss := _reroll_gain(g.war, d.get("roll", {})) if d.has("roll") else 0.0
			return _answer(d, max(0.25, -loss + 0.4) + hostility, rep)
		"war_req":
			if g.wars_fought >= g.war_limit:
				return {"accept": false}
			var wv := war_declare_value(d.att, d.def)
			return _answer(d, max(0.2, 0.6 - wv) + hostility, rep)
		"no_attack":
			var cost := 0.0
			for a2 in Data.CITIES:
				if a2 != d.city:
					cost = max(cost, war_declare_value(a2, d.city))
			return _answer(d, cost * 0.5 + 0.25 + hostility, rep, cost > 1.5)
		"auction_req":
			var item: String = d.item
			var s := _auction_score(item, wts) if item in g.event_pool or item in g.city_pool or item == "POPE" else -5.0
			if s < -4.0:
				return {"accept": false}
			return _answer(d, max(0.2, 0.6 - s) + hostility, rep)
		"no_close":
			var pen := _end_decade_penalty()
			return _answer(d, max(0.2, 0.3 - pen) + hostility, rep)
		"city_pact":
			var mine := city_count(me, d.city)
			if mine == 0:
				return _answer(d, 0.8, rep)
			if rep < 0.6 or wts.get(from, 0.3) > 0.55 or hostility > 0.6:
				return {"accept": false}
			return {"accept": rng.randf() < 0.75}
		"protection":
			var has_steal: bool = "ruba_oro" in P(me).treach or "ruba_inf" in P(me).treach or (g.owns_ability(me, "steal_inf") and not P(me).used.has("lucrezia"))
			var need5: float = 0.25 + (0.8 * wts.get(from, 0.3) * 2.0 if has_steal else 0.0)
			return _answer(d, need5 + hostility, rep, not has_steal)
		"artist_req":
			var ev0 := ev_now()
			var mybest: Array = best_sta_city(me)
			var ev1 := ev_with({str(d.city): 1}, {str(d.city): 1})
			var v_req := city_delta(me, ev0, ev1)
			for q in wts:
				v_req -= wts[q] * city_delta(q, ev0, ev1)
			return _answer(d, max(0.1, float(mybest[1]) - v_req + 0.2) + hostility, rep)
		"french_req":
			var fb: Array = best_french_city(me)
			var v_req2 := 0.0
			if str(d.city) != "":
				var e0 := ev_now()
				var e1 := ev_with({str(d.city): -2})
				v_req2 = city_delta(me, e0, e1)
				for q in wts:
					v_req2 -= wts[q] * city_delta(q, e0, e1)
			return _answer(d, max(0.1, float(fb[1]) - v_req2 + 0.2) + hostility, rep)
		"ties_req":
			var loss2 := 0.0
			for c in ctx.get("tied", []):
				if c != d.city and city_count(me, c) > city_count(me, d.city):
					loss2 += 2.0 * (city_count(me, c) - city_count(me, d.city))
			# a fine partita l'Oro conta solo per le maggioranze
			var mv := majority_vp(str(d.pay_cur), -int(d.pay_amt)) - majority_vp(str(d.pay_cur), 0)
			if mv > loss2 or (loss2 == 0.0 and int(d.pay_amt) > 0):
				return {"accept": true}
			return {"accept": false}
	return {"accept": false}

func _best_troop_of(pid: int, w: Dictionary) -> String:
	var best := ""
	var bv := -1
	for tr in P(pid).troops:
		if g._bribed_in(w, pid, tr):
			continue
		var v: int = Data.TROOPS[tr].att + Data.TROOPS[tr].def
		if v > bv:
			bv = v
			best = tr
	return best

func decide_deal_counter(ctx: Dictionary) -> bool:
	_wts_cache = null
	var d: Dictionary = ctx.deal
	match str(d.type):
		"exchange":
			var recv := _vp(d.get_cur, int(d.get_amt))
			var give := _vp(d.give_cur, int(d.give_amt))
			return recv - give >= -0.15
		"loan":
			var interest: float = float(int(d.repay) - int(d.amount)) / max(1.0, float(int(d.amount)))
			return interest <= 0.4
		_:
			var mx: float = _plan_max.get("%s_%d" % [d.type, int(d.to)], 0.0)
			var cost := _vp(str(d.get("pay_cur", "gold")), int(d.get("pay_amt", 0)))
			if d.get("timing", "after") == "now":
				cost *= 1.0 + (1.0 - g.reputation.get(int(d.to), 1.0)) * 0.8
			return cost <= mx

func decide_deal_pay(ctx: Dictionary) -> bool:
	var amt := _vp(str(ctx.cur), int(ctx.amount))
	if level < 2:
		return true
	var d: Dictionary = ctx.get("deal", {})
	# a fine partita la reputazione non vale più nulla
	if g.decade == 3 and g.event_pool.is_empty():
		return amt <= 0.3
	if d.get("type", "") == "loan":
		return amt <= _honor_cost() * 2.5   # non restituire un prestito crea nemici
	return amt <= _honor_cost() * 1.3

# --------------------------------------------------------------- proposte nel mio turno

func plan_turn_deal(opts: Dictionary):
	var types: Array = opts.get("deal_types", []).filter(func(t): return not t in prm.get("no_deals", []))
	if types.is_empty() or rng.randf() >= prm.get("deal_p", 0.0) * prm.get("turn_deal_p", 1.0):
		return null
	_wts_cache = null
	var cands: Array = []
	var nxt: int = (me + 1) % g.players.size()
	var wts := opp_weights()
	var p := P(me)
	var used: Dictionary = p.used
	# scambio
	if "exchange" in types:
		var ex = plan_exchange()
		if ex != null:
			cands.append(ex)
	# prestito: mi serve Oro per una città nella Decade corrente
	if "loan" in types and g.decade < 3 and p.gold < 12 and g.event_pool.size() >= 2 and not used.has("loan_req"):
		var lender := -1
		var lg := 0
		for q in others():
			if P(q).gold > lg + 0 and wts.get(q, 0.3) < 0.5 and P(q).gold >= 22:
				lg = P(q).gold
				lender = q
		if lender >= 0:
			used["loan_req"] = true
			cands.append({"type": "loan", "to": lender, "lender": lender, "borrower": me, "amount": 8, "repay": 10})
	# guerra su commissione: la guerra che vorrei, la fa il prossimo giocatore
	if "war_req" in types and g.war_limit - g.wars_fought >= 2 and not used.has("war_req"):
		var bw := _best_war()
		if bw.size() > 0 and bw[0] > 1.3:
			used["war_req"] = true
			var amt := _amt_for("gold", bw[0] * 0.3)
			if amt <= p.gold / 3:
				_plan_max["war_req_%d" % nxt] = bw[0] * 0.6
				cands.append({"type": "war_req", "to": nxt, "att": bw[1], "def": bw[2], "pay_cur": "gold", "pay_amt": max(2, amt), "timing": "after"})
	# non aggressione per la mia città principale
	if "no_attack" in types and not used.has("no_attack"):
		var best_c := ""
		var bc := 1
		for c in Data.CITIES:
			if city_count(me, c) > bc:
				bc = city_count(me, c)
				best_c = c
		if best_c != "":
			var foe := -1
			var fs := -1
			for q in others():
				if city_count(q, best_c) > 0 or P(q).troops.is_empty():
					continue
				var s: int = g.condo_strength(q, "att", []) + int(opp[q].host * 2)
				if s > fs:
					fs = s
					foe = q
			if foe >= 0 and g.status[best_c] >= 6:
				used["no_attack"] = true
				_plan_max["no_attack_%d" % foe] = 0.4 * bc + 0.3
				cands.append({"type": "no_attack", "to": foe, "city": best_c, "pay_cur": "gold", "pay_amt": 2, "timing": "after"})
	# spartizione di una città
	if "city_pact" in types and not used.has("city_pact"):
		for c in Data.CITIES:
			if city_count(me, c) == 0:
				continue
			var left := 0
			for t in g.city_pool:
				if Data.city_tile(t).city == c:
					left += 1
			if left < 2:
				continue
			for q in others():
				if city_count(q, c) > 0 and g.reputation.get(q, 1.0) >= 0.7 and wts.get(q, 0.3) < 0.5:
					used["city_pact"] = true
					_plan_max["city_pact_%d" % q] = 0.5
					cands.append({"type": "city_pact", "to": q, "city": c, "pay_cur": "gold", "pay_amt": 0, "timing": "after"})
					break
			if used.has("city_pact"):
				break
	# protezione dai furti
	if "protection" in types and not used.has("protection") and (p.gold >= 25 or p.inf >= 15):
		for q in others():
			if g.owns_ability(q, "steal_inf") and not P(q).used.has("lucrezia") or P(q).treach.size() >= 2:
				used["protection"] = true
				_plan_max["protection_%d" % q] = 0.8
				cands.append({"type": "protection", "to": q, "pay_cur": "gold", "pay_amt": 2, "timing": "after"})
				break
	# chiudere / non chiudere la Decade
	if g.event_pool.size() == 1 and nxt != me:
		var pen := _end_decade_penalty()
		if "no_close" in types and pen > 0.9 and not used.has("no_close"):
			used["no_close"] = true
			_plan_max["no_close_%d" % nxt] = pen * 0.6
			cands.append({"type": "no_close", "to": nxt, "pay_cur": "gold", "pay_amt": _amt_for("gold", pen * 0.35), "timing": "after"})
		elif "auction_req" in types and pen < -0.2 and not used.has("auction_req"):
			used["auction_req"] = true
			_plan_max["auction_req_%d" % nxt] = 0.6
			cands.append({"type": "auction_req", "to": nxt, "item": g.event_pool[0], "pay_cur": "gold", "pay_amt": 2, "timing": "after"})
	if cands.is_empty():
		return null
	return cands[rng.randi_range(0, cands.size() - 1)]

# --------------------------------------------------------------- proposte nei momenti chiave

func plan_moment_deal(kind: String, ctx: Dictionary):
	if rng.randf() >= prm.get("deal_p", 0.0):
		return null
	_wts_cache = null
	var p := P(me)
	match kind:
		"card_req":
			var w: Dictionary = ctx.war
			if w.get("ca", -1) == me or w.get("cd", -1) == me:
				return null   # posso giocare io stesso le mie carte
			var base: float = war_outcome_value(me, w.att, w.def, w).value
			var best = null
			var bestg := 1.0
			# corruzione: la può giocare solo un Condottiero o il Papa alleato
			for h in ctx.holders:
				if h < 0 or h == me or P(h).treach.is_empty():
					continue
				for v in [w.ca, w.cd]:
					if v < 0 or v == h:
						continue
					var tr := _best_troop_of(v, w)
					if tr == "":
						continue
					var w2 := w.duplicate(true)
					w2.bribed.append([v, tr])
					var gain: float = war_outcome_value(me, w.att, w.def, w2).value - base
					if gain > bestg:
						bestg = gain
						best = {"to": h, "card": "corrompi_truppe", "victim": v}
			# maltempo: chiunque abbia carte
			for side in ["att", "def"]:
				var w3 := w.duplicate(true)
				if side == "att":
					w3.mal_att += 1
				else:
					w3.mal_def += 1
				var gain2: float = war_outcome_value(me, w.att, w.def, w3).value - base
				if gain2 > bestg:
					var h2 := -1
					var hc := 0
					for q in others():
						if P(q).treach.size() > hc:
							hc = P(q).treach.size()
							h2 = q
					if h2 >= 0:
						bestg = gain2
						best = {"to": h2, "card": "maltempo", "city": w[side]}
			if best == null:
				return null
			var amt := _amt_for("gold", bestg * 0.35)
			if amt > p.gold / 2 or amt < 1:
				return null
			best["pay_cur"] = "gold"
			best["pay_amt"] = max(2, amt)
			best["timing"] = "after"
			_plan_max["card_req_%d" % int(best.to)] = bestg * 0.7
			return best
		"reroll_req":
			var gain3 := _reroll_gain(ctx.war, ctx.roll)
			if gain3 < 0.9:
				return null
			var amt3: int = max(2, _amt_for("gold", gain3 * 0.35))
			if amt3 > p.gold / 2:
				return null
			_plan_max["reroll_req_%d" % int(ctx.to)] = gain3 * 0.7
			return {"to": ctx.to, "pay_cur": "gold", "pay_amt": amt3, "timing": "after", "roll": ctx.roll}
		"artist_req":
			var mine: Array = best_sta_city(me)
			var theirs: Array = best_sta_city(int(ctx.to))
			if mine[0] == theirs[0] or float(mine[1]) < 0.9:
				return null
			var amt4: int = max(2, _amt_for("gold", float(mine[1]) * 0.4))
			if amt4 > p.gold / 2:
				return null
			_plan_max["artist_req_%d" % int(ctx.to)] = float(mine[1]) * 0.7
			return {"to": ctx.to, "city": mine[0], "pay_cur": "gold", "pay_amt": amt4, "timing": "after"}
		"french_req":
			var mine2: Array = best_french_city(me)
			var theirs2: Array = best_french_city(int(ctx.to))
			if mine2[0] == theirs2[0] or float(mine2[1]) < 0.9:
				return null
			var amt5: int = max(2, _amt_for("gold", float(mine2[1]) * 0.4))
			if amt5 > p.gold / 2:
				return null
			_plan_max["french_req_%d" % int(ctx.to)] = float(mine2[1]) * 0.7
			return {"to": ctx.to, "city": mine2[0], "pay_cur": "gold", "pay_amt": amt5, "timing": "after"}
		"ties_req":
			var bestc := ""
			var bc := 0
			for c in ctx.get("tied", []):
				if city_count(me, c) > bc:
					bc = city_count(me, c)
					bestc = c
			if bestc == "":
				return null
			# l'Oro speso ora conta solo per le maggioranze finali
			var amt6 := 1
			while amt6 < 6 and majority_vp("gold", amt6 + 1) >= majority_vp("gold", 0) and amt6 + 1 <= p.gold:
				amt6 += 1
			if majority_vp("gold", amt6) < majority_vp("gold", 0) and amt6 > 1:
				amt6 -= 1
			_plan_max["ties_req_%d" % int(ctx.to)] = 99.0
			return {"to": ctx.to, "city": bestc, "pay_cur": "gold", "pay_amt": amt6, "timing": "now"}
	return null

## guadagno atteso (per me) di un rilancio dei dadi
func _reroll_gain(w: Dictionary, roll: Dictionary) -> float:
	if roll.is_empty() or w.is_empty():
		return 0.0
	var ev0 := ev_now()
	var wts := opp_weights()
	var first_round: bool = roll.a_side == "att"
	var cur_v := _round_result_value(roll.ta, roll.td, first_round, w, ev0, wts)
	var exp_v := 0.0
	for x in range(1, 7):
		for y in range(1, 7):
			exp_v += _round_result_value(roll.sa + x, roll.sd + y, first_round, w, ev0, wts) / 36.0
	return exp_v - cur_v
