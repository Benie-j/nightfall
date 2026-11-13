extends Node3D
# NIGHTFALL_COD_LOOK — scène principale : monde en ruines, ambiance « guerre moderne »,
# caméra FPS/TPS, arme en vue, post-traitement léger, qualité adaptée au 32 bits.

const Gear = preload("res://gear.gd")
const FxScript = preload("res://fx.gd")
const HudScript = preload("res://hud.gd")
const WarScript = preload("res://war.gd")
const HeroScript = preload("res://hero.gd")

const CFG_PATH := "user://nightfall.cfg"

const GRADE_CODE := """
shader_type canvas_item;
render_mode blend_mul;
uniform float damage = 0.0;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv * vec2(1.25, 1.0));
	float v = smoothstep(0.30, 0.95, d);
	vec3 col = mix(vec3(1.0), vec3(0.66, 0.74, 0.78), v);
	col = mix(col, col * vec3(1.0, 0.22, 0.22), clamp(damage, 0.0, 1.0) * smoothstep(0.15, 0.85, d));
	COLOR = vec4(col, 1.0);
}
"""

const GRAIN_CODE := """
shader_type canvas_item;
float h(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
void fragment() {
	vec2 q = floor(FRAGCOORD.xy * 0.5) + floor(TIME * 24.0) * vec2(17.0, 31.0);
	float n = h(q);
	COLOR = vec4(vec3(n), 0.05);
}
"""

var settings: Dictionary = {"quality": -1, "sens": 1.0, "sound": true, "vibe": true, "fps": true}

var env: Environment
var sun: DirectionalLight3D
var player
var rig: Node3D
var pitch_node: Node3D
var cam: Camera3D
var vm: Node3D
var vm_rifle: Node3D
var vm_muzzle: Marker3D
var flash_fp: Node3D
var flash_tp: Node3D
var light_fp: OmniLight3D
var light_tp: OmniLight3D
var flash_t := 0.0
var hud
var fx
var war
var grade_mat: ShaderMaterial
var grain: ColorRect
var dust: CPUParticles3D
var smokes: Array[CPUParticles3D] = []

var ray_boxes: Array[AABB] = []
var buckets: Array = []

var yaw := 0.0
var pitch := 0.0
var ads_t := 0.0
var sprint_t := 0.0
var moving := 0.0
var bob_t := 0.0
var shake := 0.0
var kick := 0.0
var sway := Vector2.ZERO
var hurt_flash := 0.0
var key_move := Vector2.ZERO

# ---------------------------------------------------------------- réglages

func _is_32bit() -> bool:
	return OS.has_feature("32") or OS.has_feature("arm32")

func _load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(CFG_PATH) == OK:
		settings["quality"] = int(c.get_value("game", "quality", -1))
		settings["sens"] = float(c.get_value("game", "sens", 1.0))
		settings["sound"] = bool(c.get_value("game", "sound", true))
		settings["vibe"] = bool(c.get_value("game", "vibe", true))
		settings["fps"] = bool(c.get_value("game", "fps", true))
	if int(settings["quality"]) < 0:
		settings["quality"] = 0 if _is_32bit() else 1

func save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("game", "quality", settings["quality"])
	c.set_value("game", "sens", settings["sens"])
	c.set_value("game", "sound", settings["sound"])
	c.set_value("game", "vibe", settings["vibe"])
	c.set_value("game", "fps", settings["fps"])
	c.save(CFG_PATH)

func cycle_quality() -> void:
	settings["quality"] = (int(settings["quality"]) + 1) % 3
	apply_quality()
	save_settings()

func cycle_sens() -> void:
	var presets := [0.6, 0.8, 1.0, 1.3, 1.7]
	var cur: float = float(settings["sens"])
	var idx := 0
	for i in range(presets.size()):
		if absf(float(presets[i]) - cur) < 0.05:
			idx = i
	settings["sens"] = float(presets[(idx + 1) % presets.size()])
	save_settings()

func toggle_sound() -> void:
	settings["sound"] = not bool(settings["sound"])
	fx.set_sound(bool(settings["sound"]))
	if bool(settings["sound"]) and playing():
		fx.start_ambient()
	save_settings()

