class_name StatusMarkers
extends MultiMeshInstance3D
## Schwebende, drehende Voxel-Blitze (aus Kit-Blöcken) über Zonen ohne Strom.

const B := Config.TILE_BLOCKS
const LEVEL_OFFSET := [2.2, 4.2, 6.0, 11.5]

var map: CityMap
var sim: Simulation
var _points: Array[Vector3] = []
var _crate_norm := Transform3D()
var _crates: MultiMeshInstance3D    # Vorrat von Abbau ohne Straße zum Lager: Kistenstapel je nach Füllstand
var _time := 0.0


func setup(city_map: CityMap, simulation: Simulation, lib: BlockLibrary) -> void:
	map = city_map
	sim = simulation
	var mesh := lib.voxel_mesh(IconFactory.VOXELS["bolt"], "vox_yellow", 0.22)
	var mat := (mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = Color("ffb300")
	mat.emission_energy_multiplier = 0.6
	mesh.surface_set_material(0, mat)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	sim.power_changed.connect(_rebuild)
	_crates = MultiMeshInstance3D.new()
	_crates.multimesh = MultiMesh.new()
	_crates.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_crates.multimesh.mesh = lib.meshes["crate"]
	_crate_norm = lib.norm["crate"]
	add_child(_crates)
	sim.stats_changed.connect(_rebuild_crates)
	_rebuild()


func _process(delta: float) -> void:
	_time += delta
	var rot := Basis(Vector3.UP, _time * 2.0)
	var bob := sin(_time * 3.0) * 0.15
	for k in _points.size():
		multimesh.set_instance_transform(k, Transform3D(rot, _points[k] + Vector3(0, bob, 0)))


func _rebuild() -> void:
	_points.clear()
	var size := map.size
	var zone := map.zone
	var level := map.level
	var villa := map.villa
	var height := map.height
	var anchor := map.anchor
	var pw := sim.powered
	if pw.size() != size * size:
		multimesh.instance_count = 0
		return
	for i in size * size:
		if pw[i] == 1:
			continue
		var x := i % size
		var z := i / size
		# Dienst-/Kulturbau ohne Strom: ein Blitz über dem Ursprungs-Tile
		if zone[i] == Config.Zone.NONE:
			if anchor[i] == i and sim.tile_power_use(i) > 0:
				var s: int = Config.SPECIALS[map.special[i]]["size"]
				_points.append(Vector3(x * B + s * B * 0.5, height[i] + 7.0, z * B + s * B * 0.5))
			continue
		# Leere Zonen nur jedes 2. Tile, damit es nicht überladen wirkt
		if level[i] == 0 and (x + z) % 2 == 1:
			continue
		var off: float = LEVEL_OFFSET[level[i]] if villa[i] == 0 else LEVEL_OFFSET[1] + 1.0
		_points.append(Vector3(x * B + B * 0.5, height[i] + off, z * B + B * 0.5))
	multimesh.instance_count = _points.size()


## Kisten neben Abbau-Gebäuden ohne Lieferweg: 1 Kiste je 10 Einheiten im eigenen Vorrat (max. 3 Lagen).
func _rebuild_crates() -> void:
	var xf: Array[Transform3D] = []
	for a: int in sim.local_buffer:
		if map.anchor[a] != a or map.special[a] == Config.Special.NONE:
			continue
		var total := sim._buffer_sum(sim.local_buffer[a])
		var count := mini(int(ceil(total / 10.0)), 15)
		var s: int = Config.SPECIALS[map.special[a]]["size"]
		var base := Vector3((a % map.size) * B, map.height[a], (a / map.size) * B)
		for k in count:
			var p := base + Vector3(s * B - 1.0 - (k % 3) * 0.95, (k / 9) * 0.95, -0.05 + ((k / 3) % 3) * 0.95)
			xf.append(Transform3D(Basis.from_scale(Vector3.ONE * 0.9), p) * _crate_norm)
	_crates.multimesh.instance_count = xf.size()
	for k in xf.size():
		_crates.multimesh.set_instance_transform(k, xf[k])
