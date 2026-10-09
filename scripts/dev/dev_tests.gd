class_name DevTests
extends RefCounted
## Automatische Prüfungen, per Dev-Flag gestartet (siehe DevTools). Ausgabe auf der Konsole.
## game = Hauptszene (main.gd) mit map, sim, tools, cam, hud.


## Pendler-Performance, Save/Load-Roundtrip, Audio-Quellen nah/fern.
static func selftest(game: Node) -> void:
	var map: CityMap = game.map
	var sim: Simulation = game.sim
	var cam: CityCamera = game.cam
	var t0 := Time.get_ticks_usec()
	sim.refresh()
	print("refresh: %.1f ms  pop=%d jobs=%d stau=%.2f weg=%.1f unerreichbar=%d" % [
		(Time.get_ticks_usec() - t0) / 1000.0, sim.population, sim.jobs_com + sim.jobs_ind,
		sim.avg_congestion, sim.avg_commute, sim.unreachable_workers])
	var before := [sim.population, int(sim.money), sim.date_string(), hash(map.height), hash(map.level)]
	print("save: ", error_string(SaveManager.save("selftest", map, sim)))
	map.generate(12345)
	sim.reset()
	print("nach reset: pop=%d" % sim.population)
	print("load: ", error_string(SaveManager.load_slot("selftest", map, sim)))
	var after := [sim.population, int(sim.money), sim.date_string(), hash(map.height), hash(map.level)]
	print("roundtrip ok: ", before == after, "  ", before, " / ", after)
	DirAccess.remove_absolute(SaveManager.path("selftest"))
	for dist: float in [20.0, 150.0]:
		cam._dist = dist
		Audio._scan_sources()
		var gains := []
		for p in Audio._traffic + Audio._industry:
			gains.append(snappedf(p.get_meta("target", 0.0), 0.01))
		print("audio dist=%d ziel-gain verkehr+industrie=%s" % [dist, gains])
	cam._dist = cam._target_dist


## Echtes Maus-Ziehen über Input-Events: Zone als Fläche, Straße als Linie.
static func dragtest(game: Node) -> void:
	var map: CityMap = game.map
	var tools: ToolController = game.tools
	var cam: CityCamera = game.cam
	var c := map.size / 2
	var cases := [
		[ToolController.Tool.RES, Vector2i(c - 12, c + 13), Vector2i(c - 9, c + 15)],
		[ToolController.Tool.ROAD, Vector2i(c - 12, c + 17), Vector2i(c - 6, c + 19)],
	]
	for cs in cases:
		tools.set_tool(cs[0])
		var before: float = game.sim.money
		var a := cam.camera.unproject_position(_tile_center(map, cs[1]))
		var b := cam.camera.unproject_position(_tile_center(map, cs[2]))
		for ev in [_mouse_move(a), _mouse_btn(a, true), _mouse_move(a.lerp(b, 0.5)), _mouse_move(b), _mouse_btn(b, false)]:
			Input.parse_input_event(ev)
			await game.get_tree().process_frame
		var count := 0
		var rect := Rect2i(cs[1], Vector2i.ONE).expand(cs[2] + Vector2i.ONE)
		for z in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var i := map.idx(x, z)
				if (cs[0] == ToolController.Tool.RES and map.zone[i] == Config.Zone.RES) or \
						(cs[0] == ToolController.Tool.ROAD and map.road[i] != 0):
					count += 1
		print("dragtest %s %s->%s: %d Tiles, Kosten $%d" % [ToolController.TOOLS[cs[0]]["name"], cs[1], cs[2],
			count, int(before - game.sim.money)])
	tools.set_tool(ToolController.Tool.INSPECT)


