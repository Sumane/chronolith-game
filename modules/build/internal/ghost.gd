extends Node2D
## INTERNAL (build) — placement ghost preview. Shows validity + range rings.

var btype := ""
var valid := true
var range_r := 0.0
var scan_r := 0.0
var radius := 20.0

func queue_redraw_with(type: String, def: Dictionary, is_valid: bool, show_range: float, show_scan: float) -> void:
	btype = type
	valid = is_valid
	range_r = show_range
	scan_r = show_scan
	radius = float(def.get("radius", 20))
	queue_redraw()

func _draw() -> void:
	if btype == "":
		return
	var col := Color(0.5, 1.0, 0.6, 0.9) if valid else Color(1.0, 0.4, 0.35, 0.9)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 24, col, 2.0, true)
	draw_circle(Vector2.ZERO, 3, col)
	if scan_r > 0.0:
		draw_arc(Vector2.ZERO, scan_r, 0, TAU, 48, Color(col.r, col.g, col.b, 0.35), 1.4, true)
	elif range_r > 0.0:
		draw_arc(Vector2.ZERO, range_r, 0, TAU, 48, Color(col.r, col.g, col.b, 0.35), 1.4, true)
