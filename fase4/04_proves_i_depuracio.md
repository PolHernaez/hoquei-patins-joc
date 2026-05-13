# 04 – Proves i Depuració

**Alumne:** Pol Hernáez  
**Mòdul:** Entorns de Desenvolupament  
**Curs:** DAM1 – Escola Pia de Mataró  
**Projecte:** Hoquei Patins 3D – Godot Engine 4.6.2 / GDScript  

---

## 1. Objectiu de les proves

L'objectiu d'aquesta fase és verificar que les mecàniques principals del joc funcionen correctament: el sistema de torns, la detecció de gol, la física de la pilota, el comportament del porter (GK), la stamina del jugador i la fi de partida per temps. A més, es documenten les incidències reals detectades durant el desenvolupament i les tècniques de depuració aplicades.

---

## 2. Taula de casos de prova

| Codi | Objectiu | Entrada / acció | Resultat esperat | Resultat obtingut | Estat |
|------|----------|-----------------|-----------------|-------------------|-------|
| CP-01 | Verificar el canvi de fase quan el jugador xuta | Jugador té la pilota (`human_ball=true`). Es fa drag i s'allibera el ratolí. | `phase` passa de `MY_TURN` a `SHOOTING`. `ball_free=true`, `human_ball=false`. | ✅ La fase canvia correctament. La pilota surt amb `bvx > 0`. | ✅ Superada |
| CP-02 | Verificar la detecció de gol a la porteria rival | Pilota amb `bvx > 0`, arriba a `bx > FW/2 + 0.1` amb `abs(bz) < GZ` (5.5). | `score_l` s'incrementa en 1, apareix text "GOL! ARENYS HC!", `phase = GOAL`. | ✅ El marcador puja i s'activa l'animació de gol. | ✅ Superada |
| CP-03 | Verificar que la stamina baixa en córrer i que redueix la velocitat | Jugador es mou contínuament durant 3 segons (clic lluny a la pista). | `stamina` baixa de 100 a 0 en ~2.6s. Velocitat passa de 18 u/s a ~3.2 u/s (18 × 0.18). | ✅ La stamina baixa i la velocitat es redueix visiblement. La barra canvia de blau a vermell. | ✅ Superada |
| CP-04 | Verificar el sistema REWIND | Jugador xuta (`rewinds = 3`). Prem R. | `rewinds` passa a 2. `bx`, `bz` tornen a `sv_bx`, `sv_bz`. `human_ball = true`, `phase = MY_TURN`. | ✅ La pilota i el jugador tornen a la posició guardada. El comptador de rewinds decreix. | ✅ Superada |
| CP-05 | Verificar la fi de partida per temps exhaurit | `time_left` arriba a 0 amb `score_l=2`, `score_r=1`. | `phase = OVER`, apareix pantalla de resultat amb "🏆 VICTÒRIA!" en groc. | ✅ La pantalla de resultat apareix correctament. El rellotge queda a "0:00". | ✅ Superada |
| CP-06 | Verificar que el porter rival no surt de la porteria en fer dive | Es xuta a `bz = +4.8` (extrem dret de la porteria, `GZ = 5.5`). | GK rival fa dive cap a la zona correcta. `rgk_dive_z` queda `clampf(pred_z, -4.9, 4.9)`. | ✅ El porter va cap a la zona del xut i queda dins dels límits. | ✅ Superada |
| CP-07 | Verificar que el jugador no pot entrar a l'àrea rival | Es fa clic a `x = 27.0` (dins l'àrea del GK rival, límit és `FW/2 - 9.0 = 19.0`). | `lx[2]` queda clampat a màxim 19.0 en X. No arriba a la porteria. | ✅ El jugador para a x=19.0 i no pot avançar més. | ✅ Superada |

---

## 3. Detall dels casos de prova

### CP-01 – Canvi de fase en xutar

**Passos:**
1. Iniciar partida en dificultat Normal.
2. Esperar que el jugador tingui la pilota (`human_ball = true`, phase = `MY_TURN`).
3. Fer clic i arrossegar el ratolí cap a la dreta.
4. Alliberar el ratolí.

