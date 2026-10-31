class_name BuildingGenerator
extends RefCounted
## Erzeugt Gebäude prozedural aus Blöcken im 3x3-Footprint eines Tiles.
## put.call(key: String, local: Vector3i) — local relativ zur Tile-Oberfläche.
## prop.call(key: String, local: Vector3, rot: float)


static func emit(zone: int, lv: int, seed_value: int, put: Callable, prop: Callable, villa := false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	match zone:
		Config.Zone.RES:
			if villa and lv == 3:
				_villa(rng, put, prop)
			else:
				_res(lv, rng, put, prop)
		Config.Zone.COM: _com(lv, rng, put)
		Config.Zone.IND: _ind(lv, rng, put)


static func _is_face_mid(x: int, z: int) -> bool:
	return (x == 1) != (z == 1)


static func _is_corner(x: int, z: int) -> bool:
	return x != 1 and z != 1


## Hülle eines 3x3-Quaders: Ecken = corner_key, Seitenmitten = face_key.
static func _shell(put: Callable, y0: int, floors: int, corner_key: String, face_key: String) -> void:
	for y in range(y0, y0 + floors):
		for z in 3:
			for x in 3:
				if x == 1 and z == 1:
					continue
				put.call(corner_key if _is_corner(x, z) else face_key, Vector3i(x, y, z))


static func _slab(put: Callable, y: int, key: String) -> void:
	for z in 3:
		for x in 3:
			put.call(key, Vector3i(x, y, z))


static func _res(lv: int, rng: RandomNumberGenerator, put: Callable, prop: Callable) -> void:
	match lv:
		1:
			# Häuschen 2x2: Holzbohlen, Stamm-Ecken, Ziegeldach + Garten
			var ox := rng.randi_range(0, 1)
			var oz := rng.randi_range(0, 1)
			for z in 2:
				for x in 2:
					put.call("log" if (x + z) % 2 == 0 else "wood", Vector3i(ox + x, 0, oz + z))
					put.call("brick", Vector3i(ox + x, 1, oz + z))
			var gx := 2 if ox == 0 else 0
			var gz := 2 if oz == 0 else 0
			prop.call("bush" if rng.randf() < 0.5 else "flowers1", Vector3(gx + 0.5, 0, gz + 0.5), rng.randf() * TAU)
		2:
			# Einfamilienhaus 3x3: Stamm-Ecken, Holz oder gelber Ziegel, Fenster, Spitzdach
			var wall := "wood" if rng.randf() < 0.5 else "yellowbrick"
			_shell(put, 0, 1, "log", wall)
			_shell(put, 1, 1, "log", "ice")
			_slab(put, 2, "brick")
			put.call("brick", Vector3i(1, 3, 1))
		3:
			# Wohnblock: Sockel aus grauem Ziegel, Etagen rot mit Fensterbändern, Dachgarten oder Technik
			var floors := rng.randi_range(4, 6)
			var wall := "brick" if rng.randf() < 0.6 else "yellowbrick"
			_shell(put, 0, 1, "greybrick", "square")
			for y in range(1, floors):
				_shell(put, y, 1, wall, "ice" if y % 2 == 1 else wall)
			_slab(put, floors, "square")
			if rng.randf() < 0.5:
				put.call("leaves", Vector3i(rng.randi_range(0, 2), floors + 1, rng.randi_range(0, 2)))
			else:
				put.call("crate", Vector3i(rng.randi_range(0, 2), floors + 1, rng.randi_range(0, 2)))


## Villa: flacher Bungalow mit Flachdach-Terrasse, Pool, Hecke und Garten.
static func _villa(rng: RandomNumberGenerator, put: Callable, prop: Callable) -> void:
	var wall := "square" if rng.randf() < 0.5 else "stone"
	for z in 2:
		for x in 3:
			put.call(wall if z == 1 or x != 1 else "ice", Vector3i(x, 0, z))
			put.call("ice" if (x + z) % 2 == 0 else wall, Vector3i(x, 1, z))
	for x in 3:
		put.call("wood", Vector3i(x, 2, 0))
	put.call("wood", Vector3i(2, 2, 1))
	put.call("leaves", Vector3i(0, 2, 1))                                                  # Dachgarten
	put.call("vox_blue", Vector3i(1, 0, 2))                                                # Pool
	put.call("vox_blue", Vector3i(2, 0, 2))
	prop.call("bush", Vector3(0.5, 0, 2.5), rng.randf() * TAU)
	prop.call("flowers2", Vector3(0.4, 0, 1.6), 0.0)


static func _com(lv: int, rng: RandomNumberGenerator, put: Callable) -> void:
	match lv:
		1:
			# Laden: Schaufenster, Steinrahmen, Schild
			_shell(put, 0, 1, "greybrick", "ice")
			_slab(put, 1, "square")
			put.call("cheese", Vector3i(1, 2, rng.randi_range(0, 2)))
		2:
			# Bürohaus: helle Rahmen, Glasfassade
			var floors := rng.randi_range(3, 5)
			_shell(put, 0, floors, "square", "ice")
			_slab(put, floors, "stone")
		3:
			# Turm: dunkle Ziegelkanten, Glas, Antenne
			var floors := rng.randi_range(8, 12)
			_shell(put, 0, floors, "darkbrick", "ice")
			_slab(put, floors, "darkbrick")
			put.call("metal", Vector3i(1, floors + 1, 1))
			put.call("metal", Vector3i(1, floors + 2, 1))


## Schlot-Position eines Industriegebäudes (gleicher Zufall wie _ind): [Vector2i(cx, cz), Spitze y] – für ChimneySmoke.
static func ind_stack(seed_value: int, lv: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cx := 0 if rng.randf() < 0.5 else 2
	var cz := 0 if rng.randf() < 0.5 else 2
	return [Vector2i(cx, cz), 6 if lv == 2 else 8]


static func _ind(lv: int, rng: RandomNumberGenerator, put: Callable) -> void:
	var cx := 0 if rng.randf() < 0.5 else 2
	var cz := 0 if rng.randf() < 0.5 else 2
	match lv:
		1:
			# Werkstatt: Steinboden, Ziegelschlot, Kisten
			for z in 3:
				for x in 3:
					if x == cx and z == cz:
						continue
					put.call("stone", Vector3i(x, 0, z))
			for y in 3:
				put.call("brick", Vector3i(cx, y, cz))
			put.call("crate", Vector3i(2 - cx, 1, 2 - cz))
		2:
			# Fabrikhalle: dunkle Ziegel, Metalldach, hoher Schlot
			_shell(put, 0, 2, "darkbrick", "stone")
			_slab(put, 2, "metal")
			for y in range(3, 6):
				put.call("brick" if y < 5 else "darkbrick", Vector3i(cx, y, cz))
		3:
			# Großindustrie: zwei Schlote, Kohle auf dem Dach
			_shell(put, 0, 3, "darkbrick", "greybrick")
			_slab(put, 3, "stone")
			put.call("coal", Vector3i(1, 4, 1))
			for y in range(4, 8):
				var key := "brick" if y < 7 else "darkbrick"
				put.call(key, Vector3i(cx, y, cz))
				put.call(key, Vector3i(2 - cx, y, 2 - cz))
