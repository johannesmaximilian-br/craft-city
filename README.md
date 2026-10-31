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

**Spiel beenden:** Menü → „Beenden“, Fenster schließen oder Cmd+Q öffnen dieselbe Abfrage (Spiel pausiert): „Speichern (zuletzt benutzter Platz, sonst Schnellspeicher) und beenden“ · „Ohne Speichern beenden“ · „Abbrechen“. Vorher beendete das Schließen-Kreuz das Spiel sofort ohne Nachfrage.

**Popover-Gestaltung (23.10.):** Ansicht, Zufriedenheit, Meldungen, Forschung und Info-Karte nutzen einheitliche Bausteine (`scripts/ui/pop_ui.gd`): Kopf mit Icon/Titel/Kennzahl, Abschnitte mit farbiger Überschrift + Linie, Zeilen „Bezeichnung | Wert“ (Wert fett/farbig), Balken (Zufriedenheit um eine Mitte: rot links/grün rechts), Plaketten (ERFORSCHT/LÄUFT/BEREIT/GESPERRT), roter Problemkasten, Listeneinträge (Ansicht: ganze Zeile klickbar, aktiv grün). Feste Breite 440 px mit Umbruch, höher als der Bildschirm → scrollen. Die Info-Karte zerlegt ihre Textzeilen automatisch an „·“ und „:“ bzw. der ersten Zahl in Bezeichnung/Wert.

- **Info-Karte** (Maus über Tile): kompakt = Titel, eine Kernzeile (Einwohner/Jobs, Auslastung, Pendler …) und **nur Probleme** in Rot (Verfall mit Grund, kein Strom, Brand, Überlastung). Mit **I** alle Details nach Abschnitten; die Wahl bleibt erhalten.
- **Warnungen** (Probleme mit Signalton: Brand ohne Löschzug, Strom, Kasse im Minus, Zufriedenheit sinkt, Bürgerwünsche) erscheinen als schmale Streifen **rechts** unter Steuer/Tempo, höchstens 2, ~7 s; gleiche Warnung wird gezählt („x2“). Alles landet im **Verlauf** (Glocke).
- **Infos** (Ansicht gewechselt, gespeichert, Bau nicht möglich …) erscheinen nur kurz und klein über der Werkzeugleiste, ohne Verlauf.
- **Brand-Anzeige** rechts unter Steuer/Tempo. **H** blendet alles außer der Werkzeugleiste aus.
- **Größe der Oberfläche** im Menü: 70 % · 85 % · 100 % · 115 % (gespeichert). Skaliert alle HUD-Elemente gleichmäßig.

## Spielmodi

Es gibt nur noch einen Spielmodus, den **Aufbau-Start** (Spielstart bzw. Menü → **„Neue Stadt“**). Den früheren
„klassischen“ Modus (20.000 $, alles nach Einwohnerzahl) gibt es seit 31.10. nicht mehr (Nutzerentscheidung).

- **Alte Spielstände** werden beim Laden umgerechnet (die Datei bleibt, beim nächsten Speichern neues Format): Rathaus-Stufe
  aus Einwohnern (Stufen-Schwellen, Material wird erlassen), mindestens so hoch, dass nichts Gebautes gesperrt ist (Forschung
  begonnen ⇒ Stufe 5); alle Gebäude sind fertig (keine Baustellen). Das **Rathaus** kommt auf die günstigste flache Fläche
  nahe dem Bebauungs-Schwerpunkt an einer Straße, dazu **Lagerhäuser (Stufe 3)** dort, wo die meisten Gebäude außerhalb
  jedes Lager-Kreises stehen – bevorzugt auf freiem Land, notfalls wird dafür abgerissen. Meldung: „Spielstand umgestellt …“.
  Gemessen: Megacity-Backup → Stufe 5, Rathaus + 8 Lager, nichts abgerissen; Stand des Nutzers (51k) → Rathaus + 6 Lager,
  1 Gebäude abgerissen, 9 Gebäude bleiben außerhalb.
- **Start** (31.10., Schritt 1): Start mit dem **Rathaus + Lagerhof** (3×3, nicht abreißbar, Lager für alle Rohstoffe, Notstrom 30 MW) an einer Lichtung mit einem Stück Straße, **3.000 $ Gründungskasse**, 200 Holz, 150 Stein.
  - **Gründung (Stufe 1):** keine Steuern, kein Unterhalt, **kein Zukauf** – Material muss selbst gesammelt werden (Holzfäller, Steinbruch, Grube; Straße zum Rathaus-Lager nötig). Sonderbauten kosten nur 10 % ihres Geldpreises (+ Material). Häuser brauchen schon auf Stufe 1 etwas Holz (Gewerbe/Industrie später Holz + Stein). Arbeit gibt es am Rathaus (30) und in Abbau-Betrieben mit Strom (je 15), Häuser brauchen noch keinen Pendelweg. Nach dem Ausbau auf Stufe 2 bleiben diese Jobs (und die Regel ohne Pendelweg) als Übergang, bis Gewerbe und Industrie mindestens so viele Arbeitsplätze bieten.
  - **Rathaus-Fenster** (Knopf oben): Stufe, Bedingungen der nächsten (Einwohner + Material mit Häkchen), „Rathaus ausbauen“, was neu freigeschaltet wird. Gesperrte Werkzeuge nennen die nötige Stufe.

| Stufe | Name | Ausbau braucht | Schaltet frei |
|---|---|---|---|
| 1 | Gründung | – | Straßen, Wohnen, Strom (Windrad), Holzfäller, Steinbruch, Grube, Lager |
| 2 | Dorf | 200 Einw. + 150 Holz, 150 Stein | **Steuern, Zukauf + Verkauf**, Zuschuss 2.000 $, Gewerbe, Industrie, Parks, Sägewerk, Ziegelei, Feuerwehr, Polizei, Baumschule, Biomasse |
| 3 | Kleinstadt | 1.000 Einw. + 200 Bretter, 300 Ziegel | Zuschuss 3.000 $, Schule, Krankenhaus, Bus, Kohlekraftwerk, Glashütte, Mine, Stahlwerk |
| 4 | Stadt | 3.000 Einw. + 400 Ziegel, 150 Glas, 100 Stahl | Bahn, Bibliothek, Kino, Bürgerhaus, Recyclinghof, Prospektor, Betonwerk |
| 5 | Großstadt | 6.000 Einw. + 600 Ziegel, 300 Glas, 300 Stahl, 50 Gold | Universität, Institut, Theater, Stadion, Hightech, Solar/Speicher/Wasserkraft (+ Forschung) |

- **Stadtrechte-Zuschuss + Verkauf** (31.10.): Ausbau auf Stufe 2 bringt 2.000 $, auf Stufe 3 3.000 $ – bewusst
  knapp, Handel gehört dazu: ab Stufe 2 wird Überschuss jeden Monat verkauft (Posten „Rohstoff-Export“). **Handel ist
  teuer in beide Richtungen:** Zukauf kostet 3× Grundpreis, Verkauf bringt 3× Grundpreis (`EXPORT_FACTOR`) – eigene
  Förderung lohnt sich, Holzfäller + Baumschule sind eine (langsame) Geldquelle. Behalten wird der Bedarf der nächsten Rathaus-Stufe + 50, mindestens ein Viertel der
  Lagerkapazität (`SELL_KEEP`, `SELL_EXTRA`). Vorher wurde nur verkauft, was nicht mehr ins Lager passte.
