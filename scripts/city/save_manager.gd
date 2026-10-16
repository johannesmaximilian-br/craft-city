class_name SaveManager
extends RefCounted
## Spielstände in user://saves/<slot>.citysave
## Format: store_var(meta) + store_var(daten), komprimiert. Meta ist separat lesbar (Slot-Liste).

const VERSION := 1
const DIR := "user://saves"
static var dir := DIR       # Tests stellen auf einen eigenen Ordner um (echte Spielstände nie anfassen)
const SLOTS := ["quick", "1", "2", "3"]
const BACKUPS := 3          # je Spieler-Slot: vor jedem Überschreiben alte Version als <slot>.bak1..3 behalten


## Sicherung k (1 = neueste) eines Slots; ist selbst wie ein Slot ladbar.
static func backup_slot(slot: String, k: int) -> String:
	return "%s.bak%d" % [slot, k]


## Alte Version vor dem Überschreiben wegschieben (bak1 -> bak2 -> bak3, älteste fällt weg). Nur Spieler-Slots.
static func _rotate_backups(slot: String) -> void:
	if not slot in SLOTS or not FileAccess.file_exists(path(slot)):
		return
	for k in range(BACKUPS, 1, -1):
		var older := path(backup_slot(slot, k - 1))
		if FileAccess.file_exists(older):
			DirAccess.rename_absolute(older, path(backup_slot(slot, k)))
	DirAccess.rename_absolute(path(slot), path(backup_slot(slot, 1)))


## Alle vorhandenen Sicherungen: [{slot, k, name, meta}], neueste zuerst je Slot.
static func backups() -> Array:
	var out := []
	for slot: String in SLOTS:
		for k in range(1, BACKUPS + 1):
			var m := meta(backup_slot(slot, k))
			if not m.is_empty():
				out.append({"slot": backup_slot(slot, k), "base": slot, "k": k, "meta": m})
	return out


static func path(slot: String) -> String:
	return "%s/%s.citysave" % [dir, slot]


static func save(slot: String, map: CityMap, sim: Simulation, city_name := "Cube City") -> Error:
	DirAccess.make_dir_recursive_absolute(dir)
	_rotate_backups(slot)
	var f := FileAccess.open_compressed(path(slot), FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return FileAccess.get_open_error()
	var meta := {
		"version": VERSION, "name": city_name, "date": sim.date_string(),
		"population": sim.population, "money": int(sim.money),
		"saved_at": Time.get_datetime_string_from_system(false, true),
	}
	f.store_var(meta)
	f.store_var({"map": map.to_dict(), "sim": sim.to_dict()})
	f.close()
	return OK


static func load_slot(slot: String, map: CityMap, sim: Simulation) -> Error:
	return load_file(path(slot), map, sim)


## Beliebige Datei laden (Dev: Kopie eines Spielstands analysieren, ohne den Slot anzufassen).
static func load_file(file: String, map: CityMap, sim: Simulation) -> Error:
	var f := FileAccess.open_compressed(file, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return ERR_FILE_NOT_FOUND
	var meta: Variant = f.get_var()
	var data: Variant = f.get_var()
	f.close()
	if not (meta is Dictionary and data is Dictionary) or meta.get("version", 0) > VERSION:
		return ERR_FILE_CORRUPT
	if not map.from_dict(data["map"]):
		return ERR_INVALID_DATA
	sim.from_dict(data["sim"])
	return OK


## Metadaten eines Slots oder {} wenn leer.
static func meta(slot: String) -> Dictionary:
	if not FileAccess.file_exists(path(slot)):
		return {}
	var f := FileAccess.open_compressed(path(slot), FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return {}
	var m: Variant = f.get_var()
	f.close()
	return m if m is Dictionary else {}
