extends Node2D
## INTERNAL (chronolith) — crystal + dilation bubble visuals.

var _flash := 0.0
var _pulse := 0.0

func reset() -> void:
	_flash = 0.0
	queue_redraw()

func hit_flash() -> void:
	_flash = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	_pulse += delta * 2.0
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.0)
	queue_redraw()

func _draw() -> void:
	var cfg: Dictionary = Contracts.load_json("res://modules/chronolith/data/chronolith.json")
	var radius := float(cfg.get("bubble_radius", 245))
	# --- dilation bubble ---
	var breathe := radius + 4.0 * sin(_pulse * 0.7)
	draw_circle(Vector2.ZERO, breathe, Color(0.35, 0.9, 1.0, 0.05))
	draw_arc(Vector2.ZERO, breathe, 0, TAU, 72, Color(0.35, 0.9, 1.0, 0.30), 1.6, true)
	# rotating rune ticks — cool clean light, the only sanctuary color (GDD §11)
	for i in 12:
		var a := _pulse * 0.25 + TAU * float(i) / 12.0
		var p0 := Vector2.from_angle(a) * (breathe - 8)
		var p1 := Vector2.from_angle(a) * (breathe + 4)
		draw_line(p0, p1, Color(0.45, 0.95, 1.0, 0.5), 2.0)
	# --- plinth ---
	draw_circle(Vector2.ZERO, 46, Color(0.16, 0.13, 0.11))
	draw_arc(Vector2.ZERO, 46, 0, TAU, 40, Color(0.42, 0.32, 0.24), 3.0, true)
	# --- crystal (elongated kite) ---
	var glow := 0.55 + 0.18 * sin(_pulse)
	var flash := _flash
	draw_circle(Vector2(0, -34), 60, Color(0.35, 0.9, 1.0, 0.10 * glow))
	var body := PackedVector2Array([
		Vector2(0, -110), Vector2(26, -44), Vector2(16, 34), Vector2(-16, 34), Vector2(-26, -44),
	])
	var bright := Color(0.55, 0.93, 1.0).lerp(Color.WHITE, flash)
	var dark := Color(0.12, 0.5, 0.65).lerp(Color.WHITE, flash * 0.6)
	draw_colored_polygon(body, dark)
	var facet := PackedVector2Array([Vector2(0, -110), Vector2(26, -44), Vector2(0, 20)])
	draw_colored_polygon(facet, bright * Color(1, 1, 1, 0.85))
	draw_polyline(body + PackedVector2Array([body[0]]), bright.lightened(0.2), 2.0, true)
	# cracks when hurt handled via controller integrity? keep simple: flash conveys hits
	draw_string(ThemeDB.fallback_font, Vector2(-38, 66), "THE CHRONOLITH", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.92, 1.0, 0.75))
