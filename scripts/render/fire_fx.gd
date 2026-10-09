class_name FireFx
extends Node3D
## Zeigt Brände (Voxel-Flammen + Rauch), Löschzüge mit Blaulicht, Wasserstrahl
## und rauchende Brandruinen. Liest nur FireDept/CityMap.

const B := Config.TILE_BLOCKS
const LANE := 0.62
const RUIN_SCAN := 0.5          # Sekunden zwischen Ruinen-Scans
const TRUCK_RED := Color("d8342a")

var map: CityMap
var dept: FireDept
var _flames: MultiMesh
var _smoke: MultiMesh
var _water: MultiMesh
var _trucks: MultiMesh
var _lights: MultiMesh
var _time := 0.0
var _ruins: Array[int] = []
var _ruin_scan := 0.0
var _yaw := {}                  # Truck -> geglätteter Winkel
var _anim := 0.0                # läuft nur, wenn das Spiel nicht pausiert


## Meshes mit den Materialien, die FireFx nutzt (für ShaderWarmup).
static func warmup_meshes() -> Array[Mesh]:
	var out: Array[Mesh] = [_box(false), _box(true)]
	return out


static func _box(alpha: bool) -> BoxMesh:
	var m := BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	# Unbeleuchtet: sonst färbt das Himmelslicht Rauch bläulich
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material = mat
	return m


func setup(city_map: CityMap, fire_dept: FireDept, lib: BlockLibrary) -> void:
	map = city_map
	dept = fire_dept
	_flames = _layer("Flames", _box(false))
	_smoke = _layer("Smoke", _box(true))
	_water = _layer("Water", _box(false))
	_trucks = _layer("FireTrucks", lib.fire_truck_mesh())
	_lights = _layer("Lights", _box(false))


func _layer(layer_name: String, mesh: Mesh) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.name = layer_name
	mmi.multimesh = mm
	if mesh is BoxMesh:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mm


func _process(delta: float) -> void:
	_time += delta
	_anim += delta * FireDept.TIME_SCALE[dept.sim.speed]
	_ruin_scan -= delta
	if _ruin_scan <= 0.0:
		_ruin_scan = RUIN_SCAN
		_ruins.clear()
		for i in map.size * map.size:
			if map.ruin[i] > 0 and map.zone[i] != Config.Zone.NONE:
				_ruins.append(i)
	_draw_fires()
	_draw_trucks(delta)


func _top(i: int) -> float:
	return (StatusMarkers.LEVEL_OFFSET[map.level[i]] if map.villa[i] == 0 else StatusMarkers.LEVEL_OFFSET[1] + 1.0) - 1.4


func _draw_fires() -> void:
	var flames: Array[Transform3D] = []
	var flame_cols: Array[Color] = []
	var smoke: Array[Transform3D] = []
	var smoke_cols: Array[Color] = []
	var water: Array[Transform3D] = []
	for f: FireDept.Fire in dept.fires.values():
		var i := f.tile
		var base := Vector3((i % map.size) * B, map.height[i], (i / map.size) * B)
		var top := _top(i)
		var work := f.truck.work if f.truck != null and f.truck.stage == FireDept.Stage.WORK else 0.0
		var heat := clampf(0.5 + f.progress, 0.0, 1.3) * (1.0 - work)
		var count := 8 + int(f.progress * 14.0)
		for k in count:
			var h := absi(hash(Vector2i(i, k)))
			var c := fmod(_anim * 1.6 + (h % 100) * 0.01, 1.0)
			# Auf der Hülle des 3x3-Gebäudes: Dach oder eine Seite
			var u := (h >> 8) % 100 * 0.03
			var p: Vector3
			match (h >> 4) % 5:
				0: p = Vector3(-0.1, top * ((h >> 12) % 10) * 0.1, u)
				1: p = Vector3(3.1, top * ((h >> 12) % 10) * 0.1, u)
				2: p = Vector3(u, top * ((h >> 12) % 10) * 0.1, -0.1)
				3: p = Vector3(u, top * ((h >> 12) % 10) * 0.1, 3.1)
				_: p = Vector3(0.3 + u * 0.8, top, 0.3 + ((h >> 16) % 100) * 0.024)
			var s := ((1.0 - c) * 0.8 + 0.4) * heat
			flames.append(Transform3D(Basis.from_scale(Vector3.ONE * s), base + p + Vector3(0, c * 1.8, 0)))
			flame_cols.append(Color("ffe14d").lerp(Color("ff7a1a"), c).lerp(Color("c8261a"), c * c))
		# Rauch (beim Löschen weißer Dampf)
		for k in 8:
			var c := fmod(_anim * 0.3 + k / 8.0, 1.0)
			var p := base + Vector3(1.5 + c * 2.5 + sin(k * 2.1) * 0.5, top + 0.4 + c * 7.0, 1.5 + cos(k * 1.7) * 0.5)
			smoke.append(Transform3D(Basis.from_scale(Vector3.ONE * (0.9 + c * 1.8)), p))
			var g := lerpf(0.15, 0.5, c)
			var col := Color(g, g, g).lerp(Color(0.95, 0.95, 0.95), work)
			col.a = (1.0 - c * c) * 0.85
			smoke_cols.append(col)
		# Wasserstrahl vom Löschzug zum Dach
		if work > 0.0:
			var from := _truck_pos(f.truck) + Vector3(0, 1.0, 0)
			var to := base + Vector3(1.5, top + 0.3, 1.5)
			for k in 10:
				var c := fmod(_time * 1.8 + k / 10.0, 1.0)
				var p := from.lerp(to, c) + Vector3(0, sin(c * PI) * 2.0, 0)
				water.append(Transform3D(Basis.from_scale(Vector3.ONE * 0.22), p))
	# Glimmende Ruinen: dünner heller Rauch, frisch abgebrannt stärker
	for i in _ruins:
		var base := Vector3((i % map.size) * B + 1.5, map.height[i] + 0.5, (i / map.size) * B + 1.5)
		var fresh := float(map.ruin[i]) / Config.FIRE_RUIN_MONTHS
		for k in 3:
			var c := fmod(_anim * 0.2 + k / 3.0 + i * 0.13, 1.0)
			smoke.append(Transform3D(Basis.from_scale(Vector3.ONE * (0.3 + c * 0.9)),
				base + Vector3(c * 1.2, c * 5.0, sin(i + k) * 0.5)))
			smoke_cols.append(Color(0.5, 0.5, 0.5, (1.0 - c) * 0.45 * fresh))
	_fill(_flames, flames, flame_cols)
	_fill(_smoke, smoke, smoke_cols)
	var blue: Array[Color] = []
	blue.resize(water.size())
	blue.fill(Color("6cc4ff"))
	_fill(_water, water, blue)


