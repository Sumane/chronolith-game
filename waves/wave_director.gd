class_name WaveDirector
extends Node
## M6: the twenty-wave campaign. WAVE_PLAN is the full campaign budget;
## wave_plan is the live length (probes may set it to the 3-wave prototype).
## Early start (N) skips the prep countdown. Spawns staggered from arena edges.
##
## 45-minute tuning knobs: PREP_TIME (20 s between waves), assault length
## (grunt counts below, ~40-90 s each), breather dips every ~3 waves.

const WAVE_PLAN := [3, 3, 4, 4, 5, 4, 6, 5, 7, 6, 8, 7, 9, 8, 10, 9, 11, 10, 12, 14]
const PREP_TIME := 20.0
const SPAWN_STAGGER := 0.8
const WARDEN_WAVES := {3: 1, 7: 1, 11: 1, 15: 1, 19: 1, 20: 1}  # M4/M6
const GOLEM_WAVES := {5: 1, 10: 1, 16: 1, 20: 1}  # M6: armored pressure

enum State { PREP, ASSAULT, WIN }

var wave := 1
var state := State.PREP
var wave_plan: Array = WAVE_PLAN  # live length (probe-overridable)
## M8: endless continuation — non-canonical waves after the campaign win.
## No Vrax (he died in the finale), no WIN state; the relay only advances.
var endless := false
const MAX_ALIVE := 24  # spawn bound: wave-20 peak (14 + 2 bosses) stays under it
var prep_left := PREP_TIME
var alive := 0
var arena
var crystal: Node3D = null
var rover: Node3D = null

# 8 fixed edge points; waves fan out from a rotating sector
const EDGES := [
	Vector3(0, 0, -18), Vector3(10, 0, -17), Vector3(-10, 0, -17),
	Vector3(18, 0, -8), Vector3(18, 0, 8), Vector3(-18, 0, 8),
	Vector3(-10, 0, 17), Vector3(10, 0, 17),
]

signal wave_started(wave: int, direction: String)
signal wave_cleared(wave: int)
signal attempt_won()
signal warden_event(w: Warden, kind: String)
signal golem_event(g: Golem, kind: String)
signal warden_died(w: Warden)
signal golem_died(g: Golem)

## M7: the finale boss reference (spawned on the final full-campaign wave)
var vrax: Vrax = null

func _physics_process(delta: float) -> void:
	if state == State.PREP:
		prep_left -= delta
		if prep_left <= 0.0:
			_start_assault()

func early_start() -> void:
	if state == State.PREP:
		prep_left = 0.0

func _start_assault() -> void:
	state = State.ASSAULT
	var size: int = endless_size(wave) if endless else int(wave_plan[wave - 1])
	size = mini(size, MAX_ALIVE - 2)
	alive = size
	var sector := int((wave - 1) * 2) % EDGES.size()
	for i in size:
		var e: Vector3 = EDGES[(sector + i) % EDGES.size()]
		var t := get_tree().create_timer(i * SPAWN_STAGGER)
		t.timeout.connect(_spawn_grunt.bind(e))
	wave_started.emit(wave, _edge_name(EDGES[sector]))
	var wcnt: int = WARDEN_WAVES.get(wave, 0) if not endless else (1 if wave % 3 == 2 else 0)
	for j in wcnt:
		if wave_plan.size() == 20 and wave == wave_plan.size():
			_spawn_vrax(EDGES[(sector + size) % EDGES.size()])
		else:
			_spawn_warden(EDGES[(sector + size) % EDGES.size()])
	var gcnt: int = GOLEM_WAVES.get(wave, 0) if not endless else (1 if wave % 5 == 0 else 0)
	for k in gcnt:
		_spawn_golem(EDGES[(sector + size + 1) % EDGES.size()])

func _spawn_grunt(edge: Vector3) -> void:
	if state != State.ASSAULT:
		return
	var g: Grunt = load("res://combat/enemy.gd").new()
	g.position = Vector3(edge.x, 1.0, edge.z)
	if arena != null and arena.has_method("height_at"):
		g.position.y = arena.height_at(edge.x, edge.z) + 0.5
	g.goal = crystal
	g.arena = arena
	g._rover = rover
	g.died.connect(_on_grunt_died)
	arena.get_parent().add_child(g)

