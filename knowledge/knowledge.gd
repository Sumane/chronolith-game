class_name Knowledge
extends RefCounted
## M3: meta ledger. Engrams (1 per cleared wave, idempotent per
## attempt:wave receipt), atomic research spend, applied-effects rollup.

var earned_total := 0
var spent_total := 0
var researched := {}
var receipts := {}

func balance() -> int:
	return earned_total - spent_total

func grant_wave(attempt_id: String, wave: int) -> bool:
	var key := attempt_id + ":" + str(wave)
	if receipts.has(key):
		return false
	receipts[key] = true
	earned_total += 1
	return true

func research_required(id: String) -> bool:
	var node: Dictionary = ResearchTree.NODES.get(id, {})
	for r in node.get("req", []):
		if not researched.has(r):
			return true
	return false

func can_research(id: String) -> Dictionary:
	if not ResearchTree.NODES.has(id):
		return {"ok": false, "reason": "unknown"}
	if researched.has(id):
		return {"ok": false, "reason": "already"}
	if research_required(id):
		return {"ok": false, "reason": "requires"}
	var cost: int = ResearchTree.NODES[id]["cost"]
	if balance() < cost:
		return {"ok": false, "reason": "balance"}
	return {"ok": true, "cost": cost}

func research(id: String) -> Dictionary:
	var chk := can_research(id)
	if not chk.get("ok", false):
		return chk
	researched[id] = true
	spent_total += int(chk["cost"])
	return {"ok": true, "cost": chk["cost"]}

const MIN_KEYS := ["time_factor"]

func applied() -> Dictionary:
	var out := {}
	for id in researched:
		var node: Dictionary = ResearchTree.NODES.get(id, {})
		for stat in node.get("effect", {}):
			if MIN_KEYS.has(stat):
				# stacking deepens the slow — take the strongest, never sum
				var cur: Variant = out.get(stat)
				if cur == null:
					out[stat] = float(node["effect"][stat])
				else:
					out[stat] = minf(float(cur), float(node["effect"][stat]))
			else:
				out[stat] = float(out.get(stat, 0.0)) + float(node["effect"][stat])
	return out

func snapshot() -> Dictionary:
	return {
		"earned_total": earned_total,
		"spent_total": spent_total,
		"researched": researched.duplicate(true),
		"receipts": receipts.duplicate(true),
	}

func restore(snap: Dictionary) -> void:
	earned_total = int(snap.get("earned_total", 0))
	spent_total = int(snap.get("spent_total", 0))
	researched = snap.get("researched", {}).duplicate(true)
	receipts = snap.get("receipts", {}).duplicate(true)
