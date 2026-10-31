class_name Workers
extends Node3D
## Arbeiter-Figuren (rein visuell, Schritt 4 des Aufbau-Starts): laufen über die Straßen vom nächsten Lager (Rathaus-Hof
## oder Lagerhaus) zu Baustellen (Kiste tragen, hämmern, zurück) und von Abbau-Betrieben/Werken mit Förderung zum Lager
## (Rohstoff-Block tragen). Die Simulation wird nicht beeinflusst; Aufträge werden jede Sekunde neu verteilt.

const MODELS := ["Character_Male_1", "Character_Female_1", "Character_Female_2"]
const MAX_WORKERS := 18
const SCALE := 0.75                  # kleiner als der Bürgermeister (1.0)
const SPEED := 3.5                   # Blöcke je Sekunde (bei Tempo 1)
const MAX_PATH := 70                 # weitere Wege lässt man aus (Tiles)
const WORK_TIME := 4.0               # Sekunden hämmern an der Baustelle
const DROP_TIME := 1.2               # Sekunden am Lager abladen
const SIDE := 1.15                   # Abstand von der Straßenmitte (Gehweg rechts)
const SIM_SPEED_FACTOR := [0.0, 1.0, 1.4, 1.8]
## Rohstoff -> Block, den der Arbeiter trägt (wie IconFactory res_*)
const CARRY_KEY := {"wood": "log", "stone": "stone", "sand": "sand", "clay": "clay", "coal": "coal",
	"iron": "iron_block", "gold": "gold_block", "planks": "wood", "bricks": "brick", "glass": "ice",
	"steel": "metal", "concrete": "square"}

var map: CityMap
var sim: Simulation
var lib: BlockLibrary
var _pool: Array[Dictionary] = []    # je Figur: node, model, anim, carry, state, path, pi, wait, job, from, to, key
var _assign_t := 0.0
var _stores := PackedInt32Array()


func setup(city_map: CityMap, simulation: Simulation, library: BlockLibrary) -> void:
	map = city_map
	sim = simulation
	lib = library
	for k in MAX_WORKERS:
		var root := Node3D.new()
		root.visible = false
		add_child(root)
		var model := (load("res://assets/characters/%s.gltf" % MODELS[k % MODELS.size()]) as PackedScene).instantiate() as Node3D
		Mayor.nearest_filter(model)
		model.scale = Vector3.ONE * SCALE
		root.add_child(model)
		var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim != null:
			for a in anim.get_animation_list():
				var low := a.to_lower()
				if low.ends_with("walk") or low.ends_with("walk_hold") or low.ends_with("idle") or low.ends_with("punch"):
					anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		var carry := MeshInstance3D.new()
		carry.visible = false
		model.add_child(carry)
		_pool.append({"node": root, "model": model, "anim": anim, "carry": carry, "state": "free", "path": [],
			"pi": 0, "wait": 0.0, "job": -1, "kind": "", "key": ""})


## Anzahl laufender Arbeiter (Tests).
func active_count() -> int:
	var n := 0
	for w in _pool:
		if w["state"] != "free":
			n += 1
	return n


func _process(dt: float) -> void:
	if map == null:
		return
	var f: float = SIM_SPEED_FACTOR[clampi(sim.speed, 0, 3)]
	_assign_t -= dt
	if _assign_t <= 0.0:
		_assign_t = 1.0
		_assign()
	for w in _pool:
		if w["state"] != "free":
			_step(w, dt * f, f)


# ---------------------------------------------------------------- Aufträge

## Offene Aufträge sammeln (Baustellen vor Werken) und freie Figuren losschicken; höchstens 2 Wegsuchen je Aufruf.
func _assign() -> void:
	_stores = PackedInt32Array()
	var sites: Array[int] = []
	var works: Array[int] = []
	var n := map.size * map.size
	for i in n:
		if map.construct[i] > 0 and (map.special[i] == Config.Special.NONE or map.anchor[i] == i):
			sites.append(i)
		if map.special[i] == Config.Special.NONE or map.anchor[i] != i or map.construct[i] > 0:
			continue
		var def: Dictionary = Config.SPECIALS[map.special[i]]
		if def.has("storage"):
			_stores.append(i)
		elif (def.has("produce") or def.has("process")) and sim.special_powered(i):
			works.append(i)
	if _stores.is_empty():
		return
	var busy := {}
	for w in _pool:
		if w["state"] != "free":
			busy[w["job"]] = int(busy.get(w["job"], 0)) + 1
	var searches := 0
	for job in sites + works:
		if searches >= 2:
			break
		var want := 1
		if map.special[job] != Config.Special.NONE and int(Config.SPECIALS[map.special[job]]["size"]) >= 2 and map.construct[job] > 0:
			want = 2
		if int(busy.get(job, 0)) >= want:
			continue
		var key := _carry_for(job)
		if key == "":
			continue                     # Werk ohne Förderung in diesem Monat
		var w := _free_worker()
		if w.is_empty():
			return
		searches += 1
		var store := _nearest_store(job)
		var path := _road_path(store, job)
		busy[job] = int(busy.get(job, 0)) + 1     # auch ohne Weg: nicht gleich erneut suchen
		if path.size() < 2:
			continue
		w["job"] = job
		w["kind"] = "build" if map.construct[job] > 0 else "haul"
		w["key"] = key
		if w["kind"] == "build":
			_start(w, path, true)        # Lager -> Baustelle mit Kiste
		else:
			path.reverse()
			_start(w, path, true)        # Werk -> Lager mit Rohstoff


