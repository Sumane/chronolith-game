extends CanvasLayer
## M6 META — save/load, permanent unlocks, hub scene, memory fragments.
## Built last per the dependency plan; owns ZERO in-run gameplay logic.

const SaveStore := preload("res://modules/meta/internal/save_store.gd")
const HubScreen := preload("res://modules/meta/internal/hub_screen.gd")

var store: Node
var unlocks_data: Array = []
var memory_data: Dictionary = {}
var unlocked_ids: Array = []
var ledger_cache: Dictionary = {}

var _hub: Control
var _memory_dialog: Control
var _used_this_run := false
var _current_fragment: Dictionary = {}
var _fragment_index_offset := 0

func _ready() -> void:
	if Contracts.CONTRACT_VERSION != 1:
		push_warning("[Meta] contract version mismatch")
	store = SaveStore.new()
	store.load_save()
	unlocked_ids = store.data.get("unlocked_ids", [])
	var u: Variant = Contracts.load_json("res://modules/meta/data/unlocks.json")
	if typeof(u) == TYPE_DICTIONARY:
		unlocks_data = u.get("unlocks", [])
	var m: Variant = Contracts.load_json("res://modules/meta/data/memory_fragments.json")
	if typeof(m) == TYPE_DICTIONARY:
		memory_data = m
	# build hub UI
	_hub = HubScreen.new()
	add_child(_hub)
	_hub.build_shop(unlocks_data)
	_hub.start_requested.connect(func(): Bus.hub_start_requested.emit({}))
	_hub.unlock_requested.connect(_request_unlock)
	_hub.quit_requested.connect(func(): get_tree().quit())
	# seed economy with banked shards
	Bus.meta_loaded.emit({"SHARDS": int(store.data.get("shards", 0))})
	Bus.unlocks_loaded.emit({
		"unlocked_ids": unlocked_ids,
		"memories_repaired": int(store.data.get("memories_repaired", 0)),
		"memories_seen": int(store.data.get("memories_seen", 0)),
		"runs_completed": int(store.data.get("runs_completed", 0)),
	})
	_broadcast_bonuses()
	Bus.phase_changed.connect(_on_phase_changed)
	Bus.sol_changed.connect(_on_sol_changed)
	Bus.run_started.connect(_on_run_started)
	Bus.resource_changed.connect(func(p: Dictionary) -> void:
		ledger_cache = p.get("ledger", {}))
	Bus.purchase_result.connect(_on_purchase_result)
	Bus.run_ended.connect(_on_run_ended)
	Bus.memory_resolved.connect(_on_memory_resolved)

func _on_phase_changed(payload: Dictionary) -> void:
	var pid := int(payload.get("phase_id", -1))
	_hub.visible = pid == Contracts.Phase.HUB
	if pid == Contracts.Phase.HUB:
		_hub.refresh(ledger_cache, unlocked_ids, store.data)

func _on_run_started(_payload: Dictionary) -> void:
	_used_this_run = false

func _on_sol_changed(payload: Dictionary) -> void:
	# One memory fragment surfaces at the start of sol 2 (GDD §14 slice)
	if int(payload.get("sol", 0)) == 2 and not _used_this_run and _memory_dialog == null:
		_trigger_memory()

func _trigger_memory() -> void:
	_used_this_run = true
	var fragments: Array = memory_data.get("fragments", [])
	if fragments.is_empty():
		return
	var idx := int(store.data.get("memories_seen", 0)) % fragments.size()
	_current_fragment = fragments[idx]
	get_tree().paused = true
	_memory_dialog = _build_memory_dialog(_current_fragment, idx, fragments.size())
	add_child(_memory_dialog)
	Bus.memory_event.emit({
		"title": str(_current_fragment.get("title", "FRAGMENT")),
		"text": str(_current_fragment.get("text", "")),
		"index": idx + 1,
		"total": fragments.size(),
	})

