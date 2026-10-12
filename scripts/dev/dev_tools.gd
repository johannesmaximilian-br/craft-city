class_name DevTools
extends RefCounted
## Dev-Flags (nach `--` an Godot übergeben). Ohne Flags passiert nichts.
##
##   --demo                 Teststadt bauen (DemoCity)
##   --cam=x,z,dist         Kamera auf Tile x,z mit Abstand dist
##   --overlay[=1..7]       Ansicht: 1 Verkehr, 2 Verschmutzung, 3 Bodenwert, 4 Kriminalität, 5 Zufriedenheit, 6 ÖPNV, 7 Strom
##   --popup=view|happy     Ansicht-Liste bzw. Zufriedenheits-Karte aufklappen
##   --hover=x,z [--detail] Info-Karte für Tile zeigen (ausführlich)
##   --notify               Beispiel-Warnungen in die Meldungsleiste
##   --menu / --flyout      Menü bzw. Strom-Werkzeuggruppe öffnen
##   --selftest --dragtest --lanetest --traffictest --pickcheck --firetest --bustest --happytest --cheattest --greentest --venuetest --zonetest --taxtest --cartest
##   --venues               Theater + Stadion in die Demo-Stadt setzen (Screenshots)
##   --loadfile=pfad        Spielstand-Datei laden (z.B. Kopie eines Nutzer-Spielstands)
##   --bigcity              ganze Karte bebauen (Performance)
##   --buildtest            Bau-Klick-Zeit messen
##   --villas               kleine Villensiedlung setzen (Screenshot)   Tests (DevTests)
##   --focus=x,z            Kamera auf Tile x,z fahren
##   --ignite=x,z[,sek]     Gebäude nahe x,z anzünden, Brand sek vorspulen
##   --ruin=x,z             Gebäude nahe x,z sofort abbrennen (Brandruine)
##   --screenshot=pfad      nach 90 Frames Bild speichern und beenden
##   --quit                 nach den Tests beenden (ohne Screenshot)


## Automatischer Lauf (Test/Screenshot): Tastatur wird ignoriert. Das Testfenster schiebt sich unter macOS in den
## Vordergrund, und Tastendrücke des Nutzers (der woanders tippt) würden sonst Werkzeuge wählen / die Kamera bewegen.
static var automated := false


static func has(flag: String) -> bool:
	return flag in OS.get_cmdline_user_args()


static func value(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix + "="):
			return arg.get_slice("=", 1)
	return ""


