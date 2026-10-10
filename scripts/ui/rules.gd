class_name RulesScreen
extends Control
## Regolamento (sintesi in italiano, come implementato nella versione digitale).

var main

const RULES := """[center][font_size=46][color=#7a1a1a]Principi del Rinascimento[/color][/font_size]
[i]Italia, 1470 – 1500[/i][/center]

[font_size=28][color=#7a1a1a]Lo scopo[/color][/font_size]
Ogni giocatore guida una famiglia di Condottieri – Baglioni, Bentivoglio, d'Este, Gonzaga, Malatesta, Montefeltro – e cerca di renderla la più potente d'Italia. Il potere si misura in [b]Punti Vittoria (PV)[/b], che derivano soprattutto dal controllo di interessi nelle cinque grandi città: [b]Milano, Venezia, Firenze, Roma e Napoli[/b].

[font_size=28][color=#7a1a1a]Preparazione[/color][/font_size]
• Ogni giocatore riceve 40 Oro e 12 Influenza. Oro e Influenza sono sempre visibili a tutti.
• Status iniziale: Venezia 7, Milano e Firenze 6, Roma e Napoli 5.
• Le tessere Città, Truppe ed Evento sono scoperte; le carte Tradimento formano un mazzo coperto.
• Il primo giocatore è scelto a caso.

[font_size=28][color=#7a1a1a]Regole importanti[/color][/font_size]
• Massimo 2 carte Tradimento in mano (di più con alcune tessere). Se ne prendi oltre il limite devi scartare.
• Puoi avere tessere di al massimo [b]3 città diverse[/b] e non più di [b]6 tessere Città[/b]. Le tessere Città non si scartano mai.
• Una sola Truppa per tipo. Le Truppe non si perdono mai in battaglia.
• Le abilità «una volta per Decade» si ripristinano a fine Decade.

[font_size=28][color=#7a1a1a]La partita[/color][/font_size]
La partita dura [b]3 Decadi[/b]. Una Decade finisce non appena l'[b]ultimo Evento[/b] della Decade viene aggiudicato all'asta: sono quindi i giocatori a decidere quanto dura. Nel proprio turno ogni giocatore sceglie [b]una[/b] azione:
• [b]Comprare una tessera[/b] – una Truppa (pagata in Oro al suo valore; Cavalleria e Artiglieria non sono disponibili nella Decade I, salvo l'Artiglieria per i d'Este lato A) oppure una carta Tradimento (1 Oro + 1 Influenza). In alternativa puoi scartare una Truppa.
• [b]Mettere all'asta[/b] – una tessera Città, un Evento o il Papa.
• [b]Iniziare una Guerra[/b] – al massimo 4 guerre per Decade (5 con 5-6 giocatori).
• [b]Passare[/b].
Nel tuo turno, prima dell'azione, puoi usare liberamente le carte «Rubare Oro/Influenza», Lucrezia Borgia, le carte Tradimento gratuite e il Banchiere.

[font_size=28][color=#7a1a1a]Le aste[/color][/font_size]
Si offre in senso orario partendo da chi ha messo all'asta. Chi passa [b]esce definitivamente[/b] dall'asta. Vince l'ultimo rimasto.
• [b]Città[/b]: si paga in Oro; l'offerta d'apertura è almeno il [b]doppio dello Status[/b] della città.
• [b]Eventi[/b]: in Oro (cerchio) o Influenza (quadrato); l'apertura può essere 0.
• [b]Papa[/b]: in Influenza, come un Evento.
Puoi offrire più di quanto possiedi se gli sconti (famiglia, città, Corrompere Cardinale, Banchiere) ti permettono di pagare.

[font_size=28][color=#7a1a1a]Le guerre[/color][/font_size]
1. Il giocatore attivo sceglie la città che [b]attacca[/b] e quella che [b]difende[/b]. Il segnalino Guerre avanza.
2. Ora si può giocare un [b]Veto[/b] (carta o Lorenzo de' Medici): la guerra non ha luogo ma conta nel limite.
3. Asta in [b]Influenza[/b] per il [b]Condottiero[/b] dell'attaccante, poi per quello del difensore (il primo vincitore è escluso). Possono partecipare solo i giocatori con almeno una Truppa.
4. Se un posto resta vacante, quella città combatte con valore [b]3[/b]. Se nessuno combatte, la guerra finisce in stallo.
5. Ogni città paga il proprio Condottiero in Oro pari al suo Status: l'Oro va nella città natale della famiglia e si incassa a fine Decade.
6. Il Papa può formare la [b]Lega Santa[/b] (una volta per Decade) aggiungendo le proprie Truppe a una parte. Poi si giocano «Corrompere Truppe» (attaccante, difensore, Papa) e «Maltempo».
7. [b]Assalto[/b]: attacco dell'attaccante + 1 dado contro difesa del difensore + 1 dado. Se l'attaccante supera, vince. Altrimenti [b]Contrattacco[/b]: attacco del difensore + dado contro difesa dell'attaccante + dado; se il difensore supera vince, altrimenti stallo.
8. La città vincitrice sale di 1 Status (di 2 se il totale vincente è almeno il [b]doppio[/b] di quello perdente), la perdente scende altrettanto (Status tra 3 e 10). Il Condottiero vincitore riceve una pedina [b]Vittoria[/b].

[i]Nella versione digitale il riquadro di ogni famiglia mostra la sua forza militare come Condottiero: spada = Attacco totale, scudo = Difesa totale (Truppe più bonus di famiglia e tessere, dado escluso).[/i]

[font_size=28][color=#7a1a1a]Fine Decade[/color][/font_size]
Rendite: 12 Oro e 8 Influenza dalla famiglia, più i valori delle tessere (cerchio = Oro, quadrato = Influenza), l'Influenza di Cavalleria e Artiglieria, 3 Oro al Papa, +1 Oro per ogni Mercante per ciascun «Mercante di Vini» posseduto e l'Oro guadagnato nelle guerre. Il Papa torna all'asta (tranne dopo l'ultima Decade).

[font_size=28][color=#7a1a1a]Punteggio finale[/color][/font_size]
Le città sono ordinate per Status (a parità conta il numero di Artisti «+1» assegnati; se ancora pari, prendono tutte il valore più basso): [b]10, 7, 5, 3, 2 PV[/b] per ogni tessera posseduta di quella città.
• PV degli Eventi; +1 PV per Mercante per ogni «Mercante di Vini».
• Papa nell'ultima Decade: 3 PV.
• Più Oro: 6 PV (pari merito: tutti 6), secondo: 3 PV. Più Influenza: 4 PV (anche in parità).
• Pedine Vittoria: 1, 3, 6, 10, 15… PV.

[font_size=28][color=#7a1a1a]Trattative[/color][/font_size]
Si può trattare in qualsiasi momento, ma si possono scambiare solo [b]Oro e Influenza[/b], mai tessere, e gli accordi [b]non sono vincolanti[/b]. Nella versione digitale ogni tipo di accordo si attiva o disattiva dal menu [b]«Accordi e Trattative»[/b]:
[b]Denaro[/b] – Scambio Oro/Influenza · Prestito (restituzione maggiorata a fine Decade) · Protezione dai furti.
[b]Aste[/b] – Astensione (paghi perché un rivale non rilanci) · Congelamento su commissione · Spartizione di una città (non vi rilanciate contro) · Asta su richiesta · Non chiudere la Decade.
[b]Guerre[/b] – Guerra su commissione · Non aggressione · Spartizione dei Condottieri · Lega Santa a pagamento · Taglia sul Veto · Corruzione o Maltempo su commissione · Rilancio dei dadi (Ludovico Sforza).
[b]Eventi[/b] – Artista «+1» su commissione · Invasione Francese su commissione · Spareggi tra le città (Bentivoglio).
Gli accordi del tuo turno si propongono con «Proponi accordo…», quelli d'asta con «Trattativa…» nel riquadro dell'asta; negli altri momenti (guerre, Artisti, dadi, spareggi) il gioco ti chiede se vuoi fare un'offerta. Il pagamento può essere [b]subito[/b] o [b]a cose fatte[/b]; chi riceve può accettare, rifiutare o controproporre. I patti in corso sono elencati nel riquadro «Patti in corso». Chi non mantiene la parola viene smascherato nella cronaca e perde reputazione: le IA se ne ricordano, chiedono pagamenti anticipati agli inaffidabili e diventano ostili verso chi le ha tradite. Le IA trattano anche tra loro, e un'IA Machiavelli tradisce quando il guadagno vale più della reputazione.

[font_size=28][color=#7a1a1a]Carte Tradimento[/color][/font_size]
[b]Corrompere Truppe[/b] (7) · [b]Congelare un'Offerta[/b] (7) · [b]Rubare Oro[/b] (2) · [b]Rubare Influenza[/b] (2) · [b]Corrompere Cardinale[/b] (2) · [b]Maltempo[/b] (2) · [b]Veto[/b] (1) · [b]Iniziare una Guerra[/b] (1).

[font_size=28][color=#7a1a1a]Note sulla versione digitale[/color][/font_size]
[i]• I componenti seguono l'edizione Mercury Games / italiana scansionata (famiglie con lato A/B, 35 tessere Città, Maltempo, Mercante di Vini). La composizione del mazzo Tradimento della nuova edizione non è nota: si usa 7/7/2/2/2/2/1/1.
• Gli sconti delle famiglie si applicano a tutte le offerte vinte nella valuta indicata (compresi Condottieri e Papa).
• «Maltempo» può essere giocato da chiunque durante una guerra, dopo l'assegnazione dei Condottieri.
• Per evitare stalli infiniti, dopo due giri completi di passaggi il giocatore di turno deve compiere un'azione.
• Le trattative sono limitate ai tipi di accordo elencati sopra.[/i]
"""

func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/mappa.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.35, 0.3, 0.25)
	add_child(bg)
	var pnl := UI.parchment_panel(30)
	pnl.set_anchors_preset(Control.PRESET_FULL_RECT)
	pnl.offset_left = 260
	pnl.offset_right = -260
	pnl.offset_top = 40
	pnl.offset_bottom = -110
	add_child(pnl)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.text = RULES
	rt.add_theme_color_override("default_color", UI.INK)
	rt.add_theme_font_size_override("normal_font_size", 22)
	rt.add_theme_font_size_override("bold_font_size", 22)
	rt.add_theme_font_size_override("italics_font_size", 21)
	rt.add_theme_font_override("bold_font", UI.f_bold)
	pnl.add_child(rt)
	var b := UI.button("Torna al menu", func(): main.show_menu(), 280)
	b.anchor_left = 0.5
	b.anchor_right = 0.5
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = -140
	b.offset_right = 140
	b.offset_top = -86
	b.offset_bottom = -30
	add_child(b)