## Was trägt der Arbeiter? Baustelle: Kiste, Werk: erstes gefördertes/erzeugtes Gut, "" = nichts zu tun.
func _carry_for(job: int) -> String:
	if map.construct[job] > 0:
		return "crate"
	var def: Dictionary = Config.SPECIALS[map.special[job]]
	if def.has("process"):
		for r: String in (def["process"]["out"] as Dictionary):
			return str(CARRY_KEY.get(r, "crate"))
	var info: Dictionary = sim.producer_info.get(job, {})
	for r: String in (info.get("out", {}) as Dictionary):
		return str(CARRY_KEY.get(r, "crate"))
	return ""


func _free_worker() -> Dictionary:
	for w in _pool:
		if w["state"] == "free":
			return w
	return {}


func _nearest_store(job: int) -> int:
	var best := _stores[0]
	var bd := INF
	var p := Vector2(job % map.size, job / map.size)
	for s in _stores:
		var d := p.distance_squared_to(Vector2(s % map.size, s / map.size))
		if d < bd:
			bd = d
			best = s
	return best


# ---------------------------------------------------------------- Wege

## Straßen-Tiles neben der Grundfläche (Sonderbau) bzw. im Umkreis 3 (Zonen-Baustelle, wie die Straßen-Regel).
func _access(i: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var ax := i % map.size
	var az := i / map.size
	var s := 1
	var r := 3
	if map.special[i] != Config.Special.NONE:
		s = int(Config.SPECIALS[map.special[i]]["size"])
		r = 1
	for k in r:
		for z in range(az - 1 - k, az + s + 1 + k):
			for x in range(ax - 1 - k, ax + s + 1 + k):
				if map.in_bounds(x, z) and map.road[map.idx(x, z)] != 0:
					out.append(map.idx(x, z))
		if not out.is_empty():
			return out
	return out


## Weg (Weltpunkte) über Straßen vom Lager a zum Ziel b; [] = kein Anschluss oder zu weit.
func _road_path(a: int, b: int) -> Array[Vector3]:
	var starts := _access(a)
	var goals := _access(b)
	var res: Array[Vector3] = []
	if starts.is_empty() or goals.is_empty():
		return res
	var goal := {}
	for g in goals:
		goal[g] = true
	var prev := {}
	var dist := {}
	var queue := PackedInt32Array()
	for s in starts:
		prev[s] = -1
		dist[s] = 0
		queue.append(s)
	var head := 0
	var hit := -1
	var size := map.size
	while head < queue.size():
		var c := queue[head]
		head += 1
		if goal.has(c):
			hit = c
			break
		if int(dist[c]) >= MAX_PATH:
			continue
		var cx := c % size
		var cz := c / size
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := cx + d.x
			var nz := cz + d.y
			if nx < 0 or nz < 0 or nx >= size or nz >= size:
				continue
			var ni := nz * size + nx
			if map.road[ni] == 0 or prev.has(ni):
				continue
			prev[ni] = c
			dist[ni] = int(dist[c]) + 1
			queue.append(ni)
	if hit < 0:
		return res
	var tiles := PackedInt32Array()
	var c := hit
	while c != -1:
		tiles.append(c)
		c = prev[c]
	tiles.reverse()
	# Gebäude -> erstes Straßen-Tile, entlang der Straße auf dem rechten Gehweg, -> Ziel
	res.append(_front(a, tiles[0]))
	for k in tiles.size():
		var cur := tiles[k]
		var nxt := tiles[mini(k + 1, tiles.size() - 1)]
		var prv := tiles[maxi(k - 1, 0)]
		var dir := Vector2(nxt % size - prv % size, nxt / size - prv / size)
		var p := _center(cur)
		if dir != Vector2.ZERO:
			dir = dir.normalized()
			p += Vector3(-dir.y, 0, dir.x) * SIDE
		res.append(p)
	res.append(_front(b, tiles[tiles.size() - 1]))
	return res


func _center(i: int) -> Vector3:
	var b := float(Config.TILE_BLOCKS)
	return Vector3((i % map.size + 0.5) * b, float(map.h(i % map.size, i / map.size)), (i / map.size + 0.5) * b)


## Punkt vor dem Gebäude i auf der Seite zur Straße r (knapp vor der Wand).
func _front(i: int, r: int) -> Vector3:
	var b := float(Config.TILE_BLOCKS)
	var s := 1
	if map.special[i] != Config.Special.NONE:
		s = int(Config.SPECIALS[map.special[i]]["size"])
	var c := Vector3((i % map.size + s * 0.5) * b, 0.0, (i / map.size + s * 0.5) * b)
	var rc := _center(r)
	var d := Vector3(rc.x - c.x, 0, rc.z - c.z)
	var p := c + d.normalized() * minf(s * 0.5 * b + 0.6, d.length())
	var tx := clampi(int(p.x / b), 0, map.size - 1)
	var tz := clampi(int(p.z / b), 0, map.size - 1)
	p.y = float(map.h(tx, tz))
	return p


# ---------------------------------------------------------------- Bewegung

func _start(w: Dictionary, path: Array[Vector3], loaded: bool) -> void:
	w["path"] = path
	w["pi"] = 1
	w["state"] = "go"
	var node: Node3D = w["node"]
	node.position = path[0]
	node.visible = true
	_set_carry(w, loaded)
	_play(w, "walk_hold" if loaded else "walk")


func _set_carry(w: Dictionary, on: bool) -> void:
	var carry: MeshInstance3D = w["carry"]
	carry.visible = on
	if not on:
		return
	var key: String = w["key"]
	carry.mesh = lib.meshes[key]
	carry.material_override = lib.materials.get(key)
	var norm: Transform3D = lib.norm[key]
	# vor der Brust, Modell schaut nach +z (Modell-Koordinaten, Skala SCALE kommt vom Modell)
	carry.transform = Transform3D(Basis.from_scale(Vector3.ONE * 0.9), Vector3(-0.45, 1.05, 0.45)) * norm


func _step(w: Dictionary, dt: float, f: float) -> void:
	var node: Node3D = w["node"]
	var anim: AnimationPlayer = w["anim"]
	if anim != null:
		anim.speed_scale = f
	match w["state"]:
		"go", "return":
			var path: Array[Vector3] = w["path"]
			var pi: int = w["pi"]
			var left := SPEED * dt
			while left > 0.0 and pi < path.size():
				var goal := path[pi]
				var d := goal - node.position
				d.y = 0.0
				var l := d.length()
				if l <= left:
					node.position = Vector3(goal.x, node.position.y, goal.z)
					left -= l
					pi += 1
				else:
					node.position += d / l * left
					(w["model"] as Node3D).rotation.y = atan2(d.x, d.z)
					left = 0.0
			w["pi"] = pi
			var tx := clampi(int(node.position.x / Config.TILE_BLOCKS), 0, map.size - 1)
			var tz := clampi(int(node.position.z / Config.TILE_BLOCKS), 0, map.size - 1)
			node.position.y = lerpf(node.position.y, float(map.h(tx, tz)), minf(1.0, dt * 8.0 + 0.05))
			if pi >= path.size():
				_arrived(w)
		"work", "drop":
			w["wait"] = float(w["wait"]) - dt
			if float(w["wait"]) <= 0.0:
				var path: Array[Vector3] = w["path"]
				path.reverse()
				w["pi"] = 1
				w["state"] = "return"
				_set_carry(w, false)             # leer zurück
				_play(w, "walk")


func _arrived(w: Dictionary) -> void:
	if w["state"] == "go":
		if w["kind"] == "build":
			w["state"] = "work"
			w["wait"] = WORK_TIME
			_set_carry(w, false)
			_play(w, "punch")
		else:
			w["state"] = "drop"
			w["wait"] = DROP_TIME
			_set_carry(w, false)
			_play(w, "idle")
		var path: Array[Vector3] = w["path"]
		var last := path[path.size() - 1]
		var prev := path[maxi(path.size() - 2, 0)]
		(w["model"] as Node3D).rotation.y = atan2(last.x - prev.x, last.z - prev.z)
	else:
		w["state"] = "free"
		w["job"] = -1
		(w["node"] as Node3D).visible = false
		_set_carry(w, false)


func _play(w: Dictionary, key: String) -> void:
	var anim: AnimationPlayer = w["anim"]
	if anim == null:
		return
	for a in anim.get_animation_list():
		if a.to_lower() == key or a.to_lower().ends_with("|" + key):
			if anim.current_animation != a:
				anim.play(a, 0.2)
			return
