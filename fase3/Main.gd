extends Node3D
## HOQUEI PATINS 3D – Pol Hernáez (DAM1) – Godot 4.6
##
## INVESTIGACIÓ GAME DESIGN (per que MSS funciona):
## 1. Torn-based pur: quan és el teu torn TOT s'atura excepte tu
## 2. GK batible: reacció lenta + radi petit = finestra de gol real
## 3. Rivals imperfectes: xuten cap a posicions aproximades, no perfectes
## 4. Pilota va al jugador MÉS PROPER quan s'atura (no sempre al humà)
## 5. FW rival es posa en posició i espera (no persegueix infinitament)

# ── CONSTANTS (afinades per jugabilitat) ─────────
const FW: float = 56.0    # camp més gran → més espai
const FH: float = 28.0
const GZ: float = 5.5     # porteria més gran → es pot marcar gol
const GD: float = 3.2
const GH: float = 4.0
const BR: float = 0.48    # pilota lleugerament més gran
const FRIC: float = 0.991

const SPD_N: float = 32.0  # normal
const SPD_C: float = 24.0  # corba
const SPD_P: float = 50.0  # fort

# GK: LENT i IMPERFECTE → es pot marcar gol
const GK_SPD: float = 5.5      # velocitat màxima del GK (u/s)
const GK_RADIUS: float = 0.55  # radi de parada (petit = finestra de gol)
const GK_REACT: float = 0.25   # delay de reacció del GK (segons)

# ── ESTAT ─────────────────────────────────────────
enum Phase { MY_TURN, SHOOTING, AI_TURN, GOAL, OVER }
var phase: Phase = Phase.MY_TURN
var shot: String = "n"

# Posicions [0=GK, 1=DEF, 2=FW]
var lx: Array = [0.0, 0.0, 0.0]
var lz: Array = [0.0, 0.0, 0.0]
var rx: Array = [0.0, 0.0, 0.0]
var rz: Array = [0.0, 0.0, 0.0]
# Targets
var ltx: Array = [0.0, 0.0, 0.0]
var ltz: Array = [0.0, 0.0, 0.0]
var rtx: Array = [0.0, 0.0, 0.0]
var rtz: Array = [0.0, 0.0, 0.0]

# GK: delay de reacció → no segueix la pilota immediatament
var lgk_react_timer: float = 0.0  # GK local
var rgk_react_timer: float = 0.0  # GK rival
var lgk_target_z: float = 0.0
var rgk_target_z: float = 0.0

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
var aim_pow: float = 0.65
var score_l: int = 0
var score_r: int = 0
var rewinds: int = 3
var time_left: float = 120.0

var sv_bx: float = 0.0
var sv_bz: float = 0.0
var sv_hx: float = 0.0
var sv_hz: float = 0.0

var ai_delay: float = 0.0
var ai_shoot_timer: float = 0.0  # temps que la IA espera a la posició
var ai_in_position: bool = false

var goal_delay: float = 0.0
var init_after_goal: bool = false
var local_kick_next: bool = false
var in_menu: bool = true

# just_shot: temps en que la pilota NO pot ser recollida
var just_shot_timer: float = 0.0

# ── NODES ─────────────────────────────────────────
var l_nodes: Array = []
var r_nodes: Array = []
var ball_node: Node3D
var aim_group: Node3D
var aura_node: Node3D
var cam: Camera3D
var cam_angle: float = 0.0
var cam_x: float = -25.0
var cam_z: float = 0.0
var aura_time: float = 0.0

var lbl_sl: Label
var lbl_sr: Label
var lbl_time: Label
var lbl_msg: Label
var pw_fill: ColorRect
var menu_layer: CanvasLayer
var result_layer: CanvasLayer

var mouse_down: bool = false
var ms_x: float = 0.0
var ms_y: float = 0.0
var ms_ang: float = 0.0
var ms_pow: float = 0.65
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
	_setup_menu()
	_setup_result()

func _process(delta: float) -> void:
	if in_menu:
		return

	if phase == Phase.OVER:
		_sync()
		_update_cam()
		return

	if phase == Phase.GOAL:
		goal_delay -= delta
		if goal_delay <= 0.0 and init_after_goal:
			init_after_goal = false
			_init_pos(local_kick_next)
		_sync()
		_update_cam()
		return

	# Timer de partida
	if phase != Phase.GOAL:
		time_left = maxf(0.0, time_left - delta)
		var m: int = int(time_left / 60.0)
		var s: int = int(fmod(time_left, 60.0))
		lbl_time.text = "%d:%02d" % [m, s]
		if time_left <= 0.0:
			_set_phase(Phase.OVER)
			_on_over()

	# just_shot countdown
	if just_shot_timer > 0.0:
		just_shot_timer -= delta

	# IA: timer simple - quan expira, xuta
	if phase == Phase.AI_TURN:
		if ai_delay > 0.0:
			ai_delay -= delta
		else:
			if rival_ball and r_holder >= 0:
				_ai_do_shoot()

	_tick_ball(delta)
	_tick_players(delta)
	_check_goal()
	_sync()
	_update_cam()
	aura_time += delta

# ── ENVIRONMENT ───────────────────────────────────
func _setup_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.016, 0.024, 0.055)
	env.ambient_light_color = Color(0.65, 0.65, 0.65)
	env.ambient_light_energy = 1.0
	env.fog_enabled = true
	env.fog_density = 0.013
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

# ── CAMP ──────────────────────────────────────────
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

	_decal(0.0, 0.0, 0.12, FH, Color(0.10, 0.25, 0.83))
	_decal(-FW/4.0, 0.0, 0.12, FH, Color(0.74, 0.10, 0.10))
	_decal( FW/4.0, 0.0, 0.12, FH, Color(0.74, 0.10, 0.10))

	var ci := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.outer_radius = 4.0; tm.inner_radius = 3.8
	tm.rings = 52; tm.ring_segments = 8
	ci.mesh = tm
	ci.material_override = _mat(Color(0.10, 0.25, 0.83))
	ci.rotation.x = -PI / 2.0
	ci.position.y = 0.018
	ci.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ci)

	_dot(Vector3(0.0, 0.018, 0.0), 0.32, Color(0.74, 0.10, 0.10))
	for pos: Vector3 in [
		Vector3(-FW/4.0, 0.018, -FH/3.5), Vector3(-FW/4.0, 0.018, FH/3.5),
		Vector3( FW/4.0, 0.018, -FH/3.5), Vector3( FW/4.0, 0.018, FH/3.5)
	]:
		_dot(pos, 0.30, Color(0.74, 0.10, 0.10))

