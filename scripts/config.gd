class_name Config
## Globale Konstanten: Kartengröße, Kosten, Simulationswerte.

const MAP_SIZE := 64
const TILE_BLOCKS := 3          # Blöcke pro Tile-Kante (1 Block = 1 Welteinheit)
const WATER_LEVEL := 3          # Tiles mit Höhe < WATER_LEVEL sind Wasser
const MAX_HEIGHT := 14
const SNOW_HEIGHT := 11

enum Zone { NONE, RES, COM, IND }
enum Feature { NONE, TREE, PARK }
enum Special { NONE, COAL, WIND, POLICE, FIRE, SCHOOL, HOSPITAL, LIBRARY, CINEMA, TOWNHALL, THEATER, STADIUM }
enum Road { NONE, STREET }
enum Transit { NONE, BUS_STOP, STATION }

# ---- Öffentlicher Verkehr ----
const COST_BUS_STOP := 150
const COST_RAIL := 40
const COST_STATION := 800
const UPKEEP_BUS_STOP := 4.0
const UPKEEP_RAIL := 0.5
const UPKEEP_STATION := 15.0
const BUS_RANGE := 3                    # Einzugsbereich Haltestelle (Tiles)
const BUS_TRAFFIC := 0.1                # Straßenlast je Busfahrer (1 Bus ersetzt ~10 Autos)
const STATION_WALK := 4                 # Fußweg zum Bahnhof (Tiles)
const STATION_TRANSFER := 4.0           # Umsteige-/Wartezeit in Wegkosten
const WALK_COST := 1.3                  # Wegkosten je Tile zu Fuß
const RAIL_COST := 0.3                  # Wegkosten je Gleis-Tile (schnell)
const RAIL_CAPACITY := 2500.0
const BUS_WAIT := 2.0                   # Wartezeit Zubringerbus (Wegkosten)
const BUS_FEEDER_COST := 0.5            # Wegkosten je Tile im Zubringerbus
const LAND_TRANSIT := 0.08              # Bodenwert-Bonus mit Bus- oder Bahnanschluss

# Straßen: Kapazität (Pendler/Monat ohne Stau) und Tempo. Zwei parallele, benachbarte
# Straßen verschmelzen automatisch zur 4-spurigen Hauptstraße (mehr Kapazität, schneller).
const COST_ROAD := 10
const UPKEEP_ROAD := 0.4
const STREET_CAPACITY := 300.0
const STREET_SPEED := 1.0
const WIDE_CAPACITY := 450.0            # je Tile der Hauptstraße (Paar: 900 statt 600)
const WIDE_SPEED := 1.35

# ---- Standortregeln (siehe README "Zonen richtig planen") ----
# Verschmutzung: Quelle -> [Stärke, Reichweite in Tiles], linear abfallend
const POLLUTION_IND_PER_LEVEL := [0.0, 1.2, 2.0, 3.0]
const POLLUTION_IND_RANGE := 4
const POLLUTION_COAL := 4.0
const POLLUTION_COAL_RANGE := 7
const POLLUTION_TRAFFIC := 1.2          # bei Auslastung 1.0
const POLLUTION_TRAFFIC_RANGE := 2
# Grün filtert Verschmutzung: je Baum/Park im Umkreis von 2 Tiles (5x5) weniger Verschmutzung am Tile
const GREEN_FILTER_TREE := 0.05
const GREEN_FILTER_PARK := 0.08
const GREEN_FILTER_MAX := 0.7           # höchstens 70 % weggefiltert
const GREEN_FILTER_RANGE := 2
# ---- Steuern je Zone: neutraler Satz und Empfindlichkeit der Nachfrage (Industrie nimmt mehr hin) ----
const TAX_NEUTRAL := [0.0, 0.09, 0.09, 0.12]       # Index = Zone (RES, COM, IND)
const TAX_DEMAND := [0.0, 5.0, 4.0, 2.5]           # Nachfrage-Abzug je Steuerpunkt über neutral (x 100)
const TAX_HAPPY := 2.0                             # Zufriedenheit: nur die Wohnsteuer
const TAX_MAX := 0.2

# ---- ÖPNV-Tarif: 0 kostenlos, 1 normal, 2 teuer ----
const FARE_NAMES := ["kostenlos", "normal", "teuer"]
const FARE_PRICE := [0.0, 0.10, 0.20]              # $ je Fahrgast und Monat
const FARE_PATH_COST := [-1.5, 0.0, 2.0]           # Bahn: Aufschlag auf Einstiegskosten (Routenwahl)
const FARE_BUS_SHARE := [0.55, 0.4, 0.25]          # Busanteil, wenn Start + Ziel an Haltestellen
const FARE_HAPPY := [0.05, 0.0, -0.03]             # Zufriedenheit für Wohnhäuser mit Bus-/Bahnanschluss

