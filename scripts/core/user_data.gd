extends Node
## Autoload (vor Audio): eigener Datenordner statt "Godot/app_userdata/...".
## project.godot: application/config/use_custom_user_dir = true, Name "Cube City"
##   macOS   ~/Library/Application Support/Cube City/
##   Windows %APPDATA%\Cube City\
##   Linux   ~/.local/share/Cube City/
## Beim ersten Start einmalig Spielstände + Einstellungen aus dem alten Godot-Ordner kopieren
## (nur kopieren, der alte Ordner bleibt als Sicherheitskopie unangetastet).

const OLD_PARENTS := ["Godot/app_userdata", "godot/app_userdata"]
var migrated_from := ""     # für die Info im Menü/Test; "" = nichts übernommen


func _init() -> void:
	migrate()


## Pfad des alten Ordners (oder "", wenn keiner existiert).
static func old_dir() -> String:
	var name: String = ProjectSettings.get_setting("application/config/name")
	for p: String in OLD_PARENTS:
		var d := OS.get_data_dir().path_join(p).path_join(name)
		if DirAccess.dir_exists_absolute(d):
			return d
	return ""


func migrate() -> void:
	var new_dir := OS.get_user_data_dir()
	var old := old_dir()
	if old == "" or old == new_dir:
		return
	# Nur wenn der neue Ordner noch nichts vom Spiel enthält
	if FileAccess.file_exists(new_dir.path_join("settings.cfg")) or DirAccess.dir_exists_absolute(new_dir.path_join("saves")):
		return
	DirAccess.make_dir_recursive_absolute(new_dir)
	var copied := 0
	if FileAccess.file_exists(old.path_join("settings.cfg")):
		if DirAccess.copy_absolute(old.path_join("settings.cfg"), new_dir.path_join("settings.cfg")) == OK:
			copied += 1
	var old_saves := old.path_join("saves")
	if DirAccess.dir_exists_absolute(old_saves):
		DirAccess.make_dir_recursive_absolute(new_dir.path_join("saves"))
		for f in DirAccess.get_files_at(old_saves):
			if f.ends_with(".citysave") and DirAccess.copy_absolute(old_saves.path_join(f), new_dir.path_join("saves").path_join(f)) == OK:
				copied += 1
	if copied > 0:
		migrated_from = old
		print("UserData: %d Dateien aus %s nach %s übernommen" % [copied, old, new_dir])


## Spielstand-Ordner im Finder/Explorer öffnen.
static func open_saves_folder() -> void:
	var d := ProjectSettings.globalize_path("user://saves")
	DirAccess.make_dir_recursive_absolute(d)
	OS.shell_open(d)
