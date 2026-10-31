class_name StructureGenerator
extends RefCounted
## Sonderbauten und Infrastruktur aus Blöcken. base = untere Ecke des Ursprungs-Tiles.

const POLE_HEIGHT := 3.4


## Kohlekraftwerk, 6x6 Blöcke: Halle (x 0-3), Schornstein + Kohlehaufen (x 4-5).
static var techs: Array[String] = []   # erforschte Projekte (main.gd setzt sie aus sim.research_done)


static func coal(b: BlockBatch, base: Vector3) -> void:
	for y in 3:
		for z in 6:
			for x in 4:
				if not (x == 0 or x == 3 or z == 0 or z == 5):
					continue
				var key := "ice" if y == 1 and (z == 2 or z == 3) else "greybrick"
				b.put(key, base + Vector3(x, y, z))
	for z in 6:
		for x in 4:
			b.put("metal", base + Vector3(x, 3, z))
	for y in 8:
		var key := "brick" if y == 6 else "greybrick"
		for p: Vector2i in [Vector2i(4, 1), Vector2i(5, 1), Vector2i(4, 2), Vector2i(5, 2)]:
			b.put(key, base + Vector3(p.x, y, p.y))
	for z in range(3, 6):
		b.put("coal", base + Vector3(4, 0, z))
		b.put("coal", base + Vector3(5, 0, z))
	b.put("coal", base + Vector3(5, 1, 4))
	b.put("crate", base + Vector3(4, 0, 0))
	if techs.has("plant_filter"):                                                             # Filteraufsatz
		b.put_box("metal", base + Vector3(5.0, 8.4, 2.0), Vector3(2.4, 0.8, 2.4))
		b.put_box("vox_white", base + Vector3(5.0, 8.9, 2.0), Vector3(1.8, 0.2, 1.8))
		b.put_box("metal", base + Vector3(3.0, 4.4, 1.0), Vector3(1.6, 0.8, 1.2))             # Filteranlage auf dem Dach
		b.segment("metal", base + Vector3(3.6, 4.6, 1.2), base + Vector3(4.2, 7.5, 1.6), 0.15)


## Windrad auf einem Tile (3x3 Blöcke). Rotor optional (für Animation separat).
static func wind_tower(b: BlockBatch, base: Vector3) -> void:
	var c := base + Vector3(1.5, 0, 1.5)
	b.put("concrete", base + Vector3(1, 0, 1))
	b.put_box("concrete", c + Vector3(0, 4.0, 0), Vector3(0.35, 7.0, 0.35))
	b.put_box("concrete", c + Vector3(0, 7.5, 0), Vector3(0.6, 0.6, 1.0))


static func wind_hub(base: Vector3) -> Vector3:
	return base + Vector3(1.5, 7.5, 2.05)


## Rotor um den Ursprung (für eigene, drehbare Instanz).
static func wind_rotor(b: BlockBatch, phase: float) -> void:
	for k in 3:
		var ang := phase + k * TAU / 3.0
		b.segment("concrete", Vector3.ZERO, Vector3(cos(ang), sin(ang), 0) * 2.8, 0.25)


## Gleisstück auf einem Tile (Kit-Gleise). conn: verbundene Richtungen (Vector2i).
## Gerade, Kurve (Kit-Kurve verbindet +X/+Z, wird gedreht) oder Kreuzung.
static func rail(b: BlockBatch, center: Vector3, conn: Array) -> void:
	var has := func(d: Vector2i) -> bool: return d in conn
	var x_axis: bool = has.call(Vector2i(1, 0)) or has.call(Vector2i(-1, 0))
	var z_axis: bool = has.call(Vector2i(0, 1)) or has.call(Vector2i(0, -1))
	if conn.size() == 2 and x_axis and z_axis:
		var dx := 1 if has.call(Vector2i(1, 0)) else -1
		var dz := 1 if has.call(Vector2i(0, 1)) else -1
		var rot := 0.0
		if dx == 1 and dz == -1: rot = PI * 0.5
		elif dx == -1 and dz == -1: rot = PI
		elif dx == -1 and dz == 1: rot = PI * 1.5
		b.put_prop("rail_corner", center, rot)
		return
	if x_axis or not z_axis:
		b.put_prop("rail_straight", center, 0.0)
	if z_axis:
		b.put_prop("rail_straight", center + Vector3(0, 0.005, 0), PI * 0.5)


## Bahnhof auf einem Gleis-Tile: Bahnsteige beidseitig, Pfeiler, Dächer, Schild.
static func station(b: BlockBatch, base: Vector3, along_x: bool) -> void:
	for side: float in [0.35, 2.65]:
		var plat := Vector3(1.5, 0.22, side) if along_x else Vector3(side, 0.22, 1.5)
		var plat_size := Vector3(3.0, 0.44, 0.7) if along_x else Vector3(0.7, 0.44, 3.0)
		b.put_box("square", base + plat, plat_size)
		var roof := Vector3(1.5, 2.5, side) if along_x else Vector3(side, 2.5, 1.5)
		var roof_size := Vector3(3.0, 0.2, 1.1) if along_x else Vector3(1.1, 0.2, 3.0)
		b.put_box("brick", base + roof, roof_size)
		for k: float in [0.4, 2.6]:
			var p := Vector3(k, 1.45, side) if along_x else Vector3(side, 1.45, k)
			b.put_box("log", base + p, Vector3(0.18, 2.0, 0.18))
	var sign := Vector3(1.5, 2.85, 0.35) if along_x else Vector3(0.35, 2.85, 1.5)
	b.put_box("vox_blue", base + sign, Vector3(0.9, 0.35, 0.1) if along_x else Vector3(0.1, 0.35, 0.9))


