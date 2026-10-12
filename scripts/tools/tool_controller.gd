class_name ToolController
extends Node3D
## Maus-Picking, Werkzeug-Vorschau und Anwenden der Bauaktionen.

signal hover_changed(tile: Vector2i)
signal preview_cost_changed(cost: int, valid: bool)
signal tool_changed(tool: Tool)
signal message(text: String)
signal applied(tool: Tool)

enum Tool { INSPECT, ROAD, POWERLINE, BUS_STOP, RAIL, STATION, RES, COM, IND, COAL, WIND, TREE, PARK, RAISE, LOWER, BULLDOZE,
	POLICE, FIRE, SCHOOL, HOSPITAL, LIBRARY, CINEMA, TOWNHALL, THEATER, STADIUM }

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


func setup(city_map: CityMap, simulation: Simulation, cam: Camera3D) -> void:
	map = city_map
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
	match tool:
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
	return Config.Special.NONE


## Werkzeug noch gesperrt? Liefert Hinweistext oder "".
func locked_reason(t: Tool) -> String:
	var prev := tool
	tool = t
	var sp := _special_for_tool()
	tool = prev
	if sp == Config.Special.NONE:
		return ""
	var unlock: int = Config.SPECIALS[sp].get("unlock", 0)
	if sim.population < unlock:
		return "Verfügbar ab %d Einwohnern" % unlock
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
		Tool.RES, Tool.COM, Tool.IND:
			if water or special or rail or map.road[i] != 0: return -1
			if map.zone[i] == _tool_zone(): return 0
			return Config.COST_ZONE + demolish
		Tool.COAL, Tool.WIND, Tool.POLICE, Tool.FIRE, Tool.SCHOOL, Tool.HOSPITAL, \
				Tool.LIBRARY, Tool.CINEMA, Tool.TOWNHALL, Tool.THEATER, Tool.STADIUM:
			var sp := _special_for_tool()
			if locked_reason(tool) != "": return -1
			var up := _upgrade_target()
			if up >= 0:
				# Ausbau: nur das angeklickte Tile kostet
				if map.special_level(up) >= 3: return -1
				return int(Config.SPECIALS[sp]["upgrade"]) * map.special_level(up) if t == hover else 0
			# Kosten nur auf dem Ursprungs-Tile, Rest muss frei sein
			if water or special or building or rail or map.road[i] != 0: return -1
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


func _tool_zone() -> int:
	match tool:
		Tool.RES: return Config.Zone.RES
		Tool.COM: return Config.Zone.COM
		Tool.IND: return Config.Zone.IND
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
	if _special_for_tool() != Config.Special.NONE:
		if not all_valid:
			message.emit("Hier ist kein Platz.")
			return
		todo = tiles
	if todo.is_empty():
		return
	if not sim.can_afford(total):
		message.emit("Nicht genug Geld (benötigt $%d)" % total)
		return

	var rect := Rect2i(todo[0], Vector2i.ONE)
	if _special_for_tool() != Config.Special.NONE:
		_place_special(todo)
	else:
		for t in todo:
			rect = rect.merge(_apply_tile(t))
	for t in todo:
		rect = rect.merge(Rect2i(t, Vector2i.ONE))
	sim.spend(total)
	map.notify_changed(rect)
	sim.refresh(sim.async_commute)   # im Spiel gestaffelt, in Tests sofort
	applied.emit(tool)


## keep_infra: Stromleitung, Gleis und Haltestellen bleiben (z.B. Straße über Gleis = Bahnübergang).
func _clear(i: int, keep_infra := false) -> void:
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
	if not sim.can_afford(cost):
		message.emit("Nicht genug Geld für den Ausbau (benötigt $%d)" % cost)
		return
	map.slevel[a] = lv + 1
	sim.spend(cost)
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
		Tool.RES, Tool.COM, Tool.IND:
			_clear(i)
			map.zone[i] = _tool_zone()
		Tool.BULLDOZE:
			if map.special[i] != Config.Special.NONE:
				r = _remove_special(i)
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


func _update_preview() -> void:
	var mm := _preview.multimesh
	if tool == Tool.INSPECT or hover.x < 0:
		mm.instance_count = 0
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
