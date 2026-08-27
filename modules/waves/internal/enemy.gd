extends Node2D
## INTERNAL (waves) — one Reptilian. Behaviour per type (GDD §8):
## Trooper: mass rush, chews through whatever blocks the path.
## Stalker: cloaked, hunts the ROVER; revealed by scanner masts / rover proximity.
## Burrower: tunnels under everything, emerges at a tunnel hole near the base.

const STATE_WALK := 0
const STATE_UNDERGROUND := 1
const STATE_EMERGING := 2
const STATE_DYING := 3

var eid := 0
var etype := "trooper"
var cfg: Dictionary = {}
var alive := true
var hp := 10
var max_hp := 10
var radius := 13.0
var speed := 58.0
var damage := 5
var attack_interval := 1.0
var cloaked := false

var state := STATE_WALK
var jitter := Vector2.ZERO
var target_hole := Vector2.ZERO
var attack_cd := 0.0
var emerge_t := 0.0
var died_at := 0.0
var history: Array = [] # [t, x, y, hp] ring, ~6 s @ 10 Hz
var flash := 0.0
var reveal_alpha := 1.0
var _walk_phase := randf() * TAU

# injected world state (set by controller each tick)
var crystal_pos := Vector2(960, 640)
var bubble_x := 960.0
var bubble_y := 640.0
var bubble_radius := 245.0
var slow_factor := 0.55
var layout: Array = []
var rover_pos := Vector2(960, 780)
var rover_alive := true

func setup(id: int, type: String, def: Dictionary, spawn_pos: Vector2) -> void:
	eid = id
	etype = type
	cfg = def
	hp = int(def.get("hp", 10))
	max_hp = hp
	radius = float(def.get("radius", 12))
	speed = float(def.get("speed", 50))
	damage = int(def.get("damage", 5))
	attack_interval = float(def.get("attack_interval", 1.0))
	cloaked = bool(def.get("cloak", false))
	jitter = Vector2.from_angle(randf() * TAU) * randf_range(4.0, 26.0)
	position = spawn_pos
	if bool(def.get("burrows", false)):
		state = STATE_UNDERGROUND
		var holes: Array = get_parent().tunnel_holes if get_parent() != null else []
		if holes.is_empty():
			target_hole = crystal_pos + Vector2.from_angle(randf() * TAU) * 160.0
		else:
			var hole: Dictionary = holes[randi_range(0, holes.size() - 1)]
			target_hole = Contracts.vec2_of(hole)

func effective_speed() -> float:
	if state == STATE_UNDERGROUND:
		return float(cfg.get("underground_speed", speed))
	var s := speed
	if Vector2(bubble_x, bubble_y).distance_to(position) <= bubble_radius:
		s *= slow_factor # dilation bubble — time crawls inside (GDD §5.1)
	return s

func take_damage(dmg: int) -> void:
	hp = maxi(0, hp - dmg)
	flash = 1.0

func die() -> void:
	alive = false
	state = STATE_DYING
	died_at = Time.get_ticks_msec() / 1000.0

func restore(pos_: Vector2, hp_: int) -> void:
	position = pos_
	hp = hp_

func resurrect(pos_: Vector2, hp_: int) -> void:
	alive = true
	flash = 0.0
	hp = mini(hp_, max_hp)
	position = pos_
	modulate.a = 1.0
	state = STATE_WALK if state != STATE_UNDERGROUND else STATE_UNDERGROUND
	if state == STATE_DYING:
		state = STATE_WALK

func sample_at(t: float) -> Array:
	for sample: Array in history:
		if float(sample[0]) >= t:
			return sample
	return history[0] if not history.is_empty() else []

func _physics_process(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 4.0)
	match state:
		STATE_DYING:
			modulate.a = maxf(0.0, modulate.a - delta * 2.2)
			if modulate.a <= 0.02:
				queue_free()
				return
		STATE_EMERGING:
			emerge_t -= delta
			if emerge_t <= 0.0:
				state = STATE_WALK
		STATE_UNDERGROUND:
			var to_hole := target_hole - position
			if to_hole.length() < 14.0:
				state = STATE_EMERGING
				emerge_t = 0.55
			else:
				position += to_hole.normalized() * effective_speed() * delta
		STATE_WALK:
			_walk(delta)
	# history sampling (rewind buffer)
	if state != STATE_DYING:
		_sample()

func _sample() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if history.is_empty() or now - float(history[-1][0]) >= 0.1:
		history.append([now, position.x, position.y, hp])
	while history.size() > 62:
		history.pop_front()

func _walk(delta: float) -> void:
	attack_cd -= delta
	var dest := crystal_pos + jitter
	var blocked_building: Dictionary = _blocking_building()
	if not blocked_building.is_empty():
		dest = position # stand and chew
	elif etype == "stalker" and rover_alive:
		dest = rover_pos + jitter * 0.5 # predators hunt the rover (GDD §8)
	var to_dest := dest - position
	if to_dest.length() > 6.0:
		position += to_dest.normalized() * effective_speed() * delta
	# attacks
	if attack_cd > 0.0:
		return
	if not blocked_building.is_empty():
		attack_cd = attack_interval
		Bus.enemy_attack.emit({"enemy_id": eid, "type": etype, "target": "B%d" % int(blocked_building["id"]), "damage": damage})
	elif etype == "stalker" and rover_alive and position.distance_to(rover_pos) < radius + 20.0:
		attack_cd = attack_interval
		Bus.enemy_attack.emit({"enemy_id": eid, "type": etype, "target": "ROVER", "damage": damage})
	elif position.distance_to(crystal_pos) < 62.0 + radius:
		attack_cd = attack_interval
		Bus.enemy_attack.emit({"enemy_id": eid, "type": etype, "target": "CHRONOLITH", "damage": damage})

