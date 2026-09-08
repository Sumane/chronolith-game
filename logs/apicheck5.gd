extends SceneTree
func _init() -> void:
	print("NODE_W3D=", ClassDB.class_has_method("Node", "get_world_3d"))
	for c in ClassDB.class_get_integer_constant_list("Mesh"):
		var nm := String(c["name"])
		if nm.contains("ARRAY"):
			print("MC=", nm)
	for nm in ClassDB.class_get_method_list("ArrayMesh"):
		if String(nm).contains("surface"):
			print("AM=", nm)
	for nm in ClassDB.class_get_method_list("DirectSpaceState3D"):
		print("DS=", nm)
	quit()
