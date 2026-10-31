extends Node3D
## Einstiegspunkt: baut Welt, Simulation, Kamera, Werkzeuge und HUD zusammen.
## Dev-Flags, Demo-Stadt und Tests: scripts/dev/

var map: CityMap
var sim: Simulation
var lib: BlockLibrary
var renderer: WorldRenderer
var cam: CityCamera
var tools: ToolController
var fire_dept: FireDept
var hud: Hud
var environment: Environment
var sun: DirectionalLight3D
var day_night: DayNight
var current_slot := ""          # zuletzt geladener/gespeicherter Platz (für "Speichern und beenden")


func _ready() -> void:
	# Fenster schließen / Cmd+Q beendet nicht sofort, sondern fragt (Speichern / ohne Speichern / Abbrechen)
	get_tree().set_auto_accept_quit(false)
	_setup_environment()

	lib = BlockLibrary.new()
	lib.load_all()
	day_night = DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.setup(sun, environment, lib)     # vor ShaderWarmup: Fenster-Leuchten ist schon aktiv

	map = CityMap.new()
	if DevTools.has("--demo"):
		DemoCity.generate_map(map)
	else:
		map.generate(randi())

	_setup_water()

	renderer = WorldRenderer.new()
	renderer.name = "World"
	add_child(renderer)
	renderer.setup(map, lib)

	sim = Simulation.new()
	sim.name = "Simulation"
	add_child(sim)
	sim.setup(map)
	sim.async_commute = true     # Pendler im Hintergrund-Thread (DevTools schaltet für Tests ab)

	var world_size := float(map.size * Config.TILE_BLOCKS)
	cam = CityCamera.new()
	cam.name = "CameraRig"
	cam.bounds = Rect2(0, 0, world_size, world_size)
	cam.position = Vector3(world_size * 0.5, Config.WATER_LEVEL, world_size * 0.5)
	add_child(cam)

	tools = ToolController.new()
	tools.name = "Tools"
	add_child(tools)
	tools.setup(map, sim, cam.camera)
	tools.tool_changed.connect(func(t): cam.left_drag_pans = t == ToolController.Tool.INSPECT)

	var limiter := FrameLimiter.new()
	limiter.name = "FrameLimiter"
	add_child(limiter)
	limiter.setup(sim, cam)

	var markers := StatusMarkers.new()
	markers.name = "StatusMarkers"
	add_child(markers)
	markers.setup(map, sim, lib)

	fire_dept = FireDept.new()
	fire_dept.name = "FireDept"
	add_child(fire_dept)
	fire_dept.setup(map, sim)
	var fire_fx := FireFx.new()
	fire_fx.name = "FireFx"
	add_child(fire_fx)
	fire_fx.setup(map, fire_dept, lib)
	var smoke := ChimneySmoke.new()
	smoke.name = "ChimneySmoke"
	add_child(smoke)
	smoke.setup(map, sim, renderer)

	var traffic := Traffic.new()
	traffic.name = "Traffic"
	add_child(traffic)
	traffic.setup(map, sim, lib)

	var trains := Trains.new()
	trains.name = "Trains"
	add_child(trains)
	trains.setup(map, sim, lib)

	var icons := IconFactory.new()
	icons.name = "Icons"
	add_child(icons)
	icons.setup(lib)

	hud = Hud.new()
	add_child(hud)
	hud.setup(sim, tools, map, icons, fire_dept)
	var mayor := Mayor.new()
	mayor.name = "Mayor"
	add_child(mayor)
	mayor.setup(map, sim)
	hud.mayor = mayor
	hud.focus_requested.connect(func(t: Vector2i): cam.focus_tile(t, map.h(t.x, t.y)))
	sim.stats_changed.connect(func():
		renderer.sim_speed = sim.speed
		smoke.speed = sim.speed
		StructureGenerator.techs = sim.research_done)

	var overlay := MapOverlay.new()
	overlay.name = "MapOverlay"
	add_child(overlay)
	overlay.setup(map, sim)
	hud.overlay_selected.connect(func(m: int): hud.set_overlay_mode(m, overlay.set_mode(m)))
	hud.set_overlay_mode(0, "", true)
	# Dienst-Werkzeug in der Hand -> Versorgungsansicht dieses Dienstes
	tools.tool_changed.connect(func(t):
		var sp: int = tools._special_for_tool()
		var cat: String = Config.SPECIALS[sp].get("service", "") if sp != Config.Special.NONE else ""
		if t == ToolController.Tool.BUS_STOP or t == ToolController.Tool.STATION:
			cat = "transit"        # ÖPNV-Ansicht: Busnetz blau, Gebäude mit/ohne Anschluss
		overlay.set_service(cat))
	hud.save_requested.connect(_save)
	hud.quit_requested.connect(_quit)
	hud.load_requested.connect(_load)
	hud.new_city_requested.connect(_new_city)
	hud.graphics_changed.connect(apply_graphics)

	if not DevTools.has("--nowarmup"):
		var warmup := ShaderWarmup.new()
		warmup.name = "ShaderWarmup"
		add_child(warmup)
		warmup.run(lib, cam.camera)

	Audio.setup(map, sim, cam)
	tools.applied.connect(_on_tool_applied)
	tools.message.connect(func(_t): Audio.sfx("error", 0.02))
	sim.message.connect(func(_t): Audio.sfx("notify", 0.0))
	fire_dept.alert.connect(func(_t, _p): Audio.sfx("notify", 0.0))
	sim.alert.connect(func(_t, _p): Audio.sfx("notify", 0.0))

	if OS.get_cmdline_user_args().is_empty():
		_new_city()                     # Spielstart: Rathaus-Gründung (Laden geht über das Menü)
	DevTools.run(self)


