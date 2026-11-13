extends Control
# NIGHTFALL_COD_LOOK — interface tactile style Call of Duty : radar, munitions, viseur,
# marqueurs de touche, indicateurs de dégâts, kill feed, menus.

signal reload_pressed
signal view_pressed
signal start_pressed
signal restart_pressed

var game = null
var move_vec := Vector2.ZERO
var look_delta := Vector2.ZERO
var fire_held := false
var ads_on := false
var menu := 1
var first_menu := true

var intro_active := false
var intro_pages: Array[String] = []
var intro_index := 0

func start_intro() -> void:
	intro_pages = Story.intro_pages()
	intro_index = 0
	intro_active = true
	game.narrative_active = true
	release_all()
	queue_redraw()

func advance_intro() -> void:
	if not intro_active:
		return
	intro_index += 1
	if intro_index >= intro_pages.size():
		intro_active = false
		game.narrative_active = false
		release_all()
	queue_redraw()

func _draw_intro(s: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.005, 0.008, 0.012, 0.94))
	var h := s.y
	var title := Story.intro_title()
	_ctext("2031  //  ABIDJAN — CÔTE D'IVOIRE", Vector2(s.x * 0.5, h * 0.17), int(h * 0.027), Color(0.85, 0.68, 0.42, 0.9))
	_ctext(title, Vector2(s.x * 0.5, h * 0.29), int(h * 0.045), Color(0.88, 0.16, 0.12, 1.0))
	draw_line(Vector2(s.x * 0.18, h * 0.36), Vector2(s.x * 0.82, h * 0.36), Color(0.75, 0.15, 0.12, 0.75), 2.0)
	var page := intro_pages[intro_index] if intro_index < intro_pages.size() else ""
	var font := ThemeDB.fallback_font
	var fs := int(clampf(h * 0.035, 17.0, 30.0))
	draw_multiline_string(font, Vector2(s.x * 0.12, h * 0.49), page, HORIZONTAL_ALIGNMENT_CENTER, s.x * 0.76, fs, 8, Color(0.94, 0.94, 0.92, 1.0))
	_ctext("%02d / %02d" % [intro_index + 1, intro_pages.size()], Vector2(s.x * 0.5, h * 0.84), int(h * 0.024), Color(0.8, 0.8, 0.8, 0.7))
	_ctext("TOUCHER POUR CONTINUER", Vector2(s.x * 0.5, h * 0.91), int(h * 0.027), Color(1.0, 0.72, 0.28, 0.95))


var move_idx := -1
var look_idx := -1
var fire_idx := -1
var move_origin := Vector2.ZERO
var move_cur := Vector2.ZERO
var menu_rects: Array[Rect2] = []
var menu_ids: Array[String] = []

const QUAL := ["BASSE", "MOYENNE", "HAUTE"]
const Story = preload("res://story.gd")

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func release_all() -> void:
	move_idx = -1
	look_idx = -1
	fire_idx = -1
	move_vec = Vector2.ZERO
	fire_held = false
	look_delta = Vector2.ZERO

func _vs() -> Vector2:
	return get_viewport_rect().size

func _fire_c() -> Vector2:
	var s := _vs()
	return Vector2(s.x - s.y * 0.20, s.y * 0.70)

func _ads_c() -> Vector2:
	var s := _vs()
	return Vector2(s.x - s.y * 0.43, s.y * 0.82)

func _rel_c() -> Vector2:
	var s := _vs()
	return Vector2(s.x - s.y * 0.09, s.y * 0.44)

func _view_c() -> Vector2:
	var s := _vs()
	return Vector2(s.x - s.y * 0.19, s.y * 0.075)

func _pause_c() -> Vector2:
	var s := _vs()
	return Vector2(s.x - s.y * 0.07, s.y * 0.075)

func _process(_delta: float) -> void:
	queue_redraw()

# ---------------------------------------------------------------- entrées tactiles

