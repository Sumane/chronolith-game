extends Node
## M5 ECONOMY — THE resource ledger. Single source of truth (architecture §4).
## Nobody else mutates resources: they send purchase_request / grant_resources.
## Shards persist across runs; in-run resources reset on run_started.

var ledger: Dictionary = {}
var _queue: Array = [] # purchase requests, resolved FIFO — deterministic

func _ready() -> void:
	if Contracts.CONTRACT_VERSION != 1:
		push_warning("[Economy] contract version mismatch")
	for key in Contracts.RESOURCE_KEYS:
		ledger[key] = 0
	Bus.run_started.connect(_on_run_started)
	Bus.run_ended.connect(_on_run_ended)
	Bus.rover_harvested.connect(_on_rover_harvested)
	Bus.enemy_killed.connect(_on_enemy_killed)
	Bus.grant_resources.connect(_on_grant)
	Bus.purchase_request.connect(_on_purchase_request)
	Bus.wave_cleared.connect(_on_wave_cleared)
	Bus.meta_loaded.connect(_on_meta_loaded)

func _process(_delta: float) -> void:
	if _queue.is_empty():
		return
	var req: Dictionary = _queue.pop_front()
	_resolve_purchase(req)

func _on_run_started(_payload: Dictionary) -> void:
	var start: Variant = Contracts.load_json("res://modules/economy/data/starting_resources.json")
	for key in Contracts.RESOURCE_KEYS:
		if key != "SHARDS" and key != "DNA": # meta currencies persist across runs
			ledger[key] = 0
	if typeof(start) == TYPE_DICTIONARY:
		for key: String in start:
			if key != "SHARDS" and key in ledger: # shards are meta currency; keep
				ledger[key] = int(start[key])
	_snapshot()

func _on_meta_loaded(payload: Dictionary) -> void:
	# banked shards from the save file seed the ledger (meta → economy, one-way)
	ledger["SHARDS"] = int(payload.get("SHARDS", int(ledger.get("SHARDS", 0))))
	_snapshot()

func _on_run_ended(payload: Dictionary) -> void:
	if str(payload.get("reason", "")) == "victory":
		ledger["SHARDS"] += 6
		_snapshot()
		Bus.toast.emit({"text": "+6 Chronal Shards — timeline secured", "color": "#59e6ff"})

func _on_rover_harvested(payload: Dictionary) -> void:
	if not Contracts.has_keys(payload, ["kind", "amount"]):
		push_warning("[Economy] dropped malformed rover_harvested")
		return
	var kind := str(payload["kind"])
	if kind in ledger and int(payload["amount"]) > 0:
		ledger[kind] += int(payload["amount"])
		_snapshot()

func _on_enemy_killed(payload: Dictionary) -> void:
	var salvage: Variant = payload.get("salvage", {})
	if typeof(salvage) != TYPE_DICTIONARY:
		return
	var gained := false
	for kind: String in salvage:
		if kind in ledger:
			ledger[kind] += int(salvage[kind])
			gained = true
	if gained:
		_snapshot()

func _on_grant(payload: Dictionary) -> void:
	var resources: Variant = payload.get("resources", {})
	if typeof(resources) != TYPE_DICTIONARY:
		push_warning("[Economy] dropped malformed grant_resources")
		return
	for kind: String in resources:
		if kind in ledger and int(resources[kind]) > 0:
			ledger[kind] += int(resources[kind])
	_snapshot()

func _on_wave_cleared(_payload: Dictionary) -> void:
	ledger["SHARDS"] += 2
	_snapshot()

func _on_purchase_request(payload: Dictionary) -> void:
	if not Contracts.has_keys(payload, ["req_id", "cost"]):
		push_warning("[Economy] dropped malformed purchase_request")
		return
	_queue.append(payload)

func _resolve_purchase(req: Dictionary) -> void:
	var cost: Dictionary = req.get("cost", {})
	var affordable := true
	for kind: String in cost:
		if not (kind in ledger) or ledger[kind] < int(cost[kind]):
			affordable = false
			break
	if affordable:
		for kind: String in cost:
			ledger[kind] -= int(cost[kind]) # never negative by construction
		_snapshot()
	Bus.purchase_result.emit({
		"req_id": req.get("req_id", ""),
		"ok": affordable,
		"reason": "ok" if affordable else "insufficient",
		"tag": str(req.get("tag", "")),
	})

func _snapshot() -> void:
	Bus.resource_changed.emit({"ledger": ledger.duplicate()})
