extends Node3D
## ═══════════════════════════════════════════════════════
## HOQUEI PATINS 3D  –  Pol Hernáez (DAM1)
## Godot 4.2+  –  Tot el joc en un sol script
## ═══════════════════════════════════════════════════════

# ── CONSTANTS ───────────────────────────────────────────
const FW   := 48.0   # amplada camp (X)
const FH   := 24.0   # llargada camp (Z)
const GZ   := 3.5    # semi-amplada porteria
const GD   := 2.8    # profunditat porteria
const GH   := 3.4    # alçada porteria
const BR   := 0.44   # radi pilota
const FRIC := 0.978  # fricció pilota per frame@60fps

const SPEEDS := {"n": 36.0, "c": 28.0, "p": 52.0}

# ── ESTAT DE JOC ────────────────────────────────────────
enum Phase { MY_TURN, SHOOTING, AI_TURN, GOAL, OVER }
var phase   := Phase.MY_TURN
var shot    := "n"   # n=normal, c=curve, p=power

# Posicions jugadors [0=GK, 1=DEF, 2=FW/humà]
var lx  := [-(FW/2.0 - 4.2), -13.0, -4.4]
var lz  := [0.0, 0.0, 0.0]
var ltx := [0.0, 0.0, 0.0]
var ltz := [0.0, 0.0, 0.0]
var rx  := [ FW/2.0 - 4.2,   13.0,  4.4]
var rz  := [0.0, 0.0, 0.0]
var rtx := [0.0, 0.0, 0.0]
var rtz := [0.0, 0.0, 0.0]

var human_ball := true
var rival_ball := false
var r_holder   := -1

var bx := 0.0
var bz := 0.0
var bvx := 0.0
var bvz := 0.0
var cfx := 0.0
var cfz := 0.0
var ball_free := false

var aim_ang := 0.0
var aim_pow := 0.6
var score_l := 0
var score_r := 0
var rewinds := 3
var time_left := 120.0

var sv_bx := 0.0; var sv_bz := 0.0
var sv_hx := 0.0; var sv_hz := 0.0

# Timers interns
var ai_delay   := 0.0
var goal_delay := 0.0
var init_after_goal := false
var local_kick_next := false

# ── NODES 3D ────────────────────────────────────────────
var l_nodes : Array[Node3D] = []
var r_nodes : Array[Node3D] = []
var ball_node   : Node3D
var ball_stripe : Node3D
var aim_group   : Node3D
var aura_node   : Node3D
var cam         : Camera3D
var cam_angle   := 0.0
var cam_x := -20.0
var cam_z := 0.0
var aura_time := 0.0

# ── UI ──────────────────────────────────────────────────
var lbl_sl    : Label
var lbl_sr    : Label
var lbl_time  : Label
var lbl_msg   : Label
var pw_fill   : ColorRect
var btn_refs  : Dictionary = {}

# ── INPUT ───────────────────────────────────────────────
var mouse_down := false
var ms_x := 0.0; var ms_y := 0.0
var ms_ang := 0.0; var ms_pow := 0.6
var drag_d := 0.0
var did_drag := false

# ════════════════════════════════════════════════════════
func _ready() -> void:
	_setup_env()
	_setup_field()
	_setup_goals()
	_setup_walls()
	_setup_players()
	_setup_ball()
	_setup_aim()
	_setup_aura()
	_setup_camera()
	_setup_ui()
	_init_pos(true)

# ── ENVIRONMENT ─────────────────────────────────────────
func _setup_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.016, 0.024, 0.055)
	env.ambient_light_color = Color(0.65, 0.65, 0.65)
	env.ambient_light_energy = 1.0
	env.fog_enabled = true
	env.fog_density = 0.016
	env.fog_aerial_perspective = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.96, 0.84)
	sun.light_energy = 1.15
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.54, 0.68, 1.0)
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-22, 155, 0)
	add_child(fill)

# ── CAMP DE PARQUET ─────────────────────────────────────
func _setup_field() -> void:
	# Terra de fusta (parquet)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(FW, FH)
	fl.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.73, 0.57, 0.33)
	fm.roughness = 0.92
	fl.material_override = fm
	fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fl)

	# Línies del camp
	_decal(0.0, 0.0, 0.1, FH, Color(0.10, 0.25, 0.83))
	_decal(-FW/4, 0.0, 0.1, FH, Color(0.74, 0.10, 0.10))
	_decal( FW/4, 0.0, 0.1, FH, Color(0.74, 0.10, 0.10))

	# Cercle central (torus pla)
	var ci := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.outer_radius = 3.55; tm.inner_radius = 3.35
	tm.rings = 52; tm.ring_segments = 8
	ci.mesh = tm
	var cm := _mat(Color(0.10, 0.25, 0.83))
	ci.material_override = cm
	ci.rotation.x = -PI / 2.0
	ci.position.y = 0.018
	ci.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ci)

	# Punts cara-off
	for pos: Vector3 in [
		Vector3(-FW/4, 0.018, -FH/3.5), Vector3(-FW/4, 0.018, FH/3.5),
		Vector3( FW/4, 0.018, -FH/3.5), Vector3( FW/4, 0.018, FH/3.5)
	]:
		_dot(pos, 0.28, Color(0.74, 0.10, 0.10))
	_dot(Vector3(0, 0.018, 0), 0.30, Color(0.74, 0.10, 0.10))

