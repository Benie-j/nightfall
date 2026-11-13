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
