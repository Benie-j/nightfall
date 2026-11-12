extends Node3D
var player: Node3D
var pivot: Node3D
var move_idx := -1
var look_idx := -1
var move_origin := Vector2.ZERO
var move_vec := Vector2.ZERO

func mat(c: Color, r := 0.8, m := 0.0) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = c
	s.roughness = r
	s.metallic = m
	return s

func box(size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	return mi

func _ready():
	randomize()
	var fog := Color(0.62, 0.71, 0.68)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = fog
	env.fog_enabled = true
	env.fog_light_color = fog
	env.fog_density = 0.007
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.85, 0.82)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90
	add_child(sun)
	# Sol
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1500, 1500)
	g.mesh = pm
	g.material_override = mat(Color(0.29, 0.31, 0.30), 0.9)
	add_child(g)
	# Immeubles
	for side in [-1, 1]:
		for col in range(4):
			for row in range(-8, 9):
				var h := randf_range(25.0, 120.0)
				var c := Color.from_hsv(0.4, 0.05, randf_range(0.25, 0.55))
				var x: float = side * (28.0 + col * 38.0)
				add_child(box(Vector3(30, h, 30), Vector3(x, h / 2.0, row * 45.0), mat(c, 0.6, 0.2)))
	# Lampadaires et bancs
	var pole := mat(Color(0.07, 0.07, 0.07))
	var bulb := StandardMaterial3D.new()
	bulb.albedo_color = Color(1, 0.95, 0.75)
	bulb.emission_enabled = true
	bulb.emission = Color(1, 0.9, 0.6)
	bulb.emission_energy_multiplier = 3.0
	for z in range(-200, 201, 20):
		for s in [-1, 1]:
			add_child(box(Vector3(0.25, 7, 0.25), Vector3(s * 11, 3.5, z), pole))
			add_child(box(Vector3(0.7, 0.5, 0.7), Vector3(s * 11, 7.2, z), bulb))
			if z % 40 == 0:
				add_child(box(Vector3(2, 0.5, 0.7), Vector3(s * 12.5, 0.5, z + 6), mat(Color(0.48, 0.35, 0.22))))
	# Personnage
	player = Node3D.new()
	add_child(player)
	player.add_child(box(Vector3(0.8, 0.9, 0.4), Vector3(0, 1.5, 0), mat(Color(0.16, 0.17, 0.18))))
	player.add_child(box(Vector3(0.7, 0.9, 0.35), Vector3(0, 0.55, 0), mat(Color(0.35, 0.1, 0.1))))
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.6
	head.mesh = sm
	head.material_override = mat(Color(0.23, 0.16, 0.13))
	head.position = Vector3(0, 2.25, 0)
	player.add_child(head)
	# Visage (perso.png) sur un plan devant la tete
	if ResourceLoader.exists("res://perso.png"):
		var face := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.5, 0.5)
		face.mesh = q
		var fm := StandardMaterial3D.new()
		fm.albedo_texture = load("res://perso.png")
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		face.material_override = fm
		face.position = Vector3(0, 2.25, -0.26)
		face.rotation.y = PI
		player.add_child(face)
	# Camera
	pivot = Node3D.new()
	add_child(pivot)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 2.8, 5)
	cam.rotation.x = -0.2
	cam.far = 600
	pivot.add_child(cam)

func _input(e):
	var w := get_viewport().get_visible_rect().size
	if e is InputEventScreenTouch:
		if e.pressed:
			if e.position.x < w.x * 0.5 and move_idx == -1:
				move_idx = e.index
				move_origin = e.position
			elif look_idx == -1:
				look_idx = e.index
		else:
			if e.index == move_idx:
				move_idx = -1
				move_vec = Vector2.ZERO
			if e.index == look_idx:
				look_idx = -1
	elif e is InputEventScreenDrag:
		if e.index == move_idx:
			move_vec = ((e.position - move_origin) / 80.0).limit_length(1.0)
			move_vec.y = -move_vec.y
		elif e.index == look_idx:
			pivot.rotation.y -= e.relative.x * 0.006

func _process(delta):
	var v := Input.get_vector("ui_left", "ui_right", "ui_down", "ui_up") + move_vec
	if v.length() > 1.0:
		v = v.normalized()
	if v.length() > 0.1:
		var d := pivot.global_transform.basis.x * v.x - pivot.global_transform.basis.z * v.y
		d.y = 0
		d = d.normalized()
		player.position += d * 6.0 * delta * v.length()
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-d.x, -d.z), 10.0 * delta)
	pivot.position = player.position
