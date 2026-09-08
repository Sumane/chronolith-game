extends SceneTree
func _init() -> void:
	for p in ClassDB.class_get_method_list("DirectSpaceState3D"):
		print("DS=", p["name"], "args=", p["args"], "var=", p["vararg"])
	quit()