# ---- Zonen-Idealformen ----
const COM_MAX_LEVEL_BY_DEPTH := [3, 3, 3, 2]       # Gewerbe = Ladenzeile: Stufe je Abstand zur Straße (1 = direkt dran)
const COM_DEPTH_GROWTH := [1.0, 1.0, 0.8, 0.6]     # ... und Wachstum je Abstand
const COM_CORNER_LEVEL := [4, 6]                   # Weg entlang der Straße bis zur nächsten Kreuzung/Ecke: <=4 Stufe 3, <=6 Stufe 2, sonst 1
const COM_FRONT_BONUS := 1.3                       # Wachstum an Hauptstraße / Haltestelle
const IND_CLUSTER_RANGE := 2                       # Industrie = Ballung: Industrie-Tiles im 5x5 ringsum
const IND_CLUSTER_LEVEL := [0, 3, 8]               # ab so vielen Nachbarn Stufe 2 bzw. 3
const IND_CLUSTER_GROWTH := 0.04                   # Wachstum 0.6 + 0.04 je Nachbar (max 1.6)
const RES_SHOP_RANGE := 4                          # Wohnen = Nachbarschaft: Gewerbe in 4 Tiles -> Bodenwert +
const RES_SHOP_BONUS := 0.05
const RES_DULL_RANGE := 6                          # kein Park/Wasser/Gewerbe in 6 Tiles -> Bodenwert -
const RES_DULL_MALUS := 0.08
# Villa: Wohnen Stufe 3 in Kleinsiedlung mit Top-Bodenwert -> wenige Bewohner, Bodenabgabe
const VILLA_LAND := 0.75
const VILLA_MAX_NEIGHBORS := 8                     # Wohn-Zonen im 5x5 ringsum (ohne eigenes)
const VILLA_POP := 16
const VILLA_LEVY := 6.0                            # $ je Villa und Monat

# Bodenwert 0..1
const LAND_BASE := 0.45
const LAND_WATER := 0.12                # Wasser in 3 Tiles
const LAND_PARK := 0.08                 # je Park in 3 Tiles (max 0.24); Bäume: nur Verschmutzungsfilter
const LAND_HEIGHT := 0.012              # je Block über Wasserniveau (Aussicht, max 0.1)
const LAND_POLLUTION := 0.09            # Abzug je Verschmutzungspunkt
const LAND_CONGESTION := 0.12           # Abzug je Auslastung der Zufahrt
# Wohnen: Mindest-Bodenwert je Stufe
const RES_MIN_LAND := [0.0, 0.0, 0.35, 0.55]
# Gewerbe: Kundschaft = Einwohner im Umkreis
const COM_CUSTOMER_RANGE := 6
const COM_CUSTOMERS_FULL := 300.0       # ab so vielen Einwohnern volle Wachstumsrate

# Sonderbauten: Größe (Tiles), Kosten, Unterhalt/Monat, Leistung (MW)
const SPECIALS := {
	Special.COAL: {"name": "Kohlekraftwerk", "size": 2, "cost": 3000, "upkeep": 25.0, "power": 400},
	Special.WIND: {"name": "Windrad", "size": 1, "cost": 450, "upkeep": 3.0, "power": 30},
	# Dienste/Kultur: Unterhalt je Stufe 1x / 2.2x / 3.8x, Ausbau kostet "upgrade" je Stufe
	Special.POLICE:   {"name": "Polizei", "size": 1, "cost": 900, "upgrade": 1200, "upkeep": 10.0, "power": 0, "service": "police"},
	Special.FIRE:     {"name": "Feuerwehr", "size": 1, "cost": 900, "upgrade": 1200, "upkeep": 10.0, "power": 0, "service": "fire"},
	Special.SCHOOL:   {"name": "Schule", "size": 1, "cost": 1200, "upgrade": 1500, "upkeep": 13.0, "power": 0, "service": "education"},
	Special.HOSPITAL: {"name": "Krankenhaus", "size": 2, "cost": 2500, "upgrade": 2500, "upkeep": 20.0, "power": 0, "service": "health"},
	Special.LIBRARY:  {"name": "Bibliothek", "size": 1, "cost": 1000, "upgrade": 1200, "upkeep": 7.0, "power": 0, "service": "culture", "unlock": 1000},
	Special.CINEMA:   {"name": "Kino", "size": 1, "cost": 1400, "upgrade": 1500, "upkeep": 6.0, "power": 0, "service": "culture", "unlock": 1000},
	Special.TOWNHALL: {"name": "Bürgerhaus", "size": 2, "cost": 4000, "upgrade": 4000, "upkeep": 18.0, "power": 0, "service": "culture", "unlock": 2000},
	# Großkultur: Besucher (je Stufe) = Kundschaft fürs Gewerbe ringsum + Verkehr an Veranstaltungstagen
	Special.THEATER:  {"name": "Theater", "size": 2, "cost": 8000, "upgrade": 6000, "upkeep": 35.0, "power": 0, "service": "venue",
		"unlock": 3000, "visitors": 300, "event_every": 1},
	Special.STADIUM:  {"name": "Stadion", "size": 3, "cost": 15000, "upgrade": 10000, "upkeep": 60.0, "power": 0, "service": "venue",
		"unlock": 5000, "visitors": 900, "event_every": 3},
}

