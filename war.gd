extends Node3D
# NIGHTFALL_COD_LOOK — combat : tir hitscan, recul, vagues d'ennemis, santé régénérante, kill feed.

const SoldierScript = preload("res://soldier.gd")
const Gear = preload("res://gear.gd")
const FIRE_RATE := 0.085

var game = null
var player = null

var max_hp := 100.0
var hp := 100.0
var mag := 30
var ammo := 30
var reserve := 240
var score := 0
var kills := 0
var wave := 0
var enemies: Array = []
var cd := 0.0
var reload_t := 0.0
var reload_time := 2.0
var wave_t := 2.0
var dead := false
var dead_t := 0.0
var regen_delay := 0.0
var bloom := 0.0
var spread := 0.02
var hit_t := 0.0
var hit_kill := false
var banner := ""
var banner_t := 0.0
var feed: Array = []
var dmg_marks: Array = []
var last_kill_time := -10.0
var combo := 0
var clock := 0.0
var kit: Dictionary = {}

func _ready() -> void:
	kit = {
		"uniform": Gear.mat(Color(0.22, 0.24, 0.19), 0.9),
		"vest": Gear.mat(Color(0.11, 0.12, 0.11), 0.8),
		"skin": Gear.mat(Color(0.55, 0.42, 0.33), 0.7),
		"helmet": Gear.mat(Color(0.09, 0.11, 0.09), 0.6, 0.1),
		"boots": Gear.mat(Color(0.05, 0.05, 0.05), 0.7),
		"cloth": Gear.mat(Color(0.08, 0.08, 0.09), 1.0),
		"glass": Gear.mat(Color(0.05, 0.1, 0.12), 0.1, 0.6)
	}

func reset() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	hp = max_hp
	ammo = mag
	reserve = 240
	score = 0
	kills = 0
	wave = 0
	wave_t = 2.0
	cd = 0.0
	reload_t = 0.0
	dead = false
	dead_t = 0.0
	regen_delay = 0.0
	bloom = 0.0
	hit_t = 0.0
	banner_t = 0.0
	feed.clear()
	dmg_marks.clear()
	combo = 0

func start_reload() -> void:
	if dead or reload_t > 0.0 or ammo >= mag or reserve <= 0:
		return
	if game == null or not game.playing():
		return
	reload_t = reload_time
	game.fx.play("reload", -2.0)

func feed_add(text: String, col: Color) -> void:
	feed.append({"text": text, "t": 3.5, "col": col})
	if feed.size() > 4:
		feed.pop_front()

# ---------------------------------------------------------------- maths de tir

func _ray_sphere(o: Vector3, d: Vector3, c: Vector3, r: float) -> float:
	var oc: Vector3 = o - c
	var b: float = oc.dot(d)
	var cc: float = oc.dot(oc) - r * r
	var disc: float = b * b - cc
	if disc < 0.0:
		return -1.0
	var sq: float = sqrt(disc)
	var t: float = -b - sq
	if t < 0.0:
		t = -b + sq
		if t < 0.0:
			return -1.0
	return t

func _ray_capsule(o: Vector3, d: Vector3, a: Vector3, b: Vector3, r: float) -> float:
	var v: Vector3 = b - a
	var w: Vector3 = o - a
	var uv: float = d.dot(v)
	var vv: float = v.dot(v)
	var uw: float = d.dot(w)
	var vw: float = v.dot(w)
	var den: float = vv - uv * uv
	var s: float = 0.5
	var t: float = 0.0
	if den > 0.00001:
		t = (uv * vw - uw * vv) / den
		s = (vw + t * uv) / vv
	s = clampf(s, 0.0, 1.0)
	t = s * uv - uw
	if t < 0.0:
		return -1.0
	var pr: Vector3 = o + d * t
	var ps: Vector3 = a + v * s
	var dd: float = pr.distance_to(ps)
	if dd > r:
		return -1.0
	return maxf(t - sqrt(maxf(r * r - dd * dd, 0.0)), 0.0)

# ---------------------------------------------------------------- tir du joueur