## Bushaltestelle an der Straßenecke: Pfosten mit Schild, Glasdach, Bank.
static func bus_stop(b: BlockBatch, base: Vector3) -> void:
	var c := base + Vector3(0.35, 0, 0.35)
	b.put_box("metal", c + Vector3(0, 0.8, 0), Vector3(0.08, 1.6, 0.08))
	b.put_box("vox_yellow", c + Vector3(0, 1.65, 0), Vector3(0.42, 0.42, 0.06))
	b.put_box("ice", c + Vector3(0.0, 1.3, 0.55), Vector3(0.7, 0.06, 0.5))
	b.put_box("metal", c + Vector3(-0.3, 0.65, 0.75), Vector3(0.06, 1.3, 0.06))
	b.put_box("wood", c + Vector3(0.0, 0.25, 0.65), Vector3(0.6, 0.1, 0.22))


## Quader-Hülle w x d Blöcke: Ecken corner, Fassade face; Fenster (window) jede 2. Fassadenzelle.
static func _hull(b: BlockBatch, base: Vector3, w: int, d: int, y0: int, floors: int,
		corner: String, face: String, window := "") -> void:
	for y in range(y0, y0 + floors):
		for z in d:
			for x in w:
				var edge_x := x == 0 or x == w - 1
				var edge_z := z == 0 or z == d - 1
				if not (edge_x or edge_z):
					continue
				var key := corner if edge_x and edge_z else face
				if window != "" and key == face and (x + z) % 2 == 1 and y > y0 - 1:
					key = window
				b.put(key, base + Vector3(x, y, z))


static func _roof(b: BlockBatch, base: Vector3, w: int, d: int, y: int, key: String) -> void:
	for z in d:
		for x in w:
			b.put(key, base + Vector3(x, y, z))


## Dienst-/Kulturgebäude. base = untere Ecke des Ursprungs-Tiles, lv = Ausbaustufe 1..3.
static func service(b: BlockBatch, base: Vector3, sp: int, lv: int) -> void:
	match sp:
		Config.Special.POLICE:
			var f := lv + 1
			_hull(b, base, 3, 3, 0, f, "greybrick", "greybrick", "ice")
			_roof(b, base, 3, 3, f, "darkbrick")
			b.put_box("vox_blue", base + Vector3(1.2, f + 1.2, 1.5), Vector3(0.35, 0.3, 0.35))   # Blaulicht
			b.put_box("vox_red", base + Vector3(1.8, f + 1.2, 1.5), Vector3(0.35, 0.3, 0.35))
			b.put_box("vox_blue", base + Vector3(1.5, 1.6, -0.03), Vector3(1.6, 0.4, 0.08))       # Schild
		Config.Special.FIRE:
			var f := lv + 1
			_hull(b, base, 3, 3, 0, f, "brick", "brick", "ice")
			b.put_box("vox_dark", base + Vector3(1.5, 0.6, -0.02), Vector3(1.6, 1.2, 0.06))       # Tor
			_roof(b, base, 3, 3, f, "metal")
			for y in range(f + 1, f + 2 + lv):                                                   # Schlauchturm
				b.put("brick", base + Vector3(2, y, 2))
			b.put("vox_red", base + Vector3(2, f + 2 + lv, 2))
		Config.Special.SCHOOL:
			var f := lv
			_hull(b, base, 3, 3, 0, f, "yellowbrick", "yellowbrick", "ice")
			_roof(b, base, 3, 3, f, "wood")
			b.put("wood", base + Vector3(1, f + 1, 1))
			b.put_box("metal", base + Vector3(0.2, f + 1.6, 0.2), Vector3(0.08, 3.2, 0.08))      # Fahnenmast
			b.put_box("vox_red", base + Vector3(0.55, f + 2.9, 0.2), Vector3(0.6, 0.4, 0.05))
		Config.Special.HOSPITAL:
			var f := lv + 2
			_hull(b, base, 6, 6, 0, f, "stone", "square", "ice")
			_roof(b, base, 6, 6, f, "square")
			# Rotes Kreuz auf dem Dach
			b.put_box("vox_red", base + Vector3(3, f + 1.05, 3), Vector3(3.0, 0.12, 1.0))
			b.put_box("vox_red", base + Vector3(3, f + 1.05, 3), Vector3(1.0, 0.12, 3.0))
			b.put_box("ice", base + Vector3(3, 0.8, -0.03), Vector3(2.0, 1.6, 0.08))             # Eingang
			if lv >= 3:
				b.put_box("vox_dark", base + Vector3(4.8, f + 1.05, 4.8), Vector3(1.6, 0.1, 1.6))   # Landeplatz
		Config.Special.LIBRARY:
			var f := lv
			_hull(b, base, 3, 3, 0, f, "brick", "brick", "ice")
			for x: float in [0.3, 1.5, 2.7]:                                                     # Säulen
				b.put_box("log", base + Vector3(x, f * 0.5, -0.25), Vector3(0.25, f, 0.25))
			b.put_box("stone", base + Vector3(1.5, f + 0.1, 1.3), Vector3(3.3, 0.2, 3.3))
			_roof(b, base, 3, 3, f, "darkbrick")
			b.put("darkbrick", base + Vector3(1, f + 1, 1))
		Config.Special.CINEMA:
			var f := lv + 1
			_hull(b, base, 3, 3, 0, f, "darkbrick", "darkbrick")
			b.put_box("cheese", base + Vector3(1.5, 1.4, -0.15), Vector3(3.2, 0.5, 0.3))          # Leuchtreklame
			b.put_box("vox_dark", base + Vector3(1.5, 0.5, -0.02), Vector3(1.2, 1.0, 0.06))
			_roof(b, base, 3, 3, f, "darkbrick")
			b.put_box("vox_red", base + Vector3(1.5, f + 1.5, 0.5), Vector3(1.8, 1.0, 0.15))      # Schild
		Config.Special.LUMBER:
			lumber(b, base, lv)
		Config.Special.QUARRY:
			quarry(b, base, lv)
		Config.Special.PIT:
			pit(b, base, lv)
		Config.Special.MINE:
			mine(b, base, lv)
		Config.Special.WAREHOUSE:
			warehouse(b, base, lv)
		Config.Special.SAWMILL:
			sawmill(b, base, lv)
		Config.Special.BRICKWORKS:
			brickworks(b, base, lv)
		Config.Special.GLASSWORKS:
			glassworks(b, base, lv)
		Config.Special.NURSERY:
			nursery(b, base, lv)
		Config.Special.PROSPECTOR:
			prospector(b, base, lv)
		Config.Special.RECYCLER:
			recycler(b, base, lv)
		Config.Special.UNIVERSITY:
			university(b, base, lv)
		Config.Special.BIOMASS:
			biomass(b, base)
		Config.Special.SOLAR:
			solar(b, base)
		Config.Special.BATTERY:
			battery(b, base)
		Config.Special.HYDRO:
			hydro(b, base)
		Config.Special.PUMPED:
			pumped(b, base)
		Config.Special.SALT:
			salt(b, base)
		Config.Special.INSTITUTE:
			institute(b, base, lv)
		Config.Special.STEELWORKS:
			steelworks(b, base, lv)
		Config.Special.THEATER:
			theater(b, base, lv)
		Config.Special.STADIUM:
			stadium(b, base, lv)
		Config.Special.TOWNHALL:
			var f := lv + 1
			_hull(b, base, 6, 6, 0, f, "stone", "greybrick", "ice")
			_roof(b, base, 6, 6, f, "darkbrick")
			for x: float in [0.6, 2.0, 4.0, 5.4]:                                                # Säulen
				b.put_box("log", base + Vector3(x, f * 0.5, -0.25), Vector3(0.3, f, 0.3))
			var tower := 2 + lv                                                                  # Uhrturm
			for y in range(f + 1, f + 1 + tower):
				b.put("wood", base + Vector3(2.5, y, 2.5))
				b.put("wood", base + Vector3(2.5, y, 3.5) - Vector3(0, 0, 1))
			b.put_box("vox_white", base + Vector3(3.0, f + tower - 0.5, 1.95), Vector3(0.8, 0.8, 0.08))
			b.put("brick", base + Vector3(2.5, f + 1 + tower, 2.5))


