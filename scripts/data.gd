extends Node
## Dati statici del gioco: città, tessere, truppe, eventi, famiglie, carte Tradimento.
## Valori ricavati dalle scansioni dei componenti (edizione Mercury Games / italiana).

const CITIES := ["MIL", "VEN", "FIR", "ROM", "NAP"]
const CITY_NAME := {"MIL": "Milano", "VEN": "Venezia", "FIR": "Firenze", "ROM": "Roma", "NAP": "Napoli"}
const CITY_COLOR := {
	"MIL": Color(0.42, 0.47, 0.60), "VEN": Color(0.70, 0.12, 0.12), "FIR": Color(0.20, 0.38, 0.20),
	"ROM": Color(0.45, 0.30, 0.45), "NAP": Color(0.86, 0.66, 0.16)}
const CITY_START := {"VEN": 7, "MIL": 6, "FIR": 6, "ROM": 5, "NAP": 5}
const CITY_BACK := {"MIL": "milano", "VEN": "venezia", "FIR": "firenze", "ROM": "roma", "NAP": "napoli"}
## Posizione (frazione della mappa) del riquadro città
const CITY_MAP_POS := {
	"MIL": Vector2(0.305, 0.150), "VEN": Vector2(0.760, 0.098), "FIR": Vector2(0.442, 0.445),
	"ROM": Vector2(0.852, 0.508), "NAP": Vector2(0.702, 0.712)}
const CITY_BOX_SIZE := Vector2(0.155, 0.150)
const VP_RANK := [10, 7, 5, 3, 2]
const STATUS_MIN := 3
const STATUS_MAX := 10

## Tessere Città.  gold/inf = rendita per Decade.  ab = abilità
const CITY_TILES := [
	{"id": "MIL_mercante", "city": "MIL", "name": "Mercante", "gold": 2, "inf": 0, "merchant": true, "ab": []},
	{"id": "MIL_caterina", "city": "MIL", "name": "Caterina Sforza", "gold": 0, "inf": 1, "ab": ["def2"]},
	{"id": "MIL_ludovico", "city": "MIL", "name": "Ludovico Sforza", "gold": 0, "inf": 3, "ab": ["reroll"]},
	{"id": "MIL_ricca", "city": "MIL", "name": "Famiglia ricca", "gold": 1, "inf": 1, "ab": []},
	{"id": "MIL_armaiolo", "city": "MIL", "name": "Armaiolo", "gold": 0, "inf": 0, "ab": ["cav_att1", "condo_disc1"]},
	{"id": "MIL_genovesi", "city": "MIL", "name": "Balestrieri Genovesi", "gold": 0, "inf": 0, "ab": ["cross_def1"]},
	{"id": "MIL_svizzeri", "city": "MIL", "name": "Mercenari Svizzeri", "gold": 0, "inf": 0, "ab": ["pike_ad1", "condo_disc1"]},

	{"id": "NAP_ferrante", "city": "NAP", "name": "Ferrante d'Aragona", "gold": 0, "inf": 1, "ab": ["treach_limit1"]},
	{"id": "NAP_alfonso", "city": "NAP", "name": "Alfonso d'Aragona", "gold": 0, "inf": 0, "ab": ["free_treach"]},
	{"id": "NAP_mercante1", "city": "NAP", "name": "Mercante", "gold": 2, "inf": 0, "merchant": true, "ab": []},
	{"id": "NAP_mercante2", "city": "NAP", "name": "Mercante", "gold": 2, "inf": 0, "merchant": true, "ab": []},
	{"id": "NAP_pallavicino", "city": "NAP", "name": "Famiglia Pallavicino", "gold": 0, "inf": 1, "ab": ["free_treach"]},
	{"id": "NAP_mercante3", "city": "NAP", "name": "Mercante", "gold": 2, "inf": 0, "merchant": true, "ab": []},
	{"id": "NAP_spagnole", "city": "NAP", "name": "Truppe Spagnole", "gold": 0, "inf": 0, "ab": ["li_ad1"]},

	{"id": "VEN_mercinfl", "city": "VEN", "name": "Mercante Influente", "gold": 2, "inf": 1, "merchant": true, "ab": []},
	{"id": "VEN_mercante1", "city": "VEN", "name": "Mercante", "gold": 3, "inf": 0, "merchant": true, "ab": []},
	{"id": "VEN_mercante2", "city": "VEN", "name": "Mercante", "gold": 3, "inf": 0, "merchant": true, "ab": []},
	{"id": "VEN_mercante3", "city": "VEN", "name": "Mercante", "gold": 3, "inf": 0, "merchant": true, "ab": []},
	{"id": "VEN_mercante4", "city": "VEN", "name": "Mercante", "gold": 3, "inf": 0, "merchant": true, "ab": []},
	{"id": "VEN_doge", "city": "VEN", "name": "Il Doge", "gold": 2, "inf": 2, "ab": []},
	{"id": "VEN_mercante5", "city": "VEN", "name": "Mercante", "gold": 3, "inf": 0, "merchant": true, "ab": []},

	{"id": "ROM_colonna", "city": "ROM", "name": "Famiglia Colonna", "gold": 0, "inf": 1, "ab": ["pope_disc1"]},
	{"id": "ROM_orsini", "city": "ROM", "name": "Famiglia Orsini", "gold": 0, "inf": 1, "ab": ["pope_disc1"]},
	{"id": "ROM_cesare", "city": "ROM", "name": "Cesare Borgia", "gold": 0, "inf": 1, "ab": ["treach_limit1"]},
	{"id": "ROM_rodrigo", "city": "ROM", "name": "Rodrigo Borgia", "gold": 0, "inf": 2, "ab": ["pope_disc1"]},
	{"id": "ROM_rovere", "city": "ROM", "name": "Della Rovere", "gold": 0, "inf": 2, "ab": ["pope_disc1"]},
	{"id": "ROM_mercante", "city": "ROM", "name": "Mercante", "gold": 2, "inf": 0, "merchant": true, "ab": []},
	{"id": "ROM_lucrezia", "city": "ROM", "name": "Lucrezia Borgia", "gold": 0, "inf": 0, "ab": ["steal_inf"]},

	{"id": "FIR_pazzi", "city": "FIR", "name": "Famiglia Pazzi", "gold": 0, "inf": 1, "ab": []},
	{"id": "FIR_soderini", "city": "FIR", "name": "Famiglia Soderini", "gold": 0, "inf": 1, "ab": []},
	{"id": "FIR_banchiere1", "city": "FIR", "name": "Banchiere", "gold": 0, "inf": 0, "ab": ["bank"]},
	{"id": "FIR_giovanni", "city": "FIR", "name": "Giovanni de' Medici", "gold": 0, "inf": 1, "ab": ["pope_disc1"]},
	{"id": "FIR_mercante", "city": "FIR", "name": "Mercante", "gold": 2, "inf": 0, "merchant": true, "ab": []},
	{"id": "FIR_lorenzo", "city": "FIR", "name": "Lorenzo de' Medici", "gold": 0, "inf": 1, "ab": ["veto"]},
	{"id": "FIR_banchiere2", "city": "FIR", "name": "Banchiere", "gold": 0, "inf": 0, "ab": ["bank"]},
]