func toggle_vibe() -> void:
	settings["vibe"] = not bool(settings["vibe"])
	save_settings()

func toggle_view() -> void:
	settings["fps"] = not bool(settings["fps"])
	apply_view()
	save_settings()

func playing() -> bool:
	return hud != null and hud.menu == 0

# ---------------------------------------------------------------- matériaux / textures

func _noise_tex(freq: float, octaves: int) -> ImageTexture:
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = freq
	fn.fractal_octaves = octaves
	var img: Image = fn.get_seamless_image(128, 128)
	img.convert(Image.FORMAT_RGB8)
	img.adjust_bcs(1.7, 1.0, 1.0)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _facade_tex() -> ImageTexture:
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	img.fill(Color(0.88, 0.86, 0.82))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for cy in range(4):
		for cx in range(4):
			var x0: int = cx * 64 + 14
			var y0: int = cy * 64 + 10
			var shade: float = rng.randf_range(0.08, 0.2)
			var col := Color(shade * 0.9, shade, shade * 1.15)
			var r: float = rng.randf()
			if r < 0.10:
				col = Color(0.85, 0.6, 0.28)
			elif r < 0.22:
				col = Color(0.02, 0.02, 0.02)
			img.fill_rect(Rect2i(x0, y0, 36, 42), col)
			img.fill_rect(Rect2i(x0 - 3, y0 - 3, 42, 3), Color(0.62, 0.6, 0.57))
			img.fill_rect(Rect2i(x0 - 3, y0 + 42, 42, 3), Color(0.5, 0.48, 0.45))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _tex_mat(tex: Texture2D, tint: Color, scale: float, rough: float = 0.9, vcol: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	m.vertex_color_use_as_albedo = vcol
	return m

func _soft_tex() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	return gt

# ---------------------------------------------------------------- collisions maison

func register_box(bb: AABB, solid: bool) -> void:
	ray_boxes.append(bb)
	if not solid:
		return
	var z0: float = bb.position.z - 0.6
	var z1: float = bb.position.z + bb.size.z + 0.6
	var b0 := clampi(int((z0 + 200.0) / 10.0), 0, 40)
	var b1 := clampi(int((z1 + 200.0) / 10.0), 0, 40)
	for b in range(b0, b1 + 1):
		var arr: Array = buckets[b]
		arr.append(bb)

func push_out(p: Vector3, radius: float) -> Vector3:
	var bi := clampi(int((p.z + 200.0) / 10.0), 0, 40)
	var arr: Array = buckets[bi]
	for item in arr:
		var bb: AABB = item
		var x0: float = bb.position.x
		var z0: float = bb.position.z
		var x1: float = x0 + bb.size.x
		var z1: float = z0 + bb.size.z
		var cx: float = clampf(p.x, x0, x1)
		var cz: float = clampf(p.z, z0, z1)
		var dx: float = p.x - cx
		var dz: float = p.z - cz
		var d2: float = dx * dx + dz * dz
		if d2 < radius * radius:
			if d2 > 0.000001:
				var d: float = sqrt(d2)
				p.x += dx / d * (radius - d)
				p.z += dz / d * (radius - d)
			else:
				var pen_l: float = p.x - x0
				var pen_r: float = x1 - p.x
				var pen_t: float = p.z - z0
				var pen_b: float = z1 - p.z
				var m: float = minf(minf(pen_l, pen_r), minf(pen_t, pen_b))
				if m == pen_l:
					p.x = x0 - radius
				elif m == pen_r:
					p.x = x1 + radius
				elif m == pen_t:
					p.z = z0 - radius
				else:
					p.z = z1 + radius
	p.x = clampf(p.x, -9.0, 9.0)
	p.z = clampf(p.z, -185.0, 185.0)
	return p

func ray_box(o: Vector3, d: Vector3, bb: AABB) -> float:
	var tmin := 0.0
	var tmax := 1.0e9
	var mn: Vector3 = bb.position
	var mx: Vector3 = bb.position + bb.size
	for ax in range(3):
		var oo: float = o[ax]
		var dd: float = d[ax]
		var lo: float = mn[ax]
		var hi: float = mx[ax]
		if absf(dd) < 1.0e-8:
			if oo < lo or oo > hi:
				return -1.0
		else:
			var t1: float = (lo - oo) / dd
			var t2: float = (hi - oo) / dd
			if t1 > t2:
				var tmp: float = t1
				t1 = t2
				t2 = tmp
			tmin = maxf(tmin, t1)
			tmax = minf(tmax, t2)
			if tmin > tmax:
				return -1.0
	return tmin

# Distance jusqu'au premier obstacle (décor, sol) le long d'un rayon, sinon max_d.
func ray_world(o: Vector3, d: Vector3, max_d: float) -> float:
	var best: float = max_d
	for bb in ray_boxes:
		var t: float = ray_box(o, d, bb)
		if t >= 0.0 and t < best:
			best = t
	if d.y < -0.0001:
		var tg: float = -o.y / d.y
		if tg >= 0.0 and tg < best:
			best = tg
	return best

func blocked(a: Vector3, b: Vector3) -> bool:
	var d: Vector3 = b - a
	var l: float = d.length()
	if l < 0.1:
		return false
	d /= l
	return ray_world(a, d, l) < l - 0.15

# ---------------------------------------------------------------- construction du monde

func _build_env() -> void:
	env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.30, 0.40, 0.52)
	sm.sky_horizon_color = Color(0.76, 0.67, 0.56)
	sm.sky_curve = 0.18
	sm.ground_horizon_color = Color(0.52, 0.48, 0.42)
	sm.ground_bottom_color = Color(0.20, 0.20, 0.20)
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.66, 0.58)
	env.fog_density = 0.009
	env.fog_sky_affect = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.82
	env.adjustment_contrast = 1.12
	env.glow_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24, 38, 0)
	sun.light_color = Color(1.0, 0.82, 0.62)
	sun.light_energy = 1.55
	sun.shadow_enabled = false
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_bias = 0.06
	add_child(sun)