## Theater (6x6): Säulenfront, roter Vorhang-Giebel, hoher Bühnenturm hinten.
static func theater(b: BlockBatch, base: Vector3, lv: int) -> void:
	var f := lv + 2
	_hull(b, base, 6, 6, 0, f, "stone", "brick", "ice")
	_roof(b, base, 6, 6, f, "darkbrick")
	for x: float in [0.5, 1.8, 3.0, 4.2, 5.5]:                                               # Säulen
		b.put_box("stone", base + Vector3(x, f * 0.5, -0.35), Vector3(0.35, f, 0.35))
	b.put_box("stone", base + Vector3(3.0, f + 0.15, -0.2), Vector3(6.4, 0.3, 0.9))          # Gesims
	b.put_box("vox_red", base + Vector3(3.0, f + 0.9, 0.1), Vector3(4.0, 1.2, 0.2))          # Giebel/Vorhang
	b.put_box("cheese", base + Vector3(3.0, 1.0, -0.05), Vector3(2.0, 0.5, 0.1))             # Leuchtschild
	for y in range(f + 1, f + 2 + lv):                                                       # Bühnenturm
		for z in range(3, 6):
			for x in range(1, 5):
				if x == 1 or x == 4 or z == 3 or z == 5:
					b.put("brick", base + Vector3(x, y, z))
	_roof(b, base + Vector3(1, 0, 3), 4, 3, f + 2 + lv, "darkbrick")


## Biomassekraftwerk (6x6): Ziegel-Kesselhaus mit Schlot, großer Holzstapel, Förderband.
static func biomass(b: BlockBatch, base: Vector3) -> void:
	_hull(b, base + Vector3(0, 0, 2), 4, 4, 0, 3, "brick", "wood", "ice")
	_roof(b, base + Vector3(0, 0, 2), 4, 4, 3, "darkbrick")
	for y in range(0, 8):
		b.put("brick" if y < 7 else "darkbrick", base + Vector3(4, y, 4))                    # Schlot
	for k in 3:                                                                               # Holzstapel
		for j in 2 - (k / 2):
			b.put_box("log", base + Vector3(1.0 + k * 1.1, 0.3 + j * 0.55, 0.9), Vector3(1.0, 0.5, 1.4), PI * 0.5)
	b.segment("vox_dark", base + Vector3(3.6, 0.5, 1.0), base + Vector3(3.6, 2.4, 2.4), 0.3)    # Förderband
	b.put_box("vox_green", base + Vector3(5.2, 0.3, 1.0), Vector3(1.0, 0.6, 1.4))             # Hackschnitzel


## Solarfeld (6x6): Reihen schräger blauer Paneele auf Metallständern.
static func solar(b: BlockBatch, base: Vector3) -> void:
	for row in 3:
		var z := 1.0 + row * 2.0
		for col in 2:
			var x := 1.5 + col * 3.0
			b.put_box("metal", base + Vector3(x - 1.0, 0.3, z), Vector3(0.12, 0.6, 0.12))
			b.put_box("metal", base + Vector3(x + 1.0, 0.3, z), Vector3(0.12, 0.6, 0.12))
			b.put_xf("vox_blue", Transform3D(Basis(Vector3.RIGHT, -0.5).scaled(Vector3(2.8, 0.1, 1.6)),
				base + Vector3(x, 0.75, z)))
			b.put_xf("vox_white", Transform3D(Basis(Vector3.RIGHT, -0.5).scaled(Vector3(2.9, 0.06, 1.7)),
				base + Vector3(x, 0.7, z + 0.02)))
	b.put_box("metal", base + Vector3(5.4, 0.6, 5.4), Vector3(0.9, 1.2, 0.9))                # Wechselrichter


