class_name TutorialOverlay
extends Control
## Tutorial: velo scuro con un "faro" sulla zona spiegata e un cartiglio di pergamena con il testo.
## Usato sia per il giro introduttivo del tavolo sia per i suggerimenti durante la partita.

signal closed(skipped: bool)

const W := 620.0
const TITLE_COL := Color("7a1a1a")

var steps: Array = []       # [{title, text, rect: Rect2 | Callable | null}]
var idx := 0
var tip_mode := false       # true: un solo suggerimento con «Ho capito»
var auto_advance := 0.0     # modalità di prova: avanza da solo
var hole := Rect2()
var _t := 0.0
var _auto_t := 0.0

var card: PanelContainer
var title_l: Label
var body: RichTextLabel
var count_l: Label
var btn_prev: Button
var btn_next: Button
var btn_skip: Button
var mute_cb: CheckBox

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 80
	card = UI.parchment_panel(22)
	card.custom_minimum_size.x = W
	add_child(card)
	var v := UI.vbox(10)
	card.add_child(v)
	var top := UI.hbox(10)
	v.add_child(top)
	var ic := UI.tex_rect(load("res://assets/ui/laurel.png"), Vector2(34, 34))
	top.add_child(ic)
	title_l = UI.label("", 30, TITLE_COL, UI.f_title)
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(title_l)
	count_l = UI.label("", 16, Color(0.45, 0.32, 0.18), UI.f_italic)
	top.add_child(count_l)
	var line := ColorRect.new()
	line.color = Color(0.6, 0.45, 0.2, 0.6)
	line.custom_minimum_size.y = 2
	v.add_child(line)
	body = RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.custom_minimum_size.x = W - 44
	body.add_theme_color_override("default_color", UI.INK)
	body.add_theme_font_size_override("normal_font_size", 20)
	body.add_theme_font_size_override("bold_font_size", 20)
	body.add_theme_font_size_override("italics_font_size", 19)
	body.add_theme_font_override("bold_font", UI.f_bold)
	v.add_child(body)
	var bot := UI.hbox(10)
	v.add_child(bot)
	if tip_mode:
		mute_cb = CheckBox.new()
		mute_cb.text = "Basta suggerimenti"
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			mute_cb.add_theme_color_override(k, Color(0.35, 0.22, 0.1))
		for k in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			mute_cb.add_theme_stylebox_override(k, StyleBoxEmpty.new())
		mute_cb.tooltip_text = "Non mostrare altri suggerimenti in questa partita"
		mute_cb.add_theme_font_size_override("font_size", 16)
		bot.add_child(mute_cb)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bot.add_child(sp)
		btn_next = UI.button("Ho capito", func(): _close(false), 180)
		bot.add_child(btn_next)
	else:
		btn_skip = UI.button("Salta il giro", func(): _close(true), 0)
		bot.add_child(btn_skip)
		var sp2 := Control.new()
		sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bot.add_child(sp2)
		btn_prev = UI.button("◀ Indietro", func(): _go(idx - 1), 150)
		bot.add_child(btn_prev)
		btn_next = UI.button("Avanti ▶", func(): _go(idx + 1), 170)
		bot.add_child(btn_next)
	_go(0)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if auto_advance > 0.0:
		_auto_t += delta
		if _auto_t >= auto_advance:
			_auto_t = 0.0
			if tip_mode or idx >= steps.size() - 1:
				_close(false)
			else:
				_go(idx + 1)

func _unhandled_key_input(e: InputEvent) -> void:
	if e.is_pressed() and not e.is_echo():
		if e.is_action("ui_accept") or e.is_action("ui_right"):
			if tip_mode or idx >= steps.size() - 1:
				_close(false)
			else:
				_go(idx + 1)
			get_viewport().set_input_as_handled()
		elif e.is_action("ui_left") and not tip_mode:
			_go(idx - 1)
			get_viewport().set_input_as_handled()

func _go(i: int) -> void:
	if i >= steps.size():
		_close(false)
		return
	idx = clampi(i, 0, steps.size() - 1)
	var s: Dictionary = steps[idx]
	title_l.text = s.get("title", "")
	body.text = str(s.get("text", "")).replace("[b]", "[b][color=#6e1a10]").replace("[/b]", "[/color][/b]")
	if not tip_mode:
		count_l.text = "%d / %d" % [idx + 1, steps.size()]
		btn_prev.disabled = idx == 0
		btn_next.text = "Inizia a giocare ▶" if idx == steps.size() - 1 else "Avanti ▶"
	Sfx.play("card", -14, 1.2)
	card.modulate.a = 0.0
	hole = Rect2()
	# la zona può comparire o spostarsi (es. riquadri d'asta): si misura dopo due frame
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var r = s.get("rect", null)
	if r is Callable:
		r = r.call()
	hole = r.grow(6) if r is Rect2 and r.has_area() else Rect2()
	_place_card()
	var tw := create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.25)