## Autos auf Hauptstraßen fahren rechts der Mittellinie (nur Fahrten innerhalb des Straßenpaars).
static func lanetest(game: Node) -> void:
	var map: CityMap = game.map
	var traffic: Traffic = game.get_node("Traffic")
	var ok := 0
	var wrong := 0
	var on_wide := 0
	for f in 240:
		await game.get_tree().process_frame
		for car in traffic._cars:
			if map.wide_partner(car.from.x, car.from.y) != Vector2i.ZERO:
				on_wide += 1
			if car.t < 0.2 or car.t > 0.8:
				continue
			var p_from := map.wide_partner(car.from.x, car.from.y)
			var p_to := map.wide_partner(car.to.x, car.to.y)
			var dir: Vector2i = car.to - car.from
			if p_from == Vector2i.ZERO or p_to == Vector2i.ZERO or (p_from.x != 0) == (dir.x != 0):
				continue
			var on: Vector2i = car.from if car.t < 0.5 else car.to
			var partner := map.wide_partner(on.x, on.y)
			var B := Config.TILE_BLOCKS
			var right := Vector2(-dir.y, dir.x)
			var side: float
			if partner.x == 0:
				side = (car.pos.z - (on.y + (1 if partner.y == 1 else 0)) * B) * right.y
			else:
				side = (car.pos.x - (on.x + (1 if partner.x == 1 else 0)) * B) * right.x
			if side > 0.0: ok += 1
			else: wrong += 1
	print("lanetest Hauptstraße: %d Messungen rechts der Mittellinie, %d falsch (Autos auf Hauptstraße: %d, gesamt %d)" % [
		ok, wrong, on_wide, traffic._cars.size()])


## Synthetischer Korridor: Wohnviertel West, Industrie Ost, 1.500 Pendler; Ausbau-Varianten.
static func traffictest() -> void:
	var m := CityMap.new()
	m.height.fill(6)
	var s := Simulation.new()
	s.map = m
	var street := Config.Road.STREET
	var link := func(z: int) -> void:
		for x in range(12, 40):
			m.road[m.idx(x, z)] = street
	for dist_x: int in [4, 40]:
		for z in range(10, 30):
			for x in range(dist_x, dist_x + 9):
				var i := m.idx(x, z)
				if (x - dist_x) % 4 == 0 or (z - 10) % 4 == 0:
					m.road[i] = street
				else:
					m.zone[i] = Config.Zone.RES if dist_x == 4 else Config.Zone.IND
					m.level[i] = 2
	var measure := func(label: String) -> void:
		m.notify_changed(Rect2i(0, 0, m.size, m.size))   # Karte direkt geändert -> Caches erneuern
		for k in 5:
			s.refresh()
		var link_max := 0.0
		for x in range(14, 38):
			for z in range(10, 30):
				link_max = maxf(link_max, s.congestion[m.idx(x, z)])
		print("traffictest %-30s Verbindung max %3d%%  Stau Ø %3d%%  Weg Ø %5.1f  ÖPNV %2d%% (Bus %d, Bahn %d)" % [label,
			roundi(link_max * 100), roundi(s.avg_congestion * 100), s.avg_commute,
			roundi(s.transit_share * 100), int(s.bus_riders), int(s.rail_riders)])
	s.powered.resize(m.size * m.size)
	link.call(14)
	measure.call("1 Verbindung")
	link.call(22)
	measure.call("+ Parallelstraße")
	link.call(15)
	link.call(23)
	measure.call("beide als Hauptstraße")
	# Zurück auf 1 Verbindung, dann Bus bzw. Bahn
	for z: int in [15, 22, 23]:
		for x in range(12, 40):
			m.road[m.idx(x, z)] = 0
	s.congestion.fill(0.0)
	for dist_x: int in [4, 40]:
		for z in range(10, 30, 8):
			for x in range(dist_x, dist_x + 9, 8):
				m.transit[m.idx(x, z)] = Config.Transit.BUS_STOP
	measure.call("1 Verbindung + Bushaltestellen")
	m.transit.fill(0)
	for x in range(6, 47):
		m.rail[m.idx(x, 31)] = 1
	m.transit[m.idx(8, 31)] = Config.Transit.STATION
	m.transit[m.idx(44, 31)] = Config.Transit.STATION
	s.congestion.fill(0.0)
	measure.call("1 Verbindung + Bahn")
	# Bahnhöfe an der Ecke der Viertel (nur 1 Straße im Fußweg) -> ohne/mit Zubringerbussen
	for x in range(0, 64):
		m.rail[m.idx(x, 31)] = 0
		m.transit[m.idx(x, 31)] = 0
	for x in range(2, 51):
		m.rail[m.idx(x, 31)] = 1
	m.transit[m.idx(2, 31)] = Config.Transit.STATION
	m.transit[m.idx(50, 31)] = Config.Transit.STATION
	s.congestion.fill(0.0)
	measure.call("Bahnhöfe an der Ecke, ohne Bus")
	for dist_x: int in [4, 40]:
		for z: int in [10, 18, 26]:
			for x in range(dist_x, dist_x + 9, 4):
				m.transit[m.idx(x, z)] = Config.Transit.BUS_STOP
	m.transit[m.idx(4, 29)] = Config.Transit.BUS_STOP     # Haltestellen am Bahnhof
	m.transit[m.idx(48, 29)] = Config.Transit.BUS_STOP
	s.congestion.fill(0.0)
	measure.call("Bahnhöfe an der Ecke + Zubringer")
	s.free()