## Batteriespeicher (3x3): zwei Container-Module mit grünen Streifen, Kühlgitter.
static func battery(b: BlockBatch, base: Vector3) -> void:
	for k in 2:
		var z := 0.8 + k * 1.4
		b.put_box("metal", base + Vector3(1.5, 0.55, z), Vector3(2.6, 1.1, 1.1))
		b.put_box("vox_green", base + Vector3(1.5, 0.75, z - 0.56), Vector3(2.4, 0.18, 0.04))
		b.put_box("vox_dark", base + Vector3(1.5, 1.15, z), Vector3(1.6, 0.1, 0.7))           # Kühlgitter
	b.put_box("vox_yellow", base + Vector3(2.7, 0.35, 2.7), Vector3(0.4, 0.7, 0.4))           # Trafo


## Wasserkraftwerk (6x6): Staumauer aus Stein, Turbinenhaus, blaue Druckrohre, Auslauf.
static func hydro(b: BlockBatch, base: Vector3) -> void:
	for x in 6:                                                                               # Staumauer hinten
		for y in 4:
			b.put("stone" if y < 3 else "greybrick", base + Vector3(x, y, 5))
	_hull(b, base + Vector3(1, 0, 0), 4, 3, 0, 2, "greybrick", "stone", "ice")                # Turbinenhaus
	_roof(b, base + Vector3(1, 0, 0), 4, 3, 2, "metal")
	for x: float in [1.8, 3.0, 4.2]:                                                           # Druckrohre
		b.segment("vox_blue", base + Vector3(x, 3.6, 5.2), base + Vector3(x, 1.4, 3.0), 0.35)
	b.put_box("vox_glass", base + Vector3(3.0, 0.15, -0.3), Vector3(3.0, 0.3, 0.8))           # Auslauf
	b.put_box("vox_yellow", base + Vector3(5.4, 0.5, 1.0), Vector3(0.6, 1.0, 0.6))            # Trafo


## Pumpspeicher (6x6): Oberbecken mit Wasser, Druckrohr den Hang hinab, Pumpenhaus.
static func pumped(b: BlockBatch, base: Vector3) -> void:
	for z in range(2, 6):
		for x in 6:
			var edge := x == 0 or x == 5 or z == 2 or z == 5
			for y in 2:
				if edge:
					b.put("stone", base + Vector3(x, y, z))
	b.put_box("vox_glass", base + Vector3(3.0, 1.7, 3.5), Vector3(4.0, 0.2, 2.0))             # Wasser im Becken
	b.segment("vox_blue", base + Vector3(1.0, 1.5, 2.2), base + Vector3(1.0, 0.4, 0.4), 0.4)  # Druckrohr
	_hull(b, base + Vector3(3, 0, 0), 3, 2, 0, 1, "greybrick", "greybrick", "ice")            # Pumpenhaus
	_roof(b, base + Vector3(3, 0, 0), 3, 2, 1, "metal")


## Salzspeicher (6x6): zwei große Tanks (heiß/kalt), Wärmetauscher-Turm mit glühendem Band.
static func salt(b: BlockBatch, base: Vector3) -> void:
	for t: Vector2 in [Vector2(1.6, 2.0), Vector2(4.4, 2.0)]:
		b.put_box("metal", base + Vector3(t.x, 1.4, t.y), Vector3(2.4, 2.8, 2.4))
		b.put_box("vox_white", base + Vector3(t.x, 2.9, t.y), Vector3(2.2, 0.2, 2.2))
	b.put_box("cheese", base + Vector3(1.6, 1.4, 0.78), Vector3(2.0, 0.25, 0.06))             # heißer Tank: Glutband
	b.put_box("vox_blue", base + Vector3(4.4, 1.4, 0.78), Vector3(2.0, 0.25, 0.06))           # kalter Tank
	_hull(b, base + Vector3(2, 0, 4), 2, 2, 0, 4, "greybrick", "metal")                       # Wärmetauscher
	b.segment("metal", base + Vector3(1.6, 2.2, 3.2), base + Vector3(2.5, 2.2, 4.2), 0.25)
	b.segment("metal", base + Vector3(4.4, 2.2, 3.2), base + Vector3(3.5, 2.2, 4.2), 0.25)
	b.put_box("sand", base + Vector3(5.2, 0.3, 5.2), Vector3(1.0, 0.6, 1.0))                  # Salzvorrat


## Universität (9x9): Hauptgebäude mit Säulenportal und Kuppel vorn, zwei Seitenflügel, Rasen-Innenhof.
static func university(b: BlockBatch, base: Vector3, lv: int) -> void:
	var f := lv + 2
	_hull(b, base, 9, 3, 0, f, "stone", "yellowbrick", "ice")                                # Hauptgebäude
	_roof(b, base, 9, 3, f, "darkbrick")
	for x: float in [2.5, 3.6, 4.5, 5.4, 6.5]:                                               # Säulen
		b.put_box("stone", base + Vector3(x, f * 0.5, -0.35), Vector3(0.35, f, 0.35))
	b.put_box("stone", base + Vector3(4.5, f + 0.15, -0.2), Vector3(5.0, 0.3, 0.9))          # Gesims
	for y in 2:                                                                              # Kuppel
		b.put_box("metal", base + Vector3(4.5, f + 1.0 + y * 0.8, 1.5), Vector3(3.0 - y * 1.2, 0.8, 3.0 - y * 1.2))
	b.put_box("vox_yellow", base + Vector3(4.5, f + 2.8, 1.5), Vector3(0.3, 0.5, 0.3))
	var wing := lv + 1
	_hull(b, base + Vector3(0, 0, 3), 3, 6, 0, wing, "stone", "yellowbrick", "ice")          # Seitenflügel
	_roof(b, base + Vector3(0, 0, 3), 3, 6, wing, "darkbrick")
	_hull(b, base + Vector3(6, 0, 3), 3, 6, 0, wing, "stone", "yellowbrick", "ice")
	_roof(b, base + Vector3(6, 0, 3), 3, 6, wing, "darkbrick")
	b.put_box("vox_green", base + Vector3(4.5, 0.05, 6.0), Vector3(3.0, 0.1, 6.0))           # Innenhof
	b.put_box("stone", base + Vector3(4.5, 0.12, 6.0), Vector3(0.6, 0.1, 6.0))               # Weg
	b.put_prop("bush", base + Vector3(3.6, 0, 4.5), 0.0)
	b.put_prop("bush", base + Vector3(5.4, 0, 7.5), 1.2)


