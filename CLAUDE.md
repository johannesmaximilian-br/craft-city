# Cube City — Arbeitsnotizen für Claude

SimCity-artiges Aufbauspiel im Minecraft-/Blockstil. Godot 4.7.2 (`/Applications/Godot.app`), GDScript, kein C#.
Spielerdoku, Regeln, Steuerung, Dateiübersicht: **README.md**. Diese Datei: Entscheidungen, Fallstricke, Arbeitsweise.

## Zusammenarbeit

- Sprache: **Deutsch** (UI-Texte, Kommentare, Antworten). Code-Bezeichner englisch.
- Nutzer installiert Software selbst (kein `brew install` o.ä. ausführen, sondern vorschlagen).
- Nutzer gibt Feedback oft mit Screenshots aus dem Spiel; Ideen werden diskutiert, dann umgesetzt.
- Vor Abschluss immer: Tests laufen lassen + Screenshot ansehen (siehe unten). Ergebnisse ehrlich berichten,
  insbesondere was nur gemessen/nicht selbst gespielt wurde.
- **Dokumentation sofort mitpflegen (Pflicht):** Jede Architektur-Entscheidung, Konzeptänderung, neue/geänderte
  Spielregel oder neu entdeckter Fallstrick wird **im selben Arbeitsschritt** dokumentiert — nicht erst am Ende:
  Architektur/Fallstricke/Arbeitsweise → diese `CLAUDE.md`; Regeln, Steuerung, Dateiübersicht, Roadmap → `README.md`.
  Veraltete Stellen dabei korrigieren oder löschen. Eine Aufgabe gilt erst als fertig, wenn die Doku stimmt.
- Keine Downloads ohne Rückfrage. Assets bisher: Quaternius Cube World Kit (CC0, Original in `~/Downloads/Cube World - Aug 2023`),
  Silkscreen-Font (OFL, vom Nutzer bereitgestellt). Audio wird selbst erzeugt (`tools/audio/gen_audio.py`).

## Testen & Prüfen (immer nach Änderungen)

```bash
G=/Applications/Godot.app/Contents/MacOS/Godot
$G --headless --import 2>&1 | grep -E "SCRIPT ERROR|Parse" -A1          # Kompilierfehler
$G --path . -- --demo --selftest --dragtest --servicetest --quit          # Funktionstests
$G --headless --path . -- --traffictest --widetest --quit                 # Verkehr/Hauptstraßen (synthetisch)
$G --path . -- --demo --profile=20,3 --quit                               # Performance (Ruckler > 25 ms), läuft mit der FPS-Grenze aus den Nutzer-Einstellungen (z.B. 30!)
$G --path . -- --demo --gpumeasure=0.1,0 --profile=20,3 --quit            # dito ohne FPS-Grenze (Vergleich mit alten Messungen)
$G --path . -- --demo --cam=32,32,60 --screenshot=/pfad/bild.png          # Screenshot ansehen (Read-Tool)
```
- Dev-Flags/Tests liegen in `scripts/dev/` (nie in `main.gd`). Neue Tests dort als statische Funktion + Flag in `dev_tools.gd`.
- `--tool=<icon>` wählt ein Werkzeug (Gruppe klappt auf), `--overlay=1..5` Ansicht, `--menu`, `--gfx=0..2`.
- Tests, die die Karte direkt ändern, müssen danach `map.notify_changed(...)` rufen (sonst veraltete Caches).
- Profilieren nur mit Fenster im Vordergrund (macOS drosselt verdeckte Fenster → falsche 1-s-Spitzen; `profile()` setzt always-on-top).
- Testspielstände (`selftest`, `servicetest`) werden wieder gelöscht; echte Spielstände des Nutzers liegen in
  `~/Library/Application Support/Cube City/saves/` — nicht anfassen. (Bis 16.10. lagen sie unter
  `.../Godot/app_userdata/Cube City/`; dieser alte Ordner ist die Sicherheitskopie des Nutzers, ebenfalls nicht anfassen.)

## Architektur-Prinzipien

- **Daten ↔ Darstellung getrennt:** `CityMap` (Packed-Arrays, keine Logik außer Abfragen), `Simulation` (Regeln),
  Renderer/Fahrzeuge/HUD lesen nur. Alle Spielwerte in `config.gd`.
- **Änderungen melden:** `map.notify_changed(rect, infra := true)`. `infra=false` nur bei reinen Gebäudestufen
  (Wachstum, Brände) → Autos/Züge/Hauptstraßen-Cache werden dann nicht neu berechnet. Bauwerkzeuge melden immer `infra=true`.
- **Kartengröße 128×128** (`Config.MAP_SIZE`). Kleinere alte Saves bettet `CityMap._embed` mittig ein (Anker-Indizes
  umrechnen!, Höhen am Rand angleichen); Sim-Arrays aus dem Save mit falscher Größe werden verworfen.
- **Simulation verteilt:** Monat = `TICK_STAGES` (je Frame eine Etappe, Ziel ≤ ~16 ms bei 128×128). Umwelt
  (`_env_begin/_env_rows/_env_end`) und Wachstum (`_grow_rows/_grow_finish`) sind zeilenweise teilbar. `tick_month()` = synchron (Tests/Demo),
  `refresh()` = alles sofort (nach Bauaktionen). Neue teure Berechnungen als eigene Etappe einhängen.
- **Pendler asynchron:** im Spiel (`sim.async_commute = true`, gesetzt in `main.gd`) rechnet eine zweite
  `Simulation`-Instanz (`_worker`) `_compute_commute` per `WorkerThreadPool` auf einer Kopie aller `SAVE_FIELDS`;
  Eingaben `COMMUTE_IN`, Ergebnisse `COMMUTE_OUT` werden in `_poll_commute` (Hauptthread) übernommen. Neues Feld,
  das die Pendler-Berechnung liest/schreibt ⇒ in diese Listen eintragen. DevTools schaltet für Tests auf synchron
  (deterministisch) und erst vor `--profile`/Screenshot wieder auf async. `refresh(staged)` vom Bauwerkzeug.
