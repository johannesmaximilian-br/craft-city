class_name ToolController
extends Node3D
## Maus-Picking, Werkzeug-Vorschau und Anwenden der Bauaktionen.

signal hover_changed(tile: Vector2i)
signal preview_cost_changed(cost: int, valid: bool)   # cost inkl. Zukauf fehlender Baumaterialien
signal tool_changed(tool: Tool)
signal message(text: String)
signal applied(tool: Tool)

enum Tool { INSPECT, ROAD, POWERLINE, BUS_STOP, RAIL, STATION, RES, COM, IND, COAL, WIND, TREE, PARK, RAISE, LOWER, BULLDOZE,
	POLICE, FIRE, SCHOOL, HOSPITAL, LIBRARY, CINEMA, TOWNHALL, THEATER, STADIUM,
	LUMBER, QUARRY, PIT, MINE, WAREHOUSE, SAWMILL, BRICKWORKS, GLASSWORKS, STEELWORKS, NURSERY, PROSPECTOR, RECYCLER,
	UNIVERSITY, INSTITUTE, BIOMASS, SOLAR, BATTERY, HYDRO, PUMPED, SALT, HIGHTECH, CONCRETE }

## Anzeige-Metadaten: Name, Icon, Taste, Gruppe (für Toolbar-Trenner)
const TOOLS := {
	Tool.INSPECT:   {"name": "Info / Kamera", "icon": "info", "key": KEY_1, "group": 0,
		"hint": "Ziehen: Karte verschieben"},
	Tool.ROAD:      {"name": "Straße", "icon": "road", "key": KEY_2, "group": 1, "cost": Config.COST_ROAD,
		"hint": "Ziehen: Linie  ·  Shift: Raster  ·  2 Straßen nebeneinander = 4-spurige Hauptstraße"},
	Tool.POWERLINE: {"name": "Stromleitung", "icon": "powerline", "key": KEY_3, "group": 1, "cost": Config.COST_POWERLINE},
	Tool.BUS_STOP:  {"name": "Bushaltestelle", "icon": "bus_stop", "key": KEY_J, "group": 6, "cost": Config.COST_BUS_STOP,
		"hint": "Auf Straße setzen  ·  3 Tiles Umkreis  ·  Haltestelle am Bahnhof = ganzes Busnetz an die Bahn angebunden"},
	Tool.RAIL:      {"name": "Gleis", "icon": "rail", "key": KEY_R, "group": 6, "cost": Config.COST_RAIL,
		"hint": "Ziehen: Linie  ·  darf Straßen kreuzen  ·  max. 1 Block Steigung"},
	Tool.STATION:   {"name": "Bahnhof", "icon": "station", "key": KEY_Z, "group": 6, "cost": Config.COST_STATION,
		"hint": "Auf Gleis setzen  ·  4 Tiles Fußweg  ·  lohnt sich für lange Wege und bei Stau"},
	Tool.RES:       {"name": "Wohngebiet", "icon": "res", "key": KEY_4, "group": 2, "cost": Config.COST_ZONE,
		"hint": "6 Tiles tief zwischen 2 Straßen  ·  >=5 Abstand zu Industrie, >=8 zu Kohle  ·  Grün/Wasser+"},
	Tool.COM:       {"name": "Gewerbegebiet", "icon": "com", "key": KEY_5, "group": 2, "cost": Config.COST_ZONE,
		"hint": "Braucht Einwohner im Umkreis von 6 Tiles  ·  ideal zwischen Wohnen und Industrie"},
	Tool.IND:       {"name": "Industriegebiet", "icon": "ind", "key": KEY_6, "group": 2, "cost": Config.COST_ZONE,
		"hint": "Verschmutzt 4 Tiles weit  ·  mit Abstand zu Wohngebieten bauen"},
	Tool.COAL:      {"name": "Kohlekraftwerk (400 MW)", "icon": "coal", "key": KEY_7, "group": 3, "cost": 3000},
	Tool.WIND:      {"name": "Windrad (30 MW)", "icon": "wind", "key": KEY_8, "group": 3, "cost": 450},
	Tool.POLICE:    {"name": "Polizei", "icon": "police", "key": KEY_U, "group": 7, "cost": 900,
		"hint": "Senkt Kriminalität  ·  ab 300 Einwohnern erwartet  ·  nochmal klicken = Ausbau"},
	Tool.FIRE:      {"name": "Feuerwehr", "icon": "fire", "key": KEY_F, "group": 7, "cost": 900,
		"hint": "Schützt vor Bränden  ·  ab 300 Einwohnern erwartet  ·  nochmal klicken = Ausbau"},
	Tool.SCHOOL:    {"name": "Schule", "icon": "school", "key": KEY_L, "group": 7, "cost": 1200,
		"hint": "Bildung: Zufriedenheit + Fachkräfte für Gewerbe/Industrie  ·  ab 600 Einwohnern"},
	Tool.HOSPITAL:  {"name": "Krankenhaus", "icon": "hospital", "key": KEY_K, "group": 7, "cost": 2500,
		"hint": "Gesundheit  ·  2x2 Tiles  ·  ab 600 Einwohnern erwartet  ·  nochmal klicken = Ausbau"},
	Tool.LIBRARY:   {"name": "Bibliothek", "icon": "library", "key": KEY_N, "group": 8, "cost": 1000,
		"hint": "Kultur  ·  verfügbar ab 1.000 Einwohnern  ·  ab 1.500 erwartet"},
	Tool.CINEMA:    {"name": "Kino", "icon": "cinema", "key": KEY_X, "group": 8, "cost": 1400,
		"hint": "Kultur  ·  verfügbar ab 1.000 Einwohnern  ·  ab 1.500 erwartet"},
	Tool.TOWNHALL:  {"name": "Bürgerhaus", "icon": "townhall", "key": KEY_C, "group": 8, "cost": 4000,
		"hint": "Kultur, große Reichweite  ·  2x2 Tiles  ·  verfügbar ab 2.000 Einwohnern"},
	Tool.THEATER:   {"name": "Theater", "icon": "theater", "key": KEY_Y, "group": 8, "cost": 8000,
		"hint": "Großkultur  ·  2x2  ·  ab 3.000 Einw.  ·  jeden Monat Vorstellung: Besucher kaufen ringsum ein, Verkehr"},
	Tool.STADIUM:   {"name": "Stadion", "icon": "stadium", "key": KEY_O, "group": 8, "cost": 15000,
		"hint": "Großkultur  ·  3x3  ·  ab 5.000 Einw.  ·  Spieltag alle 3 Monate: viele Besucher, Stau ohne Bus/Bahn"},
	# Rohstoffe (keine freie Taste mehr -> nur über die Werkzeugleiste)
	Tool.LUMBER:    {"name": "Holzfäller", "icon": "lumber", "key": KEY_NONE, "group": 9, "cost": 600,
		"hint": "Fällt Bäume im Umkreis von 4 Tiles -> Holz  ·  Wald wächst (noch) nicht nach"},
	Tool.QUARRY:    {"name": "Steinbruch", "icon": "quarry", "key": KEY_NONE, "group": 9, "cost": 1500,
		"hint": "Baut Fels (graue Steinflächen im Hochland/an Hängen) im Umkreis von 2 Tiles ab  ·  2x2"},
	Tool.PIT:       {"name": "Grube (Sand/Ton)", "icon": "pit", "key": KEY_NONE, "group": 9, "cost": 500,
		"hint": "Baut Sand (Strand) und Ton (Niederung) im Umkreis von 2 Tiles ab  ·  Vorkommen in der Ansicht Rohstoffe"},
	Tool.MINE:      {"name": "Mine", "icon": "mine", "key": KEY_NONE, "group": 9, "cost": 3000,
		"hint": "Kohle, Eisen, Gold aus Erzadern im Umkreis von 3 Tiles  ·  2x2  ·  Vorkommen sind endlich"},
	Tool.WAREHOUSE: {"name": "Lagerhaus", "icon": "warehouse", "key": KEY_NONE, "group": 9, "cost": 1200,
		"hint": "+1.000 Lager je Rohstoff  ·  2x2  ·  Überschuss wird sonst automatisch exportiert"},
	Tool.NURSERY:   {"name": "Baumschule", "icon": "nursery", "key": KEY_NONE, "group": 9, "cost": 400,
		"hint": "Pflanzt 2 Bäume je Monat im Umkreis von 4 Tiles  ·  mit Holzfäller = nachhaltiges Holz"},
	Tool.PROSPECTOR: {"name": "Prospektor", "icon": "prospector", "key": KEY_NONE, "group": 9, "cost": 1500,
		"hint": "Sucht neue Kohle-/Eisen-/Goldadern im Umkreis von 8 Tiles (Hügelland)  ·  ~8 %/Monat je Stufe"},
	Tool.RECYCLER:  {"name": "Recyclinghof", "icon": "recycler", "key": KEY_NONE, "group": 9, "cost": 2000,
		"hint": "Abriss gibt 80 % statt 40 % der verbauten Baustoffe zurück  ·  2x2"},
	Tool.BIOMASS: {"name": "Biomassekraftwerk", "icon": "biomass", "key": KEY_NONE, "group": 3, "cost": 1200,
		"hint": "60 MW, Tag und Nacht  ·  verbrennt 20 Holz/Monat (sonst Zukauf)  ·  Abgas  ·  2x2"},
	Tool.SOLAR: {"name": "Solarfeld", "icon": "solar", "key": KEY_NONE, "group": 3, "cost": 2500,
		"hint": "50 MW, nur tagsüber - nachts Speicher oder Grundlast nötig  ·  sauber  ·  2x2  ·  Forschung Solarenergie"},
	Tool.BATTERY: {"name": "Batteriespeicher", "icon": "battery", "key": KEY_NONE, "group": 3, "cost": 3000,
		"hint": "Lädt mit dem Tagesüberschuss, liefert nachts bis 40 MW  ·  Forschung Batteriespeicher"},
	Tool.HIGHTECH: {"name": "Hightech-Industrie", "icon": "hightech", "key": KEY_NONE, "group": 6, "cost": 5,
		"hint": "Industrie-Zone: 85 % weniger Verschmutzung, 60 % mehr Steuer  ·  wächst nur mit Akademikern (Uni in Reichweite)"},
	Tool.CONCRETE: {"name": "Betonwerk", "icon": "concrete", "key": KEY_NONE, "group": 10, "cost": 2500,
		"hint": "10 Stein + 10 Sand + 1 Kohle -> 12 Beton  ·  für Hochhäuser und Bürotürme  ·  Forschung Beton"},
	Tool.HYDRO: {"name": "Wasserkraftwerk", "icon": "hydro", "key": KEY_NONE, "group": 3, "cost": 9000,
		"hint": "120 MW Tag und Nacht, sauber  ·  nur direkt am Wasser  ·  2x2  ·  Forschung Wasserkraft"},
	Tool.PUMPED: {"name": "Pumpspeicher", "icon": "pumped", "key": KEY_NONE, "group": 3, "cost": 7000,
		"hint": "Speichert 150 MW für die Nacht  ·  am Hang: 3+ Blöcke über Wasser, Wasser in 4 Tiles  ·  Forschung Pumpspeicher"},
	Tool.SALT: {"name": "Salzspeicher", "icon": "salt", "key": KEY_NONE, "group": 3, "cost": 8000,
		"hint": "Speichert 300 MW für die Nacht  ·  Klick auf Kohlekraftwerk = Umrüsten zum halben Preis  ·  Forschung Salzspeicher"},
	Tool.UNIVERSITY: {"name": "Universität", "icon": "university", "key": KEY_NONE, "group": 7, "cost": 15000,
		"hint": "Hochschule: Akademiker für Forschung  ·  3x3  ·  ab 6.000 Einw. und 70 % Schulversorgung  ·  großer Einzugskreis"},
	Tool.INSTITUTE: {"name": "Forschungsinstitut", "icon": "institute", "key": KEY_NONE, "group": 7, "cost": 8000,
		"hint": "Forschungspunkte (mehr Akademiker = schneller)  ·  2x2  ·  braucht Universität  ·  Projekte im Forschungsfenster"},
	Tool.SAWMILL:   {"name": "Sägewerk", "icon": "sawmill", "key": KEY_NONE, "group": 10, "cost": 1500,
		"hint": "10 Holz -> 10 Bretter je Monat  ·  Bretter braucht Stufe 2"},
	Tool.BRICKWORKS: {"name": "Ziegelei", "icon": "brickworks", "key": KEY_NONE, "group": 10, "cost": 1800,
		"hint": "10 Ton + 2 Kohle -> 10 Ziegel  ·  Ziegel brauchen Stufe 2 und 3  ·  verschmutzt etwas"},
	Tool.GLASSWORKS: {"name": "Glashütte", "icon": "glassworks", "key": KEY_NONE, "group": 10, "cost": 2500,
		"hint": "10 Sand + 3 Kohle -> 8 Glas  ·  Glas braucht Stufe 3 (vor allem Gewerbe)  ·  verschmutzt"},
	Tool.STEELWORKS: {"name": "Stahlwerk", "icon": "steelworks", "key": KEY_NONE, "group": 10, "cost": 4000,
		"hint": "10 Eisen + 5 Kohle -> 8 Stahl  ·  Stahl braucht Stufe 3  ·  verschmutzt stark"},
	Tool.TREE:      {"name": "Baum", "icon": "tree", "key": KEY_9, "group": 4, "cost": Config.COST_TREE,
		"hint": "Filtert Verschmutzung im Umkreis von 2 Tiles  ·  kostenlos im Unterhalt"},
	Tool.PARK:      {"name": "Park", "icon": "park", "key": KEY_0, "group": 4, "cost": Config.COST_PARK,
		"hint": "Filtert Verschmutzung  ·  Zufriedenheit + Bodenwert im Umkreis von 3 Tiles  ·  $%d/Monat" % int(Config.UPKEEP_PARK)},
	Tool.RAISE:     {"name": "Terrain anheben", "icon": "raise", "key": KEY_T, "group": 5, "cost": Config.COST_TERRAFORM,
		"hint": "Straßen, Gleise, Parks und Gebäude darauf werden abgerissen"},
	Tool.LOWER:     {"name": "Terrain absenken", "icon": "lower", "key": KEY_G, "group": 5, "cost": Config.COST_TERRAFORM,
		"hint": "Straßen, Gleise, Parks und Gebäude darauf werden abgerissen"},
	Tool.BULLDOZE:  {"name": "Abriss", "icon": "bulldoze", "key": KEY_B, "group": 5, "cost": Config.COST_BULLDOZE},
}

