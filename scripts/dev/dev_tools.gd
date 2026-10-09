class_name DevTools
extends RefCounted
## Dev-Flags (nach `--` an Godot übergeben). Ohne Flags passiert nichts.
##
##   --demo                 Teststadt bauen (DemoCity)
##   --cam=x,z,dist         Kamera auf Tile x,z mit Abstand dist
##   --overlay[=1..3]       Ansicht: 1 Verkehr, 2 Verschmutzung, 3 Bodenwert
##   --menu / --flyout      Menü bzw. Strom-Werkzeuggruppe öffnen
##   --selftest --dragtest --lanetest --traffictest --pickcheck   Tests (DevTests)
##   --screenshot=pfad      nach 90 Frames Bild speichern und beenden
##   --quit                 nach den Tests beenden (ohne Screenshot)


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
	if has("--demo"):
		DemoCity.build(game)
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
				game.hud.overlay_toggled.emit()

	if value("--gfx") != "":
		# Grafikstufe nur für diesen Lauf (0 Niedrig, 1 Mittel, 2 Hoch), nicht gespeichert
		GraphicsSettings.current = int(value("--gfx")) as GraphicsSettings.Preset
		game.apply_graphics()
	if has("--traffictest"):
		DevTests.traffictest()
	if has("--servicetest"):
		DevTests.servicetest(game)
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
