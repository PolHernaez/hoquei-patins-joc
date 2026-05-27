# 07 – Manual Tècnic

**Projecte:** Hoquei Patins 3D  
**Alumne:** Pol Hernáez – DAM1 – Escola Pia de Mataró  
**Motor:** Godot Engine 4.6.2 | **Llenguatge:** GDScript 4.6  

---

## 1. Arquitectura general

El projecte segueix una arquitectura **monolítica procedural** en un sol script `Main.gd` de ~1.400 línies que genera tot el joc per codi en temps d'execució. Aquesta decisió és deliberada per a un projecte d'escola: facilita la revisió, evita dependències entre escenes i manté tot el context en un sol fitxer.

```
hoquei-patins-godot/
├── Main.gd          ← Script principal (~1.400 línies, tot el joc)
├── Main.tscn        ← Escena arrel (Node3D buit, Main.gd adjunt)
├── project.godot    ← Configuració del projecte Godot
└── stick.glb        ← Model 3D de l'estic (opcional)
```

---

## 2. Estructura de carpetes del repositori

```
hoquei-patins-joc/
├── README.md
├── fase1/           ← Idea i abast
├── fase2/           ← Model del joc + diagrames
├── fase3/           ← Codi Godot + captures + doc entorn
├── fase4/           ← Proves i depuració
└── fase5/           ← Millores i reflexió
```

---

## 3. Fitxers principals del codi

| Fitxer | Responsabilitat |
|--------|----------------|
| `Main.gd` | Tot el joc: lògica, física, IA, UI, càmera, jugadors |
| `Main.tscn` | Escena arrel de Godot (Node3D + Main.gd com a script) |
| `project.godot` | Configuració Godot (resolució 1280×720, escena principal) |
| `stick.glb` | Model 3D de l'estic de hoquei (carregat proceduralment) |

---

## 4. Components principals del codi

### 4.1 Màquina d'estats (enum Phase)

```gdscript
enum Phase { MY_TURN, SHOOTING, AI_TURN, GOAL, OVER }
```

| Estat | Descripció |
|-------|-----------|
| `MY_TURN` | Torn del jugador humà: pot moure's i apuntar |
| `SHOOTING` | Pilota en vol: tots els jugadors es mouen |
| `AI_TURN` | Torn de la IA: el rival es posiciona i xuta |
| `GOAL` | Gol marcat: espera 2.5s i reinicia posicions |
| `OVER` | Fi de partida: mostra la pantalla de resultat |

### 4.2 Representació dels jugadors

Els jugadors es representen amb **arrays de posicions** en lloc d'objectes:

```gdscript
var lx: Array = [-22.0, -14.0, -4.0]   # posicions X equip local
var lz: Array = [0.0, -6.0, 0.0]       # posicions Z equip local
var rx: Array = [22.0, 14.0, 4.0]      # posicions X equip rival
var rz: Array = [0.0, 6.0, 0.0]        # posicions Z equip rival
```

Índexs: `[0]` = GK (porter), `[1]` = DEF (defensa), `[2]` = FW (davanter)

### 4.3 Física de la pilota

```gdscript
var bx, bz: float    # posició X, Z de la pilota
var bvx, bvz: float  # velocitat X, Z de la pilota
var by: float        # alçada (per als arcs de passada)
const FRIC: float = 0.991  # fricció per frame normalitzada
const BR: float = 0.48     # radi de la pilota
```

La fricció s'aplica multiplicada per `pow(FRIC, delta*60.0)` per garantir comportament idèntic a qualsevol FPS.

### 4.4 Porter (GK) intel·ligent

El porter prediu on arribarà la pilota calculant la **intersecció de la trajectòria** amb la seva línia X:

```gdscript
if abs(bvx) > 0.5:
    var t_to_goal: float = (goal_x - bx) / bvx
    if t_to_goal > 0.0:
        predicted_z = bz + bvz * t_to_goal
```

Paràmetres per dificultat:

| Dificultat | GK_SPD | GK_RADIUS | GK_REACT | Error dive |
|-----------|--------|-----------|----------|-----------|
| Fàcil | 3.2 u/s | 0.45 u | 0.50 s | 55% |
| Normal | 5.5 u/s | 0.75 u | 0.28 s | 28% |
| Difícil | 7.2 u/s | 1.05 u | 0.12 s | 10% |

### 4.5 Intel·ligència Artificial rival

La IA té **tres personalitats** aleatòries per partida:

| Personalitat | Comportament | Dispersió xut |
|-------------|-------------|--------------|
| `aggressive` | Ataca ràpid, apunta als costats | ±GZ×0.85 |
| `balanced` | Equilibra atac i defensa | ±GZ×0.65 |
| `defensive` | Espera al centre del camp | ±GZ×0.45 |

La IA xuta a velocitat variable `20–34 u/s` (deliberadament reduïda per fer el joc just).

### 4.6 Timers de joc fair-play

```gdscript
var just_shot_timer: float    # 0.4s: pilota no recollible just després del xut
var possession_timer: float   # 1.2s: invulnerabilitat de possessió
var loose_ball_timer: float   # 0.4s: IA no recalcula vector en rebots
var ai_confusion_timer: float # 0.6s: IA "cega" després de parada del GK
```

---

## 5. Funcions principals