- **Dorf (Stufe 2) bewusst entlastet** (31.10.): Abbau-Betriebe, Werke und Lager kosten 30 % (`VILLAGE_WORKS_COST`);
  Polizei und Feuerwehr werden erst ab Stufe 3 erwartet (`SERVICE_HALL`, vorher schon ab 300 Einw. – unbezahlbar).
- **Kette ohne Zukauf:** Jede Rathaus-Stufe ist mit eigener Förderung erreichbar (Stufe 2: Holz/Stein, Stufe 3: Bretter
  + Ziegel – Ziegelei brennt ohne Kohle mit Holz, Stufe 4: Glas/Stahl mit der Mine ab Stufe 3). Werke kaufen ab Stufe 2
  fehlende Kohle als Brennstoff zu (3× Preis), wenn kein Ersatz-Brennstoff möglich ist.
- **Baustellen** (Schritt 2): Wächst ein Haus, ist es erst eine Baustelle (Holzgerüst, Materialstapel, ab Stufe 3 Kran) – Bauzeit Stufe 1/2/3+ = 1/2/3 Monate, solange wohnt/arbeitet dort niemand. Auch Sonderbauten sind erst Baustelle (1×1 = 1, 2×2 = 2, 3×3 = 3 Monate) und liefern solange nichts (kein Strom, keine Förderung, kein Dienst).
- **Lager-Netz:** Rathaus-Hof (18 Tiles) und Lagerhäuser (14 / 20 / 26 Tiles je Stufe) haben einen Einzugskreis. Baustellen außerhalb dauern **doppelt so lange**; ab 2.000 Einwohnern verfallen Gebäude außerhalb leichter (Instandhaltung kommt schlecht an). Info-Karte: „Baustelle: fertig in ~N Monaten (langsam)“, „Kein Lager in Reichweite“; Bau-Vorschau des Lagerhauses zeigt den Kreis.
- **Bürgermeister** (Schritt 3): Figur vor der Rathaus-Front (ohne Rathaus: an der Straße nahe dem Wohn-Schwerpunkt). Er **verkündet jede Warnung** per Sprechblase über dem Kopf (Stromengpass, Unzufriedenheit, Brände, Leerstand …) und **läuft zum Ort**, wenn er höchstens 40 Tiles entfernt ist (schüttelt dort den Kopf bzw. nickt bei guten Nachrichten, dann zurück); fernere Orte sagt er nur an und winkt. **Klick auf ihn** oder Knopf oben (Figur) öffnet den **Berater**: die wichtigsten Probleme der Stadt mit Ort und auf Rathaus-Stufe 1–2 eine Aufgabenliste für die ersten Schritte. Zwischen hohen Häusern kann er verdeckt sein – die Sprechblase bleibt sichtbar.
- **Arbeiter** (Schritt 4, rein optisch): bis zu 18 kleine Figuren laufen auf dem rechten Gehweg über die Straßen – vom
  nächsten Lager (Rathaus-Hof/Lagerhaus) mit einer **Kiste** zur **Baustelle**, hämmern dort kurz und gehen zurück; von
  **Abbau-Betrieben/Werken** mit Förderung tragen sie einen **Block des Rohstoffs** (Stamm, Stein, Sand, Ziegel …) zum Lager.
  Baustellen haben Vorrang, 2×2-Baustellen bekommen zwei Arbeiter. Ohne Straßenverbindung oder bei mehr als 70 Tiles Weg
  läuft niemand. Laufen mit dem Spieltempo, stehen bei Pause.

Test `--buildstart [--bsmonths=N]` (Gründung, Sperren, Abbau, Baustellen, Lager-Kreis, Wachstum, Ausbau), `--mayortest` (Bürgermeister läuft zum nahen Ort und zurück, ferner Ort nur Ansage), `--workertest` (Arbeiter-Zyklen zählen, mit `--buildstart` oder `--loadfile`), Screenshot-Flags `--construct`, `--mayorcam` (Kamera auf den Bürgermeister), `--workercam` (Kamera auf einen laufenden Arbeiter).

## Regeln (Kurz)

- Neue Städte starten im **Januar 1980** (`Config.START_YEAR`, bewusst gewählt).
- Zonen wachsen nur mit **Straße** (≤3 Tiles), **Strom** und **Nachfrage** (RCI-Balken). Info-Karte zeigt Blocker.
- Strom fließt durch Leitungen, Zonen und Sonderbauten — **nicht über Straßen**, dort Leitung drüberziehen.
- **Stromnetze sind getrennt:** alles Zusammenhängende ist ein Netz und bekommt nur die Leistung seiner eigenen Kraftwerke. Ein neues Kraftwerk ohne Verbindung hilft einem anderen Netz nicht.
- **Dienst- und Kulturbauten brauchen Strom** (Stufe 1: Bibliothek/Polizei/Feuerwehr 1 MW, Schule/Kino 2, Bürgerhaus 3, Krankenhaus/Theater 5, Stadion 12; Stufe 2 ×1,5, Stufe 3 ×2). Ohne Strom arbeiten sie nicht: keine Versorgung, Feuerwache rückt nicht aus („Feuerwache ohne Strom“), keine Veranstaltungen; Blitz-Symbol, Info-Karte „x Kein Strom“. Im Netz werden sie **bevorzugt** versorgt (vor Wohnen/Gewerbe/Industrie). Ein Dienstbau zwischen Straßen ohne angrenzende Zone braucht eine Stromleitung.
- Im Netz wird vom Kraftwerk aus Tile für Tile versorgt; reicht die Leistung nicht, fällt das **Leitungsende** zuerst aus (Blitz-Symbol, kein Wachstum, Verfall).
- Anzeige oben: Bedarf aller Gebäude (auch nicht angeschlossener) / Leistung aller Kraftwerke, **rot sobald irgendwo ein Gebäude ohne Strom ist**; Tooltip listet die Netze (Bedarf/Leistung/Kraftwerke/Engpass). Meldung mit Ort: „Kein Strom: … ohne Kraftwerk im Netz“ bzw. „Stromengpass im Netz bei x,z“. Info-Karte: Netz des Tiles. **Ansicht Strom** (V): jedes Netz in eigener Farbe, Gebäude ohne Strom rot, Kraftwerke weiß. Test `--powertest`, `--powerreport` (Dienste ohne Strom eines Spielstands), `--processtest`, `--budgettest` (Haushalt über 12 Monate), `--determinism` (Prüfsummen nach 12 Monaten mit festem Zufall).
- Kohlekraftwerk senkt Bodenwert von Wohngebieten in der Nähe.
- **Pendler**: 55 % der Einwohner fahren monatlich zum nächsten freien Job (Dijkstra, Stau verteuert Wege).
  Wohnen braucht erreichbare Jobs (auch per Bahn), Gewerbe/Industrie erreichbare Einwohner. Fahrzeit > 40 blockiert Wohnwachstum.