const B := Config.TILE_BLOCKS
const PREVIEW_OK := Color(0.3, 0.9, 1.0, 0.45)
const PREVIEW_BAD := Color(1.0, 0.2, 0.2, 0.5)


## Eignung 0..1 -> rot/gelb/grün
static func suitability_color(v: float) -> Color:
	var bad := Color(0.95, 0.25, 0.2, 0.55)
	var mid := Color(1.0, 0.85, 0.2, 0.55)
	var good := Color(0.3, 0.9, 0.35, 0.55)
	return bad.lerp(mid, v * 2.0) if v < 0.5 else mid.lerp(good, (v - 0.5) * 2.0)

var map: CityMap
var sim: Simulation
var camera: Camera3D
var tool := Tool.INSPECT

var hover := Vector2i(-1, -1)
var _drag_start := Vector2i(-1, -1)
var _dragging := false
var _preview: MultiMeshInstance3D
var preview_site := ""              # Standortregel verletzt: Grund (HUD-Kostenblase)
var preview_convert := false        # Salzspeicher über Kohlekraftwerk: Umrüsten
var preview_materials := {}         # Baumaterial der aktuellen Vorschau (HUD-Kostenblase)
var preview_missing := {}           # davon nicht im Lager
var preview_import := 0.0           # Zukaufpreis dafür (in preview_cost enthalten)
var _recycled := {}
var _present := {}                  # Sonderbau-Art -> vorhanden (Cache für locked_reason, geleert bei Kartenänderung)                 # Rückgewinnung beim aktuellen Abriss (für die Meldung)
var _range: MultiMeshInstance3D     # Reichweite unter dem Cursor (Haltestelle, Bahnhof, Dienste)
const RANGE_ROAD := Color(0.25, 0.55, 1.0, 0.5)      # Straße kommt ins Busnetz / Fußweg zum Bahnhof
const RANGE_NEW := Color(0.3, 0.95, 0.4, 0.5)        # Gebäude bekommt neu Anschluss
const RANGE_AREA := Color(1.0, 1.0, 1.0, 0.75)       # Rand des Einzugsgebiets eines Dienstes


