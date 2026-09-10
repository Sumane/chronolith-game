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
# M12: health bars — rover top-left, crystal bottom-center
var rover_bar_bg: ColorRect
var rover_bar_fill: ColorRect
var crystal_bar_bg: ColorRect
var crystal_bar_fill: ColorRect
const ROVER_BAR_W := 220
const ROVER_BAR_H := 14
const CRYSTAL_BAR_W := 260
const CRYSTAL_BAR_H := 14

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
	# M12: rover health bar, top-left (label moves below it)
	rover_bar_bg = _bar(ROVER_BAR_W, ROVER_BAR_H, Color(0.08, 0.1, 0.12, 0.85))
	rover_bar_bg.position = Vector2(16, 62)
	root.add_child(rover_bar_bg)
	rover_bar_fill = _bar_fill(Color(0.35, 0.85, 0.4), ROVER_BAR_W, ROVER_BAR_H)
	rover_bar_bg.add_child(rover_bar_fill)
	var br := Label.new()
	br.position = Vector2(16, 79)
	br.add_theme_font_size_override("font_size", 16)
	root.add_child(br)
	rover_label = br
	# M12: crystal health bar, bottom-center (label moves above it)
	crystal_bar_bg = _bar(CRYSTAL_BAR_W, CRYSTAL_BAR_H, Color(0.08, 0.1, 0.12, 0.85))
	crystal_bar_bg.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	crystal_bar_bg.position = Vector2(-CRYSTAL_BAR_W / 2.0, -38)
	root.add_child(crystal_bar_bg)
	crystal_bar_fill = _bar_fill(Color(0.45, 0.65, 1.0), CRYSTAL_BAR_W, CRYSTAL_BAR_H)
	crystal_bar_bg.add_child(crystal_bar_fill)
	var bc := Label.new()
	bc.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bc.position = Vector2(-60, -58)
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
	_set_fill(rover_bar_fill, ROVER_BAR_W, hp, max_hp)

func set_crystal(hp: int, max_hp: int) -> void:
	crystal_label.text = "CRYSTAL  %d/%d" % [hp, max_hp]
	_set_fill(crystal_bar_fill, CRYSTAL_BAR_W, hp, max_hp)

## Build a left-anchored health bar (background plate + inset fill).
func _bar(w: int, h: int, bg_color: Color) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = bg_color
	bg.custom_minimum_size = Vector2(w, h)
	bg.size = Vector2(w, h)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bg

func _bar_fill(color: Color, w: int, h: int) -> ColorRect:
	var f := ColorRect.new()
	f.color = color
	f.position = Vector2(2, 2)
	f.size = Vector2(w - 4, h - 4)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return f

func _set_fill(fill: ColorRect, w: int, hp: int, max_hp: int) -> void:
	var inner := float(w - 4)
	var r := clampf(float(hp) / float(maxi(1, max_hp)), 0.0, 1.0)
	fill.size = Vector2(inner * r, fill.size.y)

func set_banner(text: String) -> void:
	banner_label.text = text

func set_hint(text: String) -> void:
	hint_label.text = text
