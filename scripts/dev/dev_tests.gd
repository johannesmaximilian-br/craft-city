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
	# Testfläche einebnen und freiräumen (Landschaft der Demo hängt von der Kartengröße ab)
	var area := Rect2i(c - 13, c + 12, 9, 9)
	var flat := maxi(map.h(c, c), Config.WATER_LEVEL + 1)
	for z in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var i := map.idx(x, z)
			map.height[i] = flat
			map.feature[i] = Config.Feature.NONE
			map.zone[i] = Config.Zone.NONE
			map.level[i] = 0
			map.road[i] = 0
			map.special[i] = Config.Special.NONE
			map.anchor[i] = -1
	map.notify_changed(area)
	for k in 3:
		await game.get_tree().process_frame
	# Echte Eingabe-Pipeline nötig (Test-Ereignisse sind als synthetic markiert); Nutzer-Eingaben bleiben dank Meta gesperrt
	game.get_viewport().gui_disable_input = false
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
	game.get_viewport().gui_disable_input = DevTools.automated


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
		_remove_specials(map, sim, "")      # Demo-Stadt hat schon Dienste
		sim.fires_total = 0
		if variant == "mit Diensten":
			sim.money += 20000
			for t: ToolController.Tool in [ToolController.Tool.POLICE, ToolController.Tool.FIRE,
					ToolController.Tool.SCHOOL, ToolController.Tool.HOSPITAL]:
				_place_near_center(map, tools, t)
		sim._rng.seed = 7
		var dept: FireDept = game.fire_dept
		dept._rng.seed = 7
		var burned0 := dept.burned_total
		var ext0 := dept.extinguished_total
		var log_burn := func(text: String, _t: Vector2i) -> void:
			if text.begins_with("Abgebrannt"):
				print("servicetest   ", text)
		dept.alert.connect(log_burn)
		for m in 36:
			sim.tick_month()
			dept.advance(Simulation.SECONDS_PER_MONTH[1])
		dept.alert.disconnect(log_burn)
		report.call(variant)
		print("servicetest %-22s Brände: %d abgebrannt, %d gelöscht" % ["", dept.burned_total - burned0,
			dept.extinguished_total - ext0])
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


## Brand nahe der Feuerwache wird gelöscht, Brand ohne Brandschutz brennt ab (Ruine, keine Neubebauung).
static func firetest(game: Node) -> void:
	var map: CityMap = game.map
	var sim: Simulation = game.sim
	var dept: FireDept = game.fire_dept
	SaveManager.save("firetest", map, sim)
	sim.speed = 0
	var cov: PackedFloat32Array = sim.coverage["fire"]
	var near := -1
	var far := -1
	var base_risk := 0.0
	var risk := 0.0
	for i in map.size * map.size:
		if map.level[i] == 0 or map.zone[i] == Config.Zone.NONE or map.burning[i] > 0:
			continue
		var f := Config.FIRE_IND_FACTOR if map.zone[i] == Config.Zone.IND else 1.0
		base_risk += Config.FIRE_RISK * f
		risk += Config.FIRE_RISK * f * pow(1.0 - minf(cov[i], 1.0), 2.0)
		if sim._src(i) >= 0 and (near < 0 or cov[i] > cov[near]):
			near = i
		if cov[i] <= 0.0 and sim._src(i) >= 0:
			far = i
	print("firetest Ausbrüche/Jahr erwartet: ohne Feuerwehr %.1f, mit %.1f" % [base_risk * 12.0, risk * 12.0])
	# 1) Brand nahe der Wache
	var lv_near := map.level[near]
	map.burning[near] = 1
	map.notify_changed(Rect2i(near % map.size, near / map.size, 1, 1), false)
	var status := dept.status_text(near)
	var t := _fire_until_out(dept, near)
	print("firetest nah (Schutz %d%%): %s, %s nach %.1fs, Stufe %d -> %d, Zug zurück: %s" % [roundi(cov[near] * 100), status,
		"gelöscht" if map.level[near] > 0 else "ABGEBRANNT", t, lv_near, map.level[near], dept.trucks.is_empty()])
	# 2) ohne Feuerwehr: brennt ab, Ruine blockiert Neubau
	_remove_specials(map, sim, "fire")
	if far < 0:
		far = near
	map.burning[far] = 1
	map.notify_changed(Rect2i(far % map.size, far / map.size, 1, 1), false)
	status = dept.status_text(far)
	var burned0 := dept.burned_total
	t = _fire_until_out(dept, far)
	sim.tick_month()
	var spread := dept.burned_total - burned0 - 1 + dept.fires.size()
	print("firetest ohne Wache: %s, %s nach %.1fs, Ruine %d Monate, Stufe nach 1 Monat %d, Ausbreitung %d" % [
		status, "abgebrannt" if map.ruin[far] > 0 else "NICHT ABGEBRANNT", t, map.ruin[far], map.level[far], spread])
	SaveManager.load_slot("firetest", map, sim)
	DirAccess.remove_absolute(SaveManager.path("firetest"))
	_fire_industry_only()


## Reines Industriegebiet (0 Einwohner) mit Feuerwache direkt daneben: brennt trotzdem ab und zu, Wache löscht.
static func _fire_industry_only() -> void:
	var m := CityMap.new()
	m.height.fill(6)
	var s := Simulation.new()
	s.map = m
	s.powered.resize(m.size * m.size)
	for z in range(10, 20):
		m.road[m.idx(9, z)] = 1
		for x in range(10, 13):
			m.zone[m.idx(x, z)] = Config.Zone.IND
			m.level[m.idx(x, z)] = 2
	var st := m.idx(8, 14)
	m.special[st] = Config.Special.FIRE
	m.anchor[st] = st
	m.slevel[st] = 1
	var wind := m.idx(7, 14)         # Feuerwache braucht Strom
	m.special[wind] = Config.Special.WIND
	m.anchor[wind] = wind
	m.notify_changed(Rect2i(0, 0, m.size, m.size))
	s.refresh()
	var dept := FireDept.new()
	dept.setup(m, s)
	s._rng.seed = 3
	dept._rng.seed = 3
	var statuses := {}
	dept.alert.connect(func(text: String, _t: Vector2i) -> void:
		var key := text.get_slice(" - ", 1)
		statuses[key] = int(statuses.get(key, 0)) + 1)
	for k in 120:       # nur Brand-Etappe: ohne Strom würde die Industrie sonst verfallen
		s._fires()
		dept.advance(Simulation.SECONDS_PER_MONTH[1])
	print("firetest   Meldungen: %s" % statuses)
	print("firetest Industrie ohne Einwohner (30 Gebäude, Wache daneben, Auslastung %d%%): 10 Jahre -> %d Ausbrüche, %d gelöscht, %d abgebrannt" % [
		roundi(float(s.service_load.get(st, 0.0)) * 100), s.fires_total, dept.extinguished_total, dept.burned_total])
	dept.free()
	s.free()


static func _fire_until_out(dept: FireDept, i: int) -> float:
	var t := 0.0
	while dept.fires.has(i) and t < 30.0:
		dept.advance(0.1)
		t += 0.1
	for k in 100:        # Rückfahrt abwarten
		dept.advance(0.1)
	return t


## Sonderbauten einer Dienst-Kategorie entfernen ("" = alle Dienste).
static func _remove_specials(map: CityMap, sim: Simulation, service: String) -> void:
	for i in map.size * map.size:
		var a := map.anchor[i]
		if a < 0:
			continue
		var def: Dictionary = Config.SPECIALS[map.special[a]]
		if def.has("service") and (service == "" or def["service"] == service):
			if i != a:
				map.special[i] = Config.Special.NONE
				map.anchor[i] = -1
	for i in map.size * map.size:
		if map.anchor[i] == i and Config.SPECIALS[map.special[i]].has("service") \
				and (service == "" or Config.SPECIALS[map.special[i]]["service"] == service):
			map.special[i] = Config.Special.NONE
			map.anchor[i] = -1
			map.slevel[i] = 0
	map.notify_changed(Rect2i(0, 0, map.size, map.size))
	sim.refresh()


## Vorstadt nur per Bahn angebunden (eigenes Straßennetz) mit 4 Haltestellen -> bekommt eigene Busse.
static func bustest(game: Node) -> void:
	var map: CityMap = game.map
	var traffic: Traffic = game.get_node("Traffic")
	SaveManager.save("bustest", map, game.sim)
	var x0 := 2
	var z0 := 54
	for z in range(z0, z0 + 8):
		for x in range(x0, x0 + 8):
			var i := map.idx(x, z)
			map.height[i] = 6
			map.zone[i] = Config.Zone.NONE
			map.special[i] = Config.Special.NONE
			map.anchor[i] = -1
			map.rail[i] = 0
			map.transit[i] = 0
			map.road[i] = 1 if x == x0 or z == z0 or x == x0 + 7 or z == z0 + 7 else 0
	for p: Vector2i in [Vector2i(x0, z0 + 3), Vector2i(x0 + 7, z0 + 3), Vector2i(x0 + 3, z0), Vector2i(x0 + 3, z0 + 7)]:
		map.transit[map.idx(p.x, p.y)] = Config.Transit.BUS_STOP
	map.notify_changed(Rect2i(x0 - 1, z0 - 1, 10, 10))
	for k in 20:
		traffic._adjust_buses()
	var per_group := PackedInt32Array()
	per_group.resize(traffic._stop_groups.size())
	var suburb := -1
	for b in traffic._buses:
		per_group[b.group] += 1
	for g in traffic._stop_groups.size():
		var first: Vector2i = traffic._stop_groups[g][0]
		if first.x >= x0 and first.x < x0 + 8 and first.y >= z0:
			suburb = g
	print("bustest Netze mit Haltestellen: %d, Busse je Netz %s, Vorstadt-Netz %d hat %d Busse" % [
		traffic._stop_groups.size(), per_group, suburb, per_group[suburb] if suburb >= 0 else 0])
	SaveManager.load_slot("bustest", map, game.sim)
	DirAccess.remove_absolute(SaveManager.path("bustest"))


## Zufriedenheit: Aufschlüsselung + Warnung bei starkem Abfall (Steuer hoch bzw. Polizei weg).
static func happytest(game: Node) -> void:
	var map: CityMap = game.map
	var sim: Simulation = game.sim
	SaveManager.save("happytest", map, sim)
	var msgs: Array[String] = []
	var log_msg := func(t: String) -> void:
		if t.begins_with("Zufriedenheit"):
			msgs.append(t)
	sim.message.connect(log_msg)
	var total := Config.HAPPY_BASE
	for k: String in sim.happy_parts:
		total += float(sim.happy_parts[k])
	print("happytest Stadt %d%%, Summe der Teile %d%%, schlechtester Teil: %s" % [
		roundi(sim.city_happiness * 100), roundi(total * 100), sim.happiness_report()[0]])
	for scenario: String in ["Steuer 20%", "Polizei abgerissen"]:
		SaveManager.load_slot("happytest", map, sim)
		for m in 3:
			sim.tick_month()
		msgs.clear()
		if scenario == "Steuer 20%":
			sim.tax[Config.Zone.RES] = 0.2
		else:
			_remove_specials(map, sim, "police")
		for m in 3:
			sim.tick_month()
		print("happytest %-20s -> %d%%, Meldungen: %s" % [scenario, roundi(sim.city_happiness * 100), msgs])
	sim.message.disconnect(log_msg)
	SaveManager.load_slot("happytest", map, sim)
	DirAccess.remove_absolute(SaveManager.path("happytest"))


## Geld-Cheat über echtes Tastenereignis (Strg+Shift+G); ohne Modifier wählt G weiter das Terrain-Werkzeug.
static func cheattest(game: Node) -> void:
	var sim: Simulation = game.sim
	var before := sim.money
	var e := InputEventKey.new()
	e.set_meta("synthetic", true)
	e.keycode = KEY_G
	e.pressed = true
	e.ctrl_pressed = true
	e.shift_pressed = true
	game.hud._unhandled_key_input(e)
	var after := sim.money
	e.ctrl_pressed = false
	e.shift_pressed = false
	game.hud._unhandled_key_input(e)
	print("cheattest Geld %d -> %d (+%d), G ohne Modifier -> Werkzeug %s" % [before, after, after - before,
		ToolController.TOOLS[game.tools.tool]["name"]])
	game.tools.set_tool(ToolController.Tool.INSPECT)


## Grüngürtel: Verschmutzung am Wohnhaus ohne / mit Baumreihe / mit Parks; Terraforming reißt Straße ab.
static func greentest(game: Node) -> void:
	var m := CityMap.new()
	m.height.fill(6)
	var s := Simulation.new()
	s.map = m
	s.powered.resize(m.size * m.size)
	# Industrie (Stufe 3) bei x 10..12, Wohnhaus bei x 16, dazwischen Platz für Grün (x 13..15)
	for z in range(10, 13):
		for x in range(10, 13):
			m.zone[m.idx(x, z)] = Config.Zone.IND
			m.level[m.idx(x, z)] = 3
	var home := m.idx(16, 11)
	m.zone[home] = Config.Zone.RES
	m.level[home] = 1
	var measure := func(label: String) -> void:
		m.notify_changed(Rect2i(0, 0, m.size, m.size))
		s.refresh()
		print("greentest %-18s Verschmutzung am Wohnhaus %.2f (Filter %d%%), Bodenwert %d%%, Park-Zufriedenheit +%d" % [label,
			s.pollution[home], roundi(s.green_filter[home] * 100), roundi(s.land_value[home] * 100),
			roundi(minf(s.parks_near[home] * Config.HAPPY_PARK, Config.HAPPY_PARK_MAX) * 100)])
	measure.call("ohne Grün")
	for z in range(8, 15):
		for x in range(14, 16):
			m.feature[m.idx(x, z)] = Config.Feature.TREE
	measure.call("Baumgürtel 2 breit")
	for z in range(8, 15):
		for x in range(14, 16):
			m.feature[m.idx(x, z)] = Config.Feature.PARK
	measure.call("Parkgürtel 2 breit")
	s.free()
	# Terraforming auf Straße/Gleis/Park reißt ab
	var map: CityMap = game.map
	var tools: ToolController = game.tools
	var road := -1
	for i in map.size * map.size:
		if map.road[i] != 0 and map.rail[i] == 0 and map.height[i] < Config.MAX_HEIGHT:
			road = i
			break
	tools.set_tool(ToolController.Tool.RAISE)
	var t := Vector2i(road % map.size, road / map.size)
	tools.hover = t
	var cost := tools.tile_cost(t)
	tools._apply([t] as Array[Vector2i])
	print("greentest Terrain anheben auf Straße %s: Kosten $%d, Straße danach %d (0 = abgerissen)" % [t, cost, map.road[road]])
	tools.set_tool(ToolController.Tool.INSPECT)