func _multimesh(mesh: Mesh, count: int, m: Material, colors: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mm

func _unit_box() -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3.ONE
	return b

func _smoke(pos: Vector3, soft: Texture2D) -> void:
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 6.0
	p.position = pos
	p.direction = Vector3.UP
	p.spread = 9.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0.25, 0.2, 0.0)
	p.scale_amount_min = 2.5
	p.scale_amount_max = 5.0
	p.color = Color(0.22, 0.22, 0.22, 0.32)
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = soft
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	smokes.append(p)

func _cover(kind: int, pos: Vector3, rotated: bool, mats: Dictionary, soft: Texture2D, burn: bool) -> void:
	var g := Node3D.new()
	g.position = pos
	add_child(g)
	var conc: Material = mats["conc"]
	var sand: Material = mats["sand"]
	var rust: Material = mats["rust"]
	var dark: Material = mats["dark"]
	var wood: Material = mats["wood"]
	var cont: Material = mats["cont"]
	var size := Vector3(1, 1, 1)
	match kind:
		0: # barrière béton
			Gear.box(g, Vector3(0.9, 0.3, 3.2), Vector3(0, 0.15, 0), conc)
			Gear.box(g, Vector3(0.5, 0.75, 3.2), Vector3(0, 0.65, 0), conc)
			size = Vector3(0.9, 1.0, 3.2)
		1: # sacs de sable
			Gear.box(g, Vector3(2.8, 0.38, 0.9), Vector3(0, 0.19, 0), sand)
			Gear.box(g, Vector3(2.6, 0.38, 0.8), Vector3(0.05, 0.57, 0), sand)
			Gear.box(g, Vector3(2.2, 0.34, 0.7), Vector3(-0.1, 0.93, 0), sand)
			size = Vector3(2.8, 1.1, 0.9)
		2: # voiture calcinée
			Gear.box(g, Vector3(1.9, 0.62, 4.3), Vector3(0, 0.66, 0), rust)
			Gear.box(g, Vector3(1.6, 0.6, 2.2), Vector3(0, 1.27, -0.2), dark)
			Gear.axle(g, 0.36, 2.05, Vector3(0, 0.36, 1.35), dark)
			Gear.axle(g, 0.36, 2.05, Vector3(0, 0.36, -1.35), dark)
			size = Vector3(1.95, 1.55, 4.3)
		3: # caisses
			Gear.box(g, Vector3(1.3, 1.3, 1.3), Vector3(0, 0.65, 0), wood)
			Gear.box(g, Vector3(1.0, 0.9, 1.0), Vector3(0.1, 1.75, 0), wood, Vector3(0, 22, 0))
			size = Vector3(1.3, 2.2, 1.3)
		4: # conteneur
			Gear.box(g, Vector3(2.5, 2.6, 6.0), Vector3(0, 1.3, 0), cont)
			size = Vector3(2.5, 2.6, 6.0)
		5: # mur en ruine
			Gear.box(g, Vector3(0.5, 2.6, 4.2), Vector3(0, 1.3, 0), conc)
			Gear.box(g, Vector3(0.6, 0.6, 1.4), Vector3(0, 2.9, 1.2), conc, Vector3(0, 0, 12))
			size = Vector3(0.5, 2.6, 4.2)
		_: # bidons
			Gear.barrel(g, 0.3, 0.9, Vector3(0, 0.45, 0), rust).rotation_degrees = Vector3(0, 0, 0)
			Gear.barrel(g, 0.3, 0.9, Vector3(0.6, 0.45, 0.2), dark).rotation_degrees = Vector3(0, 0, 0)
			size = Vector3(1.3, 0.95, 1.1)
			if burn:
				var fire := StandardMaterial3D.new()
				fire.albedo_color = Color(1.0, 0.45, 0.1)
				fire.emission_enabled = true
				fire.emission = Color(1.0, 0.45, 0.1)
				fire.emission_energy_multiplier = 2.5
				Gear.box(g, Vector3(0.45, 0.12, 0.45), Vector3(0, 0.95, 0), fire)
	var bb_size := size
	if rotated:
		bb_size = Vector3(size.z, size.y, size.x)
		g.rotation_degrees = Vector3(0, 90, 0)
	var bb := AABB(Vector3(pos.x - bb_size.x * 0.5, 0.0, pos.z - bb_size.z * 0.5), bb_size)
	register_box(bb, true)
	if burn or kind == 2:
		_smoke(pos + Vector3(0, 1.2, 0), soft)

