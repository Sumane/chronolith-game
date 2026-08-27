extends Node
## INTERNAL (meta) — JSON persistence in user:// with corrupt-quarantine.
## Schema v1: shards/dna are banked here; unlocks, memory tallies, run stats.

const SAVE_PATH := "user://chronolith_save.json"

var data: Dictionary = {}

func load_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		data = _fresh()
		return data
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed: Variant = null
	if f != null:
		parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", -1)) != 1:
		_quarantine()
		data = _fresh()
	else:
		data = parsed
	return data

func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[Meta] cannot write save: %d" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data, "\t"))

func _quarantine() -> void:
	push_warning("[Meta] save corrupted — quarantining")
	if FileAccess.file_exists(SAVE_PATH):
		var stamp := Time.get_datetime_dict_from_system()
		DirAccess.rename_absolute(SAVE_PATH, "%s.corrupt.%04d%02d%02d%02d%02d%02d" % [
			SAVE_PATH, stamp.year, stamp.month, stamp.day, stamp.hour, stamp.minute, stamp.second,
		])

func _fresh() -> Dictionary:
	return {
		"version": 1,
		"shards": 0,
		"dna": 0,
		"unlocked_ids": [],
		"memories_repaired": 0,
		"memories_seen": 0,
		"runs_completed": 0,
		"best_sol": 0,
	}
