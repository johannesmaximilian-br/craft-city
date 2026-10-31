class_name SplashArt
extends CanvasLayer
## Startbild (nur für die Erzeugung von assets/app/splash.png, Flag --splash[=stil]):
## 3D-Logo aus echten Spielblöcken (Pixel-Schrift, Minecraft-Stil) über der Stadt, schwebende Spielblöcke ums Logo,
## Tilt-Shift-Unschärfe der Stadt (Miniatur-Look), weicher Lichthof, Vignette, Funkeln und ein Schriftband.
## Stile: brick (Ziegel, Standard – Nutzerwahl), grass (Gras/Erde), stone (Stein + Gold). Nutzer: Farbwürfel/Strahlen passten nicht.

const GLYPHS := {          # 5x7, "#" = Block
	"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"I": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####"],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
}

var style := "brick"
var _logo_vp: SubViewport
var _rng := RandomNumberGenerator.new()


func setup(lib: BlockLibrary, kind: String, city_cam: Camera3D) -> void:
	style = kind if kind in ["grass", "stone", "brick"] else "brick"
	# Tilt-Shift: Stadt nah (unten) und fern (oben) unscharf, Mitte scharf -> wirkt wie ein Miniaturmodell
	var attr := CameraAttributesPractical.new()
	attr.dof_blur_near_enabled = true
	attr.dof_blur_near_distance = 55.0
	attr.dof_blur_near_transition = 25.0
	attr.dof_blur_far_enabled = true
	attr.dof_blur_far_distance = 95.0
	attr.dof_blur_far_transition = 45.0
	attr.dof_blur_amount = 0.14
	city_cam.attributes = attr
	layer = 10
	_rng.seed = 7
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var art := _Art.new()
	art.owner_art = self
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(art)
	# 3D-Logo in eigener Szene rendern und mittig einblenden
	_logo_vp = _render_logo(lib)
	var shadow := TextureRect.new()           # dunkler Schlagschatten hebt das Logo von der Stadt ab
	shadow.texture = _logo_vp.get_texture()
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shadow.modulate = Color(0.05, 0.03, 0.1, 0.65)
	shadow.anchor_left = 0.03
	shadow.anchor_right = 0.97
	shadow.anchor_top = 0.08
	shadow.anchor_bottom = 0.64
	shadow.offset_left = 14
	shadow.offset_right = 14
	shadow.offset_top = 16
	shadow.offset_bottom = 16
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shadow)
	var tr := TextureRect.new()
	tr.texture = _logo_vp.get_texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.anchor_left = 0.03
	tr.anchor_right = 0.97
	tr.anchor_top = 0.08
	tr.anchor_bottom = 0.64
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tr)
	# Schriftband unter dem Logo
	var band := PanelContainer.new()
	band.add_theme_stylebox_override("panel", UiTheme.card(12, 12, Color("ffcc33"), UiTheme.PANEL_EDGE))
	band.anchor_left = 0.5
	band.anchor_right = 0.5
	band.anchor_top = 0.68
	band.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(band)
	var l := Label.new()
	l.text = "BAUE DEINE BLOCKSTADT!"
	l.add_theme_font_override("font", UiTheme.font(true))
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", UiTheme.TEXT)
	band.add_child(l)
	band.rotation_degrees = -2.0


## Logo als BlockBatch in eigener SubViewport-Welt, Kamera leicht von unten (wirkt mächtig).
func _render_logo(lib: BlockLibrary) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(1800, 640)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.82, 0.9)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.25
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	vp.add_child(sun)
	var b := BlockBatch.new(lib)
	var width := _build_text(b, "CUBE CITY")
	_floating_blocks(b, width)
	vp.add_child(b.build("Logo"))
	var cam := Camera3D.new()
	cam.fov = 30
	var center := Vector3(width * 0.5, 7.0, -1.0)
	cam.look_at_from_position(center + Vector3(0.0, 24.0, 94.0), center, Vector3.UP)    # leicht von oben: Oberseiten sichtbar
	vp.add_child(cam)
	return vp