func _build_memory_dialog(fragment: Dictionary, idx: int, total: int) -> Control:
	var root := Control.new()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "%s   (%d / %d)" % [str(fragment.get("title", "FRAGMENT")), idx + 1, total]
	title.add_theme_color_override("font_color", Color("59e6ff"))
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	var body := Label.new()
	body.text = str(fragment.get("text", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(520, 0)
	vbox.add_child(body)
	var hint := Label.new()
	hint.text = "REPAIR the fragment — keep the story, gain a permanent +5%% harvest yield.\nPURGE it — dump its energy into this timeline's resources."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	vbox.add_child(hint)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	vbox.add_child(row)
	var repair_btn := Button.new()
	repair_btn.text = "REPAIR"
	repair_btn.custom_minimum_size = Vector2(180, 44)
	repair_btn.pressed.connect(func(): Bus.memory_resolved.emit({"choice": "repair"}))
	row.add_child(repair_btn)
	var purge_btn := Button.new()
	purge_btn.text = "PURGE"
	purge_btn.custom_minimum_size = Vector2(180, 44)
	purge_btn.pressed.connect(func(): Bus.memory_resolved.emit({"choice": "purge"}))
	row.add_child(purge_btn)
	return root

func _on_memory_resolved(payload: Dictionary) -> void:
	if _memory_dialog == null:
		return
	var choice := str(payload.get("choice", ""))
	var purge_grant: Dictionary = _current_fragment.get("purge_grant", {})
	_memory_dialog.queue_free()
	_memory_dialog = null
	get_tree().paused = false
	match choice:
		"repair":
			store.data["memories_repaired"] = int(store.data.get("memories_repaired", 0)) + 1
			store.data["memories_seen"] = int(store.data.get("memories_seen", 0)) + 1
			store.save()
			_broadcast_bonuses()
			Bus.toast.emit({"text": "Fragment repaired — the Grey remembers (+5% harvest, permanent)", "color": "#59e6ff"})
		"purge":
			store.data["memories_seen"] = int(store.data.get("memories_seen", 0)) + 1
			store.save()
			Bus.grant_resources.emit({"resources": purge_grant})
			Bus.toast.emit({"text": "Fragment purged — story lost for this timeline", "color": "#ff8a5a"})

func _broadcast_bonuses() -> void:
	var hp_flat := 0
	var harvest_bonus := float(memory_data.get("repair_bonus_harvest_per_fragment", 0.05)) * int(store.data.get("memories_repaired", 0))
	for u: Dictionary in unlocks_data:
		if str(u.get("id", "")) in unlocked_ids:
			var effect: Dictionary = u.get("effect", {})
			if str(effect.get("stat", "")) == "hp_flat":
				hp_flat += int(effect.get("value", 0))
			elif str(effect.get("stat", "")) == "harvest_mult":
				harvest_bonus += float(effect.get("value", 0.0))
	Bus.meta_bonuses.emit({"hp_flat": hp_flat, "harvest_mult": 1.0 + harvest_bonus})

func _request_unlock(id: String) -> void:
	for u: Dictionary in unlocks_data:
		if str(u.get("id", "")) == id:
			Bus.purchase_request.emit({
				"req_id": "unlock_%s_%d" % [id, randi()],
				"cost": u.get("cost", {}),
				"tag": "unlock",
				"unlock_id": id,
			})
			return

func _on_purchase_result(payload: Dictionary) -> void:
	if str(payload.get("tag", "")) != "unlock" or not bool(payload.get("ok", false)):
		return
	var id := str(payload.get("unlock_id", ""))
	if id != "" and not (id in unlocked_ids):
		unlocked_ids.append(id)
		store.data["unlocked_ids"] = unlocked_ids
		store.data["shards"] = int(ledger_cache.get("SHARDS", 0))
		store.save()
		Bus.unlock_purchased.emit({"id": id})
		_broadcast_bonuses()

func _on_run_ended(payload: Dictionary) -> void:
	store.data["runs_completed"] = int(store.data.get("runs_completed", 0)) + 1
	store.data["best_sol"] = maxi(int(store.data.get("best_sol", 0)), int(payload.get("sols_survived", 0)))
	store.data["shards"] = int(ledger_cache.get("SHARDS", 0))
	store.save()

func debug_trigger_memory() -> void:
	_trigger_memory()