- **Pendler-Graph:** Knoten 0..n-1 Straßen-Tiles, n..2n-1 Gleis-Tiles; Bahnhöfe verbinden per Fuß/Zubringerbus.
  Incremental assignment in 3 Etappen (sonst nutzt niemand Parallelstraßen). Kosten: `(1 + 2·Auslastung²)/Tempo`,
  Abbruch über Weglänge (`MAX_HOPS`), nicht über Staukosten (sonst verschwindet Überlast als "unerreichbar").
- **Rendering:** alles aus Kit-Blöcken via `BlockBatch` → MultiMesh je Mesh-Typ und Chunk. `put()` = Block an Ecke,
  `put_box()` = skalierte Box um Mittelpunkt (nur für Keys mit Einheitswürfel-Normierung, also nicht PLATES),
  `put_prop()` = Modell unten mittig. Neue Gebäude in `structure_generator.gd` / `building_generator.gd`.
- **Ausrichtung von Sonderbauten:** Generatoren bauen die Front immer Richtung -z. `WorldRenderer._front_angle` wählt die
  Seite mit den meisten Straßen, `BlockBatch.pivot` dreht alle folgenden Instanzen um die Grundflächen-Mitte (danach
  zurücksetzen!). Chunks werden mit 3 Tiles Rand neu gebaut, damit eine neue Straße auch große Bauten neu ausrichtet.
- **Icons** werden aus denselben Generatoren per SubViewport gerendert (`icon_factory.gd`) — neues Gebäude ⇒ Icon-Case ergänzen.
- **Hauptstraße** wird nicht gebaut, sondern erkannt: 2 parallele Straßen nebeneinander (`CityMap.wide_partner`,
  vorberechnet in `_compute_wide`; Fahrtrichtung = längere Achse, Paare ab Bandkante). Enden → Viertelbogen (`_emit_taper`).
- **Sonderbauten** (`Config.SPECIALS`): Kraftwerke + Dienste/Kultur, Größe 1 oder 2, `anchor` = Ursprungs-Tile,
  `slevel` = Ausbaustufe 1..3 (0 in alten Saves ⇒ 1). Dienste haben `"service"`-Kategorie aus `Config.SERVICES`.
- **Brände:** Ausbruch würfelt `Simulation._fires()` monatlich (setzt `map.burning = 1`, zählt Ruinen herunter).
  Verlauf/Löschzüge/Ausbreitung laufen in `FireDept` in **Echtzeit** (`advance(dt)`, skaliert mit Tempo, steht bei Pause) —
  sonst wären Löschzüge bei schnellem Tempo bedeutungslos. `FireDept` übernimmt neue Brände über `tiles_changed`
  (auch beim Laden; volle Karte ⇒ alte Einsätze verwerfen). Tests rufen `advance()` selbst (`tick_month()` bewegt keine Züge).
  Meldungen mit Ort: Signal `alert(text, tile)` → `Hud.show_message(text, tile)` → `focus_requested` → Kamera.
- **Busse (visuell, `traffic.gd`):** je zusammenhängendem Straßennetz mit ≥ 2 Haltestellen (`_stop_groups`), Bus bleibt
  in seinem Netz. Früher globale Anzahl + Start an zufälliger Haltestelle ⇒ getrennte Vorstädte bekamen oft keinen Bus.
- **Zufriedenheit erklärbar:** `_compute_services` sammelt `happy_parts` (einwohnergewichtete Anteile; Summe + `HAPPY_BASE`
  = `city_happiness`, solange keine Kappung greift). Neue Einflüsse auf `happiness[i]` dort **mit eintragen**, sonst stimmt
  die HUD-Aufschlüsselung nicht. `_check_happiness()` läuft nur in der Monats-Etappe „dienste“ (nicht in `refresh()`).
- **HUD-Ausklapplisten:** `Hud._popup` (Ansicht-Liste / Zufriedenheit / Meldungsverlauf), getrennt vom Werkzeug-`_flyout`.
- **Meldungen zweistufig:** `Hud.notify(text, tile)` = Warnung (Streifen rechts in `_feed`, Verlauf `_log`, Glocke;
  verbunden mit `sim.message`, `sim.alert`, `fire_dept.alert` — die auch den Ton auslösen). `Hud.show_message(text)` =
  kurze Info über der Werkzeugleiste ohne Verlauf (`tools.message`, Ansicht, Speichern). Neue Meldung: Problem ⇒ notify.
- **Info-Karte:** `_on_hover` sammelt Zeilen je Abschnitt (`add.call(Abschnitt, Text)`), dazu `summary` und `problems`;
  kompakt zeigt nur summary + problems, Taste I (`_info_detail`) alles. Neue Info ⇒ passenden Abschnitt wählen,
  Probleme zusätzlich in `problems`.
- **Grünfilter:** `_compute_environment` stempelt Verschmutzung, filtert sie dann je Tile über Bäume/Parks im Umkreis
  (Integralbild, `green_filter`) und rechnet erst danach Bodenwert. Kein echtes „Blockieren“ entlang der Windrichtung —
  Grün nahe am Empfänger wirkt. Bäume geben keinen Bodenwert mehr (Nutzerwunsch: Bäume = nur Filter, Parks = Filter + Zufriedenheit + Kosten).
- **Großkultur:** Theater/Stadion = Dienst-Kategorie `venue` + Felder `visitors`/`event_every` in `SPECIALS`.
  Event-Verkehr wird in `_compute_commute` **vor** der Stau-Berechnung auf `traffic` addiert (`_add_venue_traffic`),
  Kundschaft-Bonus am Ende von `_compute_environment`. Stadion ist der erste 3x3-Sonderbau (Größe überall generisch).