## Theater + Stadion in die Demo-Stadt setzen (Freischaltung per Einwohnerzahl wird übergangen).
static func place_venues(game: Node) -> void:
	var sim: Simulation = game.sim
	sim.money += 40000
	for t: ToolController.Tool in [ToolController.Tool.STADIUM, ToolController.Tool.THEATER]:
		sim.population = 6000          # Bauen ruft refresh() -> Einwohnerzahl wieder echt
		_place_near_center(game.map, game.tools, t)
	game.tools.set_tool(ToolController.Tool.INSPECT)
	sim.refresh()


## Stadion/Theater: Kundschaft fürs Gewerbe, Verkehr am Veranstaltungstag, Bus/Bahn entlastet.
static func venuetest(game: Node) -> void:
	var map: CityMap = game.map
	var sim: Simulation = game.sim
	SaveManager.save("venuetest", map, sim)
	var com_before := sim.demand_com
	place_venues(game)
	var vs := sim.venues()
	print("venuetest platziert: %s" % [Array(vs).map(func(a: int) -> String: return "%s bei %d,%d" % [
		Config.SPECIALS[map.special[a]]["name"], a % map.size, a / map.size])])
	for a in vs:
		var name: String = Config.SPECIALS[map.special[a]]["name"]
		var jams := []
		for m in 3:
			sim.month = m
			sim.refresh()
			jams.append("%s %d%%" % ["Event" if sim.venue_has_event(a) else "-", roundi(float(sim.venue_jam.get(a, 0.0)) * 100)])
		# Kundschaft am nächsten Gewerbe-Tile
		var best := -1
		for i in map.size * map.size:
			if map.zone[i] == Config.Zone.COM and (best < 0 or absi(i % map.size - a % map.size) + absi(i / map.size - a / map.size)
					< absi(best % map.size - a % map.size) + absi(best / map.size - a / map.size)):
				best = i
		print("venuetest %-8s Besucher %d, Straßen-Auslastung Monat 0..2: %s, Kundschaft Gewerbe %d,%d: %d" % [name,
			int(sim.venue_visitors(a)), jams, best % map.size, best / map.size, int(sim.customers[best])])
	print("venuetest Gewerbe-Nachfrage %.2f -> %.2f" % [com_before, sim.demand_com])
	SaveManager.load_slot("venuetest", map, sim)
	DirAccess.remove_absolute(SaveManager.path("venuetest"))


## Zonen-Idealformen: Gewerbe (Tiefe + Weg zur Kreuzung), Industrie-Ballung, Wohnen Nachbarschaft + Villenlage.
static func zonetest() -> void:
	var m := CityMap.new()
	m.height.fill(6)
	var s := Simulation.new()
	s.map = m
	s.powered.resize(m.size * m.size)
	var road := func(x0: int, z0: int, x1: int, z1: int) -> void:
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				m.road[m.idx(x, z)] = 1
	var zone_rect := func(zn: int, x0: int, z0: int, w: int, h: int) -> void:
		for z in range(z0, z0 + h):
			for x in range(x0, x0 + w):
				m.zone[m.idx(x, z)] = zn
				m.level[m.idx(x, z)] = 1
	# A) Gewerbe 3x3, Straßen rundum (x 2..6, z 2..6)
	road.call(2, 2, 6, 2); road.call(2, 6, 6, 6); road.call(2, 2, 2, 6); road.call(6, 2, 6, 6)
	zone_rect.call(Config.Zone.COM, 3, 3, 3, 3)
	# B) Gewerbe 10x2 an Straße z=10 mit Querstraßen an beiden Enden (x 10 und 21)
	road.call(8, 10, 40, 10); road.call(10, 8, 10, 14); road.call(21, 8, 21, 14)
	zone_rect.call(Config.Zone.COM, 11, 11, 10, 2)
	# C) Gewerbe 16x1 ohne Querstraße (x 23..38) an derselben Straße
	zone_rect.call(Config.Zone.COM, 23, 11, 16, 1)
	# D) Industrie 3x3 und 3x6 an Straße z=20
	road.call(2, 20, 30, 20)
	zone_rect.call(Config.Zone.IND, 3, 21, 3, 3)
	zone_rect.call(Config.Zone.IND, 12, 21, 6, 3)
	# E) Kleinsiedlung 3x2 am Wasser mit Parks vs. große Siedlung 12x3
	road.call(2, 40, 30, 40)
	zone_rect.call(Config.Zone.RES, 4, 41, 3, 2)
	for p: Vector2i in [Vector2i(3, 41), Vector2i(7, 41), Vector2i(5, 43)]:
		m.feature[m.idx(p.x, p.y)] = Config.Feature.PARK
	m.height[m.idx(5, 44)] = 1     # Teich
	zone_rect.call(Config.Zone.RES, 12, 41, 12, 3)
	m.notify_changed(Rect2i(0, 0, m.size, m.size))
	s.refresh()
	var levels := func(x0: int, x1: int, z: int) -> String:
		var out := ""
		for x in range(x0, x1 + 1):
			out += str(s._max_level(m.idx(x, z)))
		return out
	print("zonetest Gewerbe 3x3 rundum Straße, max Stufen je Reihe: %s / %s / %s" % [levels.call(3, 5, 3), levels.call(3, 5, 4), levels.call(3, 5, 5)])
	print("zonetest Gewerbe 10x2 mit Querstraßen an den Enden: %s / %s" % [levels.call(11, 20, 11), levels.call(11, 20, 12)])
	print("zonetest Gewerbe 16x1 ohne Querstraße:            %s" % levels.call(23, 38, 11))
	print("zonetest Industrie 3x3: %s / %s / %s   3x6: %s / %s / %s" % [levels.call(3, 5, 21), levels.call(3, 5, 22), levels.call(3, 5, 23),
		levels.call(12, 17, 21), levels.call(12, 17, 22), levels.call(12, 17, 23)])
	for i: int in [m.idx(5, 41), m.idx(17, 42)]:
		print("zonetest Wohnen %d,%d: Wohn-Nachbarn %d, Bodenwert %d%% -> Villenlage %s" % [i % m.size, i / m.size,
			int(s.res_cluster[i]), roundi(s.land_value[i] * 100), s.villa_site(i)])
	s.free()


## Kleine Villensiedlung in die Demo-Stadt setzen (Screenshot): Straße, Parks, Teich, 4 Villen.
static func place_villas(game: Node) -> void:
	var map: CityMap = game.map
	var x0 := 18
	var z0 := 22
	for x in range(x0, x0 + 6):
		var i := map.idx(x, z0)
		map.road[i] = 1
		map.zone[i] = Config.Zone.NONE
		map.feature[i] = Config.Feature.NONE
	for x in range(x0, x0 + 6):
		for z in range(z0 + 1, z0 + 3):
			var i := map.idx(x, z)
			map.height[i] = map.height[map.idx(x0, z0)]
			map.feature[i] = Config.Feature.NONE
			if x % 2 == 0 and z == z0 + 1:
				map.zone[i] = Config.Zone.RES
				map.level[i] = 3
				map.villa[i] = 1
			else:
				map.feature[i] = Config.Feature.PARK
	map.notify_changed(Rect2i(x0 - 1, z0 - 1, 8, 5))
	game.sim.refresh()
	game.hud.focus_requested.emit(Vector2i(x0 + 3, z0 + 1))


## Steuern je Zone (Einnahmen/Nachfrage) und ÖPNV-Tarif (Fahrgäste, Einnahmen, Zufriedenheit).
static func taxtest(game: Node) -> void:
	var sim: Simulation = game.sim
	var map: CityMap = game.map
	SaveManager.save("taxtest", map, sim)
	var show := func(label: String) -> void:
		sim.refresh()
		sim._budget()
		print("taxtest %-26s Ausgaben $%d (Zukauf $%d)" % [label, roundi(sim.last_expense), roundi(sim.import_cost)])
		print("taxtest %-26s Einnahmen %s = $%d  Nachfrage W/G/I %.2f/%.2f/%.2f  Zufriedenheit %d%%" % [label,
			sim.income_parts.keys().map(func(k: String) -> String: return "%s %d" % [k, roundi(float(sim.income_parts[k]))]),
			roundi(sim.last_income), sim.demand_res, sim.demand_com, sim.demand_ind, roundi(sim.city_happiness * 100)])
	show.call("neutral (9/9/12)")
	sim.tax[Config.Zone.IND] = 0.16
	show.call("Industrie 16%")
	sim.tax[Config.Zone.IND] = 0.12
	sim.tax[Config.Zone.RES] = 0.13
	show.call("Wohnen 13%")
	sim.tax[Config.Zone.RES] = 0.09
	for f in 3:
		sim.fare = f
		sim.refresh()
		sim._budget()
		print("taxtest ÖPNV %-10s Fahrgäste %d (Bus %d, Bahn %d), ÖPNV-Anteil %d%%, Einnahme $%d, Zufriedenheit %d%% (Tarif-Anteil %+d)" % [
			Config.FARE_NAMES[f], int(sim.bus_riders + sim.rail_riders), int(sim.bus_riders), int(sim.rail_riders),
			roundi(sim.transit_share * 100), roundi(float(sim.income_parts["ÖPNV"])), roundi(sim.city_happiness * 100),
			roundi(float(sim.happy_parts.get("ÖPNV-Tarif", 0.0)) * 100)])
	SaveManager.load_slot("taxtest", map, sim)
	DirAccess.remove_absolute(SaveManager.path("taxtest"))


## Große Stadt fürs Profilieren: Straßenraster über die ganze Landfläche, Zonen mit fertigen Gebäuden,
## Kraftwerke, Dienste. Direkt in die Karte geschrieben (schnell), danach ein paar Monate Simulation.
static func bigcity(game: Node) -> void:
	var map: CityMap = game.map
	var sim: Simulation = game.sim
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for z in range(2, map.size - 2):
		for x in range(2, map.size - 2):
			var i := map.idx(x, z)
			if map.is_water(x, z) or map.special[i] != Config.Special.NONE:
				continue
			map.feature[i] = Config.Feature.NONE
			if (x - 2) % 7 == 0 or (z - 2) % 7 == 0:
				map.road[i] = 1
				map.zone[i] = Config.Zone.NONE
				map.level[i] = 0
				continue
			if map.road[i] != 0 or map.rail[i] != 0:
				continue
			var zn := Config.Zone.RES
			if x > 44:
				zn = Config.Zone.IND
			elif (x - 2) % 7 == 1 and z % 2 == 0:
				zn = Config.Zone.COM
			map.zone[i] = zn
			map.level[i] = rng.randi_range(1, 3)
	# Terrain glätten, damit Straßen verbunden sind (max. 1 Block Unterschied)
	for i in map.size * map.size:
		if map.road[i] != 0:
			map.height[i] = maxi(map.height[i], Config.WATER_LEVEL)
	map.notify_changed(Rect2i(0, 0, map.size, map.size))
	sim.money = 500000
	sim.population = 50000     # Freischaltungen
	for t: ToolController.Tool in [ToolController.Tool.COAL, ToolController.Tool.COAL, ToolController.Tool.COAL,
			ToolController.Tool.POLICE, ToolController.Tool.FIRE, ToolController.Tool.SCHOOL, ToolController.Tool.HOSPITAL]:
		_place_near_center(map, game.tools, t)
	game.tools.set_tool(ToolController.Tool.INSPECT)
	sim.refresh()
	print("bigcity Einwohner %d, Jobs %d, Straßen %d, Strom %d/%d MW" % [sim.population, sim.jobs_com + sim.jobs_ind,
		sim.road_count, sim.power_demand, sim.power_supply])


