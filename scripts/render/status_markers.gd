class_name StatusMarkers
extends MultiMeshInstance3D
## Schwebende, drehende Voxel-Blitze (aus Kit-Blöcken) über Zonen ohne Strom.

const B := Config.TILE_BLOCKS
const LEVEL_OFFSET := [2.2, 4.2, 6.0, 11.5]

var map: CityMap
var sim: Simulation
var _points: Array[Vector3] = []
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
