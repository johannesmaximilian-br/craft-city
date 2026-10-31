class_name DayNight
extends Node
## Sichtbarer Tag/Nacht-Zyklus (nur Optik, in Echtzeit unabhängig vom Spieltempo): Sonnenstand, Himmels- und
## Nebelfarbe, Umgebungslicht, nachts leuchtende Fenster. Die Nacht bleibt bewusst hell (Mondlicht, bläulich),
## damit sie beim Bauen nicht stört (Nutzerwunsch). Im Menü abschaltbar (GraphicsSettings.day_night) -> fester Mittag.
## Die Strom-Simulation rechnet Tag/Nacht unabhängig davon je Monat (Solar nur tagsüber, Speicher für die Nacht).

const CYCLE := 360.0                 # Sekunden für einen ganzen Tag
const SKY_TOP := [Color(0.35, 0.6, 0.95), Color(0.1, 0.14, 0.3)]          # [Tag, Nacht]
const SKY_HORIZON := [Color(0.75, 0.85, 0.95), Color(0.24, 0.3, 0.46)]
const SUNSET := Color(1.0, 0.62, 0.35)

static var time := 0.42              # 0 = Mitternacht, 0.25 Sonnenaufgang, 0.5 Mittag, 0.75 Sonnenuntergang
static var daylight := 1.0           # 0 Nacht .. 1 Tag (für andere Effekte)

var sun: DirectionalLight3D
var env: Environment
var sky: ProceduralSkyMaterial
var window_mat: StandardMaterial3D
var frozen := false                  # Testläufe: feste Uhrzeit (Screenshots vergleichbar)


func setup(light: DirectionalLight3D, environment: Environment, lib: BlockLibrary) -> void:
	sun = light
	env = environment
	sky = env.sky.sky_material as ProceduralSkyMaterial
	# Fenster (Glasblock "ice"): Leuchten immer aktiv, nur die Stärke ändert sich -> kein Shader-Neukompilieren
	var mesh: Mesh = lib.meshes.get("ice")
	if mesh != null and mesh.get_surface_count() > 0:
		window_mat = mesh.surface_get_material(0) as StandardMaterial3D
		if window_mat != null:
			window_mat.emission_enabled = true
			window_mat.emission = Color(1.0, 0.78, 0.42)
			window_mat.emission_energy_multiplier = 0.0
	_apply()


func _process(dt: float) -> void:
	if GraphicsSettings.day_night and not frozen:
		time = fmod(time + dt / CYCLE, 1.0)
	_apply()


func _apply() -> void:
	var t := time if GraphicsSettings.day_night else 0.42
	var h := sin((t - 0.25) * TAU)                       # Sonnenhöhe -1..1
	daylight = smoothstep(-0.2, 0.3, h)
	var dusk := clampf(1.0 - absf(h) * 3.0, 0.0, 1.0) * (1.0 if h > -0.25 else 0.0)   # Morgen-/Abendrot
	if h > 0.0:
		# Sonne wandert von Ost nach West, Höhe 12..60 Grad
		sun.rotation_degrees = Vector3(-lerpf(12.0, 60.0, h), -35.0 + (t - 0.5) * 140.0, 0)
	else:
		sun.rotation_degrees = Vector3(-45.0, 20.0, 0)       # Mond: feste Richtung, damit Schatten nicht springen
	var day_col := Color(1.0, 0.97, 0.92).lerp(SUNSET, dusk * 0.8)
	sun.light_color = Color(0.62, 0.72, 1.0).lerp(day_col, daylight)
	sun.light_energy = lerpf(0.42, 1.1, daylight)
	env.ambient_light_energy = lerpf(0.48, 0.6, daylight)
	var top: Color = (SKY_TOP[1] as Color).lerp(SKY_TOP[0], daylight)
	var hor: Color = (SKY_HORIZON[1] as Color).lerp(SKY_HORIZON[0], daylight).lerp(SUNSET, dusk * 0.5)
	sky.sky_top_color = top
	sky.sky_horizon_color = hor
	sky.ground_horizon_color = hor
	env.fog_light_color = hor
	if window_mat != null:
		window_mat.emission_energy_multiplier = (1.0 - daylight) * 1.4