func _place_card() -> void:
	card.reset_size()
	var sz: Vector2 = card.get_combined_minimum_size()
	sz.x = max(sz.x, W)
	card.size = sz
	var vp := Vector2(1920, 1080)
	var pos := (vp - sz) / 2.0
	if hole.has_area():
		var cy: float = hole.get_center().y - sz.y / 2.0
		if hole.end.x + 28 + sz.x <= vp.x - 12:
			pos = Vector2(hole.end.x + 28, cy)
		elif hole.position.x - 28 - sz.x >= 12:
			pos = Vector2(hole.position.x - 28 - sz.x, cy)
		elif hole.end.y + 24 + sz.y <= vp.y - 12:
			pos = Vector2(hole.get_center().x - sz.x / 2.0, hole.end.y + 24)
		elif hole.position.y - 24 - sz.y >= 12:
			pos = Vector2(hole.get_center().x - sz.x / 2.0, hole.position.y - 24 - sz.y)
		else:
			# la zona copre quasi tutto: il cartiglio va nell'angolo meno coperto
			pos = Vector2(vp.x - sz.x - 24 if hole.get_center().x < vp.x / 2 else 24, vp.y - sz.y - 24)
	pos.x = clampf(pos.x, 12, vp.x - sz.x - 12)
	pos.y = clampf(pos.y, 12, vp.y - sz.y - 12)
	card.position = pos

func _draw() -> void:
	var dark := Color(0, 0, 0, 0.5 if tip_mode else 0.64)
	var vp := Rect2(Vector2.ZERO, Vector2(1920, 1080))
	if not hole.has_area():
		draw_rect(vp, dark)
		return
	var h := hole.intersection(vp)
	draw_rect(Rect2(0, 0, vp.size.x, h.position.y), dark)
	draw_rect(Rect2(0, h.end.y, vp.size.x, vp.size.y - h.end.y), dark)
	draw_rect(Rect2(0, h.position.y, h.position.x, h.size.y), dark)
	draw_rect(Rect2(h.end.x, h.position.y, vp.size.x - h.end.x, h.size.y), dark)
	var a: float = 0.55 + 0.45 * sin(_t * 4.0)
	draw_rect(h, Color(UI.GOLD, a), false, 4.0)
	draw_rect(h.grow(5), Color(UI.GOLD, a * 0.35), false, 3.0)

func _close(skipped: bool) -> void:
	if not is_inside_tree():
		return
	var muted: bool = mute_cb != null and mute_cb.button_pressed
	set_process(false)
	closed.emit(skipped or muted)
	queue_free()

# ================================================================ contenuti

