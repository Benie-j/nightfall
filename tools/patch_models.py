import sys
p = "main.gd"
s = open(p).read()
if "NIGHTFALL_MODELS" in s:
    print("main.gd déjà patché (modèles)"); sys.exit(0)
def rep(old, new):
    global s
    if old not in s:
        print("ERREUR patch : introuvable ->", old[:60]); sys.exit(2)
    s = s.replace(old, new, 1)
rep("func _soft_tex()", '''# NIGHTFALL_MODELS : vrais modèles 3D (res://models/) à la place des formes simples
func _collect_meshes(node: Node, output: Array) -> void:
	if node is MeshInstance3D:
		output.append(node)
	for child in node.get_children():
		_collect_meshes(child, output)

func _model_node(parent: Node3D, base: String, length: float, offset: Vector3) -> Node3D:
	var ps := load("res://models/%s/model.gltf" % base) as PackedScene
	if ps == null:
		return null
	var inst := ps.instantiate() as Node3D
	if inst == null:
		return null
	var wrap := Node3D.new()
	wrap.position = offset
	parent.add_child(wrap)
	wrap.add_child(inst)
	var meshes: Array = []
	_collect_meshes(inst, meshes)
	var bounds := AABB()
	var first := true
	for mn in meshes:
		var lb: AABB = inst.global_transform.affine_inverse() * mn.global_transform * mn.get_aabb()
		if first:
			bounds = lb
			first = false
		else:
			bounds = bounds.merge(lb)
	if first or maxf(bounds.size.x, bounds.size.z) < 0.001:
		wrap.queue_free()
		return null
	var k: float = length / maxf(bounds.size.x, bounds.size.z)
	inst.scale = Vector3.ONE * k
	var ctr: Vector3 = bounds.get_center()
	inst.position = Vector3(-ctr.x * k, -bounds.position.y * k, -ctr.z * k)
	if bounds.size.x > bounds.size.z * 1.2:
		wrap.rotation.y = PI * 0.5
	return wrap

func _swap_models(g: Node3D, kind: int) -> void:
	var base := ""
	var length := 1.0
	var count := 1
	match kind:
		0:
			base = "barrier"
			length = 3.2
		1:
			base = "sandbag"
			length = 2.8
		3:
			base = "crate"
			length = 1.3
		6:
			base = "barrel"
			length = 0.9
			count = 2
		_:
			return
	if not ResourceLoader.exists("res://models/%s/model.gltf" % base):
		return
	var first_node: Node3D = _model_node(g, base, length, Vector3.ZERO)
	if first_node == null:
		return
	if count > 1:
		_model_node(g, base, length, Vector3(0.6, 0.0, 0.2))
	for ch in g.get_children():
		if ch is MeshInstance3D:
			(ch as MeshInstance3D).visible = false

func _scatter(base: String, length: float, count: int, rng: RandomNumberGenerator) -> void:
	if int(settings["quality"]) < 1:
		return
	if not ResourceLoader.exists("res://models/%s/model.gltf" % base):
		return
	for i in range(count):
		var holder := Node3D.new()
		holder.position = Vector3(rng.randf_range(-8.5, 8.5), 0.0, rng.randf_range(-185.0, 185.0))
		holder.rotation.y = rng.randf_range(0.0, TAU)
		add_child(holder)
		if _model_node(holder, base, length, Vector3.ZERO) == null:
			holder.queue_free()
			return

func _soft_tex()''')
rep("\tvar aom := MeshInstance3D.new()\n", "\tif int(settings[\"quality\"]) >= 1:\n\t\t_swap_models(g, kind)\n\tvar aom := MeshInstance3D.new()\n")
rep("\t# barrages aux extrémités\n", "\t_scatter(\"tire\", 0.9, 14, rng)\n\t_scatter(\"cone\", 0.7, 10, rng)\n\t# barrages aux extrémités\n")
open(p, "w").write(s)
print("main.gd patché (modèles)")
