#!/data/data/com.termux/files/usr/bin/bash
# Nightfall - Etape 2 : visee (ADS), course auto, accroupi, saut, reticule dynamique,
# indicateur de direction des tirs, kill feed, diagnostic du modele hero.glb.
# Usage : cd ~/nightfall && bash step2_mouvement.sh   (apres l'etape 1)
set -euo pipefail

if [[ ! -f main.gd || ! -f war.gd || ! -f weapon.gd ]]; then
  echo "ERREUR : lance depuis le dossier nightfall, apres l'etape 1 (weapon.gd manquant)."
  exit 1
fi
if grep -q "ads_held" war.gd; then
  echo "INFO : etape 2 deja appliquee."
  exit 0
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
B="backups/step2-$STAMP"
mkdir -p "$B"
cp -f main.gd war.gd weapon.gd "$B/"
echo "==> Sauvegarde : $B/"

cat > main.gd <<'NF_EOF'
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
	var sens := LOOK_SENS * (1.0 - 0.45 * war.ads_amt)
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
	var want_sprint := v.length() > 0.92 and not crouching and not war.ads_held and not war.fire_held and war.reload_t <= 0.0
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
NF_EOF

cat > war.gd <<'NF_EOF'
extends Node3D

var player: CharacterBody3D
var cam: Camera3D
var weapon
var stats: Dictionary
var hp := 100.0
var mag := 30
var ammo := 30
var score := 0
var wave := 0
var enemies: Array = []
var fire_held := false
var cd := 0.0
var reload_t := 0.0
var wave_t := 2.0
var dead := false
var rt := 0.0
var motion := 0.0
var look := Vector2.ZERO
var cam_kick := 0.0
var hurt_t := 0.0
var hit_t := 0.0
var mat_spark: StandardMaterial3D
var mat_blood: StandardMaterial3D
var mat_tracer: StandardMaterial3D
# Interface
var hp_fill: ColorRect
var hp_lbl: Label
var ammo_lbl: Label
var wave_lbl: Label
var over: Label
var vignette: ColorRect
var hit_marks: Array = []
var fire_zone: Panel
var reload_zone: Panel
var joy_base: Panel
var joy_knob: Panel
var ads_held := false
var ads_amt := 0.0
var sprint_amt := 0.0
var body_ref
var zones: Array = []
var cross: Array = []
var dmg_ind: Control
var ind_t := 0.0
var feed: Array = []
var feed_lbl: Label
var diag_lbl: Label
var diag_t := 10.0

func _mat(c: Color) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = c
	s.roughness = 0.8
	return s

func _unshaded(c: Color) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s.albedo_color = c
	return s

func _box(size: Vector3, pos: Vector3, m: Material, parent: Node) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi

func _ctrl(c: Control, ax: float, ay: float, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = l
	c.offset_top = t
	c.offset_right = r
	c.offset_bottom = b
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _circle(fill: Color, border: Color) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(200)
	sb.border_color = border
	sb.set_border_width_all(3)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _zone(cl: CanvasLayer, id: int, text: String, fs: int, l: float, t: float, r: float, b: float) -> Panel:
	var p := _circle(Color(1, 1, 1, 0.10), Color(1, 1, 1, 0.5))
	_ctrl(p, 1.0, 1.0, l, t, r, b)
	var lb := _label(text, fs, HORIZONTAL_ALIGNMENT_CENTER)
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.add_child(lb)
	cl.add_child(p)
	zones.append([p, id])
	return p

func _feed(text: String) -> void:
	feed.append([text, 4.0])
	if feed.size() > 4:
		feed.pop_front()

func _diag() -> String:
	if body_ref == null:
		return ""
	if body_ref.fallback != null:
		return "Modèle : secours (capsules) - hero.glb non chargé"
	if body_ref.skeleton == null:
		return "Modèle : hero.glb ÉCHEC (aucun squelette)"
	return "Modèle : hero.glb OK - os reconnus %d/16" % body_ref.bone_ids.size()

func _label(text: String, size: int, align: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _ready() -> void:
	randomize()
	mat_spark = _unshaded(Color(1.0, 0.8, 0.4))
	mat_blood = _unshaded(Color(0.45, 0.02, 0.02))
	mat_tracer = _unshaded(Color(1.0, 0.85, 0.35))
	weapon = preload("res://weapon.gd").new()
	weapon.setup("rifle")
	cam.add_child(weapon)
	stats = weapon.stats
	mag = int(stats["mag"])
	ammo = mag
	var cl := CanvasLayer.new()
	add_child(cl)
	vignette = ColorRect.new()
	vignette.color = Color(0.7, 0, 0, 0)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(vignette)
	# Barre de vie
	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.55)
	_ctrl(hp_bg, 0.0, 0.0, 20, 20, 340, 44)
	cl.add_child(hp_bg)
	hp_fill = ColorRect.new()
	hp_fill.position = Vector2(3, 3)
	hp_fill.size = Vector2(314, 18)
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bg.add_child(hp_fill)
	hp_lbl = _label("100", 20, HORIZONTAL_ALIGNMENT_CENTER)
	hp_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_bg.add_child(hp_lbl)
	# Vague / score
	wave_lbl = _label("", 26, HORIZONTAL_ALIGNMENT_RIGHT)
	_ctrl(wave_lbl, 1.0, 0.0, -420, 20, -20, 70)
	cl.add_child(wave_lbl)
	# Munitions
	ammo_lbl = _label("", 44, HORIZONTAL_ALIGNMENT_RIGHT)
	_ctrl(ammo_lbl, 1.0, 0.0, -420, 74, -20, 134)
	cl.add_child(ammo_lbl)
	# Réticule dynamique (s'écarte en mouvement et au tir, disparaît en visée)
	for d in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		var cr := ColorRect.new()
		cr.color = Color(1, 1, 1, 0.85)
		_ctrl(cr, 0.5, 0.5, 0, 0, 2, 2)
		cl.add_child(cr)
		cross.append([cr, d])
	# Marqueur de touche (croix à 45 degrés)
	for ang in [45.0, -45.0]:
		var hm := ColorRect.new()
		hm.color = Color(1, 1, 1, 0.95)
		_ctrl(hm, 0.5, 0.5, -11, -1.5, 11, 1.5)
		hm.pivot_offset = Vector2(11, 1.5)
		hm.rotation_degrees = ang
		hm.visible = false
		cl.add_child(hm)
		hit_marks.append(hm)
	# Zones tactiles (gérées par main.gd, multi-doigts) : 1 tir, 2 recharge, 3 viser, 4 saut, 5 accroupi
	fire_zone = _zone(cl, 1, "TIR", 30, -250, -250, -90, -90)
	reload_zone = _zone(cl, 2, "R", 28, -340, -150, -270, -80)
	_zone(cl, 3, "VISER", 18, -130, -370, -40, -280)
	_zone(cl, 4, "SAUT", 18, -370, -260, -290, -180)
	_zone(cl, 5, "ACCR.", 16, -470, -170, -390, -90)
	# Joystick flottant
	joy_base = _circle(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.35))
	joy_base.size = Vector2(160, 160)
	joy_base.visible = false
	cl.add_child(joy_base)
	joy_knob = _circle(Color(1, 1, 1, 0.25), Color(1, 1, 1, 0.6))
	joy_knob.size = Vector2(70, 70)
	joy_knob.visible = false
	cl.add_child(joy_knob)
	# Indicateur de direction des tirs reçus
	dmg_ind = Control.new()
	dmg_ind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ctrl(dmg_ind, 0.5, 0.5, 0, 0, 0, 0)
	var bar := ColorRect.new()
	bar.color = Color(0.9, 0.1, 0.1, 0.9)
	bar.position = Vector2(-70, -210)
	bar.size = Vector2(140, 12)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dmg_ind.add_child(bar)
	dmg_ind.visible = false
	cl.add_child(dmg_ind)
	feed_lbl = _label("", 22, HORIZONTAL_ALIGNMENT_LEFT)
	_ctrl(feed_lbl, 0.0, 0.0, 20, 60, 520, 190)
	cl.add_child(feed_lbl)
	diag_lbl = _label("", 18, HORIZONTAL_ALIGNMENT_LEFT)
	_ctrl(diag_lbl, 0.0, 1.0, 20, -60, 760, -20)
	cl.add_child(diag_lbl)
	over = _label("", 48, HORIZONTAL_ALIGNMENT_CENTER)
	over.visible = false
	_ctrl(over, 0.5, 0.5, -400, -100, 400, 100)
	cl.add_child(over)

func zone_at(p: Vector2) -> int:
	for z in zones:
		if _in_circle(z[0], p, 1.25):
			return z[1]
	return 0

func _in_circle(c: Control, p: Vector2, k: float) -> bool:
	var r := c.get_global_rect()
	return p.distance_to(r.get_center()) <= r.size.x * 0.5 * k