func _input(e: InputEvent) -> void:
	if intro_active:
		if e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed:
			advance_intro()
			get_viewport().set_input_as_handled()
		elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			advance_intro()
			get_viewport().set_input_as_handled()
		elif e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo:
			if (e as InputEventKey).keycode in [KEY_ENTER, KEY_SPACE]:
				advance_intro()
				get_viewport().set_input_as_handled()
		return
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			_press(t.index, t.position)
		else:
			_release(t.index)
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		_drag(d.index, d.position, d.relative)

func _press(idx: int, p: Vector2) -> void:
	var s := _vs()
	if menu != 0:
		_menu_press(p)
		return
	if p.distance_to(_pause_c()) < s.y * 0.07:
		menu = 1
		first_menu = false
		release_all()
		return
	if p.distance_to(_view_c()) < s.y * 0.07:
		view_pressed.emit()
		return
	if p.distance_to(_rel_c()) < s.y * 0.09:
		reload_pressed.emit()
		return
	if p.distance_to(_ads_c()) < s.y * 0.11:
		ads_on = not ads_on
		return
	if p.distance_to(_fire_c()) < s.y * 0.16 and fire_idx == -1:
		fire_idx = idx
		fire_held = true
		return
	if p.x < s.x * 0.42 and move_idx == -1:
		move_idx = idx
		move_origin = p
		move_cur = p
		return
	if look_idx == -1:
		look_idx = idx

func _release(idx: int) -> void:
	if idx == move_idx:
		move_idx = -1
		move_vec = Vector2.ZERO
	if idx == look_idx:
		look_idx = -1
	if idx == fire_idx:
		fire_idx = -1
		fire_held = false

func _drag(idx: int, p: Vector2, rel: Vector2) -> void:
	if menu != 0:
		return
	if idx == move_idx:
		move_cur = p
		var v: Vector2 = ((p - move_origin) / (_vs().y * 0.12)).limit_length(1.0)
		if v.length() < 0.12:
			move_vec = Vector2.ZERO
		else:
			move_vec = Vector2(v.x, -v.y)
	elif idx == look_idx or idx == fire_idx:
		look_delta += rel

func _menu_press(p: Vector2) -> void:
	for i in range(menu_rects.size()):
		if menu_rects[i].has_point(p):
			_menu_action(menu_ids[i])
			return

func _menu_action(id: String) -> void:
	match id:
		"play":
			menu = 0
			release_all()
			if first_menu:
				first_menu = false
				start_pressed.emit()
		"view":
			game.toggle_view()
		"quality":
			game.cycle_quality()
		"sens":
			game.cycle_sens()
		"sound":
			game.toggle_sound()
		"vibe":
			game.toggle_vibe()
		"restart", "retry":
			restart_pressed.emit()
		"quit":
			get_tree().quit()

# ---------------------------------------------------------------- dessin

func _txt(s: String, pos: Vector2, size_px: int, col: Color, align: int = 0, width: float = -1.0) -> void:
	var f := ThemeDB.fallback_font
	draw_string(f, pos + Vector2(2, 2), s, align, width, size_px, Color(0, 0, 0, col.a * 0.75))
	draw_string(f, pos, s, align, width, size_px, col)

func _ctext(s: String, c: Vector2, size_px: int, col: Color) -> void:
	_txt(s, Vector2(c.x - 300.0, c.y + size_px * 0.35), size_px, col, 1, 600.0)

func _draw() -> void:
	if game == null or game.war == null:
		return
	var s := _vs()
	if menu == 0:
		_draw_game(s)
		if intro_active:
			_draw_intro(s)
	else:
		_draw_menu(s)