func setup(city_map: CityMap, simulation: Simulation, cam: Camera3D) -> void:
	map = city_map
	map.tiles_changed.connect(func(_r: Rect2i) -> void: _present.clear())
	sim = simulation
	camera = cam
	var box := BoxMesh.new()
	box.size = Vector3(B - 0.1, 0.25, B - 0.1)
	box.material = _make_mat()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = box
	_preview = MultiMeshInstance3D.new()
	_preview.multimesh = mm
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_preview)
	var plate := BoxMesh.new()
	plate.size = Vector3(B - 0.3, 0.12, B - 0.3)
	var pm := _make_mat()
	pm.render_priority = 1          # über der Ansichts-Einfärbung zeichnen
	plate.material = pm
	var rm := MultiMesh.new()
	rm.transform_format = MultiMesh.TRANSFORM_3D
	rm.use_colors = true
	rm.mesh = plate
	_range = MultiMeshInstance3D.new()
	_range.multimesh = rm
	_range.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_range)


func _make_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = true
	return m


func set_tool(t: Tool) -> void:
	tool = t
	_dragging = false
	_update_preview()
	tool_changed.emit(t)


func _special_for_tool() -> int:
	return special_for(tool)


func special_for(t: Tool) -> int:
	match t:
		Tool.COAL: return Config.Special.COAL
		Tool.WIND: return Config.Special.WIND
		Tool.POLICE: return Config.Special.POLICE
		Tool.FIRE: return Config.Special.FIRE
		Tool.SCHOOL: return Config.Special.SCHOOL
		Tool.HOSPITAL: return Config.Special.HOSPITAL
		Tool.LIBRARY: return Config.Special.LIBRARY
		Tool.CINEMA: return Config.Special.CINEMA
		Tool.TOWNHALL: return Config.Special.TOWNHALL
		Tool.THEATER: return Config.Special.THEATER
		Tool.STADIUM: return Config.Special.STADIUM
		Tool.LUMBER: return Config.Special.LUMBER
		Tool.QUARRY: return Config.Special.QUARRY
		Tool.PIT: return Config.Special.PIT
		Tool.MINE: return Config.Special.MINE
		Tool.WAREHOUSE: return Config.Special.WAREHOUSE
		Tool.SAWMILL: return Config.Special.SAWMILL
		Tool.BRICKWORKS: return Config.Special.BRICKWORKS
		Tool.GLASSWORKS: return Config.Special.GLASSWORKS
		Tool.STEELWORKS: return Config.Special.STEELWORKS
		Tool.NURSERY: return Config.Special.NURSERY
		Tool.PROSPECTOR: return Config.Special.PROSPECTOR
		Tool.RECYCLER: return Config.Special.RECYCLER
		Tool.UNIVERSITY: return Config.Special.UNIVERSITY
		Tool.BIOMASS: return Config.Special.BIOMASS
		Tool.SOLAR: return Config.Special.SOLAR
		Tool.BATTERY: return Config.Special.BATTERY
		Tool.HYDRO: return Config.Special.HYDRO
		Tool.PUMPED: return Config.Special.PUMPED
		Tool.SALT: return Config.Special.SALT
		Tool.CONCRETE: return Config.Special.CONCRETE
		Tool.INSTITUTE: return Config.Special.INSTITUTE
	return Config.Special.NONE


