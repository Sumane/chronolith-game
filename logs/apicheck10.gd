extends SceneTree
func _init() -> void:
	for p in ClassDB.class_get_method_list("PhysicsRayQueryParameters3D"):
		print("PRQP=", p["name"], "|", p["args"])
	quit()
