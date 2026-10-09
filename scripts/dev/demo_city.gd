class_name DemoCity
extends RefCounted
## Baut eine reproduzierbare Teststadt (Dev-Flag --demo): Straßenkreuz, alle Zonen,
## Strom, ÖPNV, eine 4-spurige Straße; danach 5 Jahre Simulation.


## Erster Seed, bei dem der Kartenmittelpunkt großflächig Land ist.
static func generate_map(map: CityMap) -> void:
	var c := map.size / 2
	for s in range(1, 500):
		map.generate(s)
		var land := true
		for z in range(c - 8, c + 9):
			for x in range(c - 8, c + 12):
				if map.is_water(x, z):
					land = false
		if land:
			return


static func build(game: Node) -> void:
	var map: CityMap = game.map
	var tools: ToolController = game.tools
	var c := map.size / 2
	var place := func(tool: ToolController.Tool, tiles: Array[Vector2i]) -> void:
		tools.set_tool(tool)
		tools._apply(tiles)
	var click := func(tool: ToolController.Tool, at: Vector2i) -> void:
		tools.set_tool(tool)
		tools.hover = at
		tools._apply(tools._affected_tiles())

	# Straßenkreuz
	var cross: Array[Vector2i] = []
	for k in range(-8, 9):
		cross.append(Vector2i(c + k, c))
		cross.append(Vector2i(c, c + k))
	place.call(ToolController.Tool.ROAD, cross)

	# Quadranten um die Kreuzung: [Werkzeug, x-Start, z-Start]
	for blk: Array in [
		[ToolController.Tool.RES, c + 1, c + 1], [ToolController.Tool.RES, c - 6, c - 3],
		[ToolController.Tool.COM, c - 6, c + 1], [ToolController.Tool.IND, c + 1, c - 3],
	]:
		var area: Array[Vector2i] = []
		for z in 3:
			for x in 6:
				area.append(Vector2i(blk[1] + x, blk[2] + z))
		place.call(blk[0], area)

	# Strom: Kraftwerk, Windrad, Leitungen über die Straßen (Zonen leiten selbst)
	click.call(ToolController.Tool.COAL, Vector2i(c + 9, c + 2))
	click.call(ToolController.Tool.WIND, Vector2i(c + 9, c - 3))
	var line: Array[Vector2i] = [Vector2i(c + 7, c + 2), Vector2i(c + 8, c + 2),
		Vector2i(c, c + 2), Vector2i(c + 3, c), Vector2i(c, c - 2)]
	place.call(ToolController.Tool.POWERLINE, line)

	# Zone ohne Stromanschluss -> Blitz-Marker
	var dark: Array[Vector2i] = [Vector2i(c - 2, c + 6), Vector2i(c - 1, c + 6), Vector2i(c - 2, c + 7), Vector2i(c - 1, c + 7)]
	place.call(ToolController.Tool.RES, dark)

	# ÖPNV: Haltestellen an der Kreuzung, Bahnlinie nördlich (kreuzt die Straße) mit 2 Bahnhöfen
	for p: Vector2i in [Vector2i(c + 3, c), Vector2i(c - 3, c), Vector2i(c, c + 3), Vector2i(c, c - 3)]:
		click.call(ToolController.Tool.BUS_STOP, p)
	var track: Array[Vector2i] = []
	for k in range(-8, 9):
		track.append(Vector2i(c + k, c - 5))
	place.call(ToolController.Tool.RAIL, track)
	for p: Vector2i in [Vector2i(c - 5, c - 5), Vector2i(c + 5, c - 5)]:
		click.call(ToolController.Tool.STATION, p)

	# Zwei parallele Straßen -> 4-spurige Hauptstraße; Ende rechts läuft einspurig weiter
	var wide: Array[Vector2i] = [Vector2i(c, c + 9), Vector2i(c, c + 10)]
	for k in range(-7, 8):
		wide.append(Vector2i(c + k, c + 10))
		wide.append(Vector2i(c + k, c + 11))
	for k in range(8, 12):
		wide.append(Vector2i(c + k, c + 10))
	place.call(ToolController.Tool.ROAD, wide)

	# Dienste nahe der Mitte (ab 300/600 Einwohnern erwartet)
	game.sim.money += 8000
	for t: ToolController.Tool in [ToolController.Tool.POLICE, ToolController.Tool.FIRE,
			ToolController.Tool.SCHOOL, ToolController.Tool.HOSPITAL]:
		DevTests._place_near_center(map, tools, t)

	tools.hover = Vector2i(-1, -1)
	tools.set_tool(ToolController.Tool.INSPECT)
	for m in 60:
		game.sim.tick_month()
	game.cam.position = Vector3(c * Config.TILE_BLOCKS, map.h(c, c), c * Config.TILE_BLOCKS)
