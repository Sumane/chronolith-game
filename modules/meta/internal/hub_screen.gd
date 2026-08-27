extends Control
## INTERNAL (meta) — hub screen: the crashed vessel interior.
## Stub hub per GDD §14: stats, one shop, begin-timeline button.

signal start_requested
signal unlock_requested(id: String)
signal quit_requested

var _shards_label: Label
var _dna_label: Label
var _runs_label: Label
var _mem_label: Label
var _shop_rows := {} # id -> Button
var _unlocks_data: Array = []
var _flavor: Label

const FLAVOR_LINES := [
	"Timeline %d. The vessel hums around you like a held breath.",
	"The crystal remembers every timeline. So, increasingly, do you.",
	"Somewhere on Earth, mission control is still waiting for sample B7.",
]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.06, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "CHRONOLITH"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("59e6ff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "— interior of the crashed vessel —"
	sub.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	_flavor = Label.new()
	_flavor.add_theme_color_override("font_color", Color(0.55, 0.75, 0.85))
	_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_flavor)

	vbox.add_child(HSeparator.new())

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 30)
	stats.add_theme_constant_override("v_separation", 4)
	vbox.add_child(stats)
	_shards_label = _stat_row(stats, "Chronal Shards")
	_dna_label = _stat_row(stats, "Alien DNA")
	_runs_label = _stat_row(stats, "Timelines lived")
	_mem_label = _stat_row(stats, "Memories repaired")

	vbox.add_child(HSeparator.new())

	var shop_title := Label.new()
	shop_title.text = "GREY TECH ARCHIVE — permanent unlocks"
	shop_title.add_theme_color_override("font_color", Color(0.5, 0.85, 0.95))
	vbox.add_child(shop_title)
	var shop_box := VBoxContainer.new()
	shop_box.name = "ShopBox"
	vbox.add_child(shop_box)

	var start := Button.new()
	start.text = "BEGIN NEW TIMELINE  [the Chronolith pulls you back]"
	start.custom_minimum_size = Vector2(0, 52)
	start.add_theme_font_size_override("font_size", 18)
	start.pressed.connect(func(): start_requested.emit())
	vbox.add_child(start)

	var quit := Button.new()
	quit.text = "Dormancy (quit)"
	quit.pressed.connect(func(): quit_requested.emit())
	vbox.add_child(quit)

func _stat_row(grid: GridContainer, label_text: String) -> Label:
	var l := Label.new()
	l.text = label_text + ":"
	l.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	grid.add_child(l)
	var v := Label.new()
	v.text = "0"
	grid.add_child(v)
	return v

func build_shop(unlocks: Array) -> void:
	_unlocks_data = unlocks
	var shop_box: VBoxContainer = find_child("ShopBox", true, false)
	if shop_box == null:
		return
	for u: Dictionary in unlocks:
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func(): unlock_requested.emit(str(u.get("id", ""))))
		shop_box.add_child(btn)
		_shop_rows[str(u.get("id", ""))] = btn

func refresh(ledger: Dictionary, unlocked_ids: Array, store_data: Dictionary) -> void:
	var shards := int(ledger.get("SHARDS", int(store_data.get("shards", 0))))
	_shards_label.text = str(shards)
	_shards_label.add_theme_color_override("font_color", Color("59e6ff") if shards > 0 else Color(0.5, 0.55, 0.6))
	_dna_label.text = str(int(store_data.get("dna", 0)))
	_runs_label.text = str(int(store_data.get("runs_completed", 0)))
	_mem_label.text = "%d / 3" % int(store_data.get("memories_repaired", 0))
	var runs := int(store_data.get("runs_completed", 0)) + 1
	var line := str(FLAVOR_LINES[(runs - 1) % FLAVOR_LINES.size()])
	_flavor.text = (line % runs) if "%d" in line else line
	for u: Dictionary in _unlocks_data:
		var id := str(u.get("id", ""))
		var btn: Button = _shop_rows.get(id)
		if btn == null:
			continue
		var cost: Dictionary = u.get("cost", {})
		var shard_cost := int(cost.get("SHARDS", 0))
		var owned := id in unlocked_ids
		if owned:
			btn.text = "■ %s — OWNED" % str(u.get("name", id))
			btn.disabled = true
			btn.modulate = Color(0.6, 1.0, 0.8, 0.9)
		else:
			btn.text = "□ %s — %s\n     %s   (cost: %d shards)" % [
				str(u.get("name", id)), str(u.get("desc", "")), "", shard_cost]
			btn.disabled = shards < shard_cost
			btn.modulate = Color(1, 1, 1) if not btn.disabled else Color(1, 1, 1, 0.55)
