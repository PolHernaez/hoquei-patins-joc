extends Node3D
## HOQUEI PATINS 3D – Pol Hernáez (DAM1) – Godot 4.6

# ── CONSTANTS ──────────────────────────────────
const FW: float = 48.0
const FH: float = 24.0
const GZ: float = 3.5
const GD: float = 2.8
const GH: float = 3.4
const BR: float = 0.44
const FRIC: float = 0.978

enum Phase { MY_TURN, SHOOTING, AI_TURN, GOAL, OVER }
var phase: Phase = Phase.MY_TURN
var shot: String = "n"

var lx: Array = [-(FW/2.0 - 4.2), -13.0, -4.4]
var lz: Array = [0.0, 0.0, 0.0]
var ltx: Array = [0.0, 0.0, 0.0]
var ltz: Array = [0.0, 0.0, 0.0]
var rx: Array = [FW/2.0 - 4.2, 13.0, 4.4]
var rz: Array = [0.0, 0.0, 0.0]
var rtx: Array = [0.0, 0.0, 0.0]
var rtz: Array = [0.0, 0.0, 0.0]

var human_ball: bool = true
var rival_ball: bool = false
var r_holder: int = -1

var bx: float = 0.0
var bz: float = 0.0
var bvx: float = 0.0
var bvz: float = 0.0
var cfx: float = 0.0
var cfz: float = 0.0
var ball_free: bool = false

var aim_ang: float = 0.0
var aim_pow: float = 0.6
var score_l: int = 0
var score_r: int = 0
var rewinds: int = 3
var time_left: float = 120.0

var sv_bx: float = 0.0
var sv_bz: float = 0.0
var sv_hx: float = 0.0
var sv_hz: float = 0.0

var ai_delay: float = 0.0
var goal_delay: float = 0.0
var init_after_goal: bool = false
var local_kick_next: bool = false

var l_nodes: Array = []
var r_nodes: Array = []
var ball_node: Node3D
var aim_group: Node3D
var aura_node: Node3D
var cam: Camera3D
var cam_angle: float = 0.0
var cam_x: float = -20.0
var cam_z: float = 0.0
var aura_time: float = 0.0

var lbl_sl: Label
var lbl_sr: Label
var lbl_time: Label
var lbl_msg: Label
var pw_fill: ColorRect
var btn_n: Button
var btn_c: Button
var btn_p: Button

var mouse_down: bool = false
var ms_x: float = 0.0
var ms_y: float = 0.0
var ms_ang: float = 0.0
var ms_pow: float = 0.6
var did_drag: bool = false

# ════════════════════════════════════════════════
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

# ── ENVIRONMENT ─────────────────────────────────
func _setup_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.016, 0.024, 0.055)
	env.ambient_light_color = Color(0.65, 0.65, 0.65)
	env.ambient_light_energy = 1.0
	env.fog_enabled = true
	env.fog_density = 0.016
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.96, 0.84)
	sun.light_energy = 1.15
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.54, 0.68, 1.0)
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-22.0, 155.0, 0.0)
	add_child(fill)

# ── CAMP ────────────────────────────────────────
func _setup_field() -> void:
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
	_decal(0.0, 0.0, 0.1, FH, Color(0.10, 0.25, 0.83))
	_decal(-FW/4.0, 0.0, 0.1, FH, Color(0.74, 0.10, 0.10))
	_decal( FW/4.0, 0.0, 0.1, FH, Color(0.74, 0.10, 0.10))
	var ci := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.outer_radius = 3.55
	tm.inner_radius = 3.35
	tm.rings = 52
	tm.ring_segments = 8
	ci.mesh = tm
	ci.material_override = _mat(Color(0.10, 0.25, 0.83))
	ci.rotation.x = -PI / 2.0
	ci.position.y = 0.018
	ci.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ci)
	_dot(Vector3(0.0, 0.018, 0.0), 0.30, Color(0.74, 0.10, 0.10))
	_dot(Vector3(-FW/4.0, 0.018, -FH/3.5), 0.28, Color(0.74, 0.10, 0.10))
	_dot(Vector3(-FW/4.0, 0.018,  FH/3.5), 0.28, Color(0.74, 0.10, 0.10))
	_dot(Vector3( FW/4.0, 0.018, -FH/3.5), 0.28, Color(0.74, 0.10, 0.10))
	_dot(Vector3( FW/4.0, 0.018,  FH/3.5), 0.28, Color(0.74, 0.10, 0.10))

