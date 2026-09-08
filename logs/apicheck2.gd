extends SceneTree
func _init() -> void:
	for p in ClassDB.class_get_method_list("ArrayMesh"):
		if String(p["name"]).begins_with("add_surface_from_arrays"):
			print("ADD_SURF args=", p["args"])
	for p in ClassDB.class_get_method_list("DirectSpaceState3D"):
		if String(p["name"]).begins_with("intersect_ray"):
			print("IRAY args=", p["args"], "vararg=", p["vararg"])
	print("NODE_WORLD3D=", ClassDB.class_has_method("Node", "get_world_3d"))
	for c in ClassDB.class_get_integer_constant_list("Mesh"):
		if String(c["name"]).contains("UV") or String(c["name"]).contains("VERTEX"):
			print("MESH_CONST", c["name"])
	for p in ClassDB.class_get_method_list("PhysicsRayQueryParameters3D"):
		if String(p["name"]) == "create":
			print("PRQP_CREATE args=", p["args"])
	quit()