- **Stau** senkt Bodenwert und bremst Autos sichtbar.
- **Sichtbarer Verkehr** folgt der Simulation: 1 Auto je 11 Auto-Pendler (Bus-/Bahnfahrer fahren nicht Auto), Autos erscheinen fast nur auf Straßen mit Pendlern (reine Bahn-Vorstädte bleiben ruhig), 1 Bus je 120 Fahrgäste/Monat. Jedes Auto fährt 8–30 Tiles und taucht dann neu nach Pendler-Gewicht auf (sonst sammeln sich Zufallsfahrer in Nebenecken wie Serpentinen). Tests `--cartest`, `--cardrift=Sek` (nach 20 s: 22 % der Autos auf den Top-10-%-Straßen bei 28 % Verkehrsanteil; vorher 11 %).
- **Bahnhofs-Kapazität**: 1.500 Ein-/Aussteiger je Bahnhof und Monat. Darüber wird der Weg über diesen Bahnhof teurer (Aufschlag 3 × Auslastung²), ab 150 % ist er für den Monat dicht → Pendler weichen auf andere Bahnhöfe, Bus oder Auto aus. Info-Karte des Bahnhofs zeigt die Auslastung („überfüllt!“). Mehr Bahnhöfe = mehr Kapazität.
- **Reichweite beim Bauen:** Mit Haltestelle oder Bahnhof in der Hand zeigt die Karte automatisch die ÖPNV-Ansicht, dazu unter dem Cursor die Reichweite: **blau** die Straßen, die ins Busnetz kommen bzw. im Fußweg zum Bahnhof liegen (inkl. ganzem Busnetz, wenn eine Haltestelle nahe dem Bahnhof steht), **hellgrün** Gebäude, die dadurch neu Anschluss bekommen. Dienst-/Kulturbauten zeigen den **Rand ihres Einzugskreises** (weiß), beim Ausbau den Radius der nächsten Stufe. Test `--rangetest`.
- **Ansicht ÖPNV** (V bzw. Ansicht-Liste): Straßen im Busnetz blau, Gebäude mit Bus-/Bahnanschluss grün, ohne rot; Liste zeigt Anteil, Bus-/Bahnfahrer und Anteil Wohnungen mit Anschluss.
- Spielstände von vor der Einführung von Fels bekommen beim Laden Fels auf freiem Gelände nachgeneriert (`ore_version`).
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
- `dev_tests.gd` — `--selftest` (Timing, Speichern/Laden, Audio), `--dragtest` (echtes Maus-Ziehen), `--lanetest` (Rechtsverkehr auf Hauptstraßen), `--widetest` (Hauptstraßen-Erkennung), `--profile[=Sek,Tempo]` (Frame-Zeiten + Ruckler-Ursachen), `--gfx=0..2`, `--nowarmup`, `--servicetest`, `--tool=<name>`, `--traffictest` (Korridor: Straße/Parallelstraße/Hauptstraße/Bus/Bahn), `--pickcheck`, `--firetest` (Brand an der Wache gelöscht, ohne Wache abgebrannt + Ruine), `--bustest` (Vorstadt mit eigenem Straßennetz bekommt Busse), `--happytest` (Aufschlüsselung, Warnung bei Steuer hoch / Polizei weg), `--cheattest` (Geld-Cheat per Tastenereignis), `--greentest` (Grüngürtel gegen Verschmutzung, Terraforming reißt Straße ab), `--venuetest` (Stadion/Theater: Besucherverkehr, Kundschaft), `--zonetest` (Ladenzeile, Ballung, Nachbarschaft), `--taxtest` (Steuern je Zone, ÖPNV-Tarif), `--cartest` (Autos/Busse je Tarif, Diagnose ÖPNV, Bahnhofs-Auslastung), `--cardrift=Sek`, `--jamreport` (meistbelastete Straßen), `--loadfile=pfad` (Spielstand-Kopie laden, alte Stände werden umgerechnet; `--nomigrate` = ohne Umrechnung zum Vergleich), `--focus=x,z` (Kamera auf Tile), `--fronttest`, `--hover=x,z [--detail]`, `--notify`, `--hidehud`, `--fpstest`, `--mutetest`, `--savetest`, `--uiscale=f`, `--zoomtest`, `--rangetest`, `--appicon=pfad.png` (App-Icon rendern), `--splash[=brick|grass|stone]` (+ `--loadfile`, `--cam`, `--screenshot`: Startbild mit 3D-Block-Logo, Tilt-Shift), `--menu --asksave=slot`, `--gpumeasure=Sek,fps [--pause]`, `--popup=view|happy|log`, `--loadreport` (Auslastung der Dienste + Brände in 12 Monaten), `--powertest`, `--bigcity` (ganze Karte bebauen), `--buildtest` (Bau-Klick-Zeit, Pendler synchron/Hintergrund), `--restest`, `--processtest`, `--renewtest`, `--treereport`, `--researchtest`, `--resbuild`, `--freshrun=Jahre` (Neustart mit Startkapital: Startviertel + jährlicher Ausbau nach Kassenlage, Haushalt je Jahr, Wachstumsblocker), `--econreport` (Haushalt nach Posten, mit `--loadfile`)

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

**Belegung & Leerstand (23.10.):** Jedes Gebäude hat eine Belegung 0–100 % – Einwohner/Jobs = Kapazität × Belegung, die Stadt schrumpft also sofort und schrittweise, wenn Gebäude verfallen.
- **Auszug je Monat:** kein Strom/keine Straße/keine Jobs bzw. Einwohner erreichbar −12 %; unzufrieden −6 % (Zeit zum Gegensteuern); nur „keine Nachfrage“ oder „zu groß für die Lage“/„Villenlage verloren“ −3 % und nie unter 30 % (das Gebäude steigt dann eher auf eine kleinere Stufe ab). Ohne Problem **Zuzug +10 %**. Neu gewachsene Gebäude starten voll belegt.
- **Leerstand** bei 0 %: vernagelte Fenster, keine Einwohner/Jobs/Steuern, kein Stufenwechsel. Wird der Grund behoben, ziehen wieder Leute ein. Nach **24 Monaten** Leerstand wird es abgerissen (die Zone bleibt).
- **Verfall im Viertel:** jedes leere Gebäude senkt die Zufriedenheit der Wohnhäuser im Umkreis von 3 Tiles um 3 Punkte (höchstens 12) – eigener Posten „Leerstand“ in der Zufriedenheit. Gegensteuern: Ursache beheben, Leerstand abreißen, Viertel mit Diensten/Parks aufwerten.
- Anzeige: Info-Karte „Belegung 60 % (sinkt)“ bzw. Titel „LEERSTAND“ mit Grund und Abriss-Countdown; Meldung „Leerstand: … aufgegeben (Grund)“ mit Sprung zum Ort. Früher stiegen Gebäude bei diesen Gründen zufällig eine Stufe ab (4–8 %/Monat), die Einwohner fielen erst dann sprunghaft.
- Messung: Neustart (`--freshrun=15`, Skript ohne Parks/Kultur) 935 statt 1.190 Einwohner nach 15 Jahren; Megacity des Nutzers stabil (42.660 → 42.675 in 12 Monaten). Test `--vacancytest`, Screenshot-Flag `--vacant`.