## Bau-Klick-Zeit: Straße und Zone setzen, Zeit für _apply messen (inkl. Neuberechnung).
static func buildtest(game: Node) -> void:
	var map: CityMap = game.map
	var tools: ToolController = game.tools
	var times := []
	for k in 6:
		# freies Land-Tile ohne Straße suchen
		var t := Vector2i(-1, -1)
		for i in range(map.size * map.size - 1, -1, -1):
			if map.road[i] == 0 and map.zone[i] == Config.Zone.NONE and map.special[i] == Config.Special.NONE \
					and not map.is_water(i % map.size, i / map.size) and map.rail[i] == 0 and i % 5 == k:
				t = Vector2i(i % map.size, i / map.size)
				break
		tools.set_tool(ToolController.Tool.ROAD if k % 2 == 0 else ToolController.Tool.RES)
		var start := Time.get_ticks_usec()
		tools._apply([t] as Array[Vector2i])
		times.append(snappedf((Time.get_ticks_usec() - start) / 1000.0, 0.1))
	tools.set_tool(ToolController.Tool.INSPECT)
	print("buildtest synchron  Bau-Klick (ms): %s, Einwohner %d" % [times, game.sim.population])
	# Diagnose: Kopie synchron vs. im Thread
	var sim: Simulation = game.sim
	sim.async_commute = true
	sim._request_commute()
	WorkerThreadPool.wait_for_task_completion(sim._commute_task)
	sim._commute_task = -1
	var t1 := Time.get_ticks_usec()
	sim._worker._compute_commute()
	print("buildtest Kopie synchron: %.0f ms" % ((Time.get_ticks_usec() - t1) / 1000.0))
	var t2 := Time.get_ticks_usec()
	var tid := WorkerThreadPool.add_task(sim._worker._compute_commute, true)
	WorkerThreadPool.wait_for_task_completion(tid)
	print("buildtest Kopie im Thread (Hauptthread wartet): %.0f ms" % ((Time.get_ticks_usec() - t2) / 1000.0))
	var th := Thread.new()
	var t3 := Time.get_ticks_usec()
	th.start(sim._worker._compute_commute)
	th.wait_to_finish()
	print("buildtest Kopie in eigenem Thread: %.0f ms" % ((Time.get_ticks_usec() - t3) / 1000.0))
	sim.async_commute = false
	# Wie im Spiel: Pendler im Hintergrund-Thread
	sim.async_commute = true
	var async_times := []
	var frame_max := 0.0
	var wait_frames := 0
	for k in 3:
		var t := Vector2i(10 + k * 2, map.size - 4)
		tools.set_tool(ToolController.Tool.ROAD)
		var start := Time.get_ticks_usec()
		tools._apply([t] as Array[Vector2i])
		async_times.append(snappedf((Time.get_ticks_usec() - start) / 1000.0, 0.1))
		var t_wait := Time.get_ticks_usec()
		while sim._commute_task != -1:
			var f0 := Time.get_ticks_usec()
			await game.get_tree().process_frame
			frame_max = maxf(frame_max, (Time.get_ticks_usec() - f0) / 1000.0)
			wait_frames += 1
		if k == 0:
			print("buildtest Hintergrund: Ergebnis nach %.0f ms" % ((Time.get_ticks_usec() - t_wait) / 1000.0))
	# Aufteilung eines Klicks: Kartenänderungs-Signale vs. Neuberechnung
	var t5 := Time.get_ticks_usec()
	map.notify_changed(Rect2i(5, map.size - 4, 1, 1))
	var t6 := Time.get_ticks_usec()
	sim.refresh(true)
	var t7 := Time.get_ticks_usec()
	var hparts := []
	map._wide_dirty = true
	for pair: Array in [["wide", func(): map._compute_wide()],
			["renderer", func(): game.renderer._on_infra_changed()],
			["verkehr", func(): game.get_node("Traffic")._on_map_changed(Rect2i())],
			["feuerwehr", func(): game.fire_dept._collect_stations()],
			["feuer_sync", func(): game.fire_dept._sync(Rect2i(5, map.size - 4, 1, 1))],
			["marker", func(): game.get_node("StatusMarkers")._rebuild()],
			["overlay", func(): game.get_node("MapOverlay")._rebuild()]]:
		var tp := Time.get_ticks_usec()
		(pair[1] as Callable).call()
		hparts.append("%s %.1f" % [pair[0], (Time.get_ticks_usec() - tp) / 1000.0])
	print("buildtest Signal-Empfänger (ms): %s" % ", ".join(hparts))
	print("buildtest Klick-Anteile: Signale (Renderer/Verkehr/Feuerwehr) %.1f ms, Neuberechnung sofort %.1f ms" % [
		(t6 - t5) / 1000.0, (t7 - t6) / 1000.0])
	tools.set_tool(ToolController.Tool.INSPECT)
	sim.async_commute = false
	print("buildtest Hintergrund Bau-Klick (ms): %s, längster Frame beim Warten %.1f ms (%d Frames)" % [
		async_times, frame_max, wait_frames])
	Perf.enabled = true
	Perf.total = {}
	var t0 := Perf.begin()
	game.sim.refresh()
	Perf.end("refresh", t0)
	Perf.enabled = false
	var parts := []
	for key in Perf.total:
		parts.append("%s %.1f" % [key, Perf.total[key][0] / 1000.0])
	print("buildtest refresh-Teile (ms): %s" % ", ".join(parts))


## Sichtbarer Verkehr folgt der Simulation: Autos = Auto-Pendler, kaum Autos auf Straßen ohne Pendler.
static func cartest(game: Node) -> void:
	var sim: Simulation = game.sim
	var map: CityMap = game.map
	var traffic: Traffic = game.get_node("Traffic")
	for f: int in [1, 0]:
		sim.fare = f
		sim.refresh()
		traffic._rebuild_weights()
		var empty := 0.0
		var total := 0.0
		var empty_old := 0.0
		var total_old := 0.0
		for k in traffic._road_tiles.size():
			var tr := traffic._traffic_at(traffic._road_tiles[k])
			total += 0.02 + tr
			total_old += 1.0 + tr
			if tr < 1.0:
				empty += 0.02 + tr
				empty_old += 1.0 + tr
		var buses := 0
		for g in traffic._stop_groups.size():
			buses += traffic.target_buses(g)
		print("cartest ÖPNV %-10s Einw. %d, Auto-Pendler %d (ÖPNV %d%%) -> Autos %d (früher nach Einwohnern: %d), Busse %d, Anteil Autos auf Straßen ohne Pendler %d%% (früher %d%%)" % [
			Config.FARE_NAMES[f], sim.population, int(sim.car_trips), roundi(sim.transit_share * 100), traffic.target_count(),
			sim.population / 20, buses, roundi(empty / maxf(total, 0.001) * 100), roundi(empty_old / maxf(total_old, 0.001) * 100)])
	sim.fare = 1
	sim.refresh()
	var served := 0
	for i in map.size * map.size:
		served += sim.bus_served[i]
	print("cartest Diagnose: Straßen im Busnetz %d von %d, Busfahrer %d, Bahnfahrer %d, ÖPNV-Wege %d, zugeordnet %d, Haltestellen %d, Bahnhöfe %d, Bahnhof-Links %d" % [
		served, sim.road_count, int(sim.bus_riders), int(sim.rail_riders), int(sim._transit_trips),
		int(sim.car_trips + sim._transit_trips), sim.bus_stop_count, sim.station_count, sim._road_station_links.size()])
	for st: int in sim.station_use:
		print("cartest Bahnhof %d,%d: %d Ein-/Aussteiger (%d%% der Kapazität)" % [st % map.size, st / map.size,
			int(sim.station_use[st]), roundi(float(sim.station_use[st]) / Config.STATION_CAPACITY * 100)])


## Straßen mit der höchsten Auslastung (Ort, Höhe, Pendler, Busnetz) – Stau-Analyse eines Spielstands.
static func jamreport(game: Node) -> void:
	var map: CityMap = game.map
	var sim: Simulation = game.sim
	sim.refresh()
	var roads := []
	for i in map.size * map.size:
		if map.road[i] != 0:
			roads.append(i)
	var hi := Rect2i()
	var first := true
	for i: int in roads:
		if map.height[i] >= 8:
			var r := Rect2i(i % map.size, i / map.size, 1, 1)
			hi = r if first else hi.merge(r)
			first = false
	print("jamreport Bergstraßen (Höhe >= 8): Bereich %s" % hi)
	roads.sort_custom(func(a: int, b: int) -> bool: return sim.congestion[a] > sim.congestion[b])
	for k in mini(20, roads.size()):
		var i: int = roads[k]
		print("jamreport %2d,%2d  Höhe %2d  Auslastung %3d%%  Pendler %4d  Busnetz %d  Weg zur Kreuzung %d" % [
			i % map.size, i / map.size, map.height[i], roundi(sim.congestion[i] * 100), int(sim.traffic[i]),
			sim.bus_served[i], sim.junction_dist[i]])


## Nach Spielzeit: Stimmt die Verteilung der sichtbaren Autos mit dem simulierten Verkehr überein?
## Vergleich: Anteil Autos auf den 10 % meistbefahrenen Straßen vs. deren Anteil am Verkehr.
static func cardrift(game: Node, seconds: float) -> void:
	var sim: Simulation = game.sim
	var traffic: Traffic = game.get_node("Traffic")
	game.hud._set_speed(3)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < seconds * 1000.0:
		await game.get_tree().process_frame
	var roads: Array = traffic._road_tiles.duplicate()
	roads.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return traffic._traffic_at(a) > traffic._traffic_at(b))
	var top := {}
	var top_traffic := 0.0
	var all_traffic := 0.0
	for k in roads.size():
		all_traffic += traffic._traffic_at(roads[k])
		if k < roads.size() / 10:
			top[roads[k]] = true
			top_traffic += traffic._traffic_at(roads[k])
	var on_top := 0
	for c in traffic._cars:
		if top.has(c.from):
			on_top += 1
	print("cardrift nach %ds: Autos %d, auf den Top-10%%-Straßen %d%% der Autos (Verkehrsanteil dort %d%%)" % [
		seconds, traffic._cars.size(), roundi(100.0 * on_top / maxf(traffic._cars.size(), 1)), roundi(100.0 * top_traffic / maxf(all_traffic, 1))])


## Verfall: Villa verliert ihre Lage (Parks weg) -> abgenutzt, später Einfamilienhaus; Wohnblock unter 55 % Bodenwert.
static func decaytest() -> void:
	var m := CityMap.new()
	m.height.fill(6)
	var s := Simulation.new()
	s.map = m
	for x in range(2, 30):
		m.road[m.idx(x, 10)] = 1
	var villa := m.idx(5, 11)
	m.zone[villa] = Config.Zone.RES
	m.level[villa] = 3
	m.villa[villa] = 1
	var parks: Array[int] = [m.idx(4, 11), m.idx(6, 11), m.idx(5, 12), m.idx(4, 12), m.idx(6, 12)]
	for p in parks:
		m.feature[p] = Config.Feature.PARK
	m.height[m.idx(5, 13)] = 1
	var block := m.idx(20, 11)
	m.zone[block] = Config.Zone.RES
	m.level[block] = 3
	for x in range(26, 30):       # Arbeitsplätze, damit Wohnen "erreichbar" ist
		for z in range(11, 14):
			m.zone[m.idx(x, z)] = Config.Zone.IND
			m.level[m.idx(x, z)] = 2
	m.notify_changed(Rect2i(0, 0, m.size, m.size))
	s.refresh()
	s.powered.fill(1)
	s._grow()
	print("decaytest Villa mit Parks: Bodenwert %d%%, verfällt '%s', worn %d" % [roundi(s.land_value[villa] * 100),
		s.decay_reason(villa), m.worn[villa]])
	print("decaytest Wohnblock Bodenwert %d%%: verfällt '%s', worn %d" % [roundi(s.land_value[block] * 100),
		s.decay_reason(block), m.worn[block]])
	for p in parks:
		m.feature[p] = Config.Feature.NONE
	m.notify_changed(Rect2i(0, 0, m.size, m.size))
	s.refresh()
	s.powered.fill(1)
	var months := 0
	while m.level[villa] == 3 and m.villa[villa] == 1 and months < 200:
		s._grow()
		months += 1
	print("decaytest Villa ohne Parks: Bodenwert %d%%, Grund '%s' -> nach %d Monaten Stufe %d, Villa %d" % [
		roundi(s.land_value[villa] * 100), s.decay_reason(villa) if m.level[villa] == 3 else "abgestiegen", months, m.level[villa], m.villa[villa]])
	print("decaytest Wohnblock danach: Stufe %d (abgestiegen = Verfall hat gewirkt)" % m.level[block])
	s.free()


## Energie: Solar allein -> nachts zu knapp; mit Batterie gedeckt; Biomasse verbrennt Holz (sonst Zukauf).
static func energytest() -> void:
	var m := CityMap.new()
	m.height.fill(6)
	var s := Simulation.new()
	s.map = m
	var put_special := func(x: int, z: int, sp: int) -> void:
		var sz: int = Config.SPECIALS[sp]["size"]
		var a := m.idx(x, z)
		for dz in sz:
			for dx in sz:
				m.special[m.idx(x + dx, z + dz)] = sp
				m.anchor[m.idx(x + dx, z + dz)] = a
		m.slevel[a] = 1
	for x in range(0, 40):
		m.power_line[m.idx(x, 10)] = 1
	for x in range(10, 22):              # Wohngebiet am Netz: 12 Häuser Stufe 2
		m.zone[m.idx(x, 11)] = Config.Zone.RES
		m.level[m.idx(x, 11)] = 2
	put_special.call(0, 8, Config.Special.SOLAR)
	var report := func(label: String) -> void:
		s._compute_power()
		var net: Dictionary = s.power_nets[s.power_net[m.idx(5, 10)]]
		print("energytest %-26s Bedarf %d MW, Tag %d / Nacht %d (Speicher %d) -> versorgt bis %d MW, ohne Strom %d%s" % [
			label, int(net["demand"]), int(net["day"]), int(net["night"]), int(net["store_used"]), int(net["capacity"]),
			int(net["unserved"]), "  (nachts zu knapp)" if bool(net["night_limited"]) and int(net["unserved"]) > 0 else ""])
	report.call("nur Solarfeld:")
	put_special.call(3, 8, Config.Special.SOLAR)
	report.call("2 Solarfelder:")
	put_special.call(6, 9, Config.Special.BATTERY)
	report.call("+ 1 Batterie:")
	put_special.call(8, 8, Config.Special.BIOMASS)
	report.call("+ Biomasse:")
	s.stock["wood"] = 5.0
	var m0 := s.money
	s._process_goods()
	s._budget()
	print("energytest Biomasse mit 5 Holz im Lager: Holz danach %d, Zukauf %s, Hinweis '%s'" % [int(s.stock["wood"]),
		s.imported.get("wood", 0.0), s.producer_info.get(m.idx(8, 8), {}).get("issue", "")])
	# Teil B: Salzspeicher statt Batterie-Grenze
	put_special.call(12, 8, Config.Special.SALT)
	report.call("+ Salzspeicher:")
	s.free()


