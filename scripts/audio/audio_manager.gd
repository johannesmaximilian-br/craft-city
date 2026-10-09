extends Node
## Autoload "Audio": Musik (Playlist mit Pausen), Effekte, Umgebungsgeräusche.
## Alle Klänge sind vorab erzeugte Dateien (tools/audio/gen_audio.py), hier wird nur abgespielt.
##
## Verkehr/Industrie: kleiner Pool 3D-Quellen, die alle paar Zehntelsekunden an die
## lautesten Straßen/Fabriken nahe dem Kamerafokus wandern. Nah gezoomt hörbar, weit weg still.

const MUSIC := [
	"res://assets/audio/music/morgentau.mp3",
	"res://assets/audio/music/schornsteine.mp3",
	"res://assets/audio/music/gruenflaechen.mp3",
	"res://assets/audio/music/abendrot.mp3",
]
const MUSIC_GAP := Vector2(25.0, 70.0)      # Stille zwischen Stücken (Sekunden)
const SFX_NAMES := ["click", "place", "zone", "bulldoze", "error", "notify"]
const SETTINGS_PATH := "user://settings.cfg"

const TRAFFIC_VOICES := 4
const INDUSTRY_VOICES := 3
const SCAN_RADIUS := 14                     # Tiles um den Kamerafokus
const UPDATE_INTERVAL := 0.3
const ZOOM_NEAR := 25.0                     # Kameradistanz: voll hörbar
const ZOOM_FAR := 110.0                     # Kameradistanz: still

var volumes := {"Music": 0.6, "SFX": 0.8, "Ambient": 0.8}
var music_muted := false

var _music: AudioStreamPlayer
var _music_bag: Array = []
var _music_wait := 3.0
var _sfx := {}
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _wind: AudioStreamPlayer
var _birds: AudioStreamPlayer
var _traffic: Array[AudioStreamPlayer3D] = []
var _industry: Array[AudioStreamPlayer3D] = []
var _scan_timer := 0.0

var map: CityMap
var sim: Simulation
var cam: CityCamera


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_load_settings()
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.finished.connect(func(): _music_wait = randf_range(MUSIC_GAP.x, MUSIC_GAP.y))
	add_child(_music)
	for n: String in SFX_NAMES:
		_sfx[n] = load("res://assets/audio/sfx/%s.wav" % n)
	for k in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)


## Vom Spiel aufgerufen, sobald Welt und Kamera existieren.
func setup(city_map: CityMap, simulation: Simulation, camera: CityCamera) -> void:
	map = city_map
	sim = simulation
	cam = camera
	_wind = _bed("wind")
	_birds = _bed("birds")
	for k in TRAFFIC_VOICES:
		_traffic.append(_voice("traffic", 9.0))
	for k in INDUSTRY_VOICES:
		_industry.append(_voice("industry", 11.0))


func _setup_buses() -> void:
	for bus: String in volumes:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")
	# Etwas Raum für die Umgebung
	var amb := AudioServer.get_bus_index("Ambient")
	if AudioServer.get_bus_effect_count(amb) == 0:
		var rev := AudioEffectReverb.new()
		rev.room_size = 0.5
		rev.wet = 0.12
		rev.dry = 1.0
		AudioServer.add_bus_effect(amb, rev)


func _loop_stream(path: String) -> AudioStreamWAV:
	var s: AudioStreamWAV = (load(path) as AudioStreamWAV).duplicate()
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate)
	return s