**Verfall sichtbar:** Ein Gebäude, das absinken wird (Bodenwert/Lage reicht nicht mehr für die Stufe, unzufrieden, ohne Strom/Straße/Erreichbarkeit, keine Nachfrage, Villenlage verloren), sieht schon vorher abgenutzt aus: verwitterte Blöcke, kaputte Fenster, Ranken an den Wänden, Geröll. Die Info-Karte nennt den Grund („x Verfällt: Bodenwert 39 % zu niedrig für Stufe 3“). Abstieg dann mit 4–8 % Chance je Monat. Test `--decaytest`, Screenshot-Flag `--worn`.

### Steuern & ÖPNV-Tarif

| Steuer (Regler W/G/I oben rechts) | neutral | Wirkung je Punkt über neutral |
|---|---|---|
| Wohnen | 9 % | Nachfrage −0,05 und Zufriedenheit −4 je Punkt, **ab +2 Punkten zusätzlich quadratisch** (+2 → −8 %, +3 → −12,4 %, +6 → −30,4 %); unter neutral +2 je Punkt |
| Gewerbe | 9 % | Gewerbe-Nachfrage −0,04 |
| Industrie | 12 % | Industrie-Nachfrage −0,025 (robust, „dreckig, nimmt es hin“) |

- **Verwaltung**: ab 5.000 Einwohnern Ausgabe 0,06 × (Einw. − 5.000)² / 50.000 pro Monat (10.000 Einw. → 30 $, 20.000 → 270 $, 40.000 → 1.470 $). Große Städte werden dadurch nicht endlos reich; Tooltip auf „+x / Monat“ zeigt den Posten.
- Einnahmen/Monat = Einwohner × 0,18 × Wohnsteuer × 12 + Gewerbejobs × 0,15 × Gewerbesteuer × 12 + Industriejobs × 0,15 × Industriesteuer × 12 (Hightech × 1,6) + ÖPNV-Tarif + Bodenabgabe der Villen (seit 31.10. +50 %, Straßenunterhalt halbiert auf 0,2 $/Feld – Kleinstädte trugen sich nicht). **Schulden kosten 1 % Zinsen pro Monat** auf den Minusbetrag. Tooltip auf „+x / Monat“ zeigt die Aufteilung.
- **Spieltempo** (seit 31.10. langsamer): normal 8 s, schnell 4 s, sehr schnell 1,5 s je Spielmonat (vorher 3/1,5/0,5 s – 40 Spieljahre waren nur 24 bzw. 4 Minuten). 40 Jahre ≈ 64 / 32 / 12 Minuten.
- **ÖPNV-Tarif** (Button unter den Steuern): **kostenlos** – keine Einnahmen, Einstieg in die Bahn wirkt günstiger, Busanteil 55 %, +5 Zufriedenheit für Wohnhäuser mit Bus-/Bahnanschluss · **normal** – $0,10 je Fahrgast, Busanteil 40 % · **teuer** – $0,20, Busanteil 25 %, −3 Zufriedenheit.
- Demo-Stadt (`--taxtest`): neutral $188/Monat; Industrie 16 % → +$13, Nachfrage I −0,10; Wohnen 13 % → +$47, aber Zufriedenheit −22 (vor 23.10.: −8), Wohnnachfrage −0,40.
- **Balance-Messung 23.10.** (`--freshrun=20`, `--econreport`): Neustart mit 20.000 $ fällt nie unter ~6.500 $, Saldo nach 20 Jahren +1.200 $/Jahr bei 1.300 Einw. (Wachstum bremst die Nachfrage, nicht das Geld). Megacity des Nutzers (42.700 Einw.): vorher +2.400 $/Monat (Einnahmen 30 % über Ausgaben, 14,5 Mio. $ in der Kasse), jetzt +530 $/Monat (Verwaltung 1.700 $, Zukauf 570 $), Zufriedenheit 91 % bei Wohnsteuer 10 %. Tarif kostenlos/normal/teuer: 244/178/110 Fahrgäste, $0/18/22, Zufriedenheit 65/60/57 %.

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
- **Lieferweg**: Abbau-Gebäude und Werke liefern nur mit **Straße direkt am Gebäude**, die zum Lager führt (Netz mit Lagerhaus; ohne Lagerhaus das Straßennetz mit den meisten Einwohnern). Ohne Anschluss fördert ein Abbau-Gebäude in einen **eigenen Vorrat** (50 je Stufe, als Kistenstapel sichtbar) und steht still, wenn er voll ist; mit der Straße wird der Vorrat geliefert. Werke ohne Anschluss bekommen keine Rohstoffe. Warnung beim Wegfall, Info-Karte, **Ansicht Rohstoffe** färbt Gebäude grün/rot, Bau-Vorschau zeigt einen Rahmen grün (angeschlossen) / gelb (Straße, anderes Netz) / rot (keine Straße).
- **Lager**: 200 je Rohstoff, + Lagerhäuser. Was nicht passt, wird **automatisch exportiert** (Holz 1, Stein/Sand 0,5, Ton 0,8, Kohle 1,5, Eisen 3, Gold 12 $ je Einheit) → Einnahme „Rohstoff-Export“.
- **Endlich, aber langlebig**: je Vorkommen-Tile 1.200–2.550 Einheiten. Typische Karte 128×128: ~950.000 Stein (≈ 500 Fels-Tiles), ~200.000 Kohle, ~100.000 Eisen, ~30.000–55.000 Gold, Sand/Ton praktisch unerschöpflich. Eine Mine an einer Ader hält bei Stufe 3 rund 40–50 Spieljahre. Nachschub siehe **Erneuerung**.
- Sichtbar: Fels, Sand und Ton färben den Boden, Erzbrocken ragen aus dem Gras; **Ansicht Rohstoffe** (V) färbt alle Vorkommen (kräftig = voll, grau = erschöpft), die Ansicht-Liste zeigt die Restmengen. Mit einem Abbau-Werkzeug zeigt die Vorschau Vorkommen im Umkreis. HUD: Lager-Leiste (Tooltip: Förderung, Kapazität, Export).
- Werkzeuge haben keine Taste (alle Buchstaben belegt) – nur über die Werkzeugleiste. Tests `--restest`, `--orecount`, Screenshot-Flag `--resbuild`.

## Verarbeitung & Baustoffe (Bergbau-Wirtschaft, Stufe 2)

| Werk (Werkzeuggruppe Verarbeitung, 2×2, Strom) | Bedarf je Monat | Ergebnis | Verschmutzung |
|---|---|---|---|
| Sägewerk | 10 Holz | 10 Bretter | – |
| Ziegelei | 10 Ton + 2 Kohle – ohne Kohle: 4 Holz bei 70 % Ausstoß | 10 Ziegel (7 mit Holz) | leicht |
| Glashütte | 10 Sand + 3 Kohle | 8 Glas | mittel |
| Stahlwerk | 10 Eisen + 5 Kohle | 8 Stahl | stark |

(× Ausbaustufe; reicht ein Rohstoff nicht, läuft das Werk anteilig – Info-Karte: „Zu wenig Sand (50 % Auslastung)“.)

- **Baustoffbedarf beim Wachsen** (ab **2.000** Einwohnern – vorher 400, das war eine Armutsfalle für Kleinstädte; Stufe 1 bleibt kostenlos; der Zukauf darf die Kasse bis −2.000 $ ins Minus drücken, statt das Wachstum zu stoppen):