## Werkzeug noch gesperrt? Liefert Hinweistext oder "".
func locked_reason(t: Tool) -> String:
	var prev := tool
	tool = t
	var sp := _special_for_tool()
	tool = prev
	if t == Tool.HIGHTECH and not sim.tech("hightech"):
		return "Erst erforschen: Hightech-Industrie (Forschungsfenster)"
	if sp == Config.Special.NONE:
		return ""
	var def: Dictionary = Config.SPECIALS[sp]
	var unlock: int = def.get("unlock", 0)
	if sim.population < unlock:
		return "Verfügbar ab %d Einwohnern" % unlock
	if def.has("need_tech") and not sim.tech(str(def["need_tech"])):
		return "Erst erforschen: %s (Forschungsfenster)" % Config.RESEARCH[str(def["need_tech"])]["name"]
	if def.has("need_coverage"):
		var cat: String = def["need_coverage"][0]
		var share: float = def["need_coverage"][1]
		var have := float(sim.city_coverage.get(cat, 0.0))
		if have < share:
			return "Erst %d %% %s-Versorgung nötig (jetzt %d %%)" % [roundi(share * 100.0), Config.SERVICES[cat][0],
				roundi(have * 100.0)]
	if def.has("need_special"):
		var need: int = def["need_special"]
		if not _special_present(need):
			return "Erst eine %s bauen" % Config.SPECIALS[need]["name"]
	return ""


## Klick auf bestehenden Sonderbau desselben Typs = Ausbau. Liefert Ursprungs-Tile oder -1.
func _upgrade_target() -> int:
	var sp := _special_for_tool()
	if sp == Config.Special.NONE or hover.x < 0 or not Config.SPECIALS[sp].has("upgrade"):
		return -1
	var i := map.idx(hover.x, hover.y)
	return map.anchor[i] if map.special[i] == sp else -1


func _unhandled_input(event: InputEvent) -> void:
	if DevTools.automated and not event.has_meta("synthetic"):
		return      # echte Maus des Nutzers in Testläufen ignorieren
	if event is InputEventMouseMotion:
		var t := pick((event as InputEventMouseMotion).position)
		if t != hover:
			hover = t
			hover_changed.emit(hover)
			_update_preview()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		# Leertaste + Klick gehört der Kamera
		if Input.is_key_pressed(KEY_SPACE) or tool == Tool.INSPECT:
			_dragging = false
			return
		if mb.pressed and hover.x >= 0:
			_drag_start = hover
			_dragging = true
			if tool in [Tool.RAISE, Tool.LOWER, Tool.BUS_STOP, Tool.STATION] or _special_for_tool() != Config.Special.NONE:
				_dragging = false
				_apply(_affected_tiles())
		elif not mb.pressed and _dragging:
			# Erst Fläche berechnen, dann Ziehen beenden (_affected_tiles braucht _dragging)
			var tiles := _affected_tiles() if hover.x >= 0 else ([] as Array[Vector2i])
			_dragging = false
			_apply(tiles)
		_update_preview()
	elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		_dragging = false
		_update_preview()


## Strahl durch das Höhenfeld marschieren -> Tile unter der Maus.
func pick(screen_pos: Vector2) -> Vector2i:
	var o := camera.project_ray_origin(screen_pos)
	var d := camera.project_ray_normal(screen_pos)
	if d.y >= 0.0:
		return Vector2i(-1, -1)
	# Erst ab der maximalen Terrainhöhe marschieren
	var t := maxf(0.0, (o.y - Config.MAX_HEIGHT - 1.0) / -d.y)
	while t < 1500.0:
		var p := o + d * t
		var tx := floori(p.x / B)
		var tz := floori(p.z / B)
		if map.in_bounds(tx, tz):
			var top := maxf(float(map.height[map.idx(tx, tz)]), Config.WATER_LEVEL - 0.2)
			if p.y <= top:
				return Vector2i(tx, tz)
		elif p.y < 0.0:
			break
		t += 0.2
	return Vector2i(-1, -1)


func _affected_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if hover.x < 0:
		return out
	var conv := _convert_target()
	if conv >= 0:
		for z in 2:
			for x in 2:
				out.append(Vector2i(conv % map.size + x, conv / map.size + z))
		return out
	var sp := _special_for_tool()
	if sp != Config.Special.NONE:
		var s: int = Config.SPECIALS[sp]["size"]
		for z in s:
			for x in s:
				out.append(hover + Vector2i(x, z))
		return out
	if not _dragging:
		out.append(hover)
		return out
	var a := _drag_start
	var b := hover
	if tool == Tool.ROAD and Input.is_key_pressed(KEY_SHIFT):
		_grid(a, b, out)
	elif tool == Tool.ROAD or tool == Tool.POWERLINE or tool == Tool.RAIL:
		# L-Form: erst entlang der längeren Achse
		var corner := Vector2i(b.x, a.y) if absi(b.x - a.x) >= absi(b.y - a.y) else Vector2i(a.x, b.y)
		_line(a, corner, out)
		_line(corner, b, out)
	else:
		for z in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
			for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
				out.append(Vector2i(x, z))
	return out


## Straßenraster im Rechteck: Rand + Querstraßen alle 7 Tiles -> 6 Tiles tiefe Blöcke
## (je 3 Tiles Straßenreichweite von beiden Seiten).
func _grid(a: Vector2i, b: Vector2i, out: Array[Vector2i]) -> void:
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var hi := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	for z in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var on_x := (x - lo.x) % 7 == 0 or x == hi.x
			var on_z := (z - lo.y) % 7 == 0 or z == hi.y
			if on_x or on_z:
				out.append(Vector2i(x, z))


func _line(a: Vector2i, b: Vector2i, out: Array[Vector2i]) -> void:
	var step := (b - a).sign()
	var p := a
	while true:
		if not out.has(p):
			out.append(p)
		if p == b:
			break
		p += step


