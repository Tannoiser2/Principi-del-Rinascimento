class_name MapView
extends Control
## Plancia: mappa d'Italia con Status delle città, classifica PV, segnalino Guerre,
## marcatori di guerra, Artisti assegnati e Oro in attesa nelle città natali.

signal city_clicked(c: String)
signal city_hover(c: String, on: bool)

var g: GameEngine
var map_tex: Texture2D
var selectable_cities: Array = []
var highlight := {}       # città -> colore
var _t := 0.0
var _hover_city := ""
var _prev_status := {}
var _fx: Array = []     # [città, delta, tempo]

const ROW_Y := {10: 0.5926, 9: 0.6413, 8: 0.6900, 7: 0.7387, 6: 0.7874, 5: 0.8360, 4: 0.8847, 3: 0.9334}
const VP_Y := [0.598, 0.645, 0.695, 0.743, 0.790]
const WAR_X := [0.383, 0.481, 0.582, 0.690, 0.800, 0.915]
const AUCTION_RECT := Rect2(0.012, 0.355, 0.178, 0.170)

func _ready() -> void:
	map_tex = load("res://assets/ui/mappa.jpg")
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)

func _process(d: float) -> void:
	_t += d
	if g:
		for c in Data.CITIES:
			if _prev_status.has(c) and _prev_status[c] != g.status[c]:
				_fx.append([c, g.status[c] - _prev_status[c], 0.0])
			_prev_status[c] = g.status[c]
	for e in _fx:
		e[2] += d
	_fx = _fx.filter(func(e): return e[2] < 2.2)
	queue_redraw()

func P(fx: float, fy: float) -> Vector2:
	return Vector2(fx * size.x, fy * size.y)

func city_rect(c: String) -> Rect2:
	var cp: Vector2 = Data.CITY_MAP_POS[c]
	var s: Vector2 = Data.CITY_BOX_SIZE
	return Rect2(P(cp.x - s.x / 2, cp.y - s.y / 2), P(s.x, s.y))

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var hc := ""
		for c in Data.CITIES:
			if city_rect(c).has_point(e.position):
				hc = c
		if hc != _hover_city:
			if _hover_city != "":
				city_hover.emit(_hover_city, false)
			_hover_city = hc
			if hc != "":
				city_hover.emit(hc, true)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hc in selectable_cities else Control.CURSOR_ARROW
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for c in Data.CITIES:
			if city_rect(c).has_point(e.position) and c in selectable_cities:
				Sfx.play("card", -6)
				city_clicked.emit(c)

