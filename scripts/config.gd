class_name Config
## Globale Konstanten: Kartengröße, Kosten, Simulationswerte.

const MAP_SIZE := 128
const TILE_BLOCKS := 3          # Blöcke pro Tile-Kante (1 Block = 1 Welteinheit)
const WATER_LEVEL := 3          # Tiles mit Höhe < WATER_LEVEL sind Wasser
const MAX_HEIGHT := 14
const SNOW_HEIGHT := 11

enum Zone { NONE, RES, COM, IND }
enum Feature { NONE, TREE, PARK }
enum Special { NONE, COAL, WIND, POLICE, FIRE, SCHOOL, HOSPITAL, LIBRARY, CINEMA, TOWNHALL, THEATER, STADIUM,
	LUMBER, QUARRY, PIT, MINE, WAREHOUSE, SAWMILL, BRICKWORKS, GLASSWORKS, STEELWORKS, NURSERY, PROSPECTOR, RECYCLER,
	UNIVERSITY, INSTITUTE, BIOMASS, SOLAR, BATTERY, HYDRO, PUMPED, SALT }
# Bodenvorkommen (CityMap.ore): Art je Tile, Menge in CityMap.ore_amt
enum Ore { NONE, COAL, IRON, GOLD, CLAY, SAND, STONE }
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
const STATION_CAPACITY := 1500.0        # Ein-/Aussteiger je Bahnhof und Monat
const STATION_CROWD_COST := 3.0         # Wegkosten-Aufschlag am Bahnhof: k * Auslastung^2 (Auslastung max 4)
const STATION_HARD_LIMIT := 1.5         # ab 150 % Ein-/Aussteiger im Monat ist der Bahnhof dicht (Pendler weichen aus)
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
# ---- Rohstoffe ----
# Lager-Reihenfolge = Anzeige-Reihenfolge. price = Exportpreis je Einheit (Überschuss über der Lagerkapazität)
const RESOURCES := {
	"wood":  {"name": "Holz",  "price": 1.0,  "color": Color("8a5a2b")},
	"stone": {"name": "Stein", "price": 0.5,  "color": Color("9a9a9a")},
	"sand":  {"name": "Sand",  "price": 0.5,  "color": Color("e6d38c")},
	"clay":  {"name": "Ton",   "price": 0.8,  "color": Color("b7845f")},
	"coal":  {"name": "Kohle", "price": 1.5,  "color": Color("2b2d33")},
	"iron":  {"name": "Eisen", "price": 3.0,  "color": Color("c8875a")},
	"gold":  {"name": "Gold",  "price": 12.0, "color": Color("f2c12e")},
	# Baustoffe (aus der Verarbeitung)
	"planks": {"name": "Bretter", "price": 2.5, "color": Color("c89a5a"), "good": true},
	"bricks": {"name": "Ziegel",  "price": 2.5, "color": Color("b5503a"), "good": true},
	"glass":  {"name": "Glas",    "price": 4.0, "color": Color("9fd3ee"), "good": true},
	"steel":  {"name": "Stahl",   "price": 8.0, "color": Color("6f7a86"), "good": true},
}
const ORE_RESOURCE := ["", "coal", "iron", "gold", "clay", "sand", "stone"]   # Index = Ore
const STOCK_BASE := 200            # Lagerkapazität je Rohstoff ohne Lagerhaus
const STOCK_WAREHOUSE := 1000      # zusätzlich je Lagerhaus (je Ausbaustufe)
# Abbau je Monat (Ausbaustufe x): Holzfäller fällt Bäume, Grube/Mine entnehmen Vorkommen im Umkreis
const LUMBER_RANGE := 4
const LUMBER_TREES := 2            # Bäume je Monat
const WOOD_PER_TREE := 10
const QUARRY_STONE := 20           # Stein je Monat aus Fels im Umkreis
const QUARRY_RANGE := 2
const PIT_RANGE := 2
const PIT_RATE := 10               # Sand/Ton je Monat
const MINE_RANGE := 3
const MINE_RATE := {"coal": 15, "iron": 10, "gold": 3}
# Baustoffbedarf beim Wachsen auf Stufe 2/3 (ab MATERIAL_FROM_POP Einwohnern). Fehlt etwas, wird es zugekauft
# (IMPORT_FACTOR x Exportpreis); ohne Geld dafür stoppt das Wachstum.
const MATERIAL_FROM_POP := 400
const IMPORT_FACTOR := 3.0         # Zukauf = 3× Exportpreis (bei 2× lohnten eigene Minen/Werke kaum: 4 % der Ausgaben)
const MATERIAL_COST := {
	Zone.RES: [{}, {}, {"planks": 4, "bricks": 4}, {"bricks": 8, "glass": 4, "steel": 3}],
	Zone.COM: [{}, {}, {"planks": 3, "bricks": 3, "glass": 2}, {"bricks": 4, "glass": 8, "steel": 6}],
	Zone.IND: [{}, {}, {"planks": 4, "bricks": 4}, {"bricks": 6, "steel": 8}],
}
# Baumaterial beim Bauen (aus dem Lager, Fehlendes wird sofort zum Zukaufpreis bezahlt). Je Tile bzw. je Gebäude.
const BUILD_MATERIALS := {
	"road": {"stone": 2}, "rail": {"stone": 2, "steel": 1}, "powerline": {"wood": 1},
	"bus_stop": {"steel": 2}, "station": {"bricks": 20, "steel": 5, "glass": 4}, "park": {"wood": 4},
}
const UPGRADE_MATERIALS := 0.5      # Ausbau eines Sonderbaus: Baumaterial × aktuelle Stufe × Faktor
const SPECIAL_MATERIALS := {        # Zukaufwert ca. 15-25 % des Geldpreises
	Special.COAL: {"bricks": 60, "steel": 30},
	Special.WIND: {"steel": 6},
	Special.BIOMASS: {"bricks": 30, "wood": 40},
	Special.SOLAR: {"glass": 40, "steel": 15, "gold": 4},
	Special.BATTERY: {"steel": 25, "gold": 8},
	Special.HYDRO: {"stone": 200, "bricks": 80, "steel": 40},
	Special.PUMPED: {"stone": 160, "steel": 50, "gold": 6},
	Special.SALT: {"sand": 150, "steel": 40, "gold": 10},
	Special.POLICE: {"bricks": 20, "planks": 6, "glass": 2},
	Special.FIRE: {"bricks": 20, "planks": 6, "glass": 2},
	Special.SCHOOL: {"bricks": 25, "planks": 10, "glass": 6},
	Special.HOSPITAL: {"bricks": 50, "glass": 20, "steel": 6},
	Special.LIBRARY: {"bricks": 20, "planks": 10, "glass": 4},
	Special.CINEMA: {"bricks": 25, "glass": 10, "steel": 4},
	Special.TOWNHALL: {"bricks": 80, "glass": 20, "steel": 10},
	Special.THEATER: {"bricks": 150, "glass": 40, "steel": 30},
	Special.STADIUM: {"stone": 300, "bricks": 150, "steel": 120},
	Special.UNIVERSITY: {"stone": 100, "bricks": 200, "glass": 60, "steel": 40},
	Special.INSTITUTE: {"bricks": 80, "glass": 40, "steel": 30},
	Special.LUMBER: {"wood": 30, "planks": 10},
	Special.QUARRY: {"wood": 40, "steel": 6},
	Special.PIT: {"wood": 20},
	Special.MINE: {"wood": 60, "stone": 40, "steel": 25},
	Special.WAREHOUSE: {"planks": 30, "bricks": 20},
	Special.NURSERY: {"wood": 15},
	Special.PROSPECTOR: {"planks": 10, "steel": 8},
	Special.RECYCLER: {"bricks": 30, "steel": 15},
	Special.SAWMILL: {"wood": 50, "stone": 40},          # ohne Baustoffe baubar (Henne-Ei)
	Special.BRICKWORKS: {"wood": 30, "stone": 80},
	Special.GLASSWORKS: {"bricks": 40, "stone": 40},
	Special.STEELWORKS: {"bricks": 80, "stone": 80},
}
const BIOMASS_WOOD_USE := 20       # Holz je Monat und Biomassekraftwerk (fehlt es: Zukauf, konkurriert mit dem Sägewerk)
const SALT_CONVERT := 0.5          # Kohlekraftwerk zum Salzspeicher umrüsten: Anteil von Preis und Material
const HYDRO_MIN_WATER := 3         # Wasserkraft: so viele Wasser-Tiles direkt am Gebäude (Rand)
const PUMPED_MIN_HEIGHT := 3       # Pumpspeicher: Blöcke über dem Wasserspiegel ...
const PUMPED_WATER_RANGE := 4      # ... und Wasser in diesem Umkreis
const NIGHT_DEMAND := 0.75         # nachts brauchen Gebäude 75 % des Tagesbedarfs
const COAL_PLANT_USE := 8         # Kohle je Monat und Kohlekraftwerk (fehlt sie: Zukauf)
# ---- Erneuerung ----
const FOREST_SPREAD := 0.01        # Chance je Monat: Lücke im Wald (5+ von 8 Nachbarn Baum) wächst zu
const FOREST_GAP := 5               # Nachbarn (inkl. Diagonalen), ab denen eine Lücke zuwächst; Waldränder wachsen nicht
const FOREST_MAX_SHARE := 0.25      # natürliche Ausbreitung stoppt, wenn so viel Land bewaldet ist
const NURSERY_MAX_SHARE := 0.5      # Baumschule pflanzt nur, bis so viel ihres Umkreises Wald ist
const NURSERY_RANGE := 4
const NURSERY_TREES := 2           # Bäume je Monat und Stufe
const ORE_REGROW := 1.0 / 24.0     # Chance je Monat und Vorkommen-Tile (unter Startmenge): +1 Punkt (= ORE_UNIT)
const PROSPECT_RANGE := 8
const PROSPECT_CHANCE := 0.08
const PROSPECT_MIN := 40            # gefundene Restadern: 40..ORE_MIN Einheiten je Tile (kleiner als Startvorkommen)      # je Monat und Stufe: neue Ader (Kohle/Eisen/Gold, 3-6 Tiles) gefunden
const RECYCLE_SHARE := 0.4         # Anteil der verbauten Baustoffe, der beim Abriss zurückkommt ...
const RECYCLE_SHARE_YARD := 0.8    # ... mit Recyclinghof
const LOCAL_BUFFER := 50           # eigener Vorrat je Stufe für Abbau ohne Straße zum Lager
const ORE_MIN := 120               # Startmenge je Vorkommen-Tile (bis 255) ...
const ORE_UNIT := 10               # ... je Punkt 10 Einheiten Rohstoff (eine Ader hält Jahrzehnte)