func _on_tool_applied(t: ToolController.Tool) -> void:
	match t:
		ToolController.Tool.BULLDOZE: Audio.sfx("bulldoze")
		ToolController.Tool.RES, ToolController.Tool.COM, ToolController.Tool.IND: Audio.sfx("zone")
		_: Audio.sfx("place")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if DevTools.automated or hud == null:
			get_tree().quit()
		else:
			hud.ask_quit(current_slot)


func _quit(save_slot: String) -> void:
	if save_slot != "":
		_save(save_slot)
	get_tree().quit()


func _save(slot: String) -> void:
	current_slot = slot
	hud._current_slot_hint = slot
	var existed := not SaveManager.meta(slot).is_empty()
	var err := SaveManager.save(slot, map, sim)
	hud.show_message(("Gespeichert (%s)%s" % [Hud.slot_name(slot), " - alte Version gesichert" if existed else ""])
		if err == OK else "Speichern fehlgeschlagen: %s" % error_string(err))


func _load(slot: String) -> void:
	var err := SaveManager.load_slot(slot, map, sim)
	if err == OK:
		current_slot = slot.get_slice(".bak", 0)     # aus einer Sicherung geladen -> deren Platz
		hud._current_slot_hint = current_slot
	hud.show_message("Geladen (%s)" % Hud.slot_name(slot) if err == OK
		else ("Slot ist leer" if err == ERR_FILE_NOT_FOUND else "Laden fehlgeschlagen: %s" % error_string(err)))


func _new_city() -> void:
	map.generate(randi())
	sim.reset()
	current_slot = ""
	hud._current_slot_hint = ""
	var spot := CityStart.setup_build(map, sim)
	cam.focus_tile(spot + Vector2i(1, 1), map.h(spot.x, spot.y))
	hud.show_message("Neue Stadt: erst Holz und Stein sammeln - Holzfäller am Wald, Steinbruch am Fels")


func _setup_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.35, 0.6, 0.95)
	sky_mat.sky_horizon_color = Color(0.75, 0.85, 0.95)
	sky_mat.ground_horizon_color = Color(0.75, 0.85, 0.95)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ssao_enabled = true
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.25
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.85, 0.95)
	env.fog_density = 0.0008

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.1
	add_child(sun)
	environment = env
	GraphicsSettings.load_saved()
	apply_graphics()
	GraphicsSettings.apply_window()


func apply_graphics() -> void:
	GraphicsSettings.apply(get_viewport(), environment, sun)


func _setup_water() -> void:
	var size := float(map.size * Config.TILE_BLOCKS)
	var plane := PlaneMesh.new()
	plane.size = Vector2(size + 400.0, size + 400.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.5, 0.85, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.1
	mat.metallic = 0.2
	plane.material = mat
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = plane
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position = Vector3(size * 0.5, Config.WATER_LEVEL - 0.2, size * 0.5)
	add_child(water)