const AB_TEXT := {
	"def2": "+2 Difesa (serve almeno una Truppa)",
	"reroll": "Una volta per Decade: fai rilanciare entrambi i dadi in una guerra",
	"cav_att1": "+1 Attacco alla Cavalleria",
	"condo_disc1": "Sconto di 1 quando paghi per divenire Condottiero",
	"cross_def1": "+1 Difesa ai Balestrieri",
	"pike_ad1": "+1 Attacco/Difesa ai Picchieri",
	"treach_limit1": "Puoi tenere una carta Tradimento extra",
	"free_treach": "Prendi una carta Tradimento gratis una volta per Decade",
	"li_ad1": "+1 Attacco/Difesa alla Fanteria Leggera",
	"pope_disc1": "Sconto di 1 quando paghi per divenire il Papa",
	"steal_inf": "Puoi rubare 2 Influenza, una volta per Decade",
	"bank": "Scambi fino a 3 Oro per 3 Influenza o viceversa, una volta per Decade",
	"veto": "Puoi porre il veto su una guerra, una volta per Decade",
}

## Truppe: costo in oro, attacco, difesa, rendita influenza, non acquistabile in Decade I
const TROOPS := {
	"cavalleria": {"name": "Cavalleria", "cost": 6, "att": 4, "def": 0, "inf": 2, "noI": true, "count": 3},
	"artiglieria": {"name": "Artiglieria", "cost": 6, "att": 3, "def": 1, "inf": 1, "noI": true, "count": 4},
	"stradioti": {"name": "Stradioti", "cost": 2, "att": 2, "def": 0, "inf": 0, "noI": false, "count": 2},
	"archibugieri": {"name": "Archibugieri", "cost": 1, "att": 1, "def": 0, "inf": 0, "noI": false, "count": 2},
	"fanteria": {"name": "Fanteria Leggera", "cost": 1, "att": 1, "def": 0, "inf": 0, "noI": false, "count": 3},
	"picchieri": {"name": "Picchieri", "cost": 2, "att": 0, "def": 2, "inf": 0, "noI": false, "count": 3},
	"balestrieri": {"name": "Balestrieri", "cost": 1, "att": 0, "def": 1, "inf": 0, "noI": false, "count": 3},
	"campo": {"name": "Campo Fortificato", "cost": 3, "att": 0, "def": 3, "inf": 0, "noI": false, "count": 4},
}
const TROOP_ORDER := ["cavalleria", "artiglieria", "stradioti", "archibugieri", "fanteria", "picchieri", "balestrieri", "campo"]