## Probe-only: spawn a Warden at a world position without touching
## state/alive (so counter-path tests can run in any phase).
func debug_spawn_warden(pos: Vector3) -> Warden:
	var w: Warden = load("res://combat/warden.gd").new()
	w.position = pos
	w.goal = crystal
	w.arena = arena
	w._rover = rover
	w.died.connect(_on_grunt_died)
	w.died.connect(func(wd: Warden) -> void: warden_died.emit(wd))
	w.warden_event.connect(func(w2: Warden, k2: String) -> void: warden_event.emit(w2, k2))
	arena.get_parent().add_child(w)
	return w

func _spawn_warden(edge: Vector3) -> void:
	if state != State.ASSAULT:
		return
	var w: Warden = load("res://combat/warden.gd").new()
	w.position = Vector3(edge.x, 1.0, edge.z)
	if arena != null and arena.has_method("height_at"):
		w.position.y = arena.height_at(edge.x, edge.z) + 0.5
	w.goal = crystal
	w.arena = arena
	w._rover = rover
	w.died.connect(_on_grunt_died)
	w.died.connect(func(wd: Warden) -> void: warden_died.emit(wd))
	w.warden_event.connect(func(w2: Warden, k2: String) -> void: warden_event.emit(w2, k2))
	arena.get_parent().add_child(w)

func _spawn_golem(edge: Vector3) -> void:
	if state != State.ASSAULT:
		return
	var g: Golem = load("res://combat/golem.gd").new()
	g.position = Vector3(edge.x, 1.0, edge.z)
	if arena != null and arena.has_method("height_at"):
		g.position.y = arena.height_at(edge.x, edge.z) + 0.5
	g.goal = crystal
	g.arena = arena
	g._rover = rover
	g.died.connect(_on_grunt_died)
	g.died.connect(func(gd: Golem) -> void: golem_died.emit(gd))
	g.golem_event.connect(func(g2: Golem, k2: String) -> void: golem_event.emit(g2, k2))
	arena.get_parent().add_child(g)


func _spawn_vrax(edge: Vector3) -> void:
	if state != State.ASSAULT:
		return
	var v: Vrax = Vrax.new()
	v.position = Vector3(edge.x, 1.0, edge.z)
	if arena != null and arena.has_method("height_at"):
		v.position.y = arena.height_at(edge.x, edge.z) + 0.5
	v.goal = crystal
	v.arena = arena
	v._rover = rover
	v.died.connect(_on_grunt_died)
	v.died.connect(func(wd: Warden) -> void: warden_died.emit(wd))
	v.warden_event.connect(func(w2: Warden, k2: String) -> void: warden_event.emit(w2, k2))
	arena.get_parent().add_child(v)
	vrax = v

func _on_grunt_died(_e) -> void:
	alive -= 1
	if state == State.ASSAULT and alive <= 0:
		if not endless and wave >= wave_plan.size():
			state = State.WIN
			attempt_won.emit()
		else:
			state = State.PREP
			wave += 1
			prep_left = PREP_TIME
			wave_cleared.emit(wave - 1)

# debug/test hooks (typed calls)
func debug_instant_wave(n: int) -> void:
	state = State.ASSAULT
	alive = mini(n, MAX_ALIVE - 2)
	var i := 0
	while i < alive:
		_spawn_grunt(EDGES[i % EDGES.size()])
		i += 1
	var dwcnt: int = WARDEN_WAVES.get(wave, 0) if not endless else (1 if wave % 3 == 2 else 0)
	if dwcnt > 0:
		if wave_plan.size() == 20 and wave == wave_plan.size():
			_spawn_vrax(EDGES[(n) % EDGES.size()])
		else:
			_spawn_warden(EDGES[(n) % EDGES.size()])
		alive += 1
	var dgcnt: int = GOLEM_WAVES.get(wave, 0) if not endless else (1 if wave % 5 == 0 else 0)
	if dgcnt > 0:
		_spawn_golem(EDGES[(n + 1) % EDGES.size()])
		alive += 1

func _edge_name(e: Vector3) -> String:
	if absf(e.z) > absf(e.x):
		return "NORTH" if e.z < 0 else "SOUTH"
	return "EAST" if e.x > 0 else "WEST"


## M8: endless wave budget — the wave-20 climax size ramps half a grunt per
## wave, capped. Tuning knob: change the slope/cap here.
func endless_size(w: int) -> int:
	return mini(14 + (w - 20) / 2, 20)

## M8: continue the victorious physical state into non-canonical waves.
func begin_endless() -> void:
	endless = true
	state = State.PREP
	wave = int(wave_plan.size()) + 1
	prep_left = PREP_TIME
