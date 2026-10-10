# Principi del Rinascimento — versione digitale (Godot 4)

Adattamento digitale amatoriale, per uso personale, di *Princes of the Renaissance* di Martin Wallace
(edizione Mercury Games / italiana), con avversari IA.

## Avvio
1. Apri Godot 4.4 o successivo (testato con 4.4.1; compatibile con 4.7).
2. *Importa* → seleziona `project.godot` in questa cartella → *Importa e modifica*.
3. Premi **F5** (scena principale `scenes/Main.tscn`).

## Contenuto
- **Tutorial**: dal menu principale, una partita guidata (famiglia Montefeltro contro tre IA Facili). Prima un
  giro illustrato del tavolo (mappa, Status, Eventi, Città, Truppe, famiglie, azioni, carte, patti, cronaca,
  guerre e punteggio), poi durante il gioco un suggerimento ogni volta che incontri qualcosa di nuovo
  (primo turno, aste, Condottieri, guerre, dadi, carte, accordi, Decadi II e III). Il gioco si ferma finché
  non premi «Ho capito»; «Basta suggerimenti» li disattiva. Si usano anche le frecce della tastiera.
- **Menu iniziale** con la copertina, **Nuova Partita** (3–6 giocatori, famiglia, lato A/B della tessera,
  umano o IA a tre livelli), **Partita Rapida** (ripete l'ultima configurazione), **Regole**.
- **Tavolo**: mappa con Status, classifica PV delle città, segnalino Guerre, marcatori di guerra, Artisti
  assegnati, Oro in attesa nelle città natali e lotto all'asta sullo spazio del martelletto.
  Al centro gli Eventi della Decade, il Papa, le 35 tessere Città e le Truppe; a destra i giocatori
  (con il paravento che mostra il martelletto barrato quando passano) e la cronaca. Oro, Influenza e pedine
  Vittoria sono gettoni con il numero al centro.
- **Forza militare**: nel riquadro di ogni famiglia la spada indica l'Attacco totale e lo scudo la Difesa totale
  come Condottiero (Truppe più bonus di famiglia e di tessere); passando il mouse si vede il dettaglio.
- **Passa il mouse** su qualsiasi tessera o città per vederla ingrandita con la descrizione.
- **Il tuo turno**: clicca una tessera evidenziata (asta) o una Truppa (acquisto), oppure usa i pulsanti
  (carta Tradimento, Dichiara Guerra, Scarta Truppa, Passa) e le azioni gratuite (Rubare Oro/Influenza,
  Lucrezia, carta gratuita, Banchiere).
- **Aste**: i paraventi dei partecipanti con l'ultima offerta di ciascuno scritta sul gettone (moneta per l'Oro,
  gettone quadrato per l'Influenza); pulsanti −/+/+5 con Offri e Passa sulla stessa riga, poi Congela e Trattativa.
- **Resoconto finale**: classifica delle città e, per ogni famiglia, i PV città per città (tessere × valore),
  Artisti, Mercanti di Vini, Papa, Oro, Influenza e pedine Vittoria, con le miniature delle tessere.
- **Guerre**: riquadro con Condottieri, Truppe (quelle corrotte sono barrate), probabilità di vittoria,
  dadi animati, Veto/Lega Santa/Corrompere/Maltempo/Ludovico quando ti riguardano.
- **Menu in partita**: velocità dell'IA, suoni, regole, ricomincia, abbandona.

## Trattative
Si scambiano solo Oro e Influenza e gli accordi non sono vincolanti. Dal menu principale,
**Accordi e Trattative**, attivi o disattivi ogni tipo di accordo (vale per te e per le IA) e scegli se
essere interpellato nei momenti chiave. Nella schermata Nuova Partita c'è l'interruttore generale.

| Gruppo | Accordi |
|---|---|
| Denaro | Scambio Oro/Influenza · Prestito (restituzione maggiorata a fine Decade, Decadi I–II) · Protezione dai furti |
| Aste | Astensione · Congelamento su commissione · Spartizione di una città · Asta su richiesta · Non chiudere la Decade |
| Guerre | Guerra su commissione · Non aggressione · Spartizione dei Condottieri · Lega Santa a pagamento · Taglia sul Veto · Corruzione/Maltempo su commissione · Rilancio dei dadi |
| Eventi | Artista «+1» su commissione · Invasione Francese su commissione · Spareggi tra le città |

- Nel tuo turno: **Proponi accordo…** (fino a tre proposte per turno).
- In un'asta: **Trattativa…** nel riquadro dell'asta (una per asta).
- Guerre, Artisti, dadi, spareggi: il gioco ti chiede se vuoi fare un'offerta (puoi rispondere
  «Non chiedermelo più in questa partita»).
