extends SceneTree
func _init() -> void:
	var verts := PackedVector3Array([Vector3(0,0,0), Vector3(1,0,0), Vector3(0,0,1)])
	var nrm := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	var idx := PackedInt32Array([0,1,2])
	var m1 := ArrayMesh.new()
	m1.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, [[Mesh.ARRAY_VERTEX, verts], [Mesh.ARRAY_NORMAL, nrm], [Mesh.ARRAY_INDEX, idx]])
	print("PAIRS_SURF=", m1.get_surface_count())
	var m2 := ArrayMesh.new()
	m2.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, [{"name": Mesh.ARRAY_VERTEX, "data": verts}, {"name": Mesh.ARRAY_NORMAL, "data": nrm}, {"name": Mesh.ARRAY_INDEX, "data": idx}])
	print("DICTSURF=", m2.get_surface_count())
	for p in ClassDB.class_get_method_list("DirectSpaceState3D"):
		print("DS=", p["name"], "|", p["args"])
	quit()