## Kosten einer Aktion für ein Tile; -1 = nicht möglich, 0 = nichts zu tun.
func tile_cost(t: Vector2i) -> int:
	if not map.in_bounds(t.x, t.y):
		return -1
	var i := map.idx(t.x, t.y)
	var water := map.is_water(t.x, t.y)
	var building := map.has_building(t.x, t.y)
	var special := map.special[i] != Config.Special.NONE
	var demolish := Config.COST_BULLDOZE_BUILDING if building else 0
	var rail := map.rail[i] != 0
	var station := map.transit[i] == Config.Transit.STATION
	match tool:
		Tool.ROAD:
			if water or special or station: return -1
			if map.road[i] != 0: return 0
			return Config.COST_ROAD + demolish
		Tool.BUS_STOP:
			if map.road[i] == 0: return -1
			if map.transit[i] == Config.Transit.BUS_STOP: return 0
			if map.transit[i] != Config.Transit.NONE: return -1
			return Config.COST_BUS_STOP
		Tool.RAIL:
			if water or special or building or map.zone[i] != Config.Zone.NONE: return -1
			if rail: return 0
			return Config.COST_RAIL
		Tool.STATION:
			if not rail or map.road[i] != 0: return -1
			if station: return 0
			return Config.COST_STATION
		Tool.POWERLINE:
			if water or special: return -1
			if map.power_line[i] == 1 or map.zone[i] != Config.Zone.NONE: return 0
			return Config.COST_POWERLINE
		Tool.RES, Tool.COM, Tool.IND, Tool.HIGHTECH:
			if water or special or rail or map.road[i] != 0: return -1
			if tool == Tool.HIGHTECH and locked_reason(tool) != "": return -1
			if map.zone[i] == _tool_zone() and (map.hightech[i] == 1) == (tool == Tool.HIGHTECH): return 0
			return Config.COST_ZONE + demolish
		Tool.COAL, Tool.WIND, Tool.POLICE, Tool.FIRE, Tool.SCHOOL, Tool.HOSPITAL, \
				Tool.LIBRARY, Tool.CINEMA, Tool.TOWNHALL, Tool.THEATER, Tool.STADIUM, \
				Tool.LUMBER, Tool.QUARRY, Tool.PIT, Tool.MINE, Tool.WAREHOUSE, \
				Tool.SAWMILL, Tool.BRICKWORKS, Tool.GLASSWORKS, Tool.STEELWORKS, \
				Tool.NURSERY, Tool.PROSPECTOR, Tool.RECYCLER, Tool.UNIVERSITY, Tool.INSTITUTE, \
				Tool.BIOMASS, Tool.SOLAR, Tool.BATTERY, Tool.HYDRO, Tool.PUMPED, Tool.SALT, Tool.CONCRETE:
			var sp := _special_for_tool()
			if locked_reason(tool) != "": return -1
			var up := _upgrade_target()
			if up >= 0:
				# Ausbau: nur das angeklickte Tile kostet
				if map.special_level(up) >= 3: return -1
				return int(Config.SPECIALS[sp]["upgrade"]) * map.special_level(up) if t == hover else 0
			var conv := _convert_target()
			if conv >= 0:
				# Salzspeicher: Kohlekraftwerk umrüsten (Kosten nur am Ursprungs-Tile)
				return int(Config.SPECIALS[sp]["cost"] * Config.SALT_CONVERT) if i == conv else 0
			# Kosten nur auf dem Ursprungs-Tile, Rest muss frei sein
			if water or special or building or rail or map.road[i] != 0: return -1
			if t == hover and site_reason(sp, hover) != "": return -1
			return Config.SPECIALS[sp]["cost"] if t == hover else 0
		Tool.BULLDOZE:
			if special:
				var s: int = Config.SPECIALS[map.special[i]]["size"]
				return Config.COST_BULLDOZE_BUILDING * s * s
			if building or station: return Config.COST_BULLDOZE_BUILDING
			if map.road[i] != 0 or map.power_line[i] == 1 or map.zone[i] != Config.Zone.NONE \
					or map.feature[i] != Config.Feature.NONE or rail or map.transit[i] != Config.Transit.NONE:
				return Config.COST_BULLDOZE
			return 0
		Tool.RAISE, Tool.LOWER:
			if special: return -1
			if map.height[i] >= Config.MAX_HEIGHT and tool == Tool.RAISE or map.height[i] <= 1 and tool == Tool.LOWER:
				return -1
			# Straße/Gleis/Park darauf wird abgerissen
			var built := map.road[i] != 0 or rail or map.feature[i] == Config.Feature.PARK
			return Config.COST_TERRAFORM + (Config.COST_BULLDOZE if built else 0)
		Tool.TREE:
			if water or special or rail or map.road[i] != 0 or building: return -1
			return Config.COST_TREE if map.feature[i] != Config.Feature.TREE else 0
		Tool.PARK:
			if water or special or rail or map.road[i] != 0 or building: return -1
			return Config.COST_PARK if map.feature[i] != Config.Feature.PARK else 0
	return 0


## Baumaterial einer Aktion für ein Tile (nur wo tile_cost > 0; Sonderbau nur am Ursprungs-Tile).
func tile_materials(t: Vector2i) -> Dictionary:
	if tile_cost(t) <= 0:
		return {}
	var infra := _infra_materials()
	if not infra.is_empty():
		return infra if sim.build_factor() == 1.0 else Simulation.scale_materials(infra, sim.build_factor())
	var sp := _special_for_tool()
	if sp == Config.Special.NONE:
		return {}
	var base: Dictionary = Config.SPECIAL_MATERIALS.get(sp, {})
	if _convert_target() >= 0:
		return Simulation.scale_materials(base, Config.SALT_CONVERT * sim.build_factor())
	var up := _upgrade_target()
	if up >= 0:
		return Simulation.scale_materials(base, Config.UPGRADE_MATERIALS * map.special_level(up) * sim.build_factor())
	return base if sim.build_factor() == 1.0 else Simulation.scale_materials(base, sim.build_factor())


## Standortregel eines Sonderbaus ("site" in SPECIALS) für Ursprung o: "" = passt, sonst Grund.
func site_reason(sp: int, o: Vector2i) -> String:
	var def: Dictionary = Config.SPECIALS[sp]
	if not def.has("site"):
		return ""
	var s: int = def["size"]
	match str(def["site"]):
		"water":
			var water := 0
			for z in range(o.y - 1, o.y + s + 1):
				for x in range(o.x - 1, o.x + s + 1):
					var inside := x >= o.x and x < o.x + s and z >= o.y and z < o.y + s
					if not inside and map.in_bounds(x, z) and map.is_water(x, z):
						water += 1
			if water < Config.HYDRO_MIN_WATER:
				return "Wasserkraft braucht Wasser direkt am Gebäude (Fluss/See, mind. %d Wasserfelder am Rand)" % Config.HYDRO_MIN_WATER
		"hill":
			var top := 0
			for z in range(o.y, o.y + s):
				for x in range(o.x, o.x + s):
					if map.in_bounds(x, z):
						top = maxi(top, map.h(x, z))
			if top - Config.WATER_LEVEL < Config.PUMPED_MIN_HEIGHT:
				return "Pumpspeicher braucht einen Hang: mind. %d Blöcke über dem Wasser (hier %d)" % [
					Config.PUMPED_MIN_HEIGHT, maxi(top - Config.WATER_LEVEL, 0)]
			var r := Config.PUMPED_WATER_RANGE
			for z in range(o.y - r, o.y + s + r):
				for x in range(o.x - r, o.x + s + r):
					if map.in_bounds(x, z) and map.is_water(x, z):
						return ""
			return "Pumpspeicher braucht Wasser in der Nähe (%d Tiles) als Unterbecken" % r
	return ""


