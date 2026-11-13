extends Node3D
var t := 0.0
var legs: Array = []
var arms: Array = []

func _m(c: Color, r := 0.8) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = c
	s.roughness = r
	return s

func _cap(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c

func _sph(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s

func _part(mesh: Mesh, m: Material, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	if parent:
		parent.add_child(mi)
	else:
		add_child(mi)
	return mi

func _limb(pos: Vector3, r: float, h: float, m: Material, end_m: Material, arm: bool) -> void:
	var p := Node3D.new()
	p.position = pos
	add_child(p)
	_part(_cap(r, h), m, Vector3(0, -h / 2.0, 0), p)
	if arm:
		_part(_sph(r * 1.05), end_m, Vector3(0, -h, 0), p)
	else:
		var foot := BoxMesh.new()
		foot.size = Vector3(r * 2.2, 0.08, r * 3.6)
		_part(foot, end_m, Vector3(0, -h - 0.02, -0.05), p)
	if arm:
		arms.append(p)
	else:
		legs.append(p)

func _ready() -> void:
	var skin := _m(Color(0.23, 0.16, 0.13), 0.6)
	var jacket := _m(Color(0.16, 0.17, 0.18), 0.5)
	var pants := _m(Color(0.35, 0.1, 0.1))
	var shoes := _m(Color(0.05, 0.05, 0.05))
	# Torse, bassin, cou
	_part(_cap(0.17, 0.66), jacket, Vector3(0, 1.2, 0)).scale = Vector3(1.25, 1.0, 0.7)
	_part(_sph(0.16), pants, Vector3(0, 0.92, 0)).scale = Vector3(1.1, 0.8, 0.8)
	_part(_cap(0.05, 0.14), skin, Vector3(0, 1.52, 0))
	# Tete + visage
	_part(_sph(0.11), skin, Vector3(0, 1.66, 0)).scale = Vector3(1.0, 1.2, 1.0)
	if ResourceLoader.exists("res://perso.png"):
		var q := QuadMesh.new()
		q.size = Vector2(0.2, 0.24)
		var fm := StandardMaterial3D.new()
		fm.albedo_texture = load("res://perso.png")
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.uv1_scale = Vector3(0.5, 0.55, 1)
		fm.uv1_offset = Vector3(0.235, 0.15, 0)
		var f := _part(q, fm, Vector3(0, 1.66, -0.115))
		f.rotation.y = PI
	# Bras (gauche, droit) et jambes (gauche, droite)
	_limb(Vector3(-0.29, 1.4, 0), 0.05, 0.62, jacket, skin, true)
	_limb(Vector3(0.29, 1.4, 0), 0.05, 0.62, jacket, skin, true)
	_limb(Vector3(-0.1, 0.92, 0), 0.08, 0.9, pants, shoes, false)
	_limb(Vector3(0.1, 0.92, 0), 0.08, 0.9, pants, shoes, false)

func animate(a: float, delta: float) -> void:
	t += delta * 9.0 * maxf(a, 0.0)
	var s := sin(t) * 0.7 * clampf(a, 0.0, 1.0)
	legs[0].rotation.x = s
	legs[1].rotation.x = -s
	arms[0].rotation.x = -s * 0.8
	arms[1].rotation.x = s * 0.8
