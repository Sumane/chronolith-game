extends Node2D
## INTERNAL (rover) — chassis visuals: NASA foil & wheels → Hybrid hover frame.
## Art rule (GDD §4.1): grounded/functional, converging toward grey aesthetic.

var stage := 0
var motion := Vector2.ZERO
var speed := 175.0
var health_frac := 1.0
var wheel_spin := 0.0
var tracers: Array = [] # {a: Vector2 local, b: Vector2 local, ttl}
var muzzle_flashes: Array = [] # {p: Vector2, ttl}
var flash := 0.0
var wrecked := false

func reset(new_stage: int) -> void:
	stage = new_stage
	tracers.clear()
	muzzle_flashes.clear()
	flash = 0.0
	wrecked = false
	health_frac = 1.0
	queue_redraw()

func set_motion(motion_vec: Vector2, move_speed: float) -> void:
	motion = motion_vec
	speed = move_speed
	if stage == 0 and motion.length_squared() > 0.01:
		wheel_spin += motion.length() * move_speed * 0.02

func set_health_frac(frac: float) -> void:
	health_frac = clampf(frac, 0.0, 1.0)

func hit_flash() -> void:
	flash = 1.0

func wreck() -> void:
	wrecked = true
	queue_redraw()

func add_tracer(global_a: Vector2, global_b: Vector2, cyan: bool) -> void:
	tracers.append({"a": to_local(global_a), "b": to_local(global_b), "ttl": 0.09, "cyan": cyan})
	muzzle_flashes.append({"p": to_local(global_a), "ttl": 0.06})

func _process(delta: float) -> void:
	var dirty := false
	for t: Dictionary in tracers:
		t["ttl"] -= delta
		dirty = true
	tracers = tracers.filter(func(t: Dictionary) -> bool: return float(t["ttl"]) > 0.0)
	for m: Dictionary in muzzle_flashes:
		m["ttl"] -= delta
		dirty = true
	muzzle_flashes = muzzle_flashes.filter(func(m: Dictionary) -> bool: return float(m["ttl"]) > 0.0)
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 4.0)
		dirty = true
	if dirty or stage == 1 or not wrecked:
		queue_redraw()

func _draw() -> void:
	if wrecked:
		_draw_wreck()
		return
	var hurt := Color(1, 0.45, 0.35, flash * 0.8)
	if stage == 0:
		_draw_nasa(hurt)
	else:
		_draw_hybrid(hurt)
	_draw_effects()

func _draw_nasa(hurt: Color) -> void:
	# shadow
	draw_circle(Vector2.ZERO, 22, Color(0, 0, 0, 0.25))
	# six wheels (three per side)
	for wx in [-12.0, 0.0, 12.0]:
		for wy in [-15.0, 15.0]:
			var wy2 := float(wy) + (2.0 if wy > 0 else -2.0)
			draw_circle(Vector2(wx, wy2), 5.5, Color(0.13, 0.11, 0.10))
			var spoke_a: float = wheel_spin + float(wx)
			draw_line(
				Vector2(wx, wy2) + Vector2.from_angle(spoke_a) * 3.0,
				Vector2(wx, wy2) - Vector2.from_angle(spoke_a) * 3.0,
				Color(0.32, 0.28, 0.24), 1.2)
	# gold foil chassis
	var body_rect := Rect2(-18, -11, 36, 22)
	draw_rect(body_rect, Color(0.78, 0.58, 0.20).lerp(Color.WHITE, flash * 0.6))
	draw_rect(body_rect.grow(-3), Color(0.9, 0.72, 0.3))
	draw_line(Vector2(-14, -7), Vector2(14, -7), Color(0.65, 0.45, 0.12), 1.5)
	# mast + camera head
	draw_line(Vector2(-6, -11), Vector2(-2, -26), Color(0.25, 0.25, 0.27), 2.0)
	draw_rect(Rect2(-7, -31, 9, 6), Color(0.2, 0.2, 0.22).lerp(Color.WHITE, flash * 0.5))
	draw_circle(Vector2(1.5, -28), 1.6, Color(0.4, 0.75, 0.95))
	# dish at rear
	draw_arc(Vector2(-13, 0), 5.0, PI * 0.25, PI * 1.75, 10, Color(0.85, 0.85, 0.88), 1.5, true)
	# laser emitter front
	draw_circle(Vector2(19, 0), 2.6, Color(1.0, 0.35, 0.2))
	draw_rect(Rect2(-18, -11, 36, 22), hurt, false, 2.0)