func _build_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261113
	var conc_tex := _noise_tex(0.05, 4)
	var fine_tex := _noise_tex(0.11, 3)
	var facade := _facade_tex()
	var soft := _soft_tex()
	var mats: Dictionary = {
		"conc": _tex_mat(conc_tex, Color(0.62, 0.60, 0.56), 0.25, 0.95),
		"sand": _tex_mat(fine_tex, Color(0.66, 0.55, 0.38), 0.4, 1.0),
		"rust": _tex_mat(fine_tex, Color(0.42, 0.24, 0.16), 0.3, 0.8),
		"dark": _tex_mat(fine_tex, Color(0.16, 0.16, 0.17), 0.3, 0.7),
		"wood": _tex_mat(fine_tex, Color(0.52, 0.40, 0.26), 0.5, 0.95),
		"cont": _tex_mat(fine_tex, Color(0.24, 0.32, 0.28), 0.2, 0.7)
	}
	var m_ground := _tex_mat(conc_tex, Color(0.46, 0.44, 0.40), 0.12, 1.0)
	var m_road := _tex_mat(fine_tex, Color(0.26, 0.26, 0.27), 0.2, 0.95)
	var m_side := _tex_mat(conc_tex, Color(0.60, 0.58, 0.54), 0.3, 0.95)
	var m_line := Gear.mat(Color(0.62, 0.52, 0.14), 1.0)
	var m_edge := Gear.mat(Color(0.55, 0.55, 0.52), 1.0)
	# sol, route, trottoirs
	var gp := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	gp.mesh = pm
	gp.material_override = m_ground
	add_child(gp)
	Gear.box(self, Vector3(22, 0.06, 440), Vector3(0, 0.03, 0), m_road)
	Gear.box(self, Vector3(3.0, 0.18, 440), Vector3(12.5, 0.09, 0), m_side)
	Gear.box(self, Vector3(3.0, 0.18, 440), Vector3(-12.5, 0.09, 0), m_side)
	Gear.box(self, Vector3(0.12, 0.02, 440), Vector3(10.4, 0.07, 0), m_edge)
	Gear.box(self, Vector3(0.12, 0.02, 440), Vector3(-10.4, 0.07, 0), m_edge)
	var dash := _multimesh(_box_mesh(Vector3(0.18, 0.02, 3.2)), 51, m_line, false)
	for i in range(51):
		dash.set_instance_transform(i, Transform3D(Basis(), Vector3(0, 0.07, -200.0 + i * 8.0)))
	# immeubles (un seul draw call)
	var m_build := _tex_mat(facade, Color(1, 1, 1), 1.0 / 16.0, 0.9, true)
	var bm := _multimesh(_unit_box(), 136, m_build, true)
	var bi := 0
	for side in [-1, 1]:
		for col in range(4):
			for row in range(-8, 9):
				var h: float = rng.randf_range(25.0, 120.0)
				var x: float = float(side) * (28.0 + col * 38.0)
				var z: float = row * 45.0
				var tone: float = rng.randf_range(0.55, 0.95)
				var c := Color(tone, tone * 0.97, tone * 0.92)
				bm.set_instance_transform(bi, Transform3D(Basis().scaled(Vector3(30, h, 30)), Vector3(x, h * 0.5, z)))
				bm.set_instance_color(bi, c)
				bi += 1
				if col == 0:
					ray_boxes.append(AABB(Vector3(x - 15.0, 0.0, z - 15.0), Vector3(30.0, h, 30.0)))
	# lampadaires
	var m_pole := Gear.mat(Color(0.07, 0.07, 0.07), 0.6, 0.5)
	var m_bulb := StandardMaterial3D.new()
	m_bulb.albedo_color = Color(1, 0.92, 0.7)
	m_bulb.emission_enabled = true
	m_bulb.emission = Color(1.0, 0.85, 0.55)
	m_bulb.emission_energy_multiplier = 1.4
	var poles := _multimesh(_box_mesh(Vector3(0.25, 7, 0.25)), 42, m_pole, false)
	var bulbs := _multimesh(_box_mesh(Vector3(0.7, 0.5, 0.7)), 42, m_bulb, false)
	var pi2 := 0
	for z2 in range(-200, 201, 20):
		for s in [-1, 1]:
			poles.set_instance_transform(pi2, Transform3D(Basis(), Vector3(s * 11.2, 3.5, z2)))
			bulbs.set_instance_transform(pi2, Transform3D(Basis(), Vector3(s * 11.2, 7.2, z2)))
			pi2 += 1
	# gravats sur la chaussée
	var m_deb := _tex_mat(conc_tex, Color(0.55, 0.53, 0.5), 0.5, 1.0, true)
	var deb := _multimesh(_unit_box(), 70, m_deb, true)
	for i in range(70):
		var sz := Vector3(rng.randf_range(0.2, 1.0), rng.randf_range(0.1, 0.5), rng.randf_range(0.2, 1.0))
		var eb := Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0.0, TAU), rng.randf_range(-0.4, 0.4)))
		var px: float = rng.randf_range(-9.5, 9.5)
		if rng.randf() < 0.5:
			px = signf(px) * rng.randf_range(7.0, 9.8)
		deb.set_instance_transform(i, Transform3D(eb.scaled(sz), Vector3(px, sz.y * 0.3, rng.randf_range(-195.0, 195.0))))
		var gt: float = rng.randf_range(0.5, 1.0)
		deb.set_instance_color(i, Color(gt, gt, gt))
	# couvertures
	for i in range(47):
		var z3: float = -186.0 + i * 8.0 + rng.randf_range(-2.0, 2.0)
		if absf(z3) < 9.0:
			continue
		var kind: int = rng.randi_range(0, 6)
		var x3: float = rng.randf_range(-7.0, 7.0)
		var rotated: bool = rng.randf() < 0.35
		if kind == 4:
			x3 = signf(x3 + 0.01) * 7.5
			rotated = false
		_cover(kind, Vector3(x3, 0.0, z3), rotated, mats, soft, kind == 6 and rng.randf() < 0.5)
	# barrages aux extrémités
	for zz in [-198.0, 198.0]:
		Gear.box(self, Vector3(24, 5, 2.5), Vector3(0, 2.5, zz), mats["conc"])
		register_box(AABB(Vector3(-12.0, 0.0, zz - 1.25), Vector3(24.0, 5.0, 2.5)), true)
	# poussière en suspension autour du joueur
	dust = CPUParticles3D.new()
	dust.amount = 50
	dust.lifetime = 8.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(24, 5, 24)
	dust.direction = Vector3(1, 0.1, 0.2)
	dust.spread = 180.0
	dust.initial_velocity_min = 0.2
	dust.initial_velocity_max = 0.6
	dust.gravity = Vector3.ZERO
	dust.local_coords = false
	var dq := QuadMesh.new()
	dq.size = Vector2(0.05, 0.05)
	dust.mesh = dq
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(1.0, 0.92, 0.78, 0.45)
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dust.material_override = dm
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)