## Forschungsinstitut (6x6): moderner Glasbau, Labortrakt, Parabolantenne auf dem Dach.
static func institute(b: BlockBatch, base: Vector3, lv: int) -> void:
	var f := lv + 2
	_hull(b, base, 6, 4, 0, f, "stone", "ice", "")                                           # Glasfassade
	_roof(b, base, 6, 4, f, "greybrick")
	_hull(b, base + Vector3(0, 0, 4), 4, 2, 0, 2, "greybrick", "greybrick", "ice")           # Labortrakt
	_roof(b, base + Vector3(0, 0, 4), 4, 2, 2, "metal")
	b.put_box("metal", base + Vector3(4.5, f + 0.4, 2.0), Vector3(0.3, 0.8, 0.3))            # Antenne
	b.put_box("vox_white", base + Vector3(4.5, f + 1.0, 2.0), Vector3(1.6, 0.15, 1.6))       # Schüssel
	b.put_box("vox_blue", base + Vector3(3.0, 1.4, -0.05), Vector3(2.4, 0.4, 0.1))           # Schild
	if lv >= 2:
		b.put_box("metal", base + Vector3(1.5, f + 0.5, 1.5), Vector3(1.2, 1.0, 1.2))       # Rechenzentrum
	if lv >= 3:
		b.put_box("vox_red", base + Vector3(1.5, f + 1.2, 1.5), Vector3(0.3, 0.3, 0.3))


## Stadion (9x9): Tribünen-Ring (Höhe je Stufe), Rasen mit Linien, Flutlichtmasten in den Ecken.
static func stadium(b: BlockBatch, base: Vector3, lv: int) -> void:
	var h := lv + 1
	for z in 9:
		for x in 9:
			var ring := mini(mini(x, 8 - x), mini(z, 8 - z))                                 # 0 = Außenkante
			if ring >= 2:
				continue
			var corner := (x < 2 or x > 6) and (z < 2 or z > 6)
			if corner and (x == 0 or x == 8) and (z == 0 or z == 8):
				continue                                                                     # abgerundete Ecken
			var top := h - ring                                                              # Stufen nach innen
			for y in top:
				b.put("greybrick" if ring == 0 else "square", base + Vector3(x, y, z))
			if ring == 1:
				b.put_box("vox_red" if (x + z) % 2 == 0 else "vox_white",
					base + Vector3(x + 0.5, top + 0.1, z + 0.5), Vector3(0.8, 0.2, 0.8))         # Sitze
	b.put_box("vox_green", base + Vector3(4.5, 0.05, 4.5), Vector3(5.0, 0.1, 5.0))          # Rasen
	b.put_box("paint_white", base + Vector3(4.5, 0.12, 4.5), Vector3(0.1, 0.04, 4.6))        # Mittellinie
	b.put_box("paint_white", base + Vector3(4.5, 0.12, 4.5), Vector3(1.2, 0.04, 1.2))        # Anstoßkreis (eckig)
	b.put_box("vox_green", base + Vector3(4.5, 0.13, 4.5), Vector3(1.0, 0.04, 1.0))
	for p: Vector2 in [Vector2(0.5, 0.5), Vector2(8.5, 0.5), Vector2(0.5, 8.5), Vector2(8.5, 8.5)]:
		var mh := h + 3.0
		b.put_box("metal", base + Vector3(p.x, mh * 0.5, p.y), Vector3(0.2, mh, 0.2))         # Flutlicht
		b.put_box("vox_yellow", base + Vector3(p.x, mh + 0.2, p.y), Vector3(0.8, 0.5, 0.3))


## Holzfäller (3x3): Blockhütte, Stapel Stämme, Baumstumpf.
static func lumber(b: BlockBatch, base: Vector3, lv: int) -> void:
	for z in 2:
		for x in 2:
			b.put("log" if (x + z) % 2 == 0 else "wood", base + Vector3(x, 0, z))
			if lv >= 2:
				b.put("wood", base + Vector3(x, 1, z))
	_roof(b, base, 2, 2, 1 if lv < 2 else 2, "darkbrick")
	b.put_box("vox_dark", base + Vector3(1.0, 0.5, -0.03), Vector3(0.6, 1.0, 0.06))          # Tür
	for k in 2 + lv:                                                                         # Stämme gestapelt
		b.put_box("log", base + Vector3(2.5, 0.25 + (k / 2) * 0.5, 0.6 + (k % 2) * 0.9), Vector3(0.45, 0.45, 0.85))
	b.put_box("log", base + Vector3(0.6, 0.2, 2.4), Vector3(0.6, 0.4, 0.6))                    # Stumpf


