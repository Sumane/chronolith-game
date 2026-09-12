extends Node3D
## M1 arena: hand-built Mars test range.
## Real geometry: heightmap terrain (HeightMapShape3D collision + matching
## mesh), shot-blocking rocks, fixed Chronolith crystal, target dummies.
## All blockout visuals (docs/asset-conventions.md).
## Playtest fix 4: the whole visible field is ONE continuous ground surface
## (120 m, textured at 1 m grid scale). The arena relief lives in the centre
## 40 m and tapers back to 0 between r = 20 and r = 30. The old separate
## 500 m "plain" under the heightmap is gone — it read as a second, lower
## floor (a textured layer under the main ground).

const GRID := 121
const SIZE := 120.0

# M6: recognisable map. Four cover clusters (two rocks each) flank the
# eight edge approaches; single pinch rocks force lanes; the blocker rock
# keeps the north-centre approach flanked. Cover pockets sit on the mid
# ring (8-14 m) where turrets/walls hold two or three lanes.
const ROCKS: Array = [
	# NE cluster + lane pinch (lanes from E1/E3)
	[8.0, -8.0, 1.5], [11.0, -5.0, 1.2], [14.0, -12.0, 1.6],
	# NW cluster (lanes from E2/E5)
	[-9.0, -7.0, 1.4], [-12.0, -10.0, 1.6], [-9.5, -4.0, 1.2],
	# SW cluster (lane from E6)
	[-8.0, 10.0, 1.5], [-12.0, 13.0, 1.3], [-5.0, 15.0, 1.2], [-12.0, 8.5, 1.7],
	# SE cluster (lanes from E4/E7) — wraps the (10,10) build pocket,
	# never inside its r+0.9 build exclusion
	[6.5, 12.0, 1.4], [14.0, 10.0, 1.3], [12.0, 8.0, 1.3],
	# mid-ring solos holding the central approach
	[-7.0, 2.0, 1.6], [9.0, -2.0, 1.8], [3.0, 9.5, 1.1], [6.5, 6.0, 1.4],
]
const BLOCKER_POS := Vector3(0.0, 0.0, -2.0)  # keeps north-centre flanked (M1 LOS)
const BLOCKER_R := 1.6

var crystal: ChronolithCrystal
var dep_group: Node3D
var rock_list: Array = []

# M6: resource distance ladder — 7 / 10 / 13 / 17 / 21 m from the crystal.
# Each deposit sits off the main lanes, most near a cover cluster: harvesting
# is always a detour with a partial view of the approach that feeds it.
const DEPOSIT_POS := [Vector2(6.0, 4.0), Vector2(-7.0, 7.0), Vector2(11.0, -6.0), Vector2(-14.0, 10.0), Vector2(15.0, 15.0)]

func height_at(x: float, z: float) -> float:
	var h := 0.7 * sin(x * 0.22) * cos(z * 0.19) \
		+ 0.45 * sin(x * 0.09 + 1.7) * sin(z * 0.11 + 0.4) \
		+ 0.3 * cos((x + z) * 0.05)
	h += maxf(0.0, -x - 8.0) * 0.22  # west slope ridge
	var d := Vector2(x, z).length()
	var pad := clampf((d - 6.0) / 6.0, 0.0, 1.0)  # flat buildable pad at centre
	# fix 4: identical inside the arena (r < 20), then the relief fades to a
	# flat field between r = 20 and r = 30 so the extended ground is one
	# continuous surface (fog swamps anything past ~45 m anyway)
	var taper := 1.0 - smoothstep(20.0, 30.0, d)
	return h * pad * pad * taper

func _ready() -> void:
	_build_environment()
	_build_terrain()
	for r in ROCKS:
		_rock(Vector3(float(r[0]), height_at(float(r[0]), float(r[1])), float(r[1])), float(r[2]))
	_rock(BLOCKER_POS, BLOCKER_R)
	crystal = ChronolithCrystal.new()
	crystal.name = "Chronolith"
	add_child(crystal)
	dep_group = Node3D.new()
	dep_group.name = "Deposits"
	for i in DEPOSIT_POS.size():
		var d := Deposit.new()
		d.name = "Deposit%d" % (i + 1)
		d.position = Vector3(DEPOSIT_POS[i].x, height_at(DEPOSIT_POS[i].x, DEPOSIT_POS[i].y), DEPOSIT_POS[i].y)
		dep_group.add_child(d)
	add_child(dep_group)
	var t1 := TargetDummy.new()
	t1.name = "Target1"
	t1.position = Vector3(0.0, height_at(0.0, -12.0), -12.0)
	add_child(t1)
	var t2 := TargetDummy.new()
	t2.name = "Target2"
	t2.position = Vector3(8.0, height_at(8.0, -6.0), -6.0)
	add_child(t2)
	var t3 := TargetDummy.new()
	t3.name = "Target3"
	t3.position = Vector3(-9.0, height_at(-9.0, -7.0), -7.0)
	add_child(t3)
	print("M1_ARENA_READY")

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m