func _bed(name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _loop_stream("res://assets/audio/ambient/%s.wav" % name)
	p.bus = "Ambient"
	p.volume_db = -80.0
	add_child(p)
	p.play()
	return p


func _voice(name: String, unit_size: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = _loop_stream("res://assets/audio/ambient/%s.wav" % name)
	p.bus = "Ambient"
	p.unit_size = unit_size
	p.max_distance = 90.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.volume_db = -80.0
	p.set_meta("gain", 0.0)
	add_child(p)
	p.play(randf() * p.stream.get_length())   # versetzt starten, kein Gleichklang
	return p


# ---------------------------------------------------------------- Öffentliche API

func sfx(name: String, pitch_var := 0.08, volume_db := 0.0) -> void:
	if not _sfx.has(name):
		return
	var p := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	p.stream = _sfx[name]
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.volume_db = volume_db
	p.play()


func set_volume(bus: String, v: float) -> void:
	volumes[bus] = clampf(v, 0.0, 1.0)
	_apply_volume(bus)
	_save_settings()


func toggle_music_mute() -> void:
	music_muted = not music_muted
	_apply_volume("Music")
	_save_settings()


func _apply_volume(bus: String) -> void:
	var idx := AudioServer.get_bus_index(bus)
	var v: float = volumes[bus]
	var mute := v <= 0.001 or (bus == "Music" and music_muted)
	AudioServer.set_bus_mute(idx, mute)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for bus: String in volumes:
			volumes[bus] = cfg.get_value("audio", bus, volumes[bus])
		music_muted = cfg.get_value("audio", "music_muted", false)
	for bus: String in volumes:
		_apply_volume(bus)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	for bus: String in volumes:
		cfg.set_value("audio", bus, volumes[bus])
	cfg.set_value("audio", "music_muted", music_muted)
	cfg.save(SETTINGS_PATH)


# ---------------------------------------------------------------- Laufzeit

func _process(delta: float) -> void:
	_update_music(delta)
	if cam == null:
		return
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = UPDATE_INTERVAL
		_scan_sources()
	_smooth_voices(_traffic, delta)
	_smooth_voices(_industry, delta)


func _update_music(delta: float) -> void:
	if _music.playing:
		return
	_music_wait -= delta
	if _music_wait > 0.0:
		return
	if _music_bag.is_empty():
		_music_bag = MUSIC.duplicate()
		_music_bag.shuffle()
	var t := Perf.begin()
	_music.stream = load(_music_bag.pop_back())
	Perf.end("audio.musik_laden", t)
	t = Perf.begin()
	_music.volume_db = -30.0
	_music.play()
	create_tween().tween_property(_music, "volume_db", 0.0, 4.0)
	Perf.end("audio.musik_start", t)
	_music_wait = 1e9


## 1 = ganz nah, 0 = weit weg
func _zoom_near() -> float:
	return clampf(inverse_lerp(ZOOM_FAR, ZOOM_NEAR, cam._dist), 0.0, 1.0)


func _scan_sources() -> void:
	var B := Config.TILE_BLOCKS
	var near := _zoom_near()
	var cx := floori(cam.position.x / B)
	var cz := floori(cam.position.z / B)
	var traffic_c: Array = []
	var industry_c: Array = []
	var trees := 0
	for z in range(cz - SCAN_RADIUS, cz + SCAN_RADIUS + 1):
		for x in range(cx - SCAN_RADIUS, cx + SCAN_RADIUS + 1):
			if not map.in_bounds(x, z):
				continue
			var i := map.idx(x, z)
			var d2 := float((x - cx) * (x - cx) + (z - cz) * (z - cz))
			var falloff := 1.0 / (1.0 + d2 * 0.04)
			if map.road[i] != 0 and sim.traffic.size() > i and sim.traffic[i] > 0.0:
				var s := minf(sim.traffic[i] / 120.0, 1.5)
				traffic_c.append([s * falloff, Vector2i(x, z), s])
			elif map.zone[i] == Config.Zone.IND and map.level[i] > 0:
				var s := map.level[i] / 3.0
				industry_c.append([s * falloff, Vector2i(x, z), s])
			elif map.special[i] == Config.Special.COAL:
				industry_c.append([1.5 * falloff, Vector2i(x, z), 1.5])
			if d2 < 64.0 and (map.feature[i] != Config.Feature.NONE):
				trees += 1
	# Verkehr verstummt bei Pause (Autos stehen)
	var traffic_gain := near * (1.0 if sim.speed > 0 else 0.0)
	_assign(_traffic, _pick(traffic_c, TRAFFIC_VOICES, 4), traffic_gain)
	_assign(_industry, _pick(industry_c, INDUSTRY_VOICES, 3), near)
	# Betten: Wind lauter mit Höhe, Vögel nah über Grün
	_fade(_wind, lerpf(0.12, 0.5, 1.0 - near))
	_fade(_birds, near * clampf(trees / 30.0, 0.0, 1.0) * 0.7)


## Beste Kandidaten mit Mindestabstand (in Tiles) auswählen.
func _pick(cands: Array, count: int, spacing: int) -> Array:
	cands.sort_custom(func(a, b): return a[0] > b[0])
	var out: Array = []
	for c in cands:
		var ok := true
		for o in out:
			var d: Vector2i = (o[1] as Vector2i) - (c[1] as Vector2i)
			if absi(d.x) + absi(d.y) < spacing:
				ok = false
				break
		if ok:
			out.append(c)
			if out.size() >= count:
				break
	return out


func _assign(voices: Array[AudioStreamPlayer3D], picks: Array, gain: float) -> void:
	var B := Config.TILE_BLOCKS
	for k in voices.size():
		var p := voices[k]
		if k < picks.size():
			var t: Vector2i = picks[k][1]
			var pos := Vector3(t.x * B + B * 0.5, map.h(t.x, t.y) + 1.0, t.y * B + B * 0.5)
			# Stumme Stimmen springen, hörbare gleiten
			if p.get_meta("gain") < 0.01:
				p.global_position = pos
			p.set_meta("target_pos", pos)
			p.set_meta("target", clampf(picks[k][2], 0.15, 1.0) * gain)
		else:
			p.set_meta("target", 0.0)


func _smooth_voices(voices: Array[AudioStreamPlayer3D], delta: float) -> void:
	for p in voices:
		var g: float = move_toward(p.get_meta("gain"), p.get_meta("target", 0.0), delta * 0.8)
		p.set_meta("gain", g)
		p.volume_db = linear_to_db(maxf(g, 0.0001))
		if p.has_meta("target_pos"):
			p.global_position = p.global_position.lerp(p.get_meta("target_pos"), minf(1.0, delta * 3.0))


func _fade(p: AudioStreamPlayer, target: float) -> void:
	create_tween().tween_property(p, "volume_db", linear_to_db(maxf(target, 0.0001)), UPDATE_INTERVAL)