## Eventi.  kind: vp / sta / merchant / french ; cur: gold / inf
const EVENTS := [
	{"id": "EV_vini1", "dec": 1, "name": "Mercante di Vini", "kind": "merchant", "value": 0, "cur": "inf", "artist": false},
	{"id": "EV_gozzoli", "dec": 1, "name": "Gozzoli", "kind": "vp", "value": 2, "cur": "inf", "artist": true},
	{"id": "EV_bellini", "dec": 1, "name": "Bellini", "kind": "vp", "value": 3, "cur": "gold", "artist": true},
	{"id": "EV_botticelli", "dec": 1, "name": "Botticelli", "kind": "sta", "value": 1, "cur": "gold", "artist": true},
	{"id": "EV_davinci", "dec": 2, "name": "Leonardo da Vinci", "kind": "vp", "value": 3, "cur": "gold", "artist": true},
	{"id": "EV_pinturicchio", "dec": 2, "name": "Pinturicchio", "kind": "sta", "value": 1, "cur": "gold", "artist": true},
	{"id": "EV_verrocchio", "dec": 2, "name": "Verrocchio", "kind": "vp", "value": 2, "cur": "inf", "artist": true},
	{"id": "EV_vini2", "dec": 2, "name": "Mercante di Vini", "kind": "merchant", "value": 0, "cur": "inf", "artist": false},
	{"id": "EV_francia", "dec": 3, "name": "Invasione Francese", "kind": "french", "value": -2, "cur": "inf", "artist": false},
	{"id": "EV_ghirlandaio", "dec": 3, "name": "Ghirlandaio", "kind": "sta", "value": 1, "cur": "inf", "artist": true},
	{"id": "EV_michelangelo", "dec": 3, "name": "Michelangelo", "kind": "vp", "value": 4, "cur": "gold", "artist": true},
	{"id": "EV_carpaccio", "dec": 3, "name": "Carpaccio", "kind": "sta", "value": 1, "cur": "inf", "artist": true},
]

const POPE := {"id": "POPE", "name": "Il Papa", "cur": "inf", "gold": 3}

## Famiglie (tessera fronte A / retro B).  Rendita 12 Oro e 8 Influenza.
const FAMILIES := {
	"gonzaga": {"name": "Gonzaga", "home": "Mantova", "home_pos": Vector2(0.45, 0.18), "color": Color(0.85, 0.85, 0.85),
		"A": {"gold_disc": 2}, "B": {"gold_disc": 1},
		"txtA": "Sconto di 2 sulle offerte in Oro", "txtB": "Sconto di 1 sulle offerte in Oro"},
	"baglioni": {"name": "Baglioni", "home": "Perugia", "home_pos": Vector2(0.59, 0.44), "color": Color(0.95, 0.80, 0.15),
		"A": {"any_disc": 1}, "B": {"choose_disc": 1},
		"txtA": "Sconto di 1 Oro o 1 Influenza su ogni offerta vinta", "txtB": "A inizio Decade scegli: sconto di 1 Oro oppure 1 Influenza sulle offerte"},
	"montefeltro": {"name": "Montefeltro", "home": "Urbino", "home_pos": Vector2(0.63, 0.39), "color": Color(0.25, 0.55, 0.85),
		"A": {"inf_disc": 2}, "B": {"inf_disc": 1},
		"txtA": "Sconto di 2 sulle offerte in Influenza", "txtB": "Sconto di 1 sulle offerte in Influenza"},
	"malatesta": {"name": "Malatesta", "home": "Rimini", "home_pos": Vector2(0.60, 0.35), "color": Color(0.30, 0.65, 0.35),
		"A": {"treach_limit": 3, "free_treach": true}, "B": {"treach_limit": 3},
		"txtA": "Puoi tenere 3 carte Tradimento. Prendi 1 carta Tradimento gratis per Decade", "txtB": "Puoi tenere 3 carte Tradimento"},
	"este": {"name": "d'Este", "home": "Ferrara", "home_pos": Vector2(0.52, 0.23), "color": Color(0.30, 0.70, 0.85),
		"A": {"def": 1, "artillery_I": true}, "B": {"def": 1},
		"txtA": "+1 Difesa. Puoi acquistare Artiglieria nella prima Decade", "txtB": "+1 Difesa"},
	"bentivoglio": {"name": "Bentivoglio", "home": "Bologna", "home_pos": Vector2(0.47, 0.28), "color": Color(0.85, 0.25, 0.20),
		"A": {"draw2": true, "artist_ties": true}, "B": {"draw2": true},
		"txtA": "Quando prendi carte Tradimento ne peschi 2 e ne tieni 1. Decidi sulle parità in Artisti", "txtB": "Quando prendi carte Tradimento ne peschi 2 e ne tieni 1"},
}
const FAMILY_ORDER := ["baglioni", "bentivoglio", "este", "gonzaga", "malatesta", "montefeltro"]
const FAMILY_GOLD := 12
const FAMILY_INF := 8

