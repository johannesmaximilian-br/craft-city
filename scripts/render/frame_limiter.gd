class_name FrameLimiter
extends Node
## Stromsparen: begrenzt die Bildrate je nach Lage.
##   Fenster nicht im Vordergrund  -> BACKGROUND_FPS (Simulation läuft weiter)
##   Pause und Kamera ruht          -> PAUSED_FPS
##   sonst                          -> Grenze aus dem Menü (GraphicsSettings.fps_limit, 0 = unbegrenzt)
## Ohne Grenze zeichnet das Spiel so oft wie der Bildschirm kann (MacBook: 120 Hz) - doppelte Last.

const BACKGROUND_FPS := 10
const PAUSED_FPS := 30
const IDLE_AFTER := 1.0        # Sekunden ohne Kamerabewegung, bis Pause gedrosselt wird

var sim: Simulation
var cam: CityCamera
var _focused := true
var _idle := 0.0
var _last_cam := Transform3D()


func setup(simulation: Simulation, camera: CityCamera) -> void:
	sim = simulation
	cam = camera


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_focused = false
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_focused = true


func _process(delta: float) -> void:
	var xf := cam.camera.global_transform
	if xf.is_equal_approx(_last_cam):
		_idle += delta
	else:
		_idle = 0.0
	_last_cam = xf
	var limit := GraphicsSettings.fps_limit
	# Testläufe laufen oft im Hintergrund -> dort nicht drosseln (sonst falsche Messungen)
	if not _focused and not DevTools.automated:
		limit = BACKGROUND_FPS
	elif sim.speed == 0 and _idle > IDLE_AFTER:
		limit = PAUSED_FPS if limit == 0 else mini(limit, PAUSED_FPS)
	if Engine.max_fps != limit:
		Engine.max_fps = limit