## Steinbruch (6x6): abgestufte Steinwand, Geröll, Kran.
static func quarry(b: BlockBatch, base: Vector3, lv: int) -> void:
	for z in 6:
		for x in 6:
			var step := maxi(0, mini(x, z) - 1)          # Terrassen zur hinteren Ecke hin höher
			for y in mini(step, 2 + lv):
				b.put("stone", base + Vector3(x, y, z))
			if (x + z) % 3 == 0 and step == 0:
				b.put_box("stone", base + Vector3(x + 0.5, 0.2, z + 0.5), Vector3(0.4, 0.4, 0.4))   # Geröll
	var top := Vector3(1.0, 5.0 + lv, 1.0)
	b.segment("metal", base + Vector3(1.0, 0, 1.0), base + top, 0.25)                         # Kranmast
	b.segment("metal", base + top, base + top + Vector3(3.0, -0.5, 3.0), 0.18)                # Ausleger
	b.segment("coal", base + top + Vector3(3.0, -0.5, 3.0), base + Vector3(4.0, 1.2, 4.0), 0.05)
	b.put_box("stone", base + Vector3(4.0, 1.0, 4.0), Vector3(0.6, 0.5, 0.6))                 # Block am Haken
	b.put_box("vox_yellow", base + Vector3(0.6, 0.35, 4.6), Vector3(0.9, 0.5, 0.6))           # Lore
	if techs.has("deep_mining"):                                                              # Tiefbau: Förderband + Bagger
		b.segment("vox_dark", base + Vector3(4.5, 3.0 + lv * 0.5, 4.5), base + Vector3(1.0, 0.5, 5.0), 0.3)
		b.put_box("vox_yellow", base + Vector3(4.6, 2.2 + lv, 2.0), Vector3(1.2, 0.8, 0.9))
		b.segment("vox_yellow", base + Vector3(4.6, 2.6 + lv, 2.0), base + Vector3(3.4, 3.4 + lv, 1.0), 0.15)


## Grube (3x3): Sand- und Tonhaufen, kleiner Bagger.
static func pit(b: BlockBatch, base: Vector3, lv: int) -> void:
	b.put_box("sand", base + Vector3(0.9, 0.3, 0.9), Vector3(1.4, 0.6 + lv * 0.2, 1.4))
	b.put_box("sand", base + Vector3(0.9, 0.75 + lv * 0.1, 0.9), Vector3(0.8, 0.4, 0.8))
	b.put_box("clay", base + Vector3(2.2, 0.25, 2.2), Vector3(1.2, 0.5 + lv * 0.15, 1.2))
	b.put_box("vox_yellow", base + Vector3(2.2, 0.45, 0.8), Vector3(1.0, 0.6, 0.7))           # Bagger
	b.put_box("vox_dark", base + Vector3(2.2, 0.15, 0.8), Vector3(1.1, 0.3, 0.8))
	b.segment("vox_yellow", base + Vector3(1.8, 0.8, 0.8), base + Vector3(1.1, 1.3, 1.6), 0.15)
	b.put_prop("shovel", base + Vector3(0.4, 0, 2.5), 0.6)


## Mine (6x6): Förderturm mit Seilrad, Stolleneingang im Hang, Gleis mit Lore, Erzhaufen.
static func mine(b: BlockBatch, base: Vector3, lv: int) -> void:
	for z in range(3, 6):                                                                     # Hügel mit Stollen
		for x in range(0, 6):
			var hgt := 1 + (z - 3) + (1 if x in [2, 3] else 0)
			for y in hgt:
				if not (x in [2, 3] and z == 3 and y < 2):
					b.put("stone" if y > 0 else "dirt", base + Vector3(x, y, z))
	b.put_box("wood", base + Vector3(3.0, 2.05, 3.0), Vector3(2.2, 0.15, 0.3))                # Stollen-Rahmen
	b.put_box("log", base + Vector3(2.0, 1.0, 3.0), Vector3(0.2, 2.0, 0.2))
	b.put_box("log", base + Vector3(4.0, 1.0, 3.0), Vector3(0.2, 2.0, 0.2))
	var h := 6.0 + lv
	for c: Vector2 in [Vector2(0.5, 0.5), Vector2(2.0, 0.5), Vector2(0.5, 2.0), Vector2(2.0, 2.0)]:   # Förderturm
		b.segment("metal", base + Vector3(c.x, 0, c.y), base + Vector3(1.25, h, 1.25), 0.15)
	b.put_box("vox_red", base + Vector3(1.25, h + 0.3, 1.25), Vector3(1.4, 1.4, 0.15))        # Seilrad
	b.segment("coal", base + Vector3(1.25, h + 0.3, 1.25), base + Vector3(3.0, 1.5, 3.0), 0.05)
	for k in 4:                                                                               # Gleis + Lore
		b.put_box("wood", base + Vector3(3.0, 0.05, 2.6 - k * 0.7), Vector3(1.0, 0.1, 0.2))
	b.put_box("vox_dark", base + Vector3(3.0, 0.4, 1.0), Vector3(0.8, 0.5, 0.7))
	b.put_box("coal", base + Vector3(3.0, 0.7, 1.0), Vector3(0.6, 0.2, 0.5))
	b.put_box("coal", base + Vector3(5.0, 0.3, 0.8), Vector3(1.0, 0.6, 1.0))                  # Erzhaufen
	b.put_box("iron_ore", base + Vector3(5.0, 0.25, 2.0), Vector3(0.8, 0.5, 0.8))
	if techs.has("deep_mining"):                                                              # Tiefbau: Stahl-Förderturm
		var t := 9.0 + lv
		for c: Vector2 in [Vector2(4.2, 4.2), Vector2(5.8, 4.2), Vector2(4.2, 5.8), Vector2(5.8, 5.8)]:
			b.segment("metal", base + Vector3(c.x, 2.0, c.y), base + Vector3(5.0, t, 5.0), 0.18)
		b.put_box("vox_blue", base + Vector3(5.0, t + 0.4, 5.0), Vector3(1.8, 1.8, 0.2))      # großes Seilrad
		b.put_box("metal", base + Vector3(5.0, t - 0.6, 5.0), Vector3(1.2, 0.8, 1.2))         # Maschinenhaus
		b.segment("vox_dark", base + Vector3(5.0, 2.2, 4.0), base + Vector3(3.0, 0.6, 1.0), 0.3)   # Förderband


