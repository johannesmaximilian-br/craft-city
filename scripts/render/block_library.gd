class_name BlockLibrary
extends RefCounted
## Lädt Meshes aus dem Cube World Kit und normalisiert sie:
## Blöcke -> Einheitswürfel [0,1]^3, Props -> unten mittig am Ursprung.

const ATLAS := preload("res://assets/Atlas.png")

# key -> Pfad unter assets/ (pixel/ = texturierte Pixel Blocks, blocks/ = glatte Farbblöcke)
const BLOCKS := {
	# Terrain
	"grass": "pixel/Grass", "dirt": "pixel/Dirt", "stone": "pixel/Stone", "snow": "pixel/Snow",
	# Baumaterial
	"wood": "pixel/WoodPlanks", "log": "pixel/Wood", "brick": "pixel/Bricks_Red",
	"greybrick": "pixel/Bricks_Grey", "darkbrick": "pixel/Bricks_Dark", "yellowbrick": "pixel/Bricks_Yellow",
	"ice": "pixel/Ice", "leaves": "pixel/Leaves", "square": "pixel/Block_Square",
	"coal": "pixel/Coal",
	# glatte Kit-Blöcke (Basis für Einfärbungen, Kisten, Metall)
	"metal": "blocks/Block_Metal", "crate": "blocks/Block_Crate", "blank": "blocks/Block_Blank",
	"cheese": "blocks/Block_Cheese",
}

# key -> [Pfad unter assets/, Zielhöhe in Blöcken]
# Modelle mit eigenem Ursprung, nur skaliert: key -> [Pfad, Faktor]
# Gleise: Gerade/Kurve sind 2 Einheiten lang -> x1.5 = genau 1 Tile (3 Blöcke)
const RAW_PROPS := {
	"rail_straight": ["env/Rail_Straight", 1.5],
	"rail_corner": ["env/Rail_Corner", 1.5],
}

const PROPS := {
	"tree1": ["env/Tree_1", 3.6], "tree2": ["env/Tree_2", 3.2], "tree3": ["env/Tree_3", 3.8],
	"bush": ["env/Bush", 0.9], "flowers1": ["env/Flowers_1", 0.7], "flowers2": ["env/Flowers_2", 0.7],
	"rock": ["env/Rock1", 0.8], "fence": ["env/Fence_Center", 0.8],
	"chest": ["env/Chest_Closed", 1.0], "pickaxe": ["tools/Pickaxe_Diamond", 2.0],
	"shovel": ["tools/Shovel_Gold", 2.0],
}

# Eingefärbte Kit-Blöcke (abgerundeter Blank-Block + Farbe)
const TINTED := {
	"asphalt": ["blank", Color(0.25, 0.25, 0.27)],
	"concrete": ["blank", Color(0.88, 0.88, 0.86)],
	"vox_yellow": ["blank", Color("ffcc33")],
	"vox_red": ["blank", Color("e0503c")],
	"vox_green": ["blank", Color("7cc242")],
	"vox_white": ["blank", Color("f4f2ec")],
	"vox_blue": ["blank", Color("4a90e2")],
	"vox_dark": ["blank", Color("2b2d33")],
	"vox_glass": ["blank", Color("9fd3ee")],
	"paint_white": ["blank", Color(0.96, 0.96, 0.94)],
	"paint_yellow": ["blank", Color("f2c12e")],
}

# Flache Platten: [Farbe, Größe x/z, Dicke]
const PLATES := {
	"zone_res": [Color(0.2, 0.85, 0.3, 0.45), 1.0, 0.06],
	"zone_com": [Color(0.25, 0.5, 1.0, 0.45), 1.0, 0.06],
	"zone_ind": [Color(1.0, 0.8, 0.15, 0.45), 1.0, 0.06],
	"marking": [Color(0.95, 0.9, 0.6), 0.25, 0.04],
	"marking_white": [Color(0.96, 0.96, 0.94), 0.22, 0.04],
}

