class_name IconFactory
extends Node
## Rendert HUD-Icons aus den Kit-Modellen (gleiches Licht, gleicher Look wie die Welt).
## Jedes Icon = eigener SubViewport, einmalig gerendert, Textur bleibt live nutzbar.

const SIZE := 128

# Voxel-Symbole aus abgerundeten Kit-Blöcken ("X" = Block)
const VOXELS := {
	"bolt": [
		"...XXX",
		"..XXX.",
		"..XX..",
		".XXXXX",
		"XXXXX.",
		"...XX.",
		"..XX..",
		"..X...",
		".X....",
	],
	"arrow_up": ["..X..", ".XXX.", "XXXXX", ".XXX.", ".XXX."],
	"arrow_down": [".XXX.", ".XXX.", "XXXXX", ".XXX.", "..X.."],
	"info": [".X.", "...", "XX.", ".X.", ".X.", "XXX"],
	"bell": ["..X..", ".XXX.", ".XXX.", ".XXX.", "XXXXX", ".....", "..X.."],
	"happy": [".XXXXX.", "XXXXXXX", "XXXXXXX", "XXXXXXX", "XXXXXXX", "XXXXXXX", ".XXXXX."],
	"happy_eyes": [".......", "..X.X..", "..X.X..", ".......", ".X...X.", "..XXX..", "......."],
	"pause": ["XX.XX", "XX.XX", "XX.XX", "XX.XX", "XX.XX", "XX.XX"],
	"play": ["X...", "XX..", "XXX.", "XXXX", "XXX.", "XX..", "X..."],
	"fast": ["X..X..", "XX.XX.", "XXXXXX", "XX.XX.", "X..X.."],
	"stats": ["....X", "....X", "..X.X", "..X.X", "X.X.X", "X.X.X", "XXXXX"],
	"fastest": ["X..X..X..", "XX.XX.XX.", "XXXXXXXXX", "XX.XX.XX.", "X..X..X.."],
}

const SERVICE_ICONS := {
	"police": Config.Special.POLICE, "fire": Config.Special.FIRE, "school": Config.Special.SCHOOL,
	"hospital": Config.Special.HOSPITAL, "library": Config.Special.LIBRARY,
	"cinema": Config.Special.CINEMA, "townhall": Config.Special.TOWNHALL,
	"theater": Config.Special.THEATER, "stadium": Config.Special.STADIUM,
	"lumber": Config.Special.LUMBER, "quarry": Config.Special.QUARRY, "pit": Config.Special.PIT,
	"mine": Config.Special.MINE, "warehouse": Config.Special.WAREHOUSE,
	"sawmill": Config.Special.SAWMILL, "brickworks": Config.Special.BRICKWORKS,
	"glassworks": Config.Special.GLASSWORKS, "steelworks": Config.Special.STEELWORKS,
	"nursery": Config.Special.NURSERY, "prospector": Config.Special.PROSPECTOR, "recycler": Config.Special.RECYCLER,
	"university": Config.Special.UNIVERSITY, "institute": Config.Special.INSTITUTE,
	"biomass": Config.Special.BIOMASS, "solar": Config.Special.SOLAR, "battery": Config.Special.BATTERY,
	"hydro": Config.Special.HYDRO, "pumped": Config.Special.PUMPED, "salt": Config.Special.SALT,
}

var lib: BlockLibrary
var _icons := {}


func setup(library: BlockLibrary) -> void:
	lib = library


func get_icon(icon_name: String) -> Texture2D:
	if not _icons.has(icon_name):
		_icons[icon_name] = _render(icon_name)
	return _icons[icon_name]


# ---------------------------------------------------------------- Szeneninhalt

## App-Icon (1024 px): Mini-Insel aus der Stadt auf blauem, abgerundetem Grund.
func render_app_icon(path: String) -> void:
	var tex := _render("app", 1024)
	for k in 4:
		await get_tree().process_frame
	var fg := tex.get_image()
	var img := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	var top := Color("8fd0ff")
	var bottom := Color("3a8fd9")
	var r := 180.0          # Eckenradius (macOS-typisch ~ 18 %)
	var m := 40.0           # Rand
	for y in 1024:
		var col := top.lerp(bottom, float(y) / 1023.0)
		for x in 1024:
			var dx := maxf(maxf(m + r - x, x - (1023.0 - m - r)), 0.0)
			var dy := maxf(maxf(m + r - y, y - (1023.0 - m - r)), 0.0)
			var inside := x >= m and x <= 1023.0 - m and y >= m and y <= 1023.0 - m and dx * dx + dy * dy <= r * r
			img.set_pixel(x, y, col if inside else Color(0, 0, 0, 0))
	img.blend_rect(fg, Rect2i(0, 0, 1024, 1024), Vector2i(0, 0))
	img.save_png(path)