func _draw_hybrid(hurt: Color) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	# hover shadow + thruster glow
	_draw_ellipse_shadow()
	var flicker := 0.55 + 0.25 * sin(t * 30.0)
	draw_circle(Vector2(-16, 0), 7.0, Color(0.4, 0.9, 1.0, 0.30 * flicker))
	draw_circle(Vector2(-16, -6), 4.0, Color(0.4, 0.9, 1.0, 0.22 * flicker))
	draw_circle(Vector2(-16, 6), 4.0, Color(0.4, 0.9, 1.0, 0.22 * flicker))
	# sleek biomechanical hexagonal frame — converging toward the grey aesthetic
	var hull := PackedVector2Array([
		Vector2(24, 0), Vector2(10, -12), Vector2(-14, -13),
		Vector2(-22, 0), Vector2(-14, 13), Vector2(10, 12),
	])
	draw_colored_polygon(hull, Color(0.78, 0.84, 0.87).lerp(Color.WHITE, flash * 0.6))
	draw_polyline(hull + PackedVector2Array([hull[0]]), Color("59e6ff"), 1.8, true)
	draw_line(Vector2(-14, 0), Vector2(16, 0), Color("59e6ff"), 1.4)
	draw_circle(Vector2(6, 0), 4.0, Color(0.35, 0.9, 1.0, 0.5 + 0.3 * sin(t * 5.0)))
	# twin manipulator arms
	draw_line(Vector2(8, -10), Vector2(20, -17), Color(0.6, 0.68, 0.72), 2.0)
	draw_line(Vector2(8, 10), Vector2(20, 17), Color(0.6, 0.68, 0.72), 2.0)
	# emitters
	draw_circle(Vector2(21, -6), 2.4, Color(0.55, 0.95, 1.0))
	draw_circle(Vector2(21, 6), 2.4, Color(0.55, 0.95, 1.0))
	draw_polyline(hull + PackedVector2Array([hull[0]]), hurt, 2.0, true)

func _draw_wreck() -> void:
	draw_circle(Vector2.ZERO, 20, Color(0.12, 0.1, 0.09))
	draw_rect(Rect2(-16, -9, 32, 18), Color(0.3, 0.24, 0.18))
	draw_line(Vector2(-14, -8), Vector2(12, 9), Color(0.16, 0.13, 0.11), 3.0)
	var t := Time.get_ticks_msec() / 1000.0
	for i in 5:
		var a := t * 0.8 + float(i) * TAU / 5.0
		var p := Vector2.from_angle(a) * (10.0 + 6.0 * sin(t * 2.0 + i))
		draw_circle(p, 3.0 + 2.0 * sin(t * 3.0 + i), Color(0.25, 0.2, 0.18, 0.5))

func _draw_ellipse_shadow() -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a) * 24.0, sin(a) * 14.0))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.22))

func _draw_effects() -> void:
	for t: Dictionary in tracers:
		var alpha := clampf(float(t["ttl"]) / 0.09, 0.0, 1.0)
		var col := Color(0.55, 0.95, 1.0, alpha) if bool(t["cyan"]) else Color(1.0, 0.55, 0.25, alpha)
		draw_line(t["a"], t["b"], col, 2.0)
		draw_line(t["a"], t["a"] + (t["b"] - t["a"]).normalized() * 6.0, Color(1, 1, 1, alpha), 1.0)
	for m: Dictionary in muzzle_flashes:
		var alpha := clampf(float(m["ttl"]) / 0.06, 0.0, 1.0)
		draw_circle(m["p"], 5.0 * alpha + 2.0, Color(1.0, 0.85, 0.5, alpha * 0.9))
