class_name Mayor
extends Node3D
## Bürgermeister-Figur (Kit-Charakter): steht vor dem Rathaus (ohne Rathaus, z. B. Demo: an der Straße nahe dem
## Stadtzentrum), verkündet alle Meldungen (Sprechblase im HUD über seinem Kopf), läuft zu nahen Problemorten und zurück.
## Klick auf ihn öffnet den Berater (Hud, Popup "mayor").

const SCALE := 1.0                   # Modell ist 2,66 Blöcke hoch: gut sichtbar, aber kleiner als ein Haus
const SPEED := 6.0                   # Blöcke je Sekunde
const WALK_MAX := 40                 # weiter entfernte Orte nur ansagen, nicht hinlaufen (Tiles)
const SAY_TIME := 6.0

var map: CityMap
var sim: Simulation
var text := ""                       # aktuelle Sprechblase ("" = keine)
var _say_left := 0.0
var _home := Vector3.ZERO
var _home_rot := 0.0                 # Blickrichtung am Heimatplatz (vom Rathaus weg)
var _target := Vector3.ZERO
var _state := "home"                 # home | to | there | back
var _wait := 0.0
var _good := false
var _anim: AnimationPlayer
var _model: Node3D
var _idle_t := 0.0
var _home_scan := 0.0


func setup(city_map: CityMap, simulation: Simulation) -> void:
	map = city_map
	sim = simulation
	_model = (load("res://assets/characters/Character_Male_2.gltf") as PackedScene).instantiate()
	nearest_filter(_model)
	_model.scale = Vector3.ONE * SCALE
	add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null:
		for a in _anim.get_animation_list():
			var low := a.to_lower()
			if low.ends_with("idle") or low.ends_with("walk"):
				_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_play("idle")
	map.tiles_changed.connect(func(_r: Rect2i) -> void: _home_scan = 0.0)


## Kopfposition (für die Sprechblase im HUD).
func head() -> Vector3:
	return global_position + Vector3(0, 2.7 * SCALE + 0.4, 0)


## Meldung verkünden; tile >= 0 und nah genug -> hinlaufen. good = positive Nachricht (nicken statt Kopfschütteln).
func say(msg: String, tile := Vector2i(-1, -1), good := false) -> void:
	text = msg
	_say_left = SAY_TIME
	_good = good
	if tile.x < 0 or not map.in_bounds(tile.x, tile.y):
		_wave()
		return
	var p := _tile_pos(tile)
	if p.distance_to(_home) > WALK_MAX * Config.TILE_BLOCKS:
		_wave()
		return
	_target = p
	_state = "to"


func _tile_pos(t: Vector2i) -> Vector3:
	var b := float(Config.TILE_BLOCKS)
	return Vector3(t.x * b + b * 0.5, float(map.h(t.x, t.y)), t.y * b + b * 0.5)


## Heimatplatz: vor dem Rathaus, sonst Straße nahe dem Bevölkerungsschwerpunkt.
func _find_home() -> void:
	for a in map.size * map.size:
		if map.anchor[a] == a and map.special[a] == Config.Special.CITYHALL:
			# vor der Front (Seite mit den meisten Straßen, wie WorldRenderer._front_angle), knapp vor der Wand
			var tx := a % map.size
			var tz := a / map.size
			var counts := [0, 0, 0, 0]    # N, O, S, W
			for k in 3:
				counts[0] += 1 if map.is_road(tx + k, tz - 1) else 0
				counts[1] += 1 if map.is_road(tx + 3, tz + k) else 0
				counts[2] += 1 if map.is_road(tx + k, tz + 3) else 0
				counts[3] += 1 if map.is_road(tx - 1, tz + k) else 0
			var side := 0
			for d in range(1, 4):
				if counts[d] > counts[side]:
					side = d
			var dir: Vector2i = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)][side]
			var b := float(Config.TILE_BLOCKS)
			var t := Vector2i(tx + 1, tz + 1) + dir * 2
			t = Vector2i(clampi(t.x, 0, map.size - 1), clampi(t.y, 0, map.size - 1))
			_home = Vector3((tx + 1.5) * b, 0.0, (tz + 1.5) * b) + Vector3(dir.x, 0, dir.y) * (1.5 * b + 0.9)
			_home.y = float(map.h(t.x, t.y))
			_home_rot = atan2(float(dir.x), float(dir.y))
			return
	var sx := 0.0
	var sz := 0.0
	var w := 0.0
	for i in map.size * map.size:
		if map.zone[i] == Config.Zone.RES and map.level[i] > 0:
			sx += i % map.size
			sz += i / map.size
			w += 1.0
	_home_rot = 0.0
	var c := Vector2(map.size * 0.5, map.size * 0.5) if w == 0.0 else Vector2(sx / w, sz / w)
	var best := Vector2i(int(c.x), int(c.y))
	var bd := INF
	for i in map.size * map.size:
		if map.road[i] != 0:
			var d := Vector2(i % map.size, i / map.size).distance_squared_to(c)
			if d < bd:
				bd = d
				best = Vector2i(i % map.size, i / map.size)
	_home = _tile_pos(best)


func _process(dt: float) -> void:
	_home_scan -= dt
	if _home_scan <= 0.0:
		_home_scan = 5.0
		_find_home()
		if _state == "home":
			position = _home
	if _say_left > 0.0:
		_say_left -= dt
		if _say_left <= 0.0:
			text = ""
	match _state:
		"home":
			position = _home
			_model.rotation.y = _home_rot
			_idle_t -= dt
			if _idle_t <= 0.0:
				_idle_t = randf_range(8.0, 16.0)
				_wave()
		"to", "back":
			var goal := _target if _state == "to" else _home
			var d := goal - position
			d.y = 0.0
			if d.length() < 0.5:
				position = goal
				if _state == "to":
					_state = "there"
					_wait = 3.0
					_play("yes" if _good else "no")
				else:
					_state = "home"
					_play("idle")
			else:
				var step := d.normalized() * minf(SPEED * dt, d.length())
				position += step
				var tx := clampi(int(position.x / Config.TILE_BLOCKS), 0, map.size - 1)
				var tz := clampi(int(position.z / Config.TILE_BLOCKS), 0, map.size - 1)
				position.y = lerpf(position.y, float(map.h(tx, tz)) + (0.3 if map.has_building(tx, tz) else 0.0), 0.2)
				_model.rotation.y = atan2(d.x, d.z)
				_play("walk")
		"there":
			_wait -= dt
			if _wait <= 0.0:
				_state = "back"


## Eigener 32-px-Atlas der Figur bleibt (BlockLibrary.fix_node_materials würde ihn gegen den Block-Atlas tauschen).
static func nearest_filter(n: Node) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mesh := (n as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s) as BaseMaterial3D
			if mat != null:
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	for c in n.get_children():
		nearest_filter(c)


func _wave() -> void:
	if _state == "home":
		_play("wave")
		await get_tree().create_timer(1.6).timeout
		if _state == "home":
			_play("idle")


func _play(key: String) -> void:
	if _anim == null:
		return
	for a in _anim.get_animation_list():
		var low := a.to_lower()
		if low.ends_with(key) or low.ends_with("|" + key) or low == key:
			if _anim.current_animation != a:
				_anim.play(a, 0.2)
			return