## Salzspeicher-Werkzeug über einem Kohlekraftwerk -> dessen Ursprungs-Tile (Umrüsten), sonst -1.
func _convert_target() -> int:
	if tool != Tool.SALT or hover.x < 0 or not map.in_bounds(hover.x, hover.y) or locked_reason(tool) != "":
		return -1
	var i := map.idx(hover.x, hover.y)
	return map.anchor[i] if map.special[i] == Config.Special.COAL else -1


func _convert_to_salt(a: int) -> void:
	var cost := int(Config.SPECIALS[Config.Special.SALT]["cost"] * Config.SALT_CONVERT)
	var mats := Simulation.scale_materials(Config.SPECIAL_MATERIALS[Config.Special.SALT], Config.SALT_CONVERT * sim.build_factor())
	var import_price: float = sim.build_need(mats)[1]
	if not sim.can_afford(cost + import_price):
		message.emit("Nicht genug Geld für den Umbau (benötigt $%d)" % (cost + int(import_price)))
		return
	for z in 2:
		for x in 2:
			var j := a + z * map.size + x
			map.special[j] = Config.Special.SALT
			map.anchor[j] = a
	map.slevel[a] = 1
	sim.spend(cost)
	sim.use_build_materials(mats)
	map.notify_changed(Rect2i(a % map.size, a / map.size, 2, 2))
	sim.refresh(sim.async_commute)
	message.emit("Umgerüstet: Salzspeicher speichert 300 MW für die Nacht - %d MW Kohlestrom fehlen jetzt, ggf. Ersatz bauen" %
		int(Config.SPECIALS[Config.Special.COAL]["power"]))
	applied.emit(tool)


## Gibt es mindestens einen Sonderbau dieser Art? (gecacht: locked_reason läuft je Tile und Mausbewegung)
func _special_present(sp: int) -> bool:
	if not _present.has(sp):
		var found := false
		for a in map.size * map.size:
			if map.special[a] == sp:
				found = true
				break
		_present[sp] = found
	return _present[sp]


func _infra_materials() -> Dictionary:
	match tool:
		Tool.ROAD: return Config.BUILD_MATERIALS["road"]
		Tool.RAIL: return Config.BUILD_MATERIALS["rail"]
		Tool.POWERLINE: return Config.BUILD_MATERIALS["powerline"]
		Tool.BUS_STOP: return Config.BUILD_MATERIALS["bus_stop"]
		Tool.STATION: return Config.BUILD_MATERIALS["station"]
		Tool.PARK: return Config.BUILD_MATERIALS["park"]
	return {}


func materials_for(tiles: Array[Vector2i]) -> Dictionary:
	var sum := {}
	for t in tiles:
		var m := tile_materials(t)
		for r: String in m:
			sum[r] = float(sum.get(r, 0.0)) + float(m[r])
	return sum


func _tool_zone() -> int:
	match tool:
		Tool.RES: return Config.Zone.RES
		Tool.COM: return Config.Zone.COM
		Tool.IND, Tool.HIGHTECH: return Config.Zone.IND
	return Config.Zone.NONE


func _apply(tiles: Array[Vector2i]) -> void:
	if tool == Tool.INSPECT or tiles.is_empty():
		return
	var lock := locked_reason(tool)
	if lock != "":
		message.emit(lock)
		return
	var up := _upgrade_target()
	if up >= 0:
		_upgrade(up)
		return
	var total := 0
	var todo: Array[Vector2i] = []
	var all_valid := true
	for t in tiles:
		var c := tile_cost(t)
		if c < 0:
			all_valid = false
		if c > 0:
			total += c
			todo.append(t)
	var conv := _convert_target()
	if conv >= 0:
		_convert_to_salt(conv)
		return
	if _special_for_tool() != Config.Special.NONE:
		if not all_valid:
			var why := site_reason(_special_for_tool(), hover) if map.in_bounds(hover.x, hover.y) else ""
			message.emit(why if why != "" else "Hier ist kein Platz.")
			return
		todo = tiles
	if todo.is_empty():
		return
	var mats := materials_for(todo)
	var import_price: float = sim.build_need(mats)[1]
	if not sim.can_afford(total + import_price):
		if import_price > 0.0:
			message.emit("Nicht genug Geld (benötigt $%d, davon Zukauf Baumaterial $%d)" % [total + int(import_price), int(import_price)])
		else:
			message.emit("Nicht genug Geld (benötigt $%d)" % total)
		return

	var rect := Rect2i(todo[0], Vector2i.ONE)
	_recycled = {}
	if _special_for_tool() != Config.Special.NONE:
		_place_special(todo)
	else:
		for t in todo:
			rect = rect.merge(_apply_tile(t))
	for t in todo:
		rect = rect.merge(Rect2i(t, Vector2i.ONE))
	sim.spend(total)
	sim.use_build_materials(mats)
	if not _recycled.is_empty():
		var parts := PackedStringArray()
		for res: String in _recycled:
			parts.append("%d %s" % [roundi(float(_recycled[res])), Config.RESOURCES[res]["name"]])
		message.emit("Recycling: %s zurück ins Lager" % ", ".join(parts))
	map.notify_changed(rect)
	sim.refresh(sim.async_commute)   # im Spiel gestaffelt, in Tests sofort
	applied.emit(tool)


## keep_infra: Stromleitung, Gleis und Haltestellen bleiben (z.B. Straße über Gleis = Bahnübergang).
func _clear(i: int, keep_infra := false) -> void:
	map.hightech[i] = 0
	map.road[i] = 0
	map.zone[i] = Config.Zone.NONE
	map.level[i] = 0
	map.feature[i] = Config.Feature.NONE
	if not keep_infra:
		map.power_line[i] = 0
		map.rail[i] = 0
		map.transit[i] = Config.Transit.NONE


