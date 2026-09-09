class_name ResearchScreen
extends CanvasLayer
## M3: full-pause research menu (blockout). Opens between waves.
## Keys 1-6 buy, Esc/G closes. Purchase = memory apply + verified save;
## a failed save rolls the purchase back (refund invariant).

var knowledge: Knowledge = null
var on_purchase: Callable
var on_close: Callable
var visible_now := false
var _page := 0
var _stats: Label
var _rows := {}
var _flash: Label
var _hint: Label
var _flash_t := 0.0
var _dim: ColorRect

# M6: two pages of 7 — page 1 TURRET+FORT, page 2 ROVER+TEMPORAL+MECH.
const PAGES := [
	["t1", "t2", "t3", "t4", "f1", "f2", "f3"],
	["r1", "r2", "r3", "r4", "x1", "x2", "mech"],
]

func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.02, 0.06, 0.92)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 480)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "ENGRAM RESEARCH"
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	_stats = Label.new()
	_stats.add_theme_font_size_override("font_size", 16)
	_stats.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	box.add_child(_stats)
	var counters := Label.new()
	counters.text = "COUNTERS — Grunt: any damage · Warden: pierce shot or ram · Golem: armor 20 blocks flat shots — pierce or ram"
	counters.add_theme_font_size_override("font_size", 14)
	counters.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	box.add_child(counters)
	for i in ResearchTree.ORDER.size():
		var id: String = ResearchTree.ORDER[i]
		var node: Dictionary = ResearchTree.NODES[id]
		var row := HBoxContainer.new()
		var key_lbl := Label.new()
		key_lbl.text = "[%d]" % (i + 1)
		key_lbl.custom_minimum_size = Vector2(40, 0)
		key_lbl.add_theme_font_size_override("font_size", 15)
		row.add_child(key_lbl)
		var name_lbl := Label.new()
		name_lbl.text = "%s  (%s)" % [str(node["name"]), str(node["line"])]
		name_lbl.custom_minimum_size = Vector2(230, 0)
		name_lbl.add_theme_font_size_override("font_size", 15)
		row.add_child(name_lbl)
		var desc_lbl := Label.new()
		desc_lbl.text = str(node["desc"])
		desc_lbl.custom_minimum_size = Vector2(300, 0)
		desc_lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(desc_lbl)
		var btn := Button.new()
		btn.text = "BUY %d" % int(node["cost"])
		btn.custom_minimum_size = Vector2(110, 0)
		btn.pressed.connect(_on_buy.bind(id))
		row.add_child(btn)
		box.add_child(row)
		row.visible = i < 7
		_rows[id] = {"btn": btn, "desc": desc_lbl, "row": row, "idx": i, "key": key_lbl}
	_flash = Label.new()
	_flash.add_theme_font_size_override("font_size", 15)
	_flash.add_theme_color_override("font_color", Color(1, 0.5, 0.4))
	box.add_child(_flash)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 13)
	box.add_child(_hint)
	panel.add_child(box)
	center.add_child(panel)
	_dim.add_child(center)
	add_child(_dim)
	_dim.visible = false

func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash.text = ""

func show_screen() -> void:
	visible_now = true
	_page = 0
	_refresh()
	_dim.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not visible_now:
		return
	if event.is_action_pressed("pause_toggle") or event.is_action_pressed("research_toggle"):
		_close()
	elif event is InputEventKey and event.pressed and not event.echo:
		var kc := (event as InputEventKey).keycode
		if kc == KEY_P or kc == KEY_TAB:
			_flip_page()
		else:
			var idx := _key_index(kc)
			if idx >= 0:
				_on_buy(PAGES[_page][idx])

func _key_index(k: Key) -> int:
	var keys: Array = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7]
	var i := 0
	while i < keys.size():
		if k == keys[i]:
			return i
		i += 1
	return -1

func _on_buy(id: String) -> void:
	if knowledge == null or visible_now == false:
		return
	var snap := knowledge.snapshot()
	var res: Dictionary = knowledge.research(id)
	if not res.get("ok", false):
		_flash.text = "CANNOT RESEARCH: " + str(res.get("reason", ""))
		_flash_t = 2.5
		return
	var saved: Dictionary = on_purchase.call(id)
	if not saved.get("ok", false):
		knowledge.restore(snap)
		_flash.text = "SAVE FAILED — PURCHASE REFUNDED"
		_flash_t = 3.0
		return
	_refresh()

func _close() -> void:
	if not visible_now:
		return
	visible_now = false
	_dim.visible = false
	on_close.call()

func _flip_page() -> void:
	_page = (_page + 1) % PAGES.size()
	_refresh()

func _refresh() -> void:
	if knowledge == null:
		return
	var visible: Array = PAGES[_page]
	for id in _rows:
		if not visible.has(id):
			_rows[id]["row"].visible = false
		else:
			_rows[id]["row"].visible = true
			_rows[id]["key"].text = "[%d]" % (int(visible.find(id)) + 1)
	_hint.text = "PAGE %d/%d — P — other line · 1-7 — buy · Esc / G — close" % [_page + 1, PAGES.size()]
	_stats.text = "EARNED %d   SPENT %d   BALANCE %d" % [knowledge.earned_total, knowledge.spent_total, knowledge.balance()]
	for id in _rows:
		var node: Dictionary = ResearchTree.NODES[id]
		var chk: Dictionary = knowledge.can_research(id)
		var state := ""
		if knowledge.researched.has(id):
			state = "RESEARCHED"
		elif chk.get("ok", false):
			state = "READY"
		elif chk.get("reason", "") == "requires":
			var reqs: Array = node["req"]
			state = "needs " + str(ResearchTree.NODES[reqs[0]]["name"])
		else:
			state = "LOW BALANCE"
		_rows[id]["desc"].text = "%s   [%s]" % [str(node["desc"]), state]
		_rows[id]["btn"].disabled = not chk.get("ok", false)