func _decal(x: float, z: float, w: float, h: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, h)
	mi.mesh = pm
	mi.material_override = _mat(col)
	mi.position = Vector3(x, 0.014, z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _dot(pos: Vector3, r: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = r
	cy.bottom_radius = r
	cy.height = 0.04
	cy.radial_segments = 16
	mi.mesh = cy
	mi.material_override = _mat(col)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

# ── PORTERIES ───────────────────────────────────
func _setup_goals() -> void:
	_make_goal(-FW/2.0, true)
	_make_goal( FW/2.0, false)

func _make_goal(gx: float, is_local: bool) -> void:
	var c: Color
	var nc: Color
	if is_local:
		c  = Color(0.80, 0.085, 0.085)
		nc = Color(0.10, 0.02,  0.02)
	else:
		c  = Color(0.055, 0.20, 0.83)
		nc = Color(0.02,  0.03, 0.10)
	var g := Node3D.new()
	add_child(g)
	g.position.x = gx
	_box_c(g, Vector3(0.42, GH, 0.42), Vector3(0.0, GH/2.0, -GZ), c)
	_box_c(g, Vector3(0.42, GH, 0.42), Vector3(0.0, GH/2.0,  GZ), c)
	_box_c(g, Vector3(0.42, 0.42, GZ*2.0+0.42), Vector3(0.0, GH, 0.0), c)
	var rx2: float
	if is_local:
		rx2 = -GD/2.0
	else:
		rx2 = GD/2.0
	_box_c(g, Vector3(GD, 0.42, 0.42), Vector3(rx2, GH, -GZ), c)
	_box_c(g, Vector3(GD, 0.42, 0.42), Vector3(rx2, GH,  GZ), c)
	_box_c(g, Vector3(0.42, GH, GZ*2.0+0.42), Vector3(rx2*2.0, GH/2.0, 0.0), c)
	_box_c(g, Vector3(GD, GH-0.4, GZ*2.0), Vector3(rx2, GH/2.0+0.2, 0.0), nc)

# ── BANDES ──────────────────────────────────────
func _setup_walls() -> void:
	var wc := Color(0.91, 0.93, 0.97)
	var rc := Color(0.67, 0.07, 0.07)
	var wh: float = 3.4
	_add_wall(Vector3(0.0, wh/2.0, -FH/2.0-0.45), Vector3(FW+2.6, wh, 0.9), wc, rc)
	_add_wall(Vector3(0.0, wh/2.0,  FH/2.0+0.45), Vector3(FW+2.6, wh, 0.9), wc, rc)
	_add_wall(Vector3(-FW/2.0-0.45, wh/2.0, 0.0), Vector3(0.9, wh, FH), wc, rc)
	_add_wall(Vector3( FW/2.0+0.45, wh/2.0, 0.0), Vector3(0.9, wh, FH), wc, rc)

func _add_wall(pos: Vector3, sz: Vector3, wc: Color, rc: Color) -> void:
	_box_c(self, sz, pos, wc)
	_box_c(self, Vector3(sz.x+0.1, 0.62, sz.z+0.1),
		Vector3(pos.x, pos.y + sz.y/2.0 - 0.55, pos.z), rc)

# ── JUGADORS ────────────────────────────────────
func _setup_players() -> void:
	for i in range(3):
		var lh: Color
		if i == 0:
			lh = Color(1.0, 0.84, 0.0)
		else:
			lh = Color(0.52, 0.05, 0.05)
		var rh: Color
		if i == 0:
			rh = Color(1.0, 0.84, 0.0)
		else:
			rh = Color(0.03, 0.11, 0.52)
		var ln: Node3D = _make_player(Color(0.78, 0.085, 0.085), Color(0.52, 0.52, 0.52), lh, i == 2)
		ln.position = Vector3(float(lx[i]), 0.0, float(lz[i]))
		ln.rotation.y = -PI / 2.0
		add_child(ln)
		l_nodes.append(ln)
		var rn: Node3D = _make_player(Color(0.055, 0.20, 0.83), Color(0.31, 0.31, 0.31), rh, false)
		rn.position = Vector3(float(rx[i]), 0.0, float(rz[i]))
		rn.rotation.y = PI / 2.0
		add_child(rn)
		r_nodes.append(rn)

func _make_player(jc: Color, sc: Color, hc: Color, is_human: bool) -> Node3D:
	var g := Node3D.new()
	var bk := _mat(Color(0.06, 0.06, 0.06))
	var wm := _mat(Color(0.80, 0.07, 0.07))
	var wt := _mat(Color(1.0, 1.0, 1.0))
	var wd := _mat(Color(0.48, 0.31, 0.09))
	var bd := _mat(Color(0.24, 0.11, 0.03))
	var sk := _mat(Color(0.88, 0.68, 0.51))
	var jm := _mat(jc)
	var sm := _mat(sc)
	var hm := _mat(hc)
	# Patins
	_box_m(g, Vector3(1.55, 0.65, 2.25), Vector3(-0.55, 0.32, 0.0), bk)
	_box_m(g, Vector3(1.55, 0.65, 2.25), Vector3( 0.55, 0.32, 0.0), bk)
	# Rodes
	for sx in [-0.55, 0.55]:
		for sz in [-0.82, -0.28, 0.28, 0.82]:
			var wr := MeshInstance3D.new()
			var cy := CylinderMesh.new()
			cy.top_radius = 0.27
			cy.bottom_radius = 0.27
			cy.height = 0.44
			cy.radial_segments = 8
			wr.mesh = cy
			wr.material_override = wm
			wr.rotation.z = PI/2.0
			wr.position = Vector3(sx, 0.13, sz)
			wr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			g.add_child(wr)
	# Cames
	_box_m(g, Vector3(1.1, 1.85, 1.1), Vector3(-0.52, 1.58, 0.0), sm)
	_box_m(g, Vector3(1.1, 1.85, 1.1), Vector3( 0.52, 1.58, 0.0), sm)
	_box_m(g, Vector3(1.3, 0.9, 1.3),  Vector3(-0.52, 1.15, 0.0), bk)
	_box_m(g, Vector3(1.3, 0.9, 1.3),  Vector3( 0.52, 1.15, 0.0), bk)
	# Torso
	_box_m(g, Vector3(2.45, 2.35, 1.55), Vector3(0.0, 3.68, 0.0), jm)
	_box_m(g, Vector3(2.45, 0.40, 1.58), Vector3(0.0, 3.65, 0.0), wt)
	# Braços
	_box_m(g, Vector3(0.92, 2.05, 0.92), Vector3(-1.68, 3.68, 0.0), jm)
	_box_m(g, Vector3(0.92, 2.05, 0.92), Vector3( 1.68, 3.68, 0.0), jm)
	_box_m(g, Vector3(1.12, 0.88, 1.12), Vector3(-1.68, 2.88, 0.0), bk)
	_box_m(g, Vector3(1.12, 0.88, 1.12), Vector3( 1.68, 2.88, 0.0), bk)
	_box_m(g, Vector3(1.22, 1.12, 1.12), Vector3(-1.68, 2.10, 0.0), bk)
	_box_m(g, Vector3(1.22, 1.12, 1.12), Vector3( 1.68, 2.10, 0.0), bk)
	# Cap
	_box_m(g, Vector3(2.82, 2.45, 2.82), Vector3(0.0, 6.08, 0.0), sk)
	_box_m(g, Vector3(0.62, 0.52, 0.10), Vector3(-0.56, 6.08, -1.46), bk)
	_box_m(g, Vector3(0.62, 0.52, 0.10), Vector3( 0.56, 6.08, -1.46), bk)
	_box_m(g, Vector3(1.02, 0.36, 0.10), Vector3( 0.00, 5.62, -1.46), bk)
	# Casc
	_box_m(g, Vector3(3.24, 2.9, 3.24), Vector3(0.0, 6.10, 0.0), hm)
	var hbr := _mat(Color(minf(hc.r+0.12, 1.0), minf(hc.g+0.12, 1.0), minf(hc.b+0.12, 1.0)))
	_box_m(g, Vector3(3.24, 0.50, 3.26), Vector3(0.0, 4.88, 0.0), hbr)
	_box_m(g, Vector3(2.55, 1.88, 0.13), Vector3(0.0, 5.90, -1.685), bk)
	for bv in [-0.88, -0.30, 0.30, 0.88]:
		_box_m(g, Vector3(0.22, 1.88, 0.15), Vector3(bv, 5.90, -1.685), _mat(Color(0.2, 0.2, 0.2)))
	# Estic
	var stk := _box_m(g, Vector3(0.55, 4.85, 0.55), Vector3(1.72, 2.55, 0.0), wd)
	stk.rotation.z = -0.22
	_box_m(g, Vector3(0.42, 0.42, 2.25), Vector3(2.0, 0.40, 0.90), bd)
	# Anell humà
	if is_human:
		var rm := MeshInstance3D.new()
		var tmesh := TorusMesh.new()
		tmesh.outer_radius = 1.92
		tmesh.inner_radius = 1.74
		tmesh.rings = 40
		tmesh.ring_segments = 8
		rm.mesh = tmesh
		rm.material_override = _mat(Color(1.0, 0.84, 0.0))
		rm.rotation.x = -PI/2.0
		rm.position.y = 0.12
		rm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(rm)
	# Ombra
	var sh := MeshInstance3D.new()
	var shm := CylinderMesh.new()
	shm.top_radius = 1.65
	shm.bottom_radius = 1.65
	shm.height = 0.04
	shm.radial_segments = 20
	sh.mesh = shm
	var shmat := StandardMaterial3D.new()
	shmat.albedo_color = Color(0.04, 0.03, 0.02, 0.38)
	shmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sh.material_override = shmat
	sh.position.y = 0.012
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(sh)
	return g

# ── PILOTA ──────────────────────────────────────
func _setup_ball() -> void:
	ball_node = Node3D.new()
	var bmi := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = BR
	bm.height = BR*2.0
	bm.radial_segments = 18
	bm.rings = 12
	bmi.mesh = bm
	bmi.material_override = _mat(Color(1.0, 0.43, 0.03))
	ball_node.add_child(bmi)
	add_child(ball_node)

# ── FLETXA AIM ──────────────────────────────────
func _setup_aim() -> void:
	aim_group = Node3D.new()
	for i in range(1, 11):
		var t: float = float(i) / 10.0
		var col: Color
		if t < 0.4:
			col = Color(0.13, 0.85, 0.24)
		elif t < 0.7:
			col = Color(1.0, 0.76, 0.08)
		else:
			col = Color(1.0, 0.17, 0.11)
		var disc := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.52 - float(i)*0.022
		cy.bottom_radius = cy.top_radius
		cy.height = 0.09
		cy.radial_segments = 14
		disc.mesh = cy
		disc.material_override = _mat(col)
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		disc.position = Vector3(float(i) * 1.65, 0.09, 0.0)
		aim_group.add_child(disc)
	var tip := _box_m(aim_group, Vector3(1.2, 0.12, 1.2), Vector3(17.8, 0.09, 0.0), _mat(Color(1.0, 0.89, 0.11)))
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aim_group.visible = false
	add_child(aim_group)

# ── AURA ────────────────────────────────────────
func _setup_aura() -> void:
	aura_node = Node3D.new()
	var rm1 := MeshInstance3D.new()
	var t1 := TorusMesh.new()
	t1.outer_radius = 2.0
	t1.inner_radius = 1.82
	t1.rings = 44
	t1.ring_segments = 8
	rm1.mesh = t1
	rm1.material_override = _mat(Color(0.21, 0.76, 1.0))
	rm1.rotation.x = -PI/2.0
	rm1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura_node.add_child(rm1)
	aura_node.position.y = 0.12
	aura_node.visible = false
	add_child(aura_node)

# ── CAMERA ──────────────────────────────────────
func _setup_camera() -> void:
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.1
	cam.far = 180.0
	cam.position = Vector3(-20.0, 12.0, 0.0)
	cam.look_at(Vector3(5.0, 1.5, 0.0))
	add_child(cam)

func _update_camera() -> void:
	var px: float = float(lx[2])
	var pz: float = float(lz[2])
	var rad: float = cam_angle * PI / 180.0
	var offx: float = -cos(rad) * 20.0
	var offz: float = -sin(rad) * 20.0
	cam_x = lerp(cam_x, px + offx, 0.07)
	cam_z = lerp(cam_z, pz + offz, 0.07)
	cam.position = Vector3(cam_x, 12.0, cam_z)
	cam.look_at(Vector3(px + cos(rad)*5.0, 1.5, pz + sin(rad)*5.0), Vector3.UP)

# ── UI ──────────────────────────────────────────
func _setup_ui() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	var hud := ColorRect.new()
	hud.color = Color(0.053, 0.09, 0.19, 0.96)
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud.custom_minimum_size = Vector2(0.0, 70.0)
	cl.add_child(hud)
	lbl_sl = _lbl("0", 44, Color(1,1,1))
	lbl_sl.position = Vector2(20.0, 8.0)
	hud.add_child(lbl_sl)
	lbl_sr = _lbl("0", 44, Color(1,1,1))
	lbl_sr.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	lbl_sr.position = Vector2(-100.0, 8.0)
	hud.add_child(lbl_sr)
	var nl := _lbl("★  ARENYS HC", 12, Color(0.87, 0.12, 0.12))
	nl.position = Vector2(20.0, -2.0)
	hud.add_child(nl)
	var nr := _lbl("RIVALS FC  ★", 12, Color(0.06, 0.25, 0.79))
	nr.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	nr.position = Vector2(-165.0, -2.0)
	hud.add_child(nr)
	lbl_time = _lbl("2:00", 34, Color(0.60, 0.67, 0.81))
	lbl_time.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	lbl_time.position = Vector2(-60.0, 5.0)
	hud.add_child(lbl_time)
	lbl_msg = _lbl("EL TEU TORN", 10, Color(1.0, 0.86, 0.19))
	lbl_msg.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	lbl_msg.position = Vector2(-220.0, 44.0)
	hud.add_child(lbl_msg)
	var ctrl := ColorRect.new()
	ctrl.color = Color(0.02, 0.03, 0.06, 0.96)
	ctrl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	ctrl.custom_minimum_size = Vector2(0.0, 68.0)
	cl.add_child(ctrl)
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_theme_constant_override("separation", 8)
	ctrl.add_child(bar)
	btn_n = _btn("⬛ NORMAL [Q]",  Color(0.09, 0.31, 0.08), true)
	btn_c = _btn("↩ EFECTE  [W]", Color(0.35, 0.25, 0.05), false)
	btn_p = _btn("⚡ FORT    [E]", Color(0.38, 0.08, 0.08), false)
	var b_pass := _btn("➡ PASSAR  [P]", Color(0.06, 0.21, 0.38), false)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b_rew := _btn("↩ REWIND×3[R]", Color(0.24, 0.16, 0.04), false)
	var b_shoot := _btn("🏒  TIRA! [SPC]", Color(0.10, 0.35, 0.09), false)
	b_shoot.custom_minimum_size = Vector2(144.0, 48.0)
	b_shoot.add_theme_font_size_override("font_size", 14)
	btn_n.pressed.connect(func(): _set_shot("n"))
	btn_c.pressed.connect(func(): _set_shot("c"))
	btn_p.pressed.connect(func(): _set_shot("p"))
	b_pass.pressed.connect(func(): do_pass())
	b_rew.pressed.connect(func(): do_rewind())
	b_shoot.pressed.connect(func(): do_shoot())
	bar.add_child(btn_n)
	bar.add_child(btn_c)
	bar.add_child(btn_p)
	bar.add_child(b_pass)
	bar.add_child(sp)
	bar.add_child(b_rew)
	bar.add_child(b_shoot)
	var pw_bg := ColorRect.new()
	pw_bg.color = Color(1.0, 1.0, 1.0, 0.12)
	pw_bg.custom_minimum_size = Vector2(14.0, 110.0)
	pw_bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	pw_bg.position = Vector2(22.0, -185.0)
	pw_bg.visible = false
	cl.add_child(pw_bg)
	pw_fill = ColorRect.new()
	pw_fill.color = Color(0.14, 0.86, 0.24)
	pw_fill.size = Vector2(14.0, 66.0)
	pw_fill.position = Vector2(0.0, 44.0)
	pw_bg.add_child(pw_fill)

func _lbl(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _btn(text: String, bg: Color, active: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.custom_minimum_size = Vector2(104.0, 44.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 7
	sb.corner_radius_top_right = 7
	sb.corner_radius_bottom_left = 7
	sb.corner_radius_bottom_right = 7
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	if active:
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_color = Color(1.0, 1.0, 1.0, 0.65)
	b.add_theme_stylebox_override("normal", sb)
	b.focus_mode = Control.FOCUS_NONE
	return b

# ── INPUT ───────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				mouse_down = true
				ms_x = mb.position.x
				ms_y = mb.position.y
				ms_ang = aim_ang
				ms_pow = aim_pow
				did_drag = false
			else:
				mouse_down = false
				if did_drag:
					if phase == Phase.MY_TURN and human_ball:
						do_shoot()
				else:
					_move_click(mb.position)
				did_drag = false
	elif event is InputEventMouseMotion:
		if mouse_down:
			var mm := event as InputEventMouseMotion
			var dx: float = mm.position.x - ms_x
			var dy: float = mm.position.y - ms_y
			var dd: float = sqrt(dx*dx + dy*dy)
			if dd > 8.0 and phase == Phase.MY_TURN and human_ball:
				did_drag = true
				aim_ang = ms_ang + dx * 0.026
				aim_pow = clampf(ms_pow - dy / 185.0, 0.05, 1.0)
				_update_power_bar()
	elif event is InputEventKey:
		if event.pressed:
			match event.keycode:
				KEY_Q: _set_shot("n")
				KEY_W: _set_shot("c")
				KEY_E: _set_shot("p")
				KEY_P: do_pass()
				KEY_R: do_rewind()
				KEY_SPACE: do_shoot()
				KEY_ENTER: do_shoot()
				KEY_A:
					if phase == Phase.MY_TURN:
						ltx[2] = clampf(float(lx[2]) - 5.0, -FW/2.0+1.4, FW/2.0-1.4)
						ltz[2] = float(lz[2])
				KEY_D:
					if phase == Phase.MY_TURN:
						ltx[2] = clampf(float(lx[2]) + 5.0, -FW/2.0+1.4, FW/2.0-1.4)
						ltz[2] = float(lz[2])
				KEY_S:
					if phase == Phase.MY_TURN:
						ltx[2] = float(lx[2])
						ltz[2] = clampf(float(lz[2]) + 5.0, -FH/2.0+0.8, FH/2.0-0.8)
				KEY_F:
					if phase == Phase.MY_TURN:
						ltx[2] = float(lx[2])
						ltz[2] = clampf(float(lz[2]) - 5.0, -FH/2.0+0.8, FH/2.0-0.8)
				KEY_LEFT:  cam_angle = fmod(cam_angle - 22.0 + 360.0, 360.0)
				KEY_RIGHT: cam_angle = fmod(cam_angle + 22.0, 360.0)
				KEY_UP:    cam_angle = 0.0
				KEY_DOWN:  cam_angle = 180.0

func _move_click(screen_pos: Vector2) -> void:
	if phase != Phase.MY_TURN:
		return
	var ray_o: Vector3 = cam.project_ray_origin(screen_pos)
	var ray_d: Vector3 = cam.project_ray_normal(screen_pos)
	if abs(ray_d.y) < 0.001:
		return
	var t: float = -ray_o.y / ray_d.y
	if t < 0.0:
		return
	var wp: Vector3 = ray_o + ray_d * t
	var ddx: float = wp.x - float(lx[2])
	var ddz: float = wp.z - float(lz[2])
	var dd: float = sqrt(ddx*ddx + ddz*ddz)
	if dd > 0.2:
		var cap: float = 14.0
		if dd > cap:
			ddx = ddx/dd*cap
			ddz = ddz/dd*cap
		ltx[2] = clampf(float(lx[2])+ddx, -FW/2.0+1.4, FW/2.0-1.4)
		ltz[2] = clampf(float(lz[2])+ddz, -FH/2.0+0.8, FH/2.0-0.8)

func _update_power_bar() -> void:
	if pw_fill == null:
		return
	var h: float = aim_pow * 110.0
	pw_fill.size.y = h
	pw_fill.position.y = 110.0 - h
	if aim_pow < 0.4:
		pw_fill.color = Color(0.14, 0.86, 0.24)
	elif aim_pow < 0.7:
		pw_fill.color = Color(1.0, 0.76, 0.08)
	else:
		pw_fill.color = Color(1.0, 0.17, 0.11)

# ── ACCIONS ─────────────────────────────────────
func do_shoot() -> void:
	if phase != Phase.MY_TURN or not human_ball:
		return
	sv_bx = bx; sv_bz = bz; sv_hx = float(lx[2]); sv_hz = float(lz[2])
	human_ball = false
	ball_free = true
	var speed_val: float
	if shot == "n":
		speed_val = 36.0
	elif shot == "c":
		speed_val = 28.0
	else:
		speed_val = 52.0
	var spd: float = 70.0 + aim_pow * (speed_val - 70.0)
	bvx = cos(aim_ang) * spd
	bvz = sin(aim_ang) * spd
	if shot == "c":
		cfx = -sin(aim_ang) * 8.0
		cfz =  cos(aim_ang) * 8.0
	else:
		cfx = 0.0
		cfz = 0.0
	_set_phase(Phase.SHOOTING)

func do_pass() -> void:
	if phase != Phase.MY_TURN or not human_ball:
		return
	var d0: float = _d2(float(lx[0]), float(lz[0]), float(lx[2]), float(lz[2]))
	var d1: float = _d2(float(lx[1]), float(lz[1]), float(lx[2]), float(lz[2]))
	var t: int
	if d0 < d1:
		t = 0
	else:
		t = 1
	human_ball = false
	ball_free = true
	cfx = 0.0
	cfz = 0.0
	var dx: float = float(lx[t]) - bx
	var dz: float = float(lz[t]) - bz
	var dd: float = sqrt(dx*dx + dz*dz)
	if dd < 0.1:
		human_ball = true
		ball_free = false
		return
	bvx = dx/dd * 28.0
	bvz = dz/dd * 28.0
	_set_phase(Phase.SHOOTING)

func do_rewind() -> void:
	if rewinds <= 0 or phase == Phase.MY_TURN:
		return
	rewinds -= 1
	human_ball = true
	ball_free = false
	bx = sv_bx; bz = sv_bz; bvx = 0.0; bvz = 0.0; cfx = 0.0; cfz = 0.0
	lx[2] = sv_hx; lz[2] = sv_hz; ltx[2] = sv_hx; ltz[2] = sv_hz
	_set_phase(Phase.MY_TURN)

func _set_shot(t: String) -> void:
	shot = t

func _set_phase(p: Phase) -> void:
	phase = p
	match p:
		Phase.MY_TURN:
			lbl_msg.text = "EL TEU TORN – Arrossega per apuntar"
			lbl_msg.add_theme_color_override("font_color", Color(1.0, 0.86, 0.19))
		Phase.SHOOTING:
			lbl_msg.text = "LLANÇAMENT..."
			lbl_msg.add_theme_color_override("font_color", Color(1.0, 0.54, 0.17))
		Phase.AI_TURN:
			lbl_msg.text = "TORN RIVAL"
			lbl_msg.add_theme_color_override("font_color", Color(0.27, 0.51, 1.0))
			ai_delay = 0.6 + randf() * 0.7
		Phase.GOAL:
			aim_group.visible = false
		Phase.OVER:
			aim_group.visible = false

# ── INIT ────────────────────────────────────────
func _init_pos(local_kick: bool) -> void:
	lx = [-(FW/2.0 - 4.2), -13.0, -4.4]
	lz = [0.0, 0.0, 0.0]
	ltx = [lx[0], lx[1], lx[2]]
	ltz = [lz[0], lz[1], lz[2]]
	rx = [FW/2.0 - 4.2, 13.0, 4.4]
	rz = [0.0, 0.0, 0.0]
	rtx = [rx[0], rx[1], rx[2]]
	rtz = [rz[0], rz[1], rz[2]]
	human_ball = false
	rival_ball = false
	r_holder = -1
	bvx = 0.0; bvz = 0.0; cfx = 0.0; cfz = 0.0; ball_free = false
	aim_ang = 0.0; aim_pow = 0.6; ai_delay = 0.0
	if local_kick:
		human_ball = true
		bx = float(lx[2]) + 1.8
		bz = 0.0
		_set_phase(Phase.MY_TURN)
	else:
		rival_ball = true
		r_holder = 2
		bx = float(rx[2]) - 1.8
		bz = 0.0
		ai_delay = 0.5
		phase = Phase.AI_TURN
		lbl_msg.text = "TORN RIVAL"
		lbl_msg.add_theme_color_override("font_color", Color(0.27, 0.51, 1.0))

# ── GAME LOOP ────────────────────────────────────
func _process(delta: float) -> void:
	if phase == Phase.OVER:
		_sync(); _update_camera(); return
	if phase == Phase.GOAL:
		goal_delay -= delta
		if goal_delay <= 0.0 and init_after_goal:
			init_after_goal = false
			_init_pos(local_kick_next)
		_sync(); _update_camera(); return
	if phase != Phase.GOAL:
		time_left = maxf(0.0, time_left - delta)
		var m: int = int(time_left / 60.0)
		var s: int = int(fmod(time_left, 60.0))
		lbl_time.text = "%d:%02d" % [m, s]
		if time_left <= 0.0:
			_set_phase(Phase.OVER)
			_on_over()
	if phase == Phase.AI_TURN and ai_delay > 0.0:
		ai_delay -= delta
		if ai_delay <= 0.0:
			_ai_shoot()
	_tick_ball(delta)
	_tick_ai(delta)
	_check_goal()
	_sync()
	_update_camera()
	aura_time += delta

# ── FÍSICA PILOTA ────────────────────────────────
func _tick_ball(dt: float) -> void:
	if human_ball and phase == Phase.MY_TURN:
		bx = float(lx[2]) + 1.8
		bz = float(lz[2])
		bvx = 0.0; bvz = 0.0; return
	if rival_ball and r_holder >= 0:
		bx = float(rx[r_holder]) - 1.8
		bz = float(rz[r_holder])
		bvx = 0.0; bvz = 0.0; return
	if not ball_free:
		return
	if shot == "c":
		bvx += cfx*dt; bvz += cfz*dt
		var dc: float = pow(0.88, dt*60.0)
		cfx *= dc; cfz *= dc
	bx += bvx*dt; bz += bvz*dt
	var fr: float = pow(FRIC, dt*60.0)
	bvx *= fr; bvz *= fr
	var wx: float = FW/2.0 + 0.2 - BR
	var wz: float = FH/2.0 + 0.2 - BR
	if abs(bx) > wx:
		bvx *= -0.65; bx = sign(bx)*wx
	if abs(bz) > wz:
		bvz *= -0.65; bz = sign(bz)*wz
	var bs: float = sqrt(bvx*bvx + bvz*bvz)
	if _d2(bx, bz, float(lx[0]), float(lz[0])) < 1.4 and bs > 1.5:
		bvx *= -0.52; bvz += (randf()-0.5)*11.0; _clamp_ball(13.0)
	if _d2(bx, bz, float(rx[0]), float(rz[0])) < 1.4 and bs > 1.5:
		bvx *= -0.52; bvz += (randf()-0.5)*11.0; _clamp_ball(13.0)
	if phase == Phase.SHOOTING:
		for i in range(3):
			if _d2(bx, bz, float(lx[i]), float(lz[i])) < 1.25:
				ball_free = false
				if i == 2:
					human_ball = true
					_set_phase(Phase.MY_TURN)
				else:
					var tw := create_tween()
					tw.tween_callback(func():
						human_ball = true
						bx = float(lx[2]) + 1.8
						bz = float(lz[2])
						_set_phase(Phase.MY_TURN)
					).set_delay(0.35)
				return
		for i in range(3):
			if _d2(bx, bz, float(rx[i]), float(rz[i])) < 1.25:
				ball_free = false; rival_ball = true; r_holder = i
				_set_phase(Phase.AI_TURN); return
		if sqrt(bvx*bvx + bvz*bvz) < 0.7:
			ball_free = false; human_ball = true
			bx = float(lx[2]) + 1.8; bz = float(lz[2])
			_set_phase(Phase.MY_TURN)

func _clamp_ball(mx: float) -> void:
	var s: float = sqrt(bvx*bvx + bvz*bvz)
	if s > 0.0 and s < mx:
		bvx = bvx/s*mx; bvz = bvz/s*mx

# ── IA ──────────────────────────────────────────
func _tick_ai(dt: float) -> void:
	_mv(lx, lz, ltx, ltz, 0, -(FW/2.0-4.2), clampf(bz, -GZ+0.5, GZ-0.5), 12.5, dt)
	var dftx: float
	if phase != Phase.MY_TURN:
		dftx = clampf(float(rx[2])-7.5, -FW/2.0+5.5, -0.5)
	else:
		dftx = -11.0
	_mv(lx, lz, ltx, ltz, 1, dftx, bz*0.38, 14.0, dt)
	if phase != Phase.MY_TURN:
		_mv(lx, lz, ltx, ltz, 2, bx-2.2, bz, 16.5, dt)
	else:
		var ddx: float = float(ltx[2]) - float(lx[2])
		var ddz: float = float(ltz[2]) - float(lz[2])
		var dd: float = sqrt(ddx*ddx + ddz*ddz)
		if dd > 0.1:
			var s: float = minf(19.0*dt, dd)
			lx[2] = float(lx[2]) + ddx/dd*s
			lz[2] = float(lz[2]) + ddz/dd*s
		lx[2] = clampf(float(lx[2]), -FW/2.0+1.4, FW/2.0-1.4)
		lz[2] = clampf(float(lz[2]), -FH/2.0+0.8, FH/2.0-0.8)
	_mv(rx, rz, rtx, rtz, 0, FW/2.0-4.2, clampf(bz, -GZ+0.5, GZ-0.5), 12.5, dt)
	var rdfx: float = maxf(2.5, float(lx[2])+5.5+sin(Time.get_unix_time_from_system()*0.002)*2.2)
	_mv(rx, rz, rtx, rtz, 1, rdfx, float(lz[2])*0.5, 13.6, dt)
	if phase == Phase.AI_TURN and rival_ball and r_holder == 2:
		var tx: float = -(FW/2.0-9.4)
		var tz: float = sin(Time.get_unix_time_from_system()*0.00082)*5.5
		_mv(rx, rz, rtx, rtz, 2, tx, tz, 15.2, dt)
	elif not rival_ball:
		_mv(rx, rz, rtx, rtz, 2, maxf(1.8, bx+2.6), bz*0.75, 14.0, dt)

func _mv(x: Array, z: Array, tx: Array, tz: Array, i: int,
		ttx: float, ttz: float, spd: float, dt: float) -> void:
	tx[i] = ttx; tz[i] = ttz
	var dx: float = float(tx[i]) - float(x[i])
	var dz: float = float(tz[i]) - float(z[i])
	var dd: float = sqrt(dx*dx + dz*dz)
	if dd > 0.1:
		var s: float = minf(spd*dt, dd)
		x[i] = float(x[i]) + dx/dd*s
		z[i] = float(z[i]) + dz/dd*s
	x[i] = clampf(float(x[i]), -FW/2.0+1.2, FW/2.0-1.2)
	z[i] = clampf(float(z[i]), -FH/2.0+0.8, FH/2.0-0.8)

func _ai_shoot() -> void:
	if phase != Phase.AI_TURN or not rival_ball:
		return
	rival_ball = false; ball_free = true; cfx = 0.0; cfz = 0.0
	var tx: float = -(FW/2.0) - bx
	var tz: float = (randf()-0.5)*GZ*1.5 - bz
	var dd: float = sqrt(tx*tx + tz*tz)
	bvx = tx/dd * (24.0 + randf()*19.5)
	bvz = tz/dd * (24.0 + randf()*19.5)
	phase = Phase.SHOOTING
	lbl_msg.text = "LLANÇAMENT RIVAL!"
	lbl_msg.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))

# ── GOL ─────────────────────────────────────────
func _check_goal() -> void:
	if phase == Phase.GOAL or phase == Phase.OVER:
		return
	if bx < -(FW/2.0 + 0.7) and abs(bz) < GZ:
		_on_goal(false)
	if bx > FW/2.0 + 0.7 and abs(bz) < GZ:
		_on_goal(true)

func _on_goal(local_scored: bool) -> void:
	if local_scored:
		score_l += 1
	else:
		score_r += 1
	lbl_sl.text = str(score_l)
	lbl_sr.text = str(score_r)
	if local_scored:
		lbl_msg.text = "GOL!  ARENYS HC!"
		lbl_msg.add_theme_color_override("font_color", Color(1.0, 0.87, 0.20))
	else:
		lbl_msg.text = "GOL!  RIVALS FC!"
		lbl_msg.add_theme_color_override("font_color", Color(1.0, 0.27, 0.27))
	phase = Phase.GOAL
	ball_free = false; bvx = 0.0; bvz = 0.0
	human_ball = false; rival_ball = false; r_holder = -1
	aim_group.visible = false
	goal_delay = 2.2
	init_after_goal = true
	local_kick_next = not local_scored

func _on_over() -> void:
	if score_l > score_r:
		lbl_msg.text = "VICTORIA!  %d - %d" % [score_l, score_r]
	elif score_r > score_l:
		lbl_msg.text = "DERROTA!  %d - %d" % [score_l, score_r]
	else:
		lbl_msg.text = "EMPAT!  %d - %d" % [score_l, score_r]
	lbl_msg.add_theme_color_override("font_color", Color(1.0, 0.87, 0.20))

# ── SYNC ────────────────────────────────────────
func _sync() -> void:
	for i in range(3):
		var ln: Node3D = l_nodes[i]
		ln.position = Vector3(float(lx[i]), 0.0, float(lz[i]))
		var rn: Node3D = r_nodes[i]
		rn.position = Vector3(float(rx[i]), 0.0, float(rz[i]))
	ball_node.position = Vector3(bx, BR, bz)
	aura_node.position = Vector3(float(lx[2]), 0.12, float(lz[2]))
	aura_node.visible = (phase == Phase.MY_TURN)
	if aura_node.visible:
		var sc: float = 1.0 + sin(aura_time * 2.2) * 0.18
		aura_node.scale = Vector3(sc, 1.0, sc)
	var show_aim: bool = phase == Phase.MY_TURN and human_ball
	aim_group.visible = show_aim
	if show_aim:
		aim_group.position = Vector3(bx, 0.0, bz)
		aim_group.rotation.y = -aim_ang
		aim_group.scale.x = 0.25 + aim_pow * 0.75
		if pw_fill != null and pw_fill.get_parent() != null:
			pw_fill.get_parent().visible = true
	else:
		if pw_fill != null and pw_fill.get_parent() != null:
			pw_fill.get_parent().visible = false

# ── HELPERS ─────────────────────────────────────
func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.88
	return m

func _box_c(parent: Node, sz: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	return _box_m(parent, sz, pos, _mat(col))

func _box_m(parent: Node, sz: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _d2(x1: float, z1: float, x2: float, z2: float) -> float:
	return sqrt((x1-x2)*(x1-x2) + (z1-z2)*(z1-z2))