func _remove_special(i: int) -> Rect2i:
	var a := map.anchor[i]
	var s: int = Config.SPECIALS[map.special[a]]["size"]
	var ax := a % map.size
	var az := a / map.size
	for z in s:
		for x in s:
			var j := map.idx(ax + x, az + z)
			map.special[j] = Config.Special.NONE
			map.anchor[j] = -1
	return Rect2i(ax, az, s, s)


func _upgrade(a: int) -> void:
	var sp := _special_for_tool()
	var lv := map.special_level(a)
	if lv >= 3:
		message.emit("%s ist bereits voll ausgebaut." % Config.SPECIALS[sp]["name"])
		return
	var cost := int(Config.SPECIALS[sp]["upgrade"]) * lv
	var mats := Simulation.scale_materials(Config.SPECIAL_MATERIALS.get(sp, {}), Config.UPGRADE_MATERIALS * lv * sim.build_factor())
	var import_price: float = sim.build_need(mats)[1]
	if not sim.can_afford(cost + import_price):
		message.emit("Nicht genug Geld für den Ausbau (benötigt $%d)" % (cost + int(import_price)))
		return
	map.slevel[a] = lv + 1
	sim.spend(cost)
	sim.use_build_materials(mats)
	var s: int = Config.SPECIALS[sp]["size"]
	map.notify_changed(Rect2i(a % map.size, a / map.size, s, s))
	sim.refresh(sim.async_commute)   # im Spiel gestaffelt, in Tests sofort
	message.emit("%s ausgebaut auf Stufe %d" % [Config.SPECIALS[sp]["name"], lv + 1])
	applied.emit(tool)


func _place_special(tiles: Array[Vector2i]) -> void:
	var sp := _special_for_tool()
	var top := 0
	for t in tiles:
		top = maxi(top, map.h(t.x, t.y))
	var a := map.idx(tiles[0].x, tiles[0].y)
	for t in tiles:
		var i := map.idx(t.x, t.y)
		_clear(i)
		map.height[i] = top          # Fundament einebnen
		map.special[i] = sp
		map.anchor[i] = a
	map.slevel[a] = 1


## Gibt das geänderte Rechteck zurück (Sonderbauten können größer sein).
func _apply_tile(t: Vector2i) -> Rect2i:
	var i := map.idx(t.x, t.y)
	var r := Rect2i(t, Vector2i.ONE)
	match tool:
		Tool.ROAD:
			_clear(i, true)
			map.road[i] = Config.Road.STREET
		Tool.POWERLINE:
			map.feature[i] = Config.Feature.NONE
			map.power_line[i] = 1
		Tool.BUS_STOP:
			map.transit[i] = Config.Transit.BUS_STOP
		Tool.RAIL:
			map.feature[i] = Config.Feature.NONE
			map.rail[i] = 1
		Tool.STATION:
			map.transit[i] = Config.Transit.STATION
		Tool.RES, Tool.COM, Tool.IND, Tool.HIGHTECH:
			_clear(i)
			map.zone[i] = _tool_zone()
			map.hightech[i] = 1 if tool == Tool.HIGHTECH else 0
		Tool.BULLDOZE:
			if map.special[i] != Config.Special.NONE:
				var sa := map.anchor[i]
				var back_sp: Dictionary = sim.recycle_special(map.special[sa], map.special_level(sa), sa)
				for res: String in back_sp:
					_recycled[res] = float(_recycled.get(res, 0.0)) + float(back_sp[res])
				r = _remove_special(i)
			elif map.zone[i] != Config.Zone.NONE and map.level[i] >= 2:
				var back: Dictionary = sim.recycle(map.zone[i], map.level[i], i)
				for res: String in back:
					_recycled[res] = float(_recycled.get(res, 0.0)) + float(back[res])
			_clear(i)
		Tool.RAISE, Tool.LOWER:
			# Gebäude, Straßen, Gleise (samt Haltestelle/Bahnhof) und Parks passen nicht mehr -> weg
			map.level[i] = 0
			map.road[i] = 0
			map.rail[i] = 0
			map.transit[i] = Config.Transit.NONE
			if map.feature[i] == Config.Feature.PARK:
				map.feature[i] = Config.Feature.NONE
			map.height[i] += 1 if tool == Tool.RAISE else -1
			if map.is_water(t.x, t.y):
				_clear(i)
		Tool.TREE:
			_clear(i)
			map.feature[i] = Config.Feature.TREE
		Tool.PARK:
			_clear(i)
			map.feature[i] = Config.Feature.PARK
	return r


## Reichweite eines geplanten Bauwerks: Tile -> Farbe.
## Haltestelle: Straßen im Umkreis BUS_RANGE (Busnetz) + Gebäude, die dadurch neu Anschluss bekommen.
## Bahnhof: Straßen im Fußweg STATION_WALK (+ ganzes Busnetz, wenn eine Haltestelle in Fußweg-Nähe liegt).
## Dienste: Einzugskreis (Radius der Stufe, die der Klick baut bzw. ausbaut).
func range_preview(t: Vector2i) -> Dictionary:
	var out := {}
	if t.x < 0 or not map.in_bounds(t.x, t.y) or tile_cost(t) < 0:
		return out
	var n := map.size * map.size
	var roads := {}
	match tool:
		Tool.BUS_STOP, Tool.STATION:
			var r := Config.BUS_RANGE if tool == Tool.BUS_STOP else Config.STATION_WALK
			var feeder := false
			for dz in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if absi(dx) + absi(dz) > r or not map.is_road(t.x + dx, t.y + dz):
						continue
					var j := map.idx(t.x + dx, t.y + dz)
					roads[j] = true
					if tool == Tool.STATION and map.transit[j] == Config.Transit.BUS_STOP:
						feeder = true
			# Zubringer: Haltestelle nahe dem Bahnhof bindet ihr ganzes Busnetz an
			if feeder and sim.road_comp.size() == n:
				var comps := {}
				for j: int in roads:
					if map.transit[j] == Config.Transit.BUS_STOP:
						comps[sim.road_comp[j]] = true
				for j in n:
					if sim.bus_served[j] == 1 and comps.has(sim.road_comp[j]):
						roads[j] = true
			for j: int in roads:
				out[j] = RANGE_ROAD
			# Gebäude, deren Straßenanschluss im neuen Bereich liegt und die noch keinen Anschluss haben
			if sim.road_src.size() == n:
				for j in n:
					if map.zone[j] == Config.Zone.NONE or sim.road_dist[j] > Config.ROAD_ACCESS_RANGE:
						continue
					if roads.has(sim.road_src[j]) and not sim.has_transit(j):
						out[j] = RANGE_NEW
		_:
			var sp := _special_for_tool()
			if sp != Config.Special.NONE and Config.SPECIALS[sp].has("produce"):
				return _with_delivery(_resource_preview(t, sp), t, sp)
			if sp != Config.Special.NONE and Config.SPECIALS[sp].has("process"):
				return _with_delivery({}, t, sp)
			if sp in [Config.Special.NURSERY, Config.Special.PROSPECTOR]:
				var rr := Config.NURSERY_RANGE if sp == Config.Special.NURSERY else Config.PROSPECT_RANGE
				var ring := {}
				for z in range(t.y - rr, t.y + rr + 1):
					for x in range(t.x - rr, t.x + rr + 1):
						if map.in_bounds(x, z) and (absi(x - t.x) == rr or absi(z - t.y) == rr):
							ring[map.idx(x, z)] = RANGE_AREA
				return ring
			if sp == Config.Special.NONE or not (Config.SPECIALS[sp].has("service") or sp == Config.Special.RECYCLER):
				return out
			var up := _upgrade_target()
			var lv := mini(map.special_level(up) + 1, 3) if up >= 0 else 1
			var s: int = Config.SPECIALS[sp]["size"]
			var origin := Vector2i(up % map.size, up / map.size) if up >= 0 else t
			var half := (s - 1) * 0.5
			var rad: int = Simulation.service_radius_for(sp, lv)
			for dz in range(-rad, rad + s):
				for dx in range(-rad, rad + s):
					var x := origin.x + dx
					var z := origin.y + dz
					var d := Vector2(dx - half, dz - half).length()
					# nur der Rand (letzter Tile-Ring), die Fläche zeigt die Versorgungsansicht
					if map.in_bounds(x, z) and d <= rad and d > rad - 1.0 and not map.is_water(x, z):
						out[map.idx(x, z)] = RANGE_AREA
	return out