func _terrain_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _grid_texture()
	# ANISOTROPIC (with the mipmap chain): the player camera is nearly
	# horizontal, so the ground in front of you is sampled at extreme
	# minification. Without anisotropy the 1 m grid averages out on the flat
	# ground you are driving on while it survives on steeper ground further
	# away — the texture appears to live on a different face of the ground
	# than the one under the rover (playtest fix 5). Anisotropy keeps it on
	# the face you are looking at, at every angle. Requires
	# rendering/textures/default_filters/anisotropic_filtering_level in
	# project.godot (16).
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.roughness = 1.0
	return m

## The ground grid: one 640 px image (16 px per metre) with base Mars tone,
## deterministic speckle noise and a bright line at every tile edge — the
## surface reads as 1 m square placeholder tiles and distances are
## measurable. The 120 m field reuses the same image tiled (UVs span 0..3),
## so the 1 m grid is continuous from the arena to the field edge.
## Fix 5: the lines are 6 px wide (37.5 cm of ground) — a 1 px line
## (6 cm) is sub-texel as soon as the ground is sampled at a glancing
## angle and the grid vanishes from the face you are looking at.
func _grid_texture() -> ImageTexture:
	const RES := 640
	const PER_M := 16
	const LINE := 6
	var img := Image.create(RES, RES, false, Image.FORMAT_RGB8)
	var base := Color(0.45, 0.26, 0.17)
	var line := Color(0.68, 0.47, 0.34)
	for y in RES:
		for x in RES:
			var r := fmod(sin(float(x) * 127.1 + float(y) * 311.7) * 43758.5453, 1.0)
			var v := 1.0 + (r - 0.5) * 0.22
			var c := Color(base.r * v, base.g * v, base.b * v)
			if x % PER_M < LINE or y % PER_M < LINE:
				c = line
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var pm := ProceduralSkyMaterial.new()
	pm.sky_top_color = Color(0.32, 0.17, 0.14)
	pm.sky_horizon_color = Color(0.58, 0.33, 0.22)
	pm.ground_bottom_color = Color(0.2, 0.1, 0.08)
	pm.ground_horizon_color = Color(0.58, 0.33, 0.22)
	sky.sky_material = pm
	env.sky = sky
	env.fog_enabled = true
	env.fog_light_color = Color(0.6, 0.36, 0.25)
	# dense enough that the 40 m arena edge softens into the horizon
	env.fog_density = 0.03
	world.environment = env
	add_child(world)
	# fix 4: no separate plain. The horizon IS the terrain field itself
	# (120 m of 1 m grid texture fading into fog) — one ground surface,
	# nothing under the main ground.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.88, 0.72)
	sun.shadow_enabled = true
	add_child(sun)

func _build_terrain() -> void:
	var n := GRID
	var verts := PackedVector3Array()
	var nrm := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for iz in n:
		for ix in n:
			var x := -SIZE / 2.0 + float(ix)
			var z := -SIZE / 2.0 + float(iz)
			var h := height_at(x, z)
			heights[iz * n + ix] = h
			verts.append(Vector3(x, h, z))
	for iz in n:
		for ix in n:
			var x := -SIZE / 2.0 + float(ix)
			var z := -SIZE / 2.0 + float(iz)
			var hx := height_at(x + 0.5, z) - height_at(x - 0.5, z)
			var hz := height_at(x, z + 0.5) - height_at(x, z - 0.5)
			nrm.append(Vector3(-hx, 1.0, -hz).normalized())
			# the 640 px image covers 40 m (16 px per metre); the 120 m field
			# tiles it 3x (UVs span 0..3), so the 1 m grid stays continuous
			# from the arena centre to the field edge
			uvs.append(Vector2(ix / 40.0, iz / 40.0))
	for iz in n - 1:
		for ix in n - 1:
			var a := iz * n + ix
			idx.append_array([a, a + n, a + 1, a + 1, a + n, a + n + 1])
	var mesh := ArrayMesh.new()
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _terrain_material()
	add_child(mi)
	# Godot 4.7 HeightMapShape3D: no map_origin/map_size (removed) — the map
	# is centred on the body origin, one world unit per sample, heights
	# absolute (verified empirically: tests/v1/heightmap_probe.gd). Body at
	# the arena origin => collision matches the visual mesh exactly.
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	shape.map_data = heights
	col.shape = shape
	body.add_child(col)
	add_child(body)

func _rock(pos: Vector3, r: float) -> void:
	rock_list.append({"pos": pos, "r": r})
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = r
	col.shape = s
	col.position = Vector3(0, r * 0.5, 0)
	body.add_child(col)
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 1.2
	m.mesh = sm
	m.material_override = _mat(Color(0.3, 0.19, 0.14))
	m.position = Vector3(0, r * 0.5, 0)
	m.scale = Vector3(1.0, 0.72, 1.0)
	body.add_child(m)
	body.position = pos
	add_child(body)