# ---- Steuern je Zone: neutraler Satz und Empfindlichkeit der Nachfrage (Industrie nimmt mehr hin) ----
const TAX_NEUTRAL := [0.0, 0.09, 0.09, 0.12]       # Index = Zone (RES, COM, IND)
const TAX_DEMAND := [0.0, 5.0, 4.0, 2.5]           # Nachfrage-Abzug je Steuerpunkt über neutral (x 100)
const TAX_HAPPY := 2.0                             # Zufriedenheit: nur die Wohnsteuer; Bonus je Punkt unter neutral
const TAX_HAPPY_UP := 4.0                          # Abzug je Punkt über neutral ...
const TAX_HAPPY_SQ := 40.0                         # ... plus quadratisch: +1 -> -4,4 %, +3 -> -16 %, +6 -> -38 %
# Verwaltung: Ausgabe/Monat = ADMIN_RATE × (Einw. - ADMIN_FROM)² / ADMIN_SCALE -> große Städte werden nicht endlos reich
const ADMIN_FROM := 5000
const ADMIN_RATE := 0.06
const ADMIN_SCALE := 50000.0
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
const VILLA_KEEP_LAND := 0.70                      # darunter (oder zu dicht bebaut) verfällt die Villa zum Einfamilienhaus
const VILLA_DECAY := 0.05                          # Chance je Monat

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

