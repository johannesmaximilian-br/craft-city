class_name Config
## Globale Konstanten: Kartengröße, Kosten, Simulationswerte.

const MAP_SIZE := 64
const TILE_BLOCKS := 3          # Blöcke pro Tile-Kante (1 Block = 1 Welteinheit)
const WATER_LEVEL := 3          # Tiles mit Höhe < WATER_LEVEL sind Wasser
const MAX_HEIGHT := 14
const SNOW_HEIGHT := 11

enum Zone { NONE, RES, COM, IND }
enum Feature { NONE, TREE, PARK }
enum Special { NONE, COAL, WIND, POLICE, FIRE, SCHOOL, HOSPITAL, LIBRARY, CINEMA, TOWNHALL }
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
const BUS_SHARE := 0.4                  # Anteil Pendler, die Bus fahren, wenn Start+Ziel versorgt
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
# Bodenwert 0..1
const LAND_BASE := 0.45
const LAND_WATER := 0.12                # Wasser in 3 Tiles
const LAND_TREE := 0.015                # je Baum in 3 Tiles (max 0.15)
const LAND_PARK := 0.08                 # je Park in 3 Tiles (max 0.24)
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
}
const HAPPY_BASE := 0.55
const HAPPY_LEAVE := 0.30               # darunter ziehen Leute weg
const FIRE_RISK := 0.002                # Brandrisiko je Gebäude/Monat ohne Feuerwehr
const FIRE_GRACE_POP := 200             # kleine Dörfer brennen nicht

# Stromverbrauch (MW) pro Gebäudestufe
const POWER_USE := {
	Zone.RES: [0, 1, 2, 4],
	Zone.COM: [0, 2, 4, 7],
	Zone.IND: [0, 3, 6, 10],
}

const START_MONEY := 20000.0
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
const UPKEEP_PARK := 1.5
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