## Carte Tradimento (mazzo).  Costo 1 Oro + 1 Influenza.
const TREACHERY := {
	"corrompi_truppe": {"name": "Corrompere Truppe", "count": 7, "txt": "Durante una guerra, dopo l'assegnazione dei Condottieri: annulla una Tessera Truppa per tutta la guerra."},
	"congela": {"name": "Congelare un'Offerta", "count": 7, "txt": "Quando tocca a te in un'asta: un giocatore non potrà rialzare la prossima volta."},
	"veto": {"name": "Veto", "count": 1, "txt": "Dopo la dichiarazione di una guerra: la guerra non ha luogo (conta comunque nel limite)."},
	"inizia_guerra": {"name": "Iniziare una Guerra", "count": 1, "txt": "A fine turno inizi una guerra aggiuntiva (non muove il segnalino Guerre)."},
	"ruba_inf": {"name": "Rubare Influenza", "count": 2, "txt": "Nel tuo turno, fuori dalle aste: ruba 2 Influenza a un giocatore."},
	"ruba_oro": {"name": "Rubare Oro", "count": 2, "txt": "Nel tuo turno, fuori dalle aste: ruba 3 Oro a un giocatore."},
	"cardinale": {"name": "Corrompere Cardinale", "count": 2, "txt": "Vale 3 Influenza per pagare la Tessera Papa."},
	"maltempo": {"name": "Maltempo", "count": 2, "txt": "Durante una guerra: -1 all'Attaccante o al Difensore per tutta la guerra."},
}
const TREACHERY_IMG := {"corrompi_truppe": "TC_corrompi_truppe", "congela": "TC_congela", "veto": "TC_veto", "inizia_guerra": "TC_inizia_guerra",
	"ruba_inf": "TC_ruba_influenza", "ruba_oro": "TC_ruba_oro", "cardinale": "TC_cardinale", "maltempo": "TC_maltempo"}

