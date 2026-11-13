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

	# Remplacer le modèle géométrique par le modèle FPS M4A1
	# lorsque la ressource externe est disponible.
	var fp_scene := load("res://assets/external/m4a1_fp.glb") as PackedScene
	if fp_scene != null:
		for child in get_children():
			child.visible = false
		var fp_model := fp_scene.instantiate()
		fp_model.scale = Vector3.ONE
		add_child(fp_model)
	else:
		push_warning("M4A1 FPS GLB absent : utilisation du modèle procédural.")

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
