# Cube City

SimCity-artiger Städtebau im Blockstil. Godot 4.7, GDScript, Assets: [Quaternius Cube World Kit](https://quaternius.com/packs/cubeworldkit.html) (CC0), Font: Silkscreen (OFL, `assets/fonts/`).

## Starten

- **Als Mac-App (empfohlen zum Spielen):** `build/Cube City.app` doppelklicken. Release-Build, ~35 % schnellere Simulation als im Editor. Spielstände sind dieselben wie im Editor.
  Neu bauen (Export-Vorlagen 4.7.2 müssen installiert sein, Profil `export_presets.cfg`, Universal, ad-hoc signiert):
  ```bash
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "macOS" "build/Cube City.app"
  ```
- **Ohne Editor aus dem Quellcode:** `/Applications/Godot.app/Contents/MacOS/Godot --path .`
- **Im Editor:** Projekt öffnen → F5.

Dev-Flags (nach `--`, funktionieren auch mit der App: `"build/Cube City.app/Contents/MacOS/Cube City" -- --demo`):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --demo --screenshot=shot.png
```

## Steuerung

| Eingabe | Aktion |
|---|---|
| WASD / Pfeile | Kamera verschieben |
| Leertaste + Linksklick ziehen, mittlere Maus, Linksklick im Info-Modus | Karte greifen & ziehen |
| Q / E, rechte Maus ziehen | Drehen / Neigen |
| Mausrad · Trackpad: Zwei Finger auseinander/zusammen · + / - (oder Bild auf/ab) · Cmd + Zwei-Finger-Wischen | Zoom |
| Trackpad: Zwei-Finger-Wischen | Karte verschieben |
| 1 Info · 2 Straße · J Bushaltestelle · R Gleis · Z Bahnhof · 3 Stromleitung | Werkzeuge |
| 4/5/6 Wohnen/Gewerbe/Industrie · 7 Kohle · 8 Wind · 9 Baum · 0 Park · T/G Terrain · B Abriss | Werkzeuge |
| U Polizei · F Feuerwehr · L Schule · K Krankenhaus · N Bibliothek · X Kino · C Bürgerhaus · Y Theater · O Stadion | Dienste & Kultur (nochmal auf Gebäude klicken = Ausbau) |
| Toolbar-Button mit `^` | Gruppe: klicken wählt zuletzt genutztes Werkzeug und klappt die Auswahl auf |
| Linke Maus ziehen | Fläche (Zonen) / Linie in L-Form (Straße, Gleis, Leitung) |
| Shift + ziehen (Straße) | Straßenraster mit 6 Tiles tiefen Blöcken |
| P | Pause |
| Tab, Klick auf Brand-Anzeige | reihum zu laufenden Bränden springen (sonst zum Ort der letzten Warnung) |
| Klick auf Warnung mit `>` (rechts oder im Verlauf) | Kamera fährt zum Ort |
| Glocke (oben links, Zahl = ungelesen) | Verlauf der letzten 20 Warnungen |
| I | Info-Karte: kompakt ↔ alle Details (Gebäude · Dienst/Verkehr · Versorgung · Lage · Wachstum) |
| H | HUD aus-/einblenden (Werkzeugleiste bleibt) |
| F11 oder Ctrl+Cmd+F | Vollbild an/aus (Start im Vollbild, Einstellung wird gespeichert; auch im Menü) |
| V | Ansicht: Verkehr → Verschmutzung → Bodenwert → Kriminalität → Zufriedenheit → ÖPNV → Strom → aus |
| Ansicht-Button (oben, Balken-Symbol) | Liste aller Ansichten mit Kennzahlen (Stau, ÖPNV, Ø Verschmutzung/Bodenwert/Kriminalität, Arbeitslose); Button zeigt aktive Ansicht |
| Zufriedenheit (oben, Smiley) | Hover: größte Minuspunkte · Klick: Aufschlüsselung mit Tipps, was fehlt |
| Esc | Menü: Speichern / Laden / Neue Stadt |
| F5 / F9 | Schnellspeichern / Schnellladen |
| M | Alle Töne an/aus (Musik, Effekte, Umgebung; Lautstärken im Menü bleiben erhalten) |
| Strg/Cmd + Shift + G | Cheat: +$50.000 (zum Testen) |

## Oberfläche

- **Info-Karte** (Maus über Tile): kompakt = Titel, eine Kernzeile (Einwohner/Jobs, Auslastung, Pendler …) und **nur Probleme** in Rot (Verfall mit Grund, kein Strom, Brand, Überlastung). Mit **I** alle Details nach Abschnitten; die Wahl bleibt erhalten.
- **Warnungen** (Probleme mit Signalton: Brand ohne Löschzug, Strom, Kasse im Minus, Zufriedenheit sinkt, Bürgerwünsche) erscheinen als schmale Streifen **rechts** unter Steuer/Tempo, höchstens 2, ~7 s; gleiche Warnung wird gezählt („x2“). Alles landet im **Verlauf** (Glocke).
- **Infos** (Ansicht gewechselt, gespeichert, Bau nicht möglich …) erscheinen nur kurz und klein über der Werkzeugleiste, ohne Verlauf.
- **Brand-Anzeige** rechts unter Steuer/Tempo. **H** blendet alles außer der Werkzeugleiste aus.
- **Größe der Oberfläche** im Menü: 70 % · 85 % · 100 % · 115 % (gespeichert). Skaliert alle HUD-Elemente gleichmäßig.

## Regeln (Kurz)

- Zonen wachsen nur mit **Straße** (≤3 Tiles), **Strom** und **Nachfrage** (RCI-Balken). Info-Karte zeigt Blocker.
- Strom fließt durch Leitungen, Zonen und Sonderbauten — **nicht über Straßen**, dort Leitung drüberziehen.
- **Stromnetze sind getrennt:** alles Zusammenhängende ist ein Netz und bekommt nur die Leistung seiner eigenen Kraftwerke. Ein neues Kraftwerk ohne Verbindung hilft einem anderen Netz nicht.
- **Dienst- und Kulturbauten brauchen Strom** (Stufe 1: Bibliothek/Polizei/Feuerwehr 1 MW, Schule/Kino 2, Bürgerhaus 3, Krankenhaus/Theater 5, Stadion 12; Stufe 2 ×1,5, Stufe 3 ×2). Ohne Strom arbeiten sie nicht: keine Versorgung, Feuerwache rückt nicht aus („Feuerwache ohne Strom“), keine Veranstaltungen; Blitz-Symbol, Info-Karte „x Kein Strom“. Im Netz werden sie **bevorzugt** versorgt (vor Wohnen/Gewerbe/Industrie). Ein Dienstbau zwischen Straßen ohne angrenzende Zone braucht eine Stromleitung.
- Im Netz wird vom Kraftwerk aus Tile für Tile versorgt; reicht die Leistung nicht, fällt das **Leitungsende** zuerst aus (Blitz-Symbol, kein Wachstum, Verfall).
- Anzeige oben: Bedarf aller Gebäude (auch nicht angeschlossener) / Leistung aller Kraftwerke, **rot sobald irgendwo ein Gebäude ohne Strom ist**; Tooltip listet die Netze (Bedarf/Leistung/Kraftwerke/Engpass). Meldung mit Ort: „Kein Strom: … ohne Kraftwerk im Netz“ bzw. „Stromengpass im Netz bei x,z“. Info-Karte: Netz des Tiles. **Ansicht Strom** (V): jedes Netz in eigener Farbe, Gebäude ohne Strom rot, Kraftwerke weiß. Test `--powertest`, `--powerreport` (Dienste ohne Strom eines Spielstands), `--determinism` (Prüfsummen nach 12 Monaten mit festem Zufall).
- Kohlekraftwerk senkt Bodenwert von Wohngebieten in der Nähe.
- **Pendler**: 55 % der Einwohner fahren monatlich zum nächsten freien Job (Dijkstra, Stau verteuert Wege).
  Wohnen braucht erreichbare Jobs (auch per Bahn), Gewerbe/Industrie erreichbare Einwohner. Fahrzeit > 40 blockiert Wohnwachstum.
- **Stau** senkt Bodenwert und bremst Autos sichtbar.
- **Sichtbarer Verkehr** folgt der Simulation: 1 Auto je 11 Auto-Pendler (Bus-/Bahnfahrer fahren nicht Auto), Autos erscheinen fast nur auf Straßen mit Pendlern (reine Bahn-Vorstädte bleiben ruhig), 1 Bus je 120 Fahrgäste/Monat. Jedes Auto fährt 8–30 Tiles und taucht dann neu nach Pendler-Gewicht auf (sonst sammeln sich Zufallsfahrer in Nebenecken wie Serpentinen). Tests `--cartest`, `--cardrift=Sek` (nach 20 s: 22 % der Autos auf den Top-10-%-Straßen bei 28 % Verkehrsanteil; vorher 11 %).
- **Bahnhofs-Kapazität**: 1.500 Ein-/Aussteiger je Bahnhof und Monat. Darüber wird der Weg über diesen Bahnhof teurer (Aufschlag 3 × Auslastung²), ab 150 % ist er für den Monat dicht → Pendler weichen auf andere Bahnhöfe, Bus oder Auto aus. Info-Karte des Bahnhofs zeigt die Auslastung („überfüllt!“). Mehr Bahnhöfe = mehr Kapazität.
- **Reichweite beim Bauen:** Mit Haltestelle oder Bahnhof in der Hand zeigt die Karte automatisch die ÖPNV-Ansicht, dazu unter dem Cursor die Reichweite: **blau** die Straßen, die ins Busnetz kommen bzw. im Fußweg zum Bahnhof liegen (inkl. ganzem Busnetz, wenn eine Haltestelle nahe dem Bahnhof steht), **hellgrün** Gebäude, die dadurch neu Anschluss bekommen. Dienst-/Kulturbauten zeigen den **Rand ihres Einzugskreises** (weiß), beim Ausbau den Radius der nächsten Stufe. Test `--rangetest`.
- **Ansicht ÖPNV** (V bzw. Ansicht-Liste): Straßen im Busnetz blau, Gebäude mit Bus-/Bahnanschluss grün, ohne rot; Liste zeigt Anteil, Bus-/Bahnfahrer und Anteil Wohnungen mit Anschluss.
- **Alte 64×64-Spielstände** werden beim Laden mittig in eine neu erzeugte 128er-Landschaft gesetzt (Ränder über 8 Tiles in der Höhe angeglichen); gespeichert wird dann als 128er-Stand, die alte Version bleibt als Sicherung.
- **Spielstände + Einstellungen** liegen im eigenen Datenordner des Spiels (gleich für Editor und Mac-App, kein Godot nötig):
  macOS `~/Library/Application Support/Cube City/` · Windows `%APPDATA%\Cube City\` · Linux `~/.local/share/Cube City/`,
  darin `saves/*.citysave` (Schnellspeicher F5/F9 + Slot 1–3) und `settings.cfg`. Menü: **„Spielstand-Ordner öffnen“**.
  Ältere Versionen speicherten unter `…/Godot/app_userdata/Cube City/`; beim ersten Start wird von dort einmalig kopiert (der alte Ordner bleibt).
- **Überschreiben-Schutz:** Speichern im Menü auf einen belegten Platz fragt nach („… überschreiben? Datum · Einw. · Kasse“). Zusätzlich wird vor **jedem** Überschreiben (auch F5) die alte Version als Sicherung behalten: je Platz die letzten 3 (`<platz>.bak1..3.citysave`), im Menü unter „Sicherungen“ ladbar. Test `--savetest` (eigener Testordner).

## Entwicklung & Tests

**VS Code:** Erweiterung *godot-tools*; `.vscode/settings.json` zeigt auf `/Applications/Godot.app/Contents/MacOS/Godot` und startet den Sprachserver headless (`godotTools.lsp.headless`) → Gehe-zu-Definition/Autovervollständigung auch ohne offenen Godot-Editor. Läuft der Editor parallel, nutzt die Erweiterung dessen Server.

**`.import`-Dateien** neben den Assets sind Godots Import-Einstellungen je Datei und gehören ins Repo; die importierten Daten selbst liegen in `.godot/` (ignoriert).

Dev-Werkzeuge liegen getrennt vom Spielcode in `scripts/dev/` und laufen nur mit Flags (nach `--`):

- `dev_tools.gd` — wertet Flags aus: `--demo`, `--cam=x,z,dist`, `--ignite=x,z[,sek]` (Gebäude anzünden, Brand vorspulen, Kamera hin), `--ruin=x,z` (sofort abbrennen), `--overlay[=1..5]`, `--popup=view|happy`, `--menu`, `--flyout`, `--screenshot=pfad`, `--quit`
- `demo_city.gd` — reproduzierbare Teststadt (Zonen, Strom, ÖPNV, 4-spurige Straße mit Verjüngung)
- `dev_tests.gd` — `--selftest` (Timing, Speichern/Laden, Audio), `--dragtest` (echtes Maus-Ziehen), `--lanetest` (Rechtsverkehr auf Hauptstraßen), `--widetest` (Hauptstraßen-Erkennung), `--profile[=Sek,Tempo]` (Frame-Zeiten + Ruckler-Ursachen), `--gfx=0..2`, `--nowarmup`, `--servicetest`, `--tool=<name>`, `--traffictest` (Korridor: Straße/Parallelstraße/Hauptstraße/Bus/Bahn), `--pickcheck`, `--firetest` (Brand an der Wache gelöscht, ohne Wache abgebrannt + Ruine), `--bustest` (Vorstadt mit eigenem Straßennetz bekommt Busse), `--happytest` (Aufschlüsselung, Warnung bei Steuer hoch / Polizei weg), `--cheattest` (Geld-Cheat per Tastenereignis), `--greentest` (Grüngürtel gegen Verschmutzung, Terraforming reißt Straße ab), `--venuetest` (Stadion/Theater: Besucherverkehr, Kundschaft), `--zonetest` (Ladenzeile, Ballung, Nachbarschaft), `--taxtest` (Steuern je Zone, ÖPNV-Tarif), `--cartest` (Autos/Busse je Tarif, Diagnose ÖPNV, Bahnhofs-Auslastung), `--cardrift=Sek`, `--jamreport` (meistbelastete Straßen), `--loadfile=pfad` (Spielstand-Kopie laden), `--focus=x,z` (Kamera auf Tile), `--fronttest`, `--hover=x,z [--detail]`, `--notify`, `--hidehud`, `--fpstest`, `--mutetest`, `--savetest`, `--uiscale=f`, `--zoomtest`, `--rangetest`, `--appicon=pfad.png` (App-Icon rendern), `--splash` (+ `--screenshot`, Startbild), `--menu --asksave=slot`, `--gpumeasure=Sek,fps [--pause]`, `--popup=view|happy|log`, `--loadreport` (Auslastung der Dienste + Brände in 12 Monaten), `--powertest`, `--bigcity` (ganze Karte bebauen), `--buildtest` (Bau-Klick-Zeit, Pendler synchron/Hintergrund)

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --demo --selftest --dragtest --traffictest --quit
```

## Dienste, Zufriedenheit, Kriminalität

| Dienst | erwartet ab | Wirkung |
|---|---|---|
| Polizei | 300 Einw. | senkt Kriminalität (bis 85 %) |
| Feuerwehr | 300 Einw. | Brandschutz + Löschzüge (siehe *Brände*) |
| Schule | 600 Einw. | Zufriedenheit + Fachkräfte (Gewerbe/Industrie wachsen schneller) |
| Krankenhaus (2x2) | 600 Einw. | Zufriedenheit |
| Bibliothek / Kino | 1.500 Einw. (baubar ab 1.000) | Kultur |
| Bürgerhaus (2x2) | 1.500 Einw. (baubar ab 2.000) | Kultur, groß |
| Theater (2x2) | 4.000 Einw. (baubar ab 3.000) | Großkultur; jeden Monat Vorstellung, 300 Besucher je Stufe |
| Stadion (3x3) | 4.000 Einw. (baubar ab 5.000) | Großkultur; Spieltag alle 3 Monate, 900 Besucher je Stufe |

**Unterhalt** (je Monat, Stufe 2/3: ×2,2/×3,8): Polizei/Feuerwehr 10, Schule 13, Krankenhaus 20, Bibliothek 7, Kino 6, Bürgerhaus 18, Theater 35, Stadion 60.

**Großkultur (Theater/Stadion)**: Besucher kaufen im Umkreis von 5 Tiles ein (+50 % der Besucher als Kundschaft fürs Gewerbe) und erhöhen die Gewerbe-Nachfrage. Am Veranstaltungstag fahren die Besucher über die Straßen im Umkreis von 3 Tiles (Besucher × 2,5 Pendler-Äquivalente, verteilt) → Stau; Bushaltestelle/Bahnhof in 4 Tiles nimmt 40 % auf. Info-Karte zeigt Besucher, „heute!“ und die Auslastung rundum; verstopft ein Event die Straßen, kommt (max. 1×/Jahr) eine Meldung. Test: `--venuetest`, Screenshot-Flag `--venues`.

- **Ausrichtung:** Dienst- und Kulturbauten drehen ihre Front (Eingang, Schild, Säulen) automatisch zur Seite mit den meisten angrenzenden Straßen (Test `--fronttest`).
- **Ausbaustufen 1–3**: gleiches Werkzeug auf das Gebäude → Reichweite 6/9/12 Tiles, Kapazität 800/2.000/4.500 Einwohner, mehr Etagen. Überlastete Gebäude wirken schwächer. Decken mehrere Gebäude derselben Art ein Gebiet ab, **teilen sie sich dessen Einwohner** (Auslastung je Gebäude = Anteil). Beispiel Nutzerstadt (17.600 Einw., 17 Feuerwachen): vorher je Wache 100–200 % (jede zählte alle), jetzt 19–70 %, Versorgung 69 → 85 % (`--loadreport`).
- **Zufriedenheit** je Wohnhaus: Bodenwert + versorgt (+) / unversorgt (−, sobald die Stadtgröße den Dienst verlangt) − Kriminalität − Wohnsteuer ± ÖPNV-Tarif. **Unter 30 % ziehen Leute weg** → weniger Kunden/Arbeitskräfte → Gewerbe und Industrie schrumpfen. Zufriedene Städte locken Zuzug an.
- **Aufschlüsselung** (Klick auf Zufriedenheit): Grundwert 55 + Bodenwert + Parks + je Dienst (versorgt +, unversorgt −) − Kriminalität − Steuern, schlechteste zuerst mit Tipp („Krankenhaus erreicht nur 33 % – mehr bauen oder ausbauen“, „Steuern senken“ …). Einwohnergewichteter Schnitt der Wohnhäuser.
- **Warnung**: sinkt die Zufriedenheit in 3 Monaten um ≥ 8 Punkte (oder in 1 Monat um ≥ 5), kommt eine Meldung mit dem Teil, der am stärksten gefallen ist, z.B. „Zufriedenheit sinkt: 60 % → 40 % – Grund: Polizei (−14)“. Danach 6 Monate Pause. Test `--happytest`.
- **Kriminalität** aus Dichte, niedrigem Bodenwert und Arbeitslosigkeit; Polizei senkt sie; schadet Zufriedenheit und Gewerbe.
- Mit einem Dienst-Werkzeug in der Hand zeigt die Karte dessen **Versorgung** (grün/gelb/rot). Die Info-Karte eines Hauses nennt fehlende Dienste.
- Test (`--servicetest`, Demo-Stadt, Dienste entfernt bzw. neu gebaut, 36 Monate): ohne Dienste 770 → 490 Einw., Zufriedenheit 34 %, 3 Ausbrüche / 8 abgebrannt (inkl. Ausbreitung); mit Diensten 760 Einw., 59 %, 0 Ausbrüche.

### Brände

- **Ausbruch** (monatlich je Gebäude): 0,2 % × (1 − Brandschutz)². Wohnen/Gewerbe erst ab 200 Einw. in der Stadt; volle Abdeckung ⇒ dort praktisch keine Brände.
- **Industrie brennt immer**: ×3 Risiko, unabhängig von der Einwohnerzahl und mit Restrisiko 25 % auch bei vollem Brandschutz — die Feuerwehr hat dort also zu tun und löscht. Test: 30 Industriegebäude ohne Einwohner, Wache daneben → in 10 Jahren 5 Brände, 4 gelöscht.
- **Brandschutz** = Versorgung der Feuerwache (100 % nah, 60 % am Rand der Reichweite). Auslastung der Wache = Einwohner + **halbe Arbeitsplätze** im Einzugsgebiet; Überlastung schwächt den Schutz.
- **Verlauf**: Ein Brand dauert ~10 s (Tempo 1, schneller bei höherem Tempo) bis zum Abbrennen. Sichtbar durch Flammen + Rauchsäule; Oben eine Brand-Anzeige (Tab/Klick springt hin). **Meldung + Signalton nur bei Problemen**: keine Wache in Reichweite, alle Löschzüge im Einsatz, keine Zufahrt, Feuer greift über, abgebrannt. Routine-Brände (Löschzug rückt aus) und gelöschte Brände bleiben still.
- **Löschzug**: Die nächste Wache, in deren Reichweite der Brand liegt, schickt einen Zug über die Straßen (Wache braucht Straßenanschluss). Je Ausbaustufe 1/2/3 Züge. Vor Ort stoppt der Brand, Löschen dauert 2,5 s. Erst nach 60 % Brandfortschritt gelöscht ⇒ Gebäude verliert 1 Stufe.
- **Ohne Löschzug** (keine Wache in Reichweite / alle im Einsatz / keine Zufahrt): Gebäude brennt ab. Bei halbem Brand greift das Feuer auf Nachbarn über: 25 % × (1 − Schutz)² je Nachbar.
- **Brandruine**: 6 Monate verkohlte Reste mit Rauch, dort wächst nichts (Info-Karte: Restmonate). Abriss/Umzonen räumt sie.
- **Info-Karte** eines Gebäudes: „Brandschutz 66 % – Rand der Reichweite / Feuerwache überlastet / keine Feuerwache“; bei Brand Fortschritt und Status des Löschzugs.
- Werte: `config.gd` (Abschnitt *Brände*). Test: `--firetest` (Wache nah: gelöscht nach 2,9 s; ohne Wache: abgebrannt nach 10 s, Ruine).

## Zonen richtig planen

Beim Aufziehen färbt die Vorschau jedes Tile nach **Eignung** (grün/gelb/rot).

| | Ideal | Vermeiden |
|---|---|---|
| **Blockgröße** | 6 Tiles tief zwischen zwei parallelen Straßen (je 3 Tiles Reichweite) – Shift+Ziehen baut so ein Raster | Tiles > 3 von der Straße wachsen nie |
| **Wohnen** = Nachbarschaft | Blöcke ~6×8 bis 6×12 mit Laden (+5 % Bodenwert, wenn Gewerbe in 4 Tiles) oder Park dazwischen. Bodenwert hoch: Wasser, Parks, Höhenlage, wenig Verschmutzung. Stufe 2 ab 35 %, Wohnblock (Stufe 3) ab 55 % | Eintönige Großsiedlung: kein Laden/Park/Wasser in 6 Tiles = −8 % Bodenwert. < 5 Tiles zu Industrie, < 8 zum Kohlekraftwerk, Staustraßen |
| **Gewerbe** = Ladenzeile | 1–2 Tiles tiefe Streifen an belebter Straße (Hauptstraße/Haltestelle/Bahnhof: Wachstum ×1,3), viele Einwohner in 6 Tiles. **Tiefe:** Reihe 1–2 bis Stufe 3 (Reihe 2 wächst ×0,8), Reihe 3 bis Stufe 2 (×0,6). **Länge:** Weg entlang der Straße bis zur nächsten Kreuzung/Ecke/Straßenende ≤ 4 → Stufe 3, ≤ 6 → Stufe 2, darüber 1 ⇒ etwa alle 8–10 Tiles eine Querstraße. 3×3-Block mit Straßen rundum wird komplett Stufe 3 | Lange Gewerbestreifen ohne Querstraße, tiefe Blöcke, abgelegen |
| **Industrie** = Ballung | Kompakte Flächen, am Rand, Abstand zu Wohnen. Industrie-Zonen im 5×5 ringsum: ab 3 → Stufe 2, ab 8 → Stufe 3 (2×2 → Stufe 2, 3×3 → komplett Stufe 3); Wachstum 0,6 + 0,04 je Nachbar (max ×1,6) | Einzelne Tiles und Paare (bleiben Stufe 1, wachsen langsam); direkt neben Wohnen |
| **Villa** | Wohnen mit Bodenwert ≥ 75 % in einer **Kleinsiedlung** (≤ 8 Wohn-Tiles im 5×5 ringsum): Stufe 3 wird statt Wohnblock eine Villa (Bungalow mit Pool), 16 Einwohner, **Bodenabgabe $6/Monat**, wenig Last für Dienste/Verkehr. Info-Karte zeigt „Villenlage“. Sinkt der Bodenwert unter 70 % oder wird die Siedlung zu dicht, verfällt sie (5 %/Monat) zum Einfamilienhaus | Große Siedlungen (dort entstehen Wohnblöcke) |

Werte und Reichweiten: `scripts/config.gd` (Abschnitte *Standortregeln*, *Zonen-Idealformen*). Die Info-Karte zeigt je Tile Ladenzeile/Ballung/Nachbarschaft, die Vorschau berücksichtigt sie. Test: `--zonetest` (u.a. 10×2 Gewerbe mit Querstraßen an den Enden: Stufen 3333223333; 16×1 ohne Querstraße: 3332211111122333). Screenshot-Flag `--villas`.

**Verfall sichtbar:** Ein Gebäude, das absinken wird (Bodenwert/Lage reicht nicht mehr für die Stufe, unzufrieden, ohne Strom/Straße/Erreichbarkeit, keine Nachfrage, Villenlage verloren), sieht schon vorher abgenutzt aus: verwitterte Blöcke, kaputte Fenster, Ranken an den Wänden, Geröll. Die Info-Karte nennt den Grund („x Verfällt: Bodenwert 39 % zu niedrig für Stufe 3“). Abstieg dann mit 4–8 % Chance je Monat. Test `--decaytest`, Screenshot-Flag `--worn`.

### Steuern & ÖPNV-Tarif

| Steuer (Regler W/G/I oben rechts) | neutral | Wirkung je Punkt über neutral |
|---|---|---|
| Wohnen | 9 % | Nachfrage −0,05 und Zufriedenheit −2 (empfindlich) |
| Gewerbe | 9 % | Gewerbe-Nachfrage −0,04 |
| Industrie | 12 % | Industrie-Nachfrage −0,025 (robust, „dreckig, nimmt es hin“) |

- Einnahmen/Monat = Einwohner × 0,12 × Wohnsteuer × 12 + Gewerbejobs × 0,1 × Gewerbesteuer × 12 + Industriejobs × 0,1 × Industriesteuer × 12 + ÖPNV-Tarif + Bodenabgabe der Villen. Tooltip auf „+x / Monat“ zeigt die Aufteilung.
- **ÖPNV-Tarif** (Button unter den Steuern): **kostenlos** – keine Einnahmen, Einstieg in die Bahn wirkt günstiger, Busanteil 55 %, +5 Zufriedenheit für Wohnhäuser mit Bus-/Bahnanschluss · **normal** – $0,10 je Fahrgast, Busanteil 40 % · **teuer** – $0,20, Busanteil 25 %, −3 Zufriedenheit.
- Demo-Stadt (`--taxtest`): neutral $193/Monat; Industrie 16 % → +$15, Nachfrage I −0,10; Wohnen 13 % → +$48, aber Zufriedenheit −8, Wohnnachfrage −0,27. Tarif kostenlos/normal/teuer: 244/178/110 Fahrgäste, $0/18/22, Zufriedenheit 65/60/57 %.

### Bäume & Parks

| | Verschmutzung | Bodenwert | Zufriedenheit | Unterhalt |
|---|---|---|---|---|
| **Baum** ($5) | −5 % je Baum im Umkreis 2 Tiles | – | – | – |
| **Park** ($80) | −8 % je Park im Umkreis 2 Tiles | +8 % je Park in 3 Tiles (max +24 %) | +3 je Park in 3 Tiles (max +9) | $3/Monat |

- Filter zusammen höchstens 70 %. Ein 2 Tiles breiter **Grüngürtel** zwischen Industrie und Wohnen halbiert (Bäume) bzw. drittelt (Parks) die Verschmutzung am Wohnhaus (`--greentest`). Info-Karte: „Verschmutzung 0.3 (Grün filtert 50 %)“.
- **Terrain anheben/absenken** reißt Straßen, Gleise (samt Haltestelle/Bahnhof), Parks und Gebäude auf dem Tile ab (+$2 Abriss); Bäume bleiben.

## Rohstoffe (Bergbau-Wirtschaft, Stufe 1: Abbau + Lager)

| Rohstoff | Vorkommen | Gebäude (Werkzeuggruppe Rohstoffe) | Förderung je Monat (× Ausbaustufe) |
|---|---|---|---|
| Holz | Wald | **Holzfäller** (1×1): fällt Bäume im Umkreis 4 | 2 Bäume = 20 Holz |
| Stein | **Fels**: graue Steinflächen im Hochland (ab 6 Blöcken über Wasser) und an steilen Hängen | **Steinbruch** (2×2), Umkreis 2 | 20 |
| Sand / Ton | Strände an der Wasserkante / feuchte Niederungen | **Grube** (1×1), Umkreis 2 | je 10 |
| Kohle / Eisen / Gold | Erzadern im Hügelland (Kohle ab 2, Eisen ab 4, Gold ab 5 Blöcken über Wasser, Gold selten) | **Mine** (2×2), Umkreis 3 | 15 / 10 / 3 |
| – | – | **Lagerhaus** (2×2) | +1.000 Lagerplatz je Rohstoff und Stufe |

- Alle Abbau-Gebäude brauchen **Strom** (1–4 MW) und kosten Unterhalt. Ohne Wald/Vorkommen in Reichweite stehen sie still (Info-Karte nennt den Grund).
- **Lager**: 200 je Rohstoff, + Lagerhäuser. Was nicht passt, wird **automatisch exportiert** (Holz 1, Stein/Sand 0,5, Ton 0,8, Kohle 1,5, Eisen 3, Gold 12 $ je Einheit) → Einnahme „Rohstoff-Export“.
- **Endlich, aber langlebig**: je Vorkommen-Tile 1.200–2.550 Einheiten. Typische Karte 128×128: ~950.000 Stein (≈ 500 Fels-Tiles), ~200.000 Kohle, ~100.000 Eisen, ~30.000–55.000 Gold, Sand/Ton praktisch unerschöpflich. Eine Mine an einer Ader hält bei Stufe 3 rund 40–50 Spieljahre. Holz wächst (noch) nicht nach.
- Sichtbar: Fels, Sand und Ton färben den Boden, Erzbrocken ragen aus dem Gras; **Ansicht Rohstoffe** (V) färbt alle Vorkommen (kräftig = voll, grau = erschöpft), die Ansicht-Liste zeigt die Restmengen. Mit einem Abbau-Werkzeug zeigt die Vorschau Vorkommen im Umkreis. HUD: Lager-Leiste (Tooltip: Förderung, Kapazität, Export).
- Werkzeuge haben keine Taste (alle Buchstaben belegt) – nur über die Werkzeugleiste. Tests `--restest`, `--orecount`, Screenshot-Flag `--resbuild`.

## Verkehr

- Pendler werden in 3 Etappen verteilt; jede Etappe sieht den Stau der vorherigen → **Parallelstraßen und Umfahrungen werden genutzt**.
- Kapazität pro Tile: Straße 300 Pendler/Monat.
- **Hauptstraße entsteht automatisch**: zwei parallele Straßen direkt nebeneinander verschmelzen zur 4-spurigen Straße. Fahrtrichtung = Achse, entlang der der Straßenzug länger ist; breitere Flächen werden von der Kante aus zu Paaren (4 Reihen = 2 Hauptstraßen), Querstraßen bleiben Kreuzungen (weiße Spurlinien, gelbe Doppel-Mittellinie), 450 je Tile (Paar 900 statt 600), Autos 35 % schneller. Richtungsgetrennt: jede Fahrtrichtung nutzt ihre Hälfte (Rechtsverkehr) mit 2 Spuren, Busse außen. Endet eine Hälfte, läuft sie in einem Viertelbogen in die weiterführende Spur aus.
- Grundstücke nutzen alle Straßen in 3 Tiles Reichweite → zusätzliche Straßen nehmen Last ab.
- Stau-Anzeige = Stau, den Pendler im Schnitt erleben. Über 100 % = mehr Pendler als Kapazität.

### Bus & Bahn

| | Wirkung | Kosten / Unterhalt |
|---|---|---|
| **Bushaltestelle** (auf Straße) | Liegen Start *und* Ziel im Umkreis von 3 Tiles einer Haltestelle, fahren 40 % Bus. Ein Busfahrer = 10 % Straßenlast. **Zubringer:** Haltestelle ≤ 4 Tiles vom Bahnhof bindet das ganze zusammenhängende Haltestellen-Netz an die Bahn an. Busse fahren je zusammenhängendem Straßennetz ab 2 Haltestellen (1 Bus je 2 Haltestellen + mehr bei vielen Fahrgästen) — eine nur per Bahn angebundene Vorstadt bekommt eigene Busse. Grundstücke mit Bus-/Bahnanschluss: +8 % Bodenwert. | $150 / $4 |
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

- **Simulationsmonat auf 11 Frames verteilt** (Straßen → Strom → Pendler → Umwelt ½ → Umwelt ½ → Zählen → Dienste → Wachstum ½ → Wachstum ½ → Strom → Abschluss); Umwelt und Wachstum zeilenweise halbiert.
- **Heiße Schleifen** (Straßenabstand, Kreuzungen, Strom, Hauptstraßen-Erkennung, Zählung, Verkehrs-Neuaufbau, Blitz-Marker) rechnen mit lokalen Arrays statt Funktionsaufrufen je Tile. `--determinism` (12 Monate mit festem Zufall) prüft, dass Optimierungen das Ergebnis nicht verändern.
- Messung **128×128 mit Megacity** (17.600 Einw.): Ruckler > 25 ms im laufenden Spiel 74 → 5, schwerste Etappe ~20 ms; Bau-Klick 66 → 28 ms; Pendler 1,9 s im Hintergrund; ganz herausgezoomt weiter ~117 Bilder/s.
- **Pendler im Hintergrund-Thread:** die teuerste Berechnung (Dijkstra je Wohnstraße, 3 Etappen) läuft auf einer Kartenkopie; das Ergebnis wird übernommen, sobald es fertig ist. Bau-Klicks und Monate frieren nicht mehr ein. Die Suche arbeitet ohne Allokationen (vorberechnete Nachbarn, Heap in Packed-Arrays) und bricht ab, wenn keine Jobs mehr frei sind.
- **Bau-Klick gestaffelt:** Straßen/Strom sofort, Umwelt und Dienste in den 2 folgenden Frames.
- Messung Riesenstadt (`--demo --bigcity --buildtest`, ganze Karte bebaut, 43.000 Einw.): Pendler vorher 4,4 s je Bau-Klick und Monat → jetzt 0,86 s im Hintergrund (App: 0,55 s); Bau-Klick 31 ms (App: 20 ms); `--profile=15,3` App: Ø 8,6 ms, kein Ruckler > 25 ms.
- **Wachstum ≠ Netzänderung:** Gebäudestufen lösen keine Karten-Scans (Autos, Züge, Hauptstraßen) aus.
- **Chunk-Neubau** mit Zeitbudget (4 ms/Frame), MultiMesh-Daten als ein Block statt je Instanz.
- **Shader-Aufwärmen** beim Start: jedes Material einmal rendern → kein Kompilier-Ruckler, wenn später z.B. der erste Bus erscheint.
- **Grafik** im Menü: Hoch (Schatten 4096, SSAO, MSAA 2x) · Mittel (Schatten 2048, FXAA) · Niedrig (ohne Schatten, 75 % Auflösung mit FSR) · VSync.
- **Stromsparen / Bilder pro Sekunde** (Menü): 30 · **60 (Standard)** · Unbegrenzt. Ohne Grenze zeichnet das Spiel so oft wie der Bildschirm kann (MacBook 120 Hz) – gemessen ~45 % statt ~21 % CPU-Last eines Kerns. Zusätzlich automatisch: **Fenster im Hintergrund 10 Bilder/s** (Simulation läuft weiter), **Pause mit ruhender Kamera 30 Bilder/s**. Bei 60 auf 120-Hz-Bildschirmen kann vereinzelt ein Frame 25–33 ms dauern (Taktversatz); wer maximale Glätte will: Unbegrenzt. Test `--fpstest`.
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

1 Tile = 3×3 Blöcke (1 Block = 1 Welteinheit), Höhe in Blockschritten, Karte 128×128 Tiles (bis Okt. 2026: 64×64). Alle Spielwerte in `scripts/config.gd`.

| Datei | Aufgabe |
|---|---|
| `main.gd` | Einstieg: baut Welt, Simulation, Kamera, Werkzeuge, HUD; Speichern/Laden; Umgebung/Licht |
| `config.gd` | alle Konstanten (Kosten, Kapazitäten, Reichweiten, Standortregeln, Dienste) |
| `core/user_data.gd` | Autoload `UserData`: eigener Datenordner, Umzug aus altem Godot-Ordner, „Spielstand-Ordner öffnen“ |
| `city/city_map.gd` | Kartendaten als Packed-Arrays + Signale `tiles_changed` / `infra_changed`, Hauptstraßen-Erkennung |
| `city/simulation.gd` | Monat in 5 Etappen: Netz/Strom → Pendler → Umwelt → Dienste → Wachstum/Brände/Budget |
| `city/fire_dept.gd` | Brände in Echtzeit: Fortschritt, Löschzug-Alarmierung (BFS über Straßen), Löschen, Ausbreitung, Meldungen mit Ort |
| `city/save_manager.gd` | Spielstände (Meta + Daten, ZSTD) |
| `tools/tool_controller.gd` | Werkzeuge, Kosten, Vorschau, Bauen, Ausbau |
| `render/world_renderer.gd` | 16×16-Chunks als MultiMesh, Neubau mit Zeitbudget; Rotoren |
| `render/block_library.gd` / `block_batch.gd` | Meshes laden/normalisieren; Instanzen sammeln → MultiMesh |
| `render/building_generator.gd` / `structure_generator.gd` | Zonen-Gebäude bzw. Sonderbauten/Gleise/Masten aus Blöcken |
| `render/traffic.gd` / `trains.gd` | Autos+Busse / Züge (rein visuell) |
| `render/map_overlay.gd` | Karten-Ansichten (V: Verkehr, Verschmutzung, Bodenwert, Kriminalität, Zufriedenheit, ÖPNV, Strom) + Versorgungsansicht der Dienste |
| `render/status_markers.gd` | Blitz-Marker (kein Strom) |
| `render/fire_fx.gd` | Flammen, Rauch, Wasserstrahl, Löschzüge mit Blaulicht, Rauch über Ruinen |
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
- [x] Steuern je Zone (W/G/I), ÖPNV-Tarif, Zonen-Idealformen (Ladenzeile, Ballung, Nachbarschaft)
- [x] Rohstoffe Schritt 1–2: Karte 128×128, Vorkommen, Abbau-Gebäude, Lager, Export
- [ ] Rohstoffe Schritt 3: Verarbeitung (Holz → Bretter, Sand → Glas, Ton → Ziegel, Erz → Barren), Materialbedarf beim Wachsen — dabei verbraucht das Kohlekraftwerk Kohle aus dem Lager (bisher läuft es ohne)
- [ ] **Erneuerbare Energien** (Kohle ist endlich, Unabhängigkeit vom Handel): Windrad gibt es schon; dazu Solarfeld (Leistung nach Tageszeit), Wasserkraft (Damm an Fluss/See), Biomasse (verbrennt nachwachsendes Holz), Geothermie (mit der Untertage-Ebene). Schwankende Leistung → Speicher (Batterie, Pumpspeicher). Teils über Forschung freigeschaltet
- [ ] Rohstoffe Schritt 4: Erneuerung (Aufforstung/Baumschule, Prospektion, Recycling)
- [ ] **Forschung & Technik** (Nutzerwunsch, statt nur Handel): Upgrades wie Tiefbau (neue/tiefere Vorkommen), effizientere Verarbeitung (weniger Material je Gebäude), Recycling, Ersatzstoffe
- [ ] Untertage-Ebene, Tunnel zu Nachbarstädten, Handel mit fiktiven Bürgermeistern
- [ ] Budget-Fenster (Ressorts, Kredite, Jahresbilanz)
- [x] Brände sichtbar (Flammen/Rauch/Ruinen), Feuerwehr-Einsätze mit Löschzügen, Meldungen mit Kamera-Sprung
- [ ] Brand-Geräusche (Sirene, Knistern), evtl. Brandschutz-Ansicht (V)
- [ ] Bewohner/Tiere aus dem Kit (Characters/Animals) als Leben in der Stadt
- [ ] Performance: Pendler-Berechnung in Thread, Sichtweite für Kleinkram, Terrain/Gebäude getrennt rendern
- [ ] Glattere Hauptstraßen-Rundung (echtes Mesh statt Streifen)