var meshes := {}        # key -> Mesh
var norm := {}          # key -> Transform3D
var materials := {}     # key -> Material (Override) — optional


func load_all() -> void:
	for key in BLOCKS:
		_load_block(key, "res://assets/%s.gltf" % BLOCKS[key])
	for key in PROPS:
		_load_prop(key, "res://assets/%s.gltf" % PROPS[key][0], PROPS[key][1])
	for key in RAW_PROPS:
		var res := _extract("res://assets/%s.gltf" % RAW_PROPS[key][0])
		meshes[key] = res[0]
		var s: float = RAW_PROPS[key][1]
		norm[key] = Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3.ZERO) * (res[1] as Transform3D)
	for key in TINTED:
		var base: String = TINTED[key][0]
		meshes[key] = meshes[base]
		norm[key] = norm[base]
		materials[key] = flat_material(TINTED[key][1])
	# Glatte Asphalt-Box (Einheitswürfel ohne Fase) für Rundungen aus Streifen
	var flat := BoxMesh.new()
	flat.material = materials["asphalt"]
	meshes["flat_asphalt"] = flat
	norm["flat_asphalt"] = Transform3D(Basis(), Vector3(0.5, 0.5, 0.5))
	for key in PLATES:
		var spec: Array = PLATES[key]
		var box := BoxMesh.new()
		var s: float = spec[1]
		var t: float = spec[2]
		box.size = Vector3(s, t, s)
		var mat := StandardMaterial3D.new()
		var col: Color = spec[0]
		mat.albedo_color = col
		if col.a < 1.0:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		box.material = mat
		meshes[key] = box
		# Box ist zentriert -> auf Zellmitte, Unterseite auf y=0
		norm[key] = Transform3D(Basis(), Vector3(0.5, t * 0.5 + 0.01, 0.5))


static func flat_material(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.85
	return mat


## Glatte Kit-glTFs betten nur einen 32px-Atlas ein -> durch vollen Palette-Atlas ersetzen.
## Nearest ohne Mipmaps, sonst mischen sich Nachbarfarben/Weiß ein.
static func fix_mesh_materials(mesh: Mesh) -> void:
	for s in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s) as BaseMaterial3D
		if mat == null:
			continue
		# Nur der heruntergerechnete Paletten-Atlas (32px) wird ersetzt; Pixel-Blocks-Texturen bleiben
		var tex := mat.albedo_texture
		if tex == null or tex.get_width() <= 32:
			mat.albedo_texture = ATLAS
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST


static func fix_node_materials(n: Node) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		fix_mesh_materials((n as MeshInstance3D).mesh)
	for c in n.get_children():
		fix_node_materials(c)


func _extract(path: String) -> Array:
	var scene: PackedScene = load(path)
	var root := scene.instantiate()
	var mi := _find_mesh(root)
	assert(mi != null, "Kein Mesh in " + path)
	var xf := Transform3D()
	var n: Node = mi
	while n != root and n is Node3D:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	var mesh := mi.mesh
	root.free()
	fix_mesh_materials(mesh)
	return [mesh, xf]


func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _find_mesh(c)
		if r:
			return r
	return null


func _load_block(key: String, path: String) -> void:
	var res := _extract(path)
	var mesh: Mesh = res[0]
	var xf: Transform3D = res[1]
	var aabb := xf * mesh.get_aabb()
	var inv := Vector3.ONE / aabb.size
	meshes[key] = mesh
	norm[key] = Transform3D(Basis.from_scale(inv), -aabb.position * inv) * xf


func _load_prop(key: String, path: String, target_height: float) -> void:
	var res := _extract(path)
	var mesh: Mesh = res[0]
	var xf: Transform3D = res[1]
	var aabb := xf * mesh.get_aabb()
	var s := target_height / aabb.size.y
	var c := aabb.get_center()
	meshes[key] = mesh
	norm[key] = Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3(-c.x * s, -aabb.position.y * s, -c.z * s)) * xf