func _decal(x: float, z: float, w: float, h: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(w, h)
	mi.mesh = pm; mi.material_override = _mat(col)
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

# ── PORTERIES ─────────────────────────────────────
func _setup_goals() -> void:
	_make_goal(-FW/2.0, true)
	_make_goal( FW/2.0, false)

func _make_goal(gx: float, is_local: bool) -> void:
	var c: Color
	var nc: Color
	if is_local:
		c = Color(0.80, 0.085, 0.085); nc = Color(0.10, 0.02, 0.02)
	else:
		c = Color(0.055, 0.20, 0.83);  nc = Color(0.02, 0.03, 0.10)
	var g := Node3D.new(); add_child(g); g.position.x = gx
	_box_c(g, Vector3(0.42, GH, 0.42), Vector3(0.0, GH/2.0, -GZ), c)
	_box_c(g, Vector3(0.42, GH, 0.42), Vector3(0.0, GH/2.0,  GZ), c)
	_box_c(g, Vector3(0.42, 0.42, GZ*2.0+0.42), Vector3(0.0, GH, 0.0), c)
	var rx2: float = -GD/2.0 if is_local else GD/2.0
	_box_c(g, Vector3(GD, 0.42, 0.42), Vector3(rx2, GH, -GZ), c)
	_box_c(g, Vector3(GD, 0.42, 0.42), Vector3(rx2, GH,  GZ), c)
	_box_c(g, Vector3(0.42, GH, GZ*2.0+0.42), Vector3(rx2*2.0, GH/2.0, 0.0), c)
	# Xarxa semitransparent (visual only, no física)
	var net_mi := MeshInstance3D.new()
	var net_bm := BoxMesh.new()
	net_bm.size = Vector3(GD, GH-0.4, GZ*2.0)
	net_mi.mesh = net_bm
	var net_mat := StandardMaterial3D.new()
	net_mat.albedo_color = nc
	net_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	net_mat.albedo_color.a = 0.25  # quasi transparent
	net_mi.material_override = net_mat
	net_mi.position = Vector3(rx2, GH/2.0+0.2, 0.0)
	net_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(net_mi)

# ── BANDES ────────────────────────────────────────
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

# ── JUGADORS ──────────────────────────────────────
func _setup_players() -> void:
	for i in range(3):
		var lh: Color = Color(1.0, 0.84, 0.0) if i == 0 else Color(0.52, 0.05, 0.05)
		var rh: Color = Color(1.0, 0.84, 0.0) if i == 0 else Color(0.03, 0.11, 0.52)
		var ln: Node3D = _make_player(Color(0.78, 0.085, 0.085), Color(0.52, 0.52, 0.52), lh, i == 2)
		ln.rotation.y = -PI / 2.0
		add_child(ln); l_nodes.append(ln)
		var rn: Node3D = _make_player(Color(0.055, 0.20, 0.83), Color(0.31, 0.31, 0.31), rh, false)
		rn.rotation.y = PI / 2.0
		add_child(rn); r_nodes.append(rn)

func _make_player(jc: Color, sc: Color, hc: Color, is_human: bool) -> Node3D:
	var g := Node3D.new()
	var bk := _mat(Color(0.06, 0.06, 0.06))
	var wm := _mat(Color(0.80, 0.07, 0.07))
	var wt := _mat(Color(1.0, 1.0, 1.0))
	var wd := _mat(Color(0.48, 0.31, 0.09))
	var bd := _mat(Color(0.24, 0.11, 0.03))
	var sk := _mat(Color(0.88, 0.68, 0.51))
	var jm := _mat(jc); var sm := _mat(sc); var hm := _mat(hc)
	# Patins
	_box_m(g, Vector3(1.55, 0.65, 2.25), Vector3(-0.55, 0.32, 0.0), bk)
	_box_m(g, Vector3(1.55, 0.65, 2.25), Vector3( 0.55, 0.32, 0.0), bk)
	for sx in [-0.55, 0.55]:
		for sz in [-0.82, -0.28, 0.28, 0.82]:
			var wr := MeshInstance3D.new()
			var cy := CylinderMesh.new()
			cy.top_radius = 0.27; cy.bottom_radius = 0.27; cy.height = 0.44; cy.radial_segments = 8
			wr.mesh = cy; wr.material_override = wm
			wr.rotation.z = PI/2.0; wr.position = Vector3(sx, 0.13, sz)
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
	var hbr := _mat(Color(minf(hc.r+0.12,1.0), minf(hc.g+0.12,1.0), minf(hc.b+0.12,1.0)))
	_box_m(g, Vector3(3.24, 0.50, 3.26), Vector3(0.0, 4.88, 0.0), hbr)
	_box_m(g, Vector3(2.55, 1.88, 0.13), Vector3(0.0, 5.90, -1.685), bk)
	for bv in [-0.88, -0.30, 0.30, 0.88]:
		_box_m(g, Vector3(0.22, 1.88, 0.15), Vector3(bv, 5.90, -1.685), _mat(Color(0.2, 0.2, 0.2)))
	# Estic GLB (stick.glb a la carpeta del projecte)
	# Dimensions originals: Z=2u (llarg), X=0.35u, Y=0.07u (pla)
	# Escala 3x → 6u llarg | Rotar X+90° → vertical | Rotar Z-15° → inclinat
	var stick_path := "res://stick.glb"
	if ResourceLoader.exists(stick_path):
		var stick_res = load(stick_path)
		if stick_res != null:
			var stick_inst: Node3D = stick_res.instantiate()
			stick_inst.scale = Vector3(3.0, 3.0, 3.0)
			stick_inst.rotation_degrees = Vector3(90.0, 0.0, -15.0)
			stick_inst.position = Vector3(1.8, 3.0, -0.3)
			g.add_child(stick_inst)
	else:
		# Fallback procedural si no hi ha el fitxer
		var stk := _box_m(g, Vector3(0.48, 5.5, 0.48), Vector3(1.75, 2.6, 0.0), wd)
		stk.rotation.z = -0.20
		_box_m(g, Vector3(0.28, 0.45, 2.6), Vector3(2.18, 0.22, 0.75), bd)
	# Anell humà
	if is_human:
		var rm := MeshInstance3D.new()
		var tmesh := TorusMesh.new()
		tmesh.outer_radius = 1.92; tmesh.inner_radius = 1.74; tmesh.rings = 40; tmesh.ring_segments = 8
		rm.mesh = tmesh; rm.material_override = _mat(Color(1.0, 0.84, 0.0))
		rm.rotation.x = -PI/2.0; rm.position.y = 0.12
		rm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(rm)
	# Ombra
	var sh := MeshInstance3D.new()
	var shm := CylinderMesh.new()
	shm.top_radius = 1.65; shm.bottom_radius = 1.65; shm.height = 0.04; shm.radial_segments = 20
	sh.mesh = shm
	var shmat := StandardMaterial3D.new()
	shmat.albedo_color = Color(0.04, 0.03, 0.02, 0.38)
	shmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sh.material_override = shmat; sh.position.y = 0.012
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(sh)
	return g

# ── PILOTA ────────────────────────────────────────
func _setup_ball() -> void:
	ball_node = Node3D.new()
	var bmi := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = BR; bm.height = BR*2.0; bm.radial_segments = 18; bm.rings = 12
	bmi.mesh = bm; bmi.material_override = _mat(Color(1.0, 0.43, 0.03))
	bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	ball_node.add_child(bmi)
	add_child(ball_node)

# ── FLETXA AIM ────────────────────────────────────
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
		cy.top_radius = 0.55 - float(i)*0.025
		cy.bottom_radius = cy.top_radius
		cy.height = 0.10; cy.radial_segments = 14
		disc.mesh = cy; disc.material_override = _mat(col)
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		disc.position = Vector3(float(i) * 1.8, 0.10, 0.0)
		aim_group.add_child(disc)
	var tip := _box_m(aim_group, Vector3(1.4, 0.14, 1.4), Vector3(20.0, 0.10, 0.0), _mat(Color(1.0, 0.89, 0.11)))
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aim_group.visible = false
	add_child(aim_group)

# ── AURA ──────────────────────────────────────────
func _setup_aura() -> void:
	aura_node = Node3D.new()
	var rm1 := MeshInstance3D.new()
	var t1 := TorusMesh.new()
	t1.outer_radius = 2.2; t1.inner_radius = 2.0; t1.rings = 44; t1.ring_segments = 8
	rm1.mesh = t1; rm1.material_override = _mat(Color(0.21, 0.76, 1.0))
	rm1.rotation.x = -PI/2.0; rm1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura_node.add_child(rm1)
	aura_node.position.y = 0.12; aura_node.visible = false
	add_child(aura_node)

# ── CAMERA ────────────────────────────────────────
func _setup_camera() -> void:
	cam = Camera3D.new()
	cam.fov = 58.0; cam.near = 0.1; cam.far = 200.0
	cam.position = Vector3(-28.0, 10.0, 0.0)
	cam.look_at(Vector3(0.0, 2.0, 0.0))
	add_child(cam)

func _update_cam() -> void:
	var px: float = float(lx[2])
	var pz: float = float(lz[2])
	var rad: float = cam_angle * PI / 180.0
	# Càmera SEMPRE darrere del jugador local (en la direcció oposada a la porteria rival)
	# El jugador mira cap a +X (porteria rival a X=+FW/2)
	# Càmera ha d'estar a X-negativa respecte al jugador
	var offx: float = -cos(rad) * 22.0
	var offz: float = -sin(rad) * 22.0
	# Lerp suau
	cam_x = lerp(cam_x, px + offx, 0.08)
	cam_z = lerp(cam_z, pz + offz, 0.08)
	cam.position = Vector3(cam_x, 10.0, cam_z)
	# Mira cap al jugador + una mica endavant (cap a la porteria rival)
	cam.look_at(Vector3(px + cos(rad)*8.0, 2.0, pz + sin(rad)*8.0), Vector3.UP)

# ── UI ────────────────────────────────────────────
func _setup_ui() -> void:
	var cl := CanvasLayer.new(); add_child(cl)
	# HUD superior
	var hud := ColorRect.new()
	hud.color = Color(0.053, 0.09, 0.19, 0.96)
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud.custom_minimum_size = Vector2(0.0, 70.0)
	cl.add_child(hud)
	lbl_sl = _lbl("0", 44, Color(1.0, 1.0, 1.0))
	lbl_sl.position = Vector2(20.0, 8.0); hud.add_child(lbl_sl)
	lbl_sr = _lbl("0", 44, Color(1.0, 1.0, 1.0))
	lbl_sr.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	lbl_sr.position = Vector2(-100.0, 8.0); hud.add_child(lbl_sr)
	_lbl_at(hud, "★  ARENYS HC", 12, Color(0.87, 0.12, 0.12), Vector2(20.0, -2.0))
	var nr := _lbl("RIVALS FC  ★", 12, Color(0.06, 0.25, 0.79))
	nr.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	nr.position = Vector2(-165.0, -2.0); hud.add_child(nr)
	lbl_time = _lbl("2:00", 34, Color(0.60, 0.67, 0.81))
	lbl_time.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	lbl_time.position = Vector2(-60.0, 5.0); hud.add_child(lbl_time)
	lbl_msg = _lbl("EL TEU TORN", 10, Color(1.0, 0.86, 0.19))
	lbl_msg.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	lbl_msg.position = Vector2(-240.0, 44.0); hud.add_child(lbl_msg)
	# Barra inferior
	var ctrl := ColorRect.new()
	ctrl.color = Color(0.02, 0.03, 0.06, 0.96)
	ctrl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	ctrl.custom_minimum_size = Vector2(0.0, 68.0); cl.add_child(ctrl)
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_theme_constant_override("separation", 8)
	ctrl.add_child(bar)
	var bn := _btn("⬛ NORMAL [Q]",  Color(0.09, 0.31, 0.08), true)
	var bc := _btn("↩ EFECTE  [W]", Color(0.35, 0.25, 0.05), false)
	var bp := _btn("⚡ FORT    [E]", Color(0.38, 0.08, 0.08), false)
	var ba := _btn("➡ PASSAR  [P]", Color(0.06, 0.21, 0.38), false)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var br := _btn("↩ REWIND×3[R]", Color(0.24, 0.16, 0.04), false)
	var bs := _btn("🏒  TIRA! [SPC]", Color(0.10, 0.35, 0.09), false)
	bs.custom_minimum_size = Vector2(144.0, 48.0)
	bs.add_theme_font_size_override("font_size", 14)
	bn.pressed.connect(func(): _set_shot("n"))
	bc.pressed.connect(func(): _set_shot("c"))
	bp.pressed.connect(func(): _set_shot("p"))
	ba.pressed.connect(func(): do_pass())
	br.pressed.connect(func(): do_rewind())
	bs.pressed.connect(func(): do_shoot())
	bar.add_child(bn); bar.add_child(bc); bar.add_child(bp); bar.add_child(ba)
	bar.add_child(sp); bar.add_child(br); bar.add_child(bs)
	# Power bar
	var pw_bg := ColorRect.new()
	pw_bg.color = Color(1.0, 1.0, 1.0, 0.12)
	pw_bg.custom_minimum_size = Vector2(14.0, 110.0)
	pw_bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	pw_bg.position = Vector2(22.0, -185.0)
	pw_bg.visible = false; cl.add_child(pw_bg)
	pw_fill = ColorRect.new()
	pw_fill.color = Color(0.14, 0.86, 0.24)
	pw_fill.size = Vector2(14.0, 66.0)
	pw_fill.position = Vector2(0.0, 44.0)
	pw_bg.add_child(pw_fill)

func _lbl(text: String, size: int, col: Color) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _lbl_at(parent: Control, text: String, size: int, col: Color, pos: Vector2) -> void:
	var l := _lbl(text, size, col); l.position = pos; parent.add_child(l)

func _btn(text: String, bg: Color, active: bool) -> Button:
	var b := Button.new(); b.text = text
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.custom_minimum_size = Vector2(104.0, 44.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left=7; sb.corner_radius_top_right=7
	sb.corner_radius_bottom_left=7; sb.corner_radius_bottom_right=7
	sb.content_margin_left=8.0; sb.content_margin_right=8.0
	if active:
		sb.border_width_top=2; sb.border_width_bottom=2
		sb.border_width_left=2; sb.border_width_right=2
		sb.border_color=Color(1.0, 1.0, 1.0, 0.65)
	b.add_theme_stylebox_override("normal", sb)
	b.focus_mode = Control.FOCUS_NONE
	return b

# ── MENÚ INICIAL ──────────────────────────────────
func _setup_menu() -> void:
	menu_layer = CanvasLayer.new(); add_child(menu_layer)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.14, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(bg)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(-200.0, -180.0)
	vbox.custom_minimum_size = Vector2(400.0, 360.0)
	vbox.add_theme_constant_override("separation", 16)
	bg.add_child(vbox)
	# Títol
	var t1 := _lbl("🏒  HOQUEI PATINS 3D", 32, Color(1.0, 0.86, 0.19))
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vbox.add_child(t1)
	var t2 := _lbl("DAM1  –  Pol Hernáez", 11, Color(0.5, 0.55, 0.7))
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vbox.add_child(t2)
	vbox.add_child(_lbl(" ", 8, Color.WHITE))
	var t3 := _lbl("Sempre controles l'equip VERMELL (★ Arenys HC)", 12, Color(0.87, 0.3, 0.3))
	t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vbox.add_child(t3)
	vbox.add_child(_lbl(" ", 8, Color.WHITE))
	# Controls
	var tc := _lbl(
		"🖱 Arrossega → apunta  |  Allibera → xuta\n" +
		"Clic pista → mou  |  ASDF → moure  |  Q/W/E → tipus\n" +
		"P → passar  |  R → rewind  |  ← → → rotar càmera",
		11, Color(0.5, 0.55, 0.7))
	tc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vbox.add_child(tc)
	vbox.add_child(_lbl(" ", 8, Color.WHITE))
	# Botó jugar
	var bp := Button.new()
	bp.text = "▶   JUGAR!"
	bp.custom_minimum_size = Vector2(280.0, 56.0)
	bp.add_theme_font_size_override("font_size", 20)
	bp.add_theme_color_override("font_color", Color.WHITE)
	var splay := StyleBoxFlat.new()
	splay.bg_color = Color(0.1, 0.55, 0.12)
	splay.corner_radius_top_left=10; splay.corner_radius_top_right=10
	splay.corner_radius_bottom_left=10; splay.corner_radius_bottom_right=10
	bp.add_theme_stylebox_override("normal", splay)
	bp.alignment = HORIZONTAL_ALIGNMENT_CENTER
	bp.focus_mode = Control.FOCUS_NONE
	bp.pressed.connect(func(): _start_game())
	vbox.add_child(bp)

func _start_game() -> void:
	in_menu = false
	menu_layer.visible = false
	_init_pos(true)

# ── PANTALLA RESULTAT ─────────────────────────────
func _setup_result() -> void:
	result_layer = CanvasLayer.new(); add_child(result_layer)
	result_layer.visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.14, 0.93)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_layer.add_child(bg)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(-160.0, -130.0)
	vbox.custom_minimum_size = Vector2(320.0, 260.0)
	vbox.add_theme_constant_override("separation", 18)
	bg.add_child(vbox)
	var lr := _lbl("", 30, Color(1.0, 0.86, 0.19))
	lr.name = "LblRes"; lr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vbox.add_child(lr)
	var ls := _lbl("", 52, Color.WHITE)
	ls.name = "LblScore"; ls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vbox.add_child(ls)
	var br := Button.new()
	br.text = "🔄  TORNAR A JUGAR"
	br.custom_minimum_size = Vector2(260.0, 52.0)
	br.add_theme_font_size_override("font_size", 16)
	br.add_theme_color_override("font_color", Color.WHITE)
	var sr := StyleBoxFlat.new()
	sr.bg_color = Color(0.1, 0.42, 0.12)
	sr.corner_radius_top_left=10; sr.corner_radius_top_right=10
	sr.corner_radius_bottom_left=10; sr.corner_radius_bottom_right=10
	br.add_theme_stylebox_override("normal", sr)
	br.focus_mode = Control.FOCUS_NONE
	br.pressed.connect(func():
		result_layer.visible = false
		score_l=0; score_r=0; rewinds=3; time_left=120.0
		lbl_sl.text="0"; lbl_sr.text="0"; lbl_time.text="2:00"
		_init_pos(true)
	)
	vbox.add_child(br)

# ── INPUT ─────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if in_menu:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				mouse_down=true; ms_x=mb.position.x; ms_y=mb.position.y
				ms_ang=aim_ang; ms_pow=aim_pow; did_drag=false
			else:
				mouse_down=false
				if did_drag:
					if phase==Phase.MY_TURN and human_ball:
						do_shoot()
				else:
					_click_move(mb.position)
				did_drag=false
	elif event is InputEventMouseMotion and mouse_down:
		var mm := event as InputEventMouseMotion
		var dx: float = mm.position.x - ms_x
		var dy: float = mm.position.y - ms_y
		if sqrt(dx*dx+dy*dy) > 8.0 and phase==Phase.MY_TURN and human_ball:
			did_drag=true
			aim_ang = ms_ang + dx*0.026
			aim_pow = clampf(ms_pow - dy/185.0, 0.05, 1.0)
			_update_pw()
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_Q: _set_shot("n")
			KEY_W: _set_shot("c")
			KEY_E: _set_shot("p")
			KEY_P: do_pass()
			KEY_R: do_rewind()
			KEY_SPACE: do_shoot()
			KEY_ENTER: do_shoot()
			KEY_A:
				# Moviment sempre actiu (per interceptar)
				if phase!=Phase.GOAL and phase!=Phase.OVER:
					ltx[2]=clampf(float(lx[2])-5.0,-FW/2.0+1.4,FW/2.0-1.4); ltz[2]=float(lz[2])
			KEY_D:
				if phase!=Phase.GOAL and phase!=Phase.OVER:
					ltx[2]=clampf(float(lx[2])+5.0,-FW/2.0+1.4,FW/2.0-1.4); ltz[2]=float(lz[2])
			KEY_S:
				if phase!=Phase.GOAL and phase!=Phase.OVER:
					ltx[2]=float(lx[2]); ltz[2]=clampf(float(lz[2])+5.0,-FH/2.0+0.8,FH/2.0-0.8)
			KEY_F:
				if phase!=Phase.GOAL and phase!=Phase.OVER:
					ltx[2]=float(lx[2]); ltz[2]=clampf(float(lz[2])-5.0,-FH/2.0+0.8,FH/2.0-0.8)
			KEY_LEFT:  cam_angle=fmod(cam_angle-22.0+360.0,360.0)
			KEY_RIGHT: cam_angle=fmod(cam_angle+22.0,360.0)
			KEY_UP:    cam_angle=0.0
			KEY_DOWN:  cam_angle=180.0

func _click_move(screen_pos: Vector2) -> void:
	if phase == Phase.GOAL or phase == Phase.OVER:
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
		if dd > 16.0:
			ddx=ddx/dd*16.0; ddz=ddz/dd*16.0
		ltx[2]=clampf(float(lx[2])+ddx,-FW/2.0+1.4,FW/2.0-1.4)
		ltz[2]=clampf(float(lz[2])+ddz,-FH/2.0+0.8,FH/2.0-0.8)

func _update_pw() -> void:
	if pw_fill==null:
		return
	var h: float = aim_pow*110.0
	pw_fill.size.y=h; pw_fill.position.y=110.0-h
	if aim_pow<0.4:
		pw_fill.color=Color(0.14,0.86,0.24)
	elif aim_pow<0.7:
		pw_fill.color=Color(1.0,0.76,0.08)
	else:
		pw_fill.color=Color(1.0,0.17,0.11)

# ── ACCIONS ───────────────────────────────────────
func do_shoot() -> void:
	if phase!=Phase.MY_TURN or not human_ball:
		return
	sv_bx=bx; sv_bz=bz; sv_hx=float(lx[2]); sv_hz=float(lz[2])
	human_ball=false; ball_free=true
	var spd: float
	if shot=="n":   spd=SPD_N
	elif shot=="c": spd=SPD_C
	else:           spd=SPD_P
	var final_spd: float = 18.0 + aim_pow*(spd-18.0)  # mínim 18u/s
	bvx = cos(aim_ang)*final_spd
	bvz = sin(aim_ang)*final_spd
	# Offset immediat per evitar auto-recollida
	# Punt de partida: davant del jugador + offset en direcció de xut
	bx = float(lx[2]) + 1.5 + cos(aim_ang)*2.0
	bz = float(lz[2]) + sin(aim_ang)*2.0
	if shot=="c":
		cfx=-sin(aim_ang)*8.0; cfz=cos(aim_ang)*8.0
	else:
		cfx=0.0; cfz=0.0
	just_shot_timer=0.5
	_set_phase(Phase.SHOOTING)

func do_pass() -> void:
	if phase!=Phase.MY_TURN or not human_ball:
		return
	var d0: float = _d2(float(lx[0]),float(lz[0]),float(lx[2]),float(lz[2]))
	var d1: float = _d2(float(lx[1]),float(lz[1]),float(lx[2]),float(lz[2]))
	var t: int = 0 if d0 < d1 else 1
	human_ball=false; ball_free=true; cfx=0.0; cfz=0.0
	var dx: float = float(lx[t])-bx; var dz: float = float(lz[t])-bz
	var dd: float = sqrt(dx*dx+dz*dz)
	if dd < 0.1:
		human_ball=true; ball_free=false; return
	bvx=dx/dd*26.0; bvz=dz/dd*26.0
	bx+=dx/dd*2.0; bz+=dz/dd*2.0
	just_shot_timer=0.4
	_set_phase(Phase.SHOOTING)

func do_rewind() -> void:
	if rewinds<=0 or phase==Phase.MY_TURN:
		return
	rewinds-=1
	human_ball=true; ball_free=false
	bx=sv_bx; bz=sv_bz; bvx=0.0; bvz=0.0; cfx=0.0; cfz=0.0
	lx[2]=sv_hx; lz[2]=sv_hz; ltx[2]=sv_hx; ltz[2]=sv_hz
	_set_phase(Phase.MY_TURN)

func _set_shot(t: String) -> void:
	shot=t

func _set_phase(p: Phase) -> void:
	phase=p
	match p:
		Phase.MY_TURN:
			lbl_msg.text="EL TEU TORN – Arrossega per apuntar + allibera"
			lbl_msg.add_theme_color_override("font_color",Color(1.0,0.86,0.19))
			# Resetar target del GK al seu lloc base
			lgk_react_timer=GK_REACT
			rgk_react_timer=GK_REACT
		Phase.SHOOTING:
			lbl_msg.text="LLANÇAMENT..."
			lbl_msg.add_theme_color_override("font_color",Color(1.0,0.54,0.17))
			lgk_react_timer=GK_REACT
			rgk_react_timer=GK_REACT
		Phase.AI_TURN:
			lbl_msg.text="TORN RIVAL"
			lbl_msg.add_theme_color_override("font_color",Color(0.27,0.51,1.0))
			ai_delay=2.0+randf()*1.5  # 2-3.5s per driblar i posicionar-se
			ai_in_position=false
			ai_shoot_timer=0.0
		Phase.GOAL, Phase.OVER:
			aim_group.visible=false

# ── INIT ──────────────────────────────────────────
func _init_pos(local_kick: bool) -> void:
	# Posicions ben separades: ningú es toca
	lx=[-( FW/2.0-4.0), -FW/5.0, -4.0]
	lz=[0.0, 0.0, 0.0]
	ltx=[float(lx[0]), float(lx[1]), float(lx[2])]
	ltz=[float(lz[0]), float(lz[1]), float(lz[2])]
	rx=[ FW/2.0-4.0,  FW/5.0,  4.0]
	rz=[0.0, 0.0, 0.0]
	rtx=[float(rx[0]), float(rx[1]), float(rx[2])]
	rtz=[float(rz[0]), float(rz[1]), float(rz[2])]

	human_ball=false; rival_ball=false; r_holder=-1
	bvx=0.0; bvz=0.0; cfx=0.0; cfz=0.0; ball_free=false
	aim_ang=0.0; aim_pow=0.65
	just_shot_timer=0.0; ai_delay=0.0; ai_in_position=false
	lgk_react_timer=0.0; rgk_react_timer=0.0
	lgk_target_z=0.0; rgk_target_z=0.0

	if local_kick:
		human_ball=true
		bx=float(lx[2]); bz=float(lz[2])
		_set_phase(Phase.MY_TURN)
	else:
		rival_ball=true; r_holder=2
		bx=float(rx[2]); bz=float(rz[2])
		_set_phase(Phase.AI_TURN)

# ── FÍSICA PILOTA ─────────────────────────────────
func _tick_ball(dt: float) -> void:
	# Pilota adherida al posseïdor (visible davant del jugador)
	if human_ball and phase==Phase.MY_TURN:
		# Pilota lleugerament davant del jugador (visible)
		bx=float(lx[2])+1.5; bz=float(lz[2]); bvx=0.0; bvz=0.0; return
	if rival_ball and r_holder>=0:
		bx=float(rx[r_holder]); bz=float(rz[r_holder]); bvx=0.0; bvz=0.0; return
	if not ball_free:
		return

	# Efecte corba
	if shot=="c":
		bvx+=cfx*dt; bvz+=cfz*dt
		var dc: float=pow(0.88,dt*60.0); cfx*=dc; cfz*=dc

	bx+=bvx*dt; bz+=bvz*dt
	var fr: float=pow(FRIC,dt*60.0); bvx*=fr; bvz*=fr

	# Rebots bandes - NO bloquejar zona de porteria!
	var wx: float = FW/2.0 + 0.2 - BR
	var wz: float = FH/2.0 + 0.2 - BR
	if abs(bx) > wx:
		# Si la pilota és dins de la zona de porteria (Z), deixar-la passar cap al gol
		if abs(bz) >= GZ:
			# Fora de la porteria: rebot normal a la paret del fons
			bvx *= -0.65; bx = sign(bx)*wx
		# Si abs(bz) < GZ: no rebotar, la pilota va cap a la porteria
	if abs(bz) > wz: bvz *= -0.62; bz = sign(bz)*wz
	# Seguretat: si la pilota va molt lluny, resetar
	if abs(bx) > FW/2.0 + GD + 2.0:
		bx = 0.0; bz = 0.0; bvx = 0.0; bvz = 0.0
		ball_free = false; human_ball = true; _set_phase(Phase.MY_TURN)

	# SAFETY: si la pilota surt molt del camp (bug), torna-la al centre
	if abs(bx)>FW or abs(bz)>FH:
		bx=0.0; bz=0.0; bvx=0.0; bvz=0.0
		ball_free=false; human_ball=true
		_set_phase(Phase.MY_TURN)

	# Porters salven (radi petit → finestra de gol real)
	var bspd: float=sqrt(bvx*bvx+bvz*bvz)
	if rgk_react_timer<=0.0 and _d2(bx,bz,float(rx[0]),float(rz[0]))<GK_RADIUS and bspd>1.0:
		bvx*=-0.45; bvz+=(randf()-0.5)*14.0; _clamp_ball(16.0)
	if lgk_react_timer<=0.0 and _d2(bx,bz,float(lx[0]),float(lz[0]))<GK_RADIUS and bspd>1.0:
		bvx*=-0.45; bvz+=(randf()-0.5)*14.0; _clamp_ball(16.0)

	# Recollida
	# Intercepcions: el human pot recuperar la pilota en qualsevol moment
	# PERÒ no durant just_shot_timer (sinó la pilota torna immediatament)
	if just_shot_timer>0.0:
		return

	if not human_ball and not rival_ball and ball_free:
		if _d2(bx,bz,float(lx[2]),float(lz[2]))<2.0:
			ball_free=false; human_ball=true
			_set_phase(Phase.MY_TURN); return
	# Durant AI_TURN: si el human s'apropa molt al rival amb pilota
	if rival_ball and r_holder>=0 and phase==Phase.AI_TURN:
		if _d2(float(lx[2]),float(lz[2]),float(rx[r_holder]),float(rz[r_holder]))<3.0:
			rival_ball=false; r_holder=-1; human_ball=true
			bx=float(lx[2]); bz=float(lz[2])
			_set_phase(Phase.MY_TURN); return

	if phase==Phase.SHOOTING:
		# Locals agafen la pilota
		for i in range(3):
			if _d2(bx,bz,float(lx[i]),float(lz[i]))<1.4:
				ball_free=false
				if i==2:
					human_ball=true; _set_phase(Phase.MY_TURN)
				else:
					# GK/DEF local recull → passa visible cap al human FW
					# La pilota vola des del company fins al jugador humà
					var dx_p: float = float(lx[2]) - bx
					var dz_p: float = float(lz[2]) - bz
					var dd_p: float = sqrt(dx_p*dx_p + dz_p*dz_p)
					if dd_p > 0.5:
						bvx = dx_p/dd_p * 28.0  # passa a 28 u/s
						bvz = dz_p/dd_p * 28.0
						ball_free = true  # pilota lliure mentre vola
						just_shot_timer = 0.1  # petit delay
						phase = Phase.SHOOTING  # continua en SHOOTING
					else:
						human_ball = true; _set_phase(Phase.MY_TURN)
				return
		# Rivals agafen la pilota
		for i in range(3):
			if _d2(bx,bz,float(rx[i]),float(rz[i]))<1.6:
				ball_free=false; rival_ball=true; r_holder=i
				_set_phase(Phase.AI_TURN); return
		# Pilota s'atura → jugador MÉS PROPER la recull
		if bspd<0.3 and just_shot_timer<=0.0:
			_give_to_nearest()

func _give_to_nearest() -> void:
	ball_free=false
	var best_d: float=999.0
	var best_team: String="local"
	var best_i: int=2
	for ii in range(3):
		var dl: float=_d2(bx,bz,float(lx[ii]),float(lz[ii]))
		if dl<best_d: best_d=dl; best_team="local"; best_i=ii
	for ii in range(3):
		var dr: float=_d2(bx,bz,float(rx[ii]),float(rz[ii]))
		if dr<best_d: best_d=dr; best_team="rival"; best_i=ii
	if best_team=="local":
		human_ball=true; bx=float(lx[2]); bz=float(lz[2]); _set_phase(Phase.MY_TURN)
	else:
		rival_ball=true; r_holder=best_i; _set_phase(Phase.AI_TURN)

func _clamp_ball(mx: float) -> void:
	var s: float=sqrt(bvx*bvx+bvz*bvz)
	if s>0.0 and s<mx: bvx=bvx/s*mx; bvz=bvz/s*mx

# ── MOVIMENT JUGADORS ─────────────────────────────
func _tick_players(dt: float) -> void:
	# GK react timers
	if lgk_react_timer>0.0: lgk_react_timer-=dt
	if rgk_react_timer>0.0: rgk_react_timer-=dt

	match phase:
		Phase.MY_TURN:
			# ── MY TURN: GK rival SEMPRE al centre (no segueix pilota) ──
			# Amb el GK al centre, el jugador pot apuntar a les cantonades
			_mv_to(lx,lz,0, -(FW/2.0-4.0), 0.0, 3.0, dt)
			_mv_to(lx,lz,1, -FW/5.0, 0.0, 3.0, dt)
			_human_move(dt)
			# GK rival: torna al CENTRE (posició neutra) durant MY_TURN
			rgk_target_z = 0.0  # no segueix la pilota!
			_mv_to(rx,rz,0, FW/2.0-4.0, 0.0, GK_SPD, dt)
			_mv_to(rx,rz,1, FW/4.0, sin(aura_time*0.5)*3.0, 4.0, dt)
			_mv_to(rx,rz,2, FW/6.0, sin(aura_time*0.7)*4.0, 4.0, dt)

		Phase.SHOOTING:
			_mv_to(lx,lz,0, -(FW/2.0-4.0), clampf(bz,-GZ+0.6,GZ-0.6), GK_SPD, dt)
			_mv_to(lx,lz,1, bx-3.0, bz*0.5, 14.0, dt)
			_human_move(dt)
			if rgk_react_timer<=0.0:
				rgk_target_z=clampf(bz,-GZ+0.6,GZ-0.6)
			_mv_to(rx,rz,0, FW/2.0-4.0, rgk_target_z, GK_SPD, dt)
			if bx>0.0:
				_mv_to(rx,rz,1, bx+2.0, bz, 12.0, dt)
			else:
				_mv_to(rx,rz,1, FW/4.0, 0.0, 8.0, dt)
			_mv_to(rx,rz,2, bx+1.5, bz, 18.0, dt)

		Phase.AI_TURN:
			# ── AI TURN: GK local reacciona tard i amb errors ──
			# GK local: reacciona lentament i imperfectament
			if lgk_react_timer <= 0.0:
				# Posició amb error humà (±1.5 unitats de desviació)
				lgk_target_z = clampf(bz + (randf()-0.5)*3.0, -GZ+0.6, GZ-0.6)
				lgk_react_timer = 0.15  # small delay before next update
			_mv_to(lx,lz,0, -(FW/2.0-4.0), lgk_target_z, GK_SPD*0.85, dt)
			# DEF local: pressiona el rival que té la pilota
			if r_holder>=0:
				var target_x: float=clampf(float(rx[r_holder])-4.0,-FW/2.0+4.0,0.0)
				_mv_to(lx,lz,1, target_x, float(rz[r_holder])*0.6, 14.0, dt)
			else:
				_mv_to(lx,lz,1, -FW/5.0, 0.0, 8.0, dt)
			# Human: no es mou sol (queda on estava)
			_human_move(dt)
			# GK rival
			_mv_to(rx,rz,0, FW/2.0-4.0, clampf(bz,-GZ+0.6,GZ-0.6), GK_SPD, dt)
			# DEF rival: retrocedeix al seu camp
			_mv_to(rx,rz,1, FW/4.0, 0.0, 8.0, dt)
			# FW rival: si té la pilota, va a posició de tir; si no, la busca
			if rival_ball and r_holder == 2:
				# FW rival dribla cap a posició de tir
				if not ai_in_position:
					rtx[2] = -(FW/4.5) + (randf()-0.5)*5.0
					rtz[2] = (randf()-0.5)*FH*0.4
					ai_in_position = true
				_mv_to(rx,rz,2, float(rtx[2]), float(rtz[2]), 14.0, dt)
			elif rival_ball and (r_holder == 0 or r_holder == 1):
				# GK o DEF rival té la pilota → passa al FW ràpid
				var holder_x: float = float(rx[r_holder])
				var holder_z: float = float(rz[r_holder])
				var fw_x: float = float(rx[2])
				var fw_z: float = float(rz[2])
				var pdx: float = fw_x - holder_x
				var pdz: float = fw_z - holder_z
				var pdd: float = sqrt(pdx*pdx + pdz*pdz)
				if pdd > 0.5:
					# Visualment: el portador es mou cap al FW 0.5s, llavors passa
					ai_delay = maxf(ai_delay, 0.6)  # mínim 0.6s per passar
					if ai_delay <= 0.0:
						# Passa!
						rival_ball = false; ball_free = true
						bvx = pdx/pdd*30.0; bvz = pdz/pdd*30.0
						bx = holder_x + pdx/pdd*1.5
						bz = holder_z + pdz/pdd*1.5
						just_shot_timer = 0.3
						r_holder = -1
						phase = Phase.SHOOTING
				else:
					# FW és al costat → transferència directa
					rival_ball = true; r_holder = 2
			elif not rival_ball:
				_mv_to(rx,rz,2, bx+2.0, bz, 16.0, dt)

func _human_move(dt: float) -> void:
	# El jugador humà pot moure's SEMPRE (per interceptar la pilota)
	var ddx: float=float(ltx[2])-float(lx[2])
	var ddz: float=float(ltz[2])-float(lz[2])
	var dd: float=sqrt(ddx*ddx+ddz*ddz)
	if dd>0.1:
		# Velocitat reduïda quan NO és el seu torn (no pot xocar amb rivals)
		var spd: float = 18.0 if phase==Phase.MY_TURN else 14.0
		var s: float=minf(spd*dt,dd)
		lx[2]=float(lx[2])+ddx/dd*s
		lz[2]=float(lz[2])+ddz/dd*s
	lx[2]=clampf(float(lx[2]),-FW/2.0+1.4,FW/2.0-1.4)
	lz[2]=clampf(float(lz[2]),-FH/2.0+0.8,FH/2.0-0.8)

func _mv_to(xa: Array, za: Array, i: int, tx: float, tz: float, spd: float, dt: float) -> void:
	var dx: float=tx-float(xa[i]); var dz: float=tz-float(za[i])
	var dd: float=sqrt(dx*dx+dz*dz)
	if dd>0.08:
		var s: float=minf(spd*dt,dd)
		xa[i]=float(xa[i])+dx/dd*s
		za[i]=float(za[i])+dz/dd*s
	xa[i]=clampf(float(xa[i]),-FW/2.0+1.2,FW/2.0-1.2)
	za[i]=clampf(float(za[i]),-FH/2.0+0.8,FH/2.0-0.8)

# ── IA XUTA ───────────────────────────────────────
func _ai_do_shoot() -> void:
	if phase!=Phase.AI_TURN or not rival_ball or r_holder!=2:
		return
	rival_ball=false; ball_free=true; cfx=0.0; cfz=0.0
	# Apunta cap a la porteria local + imperfecció humana
	var goal_x: float = -(FW/2.0)
	var goal_z: float = (randf()-0.5)*GZ*1.6  # imperfecte: no sempre al centre
	var dx: float = goal_x-bx; var dz: float = goal_z-bz
	var dd: float = sqrt(dx*dx+dz*dz)
	var spd: float = 26.0+randf()*18.0  # velocitat variable
	bvx=dx/dd*spd; bvz=dz/dd*spd
	bx+=dx/dd*2.5; bz+=dz/dd*2.5  # offset
	just_shot_timer=0.4
	phase=Phase.SHOOTING
	lbl_msg.text="LLANÇAMENT RIVAL!"
	lbl_msg.add_theme_color_override("font_color",Color(1.0,0.25,0.25))

# ── GOL ───────────────────────────────────────────
func _check_goal() -> void:
	if phase==Phase.GOAL or phase==Phase.OVER:
		return
	if bx<-(FW/2.0+0.1) and abs(bz)<GZ:
		_on_goal(false)
	if bx>  FW/2.0+0.1 and abs(bz)<GZ:
		_on_goal(true)

func _on_goal(ls: bool) -> void:
	if ls:
		score_l+=1
	else:
		score_r+=1
	lbl_sl.text=str(score_l); lbl_sr.text=str(score_r)
	if ls:
		lbl_msg.text="⚽  GOL!  ARENYS HC!"
		lbl_msg.add_theme_color_override("font_color",Color(1.0,0.87,0.20))
	else:
		lbl_msg.text="⚽  GOL!  RIVALS FC!"
		lbl_msg.add_theme_color_override("font_color",Color(1.0,0.27,0.27))
	phase=Phase.GOAL
	ball_free=false; bvx=0.0; bvz=0.0
	human_ball=false; rival_ball=false; r_holder=-1
	aim_group.visible=false
	goal_delay=2.2; init_after_goal=true; local_kick_next=not ls
	var el: Label
	if ls:
		el=lbl_sl
	else:
		el=lbl_sr
	var tw := create_tween(); tw.set_loops(5)
	tw.tween_property(el,"modulate:a",0.1,0.18)
	tw.tween_property(el,"modulate:a",1.0,0.18)

func _on_over() -> void:
	if result_layer==null: return
	result_layer.visible=true
	var lr := result_layer.get_node_or_null("ColorRect/VBoxContainer/LblRes") as Label
	var ls2 := result_layer.get_node_or_null("ColorRect/VBoxContainer/LblScore") as Label
	if lr==null or ls2==null: return
	ls2.text="%d – %d" % [score_l, score_r]
	if score_l>score_r:
		lr.text="🏆  VICTÒRIA!"; lr.add_theme_color_override("font_color",Color(1.0,0.86,0.19))
	elif score_r>score_l:
		lr.text="💀  DERROTA!";  lr.add_theme_color_override("font_color",Color(1.0,0.27,0.27))
	else:
		lr.text="🤝  EMPAT!";    lr.add_theme_color_override("font_color",Color(0.7,0.7,1.0))

# ── SYNC ──────────────────────────────────────────
func _sync() -> void:
	for i in range(3):
		(l_nodes[i] as Node3D).position=Vector3(float(lx[i]),0.0,float(lz[i]))
		(r_nodes[i] as Node3D).position=Vector3(float(rx[i]),0.0,float(rz[i]))
	ball_node.position=Vector3(bx,BR,bz)
	aura_node.position=Vector3(float(lx[2]),0.12,float(lz[2]))
	aura_node.visible=(phase==Phase.MY_TURN)
	if aura_node.visible:
		var sc: float=1.0+sin(aura_time*2.2)*0.18
		aura_node.scale=Vector3(sc,1.0,sc)
	var show_aim: bool=(phase==Phase.MY_TURN and human_ball)
	aim_group.visible=show_aim
	if show_aim:
		aim_group.position=Vector3(bx,0.0,bz)
		aim_group.rotation.y=-aim_ang
		aim_group.scale.x=0.25+aim_pow*0.75
		if pw_fill!=null and pw_fill.get_parent()!=null:
			pw_fill.get_parent().visible=true
	else:
		if pw_fill!=null and pw_fill.get_parent()!=null:
			pw_fill.get_parent().visible=false

# ── HELPERS ───────────────────────────────────────
func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color=col; m.roughness=0.88; return m

func _box_c(parent: Node, sz: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	return _box_m(parent, sz, pos, _mat(col))

func _box_m(parent: Node, sz: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size=sz
	mi.mesh=bm; mi.material_override=mat; mi.position=pos
	parent.add_child(mi); return mi

func _d2(x1: float, z1: float, x2: float, z2: float) -> float:
	return sqrt((x1-x2)*(x1-x2)+(z1-z2)*(z1-z2))