func _decal(x: float, z: float, w: float, h: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(w, h)
	mi.mesh = pm
	mi.material_override = _mat(col)
	mi.position = Vector3(x, 0.014, z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _dot(pos: Vector3, r: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = r; cy.bottom_radius = r; cy.height = 0.04; cy.radial_segments = 16
	mi.mesh = cy; mi.material_override = _mat(col)
	mi.position = pos; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

# ── PORTERIES ───────────────────────────────────────────
func _setup_goals() -> void:
	_make_goal(-FW/2.0, true)
	_make_goal( FW/2.0, false)

func _make_goal(gx: float, local: bool) -> void:
	var c  := Color(0.80, 0.085, 0.085) if local else Color(0.055, 0.20, 0.83)
	var nc := Color(0.10, 0.02, 0.02)   if local else Color(0.02, 0.03, 0.10)
	var g  := Node3D.new(); add_child(g); g.position.x = gx

	for zz: float in [-GZ, GZ]:
		_box_c(g, Vector3(0.42, GH, 0.42), Vector3(0, GH/2.0, zz), c)
	_box_c(g, Vector3(0.42, 0.42, GZ*2.0 + 0.42), Vector3(0, GH, 0), c)
	var rx2 := -GD/2.0 if local else GD/2.0
	for zz: float in [-GZ, GZ]:
		_box_c(g, Vector3(GD, 0.42, 0.42), Vector3(rx2, GH, zz), c)
	_box_c(g, Vector3(0.42, GH, GZ*2.0 + 0.42), Vector3(rx2*2.0, GH/2.0, 0), c)

	# Xarxa semitransparent
	var nm := StandardMaterial3D.new()
	nm.albedo_color = nc; nm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var na := Color(nc.r, nc.g, nc.b, 0.88); nm.albedo_color = na
	_box_m(g, Vector3(GD, GH-0.4, GZ*2.0), Vector3(rx2, GH/2.0+0.2, 0), nm)

# ── BANDES ──────────────────────────────────────────────
func _setup_walls() -> void:
	var wc := Color(0.91, 0.93, 0.97)
	var rc := Color(0.67, 0.07, 0.07)
	var wh := 3.4
	for cfg: Array in [
		[Vector3(0, wh/2.0, -FH/2.0-0.45), Vector3(FW+2.6, wh, 0.9)],
		[Vector3(0, wh/2.0,  FH/2.0+0.45), Vector3(FW+2.6, wh, 0.9)],
		[Vector3(-FW/2.0-0.45, wh/2.0, 0),  Vector3(0.9, wh, FH)],
		[Vector3( FW/2.0+0.45, wh/2.0, 0),  Vector3(0.9, wh, FH)]
	]:
		var pos: Vector3 = cfg[0]; var sz: Vector3 = cfg[1]
		_box_c(self, sz, pos, wc)
		_box_c(self, Vector3(sz.x+0.1, 0.62, sz.z+0.1),
			Vector3(pos.x, pos.y + sz.y/2.0 - 0.55, pos.z), rc)

# ── JUGADORS (blocky Roblox) ─────────────────────────────
# El model mira en -Z per defecte.
# Local (ha de mirar +X cap a porteria rival): rotation.y = -PI/2
# Rival (ha de mirar -X cap a porteria local): rotation.y = +PI/2
func _setup_players() -> void:
	for i in range(3):
		var lh := Color(1.0, 0.84, 0.0) if i == 0 else Color(0.52, 0.05, 0.05)
		var rh := Color(1.0, 0.84, 0.0) if i == 0 else Color(0.03, 0.11, 0.52)

		var ln := _make_player(Color(0.78, 0.085, 0.085), Color(0.52, 0.52, 0.52), lh, i == 2)
		ln.position = Vector3(lx[i], 0, lz[i])
		ln.rotation.y = -PI / 2.0   # mira +X
		add_child(ln); l_nodes.append(ln)

		var rn := _make_player(Color(0.055, 0.20, 0.83), Color(0.31, 0.31, 0.31), rh, false)
		rn.position = Vector3(rx[i], 0, rz[i])
		rn.rotation.y = PI / 2.0    # mira -X
		add_child(rn); r_nodes.append(rn)

func _make_player(jc: Color, sc: Color, hc: Color, is_human: bool) -> Node3D:
	var g := Node3D.new()
	var jm := _mat(jc); var sm := _mat(sc); var hm := _mat(hc)
	var bk := _mat(Color(0.06, 0.06, 0.06))
	var wm := _mat(Color(0.80, 0.07, 0.07))   # rodes vermelles
	var sk := _mat(Color(0.88, 0.68, 0.51))   # pell
	var wt := _mat(Color(1.0, 1.0, 1.0))      # blanc (franja)
	var wd := _mat(Color(0.48, 0.31, 0.09))   # fusta (estic)
	var bd := _mat(Color(0.24, 0.11, 0.03))   # pala

	# PATINS (de Y=0 a Y=0.65)
	_box_m(g, Vector3(1.55, 0.65, 2.25), Vector3(-0.55, 0.32, 0), bk)
	_box_m(g, Vector3(1.55, 0.65, 2.25), Vector3( 0.55, 0.32, 0), bk)
	# Rodes (4 per pati = 8 total)
	for sx: float in [-0.55, 0.55]:
		for sz: float in [-0.82, -0.28, 0.28, 0.82]:
			var wr := MeshInstance3D.new()
			var cy := CylinderMesh.new()
			cy.top_radius = 0.27; cy.bottom_radius = 0.27
			cy.height = 0.44; cy.radial_segments = 8
			wr.mesh = cy; wr.material_override = wm
			wr.rotation.z = PI/2.0
			wr.position = Vector3(sx, 0.13, sz)
			wr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			g.add_child(wr)

	# CAMES (Y=0.65 a Y=2.5)
	_box_m(g, Vector3(1.1, 1.85, 1.1), Vector3(-0.52, 1.58, 0), sm)
	_box_m(g, Vector3(1.1, 1.85, 1.1), Vector3( 0.52, 1.58, 0), sm)
	# Genolleres
	_box_m(g, Vector3(1.3, 0.9, 1.3), Vector3(-0.52, 1.15, 0), bk)
	_box_m(g, Vector3(1.3, 0.9, 1.3), Vector3( 0.52, 1.15, 0), bk)

	# TORSO (Y=2.5 a Y=4.85)
	_box_m(g, Vector3(2.45, 2.35, 1.55), Vector3(0, 3.68, 0), jm)
	_box_m(g, Vector3(2.45, 0.40, 1.58), Vector3(0, 3.65, 0), wt)  # franja

	# BRAÇOS (costat als braços)
	_box_m(g, Vector3(0.92, 2.05, 0.92), Vector3(-1.68, 3.68, 0), jm)
	_box_m(g, Vector3(0.92, 2.05, 0.92), Vector3( 1.68, 3.68, 0), jm)
	_box_m(g, Vector3(1.12, 0.88, 1.12), Vector3(-1.68, 2.88, 0), bk)  # colzeres
	_box_m(g, Vector3(1.12, 0.88, 1.12), Vector3( 1.68, 2.88, 0), bk)
	_box_m(g, Vector3(1.22, 1.12, 1.12), Vector3(-1.68, 2.1, 0), bk)   # guants
	_box_m(g, Vector3(1.22, 1.12, 1.12), Vector3( 1.68, 2.1, 0), bk)

	# CAP (Y=4.85 a Y=7.3, front = -Z)
	_box_m(g, Vector3(2.82, 2.45, 2.82), Vector3(0, 6.08, 0), sk)
	_box_m(g, Vector3(0.62, 0.52, 0.1), Vector3(-0.56, 6.08, -1.46), bk)  # ull E
	_box_m(g, Vector3(0.62, 0.52, 0.1), Vector3( 0.56, 6.08, -1.46), bk)  # ull D
	_box_m(g, Vector3(1.02, 0.36, 0.1), Vector3(0, 5.62, -1.46), bk)       # boca

	# CASC blocky
	_box_m(g, Vector3(3.24, 2.9, 3.24), Vector3(0, 6.1, 0), hm)
	var hbm := _mat(Color(minf(hc.r+0.12,1.0), minf(hc.g+0.12,1.0), minf(hc.b+0.12,1.0)))
	_box_m(g, Vector3(3.24, 0.5, 3.26), Vector3(0, 4.88, 0), hbm)  # franja casc
	# Reixa cage (roller hockey)
	_box_m(g, Vector3(2.55, 1.88, 0.13), Vector3(0, 5.9, -1.685), bk)
	for bv: float in [-0.88, -0.30, 0.30, 0.88]:
		_box_m(g, Vector3(0.22, 1.88, 0.15), Vector3(bv, 5.9, -1.685),
			_mat(Color(0.20, 0.20, 0.20)))

	# ESTIC DE FUSTA
	var stk := _box_m(g, Vector3(0.55, 4.85, 0.55), Vector3(1.72, 2.55, 0), wd)
	stk.rotation.z = -0.22
	_box_m(g, Vector3(0.42, 0.42, 2.25), Vector3(2.0, 0.40, 0.90), bd)

	# ANELL DAURAT (★ jugador humà)
	if is_human:
		var rm := MeshInstance3D.new()
		var tmesh := TorusMesh.new()
		tmesh.outer_radius = 1.92; tmesh.inner_radius = 1.74
		tmesh.rings = 40; tmesh.ring_segments = 8
		rm.mesh = tmesh
		rm.material_override = _mat(Color(1.0, 0.84, 0.0))
		rm.rotation.x = -PI/2.0
		rm.position.y = 0.12
		rm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(rm)

	# OMBRA terra
	var sh := MeshInstance3D.new()
	var shm := CylinderMesh.new()
	shm.top_radius = 1.65; shm.bottom_radius = 1.65; shm.height = 0.04; shm.radial_segments = 20
	sh.mesh = shm
	var shmat := StandardMaterial3D.new()
	shmat.albedo_color = Color(0.04, 0.03, 0.02, 0.38)
	shmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sh.material_override = shmat
	sh.position.y = 0.012
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(sh)

	return g

# ── PILOTA ──────────────────────────────────────────────
func _setup_ball() -> void:
	ball_node = Node3D.new()
	# Pilota taronja
	var bmi := MeshInstance3D.new()
	var bm := SphereMesh.new(); bm.radius = BR; bm.height = BR*2.0; bm.radial_segments = 18; bm.rings = 12
	bmi.mesh = bm; bmi.material_override = _mat(Color(1.0, 0.43, 0.03))
	bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	ball_node.add_child(bmi)
	# Franja negra
	ball_stripe = MeshInstance3D.new()
	var tsm := TorusMesh.new()
	tsm.outer_radius = BR*0.88; tsm.inner_radius = BR*0.72; tsm.rings = 28; tsm.ring_segments = 6
	ball_stripe.mesh = tsm; ball_stripe.material_override = _mat(Color(0.05, 0.05, 0.05))
	ball_stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball_node.add_child(ball_stripe)
	# Ombra pilota
	var bsh := MeshInstance3D.new()
	var bshm := CylinderMesh.new()
	bshm.top_radius = BR+0.18; bshm.bottom_radius = BR+0.18; bshm.height = 0.04; bshm.radial_segments = 16
	bsh.mesh = bshm
	var bsmat := StandardMaterial3D.new()
	bsmat.albedo_color = Color(0.03, 0.02, 0.01, 0.42)
	bsmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bsh.material_override = bsmat; bsh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball_node.add_child(bsh)
	add_child(ball_node)

# ── FLETXA AIM (discs plans al terra) ──────────────────
# aim_ang=0 → apunta +X (porteria rival)
# rotation.y = -aim_ang perquè: quan aim_ang=π/2 volem apuntar +Z,
# i rotation.y=-π/2 mapeja +X→+Z (comprovació a la documentació)
func _setup_aim() -> void:
	aim_group = Node3D.new()
	for i in range(1, 11):
		var t := float(i) / 10.0
		var col: Color
		if t < 0.4:
			col = Color(0.13, 0.85, 0.24)
		elif t < 0.7:
			col = Color(1.0, 0.76, 0.08)
		else:
			col = Color(1.0, 0.17, 0.11)
		var disc := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.52 - i*0.022; cy.bottom_radius = cy.top_radius
		cy.height = 0.09; cy.radial_segments = 14
		disc.mesh = cy; disc.material_override = _mat(col)
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		disc.position = Vector3(i * 1.65, 0.09, 0)
		aim_group.add_child(disc)
	# Punta (cub)
	var tip := _box_m(aim_group, Vector3(1.2, 0.12, 1.2), Vector3(17.8, 0.09, 0),
		_mat(Color(1.0, 0.89, 0.11)))
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aim_group.visible = false
	add_child(aim_group)

# ── AURA (anell pulsant sota el jugador humà) ───────────
func _setup_aura() -> void:
	aura_node = Node3D.new()
	var rm1 := MeshInstance3D.new()
	var t1 := TorusMesh.new(); t1.outer_radius = 2.0; t1.inner_radius = 1.82; t1.rings = 44; t1.ring_segments = 8
	rm1.mesh = t1; rm1.material_override = _mat(Color(0.21, 0.76, 1.0))
	rm1.rotation.x = -PI/2.0; rm1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura_node.add_child(rm1)
	var rm2 := MeshInstance3D.new()
	var t2 := TorusMesh.new(); t2.outer_radius = 1.35; t2.inner_radius = 1.18; t2.rings = 36; t2.ring_segments = 8
	rm2.mesh = t2; rm2.material_override = _mat(Color(0.52, 0.89, 1.0))
	rm2.rotation.x = -PI/2.0; rm2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura_node.add_child(rm2)
	aura_node.position.y = 0.12; aura_node.visible = false
	add_child(aura_node)

# ── CAMERA 3A PERSONA ───────────────────────────────────
func _setup_camera() -> void:
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.1; cam.far = 180.0
	cam.position = Vector3(-20, 12, 0)
	cam.look_at(Vector3(5, 1.5, 0))
	add_child(cam)

func _update_camera() -> void:
	var px: float = lx[2]
	var pz: float = lz[2]
	var rad := cam_angle * PI / 180.0
	var offx := -cos(rad) * 20.0; var offz := -sin(rad) * 20.0
	cam_x = lerp(cam_x, px + offx, 0.07)
	cam_z = lerp(cam_z, pz + offz, 0.07)
	cam.position = Vector3(cam_x, 12.0, cam_z)
	cam.look_at(Vector3(px + cos(rad)*5.0, 1.5, pz + sin(rad)*5.0), Vector3.UP)

# ── UI ──────────────────────────────────────────────────
func _setup_ui() -> void:
	var cl := CanvasLayer.new(); add_child(cl)

	# HUD superior
	var hud := ColorRect.new()
	hud.color = Color(0.053, 0.09, 0.19, 0.96)
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud.custom_minimum_size = Vector2(0, 70)
	cl.add_child(hud)

	lbl_sl = _lbl("0", 44, Color(1,1,1), true); lbl_sl.position = Vector2(20, 10); hud.add_child(lbl_sl)
	lbl_sr = _lbl("0", 44, Color(1,1,1), true)
	lbl_sr.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	lbl_sr.position = Vector2(-100, 10); hud.add_child(lbl_sr)

	var nl := _lbl("★  ARENYS HC", 12, Color(0.87, 0.12, 0.12), true)
	nl.position = Vector2(20, -4); hud.add_child(nl)

	var nr := _lbl("RIVALS FC  ★", 12, Color(0.06, 0.25, 0.79), true)
	nr.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	nr.position = Vector2(-160, -4); hud.add_child(nr)

	lbl_time = _lbl("2:00", 34, Color(0.60, 0.67, 0.81), true)
	lbl_time.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	lbl_time.position = Vector2(-60, 5); hud.add_child(lbl_time)

	lbl_msg = _lbl("EL TEU TORN – Arrossega per apuntar", 10, Color(1.0, 0.86, 0.19))
	lbl_msg.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	lbl_msg.position = Vector2(-220, 44); hud.add_child(lbl_msg)

	# Barra de controls inferior
	var ctrl := ColorRect.new()
	ctrl.color = Color(0.02, 0.03, 0.06, 0.96)
	ctrl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	ctrl.custom_minimum_size = Vector2(0, 68)
	cl.add_child(ctrl)

	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_theme_constant_override("separation", 8)
	bar.add_theme_constant_override("margin_left", 18)
	ctrl.add_child(bar)

	var bN := _btn("⬛ NORMAL [Q]",  Color(0.09, 0.31, 0.08), true)
	var bC := _btn("↩ EFECTE  [W]", Color(0.35, 0.25, 0.05), false)
	var bP := _btn("⚡ FORT    [E]", Color(0.38, 0.08, 0.08), false)
	var bA := _btn("➡ PASSAR  [P]", Color(0.06, 0.21, 0.38), false)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bR := _btn("↩ REWIND×3 [R]",Color(0.24, 0.16, 0.04), false)
	var bS := _btn("🏒  TIRA! [SPACE]",Color(0.10, 0.35, 0.09), false)

	bN.pressed.connect(func(): _set_shot("n"))
	bC.pressed.connect(func(): _set_shot("c"))
	bP.pressed.connect(func(): _set_shot("p"))
	bA.pressed.connect(func(): do_pass())
	bR.pressed.connect(func(): do_rewind())
	bS.pressed.connect(func(): do_shoot())

	bar.add_child(bN); bar.add_child(bC); bar.add_child(bP); bar.add_child(bA)
	bar.add_child(sp); bar.add_child(bR); bar.add_child(bS)

	btn_refs = {"n": bN, "c": bC, "p": bP, "rew": bR, "shoot": bS, "pass": bA}

	# Power bar (barra de potència)
	var pw_bg := ColorRect.new()
	pw_bg.color = Color(1,1,1,0.12)
	pw_bg.custom_minimum_size = Vector2(14, 110)
	pw_bg.position = Vector2(22, -185)
	pw_bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	cl.add_child(pw_bg)

	pw_fill = ColorRect.new()
	pw_fill.color = Color(0.14, 0.86, 0.24)
	pw_fill.size = Vector2(14, 66)
	pw_fill.position = Vector2(0, 44)
	pw_bg.add_child(pw_fill)
	pw_bg.visible = false

	# Consell rotació càmera
	var tip := _lbl("← → Rotar càmera  ·  ASDF Moure  ·  ↑ Reset", 9, Color(0.20, 0.22, 0.31))
	tip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	tip.position = Vector2(-480, -75); cl.add_child(tip)

func _lbl(text: String, size: int, col: Color, bold: bool = false) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _btn(text: String, bg: Color, active: bool) -> Button:
	var b := Button.new(); b.text = text
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.custom_minimum_size = Vector2(104, 44)
	b.add_theme_stylebox_override("normal", _box_style(bg, active))
	b.add_theme_stylebox_override("hover", _box_style(bg.lightened(0.2), active))
	b.add_theme_stylebox_override("pressed", _box_style(bg.darkened(0.1), active))
	b.add_theme_stylebox_override("disabled", _box_style(Color(bg.r,bg.g,bg.b,0.35), false))
	b.focus_mode = Control.FOCUS_NONE
	return b

func _box_style(col: Color, border: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col; sb.corner_radius_top_left = 7; sb.corner_radius_top_right = 7
	sb.corner_radius_bottom_left = 7; sb.corner_radius_bottom_right = 7
	sb.content_margin_left = 8; sb.content_margin_right = 8
	if border: sb.border_width_top=2;sb.border_width_bottom=2;sb.border_width_left=2;sb.border_width_right=2
	sb.border_color = Color(1,1,1,0.65)
	return sb

# ════════════════════════════════════════════════════════
# INPUT
# ════════════════════════════════════════════════════════
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				mouse_down = true; ms_x = mb.position.x; ms_y = mb.position.y
				ms_ang = aim_ang; ms_pow = aim_pow; drag_d = 0.0; did_drag = false
			else:
				mouse_down = false
				if did_drag:
					if phase == Phase.MY_TURN and human_ball:
						do_shoot()
				else:
					_move_human_click(mb.position)
				did_drag = false

	elif event is InputEventMouseMotion and mouse_down:
		var mm := event as InputEventMouseMotion
		var dx := mm.position.x - ms_x; var dy := mm.position.y - ms_y
		drag_d = sqrt(dx*dx + dy*dy)
		if drag_d > 8.0 and phase == Phase.MY_TURN and human_ball:
			did_drag = true
			aim_ang = ms_ang + dx * 0.026
			aim_pow = clampf(ms_pow - dy / 185.0, 0.05, 1.0)
			_update_power_bar()

	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_Q: _set_shot("n")
			KEY_W: _set_shot("c")
			KEY_E: _set_shot("p")
			KEY_P: do_pass()
			KEY_R: do_rewind()
			KEY_SPACE, KEY_ENTER: do_shoot()
			KEY_A:
				if phase == Phase.MY_TURN:
					ltx[2] = clampf(lx[2] - 5.0, -FW/2.0+1.4, FW/2.0-1.4); ltz[2] = lz[2]
			KEY_D:
				if phase == Phase.MY_TURN:
					ltx[2] = clampf(lx[2] + 5.0, -FW/2.0+1.4, FW/2.0-1.4); ltz[2] = lz[2]
			KEY_S:
				if phase == Phase.MY_TURN:
					ltx[2] = lx[2]; ltz[2] = clampf(lz[2] + 5.0, -FH/2.0+0.8, FH/2.0-0.8)
			KEY_F:
				if phase == Phase.MY_TURN:
					ltx[2] = lx[2]; ltz[2] = clampf(lz[2] - 5.0, -FH/2.0+0.8, FH/2.0-0.8)
			KEY_LEFT:  cam_angle = fmod(cam_angle - 22.0 + 360.0, 360.0)
			KEY_RIGHT: cam_angle = fmod(cam_angle + 22.0, 360.0)
			KEY_UP:    cam_angle = 0.0
			KEY_DOWN:  cam_angle = 180.0

func _move_human_click(screen_pos: Vector2) -> void:
	if phase != Phase.MY_TURN: return
	var ray_o := cam.project_ray_origin(screen_pos)
	var ray_d := cam.project_ray_normal(screen_pos)
	if abs(ray_d.y) < 0.001: return
	var t := -ray_o.y / ray_d.y
	if t < 0: return
	var wp := ray_o + ray_d * t
	var ddx: float = wp.x - lx[2]
	var ddz: float = wp.z - lz[2]
	var dd := sqrt(ddx*ddx + ddz*ddz)
	if dd > 0.2:
		var cap := 14.0
		if dd > cap: ddx = ddx/dd*cap; ddz = ddz/dd*cap
		ltx[2] = clampf(lx[2]+ddx, -FW/2.0+1.4, FW/2.0-1.4)
		ltz[2] = clampf(lz[2]+ddz, -FH/2.0+0.8, FH/2.0-0.8)

# ════════════════════════════════════════════════════════
# ACCIONS DE JOC
# ════════════════════════════════════════════════════════
func do_shoot() -> void:
	if phase != Phase.MY_TURN or not human_ball: return
	sv_bx=bx; sv_bz=bz; sv_hx=lx[2]; sv_hz=lz[2]
	human_ball = false; ball_free = true
	var spd := 70.0 + aim_pow * (SPEEDS[shot] - 70.0)
	# aim_ang=0 → +X (porteria rival), aim_ang=π/2 → +Z
	bvx = cos(aim_ang) * spd
	bvz = sin(aim_ang) * spd
	cfx = -sin(aim_ang)*8.0 if shot=="c" else 0.0
	cfz =  cos(aim_ang)*8.0 if shot=="c" else 0.0
	_set_phase(Phase.SHOOTING)

func do_pass() -> void:
	if phase != Phase.MY_TURN or not human_ball: return
	var t := 0 if _d2(lx[0],lz[0],lx[2],lz[2]) < _d2(lx[1],lz[1],lx[2],lz[2]) else 1
	human_ball=false; ball_free=true; cfx=0.0; cfz=0.0
	var dx: float = lx[t]-bx
	var dz: float = lz[t]-bz
	var dd: float = sqrt(dx*dx+dz*dz)
	if dd < 0.1: human_ball=true; ball_free=false; return
	bvx=dx/dd*28.0; bvz=dz/dd*28.0
	_set_phase(Phase.SHOOTING)

func do_rewind() -> void:
	if rewinds <= 0 or phase == Phase.MY_TURN: return
	rewinds -= 1
	btn_refs["rew"].text = "↩ REWIND×%d [R]" % rewinds
	bx=sv_bx; bz=sv_bz; bvx=0.0; bvz=0.0; cfx=0.0; cfz=0.0
	lx[2]=sv_hx; lz[2]=sv_hz; ltx[2]=sv_hx; ltz[2]=sv_hz
	human_ball=true; ball_free=false
	_set_phase(Phase.MY_TURN)

func _set_shot(t: String) -> void:
	shot = t
	for k in btn_refs:
		if k in ["n","c","p"]:
			btn_refs[k].add_theme_stylebox_override("normal",
				_box_style(btn_refs[k].get_theme_stylebox("normal").bg_color, k == t))
	_set_shot_style()

func _set_shot_style() -> void:
	var cols := {"n": Color(0.09,0.31,0.08), "c": Color(0.35,0.25,0.05), "p": Color(0.38,0.08,0.08)}
	for k in ["n","c","p"]:
		if k in btn_refs and k in cols:
			btn_refs[k].add_theme_stylebox_override("normal", _box_style(cols[k], k == shot))

# ════════════════════════════════════════════════════════
# FASES
# ════════════════════════════════════════════════════════
func _set_phase(p: Phase) -> void:
	phase = p
	var my := p == Phase.MY_TURN
	for k in ["n","c","p","pass","shoot"]:
		if k in btn_refs: btn_refs[k].disabled = not my
	if "rew" in btn_refs: btn_refs["rew"].disabled = rewinds<=0 or my

	match p:
		Phase.MY_TURN:
			lbl_msg.text = "EL TEU TORN – Arrossega per apuntar + allibera per xutar"
			lbl_msg.add_theme_color_override("font_color", Color(1.0,0.86,0.19))
		Phase.SHOOTING:
			lbl_msg.text = "LLANÇAMENT..."; lbl_msg.add_theme_color_override("font_color", Color(1.0,0.54,0.17))
		Phase.AI_TURN:
			lbl_msg.text = "TORN RIVAL"; lbl_msg.add_theme_color_override("font_color", Color(0.27,0.51,1.0))
			ai_delay = 0.6 + randf() * 0.7
		Phase.GOAL:
			aim_group.visible = false
		Phase.OVER:
			aim_group.visible = false

func _update_power_bar() -> void:
	if "power_bar_parent" in btn_refs: return  # skip
	# Power bar via pw_fill
	var h := aim_pow * 110.0
	if pw_fill != null:
		pw_fill.size.y = h
		pw_fill.position.y = 110.0 - h
		var t := aim_pow
		pw_fill.color = Color(0.14,0.86,0.24) if t<0.4 else Color(1.0,0.76,0.08) if t<0.7 else Color(1.0,0.17,0.11)

# ════════════════════════════════════════════════════════
# INIT POSICIONS
# ════════════════════════════════════════════════════════
func _init_pos(local_kick: bool) -> void:
	lx = [-(FW/2.0-4.2), -13.0, -4.4]; lz = [0.0,0.0,0.0]
	ltx = lx.duplicate()
	ltz = lz.duplicate()
	rx = [FW/2.0-4.2, 13.0, 4.4]; rz = [0.0,0.0,0.0]
	rtx = rx.duplicate()
	rtz = rz.duplicate()
	human_ball=false; rival_ball=false; r_holder=-1
	bvx=0.0; bvz=0.0; cfx=0.0; cfz=0.0; ball_free=false
	aim_ang=0.0; aim_pow=0.6; ai_delay=0.0

	if local_kick:
		human_ball=true; bx=lx[2]+1.8; bz=lz[2]
		_set_phase(Phase.MY_TURN)
	else:
		rival_ball=true; r_holder=2; bx=rx[2]-1.8; bz=rz[2]
		ai_delay = 0.5
		phase = Phase.AI_TURN
		lbl_msg.text = "TORN RIVAL"; lbl_msg.add_theme_color_override("font_color", Color(0.27,0.51,1.0))

# ════════════════════════════════════════════════════════
# GAME LOOP
# ════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	if phase == Phase.OVER: _sync_scene(); _update_camera(); return

	# Timer (no compta durant GOAL)
	if phase != Phase.GOAL:
		time_left = maxf(0.0, time_left - delta)
		var m := int(time_left / 60.0); var s := int(fmod(time_left, 60.0))
		lbl_time.text = "%d:%02d" % [m, s]
		if time_left <= 0.0 and phase != Phase.OVER:
			_set_phase(Phase.OVER); _on_over()

	# Timer de gol
	if phase == Phase.GOAL:
		goal_delay -= delta
		if goal_delay <= 0.0 and init_after_goal:
			init_after_goal = false; _init_pos(local_kick_next)
		_sync_scene(); _update_camera(); return

	# Timer de la IA
	if phase == Phase.AI_TURN and ai_delay > 0.0:
		ai_delay -= delta
		if ai_delay <= 0.0: _ai_shoot()

	_tick_ball(delta)
	_tick_ai(delta)
	_check_goal()
	_sync_scene()
	_update_camera()
	aura_time += delta

# ── FÍSICA PILOTA ───────────────────────────────────────
func _tick_ball(dt: float) -> void:
	if human_ball and phase == Phase.MY_TURN:
		bx = lx[2] + 1.8; bz = lz[2]; bvx=0.0; bvz=0.0; return
	if rival_ball and r_holder >= 0:
		bx = rx[r_holder] - 1.8; bz = rz[r_holder]; bvx=0.0; bvz=0.0; return
	if not ball_free: return

	# Efecte de corba
	if shot == "c":
		bvx += cfx*dt; bvz += cfz*dt
		var dc := pow(0.88, dt*60.0); cfx*=dc; cfz*=dc

	bx += bvx*dt; bz += bvz*dt
	var fr := pow(FRIC, dt*60.0); bvx*=fr; bvz*=fr

	# Rebots bandes
	var wx := FW/2.0+0.2-BR; var wz := FH/2.0+0.2-BR
	if abs(bx) > wx: bvx *= -0.65; bx = sign(bx)*wx
	if abs(bz) > wz: bvz *= -0.65; bz = sign(bz)*wz

	# Porters salven
	var bs := sqrt(bvx*bvx+bvz*bvz)
	if _d2(bx,bz,lx[0],lz[0]) < 1.4 and bs > 1.5:
		bvx *= -0.52; bvz += (randf()-0.5)*11.0; _clamp_ball(13.0)
	if _d2(bx,bz,rx[0],rz[0]) < 1.4 and bs > 1.5:
		bvx *= -0.52; bvz += (randf()-0.5)*11.0; _clamp_ball(13.0)

	# Recollida (durant SHOOTING)
	if phase == Phase.SHOOTING:
		for i in range(3):
			if _d2(bx,bz,lx[i],lz[i]) < 1.25:
				ball_free = false
				if i == 2:
					human_ball = true
					_set_phase(Phase.MY_TURN)
				else:
					# DEF o GK local: passa al FW humà després d'un moment
					var tw := create_tween()
					tw.tween_callback(func():
						human_ball=true; bx=lx[2]+1.8; bz=lz[2]; _set_phase(Phase.MY_TURN)
					).set_delay(0.35)
				return
		for i in range(3):
			if _d2(bx,bz,rx[i],rz[i]) < 1.25:
				ball_free=false; rival_ball=true; r_holder=i; _set_phase(Phase.AI_TURN); return
		if sqrt(bvx*bvx+bvz*bvz) < 0.7:
			ball_free=false; human_ball=true; bx=lx[2]+1.8; bz=lz[2]; _set_phase(Phase.MY_TURN)

func _clamp_ball(mx: float) -> void:
	var s := sqrt(bvx*bvx+bvz*bvz)
	if s > 0.0 and s < mx: bvx=bvx/s*mx; bvz=bvz/s*mx

# ── IA ──────────────────────────────────────────────────
func _tick_ai(dt: float) -> void:
	# GK local
	_mv_ent(lx,lz,ltx,ltz,0, -(FW/2.0-4.2), clampf(bz,-GZ+0.5,GZ-0.5), 12.5, dt)
	# DEF local (cobertura)
	var dftx := clampf(rx[2]-7.5, -FW/2.0+5.5, -0.5) if phase!=Phase.MY_TURN else -11.0
	_mv_ent(lx,lz,ltx,ltz,1, dftx, bz*0.38, 14.0, dt)
	# Humà
	if phase != Phase.MY_TURN:
		_mv_ent(lx,lz,ltx,ltz,2, bx-2.2, bz, 16.5, dt)
	else:
		var ddx: float = ltx[2]-lx[2]
		var ddz: float = ltz[2]-lz[2]
		var dd: float = sqrt(ddx*ddx+ddz*ddz)
		if dd > 0.1:
			var s := minf(19.0*dt, dd); lx[2]+=ddx/dd*s; lz[2]+=ddz/dd*s
		lx[2]=clampf(lx[2],-FW/2.0+1.4,FW/2.0-1.4); lz[2]=clampf(lz[2],-FH/2.0+0.8,FH/2.0-0.8)

	# GK rival
	_mv_ent(rx,rz,rtx,rtz,0, FW/2.0-4.2, clampf(bz,-GZ+0.5,GZ-0.5), 12.5, dt)
	# DEF rival (pressiona però queda al seu camp X>2.5)
	var rdfx := maxf(2.5, lx[2]+5.5+sin(Time.get_unix_time_from_system()*0.002)*2.2)
	_mv_ent(rx,rz,rtx,rtz,1, rdfx, lz[2]*0.5, 13.6, dt)
	# FW rival (dribla si té pilota; sinó queda al seu camp)
	if phase == Phase.AI_TURN and rival_ball and r_holder == 2:
		var tx := -(FW/2.0-9.4)
		var tz := sin(Time.get_unix_time_from_system()*0.00082)*5.5
		_mv_ent(rx,rz,rtx,rtz,2, tx, tz, 15.2, dt)
	elif not rival_ball:
		_mv_ent(rx,rz,rtx,rtz,2, maxf(1.8, bx+2.6), bz*0.75, 14.0, dt)

func _mv_ent(x:Array,z:Array,tx:Array,tz:Array,i:int,ttx:float,ttz:float,spd:float,dt:float) -> void:
	tx[i]=ttx; tz[i]=ttz
	var dx: float = tx[i]-x[i]
	var dz: float = tz[i]-z[i]
	var dd: float = sqrt(dx*dx+dz*dz)
	if dd > 0.1:
		var s := minf(spd*dt, dd); x[i]+=dx/dd*s; z[i]+=dz/dd*s
	x[i]=clampf(x[i],-FW/2.0+1.2,FW/2.0-1.2); z[i]=clampf(z[i],-FH/2.0+0.8,FH/2.0-0.8)

func _ai_shoot() -> void:
	if phase != Phase.AI_TURN or not rival_ball: return
	rival_ball=false; ball_free=true; cfx=0.0; cfz=0.0
	var tx := -(FW/2.0)-bx; var tz := (randf()-0.5)*GZ*1.5-bz
	var dd := sqrt(tx*tx+tz*tz)
	bvx=tx/dd*(24.0+randf()*19.5); bvz=tz/dd*(24.0+randf()*19.5)
	phase = Phase.SHOOTING
	lbl_msg.text = "LLANÇAMENT RIVAL!"; lbl_msg.add_theme_color_override("font_color",Color(1.0,0.25,0.25))

# ── GOL ─────────────────────────────────────────────────
func _check_goal() -> void:
	if phase == Phase.GOAL or phase == Phase.OVER: return
	if bx < -(FW/2.0 + 0.7) and abs(bz) < GZ:
		_on_goal(false)
	if bx > FW/2.0 + 0.7 and abs(bz) < GZ:
		_on_goal(true)

func _on_goal(local_scored: bool) -> void:
	if local_scored:
		score_l += 1
	else:
		score_r += 1
	lbl_sl.text = str(score_l); lbl_sr.text = str(score_r)

	var col := Color(1.0,0.87,0.20) if local_scored else Color(1.0,0.27,0.27)
	var msg := "⚽  GOL!  ARENYS HC!" if local_scored else "⚽  GOL!  RIVALS FC!"
	lbl_msg.text = msg; lbl_msg.add_theme_color_override("font_color", col)

	phase = Phase.GOAL
	ball_free = false
	bvx = 0.0
	bvz = 0.0
	human_ball = false
	rival_ball = false
	r_holder = -1
	aim_group.visible = false

	# Parpelleig del marcador
	var lbl := lbl_sl if local_scored else lbl_sr
	var tw := create_tween(); tw.set_loops(6)
	tw.tween_property(lbl, "modulate:a", 0.1, 0.16)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.16)

	goal_delay = 2.2
	init_after_goal = true
	local_kick_next = not local_scored

func _on_over() -> void:
	var msg: String
	if score_l > score_r:
		msg = "🏆  VICTÒRIA!  %d-%d" % [score_l, score_r]
	elif score_r > score_l:
		msg = "💀  DERROTA!  %d-%d" % [score_l, score_r]
	else:
		msg = "🤝  EMPAT!  %d-%d" % [score_l, score_r]
	lbl_msg.text = msg
	lbl_msg.add_theme_color_override("font_color", Color(1.0, 0.87, 0.20))

# ── SYNC VISUAL ─────────────────────────────────────────
func _sync_scene() -> void:
	for i in range(3):
		l_nodes[i].position = Vector3(lx[i], 0, lz[i])
		r_nodes[i].position = Vector3(rx[i], 0, rz[i])

	ball_node.position = Vector3(bx, BR, bz)
	ball_stripe.rotation.y += 0.05  # rotació animada

	# Aura
	aura_node.position = Vector3(lx[2], 0.12, lz[2])
	aura_node.visible = (phase == Phase.MY_TURN)
	if aura_node.visible:
		var sc := 1.0 + sin(aura_time * 2.2) * 0.18
		aura_node.scale = Vector3(sc, 1.0, sc)

	# Aim arrow
	var show_aim := phase == Phase.MY_TURN and human_ball
	aim_group.visible = show_aim
	if show_aim:
		aim_group.position = Vector3(bx, 0.0, bz)
		# rotation.y = -aim_ang: quan aim_ang=0 → apunta +X (porteria rival) ✓
		aim_group.rotation.y = -aim_ang
		aim_group.scale.x = 0.25 + aim_pow * 0.75
		if pw_fill and pw_fill.get_parent():
			pw_fill.get_parent().visible = true
			_update_power_bar()
	else:
		if pw_fill and pw_fill.get_parent():
			pw_fill.get_parent().visible = false

# ════════════════════════════════════════════════════════
# HELPERS
# ════════════════════════════════════════════════════════
func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col; m.roughness = 0.88; m.metallic = 0.0
	return m

func _box_c(parent: Node, sz: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	return _box_m(parent, sz, pos, _mat(col))

func _box_m(parent: Node, sz: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = sz
	mi.mesh = bm; mi.material_override = mat; mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi); return mi

func _d2(x1:float,z1:float,x2:float,z2:float) -> float:
	return sqrt((x1-x2)*(x1-x2)+(z1-z2)*(z1-z2))
