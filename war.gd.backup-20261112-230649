extends Node3D
var player
var pivot: Node3D
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
var lbl: Label
var over: Label
var flash: OmniLight3D

func _mat(c: Color) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = c
	s.roughness = 0.8
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

func _ready() -> void:
	randomize()
	_box(Vector3(0.08, 0.12, 0.7), Vector3(0.3, 1.25, -0.45), _mat(Color(0.05, 0.05, 0.05)), player)
	flash = OmniLight3D.new()
	flash.position = Vector3(0.3, 1.25, -0.9)
	flash.light_energy = 0.0
	flash.omni_range = 8.0
	flash.light_color = Color(1, 0.7, 0.3)
	player.add_child(flash)
	var cl := CanvasLayer.new()
	add_child(cl)
	lbl = Label.new()
	lbl.position = Vector2(20, 15)
	lbl.add_theme_font_size_override("font_size", 28)
	cl.add_child(lbl)
	over = Label.new()
	over.add_theme_font_size_override("font_size", 48)
	over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over.visible = false
	_ctrl(over, 0.5, 0.5, -400, -100, 400, 100)
	cl.add_child(over)
	var ch := ColorRect.new()
	ch.color = Color(1, 1, 1, 0.8)
	_ctrl(ch, 0.5, 0.5, -3, -3, 3, 3)
	cl.add_child(ch)
	var fire := Button.new()
	fire.text = "TIR"
	fire.add_theme_font_size_override("font_size", 32)
	_ctrl(fire, 1.0, 1.0, -230, -230, -70, -70)
	fire.button_down.connect(func(): fire_held = true)
	fire.button_up.connect(func(): fire_held = false)
	cl.add_child(fire)
	var rel := Button.new()
	rel.text = "RECHARGER"
	rel.add_theme_font_size_override("font_size", 22)
	_ctrl(rel, 1.0, 1.0, -260, -330, -40, -250)
	rel.pressed.connect(_reload)
	cl.add_child(rel)

func _reload() -> void:
	if reload_t <= 0.0 and ammo < mag:
		reload_t = 1.5

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
		e.set_meta("hp", 60.0)
		e.set_meta("cd", randf_range(1.0, 2.5))
		add_child(e)
		enemies.append(e)

func _tracer(a: Vector3, b: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(a)
	im.surface_add_vertex(b)
	im.surface_end()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 0.85, 0.3)
	mi.material_override = m
	add_child(mi)
	get_tree().create_timer(0.05).timeout.connect(mi.queue_free)

func _shoot() -> void:
	cd = 0.11
	ammo -= 1
	flash.light_energy = 6.0
	var fwd: Vector3 = -pivot.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	player.rotation.y = pivot.rotation.y
	var o: Vector3 = player.position + Vector3(0, 1.4, 0)
	var best = null
	var bd := 150.0
	for e in enemies:
		var v: Vector3 = e.position + Vector3(0, 1.2, 0) - o
		var t := v.dot(fwd)
		if t > 0.0 and t < bd and (v - fwd * t).length() < 0.8:
			best = e
			bd = t
	_tracer(o + fwd, o + fwd * (bd if best != null else 60.0))
	if best != null:
		var h: float = best.get_meta("hp") - 34.0
		best.set_meta("hp", h)
		if h <= 0.0:
			enemies.erase(best)
			score += 10
			create_tween().tween_property(best, "rotation:x", -PI / 2.0, 0.3)
			get_tree().create_timer(3.0).timeout.connect(best.queue_free)

func _hurt(n: float) -> void:
	hp -= n
	if hp <= 0.0:
		hp = 0.0
		dead = true
		rt = 1.0
		over.text = "MISSION ÉCHOUÉE\nVague %d - Score %d\nTouche l'écran pour recommencer" % [wave, score]
		over.visible = true

func _input(e) -> void:
	if dead and rt <= 0.0 and ((e is InputEventScreenTouch and e.pressed) or (e is InputEventKey and e.pressed)):
		get_tree().reload_current_scene()

func _process(delta: float) -> void:
	if dead:
		rt -= delta
		return
	cd -= delta
	flash.light_energy = maxf(flash.light_energy - delta * 60.0, 0.0)
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			ammo = mag
	elif (fire_held or Input.is_key_pressed(KEY_SPACE)) and cd <= 0.0 and ammo > 0:
		_shoot()
	if ammo <= 0 or Input.is_key_pressed(KEY_R):
		_reload()
	for e in enemies:
		var d: Vector3 = player.position - e.position
		d.y = 0
		var dist := d.length()
		var dir := d.normalized()
		e.rotation.y = atan2(-dir.x, -dir.z)
		if dist > 14.0:
			e.position += dir * 3.2 * delta
			e.position.x = clampf(e.position.x, -10.0, 10.0)
		var c: float = e.get_meta("cd") - delta
		if dist < 40.0 and c <= 0.0:
			c = randf_range(0.8, 1.6)
			if randf() < 0.35:
				_hurt(7.0)
		e.set_meta("cd", c)
	if enemies.is_empty():
		wave_t -= delta
		if wave_t <= 0.0:
			_spawn_wave()
	lbl.text = "PV %d | Munitions %d/%d %s\nVague %d | Score %d" % [int(hp), ammo, mag, "(recharge)" if reload_t > 0.0 else "", wave, score]