- **Dienst-Auslastung** zählt Einwohner (`_ipop`); nur die Feuerwehr zählt zusätzlich Arbeitsplätze (`_ijobs` × `FIRE_JOB_WEIGHT`).
  Brand-Ausbruch für Industrie ohne Einwohner-Schwelle und mit Restrisiko (`FIRE_IND_MIN_SHARE`).
- **Steuern:** `sim.tax[zone]` (Array, Index = `Config.Zone`), neutral/Empfindlichkeit in `Config.TAX_*`; Zufriedenheit nur
  über die Wohnsteuer. Alte Saves mit `tax_rate` → W/G übernehmen, I neutral. Tarif `sim.fare` wirkt in
  `_build_transit_links` (Einstiegskosten), `_record_trip` (Busanteil) und Zufriedenheit; Änderung ⇒ `sim.refresh()`.
- **Zonen-Idealformen** werden in `_compute_environment` vorberechnet (`ind_cluster`, `land_mix` per Integralbild) und
  greifen über `_max_level` (Gewerbe nach `road_dist` und `junction_dist` = Weg zur nächsten Kreuzung, in der Etappe „netz“
  berechnet; Industrie nach Ballung), `_growth_factor`, `suitability`, `growth_blockers`.
- **Villa** = Map-Feld `villa` auf Wohnen Stufe 3, gesetzt beim Wachsen auf 3 (`villa_site`). Einwohner immer über
  `CityMap.res_capacity(i)`, nie direkt `RES_CAPACITY[level]` (sonst zählen Villen 80 statt 16).
- **Belegung/Leerstand:** Map-Feld `empty` (Leerstand 0..100 %, **0 = voll** – so sind alte Saves, Tests und direkt
  gesetzte Stufen automatisch belegt) + `vacant` (Monate leer). Einwohner/Jobs immer über `map.residents(i)` /
  `map.jobs_at(i)` (nicht `res_capacity`/`*_CAPACITY` direkt), `map.occupancy(i)`, `map.is_vacant(i)`. In `_grow_rows`:
  harte Gründe (`not ok` −12, unzufrieden −6) können leeren, sanfte (Nachfrage, zu groß, Villa) −3 bis min. 30 %;
  Leerstand ohne Stufenwechsel, nach `VACANT_MONTHS` Abriss. Zufällige Stufen-Abstiege gibt es nur noch für „zu groß für
  die Lage“ und Villa. `_blight_field()` → Zufriedenheit (happy_parts "Leerstand"). Zu starke Werte erzeugen eine
  Abwärtsspirale – mit `--freshrun` messen.
- **Verfall:** `decay_reason(i)` bündelt alle Abstiegsgründe aus `_grow()`; `_grow()` setzt monatlich `map.worn`
  (Map-Feld, damit der Renderer es lesen kann) und meldet Änderungen mit `infra=false`. Neuer Abstiegsgrund ⇒ in beiden ergänzen.
  Renderer: `_put_worn` tauscht ~35 % der Blöcke gegen verwitterte (`WORN_KEYS`), `_emit_worn_props` setzt Ranken/Geröll.
- **Strom:** `_compute_power` erfasst **alle** leitenden Komponenten (auch ohne Kraftwerk) → `power_net` je Tile,
  `power_nets` (capacity, demand, plants, unserved, dark). Meldungen über Signal `sim.alert(text, tile)` nur bei neuen
  Problemen (`_power_warned`). Anzeige oben = Bedarf aller Gebäude, rot bei irgendeinem Gebäude ohne Strom.
- **Strom für Dienste:** `tile_power_use` liefert am Ursprungs-Tile eines Dienstbaus `use × SERVICE_POWER_LEVEL[stufe]`;
  `_compute_power` versorgt diese Anker vor der BFS (Vorrang), übrige Tiles erben `powered` vom Anker. `special_powered(i)`
  prüfen: ohne Strom keine Versorgung (`_compute_services`), keine Löschzüge (`FireDept._dispatch`), keine Events.
  `powered` steht deshalb in `COMMUTE_IN` (Event-Verkehr im Worker).
- **Dienst-Auslastung geteilt:** `_compute_services` zählt je Kategorie, wie viele Gebäude ein Tile abdecken
  (`_service_tiles`, Kreis), und teilt dessen Einwohner/Jobs durch diese Zahl. Vorher zählte jedes Gebäude alles im
  Quadrat → in dichten Vierteln war jede Wache überlastet, egal wie viele man baute.
- **Bildrate/Stromsparen:** `FrameLimiter` (Node in main) setzt jeden Frame `Engine.max_fps`: Menü-Grenze
  (`GraphicsSettings.fps_limit`, Standard 60), Fenster im Hintergrund 10, Pause + ruhende Kamera 30. In Testläufen
  (`DevTools.automated`) keine Hintergrund-Drosselung, sonst laufen Tests im verdeckten Fenster mit 10 FPS.
  Nicht direkt `Engine.max_fps` setzen (wird überschrieben) – für Messungen `GraphicsSettings.fps_limit`.
- **Datenordner:** `application/config/use_custom_user_dir` → `user://` = `Application Support/Cube City` (Win `%APPDATA%`,
  Linux `~/.local/share`), auch im Editor. Autoload `UserData` (vor `Audio`, das sofort Einstellungen liest) kopiert beim
  ersten Start Spielstände + `settings.cfg` aus dem alten `Godot/app_userdata`-Ordner, nur wenn der neue noch leer ist.