func _shoot() -> void:
	cd = FIRE_RATE
	ammo -= 1
	bloom = minf(bloom + 0.0035, 0.03)
	var cam: Camera3D = game.cam
	var bs: Basis = cam.global_transform.basis
	var d: Vector3 = (-bs.z + bs.x * randf_range(-spread, spread) + bs.y * randf_range(-spread, spread)).normalized()
	var o: Vector3 = cam.global_position
	var head_pos: Vector3 = game.rig.global_position
	var lead: float = maxf((head_pos - o).dot(d), 0.0)
	o += d * lead
	var max_d := 160.0
	var t_world: float = game.ray_world(o, d, max_d)
	var best = null
	var best_t: float = t_world
	var head_hit := false
	for e in enemies:
		if not e.alive:
			continue
		var base: Vector3 = e.global_position
		var th: float = _ray_sphere(o, d, base + Vector3(0, 1.68, 0), 0.17)
		if th >= 0.0 and th < best_t:
			best = e
			best_t = th
			head_hit = true
		else:
			var tb: float = _ray_capsule(o, d, base + Vector3(0, 0.2, 0), base + Vector3(0, 1.5, 0), 0.32)
			if tb >= 0.0 and tb < best_t:
				best = e
				best_t = tb
				head_hit = false
	var hit_pos: Vector3 = o + d * best_t
	var muzzle: Vector3 = game.muzzle_pos()
	game.show_flash()
	game.add_recoil(0.0105)
	game.fx.play("shot", -2.0, randf_range(0.95, 1.05))
	game.fx.tracer(muzzle, hit_pos)
	game.fx.shell(muzzle - d * 0.3 + Vector3(0, 0.03, 0), bs.x)
	if best != null:
		var dmg := 34.0
		if head_hit:
			dmg = 120.0
		best.hp -= dmg
		game.fx.burst("blood", hit_pos, -d)
		hit_t = 0.2
		hit_kill = false
		game.fx.play("hit", -6.0, 1.0)
		if best.hp <= 0.0:
			_kill(best, head_hit)
	elif t_world < max_d - 0.5:
		var n: Vector3 = (-d + Vector3.UP * 0.6).normalized()
		if d.y < -0.6:
			game.fx.burst("dust", hit_pos, Vector3.UP)
		else:
			game.fx.burst("spark", hit_pos, n)
			game.fx.burst("dust", hit_pos, n)

func _kill(e, head: bool) -> void:
	e.die()
	enemies.erase(e)
	kills += 1
	hit_kill = true
	hit_t = 0.4
	game.fx.play("kill", -3.0)
	var pts := 100
	var label := "ÉLIMINATION  +100"
	if head:
		pts = 150
		label = "TIR À LA TÊTE  +150"
	if clock - last_kill_time < 3.5:
		combo += 1
	else:
		combo = 0
	last_kill_time = clock
	score += pts
	feed_add(label, Color(1, 1, 1, 1))
	if combo >= 1:
		var bonus: int = 50 * combo
		score += bonus
		var names := ["", "DOUBLE ÉLIMINATION", "TRIPLE ÉLIMINATION", "QUADRUPLE ÉLIMINATION"]
		var nm: String = "SÉRIE x%d" % (combo + 1)
		if combo < names.size():
			nm = str(names[combo])
		feed_add("%s  +%d" % [nm, bonus], Color(1.0, 0.72, 0.2, 1))
	if randf() < 0.3:
		reserve = mini(reserve + 30, 300)
		feed_add("MUNITIONS  +30", Color(0.7, 0.9, 0.6, 1))
	get_tree().create_timer(6.0).timeout.connect(e.queue_free)

# ---------------------------------------------------------------- dégâts subis

func _hurt(n: float, from_pos: Vector3) -> void:
	if dead:
		return
	hp -= n
	regen_delay = 5.0
	game.on_hurt(n)
	var v: Vector3 = from_pos - player.position
	dmg_marks.append({"ang": atan2(-v.x, -v.z), "t": 1.3})
	if dmg_marks.size() > 8:
		dmg_marks.pop_front()
	if hp <= 0.0:
		hp = 0.0
		dead = true
		dead_t = 1.1
		game.hud.ads_on = false

func _enemy_fire(e, dist: float) -> void:
	e.fire_flash()
	var from: Vector3 = e.muzzle_pos()
	var chest: Vector3 = player.position + Vector3(0, 1.2, 0)
	game.fx.play3d("enemy", from, -3.0 - dist * 0.04, randf_range(0.85, 1.05))
	var chance: float = clampf(0.55 - dist * 0.011, 0.08, 0.5)
	chance *= lerpf(1.0, 0.8, game.ads_t)
	if randf() < chance:
		game.fx.tracer(from, chest)
		_hurt(minf(7.0 + wave * 0.3, 12.0), e.position)
	else:
		var miss: Vector3 = chest + Vector3(randf_range(-1.6, 1.6), randf_range(-1.0, 1.2), randf_range(-1.6, 1.6))
		var dir: Vector3 = (miss - from).normalized()
		var tt: float = game.ray_world(from, dir, dist + 25.0)
		game.fx.tracer(from, from + dir * tt)
		if tt < dist + 24.0:
			game.fx.burst("dust", from + dir * tt, Vector3.UP)

# ---------------------------------------------------------------- vagues et IA