func _content(icon_name: String) -> Node3D:
	var b := BlockBatch.new(lib)
	var root := Node3D.new()
	match icon_name:
		"road":
			_ground(b, 3, "asphalt")
			for z in 3:
				b.put("marking", Vector3(1, 1, z))
		"bus_stop":
			_ground(b, 3, "asphalt")
			StructureGenerator.bus_stop(b, Vector3(0.6, 1, 0.6))
			var bus := MeshInstance3D.new()
			bus.mesh = lib.bus_mesh()
			bus.set_surface_override_material(0, BlockLibrary.flat_material(Color("ffc21a")))
			bus.position = Vector3(1.6, 1.0, 2.0)
			root.add_child(bus)
		"rail":
			_ground(b, 3, "stone")
			StructureGenerator.rail(b, Vector3(1.5, 1.01, 1.5), [Vector2i(0, 1), Vector2i(0, -1)])
		"station":
			_ground(b, 3, "stone")
			StructureGenerator.rail(b, Vector3(1.5, 1.01, 1.5), [Vector2i(1, 0), Vector2i(-1, 0)])
			StructureGenerator.station(b, Vector3(0, 1, 0), true)
		"bus":
			var bus := MeshInstance3D.new()
			bus.mesh = lib.bus_mesh()
			bus.set_surface_override_material(0, BlockLibrary.flat_material(Color("ffc21a")))
			bus.rotation.y = -0.3
			root.add_child(bus)
		"powerline":
			_ground(b, 3)
			StructureGenerator.pole(b, Vector3(1.5, 1, 1.5), PI * 0.5)
			var top := Vector3(1.5, 1 + StructureGenerator.POLE_HEIGHT, 1.5)
			b.segment("coal", top, top + Vector3(0, -0.4, 2.2), 0.08)
			b.segment("coal", top, top + Vector3(0, -0.4, -2.2), 0.08)
		"res", "com", "ind":
			_ground(b, 3)
			b.base = Vector3(0, 1, 0)
			var zone: int = {"res": Config.Zone.RES, "com": Config.Zone.COM, "ind": Config.Zone.IND}[icon_name]
			BuildingGenerator.emit(zone, 2, 7, b.put_local, b.prop_local)
		"app":
			# Insel 9x9 Blöcke: Gras + Erdschicht, Hochhaus, Haus, Fabrik, Bäume, Straße
			for z in 9:
				for x in 9:
					b.put("dirt", Vector3(x, 0, z))
					b.put("grass" if not (z == 4) else "asphalt", Vector3(x, 1, z))
			b.base = Vector3(0, 2, 0)
			BuildingGenerator.emit(Config.Zone.COM, 2, 3, b.put_local, b.prop_local)
			b.base = Vector3(6, 2, 0)
			BuildingGenerator.emit(Config.Zone.RES, 2, 5, b.put_local, b.prop_local)
			b.base = Vector3(6, 2, 6)
			BuildingGenerator.emit(Config.Zone.RES, 3, 9, b.put_local, b.prop_local)
			b.put_prop("tree1", Vector3(1.5, 2, 7.5), 0.4)
			b.put_prop("tree2", Vector3(3.6, 2, 6.4), 1.3)
			b.put_prop("bush", Vector3(4.5, 2, 1.5), 0.0)
			for x in 9:
				b.put("marking", Vector3(x + 0.375, 2.0, 4.375))
		"res_wood", "res_stone", "res_sand", "res_clay", "res_coal", "res_iron", "res_gold", \
				"res_planks", "res_bricks", "res_glass", "res_steel":
			# Rohstoff-Symbol: ein Block des Materials
			b.put({"res_wood": "log", "res_stone": "stone", "res_sand": "sand", "res_clay": "clay", "res_coal": "coal",
				"res_iron": "iron_block", "res_gold": "gold_block", "res_planks": "wood", "res_bricks": "brick",
				"res_glass": "ice", "res_steel": "metal"}[icon_name], Vector3.ZERO)
		"coal":
			_ground(b, 6)
			StructureGenerator.coal(b, Vector3(0, 1, 0))
		"police", "fire", "school", "hospital", "library", "cinema", "townhall", "theater", "stadium", \
				"lumber", "quarry", "pit", "mine", "warehouse", "sawmill", "brickworks", "glassworks", "steelworks", \
				"nursery", "prospector", "recycler", "university", "institute", "biomass", "solar", "battery", "hydro", "pumped", "salt":
			var sp: int = SERVICE_ICONS[icon_name]
			var s: int = Config.SPECIALS[sp]["size"] * Config.TILE_BLOCKS
			_ground(b, s)
			StructureGenerator.service(b, Vector3(0, 1, 0), sp, 1)
		"happy":
			var face := _voxel(VOXELS["happy"], "vox_yellow", 1.0)
			face.rotation.y = 0.35
			root.add_child(face)
			var eyes := _voxel(VOXELS["happy_eyes"], "vox_dark", 1.0)
			eyes.position = Vector3(0, 0, 0.35)
			face.add_child(eyes)
		"wind":
			_ground(b, 3)
			StructureGenerator.wind_tower(b, Vector3(0, 1, 0))
			var hub := StructureGenerator.wind_hub(Vector3(0, 1, 0))
			for k in 3:
				var ang := 0.3 + k * TAU / 3.0
				b.segment("concrete", hub, hub + Vector3(cos(ang), sin(ang), 0) * 2.8, 0.3)
		"tree":
			_ground(b, 3)
			b.put_prop("tree1", Vector3(1.5, 1, 1.5), 0.4)
		"park":
			_ground(b, 3)
			b.put_prop("tree2", Vector3(1.5, 1, 1.5), 0.0)
			b.put_prop("flowers1", Vector3(0.5, 1, 2.5), 0.0, 1.4)
			b.put_prop("bush", Vector3(2.5, 1, 2.5), 0.0, 1.3)
		"raise", "lower":
			_ground(b, 3)
			var up := icon_name == "raise"
			var arrow := _voxel(VOXELS["arrow_up" if up else "arrow_down"], "vox_green" if up else "vox_red", 0.55)
			arrow.position = Vector3(1.5, 3.0, 1.5)
			arrow.rotation.y = PI * 0.25
			root.add_child(arrow)
		"bulldoze":
			b.put_prop("pickaxe", Vector3.ZERO, 0.0)
			root.rotation = Vector3(0, 0, 0.6)
		"money":
			b.put_prop("chest", Vector3.ZERO, -0.5)
		"jobs":
			b.put("crate", Vector3.ZERO)
		"car":
			var car := MeshInstance3D.new()
			car.mesh = lib.car_mesh()
			car.set_surface_override_material(0, BlockLibrary.flat_material(Color("e0503c")))
			car.rotation.y = -0.3
			root.add_child(car)
		"people":
			var ch := (load("res://assets/characters/Character_Male_1.gltf") as PackedScene).instantiate()
			BlockLibrary.fix_node_materials(ch)
			_pose(ch)
			ch.rotation.y = -0.4
			root.add_child(ch)
		_:
			if VOXELS.has(icon_name):
				var key := "vox_yellow" if icon_name == "bolt" else ("vox_blue" if icon_name == "info" else "vox_dark")
				var v := _voxel(VOXELS[icon_name], key, 1.0)
				v.rotation.y = 0.35
				root.add_child(v)
	if not b.buckets.is_empty():
		root.add_child(b.build())
	return root


