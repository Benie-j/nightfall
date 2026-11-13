extends Node3D
# NIGHTFALL_COD_LOOK — sons synthétisés, étincelles, traçantes, douilles, ambiance.

const RATE := 22050

var enabled_sound := true
var snd: Dictionary = {}
var pools: Dictionary = {}
var pool_idx: Dictionary = {}
var p3d: Array[AudioStreamPlayer3D] = []
var p3d_i := 0
var wind: AudioStreamPlayer
var ambient_t := 5.0
var anchor: Node3D = null

var burst_pools: Dictionary = {}
var burst_idx: Dictionary = {}

var tracer_nodes: Array[MeshInstance3D] = []
var tracer_i := 0
var tracer_a := PackedVector3Array()
var tracer_b := PackedVector3Array()
var tracer_t := PackedFloat32Array()
var tracer_d := PackedFloat32Array()

var shell_nodes: Array[MeshInstance3D] = []
var shell_i := 0
var shell_v := PackedVector3Array()
var shell_life := PackedFloat32Array()

func _wav(data: PackedByteArray, loop: bool = false) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(data.size() * 0.5)
	return w

func _burst(dur: float, decay: float, lpf: float, thump: float, thump_decay: float, thump_amt: float, gain: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in range(n):
		var t: float = float(i) / float(RATE)
		var w: float = randf() * 2.0 - 1.0
		lp += (w - lp) * lpf
		var s: float = lp * exp(-t * decay) + sin(TAU * thump * t) * exp(-t * thump_decay) * thump_amt
		s += w * exp(-t * 350.0) * 0.8
		s = clampf(s * gain, -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 32000.0))
	return _wav(data)

func _clicks(times: Array, dur: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t: float = float(i) / float(RATE)
		var s := 0.0
		for c in times:
			var dt: float = t - float(c)
			if dt >= 0.0:
				s += (randf() * 2.0 - 1.0) * exp(-dt * 130.0) * 0.55
		s = clampf(s, -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 32000.0))
	return _wav(data)

func _tone(f1: float, f2: float, dur: float, decay: float, gain: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t: float = float(i) / float(RATE)
		var s: float = (sin(TAU * f1 * t) + sin(TAU * f2 * t) * 0.6) * exp(-t * decay) * gain
		s = clampf(s, -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 32000.0))
	return _wav(data)

func _wind() -> AudioStreamWAV:
	var dur := 3.0
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in range(n):
		var t: float = float(i) / float(RATE)
		lp += ((randf() * 2.0 - 1.0) - lp) * 0.035
		var s: float = lp * sin(PI * t / dur) * 2.2
		s = clampf(s, -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 24000.0))
	return _wav(data, true)

func _make_pool(sound_name: String, count: int) -> void:
	var arr: Array[AudioStreamPlayer] = []
	for i in range(count):
		var p := AudioStreamPlayer.new()
		p.stream = snd[sound_name]
		add_child(p)
		arr.append(p)
	pools[sound_name] = arr
	pool_idx[sound_name] = 0

func _make_burst_pool(kind: String, col: Color, grav: float, amount: int, size: float, v_min: float, v_max: float, life: float, count: int) -> void:
	var arr: Array[CPUParticles3D] = []
	for i in range(count):
		var p := CPUParticles3D.new()
		p.one_shot = true
		p.emitting = false
		p.amount = amount
		p.lifetime = life
		p.explosiveness = 1.0
		p.direction = Vector3.UP
		p.spread = 55.0
		p.initial_velocity_min = v_min
		p.initial_velocity_max = v_max
		p.gravity = Vector3(0, -grav, 0)
		p.local_coords = false
		var m := BoxMesh.new()
		m.size = Vector3(size, size, size)
		p.mesh = m
		var mt := StandardMaterial3D.new()
		mt.albedo_color = col
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		p.material_override = mt
		add_child(p)
		arr.append(p)
	burst_pools[kind] = arr
	burst_idx[kind] = 0

func _ready() -> void:
	snd["shot"] = _burst(0.30, 15.0, 0.38, 75.0, 26.0, 0.9, 1.7)
	snd["enemy"] = _burst(0.34, 13.0, 0.22, 60.0, 22.0, 0.8, 1.5)
	snd["boom"] = _burst(0.9, 5.0, 0.07, 45.0, 6.0, 1.1, 1.6)
	snd["reload"] = _clicks([0.10, 0.46, 0.64], 0.8)
	snd["empty"] = _clicks([0.01], 0.12)
	snd["hit"] = _tone(1900.0, 2600.0, 0.07, 60.0, 0.5)
	snd["kill"] = _tone(900.0, 1350.0, 0.18, 22.0, 0.6)
	snd["hurt"] = _burst(0.28, 12.0, 0.1, 55.0, 14.0, 1.0, 1.2)
	_make_pool("shot", 4)
	_make_pool("reload", 1)
	_make_pool("empty", 1)
	_make_pool("hit", 2)
	_make_pool("kill", 1)
	_make_pool("hurt", 1)
	for i in range(5):
		var p3 := AudioStreamPlayer3D.new()
		p3.max_distance = 140.0
		p3.unit_size = 9.0
		add_child(p3)
		p3d.append(p3)
	wind = AudioStreamPlayer.new()
	wind.stream = _wind()
	wind.volume_db = -17.0
	add_child(wind)
	_make_burst_pool("spark", Color(1.0, 0.8, 0.35), 12.0, 7, 0.035, 2.5, 6.0, 0.3, 5)
	_make_burst_pool("dust", Color(0.62, 0.55, 0.45), 2.0, 8, 0.10, 0.8, 2.2, 0.7, 5)
	_make_burst_pool("blood", Color(0.45, 0.02, 0.02), 9.0, 8, 0.05, 1.5, 4.0, 0.45, 4)
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(1.0, 0.86, 0.45, 0.9)
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	for i in range(14):
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.025, 0.025, 2.6)
		mi.mesh = b
		mi.material_override = tm
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		tracer_nodes.append(mi)
		tracer_a.append(Vector3.ZERO)
		tracer_b.append(Vector3.ZERO)
		tracer_t.append(-1.0)
		tracer_d.append(0.1)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.75, 0.55, 0.15)
	sm.metallic = 0.9
	sm.roughness = 0.35
	for i in range(8):
		var mi2 := MeshInstance3D.new()
		var b2 := BoxMesh.new()
		b2.size = Vector3(0.012, 0.012, 0.045)
		mi2.mesh = b2
		mi2.material_override = sm
		mi2.visible = false
		mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi2)
		shell_nodes.append(mi2)
		shell_v.append(Vector3.ZERO)
		shell_life.append(-1.0)

