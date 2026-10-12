class_name SaveManager
extends RefCounted
## Spielstände in user://saves/<slot>.citysave
## Format: store_var(meta) + store_var(daten), komprimiert. Meta ist separat lesbar (Slot-Liste).

const VERSION := 1
const DIR := "user://saves"
const SLOTS := ["quick", "1", "2", "3"]


static func path(slot: String) -> String:
	return "%s/%s.citysave" % [DIR, slot]


static func save(slot: String, map: CityMap, sim: Simulation, city_name := "Cube City") -> Error:
	DirAccess.make_dir_recursive_absolute(DIR)
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
