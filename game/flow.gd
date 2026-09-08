class_name GameFlow
extends Node
## M2 attempt lifecycle: RUNNING / LOST / WIN. Death of rover or crystal ends
## the attempt; R (restart_attempt) loads a clean new attempt.

var running := true
var last_result := ""

signal ended(result: String)

func on_rover_lost() -> void:
	_end("lost_rover")

func on_crystal_lost() -> void:
	_end("lost_crystal")

func on_won() -> void:
	_end("win")

func _end(result: String) -> void:
	if not running:
		return
	running = false
	last_result = result
	ended.emit(result)
