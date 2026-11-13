extends Node3D

const EYE_H := 1.65
const WALK_SPEED := 5.0
const SPRINT_SPEED := 8.0
const CROUCH_SPEED := 2.6
const LOOK_SENS := 0.0045
const RENDER_SCALE := 0.85

var player: CharacterBody3D
var body: Node3D
var head: Node3D
var cam: Camera3D
var war
var yaw := 0.0
var pitch := 0.0
var move_idx := -1
var look_idx := -1
var fire_idx := -1
var reload_idx := -1
var ads_idx := -1
var crouching := false
var jump_req := false
var py := 0.0
var vy := 0.0
var sprint_k := 0.0
var eye_h := EYE_H
var cap_shape: CapsuleShape3D
var cap_node: CollisionShape3D
var move_origin := Vector2.ZERO
var move_vec := Vector2.ZERO
var look_delta := Vector2.ZERO

func mat(c: Color, r := 0.8, m := 0.0) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = c
	s.roughness = r
	s.metallic = m
	return s

# Un seul MultiMesh pour N boîtes : 1 nœud, 1 draw call, 1 matériau.
func _multibox(items: Array, m: Material, colored := false) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colored
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	mm.mesh = bm
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		if colored:
			mm.set_instance_color(i, items[i][1])
	mm.custom_aabb = AABB(Vector3(-250, -1, -450), Vector3(500, 140, 900))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	add_child(mmi)

func _add_shape(sb: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	sb.add_child(cs)

func _build_world() -> void:
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
	env.glow_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)
	# Sol (visuel + collision sur la couche 8, réservée aux impacts de balles)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1500, 1500)
	g.mesh = pm
	g.material_override = mat(Color(0.29, 0.31, 0.30), 0.9)
	add_child(g)
	var ground := StaticBody3D.new()
	ground.collision_layer = 8
	ground.collision_mask = 0
	_add_shape(ground, Vector3(1500, 1, 1500), Vector3(0, -0.5, 0))
	add_child(ground)
	# Collisions du décor (couche 1) : un seul corps statique
	var world := StaticBody3D.new()
	world.collision_layer = 1
	world.collision_mask = 0
	add_child(world)
	# Immeubles
	var b_items: Array = []
	for side in [-1, 1]:
		for col in range(4):
			for row in range(-8, 9):
				var h := randf_range(25.0, 120.0)
				var c := Color.from_hsv(0.4, 0.05, randf_range(0.25, 0.55))
				var x: float = side * (28.0 + col * 38.0)
				var pos := Vector3(x, h / 2.0, row * 45.0)
				b_items.append([Transform3D(Basis.from_scale(Vector3(30, h, 30)), pos), c])
				_add_shape(world, Vector3(30, h, 30), pos)
	var bmat := mat(Color(1, 1, 1), 0.6, 0.2)
	bmat.vertex_color_use_as_albedo = true
	_multibox(b_items, bmat, true)
	# Lampadaires et bancs
	var poles: Array = []
	var bulbs: Array = []
	var benches: Array = []
	for z in range(-200, 201, 20):
		for s in [-1, 1]:
			poles.append([Transform3D(Basis.from_scale(Vector3(0.25, 7, 0.25)), Vector3(s * 11, 3.5, z))])
			bulbs.append([Transform3D(Basis.from_scale(Vector3(0.7, 0.5, 0.7)), Vector3(s * 11, 7.2, z))])
			_add_shape(world, Vector3(0.25, 7, 0.25), Vector3(s * 11, 3.5, z))
			if z % 40 == 0:
				benches.append([Transform3D(Basis.from_scale(Vector3(2, 0.5, 0.7)), Vector3(s * 12.5, 0.5, z + 6))])
	_multibox(poles, mat(Color(0.07, 0.07, 0.07)))
	var bulb := StandardMaterial3D.new()
	bulb.albedo_color = Color(1, 0.95, 0.75)
	bulb.emission_enabled = true
	bulb.emission = Color(1, 0.9, 0.6)
	bulb.emission_energy_multiplier = 3.0
	_multibox(bulbs, bulb)
	_multibox(benches, mat(Color(0.48, 0.35, 0.22)))

