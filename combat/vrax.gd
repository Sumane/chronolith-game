class_name Vrax
extends Warden
## M7 finale boss: Vrax commands the Corsair wave and holds temporal memory
## of Vael's earlier attempts. The GDD is unambiguous — the mech is
## REQUIRED to defeat the final boss: every non-mech shot (flat or
## piercing, turret or wall) is ignored outright, and only the mech's
## heavy round deals damage. Walls still stun (deflect), never damage.
## (Review fix M13: the former non-mech "chip" let fortresses kill Vrax
## without the mech, making the requirement optional.)

const BOSS_HP := 400

func _ready() -> void:
	hp = BOSS_HP
	super._ready()
	var v: Node = get_node_or_null("Visual")
	if v != null:
		v.scale = Vector3(1.4, 1.4, 1.4)
		v.position = Vector3(0, 1.26, 0)
		var m: Material = (v as MeshInstance3D).get_material_override()
		if m is StandardMaterial3D:
			(m as StandardMaterial3D).albedo_color = Color(0.5, 0.08, 0.1)

func damage(n: int, piercing: bool = false, from_mech: bool = false) -> void:
	if _dead:
		return
	if not from_mech:
		warden_event.emit(self, "immune")
		return
	warden_event.emit(self, "counter")
	hp -= n
	if hp <= 0:
		_die()

## The seal holds: a wall in the charge lane still stuns Vrax, but the
## deflect hit cannot break it — only the mech's gun can.
func _deflect() -> void:
	_state = "stunned"
	_t = DEFLECT_STUN
	velocity = Vector3.ZERO
	warden_event.emit(self, "deflect")
