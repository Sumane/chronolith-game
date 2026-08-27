extends Node2D
## INTERNAL (environment) — procedural Mars backdrop, vessel landmark, nodes.
## Pure rendering + hit-free visuals. Drawn once; redrawn when node amounts change.

const NODE_COLORS := {
	"REGOLITH": Color("b08a5e"),
	"SCRAP": Color("9aa0a6"),
	"RARE": Color("4fe3c1"),
}

var _map: Dictionary = {}
var _nodes: Array = []
var _bg: ImageTexture
var _time := 0.0

func setup(map_data: Dictionary, nodes: Array) -> void:
	_map = map_data
	_nodes = nodes
	_build_background()
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	if _time > 0.25:
		_time = 0.0
		queue_redraw() # gentle node shimmer only

func _build_background() -> void:
	var w := int(_map.get("map_w", 1920))
	var h := int(_map.get("map_h", 1280))
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var base := Color("6e4a33")
	for y in h:
		var t := float(y) / float(h)
		var row := base.lerp(Color("8a5a3a"), t * 0.55)
		for x in range(0, w, 4):
			var c := row * (0.92 + 0.16 * sin(float(x) * 0.031 + float(y) * 0.017))
			c = c.lerp(Color("54382a"), randf() * 0.22)
			for dx in 4:
				if x + dx < w:
					img.set_pixel(x + dx, y, c)
	_bg = ImageTexture.create_from_image(img)

func _draw() -> void:
	if _bg != null:
		draw_texture(_bg, Vector2.ZERO)
	# craters
	for cr: Dictionary in _map.get("craters", []):
		var p := Contracts.vec2_of(cr)
		var r := float(cr.get("r", 60))
		draw_circle(p, r, Color(0.24, 0.15, 0.10, 0.85))
		draw_arc(p, r, 0, TAU, 40, Color(0.62, 0.42, 0.28, 0.7), 4.0, true)
		draw_arc(p, r * 0.72, 0, TAU, 32, Color(0.30, 0.19, 0.13, 0.6), 2.0, true)
	# ridges (dark rock slabs)
	for ridge: Dictionary in _map.get("ridges", []):
		var pts := PackedVector2Array()
		for pt: Dictionary in ridge.get("pts", []):
			pts.append(Contracts.vec2_of(pt))
		if pts.size() >= 3:
			draw_colored_polygon(pts, Color(0.33, 0.23, 0.17, 0.95))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.58, 0.40, 0.27, 0.8), 3.0, true)
	# tunnel holes (burrower emergence points)
	for hole: Dictionary in _map.get("tunnel_holes", []):
		var hp := Contracts.vec2_of(hole)
		draw_circle(hp, 26, Color(0.12, 0.07, 0.05, 0.95))
		draw_arc(hp, 26, 0, TAU, 24, Color(0.45, 0.3, 0.2, 0.8), 3.0, true)
	# crashed grey vessel — clean, straight-lined, precision (art rule §11)
	var v := Contracts.vec2_of(_map.get("vessel", {"x": 340, "y": 300}))
	_draw_vessel(v)
	# harvest nodes
	for n: Dictionary in _nodes:
		_draw_node(n)

func _draw_vessel(v: Vector2) -> void:
	var glow := 0.5 + 0.14 * sin(Time.get_ticks_msec() / 700.0)
	draw_circle(v, 130, Color(0.35, 0.75, 0.9, 0.05 * glow))
	# hull: long straight wedge
	var hull := PackedVector2Array([
		v + Vector2(-120, -34), v + Vector2(96, -46), v + Vector2(150, 0),
		v + Vector2(96, 46), v + Vector2(-120, 34), v + Vector2(-150, 0),
	])
	draw_colored_polygon(hull, Color("dfe7ea"))
	draw_polyline(hull + PackedVector2Array([hull[0]]), Color("59e6ff"), 2.5, true)
	# spine + straight landing legs (Star-Wars-style, art rule)
	draw_line(v + Vector2(-110, 0), v + Vector2(120, 0), Color("59e6ff"), 2.0)
	for leg_x in [-100.0, -20.0, 70.0]:
		draw_line(v + Vector2(leg_x, 38), v + Vector2(leg_x - 26, 86), Color("cfd8dc"), 4.0)
		draw_line(v + Vector2(leg_x, -38), v + Vector2(leg_x - 26, -86), Color("cfd8dc"), 4.0)
	# cockpit slit
	draw_line(v + Vector2(96, -10), v + Vector2(134, -2), Color("59e6ff"), 3.0)
	draw_line(v + Vector2(96, 10), v + Vector2(134, 2), Color("59e6ff"), 3.0)
	draw_string(ThemeDB.fallback_font, v + Vector2(-52, -56), "CRASHED VESSEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.9, 1.0, 0.65))

func _draw_node(n: Dictionary) -> void:
	var p := Vector2(float(n["x"]), float(n["y"]))
	var kind := str(n["kind"])
	var amount := int(n["amount"])
	var max_amount := maxi(1, int(n.get("max", amount)))
	var col: Color = NODE_COLORS.get(kind, Color.WHITE)
	if amount <= 0:
		draw_circle(p, 16, Color(0.2, 0.16, 0.13, 0.5))
		return
	match kind:
		"REGOLITH":
			draw_circle(p, 22, col.darkened(0.25))
			draw_circle(p, 15, col)
			draw_circle(p + Vector2(-8, -6), 7, col.lightened(0.15))
		"SCRAP":
			var pts := PackedVector2Array([
				p + Vector2(-18, 8), p + Vector2(-6, -14), p + Vector2(8, -6),
				p + Vector2(18, 10), p + Vector2(2, 16),
			])
			draw_colored_polygon(pts, col.darkened(0.2))
			draw_polyline(pts + PackedVector2Array([pts[0]]), col, 2.0, true)
			draw_line(p + Vector2(-8, -2), p + Vector2(10, 4), col.lightened(0.3), 2.0)
		"RARE":
			var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 300.0)
			draw_circle(p, 20, Color(0.31, 0.89, 0.76, 0.10 * pulse))
			for i in 3:
				var off := Vector2(-10 + 10 * i, 4 - (6 if i % 2 == 0 else 0))
				var crys := PackedVector2Array([
					p + off + Vector2(0, -14), p + off + Vector2(6, 0), p + off + Vector2(0, 8), p + off + Vector2(-6, 0),
				])
				draw_colored_polygon(crys, col * pulse)
	# remaining bar
	var frac := float(amount) / float(max_amount)
	draw_rect(Rect2(p + Vector2(-18, 24), Vector2(36, 4)), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(p + Vector2(-18, 24), Vector2(36.0 * frac, 4)), col)