func _draw_game(s: Vector2) -> void:
	var w = game.war
	var h: float = s.y
	var ctr := s * 0.5
	var fps_view: bool = bool(game.settings["fps"])
	# indicateurs de dégâts
	var yaw: float = game.yaw
	for m in w.dmg_marks:
		var a: float = float(m["t"])
		var ang: float = -PI * 0.5 + (yaw - float(m["ang"]))
		draw_arc(ctr, h * 0.2, ang - 0.28, ang + 0.28, 12, Color(0.9, 0.05, 0.03, clampf(a, 0.0, 1.0) * 0.85), h * 0.012)
	# viseur
	var spr: float = w.spread
	var gap: float = 5.0 + spr * h * 0.8
	var ccol := Color(1, 1, 1, 0.85)
	if not (fps_view and ads_on):
		draw_line(ctr + Vector2(gap, 0), ctr + Vector2(gap + 10, 0), ccol, 2.0)
		draw_line(ctr - Vector2(gap, 0), ctr - Vector2(gap + 10, 0), ccol, 2.0)
		draw_line(ctr + Vector2(0, gap), ctr + Vector2(0, gap + 10), ccol, 2.0)
		draw_line(ctr - Vector2(0, gap + 10), ctr - Vector2(0, gap), ccol, 2.0)
	# marqueur de touche
	if w.hit_t > 0.0:
		var hc := Color(1, 1, 1, clampf(w.hit_t / 0.15, 0.0, 1.0))
		if w.hit_kill:
			hc = Color(1.0, 0.15, 0.1, clampf(w.hit_t / 0.25, 0.0, 1.0))
		for dv in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var dvec: Vector2 = dv
			draw_line(ctr + dvec * 9.0, ctr + dvec * 20.0, hc, 3.0)
	# rechargement
	if w.reload_t > 0.0:
		var prog: float = 1.0 - w.reload_t / w.reload_time
		draw_arc(ctr, 40.0, -PI * 0.5, -PI * 0.5 + TAU * prog, 32, Color(1, 1, 1, 0.8), 4.0)
		_ctext("RECHARGEMENT", ctr + Vector2(0, 62), int(h * 0.032), Color(1, 1, 1, 0.9))
	elif w.ammo <= 0 and w.reserve <= 0:
		_ctext("PLUS DE MUNITIONS", ctr + Vector2(0, 62), int(h * 0.032), Color(1, 0.3, 0.2, 0.95))
	elif w.ammo <= 8:
		_ctext("MUNITIONS FAIBLES", ctr + Vector2(0, 62), int(h * 0.03), Color(1, 0.7, 0.2, 0.9))
	_draw_minimap(s, w)
	# santé
	var r: float = h * 0.12
	var bw: float = r * 2.0
	var bx: float = h * 0.03
	var by: float = h * 0.03 + r * 2.0 + h * 0.02
	var frac: float = clampf(w.hp / w.max_hp, 0.0, 1.0)
	draw_rect(Rect2(bx, by, bw, h * 0.012), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(bx, by, bw * frac, h * 0.012), Color(1.0, 0.25 + 0.7 * frac, 0.2 + 0.7 * frac, 0.95))
	# haut de l'écran
	_txt("HOSTILES  %d" % w.enemies.size(), Vector2(ctr.x - 200.0, h * 0.065), int(h * 0.04), Color(1, 1, 1, 0.92), 1, 400.0)
	_txt("SCORE  %d" % w.score, Vector2(ctr.x - 200.0, h * 0.105), int(h * 0.03), Color(1.0, 0.72, 0.2, 0.95), 1, 400.0)
	# munitions
	var rx: float = s.x - h * 0.03
	_txt("%d" % w.ammo, Vector2(rx - 300.0, h * 0.31), int(h * 0.09), Color(1, 1, 1, 0.95), 2, 300.0)
	_txt("/ %d" % w.reserve, Vector2(rx - 300.0, h * 0.345), int(h * 0.035), Color(1, 1, 1, 0.7), 2, 300.0)
	_txt("NF-16 CARABINE", Vector2(rx - 300.0, h * 0.385), int(h * 0.028), Color(1.0, 0.72, 0.2, 0.85), 2, 300.0)
	# kill feed
	var fy: float = h * 0.62
	for item in w.feed:
		var ci: Color = item["col"]
		ci.a = clampf(float(item["t"]), 0.0, 1.0)
		_ctext(str(item["text"]), Vector2(ctr.x, fy), int(h * 0.034), ci)
		fy += h * 0.045
	# annonce de vague
	if w.banner_t > 0.0:
		var ba: float = clampf(w.banner_t, 0.0, 1.0)
		_ctext(w.banner, Vector2(ctr.x, h * 0.22), int(h * 0.085), Color(1, 1, 1, ba))
		_ctext("ÉLIMINEZ TOUS LES HOSTILES", Vector2(ctr.x, h * 0.29), int(h * 0.03), Color(1.0, 0.72, 0.2, ba))
	# boutons
	_draw_buttons(s, w)
	_txt("%d FPS" % Engine.get_frames_per_second(), Vector2(s.x - h * 0.2, h * 0.17), int(h * 0.022), Color(1, 1, 1, 0.45), 2, h * 0.17)