## Abbau-Gebäude: Vorkommen bzw. Bäume im Abbau-Umkreis in Rohstoff-Farbe, übrige Fläche des Umkreises blass.
func _resource_preview(t: Vector2i, sp: int) -> Dictionary:
	var out := {}
	var def: Dictionary = Config.SPECIALS[sp]
	var s: int = def["size"]
	var r := 0
	match def["produce"]:
		"wood": r = Config.LUMBER_RANGE
		"stone": r = Config.QUARRY_RANGE
		"pit": r = Config.PIT_RANGE
		"mine": r = Config.MINE_RANGE
		_: return out
	for z in range(t.y - r, t.y + s + r):
		for x in range(t.x - r, t.x + s + r):
			if not map.in_bounds(x, z) or map.is_water(x, z):
				continue
			var j := map.idx(x, z)
			var res := ""
			if def["produce"] == "wood" and map.feature[j] == Config.Feature.TREE:
				res = "wood"
			elif map.ore_amt[j] > 0:
				var o: String = Config.ORE_RESOURCE[map.ore[j]]
				if (def["produce"] == "pit" and o in ["sand", "clay"]) or (def["produce"] == "mine" and o in ["coal", "iron", "gold"]) \
						or (def["produce"] == "stone" and o == "stone"):
					res = o
			if res != "":
				var c: Color = Config.RESOURCES[res]["color"] if res != "wood" else Color(0.25, 0.85, 0.3)
				c.a = 0.8
				out[j] = c
			else:
				out[j] = Color(1, 1, 1, 0.12)
	return out


## Lieferweg-Anzeige: Rahmen um die Grundfläche grün (Straße zum Lager), gelb (Straße, aber anderes Netz), rot (keine Straße).
func _with_delivery(out: Dictionary, t: Vector2i, sp: int) -> Dictionary:
	var s: int = Config.SPECIALS[sp]["size"]
	var state := sim.delivery_at(t, s)
	var c: Color = [Color(1.0, 0.25, 0.2, 0.85), Color(1.0, 0.8, 0.2, 0.85), Color(0.3, 0.95, 0.4, 0.85)][state]
	for z in range(t.y - 1, t.y + s + 1):
		for x in range(t.x - 1, t.x + s + 1):
			var edge := (x == t.x - 1 or x == t.x + s) != (z == t.y - 1 or z == t.y + s)
			if edge and map.in_bounds(x, z) and (state == 0 or map.is_road(x, z)):
				out[map.idx(x, z)] = c
	return out


func _update_range() -> void:
	var mm := _range.multimesh
	var tiles := range_preview(hover) if not _dragging else {}
	mm.instance_count = tiles.size()
	var k := 0
	for j: int in tiles:
		var y := maxf(float(map.height[j]), Config.WATER_LEVEL - 0.2)
		mm.set_instance_transform(k, Transform3D(Basis(), Vector3((j % map.size) * B + B * 0.5, y + 0.1, (j / map.size) * B + B * 0.5)))
		mm.set_instance_color(k, tiles[j])
		k += 1


func _update_preview() -> void:
	_update_range()
	var mm := _preview.multimesh
	if tool == Tool.INSPECT or hover.x < 0:
		mm.instance_count = 0
		preview_site = ""
		preview_convert = false
		preview_cost_changed.emit(0, true)
		return
	var tiles := _affected_tiles()
	var total := 0
	var valid := true
	for t in tiles:
		var c := tile_cost(t)
		if c < 0:
			valid = false
		else:
			total += c
	var sp_prev := _special_for_tool()
	preview_convert = _convert_target() >= 0
	preview_site = site_reason(sp_prev, hover) if sp_prev != Config.Special.NONE and not preview_convert \
		and map.in_bounds(hover.x, hover.y) and locked_reason(tool) == "" else ""
	preview_materials = materials_for(tiles) if valid else {}
	var need := sim.build_need(preview_materials)
	preview_missing = need[0]
	preview_import = need[1]
	total += int(preview_import)
	valid = valid and sim.can_afford(total)
	var shown: Array[Vector2i] = []
	for t in tiles:
		if map.in_bounds(t.x, t.y):
			shown.append(t)
	mm.instance_count = shown.size()
	var zn := _tool_zone()
	for k in shown.size():
		var t := shown[k]
		var i := map.idx(t.x, t.y)
		var y := maxf(float(map.height[i]), Config.WATER_LEVEL - 0.2)
		mm.set_instance_transform(k, Transform3D(Basis(), Vector3(t.x * B + B * 0.5, y + 0.15, t.y * B + B * 0.5)))
		var col := PREVIEW_OK
		if not valid or tile_cost(t) < 0:
			col = PREVIEW_BAD
		elif zn != Config.Zone.NONE:
			col = suitability_color(sim.suitability(i, zn))
		mm.set_instance_color(k, col)
	preview_cost_changed.emit(total, valid)
