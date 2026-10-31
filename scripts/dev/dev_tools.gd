class_name DevTools
extends RefCounted
## Dev-Flags (nach `--` an Godot übergeben). Ohne Flags passiert nichts.
##
##   --demo                 Teststadt bauen (DemoCity)
##   --cam=x,z,dist         Kamera auf Tile x,z mit Abstand dist
##   --overlay[=1..8]       Ansicht: 1 Verkehr, 2 Verschmutzung, 3 Bodenwert, 4 Kriminalität, 5 Zufriedenheit, 6 ÖPNV, 7 Strom, 8 Rohstoffe
##   --popup=view|happy     Ansicht-Liste bzw. Zufriedenheits-Karte aufklappen
##   --hover=x,z [--detail] Info-Karte für Tile zeigen (ausführlich)
##   --notify               Beispiel-Warnungen in die Meldungsleiste
##   --uiscale=f            HUD-Größe (0.7 / 0.85 / 1.0 / 1.15)
##   --appicon=pfad.png     App-Icon rendern
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
	# Tests/Demo bauen auf leerer Karte mit allem freigeschaltet (höchste Rathaus-Stufe); --buildstart startet echt
	game.sim.hall_level = Config.HALL_LEVELS.size() - 1
	# Tests/Demo-Aufbau rechnen Pendler synchron (deterministisch, Ergebnis sofort lesbar)
	game.sim.async_commute = false
	# Automatische Läufe (Tests/Screenshots) nehmen keinen Tastaturfokus: sonst landen Tastendrücke
	# des Nutzers (der gerade woanders tippt) im Spiel und wählen z.B. Werkzeuge
	automated = has("--quit") or value("--screenshot") != ""
	if automated:
		# Testläufe: feste Uhrzeit (Mittag), außer --time=0..1 (0 Mitternacht, 0.25 Morgen, 0.75 Abend)
		game.day_night.frozen = true
		DayNight.time = float(value("--time")) if value("--time") != "" else 0.42
	if automated:
		game.get_viewport().gui_disable_input = true    # auch keine Klicks des Nutzers auf Buttons (z.B. Menü)
	if has("--demo"):
		DemoCity.build(game)
	if value("--loadfile") != "":
		CityMigrate.disabled = has("--nomigrate")
		# --loadfile=/pfad/datei.citysave: Spielstand-Kopie laden (Slots bleiben unberührt)
		var err := SaveManager.load_file(value("--loadfile"), game.map, game.sim)
		print("loadfile %s: %s, Einw. %d, Rathaus Stufe %d, Gebäude außerhalb Lager %d" % [value("--loadfile"),
			error_string(err), game.sim.population, game.sim.hall_level, CityMigrate.uncovered(game.map, game.sim)])
		if not CityMigrate.last.is_empty():
			print("loadfile umgerechnet: %s" % CityMigrate.last)
		var dark := 0
		for i in game.map.size * game.map.size:
			if game.map.zone[i] != Config.Zone.NONE and game.map.level[i] > 0 and game.sim.powered[i] == 0:
				dark += 1
		var cap := 0.0
		var dem := 0.0
		for net: Dictionary in game.sim.power_nets:
			cap += float(net["capacity"])
			dem += float(net["demand"])
		print("loadfile Strom: Leistung %.0f, Bedarf %.0f, Gebäude ohne Strom %d" % [cap, dem, dark])
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
	if value("--uiscale") != "":
		# --uiscale=0.85: HUD-Größe nur für diesen Lauf
		GraphicsSettings.ui_scale = float(value("--uiscale"))
		game.hud._apply_ui_scale()
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
	if has("--orecount"):
		DevTests.orecount(game)
	if has("--resbuild"):
		DevTests.place_resources(game)
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
	if has("--askquit"):
		game.hud.ask_quit("2")        # Screenshot der Beenden-Abfrage
	if has("--lv4"):
		# Screenshot: Wohnen/Gewerbe Stufe 3 -> 4, Industrie -> Hightech (nur Optik)
		var mp: CityMap = game.map
		for i in mp.size * mp.size:
			if mp.level[i] == 3 and mp.zone[i] in [Config.Zone.RES, Config.Zone.COM] and mp.villa[i] == 0:
				mp.level[i] = 4
			elif mp.zone[i] == Config.Zone.IND and mp.level[i] > 0:
				mp.hightech[i] = 1
		mp.notify_changed(Rect2i(0, 0, mp.size, mp.size), false)
	if has("--construct"):
		# Screenshot: jedes 3. Gebäude als Baustelle (nur Optik)
		var mpc: CityMap = game.map
		var kc := 0
		for i in mpc.size * mpc.size:
			if mpc.level[i] > 0 and mpc.zone[i] != Config.Zone.NONE:
				kc += 1
				if kc % 3 == 0:
					mpc.construct[i] = 2
		mpc.notify_changed(Rect2i(0, 0, mpc.size, mpc.size), false)
	if has("--vacant"):
		# jedes 3. Gebäude als Leerstand markieren (Screenshot)
		var mp: CityMap = game.map
		var k := 0
		for i in mp.size * mp.size:
			if mp.level[i] > 0 and mp.zone[i] != Config.Zone.NONE:
				k += 1
				if k % 3 == 0:
					mp.empty[i] = 100
					mp.vacant[i] = 5
		mp.notify_changed(Rect2i(0, 0, mp.size, mp.size), false)
		game.sim.refresh()
	if has("--fronttest"):
		DevTests.fronttest(game)
	if has("--loadreport"):
		DevTests.loadreport(game)
	if has("--determinism"):
		DevTests.determinism(game)
	if has("--powerreport"):
		DevTests.powerreport(game)
	if has("--resreport"):
		DevTests.resreport(game)
	if has("--budgettest"):
		DevTests.budgettest(game)
	if has("--processtest"):
		DevTests.processtest()
	if has("--restest"):
		DevTests.restest()
	if has("--renewtest"):
		DevTests.renewtest()
	if value("--freshrun") != "":
		DevTests.freshrun(game, int(value("--freshrun")))
	if has("--econreport"):
		DevTests.econreport(game)
	if has("--researchtest"):
		await DevTests.researchtest(game)
	if has("--energybuild"):
		# Biomasse, Solarfeld, Batterie in die Demo setzen (Forschung freigeschaltet) – Screenshots
		game.sim.money += 30000
		for id: String in ["solar", "battery"]:
			if not game.sim.research_done.has(id):
				game.sim.research_done.append(id)
		for t: ToolController.Tool in [ToolController.Tool.BIOMASS, ToolController.Tool.SOLAR, ToolController.Tool.BATTERY]:
			DevTests._place_near_center(game.map, game.tools, t)
		game.tools.set_tool(ToolController.Tool.INSPECT)
		for k in 2:
			game.sim.tick_month()
		for i in game.map.size * game.map.size:
			if game.map.anchor[i] == i and game.map.special[i] in [Config.Special.BIOMASS, Config.Special.SOLAR, Config.Special.BATTERY]:
				print("energybuild %s bei %d,%d" % [Config.SPECIALS[game.map.special[i]]["name"], i % game.map.size, i / game.map.size])
	if value("--humanrun") != "":
		# --humanrun=Jahre[,seed]: Neustart wie ein Mensch gespielt (Balance-Messung)
		var hv := value("--humanrun").split(",")
		HumanPlayer.new().run(game, int(hv[0]), int(hv[1]) if hv.size() > 1 else 1)
	if has("--buildstart"):
		await DevTests.buildstarttest(game)
	if has("--mayortest"):
		await DevTests.mayortest(game)
	if has("--citytechtest"):
		await DevTests.citytechtest(game)
	if has("--energytest"):
		DevTests.energytest()
	if has("--energytestb"):
		DevTests.energytest_b(game)
	if has("--vacancytest"):
		DevTests.vacancytest()
	if has("--treereport"):
		DevTests.treereport(game)
	if has("--powertest"):
		DevTests.powertest()
	if has("--cartest"):
		DevTests.cartest(game)
	if has("--greentest"):
		DevTests.greentest(game)
	if has("--savetest"):
		DevTests.savetest(game)
	if has("--rangetest"):
		DevTests.rangetest(game)
	if has("--zoomtest"):
		DevTests.zoomtest(game)
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
		game.tools._update_preview()
		if game.hud._cost.text != "":
			print("hover Kostenblase: %s" % game.hud._cost.text.replace("\n", " | "))
			game.hud._cost_pill.set_meta("pin", true)
	if has("--popflash"):
		# Popover/Info-Karte dürfen weder beim Öffnen noch beim Monats-Neuaufbau kurz die Höhe springen lassen.
		# Je Frame Höhe protokollieren; "Zucken" = Höhe weicht ab und kehrt danach zurück.
		var jitter := func(h: Array[int]) -> int:
			var n := 0
			for k in range(1, h.size() - 1):
				if h[k] != h[k - 1] and h[k + 1] != h[k] and h[k + 1] == h[k - 1]:
					n += 1
			return n
		for kind: String in ["happy", "view", "research", "log"]:
			var heights: Array[int] = []
			game.hud._toggle_popup(kind)
			await RenderingServer.frame_pre_draw
			heights.append(int(game.hud._popup.size.y))
			for m in 3:
				for k in 3:
					await RenderingServer.frame_pre_draw
					heights.append(int(game.hud._popup.size.y))
				game.sim.tick_month()             # löst stats_changed -> Neuaufbau aus
				await RenderingServer.frame_pre_draw   # gemessen wird, was gezeichnet wird (nach dem Layout im Frame)
				heights.append(int(game.hud._popup.size.y))
			for k in 3:
				await RenderingServer.frame_pre_draw
				heights.append(int(game.hud._popup.size.y))
			print("popflash %s: Höhen je Frame %s -> Zucker %d" % [kind, heights, jitter.call(heights)])
			game.hud._close_popup()
		# Info-Karte über einem Wohnhaus, Details an
		var mp: CityMap = game.map
		var target := Vector2i(-1, -1)
		for i in mp.size * mp.size:
			if mp.zone[i] == Config.Zone.RES and mp.level[i] > 0:
				target = Vector2i(i % mp.size, i / mp.size)
				break
		game.hud._info_detail = true
		game.tools.hover = target
		game.hud._on_hover(target)
		var hs: Array[int] = []
		for m in 3:
			for k in 3:
				await RenderingServer.frame_pre_draw
				hs.append(int(game.hud._info_card.size.y))
			game.sim.tick_month()
			game.hud._on_hover(target)
			await RenderingServer.frame_pre_draw
			hs.append(int(game.hud._info_card.size.y))
		print("popflash info: Höhen je Frame %s -> Zucker %d" % [hs, jitter.call(hs)])

	if value("--techs") != "":
		# --techs=plant_filter,deep_mining: Projekte als erforscht setzen (Screenshots der Wirkung)
		for id: String in value("--techs").split(","):
			if Config.RESEARCH.has(id) and not game.sim.research_done.has(id):
				game.sim.research_done.append(id)
		StructureGenerator.techs = game.sim.research_done
		game.map.notify_changed(Rect2i(0, 0, game.map.size, game.map.size), false)
	if value("--breakthrough") != "":
		# --breakthrough=deep_mining: Durchbruch-Karte zeigen (Screenshot)
		await game.get_tree().process_frame
		game.hud._on_research_finished(value("--breakthrough"))
	if has("--notify"):
		# Beispiel-Warnungen für Screenshots der Meldungsleiste
		game.hud.notify("Stromengpass im Netz bei 30,30: Bedarf 48 MW > Leistung 30 MW", Vector2i(30, 30))
		game.hud.notify("Feuer! Wohnhaus bei 28,33 - keine Feuerwache in Reichweite", Vector2i(28, 33))
		game.hud.notify("Feuer! Wohnhaus bei 28,33 - keine Feuerwache in Reichweite", Vector2i(28, 33))
		game.hud.show_message("Ansicht: Strom")
	if has("--hidehud"):
		game.hud.toggle_hud()
	if has("--splash") or value("--splash") != "":
		# Startbild: HUD aus, 3D-Block-Logo + Effekte (mit --screenshot=pfad aufnehmen), --splash=grass|stone|brick
		game.hud.visible = false
		game.get_node("StatusMarkers").visible = false
		var art := SplashArt.new()
		game.add_child(art)
		art.setup(game.lib, value("--splash"), game.cam.camera)
	if value("--appicon") != "":
		# --appicon=pfad.png: App-Icon (1024 px) rendern
		await game.get_node("Icons").render_app_icon(value("--appicon"))
	if has("--menu"):
		game.hud.toggle_menu()
		if value("--asksave") != "":
			game.hud._ask_save(value("--asksave"))     # nur Abfrage zeigen, nichts speichern

	if has("--mayorcam"):
		# Kamera auf den Bürgermeister (Screenshot)
		game.get_node("Mayor")._find_home()
		game.get_node("Mayor").position = game.get_node("Mayor")._home
		var mp: Vector3 = game.get_node("Mayor").position
		var mt := Vector2i(int(mp.x / Config.TILE_BLOCKS), int(mp.z / Config.TILE_BLOCKS))
		print("mayorcam Bürgermeister bei Tile %s" % mt)
		game.cam.position = Vector3(mp.x, mp.y, mp.z)
		game.cam._dist = 34.0
		game.cam._target_dist = 34.0
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
