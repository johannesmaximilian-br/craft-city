class_name CityStart
extends RefCounted
## Neue Stadt: Rathaus mit Lagerhof (3x3) auf freiem Land nahe der Kartenmitte, Lichtung ringsum,
## kurzes Straßenstück, Gründungskasse und etwas Holz/Stein im Lager. Rathaus-Stufe 1, Steuern/Handel erst ab Stufe 2.


static func setup_build(map: CityMap, sim: Simulation) -> Vector2i:
	sim.hall_level = 1
	sim.money = Config.BUILD_START_MONEY
	for r: String in Config.BUILD_START_STOCK:
		sim.stock[r] = float(Config.BUILD_START_STOCK[r])
	var spot := _find_spot(map)
	var a := map.idx(spot.x, spot.y)
	var top := 0
	for z in 3:
		for x in 3:
			top = maxi(top, map.h(spot.x + x, spot.y + z))
	# Lichtung (Radius 4) und Fundament einebnen
	for z in range(spot.y - 4, spot.y + 7):
		for x in range(spot.x - 4, spot.x + 7):
			if map.in_bounds(x, z) and map.feature[map.idx(x, z)] == Config.Feature.TREE:
				map.feature[map.idx(x, z)] = Config.Feature.NONE
	for z in 3:
		for x in 3:
			var i := map.idx(spot.x + x, spot.y + z)
			map.height[i] = top
			map.special[i] = Config.Special.CITYHALL
			map.anchor[i] = a
			map.feature[i] = Config.Feature.NONE
	map.slevel[a] = 1
	# Straßenstück vor dem Rathaus (Richtung Kartenmitte), nur auf Land
	var dir := 1 if spot.x + 1 < map.size / 2 else -1
	var sx := spot.x + 3 if dir > 0 else spot.x - 1
	for k in 6:
		var x := sx + k * dir
		var z := spot.y + 1
		if map.in_bounds(x, z) and not map.is_water(x, z):
			map.road[map.idx(x, z)] = 1
			map.feature[map.idx(x, z)] = Config.Feature.NONE
	map.notify_changed(Rect2i(0, 0, map.size, map.size))
	sim.refresh()
	return spot


## Erster Ursprung (Spirale ab Mitte) mit 3x3 Land, flach genug (max. 1 Block Höhenunterschied) und Rand ohne Wasser.
static func _find_spot(map: CityMap) -> Vector2i:
	var c := map.size / 2
	for r in range(0, 40):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var o := Vector2i(c + dx, c + dz)
				if _ok(map, o):
					return o
	return Vector2i(c, c)


static func _ok(map: CityMap, o: Vector2i) -> bool:
	var lo := 999
	var hi := -999
	for z in range(o.y - 1, o.y + 4):
		for x in range(o.x - 1, o.x + 10):
			if not map.in_bounds(x, z) or map.is_water(x, z):
				return false
	for z in 3:
		for x in 3:
			var h := map.h(o.x + x, o.y + z)
			lo = mini(lo, h)
			hi = maxi(hi, h)
	return hi - lo <= 1