## Aufbau-Start: Rathaus, Sperren, kein Handel vor Stufe 2, Holz für Häuser, Ausbau auf Stufe 2.
static func buildstarttest(game: Node) -> void:
	var map: CityMap = game.map
	var sim: Simulation = game.sim
	var tools: ToolController = game.tools
	game._new_city()
	var hall := -1
	for a in map.size * map.size:
		if map.anchor[a] == a and map.special[a] == Config.Special.CITYHALL:
			hall = a
	var hx := hall % map.size
	var hz := hall / map.size
	print("buildstart Rathaus bei %d,%d, Kasse $%d, Lager Holz %d Stein %d, Lagerkapazität %d" % [hx, hz, int(sim.money),
		int(sim.stock["wood"]), int(sim.stock["stone"]), sim.stock_capacity()])
	print("buildstart Sperren: Gewerbe '%s' | Schule '%s' | Wohnen '%s' | Holzfäller '%s'" % [
		tools.locked_reason(ToolController.Tool.COM), tools.locked_reason(ToolController.Tool.SCHOOL),
		tools.locked_reason(ToolController.Tool.RES), tools.locked_reason(ToolController.Tool.LUMBER)])
	var msgs: Array[String] = []
	tools.message.connect(func(t: String) -> void: msgs.append(t))
	# Straße + Wohnzone entlang des Straßenstücks, Holzfäller am nächsten Wald, Steinbruch am Fels
	var road: Array[Vector2i] = []
	var dir := 1 if map.road[map.idx(hx + 3, hz + 1)] == 1 else -1
	var sx := hx + 3 if dir > 0 else hx - 1
	for k in range(0, 14):
		road.append(Vector2i(sx + k * dir, hz + 1))
	tools.set_tool(ToolController.Tool.ROAD)
	tools._apply(road)
	var zone: Array[Vector2i] = []
	for k in range(1, 13):
		zone.append(Vector2i(sx + k * dir, hz))
		zone.append(Vector2i(sx + k * dir, hz + 2))
	tools.set_tool(ToolController.Tool.RES)
	tools._apply(zone)
	tools.set_tool(ToolController.Tool.INSPECT)
	var hp := HumanPlayer.new()
	hp.game = game
	hp.map = map
	hp.sim = sim
	hp.tools = tools
	hp.c = map.size / 2
	var lum := hp._place_at(ToolController.Tool.LUMBER, hp._near_feature(Config.Feature.TREE))
	var qua := hp._place_at(ToolController.Tool.QUARRY, hp._near_ore(Config.Ore.STONE))
	# Abbau an Straße + Strom anschließen (L-Weg zum Straßenstück vor dem Rathaus, Leitung auf der Straße)
	for site: Vector2i in [lum, qua]:
		if site.x < 0:
			continue
		var path: Array[Vector2i] = []
		var sz: int = Config.SPECIALS[map.special[map.idx(site.x, site.y)]]["size"]
		var goal := Vector2i(sx, hz + 1)
		var z := site.y + sz if goal.y > site.y else site.y - 1       # neben dem Gebäude starten, nicht hindurch
		var x := site.x
		while z != goal.y:
			path.append(Vector2i(x, z))
			z += signi(goal.y - z)
		while x != goal.x:
			path.append(Vector2i(x, z))
			x += signi(goal.x - x)
		path.append(goal)
		tools.set_tool(ToolController.Tool.ROAD)
		tools._apply(path)
		tools.set_tool(ToolController.Tool.POWERLINE)
		tools._apply(path)
	tools.set_tool(ToolController.Tool.POWERLINE)
	tools._apply([Vector2i(sx, hz + 1), Vector2i(sx, hz), Vector2i(sx, hz + 2)] as Array[Vector2i])
	tools.set_tool(ToolController.Tool.INSPECT)
	print("buildstart Holzfäller bei %s, Steinbruch bei %s, Kasse $%d, Holz %d, Meldungen %s" % [lum, qua, int(sim.money),
		int(sim.stock["wood"]), msgs])
	print("buildstart Baustellen direkt nach dem Bau: Holzfäller %d, Steinbruch %d halbe Monate, Lager-Kreis am Holzfäller %d" % [
		map.construct[map.idx(lum.x, lum.y)] if lum.x >= 0 else -1, map.construct[map.idx(qua.x, qua.y)] if qua.x >= 0 else -1,
		sim.store_cover[map.idx(lum.x, lum.y)] if lum.x >= 0 and sim.store_cover.size() > 0 else -1])
	# Grube weit draußen (außerhalb des Rathaus-Kreises) -> doppelte Bauzeit
	var far := hp._place_at(ToolController.Tool.PIT, Vector2i(hx + 30, hz + 30))
	var months := int(DevTools.value("--bsmonths")) if DevTools.value("--bsmonths") != "" else 36
	for m in months:
		if m < 4 and far.x >= 0:
			print("buildstart Monat %d: Grube weit draußen (Kreis %d) Rest %d, Holzfäller Rest %d" % [m, sim.store_cover[map.idx(far.x, far.y)],
				map.construct[map.idx(far.x, far.y)], map.construct[map.idx(lum.x, lum.y)] if lum.x >= 0 else -1])
		sim.tick_month()
		if m % 6 == 5:
			var nx := sim.hall_next()
			var sites := 0
			for i in map.size * map.size:
				if map.construct[i] > 0:
					sites += 1
			print("buildstart Monat %d: Einw. %d, Baustellen %d, Holz %d, Stein %d, Steuern $%d, Kasse $%d, Stufe 2 fehlt: %s" % [m + 1,
				sim.population, sites, int(sim.stock["wood"]), int(sim.stock["stone"]), roundi(float(sim.income_parts.get("Wohnen", 0.0))),
				int(sim.money), nx.get("missing", [])])
			if bool(nx.get("ok", false)):
				print("buildstart Ausbau: '%s' -> Stufe %d, Gewerbe jetzt '%s'" % [sim.upgrade_hall(), sim.hall_level,
					tools.locked_reason(ToolController.Tool.COM)])
	var why := {}
	for i in map.size * map.size:
		if map.zone[i] != Config.Zone.NONE:
			for b: String in sim.growth_blockers(i):
				why[b.substr(0, 40)] = int(why.get(b.substr(0, 40), 0)) + 1
	print("buildstart Blocker Wohnen: %s, Nachfrage W %.2f" % [why, sim.demand_res])
	for a: int in sim.producer_info:
		print("buildstart %s: %s" % [Config.SPECIALS[map.special[a]]["name"], sim.producer_info[a]])
	var d := sim.to_dict()
	print("buildstart Speichern: Modus %s, Stufe %d" % [d["game_mode"], d["hall_level"]])
	game.hud._toggle_popup("hall")
	await game.get_tree().process_frame


## Forschung Schritt 3 (mit --loadfile=<große Stadt mit Uni>): Stadt-Projekte erforscht setzen, Hightech-Zone an der
## Uni ausweisen, 12 Monate -> Hochhäuser, Bürotürme, Hightech, Stau, Einnahmen.
static func citytechtest(game: Node) -> void:
	var map: CityMap = game.map
	var sim: Simulation = game.sim
	var tools: ToolController = game.tools
	var count := func() -> Dictionary:
		var c := {"res4": 0, "com4": 0, "ht": 0, "ht_built": 0}
		for i in map.size * map.size:
			if map.level[i] == 4 and map.zone[i] == Config.Zone.RES: c["res4"] += 1
			if map.level[i] == 4 and map.zone[i] == Config.Zone.COM: c["com4"] += 1
			if map.hightech[i] == 1:
				c["ht"] += 1
				if map.level[i] > 0: c["ht_built"] += 1
		return c
	sim.tick_month()
	var c0: Dictionary = count.call()
	var pop0 := sim.population
	var jam0 := sim.avg_congestion
	sim.money += 200000
	print("citytechtest vorher: Einw. %d, Stau Ø %d%%, Hightech-Werkzeug gesperrt: '%s'" % [pop0, roundi(jam0 * 100.0),
		tools.locked_reason(ToolController.Tool.HIGHTECH)])
	for id: String in ["concrete", "highrise", "offices", "hightech", "traffic"]:
		if not sim.research_done.has(id):
			sim.research_done.append(id)
	# Hightech: freie Fläche an einer Straße nahe der ersten Universität (6x2)
	var uni := -1
	for a in map.size * map.size:
		if map.anchor[a] == a and map.special[a] == Config.Special.UNIVERSITY:
			uni = a
			break
	var placed := 0
	if uni >= 0:
		tools.set_tool(ToolController.Tool.HIGHTECH)
		var ux := uni % map.size
		var uz := uni / map.size
		for r in range(3, 14):
			for z in range(uz - r, uz + r + 1):
				for x in range(ux - r, ux + r + 1):
					if placed >= 12 or not map.in_bounds(x, z):
						continue
					var i := map.idx(x, z)
					if map.zone[i] == Config.Zone.NONE and map.road[i] == 0 and map.special[i] == Config.Special.NONE \
							and not map.is_water(x, z) and sim.road_dist.size() > i and sim.road_dist[i] <= 2 and map.rail[i] == 0:
						tools._apply([Vector2i(x, z)] as Array[Vector2i])
						placed += 1
		tools.set_tool(ToolController.Tool.INSPECT)
	print("citytechtest Hightech-Zone ausgewiesen: %d Tiles (Uni %s)" % [placed, uni >= 0])
	for m in 12:
		sim.tick_month()
	var c1: Dictionary = count.call()
	print("citytechtest nach 12 Monaten: Einw. %d -> %d, Hochhäuser %d -> %d, Bürotürme %d -> %d, Hightech %d/%d bebaut, Stau Ø %d%% -> %d%%" % [
		pop0, sim.population, c0["res4"], c1["res4"], c0["com4"], c1["com4"], c1["ht_built"], c1["ht"],
		roundi(jam0 * 100.0), roundi(sim.avg_congestion * 100.0)])
	print("citytechtest Einnahmen: %s, Beton im Lager %d, zugekauft letzter Monat %s" % [sim.income_parts,
		int(sim.stock.get("concrete", 0.0)), sim.imported.get("concrete", 0.0)])


## Teil B im laufenden Spiel: Standortregeln (Wasser/Hang) über das Werkzeug, Umrüsten Kohle -> Salzspeicher.
static func energytest_b(game: Node) -> void:
	var map: CityMap = game.map
	var sim: Simulation = game.sim
	var tools: ToolController = game.tools
	sim.money += 100000
	for id: String in ["solar", "battery", "hydro", "pumped", "salt"]:
		if not sim.research_done.has(id):
			sim.research_done.append(id)
	# Wasserkraft: erst mitten im Land (falsch), dann an der Küste
	var land := Vector2i(-1, -1)
	var shore := Vector2i(-1, -1)
	var hill := Vector2i(-1, -1)
	for z in range(4, map.size - 4):
		for x in range(4, map.size - 4):
			if land.x < 0 and tools.site_reason(Config.Special.HYDRO, Vector2i(x, z)) != "" and not map.is_water(x, z):
				land = Vector2i(x, z)
			if shore.x < 0 and not map.is_water(x, z) and not map.is_water(x + 1, z) and not map.is_water(x, z + 1) \
					and not map.is_water(x + 1, z + 1) and tools.site_reason(Config.Special.HYDRO, Vector2i(x, z)) == "" \
					and map.special[map.idx(x, z)] == Config.Special.NONE and map.zone[map.idx(x, z)] == Config.Zone.NONE:
				shore = Vector2i(x, z)
			if hill.x < 0 and tools.site_reason(Config.Special.PUMPED, Vector2i(x, z)) == "" \
					and map.zone[map.idx(x, z)] == Config.Zone.NONE and map.special[map.idx(x, z)] == Config.Special.NONE:
				hill = Vector2i(x, z)
	print("energytest_b Wasserkraft im Land: '%s'" % tools.site_reason(Config.Special.HYDRO, land))
	var msgs: Array[String] = []
	tools.message.connect(func(t: String) -> void: msgs.append(t))
	for pair: Array in [[ToolController.Tool.HYDRO, shore], [ToolController.Tool.PUMPED, hill]]:
		var p: Vector2i = pair[1]
		tools.set_tool(pair[0])
		tools.hover = p
		tools._apply(tools._affected_tiles())
		var i := map.idx(p.x, p.y) if p.x >= 0 else 0
		print("energytest_b %s bei %s: gebaut %s" % [ToolController.TOOLS[pair[0]]["name"], p,
			p.x >= 0 and map.special[i] != Config.Special.NONE])
	# Umrüsten: erstes Kohlekraftwerk
	var coal := -1
	for a in map.size * map.size:
		if map.anchor[a] == a and map.special[a] == Config.Special.COAL:
			coal = a
			break
	if coal >= 0:
		var m0 := sim.money
		tools.set_tool(ToolController.Tool.SALT)
		tools.hover = Vector2i(coal % map.size, coal / map.size)
		tools._update_preview()
		print("energytest_b Vorschau über Kohlekraftwerk: Umrüsten %s, Kostenblase '%s'" % [tools.preview_convert,
			game.hud._cost.text.replace("\n", " | ")])
		tools._apply(tools._affected_tiles())
		print("energytest_b Umgerüstet: %s, Kosten $%d" % [Config.SPECIALS[map.special[coal]]["name"], int(m0 - sim.money)])
	tools.set_tool(ToolController.Tool.INSPECT)
	print("energytest_b Meldungen: %s" % [msgs])


## Belegung/Leerstand: Haus ohne Strom leert sich schrittweise, steht leer, drückt die Nachbarn; mit Strom wieder
## bezogen; dauerhaft leer -> nach VACANT_MONTHS abgerissen.
static func vacancytest() -> void:
	var m := CityMap.new()
	m.height.fill(6)
	var s := Simulation.new()
	s.map = m
	s._rng.seed = 3
	for x in range(2, 30):
		m.road[m.idx(x, 10)] = 1
	for x in range(6, 15):              # 9 Häuser à 30 = 270 Einw. (unter der Dienst-Schwelle 300)
		m.zone[m.idx(x, 11)] = Config.Zone.RES
		m.level[m.idx(x, 11)] = 2
	for x in range(26, 30):
		for z in range(11, 14):
			m.zone[m.idx(x, z)] = Config.Zone.IND
			m.level[m.idx(x, z)] = 2
	var t := m.idx(10, 11)
	var nb := m.idx(12, 11)
	m.notify_changed(Rect2i(0, 0, m.size, m.size))
	var month := func(cut: bool) -> void:
		s.refresh()
		s.powered.fill(1)
		if cut:
			s.powered[t] = 0
		s._grow()
		s._recount()
	month.call(false)
	var pop0 := s.population
	var h0 := s.happiness[nb]
	var trace := PackedStringArray()
	for k in 10:
		month.call(true)
		trace.append("%d%%/%d" % [m.occupancy(t), s.population])
	s.refresh()
	print("vacancytest Haus ohne Strom, Belegung/Stadt-Einw. je Monat: %s (vorher %d Einw.)" % [", ".join(trace), pop0])
	var others := PackedStringArray()
	s.powered.fill(1)
	for x in range(6, 15):
		var j := m.idx(x, 11)
		if j != t:
			others.append("%d%%:%s" % [m.occupancy(j), s.decay_reason(j).substr(0, 18)])
	print("vacancytest übrige Häuser: %s  (Nachfrage W %.2f)" % [", ".join(others), s.demand_res])
	print("vacancytest Leerstand %s, Zufriedenheit Nachbar %d%% -> %d%%, Anteil 'Leerstand' %d" % [m.is_vacant(t),
		roundi(h0 * 100.0), roundi(s.happiness[nb] * 100.0), roundi(float(s.happy_parts.get("Leerstand", 0.0)) * 100.0)])
	trace.clear()
	for k in 4:
		month.call(false)
		trace.append("%d%%" % m.occupancy(t))
	print("vacancytest Strom wieder da: Belegung %s, leer %s" % [", ".join(trace), m.is_vacant(t)])
	var months := 0
	while m.level[t] > 0 and months < 60:
		month.call(true)
		months += 1
	print("vacancytest dauerhaft ohne Strom: nach %d Monaten Stufe %d (Abriss nach %d Monaten Leerstand), Zone %d" % [months,
		m.level[t], Config.VACANT_MONTHS, m.zone[t]])
	s.free()


