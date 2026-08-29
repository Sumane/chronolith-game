extends Node
## Ordered event-stream logger for integration debugging.
## Enable with env var CHRONOLOG=1  (run:  CHRONOLOG=1 godot --path . )

var enabled := false
var _count := 0
const MAX_LINES := 500 # hard cap: per-print cost in headless 4.7.1 is high; never let a long run grow unbounded

func _ready() -> void:
	enabled = OS.get_environment("CHRONOLOG") == "1"
	if not enabled:
		return
	for sig in Bus.get_signal_list():
		Bus.connect(sig["name"], _log_event.bind(sig["name"]))

func _log_event(payload: Variant, sig_name: String) -> void:
	if _count >= MAX_LINES:
		return
	_count += 1
	if _count == MAX_LINES:
		print("[%06d BUS] <logger capped at %d lines>" % [_count, MAX_LINES])
	var text := str(payload).replace("\n", " ")
	if text.length() > 180:
		text = text.substr(0, 180) + "…"
	print("[%06d BUS] %s %s" % [_count, sig_name, text])