func _draw_minimap(s: Vector2, w) -> void:
	var h: float = s.y
	var r: float = h * 0.12
	var c := Vector2(h * 0.03 + r, h * 0.03 + r)
	draw_circle(c, r, Color(0.02, 0.04, 0.04, 0.5))
	draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.5), 2.0)
	draw_arc(c, r * 0.5, 0.0, TAU, 28, Color(1, 1, 1, 0.15), 1.0)
	var p: Vector3 = game.player.position
	var yaw: float = game.yaw
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var rgt := Vector2(cos(yaw), -sin(yaw))
	for e in w.enemies:
		var d := Vector2(e.position.x - p.x, e.position.z - p.z)
		var off := Vector2(d.dot(rgt), -d.dot(fwd)) * (r / 45.0)
		if off.length() < r - 4.0:
			draw_circle(c + off, r * 0.05, Color(1.0, 0.15, 0.1, 0.95))
	var tri := PackedVector2Array([c + Vector2(0, -9), c + Vector2(6, 7), c + Vector2(-6, 7)])
	draw_colored_polygon(tri, Color(1, 1, 1, 0.95))

func _draw_buttons(s: Vector2, w) -> void:
	var h: float = s.y
	var fc := _fire_c()
	var fr: float = h * 0.13
	draw_circle(fc, fr, Color(1, 1, 1, 0.38 if fire_held else 0.14))
	draw_arc(fc, fr, 0.0, TAU, 40, Color(1, 1, 1, 0.6), 3.0)
	for i in range(3):
		var bx: float = fc.x - fr * 0.3 + i * fr * 0.3
		draw_rect(Rect2(bx - 4.0, fc.y - fr * 0.3, 8.0, fr * 0.6), Color(1, 1, 1, 0.7))
	var ac := _ads_c()
	var ar: float = h * 0.085
	draw_circle(ac, ar, Color(1, 1, 1, 0.34 if ads_on else 0.14))
	draw_arc(ac, ar, 0.0, TAU, 32, Color(1, 1, 1, 0.6), 3.0)
	draw_arc(ac, ar * 0.45, 0.0, TAU, 20, Color(1, 1, 1, 0.8), 2.0)
	draw_line(ac + Vector2(-ar * 0.75, 0), ac + Vector2(-ar * 0.3, 0), Color(1, 1, 1, 0.8), 2.0)
	draw_line(ac + Vector2(ar * 0.75, 0), ac + Vector2(ar * 0.3, 0), Color(1, 1, 1, 0.8), 2.0)
	var rc := _rel_c()
	var rr: float = h * 0.065
	draw_circle(rc, rr, Color(1, 1, 1, 0.14))
	draw_arc(rc, rr, 0.0, TAU, 28, Color(1, 1, 1, 0.6), 3.0)
	draw_arc(rc, rr * 0.5, 0.4, 5.4, 18, Color(1, 1, 1, 0.85), 3.0)
	var vc := _view_c()
	var pc := _pause_c()
	var br: float = h * 0.05
	draw_circle(vc, br, Color(0, 0, 0, 0.4))
	draw_arc(vc, br, 0.0, TAU, 24, Color(1, 1, 1, 0.5), 2.0)
	_ctext("FPS" if bool(game.settings["fps"]) else "TPS", vc, int(h * 0.026), Color(1, 1, 1, 0.9))
	draw_circle(pc, br, Color(0, 0, 0, 0.4))
	draw_arc(pc, br, 0.0, TAU, 24, Color(1, 1, 1, 0.5), 2.0)
	draw_rect(Rect2(pc.x - br * 0.35, pc.y - br * 0.35, br * 0.22, br * 0.7), Color(1, 1, 1, 0.85))
	draw_rect(Rect2(pc.x + br * 0.13, pc.y - br * 0.35, br * 0.22, br * 0.7), Color(1, 1, 1, 0.85))
	# joystick
	var sr: float = h * 0.12
	if move_idx != -1:
		draw_arc(move_origin, sr, 0.0, TAU, 32, Color(1, 1, 1, 0.4), 3.0)
		var off: Vector2 = (move_cur - move_origin).limit_length(sr)
		draw_circle(move_origin + off, sr * 0.38, Color(1, 1, 1, 0.35))
	else:
		var hc := Vector2(h * 0.30, h * 0.74)
		draw_arc(hc, sr, 0.0, TAU, 32, Color(1, 1, 1, 0.16), 2.0)