- Pagamento *subito* o *a cose fatte*; chi riceve accetta, rifiuta o fa una controproposta.
- Il riquadro **Patti in corso** elenca gli accordi attivi (in oro quelli che ti riguardano).
- Chi rompe un patto o non paga viene smascherato nella cronaca e perde reputazione; le IA chiedono
  pagamenti anticipati agli inaffidabili e diventano ostili con chi le ha tradite. Machiavelli tradisce
  quando il guadagno supera il valore della reputazione.

## L'IA
Tre livelli: **Facile**, **Normale**, **Machiavelli**. L'IA:
- stima il valore finale delle città con una simulazione Monte Carlo dello Status (numeri casuali comuni,
  così i confronti tra scenari sono stabili) e valuta ogni scelta in Punti Vittoria attesi;
- calcola esattamente le probabilità delle guerre (assalto e contrattacco, vittorie schiaccianti);
- sceglie le guerre e le parti da sostenere, usa Veto, Corrompere Truppe, Maltempo, Lega Santa e il
  rilancio di Ludovico solo quando migliorano il suo valore atteso;
- nelle aste stima quanto vale il lotto per ogni avversario, gioca «Congelare un'Offerta» contro il
  rivale più pericoloso, fa salti d'offerta quando teme di essere congelata e, a livello Machiavelli,
  rilancia «di spinta» per far pagare di più chi vuole davvero il lotto (bluff);
- tiene un modello di ogni avversario (quanto rilancia oltre il valore stimato, quanto spesso spinge
  senza volere il lotto, chi le ha fatto dei torti) e lo usa per non farsi trascinare (controbluff);
- nell'ultima Decade tiene conto della maggioranza di Oro (6/3 PV) e di Influenza (4 PV).

I parametri del livello Machiavelli sono stati tarati con circa mille partite simulate IA contro IA (Machiavelli batte Normale in circa il 57% delle partite a 4)
(`tests/Sim.tscn`).

## Note sulle regole (scelte della versione digitale)
- Componenti e valori sono quelli delle scansioni della copia fisica (famiglie con lato A/B,
  35 tessere Città, Mercante di Vini, Maltempo, valori città 10/7/5/3/2).
- La composizione del mazzo Tradimento della nuova edizione non era nelle scansioni: si usa
  7 Corrompere Truppe, 7 Congelare, 2 Rubare Oro, 2 Rubare Influenza, 2 Corrompere Cardinale,
  2 Maltempo, 1 Veto, 1 Iniziare una Guerra (modificabile in `scripts/data.gd`).
- Gli sconti di famiglia valgono su tutte le offerte vinte nella valuta indicata (anche Condottieri e Papa).
- «Maltempo» può essere giocato da chiunque durante una guerra, dopo l'assegnazione dei Condottieri.
- Le trattative sono limitate ai tipi di accordo elencati sopra.
- Dopo due giri completi di soli passaggi, il giocatore di turno deve compiere un'azione (anti-stallo).

## Struttura
- `scripts/data.gd` — dati del gioco (tessere, truppe, eventi, famiglie, carte)
- `scripts/game.gd` — motore delle regole (coroutine con decisioni asincrone)
- `scripts/ai.gd` — intelligenza artificiale
- `scripts/ui/*` — menu, impostazione, tavolo, mappa, dialoghi
- `assets/` — grafica estratta dalle scansioni, mappa, copertina, font (OFL), suoni sintetizzati
- `tests/` — simulazioni headless:
  `godot --headless --path . res://tests/Sim.tscn -- games=20 players=4 lvlA=2 lvlB=1`