# Sonderbauten: Größe (Tiles), Kosten, Unterhalt/Monat, Leistung (MW), "use" = Verbrauch (MW) bei Stufe 1 (x SERVICE_POWER_LEVEL)
const SPECIALS := {
	Special.COAL: {"name": "Kohlekraftwerk", "size": 2, "cost": 3000, "upkeep": 25.0, "power": 400},
	Special.WIND: {"name": "Windrad", "size": 1, "cost": 450, "upkeep": 3.0, "power": 30},
	# Energie (Forschung Schritt 2): Biomasse ohne Forschung, Solar/Batterie mit
	Special.BIOMASS: {"name": "Biomassekraftwerk", "size": 2, "cost": 1200, "upkeep": 8.0, "power": 60,
		"pollution": [2.0, 5]},
	Special.SOLAR: {"name": "Solarfeld", "size": 2, "cost": 2500, "upkeep": 4.0, "power": 50, "solar": true,
		"need_tech": "solar"},
	Special.BATTERY: {"name": "Batteriespeicher", "size": 1, "cost": 3000, "upkeep": 10.0, "power": 0, "storage_mw": 40,
		"need_tech": "battery"},
	# Teil B: Standortregeln über "site" (ToolController.site_reason)
	Special.HYDRO: {"name": "Wasserkraftwerk", "size": 2, "cost": 9000, "upkeep": 20.0, "power": 120, "need_tech": "hydro",
		"site": "water"},
	Special.PUMPED: {"name": "Pumpspeicher", "size": 2, "cost": 7000, "upkeep": 15.0, "power": 0, "storage_mw": 150,
		"need_tech": "pumped", "site": "hill"},
	Special.SALT: {"name": "Salzspeicher", "size": 2, "cost": 8000, "upkeep": 12.0, "power": 0, "storage_mw": 300,
		"need_tech": "salt"},
	# Dienste/Kultur: Unterhalt je Stufe 1x / 2.2x / 3.8x, Ausbau kostet "upgrade" je Stufe
	Special.POLICE:   {"name": "Polizei", "size": 1, "cost": 900, "upgrade": 1200, "upkeep": 10.0, "power": 0, "use": 1, "service": "police"},
	Special.FIRE:     {"name": "Feuerwehr", "size": 1, "cost": 900, "upgrade": 1200, "upkeep": 10.0, "power": 0, "use": 1, "service": "fire"},
	Special.SCHOOL:   {"name": "Schule", "size": 1, "cost": 1200, "upgrade": 1500, "upkeep": 13.0, "power": 0, "use": 2, "service": "education"},
	Special.HOSPITAL: {"name": "Krankenhaus", "size": 2, "cost": 2500, "upgrade": 2500, "upkeep": 20.0, "power": 0, "use": 5, "service": "health"},
	Special.LIBRARY:  {"name": "Bibliothek", "size": 1, "cost": 1000, "upgrade": 1200, "upkeep": 7.0, "power": 0, "use": 1, "service": "culture", "unlock": 1000},
	Special.CINEMA:   {"name": "Kino", "size": 1, "cost": 1400, "upgrade": 1500, "upkeep": 6.0, "power": 0, "use": 2, "service": "culture", "unlock": 1000},
	Special.TOWNHALL: {"name": "Bürgerhaus", "size": 2, "cost": 4000, "upgrade": 4000, "upkeep": 18.0, "power": 0, "use": 3, "service": "culture", "unlock": 2000},
	# Großkultur: Besucher (je Stufe) = Kundschaft fürs Gewerbe ringsum + Verkehr an Veranstaltungstagen
	# Rohstoff-Abbau (kein Dienst, aber Strom und Unterhalt)
	Special.LUMBER:    {"name": "Holzfäller", "size": 1, "cost": 600, "upgrade": 800, "upkeep": 4.0, "power": 0, "use": 1,
		"produce": "wood"},
	Special.QUARRY:    {"name": "Steinbruch", "size": 2, "cost": 1500, "upgrade": 1500, "upkeep": 8.0, "power": 0, "use": 3,
		"produce": "stone"},
	Special.PIT:       {"name": "Grube (Sand/Ton)", "size": 1, "cost": 500, "upgrade": 700, "upkeep": 3.0, "power": 0, "use": 1,
		"produce": "pit"},
	Special.MINE:      {"name": "Mine", "size": 2, "cost": 3000, "upgrade": 3000, "upkeep": 12.0, "power": 0, "use": 4,
		"produce": "mine"},
	Special.WAREHOUSE: {"name": "Lagerhaus", "size": 2, "cost": 1200, "upgrade": 1200, "upkeep": 5.0, "power": 0, "use": 1,
		"storage": true},
	# Verarbeitung je Monat (x Ausbaustufe): "in" wird verbraucht, "out" erzeugt; Teilmengen, wenn Rohstoff knapp
	Special.NURSERY:    {"name": "Baumschule", "size": 1, "cost": 400, "upgrade": 500, "upkeep": 3.0, "power": 0, "use": 1,
		"renew": "trees"},
	Special.PROSPECTOR: {"name": "Prospektor", "size": 1, "cost": 1500, "upgrade": 1500, "upkeep": 10.0, "power": 0, "use": 1,
		"renew": "prospect"},
	Special.RECYCLER:   {"name": "Recyclinghof", "size": 2, "cost": 2000, "upkeep": 8.0, "power": 0, "use": 2,
		"renew": "recycle"},
	Special.SAWMILL:    {"name": "Sägewerk", "size": 2, "cost": 1500, "upgrade": 1500, "upkeep": 6.0, "power": 0, "use": 2,
		"process": {"in": {"wood": 10}, "out": {"planks": 10}}},
	Special.BRICKWORKS: {"name": "Ziegelei", "size": 2, "cost": 1800, "upgrade": 1800, "upkeep": 7.0, "power": 0, "use": 3,
		"process": {"in": {"clay": 10, "coal": 2}, "out": {"bricks": 10}}, "pollution": [1.0, 3]},
	Special.GLASSWORKS: {"name": "Glashütte", "size": 2, "cost": 2500, "upgrade": 2500, "upkeep": 9.0, "power": 0, "use": 4,
		"process": {"in": {"sand": 10, "coal": 3}, "out": {"glass": 8}}, "pollution": [1.5, 4]},
	Special.STEELWORKS: {"name": "Stahlwerk", "size": 2, "cost": 4000, "upgrade": 4000, "upkeep": 14.0, "power": 0, "use": 6,
		"process": {"in": {"iron": 10, "coal": 5}, "out": {"steel": 8}}, "pollution": [2.5, 5]},
	Special.THEATER:  {"name": "Theater", "size": 2, "cost": 8000, "upgrade": 6000, "upkeep": 35.0, "power": 0, "use": 5, "service": "venue",
		"unlock": 3000, "visitors": 300, "event_every": 1},
	Special.STADIUM:  {"name": "Stadion", "size": 3, "cost": 15000, "upgrade": 10000, "upkeep": 60.0, "power": 0, "use": 12, "service": "venue",
		"unlock": 5000, "visitors": 900, "event_every": 3},
	# Forschung: Uni = Dienst "university" (Akademikerquote), Institut erzeugt Forschungspunkte
	Special.UNIVERSITY: {"name": "Universität", "size": 3, "cost": 15000, "upgrade": 10000, "upkeep": 60.0, "power": 0, "use": 8,
		"service": "university", "unlock": 8000, "need_coverage": ["education", 0.7], "radius_mul": 2.5, "capacity_mul": 4.0},
	Special.INSTITUTE: {"name": "Forschungsinstitut", "size": 2, "cost": 8000, "upgrade": 8000, "upkeep": 40.0, "power": 0, "use": 6,
		"research": true, "need_special": Special.UNIVERSITY},
}
# ---- Forschung ----
const RESEARCH_POINTS := 30          # Punkte je Monat und Institutsstufe bei genug Akademikern und Referenzbudget
const ACADEMICS_PER_LEVEL := 1500    # Akademiker (von Unis versorgte Einwohner) je Institutsstufe für volle Leistung
const RESEARCH_BUDGET_REF := 1000.0  # Budget ($/Monat) für Faktor 1
const RESEARCH_BUDGET_STEPS := [0, 250, 500, 1000, 2000, 3000]
const RESEARCH_MIN_ACADEMICS := 0.1  # Untergrenze des Akademiker-Faktors (ein Institut forscht immer ein wenig)
# Projekte: group = Bereich im Forschungsfenster (aufklappbar), points = Forschungspunkte (×3 seit 23.10.: 1 Institut Stufe 1 + 1.000 $ ≈ 4 Jahre), gold = einmalig beim Start (fehlt es: Zukauf), requires = Vorgänger
const RESEARCH := {
	"deep_mining": {"group": "Rohstoffe & Industrie", "name": "Tiefbau", "desc": "Minen, Steinbrüche und Gruben fördern 50 % mehr",
		"points": 1500, "gold": 30, "requires": []},
	"efficient_build": {"group": "Rohstoffe & Industrie", "name": "Effiziente Bauweise", "desc": "25 % weniger Baumaterial beim Bauen und Wachsen",
		"points": 1800, "gold": 20, "requires": []},
	"plant_filter": {"group": "Energie", "name": "Kraftwerksfilter", "desc": "Kohlekraftwerke verschmutzen halb so viel",
		"points": 1500, "gold": 30, "requires": []},
	"solar": {"group": "Energie", "name": "Solarenergie", "desc": "Solarfeld bauen: 50 MW, aber nur tagsüber (nachts fehlt der Strom)",
		"points": 1800, "gold": 30, "requires": []},
	"battery": {"group": "Energie", "name": "Batteriespeicher", "desc": "Batterie speichert Tagesüberschuss und liefert nachts bis 40 MW",
		"points": 2100, "gold": 50, "requires": ["solar"]},
	"hydro": {"group": "Energie", "name": "Wasserkraft", "desc": "Wasserkraftwerk an Fluss/See: 120 MW Tag und Nacht, sauber, aber teuer",
		"points": 2400, "gold": 40, "requires": []},
	"pumped": {"group": "Energie", "name": "Pumpspeicher", "desc": "Pumpspeicher am Hang über Wasser: speichert 150 MW für die Nacht",
		"points": 2700, "gold": 50, "requires": ["battery"]},
	"salt": {"group": "Energie", "name": "Salzspeicher", "desc": "Flüssigsalz-Wärmespeicher (Carnot-Batterie): 300 MW für die Nacht, Kohlekraftwerke umrüstbar",
		"points": 3600, "gold": 80, "requires": ["pumped"]},
	"blast_furnace": {"group": "Rohstoffe & Industrie", "name": "Moderne Hochöfen", "desc": "Werke brauchen halb so viel Kohle und verschmutzen 40 % weniger",
		"points": 2100, "gold": 40, "requires": ["deep_mining"]},
}
const TECH_MINING := 1.5             # Faktor Förderung mit Tiefbau
const TECH_BUILD := 0.75             # Faktor Baumaterial mit effizienter Bauweise
const TECH_FILTER := 0.5             # Faktor Kraftwerks-Verschmutzung mit Filter
const TECH_FURNACE_COAL := 0.5       # Faktor Kohlebedarf der Werke mit modernen Hochöfen
const TECH_FURNACE_POLLUTION := 0.6