## Voxel-Figur aus Zeichenraster ("X" = Block), zentriert, in der XY-Ebene.
## Ergebnis: ein einziges Mesh aus abgerundeten Kit-Blöcken.
func voxel_mesh(rows: Array, key: String, voxel := 1.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	var h := rows.size()
	var w := 0
	for r: String in rows:
		w = maxi(w, r.length())
	var off := Vector3(-w * 0.5, h * 0.5, -0.5) * voxel
	var src: Mesh = meshes[key]
	for y in h:
		var row: String = rows[y]
		for x in row.length():
			if row[x] != "X":
				continue
			var p := off + Vector3(x, -y - 1, 0) * voxel
			var xf: Transform3D = Transform3D(Basis.from_scale(Vector3.ONE * voxel), p) * norm[key]
			st.append_from(src, 0, xf)
	var out := st.commit()
	out.surface_set_material(0, materials.get(key, src.surface_get_material(0)))
	return out


## Auto aus abgerundeten Kit-Blöcken, Front = +X. Karosserie nimmt Instanzfarbe an.
func car_mesh() -> ArrayMesh:
	return _vehicle_mesh({
		"body": [[Vector3(0, 0.3, 0), Vector3(1.25, 0.36, 0.66)]],
		"glass": [[Vector3(-0.1, 0.6, 0), Vector3(0.7, 0.3, 0.58)]],
		"tire": _wheels(0.38, 0.3, 0.28),
	})


## Bus: lang, Fensterband rundum, Front = +X.
func bus_mesh() -> ArrayMesh:
	return _vehicle_mesh({
		"body": [[Vector3(0, 0.45, 0), Vector3(2.4, 0.66, 0.74)]],
		"glass": [[Vector3(0.05, 0.62, 0), Vector3(2.32, 0.22, 0.77)]],
		"roof": [[Vector3(0, 0.82, 0), Vector3(2.3, 0.1, 0.68)]],
		"tire": _wheels(0.8, 0.34, 0.3),
	})


## Zug-Waggon (Lok = gleiches Modell, andere Instanzfarbe), Front = +X.
func wagon_mesh() -> ArrayMesh:
	return _vehicle_mesh({
		"body": [[Vector3(0, 0.62, 0), Vector3(2.5, 0.84, 1.0)]],
		"glass": [[Vector3(0, 0.78, 0), Vector3(2.3, 0.24, 1.03)]],
		"roof": [[Vector3(0, 1.08, 0), Vector3(2.4, 0.12, 0.9)]],
		"tire": [[Vector3(0.8, 0.14, 0), Vector3(0.6, 0.28, 0.85)], [Vector3(-0.8, 0.14, 0), Vector3(0.6, 0.28, 0.85)]],
	})


func _wheels(x: float, z: float, d: float) -> Array:
	var out := []
	for sx: float in [x, -x]:
		for sz: float in [z, -z]:
			out.append([Vector3(sx, d * 0.5, sz), Vector3(d, d, 0.12)])
	return out


## Fahrzeug aus abgerundeten Kit-Blöcken. Teil "body" nimmt die Instanzfarbe an.
func _vehicle_mesh(parts: Dictionary) -> ArrayMesh:
	var src: Mesh = meshes["blank"]
	var n: Transform3D = norm["blank"]
	var center := Transform3D(Basis(), Vector3(-0.5, -0.5, -0.5)) * n
	var body_mat := flat_material(Color.WHITE)
	body_mat.vertex_color_use_as_albedo = true
	var mats := {"body": body_mat, "glass": flat_material(Color("9fd3ee")),
		"tire": flat_material(Color("2b2d33")), "roof": flat_material(Color("4a4d55"))}
	var mesh := ArrayMesh.new()
	for key: String in parts:
		var st := SurfaceTool.new()
		for p: Array in parts[key]:
			st.append_from(src, 0, Transform3D(Basis.from_scale(p[1]), p[0]) * center)
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mats[key])
	return mesh