## Giro introduttivo del tavolo. `r` contiene le zone dello schermo (Rect2) misurate dal tavolo.
static func intro_steps(r: Dictionary, fam: String, side: String) -> Array:
	var F: Dictionary = Data.FAMILIES[fam]
	var s: Array = []
	s.append({"title": "Benvenuto, Principe!", "text":
		"Italia, 1470. Guiderai la famiglia [b]%s[/b] di %s: una casata di [b]Condottieri[/b] che si arricchisce combattendo per le grandi città e investendo in esse.\n\nLo scopo è avere più [b]Punti Vittoria (PV)[/b] alla fine della [b]terza Decade[/b]. Quasi tutti i PV arrivano dalle [b]tessere Città[/b]: ognuna vale tanto quanto la sua città sarà in alto nella classifica dello [b]Status[/b] a fine partita.\n\nPrima facciamo un giro del tavolo; poi giocherai una vera partita contro tre IA [i]Facili[/i], con un suggerimento ogni volta che incontri qualcosa di nuovo.\n[i](Puoi usare anche le frecce ◀ ▶ della tastiera.)[/i]" % [F.name, F.home]})
	s.append({"title": "La mappa e lo Status", "rect": r.map, "text":
		"Le cinque grandi città: [b]Milano, Venezia, Firenze, Roma e Napoli[/b]. Il disco su ogni città indica il suo [b]Status[/b] (da 3 a 10).\n\nLo Status [b]sale[/b] con le vittorie in guerra e con gli Artisti, [b]scende[/b] con le sconfitte e con l'Invasione Francese.\n\nA fine partita le città vengono ordinate per Status e ogni tessera vale [b]10, 7, 5, 3 o 2 PV[/b]. Sulla mappa vedi la classifica attuale, il segnalino delle Guerre e l'Oro guadagnato dai Condottieri che attende nelle città natali delle famiglie."})
	s.append({"title": "Decade, turno e guerre", "rect": r.header, "text":
		"In alto: la [b]Decade[/b] in corso, di chi è il [b]turno[/b], quante [b]guerre[/b] sono già state combattute in questa Decade (al massimo 4, o 5 con 5–6 giocatori) e quante carte Tradimento restano nel mazzo.\n\nIl pulsante [b]Menu[/b] apre velocità dell'IA, suoni, regole e salvataggio."})
	s.append({"title": "Eventi e Papa", "rect": r.events, "text":
		"Gli [b]Eventi[/b] della Decade si vincono all'asta, in Oro (simbolo rotondo) o in Influenza (simbolo quadrato); l'offerta d'apertura può essere 0. Danno PV, [b]Artisti[/b] (+1 Status a una città a tua scelta), l'[b]Invasione Francese[/b] (−2 Status) e altro: passa il mouse per leggerli.\n\n[b]Attenzione:[/b] quando viene aggiudicato l'[b]ultimo Evento[/b] la Decade finisce subito. Chi è in vantaggio ha fretta, chi è indietro no.\n\nIl [b]Papa[/b] si paga in Influenza: rende 3 Oro a fine Decade, può formare la Lega Santa e nell'ultima Decade vale 3 PV."})
	s.append({"title": "Le tessere Città", "rect": r.cities, "text":
		"Le tessere sono divise per città. Accanto al nome trovi lo [b]Status[/b] e l'[b]offerta minima[/b] (il doppio dello Status, in Oro).\n\nOgni tessera dà una [b]rendita[/b] a fine Decade e quasi sempre un'[b]abilità speciale[/b]: passaci sopra il mouse per vederla ingrandita.\n\nPuoi avere tessere di [b]al massimo 3 città[/b] e [b]6 tessere[/b] in tutto, e non le perdi mai. Il cuore del gioco è scegliere le città giuste e poi farne salire lo Status."})
	s.append({"title": "Le Truppe", "rect": r.troops, "text":
		"Le [b]Truppe[/b] si comprano in Oro al prezzo indicato; ne puoi avere [b]una per tipo[/b] e il numero dice quante ne restano. Ognuna ha un valore di [b]Attacco[/b] e di [b]Difesa[/b].\n\nSenza Truppe non puoi fare il [b]Condottiero[/b] nelle guerre, che è il modo principale per guadagnare Oro, pedine Vittoria e spostare lo Status delle città. Cavalleria e Artiglieria arrivano dalla Decade II (solo i d'Este, lato A, possono comprare l'Artiglieria già nella prima) e rendono anche Influenza."})
	s.append({"title": "Le famiglie in gioco", "rect": r.players, "text":
		"Per ogni famiglia: [b]Oro[/b], [b]Influenza[/b], pedine [b]Vittoria[/b], carte Tradimento in mano e una [b]stima dei PV[/b] (≈).\n\nLa [b]spada[/b] e lo [b]scudo[/b] sono la sua [b]forza militare[/b] come Condottiero: Attacco e Difesa totali (Truppe più bonus di famiglia e di tessere). In battaglia si aggiunge un dado. Passa il mouse per il dettaglio.\n\nSotto ci sono le tessere Città raggruppate per città (lettera colorata), poi Truppe ed Eventi. Il bordo [b]dorato[/b] indica di chi è il turno, quello [b]verde[/b] chi sta vincendo l'asta."})
	s.append({"title": "La tua famiglia", "rect": r.mine, "text":
		"Questa è la tua casata: [b]%s[/b], lato %s.\n[i]%s.[/i]\n\nOgni famiglia parte con 40 Oro e 12 Influenza e a ogni fine Decade riceve 12 Oro e 8 Influenza, più le rendite delle sue tessere. Oro e Influenza sono sempre visibili a tutti: anche le IA guardano quanto puoi spendere!" % [F.name, side, F["txt" + side]]})
	s.append({"title": "La barra delle azioni", "rect": r.actions, "text":
		"Qui compaiono le istruzioni e i pulsanti quando tocca a te.\n\nNel tuo turno fai [b]una sola azione[/b]:\n• [b]Mettere all'asta[/b] una tessera Città, un Evento o il Papa: clicca la tessera;\n• [b]Comprare[/b] una Truppa (clicca la Truppa) o una carta Tradimento (1 Oro + 1 Influenza);\n• [b]Dichiarare una Guerra[/b];\n• [b]Passare[/b].\nPrima dell'azione puoi usare le azioni gratuite (Rubare Oro, Lucrezia Borgia, Banchiere…) e proporre accordi."})
	s.append({"title": "Le carte Tradimento", "rect": r.hand, "text":
		"Le tue carte [b]Tradimento[/b], coperte per gli altri. Si pescano a caso e di norma se ne tengono al massimo 2.\n\n[b]Congelare un'Offerta[/b] blocca un rivale in un'asta, [b]Corrompere Truppe[/b] toglie una Truppa da una battaglia, il [b]Veto[/b] annulla una guerra, [b]Maltempo[/b] dà −1 a una parte, [b]Rubare[/b] Oro o Influenza… Usate al momento giusto ribaltano una partita."})
	if r.has("deals"):
		s.append({"title": "Patti in corso", "rect": r.deals, "text":
			"Si può trattare: pagare in Oro o Influenza perché un rivale non rilanci, combatta per te, ponga un Veto…\n\nGli accordi [b]non sono vincolanti[/b]: chi tradisce viene smascherato nella cronaca e perde reputazione, e le IA se lo ricordano. Qui sono elencati i patti attivi (in oro quelli che ti riguardano). I tipi ammessi si scelgono nel menu [b]Accordi e Trattative[/b]."})
	s.append({"title": "La cronaca", "rect": r.log, "text":
		"Tutto ciò che accade – offerte, guerre, dadi, tradimenti – viene annotato qui. Se ti sei perso una mossa delle IA, guarda la cronaca."})
	s.append({"title": "Le guerre in breve", "rect": r.map, "text":
		"Chi dichiara guerra sceglie una città che [b]attacca[/b] (cornice rossa) e una che [b]difende[/b] (cornice blu).\n\nSi fa un'asta in [b]Influenza[/b] per diventare il [b]Condottiero[/b] di ciascuna parte (serve almeno una Truppa). La città paga al suo Condottiero tanto Oro quanto il proprio Status.\n\n[b]Assalto[/b]: Attacco + dado contro Difesa + dado. Se l'attaccante non supera, il difensore tenta il [b]Contrattacco[/b]. Chi vince guadagna 1 Status (2 se ha fatto almeno il doppio) e il suo Condottiero una pedina Vittoria."})
	s.append({"title": "Fine Decade e punteggio", "text":
		"La Decade termina quando si aggiudica l'ultimo Evento: tutti incassano le [b]rendite[/b] e il Papa torna all'asta.\n\nDopo la terza Decade si contano i PV:\n• tessere Città secondo la classifica dello Status ([b]10, 7, 5, 3, 2[/b]);\n• PV degli Eventi e del Papa (3);\n• più Oro: [b]6 PV[/b], secondo: 3 PV; più Influenza: [b]4 PV[/b];\n• pedine Vittoria: 1, 3, 6, 10, 15… PV.\n\n[b]Consiglio:[/b] fai salire le città in cui hai investito… e combatti contro quelle dei tuoi rivali."})
	s.append({"title": "Tocca a te!", "text":
		"La partita comincia. Ogni volta che incontri qualcosa di nuovo – il tuo primo turno, un'asta, una guerra, i dadi – il gioco si ferma e ti spiega cosa fare.\n\nPuoi rileggere le regole in qualsiasi momento da [b]Menu → Regole[/b]. Buona fortuna, e diffida di chi ti offre un patto troppo generoso!"})
	return s

