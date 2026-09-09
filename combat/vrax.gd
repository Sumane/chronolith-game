class_name Vrax
extends Warden
## M7 finale boss: Vrax commands the Corsair wave and holds temporal memory
## of Vael's earlier attempts. The GDD is unambiguous — the mech is required
## to defeat the final boss: flat shots are ignored entirely, non-mech
## piercing shots chip (fortresses "actively control" the fight), and only
## the mech's heavy round deals full damage. Walls still stun (deflect),
## never damage.

const BOSS_HP := 400
const CHIP_DIVISOR := 4

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
	if not piercing:
		warden_event.emit(self, "immune")
		return
	var dmg: int = n if from_mech else maxi(1, n / CHIP_DIVISOR)
	warden_event.emit(self, "counter" if from_mech else "chip")
	hp -= dmg
	if hp <= 0:
		_die()

## The seal holds: a wall in the charge lane still stuns Vrax, but the
## deflect hit cannot break it — only the mech's gun can.
func _deflect() -> void:
	_state = "stunned"
	_t = DEFLECT_STUN
	velocity = Vector3.ZERO
	warden_event.emit(self, "deflect")