## Hauptstraßen-Erkennung: Bänder in beiden Achsen, 4 Reihen breit, mit Querstraße.
static func widetest() -> void:
	var m := CityMap.new()
	m.height.fill(6)
	var check := func(label: String, tiles: Array, expect_axis_x: bool) -> void:
		var ok := 0
		var bad := 0
		for t: Vector2i in tiles:
			var p := m.wide_partner(t.x, t.y)
			# Fahrt entlang X -> Partner quer (0,±1)
			if p != Vector2i.ZERO and (p.x == 0) == expect_axis_x:
				ok += 1
			else:
				bad += 1
		print("widetest %-34s %d richtig, %d falsch" % [label, ok, bad])
	var band_x: Array = []
	for x in range(5, 20):
		for z in [5, 6]:
			band_x.append(Vector2i(x, z))
	var band_z: Array = []
	for z in range(10, 25):
		for x in [30, 31]:
			band_z.append(Vector2i(x, z))
	var band4: Array = []
	for x in range(5, 20):
		for z in range(40, 44):
			band4.append(Vector2i(x, z))
	for t: Vector2i in band_x + band_z + band4:
		m.road[m.idx(t.x, t.y)] = 1
	# Querstraße durch das 2er-Band entlang X
	for z in range(0, 12):
		m.road[m.idx(12, z)] = 1
	m.notify_changed(Rect2i(0, 0, m.size, m.size))
	var band_x_no_cross: Array = band_x.filter(func(t): return t.x != 12)
	check.call("2er-Band entlang X (ohne Kreuzung)", band_x_no_cross, true)
	check.call("2er-Band entlang Z", band_z, false)
	check.call("4er-Band entlang X (2 Hauptstraßen)", band4, true)
	var cross_ok := m.wide_partner(12, 2) == Vector2i.ZERO and m.wide_partner(12, 9) == Vector2i.ZERO
	print("widetest Querstraße bleibt normal: ", cross_ok)


## Spielt `seconds` Sekunden und protokolliert Frame-Zeiten; Ruckler (> 25 ms) mit Ursachen.
static func profile(game: Node, seconds := 15.0) -> void:
	# Fenster nach vorn: verdeckte Fenster werden von macOS gedrosselt (verfälscht Messung)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
	Perf.enabled = true
	Perf.total = {}
	Perf.take_frame()
	var times: Array[float] = []
	var spikes: Array = []
	var last := Time.get_ticks_usec()
	var start := last
	while (Time.get_ticks_usec() - start) / 1e6 < seconds:
		await game.get_tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		times.append(ms)
		var sections := Perf.take_frame()
		if ms > 25.0:
			spikes.append([ms, sections, (now - start) / 1e6])
	Perf.enabled = false
	var sorted := times.duplicate()
	sorted.sort()
	var avg := 0.0
	for t in times:
		avg += t
	avg /= maxf(1.0, times.size())
	print("profile: %d Frames, Ø %.1f ms (%.0f FPS), Median %.1f ms, P95 %.1f ms, Max %.1f ms, Ruckler >25ms: %d" % [
		times.size(), avg, 1000.0 / avg, sorted[sorted.size() / 2], sorted[int(sorted.size() * 0.95)],
		sorted[sorted.size() - 1], spikes.size()])
	spikes.sort_custom(func(a, b): return a[0] > b[0])
	for k in mini(6, spikes.size()):
		var parts := PackedStringArray()
		var sec: Dictionary = spikes[k][1]
		var keys := sec.keys()
		keys.sort_custom(func(a, b): return sec[a] > sec[b])
		for key in keys:
			parts.append("%s %.1f" % [key, sec[key] / 1000.0])
		print("  Ruckler %.1f ms bei %.1fs: %s" % [spikes[k][0], spikes[k][2], ", ".join(parts)])
	print("  Summen (ms gesamt / Anzahl / max ms):")
	var tk := Perf.total.keys()
	tk.sort_custom(func(a, b): return Perf.total[a][0] > Perf.total[b][0])
	for key in tk:
		var v: Array = Perf.total[key]
		print("    %-28s %8.1f / %4d / %6.1f" % [key, v[0] / 1000.0, v[1], v[2] / 1000.0])