## Lagerhaus (6x6): große Halle aus Holz, Schieferdach, Kisten davor.
static func warehouse(b: BlockBatch, base: Vector3, lv: int) -> void:
	var f := 1 + lv
	_hull(b, base + Vector3(0, 0, 1), 6, 5, 0, f, "log", "wood")
	_roof(b, base + Vector3(0, 0, 1), 6, 5, f, "darkbrick")
	for x in range(1, 5):
		b.put("darkbrick", base + Vector3(x, f + 1, 3))
	b.put_box("vox_dark", base + Vector3(3.0, 0.9, 0.97), Vector3(2.0, 1.8, 0.06))            # Tor
	for p: Vector3 in [Vector3(0.5, 0, 0.3), Vector3(1.3, 0, 0.3), Vector3(5.2, 0, 0.3)]:
		b.put("crate", base + p - Vector3(0.5, 0, 0.0))
	b.put("crate", base + Vector3(0.4, 1, 0.0))


## Sägewerk (6x6): offene Halle mit Sägeblatt, Stammstapel, Bretterstapel.
static func sawmill(b: BlockBatch, base: Vector3, lv: int) -> void:
	for p: Vector2 in [Vector2(0.5, 1.5), Vector2(3.5, 1.5), Vector2(0.5, 4.5), Vector2(3.5, 4.5)]:
		b.put_box("log", base + Vector3(p.x, 1.25, p.y), Vector3(0.35, 2.5, 0.35))            # Pfosten
	b.put_box("darkbrick", base + Vector3(2.0, 2.6, 3.0), Vector3(4.2, 0.25, 3.8))           # Dach
	b.put_box("metal", base + Vector3(2.0, 0.6, 3.0), Vector3(2.6, 0.5, 0.8))                # Sägetisch
	b.put_box("vox_white", base + Vector3(2.0, 1.0, 3.0), Vector3(0.9, 0.9, 0.08))           # Sägeblatt
	for k in 2 + lv:
		b.put_box("log", base + Vector3(5.0, 0.25 + (k / 2) * 0.5, 1.2 + (k % 2) * 0.9), Vector3(1.6, 0.45, 0.45))
		b.put_box("wood", base + Vector3(5.0, 0.12 + k * 0.25, 4.5), Vector3(1.4, 0.2, 1.0))   # Bretter


## Ziegelei (6x6): Brennofen aus Ziegeln mit hohem Schlot, Ziegelstapel, Tongrube.
static func brickworks(b: BlockBatch, base: Vector3, lv: int) -> void:
	_hull(b, base + Vector3(1, 0, 2), 4, 3, 0, 2, "brick", "darkbrick")
	_roof(b, base + Vector3(1, 0, 2), 4, 3, 2, "darkbrick")
	b.put_box("vox_dark", base + Vector3(3.0, 0.6, 1.97), Vector3(1.0, 1.2, 0.06))            # Ofenloch
	b.put_box("cheese", base + Vector3(3.0, 0.4, 1.94), Vector3(0.7, 0.5, 0.04))              # Glut
	for y in range(0, 5 + lv):
		b.put("brick", base + Vector3(4, y + 3, 4))                                            # Schlot
	for k in 3:
		b.put_box("brick", base + Vector3(0.8 + k * 1.2, 0.3, 0.6), Vector3(0.9, 0.6, 0.7))   # Ziegelstapel
	b.put_box("clay", base + Vector3(0.6, 0.2, 5.3), Vector3(1.0, 0.4, 1.0))
	if techs.has("blast_furnace"):
		_modern_furnace(b, base + Vector3(4.5, 8.0 + lv, 4.5), base + Vector3(5.2, 0, 1.0))


## Glashütte (6x6): Halle mit Schmelzofen (Glut), Glasblöcke, Schlot.
static func glassworks(b: BlockBatch, base: Vector3, lv: int) -> void:
	_hull(b, base + Vector3(0, 0, 1), 5, 4, 0, 1 + lv, "stone", "greybrick", "ice")
	_roof(b, base + Vector3(0, 0, 1), 5, 4, 1 + lv, "metal")
	b.put_box("cheese", base + Vector3(2.5, 0.5, 0.97), Vector3(1.2, 0.8, 0.06))              # glühender Ofen
	for y in range(2 + lv, 6 + lv):
		b.put("greybrick", base + Vector3(4, y, 4))
	for k in 3:
		b.put_box("ice", base + Vector3(5.4, 0.35 + k * 0.6, 0.6), Vector3(0.55, 0.55, 0.55)) # Glasblöcke
	b.put_box("sand", base + Vector3(5.3, 0.25, 4.5), Vector3(1.0, 0.5, 1.0))
	if techs.has("blast_furnace"):
		_modern_furnace(b, base + Vector3(4.5, 6.0 + lv, 4.5), base + Vector3(5.2, 0, 2.6))