## Einige Gebäude der Demo-Stadt als verfallend markieren (Screenshot).
static func mark_worn(game: Node) -> void:
	var map: CityMap = game.map
	var k := 0
	for i in map.size * map.size:
		if map.level[i] > 0 and map.zone[i] != Config.Zone.NONE:
			k += 1
			if k % 2 == 0:
				map.worn[i] = 1
	map.notify_changed(Rect2i(0, 0, map.size, map.size), false)


## Dienst-/Kulturbauten: Front zeigt zur Seite mit Straße (Drehung aus WorldRenderer._front_angle).
static func fronttest(game: Node) -> void:
	var map: CityMap = game.map
	var renderer: WorldRenderer = game.renderer
	var names := {0.0: "Norden", -PI * 0.5: "Osten", PI: "Süden", PI * 0.5: "Westen"}
	for i in map.size * map.size:
		if map.anchor[i] != i or not Config.SPECIALS[map.special[i]].has("service"):
			continue
		var s: int = Config.SPECIALS[map.special[i]]["size"]
		var tx := i % map.size
		var tz := i / map.size
		var ang := renderer._front_angle(tx, tz, s)
		var front := 0
		for k in s:
			match names[ang]:
				"Norden": front += 1 if map.is_road(tx + k, tz - 1) else 0
				"Osten": front += 1 if map.is_road(tx + s, tz + k) else 0
				"Süden": front += 1 if map.is_road(tx + k, tz + s) else 0
				"Westen": front += 1 if map.is_road(tx - 1, tz + k) else 0
		print("fronttest %-12s bei %d,%d: Front nach %-6s, %d Straßen-Tiles vor der Front" % [
			Config.SPECIALS[map.special[i]]["name"], tx, tz, names[ang], front])


## Stromnetze: A versorgt, B ohne Kraftwerk (früher unsichtbar), C mit Engpass (Leitungsende fällt aus).
static func powertest() -> void:
	var m := CityMap.new()
	m.height.fill(6)
	var s := Simulation.new()
	s.map = m
	var msgs: Array[String] = []
	s.alert.connect(func(t: String, _p: Vector2i) -> void: msgs.append(t))
	var res := func(x0: int, z0: int, w: int, lv: int) -> void:
		for x in range(x0, x0 + w):
			m.zone[m.idx(x, z0)] = Config.Zone.RES
			m.level[m.idx(x, z0)] = lv
	var plant := func(x: int, z: int, sp: int) -> void:
		m.special[m.idx(x, z)] = sp
		m.anchor[m.idx(x, z)] = m.idx(x, z)
	# A: Windrad (30 MW) + 10 Häuser Stufe 1 (10 MW)
	plant.call(2, 2, Config.Special.WIND)
	res.call(3, 2, 10, 1)
	# B: 8 Häuser Stufe 2, kein Kraftwerk
	res.call(3, 10, 8, 2)
	# C: Windrad + 12 Häuser Stufe 3 (48 MW > 30 MW)
	plant.call(2, 20, Config.Special.WIND)
	res.call(3, 20, 12, 3)
	s._compute_power()
	for net: Dictionary in s.power_nets:
		var k: int = net["key"]
		print("powertest Netz bei %d,%d: Bedarf %d / Leistung %d MW, %d Kraftwerk, %d Gebäude ohne Strom" % [
			k % m.size, k / m.size, int(net["demand"]), int(net["capacity"]), int(net["plants"]), int(net["unserved"])])
	var lit := ""
	for x in range(3, 15):
		lit += str(s.powered[m.idx(x, 20)])
	print("powertest Netz C versorgt (Kraftwerk links -> Leitungsende rechts): %s" % lit)
	print("powertest gesamt: Bedarf %d, Leistung %d, geliefert %d MW" % [s.power_demand, s.power_supply, s.power_served])
	print("powertest Meldung: %s" % [msgs])
	print("powertest Info-Karte B: %s" % s.power_net_text(m.idx(5, 10)))
	msgs.clear()
	s._compute_power()
	print("powertest zweite Berechnung ohne neues Problem -> Meldungen: %d" % msgs.size())
	# Dienstgebäude: Polizei (Stufe 2) am versorgten Netz A, Schule allein ohne Anschluss
	plant.call(13, 2, Config.Special.POLICE)
	m.slevel[m.idx(13, 2)] = 2
	plant.call(30, 40, Config.Special.SCHOOL)
	s._compute_power()
	print("powertest Polizei St.2 an Netz A: Verbrauch %d MW, Strom %s | Schule ohne Anschluss: Verbrauch %d MW, Strom %s" % [
		s.tile_power_use(m.idx(13, 2)), s.special_powered(m.idx(13, 2)), s.tile_power_use(m.idx(30, 40)),
		s.special_powered(m.idx(30, 40))])
	s.free()


## Auslastung der Dienstgebäude (z.B. Feuerwehr in dichter Stadt) + Brände über 12 Monate.
static func loadreport(game: Node) -> void:
	var map: CityMap = game.map
	var sim: Simulation = game.sim
	sim.refresh()
	var per_cat := {}
	for a: int in sim.service_load:
		var cat: String = Config.SPECIALS[map.special[a]]["service"]
		if not per_cat.has(cat):
			per_cat[cat] = []
		per_cat[cat].append("%d%%(St.%d)" % [roundi(float(sim.service_load[a]) * 100), map.special_level(a)])
	for cat: String in per_cat:
		print("loadreport %-10s Auslastung je Gebäude: %s  Ø-Versorgung Einwohner %d%%" % [cat, " ".join(per_cat[cat]),
			roundi(float(sim.city_coverage.get(cat, 0.0)) * 100)])
	var dept: FireDept = game.fire_dept
	var f0 := sim.fires_total
	var alerts := [0]
	dept.alert.connect(func(_t: String, _p: Vector2i) -> void: alerts[0] += 1)
	for m in 12:
		sim.tick_month()
		dept.advance(Simulation.SECONDS_PER_MONTH[1])
	print("loadreport Brände in 12 Monaten: %d Ausbrüche, %d gelöscht, %d abgebrannt, %d Meldungen" % [sim.fires_total - f0,
		dept.extinguished_total, dept.burned_total, alerts[0]])


## Echte Rechenzeit je Frame (CPU-Skript/Physik + GPU-Renderzeit) und erreichte FPS, ohne VSync-Wartezeit.
static func gpumeasure(game: Node, seconds: float) -> void:
	var vp_rid: RID = game.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	var cpu := 0.0
	var gpu := 0.0
	var frames := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < seconds * 1000.0:
		await game.get_tree().process_frame
		cpu += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
		frames += 1
	print("gpumeasure Tempo %d, Grenze %d" % [game.sim.speed, GraphicsSettings.fps_limit])
	print("gpumeasure %s, max_fps %d: %.0f FPS, CPU (Skripte) Ø %.1f ms, GPU Ø %.1f ms je Frame -> GPU-Last ca. %d%%" % [
		GraphicsSettings.NAMES[GraphicsSettings.current], Engine.max_fps, frames / seconds, cpu / frames, gpu / frames,
		roundi(gpu / frames * frames / seconds / 10.0)])


## Bildraten-Begrenzung: normal / Fenster im Hintergrund / Pause mit ruhender Kamera.
static func fpstest(game: Node) -> void:
	var limiter: FrameLimiter = game.get_node("FrameLimiter")
	var was := DevTools.automated
	DevTools.automated = false        # wie im echten Spiel
	var res := []
	for step: String in ["normal", "Hintergrund", "Pause"]:
		match step:
			"normal":
				limiter._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
			"Hintergrund":
				limiter._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			"Pause":
				limiter._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
				game.hud._set_speed(0)
		if step == "Pause":
			for k in 90:            # Kamera muss erst 1 s ruhen
				await game.get_tree().process_frame
		else:
			for k in 3:             # Begrenzer läuft im eigenen _process (nach dem Signal)
				await game.get_tree().process_frame
		res.append("%s %d" % [step, Engine.max_fps])
	game.hud._set_speed(1)
	DevTools.automated = was
	print("fpstest Bildraten-Grenze (Menü %d): %s" % [GraphicsSettings.fps_limit, ", ".join(res)])


## Taste M schaltet alle Töne (Master) stumm und wieder an.
static func mutetest(game: Node) -> void:
	var master := AudioServer.get_bus_index("Master")
	var before := AudioServer.is_bus_mute(master)
	var e := InputEventKey.new()
	e.set_meta("synthetic", true)
	e.keycode = KEY_M
	e.pressed = true
	game.hud._unhandled_key_input(e)
	var after := AudioServer.is_bus_mute(master)
	game.hud._unhandled_key_input(e)
	print("mutetest Master stumm: vorher %s -> M -> %s -> M -> %s" % [before, after, AudioServer.is_bus_mute(master)])


## Überschreiben-Schutz: 5x in denselben Slot speichern (eigener Testordner) -> Hauptstand + 3 Sicherungen, ladbar.
static func savetest(game: Node) -> void:
	var map: CityMap = game.map
	var sim: Simulation = game.sim
	SaveManager.dir = "user://saves_test"
	var pops := []
	for k in 5:
		sim.money = 1000.0 * (k + 1)     # unterscheidbar
		SaveManager.save("1", map, sim)
	for b: Dictionary in SaveManager.backups():
		pops.append("%s=$%d" % [b["slot"], int((b["meta"] as Dictionary)["money"])])
	var main_money: int = SaveManager.meta("1")["money"]
	var err := SaveManager.load_slot("1.bak3", map, sim)
	print("savetest Slot 1 = $%d, Sicherungen %s, Laden bak3: %s (Kasse $%d)" % [main_money, pops, error_string(err), int(sim.money)])
	for f in DirAccess.get_files_at(SaveManager.dir):
		DirAccess.remove_absolute(SaveManager.dir + "/" + f)
	DirAccess.remove_absolute(SaveManager.dir)
	SaveManager.dir = SaveManager.DIR


## Zoom ohne Mausrad: Trackpad-Geste (Pinch), Zwei-Finger-Wischen (verschieben, mit Cmd zoomen).
static func zoomtest(game: Node) -> void:
	var cam: CityCamera = game.cam
	var d0 := cam._target_dist
	var g := InputEventMagnifyGesture.new()
	g.set_meta("synthetic", true)
	g.factor = 1.25
	cam._unhandled_input(g)
	var d1 := cam._target_dist
	var p := InputEventPanGesture.new()
	p.set_meta("synthetic", true)
	p.delta = Vector2(10, 0)
	var pos0 := cam.position
	cam._unhandled_input(p)
	var moved := cam.position.distance_to(pos0)
	p.meta_pressed = true
	p.delta = Vector2(0, 10)
	cam._unhandled_input(p)
	print("zoomtest Abstand %.0f -> Pinch %.0f -> Cmd+Wischen %.0f, Zwei-Finger-Wischen verschiebt um %.1f" % [
		d0, d1, cam._target_dist, moved])
	cam.position = pos0       # Kamera zurück, folgende Tests rechnen mit ihr
	cam._target_dist = d0
	cam._dist = d0


## Reichweiten-Vorschau beim Bauen: neue Haltestelle an Straße ohne Busnetz, Bahnhof auf Gleis, Schule.
static func rangetest(game: Node) -> void:
	var map: CityMap = game.map
	var sim: Simulation = game.sim
	var tools: ToolController = game.tools
	for t: ToolController.Tool in [ToolController.Tool.BUS_STOP, ToolController.Tool.STATION, ToolController.Tool.SCHOOL]:
		tools.set_tool(t)
		var best := Vector2i(-1, -1)
		var best_new := -1
		for i in map.size * map.size:
			var p := Vector2i(i % map.size, i / map.size)
			if tools.tile_cost(p) < 0 or (t == ToolController.Tool.BUS_STOP and sim.bus_served[i] == 1):
				continue
			if t == ToolController.Tool.SCHOOL and p.distance_to(Vector2i(map.size / 2, map.size / 2)) > 8:
				continue
			var r := tools.range_preview(p)
			var nnew := 0
			for j: int in r:
				if r[j] == ToolController.RANGE_NEW:
					nnew += 1
			if nnew * 100 + r.size() > best_new:      # vorzugsweise viele neue Anschlüsse, sonst große Reichweite
				best_new = nnew * 100 + r.size()
				best = p
		var r := tools.range_preview(best)
		var roads := 0
		var fresh := 0
		for j: int in r:
			if r[j] == ToolController.RANGE_ROAD:
				roads += 1
			elif r[j] == ToolController.RANGE_NEW:
				fresh += 1
		print("rangetest %-14s bei %s: %d markierte Tiles (Straßen %d, Gebäude mit neuem Anschluss %d)" % [
			ToolController.TOOLS[t]["name"], best, r.size(), roads, fresh])
	tools.set_tool(ToolController.Tool.INSPECT)


## Strom-Bilanz eines Spielstands: Dienstgebäude ohne Strom, Netze mit Engpass.
static func powerreport(game: Node) -> void:
	var map: CityMap = game.map
	var sim: Simulation = game.sim
	sim.refresh()
	var dark := []
	var svc_use := 0
	for i in map.size * map.size:
		if map.anchor[i] == i and Config.SPECIALS[map.special[i]].has("service"):
			svc_use += sim.tile_power_use(i)
			if not sim.special_powered(i):
				var net: Dictionary = sim.power_nets[sim.power_net[i]] if sim.power_net[i] >= 0 else {}
				dark.append("%s %d,%d (Netz %d/%d MW, %d Kraftwerke)" % [Config.SPECIALS[map.special[i]]["name"], i % map.size,
					i / map.size, int(net.get("demand", 0)), int(net.get("capacity", 0)), int(net.get("plants", 0))])
	print("powerreport Bedarf %d / Leistung %d MW (davon Dienste %d MW), Dienste ohne Strom: %s" % [sim.power_demand,
		sim.power_supply, svc_use, dark])