# ---- Dienste, Zufriedenheit, Kriminalität ----
const SERVICE_RADIUS := [0, 6, 9, 12]           # Reichweite (Tiles) je Ausbaustufe
const SERVICE_CAPACITY := [0, 800, 2000, 4500]  # versorgte Einwohner je Stufe
const UPKEEP_LEVEL := [0.0, 1.0, 2.2, 3.8]
const SERVICE_POWER_LEVEL := [0.0, 1.0, 1.5, 2.0]   # Stromverbrauch von Dienstbauten je Ausbaustufe
# Kategorie -> [Anzeigename, ab Einwohnerzahl erwartet, Gewicht für Zufriedenheit]
const SERVICES := {
	"police": ["Polizei", 300, 0.10],
	"fire": ["Feuerwehr", 300, 0.08],
	"education": ["Schule", 600, 0.12],
	"health": ["Krankenhaus", 600, 0.12],
	"culture": ["Kultur", 1500, 0.08],
	"venue": ["Großkultur", 4000, 0.08],
	"university": ["Hochschule", 8000, 0.04],
}
const HAPPY_BASE := 0.55
# Belegung / Leerstand
const OCC_DROP := 12                    # Belegung sinkt je Monat bei Verfall (%-Punkte): kein Strom/Straße/Erreichbarkeit
const OCC_DROP_UNHAPPY := 6             # ... bei Unzufriedenheit (langsamer: Zeit zum Gegensteuern)
const OCC_SOFT_FLOOR := 30              # sanfte Gründe (keine Nachfrage, zu groß für die Lage) leeren nie ganz
const OCC_DROP_DEMAND := 3              # ... nur wegen fehlender Nachfrage (betrifft alle Gebäude einer Zone -> sanft)
const OCC_RISE := 10                    # ... steigt sonst
const VACANT_MONTHS := 24               # so lange bleibt ein aufgegebenes Gebäude stehen, dann Abriss
const VACANT_RANGE := 3                 # Leerstand drückt die Zufriedenheit im Umkreis (Tiles) ...
const VACANT_HAPPY := 0.03              # ... je leerem Gebäude
const VACANT_HAPPY_MAX := 0.12          # ... höchstens (stärker -> Abwärtsspirale, gemessen mit --freshrun)
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
const START_YEAR := 1980

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
const CAR_TRIPS_PER_CAR := 11.0         # sichtbares Auto je so vielen Auto-Pendlern (Bus/Bahn-Fahrer fahren nicht Auto)
const MAX_CARS_PER_ROAD_TILE := 0.6
const MAX_CARS := 600

const ZONE_NAMES := ["Keine", "Wohnen", "Gewerbe", "Industrie"]
