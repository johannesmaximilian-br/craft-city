class_name TrafficOverlay
extends MultiMeshInstance3D
## Karten-Ansichten: Verkehr, Verschmutzung, Bodenwert, Kriminalität, Zufriedenheit.
## Taste V schaltet durch, Ansicht-Button oben wählt per Liste. Mit einem Dienst-Werkzeug in der Hand wird automatisch dessen
## Versorgung gezeigt (grün = versorgt, rot = nicht versorgt).

enum Mode { OFF, TRAFFIC, POLLUTION, LAND, CRIME, HAPPY }
const MODE_NAMES := ["", "Verkehr", "Verschmutzung", "Bodenwert", "Kriminalität", "Zufriedenheit"]

const B := Config.TILE_BLOCKS
const GREEN := Color(0.3, 0.85, 0.35, 0.7)
const YELLOW := Color(1.0, 0.8, 0.15, 0.75)
const RED := Color(0.9, 0.2, 0.15, 0.8)

var map: CityMap
var sim: Simulation
var mode := Mode.OFF
var service_cat := ""          # gesetzt = Versorgungsansicht dieses Dienstes (hat Vorrang)


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
	multimesh.instance_count = items.size()
	for k in items.size():
		var i := items[k]
		var x := i % map.size
		var z := i / map.size
		var pos := Vector3(x * B + B * 0.5, map.height[i] + 0.06, z * B + B * 0.5)
		multimesh.set_instance_transform(k, Transform3D(Basis(), pos))
		multimesh.set_instance_color(k, colors[k])