## Prüfsummen nach 12 Monaten mit festem Zufall (synchron): vor/nach Optimierungen vergleichen.
static func determinism(game: Node) -> void:
	var map: CityMap = game.map
	var sim: Simulation = game.sim
	sim.speed = 0                     # kein paralleler Monatstakt
	if sim._commute_task != -1:       # Startberechnung im Hintergrund abwarten (nutzt globalen Zufall)
		WorkerThreadPool.wait_for_task_completion(sim._commute_task)
		sim._commute_task = -1
	sim.congestion = PackedFloat32Array()   # Vorgeschichte (Stau, Bahnhofs-Andrang) vom Laden verwerfen
	sim.station_use = {}
	seed(1)
	sim.refresh()
	sim._rng.seed = 1
	game.fire_dept._rng.seed = 1
	seed(1)
	var trace := []
	for m in 12:
		seed(100 + m)               # globaler Zufall je Monat fest (andere Stellen verbrauchen ihn nebenbei)
		sim.tick_month()
		trace.append("%d:%d/%d" % [m, sim.population, int(sim.avg_commute * 10)])
	print("determinism Verlauf ", trace)
	var rd := 0
	var pw := 0
	var jd := 0
	for i in map.size * map.size:
		rd += sim.road_dist[i] * (i % 97 + 1)
		pw += sim.powered[i] * (i % 89 + 1)
		jd += sim.junction_dist[i] * (i % 83 + 1)
	print("determinism Einw %d Jobs %d/%d level %d worn %d villa %d road_dist %d powered %d junction %d power %d/%d/%d" % [
		sim.population, sim.jobs_com, sim.jobs_ind, hash(map.level), hash(map.worn), hash(map.villa), rd, pw, jd,
		sim.power_demand, sim.power_supply, sim.power_served])


## Rohstoffe: Holzfäller, Steinbruch, Grube, Mine mit Strom; Vorkommen nehmen ab, Lager voll -> Export.
static func restest() -> void:
	var m := CityMap.new()
	m.height.fill(6)
	var sim := Simulation.new()
	sim.map = m
	var put_special := func(x: int, z: int, sp: int) -> void:
		var sz: int = Config.SPECIALS[sp]["size"]
		var a := m.idx(x, z)
		for dz in sz:
			for dx in sz:
				m.special[m.idx(x + dx, z + dz)] = sp
				m.anchor[m.idx(x + dx, z + dz)] = a
		m.slevel[a] = 1
	# Stromleitung entlang z=20 verbindet alles, 2 Kohlekraftwerke liefern genug
	for x in range(0, 60):
		m.power_line[m.idx(x, 20)] = 1
	put_special.call(0, 18, Config.Special.COAL)
	for x in range(10, 16):
		for z in range(10, 18):
			m.feature[m.idx(x, z)] = Config.Feature.TREE
	put_special.call(12, 19, Config.Special.LUMBER)
	for x in range(19, 24):           # Fels neben dem Steinbruch
		for z in range(16, 19):
			m.ore[m.idx(x, z)] = Config.Ore.STONE
			m.ore_amt[m.idx(x, z)] = 200
	put_special.call(20, 19, Config.Special.QUARRY)
	for x in range(28, 33):
		for z in range(17, 20):
			m.ore[m.idx(x, z)] = Config.Ore.SAND if x < 30 else Config.Ore.CLAY
			m.ore_amt[m.idx(x, z)] = 50
	put_special.call(30, 21, Config.Special.PIT)
	for x in range(38, 46):
		for z in range(15, 19):
			m.ore[m.idx(x, z)] = [Config.Ore.COAL, Config.Ore.IRON, Config.Ore.GOLD][(x - 38) % 3]
			m.ore_amt[m.idx(x, z)] = 200
	put_special.call(40, 19, Config.Special.MINE)
	# Lieferweg: Straße z=21 an allen Gebäuden vorbei, Lagerhaus am Ende; Stichstraße zum Holzfäller
	for x in range(0, 50):
		if x != 30:
			m.road[m.idx(x, 21)] = 1
	m.road[m.idx(12, 20)] = 1
	for x in range(29, 32):           # Umfahrung der Grube (sonst zwei getrennte Netze)
		m.road[m.idx(x, 22)] = 1
	put_special.call(50, 21, Config.Special.WAREHOUSE)
	# Mine ohne Straße (eigene Erzader) -> eigener Vorrat
	for x in range(55, 60):
		for z in range(5, 8):
			m.ore[m.idx(x, z)] = Config.Ore.IRON
			m.ore_amt[m.idx(x, z)] = 200
	put_special.call(56, 8, Config.Special.MINE)
	for z in range(10, 21):
		m.power_line[m.idx(57, z)] = 1
	var ore_before := 0
	for i in m.size * m.size:
		ore_before += m.ore_amt[i]
	for k in 24:
		sim._compute_power()
		sim._produce()
		sim._export_surplus()
	var ore_after := 0
	for i in m.size * m.size:
		ore_after += m.ore_amt[i]
	var st := PackedStringArray()
	for r: String in Config.RESOURCES:
		st.append("%s %d (+%d/Mon)" % [Config.RESOURCES[r]["name"], int(sim.stock[r]), int(sim.production[r])])
	print("restest nach 24 Monaten: %s" % ", ".join(st))
	print("restest Vorkommen %d -> %d, Lager %d, Export letzter Monat $%d" % [ore_before, ore_after,
		sim.stock_capacity(), roundi(sim.export_income)])
	for a: int in sim.producer_info:
		var info: Dictionary = sim.producer_info[a]
		if str(info["issue"]) != "":
			print("restest %s: %s" % [Config.SPECIALS[m.special[a]]["name"], info["issue"]])
	var lone := m.idx(56, 8)
	print("restest Mine ohne Straße: liefert %s, eigener Vorrat %s, Hinweis: %s" % [sim.delivers(lone),
		sim.local_buffer.get(lone, {}), sim.producer_info.get(lone, {}).get("issue", "")])
	var iron_before: float = float(sim.stock["iron"])
	sim.stock["iron"] = 0.0
	for z in range(8, 22):
		m.road[m.idx(58, z)] = 1         # Straße zur Mine nachbauen, bis zum Lagerhaus
	for x in range(52, 58):
		m.road[m.idx(x, 21)] = 1
	sim._compute_power()
	sim._produce()
	print("restest nach Straßenbau: liefert %s, Eisen im Lager %d (Vorrat + Monatsförderung), eigener Vorrat %s" % [
		sim.delivers(lone), int(sim.stock["iron"]), sim.local_buffer.get(lone, {})])
	sim.stock["iron"] = iron_before
	print("restest Lager mit Lagerhaus: %d" % sim.stock_capacity())
	sim.free()


## Erneuerung: Waldausbreitung, Baumschule, Regeneration leerer Adern, Prospektor, Recycling beim Abriss.
static func renewtest() -> void:
	var m := CityMap.new()
	m.height.fill(6)
	var sim := Simulation.new()
	sim.map = m
	sim._rng.seed = 7
	var put_special := func(x: int, z: int, sp: int) -> void:
		var sz: int = Config.SPECIALS[sp]["size"]
		var a := m.idx(x, z)
		for dz in sz:
			for dx in sz:
				m.special[m.idx(x + dx, z + dz)] = sp
				m.anchor[m.idx(x + dx, z + dz)] = a
		m.slevel[a] = 1
	for x in range(0, 60):
		m.power_line[m.idx(x, 40)] = 1
	put_special.call(0, 38, Config.Special.COAL)
	for x in range(5, 25):              # Wald 20x20 fern von allem, mit gerodeter 6x6-Lichtung in der Mitte
		for z in range(5, 25):
			var hole := x >= 12 and x < 18 and z >= 12 and z < 18
			m.feature[m.idx(x, z)] = Config.Feature.NONE if hole else Config.Feature.TREE
	put_special.call(30, 41, Config.Special.NURSERY)
	for x in range(80, 90):             # Hügel für den Prospektor
		for z in range(30, 50):
			m.height[m.idx(x, z)] = 12
	for x in range(60, 85):
		m.power_line[m.idx(x, 40)] = 1
	put_special.call(84, 41, Config.Special.PROSPECTOR)
	m.slevel[m.idx(84, 41)] = 3
	for x in range(50, 70):             # 20 leergeräumte Kohle-Tiles
		m.ore[m.idx(x, 10)] = Config.Ore.COAL
		m.ore_amt[m.idx(x, 10)] = 0
	var trees := func() -> int:
		var c := 0
		for i in m.size * m.size:
			if m.feature[i] == Config.Feature.TREE:
				c += 1
		return c
	var ores := func() -> int:
		var c := 0
		for i in m.size * m.size:
			if m.ore[i] != Config.Ore.NONE and m.ore_amt[i] > 0:
				c += 1
		return c
	var t0: int = trees.call()
	var hole_trees := func() -> int:
		var c := 0
		for x in range(12, 18):
			for z in range(12, 18):
				if m.feature[m.idx(x, z)] == Config.Feature.TREE:
					c += 1
		return c
	var o0: int = ores.call()
	var found: Array[String] = []
	sim.alert.connect(func(t: String, _p: Vector2i) -> void: found.append(t))
	var planted := 0
	var ring := func() -> int:                # Gras direkt außerhalb des Waldrands
		var c := 0
		for x in range(4, 26):
			for z in [4, 25]:
				if m.feature[m.idx(x, z)] == Config.Feature.TREE:
					c += 1
		return c
	for k in 120:
		sim._compute_power()
		sim._renew()
		planted += sim.planted
		if k == 23:
			print("renewtest nach 24 Monaten: Lichtung %d/36 zugewachsen, Waldrand nach außen %d" % [hole_trees.call(), ring.call()])
	print("renewtest nach 10 Jahren: Lichtung %d/36 zugewachsen, Waldrand nach außen %d (soll 0)" % [hole_trees.call(), ring.call()])
	var near := 0
	for i in m.size * m.size:
		if m.feature[i] == Config.Feature.TREE and absi(i % m.size - 30) <= Config.NURSERY_RANGE + 1 \
				and absi(i / m.size - 41) <= Config.NURSERY_RANGE + 1:
			near += 1
	print("renewtest 10 Jahre: Bäume %d -> %d (Baumschule gepflanzt %d, davon im Umkreis %d)" % [t0, trees.call(), planted, near])
	var regrown := 0
	for x in range(50, 70):
		regrown += m.ore_amt[m.idx(x, 10)]
	print("renewtest 20 leere Kohle-Tiles: zusammen +%d Einheiten (Erwartung ~100 = 1 je Tile alle 2 Jahre)" % regrown)
	print("renewtest Prospektor Stufe 3 (10 Jahre): %d Funde, Vorkommen-Tiles %d -> %d, Meldungen %s" % [found.size(), o0, ores.call(),
		found])
	sim.stock["planks"] = 0.0
	sim.stock["bricks"] = 0.0
	var back := sim.recycle(Config.Zone.RES, 3)
	print("renewtest Abriss Wohnen 3 ohne Recyclinghof: %s" % back)
	put_special.call(40, 41, Config.Special.RECYCLER)
	sim._compute_power()
	back = sim.recycle(Config.Zone.RES, 3)
	print("renewtest Abriss Wohnen 3 mit Recyclinghof: %s, Lager Bretter %d" % [back, int(sim.stock["planks"])])
	# Baumaterial beim Bauen: Lager zuerst, Rest sofort zugekauft
	sim.money = 10000.0
	sim.stock["bricks"] = 10.0
	var mats: Dictionary = Config.SPECIAL_MATERIALS[Config.Special.POLICE]
	var need := sim.build_need(mats)
	var paid := sim.use_build_materials(mats)
	print("renewtest Baumaterial Polizei %s: fehlt %s, Zukauf $%d, Kasse $%d, Ziegel im Lager %d" % [mats, need[0], int(paid),
		int(sim.money), int(sim.stock["bricks"])])
	var back_sp := sim.recycle_special(Config.Special.POLICE, 2)
	print("renewtest Abriss Polizei Stufe 2 (mit Recyclinghof): %s" % back_sp)
	sim.free()


## Haushalt aufgeschlüsselt (Einnahmen/Ausgaben nach Posten) für den geladenen Stand, nach 1 Monat.
static func econreport(game: Node) -> void:
	var sim: Simulation = game.sim
	sim.tick_month()
	var inc := PackedStringArray()
	for k: String in sim.income_parts:
		inc.append("%s %d" % [k, roundi(float(sim.income_parts[k]))])
	print("econreport %s: Kasse $%d, Einw. %d, Jobs %d/%d, Steuer %s, Zufriedenheit %d%%" % [sim.date_string(), int(sim.money),
		sim.population, sim.jobs_com, sim.jobs_ind, sim.tax, roundi(sim.city_happiness * 100.0)])
	print("econreport Einnahmen $%d: %s" % [roundi(sim.last_income), ", ".join(inc)])
	print("econreport Ausgaben $%d: Straßen %d, Parks %d, Leitungen %d, Sonderbauten %d, Gleise %d, Haltestellen %d, Bahnhöfe %d, Zukauf %d, Verwaltung %d" % [
		roundi(sim.last_expense), roundi(sim.road_count * Config.UPKEEP_ROAD), roundi(sim.park_count * Config.UPKEEP_PARK),
		roundi(sim.line_count * Config.UPKEEP_POWERLINE), roundi(sim.special_upkeep), roundi(sim.rail_count * Config.UPKEEP_RAIL),
		roundi(sim.bus_stop_count * Config.UPKEEP_BUS_STOP), roundi(sim.station_count * Config.UPKEEP_STATION), roundi(sim.import_cost), roundi(sim.admin_cost)])
	print("econreport Zufriedenheit Anteile %s" % sim.happy_parts)
	var mat := PackedStringArray()
	for r: String in ["wood", "planks", "bricks", "glass", "steel", "concrete", "stone", "coal"]:
		mat.append("%s: +%d / verbaut %d / zugekauft %d / Lager %d" % [Config.RESOURCES[r]["name"], roundi(float(sim.production.get(r, 0.0))),
			roundi(float(sim.last_materials.get(r, 0.0))), roundi(float(sim.imported.get(r, 0.0))), roundi(float(sim.stock.get(r, 0.0)))])
	print("econreport Material je Monat: %s" % " | ".join(mat))
	var works := {}
	for a in sim.map.size * sim.map.size:
		if sim.map.anchor[a] == a and sim.map.special[a] != Config.Special.NONE:
			var d: Dictionary = Config.SPECIALS[sim.map.special[a]]
			if d.has("process") or d.has("produce") or d.has("renew") or d.has("storage"):
				var nm := "%s St.%d" % [d["name"], sim.map.special_level(a)]
				works[nm] = int(works.get(nm, 0)) + 1
	print("econreport Werke: %s" % works)
	print("econreport je Einwohner: Einnahmen $%.2f, Ausgaben $%.2f / Monat" % [sim.last_income / maxf(sim.population, 1),
		sim.last_expense / maxf(sim.population, 1)])


