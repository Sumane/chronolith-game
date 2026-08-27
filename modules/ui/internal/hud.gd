extends Control
## INTERNAL (ui) — the HUD. Renders latest event payloads; owns no game state.

var ledger: Dictionary = {}
var integrity := 1.0
var rover_hp := 1.0
var rewind_frac := 1.0
var rewind_ready := true
var power_text := "0 / 0"
var sol_num := 0
var phase_name := "HUB"
var wave_text := ""
var calm_frac := 0.0
var calm_visible := false
var night_alpha := 0.0
var storm_alpha := 0.0
var paused := false

var _flash_label: Label
var _night_rect: ColorRect
var _storm_rect: ColorRect
var _pause_label: Label
var _help_panel: Control
var _toasts: VBoxContainer
var _begin_night_btn: Button
var _res_labels := {}
var _status_label: Label

const RES_ORDER := ["REGOLITH", "SCRAP", "RARE", "POWER", "SHARDS", "DNA"]
const RES_COLORS := {
	"REGOLITH": Color("d8b088"), "SCRAP": Color("c9ced4"), "RARE": Color("4fe3c1"),
	"POWER": Color("ffe27a"), "SHARDS": Color("59e6ff"), "DNA": Color("e07be0"),
}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# night / storm overlays (behind everything in this layer)
	_night_rect = ColorRect.new()
	_night_rect.color = Color(0.02, 0.05, 0.13, 0.0)
	_night_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_night_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_night_rect)
	_storm_rect = ColorRect.new()
	_storm_rect.color = Color(0.55, 0.35, 0.18, 0.0)
	_storm_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_storm_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_storm_rect)
	_build_widgets()

func _build_widgets() -> void:
	# resources — top-left
	var res_box := VBoxContainer.new()
	res_box.position = Vector2(16, 12)
	res_box.add_theme_constant_override("separation", 2)
	add_child(res_box)
	for kind in ["REGOLITH", "SCRAP", "RARE"]:
		var l := Label.new()
		l.add_theme_color_override("font_color", RES_COLORS[kind])
		l.add_theme_font_size_override("font_size", 17)
		l.text = "%s  0" % kind
		res_box.add_child(l)
		_res_labels[kind] = l
	var meta_row := HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 14)
	res_box.add_child(meta_row)
	for kind in ["SHARDS", "DNA"]:
		var l := Label.new()
		l.add_theme_color_override("font_color", RES_COLORS[kind])
		l.add_theme_font_size_override("font_size", 15)
		l.text = "%s 0" % kind
		meta_row.add_child(l)
		_res_labels[kind] = l
	var power_l := Label.new()
	power_l.add_theme_color_override("font_color", RES_COLORS["POWER"])
	power_l.add_theme_font_size_override("font_size", 15)
	power_l.text = "POWER —"
	res_box.add_child(power_l)
	_res_labels["_power"] = power_l
	# status — top-right
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 19)
	_status_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_status_label.offset_left = -420
	_status_label.offset_right = -16
	_status_label.offset_top = 10
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_status_label)
	# toasts — right side under status
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toasts.offset_left = -480
	_toasts.offset_right = -16
	_toasts.offset_top = 44
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.add_theme_constant_override("separation", 4)
	add_child(_toasts)
	# begin night button — bottom-right
	_begin_night_btn = Button.new()
	_begin_night_btn.text = "BEGIN NIGHT [N]"
	_begin_night_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_begin_night_btn.offset_left = -220
	_begin_night_btn.offset_right = -16
	_begin_night_btn.offset_top = -58
	_begin_night_btn.offset_bottom = -16
	_begin_night_btn.visible = false
	_begin_night_btn.pressed.connect(func(): Bus.player_skip_calm.emit({}))
	add_child(_begin_night_btn)
	# flash label — center
	_flash_label = Label.new()
	_flash_label.set_anchors_preset(Control.PRESET_CENTER)
	_flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash_label.add_theme_font_size_override("font_size", 40)
	_flash_label.modulate.a = 0.0
	add_child(_flash_label)
	# pause overlay
	_pause_label = Label.new()
	_pause_label.text = "PAUSED"
	_pause_label.set_anchors_preset(Control.PRESET_CENTER)
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_label.add_theme_font_size_override("font_size", 52)
	_pause_label.visible = false
	add_child(_pause_label)
	# help panel
	_help_panel = _build_help()
	add_child(_help_panel)