**Variables inspeccionades:**
```gdscript
print("phase: ", phase)        # ha de passar a SHOOTING
print("ball_free: ", ball_free) # ha de ser true
print("bvx: ", bvx)            # ha de ser > 0
print("human_ball: ", human_ball) # ha de ser false
```

**Resultat obtingut:**
```
phase: 1        # SHOOTING = 1 a l'enum Phase
ball_free: true
bvx: 32.0       # SPD_N = 32.0
human_ball: false
```

✅ Correcte. La pilota surt amb la velocitat esperada `SPD_N = 32.0`.

---

### CP-02 – Detecció de gol

**Passos:**
1. Forçar manualment `bx = 29.0`, `bz = 0.0`, `bvx = 10.0` per simular una pilota entrant.
2. Executar `_check_goal()` al frame següent.

**Lògica verificada al codi:**
```gdscript
func _check_goal()->void:
    if phase==Phase.GOAL or phase==Phase.OVER: return
    if bx<-(FW/2.0+0.1) and abs(bz)<GZ: _on_goal(false)
    if bx>  FW/2.0+0.1  and abs(bz)<GZ: _on_goal(true)  # ← s'activa
```

Amb `bx = 29.0 > 28.1` i `abs(0.0) < 5.5`, la condició és `true`.

**Resultat obtingut:** `score_l` puja a 1, apareix el label animat "⚽ GOL!" ✅

---

### CP-03 – Stamina i velocitat

**Prova de càlcul manual:**

Amb `stamina = 0`:
```
stam_factor = 0.18 + (0/100) * 0.82 = 0.18
spd = 18.0 * 0.18 = 3.24 u/s
```

Amb `stamina = 100`:
```
stam_factor = 0.18 + (100/100) * 0.82 = 1.0
spd = 18.0 * 1.0 = 18.0 u/s
```

Temps fins a buidar stamina (`STAMINA_DRAIN = 38.0/s`):
```
100 / 38 ≈ 2.63 segons corrent contínuament
```

✅ Els càlculs coincideixen amb el comportament observat al joc.

---

### CP-06 – Dive del porter amb predicció de trajectòria

**Lògica de predicció implementada:**
```gdscript
func _trigger_gk_dive(is_local:bool)->void:
    var goal_x:float = FW/2.0 - 4.0   # posició GK rival
    var predicted_z:float = bz
    if abs(bvx) > 0.5:
        var t_to_goal:float = (goal_x - bx) / bvx
        if t_to_goal > 0.0:
            predicted_z = bz + bvz * t_to_goal
    predicted_z = clampf(predicted_z, -GZ+0.5, GZ-0.5)
    rgk_dive_active = true
    rgk_dive_z = predicted_z
```

**Exemple:** Pilota a `bx = 0`, `bz = 2.0`, `bvx = 30.0`, `bvz = 5.0`.
```
t_to_goal = (24 - 0) / 30 = 0.8 segons
predicted_z = 2.0 + 5.0 * 0.8 = 6.0 → clamp(6.0, -5.0, 5.0) = 5.0
```

✅ El porter va al punt màxim de la porteria, que és on acabarà la pilota si no l'atura.

---

## 4. Incidències reals detectades

### Incidència 1 – Porter rival feia dive a una posició incorrecta

**Descripció:** El porter rival (`rx[0]`) es llançava en una direcció que no corresponia a la trajectòria real de la pilota. En molts xuts, el porter anava cap a un extrem mentre la pilota entrava per l'altre costat.

**Com es va detectar:** Jugant diverses partides es va observar que marcar gol era trivial: independentment d'on es xutés, el porter fallava sistemàticament. Es va inspeccionar la funció `_trigger_gk_dive()`.

**Causa probable:** La posició de dive es calculava com `sin(aim_ang) * FW`, on `aim_ang` és l'angle de la fletxa d'apuntament en l'espai de pantalla. Aquest càlcul no te en compte la posició real de la pilota ni la seva velocitat. Donava valors desproporcionats (fins a ±56 u) que quedaven clampats aleatòriament als extrems.

