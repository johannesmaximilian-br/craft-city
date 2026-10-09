class_name Perf
extends RefCounted
## Minimaler Profiler: Zeitmessung benannter Abschnitte, nur aktiv mit Dev-Flag --profile.
##
##   var t := Perf.begin()
##   ...
##   Perf.end("name", t)

static var enabled := false
static var frame := {}      # Abschnitt -> µs im aktuellen Frame
static var total := {}      # Abschnitt -> [Summe µs, Anzahl, Max µs]


static func begin() -> int:
	return Time.get_ticks_usec() if enabled else 0


static func end(section: String, start: int) -> void:
	if not enabled:
		return
	var dt := Time.get_ticks_usec() - start
	frame[section] = frame.get(section, 0) + dt
	var t: Array = total.get(section, [0, 0, 0])
	total[section] = [t[0] + dt, t[1] + 1, maxi(t[2], dt)]


## Abschnitte des letzten Frames holen und zurücksetzen.
static func take_frame() -> Dictionary:
	var f := frame
	frame = {}
	return f
