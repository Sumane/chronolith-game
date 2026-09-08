extends SceneTree
func _init() -> void:
	var l := ClassDB.class_get_method_list("DirectSpaceState3D")
	print("LTYPE=", typeof(l), "SIZE=", l.size())
	if l.size() > 0:
		print("E0TYPE=", typeof(l[0]), "E0=", l[0])
		for i in range(l.size()):
			if typeof(l[i]) == TYPE_DICTIONARY and String(l[i]["name"]) == "intersect_ray":
				print("IRAY=", l[i])
	var c := ClassDB.class_get_integer_constant_list("Mesh")
	if c.size() > 0:
		print("C0TYPE=", typeof(c[0]), "C0=", c[0])
		for i in range(c.size()):
			if typeof(c[i]) == TYPE_DICTIONARY:
				var nm := String(c[i]["name"])
				if nm == "ARRAY_UV" or nm == "ARRAY_TEX_UV" or nm == "ARRAY_VERTEX":
					print("CONST=", c[i])
	quit()