func _blocking_building() -> Dictionary:
	for b: Dictionary in layout:
		if int(b.get("hp", 0)) <= 0 or str(b.get("type", "")) == "":
			continue
		if etype == "stalker":
			continue # stalkers slip between the walls (GDD §8)
		if position.distance_to(Vector2(float(b["x"]), float(b["y"]))) <= float(b["radius"]) + radius * 0.7:
			return b
	return {}

func _process(delta: float) -> void:
	# cloak fade
	if cloaked:
		var parent := get_parent()
		var revealed := false
		if parent != null and parent.has_method("_is_revealed"):
			revealed = parent._is_revealed(position)
		reveal_alpha = move_toward(reveal_alpha, 1.0 if revealed else 0.14, delta * 3.0)
	queue_redraw()

func _draw() -> void:
	var col: Color = Color.from_string(str(cfg.get("color", "#ffffff")), Color.WHITE).lerp(Color.WHITE, flash * 0.7)
	match state:
		STATE_UNDERGROUND:
			var t := Time.get_ticks_msec() / 1000.0
			draw_circle(Vector2.ZERO, radius * 0.8, Color(0.30, 0.20, 0.13))
			draw_arc(Vector2.ZERO, radius * 0.8 + 2.0 + 2.0 * sin(t * 9.0), 0, TAU, 16, Color(0.5, 0.36, 0.24, 0.7), 2.0, true)
			for i in 3:
				var a := t * 2.0 + float(i) * TAU / 3.0
				draw_circle(Vector2.from_angle(a) * (radius + 6.0), 2.0, Color(0.45, 0.32, 0.2, 0.5))
			return
		STATE_EMERGING:
			var frac := 1.0 - emerge_t / 0.55
			draw_circle(Vector2.ZERO, radius * (1.6 - 0.6 * frac), Color(0.35, 0.22, 0.14, 0.9))
			draw_circle(Vector2(0, -radius * 0.4 * frac), radius * 0.5 * frac, col)
			return
		STATE_DYING:
			pass # fade handled via modulate; draw corpse pose below
	match etype:
		"trooper":
			_draw_trooper(col)
		"stalker":
			_draw_stalker(col)
		"burrower":
			_draw_burrower(col)
	# tiny hp bar when damaged
	if alive and hp < max_hp:
		draw_rect(Rect2(-radius, -radius - 7, radius * 2, 3), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(-radius, -radius - 7, radius * 2 * (float(hp) / float(max_hp)), 3), Color(0.95, 0.4, 0.3))

func _draw_trooper(c: Color) -> void:
	var bob := sin(Time.get_ticks_msec() / 120.0 + _walk_phase) * 1.5
	var body := PackedVector2Array([
		Vector2(-9, 8 + bob * 0.2), Vector2(0, -10 + bob), Vector2(9, 8 + bob * 0.2), Vector2(0, 11),
	])
	draw_colored_polygon(body, c.darkened(0.15))
	draw_polyline(body + PackedVector2Array([body[0]]), c.darkened(0.5), 1.4, true)
	# amber eyes
	draw_circle(Vector2(-3, -3 + bob), 1.7, Color(1.0, 0.75, 0.25))
	draw_circle(Vector2(3, -3 + bob), 1.7, Color(1.0, 0.75, 0.25))

func _draw_stalker(c: Color) -> void:
	modulate.a = reveal_alpha
	var slink := sin(Time.get_ticks_msec() / 90.0 + _walk_phase) * 2.0
	var body := PackedVector2Array([
		Vector2(0, -14 + slink * 0.4), Vector2(6, 0), Vector2(3, 11), Vector2(-3, 11), Vector2(-6, 0),
	])
	draw_colored_polygon(body, c.darkened(0.05))
	draw_line(Vector2(-4, 11), Vector2(-7, 17 + slink * 0.3), c.darkened(0.4), 1.5)
	draw_line(Vector2(4, 11), Vector2(7, 17 - slink * 0.3), c.darkened(0.4), 1.5)
	draw_circle(Vector2(-1.8, -9), 1.2, Color(0.65, 1.0, 0.5))
	draw_circle(Vector2(1.8, -9), 1.2, Color(0.65, 1.0, 0.5))

func _draw_burrower(c: Color) -> void:
	var heave := sin(Time.get_ticks_msec() / 150.0 + _walk_phase) * 1.5
	var body := PackedVector2Array([
		Vector2(-13, 9), Vector2(-8, -8 + heave), Vector2(0, -13 + heave),
		Vector2(8, -8 + heave), Vector2(13, 9), Vector2(0, 13),
	])
	draw_colored_polygon(body, c.darkened(0.1))
	# dorsal spikes — organic, brutal (art rule §11)
	for sx in [-7.0, 0.0, 7.0]:
		draw_line(Vector2(sx, -8 + heave), Vector2(sx * 1.3, -16 + heave), c.lightened(0.2), 2.0)
	draw_circle(Vector2(-4, -6 + heave), 1.8, Color(1.0, 0.5, 0.2))
	draw_circle(Vector2(4, -6 + heave), 1.8, Color(1.0, 0.5, 0.2))
