extends Node3D
var ap: AnimationPlayer
var fb = null

func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_ap(c)
		if r:
			return r
	return null

func _meshes(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_meshes(c, out)

func _ready() -> void:
	var path := ""
	for p in ["res://hero.glb", "res://hero.fbx"]:
		if ResourceLoader.exists(p):
			path = p
	if path == "":
		fb = preload("res://human.gd").new()
		add_child(fb)
		return
	var model: Node3D = load(path).instantiate()
	var holder := Node3D.new()
	add_child(holder)
	holder.add_child(model)
	var ms: Array = []
	_meshes(model, ms)
	var box := AABB()
	var first := true
	for m in ms:
		var a: AABB = model.global_transform.affine_inverse() * m.global_transform * m.get_aabb()
		box = a if first else box.merge(a)
		first = false
	var s := 1.8 / maxf(box.size.y, 0.001)
	model.scale = Vector3.ONE * s
	model.position.y = -box.position.y * s
	holder.rotation.y = PI
	ap = _find_ap(model)
	if ap:
		var names := ap.get_animation_list()
		for n in names:
			if n != "RESET":
				ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
				ap.play(n)
				break
		ap.speed_scale = 0.0

func animate(a: float, delta: float) -> void:
	if fb:
		fb.animate(a, delta)
	elif ap:
		ap.speed_scale = a * 1.1