func _ground(b: BlockBatch, n: int, top := "grass") -> void:
	for z in n:
		for x in n:
			b.put(top, Vector3(x, 0, z))


func _voxel(rows: Array, key: String, size: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = lib.voxel_mesh(rows, key, size)
	return mi


## Idle-Pose statt T-Pose, falls Animationen vorhanden.
func _pose(n: Node) -> void:
	var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		return
	for a in ap.get_animation_list():
		if a.to_lower().contains("idle"):
			ap.play(a)
			ap.seek(0.2, true)
			ap.pause()
			return


# ---------------------------------------------------------------- Rendern

func _render(icon_name: String, px := SIZE) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.9)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.2
	vp.add_child(sun)

	var content := _content(icon_name)
	vp.add_child(content)

	# Isometrische Ortho-Kamera, auf Inhalt gerahmt
	var aabb := _aabb(content, Transform3D())
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	var dir := Vector3(1, 0.8, 1).normalized()
	var center := aabb.get_center()
	cam.look_at_from_position(center + dir * 50.0, center, Vector3.UP)
	cam.size = _ortho_size(aabb, cam.global_transform) * 1.08
	return vp.get_texture()


## Benötigte Ortho-Höhe, damit alle AABB-Ecken ins (quadratische) Bild passen.
func _ortho_size(aabb: AABB, cam_xf: Transform3D) -> float:
	var inv := cam_xf.affine_inverse()
	var m := 0.0
	for k in 8:
		var p := inv * aabb.get_endpoint(k)
		m = maxf(m, maxf(absf(p.x), absf(p.y)))
	return m * 2.0


func _aabb(n: Node, parent_xf: Transform3D) -> AABB:
	var xf := parent_xf
	if n is Node3D:
		xf = parent_xf * (n as Node3D).transform
	var box := AABB()
	var has := false
	if n is MultiMeshInstance3D:
		box = xf * (n as MultiMeshInstance3D).multimesh.get_aabb()
		has = true
	elif n is MeshInstance3D and (n as MeshInstance3D).mesh:
		box = xf * (n as MeshInstance3D).mesh.get_aabb()
		has = true
	for c in n.get_children():
		var cb := _aabb(c, xf)
		if cb.size != Vector3.ZERO:
			box = cb if not has else box.merge(cb)
			has = true
	return box