func _draw() -> void:
	draw_texture_rect(map_tex, Rect2(Vector2.ZERO, size), false)
	if g == null:
		return
	var f: Font = UI.f_head
	var W := size.x
	var rad := W * 0.019
	# --- Status delle città
	var by_status := {}
	for c in Data.CITIES:
		var s: int = g.status[c]
		if not by_status.has(s):
			by_status[s] = []
		by_status[s].append(c)
	for s in by_status:
		var k := 0
		for c in by_status[s]:
			var pos := P(0.071 + 0.040 * k, ROW_Y[s])
			_disc(pos, rad, Data.CITY_COLOR[c], Data.CITY_NAME[c].substr(0, 2))
			k += 1
	# --- classifica attuale (PV per città)
	var ranking := g.city_ranking()
	var cs: Array = Data.CITIES.duplicate()
	cs.sort_custom(func(a, b):
		if g.status[a] != g.status[b]:
			return g.status[a] > g.status[b]
		return g.artists[a] > g.artists[b])
	for i in cs.size():
		var c: String = cs[i]
		var pos2 := P(0.425, VP_Y[i])
		_disc(pos2, rad * 0.75, Data.CITY_COLOR[c], "")
		draw_string(f, pos2 + Vector2(rad + 2, 6), "%s %d" % [Data.CITY_NAME[c].substr(0, 3), ranking[c]], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.15, 0.1, 0.05))
	# --- segnalino Guerre
	var wi := clampi(g.wars_fought, 0, 5)
	var wp := P(WAR_X[wi], 0.925)
	draw_circle(wp + Vector2(2, 3), rad * 0.9, Color(0, 0, 0, 0.5))
	draw_circle(wp, rad * 0.9, Color(0.08, 0.06, 0.05))
	draw_arc(wp, rad * 0.9, 0, TAU, 32, Color(0.85, 0.7, 0.35), 2.0)
	var sw2 := rad * 0.5
	draw_line(wp + Vector2(-sw2, -sw2), wp + Vector2(sw2, sw2), Color(0.95, 0.85, 0.6), 2.5)
	draw_line(wp + Vector2(sw2, -sw2), wp + Vector2(-sw2, sw2), Color(0.95, 0.85, 0.6), 2.5)
	var lim := g.war_limit
	draw_string(f, P(0.33, 0.968), "Guerre: %d / %d" % [g.wars_fought, lim], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.2, 0.1, 0.05))
	# --- città: riquadri
	for c in Data.CITIES:
		var r := city_rect(c)
		if c in selectable_cities:
			var a := 0.5 + 0.5 * sin(_t * 4.0)
			draw_rect(r.grow(6), Color(1, 0.82, 0.3, a), false, 4.0)
		if highlight.has(c):
			draw_rect(r.grow(4), highlight[c], false, 5.0)
		# medaglione Status
		var mc := r.position + Vector2(r.size.x / 2, r.size.y * 0.30)
		draw_circle(mc + Vector2(2, 3), rad * 1.25, Color(0, 0, 0, 0.5))
		draw_circle(mc, rad * 1.25, Color(0.12, 0.08, 0.05, 0.92))
		draw_arc(mc, rad * 1.25, 0, TAU, 40, Color(0.9, 0.75, 0.4), 2.5)
		var st := str(g.status[c])
		var sw := f.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		draw_string(f, mc + Vector2(-sw / 2, 10), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 0.9, 0.6))
		# Artisti +1
		var na: int = g.artists[c]
		for k in na:
			var sp := r.position + Vector2(8 + k * 22, r.size.y * 0.52)
			draw_circle(sp, 9, Color(0.85, 0.65, 0.15))
			draw_string(f, sp + Vector2(-7, 5), "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.2, 0.05, 0.05))
		# chi possiede tessere di questa città
		var px := r.position + Vector2(6, r.size.y * 0.66)
		for p in g.players:
			var n := 0
			for t in p.cities:
				if Data.city_tile(t).city == c:
					n += 1
			for k2 in n:
				draw_rect(Rect2(px, Vector2(12, 12)), p.color, true)
				draw_rect(Rect2(px, Vector2(12, 12)), Color(0, 0, 0, 0.8), false, 1.5)
				px.x += 14
				if px.x > r.end.x - 14:
					px.x = r.position.x + 6
					px.y += 14
	# --- Oro in attesa nelle città natali
	for p in g.players:
		var hp: Vector2 = Data.FAMILIES[p.family].home_pos
		var pos3 := P(hp.x, hp.y) + Vector2(-26, -4)
		_disc(pos3, rad * 0.62, p.color, "")
		if p.home_gold > 0:
			draw_string(f, pos3 + Vector2(-5, -12), "+%d" % p.home_gold, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.3, 0.0))
	# --- spazio asta (martelletto)
	var ar := Rect2(P(AUCTION_RECT.position.x, AUCTION_RECT.position.y), P(AUCTION_RECT.size.x, AUCTION_RECT.size.y))
	if g.auction.size() > 0 and str(g.auction.get("item", "")) != "":
		var tx := Data.item_tex(g.auction.item)
		if tx:
			var ts := tx.get_size()
			var sc: float = min(ar.size.x / ts.x, ar.size.y / ts.y) * 0.92
			var ds := ts * sc
			draw_texture_rect(tx, Rect2(ar.get_center() - ds / 2, ds), false)
	_draw_war()
	_draw_fx()

const ATT_COL := Color(0.86, 0.12, 0.08)
const DEF_COL := Color(0.18, 0.42, 0.92)

func _bez(p0: Vector2, c: Vector2, p1: Vector2, u: float) -> Vector2:
	var a := 1.0 - u
	return a * a * p0 + 2.0 * a * u * c + u * u * p1

