class_name WaveDirector
extends Node
## M2: three preparation/assault rounds. Budget = grunt count grows [3,4,5].
## Early start (N) skips the prep countdown. Spawns staggered from arena edges.

const WAVE_SIZES := [3, 4, 5]
const PREP_TIME := 20.0
const SPAWN_STAGGER := 0.8

enum State { PREP, ASSAULT, WIN }

var wave := 1
var state := State.PREP
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
	alive = WAVE_SIZES[wave - 1]
	var sector := int((wave - 1) * 2) % EDGES.size()
	for i in WAVE_SIZES[wave - 1]:
		var e: Vector3 = EDGES[(sector + i) % EDGES.size()]
		var t := get_tree().create_timer(i * SPAWN_STAGGER)
		t.timeout.connect(_spawn_grunt.bind(e))
	wave_started.emit(wave, _edge_name(EDGES[sector]))

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

func _on_grunt_died(_e: Grunt) -> void:
	alive -= 1
	if state == State.ASSAULT and alive <= 0:
		if wave >= WAVE_SIZES.size():
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
	alive = n
	var i := 0
	while i < n:
		_spawn_grunt(EDGES[i % EDGES.size()])
		i += 1

func _edge_name(e: Vector3) -> String:
	if absf(e.z) > absf(e.x):
		return "NORTH" if e.z < 0 else "SOUTH"
	return "EAST" if e.x > 0 else "WEST"
