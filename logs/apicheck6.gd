extends SceneTree
func _init() -> void:
	print("NODE_W3D=", ClassDB.class_has_method("Node", "get_world_3d"))
	for c in ClassDB.class_get_integer_constant_list("Mesh"):
		var s := String(c)
		if s.contains("ARRAY"):
			print("MC=", s)
	for p in ClassDB.class_get_method_list("ArrayMesh"):
		if String(p["name"]).contains("surface"):
			print("AM=", p["name"], "args=", p["args"])
	for p in ClassDB.class_get_method_list("DirectSpaceState3D"):
		if String(p["name"]).contains("ray"):
			print("DS=", p["name"], "args=", p["args"], "var=", p["vararg"])
	quit()