func set_joystick(active: bool, origin: Vector2, offset: Vector2) -> void:
	joy_base.visible = active
	joy_knob.visible = active
	if active:
		joy_base.position = origin - joy_base.size * 0.5
		joy_knob.position = origin + offset - joy_knob.size * 0.5

func reload() -> void:
	if dead or reload_t > 0.0 or ammo >= mag:
		return
	reload_t = float(stats["reload"])
	weapon.start_reload(reload_t)

func _ray(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	return get_world_3d().direct_space_state.intersect_ray(q)

func _spawn_wave() -> void:
	wave += 1
	wave_t = 3.0
	hp = minf(100.0, hp + 20.0)
	for i in range(3 + wave * 2):
		var e := Node3D.new()
		var sgn := 1.0 if randf() < 0.5 else -1.0
		e.position = Vector3(randf_range(-9.0, 9.0), 0, player.position.z + sgn * randf_range(40.0, 70.0))
		_box(Vector3(0.5, 0.7, 0.3), Vector3(0, 1.3, 0), _mat(Color(0.25, 0.3, 0.18)), e)
		_box(Vector3(0.45, 0.85, 0.28), Vector3(0, 0.45, 0), _mat(Color(0.2, 0.22, 0.14)), e)
		_box(Vector3(0.28, 0.3, 0.28), Vector3(0, 1.85, 0), _mat(Color(0.5, 0.38, 0.3)), e)
		_box(Vector3(0.34, 0.18, 0.34), Vector3(0, 2.05, 0), _mat(Color(0.15, 0.18, 0.1)), e)
		_box(Vector3(0.07, 0.1, 0.6), Vector3(0.25, 1.3, -0.35), _mat(Color(0.05, 0.05, 0.05)), e)
		# Cible de tir : corps statique sur la couche 2 (ennemis)
		var sb := StaticBody3D.new()
		sb.collision_layer = 2
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.35
		cap.height = 1.9
		cs.shape = cap
		cs.position.y = 0.95
		sb.add_child(cs)
		e.add_child(sb)
		e.set_meta("hp", 60.0)
		e.set_meta("cd", randf_range(1.0, 2.5))
		e.set_meta("body", sb)
		add_child(e)
		enemies.append(e)

func _tracer(a: Vector3, b: Vector3) -> void:
	var dist_ab := a.distance_to(b)
	if dist_ab < 0.5:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.015, 0.015, dist_ab)
	mi.mesh = bm
	mi.material_override = mat_tracer
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var up := Vector3.UP
	if absf((b - a).normalized().y) > 0.99:
		up = Vector3.RIGHT
	mi.look_at_from_position((a + b) * 0.5, b, up)
	get_tree().create_timer(0.04).timeout.connect(mi.queue_free)

