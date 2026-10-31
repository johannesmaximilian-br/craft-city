class_name MapOverlay
extends MultiMeshInstance3D
## Karten-Ansichten: Verkehr, Verschmutzung, Bodenwert, Kriminalität, Zufriedenheit, ÖPNV, Strom.
## Taste V schaltet durch, Ansicht-Button oben wählt per Liste. Mit einem Dienst-Werkzeug in der Hand wird automatisch dessen
## Versorgung gezeigt (grün = versorgt, rot = nicht versorgt).

enum Mode { OFF, TRAFFIC, POLLUTION, LAND, CRIME, HAPPY, TRANSIT, POWER, RESOURCES }
const MODE_NAMES := ["", "Verkehr", "Verschmutzung", "Bodenwert", "Kriminalität", "Zufriedenheit", "ÖPNV", "Strom",
	"Rohstoffe"]
# Netzfarben (Strom-Ansicht); Rot bleibt für Gebäude ohne Strom reserviert
const NET_COLORS := [Color(0.3, 0.55, 1.0, 0.6), Color(0.3, 0.85, 0.4, 0.6), Color(0.75, 0.45, 1.0, 0.6),
	Color(0.2, 0.85, 0.85, 0.6), Color(1.0, 0.75, 0.2, 0.6), Color(0.95, 0.5, 0.8, 0.6)]
const BUS_ROUTE := Color(0.25, 0.55, 1.0, 0.75)
# Deckkraft-Faktor: Gelände/Straßen durchscheinend, Dächer etwas kräftiger (kleinere Fläche)
const GROUND_ALPHA := 0.30
const ROOF_ALPHA := 0.30

const B := Config.TILE_BLOCKS
const GREEN := Color(0.3, 0.85, 0.35, 0.7)
const YELLOW := Color(1.0, 0.8, 0.15, 0.75)
const RED := Color(0.9, 0.2, 0.15, 0.8)

var map: CityMap
var sim: Simulation
var mode := Mode.OFF
var service_cat := ""
var _roofs: MultiMeshInstance3D     # Einfärbung bebauter Tiles auf Dachhöhe (sonst im Gebäude versteckt)
# ungefähre Dachhöhe (Blöcke) je Zone und Stufe
const ROOF := [[0, 0, 0, 0, 0], [0, 2.0, 3.2, 6.5, 17.0], [0, 2.0, 5.0, 11.0, 22.0], [0, 3.0, 3.2, 4.2, 4.2]]          # gesetzt = Versorgungsansicht dieses Dienstes (hat Vorrang)


func setup(city_map: CityMap, simulation: Simulation) -> void:
	map = city_map
	sim = simulation
	var box := BoxMesh.new()
	box.size = Vector3(B - 0.2, 0.08, B - 0.2)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material = mat
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = box
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false
	var roof_box := BoxMesh.new()
	roof_box.size = Vector3(B - 0.4, 0.1, B - 0.4)
	var roof_mat := mat.duplicate() as StandardMaterial3D
	roof_mat.no_depth_test = true       # immer sichtbar, auch hinter höheren Nachbarn
	roof_box.material = roof_mat
	_roofs = MultiMeshInstance3D.new()
	_roofs.multimesh = MultiMesh.new()
	_roofs.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_roofs.multimesh.use_colors = true
	_roofs.multimesh.mesh = roof_box
	_roofs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_roofs)
	sim.traffic_changed.connect(_rebuild)


## 0 = gut (grün), 0.5 = gelb, 1 = schlecht (rot)
static func ramp(v: float) -> Color:
	v = clampf(v, 0.0, 1.0)
	return GREEN.lerp(YELLOW, v * 2.0) if v < 0.5 else YELLOW.lerp(RED, (v - 0.5) * 2.0)


static func color_for(cong: float) -> Color:
	return ramp(cong)


## Nächster Modus; gibt dessen Namen zurück ("" = aus).
func cycle() -> String:
	return set_mode((mode + 1) % Mode.size())


## Modus direkt wählen; gibt dessen Namen zurück ("" = aus).
func set_mode(m: int) -> String:
	mode = m as Mode
	visible = mode != Mode.OFF or service_cat != ""
	_rebuild()
	return MODE_NAMES[mode]


## Versorgungsansicht für ein Dienst-Werkzeug ein-/ausschalten ("" = aus).
func set_service(cat: String) -> void:
	service_cat = cat
	visible = cat != "" or mode != Mode.OFF
	_rebuild()