func _spawn_wave() -> void:
	wave += 1
	wave_t = 3.0
	reserve = mini(reserve + 60, 300)
	banner = "VAGUE %d" % wave
	banner_t = 3.2
	var count: int = mini(4 + wave * 2, 14)
	var models := 0
	var hq: bool = int(game.settings["quality"]) >= 1
	for i in range(count):
		var e := SoldierScript.new()
		var sgn: float = 1.0 if randf() < 0.5 else -1.0
		var pz: float = clampf(player.position.z + sgn * randf_range(45.0, 75.0), -180.0, 180.0)
		e.position = game.push_out(Vector3(randf_range(-7.0, 7.0), 0.0, pz), 0.5)
		e.hp = minf(100.0 + wave * 6.0, 160.0)
		e.pref = randf_range(14.0, 32.0)
		e.cd = randf_range(1.0, 3.0)
		e.strafe_dir = 1.0 if randf() < 0.5 else -1.0
		add_child(e)
		var use_model: bool = hq and models < 8
		if use_model:
			models += 1
		e.build(kit, use_model)
		enemies.append(e)

func _update_enemies(dt: float) -> void:
	var pp: Vector3 = player.position
	for e in enemies:
		if not e.alive:
			continue
		var ep: Vector3 = e.position
		var to_p := Vector3(pp.x - ep.x, 0.0, pp.z - ep.z)
		var dist: float = to_p.length()
		var dir: Vector3 = to_p / maxf(dist, 0.001)
		e.rotation.y = lerp_angle(e.rotation.y, atan2(-dir.x, -dir.z), minf(8.0 * dt, 1.0))
		e.los_t -= dt
		if e.los_t <= 0.0:
			e.los_t = randf_range(0.2, 0.35)
			e.los = not game.blocked(ep + Vector3(0, 1.5, 0), pp + Vector3(0, 1.3, 0))
		var mv := Vector3.ZERO
		if dist > e.pref + 3.0 or not e.los:
			mv += dir
		elif dist < e.pref - 6.0:
			mv -= dir * 0.7
		e.strafe_t -= dt
		if e.strafe_t <= 0.0:
			e.strafe_t = randf_range(1.0, 2.6)
			if randf() < 0.55:
				e.strafe_dir = -e.strafe_dir
		if e.los:
			mv += Vector3(-dir.z, 0.0, dir.x) * e.strafe_dir * 0.55
		var speed01 := 0.0
		if mv.length() > 0.05:
			mv = mv.normalized()
			ep += mv * 3.3 * dt
			speed01 = 1.0
		ep = game.push_out(ep, 0.45)
		for o in enemies:
			if o != e and o.alive:
				var dd := Vector3(ep.x - o.position.x, 0.0, ep.z - o.position.z)
				var l: float = dd.length()
				if l < 1.0 and l > 0.001:
					ep += dd / l * (1.0 - l) * 0.5
		e.position = ep
		e.animate(speed01, dt)
		e.cd -= dt
		if e.cd <= 0.0 and e.los and dist < 60.0:
			if e.burst_left <= 0:
				e.burst_left = randi_range(2, 4)
			_enemy_fire(e, dist)
			e.burst_left -= 1
			if e.burst_left > 0:
				e.cd = 0.13
			else:
				e.cd = randf_range(1.0, 2.3)

func _decay(dt: float) -> void:
	for i in range(feed.size() - 1, -1, -1):
		feed[i]["t"] = float(feed[i]["t"]) - dt
		if float(feed[i]["t"]) <= 0.0:
			feed.remove_at(i)
	for i in range(dmg_marks.size() - 1, -1, -1):
		dmg_marks[i]["t"] = float(dmg_marks[i]["t"]) - dt
		if float(dmg_marks[i]["t"]) <= 0.0:
			dmg_marks.remove_at(i)

func _process(delta: float) -> void:
	if game == null or not game.playing():
		return
	var dt: float = minf(delta, 0.05)
	clock += dt
	hit_t = maxf(hit_t - dt, 0.0)
	banner_t = maxf(banner_t - dt, 0.0)
	_decay(dt)
	if dead:
		dead_t -= dt
		if dead_t <= 0.0:
			game.hud.menu = 2
			game.hud.release_all()
		return
	regen_delay -= dt
	if regen_delay <= 0.0 and hp < max_hp:
		hp = minf(max_hp, hp + 22.0 * dt)
	if reload_t > 0.0:
		reload_t -= dt
		if reload_t <= 0.0:
			var take: int = mini(mag - ammo, reserve)
			ammo += take
			reserve -= take
	cd -= dt
	bloom = maxf(bloom - dt * 0.05, 0.0)
	spread = lerpf(0.020, 0.0035, game.ads_t) + game.moving * 0.014 * (1.0 - game.ads_t) + bloom
	var wants: bool = game.hud.fire_held or Input.is_key_pressed(KEY_SPACE)
	if reload_t <= 0.0:
		if wants and cd <= 0.0:
			if ammo > 0:
				_shoot()
			elif reserve > 0:
				start_reload()
			else:
				cd = 0.4
				game.fx.play("empty", -4.0)
		elif ammo <= 0 and reserve > 0:
			start_reload()
	_update_enemies(dt)
	if enemies.is_empty():
		wave_t -= dt
		if wave_t <= 0.0:
			_spawn_wave()