func _draw_trucks(delta: float) -> void:
	var xf: Array[Transform3D] = []
	var cols: Array[Color] = []
	var lights: Array[Transform3D] = []
	var light_cols: Array[Color] = []
	var blink := int(_time * 4.0) % 2 == 0
	var alive := {}
	for tr: FireDept.Truck in dept.trucks:
		alive[tr] = true
		var seg := _segment(tr)
		var d := Vector2(seg[1] - seg[0])
		var target := atan2(-d.y, d.x)
		var yaw: float = lerp_angle(_yaw.get(tr, target), target, minf(1.0, delta * 10.0))
		_yaw[tr] = yaw
		var basis := Basis(Vector3.UP, yaw)
		var t := Transform3D(basis, _truck_pos(tr))
		xf.append(t)
		cols.append(TRUCK_RED)
		# Blaulicht nur auf Einsatzfahrt / vor Ort
		if tr.stage != FireDept.Stage.BACK:
			for side: float in [-0.2, 0.2]:
				lights.append(t * Transform3D(Basis.from_scale(Vector3.ONE * 0.16), Vector3(0.45, 0.82, side)))
				light_cols.append(Color("3a7bff") if blink == (side > 0.0) else Color("e9f1ff"))
	for tr in _yaw.keys():
		if not alive.has(tr):
			_yaw.erase(tr)
	_fill(_trucks, xf, cols)
	_fill(_lights, lights, light_cols)


## [von, nach, t] des aktuellen Wegstücks.
func _segment(tr: FireDept.Truck) -> Array:
	var n := tr.path.size()
	var k := mini(int(tr.t), n - 2)
	var a := tr.path[k]
	var b := tr.path[k + 1]
	return [Vector2i(a % map.size, a / map.size), Vector2i(b % map.size, b / map.size), tr.t - k]


func _truck_pos(tr: FireDept.Truck) -> Vector3:
	var seg := _segment(tr)
	var from: Vector2i = seg[0]
	var to: Vector2i = seg[1]
	var t: float = seg[2]
	var a := Vector2(from) * B + Vector2.ONE * (B * 0.5)
	var b := Vector2(to) * B + Vector2.ONE * (B * 0.5)
	var dir := Vector2(to - from)
	var p := a.lerp(b, t) + Vector2(-dir.y, dir.x) * LANE
	var y := lerpf(map.h(from.x, from.y), map.h(to.x, to.y), smoothstep(0.35, 0.65, t))
	return Vector3(p.x, y, p.y)


## Instanzfarben sind linear -> sRGB-Farben umrechnen (sonst blass/weiß).
func _fill(mm: MultiMesh, xf: Array[Transform3D], cols: Array[Color]) -> void:
	mm.instance_count = xf.size()
	for k in xf.size():
		mm.set_instance_transform(k, xf[k])
		mm.set_instance_color(k, cols[k].srgb_to_linear())
