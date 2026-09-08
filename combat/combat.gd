class_name Combat
extends Node3D
## M1 combat: authoritative hitscan resolution. Typed direct call — fire().
## Signals announce completed facts only (hit_resolved).

signal hit_resolved(at: Vector3, target: Node, damage: int)

const DAMAGE := 10

func fire(from: Vector3, to: Vector3, exclude: Array = []) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, -1, exclude)
	var hit: Dictionary = space.intersect_ray(q)
	var result := {"ok": false, "at": to, "target": null}
	if hit.is_empty():
		return result
	result["ok"] = true
	result["at"] = Vector3(hit.get("position", to))
	_tracer(from, Vector3(hit["position"]))
	var collider: Object = hit.get("collider")
	if collider is Node and (collider as Node).is_in_group("damageable") and collider.has_method("damage"):
		result["target"] = collider
		(collider as Node).damage(DAMAGE)
		hit_resolved.emit(result["at"], collider, DAMAGE)
	return result

func _tracer(from: Vector3, to: Vector3) -> void:
	var d := to - from
	if d.length() < 0.05:
		return
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = 0.02
	cyl.height = 1.0
	beam.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.3)
	mat.emission_energy_multiplier = 2.0
	beam.material_override = mat
	beam.transform = Transform3D(Basis(Quaternion(Vector3.UP, d.normalized())), from)
	beam.scale = Vector3(1.0, d.length(), 1.0)
	var t := get_tree().create_timer(0.07)
	t.timeout.connect(beam.queue_free)