func _box_mesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func _make_flash(parent: Node3D, soft: Texture2D) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.34, 0.34)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = soft
	m.albedo_color = Color(1.0, 0.8, 0.45, 1.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	root.visible = false
	return root

func _make_post() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var sh := Shader.new()
	sh.code = GRADE_CODE
	grade_mat = ShaderMaterial.new()
	grade_mat.shader = sh
	var cr := ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.material = grade_mat
	layer.add_child(cr)
	var gsh := Shader.new()
	gsh.code = GRAIN_CODE
	var gm := ShaderMaterial.new()
	gm.shader = gsh
	grain = ColorRect.new()
	grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grain.material = gm
	layer.add_child(grain)

# ---------------------------------------------------------------- initialisation

func _ready() -> void:
	randomize()
	Engine.max_fps = 60
	for i in range(41):
		var empty: Array = []
		buckets.append(empty)
	_load_settings()
	_build_env()
	_build_world()
	var soft := _soft_tex()
	# joueur
	player = HeroScript.new()
	add_child(player)
	# caméra
	rig = Node3D.new()
	add_child(rig)
	pitch_node = Node3D.new()
	rig.add_child(pitch_node)
	cam = Camera3D.new()
	cam.near = 0.05
	cam.far = 220.0
	cam.fov = 75.0
	pitch_node.add_child(cam)
	# arme en vue FPS
	vm = Node3D.new()
	cam.add_child(vm)
	vm_rifle = Gear.rifle(true)
	vm.add_child(vm_rifle)
	Gear.fp_arms(vm_rifle)
	vm_muzzle = vm_rifle.get_node("Muzzle") as Marker3D
	flash_fp = _make_flash(vm_muzzle, soft)
	light_fp = OmniLight3D.new()
	light_fp.omni_range = 9.0
	light_fp.light_color = Color(1.0, 0.7, 0.3)
	light_fp.light_energy = 0.0
	vm_muzzle.add_child(light_fp)
	flash_tp = _make_flash(player.tp_muzzle, soft)
	light_tp = OmniLight3D.new()
	light_tp.omni_range = 9.0
	light_tp.light_color = Color(1.0, 0.7, 0.3)
	light_tp.light_energy = 0.0
	player.tp_muzzle.add_child(light_tp)
	# effets, gameplay, interface
	fx = FxScript.new()
	fx.anchor = player
	add_child(fx)
	fx.set_sound(bool(settings["sound"]))
	war = WarScript.new()
	war.game = self
	war.player = player
	add_child(war)
	_make_post()
	var hl := CanvasLayer.new()
	hl.layer = 10
	add_child(hl)
	hud = HudScript.new()
	hud.game = self
	hl.add_child(hud)
	hud.reload_pressed.connect(func(): war.start_reload())
	hud.view_pressed.connect(toggle_view)
	hud.start_pressed.connect(func(): fx.start_ambient())
	hud.restart_pressed.connect(restart)
	apply_quality()
	apply_view()
	_update_camera(0.016)

func restart() -> void:
	war.reset()
	player.position = Vector3.ZERO
	yaw = 0.0
	pitch = 0.0
	hud.ads_on = false
	hud.menu = 0
	fx.start_ambient()

func apply_quality() -> void:
	var q: int = int(settings["quality"])
	sun.shadow_enabled = q >= 1
	sun.directional_shadow_max_distance = 55.0 if q == 1 else 85.0
	var far_arr := [140.0, 230.0, 340.0]
	cam.far = float(far_arr[q])
	env.glow_enabled = q >= 2 and not _is_32bit()
	get_viewport().msaa_3d = Viewport.MSAA_2X if q >= 2 else Viewport.MSAA_DISABLED
	grain.visible = q >= 1
	dust.emitting = q >= 1
	dust.amount = 30 if q == 1 else 60
	for s in smokes:
		s.emitting = q >= 1

func apply_view() -> void:
	var fp: bool = bool(settings["fps"])
	vm.visible = fp
	player.set_fp(fp)
	pitch = clampf(pitch, -1.0, 0.55) if not fp else pitch

func muzzle_pos() -> Vector3:
	if bool(settings["fps"]):
		return vm_muzzle.global_position
	return player.tp_muzzle.global_position

func show_flash() -> void:
	flash_t = 0.05
	var fp: bool = bool(settings["fps"])
	flash_fp.visible = fp
	flash_tp.visible = not fp
	flash_fp.rotation.z = randf() * TAU
	if fp:
		light_fp.light_energy = 2.5
	else:
		light_tp.light_energy = 3.0

func on_hurt(amount: float) -> void:
	shake = minf(shake + 0.4 + amount * 0.03, 1.0)
	hurt_flash = 0.6
	fx.play("hurt", -4.0, randf_range(0.9, 1.1))
	if bool(settings["vibe"]):
		Input.vibrate_handheld(40)

func add_recoil(strength: float) -> void:
	var ads: float = lerpf(1.0, 0.55, ads_t)
	pitch += strength * ads
	yaw += randf_range(-0.0045, 0.0045) * ads
	kick = minf(kick + 1.0, 1.4)
	shake = minf(shake + 0.05, 1.0)

# ---------------------------------------------------------------- boucle

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if hud != null:
			if hud.menu == 0:
				hud.menu = 1
				hud.first_menu = false
				hud.release_all()
			elif hud.menu == 1:
				get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		if hud != null and hud.menu == 0:
			hud.menu = 1
			hud.first_menu = false
			hud.release_all()

func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.05)
	if flash_t > 0.0:
		flash_t -= dt
		if flash_t <= 0.0:
			flash_fp.visible = false
			flash_tp.visible = false
			light_fp.light_energy = 0.0
			light_tp.light_energy = 0.0
	hurt_flash = maxf(hurt_flash - dt * 1.6, 0.0)
	grade_mat.set_shader_parameter("damage", clampf((1.0 - war.hp / war.max_hp) * 1.1 + hurt_flash, 0.0, 1.0))
	dust.global_position = player.global_position + Vector3(0, 3.0, 0)
	if not playing():
		_update_camera(dt)
		return
	var fp: bool = bool(settings["fps"])
	# regard
	var ld: Vector2 = hud.look_delta
	hud.look_delta = Vector2.ZERO
	var sens: float = float(settings["sens"]) * 0.0042 * lerpf(1.0, 0.6, ads_t)
	yaw -= ld.x * sens
	pitch -= ld.y * sens
	if Input.is_key_pressed(KEY_LEFT):
		yaw += 1.6 * dt
	if Input.is_key_pressed(KEY_RIGHT):
		yaw -= 1.6 * dt
	pitch = clampf(pitch, -1.35, 1.35) if fp else clampf(pitch, -1.0, 0.55)
	# déplacement
	var kv := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_down", "ui_up"))
	var mv: Vector2 = hud.move_vec + kv
	if mv.length() > 1.0:
		mv = mv.normalized()
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var sprint_wish: bool = mv.length() > 0.92 and mv.y > 0.5 and not hud.ads_on and not hud.fire_held
	sprint_t = move_toward(sprint_t, 1.0 if sprint_wish else 0.0, dt * 6.0)
	var speed: float = lerpf(4.4, 7.0, sprint_t)
	speed = lerpf(speed, 2.3, ads_t)
	if mv.length() > 0.08:
		var d: Vector3 = right * mv.x + fwd * mv.y
		player.position += d * speed * dt * mv.length()
		player.position = push_out(player.position, 0.45)
	moving = move_toward(moving, mv.length() if mv.length() > 0.08 else 0.0, dt * 8.0)
	player.rotation.y = yaw
	player.set_aiming(hud.ads_on or hud.fire_held)
	player.animate(moving, dt)
	if sprint_wish:
		hud.ads_on = false
	ads_t = move_toward(ads_t, 1.0 if hud.ads_on else 0.0, dt * 7.0)
	bob_t += dt * lerpf(7.0, 11.0, sprint_t) * moving
	# viseur et effets de caméra
	kick = maxf(kick - dt * 9.0, 0.0)
	shake = maxf(shake - dt * 2.2, 0.0)
	sway = sway.lerp(Vector2(clampf(-ld.x * 0.0009, -0.05, 0.05), clampf(ld.y * 0.0009, -0.05, 0.05)), 10.0 * dt)
	_update_camera(dt)