| | Stufe 2 | Stufe 3 |
|---|---|---|
| Wohnen | 4 Bretter, 4 Ziegel | 8 Ziegel, 4 Glas, 3 Stahl |
| Gewerbe | 3 Bretter, 3 Ziegel, 2 Glas | 4 Ziegel, 8 Glas, 6 Stahl |
| Industrie | 4 Bretter, 4 Ziegel | 6 Ziegel, 8 Stahl |

- **Instandhaltung (31.10.):** ab 2.000 Einwohnern verbraucht jedes bewohnte Gebäude ab Stufe 2 monatlich **1 %** seines Baumaterials (Renovierung ≈ alle 8 Jahre; zuerst 0,5 %, auf Nutzerwunsch erhöht) – sonst brauchte eine fertig gebaute Stadt nie wieder Material und ein Werk je Sorte reichte für immer. Aus dem Lager, sonst Zukauf; reicht auch das Geld nicht (Kasse unter −2.000 $), verfallen Gebäude langsam. Haushalts-Tooltip: „Instandhaltung: x Material/Monat“. Messung bei 1 %: Megacity ≈ 140 Einheiten/Monat (61 Ziegel, 34 Glas, 39 Stahl) → etwa 4–6 Werke je Sorte (Stufe 1) oder Zukauf; Neustarts (Bot, 50 J.) 3.100–4.300 Einwohner, wachsen weiter.
- Fehlt Material, wird es **zugekauft** (3× Exportpreis, Ausgabe am Monatsende; bis 23.10. 2× – eigene Minen/Werke lohnten sich kaum). Ohne Geld dafür wächst nichts („Baustoffe fehlen …, Zukauf $x zu teuer“). Info-Karte (Details): Bedarf der nächsten Stufe und ob es im Lager ist.
- **Baumaterial beim Bauen**: Straßen, Gleise, Leitungen, Haltestellen, Bahnhöfe, Parks und alle Sonderbauten kosten neben Geld auch Rohstoffe/Baustoffe. Sie kommen aus dem Lager; was fehlt, wird **sofort zugekauft** (3× Exportpreis) und ist im angezeigten Preis enthalten. Kostenblase am Cursor: Gesamtpreis, Material („50 Ziegel (50 fehlt)“), „davon Zukauf $x“; Werkzeug-Tooltip nennt das Material. Reicht das Geld nicht für Bau + Zukauf, wird nicht gebaut. Zonen kosten kein Material (erst ihr Wachstum). Ausbau eines Sonderbaus: halbes Baumaterial × aktuelle Stufe.

| Bau | Material | | Bau | Material |
|---|---|---|---|---|
| Straße (je Tile) | 2 Stein | | Gleis (je Tile) | 2 Stein, 1 Stahl |
| Stromleitung | 1 Holz | | Park | 4 Holz |
| Haltestelle | 2 Stahl | | Bahnhof | 20 Ziegel, 5 Stahl, 4 Glas |
| Polizei/Feuerwehr | 20 Ziegel, 6 Bretter, 2 Glas | | Schule | 25 Ziegel, 10 Bretter, 6 Glas |
| Krankenhaus | 50 Ziegel, 20 Glas, 6 Stahl | | Bibliothek | 20 Ziegel, 10 Bretter, 4 Glas |
| Kino | 25 Ziegel, 10 Glas, 4 Stahl | | Bürgerhaus | 80 Ziegel, 20 Glas, 10 Stahl |
| Theater | 150 Ziegel, 40 Glas, 30 Stahl | | Stadion | 300 Stein, 150 Ziegel, 120 Stahl |
| Kohlekraftwerk | 60 Ziegel, 30 Stahl | | Windrad | 6 Stahl |
| Holzfäller | 30 Holz, 10 Bretter | | Grube | 20 Holz |
| Steinbruch | 40 Holz, 6 Stahl | | Mine | 60 Holz, 40 Stein, 25 Stahl |
| Lagerhaus | 30 Bretter, 20 Ziegel | | Baumschule | 15 Holz |
| Prospektor | 10 Bretter, 8 Stahl | | Recyclinghof | 30 Ziegel, 15 Stahl |
| Sägewerk | 50 Holz, 40 Stein | | Ziegelei | 30 Holz, 80 Stein |
| Glashütte | 40 Ziegel, 40 Stein | | Stahlwerk | 80 Ziegel, 80 Stein |

  (Zukaufwert ≈ 25–35 % des Geldpreises; Sägewerk/Ziegelei brauchen nur Rohstoffe, damit man ohne Baustoffe anfangen kann.)
- **Kohlekraftwerk verbraucht 8 Kohle/Monat** aus dem Lager, sonst Zukauf (~24 $/Monat) – eigene Mine spart Geld. **Werke haben Vorrang** bei der Kohle (sie können nicht zukaufen), Kraftwerke nehmen den Rest. Kohle ist endlich → erneuerbare Energien (Roadmap).
- Lager-Leiste: zweite Zeile Baustoffe; Tooltip mit Herstellung, Verbaut, Zugekauft, Export. Kassen-Tooltip: „davon Zukauf“.
- Messung (`--budgettest`, 12 Monate, Stand 23.10. mit 3×-Zukauf): Demo-Stadt −49 $/Monat bei 71 $ Zukauf (Kohlekraftwerk ohne eigene Mine – Steuer leicht anheben oder Mine bauen); Megacity des Nutzers +526 $ bei 497 $ Zukauf. Tests `--processtest`.

## Erneuerung (Bergbau-Wirtschaft, Stufe 4)

| Gebäude (Gruppe Rohstoffe, Strom) | Wirkung | Kosten / Unterhalt |
|---|---|---|
| **Baumschule** (1×1) | pflanzt 2 Bäume je Monat und Stufe auf freiem Gras im Umkreis 4 (nächste Tiles zuerst), **bis der Umkreis zur Hälfte Wald ist** → mit Holzfäller nachhaltiges Holz | 400 $ / 3 $ |
| **Prospektor** (1×1) | findet mit 8 % je Monat und Stufe eine neue Ader (3–6 Tiles) auf freien Hügeln im Umkreis 8: Kohle ab 2, Eisen ab 4, Gold ab 5 Blöcken über Wasser. Funde sind **Restadern** (400–1.200 Einheiten je Tile, kleiner als Startvorkommen). Meldung mit Ort | 1.500 $ / 10 $ |
| **Recyclinghof** (2×2, ausbaubar) | **Einzugskreis 18 / 27 / 36 Tiles** (3× Polizei): Abriss im Kreis gibt **80 %** statt 40 % der Baustoffe zurück; holt 30 % des Instandhaltungs-Materials im Kreis zurück (höchstens 40 / 100 / 200 je Monat) – große Städte brauchen mehrere | 2.000 $ / 8 $ |