# ---- Dienste, Zufriedenheit, Kriminalität ----
const SERVICE_RADIUS := [0, 6, 9, 12]           # Reichweite (Tiles) je Ausbaustufe
const SERVICE_CAPACITY := [0, 800, 2000, 4500]  # versorgte Einwohner je Stufe
const UPKEEP_LEVEL := [0.0, 1.0, 2.2, 3.8]
# Kategorie -> [Anzeigename, ab Einwohnerzahl erwartet, Gewicht für Zufriedenheit]
const SERVICES := {
	"police": ["Polizei", 300, 0.10],
	"fire": ["Feuerwehr", 300, 0.08],
	"education": ["Schule", 600, 0.12],
	"health": ["Krankenhaus", 600, 0.12],
	"culture": ["Kultur", 1500, 0.08],
	"venue": ["Großkultur", 4000, 0.08],
}
const HAPPY_BASE := 0.55
# Veranstaltungen (Theater/Stadion)
const VENUE_SHOP_RANGE := 5             # Gewerbe in diesem Umkreis bekommt Besucher als Kundschaft
const VENUE_SHOP_SHARE := 0.5           # Anteil der Besucher, der dort einkauft
const VENUE_TRAFFIC_RANGE := 3          # Straßen in diesem Umkreis tragen den Besucherverkehr
const VENUE_TRAFFIC := 2.5              # Besucher -> Pendler-Äquivalente (verteilt auf die Straßen)
const VENUE_TRANSIT_CUT := 0.4          # Bus/Bahn in 4 Tiles: so viel weniger Autoverkehr
const HAPPY_PARK := 0.03                # Zufriedenheit je Park im Umkreis von 3 Tiles ...
const HAPPY_PARK_MAX := 0.09            # ... höchstens
const HAPPY_LEAVE := 0.30               # darunter ziehen Leute weg
const HAPPY_ALERT_DROP := 0.08          # Abfall in 3 Monaten (bzw. 60 % davon in 1 Monat) -> Meldung

# ---- Brände (Zeiten in Sekunden bei Tempo 1, schneller bei höherem Tempo) ----
const FIRE_RISK := 0.002                # Ausbruch je Gebäude/Monat ohne Brandschutz, x (1 - Schutz)²
const FIRE_IND_FACTOR := 3.0            # Industrie brennt häufiger
const FIRE_GRACE_POP := 200             # kleine Dörfer brennen nicht (gilt nicht für Industrie)
const FIRE_JOB_WEIGHT := 0.5           # Arbeitsplätze zählen halb zur Auslastung der Feuerwache
const FIRE_IND_MIN_SHARE := 0.25        # Industrie: Restrisiko auch bei vollem Brandschutz (Feuerwehr löscht dann)
const FIRE_BURN_TIME := 10.0            # bis ein ungelöschtes Gebäude abbrennt
const FIRE_DAMAGE_AT := 0.6             # erst danach gelöscht -> Gebäude verliert 1 Stufe
const FIRE_SPREAD := 0.25               # je Nachbargebäude bei halbem Brand, x (1 - Schutz)²
const FIRE_EXTINGUISH_TIME := 2.5       # Löschen vor Ort
const FIRE_TRUCK_SPEED := 2.5           # Löschzug in Tiles/Sekunde
const FIRE_RUIN_MONTHS := 6             # Brandruine blockiert Neubau

# Stromverbrauch (MW) pro Gebäudestufe
const POWER_USE := {
	Zone.RES: [0, 1, 2, 4],
	Zone.COM: [0, 2, 4, 7],
	Zone.IND: [0, 3, 6, 10],
}

const START_MONEY := 20000.0
const CHEAT_MONEY := 50000.0          # Strg/Cmd + Shift + G
const START_YEAR := 2000

# Baukosten pro Tile
const COST_POWERLINE := 5
const COST_ZONE := 5
const COST_BULLDOZE := 2
const COST_BULLDOZE_BUILDING := 15
const COST_TERRAFORM := 30
const COST_TREE := 5
const COST_PARK := 80

# Unterhalt pro Monat
const UPKEEP_PARK := 3.0               # Parks: Pflege, Wege, Bänke (Bäume kostenlos)
const UPKEEP_POWERLINE := 0.1

# Kapazität pro Gebäudestufe (Index = Stufe 0..3)
const RES_CAPACITY := [0, 10, 30, 80]   # Einwohner
const COM_CAPACITY := [0, 8, 20, 50]    # Jobs
const IND_CAPACITY := [0, 12, 30, 60]   # Jobs

const ROAD_ACCESS_RANGE := 3            # max. Abstand Zone -> Straße (Tiles)

# Verkehr (rein visuell): 1 sichtbares Auto pro N Einwohner, gedeckelt
const CARS_PER_POP := 20
const MAX_CARS_PER_ROAD_TILE := 0.6
const MAX_CARS := 600

const ZONE_NAMES := ["Keine", "Wohnen", "Gewerbe", "Industrie"]