func _ready() -> void:
	randomize()
	get_viewport().scaling_3d_scale = RENDER_SCALE
	_build_world()
	# Joueur : corps physique + tête (pivot vertical) + caméra
	player = CharacterBody3D.new()
	player.collision_layer = 4
	player.collision_mask = 1
	player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_child(player)
	cap_node = CollisionShape3D.new()
	cap_shape = CapsuleShape3D.new()
	cap_shape.radius = 0.35
	cap_shape.height = 1.7
	cap_node.shape = cap_shape
	cap_node.position.y = 0.85
	player.add_child(cap_node)
	# Le corps du soldat n'est plus visible en vue subjective : il ne projette que son ombre.
	body = preload("res://hero.gd").new()
	player.add_child(body)
	body.set_shadow_only(true)
	head = Node3D.new()
	head.position.y = EYE_H
	player.add_child(head)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.04
	cam.far = 500.0
	head.add_child(cam)
	cam.current = true
	war = preload("res://war.gd").new()
	war.player = player
	war.cam = cam
	war.body_ref = body
	add_child(war)

func _input(e) -> void:
	var w := get_viewport().get_visible_rect().size
	if e is InputEventScreenTouch:
		if e.pressed:
			var z: int = war.zone_at(e.position)
			if z == 1:
				fire_idx = e.index
				war.fire_held = true
			elif z == 2:
				war.reload()
			elif z == 3:
				ads_idx = e.index
				war.ads_held = true
			elif z == 4:
				jump_req = true
			elif z == 5:
				crouching = not crouching
			elif e.position.x < w.x * 0.5:
				if move_idx == -1:
					move_idx = e.index
					move_origin = e.position
					war.set_joystick(true, move_origin, Vector2.ZERO)
			elif look_idx == -1:
				look_idx = e.index
		else:
			if e.index == fire_idx:
				fire_idx = -1
				war.fire_held = false
			if e.index == ads_idx:
				ads_idx = -1
				war.ads_held = false
			if e.index == move_idx:
				move_idx = -1
				move_vec = Vector2.ZERO
				war.set_joystick(false, Vector2.ZERO, Vector2.ZERO)
			if e.index == look_idx:
				look_idx = -1
	elif e is InputEventScreenDrag:
		if e.index == move_idx:
			var off: Vector2 = (e.position - move_origin).limit_length(80.0)
			move_vec = off / 80.0
			move_vec.y = -move_vec.y
			war.set_joystick(true, move_origin, off)
		elif e.index == look_idx:
			look_delta += e.relative

func _process(delta: float) -> void:
	var sens: float = LOOK_SENS * (1.0 - 0.45 * war.ads_amt)
	yaw -= look_delta.x * sens
	pitch = clampf(pitch - look_delta.y * sens, -1.45, 1.45)
	player.rotation.y = yaw
	head.rotation.x = pitch
	var v := Input.get_vector("ui_left", "ui_right", "ui_down", "ui_up") + move_vec
	if v.length() > 1.0:
		v = v.normalized()
	if war.dead:
		v = Vector2.ZERO
	# Course automatique : joystick poussé à fond, sans viser, tirer ni recharger
	var want_sprint: bool = v.length() > 0.92 and not crouching and not war.ads_held and not war.fire_held and war.reload_t <= 0.0
	sprint_k = lerpf(sprint_k, 1.0 if want_sprint else 0.0, minf(1.0, delta * 8.0))
	var spd := WALK_SPEED + (SPRINT_SPEED - WALK_SPEED) * sprint_k
	if crouching:
		spd = CROUCH_SPEED
	if war.ads_held:
		spd *= 0.6
	var bs := player.global_transform.basis
	var dir := bs.x * v.x - bs.z * v.y
	dir.y = 0.0
	player.velocity = dir * spd
	player.move_and_slide()
	# Saut (hauteur gérée à la main : le sol est une couche à part)
	if jump_req:
		if py <= 0.001 and not crouching and not war.dead:
			vy = 5.2
		jump_req = false
	vy -= 16.0 * delta
	py = maxf(0.0, py + vy * delta)
	if py == 0.0 and vy < 0.0:
		vy = 0.0
	player.position.y = py
	# Accroupi : yeux plus bas, capsule plus courte
	eye_h = lerpf(eye_h, 1.15 if crouching else EYE_H, minf(1.0, delta * 10.0))
	head.position.y = eye_h
	cap_shape.height = 1.1 if crouching else 1.7
	cap_node.position.y = cap_shape.height * 0.5
	var amount := v.length() if v.length() > 0.1 else 0.0
	body.animate(amount, delta)
	var mo := amount * (0.5 if crouching else 1.0)
	if py > 0.01:
		mo = 1.0
	war.motion = mo
	war.sprint_amt = sprint_k
	war.look += look_delta
	look_delta = Vector2.ZERO
