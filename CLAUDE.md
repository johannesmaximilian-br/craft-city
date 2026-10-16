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
$G --path . -- --demo --profile=20,3 --quit                               # Performance (Ruckler > 25 ms), läuft mit 60-FPS-Grenze
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
- **Simulation verteilt:** Monat = `TICK_STAGES` (je Frame eine Etappe, je ≤ ~9 ms). `tick_month()` = synchron (Tests/Demo),
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
- **Verfall:** `decay_reason(i)` bündelt alle Abstiegsgründe aus `_grow()`; `_grow()` setzt monatlich `map.worn`
  (Map-Feld, damit der Renderer es lesen kann) und meldet Änderungen mit `infra=false`. Neuer Abstiegsgrund ⇒ in beiden ergänzen.
  Renderer: `_put_worn` tauscht ~35 % der Blöcke gegen verwitterte (`WORN_KEYS`), `_emit_worn_props` setzt Ranken/Geröll.
- **Strom:** `_compute_power` erfasst **alle** leitenden Komponenten (auch ohne Kraftwerk) → `power_net` je Tile,
  `power_nets` (capacity, demand, plants, unserved, dark). Meldungen über Signal `sim.alert(text, tile)` nur bei neuen
  Problemen (`_power_warned`). Anzeige oben = Bedarf aller Gebäude, rot bei irgendeinem Gebäude ohne Strom.
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
- **Speichern:** neue Map-Felder in `CityMap.SAVE_FIELDS` eintragen; fehlende Felder alter Saves werden genullt.
  `SaveManager.save` rotiert vorher Sicherungen (`<slot>.bak1..3`, nur Spieler-Slots). Tests, die Spieler-Slots
  benutzen wollen, stellen `SaveManager.dir` auf einen eigenen Ordner um (siehe `savetest`).

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
- Nutzer-Spielstände analysieren: Datei nach Scratchpad **kopieren**, dann `--loadfile=<kopie>` (+ `--jamreport`, `--cartest`).

Siehe README → Roadmap. Zusätzlich: Brand-Balance im echten Spiel beobachten (Brenndauer 10 s, Ausbreitung 25 %), Balance der Dienstkosten beobachten,
`--lanetest` hat in der Demo oft wenige Messungen (wenig Verkehr auf der Hauptstraße).
