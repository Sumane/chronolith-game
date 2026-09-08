class_name ProfileStore
extends RefCounted
## M3: schema-versioned persistence with backup recovery.
## Save = write tmp -> verify round-trip -> backup original -> rename.
## Load = try original -> try .bak (recovered) -> fresh.

const SCHEMA_VERSION := 1

var path := "user://chronolith_v1_profile.json"

func save(data: Dictionary) -> Dictionary:
	var tmp := path + ".tmp"
	var bak := path + ".bak"
	var text := JSON.stringify(data)
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "reason": "write_failed"}
	f.store_string(text)
	f.close()
	# verify round-trip before touching the good file
	var v := FileAccess.open(tmp, FileAccess.READ)
	if v == null:
		return {"ok": false, "reason": "verify_open_failed"}
	var back := v.get_as_text()
	v.close()
	var parsed: Variant = JSON.parse_string(back)
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("schema_version", 0)) != SCHEMA_VERSION:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return {"ok": false, "reason": "verify_parse_failed"}
	# backup current good file (if any), then promote
	if FileAccess.file_exists(path):
		var src := FileAccess.open(path, FileAccess.READ)
		var dst := FileAccess.open(bak, FileAccess.WRITE)
		if dst != null:
			dst.store_string(src.get_as_text())
			dst.close()
		src.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	if err != OK:
		return {"ok": false, "reason": "rename_failed"}
	return {"ok": true}

func load() -> Dictionary:
	var d := _try_read(path)
	if bool(d.get("ok", false)):
		return d
	var b := _try_read(path + ".bak")
	if bool(b.get("ok", false)):
		b["recovered"] = true
		return b
	return {"ok": false, "reason": "no_profile"}

func _try_read(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {"ok": false}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {"ok": false, "reason": "open_failed"}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("schema_version", 0)) != SCHEMA_VERSION:
		return {"ok": false, "reason": "bad_schema"}
	return {"ok": true, "data": parsed}