- **HUD-Größe:** `Hud` (CanvasLayer) bekommt `scale = ui_scale`, das Wurzel-Control wird auf Fenstergröße / Faktor
  gesetzt (`_apply_ui_scale`, auch bei Fenstergröße-Änderung), damit Anker an den Rändern bleiben. Mausposition und
  Fensterbreite im HUD daher immer durch `scale` teilen (`_ui_size()`).
- **Reichweiten-Vorschau:** `ToolController.range_preview(tile)` (Tile → Farbe) bildet die Regeln aus
  `_build_transit_links` (BUS_RANGE, STATION_WALK, Zubringer) und `_service_tiles` nach — bei Regeländerung dort mitziehen.
  Eigene MultiMesh `_range` (render_priority 1, über der Ansichts-Einfärbung).
- **Ansichten (`MapOverlay`):** Boden-Tiles als flache Platte am Boden, **bebaute Tiles** (Zone mit Gebäude,
  Sonderbau) auf geschätzter Dachhöhe (`ROOF` je Zone/Stufe) in eigener MultiMesh `_roofs` ohne Tiefentest — am Boden
  lagen sie im Gebäude und waren unsichtbar (Kriminalität/Zufriedenheit). Farben über `_tint()`: sRGB→linear und
  Deckkraft × `GROUND_ALPHA` 0.35 / `ROOF_ALPHA` 0.6 (Nutzer: Stadt soll durchscheinen).
- **App-Icon/Startbild:** `assets/app/icon.png` (+ `.icns` per `iconutil`, im Export-Profil und `config/macos_native_icon`)
  wird mit `--appicon=pfad.png` aus `IconFactory` gerendert. `assets/app/splash.png` (seit 23.10.): Megacity-Kopie +
  `SplashArt` (scripts/dev/splash_art.gd): `--loadfile=<megacity-kopie> --splash[=brick|grass|stone] --cam=64,64,70
  --screenshot=…` – 3D-Logo aus Spielblöcken (Pixel-Schrift, 2x2 Blöcke je Pixel, Stil brick = Nutzerwahl) in eigener
  SubViewport, schwebende Gebäudeblöcke, Tilt-Shift-Unschärfe der Stadt (CameraAttributesPractical), Lichthof,
  Vignette, Schriftband. Nutzer-Feedback: bunte Flach-Würfel und Strahlenkranz passten nicht. Vollbild beim Start über `GraphicsSettings.apply_window()`, nie bei Läufen mit Dev-Flags.
- **Rohstoffe:** Map-Felder `ore` (Config.Ore) und `ore_amt` (Byte; 1 Punkt = `ORE_UNIT` Einheiten, Bruchteile in
  `Simulation._ore_used`, nicht gespeichert). Erzeugung `CityMap._generate_ores` (nach Höhe/Wassernähe + Rauschen).
  Abbau-Gebäude = Sonderbauten mit `"produce"` (bzw. `"storage"`), kein `"service"`. `Simulation._produce()` läuft in
  der Etappe „abschluss“: Förderung → `stock`, Überschuss über `stock_capacity()` → `export_income`. Info je Gebäude in
  `producer_info`. Stein ist ein Vorkommen (`Ore.STONE`, Fels im Hochland/an Hängen), Holz kommt aus `Feature.TREE`.
- **Verarbeitung/Baustoffe:** Werke = Sonderbauten mit `"process": {"in", "out"}` (optional `"pollution"`), laufen in
  `_process_goods()` nach `_produce()` in „abschluss“, danach `_export_surplus()`. Baustoffe in `RESOURCES` mit `"good"`.
  Wachsen auf Stufe ≥ 2 ruft `_use_materials` (Zukauf über `_buy` → `_import_pending`, im Budget abgebucht).
  Kohlekraftwerke verbrauchen `COAL_PLANT_USE` – erst nach den Werken (Vorrang), Rest wird zugekauft.
  Lieferweg: `_compute_delivery()` (Straßennetze, `_store_nets`) zu Beginn von `_produce`; `delivers(a)`,
  `delivery_at(t, s)` (Vorschau); `local_buffer` (gespeichert als "buffers") bei fehlendem Anschluss.
  Map-Save hat `ore_version`; neue Vorkommen-Arten für alte Saves in `from_dict` nachgenerieren (wie `_add_stone`). Balance-Messung: `--budgettest` (Demo + Megacity-Kopie).
- **Erneuerung** (`Simulation._renew`, Etappe „abschluss“ vor `_produce`): Waldausbreitung und Ader-Regeneration als
  **Stichprobe** (n·Rate zufällige Tiles statt Wurf je Tile — Volldurchlauf mit `randf()` kostete ~5 ms). Geänderte Tiles
  **einzeln** melden: ein Sammel-Rechteck über verstreute Tiles wird schnell die ganze Karte ⇒ alle Chunks neu und
  `FireDept._sync` verwirft bei voller Karte alle Einsätze. Recycling: `sim.recycle(zone, level)` / `recycle_special` aus
  dem Bulldozer. Wald wächst nur in Lücken (`FOREST_GAP` 5 von 8 Nachbarn) und bis `FOREST_MAX_SHARE` – mit „2 Nachbarn“
  war die Megacity des Nutzers nach ~1000 Spieljahren zu 65 % Wald. Baumschule stoppt bei `NURSERY_MAX_SHARE`.
- **Baumaterial beim Bauen:** `Config.BUILD_MATERIALS` (Infrastruktur je Tile) / `SPECIAL_MATERIALS` (je Sonderbau),
  `ToolController.tile_materials/materials_for` (nur wo `tile_cost > 0`), `sim.build_need(mats)` → [fehlend, Zukaufpreis],
  `sim.use_build_materials(mats)` nimmt aus dem Lager und bucht den Zukauf **sofort** ab (nicht Monatsende wie beim
  Wachsen). Vorschau: `preview_cost_changed` enthält den Zukauf, Details in `tools.preview_materials/missing/import`
  (HUD-Kostenblase). Neues Bau-Werkzeug ⇒ Material in beiden Tabellen + `Hud._tool_materials` ergänzen.