func _build_help() -> Control:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.custom_minimum_size = Vector2(520, 0)
	p.visible = false
	var v := VBoxContainer.new()
	p.add_child(v)
	var t := Label.new()
	t.text = "CONTROLS"
	t.add_theme_color_override("font_color", Color("59e6ff"))
	v.add_child(t)
	for line in [
		"WASD / arrows — drive",
		"Mouse aim · LMB or SPACE — fire laser",
		"Hold near resource node — harvest (auto)",
		"E hold near damaged structure — repair (2 scrap/tick)",
		"1 Wall · 2 Turret · 3 Solar · 4 Scanner — select, click to place",
		"X / RMB — cancel placement   ·   U — evolve rover (needs Rare+Scrap)",
		"R — REWIND the last 5 seconds (Chronolith active)",
		"N — skip calm phase · H — this help · ESC — pause",
	]:
		var l := Label.new()
		l.text = line
		v.add_child(l)
	return p

func toggle_help() -> void:
	_help_panel.visible = not _help_panel.visible

func set_paused(is_paused: bool) -> void:
	paused = is_paused
	_pause_label.visible = is_paused

# ------------------------------------------------------------- updaters --
func update_ledger(new_ledger: Dictionary) -> void:
	ledger = new_ledger
	for kind: String in _res_labels:
		if kind.begins_with("_"):
			continue
		if _res_labels[kind] is Label and ledger.has(kind):
			var l: Label = _res_labels[kind]
			l.text = "%s  %d" % [kind, int(ledger[kind])]
	queue_redraw()

func update_power(payload: Dictionary) -> void:
	power_text = "%d / %d" % [int(payload.get("draw", 0)), int(payload.get("capacity", 0))]
	var unpowered: Array = payload.get("unpowered_ids", [])
	var warn := unpowered.size() > 0
	var pl: Label = _res_labels["_power"]
	pl.text = "POWER %s%s" % [power_text, "  ⚠ OFFLINE" if warn else ""]
	pl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3) if warn else RES_COLORS["POWER"])

func update_integrity(payload: Dictionary) -> void:
	integrity = float(payload.get("integrity", 0)) / maxf(1.0, float(payload.get("max_integrity", 500)))
	queue_redraw()

func update_rover_hp(payload: Dictionary) -> void:
	rover_hp = float(payload.get("hp", 0)) / maxf(1.0, float(payload.get("max_hp", 100)))
	queue_redraw()

func update_rewind(payload: Dictionary) -> void:
	rewind_ready = bool(payload.get("ready", false))
	rewind_frac = 1.0 if rewind_ready else 1.0 - clampf(float(payload.get("remaining", 0)) / maxf(0.01, float(payload.get("duration", 40))), 0.0, 1.0)
	queue_redraw()

func update_sol(n: int) -> void:
	sol_num = n
	_refresh_status()

func update_phase(payload: Dictionary) -> void:
	phase_name = str(payload.get("phase", ""))
	calm_visible = phase_name == "CALM"
	_begin_night_btn.visible = calm_visible
	night_alpha = 0.42 if phase_name == "ASSAULT" else 0.06 if phase_name == "CALM" else 0.25
	if phase_name == "RESET":
		wave_text = ""
	_refresh_status()

func update_calm(payload: Dictionary) -> void:
	calm_frac = 1.0 - clampf(float(payload.get("remaining", 0)) / maxf(0.01, float(payload.get("duration", 75))), 0.0, 1.0)
	_refresh_status()
	queue_redraw()

func update_wave_started(payload: Dictionary) -> void:
	wave_text = "hostiles inbound: %d" % int(payload.get("total", 0))
	_refresh_status()