- **Wald erholt sich von selbst, breitet sich aber nicht aus**: nur Lücken mit 5+ Bäumen ringsum (von 8, inkl. Diagonalen) wachsen mit 1 % je Monat zu – gerodete Stellen schließen sich langsam von den Ecken her, Waldränder wandern nicht ins offene Land. Ab 25 % bewaldetem Land wächst gar nichts mehr von selbst. Nie auf Zonen, Straßen, Strand. (Bis 23.10. reichten 2 Nachbarn → nach Jahrhunderten war die Karte zugewachsen.)
- **Adern regenerieren** sehr langsam: Fels/Erz/Ton unter der Startmenge (1.200) +10 Einheiten je Tile alle ~2 Jahre (erschöpfte Adern kommen also wieder, bleiben aber knapp). Sand regeneriert nicht (ohnehin reichlich).
- **Recycling** beim Abreißen (Bulldozer) mit Meldung „Recycling: … zurück ins Lager“ – auch ohne Recyclinghof (40 %). Gilt für Zonen-Gebäude ab Stufe 2 und für Sonderbauten (deren Baumaterial inkl. Ausbaustufen).
- Info-Karte: gepflanzte Bäume / „Pause: Umkreis zu 50 % bewaldet“ / „Kein freies Gras im Umkreis“, letzter Prospektor-Fund. Test `--renewtest`, `--treereport` (Waldanteil eines Spielstands + Zuwachs in 12 Monaten); `--resbuild` setzt die Gebäude in die Demo und prüft Info-Karten + Abriss.

## Energie & Tag/Nacht (Forschung Schritt 2)

| Kraftwerk (Strom-Gruppe) | Bau | Leistung | Laufend | Nachteil |
|---|---|---|---|---|
| Kohlekraftwerk | 3.000 $ | 400 MW | 8 Kohle/Monat | starke Verschmutzung, Kohle endlich |
| Windrad | 450 $ | 30 MW | – | wenig Leistung |
| **Biomassekraftwerk** (2×2, ohne Forschung) | 1.200 $ | 60 MW | **20 Holz/Monat** (nach dem Sägewerk; fehlt es: Zukauf) | Abgas (halbe Kohle-Verschmutzung, Rauch), braucht Holzfäller + Baumschule |
| **Solarfeld** (2×2, Forschung „Solarenergie“) | 2.500 $ | 50 MW **nur tagsüber** | – | nachts 0 |
| **Batteriespeicher** (1×1, Forschung „Batteriespeicher“, braucht Solar) | 3.000 $ | – | – | erzeugt nichts: liefert nachts bis 40 MW aus dem Tagesüberschuss |
| **Wasserkraftwerk** (2×2, Forschung „Wasserkraft“) | 9.000 $ | 120 MW Tag und Nacht | – | teuer, **nur direkt am Wasser** (mind. 3 Wasserfelder am Rand) |
| **Pumpspeicher** (2×2, Forschung „Pumpspeicher“, nach Batterie) | 7.000 $ | – | – | Speicher 150 MW, **nur am Hang**: mind. 3 Blöcke über dem Wasser, Wasser im Umkreis 4 |
| **Salzspeicher** (2×2, Forschung „Salzspeicher“, nach Pumpspeicher) | 8.000 $ | – | – | Speicher 300 MW (Flüssigsalz-Wärmespeicher / Carnot-Batterie). **Klick auf ein Kohlekraftwerk rüstet es zum halben Preis um** – dann fehlen dessen 400 MW (Vorschau warnt) |

- **Tag/Nacht im Strom:** jedes Netz hat eine Tag- und eine Nachtbilanz. Nachts brauchen Gebäude 75 % des Tagesbedarfs, Solar liefert 0, Speicher geben den Tagesüberschuss ab (höchstens ihre Leistung). Versorgt wird nach der knapperen Hälfte – reicht die Nacht nicht, fehlt am Leitungsende Strom („Stromengpass … nachts“). Ohne Solar ändert sich nichts gegenüber früher. Strom-Tooltip und Info-Karte zeigen „Tag x MW / Nacht y MW (Speicher z)“.
- **Sichtbarer Tageszyklus** (Echtzeit, 6 Minuten je Tag, unabhängig vom Spieltempo): Licht- und Himmelsfarbe, Morgen-/Abendrot (Lichtrichtung bleibt fest – eine wandernde Sonne ließ die Schatten flimmern), **Nacht nur ~1/4 des Zyklus (~90 s)** mit hellem Mondlicht, Fenster leuchten. Während der sichtbaren Nacht zeigt die Stromanzeige oben die **Nachtbilanz** („Nacht x / y MW“, rot bei nächtlichem Engpass) – so spielt der Tag/Nacht-Unterschied sichtbar mit, obwohl die Nacht kurz ist. Menü → Grafik → „Tag/Nacht“ schaltet ab (dann immer Mittag). Nur Optik; die Strom-Bilanz rechnet Tag/Nacht je Monat unabhängig davon.
- Tests `--energytest` (Solar allein / +Batterie / +Biomasse / Holz-Zukauf), Screenshot-Flags `--energybuild`, `--time=0..1` (0 Mitternacht, 0.25 Morgen, 0.72 Abend).
- Standortregeln: Vorschau zeigt den Grund statt des Preises (z.B. „Pumpspeicher braucht einen Hang …“). Test `--energytestb` (mit `--demo`: Standorte, Bau, Umrüsten).

## Stadt-Forschung (Forschung Schritt 3)

| Projekt | Voraussetzung | Wirkung |
|---|---|---|
| **Beton** | – | Betonwerk (Verarbeitung, 2×2): 10 Stein + 10 Sand + 1 Kohle → 12 Beton |
| **Hochhäuser** | Beton | Wohnen **Stufe 4**: 200 statt 80 Einwohner, ab 75 % Bodenwert (keine Villen), Bau braucht 14 Beton, 8 Glas, 6 Stahl |
| **Bürotürme** | Beton | Gewerbe **Stufe 4**: 120 statt 50 Jobs, direkt an der Straße nahe einer Kreuzung und ab 60 % Bodenwert; 12 Beton, 14 Glas, 10 Stahl |
| **Hightech-Industrie** | – | eigenes Zonen-Werkzeug (Industrie-Gruppe): zählt als Industrie, gleiche Jobs, **15 % der Verschmutzung**, **1,6× Steuer** (eigener Einnahme-Posten „Hightech“), kein Rauch; wächst nur, wo die Hochschul-Versorgung ≥ 20 % ist (Universität in Reichweite), sonst Blocker „Hightech braucht Akademiker“ |
| **Verkehrsleitsystem** | – | Straßen vertragen 25 % mehr Verkehr (Auslastung × 0,8) → weniger Stau |

Info-Karte: „Hochhaus/Büroturm · Stufe 4“, „Hightech-Industrie“; Wachstumsblocker nennen fehlenden Bodenwert/Lage. Test `--citytechtest` (mit `--loadfile=<große Stadt mit Uni>`).

## Forschung