**Codi original (incorrecte):**
```gdscript
func _trigger_gk_dive(is_local:bool)->void:
    var shot_angle:float = aim_ang
    var predicted_z:float = sin(shot_angle) * FW  # ← MAL
    ...
```

**Solució aplicada:** Substituir el càlcul per la intersecció real de la trajectòria de la pilota (posició + velocitat) amb la línia X del porter:
```gdscript
var predicted_z:float = bz
if abs(bvx) > 0.5:
    var t_to_goal:float = (goal_x - bx) / bvx
    if t_to_goal > 0.0:
        predicted_z = bz + bvz * t_to_goal
```

**Resultat:** El porter ara s'anticipa correctament. Es va mantenir un marge d'error aleatori per dificultat (28% en Normal, 55% en Fàcil, 10% en Difícil) per no fer-lo infalible.

---

### Incidència 2 – El jugador podia plantar-se davant la porteria rival

**Descripció:** El forward humà (`lx[2]`) podia arribar fins a `x = 26.6` (camp de 56 u, clamp a `FW/2 - 1.4`), pràcticament dins la porteria rival a `x = 28`. Això permetia xutar des d'una distància de menys de 2 unitats del porter, fent impossible la defensa.

**Com es va detectar:** En partides de prova es comprovà que fent clic just davant la porteria, el jugador s'hi posicionava i qualsevol xut era gol garantit. La zona de clamp era la mateixa que la dels altres jugadors, sense cap restricció d'àrea.

**Causa probable:** La funció `_human_move()` clampa el jugador als límits físics del camp (`FW/2 - 1.4 = 26.6`) però no té en compte cap "àrea de porter" o zona restringida. No hi havia lògica de zona per al jugador humà.

**Codi original (incorrecte):**
```gdscript
lx[2]=clampf(float(lx[2]),-FW/2.0+1.4, FW/2.0-1.4)  # ← fins a x=26.6
```

**Solució aplicada:** Restringir el límit dret del jugador a `FW/2 - 9.0 = 19.0`, forçant-lo a disparar des de fora la zona del porter (que es troba a `x = 24`):
```gdscript
lx[2]=clampf(float(lx[2]),-FW/2.0+1.4, FW/2.0-9.0)  # màx x = 19.0
```

**Resultat:** El jugador ha de disparar des d'almenys 5 unitats de distància del porter rival, fent la defensa viable.

---

### Incidència 3 – Stamina massa permissiva (velocitat mínima excessiva)

**Descripció:** Tot i implementar el sistema de stamina, el jugador continuava movent-se pràcticament a velocitat normal quan la stamina estava a 0. L'efecte de cansament no es notava.

**Com es va detectar:** Es va deixar el jugador corrent fins a buidar la barra de stamina. La velocitat observada no disminuïa prou com per suposar un canvi real de joc.

**Causa probable:** La fórmula inicial era `stam_factor = 0.45 + (stamina/100) * 0.55`. Amb `stamina = 0`, `stam_factor = 0.45`, que aplicat a `18 u/s` dona `8.1 u/s` — encara força ràpid. A més, `STAMINA_DRAIN = 22/s` implicava ~4.5 segons per buidar-se, i `STAMINA_REGEN = 14/s` deixava recuperar en ~7 segons.

**Valors originals (poc efectius):**
```gdscript
const STAMINA_DRAIN: float = 22.0
const STAMINA_REGEN: float = 14.0
var stam_factor: float = 0.45 + (stamina/STAMINA_MAX) * 0.55
# → velocitat mínima: 18 × 0.45 = 8.1 u/s  (massa ràpid)
```

**Solució aplicada:**
```gdscript
const STAMINA_DRAIN: float = 38.0   # buidat en ~2.6s
const STAMINA_REGEN: float = 7.0    # recuperació en ~14s
var stam_factor: float = 0.18 + (stamina/STAMINA_MAX) * 0.82
# → velocitat mínima: 18 × 0.18 = 3.24 u/s  (quasi parat)
```

**Resultat:** Ara el cansament és palpable. Després de ~2.6 s de sprint continu, el jugador es queda a 18% de velocitat i necessita ~14 s parat per recuperar-se totalment.