## Gleiche Stadt 36 Monate ohne vs. mit Diensten (gleicher Zufalls-Seed).
static func servicetest(game: Node) -> void:
	var map: CityMap = game.map
	var sim: Simulation = game.sim
	var tools: ToolController = game.tools
	SaveManager.save("servicetest", map, sim)
	var report := func(label: String) -> void:
		var crime_sum := 0.0
		var cnt := 0
		for i in map.size * map.size:
			if map.level[i] > 0 and map.zone[i] != Config.Zone.NONE:
				crime_sum += sim.crime[i]
				cnt += 1
		print("servicetest %-22s Einw. %5d  Jobs %4d  Zufriedenheit %3d%%  Kriminalität Ø %3d%%  Brände %d  Kasse $%d" % [
			label, sim.population, sim.jobs_com + sim.jobs_ind, roundi(sim.city_happiness * 100),
			roundi(crime_sum / maxf(1, cnt) * 100), sim.fires_total, int(sim.money)])
	report.call("Start")
	for variant: String in ["ohne Dienste", "mit Diensten"]:
		SaveManager.load_slot("servicetest", map, sim)
		sim.fires_total = 0
		if variant == "mit Diensten":
			sim.money += 20000
			for t: ToolController.Tool in [ToolController.Tool.POLICE, ToolController.Tool.FIRE,
					ToolController.Tool.SCHOOL, ToolController.Tool.HOSPITAL]:
				_place_near_center(map, tools, t)
		sim._rng.seed = 7
		for m in 36:
			sim.tick_month()
		report.call(variant)
	# Ausbau: Polizei per erneutem Klick auf Stufe 3, danach weiterer Klick wird abgelehnt
	for i in map.size * map.size:
		if map.anchor[i] == i and map.special[i] == Config.Special.POLICE:
			tools.set_tool(ToolController.Tool.POLICE)
			tools.hover = Vector2i(i % map.size, i / map.size)
			var levels := [map.special_level(i)]
			var money_before := sim.money
			for k in 3:
				tools._apply(tools._affected_tiles())
				levels.append(map.special_level(i))
			print("servicetest Ausbau Polizei: Stufen %s, Kosten $%d, Reichweite jetzt %d Tiles" % [
				levels, int(money_before - sim.money), Config.SERVICE_RADIUS[map.special_level(i)]])
			break
	tools.set_tool(ToolController.Tool.INSPECT)
	DirAccess.remove_absolute(SaveManager.path("servicetest"))


## Erstes freies Plätzchen spiralförmig um die Kartenmitte.
static func _place_near_center(map: CityMap, tools: ToolController, t: ToolController.Tool) -> void:
	var c := map.size / 2
	tools.set_tool(t)
	for r in range(1, 20):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				tools.hover = Vector2i(c + dx, c + dz)
				var ok := true
				var cost := 0
				for p in tools._affected_tiles():
					var k := tools.tile_cost(p)
					if k < 0:
						ok = false
						break
					cost += k
				if ok and cost > 0:
					tools._apply(tools._affected_tiles())
					return


## Mauspicking in Bildmitte trifft das Tile unter dem Kamerafokus (auch bei skaliertem Fenster).
static func pickcheck(game: Node) -> void:
	for i in 10:
		await game.get_tree().process_frame
	var vp: Viewport = game.get_viewport()
	var center := vp.get_visible_rect().size * 0.5
	var cam: CityCamera = game.cam
	print("pickcheck window=%s visible=%s pick(center)=%s pivot=%s" % [DisplayServer.window_get_size(),
		vp.get_visible_rect().size, game.tools.pick(center),
		Vector2i(floori(cam.position.x / Config.TILE_BLOCKS), floori(cam.position.z / Config.TILE_BLOCKS))])


static func _tile_center(map: CityMap, t: Vector2i) -> Vector3:
	return Vector3((t.x + 0.5) * Config.TILE_BLOCKS, map.h(t.x, t.y), (t.y + 0.5) * Config.TILE_BLOCKS)


static func _mouse_move(p: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	return e


static func _mouse_btn(p: Vector2, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = p
	e.global_position = p
	return e