1. **Universität** (3×3, 15.000 $ + 200 Ziegel, 100 Stein, 60 Glas, 40 Stahl; Unterhalt 60 $): verfügbar ab **6.000 Einwohnern** (vorher 8.000 – laut Bot-Messung für normale Spieler kaum erreichbar) und **70 % Schulversorgung**. Dienst „Hochschule“ mit 2,5-facher Reichweite und 4-facher Kapazität (Stufe 1: 3.200, Stufe 3: 18.000 Einwohner). **Akademiker** = von Unis versorgte Einwohner, je Uni höchstens ihre Kapazität. Ab 6.000 Einwohnern erwarten die Bürger eine Hochschule (Zufriedenheit).
2. **Forschungsinstitut** (2×2, 8.000 $, Unterhalt 40 $, Strom): erst wenn eine Universität steht. Erzeugt **30 Punkte je Monat und Stufe** × Akademiker-Faktor × Budget-Faktor. Volle Leistung braucht **1.500 Akademiker je Institutsstufe** (sonst anteilig, mindestens 10 %) – mehr Institute brauchen also auch größere/mehr Unis. (Erster Entwurf nahm die Quote der ganzen Stadt: in der Megacity nur 5 % → Großstädte wären bestraft worden.)
- **Kosten (31.10. erhöht):** Startpreis je Projekt = Punkte × 10 $ (Tiefbau 15.000 $, Salzspeicher 36.000 $) + Gold; Budget-Stufen 0 / 500 / 1.000 / 2.000 / 5.000 / 10.000 $ pro Monat, Faktor 0,25 + 0,75 × √(Budget / 2.000) (2.000 $ → ×1, 10.000 $ → ×1,93).
3. **Forschungsfenster** (Knopf oben neben „Ansicht“, 620 px breit): Kopf mit Instituten/Akademikern und Budget in je einer Zeile, darunter **Bereiche zum Aufklappen** (Rohstoffe & Industrie, Energie; aufgeklappt, wenn dort etwas läuft oder bereit ist) mit **einer Karte je Projekt** in Abhängigkeitsreihenfolge: Name + Plakette (BEREIT/LÄUFT/GESPERRT/ERFORSCHT), Wirkung, Punkte/Gold/Dauer, „Projekt starten“ bzw. Fortschrittsbalken. Gesperrte Karten sind ausgegraut und nennen die Voraussetzung („Voraussetzung: Batteriespeicher erforschen“), erforschte sind kompakt. Ein Projekt gleichzeitig; **Budget** in Stufen (siehe Kosten oben). Das Budget wird nur ausgegeben, solange ein Projekt läuft; **Gold** wird beim Start verbraucht (fehlt es: Sofort-Zukauf). Abschluss als Meldung.

| Projekt | Punkte | Gold | Voraussetzung | Wirkung |
|---|---|---|---|---|
| Tiefbau | 1.500 | 30 | – | Minen, Steinbrüche, Gruben fördern 50 % mehr |
| Effiziente Bauweise | 1.800 | 20 | – | 25 % weniger Baumaterial (Bauen, Ausbau, Wachsen) |
| Kraftwerksfilter | 1.500 | 30 | – | Kohlekraftwerke verschmutzen halb so viel |
| Moderne Hochöfen | 2.100 | 40 | Tiefbau | Werke brauchen halb so viel Kohle, 40 % weniger Verschmutzung |
| Solarenergie | 1.800 | 30 | – | Solarfeld baubar (50 MW, nur tagsüber) |
| Batteriespeicher | 2.100 | 50 | Solarenergie | Batterie baubar (liefert nachts bis 40 MW) |
| Wasserkraft | 2.400 | 40 | – | Wasserkraftwerk baubar |
| Pumpspeicher | 2.700 | 50 | Batteriespeicher | Pumpspeicher baubar |
| Salzspeicher | 3.600 | 80 | Pumpspeicher | Salzspeicher baubar, Kohlekraftwerke umrüstbar |

- **Dauer** (seit 23.10. ×3, Nutzer: „zu schnell“): 1 Institut Stufe 1 + 1.000 $/Monat ≈ 4 Jahre für Tiefbau; Institut Stufe 3 + 4.500 Akademiker + 3.000 $ ≈ 11 Monate. Jede Projektkarte zeigt die Dauer beim aktuellen und beim Höchstbudget.
- **Durchbruch-Karte** bei Abschluss (Bildmitte): Wirkung in Zahlen für die eigene Stadt (z.B. „Förderung ~52 statt 30“), „Hinspringen“ zum betroffenen Gebäude.
- **Sichtbar in der Welt:** Kohlekraftwerke und Werke rauchen (Schornsteinrauch, nur mit Strom) – ohne Forschung dunkel und dicht, mit Kraftwerksfilter/Modernen Hochöfen weiß, dünn und seltener. Industrie ab Stufe 2 raucht leicht (jedes dritte Gebäude, dünn, hellgrau), damit das Bild stimmig bleibt, ohne die Stadt zu verqualmen. Kraftwerksfilter setzt Filteraufsätze auf Schlot und Dach, Moderne Hochöfen Wäscher-Ringe und einen Elektroofen, Tiefbau einen zweiten Stahl-Förderturm mit Förderband (Mine) bzw. Förderband und Bagger (Steinbruch). Kostenblase: „-25 % Material (Effiziente Bauweise)“; Info-Karte betroffener Gebäude: Abschnitt „Forschung“.
- Info-Karte: Institut zeigt Punkte/Monat, Projekt + Fortschritt, „Kein Projekt gewählt“; Universität die Zahl der Akademiker; „Zu wenig Akademiker (x % Leistung)“ am Institut. Haushalts-Tooltip: „davon Forschung“.
- Screenshot-Flags `--techs=id,id` (als erforscht setzen), `--breakthrough=id` (Durchbruch-Karte), `--popup=research`. Test `--researchtest` (mit `--loadfile=<Kopie einer großen Stadt>`: Sperren, Bau, Gold, Dauer, Wirkung, Speichern).
- Nächste Stufen (Roadmap): Solar/Wasserkraft/Speicher, Hochhäuser, Bürotürme, **Hightech-Industrie** (eigenes Zonen-Werkzeug, wenig Verschmutzung, braucht Akademiker), Verkehrsleitsystem.

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
| `render/workers.gd` | Arbeiter-Figuren: Lager ↔ Baustellen/Werke über Straßen (rein visuell) |
| `render/mayor.gd` | Bürgermeister-Figur (Kit-Charakter): Heimatplatz, Laufen zu Meldungsorten, Animationen |
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
- [ ] **Wasserversorgung**: Pumpen/Wasserwerk, Wasserleitungen (unterirdisch, wie Strom als Netz), Kläranlage; Ansicht Wasser
- [x] Steuern je Zone (W/G/I), ÖPNV-Tarif, Zonen-Idealformen (Ladenzeile, Ballung, Nachbarschaft)
- [x] Rohstoffe Schritt 1–2: Karte 128×128, Vorkommen, Abbau-Gebäude, Lager, Export
- [x] Rohstoffe Schritt 3: Verarbeitung (Bretter, Ziegel, Glas, Stahl), Baustoffbedarf beim Wachsen, Kohlekraftwerk verbraucht Kohle
- [ ] **Erneuerbare Energien** (Kohle ist endlich, Unabhängigkeit vom Handel): umgesetzt über „Forschung Schritt 2 – Energie“ (unten); Geothermie später mit der Untertage-Ebene
- [x] Rohstoffe Schritt 4: Erneuerung (Waldausbreitung, Baumschule, Prospektor, Regeneration, Recycling)
- [x] **Forschung Schritt 1** (23.10.): Universität (ab 6.000 Einw. seit 31.10., vorher 8.000; + 70 % Schule), Forschungsinstitut, Budget-Regler, Gold je Projekt, Forschungsfenster, Durchbruch-Karte, sichtbare Wirkung (Rauch, Modelle). Projekte: Tiefbau, Effiziente Bauweise, Kraftwerksfilter, Moderne Hochöfen
- [ ] **Forschung Schritt 2 – Energie** (zugleich „Erneuerbare Energien“, Konzept 31.10.; **fertig 31.10.**: Tag/Nacht, Biomasse, Solarfeld, Batterie, Wasserkraft, Pumpspeicher, Salzspeicher):
  - **Solarfeld** (nur tagsüber, braucht Fläche), **Wasserkraft** (nur an Fluss/See, teuer)
  - **Biomasse** (Nutzerwunsch): günstig, ~60 MW, verbrennt Holz aus dem Lager (konkurriert mit dem Sägewerk, sonst teurer Zukauf → braucht Holzfäller + Baumschule), Abgas ≈ halbe Kohle-Verschmutzung mit sichtbarem Rauch; Raubbau am Wald senkt den Grünfilter
  - **Speicher** in Forschungsstufen: Batterie (klein, teuer, Stahl + Gold) → Pumpspeicher (groß, nur Hang + Wasser) → **Salzspeicher** (Nutzeridee; Flüssigsalz-Wärmespeicher wie in Solarthermie-Kraftwerken bzw. Carnot-Batterie: sehr groß, günstig, alte Kohlekraftwerke umrüstbar statt Abriss; Sand + Stahl + Gold). Speicher nehmen Überschuss von Wind/Sonne auf und liefern nachts/bei Flaute
