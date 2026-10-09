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
$G --path . -- --demo --profile=20,3 --quit                               # Performance (Ruckler > 25 ms)
$G --path . -- --demo --cam=32,32,60 --screenshot=/pfad/bild.png          # Screenshot ansehen (Read-Tool)
```
- Dev-Flags/Tests liegen in `scripts/dev/` (nie in `main.gd`). Neue Tests dort als statische Funktion + Flag in `dev_tools.gd`.
- `--tool=<icon>` wählt ein Werkzeug (Gruppe klappt auf), `--overlay=1..5` Ansicht, `--menu`, `--gfx=0..2`.
- Tests, die die Karte direkt ändern, müssen danach `map.notify_changed(...)` rufen (sonst veraltete Caches).
- Profilieren nur mit Fenster im Vordergrund (macOS drosselt verdeckte Fenster → falsche 1-s-Spitzen; `profile()` setzt always-on-top).
- Testspielstände (`selftest`, `servicetest`) werden wieder gelöscht; echte Spielstände des Nutzers liegen in
  `~/Library/Application Support/Godot/app_userdata/Cube City/saves/` — nicht anfassen.

## Architektur-Prinzipien

- **Daten ↔ Darstellung getrennt:** `CityMap` (Packed-Arrays, keine Logik außer Abfragen), `Simulation` (Regeln),
  Renderer/Fahrzeuge/HUD lesen nur. Alle Spielwerte in `config.gd`.
- **Änderungen melden:** `map.notify_changed(rect, infra := true)`. `infra=false` nur bei reinen Gebäudestufen
  (Wachstum, Brände) → Autos/Züge/Hauptstraßen-Cache werden dann nicht neu berechnet. Bauwerkzeuge melden immer `infra=true`.
- **Simulation verteilt:** Monat = `TICK_STAGES` (je Frame eine Etappe, je ≤ ~9 ms). `tick_month()` = synchron (Tests/Demo),
  `refresh()` = alles sofort (nach Bauaktionen). Neue teure Berechnungen als eigene Etappe einhängen.
- **Pendler-Graph:** Knoten 0..n-1 Straßen-Tiles, n..2n-1 Gleis-Tiles; Bahnhöfe verbinden per Fuß/Zubringerbus.
  Incremental assignment in 3 Etappen (sonst nutzt niemand Parallelstraßen). Kosten: `(1 + 2·Auslastung²)/Tempo`,
  Abbruch über Weglänge (`MAX_HOPS`), nicht über Staukosten (sonst verschwindet Überlast als "unerreichbar").
- **Rendering:** alles aus Kit-Blöcken via `BlockBatch` → MultiMesh je Mesh-Typ und Chunk. `put()` = Block an Ecke,
  `put_box()` = skalierte Box um Mittelpunkt (nur für Keys mit Einheitswürfel-Normierung, also nicht PLATES),
  `put_prop()` = Modell unten mittig. Neue Gebäude in `structure_generator.gd` / `building_generator.gd`.
- **Icons** werden aus denselben Generatoren per SubViewport gerendert (`icon_factory.gd`) — neues Gebäude ⇒ Icon-Case ergänzen.
- **Hauptstraße** wird nicht gebaut, sondern erkannt: 2 parallele Straßen nebeneinander (`CityMap.wide_partner`,
  vorberechnet in `_compute_wide`; Fahrtrichtung = längere Achse, Paare ab Bandkante). Enden → Viertelbogen (`_emit_taper`).
- **Sonderbauten** (`Config.SPECIALS`): Kraftwerke + Dienste/Kultur, Größe 1 oder 2, `anchor` = Ursprungs-Tile,
  `slevel` = Ausbaustufe 1..3 (0 in alten Saves ⇒ 1). Dienste haben `"service"`-Kategorie aus `Config.SERVICES`.
- **Speichern:** neue Map-Felder in `CityMap.SAVE_FIELDS` eintragen; fehlende Felder alter Saves werden genullt.

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
- Beim Ersetzen von Code per Skript nicht über Blockgrenzen schneiden (einmal ist so ein Config-Block verloren gegangen).

## Stil & Design (vom Nutzer gewünscht)

- Optik: Cube World Kit; Terrain/Gebäude mit texturierten **Pixel Blocks**, Fahrzeuge/Schilder aus glatten Blöcken.
- HUD: helle „Spielzeug“-Karten mit Holzrand (`ui_theme.gd`), schwebend; Icons aus Modellen gerendert, keine Pixel-Art.
- Werkzeugleiste: Gruppen klappen auf (`Hud.TOOLBAR`), Hinweiszeile über der Leiste erklärt das Werkzeug.
- Musik ruhig/ASMR wie Minecraft (Felt-Piano), Geräusche nur nah gezoomt hörbar.
- Spielmechanik soll erklärbar sein: Info-Karte nennt Gründe (Blocker, fehlende Dienste), Vorschau zeigt Eignung,
  Ansichten (V) machen Felder sichtbar. Neue Mechaniken immer mit Anzeige + Test + README-Abschnitt.

## Offene Punkte / Ideen

Siehe README → Roadmap. Zusätzlich: Brandrisiko evtl. zu hoch (Meldungen), Balance der Dienstkosten beobachten,
`--lanetest` hat in der Demo oft wenige Messungen (wenig Verkehr auf der Hauptstraße).
