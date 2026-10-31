class_name ChimneySmoke
extends Node3D
## Rauch aus den Schornsteinen von Kohlekraftwerken, Werken und Industrie (nur mit Strom).
## Kraftwerk/Werke ohne Forschung dunkel und dicht; mit "Kraftwerksfilter" bzw. "Moderne Hochöfen" weiß, dünn und
## seltener (Wirkung der Forschung sichtbar). Industrie (Stufe 2-3) raucht nur leicht und nur jedes dritte Gebäude,
## sonst wird es zu viel (Nutzer-Feedback).

const B := Config.TILE_BLOCKS
const MAX_PUFFS := 450
# Schlot-Spitzen in Block-Koordinaten des Generators (vor der Drehung zur Straße), je Sonderbau
const STACKS := {
	Config.Special.COAL: [Vector3(5.0, 8.0, 2.0)],
	Config.Special.BRICKWORKS: [Vector3(4.5, 8.0, 4.5)],
	Config.Special.GLASSWORKS: [Vector3(4.5, 6.0, 4.5)],
	Config.Special.STEELWORKS: [Vector3(1.5, 8.0, 2.5), Vector3(4.5, 8.0, 2.5)],
	Config.Special.BIOMASS: [Vector3(4.5, 8.0, 4.5)],
}

var map: CityMap
var sim: Simulation
var renderer: WorldRenderer
var speed := 1.0                  # Spieltempo (0 = Pause: Rauch steht fast)
var _mm: MultiMesh
var _emitters: Array = []         # [Weltposition, Art: "coal"/"works"]
var _scan := 0.0
var _spawn := {}                  # Emitter-Index -> Zeit bis zum nächsten Puff
var _puffs: Array = []            # [pos: Vector3, age, life, size0, size1, col: Color]


func setup(city_map: CityMap, simulation: Simulation, world: WorldRenderer) -> void:
	map = city_map
	sim = simulation
	renderer = world
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = FireFx._box(true)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "ChimneySmoke"
	mmi.multimesh = _mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	map.tiles_changed.connect(func(_r: Rect2i) -> void: _scan = minf(_scan, 0.2))   # gebündelt: Wachstum meldet oft


func _rescan() -> void:
	_emitters.clear()
	for a in map.size * map.size:
		if map.anchor[a] != a or not STACKS.has(map.special[a]) or not sim.special_powered(a):
			continue
		var sp := map.special[a]
		var tx := a % map.size
		var tz := a / map.size
		var s: int = Config.SPECIALS[sp]["size"]
		var base := Vector3(tx * B, map.height[a], tz * B)
		var rot := Transform3D.IDENTITY
		if sp != Config.Special.COAL:     # Kohlekraftwerk wird nicht gedreht (siehe WorldRenderer)
			var center := base + Vector3(s * B * 0.5, 0, s * B * 0.5)
			rot = Transform3D(Basis(Vector3.UP, renderer._front_angle(tx, tz, s)), center) * Transform3D(Basis(), -center)
		var lv := map.special_level(a) if sp != Config.Special.COAL else 0
		for p: Vector3 in STACKS[sp]:
			var kind := "coal" if sp == Config.Special.COAL else ("bio" if sp == Config.Special.BIOMASS else "works")
			if sp == Config.Special.BIOMASS:
				lv = 0
			_emitters.append([rot * (base + p + Vector3(0, lv + 0.3, 0)), kind])
	# Industrie: Schlot aus dem Gebäude-Generator, nur Stufe 2-3, jedes dritte Gebäude, nur mit Strom
	for i in map.size * map.size:
		if map.zone[i] != Config.Zone.IND or map.level[i] < 2 or map.hightech[i] == 1 or sim.powered[i] == 0 \
				or absi(hash(i)) % 3 != 0:
			continue
		var tx := i % map.size
		var tz := i / map.size
		var lv := map.level[i]
		var st := BuildingGenerator.ind_stack(hash(Vector3i(tx, tz, lv)), lv)
		var c: Vector2i = st[0]
		_emitters.append([Vector3(tx * B + c.x + 0.5, map.height[i] + int(st[1]) + 0.2, tz * B + c.y + 0.5), "ind"])


func _process(dt: float) -> void:
	_scan -= dt
	if _scan <= 0.0:
		_scan = 1.0
		_rescan()
	var t := dt * (0.25 if speed <= 0 else 1.0)
	var filter := sim.tech("plant_filter")
	var furnace := sim.tech("blast_furnace")
	for k in _emitters.size():
		var e: Array = _emitters[k]
		var kind: String = e[1]
		var clean := filter if kind == "coal" else (furnace if kind == "works" else false)
		var left := float(_spawn.get(k, randf() * 0.5)) - t * (1.0 if speed <= 0 else minf(speed, 3.0))
		if left <= 0.0 and _puffs.size() < MAX_PUFFS:
			left = (1.3 if kind == "ind" else (0.8 if clean else 0.4)) * randf_range(0.7, 1.3)
			var col := Color(0.93, 0.93, 0.95, 0.32) if clean else (Color(0.24, 0.24, 0.26, 0.55) if kind == "coal"
				else (Color(0.55, 0.54, 0.53, 0.32) if kind == "ind" else (Color(0.5, 0.45, 0.38, 0.45) if kind == "bio"
				else Color(0.36, 0.34, 0.33, 0.5))))
			var big := 0.5 if clean else (0.45 if kind == "ind" else 0.85)
			_puffs.append([(e[0] as Vector3) + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2)), 0.0,
				randf_range(3.0, 4.5) * (0.7 if clean else 1.0), 0.5 * big, 2.4 * big, col])
		_spawn[k] = left
	var xf: Array[Transform3D] = []
	var cols: Array[Color] = []
	var keep: Array = []
	for p: Array in _puffs:
		p[1] = float(p[1]) + t
		var f: float = float(p[1]) / float(p[2])
		if f >= 1.0:
			continue
		keep.append(p)
		var pos: Vector3 = p[0]
		pos += Vector3(0.6 * float(p[1]), 1.1 * float(p[1]), 0.25 * float(p[1]))      # steigt, Wind treibt ab
		var sz := lerpf(float(p[3]), float(p[4]), f)
		xf.append(Transform3D(Basis.from_scale(Vector3.ONE * sz), pos))
		var c: Color = p[5]
		cols.append(Color(c.r, c.g, c.b, c.a * (1.0 - f)))
	_puffs = keep
	_mm.instance_count = xf.size()
	for i in xf.size():
		_mm.set_instance_transform(i, xf[i])
		_mm.set_instance_color(i, cols[i])