static func run(game: Node) -> void:
	if OS.get_cmdline_user_args().is_empty():
		return
	# Tests/Demo-Aufbau rechnen Pendler synchron (deterministisch, Ergebnis sofort lesbar)
	game.sim.async_commute = false
	# Automatische Läufe (Tests/Screenshots) nehmen keinen Tastaturfokus: sonst landen Tastendrücke
	# des Nutzers (der gerade woanders tippt) im Spiel und wählen z.B. Werkzeuge
	automated = has("--quit") or value("--screenshot") != ""
	if has("--demo"):
		DemoCity.build(game)
	if value("--loadfile") != "":
		# --loadfile=/pfad/datei.citysave: Spielstand-Kopie laden (Slots bleiben unberührt)
		var err := SaveManager.load_file(value("--loadfile"), game.map, game.sim)
		print("loadfile %s: %s, Einw. %d" % [value("--loadfile"), error_string(err), game.sim.population])
	if has("--bigcity"):
		DevTests.bigcity(game)
	var cam_arg := value("--cam")
	if cam_arg != "":
		var v := cam_arg.split_floats(",")
		var cam: CityCamera = game.cam
		cam.position = Vector3(v[0] * Config.TILE_BLOCKS, Config.WATER_LEVEL, v[1] * Config.TILE_BLOCKS)
		cam._dist = v[2]
		cam._target_dist = v[2]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--overlay"):
			for k in (int(arg.get_slice("=", 1)) if "=" in arg else 1):
				game.hud._toggle_overlay()

	var ruin := value("--ruin")
	if ruin != "":
		# --ruin=x,z: Gebäude nahe x,z sofort abbrennen lassen (Brandruine ansehen)
		var v := ruin.split_floats(",")
		var dept: FireDept = game.fire_dept
		var i := _nearest_building(game.map, Vector2(v[0], v[1]))
		game.map.burning[i] = 1
		game.map.notify_changed(Rect2i(i % game.map.size, i / game.map.size, 1, 1), false)
		dept._burn_down(dept.fires[i])
		game.hud.focus_requested.emit(Vector2i(i % game.map.size, i / game.map.size))
	var ignite := value("--ignite")
	if ignite != "":
		# --ignite=x,z[,sek]: Gebäude anzünden (Tile x,z oder nächstes Gebäude daneben), Brand sek vorspulen
		var v := ignite.split_floats(",")
		var map: CityMap = game.map
		var best := _nearest_building(map, Vector2(v[0], v[1]))
		map.burning[best] = 1
		map.notify_changed(Rect2i(best % map.size, best / map.size, 1, 1), false)
		if v.size() > 2:
			for k in int(v[2] * 10.0):
				game.fire_dept.advance(0.1)
		game.hud.focus_requested.emit(Vector2i(best % map.size, best / map.size))
	if value("--focus") != "":
		# --focus=x,z: Kamera auf Tile (Geländehöhe, Bildmitte)
		var fv := value("--focus").split_floats(",")
		game.hud.focus_requested.emit(Vector2i(int(fv[0]), int(fv[1])))
	if value("--gfx") != "":
		# Grafikstufe nur für diesen Lauf (0 Niedrig, 1 Mittel, 2 Hoch), nicht gespeichert
		GraphicsSettings.current = int(value("--gfx")) as GraphicsSettings.Preset
		game.apply_graphics()
	if has("--traffictest"):
		DevTests.traffictest()
	if has("--servicetest"):
		DevTests.servicetest(game)
	if has("--zonetest"):
		DevTests.zonetest()
	if has("--taxtest"):
		DevTests.taxtest(game)
	if has("--venuetest"):
		DevTests.venuetest(game)
	if has("--buildtest"):
		await DevTests.buildtest(game)
	if has("--villas"):
		DevTests.place_villas(game)
	if has("--venues"):
		DevTests.place_venues(game)
	if has("--jamreport"):
		DevTests.jamreport(game)
	if has("--decaytest"):
		DevTests.decaytest()
	if has("--worn"):
		DevTests.mark_worn(game)
	if has("--fronttest"):
		DevTests.fronttest(game)
	if has("--loadreport"):
		DevTests.loadreport(game)
	if has("--powertest"):
		DevTests.powertest()
	if has("--cartest"):
		DevTests.cartest(game)
	if has("--greentest"):
		DevTests.greentest(game)
	if has("--mutetest"):
		DevTests.mutetest(game)
	if has("--cheattest"):
		DevTests.cheattest(game)
	if has("--happytest"):
		DevTests.happytest(game)
	if has("--bustest"):
		DevTests.bustest(game)
	if has("--firetest"):
		DevTests.firetest(game)
	if has("--widetest"):
		DevTests.widetest()
	if has("--selftest"):
		DevTests.selftest(game)
	if has("--dragtest"):
		await DevTests.dragtest(game)
	if has("--lanetest"):
		await DevTests.lanetest(game)
	if has("--pickcheck"):
		await DevTests.pickcheck(game)
	# Ab hier wie im echten Spiel: Pendler im Hintergrund
	game.sim.async_commute = true
	if value("--cardrift") != "":
		await DevTests.cardrift(game, float(value("--cardrift")))
	if has("--fpstest"):
		await DevTests.fpstest(game)
	if value("--gpumeasure") != "":
		# --gpumeasure=Sek[,maxfps]
		var gm := value("--gpumeasure").split_floats(",")
		if gm.size() > 1:
			GraphicsSettings.fps_limit = int(gm[1])     # nur für diesen Lauf, nicht gespeichert
		if has("--pause"):
			game.hud._set_speed(0)
		await DevTests.gpumeasure(game, gm[0])
	if has("--profile") or value("--profile") != "":
		# --profile oder --profile=Sekunden,Tempo
		var p := value("--profile").split_floats(",") if value("--profile") != "" else PackedFloat64Array()
		if p.size() > 1:
			game.hud._set_speed(int(p[1]))
		await DevTests.profile(game, p[0] if p.size() > 0 else 15.0)

	if value("--tool") != "":
		# --tool=<icon-name>, z.B. police: Werkzeug wählen und seine Gruppe aufklappen
		await game.get_tree().process_frame
		for t in ToolController.TOOLS:
			if ToolController.TOOLS[t]["icon"] == value("--tool"):
				game.hud._on_group_pressed(game.hud._tool_group[t])
				game.hud._select_tool(t)
	if has("--flyout"):
		await game.get_tree().process_frame
		game.hud._on_group_pressed(4)
	if value("--popup") != "":
		await game.get_tree().process_frame
		game.hud._toggle_popup(value("--popup"))
	if value("--hover") != "":
		# --hover=x,z: Info-Karte für Tile x,z zeigen (Screenshot); --detail = ausführlich
		await game.get_tree().process_frame
		var hv := value("--hover").split_floats(",")
		if has("--detail"):
			game.hud._info_detail = true
		game.tools.hover = Vector2i(int(hv[0]), int(hv[1]))
		game.hud._on_hover(game.tools.hover)
	if has("--notify"):
		# Beispiel-Warnungen für Screenshots der Meldungsleiste
		game.hud.notify("Stromengpass im Netz bei 30,30: Bedarf 48 MW > Leistung 30 MW", Vector2i(30, 30))
		game.hud.notify("Feuer! Wohnhaus bei 28,33 - keine Feuerwache in Reichweite", Vector2i(28, 33))
		game.hud.notify("Feuer! Wohnhaus bei 28,33 - keine Feuerwache in Reichweite", Vector2i(28, 33))
		game.hud.show_message("Ansicht: Strom")
	if has("--hidehud"):
		game.hud.toggle_hud()
	if has("--menu"):
		game.hud.toggle_menu()

	var shot := value("--screenshot")
	if shot != "":
		for i in 90:
			await game.get_tree().process_frame
		game.get_viewport().get_texture().get_image().save_png(shot)
		game.get_tree().quit()
	elif has("--quit") or has("--pickcheck"):
		game.get_tree().quit()


static func _nearest_building(map: CityMap, p: Vector2) -> int:
	var best := -1
	for i in map.size * map.size:
		if map.level[i] > 0 and map.zone[i] != Config.Zone.NONE and map.burning[i] == 0 and (best < 0 or
				Vector2(i % map.size, i / map.size).distance_to(p) < Vector2(best % map.size, best / map.size).distance_to(p)):
			best = i
	return best