func _draw_menu(s: Vector2) -> void:
	var h: float = s.y
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.02, 0.03, 0.84))
	menu_rects.clear()
	menu_ids.clear()
	var ids: Array[String] = []
	var labels: Array[String] = []
	var st: Dictionary = game.settings
	if menu == 2:
		_ctext("MISSION ÉCHOUÉE", Vector2(s.x * 0.5, h * 0.2), int(h * 0.1), Color(0.85, 0.12, 0.08, 1))
		var w = game.war
		_ctext("Vague %d   -   Éliminations %d   -   Score %d" % [w.wave, w.kills, w.score], Vector2(s.x * 0.5, h * 0.33), int(h * 0.04), Color(1, 1, 1, 0.9))
		ids = ["retry", "quit"]
		labels = ["REJOUER", "QUITTER"]
	else:
		_ctext("NIGHTFALL", Vector2(s.x * 0.5, h * 0.11), int(h * 0.12), Color(0.85, 0.15, 0.08, 1))
		_ctext("OPÉRATION SURVIE", Vector2(s.x * 0.5, h * 0.19), int(h * 0.03), Color(1.0, 0.72, 0.2, 0.9))
		ids = ["play", "view", "quality", "sens", "sound", "vibe"]
		labels = [
			"JOUER" if first_menu else "REPRENDRE",
			"VUE : " + ("PREMIÈRE PERSONNE" if bool(st["fps"]) else "TROISIÈME PERSONNE"),
			"QUALITÉ : " + str(QUAL[int(st["quality"])]),
			"SENSIBILITÉ : %.1f" % float(st["sens"]),
			"SON : " + ("OUI" if bool(st["sound"]) else "NON"),
			"VIBRATIONS : " + ("OUI" if bool(st["vibe"]) else "NON")]
		if not first_menu:
			ids.append("restart")
			labels.append("RECOMMENCER")
		ids.append("quit")
		labels.append("QUITTER")
	var bw: float = h * 0.8
	var bh: float = h * 0.07
	var gap: float = h * 0.012
	var y: float = h * 0.25 if menu == 1 else h * 0.45
	for i in range(ids.size()):
		var rc := Rect2(s.x * 0.5 - bw * 0.5, y, bw, bh)
		draw_rect(rc, Color(0.12, 0.12, 0.13, 0.92))
		draw_rect(rc, Color(0.85, 0.15, 0.08, 0.9), false, 2.0)
		_ctext(labels[i], rc.position + rc.size * 0.5, int(h * 0.034), Color(1, 1, 1, 0.95))
		menu_rects.append(rc)
		menu_ids.append(ids[i])
		y += bh + gap
