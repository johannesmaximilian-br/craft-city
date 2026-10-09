class_name ShaderWarmup
extends Node3D
## Rendert beim Start jedes Mesh/Material der Bibliothek (und Fahrzeuge, Marker) einmal
## direkt vor der Kamera, mit Schatten. Godot kompiliert dabei alle Shader-Pipelines,
## statt später mitten im Spiel zu ruckeln, wenn z.B. der erste Bus oder ein neuer
## Blocktyp auftaucht. Nach wenigen Frames entfernt sich der Knoten selbst.

const FRAMES := 3


func run(lib: BlockLibrary, cam: Camera3D) -> void:
	var meshes: Array[Mesh] = []
	var overrides: Array = []
	for key: String in lib.meshes:
		meshes.append(lib.meshes[key])
		overrides.append(lib.materials.get(key, null))
	for m: Mesh in [lib.car_mesh(), lib.bus_mesh(), lib.wagon_mesh()]:
		meshes.append(m)
		overrides.append(null)
	# Klein, dicht vor der Kamera, damit alles im Bild (und im Schatten-Pass) ist
	var front := cam.global_transform.origin - cam.global_transform.basis.z * 6.0
	for k in meshes.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = meshes[k]
		mm.instance_count = 1
		mm.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3.ONE * 0.05), Vector3.ZERO))
		mm.set_instance_color(0, Color.WHITE)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if overrides[k] != null:
			mmi.material_override = overrides[k]
		mmi.position = front + Vector3((k % 10) * 0.06, (k / 10) * 0.06, 0)
		add_child(mmi)
	for f in FRAMES:
		await get_tree().process_frame
	queue_free()