func set_sound(on: bool) -> void:
	enabled_sound = on
	if not on and wind != null:
		wind.stop()

func start_ambient() -> void:
	if enabled_sound and wind != null and not wind.playing:
		wind.play()

func play(sound_name: String, vol: float = 0.0, pitch: float = 1.0) -> void:
	if not enabled_sound or not pools.has(sound_name):
		return
	var arr: Array = pools[sound_name]
	var i: int = pool_idx[sound_name]
	var p: AudioStreamPlayer = arr[i]
	pool_idx[sound_name] = (i + 1) % arr.size()
	p.volume_db = vol
	p.pitch_scale = pitch
	p.play()

func play3d(sound_name: String, pos: Vector3, vol: float = 0.0, pitch: float = 1.0) -> void:
	if not enabled_sound or not snd.has(sound_name):
		return
	var p: AudioStreamPlayer3D = p3d[p3d_i]
	p3d_i = (p3d_i + 1) % p3d.size()
	p.stream = snd[sound_name]
	p.global_position = pos
	p.volume_db = vol
	p.pitch_scale = pitch
	p.play()

func burst(kind: String, pos: Vector3, normal: Vector3) -> void:
	if not burst_pools.has(kind):
		return
	var arr: Array = burst_pools[kind]
	var i: int = burst_idx[kind]
	var p: CPUParticles3D = arr[i]
	burst_idx[kind] = (i + 1) % arr.size()
	p.global_position = pos
	p.direction = normal
	p.restart()
	p.emitting = true

func tracer(a: Vector3, b: Vector3) -> void:
	var dist: float = a.distance_to(b)
	if dist < 1.5:
		return
	var i := tracer_i
	tracer_i = (tracer_i + 1) % tracer_nodes.size()
	var node: MeshInstance3D = tracer_nodes[i]
	var dir: Vector3 = (b - a) / dist
	var up := Vector3.UP
	if absf(dir.y) > 0.98:
		up = Vector3.RIGHT
	node.visible = true
	node.look_at_from_position(a, b, up)
	tracer_a[i] = a
	tracer_b[i] = b
	tracer_t[i] = 0.0
	tracer_d[i] = clampf(dist / 240.0, 0.05, 0.4)

func shell(pos: Vector3, right: Vector3) -> void:
	var i := shell_i
	shell_i = (shell_i + 1) % shell_nodes.size()
	var node: MeshInstance3D = shell_nodes[i]
	node.visible = true
	node.global_position = pos
	node.rotation = Vector3(randf() * TAU, randf() * TAU, 0.0)
	shell_v[i] = right * randf_range(1.6, 2.6) + Vector3(0, randf_range(1.4, 2.2), 0)
	shell_life[i] = 1.2

func _process(delta: float) -> void:
	for i in range(tracer_nodes.size()):
		if tracer_t[i] < 0.0:
			continue
		tracer_t[i] += delta
		var k: float = tracer_t[i] / tracer_d[i]
		if k >= 1.0:
			tracer_t[i] = -1.0
			tracer_nodes[i].visible = false
		else:
			tracer_nodes[i].global_position = tracer_a[i].lerp(tracer_b[i], k)
	for i in range(shell_nodes.size()):
		if shell_life[i] < 0.0:
			continue
		shell_life[i] -= delta
		var node: MeshInstance3D = shell_nodes[i]
		var v: Vector3 = shell_v[i]
		v.y -= 9.8 * delta
		node.global_position += v * delta
		if node.global_position.y < 0.02:
			node.global_position.y = 0.02
			v = Vector3.ZERO
		shell_v[i] = v
		if shell_life[i] < 0.0:
			node.visible = false
	if enabled_sound:
		ambient_t -= delta
		if ambient_t <= 0.0:
			ambient_t = randf_range(4.0, 9.0)
			var ang: float = randf() * TAU
			var pos := Vector3(cos(ang) * 90.0, 6.0, sin(ang) * 90.0)
			var base := Vector3.ZERO
			if anchor != null:
				base = anchor.global_position
			play3d("boom", base + pos, -14.0, randf_range(0.5, 0.8))
