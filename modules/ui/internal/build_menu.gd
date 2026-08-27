extends HBoxContainer
## INTERNAL (ui) — build menu cards, rendered read-only from buildings data.

var defs: Dictionary = {}
var selected := ""
var ledger := {}
var _cards := {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 10)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_bottom = -14
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func build_cards(building_defs: Dictionary) -> void:
	defs = building_defs
	var keys := ["wall", "turret", "solar", "scanner"]
	for i in keys.size():
		var id: String = keys[i]
		if not defs.has(id):
			continue
		var def: Dictionary = defs[id]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 64)
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE # clicks go to world placement
		btn.pressed.connect(func(): pass)
		add_child(btn)
		_cards[id] = btn
		btn.set_meta("slot", i + 1)
		_refresh_card_text(id, i)

func id_of(index: int) -> String:
	var keys := ["wall", "turret", "solar", "scanner"]
	return keys[index] if index >= 0 and index < keys.size() else ""

func set_affordability(new_ledger: Dictionary) -> void:
	ledger = new_ledger
	for id: String in _cards:
		_refresh_card_text(id, int(_cards[id].get_meta("slot", 1)) - 1)

func set_selected(id: String) -> void:
	selected = id
	for cid: String in _cards:
		var btn: Button = _cards[cid]
		if cid == selected:
			btn.modulate = Color(0.6, 1.0, 1.0)
			btn.add_theme_stylebox_override("normal", StyleBoxFlat.new())
		else:
			btn.modulate = Color(1, 1, 1)

func _refresh_card_text(id: String, slot: int) -> void:
	if not defs.has(id) or not _cards.has(id):
		return
	var def: Dictionary = defs[id]
	var btn: Button = _cards[id]
	var cost_parts: Array = []
	var affordable := true
	for kind: String in def.get("cost", {}):
		cost_parts.append("%d %s" % [int(def["cost"][kind]), kind])
		if int(ledger.get(kind, 0)) < int(def["cost"][kind]):
			affordable = false
	var txt := "%d  %s\n%s" % [slot, str(def.get("name", id)), ", ".join(cost_parts)]
	btn.text = txt
	btn.disabled = not affordable
	btn.modulate.a = 1.0 if affordable else 0.5