- **Balance 31.10. (nach Bot-Messung `--humanrun`):** `MATERIAL_FROM_POP` 2000 + `MATERIAL_DEBT` (Wachsen darf bis −2.000 $
  zukaufen – sonst Armutsfalle), Schule/Krankenhaus erwartet ab 1.000, Dienst-Unterhalt Stufe 1 × `SERVICE_UPKEEP_EARLY`,
  Steuer-Quadrat erst ab `TAX_HAPPY_SQ_FROM`, Forschung: Startpreis `RESEARCH_START_PER_POINT`, Budget bis 10.000 $.
  **Bot** `HumanPlayer` (scripts/dev/human_player.gd, `--humanrun=Jahre,seed`): schaut alle 3 Monate, Zufall, baut Blöcke
  je Zonenart erst bei 60 % Bebauung, verbindet Netze, baut Dienste aus. Bot-Fehler erst ausschließen, bevor man daraus
  Balance ableitet (Windrad-Flut, Steuer-Rundung, Gesamt- statt Zonen-Bebauung waren Bot-Fehler).
  Danach (31.10.): Steuerbasis `TAX_BASE_RES/JOB` +50 %, `UPKEEP_ROAD` 0.2, Schuldzinsen `DEBT_INTEREST`, Tempo
  `SECONDS_PER_MONTH` 8/4/1,5 s, Uni ab 6.000. Ergebnis Bot 50 J.: 1.500–4.000 Einw., keine Pleiten; Megacity +5.700 $/Monat
  (Forschung ist die Geldsenke). Ziel: normaler Spieler erreicht die Uni nach ~50–70 Spieljahren.
- **Balance-Stellschrauben (23.10.):** `IMPORT_FACTOR` 3, Wohnsteuer-Zufriedenheit `tax_happiness()` (linear `TAX_HAPPY_UP` +
  quadratisch `TAX_HAPPY_SQ` über neutral), Verwaltung `Simulation.admin_for(pop)` in `_budget` (`admin_cost`, HUD-Tooltip).
  Messen mit `--freshrun=20` (Neustart, skriptgesteuerter Ausbau) und `--loadfile=<kopie> --econreport` (Posten).
- **Forschung:** Universität = normaler Dienst (`SERVICES["university"]`, `radius_mul`/`capacity_mul` in SPECIALS →
  immer `sim.service_radius(a)` / `service_capacity(a)` / `Simulation.service_radius_for(sp, lv)` statt `SERVICE_RADIUS[lv]`).
  Sperren über SPECIALS-Schlüssel `unlock`, `need_coverage: [kategorie, anteil]`, `need_special` (`ToolController.locked_reason`).
  Zustand in `Simulation` (`research_done/current/progress/budget`, gespeichert unter "research"), Monatsschritt `_research()`
  vor `_budget()` (Ausgabe `research_spent` nur bei laufendem Projekt). Wirkung über `sim.tech(id)` an der jeweiligen Stelle
  (`_produce`, `_process_goods`, `_env_begin`, `growth_materials`/`build_factor`). Neues Projekt ⇒ `Config.RESEARCH` + Wirkung + README-Tabelle.
  HUD: Popup-Art "research" (`_fill_research`), Knopf `_research_btn`.
  Akademiker = absolute Zahl (`academics_count()` aus `service_load` × Kapazität der Unis), nicht Stadtquote (die bestrafte
  Großstädte). `institute_levels()` wird in `_recount` gezählt, `ToolController._special_present` cacht `need_special`
  (locked_reason läuft je Tile/Mausbewegung – Kartenscan dort hat den Test minutenlang blockiert).
- **Popover/Karten-UI:** Bausteine in `PopUI` (`pop_ui.gd`: header, section, row, bar, diverging, chip, box, problems,
  list_item, note). Popover = `_popup` → `_popup_scroll` → `_popup_col`; nach dem Füllen immer `_fit_popup()` (feste
  Breite, Höhe bis über die Werkzeugleiste, zweiter Durchgang nach einem Frame, weil umbrochene Labels ihre Höhe erst
  nach dem Layout kennen). **Größe nie verzögert nachmessen** (früher 2 Durchgänge mit `await` → sichtbares Zucken):
  `_popup_col.minimum_size_changed` → gebündelt per `call_deferred` → `_apply_fit` (noch im selben Frame vor dem
  Zeichnen, Notbremse 6 Anpassungen/Frame). Bildlaufleiste mit `SCROLL_MODE_RESERVE`, sonst schaukelt Breite ↔ Umbruch
  ↔ Höhe bis „Message queue out of memory“ (Absturz). Test `--popflash` misst je **gezeichnetem** Frame
  (`RenderingServer.frame_pre_draw`) – Messungen direkt nach einem Neuaufbau zeigen Zwischenstände, die nie gezeichnet
  werden. Info-Karte: `_show_info()` baut nur bei geändertem Inhalt neu (Signatur), `_info_rows()`
  zerlegt Zeilen; Klartext für Tests in `hud.info_text`. Neue Info-Zeilen deshalb als „Bezeichnung Wert“ bzw. „A: B“,
  mehrere mit „  ·  “ trennen.
- **Sichtbare Forschung:** `StructureGenerator.techs` (aus `sim.research_done`, gesetzt in main.gd bei stats_changed und
  in `_research()` vor dem Neuaufbau) schaltet Modell-Extras; bei Abschluss werden betroffene Gebäude **einzeln** neu
  gemeldet (`tech_impact()["anchors"]`). `ChimneySmoke` (render/chimney_smoke.gd): Puffs an `STACKS` (Schlot-Spitzen in
  Generator-Koordinaten, gedreht wie im Renderer über `_front_angle`; Kohlekraftwerk ungedreht) – neue Schlot-Gebäude
  dort eintragen; Industrie-Schlote über `BuildingGenerator.ind_stack()` (gleicher Zufall wie `_ind`, bei Änderung dort
  mitziehen). Signal `sim.research_finished(id)` → `Hud._on_research_finished` (Durchbruch-Karte).
