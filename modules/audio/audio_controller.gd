extends Node
## M9 AUDIO — data-driven event→SFX mapping (pure consumer, emits nothing).
## Placeholder procedural beeps prove the mapping architecture (agent brief §9).

var sound_map: Dictionary = {}
var _cache: Dictionary = {} # spec string -> AudioStreamWAV
var _players: Array = []
var _next_player := 0
var _cooldown := 0.0
var _heartbeat := 0.0
var _assault := false

func _ready() -> void:
	if Contracts.CONTRACT_VERSION != 1:
		push_warning("[Audio] contract version mismatch")
	var m: Variant = Contracts.load_json("res://modules/audio/data/sound_map.json")
	if typeof(m) == TYPE_DICTIONARY:
		sound_map = m
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	for event_name: String in sound_map:
		if Bus.has_signal(event_name):
			Bus.connect(event_name, _on_mapped_event.bind(event_name))
	Bus.purchase_result.connect(_on_purchase_result)
	Bus.phase_changed.connect(func(p: Dictionary) -> void:
		_assault = int(p.get("phase_id", -1)) == Contracts.Phase.ASSAULT)

func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _assault and not get_tree().paused:
		_heartbeat -= delta
		if _heartbeat <= 0.0:
			_heartbeat = 1.15
			_play({"f": 52.0, "d": 0.22, "v": 0.30, "kind": "sine"})

func _on_purchase_result(payload: Dictionary) -> void:
	if bool(payload.get("ok", false)):
		_play({"f": 740.0, "d": 0.06, "v": 0.25, "kind": "sq"})
	else:
		_play({"f": 110.0, "d": 0.18, "v": 0.4, "kind": "sq"})

func _on_mapped_event(payload: Dictionary, event_name: String) -> void:
	var spec: Dictionary = sound_map.get(event_name, {})
	if spec.is_empty():
		return
	_play(spec)

func _play(spec: Dictionary) -> void:
	if _cooldown > 0.0:
		return
	_cooldown = 0.02
	var stream := _blip(float(spec.get("f", 440)), float(spec.get("d", 0.1)), str(spec.get("kind", "sq")))
	var p: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = stream
	p.volume_db = linear_to_db(clampf(float(spec.get("v", 0.4)), 0.01, 1.0))
	p.pitch_scale = randf_range(0.97, 1.03)
	p.play()

func _blip(freq: float, dur: float, kind: String) -> AudioStreamWAV:
	var key := "%.0f|%.3f|%s" % [freq, dur, kind]
	if _cache.has(key):
		return _cache[key]
	var rate := 22050
	var n := maxi(1, int(rate * dur))
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var progress := float(i) / float(n)
		var env := pow(1.0 - progress, 2.0)
		var f := freq
		if kind == "sweep":
			f = lerpf(freq, freq * 0.25, progress)
		var s := sin(TAU * f * t)
		match kind:
			"sq":
				s = signf(s)
			"chord":
				s = 0.6 * s + 0.4 * sin(TAU * f * 1.5 * t)
		var v := int(clampf(s * env * 0.9, -1.0, 1.0) * 32000.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	_cache[key] = wav
	return wav
