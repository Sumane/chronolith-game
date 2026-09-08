extends SceneTree
func _init() -> void:
	var verts := PackedVector3Array([Vector3(0,0,0), Vector3(1,0,0), Vector3(0,0,1)])
	var nrm := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	var idx := PackedInt32Array([0,1,2])
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_INDEX] = idx
	var m1 := ArrayMesh.new()
	m1.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	print("SLOT_SURF=", m1.get_surface_count())
	var cn := "PhysicsDirectSpaceState3D"
	print("HASCLASS=", ClassDB.class_exists(cn))
	for p in ClassDB.class_get_method_list(cn):
		if String(p["name"]).contains("ray"):
			print("DS=", p["name"], "|", p["args"])
	quit()
