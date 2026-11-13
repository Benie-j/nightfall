import sys
p = "main.gd"
s = open(p).read()
if "NIGHTFALL_EXT_TEX" in s:
    print("main.gd déjà patché"); sys.exit(0)
def rep(old, new):
    global s
    if old not in s:
        print("ERREUR patch : introuvable ->", old[:60]); sys.exit(2)
    s = s.replace(old, new, 1)
rep("func _soft_tex()", '''func _ext(base: String, suffix: String) -> Texture2D:
	var path := "res://tex/%s_%s.jpg" % [base, suffix]
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _lift(m: StandardMaterial3D, k: float) -> void:
	var c: Color = m.albedo_color
	m.albedo_color = Color(minf(c.r * k, 1.0), minf(c.g * k, 1.0), minf(c.b * k, 1.0), c.a)

func _soft_tex()''')
rep("\tvar conc_tex := _tex_from(cimg)\n", "\tvar conc_tex: Texture2D = _tex_from(cimg)\n")
rep("\tvar conc_n := _normal_from(cimg, 5.0)\n", "\tvar conc_n: Texture2D = _normal_from(cimg, 5.0)\n")
rep("\tvar fine_tex := _tex_from(fimg)\n", "\tvar fine_tex: Texture2D = _tex_from(fimg)\n")
rep("\tvar fine_n := _normal_from(fimg, 4.0)\n", "\tvar fine_n: Texture2D = _normal_from(fimg, 4.0)\n")
rep("\tvar facade_n := _normal_from(fac_img, 3.0)\n\tvar soft := _soft_tex()\n", '''\tvar facade_n := _normal_from(fac_img, 3.0)
\tvar soft := _soft_tex()
\t# NIGHTFALL_EXT_TEX : textures photo (res://tex/) si elles existent
\tvar road_tex: Texture2D = fine_tex
\tvar road_n: Texture2D = fine_n
\tvar rust_tex: Texture2D = fine_tex
\tvar rust_n: Texture2D = fine_n
\tvar wood_tex: Texture2D = fine_tex
\tvar wood_n: Texture2D = fine_n
\tvar sand_tex: Texture2D = fine_tex
\tvar sand_n: Texture2D = fine_n
\tvar x_conc: Texture2D = _ext("conc", "diff")
\tvar x_road: Texture2D = _ext("road", "diff")
\tvar x_rust: Texture2D = _ext("rust", "diff")
\tvar x_wood: Texture2D = _ext("wood", "diff")
\tvar x_sand: Texture2D = _ext("sand", "diff")
\tif x_conc != null:
\t\tconc_tex = x_conc
\t\tif _ext("conc", "nor") != null:
\t\t\tconc_n = _ext("conc", "nor")
\tif x_road != null:
\t\troad_tex = x_road
\t\tif _ext("road", "nor") != null:
\t\t\troad_n = _ext("road", "nor")
\tif x_rust != null:
\t\trust_tex = x_rust
\t\tif _ext("rust", "nor") != null:
\t\t\trust_n = _ext("rust", "nor")
\tif x_wood != null:
\t\twood_tex = x_wood
\t\tif _ext("wood", "nor") != null:
\t\t\twood_n = _ext("wood", "nor")
\tif x_sand != null:
\t\tsand_tex = x_sand
\t\tif _ext("sand", "nor") != null:
\t\t\tsand_n = _ext("sand", "nor")
''')
rep('"sand": _tex_mat(fine_tex, Color(0.66, 0.55, 0.38), 0.4, 1.0, false, fine_n)', '"sand": _tex_mat(sand_tex, Color(0.66, 0.55, 0.38), 0.4, 1.0, false, sand_n)')
rep('"rust": _tex_mat(fine_tex, Color(0.42, 0.24, 0.16), 0.3, 0.8, false, fine_n)', '"rust": _tex_mat(rust_tex, Color(0.42, 0.24, 0.16), 0.3, 0.8, false, rust_n)')
rep('"wood": _tex_mat(fine_tex, Color(0.52, 0.40, 0.26), 0.5, 0.95, false, fine_n)', '"wood": _tex_mat(wood_tex, Color(0.52, 0.40, 0.26), 0.5, 0.95, false, wood_n)')
rep("var m_road := _tex_mat(fine_tex, Color(0.26, 0.26, 0.27), 0.2, 0.95, false, fine_n, 1.5)", "var m_road := _tex_mat(road_tex, Color(0.26, 0.26, 0.27), 0.2, 0.95, false, road_n, 1.5)")
rep("\tvar m_side := _tex_mat(conc_tex, Color(0.60, 0.58, 0.54), 0.3, 0.95, false, conc_n)\n", '''\tvar m_side := _tex_mat(conc_tex, Color(0.60, 0.58, 0.54), 0.3, 0.95, false, conc_n)
\tif x_conc != null:
\t\t_lift(mats["conc"], 1.7)
\t\t_lift(m_ground, 1.7)
\t\t_lift(m_side, 1.7)
\tif x_road != null:
\t\t_lift(m_road, 1.8)
\tif x_rust != null:
\t\t_lift(mats["rust"], 1.8)
\tif x_wood != null:
\t\t_lift(mats["wood"], 1.6)
\tif x_sand != null:
\t\t_lift(mats["sand"], 1.6)
''')
open(p, "w").write(s)
print("main.gd patché")