## Accordi tra giocatori: nome, gruppo e descrizione (menu "Accordi", composer, regole)
const DEAL_INFO := {
	"exchange": {"name": "Scambio Oro / Influenza", "group": "Denaro", "desc": "Nel tuo turno scambi Oro con Influenza (o viceversa) con un altro giocatore. Immediato."},
	"loan": {"name": "Prestito", "group": "Denaro", "desc": "Oro prestato subito, da restituire maggiorato a fine Decade (solo Decadi I e II). Chi non restituisce perde la faccia."},
	"protection": {"name": "Protezione", "group": "Denaro", "desc": "Paghi un giocatore perché per tutta la Decade non usi contro di te Rubare Oro, Rubare Influenza o Lucrezia Borgia."},
	"abstain": {"name": "Astensione in un'asta", "group": "Aste", "desc": "Durante un'asta (anche per i Condottieri) paghi un rivale perché non rilanci più."},
	"freeze_req": {"name": "Congelamento su commissione", "group": "Aste", "desc": "Durante un'asta paghi un giocatore perché giochi «Congelare un'Offerta» contro un rivale."},
	"city_pact": {"name": "Spartizione di una città", "group": "Aste", "desc": "Per questa Decade tu e un altro giocatore non vi rilanciate contro sulle tessere di una città."},
	"auction_req": {"name": "Asta su richiesta", "group": "Aste", "desc": "Paghi un giocatore perché nel suo prossimo turno metta all'asta una certa tessera."},
	"no_close": {"name": "Non chiudere la Decade", "group": "Aste", "desc": "Paghi un giocatore perché nel suo prossimo turno non metta all'asta l'ultimo Evento della Decade."},
	"war_req": {"name": "Guerra su commissione", "group": "Guerre", "desc": "Paghi un giocatore perché nel suo prossimo turno dichiari la guerra che scegli tu (città attaccante e difensore)."},
	"no_attack": {"name": "Non aggressione", "group": "Guerre", "desc": "Paghi un giocatore perché in questa Decade non dichiari guerra contro una città."},
	"condo_split": {"name": "Spartizione dei Condottieri", "group": "Guerre", "desc": "Nell'asta per l'attaccante chiedi a un rivale di non contenderti l'attacco. In cambio ti impegni a lasciargli la difesa anche se l'attacco lo perdessi contro un terzo (se lo vinci, sei comunque escluso dalla difesa)."},
	"holy": {"name": "Lega Santa a pagamento", "group": "Guerre", "desc": "Da Condottiero paghi il Papa perché si schieri con te."},
	"veto_bounty": {"name": "Taglia sul Veto", "group": "Guerre", "desc": "Dopo una dichiarazione di guerra prometti una ricompensa a chi pone il Veto."},
	"card_req": {"name": "Corruzione o Maltempo su commissione", "group": "Guerre", "desc": "Durante una guerra paghi chi ha la carta perché corrompa le Truppe di un Condottiero o giochi Maltempo contro una città."},
	"reroll_req": {"name": "Rilancio dei dadi", "group": "Guerre", "desc": "Paghi chi possiede Ludovico Sforza perché faccia rilanciare i dadi."},
	"artist_req": {"name": "Artista su commissione", "group": "Eventi", "desc": "Paghi chi ha vinto un Artista «+1» perché lo assegni alla città che chiedi."},
	"french_req": {"name": "Invasione Francese su commissione", "group": "Eventi", "desc": "Paghi chi ha vinto l'Invasione Francese perché colpisca la città che chiedi, o la scarti."},
	"ties_req": {"name": "Spareggi tra le città", "group": "Eventi", "desc": "A fine partita paghi il Bentivoglio (lato A) perché decida uno spareggio a favore di una città."},
}
const DEAL_ORDER := ["exchange", "loan", "protection", "abstain", "freeze_req", "city_pact", "auction_req", "no_close",
	"war_req", "no_attack", "condo_split", "holy", "veto_bounty", "card_req", "reroll_req", "artist_req", "french_req", "ties_req"]

const START_GOLD := 40
const START_INF := 12

var _tex_cache := {}
var _city_tile_by_id := {}
var _event_by_id := {}

func _ready() -> void:
	for t in CITY_TILES:
		_city_tile_by_id[t.id] = t
	for e in EVENTS:
		_event_by_id[e.id] = e

func city_tile(id: String) -> Dictionary:
	if _city_tile_by_id.is_empty():
		_ready()
	return _city_tile_by_id.get(id, {})

func event(id: String) -> Dictionary:
	if _event_by_id.is_empty():
		_ready()
	return _event_by_id.get(id, {})

func is_city_tile(id: String) -> bool:
	return city_tile(id).size() > 0

func is_event(id: String) -> bool:
	return event(id).size() > 0

func item_name(id: String) -> String:
	if id == "POPE":
		return "Il Papa"
	if is_city_tile(id):
		var t := city_tile(id)
		return "%s (%s)" % [t.name, CITY_NAME[t.city]]
	if is_event(id):
		return event(id).name
	if TROOPS.has(id):
		return TROOPS[id].name
	if TREACHERY.has(id):
		return TREACHERY[id].name
	return id

func tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = load(path)
	_tex_cache[path] = t
	return t

func item_tex(id: String) -> Texture2D:
	if id == "POPE":
		return tex("res://assets/tiles/POPE.png")
	if is_city_tile(id) or is_event(id):
		return tex("res://assets/tiles/%s.png" % id)
	if TROOPS.has(id):
		return tex("res://assets/tiles/TR_%s.png" % id)
	if TREACHERY.has(id):
		return tex("res://assets/cards/%s.png" % TREACHERY_IMG[id])
	return null

func family_tex(fam: String, side: String) -> Texture2D:
	return tex("res://assets/tiles/FAM_%s_%s.png" % [fam, side])

func screen_tex(fam: String, passed := false) -> Texture2D:
	return tex("res://assets/families/SCR_%s%s.png" % [fam, "_pass" if passed else ""])

func back_tex(kind: String) -> Texture2D:
	return tex("res://assets/tiles/BACK_%s.png" % kind)

func cur_name(cur: String) -> String:
	return "Oro" if cur == "gold" else "Influenza"

static func tri(n: int) -> int:
	return n * (n + 1) / 2