func _impact(p: Vector3, n: Vector3, flesh: bool) -> void:
	var fx := CPUParticles3D.new()
	fx.one_shot = true
	fx.amount = 8
	fx.lifetime = 0.35
	fx.explosiveness = 1.0
	fx.direction = n
	fx.spread = 55.0
	fx.initial_velocity_min = 2.0
	fx.initial_velocity_max = 4.5
	fx.gravity = Vector3(0, -9.0, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.025
	sm.height = 0.05
	sm.radial_segments = 4
	sm.rings = 2
	sm.material = mat_blood if flesh else mat_spark
	fx.mesh = sm
	add_child(fx)
	fx.global_position = p
	fx.emitting = true
	get_tree().create_timer(0.6).timeout.connect(fx.queue_free)

func _shoot() -> void:
	cd = 60.0 / float(stats["rpm"])
	ammo -= 1
	weapon.kick()
	cam_kick = minf(0.06, cam_kick + 0.010 * (1.0 - ads_amt * 0.5))
	var o: Vector3 = cam.global_position
	var bs := cam.global_transform.basis
	var spread: float = float(stats["spread"]) * (1.0 + motion * 1.5 + sprint_amt) * (1.0 - ads_amt * 0.65)
	var fwd: Vector3 = -bs.z + bs.x * randf_range(-spread, spread) + bs.y * randf_range(-spread, spread)
	fwd = fwd.normalized()
	var end: Vector3 = o + fwd * 150.0
	# Couches : 1 décor, 2 ennemis, 8 sol
	var hit := _ray(o, end, 1 | 2 | 8)
	if not hit.is_empty():
		end = hit.position
		var col := hit.collider as Node
		var par = col.get_parent()
		if par != null and par in enemies:
			_damage_enemy(par, float(stats["damage"]))
			_impact(end, hit.normal, true)
		else:
			_impact(end, hit.normal, false)
	_tracer(weapon.muzzle.global_position, end)

func _damage_enemy(e: Node3D, dmg: float) -> void:
	var h: float = float(e.get_meta("hp")) - dmg
	e.set_meta("hp", h)
	hit_t = 0.12
	if h <= 0.0:
		enemies.erase(e)
		score += 10
		_feed("Soldat éliminé  +10")
		hit_t = 0.25
		var sb := e.get_meta("body") as StaticBody3D
		sb.collision_layer = 0
		create_tween().tween_property(e, "rotation:x", -PI / 2.0, 0.3)
		get_tree().create_timer(3.0).timeout.connect(e.queue_free)

func _hurt(n: float, src := Vector3.ZERO) -> void:
	hp -= n
	hurt_t = 0.35
	if src != Vector3.ZERO:
		var to := src - player.position
		to.y = 0.0
		var fwd := -player.global_transform.basis.z
		fwd.y = 0.0
		if to.length() > 0.1:
			dmg_ind.rotation = -fwd.signed_angle_to(to, Vector3.UP)
			ind_t = 1.2
	if hp <= 0.0:
		hp = 0.0
		dead = true
		rt = 1.0
		fire_held = false
		over.text = "MISSION ÉCHOUÉE\nVague %d - Score %d\nTouche l'écran pour recommencer" % [wave, score]
		over.visible = true

func _update_enemies(delta: float) -> void:
	var eye: Vector3 = cam.global_position
	for e in enemies:
		var d: Vector3 = player.position - e.position
		d.y = 0
		var dist := d.length()
		var dir := d.normalized()
		e.rotation.y = atan2(-dir.x, -dir.z)
		# Ligne de vue : le décor (couche 1) bloque la vue et les tirs
		var los := _ray(e.position + Vector3(0, 1.6, 0), eye, 1).is_empty()
		if dist > 18.0 or (not los and dist > 6.0):
			e.position += dir * 3.0 * delta
			e.position.x = clampf(e.position.x, -12.0, 12.0)
		elif dist < 10.0:
			e.position -= dir * 1.5 * delta
			e.position.x = clampf(e.position.x, -12.0, 12.0)
		var c: float = float(e.get_meta("cd")) - delta
		if los and dist < 40.0 and c <= 0.0:
			c = randf_range(0.8, 1.6)
			var target: Vector3 = eye
			if randf() < 0.35:
				_hurt(7.0, e.position)
			else:
				target += Vector3(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
			_tracer(e.position + Vector3(0, 1.4, 0), target)
		e.set_meta("cd", c)

func _input(e) -> void:
	if dead and rt <= 0.0 and ((e is InputEventScreenTouch and e.pressed) or (e is InputEventKey and e.pressed)):
		get_tree().reload_current_scene()

func _physics_process(delta: float) -> void:
	if dead:
		return
	cd -= delta
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			ammo = mag
	elif (fire_held or Input.is_key_pressed(KEY_SPACE)) and cd <= 0.0 and ammo > 0:
		_shoot()
	if ammo <= 0 or Input.is_key_pressed(KEY_R):
		reload()
	_update_enemies(delta)
	if enemies.is_empty():
		wave_t -= delta
		if wave_t <= 0.0:
			_spawn_wave()

func _process(delta: float) -> void:
	if dead:
		rt -= delta
	cam_kick = lerpf(cam_kick, 0.0, minf(1.0, delta * 12.0))
	cam.rotation.x = cam_kick
	var want_ads := ads_held and reload_t <= 0.0 and not dead
	ads_amt = move_toward(ads_amt, 1.0 if want_ads else 0.0, delta * 7.0)
	cam.fov = lerpf(70.0, 52.0, ads_amt) + sprint_amt * 4.0
	weapon.update(delta, motion, look, ads_amt, sprint_amt)
	look = Vector2.ZERO
	hurt_t = maxf(0.0, hurt_t - delta)
	hit_t = maxf(0.0, hit_t - delta)
	vignette.color.a = minf(0.45, hurt_t * 1.3)
	for m in hit_marks:
		m.visible = hit_t > 0.0
	var ratio := clampf(hp / 100.0, 0.0, 1.0)
	hp_fill.size.x = 314.0 * ratio
	hp_fill.color = Color(0.9, 0.15, 0.1).lerp(Color(0.25, 0.8, 0.3), ratio)
	hp_lbl.text = str(int(hp))
	ammo_lbl.text = "RECHARGE…" if reload_t > 0.0 else "%d / %d" % [ammo, mag]
	wave_lbl.text = "VAGUE %d   SCORE %d" % [wave, score]
	ind_t = maxf(0.0, ind_t - delta)
	dmg_ind.visible = ind_t > 0.0
	var gap := 6.0 + 16.0 * clampf(motion + sprint_amt, 0.0, 1.5) + 14.0 * weapon.kick_v
	for it in cross:
		var cr: ColorRect = it[0]
		var dd: Vector2 = it[1]
		var bw := 2.0 if dd.x == 0.0 else 9.0
		var bh := 9.0 if dd.x == 0.0 else 2.0
		var cc := dd * (gap + 5.0)
		cr.offset_left = cc.x - bw * 0.5
		cr.offset_right = cc.x + bw * 0.5
		cr.offset_top = cc.y - bh * 0.5
		cr.offset_bottom = cc.y + bh * 0.5
		cr.visible = ads_amt < 0.5
	for f in feed:
		f[1] -= delta
	while not feed.is_empty() and feed[0][1] <= 0.0:
		feed.pop_front()
	var txt := ""
	for f in feed:
		txt += str(f[0]) + "\n"
	feed_lbl.text = txt
	if diag_t > 0.0:
		diag_t -= delta
		diag_lbl.text = _diag()
	else:
		diag_lbl.text = ""
NF_EOF

cat > weapon.gd <<'NF_EOF'
extends Node3D

# Arme en vue subjective. Pour ajouter une arme : ajouter une entrée dans STATS
# et un cas dans setup(). Le combat (war.gd) ne lit que ces valeurs.
const STATS = {
	"rifle": {"name": "FA-47", "mag": 30, "rpm": 600.0, "damage": 34.0, "spread": 0.012, "reload": 2.0}
}
const REST_POS := Vector3(0.17, -0.19, -0.32)
const MAG_POS := Vector3(0.0, -0.075, -0.04)
const ADS_POS := Vector3(0.0, -0.082, -0.28)

var stats: Dictionary = {}
var muzzle: Marker3D
var mag_node: Node3D
var flash: MeshInstance3D
var light: OmniLight3D
var kick_v := 0.0
var flash_t := 0.0
var reload_t := 0.0
var reload_dur := 1.0
var bob_t := 0.0
var sway := Vector2.ZERO

func _mat(c: Color, r: float, m: float) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = c
	s.roughness = r
	s.metallic = m
	return s

func _box(parent: Node3D, size: Vector3, pos: Vector3, rot_deg: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _cyl(parent: Node3D, radius: float, length: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = length
	c.radial_segments = 12
	c.rings = 1
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = Vector3(90, 0, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func setup(id: String) -> void:
	stats = STATS[id]
	var steel := _mat(Color(0.16, 0.16, 0.17), 0.45, 0.5)
	var dark := _mat(Color(0.06, 0.06, 0.07), 0.6, 0.3)
	var poly := _mat(Color(0.15, 0.16, 0.13), 0.8, 0.0)
	var wood := _mat(Color(0.30, 0.19, 0.10), 0.7, 0.0)
	# Boîtier, couvre-culasse, rail
	_box(self, Vector3(0.055, 0.085, 0.34), Vector3(0, 0, 0), Vector3.ZERO, steel)
	_box(self, Vector3(0.048, 0.03, 0.30), Vector3(0, 0.055, 0.0), Vector3.ZERO, dark)
	# Garde-main, canon, tube à gaz, frein de bouche
	_box(self, Vector3(0.06, 0.065, 0.22), Vector3(0, -0.005, -0.27), Vector3.ZERO, wood)
	_cyl(self, 0.011, 0.34, Vector3(0, 0.012, -0.40), dark)
	_cyl(self, 0.008, 0.20, Vector3(0, 0.045, -0.28), steel)
	_cyl(self, 0.016, 0.05, Vector3(0, 0.012, -0.58), dark)
	# Organes de visée
	_box(self, Vector3(0.02, 0.015, 0.02), Vector3(0, 0.04, -0.54), Vector3.ZERO, dark)
	_box(self, Vector3(0.006, 0.035, 0.006), Vector3(0, 0.062, -0.54), Vector3.ZERO, dark)
	_box(self, Vector3(0.032, 0.02, 0.015), Vector3(0, 0.07, 0.10), Vector3.ZERO, dark)
	# Crosse, plaque de couche, poignée, pontet, détente
	_box(self, Vector3(0.045, 0.085, 0.24), Vector3(0, -0.02, 0.29), Vector3(-6, 0, 0), poly)
	_box(self, Vector3(0.05, 0.09, 0.02), Vector3(0, -0.03, 0.42), Vector3(-6, 0, 0), dark)
	_box(self, Vector3(0.035, 0.10, 0.05), Vector3(0, -0.085, 0.12), Vector3(18, 0, 0), poly)
	_box(self, Vector3(0.008, 0.02, 0.07), Vector3(0, -0.055, 0.045), Vector3.ZERO, dark)
	_box(self, Vector3(0.006, 0.03, 0.01), Vector3(0, -0.05, 0.05), Vector3(10, 0, 0), steel)
	# Chargeur (nœud séparé : animé au rechargement)
	mag_node = Node3D.new()
	mag_node.position = MAG_POS
	add_child(mag_node)
	_box(mag_node, Vector3(0.04, 0.14, 0.06), Vector3(0, -0.05, 0), Vector3(-10, 0, 0), dark)
	# Bouche du canon + flash
	muzzle = Marker3D.new()
	muzzle.position = Vector3(0, 0.012, -0.62)
	add_child(muzzle)
	flash = MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.05
	fm.height = 0.10
	fm.radial_segments = 8
	fm.rings = 4
	flash.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fmat.albedo_color = Color(1.0, 0.7, 0.25)
	flash.material_override = fmat
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.visible = false
	muzzle.add_child(flash)
	light = OmniLight3D.new()
	light.omni_range = 6.0
	light.light_color = Color(1.0, 0.75, 0.35)
	light.light_energy = 0.0
	muzzle.add_child(light)
	position = REST_POS

func kick() -> void:
	kick_v = minf(1.5, kick_v + 1.0)
	flash_t = 0.05
	flash.rotation.z = randf() * TAU
	flash.scale = Vector3.ONE * randf_range(0.8, 1.4)

func start_reload(duration: float) -> void:
	reload_dur = maxf(duration, 0.1)
	reload_t = reload_dur

func update(delta: float, move: float, look: Vector2, ads: float, sprint: float) -> void:
	bob_t += delta * (2.0 + move * 8.0 + sprint * 3.0)
	var calm := 1.0 - ads * 0.8
	var target := Vector2(clampf(-look.x * 0.0008, -0.04, 0.04), clampf(look.y * 0.0008, -0.04, 0.04)) * calm
	sway = sway.lerp(target, minf(1.0, delta * 8.0))
	var p := REST_POS.lerp(ADS_POS, ads)
	p += Vector3(sin(bob_t) * 0.008 * move * calm, -absf(sin(bob_t)) * 0.01 * move * calm, 0.0)
	p += Vector3(sway.x, sway.y, 0.0)
	p.y += sin(bob_t * 0.5) * 0.0015 * calm
	var r := Vector3(sway.y * 2.0, sway.x * 3.0, 0.0)
	# Course : arme abaissée et inclinée en travers
	p += Vector3(-0.07, -0.05, 0.03) * sprint
	r += Vector3(-0.30, 0.55, 0.12) * sprint
	kick_v = maxf(0.0, kick_v - delta * 9.0)
	var kick_k := 1.0 - ads * 0.5
	p.z += kick_v * 0.035 * kick_k
	r.x += kick_v * 0.05 * kick_k
	var mag_off := 0.0
	if reload_t > 0.0:
		reload_t -= delta
		var prog := clampf(1.0 - reload_t / reload_dur, 0.0, 1.0)
		var w := sin(prog * PI)
		r.x -= w * 0.55
		r.z += w * 0.35
		p.y -= w * 0.10
		p.x -= w * 0.05
		if prog > 0.15 and prog < 0.45:
			mag_off = (prog - 0.15) / 0.30
		elif prog >= 0.45 and prog < 0.70:
			mag_off = 1.0 - (prog - 0.45) / 0.25
	mag_node.position = MAG_POS + Vector3(0.0, -0.22 * mag_off, 0.03 * mag_off)
	position = p
	rotation = r
	flash_t = maxf(0.0, flash_t - delta)
	flash.visible = flash_t > 0.0
	light.light_energy = 4.0 if flash_t > 0.0 else 0.0
NF_EOF

echo "==> Verification :"
ls -l main.gd war.gd weapon.gd
grep -c "ads_held" main.gd war.gd
echo ""
echo "Termine. Rollback : cp $B/*.gd ."