## Suggerimenti contestuali: chiave → titolo e testo
const TIPS := {
	"turn": ["Il tuo primo turno", "Scegli [b]una[/b] azione:\n• clicca una [b]tessera Città[/b] o un [b]Evento[/b] illuminato per metterlo all'asta (le città costano almeno il doppio dello Status);\n• clicca una [b]Truppa[/b] per comprarla;\n• oppure usa i pulsanti in basso (carta Tradimento, Dichiara Guerra, Passa…).\n\n[b]Consiglio d'apertura:[/b] una tessera di una città con Status alto e una Truppa economica (Fanteria o Balestrieri) per poter fare il Condottiero."],
	"bid": ["L'asta", "Si offre a turno in senso orario. Con [b]− / +[/b] scegli la cifra e premi [b]Offri[/b]; con [b]Passa[/b] esci [b]definitivamente[/b] da quest'asta. Vince l'ultimo rimasto.\n\nSe hai la carta, [b]Congela[/b] impedisce a un rivale di rilanciare al prossimo giro. Guarda Oro e Influenza degli avversari: sai fin dove possono arrivare. Le IA a volte rilanciano solo per farti pagare di più!"],
	"condo_bid": ["Asta per il Condottiero", "Ora si sceglie chi guiderà l'esercito: l'asta è in [b]Influenza[/b] e partecipa solo chi ha almeno una Truppa.\n\nIl Condottiero riceve dalla città tanto [b]Oro quanto il suo Status[/b] (lo incassa a fine Decade) e, se vince, una [b]pedina Vittoria[/b]. Combatterai con la tua forza: guarda la spada e lo scudo nel tuo riquadro.\n\nSe nessuno guida una parte, quella città combatte con valore 3."],
	"war": ["Una guerra!", "La città con la cornice [b]rossa[/b] attacca, quella con la cornice [b]blu[/b] difende: le frecce sulla mappa lo mostrano.\n\nIl riquadro della guerra mostra Condottieri, Truppe e la [b]probabilità di vittoria[/b]. Pensa a quale esito ti conviene: se hai tessere della città che attacca, vuoi che vinca!"],
	"dice": ["I dadi", "[b]Assalto[/b]: Attacco dell'attaccante + 1 dado contro Difesa del difensore + 1 dado. Se l'attaccante ottiene di più, vince.\n\nAltrimenti il difensore tenta il [b]Contrattacco[/b] (il suo Attacco + dado contro la Difesa dell'attaccante + dado). Se nessuno supera l'altro è stallo.\n\nUna vittoria con [b]almeno il doppio[/b] è schiacciante: lo Status cambia di 2 invece di 1."],
	"veto": ["Il Veto", "Puoi impedire questa guerra: non avrà luogo, ma conta comunque nel limite delle guerre della Decade. Usalo se l'esito probabile danneggia le tue città."],
	"bribe": ["Corrompere Truppe", "Scegli una Truppa di un Condottiero: non combatterà in questa guerra. Toglila alla parte che vuoi far perdere, e scegli quella che conta di più (Attacco per chi attacca, Difesa per chi difende)."],
	"maltempo": ["Maltempo", "Dai −1 a una delle due parti per tutta la guerra. Spesso basta a spostare l'ago della bilancia."],
	"holy": ["La Lega Santa", "Come Papa puoi unire le tue Truppe a una delle parti (una volta per Decade). Non ricevi paga né pedine Vittoria, ma puoi difendere le città in cui hai investito."],
	"reroll": ["Ludovico Sforza", "Una volta per Decade puoi far rilanciare entrambi i dadi. Fallo se il risultato attuale danneggia le tue città."],
	"artist": ["Un Artista", "Hai vinto un Artista: scegli la città che riceve [b]+1 Status[/b]. Di solito conviene una città di cui possiedi tessere… o che ti serve far superare una rivale in classifica."],
	"french": ["Invasione Francese", "Scegli una città che perde [b]2 Status[/b] (oppure scarta la tessera). Colpisci una città forte dei tuoi rivali in cui tu non hai tessere."],
	"discard": ["Troppe carte", "Hai superato il limite di carte Tradimento: scegline una da scartare."],
	"deal_offer": ["Una proposta!", "Un altro giocatore ti propone un accordo. Puoi [b]accettare[/b], [b]rifiutare[/b] o fare una [b]controproposta[/b].\n\nRicorda: nessun accordo è vincolante. Guarda la [b]reputazione[/b] di chi propone e preferisci il pagamento «subito» a quello «a cose fatte» con chi è inaffidabile."],
	"deal_pay": ["Mantenere la parola", "L'accordo si è compiuto e ora tocca a te pagare. Puoi non farlo, ma la tua reputazione crollerà e le IA non si fideranno più di te."],
	"moment": ["Un momento per trattare", "In questo momento puoi offrire Oro o Influenza a un altro giocatore perché faccia qualcosa a tuo favore. Se non ti interessa, scegli «Nessuna offerta»; puoi anche chiedere di non essere più interpellato."],
	"decade2": ["La Decade II", "Tutti hanno incassato le rendite. Ora sono disponibili [b]Cavalleria[/b] e [b]Artiglieria[/b], le Truppe più forti, e il Papa torna all'asta.\n\nGuarda la classifica dello Status sulla mappa: a quali città conviene dare una spinta con una guerra?"],
	"decade3": ["L'ultima Decade", "È la Decade decisiva:\n• a fine partita il [b]Papa[/b] vale 3 PV;\n• chi ha [b]più Oro[/b] prende 6 PV (il secondo 3) e chi ha [b]più Influenza[/b] 4 PV: non sprecare tutto!\n• Chi è in testa vorrà chiudere in fretta aggiudicandosi gli ultimi Eventi."],
}