- **Strom Tag/Nacht:** `_compute_power` rechnet je Netz `day` (alle Kraftwerke), `night` (ohne `"solar"`-Kraftwerke) +
  Speicher (`"storage_mw"`, höchstens Tagesüberschuss) und versorgt mit `min(day, night / NIGHT_DEMAND)` – ohne Solar
  identisch zu früher (Determinismus unverändert). Netz-Dict hat `day/night/storage/store_used/night_limited`.
  Biomasse verbrennt Holz in `_process_goods` (nach den Werken, Zukauf wie Kohle). Bau-Sperre über Forschung:
  SPECIALS-Schlüssel `need_tech` (in `locked_reason`). Standortregeln über SPECIALS `"site"` ("water", "hill") in
  `ToolController.site_reason()` (Vorschau `preview_site` ersetzt den Preis durch den Grund). Salzspeicher-Werkzeug
  über einem Kohlekraftwerk = Umrüsten (`_convert_target`/`_convert_to_salt`, gleiche Grundfläche, `SALT_CONVERT`).
- **Tageszyklus (Optik):** `DayNight` (render/day_night.gd, in main vor ShaderWarmup) steuert Sonne, Himmel, Nebel,
  Umgebungslicht und das Leuchten des Fensterblocks "ice" (Emission dauerhaft an, nur Stärke ändert sich – Umschalten von
  `emission_enabled` würde Shader neu kompilieren). Testläufe frieren die Uhrzeit ein (`frozen`, `--time=`).
  `DAY_BIAS` verschiebt die Sonnenhöhe (Nacht ~25 % des Zyklus). **Lichtrichtung bleibt fest** (`SUN_DIR`): eine je Frame
  gedrehte Sonne dreht das Schattenkarten-Raster mit → Schatten flimmern (Nutzer). HUD-Stromanzeige zeigt bei `DayNight.daylight < 0.45`
  die Nachtbilanz (`_update_power_label`, Wechsel in `Hud._process` erkannt).
- **Forschungsfenster:** Projekte tragen `"group"` in `Config.RESEARCH`; `_fill_research` baut je Bereich einen
  aufklappbaren `PopUI.list_item` (`_research_open`), darunter Karten (`_research_row`, `PopUI.box`) in Reihenfolge
  `_research_ordered` (Vorgänger zuerst); gesperrt = ausgegraut + „Voraussetzung: …“ (keine Einrückung/Pfeile, Nutzerwunsch). Breite je Popover-Art in `_popup_width()`. Neues Projekt ⇒ `group` setzen.
- **Stufe 4 (Hochhaus/Büroturm):** alle Stufen-Tabellen haben 5 Einträge (`RES/COM/IND_CAPACITY`, `POWER_USE`,
  `MATERIAL_COST`, `POLLUTION_IND_PER_LEVEL`, `MapOverlay.ROOF`, `StatusMarkers.LEVEL_OFFSET`) – neue Stufen-Tabelle ⇒
  5 Einträge. `_max_level` erlaubt 4 nur mit Forschung (`highrise`: Bodenwert `RES_MIN_LAND[4]`, keine Villa; `offices`:
  `COM_MAX_LEVEL_BY_DEPTH` 4 + Ecke + `COM_TOWER_LAND`). Industrie bleibt bei 3.
- **Hightech-Industrie:** Map-Feld `hightech` (Zone bleibt IND), Werkzeug `Tool.HIGHTECH` (`_tool_zone` = IND, `_clear`
  setzt zurück). Verschmutzung × `HIGHTECH_POLLUTION`, Steuer über `jobs_hightech` (Posten "Hightech"), `_max_level` = 0
  ohne Hochschul-Abdeckung (`_uni_cover`). Renderer `BuildingGenerator._hightech`, kein Rauch.
- **Verkehrsleitsystem:** `traffic_control` (in `_recount` aus `tech("traffic")`, steht in `COMMUTE_IN`, weil der
  Pendler-Worker keine Forschung kennt) teilt die Straßenkapazität durch `TRAFFIC_CONTROL`.
- **Beenden:** `main.gd` setzt `set_auto_accept_quit(false)` und fängt `NOTIFICATION_WM_CLOSE_REQUEST` ab → `Hud.ask_quit(slot)`
  (Testläufe: sofort beenden). Signal `quit_requested(save_slot)` → `main._quit` speichert ggf. und beendet.
  `main.current_slot` = zuletzt geladener/gespeicherter Platz (auch an `hud._current_slot_hint` für den Menü-Knopf).
- **Instandhaltung:** `Simulation._maintenance()` (abschluss, nach `_process_goods`): `MAINT_RATE` × MATERIAL_COST je
  bewohntem Gebäude ab Stufe 2 (ab `MATERIAL_FROM_POP`), Recycling im Kreis (`RECYCLE_MAINT`, Kapazität `RECYCLE_CAP`),
  Rest Lager/Zukauf; ohne Geld `maint_short` → sanfter Auszug in `_grow_rows`. Recyclinghof-Kreis über `radius_mul` 3
  (`recycler_covers(i)`; Abriss-Rückgabe hängt am Tile, `recycle(zn, lv, tile)`).
