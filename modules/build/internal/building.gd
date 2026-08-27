extends Node2D
## INTERNAL (build) — a single placed structure: wall / turret / solar / scanner.

var bid := 0
var btype := "wall"
var hp := 100
var max_hp := 100
var radius := 20.0
var power_draw := 0
var power_gen := 0
var range_r := 0.0
var scan_radius := 0.0
var damage := 0
var fire_interval := 1.0
var fire_cd := 0.0
var powered := true
var angle := 0.0
var tracers: Array = []
var flash := 0.0
var _cfg_color := Color.WHITE

func setup(id: int, type: String, def: Dictionary) -> void:
	bid = id
	btype = type
	hp = int(def.get("hp", 100))
	max_hp = hp
	radius = float(def.get("radius", 20))
	power_draw = int(def.get("power_draw", 0))
	power_gen = int(def.get("power_gen", 0))
	range_r = float(def.get("range", 0))
	scan_radius = float(def.get("scan_radius", 0))
	damage = int(def.get("damage", 0))
	fire_interval = float(def.get("fire_interval", 1.0))
	fire_cd = 0.0
	_cfg_color = Color.from_string(str(def.get("color", "#ffffff")), Color.WHITE)

func set_powered(on: bool) -> void:
	if powered != on:
		powered = on
		queue_redraw()

func aim_at(target: Vector2) -> void:
	angle = (target - global_position).angle()
	queue_redraw()

func add_tracer(global_target: Vector2) -> void:
	tracers.append({"b": to_local(global_target), "ttl": 0.08})
	queue_redraw()

func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)
	flash = 0.5
	queue_redraw()

func take_damage(dmg: int) -> void:
	hp = maxi(0, hp - dmg)
	flash = 1.0
	queue_redraw()

func die() -> void:
	set_process(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)

func _process(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 3.0)
	var dirty := flash > 0.0
	for t: Dictionary in tracers:
		t["ttl"] -= delta
		dirty = true
	tracers = tracers.filter(func(t: Dictionary) -> bool: return float(t["ttl"]) > 0.0)
	if btype == "scanner" and powered and hp > 0:
		dirty = true # sweeping arc animates
	if dirty:
		queue_redraw()

func _draw() -> void:
	var dead_tint := 0.55 if not powered else 1.0
	var col := _cfg_color * Color(dead_tint, dead_tint, dead_tint)
	match btype:
		"wall":
			_draw_wall(col)
		"turret":
			_draw_turret(col)
		"solar":
			_draw_solar(col)
		"scanner":
			_draw_scanner(col)
	_draw_shared()

func _draw_wall(c: Color) -> void:
	draw_rect(Rect2(-radius, -radius, radius * 2, radius * 2), c.darkened(0.15))
	draw_rect(Rect2(-radius + 3, -radius + 3, radius * 2 - 6, radius - 2), c.lightened(0.08))
	draw_rect(Rect2(-radius + 3, 2, radius * 2 - 6, radius - 5), c.lightened(0.02))
	draw_rect(Rect2(-radius, -radius, radius * 2, radius * 2), c.lightened(0.25), false, 2.0)

func _draw_turret(c: Color) -> void:
	draw_circle(Vector2.ZERO, radius, c.darkened(0.35))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 20, c.lightened(0.2), 2.0, true)
	if powered and hp > 0:
		draw_circle(Vector2.ZERO, radius - 6, c.darkened(0.15))
		draw_line(Vector2.ZERO, Vector2.from_angle(angle) * (radius + 8), c.lightened(0.4), 4.0)

func _draw_solar(c: Color) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	draw_rect(Rect2(-radius, -radius * 0.72, radius * 2, radius * 1.44), Color(0.16, 0.14, 0.12))
	var panel_col := c * (Color(1.15, 1.15, 1.3) if powered else Color(0.5, 0.5, 0.5))
	panel_col = panel_col.lerp(Color(1.2, 1.2, 1.4), 0.06 * sin(t * 2.0) if powered else 0.0)
	draw_rect(Rect2(-radius + 3, -radius * 0.72 + 3, radius * 2 - 6, radius * 1.44 - 6), panel_col)
	for gx in [-8.0, 0.0, 8.0]:
		draw_line(Vector2(gx, -radius * 0.72 + 3), Vector2(gx, radius * 0.72 - 3), Color(0.1, 0.1, 0.14), 1.0)

func _draw_scanner(c: Color) -> void:
	if powered and hp > 0:
		var sweep := fmod(Time.get_ticks_msec() / 1400.0, 1.0) * TAU
		var pts := PackedVector2Array([Vector2.ZERO])
		for i in 13:
			var a := sweep - PI * 0.28 + PI * 0.56 * float(i) / 12.0
			pts.append(Vector2.from_angle(a) * scan_radius)
		var sweep_cols := PackedColorArray()
		for i in pts.size():
			sweep_cols.append(Color(0.35, 0.76, 0.84, 0.10 if i == 0 else float(i) / 24.0))
		draw_polygon(pts, sweep_cols)
		draw_arc(Vector2.ZERO, scan_radius, 0, TAU, 48, Color(0.35, 0.76, 0.84, 0.22), 1.2, true)
	draw_line(Vector2(0, 8), Vector2(0, -14), c.lightened(0.2), 3.0)
	draw_circle(Vector2(0, -16), 5, c if powered else c.darkened(0.5))
	draw_circle(Vector2(0, -16), 2, Color(0.9, 1.0, 1.0) if powered else Color(0.3, 0.3, 0.3))

func _draw_shared() -> void:
	if flash > 0.0:
		draw_circle(Vector2.ZERO, radius + 4, Color(1, 0.5, 0.4, flash * 0.5))
	if hp < max_hp and hp > 0:
		var frac := float(hp) / float(max_hp)
		draw_rect(Rect2(-radius, -radius - 10, radius * 2, 4), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(-radius, -radius - 10, radius * 2 * frac, 4), Color(0.45, 0.9, 0.5))
	for t: Dictionary in tracers:
		var alpha := clampf(float(t["ttl"]) / 0.08, 0.0, 1.0)
		draw_line(Vector2.ZERO, t["b"], Color(1.0, 0.8, 0.4, alpha), 1.6)
	if not powered and power_draw > 0:
		draw_string(ThemeDB.fallback_font, Vector2(-6, -radius - 14), "offline", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.85, 0.3))