## Ein paar echte Spielblöcke schweben schräg ums Logo (statt flacher Farbwürfel).
func _floating_blocks(b: BlockBatch, width: float) -> void:
	var spots := [Vector3(-9, 12, 2), Vector3(-6, 0, 5), Vector3(width + 6, 13, 1), Vector3(width + 7, 1, 4),
		Vector3(width * 0.47, 19.5, -2), Vector3(width * 0.25, -5, 6), Vector3(width * 0.75, -4.5, 5)]
	var keys := ["brick", "ice", "yellowbrick", "greybrick", "ice", "yellowbrick", "brick"]
	if style == "grass":
		keys = ["grass", "stone", "gold_block", "grass", "dirt", "gold_block", "stone"]
	for k in spots.size():
		var axis := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
		var sc := _rng.randf_range(3.0, 4.2)
		b.put_xf(keys[k], Transform3D(Basis(axis, _rng.randf_range(0.4, 1.0)).scaled(Vector3.ONE * sc), spots[k]))


## Text aus Blöcken setzen: je Glyph-Pixel eine Säule 2 Blöcke tief; Rückgabe: Breite in Blöcken.
func _build_text(b: BlockBatch, text: String) -> float:
	var x := 0
	var li := 0
	for ch in text:
		if ch == " ":
			x += 8
			continue
		var g: Array = GLYPHS[ch]
		for row in 7:
			var line: String = g[row]
			for col in 5:
				if line[col] != "#":
					continue
				var top := row == 0 or (g[row - 1] as String)[col] != "#"
				for sy in 2:                      # jedes Glyph-Pixel = 2x2 Blöcke, 3 tief -> kräftige Striche
					for sx in 2:
						var y := (6 - row) * 2 + sy
						for z in 3:
							b.put(_block(top and sy == 1, y, li), Vector3(x + col * 2 + sx, y, -z))
		x += 12
		li += 1
	return x - 2.0


func _block(top: bool, y: int, letter: int) -> String:
	match style:
		"grass":
			return "grass" if top else ("dirt" if y > 3 else "stone")
		"stone":
			return "gold_block" if top else ("stone" if (y / 2 + letter) % 3 != 0 else "greybrick")
		_:
			if top:
				return "snow"
			return ["brick", "yellowbrick", "brick", "yellowbrick", "greybrick", "brick", "yellowbrick", "greybrick"][letter % 8]


## Zeichenfläche: Strahlenkranz, Vignette, Konfetti-Würfel, Funkeln.
class _Art extends Control:
	var owner_art: SplashArt

	func _draw() -> void:
		var s := size
		var c := Vector2(s.x * 0.5, s.y * 0.38)
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.06, 0.08, 0.22, 0.28))      # Stadt etwas abdunkeln
		# weicher Lichthof hinter dem Logo
		for k in 12:
			draw_circle(c, s.y * (0.42 - k * 0.03), Color(1.0, 0.92, 0.7, 0.035))
		# Vignette: dunkle Ränder
		for k in 18:
			var t := float(k) / 18.0
			var inset := t * s.y * 0.22
			draw_rect(Rect2(Vector2(inset, inset), s - Vector2(inset, inset) * 2.0), Color(0.03, 0.04, 0.15, 0.09 * (1.0 - t)), false,
				s.y * 0.012)
		# Funkeln
		for k in 12:
			var p := Vector2(rng.randf_range(0.12, 0.88) * s.x, rng.randf_range(0.08, 0.62) * s.y)
			var l := rng.randf_range(6.0, 16.0)
			var col := Color(1, 1, 0.85, 0.9)
			draw_rect(Rect2(p - Vector2(l, 1.5), Vector2(l * 2, 3)), col)
			draw_rect(Rect2(p - Vector2(1.5, l), Vector2(3, l * 2)), col)
			draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(1, 1, 1))