func _update_camera(dt: float) -> void:
	var fp: bool = bool(settings["fps"])
	rig.position = player.position + Vector3(0, 1.62, 0)
	rig.rotation.y = yaw
	pitch_node.rotation.x = pitch
	var shake_off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * 0.02
	cam.h_offset = shake_off.x
	cam.v_offset = shake_off.y
	var bob := Vector3(sin(bob_t) * 0.012, absf(cos(bob_t)) * 0.016, 0.0) * moving
	if fp:
		cam.position = bob
		cam.fov = lerpf(76.0, 52.0, ads_t) + sprint_t * 4.0
		_update_viewmodel()
	else:
		var hip := Vector3(0.55, 0.25, 2.5)
		var ads := Vector3(0.38, 0.12, 1.35)
		cam.position = hip.lerp(ads, ads_t) + bob * 0.4
		cam.fov = lerpf(68.0, 52.0, ads_t) + sprint_t * 3.0

func _update_viewmodel() -> void:
	var hip := Vector3(0.18, -0.20, -0.40)
	var ads := Vector3(0.0, -0.074, -0.28)
	var p: Vector3 = hip.lerp(ads, ads_t)
	var spr := Vector3(0.10, -0.27, -0.34)
	p = p.lerp(spr, sprint_t)
	p += Vector3(sway.x, sway.y, 0.0)
	p.x += sin(bob_t * 0.5) * 0.006 * moving * (1.0 - ads_t)
	p.y += absf(cos(bob_t)) * 0.008 * moving * (1.0 - ads_t)
	p.z += kick * 0.03
	var rot := Vector3(kick * 0.045, 0.0, 0.0)
	rot.y = sprint_t * 0.55
	rot.z = -sprint_t * 0.2
	var rp: float = 0.0
	if war.reload_t > 0.0:
		rp = 1.0 - war.reload_t / war.reload_time
		var s: float = sin(PI * rp)
		p.y -= 0.10 * s
		p.x += 0.03 * s
		rot.x -= 0.55 * s
		rot.z += 0.35 * s
	vm.position = p
	vm.rotation = rot

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo:
		var k := (e as InputEventKey).keycode
		if k == KEY_R:
			war.start_reload()
		elif k == KEY_V:
			toggle_view()
		elif k == KEY_ESCAPE and hud != null:
			if hud.menu == 0:
				hud.menu = 1
				hud.first_menu = false
				hud.release_all()