## Neustart-Verlauf: neue Karte, Startkapital, kleines Startviertel, danach jedes Jahr ausbauen, solange Geld da ist
## (Straße + 2 Zonenblöcke, Windrad bei Strommangel, Dienste ab Erwartung). Ausgabe je Jahr.
static func freshrun(game: Node, years: int) -> void:
	var map: CityMap = game.map
	var sim: Simulation = game.sim
	var tools: ToolController = game.tools
	DemoCity.generate_map(map)
	sim.money = Config.START_MONEY
	map.notify_changed(Rect2i(0, 0, map.size, map.size))
	sim.refresh()
	var c := map.size / 2
	var place := func(tool: ToolController.Tool, tiles: Array[Vector2i]) -> void:
		tools.set_tool(tool)
		tools._apply(tiles)
	var click := func(tool: ToolController.Tool, at: Vector2i) -> void:
		tools.set_tool(tool)
		tools.hover = at
		tools._apply(tools._affected_tiles())
	# Straßenachse in x-Richtung; Blöcke 6x3 ober- und unterhalb, je Abschnitt 7 Tiles
	var segment := func(k: int, top: ToolController.Tool, bottom: ToolController.Tool) -> void:
		var x0 := c - 10 + k * 7
		var road: Array[Vector2i] = []
		for x in range(x0, x0 + 7):
			road.append(Vector2i(x, c))
		road.append(Vector2i(x0 + 6, c - 1))
		road.append(Vector2i(x0 + 6, c - 2))
		road.append(Vector2i(x0 + 6, c - 3))
		road.append(Vector2i(x0 + 6, c + 1))
		road.append(Vector2i(x0 + 6, c + 2))
		road.append(Vector2i(x0 + 6, c + 3))
		place.call(ToolController.Tool.ROAD, road)
		for blk: Array in [[top, c - 3], [bottom, c + 1]]:
			var area: Array[Vector2i] = []
			for z in 3:
				for x in 6:
					area.append(Vector2i(x0 + x, int(blk[1]) + z))
			place.call(blk[0], area)
		# Strom über die Straßen (Zonen leiten selbst, Straßen nicht)
		place.call(ToolController.Tool.POWERLINE, [Vector2i(x0 + 6, c - 2), Vector2i(x0 + 6, c + 2), Vector2i(x0 + 2, c),
			Vector2i(x0 - 1, c - 2), Vector2i(x0 - 1, c + 2)] as Array[Vector2i])
	var start_money := sim.money
	segment.call(0, ToolController.Tool.IND, ToolController.Tool.RES)
	segment.call(1, ToolController.Tool.COM, ToolController.Tool.RES)
	click.call(ToolController.Tool.WIND, Vector2i(c - 12, c - 2))
	click.call(ToolController.Tool.WIND, Vector2i(c - 12, c + 2))
	place.call(ToolController.Tool.POWERLINE, [Vector2i(c - 11, c - 2), Vector2i(c - 11, c - 1), Vector2i(c - 11, c + 1),
		Vector2i(c - 11, c + 2), Vector2i(c - 11, c)] as Array[Vector2i])
	print("freshrun Start: Kasse $%d -> $%d (Startviertel kostet $%d)" % [int(start_money), int(sim.money), int(start_money - sim.money)])
	var seg := 2
	var winds := 2
	var built := {}
	var low := sim.money
	for y in years:
		var inc := 0.0
		var exp := 0.0
		for m in 12:
			sim.tick_month()
			inc += sim.last_income
			exp += sim.last_expense
			low = minf(low, sim.money)
		var did := PackedStringArray()
		# Dienste, sobald erwartet (Schwellen wie im Spiel: Polizei/Feuer 300, Schule 300, Krankenhaus 600)
		for pair: Array in [[ToolController.Tool.FIRE, 300], [ToolController.Tool.POLICE, 300],
				[ToolController.Tool.SCHOOL, 500], [ToolController.Tool.HOSPITAL, 900]]:
			if not built.has(pair[0]) and sim.population >= int(pair[1]) and sim.money > 4000:
				_place_near_center(map, tools, pair[0])
				built[pair[0]] = true
				did.append(ToolController.TOOLS[pair[0]]["name"])
		if sim.power_demand > sim.power_supply * 0.8 and sim.money > 1500:
			click.call(ToolController.Tool.WIND, Vector2i(c - 10 + winds * 2, c - 4))   # direkt an der Zone -> leitet
			winds += 1
			did.append("Windrad")
		while sim.money > 3000 and seg < 12:
			var top: ToolController.Tool = [ToolController.Tool.COM, ToolController.Tool.IND][seg % 2]
			segment.call(seg, top, ToolController.Tool.RES)
			seg += 1
			did.append("Abschnitt")
		print("freshrun Jahr %d: Kasse $%6d  Einw. %5d  Jobs %4d  Einnahmen/Jahr $%6d  Ausgaben/Jahr $%6d (Zukauf %d)  Saldo $%6d  Strom %d/%d  %s" % [
			y + 1, int(sim.money), sim.population, sim.jobs_com + sim.jobs_ind, roundi(inc), roundi(exp), roundi(sim.import_cost),
			roundi(inc - exp), sim.power_demand, sim.power_supply, ", ".join(did)])
	print("freshrun tiefster Kassenstand $%d" % int(low))
	var why := {}
	var zones := [0, 0, 0, 0]
	for i in map.size * map.size:
		if map.zone[i] != Config.Zone.NONE:
			zones[map.zone[i]] += 1
			for b: String in sim.growth_blockers(i):
				why[b.substr(0, 40)] = int(why.get(b.substr(0, 40), 0)) + 1
	print("freshrun Zonen-Tiles W/G/I %d/%d/%d, Nachfrage W %.2f G %.2f I %.2f, Arbeitslos %d%%" % [zones[1], zones[2], zones[3],
		sim.demand_res, sim.demand_com, sim.demand_ind, roundi(sim.unemployment * 100.0)])
	print("freshrun Blocker: %s" % why)
	var occ_sum := 0
	var houses := 0
	var vac := {}
	for i in map.size * map.size:
		if map.level[i] > 0 and map.zone[i] != Config.Zone.NONE:
			houses += 1
			occ_sum += map.occupancy(i)
			if map.is_vacant(i):
				var r := sim.decay_reason(i).substr(0, 30)
				vac[r] = int(vac.get(r, 0)) + 1
	print("freshrun Belegung Ø %d %% über %d Gebäude, Leerstand je Grund: %s" % [occ_sum / maxi(houses, 1), houses, vac])
	for net: Dictionary in sim.power_nets:
		print("freshrun Netz cap %s demand %s plants %s unserved %s" % [net.get("capacity"), net.get("demand"), net.get("plants"), net.get("unserved")])
## Forschung: Sperren, Uni + Institut bauen, Projekt starten, bis zum Abschluss simulieren, Wirkung prüfen.
## Mit --loadfile=<Megacity-Kopie> (genug Einwohner); ohne nur die Sperren.
static func researchtest(game: Node) -> void:
	var map: CityMap = game.map
	var sim: Simulation = game.sim
	var tools: ToolController = game.tools
	print("researchtest Einw. %d, Schule %d %%: Uni gesperrt? '%s', Institut gesperrt? '%s'" % [sim.population,
		roundi(float(sim.city_coverage.get("education", 0.0)) * 100.0), tools.locked_reason(ToolController.Tool.UNIVERSITY),
		tools.locked_reason(ToolController.Tool.INSTITUTE)])
	if sim.population < 8000:
		return
	sim.money += 100000
	var before := sim.money
	_place_near_center(map, tools, ToolController.Tool.UNIVERSITY)
	print("researchtest Uni gebaut für $%d, Institut jetzt gesperrt? '%s'" % [int(before - sim.money),
		tools.locked_reason(ToolController.Tool.INSTITUTE)])
	_place_near_center(map, tools, ToolController.Tool.INSTITUTE)
	tools.set_tool(ToolController.Tool.INSPECT)
	sim.tick_month()
	print("researchtest Institute %d, Akademiker %d (Quote %d %%, Faktor %.2f), Punkte/Monat bei $0: %.1f" % [sim.institute_levels(),
		int(sim.academics_count()), roundi(sim.academics() * 100.0), sim.academic_factor(), sim.research_points()])
	sim.research_budget = 1000.0
	var gold0 := float(sim.stock["gold"])
	var m0 := sim.money
	var err := sim.start_research("blast_furnace")
	print("researchtest Hochöfen ohne Tiefbau: '%s'" % err)
	err = sim.start_research("deep_mining")
	print("researchtest Tiefbau gestartet: '%s', Gold %d -> %d, Kasse -$%d (Gold-Zukauf)" % [err, int(gold0),
		int(sim.stock["gold"]), int(m0 - sim.money)])
	var months := 0
	var spent := 0.0
	while sim.research_current != "" and months < 120:
		sim._research()            # nur der Forschungsschritt (ganzer Monat dauert in großen Städten ~15 s)
		spent += sim.research_spent
		months += 1
	print("researchtest Tiefbau fertig nach %d Monaten, Budget ausgegeben $%d, erforscht %s, %.1f Punkte/Monat" % [months, int(spent),
		sim.research_done, sim.research_rate])
	var prod_before := 0.0
	for r: String in ["stone", "coal", "iron"]:
		prod_before += float(sim.production.get(r, 0.0))
	sim.tick_month()
	var prod_after := 0.0
	for r: String in ["stone", "coal", "iron"]:
		prod_after += float(sim.production.get(r, 0.0))
	print("researchtest Förderung Stein+Kohle+Eisen im Monat: %d (vorher letzter Monat %d)" % [int(prod_after), int(prod_before)])
	sim.tick_month()
	print("researchtest ohne Projekt: Forschungsausgabe $%d (soll 0)" % int(sim.research_spent))
	var d := sim.to_dict()
	var sim2 := Simulation.new()
	sim2.map = map
	sim2.from_dict(d)
	print("researchtest Speichern/Laden: erforscht %s, Budget %d" % [sim2.research_done, int(sim2.research_budget)])
	sim2.free()
	game.hud._toggle_popup("research")
	await game.get_tree().process_frame


## Bäume auf der Karte: Anzahl, Anteil am Land, Baumschulen; danach 12 Monate simulieren.
static func treereport(game: Node) -> void:
	var map: CityMap = game.map
	var sim: Simulation = game.sim
	var count := func() -> Array:
		var t := 0
		var land := 0
		for i in map.size * map.size:
			if map.height[i] >= Config.WATER_LEVEL:
				land += 1
			if map.feature[i] == Config.Feature.TREE:
				t += 1
		return [t, land]
	var nurs := 0
	for i in map.size * map.size:
		if map.anchor[i] == i and map.special[i] == Config.Special.NURSERY:
			nurs += 1
	var c0: Array = count.call()
	print("treereport %s: Bäume %d = %d%% des Landes, Baumschulen %d" % [sim.date_string(), c0[0],
		roundi(100.0 * c0[0] / maxi(int(c0[1]), 1)), nurs])
	for k in 12:
		sim.tick_month()
	var c1: Array = count.call()
	print("treereport nach 12 Monaten: Bäume %d (+%d)" % [c1[0], int(c1[0]) - int(c0[0])])


## Anzahl Vorkommen-Tiles je Art auf der aktuellen Karte.
static func orecount(game: Node) -> void:
	var map: CityMap = game.map
	var cnt := {}
	for i in map.size * map.size:
		if map.ore[i] != Config.Ore.NONE:
			var r: String = Config.ORE_RESOURCE[map.ore[i]]
			cnt[r] = int(cnt.get(r, 0)) + 1
	var amt := {}
	for i in map.size * map.size:
		if map.ore[i] != Config.Ore.NONE:
			var r: String = Config.ORE_RESOURCE[map.ore[i]]
			amt[r] = int(amt.get(r, 0)) + map.ore_amt[i] * Config.ORE_UNIT
	print("orecount Tiles %s, Menge %s, Overlay-Modus %d" % [cnt, amt, game.get_node("MapOverlay").mode])


## Abbau-Gebäude in die Demo-Stadt setzen (Screenshots).
static func place_resources(game: Node) -> void:
	game.sim.money += 20000
	for t: ToolController.Tool in [ToolController.Tool.MINE, ToolController.Tool.QUARRY, ToolController.Tool.PIT,
			ToolController.Tool.LUMBER, ToolController.Tool.WAREHOUSE, ToolController.Tool.STEELWORKS,
			ToolController.Tool.SAWMILL, ToolController.Tool.BRICKWORKS, ToolController.Tool.GLASSWORKS,
			ToolController.Tool.NURSERY, ToolController.Tool.PROSPECTOR, ToolController.Tool.RECYCLER]:
		_place_near_center(game.map, game.tools, t)
	game.tools.set_tool(ToolController.Tool.INSPECT)
	var map: CityMap = game.map
	for i in map.size * map.size:
		if map.anchor[i] == i and (Config.SPECIALS[map.special[i]].has("produce") or Config.SPECIALS[map.special[i]].has("storage")
				or Config.SPECIALS[map.special[i]].has("process") or Config.SPECIALS[map.special[i]].has("renew")):
			print("resbuild %s bei %d,%d" % [Config.SPECIALS[map.special[i]]["name"], i % map.size, i / map.size])
	for k in 4:
		game.sim.tick_month()
	print("resbuild Lager nach 4 Monaten: %s, Förderung %s" % [game.sim.stock, game.sim.production])
	for a: int in game.sim.producer_info:
		print("resbuild   %s: %s" % [Config.SPECIALS[map.special[a]]["name"], game.sim.producer_info[a]])
	game.hud._info_detail = true
	for i in map.size * map.size:
		if map.anchor[i] == i and Config.SPECIALS[map.special[i]].has("renew"):
			game.hud._on_hover(Vector2i(i % map.size, i / map.size))
			print("resbuild Info %s" % game.hud.info_text)
	game.hud._info_detail = false
	# Abriss eines Wohnhauses ab Stufe 2 -> Recycling-Meldung
	var msgs: Array[String] = []
	game.tools.message.connect(func(t: String) -> void: msgs.append(t))
	for i in map.size * map.size:
		if map.zone[i] == Config.Zone.RES and map.level[i] >= 2:
			var before: float = float(game.sim.stock.get("bricks", 0.0))
			game.tools.set_tool(ToolController.Tool.BULLDOZE)
			game.tools._apply([Vector2i(i % map.size, i / map.size)] as Array[Vector2i])
			print("resbuild Abriss Wohnen bei %d,%d: Ziegel %.1f -> %.1f, Meldungen %s" % [i % map.size, i / map.size,
				before, float(game.sim.stock.get("bricks", 0.0)), msgs])
			break
	game.tools.set_tool(ToolController.Tool.INSPECT)