| Funció | Responsabilitat |
|--------|----------------|
| `_ready()` | Inicialitza entorn, jugadors, pilota, UI i menú |
| `_process(delta)` | Bucle principal: timers, física, IA, càmera, sync |
| `_tick_ball(dt)` | Física de la pilota: fricció, rebots, alçada |
| `_tick_players(dt)` | Moviment de jugadors i IA per fase |
| `_check_goal()` | Detecció de gol: `bx > FW/2+0.1` amb `abs(bz) < GZ` |
| `_human_move(dt)` | Moviment del jugador humà amb stamina |
| `_ai_do_shoot()` | Lògica de xut de la IA rival |
| `_trigger_gk_dive(is_local)` | Activar dive del porter amb predicció de trajectòria |
| `_setup_pause()` | Crear el panell de pausa (UI) |
| `_toggle_pause()` | Activar/desactivar la pausa |
| `_init_pos(full)` | Reiniciar posicions de tots els jugadors |
| `_sync()` | Actualitzar nodes 3D visuals a les posicions lògiques |
| `_update_cam(dt)` | Moure la càmera seguint l'acció |

---

## 6. Constants clau

```gdscript
const FW: float = 56.0    # amplada del camp (eix X: -28 a +28)
const FH: float = 28.0    # llargada del camp (eix Z: -14 a +14)
const GZ: float = 5.5     # semi-amplada de la porteria
const GD: float = 3.2     # profunditat de la porteria
const GH: float = 4.0     # alçada de la porteria
const BR: float = 0.48    # radi de la pilota
const FRIC: float = 0.991 # fricció (normalitzada per FPS)
const SPD_N: float = 32.0 # velocitat xut normal
const SPD_C: float = 24.0 # velocitat xut corba/efecte
const SPD_P: float = 50.0 # velocitat xut fort
```

---

## 7. Flux principal del programa

```
_ready()
  ├── _setup_env()       # llums, ambient, cel
  ├── _setup_field()     # parquet, línies, pista
  ├── _setup_goals()     # porteries vermella/blava
  ├── _setup_walls()     # bandes i franja
  ├── _setup_players()   # 6 jugadors blocky estil Roblox
  ├── _setup_ball()      # pilota taronja + indicador disc groc
  ├── _setup_aim()       # fletxa discs de colors (verd→vermell)
  ├── _setup_aura()      # anell blau pulsant sota el jugador
  ├── _setup_camera()    # càmera 3a persona
  ├── _setup_ui()        # HUD, barres, marcador, rellotge
  └── _setup_menu()      # menú inicial amb dificultat

_process(delta)
  ├── [if paused] return
  ├── timer + advertència últims 30s
  ├── timers de fair-play (just_shot, possession, loose_ball, confusion)
  ├── _tick_ball(delta)   # física + rebots + col·lisions GK
  ├── _tick_players(delta) # moviment + IA per fase
  ├── _check_goal()       # detecció de gol
  ├── _sync()             # sync posicions lògiques → nodes 3D
  └── _update_cam(delta)  # càmera segueix l'acció
```

---

## 8. Generació procedural 3D

Tot el contingut 3D es genera per codi (no hi ha models de l'editor):

```gdscript
# Exemple: creació d'un jugador blocky
func _make_player(col: Color) -> Node3D:
    var g := Node3D.new()
    # Cos
    var body := MeshInstance3D.new()
    body.mesh = BoxMesh.new()    # cos rectangular
    body.position = Vector3(0, 5, 0)
    g.add_child(body)
    # Cap
    var head := MeshInstance3D.new()
    head.mesh = BoxMesh.new()    # cap cúbic estil Roblox
    head.position = Vector3(0, 9, 0)
    g.add_child(head)
    return g
```

Avantatge: tot és reproduïble des del codi, sense dependències d'arxius externs.

---

## 9. Decisions tècniques importants

| Decisió | Justificació | Alternativa descartada |
|---------|-------------|----------------------|
| GDScript + Godot en lloc de JavaFX | JavaFX 3D era inestable i complex per a física de joc | Continuar amb JavaFX 3D |
| Un sol script `Main.gd` | Simplicitat per a un projecte d'escola, tot en context | Múltiples scripts i escenes separades |
| Arrays de posicions en lloc de classes | Menys overhead, accés directe per índex | Classe `Jugador` amb OOP |
| Física manual (no PhysicsBody3D) | Control total sobre la pilota i els rebots | Usar `RigidBody3D` de Godot |
| `_process` en lloc de `_physics_process` | Suficient per a la mecànica per torns | `_physics_process` (recomanat per fps-independence) |
| Generació procedural de tot el visual | Cap dependència d'arxius externs | Nodes dissenyats a l'editor |

---

## 10. Com ampliar el projecte

Si es volgués continuar el desenvolupament, les millores prioritàries serien:

- **Separar en escenes**: `Jugador.tscn`, `Pilota.tscn`, `UI.tscn`, `Camp.tscn`
- **Migrar a `_physics_process`**: garantir comportament idèntic a qualsevol FPS
- **Afegir sons**: `AudioStreamPlayer3D` per xuts, gols i rebots
- **Estadístiques de partida**: xuts a porta, possessió, distàncies recorregudes
- **Mode multijugador local**: segon jugador amb controls de teclat (IJKL)
- **Lliga amb classificació**: múltiples partits i puntuació acumulada

---

*Manual Tècnic – Hoquei Patins 3D – Pol Hernáez, DAM1, Escola Pia de Mataró – Maig 2026*
