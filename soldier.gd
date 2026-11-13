extends Node3D
# NIGHTFALL_COD_LOOK — soldat ennemi (équipement tactique, animation de course, mort).

const Gear = preload("res://gear.gd")
const HeroScript = preload("res://hero.gd")

var body = null

var hp := 100.0
var alive := true
var pref := 20.0
var strafe_dir := 1.0
var strafe_t := 1.0
var burst_left := 0
var cd := 1.5
var gait := 0.0
var leg_l: Node3D
var leg_r: Node3D
var muzzle: Marker3D
var flash: MeshInstance3D
var flash_t := 0.0
var los := true
var los_t := 0.0

func build(kit: Dictionary, use_model: bool = false) -> void:
	if use_model and ResourceLoader.exists("res://hero.glb"):
		body = HeroScript.new()
		add_child(body)
		muzzle = body.tp_muzzle
		_make_flash()
		return
	var uni: Material = kit["uniform"]
	var vest: Material = kit["vest"]
	var skin: Material = kit["skin"]
	var helmet: Material = kit["helmet"]
	var boots: Material = kit["boots"]
	var cloth: Material = kit["cloth"]
	var glass: Material = kit["glass"]
	leg_l = Node3D.new()
	leg_l.position = Vector3(-0.1, 0.95, 0)
	add_child(leg_l)
	leg_r = Node3D.new()
	leg_r.position = Vector3(0.1, 0.95, 0)
	add_child(leg_r)
	for leg in [leg_l, leg_r]:
		Gear.box(leg, Vector3(0.15, 0.82, 0.17), Vector3(0, -0.43, 0), uni)
		Gear.box(leg, Vector3(0.16, 0.12, 0.27), Vector3(0, -0.89, -0.04), boots)
	Gear.box(self, Vector3(0.36, 0.2, 0.22), Vector3(0, 1.0, 0), uni)
	Gear.box(self, Vector3(0.40, 0.50, 0.24), Vector3(0, 1.32, 0), vest)
	Gear.box(self, Vector3(0.30, 0.16, 0.07), Vector3(0, 1.2, -0.15), helmet)
	Gear.box(self, Vector3(0.12, 0.08, 0.1), Vector3(0, 1.57, 0), skin)
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.105
	hs.height = 0.21
	hs.radial_segments = 10
	hs.rings = 6
	head.mesh = hs
	head.material_override = skin
	head.position = Vector3(0, 1.69, 0)
	add_child(head)
	var hm := MeshInstance3D.new()
	var hms := SphereMesh.new()
	hms.radius = 0.135
	hms.height = 0.20
	hms.radial_segments = 10
	hms.rings = 6
	hm.mesh = hms
	hm.material_override = helmet
	hm.position = Vector3(0, 1.74, 0.005)
	add_child(hm)
	Gear.box(self, Vector3(0.19, 0.09, 0.05), Vector3(0, 1.62, -0.09), cloth)
	Gear.box(self, Vector3(0.20, 0.05, 0.04), Vector3(0, 1.71, -0.105), glass)
	var rifle := Gear.rifle(false)
	rifle.position = Vector3(0.12, 1.27, -0.30)
	add_child(rifle)
	muzzle = rifle.get_node("Muzzle") as Marker3D
	Gear.limb(self, Vector3(0.26, 1.5, 0), Vector3(0.28, 1.22, -0.02), 0.09, uni)
	Gear.limb(self, Vector3(0.28, 1.22, -0.02), Vector3(0.12, 1.2, -0.23), 0.08, uni)
	Gear.limb(self, Vector3(-0.26, 1.5, 0), Vector3(-0.24, 1.24, -0.18), 0.09, uni)
	Gear.limb(self, Vector3(-0.24, 1.24, -0.18), Vector3(0.11, 1.24, -0.55), 0.08, uni)
	_make_flash()

func _make_flash() -> void:
	flash = MeshInstance3D.new()
	var fs := SphereMesh.new()
	fs.radius = 0.08
	fs.height = 0.16
	fs.radial_segments = 6
	fs.rings = 3
	flash.mesh = fs
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.75, 0.3)
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash.material_override = fm
	flash.scale = Vector3(1, 1, 1.6)
	flash.visible = false
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle.add_child(flash)

func muzzle_pos() -> Vector3:
	return muzzle.global_position

func fire_flash() -> void:
	flash.visible = true
	flash_t = 0.05

func animate(speed: float, delta: float) -> void:
	if flash_t > 0.0:
		flash_t -= delta
		if flash_t <= 0.0:
			flash.visible = false
	if body != null:
		body.set_aiming(los)
		body.animate(speed, delta)
		return
	gait += delta * 10.0 * speed
	var s: float = sin(gait) * 0.65 * clampf(speed, 0.0, 1.0)
	leg_l.rotation.x = s
	leg_r.rotation.x = -s

func die() -> void:
	alive = false
	flash.visible = false
	var tw := create_tween()
	tw.tween_property(self, "rotation:x", PI / 2.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