- [x] **Forschung Schritt 3 – Stadt** (31.10.): Hochhäuser (Wohnen Stufe 4), Bürotürme (Gewerbe Stufe 4), **Hightech-Industrie** (Nutzerwunsch: eigenes Zonen-Werkzeug, gleiche Kategorie wie Industrie, wenig Verschmutzung, braucht Akademiker), Verkehrsleitsystem (−20 % Stau), Beton (neuer Baustoff aus Stein + Sand)
- [ ] Forschung später: Untertage/Tiefbau 2 (Geothermie, U-Bahn), weitere Projekte nach Bedarf; Balance (Dauer, Kosten) nach echtem Spielen nachjustieren
- [ ] **Aufbau-Start** (Konzept 31.10., entschieden; Nutzer: nicht zu Siedler-artig, keine Zelte, keine 3rd-Person) – seit 31.10. der einzige Spielmodus (später Easy Mode):
  - **Gründungskasse** (~3.000 $ für Straßen), Start mit **Rathaus + Lagerhof** an einer Lichtung; erst Material sammeln (Holzfäller, Steinbruch, Grube), Häuser brauchen schon auf Stufe 1 etwas Holz; Steuern erst ab Rathaus-Stufe 2.
  - **Rathaus-Stufen als roter Faden** (Ausbau kostet Material, schaltet frei – ersetzt teils die Einwohner-Schwellen). Entwurf: 1 Gründung (Straßen, Wohnen, Abbau, Lager, Windrad) · 2 Dorf (Steuern, Gewerbe, Industrie, Sägewerk, Ziegelei, Feuer/Polizei, Parks) · 3 Kleinstadt (Schule, Krankenhaus, Bus, Kohle, Glashütte, Mine) · 4 Stadt (Bahn, Kultur, Stahlwerk, Recycling, Prospektor) · 5 Großstadt (Universität/Forschung, Großkultur) · 6+ Metropole (U-Bahn, Wasserleitungen, Flughafen …). **Jede künftige Großfunktion wird an eine Rathaus-Stufe gebunden.**
  - **Baustellen mit kurzer Bauzeit** (1–3 Monate, auch im späteren Spiel): Gerüst + Materialstapel, steht bei Mangel still.
  - **Lager-Netz:** Lagerhäuser mit Einzugskreis; Baustellen und Instandhaltung außerhalb werden langsamer beliefert → verteilte Lager nötig.
  - **Bürgermeister-Figur** am Rathaus: verkündet dauerhaft alle Meldungen per Sprechblase und läuft zum Ort; Klick = Berater (wichtigste Baustellen der Stadt) und anfangs Aufgabenliste.
  - **Arbeiter-Figuren** laufen dauerhaft sichtbar (Lager ↔ Baustellen/Werke); später Lieferwagen (Lieferverkehr).
  - Umsetzung in Schritten: **1 Spielmodus + Rathaus-Stufen + Gründung (fertig 31.10.)** · **2 Baustellen + Lager-Netz (fertig 31.10.)** · **3 Bürgermeister + Sprechblasen + Berater (fertig 31.10.)** · **4 Arbeiter-Figuren (fertig 31.10.)**
- [ ] **Eigene Block-Figuren** (Idee 31.10., später): Bürgermeister/Arbeiter Minecraft-artig aus Pixel-Blocks (Würfel-Kopf/-Körper/-Glieder, Laufen über schwingende Glieder) statt der abgerundeten Kit-Charaktere – passt besser zu Gelände/Gebäuden. Größe bleibt bewusst übertrieben (Lesbarkeit).
- [ ] **Lieferverkehr**: Liefermengen als LKW-Fahrten zum Lager (Straßenlast, sichtbare Laster), Güterbahnhof für entfernte Minen, Lieferweg-Kosten
- [ ] Untertage-Ebene, Tunnel zu Nachbarstädten, Handel mit fiktiven Bürgermeistern
- [ ] **U-Bahn** (Untertage-Ebene, Stationen, kein Flächenverbrauch an der Oberfläche)
- [ ] **Handel mit anderen Bürgermeistern** (Nutzer 31.10., ersetzt den automatischen Verkauf): Kontakt zu Bürgermeistern der Nachbarstädte aufnehmen, Angebote/Aufträge aushandeln (was sie brauchen, was sie liefern), Preise nach Beziehung + Angebot/Nachfrage; nötig, damit ein Dorf mit knappem Zuschuss wachsen kann.
- [ ] **Erweiterter Handel** mit Nachbarstädten: Verträge (Strom, Rohstoffe, Müll), Preise nach Angebot/Nachfrage, Beziehungen zu den Bürgermeistern
- [ ] **Konflikte** mit Nachbarstädten (z.B. Streit um Wasser/Grenzen/Verschmutzung, Handelsembargo) – Ausgestaltung offen
- [ ] **Easy Mode** (Nutzeridee 31.10.): Startoption mit mehr Startkapital, niedrigeren Schwellen (Uni, Baustoffe) und sanfterem Steuer-Abzug; normales Spiel bleibt die Herausforderung (Ziel: Forschung nach ~50–70 Spieljahren ≈ 70–95 min)
- [ ] Budget-Fenster (Ressorts, **Kredite**, Jahresbilanz) – Nutzerwunsch: fehlt Geld für Bau + Material-Zukauf, Kredit aufnehmen statt nicht bauen; Kredit verzinst (31.10.: eher für ungeduldige Spieler, Handel bleibt teuer)
- [x] Brände sichtbar (Flammen/Rauch/Ruinen), Feuerwehr-Einsätze mit Löschzügen, Meldungen mit Kamera-Sprung
- [ ] Brand-Geräusche (Sirene, Knistern), evtl. Brandschutz-Ansicht (V)
- [ ] Bewohner/Tiere aus dem Kit (Characters/Animals) als Leben in der Stadt
- [ ] Performance: Pendler-Berechnung in Thread, Sichtweite für Kleinkram, Terrain/Gebäude getrennt rendern
- [ ] Glattere Hauptstraßen-Rundung (echtes Mesh statt Streifen)
