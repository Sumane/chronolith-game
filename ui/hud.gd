class_name HudLayer
extends CanvasLayer
## M2 blockout HUD: plain labels, real values. Replaced by the reference-image
## HUD later; the data contracts stay.

var scrap_label: Label
var wave_label: Label
var rover_label: Label
var crystal_label: Label
var banner_label: Label
var hint_label: Label

func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tl := Label.new()
	tl.position = Vector2(16, 12)
	tl.add_theme_font_size_override("font_size", 16)
	root.add_child(tl)
	scrap_label = tl
	var tr := Label.new()
	tr.position = Vector2(16, 40)
	tr.add_theme_font_size_override("font_size", 16)
	root.add_child(tr)
	wave_label = tr
	var br := Label.new()
	br.position = Vector2(16, 84)
	br.add_theme_font_size_override("font_size", 16)
	root.add_child(br)
	rover_label = br
	var bc := Label.new()
	bc.position = Vector2(16, 112)
	bc.add_theme_font_size_override("font_size", 16)
	root.add_child(bc)
	crystal_label = bc
	var ban := Label.new()
	ban.set_anchors_preset(Control.PRESET_CENTER_TOP)
	ban.position = Vector2(-200, 18)
	ban.add_theme_font_size_override("font_size", 22)
	ban.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	root.add_child(ban)
	banner_label = ban
	var hint := Label.new()
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-320, -46)
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	root.add_child(hint)
	hint_label = hint
	add_child(root)

func set_scrap(n: int, cost_w: int, cost_t: int, nukes: int = -1) -> void:
	if nukes >= 0:
		scrap_label.text = "SCRAP %d   (wall %d / turret %d / nuke F x%d)" % [n, cost_w, cost_t, nukes]
	else:
		scrap_label.text = "SCRAP %d   (wall %d / turret %d)" % [n, cost_w, cost_t]

func set_wave(state_name: String, wave: int, total: int, info: String) -> void:
	if total <= 0:
		wave_label.text = "WAVE %d (ENDLESS)  %s  %s" % [wave, state_name, info]
	else:
		wave_label.text = "WAVE %d/%d  %s  %s" % [wave, total, state_name, info]

func set_rover(hp: int, max_hp: int, body_name: String = "ROVER") -> void:
	rover_label.text = "%s  %d/%d" % [body_name, hp, max_hp]

func set_crystal(hp: int, max_hp: int) -> void:
	crystal_label.text = "CRYSTAL  %d/%d" % [hp, max_hp]

func set_banner(text: String) -> void:
	banner_label.text = text

func set_hint(text: String) -> void:
	hint_label.text = text
