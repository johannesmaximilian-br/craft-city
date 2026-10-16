class_name CityCamera
extends Node3D
## RTS-Kamera:
## WASD/Pfeile = verschieben, Q/E = drehen, Mausrad = Zoom,
## Leertaste+Linksklick / mittlere Maus / Linksklick im Info-Modus = greifen & ziehen,
## rechte Maustaste = drehen/neigen. Zoom: Mausrad, +/- bzw. Bild auf/ab, Trackpad-Pinch, Cmd+Zwei-Finger-Wischen;
## Zwei-Finger-Wischen ohne Cmd verschiebt die Karte.

@export var pan_speed := 60.0
@export var min_dist := 12.0
@export var max_dist := 280.0     # 128er-Karte ganz überblicken

var camera: Camera3D
var bounds := Rect2(0, 0, 192, 192)
var left_drag_pans := true      # vom Werkzeug gesetzt (Info-Modus)

var _yaw := deg_to_rad(45.0)
var _pitch := deg_to_rad(-50.0)
var _dist := 70.0
var _target_yaw := _yaw
var _target_dist := _dist
var _drag_pan := false
var _drag_rot := false
var _focus := Vector3.INF       # Ziel eines Kamera-Sprungs (INF = keiner)


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.far = 1000.0
	add_child(camera)
	_apply()


func _process(delta: float) -> void:
	if DevTools.automated:
		_apply_focus(delta)
		_dist = lerpf(_dist, _target_dist, minf(1.0, delta * 10.0))
		_apply()
		return
	var input := Vector2(
		Input.get_axis("ui_left", "ui_right") + float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		Input.get_axis("ui_up", "ui_down") + float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	if input != Vector2.ZERO or _drag_pan:
		_focus = Vector3.INF
	_apply_focus(delta)
	if input != Vector2.ZERO:
		_pan(input.limit_length(1.0) * pan_speed * delta * (_dist / 70.0))
	# Zoom per Tastatur: + / - (auch Ziffernblock), Bild auf/ab
	var zoom_in := Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_PLUS) or Input.is_key_pressed(KEY_KP_ADD) \
		or Input.is_key_pressed(KEY_PAGEUP)
	var zoom_out := Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT) or Input.is_key_pressed(KEY_PAGEDOWN)
	if zoom_in != zoom_out:
		_zoom_by(pow(0.35, delta) if zoom_in else pow(1.0 / 0.35, delta))
	if Input.is_key_pressed(KEY_Q):
		_target_yaw += 1.5 * delta
	if Input.is_key_pressed(KEY_E):
		_target_yaw -= 1.5 * delta
	_yaw = lerp_angle(_yaw, _target_yaw, minf(1.0, delta * 10.0))
	_dist = lerpf(_dist, _target_dist, minf(1.0, delta * 10.0))
	_apply()
	_update_cursor()


func _update_cursor() -> void:
	var shape := Input.CURSOR_ARROW
	if _drag_pan:
		shape = Input.CURSOR_DRAG
	elif Input.is_key_pressed(KEY_SPACE):
		shape = Input.CURSOR_POINTING_HAND
	Input.set_default_cursor_shape(shape)


func _unhandled_input(event: InputEvent) -> void:
	if DevTools.automated and not event.has_meta("synthetic"):
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_by(0.88)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_by(1.12)
			MOUSE_BUTTON_MIDDLE:
				_drag_pan = mb.pressed
			MOUSE_BUTTON_LEFT:
				if mb.pressed and (Input.is_key_pressed(KEY_SPACE) or left_drag_pans):
					_drag_pan = true
				elif not mb.pressed:
					_drag_pan = false
			MOUSE_BUTTON_RIGHT:
				_drag_rot = mb.pressed
	elif event is InputEventMagnifyGesture:
		# Trackpad: Zwei-Finger-Zoom (Auseinanderziehen = näher)
		_zoom_by(1.0 / maxf((event as InputEventMagnifyGesture).factor, 0.01))
	elif event is InputEventPanGesture:
		# Trackpad: Zwei-Finger-Wischen verschiebt die Karte; mit Cmd/Strg zoomt es (wie Mausrad)
		var pg := event as InputEventPanGesture
		if pg.meta_pressed or pg.ctrl_pressed:
			_zoom_by(pow(1.04, pg.delta.y))
		else:
			_focus = Vector3.INF
			_pan(pg.delta * 0.6 * (_dist / 70.0))
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _drag_pan:
			_grab_pan(mm.position - mm.relative, mm.position)
		if _drag_rot:
			_target_yaw -= mm.relative.x * 0.006
			_pitch = clampf(_pitch - mm.relative.y * 0.004, deg_to_rad(-85.0), deg_to_rad(-20.0))


func _zoom_by(f: float) -> void:
	_target_dist = clampf(_target_dist * f, min_dist, max_dist)


func _apply_focus(delta: float) -> void:
	if _focus != Vector3.INF:
		position = position.lerp(_focus, minf(1.0, delta * 5.0))
		if position.distance_to(_focus) < 0.1:
			_focus = Vector3.INF


## Sanft zu einem Tile fahren (z.B. Brand), bei Bedarf etwas heranzoomen.
## height = Geländehöhe, damit das Ziel in Bildmitte landet.
func focus_tile(t: Vector2i, height: float) -> void:
	_focus = Vector3((t.x + 0.5) * Config.TILE_BLOCKS, height, (t.y + 0.5) * Config.TILE_BLOCKS)
	_target_dist = minf(_target_dist, 55.0)


## Weltpunkt unter der Maus bleibt unter der Maus.
func _grab_pan(from: Vector2, to: Vector2) -> void:
	var a: Variant = _ground_point(from)
	var b: Variant = _ground_point(to)
	if a == null or b == null:
		return
	position += (a as Vector3) - (b as Vector3)
	_clamp()


func _ground_point(screen: Vector2) -> Variant:
	var plane := Plane(Vector3.UP, position.y)
	return plane.intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))


func _pan(v: Vector2) -> void:
	var right := Vector3(cos(_yaw), 0, -sin(_yaw))
	var fwd := Vector3(sin(_yaw), 0, cos(_yaw))
	position += right * v.x + fwd * v.y
	_clamp()


func _clamp() -> void:
	position.x = clampf(position.x, bounds.position.x, bounds.end.x)
	position.z = clampf(position.z, bounds.position.y, bounds.end.y)


func _apply() -> void:
	rotation = Vector3(0, _yaw, 0)
	camera.position = Vector3(0, 0, _dist).rotated(Vector3.RIGHT, _pitch)
	camera.look_at(global_position, Vector3.UP)