## Freccia curva animata: corpo dalla coda alla testa, punta triangolare
func _curved_arrow(p0: Vector2, c: Vector2, p1: Vector2, head_u: float, len_u: float, col: Color, width: float) -> void:
	var u0: float = max(0.0, head_u - len_u)
	var pts := PackedVector2Array()
	var steps := 18
	for k in steps + 1:
		pts.append(_bez(p0, c, p1, lerpf(u0, head_u, float(k) / steps)))
	if pts.size() < 2:
		return
	var shadow := Color(0, 0, 0, 0.55 * col.a)
	draw_polyline(pts, shadow, width + 5.0, true)
	draw_polyline(pts, col, width, true)
	# riflesso
	draw_polyline(pts, Color(1, 1, 1, 0.25 * col.a), max(1.0, width * 0.25), true)
	var tip: Vector2 = pts[pts.size() - 1]
	var dirv: Vector2 = (tip - pts[pts.size() - 2]).normalized()
	var nrm := Vector2(-dirv.y, dirv.x)
	var hl := width * 2.6
	var tri := PackedVector2Array([tip + dirv * hl * 0.55, tip - dirv * hl * 0.6 + nrm * hl * 0.75, tip - dirv * hl * 0.6 - nrm * hl * 0.75])
	draw_colored_polygon(PackedVector2Array([tri[0] + dirv * 3, tri[1] + (tri[1] - tip).normalized() * 3, tri[2] + (tri[2] - tip).normalized() * 3]), shadow)
	draw_colored_polygon(tri, col)

func _banner(r: Rect2, txt: String, col: Color, above: bool) -> void:
	var f: Font = UI.f_head
	var fs := 17
	var tw: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 26
	var y: float = r.position.y - 30 if above else r.end.y + 4
	y = clampf(y, 2, size.y - 30)
	var br := Rect2(Vector2(r.get_center().x - tw / 2, y), Vector2(tw, 26))
	draw_rect(Rect2(br.position + Vector2(3, 3), br.size), Color(0, 0, 0, 0.5))
	draw_rect(br, col)
	# code della pergamena
	draw_colored_polygon(PackedVector2Array([br.position, br.position + Vector2(-10, 13), br.position + Vector2(0, 26)]), col.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([br.position + Vector2(br.size.x, 0), br.position + Vector2(br.size.x + 10, 13), br.position + Vector2(br.size.x, 26)]), col.darkened(0.3))
	draw_rect(br, Color(1, 0.9, 0.6, 0.9), false, 1.5)
	draw_string(f, br.position + Vector2(13, 19), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1))

