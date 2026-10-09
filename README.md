# Cube City

SimCity-artiger Städtebau im Blockstil. Godot 4.7, GDScript, Assets: [Quaternius Cube World Kit](https://quaternius.com/packs/cubeworldkit.html) (CC0), Font: Silkscreen (OFL, `assets/fonts/`).

## Starten

Projekt in Godot öffnen → F5. Dev-Flags (nach `--`):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --demo --screenshot=shot.png
```

## Steuerung

| Eingabe | Aktion |
|---|---|
| WASD / Pfeile | Kamera verschieben |
| Leertaste + Linksklick ziehen, mittlere Maus, Linksklick im Info-Modus | Karte greifen & ziehen |
| Q / E, rechte Maus ziehen | Drehen / Neigen |
| Mausrad | Zoom |
| 1 Info · 2 Straße · J Bushaltestelle · R Gleis · Z Bahnhof · 3 Stromleitung | Werkzeuge |
| 4/5/6 Wohnen/Gewerbe/Industrie · 7 Kohle · 8 Wind · 9 Baum · 0 Park · T/G Terrain · B Abriss | Werkzeuge |
| U Polizei · F Feuerwehr · L Schule · K Krankenhaus · N Bibliothek · X Kino · C Bürgerhaus | Dienste & Kultur (nochmal auf Gebäude klicken = Ausbau) |
| Toolbar-Button mit `^` | Gruppe: klicken wählt zuletzt genutztes Werkzeug und klappt die Auswahl auf |
| Linke Maus ziehen | Fläche (Zonen) / Linie in L-Form (Straße, Gleis, Leitung) |
| Shift + ziehen (Straße) | Straßenraster mit 6 Tiles tiefen Blöcken |
| P | Pause |
| V | Ansicht: Verkehr → Verschmutzung → Bodenwert → Kriminalität → Zufriedenheit → aus |
| Esc | Menü: Speichern / Laden / Neue Stadt |
| F5 / F9 | Schnellspeichern / Schnellladen |
| M | Musik an/aus (Lautstärken im Menü) |

## Regeln (Kurz)

- Zonen wachsen nur mit **Straße** (≤3 Tiles), **Strom** und **Nachfrage** (RCI-Balken). Info-Karte zeigt Blocker.
- Strom fließt durch Leitungen, Zonen und Kraftwerke — **nicht über Straßen**, dort Leitung drüberziehen.
- Zu wenig Kapazität → Stromengpass, entfernte Tiles fallen aus (Blitz-Symbol).
- Kohlekraftwerk senkt Bodenwert von Wohngebieten in der Nähe.
- **Pendler**: 55 % der Einwohner fahren monatlich zum nächsten freien Job (Dijkstra, Stau verteuert Wege).
  Wohnen braucht erreichbare Jobs (auch per Bahn), Gewerbe/Industrie erreichbare Einwohner. Fahrzeit > 40 blockiert Wohnwachstum.
- **Stau** senkt Bodenwert und bremst Autos sichtbar.
- Spielstände: `user://saves/*.citysave` (macOS: `~/Library/Application Support/Godot/app_userdata/Cube City/saves/`).

## Entwicklung & Tests

Dev-Werkzeuge liegen getrennt vom Spielcode in `scripts/dev/` und laufen nur mit Flags (nach `--`):

- `dev_tools.gd` — wertet Flags aus: `--demo`, `--cam=x,z,dist`, `--overlay[=1..5]`, `--menu`, `--flyout`, `--screenshot=pfad`, `--quit`
- `demo_city.gd` — reproduzierbare Teststadt (Zonen, Strom, ÖPNV, 4-spurige Straße mit Verjüngung)
- `dev_tests.gd` — `--selftest` (Timing, Speichern/Laden, Audio), `--dragtest` (echtes Maus-Ziehen), `--lanetest` (Rechtsverkehr auf Hauptstraßen), `--widetest` (Hauptstraßen-Erkennung), `--profile[=Sek,Tempo]` (Frame-Zeiten + Ruckler-Ursachen), `--gfx=0..2`, `--nowarmup`, `--servicetest`, `--tool=<name>`, `--traffictest` (Korridor: Straße/Parallelstraße/Hauptstraße/Bus/Bahn), `--pickcheck`

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --demo --selftest --dragtest --traffictest --quit
```

## Dienste, Zufriedenheit, Kriminalität

| Dienst | erwartet ab | Wirkung |
|---|---|---|
| Polizei | 300 Einw. | senkt Kriminalität (bis 85 %) |
| Feuerwehr | 300 Einw. | verhindert Brände (ohne: Gebäude brennen ab, Industrie 3x häufiger) |
| Schule | 600 Einw. | Zufriedenheit + Fachkräfte (Gewerbe/Industrie wachsen schneller) |
| Krankenhaus (2x2) | 600 Einw. | Zufriedenheit |
| Bibliothek / Kino | 1.500 Einw. (baubar ab 1.000) | Kultur |
| Bürgerhaus (2x2) | 1.500 Einw. (baubar ab 2.000) | Kultur, groß |

- **Ausbaustufen 1–3**: gleiches Werkzeug auf das Gebäude → Reichweite 6/9/12 Tiles, Kapazität 800/2.000/4.500 Einwohner, mehr Etagen. Überlastete Gebäude wirken schwächer.
- **Zufriedenheit** je Wohnhaus: Bodenwert + versorgt (+) / unversorgt (−, sobald die Stadtgröße den Dienst verlangt) − Kriminalität − Steuern. **Unter 30 % ziehen Leute weg** → weniger Kunden/Arbeitskräfte → Gewerbe und Industrie schrumpfen. Zufriedene Städte locken Zuzug an.
- **Kriminalität** aus Dichte, niedrigem Bodenwert und Arbeitslosigkeit; Polizei senkt sie; schadet Zufriedenheit und Gewerbe.
- Mit einem Dienst-Werkzeug in der Hand zeigt die Karte dessen **Versorgung** (grün/gelb/rot). Die Info-Karte eines Hauses nennt fehlende Dienste.
- Test (`--servicetest`, Demo-Stadt ohne Dienste, 36 Monate): ohne Dienste 570 → 530 Einw., Zufriedenheit 35 %, 6 Brände; mit Diensten → 770 Einw., 55 %, 1 Brand.

## Zonen richtig planen

Beim Aufziehen färbt die Vorschau jedes Tile nach **Eignung** (grün/gelb/rot).

| | Ideal | Vermeiden |
|---|---|---|
| **Blockgröße** | 6 Tiles tief zwischen zwei parallelen Straßen (je 3 Tiles Reichweite) – Shift+Ziehen baut so ein Raster | Tiles > 3 von der Straße wachsen nie |
| **Wohnen** | Bodenwert hoch: Wasser, Wald, Parks, Höhenlage. Stufe 2 ab 35 %, Wohnblock (Stufe 3) ab 55 % Bodenwert | < 5 Tiles zu Industrie, < 8 zum Kohlekraftwerk, Staustraßen (Lärm) |
| **Gewerbe** | Viele Einwohner im Umkreis von 6 Tiles (Kundschaft), zwischen Wohnen und Industrie | Abgelegen ohne Wohngebiete |
| **Industrie** | Am Rand, gute Straßenanbindung, Abstand zu Wohnen | Direkt neben Wohngebieten (verschmutzt 4 Tiles weit) |

Werte und Reichweiten: `scripts/config.gd` (Abschnitt *Standortregeln*).

## Verkehr

- Pendler werden in 3 Etappen verteilt; jede Etappe sieht den Stau der vorherigen → **Parallelstraßen und Umfahrungen werden genutzt**.
- Kapazität pro Tile: Straße 300 Pendler/Monat.
- **Hauptstraße entsteht automatisch**: zwei parallele Straßen direkt nebeneinander verschmelzen zur 4-spurigen Straße. Fahrtrichtung = Achse, entlang der der Straßenzug länger ist; breitere Flächen werden von der Kante aus zu Paaren (4 Reihen = 2 Hauptstraßen), Querstraßen bleiben Kreuzungen (weiße Spurlinien, gelbe Doppel-Mittellinie), 450 je Tile (Paar 900 statt 600), Autos 35 % schneller. Richtungsgetrennt: jede Fahrtrichtung nutzt ihre Hälfte (Rechtsverkehr) mit 2 Spuren, Busse außen. Endet eine Hälfte, läuft sie in einem Viertelbogen in die weiterführende Spur aus.
- Grundstücke nutzen alle Straßen in 3 Tiles Reichweite → zusätzliche Straßen nehmen Last ab.
- Stau-Anzeige = Stau, den Pendler im Schnitt erleben. Über 100 % = mehr Pendler als Kapazität.

### Bus & Bahn

| | Wirkung | Kosten / Unterhalt |
|---|---|---|
| **Bushaltestelle** (auf Straße) | Liegen Start *und* Ziel im Umkreis von 3 Tiles einer Haltestelle, fahren 40 % Bus. Ein Busfahrer = 10 % Straßenlast. **Zubringer:** Haltestelle ≤ 4 Tiles vom Bahnhof bindet das ganze zusammenhängende Haltestellen-Netz an die Bahn an. Busse fahren ab 2 Haltestellen. Grundstücke mit Bus-/Bahnanschluss: +8 % Bodenwert. | $150 / $4 |
| **Gleis** | Eigenes Netz, darf Straßen kreuzen (Bahnübergang), max. 1 Block Steigung | $40 / $0,5 je Tile |
| **Bahnhof** (auf Gleis) | Fußweg bis 4 Tiles + Umsteigezeit; Bahn ist schnell und praktisch staufrei. Pendler wählen den Zug nur, wenn er schneller ist. Verbindet getrennte Straßennetze. | $800 / $15 |

Test (`--traffictest`, Korridor mit 1.500 Pendlern):

| Szenario | Verbindung max | ÖPNV-Anteil |
|---|---|---|
| 1 Straße | 495 % | 0 % |
| + Parallelstraße | 249 % | 0 % |
| beide als Hauptstraße (2 Spuren) | 84 % | 0 % |
| 1 Straße + 4 Bushaltestellen | 449 % | 10 % |
| 1 Straße + Bahnlinie mit 2 Bahnhöfen | 51 % | 90 % |
| Bahnhöfe an der Viertel-Ecke, ohne Bus | 65 % (Weg Ø 55) | 87 % |
| Bahnhöfe an der Ecke + Zubringerbusse | 44 % (Weg Ø 41) | 91 % |

## Performance

- **Simulationsmonat auf 4 Frames verteilt** (Netz → Pendler → Umwelt → Wachstum), je ≤ 9 ms; Pendler/Umwelt nur einmal pro Monat.
- **Wachstum ≠ Netzänderung:** Gebäudestufen lösen keine Karten-Scans (Autos, Züge, Hauptstraßen) aus.
- **Chunk-Neubau** mit Zeitbudget (4 ms/Frame), MultiMesh-Daten als ein Block statt je Instanz.
- **Shader-Aufwärmen** beim Start: jedes Material einmal rendern → kein Kompilier-Ruckler, wenn später z.B. der erste Bus erscheint.
- **Grafik** im Menü: Hoch (Schatten 4096, SSAO, MSAA 2x) · Mittel (Schatten 2048, FXAA) · Niedrig (ohne Schatten, 75 % Auflösung mit FSR) · VSync.
- Messung: `--demo --profile=30,3` → 58 Monate bei Höchsttempo, Ø 8,4 ms (120 FPS, VSync), kein Ruckler > 25 ms im Spiel.

## Audio

Alle Klänge sind **vorab erzeugt** (keine Laufzeit-Synthese), lizenzfrei, reproduzierbar:

```bash
python3 tools/audio/gen_audio.py              # alles (~1 min)
python3 tools/audio/gen_audio.py sfx ambient  # nur Effekte + Loops (~3 s)
```

- `assets/audio/music/*.mp3` — 4 ruhige Felt-Piano-Stücke + Pad + Faltungshall, Playlist mit 25–70 s Stille dazwischen
- `assets/audio/ambient/*.wav` — nahtlose Loops: Verkehr, Industrie, Wind, Vögel
- `assets/audio/sfx/*.wav` — Klick, Bauen, Zone, Abriss, Fehler, Hinweis
- `scripts/audio/audio_manager.gd` (Autoload `Audio`) — Verkehr/Industrie als 3D-Quellen an den lautesten Orten nahe dem Kamerafokus, nur nah gezoomt hörbar; Wind lauter beim Rauszoomen, Vögel nah über Grün
- Eigene Musik: MP3 nach `assets/audio/music/` legen und in `MUSIC` eintragen

## Aufbau

1 Tile = 3×3 Blöcke (1 Block = 1 Welteinheit), Höhe in Blockschritten, Karte 64×64 Tiles. Alle Spielwerte in `scripts/config.gd`.

| Datei | Aufgabe |
|---|---|
| `main.gd` | Einstieg: baut Welt, Simulation, Kamera, Werkzeuge, HUD; Speichern/Laden; Umgebung/Licht |
| `config.gd` | alle Konstanten (Kosten, Kapazitäten, Reichweiten, Standortregeln, Dienste) |
| `city/city_map.gd` | Kartendaten als Packed-Arrays + Signale `tiles_changed` / `infra_changed`, Hauptstraßen-Erkennung |
| `city/simulation.gd` | Monat in 5 Etappen: Netz/Strom → Pendler → Umwelt → Dienste → Wachstum/Brände/Budget |
| `city/save_manager.gd` | Spielstände (Meta + Daten, ZSTD) |
| `tools/tool_controller.gd` | Werkzeuge, Kosten, Vorschau, Bauen, Ausbau |
| `render/world_renderer.gd` | 16×16-Chunks als MultiMesh, Neubau mit Zeitbudget; Rotoren |
| `render/block_library.gd` / `block_batch.gd` | Meshes laden/normalisieren; Instanzen sammeln → MultiMesh |
| `render/building_generator.gd` / `structure_generator.gd` | Zonen-Gebäude bzw. Sonderbauten/Gleise/Masten aus Blöcken |
| `render/traffic.gd` / `trains.gd` | Autos+Busse / Züge (rein visuell) |
| `render/traffic_overlay.gd` | Ansichten (V) + Versorgungsansicht |
| `render/status_markers.gd` | Blitz-Marker (kein Strom) |
| `render/graphics_settings.gd` / `shader_warmup.gd` | Grafikstufen / Shader vorkompilieren |
| `ui/hud.gd` / `ui_theme.gd` / `icon_factory.gd` | HUD, Stil, aus Modellen gerenderte Icons |
| `audio/audio_manager.gd` | Autoload `Audio` |
| `dev/*` | Demo-Stadt, Tests, Profiler, Dev-Flags |

## Roadmap

- [x] v0.1 Terrain, Straßen, Zonen, Wachstum, Steuern, Terraforming
- [x] v0.2 Strom · v0.3 HUD/Icons/Verkehr · v0.4 Pendler, Speichern · v0.5 Audio
- [x] v0.6 Flächen ziehen, Standortregeln, Pixel-Texturen · v0.7 Bus & Bahn, Hauptstraßen
- [x] v0.8 Performance · v0.9 Dienste, Zufriedenheit, Kriminalität, Brände
- [ ] Wasserversorgung (Pumpen, Rohre)
- [ ] Budget-Fenster (Ressorts, Kredite, Jahresbilanz), Ticketeinnahmen ÖPNV
- [ ] Brände sichtbar machen (Rauch/Flammen), Feuerwehr-Einsätze
- [ ] Bewohner/Tiere aus dem Kit (Characters/Animals) als Leben in der Stadt
- [ ] Performance: Pendler-Berechnung in Thread, Sichtweite für Kleinkram, Terrain/Gebäude getrennt rendern
- [ ] Glattere Hauptstraßen-Rundung (echtes Mesh statt Streifen)
