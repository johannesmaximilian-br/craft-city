class_name GraphicsSettings
extends RefCounted
## Grafik-Voreinstellungen (im Menü umschaltbar, gespeichert in user://settings.cfg).
##
##            Schatten            Umgebungsverdeckung  Kantenglättung   3D-Auflösung
##   Hoch     4096, 250 Einh., 4  SSAO an              MSAA 2x          100 %
##   Mittel   2048, 150 Einh., 2  aus                  FXAA             100 %
##   Niedrig  aus                 aus                  FXAA             75 % (FSR-Hochskalierung)

enum Preset { LOW, MEDIUM, HIGH }
const NAMES := ["Niedrig", "Mittel", "Hoch"]
const SETTINGS_PATH := "user://settings.cfg"

static var current := Preset.HIGH
static var vsync := true
const FPS_OPTIONS := [30, 60, 0]          # 0 = unbegrenzt
static var fps_limit := 60
const UI_SCALES := [0.7, 0.85, 1.0, 1.15]
static var ui_scale := 1.0
static var fullscreen := true
static var day_night := true              # sichtbarer Tag/Nacht-Zyklus (aus = immer Mittag)


static func load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		current = cfg.get_value("graphics", "preset", Preset.HIGH)
		vsync = cfg.get_value("graphics", "vsync", true)
		fps_limit = cfg.get_value("graphics", "fps_limit", 60)
		ui_scale = cfg.get_value("graphics", "ui_scale", 1.0)
		fullscreen = cfg.get_value("graphics", "fullscreen", true)
		day_night = cfg.get_value("graphics", "day_night", true)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("graphics", "preset", current)
	cfg.set_value("graphics", "vsync", vsync)
	cfg.set_value("graphics", "fps_limit", fps_limit)
	cfg.set_value("graphics", "ui_scale", ui_scale)
	cfg.set_value("graphics", "fullscreen", fullscreen)
	cfg.set_value("graphics", "day_night", day_night)
	cfg.save(SETTINGS_PATH)


## Vollbild an/aus (Testläufe mit Dev-Flags bleiben immer im Fenster).
static func apply_window() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)


static func apply(viewport: Viewport, env: Environment, sun: DirectionalLight3D) -> void:
	match current:
		Preset.HIGH:
			sun.shadow_enabled = true
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			sun.directional_shadow_max_distance = 250.0
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			env.ssao_enabled = true
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			viewport.scaling_3d_scale = 1.0
		Preset.MEDIUM:
			sun.shadow_enabled = true
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = 150.0
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			env.ssao_enabled = false
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			viewport.scaling_3d_scale = 1.0
		Preset.LOW:
			sun.shadow_enabled = false
			env.ssao_enabled = false
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			viewport.scaling_3d_scale = 0.75
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