## Stahlwerk (6x6): dunkle Halle, zwei Schlote, Hochofen mit Glut, Stahlträger.
static func steelworks(b: BlockBatch, base: Vector3, lv: int) -> void:
	_hull(b, base, 6, 4, 0, 2 + lv, "darkbrick", "darkbrick", "metal")
	_roof(b, base, 6, 4, 2 + lv, "metal")
	b.put_box("cheese", base + Vector3(2.0, 0.6, -0.03), Vector3(1.4, 1.0, 0.06))             # Glut
	for c: Vector2i in [Vector2i(1, 2), Vector2i(4, 2)]:
		for y in range(3 + lv, 8 + lv):
			b.put("darkbrick" if y < 7 + lv else "brick", base + Vector3(c.x, y, c.y))
	b.put_box("iron_ore", base + Vector3(1.0, 0.3, 5.0), Vector3(1.2, 0.6, 1.0))              # Eisenerz
	for k in 2 + lv:
		b.put_box("metal", base + Vector3(4.2, 0.1 + k * 0.2, 5.0), Vector3(2.2, 0.15, 0.3)) # Stahlträger
	if techs.has("blast_furnace"):
		for c: Vector2 in [Vector2(1.5, 2.5), Vector2(4.5, 2.5)]:
			_modern_furnace(b, base + Vector3(c.x, 8.0 + lv, c.y), Vector3.INF)
		_modern_furnace(b, Vector3.INF, base + Vector3(2.8, 0, 5.0))


## Moderne Hochöfen: Wäscher-Ring auf dem Schlot (top) und blau leuchtender Elektroofen-Block (ground).
static func _modern_furnace(b: BlockBatch, top: Vector3, ground: Vector3) -> void:
	if top != Vector3.INF:
		b.put_box("metal", top + Vector3(0, 0.2, 0), Vector3(1.5, 0.4, 1.5))
		b.put_box("ice", top + Vector3(0, 0.5, 0), Vector3(1.1, 0.2, 1.1))
	if ground != Vector3.INF:
		b.put_box("metal", ground + Vector3(0, 0.7, 0), Vector3(1.2, 1.4, 1.2))
		b.put_box("vox_blue", ground + Vector3(0, 0.6, -0.62), Vector3(0.7, 0.5, 0.06))


## Baumschule (3x3): Reihen junger Bäume, Geräteschuppen, Gießkanne (blau).
static func nursery(b: BlockBatch, base: Vector3, lv: int) -> void:
	for z in 3:
		for x in 2:
			b.put_prop("bush", base + Vector3(0.6 + x * 1.0, 0, 0.5 + z * 1.0), float(x + z), 0.6 + lv * 0.1)
	b.put("wood", base + Vector3(2, 0, 2))
	b.put_box("darkbrick", base + Vector3(2.5, 1.05, 2.5), Vector3(1.1, 0.12, 1.1))
	b.put_box("vox_blue", base + Vector3(2.5, 0.2, 0.6), Vector3(0.3, 0.35, 0.3))
	b.put_prop("shovel", base + Vector3(2.6, 0, 1.4), 0.4)


## Prospektor (3x3): Zelt, kleiner Bohrturm, Fahne, Probenkisten.
static func prospector(b: BlockBatch, base: Vector3, lv: int) -> void:
	b.put_box("vox_white", base + Vector3(0.9, 0.5, 0.9), Vector3(1.4, 1.0, 1.4), 0.785)      # Zelt
	b.put_box("vox_white", base + Vector3(0.9, 1.1, 0.9), Vector3(0.8, 0.4, 0.8), 0.785)
	var top := base + Vector3(2.3, 2.5 + lv * 0.5, 2.3)
	for c: Vector2 in [Vector2(1.8, 1.8), Vector2(2.8, 1.8), Vector2(1.8, 2.8), Vector2(2.8, 2.8)]:
		b.segment("wood", base + Vector3(c.x, 0, c.y), top, 0.1)                               # Bohrturm
	b.segment("metal", top, base + Vector3(2.3, 0, 2.3), 0.08)
	b.put_box("vox_red", top + Vector3(0.25, 0.25, 0), Vector3(0.5, 0.3, 0.04))               # Fahne
	b.put("crate", base + Vector3(0.0, 0, 2.2))
	b.put_prop("pickaxe", base + Vector3(2.5, 0, 0.5), 0.3)


## Recyclinghof (6x6): eingezäunter Hof, bunte Container, Schrottpresse.
static func recycler(b: BlockBatch, base: Vector3, lv: int) -> void:
	for x in 6:
		b.put_box("metal", base + Vector3(x + 0.5, 0.35, 0.05), Vector3(1.0, 0.7, 0.06))
		b.put_box("metal", base + Vector3(x + 0.5, 0.35, 5.95), Vector3(1.0, 0.7, 0.06))
	for z in 6:
		b.put_box("metal", base + Vector3(0.05, 0.35, z + 0.5), Vector3(0.06, 0.7, 1.0))
		b.put_box("metal", base + Vector3(5.95, 0.35, z + 0.5), Vector3(0.06, 0.7, 1.0))
	var cols := ["vox_green", "vox_blue", "vox_yellow", "vox_red"]
	for k in 2 + lv:
		b.put_box(cols[k % 4], base + Vector3(1.2 + (k % 3) * 1.3, 0.45, 1.3 + (k / 3) * 1.6), Vector3(1.0, 0.9, 1.4))
	b.put_box("darkbrick", base + Vector3(4.5, 1.0, 4.3), Vector3(1.8, 2.0, 1.8))             # Presse
	b.put_box("metal", base + Vector3(4.5, 2.2, 4.3), Vector3(1.2, 0.4, 1.2))
	b.put_box("iron_ore", base + Vector3(2.0, 0.3, 4.6), Vector3(1.4, 0.6, 1.0))              # Schrotthaufen


## Holzmast mit Querträger, Fuß bei foot (Tile-Mitte).
static func pole(b: BlockBatch, foot: Vector3, rot: float) -> void:
	b.put_box("wood", foot + Vector3(0, POLE_HEIGHT * 0.5, 0), Vector3(0.25, POLE_HEIGHT, 0.25))
	b.put_box("wood", foot + Vector3(0, POLE_HEIGHT - 0.15, 0), Vector3(1.6, 0.18, 0.18), rot)
