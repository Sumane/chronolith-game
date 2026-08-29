class_name Contracts
extends RefCounted
## CHRONOLITH core contracts — THE LAW (architecture doc §1.2).
## Every cross-module signal lives on the Bus (core/event_bus.gd) and takes
## exactly ONE Dictionary payload documented here. Modules validate payloads,
## log-and-drop malformed ones, never crash.

const CONTRACT_VERSION := 1

enum EnemyType { TROOPER, STALKER, BURROWER }
enum Phase { HUB, CALM, ASSAULT, RESET }
enum ResourceKind { REGOLITH, SCRAP, RARE, POWER, SHARDS, DNA }

## Canonical ledger keys (economy owns these values).
const RESOURCE_KEYS := ["REGOLITH", "SCRAP", "RARE", "POWER", "SHARDS", "DNA"]

## Stalker reveal rule (duplicated intentionally by consumers; keep in sync):
## a cloaked stalker is targetable if inside ANY online scanner mast radius
## OR within REVEAL_RADIUS_ROVER of the rover.
const REVEAL_RADIUS_ROVER := 120.0

# ---------------------------------------------------------------- payloads --
## phase_changed { "phase": String("HUB"|"CALM"|"ASSAULT"|"RESET"), "phase_id": int }
## run_started   { "run_index": int }
## run_ended     { "reason": String("victory"|"chronolith_lost"|"rover_lost"), "sols_survived": int }
## sol_changed   { "sol": int }
## calm_tick     { "remaining": float, "duration": float }
##
## map_loaded {
##   "w": float, "h": float, "crystal": {"x","y"},
##   "vessel": {"x","y"},
##   "tunnel_holes": [ {"x","y"}, ... ],
##   "nodes": [ {"id":String,"kind":String(RESOURCE_KEY),"x","y","amount":int}, ... ] }
## environment_state { "storm": bool, "solar_mult": float, "visibility_mult": float }
## node_depleted  { "node_id": String }
##
## resource_changed { "ledger": { RESOURCE_KEY: int, ... } }   # full snapshot, economy is sole owner
## grant_resources  { "resources": { KEY: int } }              # positive additions only
## purchase_request { "req_id": String, "cost": {KEY:int}, "tag": String }
## purchase_result  { "req_id": String, "ok": bool, "reason": String, "tag": String }
##
## build_selected    { "building_id": String }   # "" = deselect
## build_place_clicked {}                        # placement attempted at mouse world pos by Build
## build_placed      { "building_id": int, "type": String, "x": float, "y": float, "hp": int }
## build_destroyed   { "building_id": int, "type": String }
## build_rejected    { "reason": String }
## layout_snapshot   { "buildings": [ {"id":int,"x","y","radius":float,"type":String,"hp":int,"max_hp":int}, ... ] }
## scanner_state     { "masts": [ {"x","y","radius":float,"online":bool}, ... ] }
## power_state_changed { "capacity": int, "draw": int, "unpowered_ids": [int] }
## turret_fired      { "building_id": int, "from":{"x","y"}, "to":{"x","y"}, "damage": int, "target_id": int }
##
## rover_moved     { "x": float, "y": float, "stage": int }          # throttled ~10 Hz
## rover_harvested { "node_id": String, "kind": String, "amount": int }
## rover_fired     { "from":{"x","y"}, "to":{"x","y"}, "damage": int, "target_id": int }  # target_id -1 = cosmetic miss
## rover_damaged   { "hp": int, "max_hp": int }
## rover_destroyed {}
## rover_upgraded_ack { "stage": int }
##
## enemy_spawned { "enemy_id": int, "type": String, "x": float, "y": float }
## enemy_positions { "entries": [ [id:int, x:float, y:float, type:String, underground:bool], ... ] }  # per physics tick during ASSAULT
## enemy_killed  { "enemy_id": int, "type": String, "salvage": {KEY:int} }
## enemy_attack  { "enemy_id": int, "type": String, "target": String("CHRONOLITH"|"ROVER"|"B<building_id>"), "damage": int }
## wave_started  { "sol": int, "total": int }
## wave_progress { "alive": int, "queued": int, "total": int }
## wave_cleared  { "sol": int }
##
## chronolith_damaged  { "integrity": int, "max_integrity": int }
## chronolith_destroyed {}
## chronolith_field_state { "x": float, "y": float, "radius": float, "slow": float }
## rewind_state       { "remaining": float, "duration": float, "ready": bool }
## chronolith_active_triggered { "active": String }
## rewind_window      { "seconds": float }
##
## input_move { "vec": {"x": float, "y": float} }   # normalized or zero
## input_fire      { "pressed": bool }
## input_interact  { "pressed": bool }
## player_activated_rewind {}
## player_requested_upgrade {}
## player_skip_calm {}
##
## memory_event    { "title": String, "text": String, "index": int, "total": int }
## memory_resolved { "choice": String("repair"|"purge") }
## unlocks_loaded  { "unlocked_ids": [String], "memories_repaired": int, "memories_seen": int, "runs_completed": int }
## unlock_purchased { "id": String }
## meta_loaded     { "SHARDS": int }
## meta_bonuses    { "hp_flat": int, "harvest_mult": float }
## hub_start_requested {}
## toast           { "text": String, "color": String(hex, optional), "life": float(optional) }


static func has_keys(payload: Variant, keys: Array) -> bool:
	if typeof(payload) != TYPE_DICTIONARY:
		return false
	for k in keys:
		if not payload.has(k):
			return false
	return true


static func vec2_of(v: Variant) -> Vector2:
	if typeof(v) == TYPE_DICTIONARY and v.has("x") and v.has("y"):
		return Vector2(float(v["x"]), float(v["y"]))
	return Vector2.ZERO


static func pack_v2(v: Vector2) -> Dictionary:
	return {"x": v.x, "y": v.y}


## 3D seam (3D-CONVERSION.md §3): z is vertical, ground = 0. Payloads that
## predate the conversion simply omit z and land on the ground plane.
static func vec3_of(v: Variant) -> Vector3:
	if typeof(v) == TYPE_DICTIONARY and v.has("x") and v.has("y"):
		return Vector3(float(v["x"]), float(v.get("z", 0.0)), float(v["y"]))
	return Vector3.ZERO


static func pack_v3(v: Vector3) -> Dictionary:
	return {"x": v.x, "y": v.z, "z": v.y}


static func phase_name(phase: int) -> String:
	return Phase.keys()[phase]


## Shared JSON loader — returns Dictionary/Array or empty Dictionary on failure (fail loud in log).
static func load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[Contracts] cannot open %s (%d)" % [path, FileAccess.get_open_error()])
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("[Contracts] malformed JSON in %s" % path)
		return {}
	return parsed