---

## 5. Tècniques de depuració usades

### a) Prints de diagnòstic (print_debug)

Per verificar els valors de física de la pilota i els canvis de fase:

```gdscript
# Afegit temporalment a _process() per monitorar la pilota
func _process(delta: float) -> void:
    print("bx=", bx, " bz=", bz, " bvx=", bvx, " bvz=", bvz,
          " phase=", phase, " stamina=", stamina)
    ...
```

Això va permetre detectar que `bvx` tenia valors normals però que la pilota travessava la porteria sense activar `_check_goal()` en alguns casos de `phase == GOAL` no resolt.

### b) Inspecció de constants i càlculs en paper

Per a la incidència del porter, es va calcular manualment:
```
# Prova: bx=0, bz=2, bvx=30, bvz=8
t = (24 - 0) / 30 = 0.8 s
predicted_z = 2 + 8 * 0.8 = 8.4 → clamp(-5.0, 5.0) = 5.0
```
Comparant amb el resultat de `sin(aim_ang) * FW`, que podia donar valors de ±30 o més, es va confirmar que el càlcul original era incorrecte.

### c) Anàlisi del codi font (lectura estàtica)

Per a la incidència de zona, es va revisar directament la funció `_human_move()` i es van comparar els valors de clamp amb les coordenades de camp del HANDOFF:

```
FW = 56.0 → FW/2 = 28.0 (porteria)
GK rival a: FW/2 - 4.0 = 24.0
Clamp anterior: FW/2 - 1.4 = 26.6  ← massa a prop
Clamp nou:      FW/2 - 9.0 = 19.0  ← 5 u de distància del GK
```

### d) Proves de valors límit (boundary testing)

Per verificar la detecció de gol es van provar valors al límit exacte de `GZ = 5.5`:

| bz testejat | abs(bz) < GZ? | Resultat esperat | Resultat obtingut |
|-------------|----------------|-----------------|-------------------|
| 0.0 | ✅ sí (0 < 5.5) | GOL | ✅ GOL |
| 5.4 | ✅ sí (5.4 < 5.5) | GOL | ✅ GOL |
| 5.5 | ❌ no (5.5 = 5.5) | Rebot | ✅ Rebot (fora) |
| 6.0 | ❌ no (6 > 5.5) | Rebot | ✅ Rebot (fora) |

### e) Error de sintaxi GDScript – `if` en una sola línia

Durant el desenvolupament es va produir l'error:
```
Parse Error: Expected end of statement, got "else"
```

**Causa:** GDScript 4.6 no permet `if cond: A else: B` en una sola línia si les accions no són simples assignacions en alguns contextos.

**Solució:**
```gdscript
# MAL (generava error):
if ls: score_l+=1 else: score_r+=1

# BÉ:
if ls:
    score_l += 1
else:
    score_r += 1
```

---

## 6. Resum d'incidències

| Codi | Descripció | Causa | Solució | Estat |
|------|-----------|-------|---------|-------|
| INC-01 | GK rival feia dive a posició incorrecta | Càlcul `sin(aim_ang)*FW` no representa la trajectòria real | Predicció amb `bz + bvz * t` (intersecció de trajectòria) | ✅ Resolta |
| INC-02 | Jugador accedia a l'àrea del porter rival | Clamp de moviment fins a `x = 26.6`, massa a prop de la porteria | Clamp restringit a `x = 19.0` (`FW/2 - 9.0`) | ✅ Resolta |
| INC-03 | Stamina massa permissiva, sense efecte real | `stam_factor` mínim 0.45 → velocitat mínima 8.1 u/s | Factor mínim 0.18 → velocitat mínima 3.24 u/s | ✅ Resolta |
| INC-04 | Error de sintaxi `if...else` en una línia | GDScript 4.6 no admet `if cond: A else: B` com a Python | Separar en blocs multilínia | ✅ Resolta |

---

*Document generat com a evidència de la Fase 4 del projecte Hoquei Patins 3D – Pol Hernáez, DAM1, Escola Pia de Mataró – Maig 2026*