func update_wave_progress(payload: Dictionary) -> void:
	wave_text = "hostiles: %d alive · %d incoming" % [int(payload.get("alive", 0)), int(payload.get("queued", 0))]
	_refresh_status()

func update_wave_cleared() -> void:
	wave_text = "WAVE CLEARED"
	_refresh_status()

func update_environment(payload: Dictionary) -> void:
	storm_alpha = 0.28 if bool(payload.get("storm", false)) else 0.0
	if bool(payload.get("storm", false)):
		add_toast("DUST STORM — solar output crippled, optics degraded", "#ffb46a")

func _refresh_status() -> void:
	_status_label.text = "SOL %d — %s\n%s" % [sol_num, phase_name, wave_text]

func flash_run_end(reason: String) -> void:
	match reason:
		"victory":
			_flash_label.text = "TIMELINE SECURED\nreality rewinds…"
			_flash_label.add_theme_color_override("font_color", Color("aef4ff"))
		"chronolith_lost":
			_flash_label.text = "THE CHRONOLITH FALLS\ntimeline collapses…"
			_flash_label.add_theme_color_override("font_color", Color("ff7a6a"))
		_:
			_flash_label.text = "ROVER TOTALLED\nconsciousness scatters…"
			_flash_label.add_theme_color_override("font_color", Color("ff7a6a"))
	_flash_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_flash_label, "modulate:a", 1.0, 0.35)
	tw.tween_interval(2.0)
	tw.tween_property(_flash_label, "modulate:a", 0.0, 0.5)

func add_toast(text: String, color_hex: String = "#ffffff", life := 4.0) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(460, 0)
	l.add_theme_color_override("font_color", Color.from_string(color_hex, Color.WHITE))
	_toasts.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(life)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)
	while _toasts.get_child_count() > 5:
		_toasts.get_child(0).queue_free()

# ------------------------------------------------------------------ draw --
func _process(delta: float) -> void:
	var dirty := false
	for r: ColorRect in [_night_rect, _storm_rect]:
		var target := night_alpha if r == _night_rect else storm_alpha
		if absf(r.color.a - target) > 0.001:
			r.color.a = move_toward(r.color.a, target, delta * 0.8)
			dirty = true
	if dirty:
		pass # ColorRects redraw themselves

func _draw() -> void:
	var vp_size := size
	# chronolith integrity bar — top center
	var bar_w := 380.0
	var bx := vp_size.x * 0.5 - bar_w * 0.5
	draw_rect(Rect2(bx, 14, bar_w, 14), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(bx + 2, 16, (bar_w - 4) * integrity, 10), Color("59e6ff"))
	draw_string(ThemeDB.fallback_font, Vector2(bx, 44), "CHRONOLITH INTEGRITY", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.65, 0.9, 1.0, 0.85))
	# rewind cooldown under it
	var rw_col := Color("59e6ff") if rewind_ready else Color(0.35, 0.55, 0.62)
	draw_rect(Rect2(bx, 50, bar_w, 6), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(bx, 50, bar_w * rewind_frac, 6), rw_col)
	draw_string(ThemeDB.fallback_font, Vector2(bx + bar_w + 10, 57), "REWIND [R]" + (" READY" if rewind_ready else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, rw_col)
	# rover hp — bottom-left
	var hp_y := vp_size.y - 34.0
	draw_rect(Rect2(16, hp_y, 260, 12), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(18, hp_y + 2, 256 * rover_hp, 8), Color(0.95, 0.75, 0.3) if rover_hp > 0.35 else Color(1.0, 0.4, 0.3))
	draw_string(ThemeDB.fallback_font, Vector2(16, hp_y - 4), "ROVER CHASSIS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.8, 0.6))
	# calm progress — top center under rewind
	if calm_visible:
		draw_rect(Rect2(bx, 64, bar_w, 6), Color(0, 0, 0, 0.4))
		draw_rect(Rect2(bx, 64, bar_w * calm_frac, 6), Color(1.0, 0.82, 0.45))
