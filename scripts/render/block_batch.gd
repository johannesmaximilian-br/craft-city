class_name BlockBatch
extends RefCounted
## Sammelt Block-/Prop-Instanzen nach Mesh-Typ und baut daraus MultiMesh-Knoten.
## Gemeinsamer Baukasten für Welt-Chunks, Icons und Fahrzeuge.

const NO_SHADOW_PREFIXES := ["zone_", "marking"]

var lib: BlockLibrary
var buckets := {}           # key -> Array[Transform3D]
var base := Vector3.ZERO    # Ursprung für put_local/prop_local


func _init(library: BlockLibrary) -> void:
	lib = library


func clear() -> void:
	buckets = {}


func _add(key: String, xf: Transform3D) -> void:
	if not buckets.has(key):
		buckets[key] = []
	buckets[key].append(xf)


## Block mit unterer Ecke bei pos (Einheitswürfel).
func put(key: String, pos: Vector3) -> void:
	_add(key, Transform3D(Basis(), pos) * lib.norm[key])


## Prop (unten mittig verankert) mit Drehung um Y.
func put_prop(key: String, pos: Vector3, rot: float, scale := 1.0) -> void:
	_add(key, Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * scale), pos) * lib.norm[key])


## Block als frei skalierte/rotierte Box: Mittelpunkt, Größe, Drehung um Y.
func put_box(key: String, center: Vector3, size: Vector3, rot_y := 0.0) -> void:
	put_xf(key, Transform3D(Basis(Vector3.UP, rot_y) * Basis.from_scale(size), center))


## xf bildet den zentrierten Einheitswürfel ab.
func put_xf(key: String, xf: Transform3D) -> void:
	_add(key, xf * Transform3D(Basis(), Vector3(-0.5, -0.5, -0.5)) * lib.norm[key])


## Dünner Balken von a nach b (Kabel, Streben, Rotorblätter).
func segment(key: String, a: Vector3, b: Vector3, thickness: float) -> void:
	var d := b - a
	var len := d.length()
	if len < 0.001:
		return
	var x := d / len
	var up := Vector3.UP if absf(x.y) < 0.99 else Vector3.RIGHT
	var z := x.cross(up).normalized()
	var y := z.cross(x).normalized()
	put_xf(key, Transform3D(Basis(x * len, y * thickness, z * thickness), (a + b) * 0.5))


# Callables für Generatoren (lokale Koordinaten relativ zu base)
func put_local(key: String, p: Vector3i) -> void:
	put(key, base + Vector3(p))


func prop_local(key: String, p: Vector3, rot: float) -> void:
	put_prop(key, base + p, rot)


## Erzeugt einen Node3D mit einer MultiMeshInstance3D pro Mesh-Typ.
func build(node_name := "Batch") -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	for key: String in buckets:
		var arr: Array = buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = lib.meshes[key]
		mm.instance_count = arr.size()
		# Alle Instanzen auf einmal übergeben (viel schneller als set_instance_transform je Instanz).
		# Format je Instanz: 3 Basis-Zeilen + Ursprung = 12 Floats.
		var buf := PackedFloat32Array()
		buf.resize(arr.size() * 12)
		var k := 0
		for xf: Transform3D in arr:
			var b := xf.basis
			buf[k] = b.x.x; buf[k + 1] = b.y.x; buf[k + 2] = b.z.x; buf[k + 3] = xf.origin.x
			buf[k + 4] = b.x.y; buf[k + 5] = b.y.y; buf[k + 6] = b.z.y; buf[k + 7] = xf.origin.y
			buf[k + 8] = b.x.z; buf[k + 9] = b.y.z; buf[k + 10] = b.z.z; buf[k + 11] = xf.origin.z
			k += 12
		mm.buffer = buf
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if lib.materials.has(key):
			mmi.material_override = lib.materials[key]
		for p: String in NO_SHADOW_PREFIXES:
			if key.begins_with(p):
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mmi)
	return node