func _rebuild() -> void:
	if (mode == Mode.OFF and service_cat == "") or sim.land_value.size() != map.size * map.size:
		return
	var items: Array[int] = []
	var colors: Array[Color] = []
	var cov: PackedFloat32Array = sim.coverage.get(service_cat, PackedFloat32Array())
	for i in map.size * map.size:
		if service_cat == "transit":
			if map.road[i] != 0:
				if sim.bus_served.size() > i and sim.bus_served[i] == 1:
					items.append(i)
					colors.append(BUS_ROUTE)
			elif map.zone[i] != Config.Zone.NONE:
				items.append(i)
				colors.append(GREEN if sim.has_transit(i) else RED)
			continue
		if service_cat != "":
			if not map.is_water(i % map.size, i / map.size) and cov.size() > i:
				items.append(i)
				colors.append(ramp(1.0 - cov[i]))
			continue
		match mode:
			Mode.CRIME:
				if sim.crime.size() > i and map.level[i] > 0 and map.zone[i] != Config.Zone.NONE:
					items.append(i)
					colors.append(ramp(sim.crime[i] * 1.5))
			Mode.HAPPY:
				if sim.happiness.size() > i and map.level[i] > 0 and map.zone[i] == Config.Zone.RES:
					items.append(i)
					colors.append(ramp(1.0 - sim.happiness[i]))
			Mode.POWER:
				# Jedes Netz eigene Farbe, Gebäude ohne Strom rot, Kraftwerke weiß
				if sim.power_net.size() > i and sim.power_net[i] >= 0:
					var net: Dictionary = sim.power_nets[sim.power_net[i]]
					if int(net["demand"]) == 0 and int(net["plants"]) == 0:
						continue
					items.append(i)
					if sim.tile_power_use(i) > 0 and sim.powered[i] == 0:
						colors.append(RED)
					elif map.special[i] != Config.Special.NONE and int(Config.SPECIALS[map.special[i]]["power"]) > 0:
						colors.append(Color(1, 1, 1, 0.85))
					else:
						var c: Color = NET_COLORS[sim.power_net[i] % NET_COLORS.size()]
						colors.append(c)
			Mode.RESOURCES:
				# Abbau-Gebäude/Werke: grün mit Lieferweg, rot ohne; Vorkommen in Rohstoff-Farbe, Wald grün, erschöpft grau
				var a := map.anchor[i]
				if a >= 0 and (Config.SPECIALS[map.special[i]].has("produce") or Config.SPECIALS[map.special[i]].has("process")):
					items.append(i)
					colors.append(GREEN if sim.delivers(a) else RED)
				elif map.ore[i] != Config.Ore.NONE:
					items.append(i)
					if map.ore_amt[i] == 0:
						colors.append(Color(0.5, 0.5, 0.5, 0.5))
					else:
						var c: Color = Config.RESOURCES[Config.ORE_RESOURCE[map.ore[i]]]["color"]
						c.a = 0.55 + 0.45 * map.ore_amt[i] / 255.0
						colors.append(c)
				elif map.feature[i] == Config.Feature.TREE:
					items.append(i)
					colors.append(Color(0.2, 0.7, 0.25, 0.6))
			Mode.TRANSIT:
				# Straßen im Busnetz blau; Gebäude grün mit Bus-/Bahnanschluss, rot ohne
				if map.road[i] != 0:
					if sim.bus_served.size() > i and sim.bus_served[i] == 1:
						items.append(i)
						colors.append(BUS_ROUTE)
				elif map.zone[i] != Config.Zone.NONE:
					items.append(i)
					colors.append(GREEN if sim.has_transit(i) else RED)
			Mode.TRAFFIC:
				if map.road[i] != 0:
					items.append(i)
					colors.append(ramp(sim.congestion[i]))
			Mode.POLLUTION:
				if not map.is_water(i % map.size, i / map.size) and sim.pollution[i] > 0.05:
					items.append(i)
					colors.append(ramp(sim.pollution[i] / 6.0))
			Mode.LAND:
				if not map.is_water(i % map.size, i / map.size):
					items.append(i)
					# grün ab Stufe-3-Grenze, rot unter Stufe-2-Grenze
					var lo: float = Config.RES_MIN_LAND[2]
					var hi: float = Config.RES_MIN_LAND[3]
					colors.append(ramp(clampf((hi + 0.05 - sim.land_value[i]) / (hi - lo + 0.1), 0.0, 1.0)))
	# Boden-Tiles normal, bebaute Tiles (Gebäude, Sonderbau) auf Dachhöhe
	var ground: Array[int] = []
	var roofs: Array[int] = []
	for k in items.size():
		var i := items[k]
		if (map.zone[i] != Config.Zone.NONE and map.level[i] > 0) or map.special[i] != Config.Special.NONE:
			roofs.append(k)
		else:
			ground.append(k)
	multimesh.instance_count = ground.size()
	for g in ground.size():
		var k := ground[g]
		var i := items[k]
		var pos := Vector3((i % map.size) * B + B * 0.5, map.height[i] + 0.06, (i / map.size) * B + B * 0.5)
		multimesh.set_instance_transform(g, Transform3D(Basis(), pos))
		# Rohstoffe: Vorkommen sollen auch aus der Ferne auffallen -> kräftiger
		multimesh.set_instance_color(g, _tint(colors[k], 0.9 if mode == Mode.RESOURCES and service_cat == "" else GROUND_ALPHA))
	var rm := _roofs.multimesh
	rm.instance_count = roofs.size()
	for r in roofs.size():
		var k := roofs[r]
		var i := items[k]
		var top := 4.0 if map.special[i] != Config.Special.NONE else float(ROOF[map.zone[i]][map.level[i]])
		if map.villa[i] == 1 and map.level[i] == 3:
			top = 2.6
		var pos := Vector3((i % map.size) * B + B * 0.5, map.height[i] + top + 0.15, (i / map.size) * B + B * 0.5)
		rm.set_instance_transform(r, Transform3D(Basis(), pos))
		rm.set_instance_color(r, _tint(colors[k], ROOF_ALPHA))


## Instanzfarbe: sRGB -> linear (sonst blass) und Deckkraft reduzieren, damit die Stadt durchscheint.
static func _tint(c: Color, alpha: float) -> Color:
	var l := c.srgb_to_linear()
	l.a = c.a * alpha
	return l
