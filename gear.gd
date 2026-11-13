extends RefCounted
# NIGHTFALL_COD_LOOK — outils de construction : matériaux, arme détaillée, membres.

static func mat(c: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = c
	s.roughness = rough
	s.metallic = metal
	return s

static func unshaded(c: Color) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = c
	s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return s

static func box(parent: Node, size: Vector3, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

# Cylindre couché le long de l'axe Z (canon, etc.)
static func barrel(parent: Node, r: float, length: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = length
	c.radial_segments = 8
	c.rings = 1
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	parent.add_child(mi)
	return mi

# Cylindre couché le long de l'axe X (essieux de voiture)
static func axle(parent: Node, r: float, length: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = length
	c.radial_segments = 10
	c.rings = 1
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	parent.add_child(mi)
	return mi

# Segment (bras, avant-bras) entre deux points.
static func limb(parent: Node, from: Vector3, to: Vector3, thick: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	var d: Vector3 = to - from
	b.size = Vector3(thick, thick, d.length())
	mi.mesh = b
	mi.material_override = m
	parent.add_child(mi)
	mi.transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP), (from + to) * 0.5)
	return mi

# Fusil d'assaut. Avant = -Z. Un Marker3D "Muzzle" marque le bout du canon.
static func rifle(detail: bool = true) -> Node3D:
	var root := Node3D.new()
	var metal := mat(Color(0.13, 0.13, 0.14), 0.4, 0.7)
	var poly := mat(Color(0.055, 0.055, 0.06), 0.7, 0.1)
	var tan := mat(Color(0.30, 0.26, 0.19), 0.8, 0.0)
	box(root, Vector3(0.05, 0.075, 0.30), Vector3(0, 0, 0), poly)
	box(root, Vector3(0.056, 0.06, 0.24), Vector3(0, -0.002, -0.26), tan)
	barrel(root, 0.011, 0.20, Vector3(0, 0.004, -0.48), metal)
	box(root, Vector3(0.036, 0.10, 0.19), Vector3(0, -0.012, 0.24), poly, Vector3(-4, 0, 0))
	box(root, Vector3(0.034, 0.13, 0.055), Vector3(0, -0.10, -0.045), metal, Vector3(10, 0, 0))
	if detail:
		box(root, Vector3(0.03, 0.085, 0.04), Vector3(0, -0.085, 0.075), poly, Vector3(18, 0, 0))
		box(root, Vector3(0.022, 0.012, 0.46), Vector3(0, 0.043, -0.05), metal)
		barrel(root, 0.017, 0.055, Vector3(0, 0.004, -0.58), metal)
		box(root, Vector3(0.008, 0.032, 0.008), Vector3(0, 0.05, -0.50), metal)
		box(root, Vector3(0.062, 0.02, 0.1), Vector3(0, -0.04, -0.27), poly)
		# viseur point rouge (cadre ouvert + point lumineux)
		box(root, Vector3(0.04, 0.012, 0.07), Vector3(0, 0.055, -0.03), poly)
		box(root, Vector3(0.006, 0.042, 0.012), Vector3(-0.018, 0.078, -0.03), poly)
		box(root, Vector3(0.006, 0.042, 0.012), Vector3(0.018, 0.078, -0.03), poly)
		box(root, Vector3(0.042, 0.006, 0.07), Vector3(0, 0.102, -0.03), poly)
		var dot := StandardMaterial3D.new()
		dot.albedo_color = Color(1.0, 0.1, 0.05)
		dot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		box(root, Vector3(0.004, 0.004, 0.004), Vector3(0, 0.078, -0.07), dot)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.004, -0.61)
	root.add_child(muzzle)
	return root

# Gants et manches en vue FPS (coordonnées locales de l'arme).
static func fp_arms(rifle_root: Node3D) -> void:
	var sleeve := mat(Color(0.15, 0.16, 0.13), 0.9)
	var glove := mat(Color(0.05, 0.05, 0.05), 0.6)
	box(rifle_root, Vector3(0.07, 0.09, 0.07), Vector3(0.004, -0.08, 0.075), glove)
	limb(rifle_root, Vector3(0.012, -0.09, 0.10), Vector3(0.16, -0.25, 0.36), 0.075, sleeve)
	box(rifle_root, Vector3(0.075, 0.07, 0.10), Vector3(0, -0.058, -0.27), glove)
	limb(rifle_root, Vector3(-0.01, -0.07, -0.24), Vector3(-0.18, -0.24, 0.24), 0.08, sleeve)