func _draw_war() -> void:
	if g.war.size() == 0:
		return
	var ra := city_rect(g.war.att)
	var rd := city_rect(g.war.def)
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	# cornici colorate
	draw_rect(ra.grow(7), Color(ATT_COL.r, ATT_COL.g, ATT_COL.b, 0.55 + 0.45 * pulse), false, 7.0)
	draw_rect(rd.grow(7), Color(DEF_COL.r, DEF_COL.g, DEF_COL.b, 0.55 + 0.45 * pulse), false, 7.0)
	draw_rect(ra.grow(2), Color(1, 0.85, 0.7, 0.5), false, 1.5)
	draw_rect(rd.grow(2), Color(0.85, 0.9, 1, 0.5), false, 1.5)
	# frecce curve che si scontrano, in loop
	var ca: Vector2 = ra.get_center()
	var cd: Vector2 = rd.get_center()
	var dirv: Vector2 = cd - ca
	var L: float = dirv.length()
	if L > 10:
		var dn: Vector2 = dirv / L
		var nrm := Vector2(-dn.y, dn.x)
		# partenza dal bordo del riquadro di ciascuna città
		var ea: float = min(ra.size.x * 0.5 / max(0.001, absf(dn.x)), ra.size.y * 0.5 / max(0.001, absf(dn.y))) + 4.0
		var ed: float = min(rd.size.x * 0.5 / max(0.001, absf(dn.x)), rd.size.y * 0.5 / max(0.001, absf(dn.y))) + 4.0
		var a0: Vector2 = ca + dn * ea
		var d0: Vector2 = cd - dn * ed
		var mid: Vector2 = (a0 + d0) * 0.5
		var gap: float = (d0 - a0).length()
		var bulge: float = clampf(gap * 0.55, 55.0, 170.0)
		var clash: Vector2 = mid + nrm * bulge * 0.12
		var a1: Vector2 = clash - dn * 12.0
		var d1: Vector2 = clash + dn * 12.0
		var ac: Vector2 = (a0 + a1) * 0.5 + nrm * bulge
		var dc: Vector2 = (d0 + d1) * 0.5 - nrm * bulge * 0.9
		# tracce punteggiate
		for k in 30:
			var u := float(k) / 30.0
			draw_circle(_bez(a0, ac, a1, u), 2.2, Color(ATT_COL.r, ATT_COL.g, ATT_COL.b, 0.4))
			draw_circle(_bez(d0, dc, d1, u), 2.2, Color(DEF_COL.r, DEF_COL.g, DEF_COL.b, 0.4))
		var ph: float = fmod(_t * 0.5, 1.0)
		var head: float = clampf(ph / 0.7, 0.0, 1.0)
		head = 1.0 - pow(1.0 - head, 2.0)
		var fade: float = 1.0 if ph < 0.86 else clampf(1.0 - (ph - 0.86) / 0.14, 0.0, 1.0)
		var ac_col := Color(ATT_COL.r, ATT_COL.g, ATT_COL.b, fade)
		var dc_col := Color(DEF_COL.r, DEF_COL.g, DEF_COL.b, fade)
		_curved_arrow(a0, ac, a1, head, 0.75, ac_col, 12.0)
		_curved_arrow(d0, dc, d1, head, 0.75, dc_col, 12.0)
		# scontro: scintille
		if ph >= 0.7:
			var k2: float = clampf((ph - 0.7) / 0.3, 0.0, 1.0)
			for i in 12:
				var ang := TAU * i / 12.0 + _t * 0.7
				var r1: float = 10.0 + 34.0 * k2
				draw_line(clash + Vector2(cos(ang), sin(ang)) * r1 * 0.35, clash + Vector2(cos(ang), sin(ang)) * r1, Color(1, 0.85, 0.3, 1.0 - k2), 3.5)
			draw_circle(clash, 14.0 * (1.0 - k2) + 3.0, Color(1, 0.95, 0.7, 1.0 - k2))
		# spade incrociate nel punto di scontro
		var sw := 15.0
		draw_line(clash + Vector2(-sw, -sw), clash + Vector2(sw, sw), Color(0, 0, 0, 0.6), 7.0)
		draw_line(clash + Vector2(sw, -sw), clash + Vector2(-sw, sw), Color(0, 0, 0, 0.6), 7.0)
		draw_line(clash + Vector2(-sw, -sw), clash + Vector2(sw, sw), Color(0.97, 0.92, 0.78), 3.5)
		draw_line(clash + Vector2(sw, -sw), clash + Vector2(-sw, sw), Color(0.97, 0.92, 0.78), 3.5)
	# stendardi ATTACCA / DIFENDE
	_banner(ra, "ATTACCA · " + Data.CITY_NAME[g.war.att].to_upper(), ATT_COL.darkened(0.15), ra.position.y > 40)
	_banner(rd, "DIFENDE · " + Data.CITY_NAME[g.war.def].to_upper(), DEF_COL.darkened(0.2), rd.position.y > 40)

func _draw_fx() -> void:
	var f: Font = UI.f_bold
	for e in _fx:
		var r := city_rect(e[0])
		var k: float = e[2] / 2.2
		var txt := ("+%d" % e[1]) if e[1] > 0 else str(e[1])
		var col := Color(0.5, 1.0, 0.45) if e[1] > 0 else Color(1.0, 0.35, 0.3)
		col.a = 1.0 - k * k
		var pos := r.get_center() + Vector2(-24, -20 - 60 * k)
		draw_string(f, pos + Vector2(3, 3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color(0, 0, 0, col.a * 0.8))
		draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 54, col)
		draw_rect(r.grow(8 + 10 * k), Color(col.r, col.g, col.b, col.a * 0.6), false, 4.0)

func _disc(pos: Vector2, r: float, col: Color, txt: String, tcol := Color(1, 1, 1)) -> void:
	draw_circle(pos + Vector2(2, 3), r, Color(0, 0, 0, 0.45))
	draw_circle(pos, r, col)
	draw_arc(pos, r, 0, TAU, 32, col.darkened(0.5), 2.0)
	draw_circle(pos + Vector2(-r * 0.3, -r * 0.35), r * 0.35, Color(1, 1, 1, 0.18))
	if txt != "":
		var f: Font = UI.f_head
		var fs := int(r * 0.95)
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, pos + Vector2(-w / 2, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tcol)