## Verarbeitung: 4 Werke mit Strom, knappe Rohstoffe -> anteilig; Kraftwerk verbraucht Kohle; Baustoffe beim Wachsen.
static func processtest() -> void:
	var m := CityMap.new()
	m.height.fill(6)
	var sim := Simulation.new()
	sim.map = m
	var put_special := func(x: int, z: int, sp: int) -> void:
		var sz: int = Config.SPECIALS[sp]["size"]
		var a := m.idx(x, z)
		for dz in sz:
			for dx in sz:
				m.special[m.idx(x + dx, z + dz)] = sp
				m.anchor[m.idx(x + dx, z + dz)] = a
		m.slevel[a] = 1
	for x in range(0, 40):
		m.power_line[m.idx(x, 10)] = 1
		m.road[m.idx(x, 10)] = 1      # Lieferweg
	put_special.call(0, 8, Config.Special.COAL)
	put_special.call(30, 8, Config.Special.WAREHOUSE)
	put_special.call(5, 8, Config.Special.SAWMILL)
	put_special.call(10, 8, Config.Special.BRICKWORKS)
	put_special.call(15, 8, Config.Special.GLASSWORKS)
	put_special.call(20, 8, Config.Special.STEELWORKS)
	sim.stock = {"wood": 100.0, "clay": 100.0, "sand": 5.0, "iron": 100.0, "coal": 22.0}
	sim._compute_power()
	sim._produce()
	sim._process_goods()
	var line := PackedStringArray()
	for r: String in ["planks", "bricks", "glass", "steel", "coal", "sand"]:
		line.append("%s %.1f" % [Config.RESOURCES[r]["name"], float(sim.stock.get(r, 0.0))])
	print("processtest nach 1 Monat: %s, Zukauf Kohle %.0f ($%.0f offen)" % [", ".join(line),
		float(sim.imported.get("coal", 0.0)), sim._import_pending])
	for a: int in sim.producer_info:
		var info: Dictionary = sim.producer_info[a]
		if str(info["issue"]) != "":
			print("processtest   %s: %s" % [Config.SPECIALS[m.special[a]]["name"], info["issue"]])
	# Baustoffe beim Wachsen
	sim.population = 1000
	sim.money = 100000.0
	var before: float = float(sim.stock["bricks"])
	var ok := sim._use_materials(Config.Zone.RES, 2)
	print("processtest Wohnen -> Stufe 2: ok %s, Ziegel %.0f -> %.0f, Bedarf Stufe 3 %s" % [ok, before,
		float(sim.stock["bricks"]), sim.material_need(Config.Zone.RES, 3)])
	sim.money = 0.0
	sim._import_pending = 0.0
	sim.stock["glass"] = 0.0
	print("processtest ohne Geld und ohne Glas -> Stufe 3 möglich: %s" % sim._use_materials(Config.Zone.RES, 3))
	sim.free()


## Haushalt über 12 Monate: Einnahmen, Ausgaben, davon Zukauf (Kraftwerkskohle, Baustoffe), Einwohner.
static func budgettest(game: Node) -> void:
	var sim: Simulation = game.sim
	sim.speed = 0
	var inc := 0.0
	var exp := 0.0
	var imp := 0.0
	var p0 := sim.population
	for m in 12:
		sim.tick_month()
		inc += sim.last_income
		exp += sim.last_expense
		imp += sim.import_cost
	print("budgettest 12 Monate: Einw. %d -> %d, Einnahmen Ø $%d, Ausgaben Ø $%d (davon Zukauf Ø $%d), Saldo Ø $%d" % [
		p0, sim.population, roundi(inc / 12), roundi(exp / 12), roundi(imp / 12), roundi((inc - exp) / 12)])


## Rohstoff-Diagnose eines Spielstands: Abbau-Gebäude mit Strom, Vorkommen im Umkreis, letzte Förderung.
static func resreport(game: Node) -> void:
	var map: CityMap = game.map
	var sim: Simulation = game.sim
	sim.speed = 0
	sim.tick_month()
	for a in map.size * map.size:
		if map.anchor[a] != a or map.special[a] == Config.Special.NONE:
			continue
		var def: Dictionary = Config.SPECIALS[map.special[a]]
		if not (def.has("produce") or def.has("process") or map.special[a] == Config.Special.COAL):
			continue
		var near := {}
		for z in range(maxi(a / map.size - 4, 0), mini(a / map.size + 6, map.size)):
			for x in range(maxi(a % map.size - 4, 0), mini(a % map.size + 6, map.size)):
				var j := z * map.size + x
				if map.ore_amt[j] > 0:
					var r: String = Config.ORE_RESOURCE[map.ore[j]]
					near[r] = int(near.get(r, 0)) + 1
		print("resreport %s bei %d,%d Stufe %d Strom %s, Vorkommen-Tiles ±4: %s, Info: %s" % [def["name"], a % map.size,
			a / map.size, map.special_level(a), sim.special_powered(a), near, sim.producer_info.get(a, {})])
	var cnt := {}
	for i in map.size * map.size:
		if map.ore[i] != Config.Ore.NONE:
			var r: String = Config.ORE_RESOURCE[map.ore[i]]
			cnt[r] = int(cnt.get(r, 0)) + 1
	print("resreport Vorkommen-Tiles gesamt: %s, Lager %s" % [cnt, sim.stock])


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
	e.set_meta("synthetic", true)
	e.position = p
	e.global_position = p
	return e


static func _mouse_btn(p: Vector2, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.set_meta("synthetic", true)
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = p
	e.global_position = p
	return e


## Bürgermeister: Meldung mit nahem Ort -> hinlaufen, kurz stehen, zurück; ferner Ort -> nur ansagen; HUD-Sprechblase.
static func mayortest(game: Node) -> void:
	var map: CityMap = game.map
	var mayor: Mayor = game.get_node("Mayor")
	game._new_city()
	mayor._find_home()
	mayor.position = mayor._home
	mayor._state = "home"
	var home := mayor._home
	var ht := Vector2i(int(home.x / Config.TILE_BLOCKS), int(home.z / Config.TILE_BLOCKS))
	var near := Vector2i(clampi(ht.x + 6, 0, map.size - 1), ht.y)
	game.hud.notify("Test: Problem in der Nähe", near)
	var states := [mayor._state]
	var bubble: bool = mayor.text != ""
	for f in 600:
		await game.get_tree().process_frame
		if states[states.size() - 1] != mayor._state:
			states.append(mayor._state)
		if mayor._state == "home" and states.size() > 1:
			break
	print("mayortest nah: Zustände %s, Sprechblase %s, zurück %s" % [states, bubble, mayor.position.distance_to(home) < 0.6])
	var far := Vector2i(clampi(ht.x + Mayor.WALK_MAX + 10, 0, map.size - 1), clampi(ht.y + Mayor.WALK_MAX, 0, map.size - 1))
	game.hud.notify("Test: Problem weit weg", far)
	print("mayortest fern: Zustand %s (erwartet home), Text '%s'" % [mayor._state, mayor.text])


## Arbeiter: nach dem Aufbau-Start laufen Figuren Lager -> Baustelle bzw. Werk -> Lager über die Straßen.
## cam = Kamera auf einen laufenden Arbeiter (Screenshot).
static func workertest(game: Node, cam: bool) -> void:
	var workers: Workers = game.get_node("Workers")
	var seen := {}
	var states := {}
	var t0 := Time.get_ticks_usec()
	var focus := false
	for f in 900:
		await game.get_tree().process_frame
		for w in workers._pool:
			if w["state"] != "free":
				seen[w["node"]] = true
				states[w["kind"] + ":" + w["state"]] = int(states.get(w["kind"] + ":" + w["state"], 0)) + 1
				if cam and not focus and w["state"] == "go" and (w["kind"] == "build" or f > 300):
					var p: Vector3 = (w["node"] as Node3D).position
					game.cam.position = p
					game.cam._dist = 20.0
					game.cam._target_dist = 20.0
					focus = true
		if cam and focus:
			break
	print("workertest Figuren unterwegs %d (gerade aktiv %d), Zustände %s, %.1f s" % [seen.size(), workers.active_count(),
		states, (Time.get_ticks_usec() - t0) / 1e6])


## Gold als Forschungswährung (--goldtest=Jahre, mit --loadfile=<Kopie einer Stadt mit Institut>): Stadt bleibt unverändert,
## Projekte starten der Reihe nach; fehlt Gold, wird gewartet, bis der Zukauf höchstens ein Viertel der Kasse kostet.
## Misst Förderung, Wartezeit, Zukauf, Tempo. --goldmine setzt zusätzlich eine Goldmine (Stufe 1) ans nächste Vorkommen.
static func goldtest(game: Node, years: int) -> void:
	var map: CityMap = game.map
	var sim: Simulation = game.sim
	if DevTools.has("--goldmine"):
		var hp := HumanPlayer.new()
		hp.game = game
		hp.map = map
		hp.sim = sim
		hp.tools = game.tools
		hp.c = map.size / 2
		var p := hp._place_at(ToolController.Tool.MINE, hp._near_ore(Config.Ore.GOLD))
		print("goldtest Goldmine bei %s" % p)
	var t0 := Time.get_ticks_msec()
	sim.tick_month()
	var gm := 0
	var glv := 0
	for a in map.size * map.size:
		if map.anchor[a] == a and map.special[a] == Config.Special.MINE:
			var info: Dictionary = sim.producer_info.get(a, {})
			if float((info.get("out", {}) as Dictionary).get("gold", 0.0)) > 0.0:
				gm += 1
				glv += map.special_level(a)
	print("goldtest 1 Monat = %d ms, Institutsstufen %d, Akademiker-Faktor %.2f, Budget $%d, Punkte/Monat %.0f, Gold im Lager %d, Gold-Förderung %.0f/Monat aus %d Minen (Stufen %d), Gold-Verkauf %d/Monat" % [
		Time.get_ticks_msec() - t0, sim.institute_levels(), sim.academic_factor(), int(sim.research_budget), sim.research_points(),
		int(sim.stock.get("gold", 0.0)), float(sim.production.get("gold", 0.0)), gm, glv, int(float(sim.exported.get("gold", 0.0)))])
	if sim.research_budget <= 0.0:
		sim.research_budget = 2000.0
	var mined := 0.0
	var bought := 0.0
	var wait := 0
	var started := 0
	var order: Array = Config.RESEARCH.keys()
	for m in years * 12:
		sim.tick_month()
		mined += float(sim.production.get("gold", 0.0))
		if sim.research_current == "":
			for id: String in order:
				if sim.research_blocker(id) != "":
					continue
				var g := float(Config.RESEARCH[id]["gold"])
				var gshort := maxf(g - float(sim.stock.get("gold", 0.0)), 0.0)
				if gshort > 0.0 and gshort * float(Config.RESOURCES["gold"]["price"]) * Config.IMPORT_FACTOR > sim.money * 0.25:
					wait += 1
					break
				if sim.start_research(id) == "":
					bought += gshort
					started += 1
					print("goldtest %s: %s gestartet (Gold %d, zugekauft %d, Lager danach %d)" % [sim.date_string(),
						Config.RESEARCH[id]["name"], int(g), int(gshort), int(sim.stock.get("gold", 0.0))])
				break
	print("goldtest Ergebnis %d J.: erforscht %d/%d (gestartet %d), Gold gefördert %d (%.0f/J.), zugekauft %d, Wartezeit %d Monate, Punkte/Monat %.0f, Kasse $%d" % [
		years, sim.research_done.size(), Config.RESEARCH.size(), started, int(mined), mined / years, int(bought), wait,
		sim.research_points(), int(sim.money)])



## Zukauf nur mit Freigabe: fehlender Bedarf -> Nachfrage (Signal), "Diesmal" gilt einen Monat, "Immer" dauerhaft,
## "Nein" pausiert die Nachfrage 12 Monate.
static func tradetest(game: Node) -> void:
	var sim: Simulation = game.sim
	game._new_city()
	sim.hall_level = 2
	var asked := []
	sim.trade_request.connect(func(req: Dictionary) -> void: asked.append(req))
	print("tradetest ohne Freigabe: can_buy(Ziegel) %s" % sim.can_buy("bricks"))
	sim._want("bricks", 40.0, "Häuser")
	sim._ask_trade()
	print("tradetest Nachfrage: %s" % [asked])
	sim.answer_trade("bricks", "once")
	print("tradetest Diesmal: can_buy %s" % sim.can_buy("bricks"))
	sim._ask_trade()
	print("tradetest nach Monatsende: can_buy %s (erwartet false)" % sim.can_buy("bricks"))
	sim.answer_trade("coal", "always")
	sim._ask_trade()
	print("tradetest Immer Kohle: can_buy %s (erwartet true)" % sim.can_buy("coal"))
	asked.clear()
	sim.answer_trade("glass", "no")
	sim._want("glass", 5.0, "Häuser")
	sim._ask_trade()
	print("tradetest Nein Glas -> keine Nachfrage: %s" % asked.is_empty())



## Kassen-Warnung des Bürgermeisters: knappe Kasse (wenige Monate), Minus mit Zinsen, Entwarnung bei positivem Saldo.
static func moneytest(game: Node) -> void:
	var sim: Simulation = game.sim
	game._new_city()
	sim.hall_level = 2
	var msgs: Array[String] = []
	sim.message.connect(func(t: String) -> void: msgs.append(t))
	sim.money = 500.0
	sim.last_income = 100.0
	sim.last_expense = 300.0
	sim._warn_money()
	sim._warn_money()                 # zweimal: nur eine Warnung
	print("moneytest knapp: %d Meldung(en): %s" % [msgs.size(), msgs])
	msgs.clear()
	sim.money = -2000.0
	sim.interest_cost = 20.0
	sim._warn_money()
	print("moneytest Minus: %s" % [msgs])
	msgs.clear()
	sim.money = 3000.0
	sim.last_income = 400.0
	sim._warn_money()
	sim.last_income = 100.0
	sim._warn_money()
	print("moneytest nach Entwarnung erneut knapp: %d Meldung(en)" % msgs.size())
