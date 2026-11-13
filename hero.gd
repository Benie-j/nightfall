extends Node3D

var skeleton: Skeleton3D
var load_status := "inconnu"
var fallback = null

var bone_ids: Dictionary = {}
var base_rotations: Dictionary = {}

var gait_time := 0.0
var aim_weight := 0.0

const BONE_NAMES := [
	"Bip01 Spine",
	"Bip01 Spine1",
	"Bip01 Spine2",
	"Bip01 Neck",
	"Bip01 L UpperArm",
	"Bip01 L Forearm",
	"Bip01 L Hand",
	"Bip01 R UpperArm",
	"Bip01 R Forearm",
	"Bip01 R Hand",
	"Bip01 L Thigh",
	"Bip01 L Calf",
	"Bip01 L Foot",
	"Bip01 R Thigh",
	"Bip01 R Calf",
	"Bip01 R Foot"
]

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node

	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found

	return null

func _meshes(node: Node, output: Array) -> void:
	if node is MeshInstance3D:
		output.append(node)

	for child in node.get_children():
		_meshes(child, output)

func _ready() -> void:
	if not ResourceLoader.exists("res://hero.glb"):
		push_warning("NIGHTFALL : hero.glb absent, utilisation du personnage de secours.")
		fallback = preload("res://human.gd").new()
		add_child(fallback)
		return

	var packed := load("res://hero.glb") as PackedScene
	if packed == null:
		load_status = "import GLB indisponible - personnage de secours"
		push_warning("NIGHTFALL : hero.glb non charge, activation du personnage de secours.")
		fallback = preload("res://human.gd").new()
		add_child(fallback)
		return

	var model := packed.instantiate() as Node3D
	if model == null:
		push_error("NIGHTFALL : le modèle GLB n'est pas un Node3D.")
		load_status = "racine non Node3D"
		return

	var holder := Node3D.new()
	add_child(holder)
	holder.add_child(model)

	# Calcul des dimensions du modèle
	var meshes: Array = []
	_meshes(model, meshes)

	var bounds := AABB()
	var first := true

	for mesh_node in meshes:
		var local_box: AABB = (
			model.global_transform.affine_inverse()
			* mesh_node.global_transform
			* mesh_node.get_aabb()
		)

		if first:
			bounds = local_box
			first = false
		else:
			bounds = bounds.merge(local_box)

	if first or bounds.size.y <= 0.001:
		push_error("NIGHTFALL : dimensions du modèle invalides.")
		load_status = "aucun mesh / dimensions invalides"
		return

	var scale_factor := 1.8 / bounds.size.y
	model.scale = Vector3.ONE * scale_factor
	model.position.y = -bounds.position.y * scale_factor

	holder.rotation.y = PI

	# Recherche du squelette réellement importé
	skeleton = _find_skeleton(model)

	if skeleton == null:
		push_error("NIGHTFALL : aucun Skeleton3D trouvé dans hero.glb.")
		load_status = "modele charge mais sans Skeleton3D"
		return

	# Mémorisation des poses initiales pour éviter leur accumulation
	for bone_name in BONE_NAMES:
		var bone_index := skeleton.find_bone(bone_name)

		if bone_index >= 0:
			bone_ids[bone_name] = bone_index
			base_rotations[bone_name] = skeleton.get_bone_pose_rotation(bone_index)
		else:
			print("NIGHTFALL : os absent : ", bone_name)

	print("NIGHTFALL : squelette détecté.")
	print("NIGHTFALL : ", bone_ids.size(), "/", BONE_NAMES.size(), " os reconnus.")

func set_aiming(value: bool) -> void:
	aim_weight = 1.0 if value else 0.0

func _pose(bone_name: String, axis: Vector3, angle: float) -> void:
	if skeleton == null:
		return

	if not bone_ids.has(bone_name):
		return

	var bone_index: int = bone_ids[bone_name]
	var base_rotation: Quaternion = base_rotations[bone_name]

	var offset := Quaternion(axis.normalized(), angle)
	skeleton.set_bone_pose_rotation(bone_index, base_rotation * offset)

func animate(amount: float, delta: float) -> void:
	if fallback != null:
		fallback.animate(amount, delta)
		return

	if skeleton == null:
		return

	var speed := clampf(amount, 0.0, 1.0)

	# Cycle de marche
	gait_time += delta * lerpf(2.0, 9.0, speed)

	var stride := sin(gait_time) * 0.55 * speed
	var opposite := sin(gait_time + PI) * 0.55 * speed

	# Respiration au repos et en déplacement
	var breathing := sin(gait_time * 0.45) * 0.025

	# Jambes
	_pose("Bip01 L Thigh", Vector3.RIGHT, stride)
	_pose("Bip01 R Thigh", Vector3.RIGHT, opposite)

	_pose("Bip01 L Calf", Vector3.RIGHT, maxf(0.0, -stride) * 0.65)
	_pose("Bip01 R Calf", Vector3.RIGHT, maxf(0.0, -opposite) * 0.65)

	# Bras : balancement ou posture de visée
	_pose(
		"Bip01 L UpperArm",
		Vector3.RIGHT,
		lerpf(-stride * 0.45, -0.85, aim_weight)
	)

	_pose(
		"Bip01 R UpperArm",
		Vector3.RIGHT,
		lerpf(-opposite * 0.45, -0.95, aim_weight)
	)

	_pose(
		"Bip01 L Forearm",
		Vector3.RIGHT,
		lerpf(0.0, -0.45, aim_weight)
	)

	_pose(
		"Bip01 R Forearm",
		Vector3.RIGHT,
		lerpf(0.0, -0.35, aim_weight)
	)

	# Torse
	_pose(
		"Bip01 Spine2",
		Vector3.RIGHT,
		breathing - 0.06 * aim_weight
	)

func set_shadow_only(on: bool) -> void:
	# Vue subjective : le corps ne s'affiche plus, il projette seulement son ombre.
	var list: Array = []
	_meshes(self, list)
	for m in list:
		(m as GeometryInstance3D).cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if on
			else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		)