- **Bürgermeister** (`render/mayor.gd`, Node „Mayor“ in main, `hud.mayor`): `Hud.notify()` ruft `mayor.say(text, tile, good)` –
  jede Warnung läuft also automatisch über ihn. Heimatplatz `_find_home()` alle 5 s/bei `tiles_changed`: vor der Rathaus-Front
  (gleiche Seitenwahl wie `WorldRenderer._front_angle`; „nächste Straße“ lag oft hinter dem Rathaus = verdeckt), ohne
  Rathaus Straße am Wohn-Schwerpunkt. Sprechblase zeichnet das HUD (`_update_bubble`, `cam.unproject_position(mayor.head())`).
  Kit-Charaktere haben einen **eigenen** 32-px-Atlas → nicht `BlockLibrary.fix_node_materials` (tauscht ihn gegen den
  Block-Atlas), nur Nearest-Filter (`_nearest`). Modell ist bei Skala 1 schon 2,66 Blöcke hoch.
- **Speichern:** neue Map-Felder in `CityMap.SAVE_FIELDS` eintragen; fehlende Felder alter Saves werden genullt.
  `SaveManager.save` rotiert vorher Sicherungen (`<slot>.bak1..3`, nur Spieler-Slots). Tests, die Spieler-Slots
  benutzen wollen, stellen `SaveManager.dir` auf einen eigenen Ordner um (siehe `savetest`).

- **Nur ein Spielmodus (31.10., Nutzer):** kein „klassischer“ Modus mehr, `sim.game_mode` ist weg (gespeichert wird
  `"game_mode": "build"` nur noch als Marker). Alte Saves ohne Marker rechnet `CityMigrate.run` in `SaveManager.load_file`
  um (Stufe aus Einwohnern + Gebautem, `construct` = 0, Rathaus per `best_site`, Lager per `_worst_gap`-Integralbild,
  notfalls Abriss; Ergebnis in `CityMigrate.last`, Meldung über `sim.message`). Spielstart ohne Dev-Flags ruft
  `main._new_city()`. **Dev-Läufe** setzen in `DevTools.run` `hall_level` auf die höchste Stufe (Demo/Tests bauen auf
  leerer Karte mit allen Werkzeugen); `--buildstart` setzt über `_new_city()` zurück auf 1. Bot `HumanPlayer` startet mit
  `START_MONEY` + höchster Stufe (überspringt Gründung; baut keine Lager → Ergebnisse über 2.000 Einw. nicht mehr mit
  früheren vergleichbar, Bot-Ausbau für Gründung/Lager steht aus). `ToolController.special_for` ist static (Migration nutzt es).
  Rathaus-Stufe `sim.hall_level` (1..5). Start:
  `CityStart.setup_build` (Rathaus `Special.CITYHALL` 3x3 mit `"storage"` + 30 MW, Lichtung, Straßenstück). Sperren über
  `ToolController.HALL_LEVEL` (Tool → Stufe) in `locked_reason`. Vor Stufe 2: `can_trade()` false (kein Zukauf, Werkzeuge
  verweigern bei fehlendem Material: `_no_trade_reason`), keine Steuern/kein Unterhalt (`_budget`), Sonderbauten
  × `BUILD_FOUNDING_COST`, `founding_jobs()` statt Gewerbe/Industrie, RES ohne Pendel-Pflicht (`_can_grow`,
  `growth_blockers`). Stufe-1-Material `BUILD_LV1_COST` über `growth_materials` (Wachstum 0→1 ruft `_use_materials`).
  Rathaus-Fenster: HUD-Popup "hall" (`_fill_hall`), Ausbau `sim.upgrade_hall()`.
- **Baustellen/Lager-Netz:** Map-Feld `construct` (halbe Monate, Sonderbau am Anker). `residents`/
  `jobs_at`/`_recount` zählen Baustellen nicht, `special_powered` ist false und Kraftwerke liefern 0, `_producers` überspringt.
  `_advance_construction()` (abschluss, vor `_recount`) zieht im Lager-Kreis 2, sonst 1 ab und meldet fertige Tiles einzeln;
  `_compute_store_cover()` → `store_cover`. Start der Bauzeit: `_grow_rows` (Stufe hoch) bzw. `ToolController._place_special`.
  Renderer: `StructureGenerator.scaffold` statt Gebäude.
- **Progression über Rathaus-Stufen (Nutzer-Grundsatz 31.10.):** Jede neue Großfunktion (U-Bahn, Wasserleitungen,
  Flughafen, …) wird künftig an eine Rathaus-Stufe gebunden, deren Ausbau Material kostet – nicht nur an Einwohnerzahlen.
  Konzept Aufbau-Start: README → Roadmap.

## Fallstricke (schon einmal hineingetappt)

- GDScript: Warnungen „type inferred from Variant“ sind hier **Fehler** → bei Dictionary/Array-Werten explizit typisieren
  (`var x: float = d["k"]`, `var t: Transform3D = ...`).
- Member-Variable und Funktion dürfen nicht gleich heißen (`_stamp`-Konflikt).
- Packed-Arrays an Hilfsfunktionen übergeben und dort ändern ist riskant (Kopiersemantik) → Member-Arrays nutzen.
- Funktionsaufrufe in großen Schleifen sind in GDScript teuer → in heißen Schleifen inline rechnen, Map-Arrays lokal referenzieren.
- `MultiMesh.buffer` (12 Floats je Instanz) statt `set_instance_transform` je Instanz.
- Glatte Kit-glTFs betten nur einen 32-px-Atlas ein → `BlockLibrary.fix_mesh_materials` ersetzt ihn durch `assets/Atlas.png`
  (nur wenn Textur ≤ 32 px; Pixel-Blocks haben eigene 80-px-Textur). Immer Nearest-Filter.
- Silkscreen hat kein `− ✓ ✗` → ASCII (`- + x`) verwenden.
- Shader-Kompilier-Ruckler: neue Meshes/Materialien landen automatisch im `ShaderWarmup` (liest `BlockLibrary.meshes`);
  Fahrzeug-Meshes dort explizit ergänzen.
