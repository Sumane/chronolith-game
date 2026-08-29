extends Node3D
## STAGE 0 POC (docs/3D-CONVERSION.md §5) — proves the 3D presentation seam.
## Lit terrain + Chronolith crystal + idle trooper + drivable rover + tilted
## top-down camera. The 2D slice is untouched; this scene is additive.
##
## Controls: WASD / arrows move the rover (W = "up" on screen = -Z).
## Headless: POC_SECONDS=N auto-quits after N seconds (verification probe).

const MAP_W := 48.0
const MAP_D := 32.0
const ROVER_SPEED := 6.0

var _rover: CharacterBody3D
var _crystal: MeshInstance3D

func _ready() -> void:
	InputSetup.setup()
	_build_environment()
	_build_terrain()
	_build_crystal()
	_build_trooper()
	_build_rover()
	_build_camera()
	_build_hud()
	print("POC_READY root_children=%d" % get_children().size())
	var secs := float(OS.get_environment("POC_SECONDS"))
	if secs > 0.0:
		get_tree().create_timer(secs).timeout.connect(get_tree().quit)

func _physics_process(delta: float) -> void:
	if _crystal != null:
		_crystal.rotation.y += delta * 0.6
	if _rover == null:
		return
	var dir := Vector3.ZERO
	dir.x = Input.get_axis("move_left", "move_right")
	dir.z = -Input.get_axis("move_up", "move_down")
	if dir.length() > 1.0:
		dir = dir.normalized()
	_rover.velocity = dir * ROVER_SPEED
	_rover.move_and_slide()

# ----------------------------------------------------------------- builders --

func _mat(albedo: Color, emissive: Color = Color.BLACK, emissive_energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = 0.9
	if emissive_energy > 0.0:
		m.emission_enabled = true
		m.emission = emissive
		m.emission_energy_multiplier = emissive_energy
	return m

func _mesh_instance(mesh: Mesh, material: Material, pos: Vector3, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi

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
	env.fog_density = 0.012
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.88, 0.72)
	sun.shadow_enabled = true
	add_child(sun)

func _build_terrain() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(MAP_W, MAP_D)
	_mesh_instance(plane, _mat(Color(0.42, 0.24, 0.16)), Vector3.ZERO)

	var floor := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = WorldBoundaryShape3D.new()
	floor.add_child(col)
	add_child(floor)

func _build_crystal() -> void:
	var ped_mesh := CylinderMesh.new()
	ped_mesh.top_radius = 1.4
	ped_mesh.bottom_radius = 1.4
	ped_mesh.height = 0.5
	_mesh_instance(ped_mesh, _mat(Color(0.35, 0.3, 0.28)), Vector3(0, 0.25, 0))

	var crystal_mesh := PrismMesh.new()
	crystal_mesh.size = Vector3(1.4, 3.4, 1.4)
	_crystal = _mesh_instance(
		crystal_mesh, _mat(Color(0.2, 0.85, 0.75), Color(0.2, 0.95, 0.85), 1.6),
		Vector3(0, 2.3, 0)
	)

	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 2.5, 0)
	glow.light_color = Color(0.3, 0.95, 0.85)
	glow.light_energy = 2.5
	glow.omni_range = 9.0
	add_child(glow)

func _build_trooper() -> void:
	var body := CapsuleMesh.new()
	body.radius = 0.45
	body.height = 1.7
	_mesh_instance(body, _mat(Color(0.75, 0.2, 0.15)), Vector3(6.0, 0.85, -4.0))
	var head := SphereMesh.new()
	head.radius = 0.3
	_mesh_instance(head, _mat(Color(0.9, 0.85, 0.7), Color(0.9, 0.2, 0.1), 0.8), Vector3(6.0, 1.95, -4.0))

func _build_rover() -> void:
	_rover = CharacterBody3D.new()
	_rover.position = Vector3(-6.0, 0.55, 4.0)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 1.5, 2.1)
	col.shape = box
	_rover.add_child(col)

	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.6, 0.7, 2.2)
	_mesh_instance(body_mesh, _mat(Color(0.72, 0.62, 0.45)), Vector3(0, 0.35, 0), _rover)

	var turret_mesh := BoxMesh.new()
	turret_mesh.size = Vector3(0.6, 0.5, 1.1)
	_mesh_instance(turret_mesh, _mat(Color(0.5, 0.45, 0.4)), Vector3(0, 0.85, -0.2), _rover)

	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.09
	barrel.bottom_radius = 0.09
	barrel.height = 0.9
	var barrel_mi := MeshInstance3D.new()
	barrel_mi.mesh = barrel
	barrel_mi.material_override = _mat(Color(0.25, 0.25, 0.3))
	barrel_mi.position = Vector3(0, 0.85, -0.9)
	barrel_mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	_rover.add_child(barrel_mi)

	for side in [-1.0, 1.0]:
		for fore in [-1.0, 1.0]:
			var wheel := CylinderMesh.new()
			wheel.top_radius = 0.35
			wheel.bottom_radius = 0.35
			wheel.height = 0.25
			var wi := MeshInstance3D.new()
			wi.mesh = wheel
			wi.material_override = _mat(Color(0.15, 0.14, 0.13))
			wi.position = Vector3(0.85 * side, -0.3, 0.8 * fore)
			wi.rotation_degrees = Vector3(0, 0, 90.0)
			_rover.add_child(wi)

	add_child(_rover)

func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 12.5, 20.8)
	cam.rotation_degrees = Vector3(-60.0, 0.0, 0.0)
	cam.current = true
	add_child(cam)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.position = Vector2(16, 12)
	label.add_theme_font_size_override("font_size", 15)
	label.modulate = Color(1, 0.95, 0.85)
	label.text = "CHRONOLITH — 3D Stage 0 POC\n" \
		+ "WASD / arrows: move rover · crystal online · trooper holding\n" \
		+ "renderer: mobile · camera: 60° tilt, fixed"
	layer.add_child(label)
	add_child(layer)
