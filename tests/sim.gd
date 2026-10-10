extends Node
## Simulazione headless IA contro IA (test e taratura):
##   godot --headless --path . res://tests/Sim.tscn -- games=20 players=4 lvlA=2 lvlB=1 prmA={"deny":0}

var verbose := false

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var i := a.find("=")
		if i > 0:
			args[a.substr(0, i)] = a.substr(i + 1)
	var games := int(args.get("games", "3"))
	var np := int(args.get("players", "4"))
	verbose = args.get("verbose", "0") == "1"
	var lvlA := int(args.get("lvlA", "2"))
	var lvlB := int(args.get("lvlB", "1"))
	var prmA: Dictionary = JSON.parse_string(args.get("prmA", "{}"))
	var prmB: Dictionary = JSON.parse_string(args.get("prmB", "{}"))
	var seed0 := int(args.get("seed", "1000"))
	var stats := {"A": {"wins": 0.0, "score": 0, "n": 0}, "B": {"wins": 0.0, "score": 0, "n": 0}}
	var acts := {"A": {}, "B": {}}
	var comp := {"A": {}, "B": {}}
	var t0 := Time.get_ticks_msec()
	var famrng := RandomNumberGenerator.new()
	famrng.seed = seed0
	for gi in games:
		var eng := GameEngine.new()
		eng.ai_delay = 0.0
		add_child(eng)
		var fams: Array = Data.FAMILY_ORDER.duplicate()
		for k in range(fams.size() - 1, 0, -1):
			var j := famrng.randi_range(0, k)
			var tmp = fams[k]
			fams[k] = fams[j]
			fams[j] = tmp
		var ps := []
		var grp := []
		for i in np:
			var isA := (i + gi) % 2 == 0
			grp.append("A" if isA else "B")
			ps.append({"name": "%s[%s]" % [Data.FAMILIES[fams[i]].name, "A" if isA else "B"], "family": fams[i], "side": "A",
				"ai": true, "level": lvlA if isA else lvlB, "ai_prm": prmA if isA else prmB})
		eng.setup({"players": ps, "seed": seed0 + gi})
		var counters := {}
		eng.log_msg.connect(func(t, k):
			if verbose:
				print("  [", k, "] ", t)
			for key in ["Congelare", "veto", "corrompe", "Maltempo", "Lega Santa", "rilanciare i dadi", "Rubare Oro", "Rubare Influenza", "Lucrezia", "Iniziare una Guerra", "stallo", "vince"]:
				if key in t and k != "bid":
					counters[key] = counters.get(key, 0) + 1)
		await eng.run()
		var res: Array = eng.results
		var line := "Partita %d: " % gi
		for r in res:
			line += "%s %d (c%d e%d m%d p%d o%d i%d v%d) | " % [r.name, r.total, r.cities, r.events, r.merchants, r.pope, r.gold, r.inf, r.counters]
			var gg: String = grp[r.pid]
			stats[gg].score += r.total
			stats[gg].n += 1
			for k2 in ["cities", "events", "merchants", "pope", "gold", "inf", "counters"]:
				comp[gg][k2] = comp[gg].get(k2, 0) + r[k2]
			var st: Dictionary = eng.action_stats.get(r.pid, {})
			for k3 in st:
				acts[gg][k3] = acts[gg].get(k3, 0) + st[k3]
		var top: int = res[0].total
		var nwin := 0
		for r in res:
			if r.total == top:
				nwin += 1
		for r in res:
			if r.total == top:
				stats[grp[r.pid]].wins += 1.0 / nwin
		if verbose or games <= 12:
			print(line)
			print("   status: ", eng.status, " turni: ", eng.turn_number, " ", counters)
		eng.queue_free()
	for k in stats:
		var s: Dictionary = stats[k]
		print("Gruppo %s: vittorie %.1f/%d  punteggio medio %.2f" % [k, s.wins, games, float(s.score) / max(1, s.n)])
		var cs := ""
		for k2 in comp[k]:
			cs += "%s %.1f " % [k2, float(comp[k][k2]) / max(1, s.n)]
		print("   componenti: ", cs)
		var as_ := ""
		for k3 in acts[k]:
			as_ += "%s %.1f " % [k3, float(acts[k][k3]) / max(1, s.n)]
		print("   azioni/partita: ", as_)
	print("tempo ms: ", Time.get_ticks_msec() - t0)
	get_tree().quit()
