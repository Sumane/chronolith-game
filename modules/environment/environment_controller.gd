extends Node2D
## M8 ENVIRONMENT — Mars map, harvest nodes, sol storms. Door: this file only.

const MarsMap := preload("res://modules/environment/internal/mars_map.gd")

var map_data: Dictionary = {}
var nodes: Array = [] # [{id, kind, x, y, amount, max}]
var _mars: Node2D

func _ready() -> void:
	if Contracts.CONTRACT_VERSION != 1:
		push_warning("[Environment] contract version mismatch")
	map_data = Contracts.load_json("res://modules/environment/data/maps.json")
	_mars = MarsMap.new()
	_mars.name = "MarsMap"
	add_child(_mars)
	Bus.run_started.connect(_on_run_started)
	Bus.phase_changed.connect(_on_phase_changed)
	Bus.rover_harvested.connect(_on_harvested)
	Bus.sol_changed.connect(_on_sol)

func _on_run_started(_payload: Dictionary) -> void:
	nodes.clear()
	for n: Dictionary in map_data.get("nodes", []):
		var amount := int(n.get("amount", 0))
		nodes.append({
			"id": n.get("id", ""),
			"kind": n.get("kind", "REGOLITH"),
			"x": float(n.get("x", 0)),
			"y": float(n.get("y", 0)),
			"amount": amount,
			"max": amount,
		})
	_mars.setup(map_data, nodes)
	var payload_nodes: Array = []
	for n: Dictionary in nodes:
		payload_nodes.append({"id": n["id"], "kind": n["kind"], "x": n["x"], "y": n["y"], "amount": n["amount"]})
	Bus.map_loaded.emit({
		"w": float(map_data.get("map_w", 1920)),
		"h": float(map_data.get("map_h", 1280)),
		"crystal": map_data.get("crystal", {"x": 960, "y": 640}),
		"vessel": map_data.get("vessel", {"x": 340, "y": 300}),
		"tunnel_holes": map_data.get("tunnel_holes", []),
		"nodes": payload_nodes,
	})

func _on_phase_changed(payload: Dictionary) -> void:
	if not payload.has("phase_id"):
		return
	match int(payload["phase_id"]):
		Contracts.Phase.ASSAULT:
			var tables: Variant = Contracts.load_json("res://modules/environment/data/storm_tables.json")
			var storm: Dictionary = {}
			if typeof(tables) == TYPE_DICTIONARY:
				var by_sol: Dictionary = tables.get("by_sol", {})
				storm = by_sol.get(str(_sol), {})
			var solar := float(storm.get("solar_mult", 1.0))
			Bus.environment_state.emit({
				"storm": solar < 1.0,
				"solar_mult": solar,
				"visibility_mult": float(storm.get("visibility_mult", 1.0)),
			})
		Contracts.Phase.CALM:
			Bus.environment_state.emit({"storm": false, "solar_mult": 1.0, "visibility_mult": 1.0})

var _sol := 1
func _on_sol(payload: Dictionary) -> void:
	_sol = int(payload.get("sol", _sol))

func _on_harvested(payload: Dictionary) -> void:
	if not Contracts.has_keys(payload, ["node_id", "amount"]):
		return
	for n: Dictionary in nodes:
		if n["id"] == payload["node_id"]:
			n["amount"] = maxi(0, int(n["amount"]) - int(payload["amount"]))
			if n["amount"] <= 0:
				Bus.node_depleted.emit({"node_id": n["id"]})
			_mars.queue_redraw()
			return