- MultiMesh-Instanzfarben sind **linear**: sRGB-Farben vorher `.srgb_to_linear()` (sonst blass/weiß; ältere Autos sind
  deshalb pastell). Effekt-Würfel (Rauch) unshaded, sonst färbt das Himmelslicht sie bläulich.
- `--cam=x,z` zielt auf Wasserhöhe → Bildmitte liegt nicht genau auf dem Tile; `CityCamera.focus_tile(t, höhe)` nutzt Geländehöhe.
- Demo-Aufbau (`tick_month()` ×60) kann Brände starten, die erst im laufenden Spiel weiterbrennen → Demo zeigt oft schon Brände.
- Button mit Text + `expand_icon = true` ⇒ Icon schrumpft auf 0 → `Hud._set_btn_icon()` (feste `icon_max_width`).
- Kompilierfehler in einem Dev-Test ⇒ `main.gd` lädt nicht, Fenster bleibt offen und `--quit` greift nie (Befehl hängt).
  Erst `--headless --import` prüfen. Neue Funktion nie mitten in eine bestehende einfügen (Rumpf-Rest landet in der neuen).
- GDScript im Thread + parallel GDScript im Hauptthread: viele Allokationen (Arrays je Schritt, `RefCounted.new()`)
  bremsen sich gegenseitig massiv (gemessen 17×). Heiße Schleifen allokationsfrei schreiben.
- Lokaler Alias eines Member-Packed-Arrays (`var p := _parent`) kopiert beim ersten Schreiben → Hilfsfunktionen, die den
  Member lesen, sehen alte Daten. Nur aliasen, was ausschließlich lokal genutzt wird.
- `git stash` springt hier auf den ersten Commit zurück (alles andere ist uncommittet) → kein Vergleichsstand.
- Testfenster (Screenshot/`--quit`) schieben sich unter macOS in den Vordergrund und bekommen Tastatur **und Maus**
  des Nutzers → `DevTools.automated` lässt HUD/Kamera/Werkzeuge echte Eingaben ignorieren (künstliche Test-Events
  tragen Meta `synthetic`); Buttons zusätzlich per `gui_disable_input` gesperrt (einmal hat ein Klick in ein
  Menü-Testfenster die Grafikeinstellung des Nutzers umgestellt). `Window.unfocusable` hilft auf macOS nicht. Der alte Fehlschlag „dragtest Straße 0 Tiles“
  kam daher.
- Export: Vorlage enthält nur `universal`, und `textures/vram_compression/import_etc2_astc` muss an sein.
- **Performance-Änderungen an der Simulation** immer mit `--loadfile=build/backups/megacity_2026-10-12.citysave --determinism`
  vorher/nachher vergleichen (Prüfsummen müssen gleich bleiben; seit 31.10. inkl. Umrechnung beim Laden – Stand vom 31.10.:
  Einw. nach 12 Monaten 15333, `level 3670374623`). Fester Zufall braucht `seed()` **vor** jeder
  Neuberechnung und leere Vorgeschichte (`congestion`, `station_use`), sonst streut das Ergebnis.
- `notify_changed` mit Rechteck = ganze Karte bedeutet für `FireDept` „neue Karte geladen“ (Einsätze weg) → nie Sammel-Rechtecke über die Karte melden.
- GDScript-Lambdas fangen lokale Variablen **als Kopie** (`var n := 0; sig.connect(func(): n += 1)` zählt nicht) → Array nutzen.
- Beim Ersetzen von Code per Skript nicht über Blockgrenzen schneiden (einmal ist so ein Config-Block verloren gegangen).

## Stil & Design (vom Nutzer gewünscht)

- Optik: Cube World Kit; Terrain/Gebäude mit texturierten **Pixel Blocks**, Fahrzeuge/Schilder aus glatten Blöcken.
- HUD: helle „Spielzeug“-Karten mit Holzrand (`ui_theme.gd`), schwebend; Icons aus Modellen gerendert, keine Pixel-Art.
- Werkzeugleiste: Gruppen klappen auf (`Hud.TOOLBAR`), Hinweiszeile über der Leiste erklärt das Werkzeug.
- Musik ruhig/ASMR wie Minecraft (Felt-Piano), Geräusche nur nah gezoomt hörbar.
- Spielmechanik soll erklärbar sein: Info-Karte nennt Gründe (Blocker, fehlende Dienste), Vorschau zeigt Eignung,
  Ansichten (V) machen Felder sichtbar. Neue Mechaniken immer mit Anzeige + Test + README-Abschnitt.

## Offene Punkte / Ideen

- Bahnhofs-Kapazität ist umgesetzt (Aufschlag + hartes Limit 150 %). Gleis-Kapazität (`RAIL_CAPACITY`) wirkt weiter nur
  weich. Pendler, die nirgends hinkommen, zählen nur als `unreachable_workers` (kein Wachstums-Malus) — ggf. später.
- **Balance ist Zwischenstand (23.10.):** nach Einbau der Forschung neu prüfen (`--freshrun`, `--econreport`): Früh-Spiel
  zu leicht (Geld bremst nie, nur Nachfrage), Startkapital ggf. 15.000; Spät-Spiel braucht Forschung als Geld-/Gold-Senke.
- Nutzer-Spielstände analysieren: Datei nach Scratchpad **kopieren**, dann `--loadfile=<kopie>` (+ `--jamreport`, `--cartest`).

Siehe README → Roadmap. Zusätzlich: Brand-Balance im echten Spiel beobachten (Brenndauer 10 s, Ausbreitung 25 %), Balance der Dienstkosten beobachten,
`--lanetest` hat in der Demo oft wenige Messungen (wenig Verkehr auf der Hauptstraße).
