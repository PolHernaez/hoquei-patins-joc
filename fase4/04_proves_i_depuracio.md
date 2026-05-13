# 04 – Proves i Depuració

**Alumne:** Pol Hernáez  
**Mòdul:** Entorns de Desenvolupament  
**Curs:** DAM1 – Escola Pia de Mataró  
**Projecte:** Hoquei Patins 3D – Godot Engine 4.6.2 / GDScript  

---

## 1. Objectiu de les proves

L'objectiu d'aquesta fase és verificar que les mecàniques principals del joc funcionen correctament: el sistema de torns, la detecció de gol, el comportament del porter (GK), la IA rival, la física de la pilota, la stamina del jugador i la fi de partida per temps. A més, es documenten les incidències reals detectades durant tot el procés de desenvolupament, que va passar per Java Swing, JavaFX i finalment Godot 4.6.

---

## 2. Taula de casos de prova

| Codi | Objectiu | Entrada / acció | Resultat esperat | Resultat obtingut | Estat |
|------|----------|----------------|-----------------|-------------------|-------|
| CP-01 | Verificar el canvi de fase quan el jugador xuta | Jugador té la pilota. Es fa drag > 8px i s'allibera el ratolí. | `phase` passa de `MY_TURN` a `SHOOTING`. `ball_free=true`, `human_ball=false`. | ✅ La fase canvia. La pilota surt amb `bvx > 0`. | ✅ Superada |
| CP-02 | Verificar la detecció de gol a la porteria rival | Pilota arriba a `bx > FW/2 + 0.1` amb `abs(bz) < GZ` (5.5). | `score_l` s'incrementa, text "GOL! ARENYS HC!", `phase = GOAL`. | ✅ Marcador puja i apareix l'animació. | ✅ Superada |
| CP-03 | Verificar que la IA rival xuta i pot marcar gols | Esperar el torn `AI_TURN`. Observar 3 partides. | FW rival es posiciona, aplica delay ~1.8s i xuta a la porteria local. | ✅ La IA xuta i ha marcat gols en proves. | ✅ Superada |
| CP-04 | Verificar el sistema REWIND | Jugador xuta (`rewinds = 3`). Prem R. | `rewinds` passa a 2. Pilota i jugador tornen a `sv_bx`, `sv_bz`. `human_ball = true`. | ✅ La posició es recupera. El comptador decreix. | ✅ Superada |
| CP-05 | Verificar la fi de partida per temps exhaurit | `time_left` arriba a 0 amb `score_l=2`, `score_r=1`. | `phase = OVER`, pantalla "🏆 VICTÒRIA!", botó "TORNAR A JUGAR". | ✅ Resultat correcte. | ✅ Superada |
| CP-06 | Verificar que el porter prediu la trajectòria de la pilota | Xut des de `bx=0, bz=2, bvx=30, bvz=5`. | `predicted_z = 2 + 5*(24-0)/30 = 6.0 → clamp → 5.0`. GK va a z=5.0. | ✅ El porter fa dive cap a la posició calculada. | ✅ Superada |
| CP-07 | Verificar restricció de zona davant la porteria rival | Clic a `x = 27.0` (zona del GK, límit és `FW/2 - 9.0 = 19.0`). | `lx[2]` queda clampat a màxim 19.0. | ✅ El jugador para a x=19.0. | ✅ Superada |
| CP-08 | Verificar que la pilota no desapareix en xutar | Xut i observar comportament durant 0.4s post-xut. | La pilota no es recull immediatament; `just_shot_timer` actua. | ✅ La pilota vola lliurement. | ✅ Superada |

---

## 3. Detall dels casos de prova

### CP-01 – Canvi de fase en xutar

**Passos:**
1. Iniciar partida en dificultat Normal.
2. Esperar que el jugador tingui la pilota (`human_ball = true`, `phase = MY_TURN`).
3. Fer clic + arrossegar el ratolí més de 8 píxels.
4. Alliberar el ratolí.

**Variables inspeccionades amb `print_debug`:**
```gdscript
print("phase: ", phase)           # ha de passar a SHOOTING (= 1)
print("ball_free: ", ball_free)   # ha de ser true
print("bvx: ", bvx)               # ha de ser > 0
print("human_ball: ", human_ball) # ha de ser false
```

**Resultat obtingut:**
```
phase: 1
ball_free: true
bvx: 32.0      # SPD_N = 32.0, correcte
human_ball: false
```
✅ Correcte.

---

### CP-02 – Detecció de gol: boundary testing

**Lògica verificada al codi:**
```gdscript
func _check_goal()->void:
    if phase==Phase.GOAL or phase==Phase.OVER: return
    if bx<-(FW/2.0+0.1) and abs(bz)<GZ: _on_goal(false)
    if bx>  FW/2.0+0.1  and abs(bz)<GZ: _on_goal(true)
```

**Valors límit testejats:**

| bz | abs(bz) < GZ (5.5)? | Resultat esperat | Resultat obtingut |
|----|---------------------|-----------------|-------------------|
| 0.0 | ✅ (0 < 5.5) | GOL | ✅ GOL |
| 5.4 | ✅ (5.4 < 5.5) | GOL | ✅ GOL |
| 5.5 | ❌ (5.5 = 5.5) | Rebot | ✅ Rebot |
| 6.0 | ❌ (6 > 5.5) | Rebot | ✅ Rebot |

---

### CP-06 – Porter prediu trajectòria real

**Càlcul manual de predicció:**
```
Pilota: bx=0, bz=2, bvx=30, bvz=5
GK posició X: goal_x = FW/2 - 4 = 24

t_to_goal = (24 - 0) / 30 = 0.8 s
predicted_z = 2 + 5 * 0.8 = 6.0
clamp(6.0, -4.9, 4.9) = 4.9
```

```gdscript
# Codi implementat:
if abs(bvx) > 0.5:
    var t_to_goal: float = (goal_x - bx) / bvx
    if t_to_goal > 0.0:
        predicted_z = bz + bvz * t_to_goal
predicted_z = clampf(predicted_z, -GZ+0.5, GZ-0.5)
```
✅ El porter va al punt màxim de la porteria — on arribarà la pilota.

---

## 4. Incidències reals detectades

### Incidència 1 – Incompatibilitat de versions JavaFX SDK 26 / JDK 21

**Descripció:** En intentar compilar amb JavaFX SDK 26 (descarregat inicialment), el compilador donava:
```
bad class file: C:\javafx-sdk-26\lib\javafx.base.jar
class file has wrong version 68.0, should be 65.0
```

**Com es va detectar:** Error de compilació en la primera comanda `javac` amb el SDK 26.

**Causa probable:** JavaFX SDK 26 genera class files de versió 68.0 (Java 24+), però el JDK instal·lat (JDK 21) espera com a màxim la versió 65.0. Incompatibilitat de versió major del bytecode Java.

**Solució aplicada:** Desinstal·lar JavaFX SDK 26 i descarregar la versió compatible:
```powershell
Remove-Item -Recurse -Force C:\javafx-sdk-26
Invoke-WebRequest -Uri "https://download2.gluonhq.com/openjfx/21.0.5/openjfx-21.0.5_windows-x64_bin-sdk.zip" `
    -OutFile "$env:USERPROFILE\Downloads\javafx-21.zip"
Expand-Archive -Path "$env:USERPROFILE\Downloads\javafx-21.zip" -DestinationPath "C:\" -Force
```
Actualitzar `.vscode/launch.json` i `.vscode/settings.json` per apuntar a `C:/javafx-sdk-21.0.5/lib`.

```powershell
# Verificació de versions:
java -version    # openjdk 21.0.10
javac -version   # javac 21.0.10
dir C:\ | Where-Object {$_.Name -like "*javafx*"}  # javafx-sdk-21.0.5 ✓
```

---

### Incidència 2 – `Color.rgb()` amb opacitat fora del rang 0.0–1.0 (JavaFX)

**Descripció:** El joc llançava l'excepció en arrencar:
```
java.lang.IllegalArgumentException: Color's opacity value (120.0) must be in the range 0.0-1.0
    at ui.GameWindow.construirPista(GameWindow.java:147)
```

**Com es va detectar:** Lectura del stack trace que apuntava a la línia 147. Es va inspeccionar la crida:
```java
Color.rgb(30, 80, 190, 120)   // ← el quart paràmetre
```

**Causa probable:** Confusió amb l'API d'Android/Swing on l'opacitat és 0–255. En JavaFX, el quart paràmetre de `Color.rgb()` és un `double` de 0.0 a 1.0.

**Solució aplicada:** Dividir l'opacitat entre 255.0:
```java
// Incorrecte:
Color.rgb(30, 80, 190, 120)

// Correcte:
Color.rgb(30, 80, 190, 120.0/255.0)  // = 0.47
```

---

### Incidència 3 – `NullPointerException` per ordre d'inicialització incorrecte (JavaFX)

**Descripció:** El joc llançava l'excepció en arrencar:
```
Caused by: java.lang.NullPointerException: Cannot invoke "javafx.scene.control.Label.setText(String)"
    because "this.lblMsg" is null
    at ui.GameWindow.setPhase(GameWindow.java:419)
    at ui.GameWindow.resetPos(GameWindow.java:443)
    at ui.GameWindow.start(GameWindow.java:81)
```

**Com es va detectar:** Lectura del stack trace complet que mostrava la cadena de crides: `start()` → `resetPos()` → `setPhase()` → `lblMsg.setText()`.

**Causa probable:** La funció `start()` cridava `resetPos()` → `setPhase()` → intentava usar `lblMsg`, però `lblMsg` era `null` perquè el HUD no s'havia construït encara.

**Solució aplicada:** Reordenar les crides de `start()`:
```java
// Incorrecte (ordre a start()):
resetPos();   // ← usa lblMsg que és null!
buildUI();    // ← lblMsg es crea aquí

// Correcte:
buildUI();    // ← primer construir la UI
resetPos();   // ← ara ja pot usar lblMsg
```

---

### Incidència 4 – `PauseTransition` no es pot subclassificar (JavaFX)

**Descripció:** Error de compilació:
```
error: cannot inherit from final javafx.animation.PauseTransition
```

**Com es va detectar:** Error de compilació en intentar compilar `GameWindow.java`.

**Causa probable:** `PauseTransition` és una classe `final`. S'havia usat la sintaxi d'inicialitzador anònim `{{ }}` que implica crear una subclasse anònima, cosa que Java no permet amb classes `final`.

**Solució aplicada:**
```java
// Incorrecte:
new PauseTransition(Duration.seconds(2.0)) {{
    setOnFinished(e -> resetPos());
    play();
}};

// Correcte:
PauseTransition pause = new PauseTransition(Duration.seconds(2.0));
pause.setOnFinished(e -> resetPos());
pause.play();
```

---

### Incidència 5 – La pilota es recol·lectava immediatament en xutar (Godot)

**Descripció:** En executar el xut, la pilota era invisible i semblava "teletransportar-se" al jugador de nou sense volar.

**Com es va detectar:** Comportament visual anòmal. Inspecció del codi d'intercepció:
```gdscript
# A _tick_ball() — el problema:
if _d2(bx, bz, float(lx[2]), float(lz[2])) < 2.0:
    ball_free = false; human_ball = true  # ← activat al mateix frame que el xut!
```

**Causa probable:** La pilota s'iniciava exactament a la posició del jugador. El check d'intercepció al frame següent la "recollectava" immediatament, de manera que el xut mai s'executava visualment.

**Solució aplicada:** Afegir `just_shot_timer` que bloqueja la recollida 0.4s post-xut, i desplaçar la pilota 2.5u en sortir:
```gdscript
var just_shot_timer: float = 0.0

func do_shoot() -> void:
    ...
    bx += dx/dd * 2.5; bz += dz/dd * 2.5  # desplaçament inicial
    just_shot_timer = 0.4

# A _tick_ball():
if just_shot_timer > 0.0: return   # ignora recollida durant 0.4s
```

---

### Incidència 6 – La IA mai xutava: timer resetejat cada frame (Godot)

**Descripció:** Durant el torn `AI_TURN`, el FW rival no xutava mai. La partida quedava encallada.

**Com es va detectar:** Cap xut de la IA en múltiples partides de test. Inspecció del bucle de la IA.

**Causa probable:** El timer es resetejava a 0.8 a cada frame mentre el rival caminava cap al punt de tir, de manera que mai arribar a 0:
```gdscript
# Incorrecte:
if dist_to_target > 5.0:
    ai_shoot_timer = 0.8   # ← resetejat CADA frame mentre camina!
```

**Solució aplicada:** El timer corre sempre que la IA té la pilota, independentment de si ha arribat o no:
```gdscript
# Correcte — a _process():
if ai_delay > 0.0:
    ai_delay -= delta
else:
    if rival_ball and r_holder >= 0:
        _ai_do_shoot()
```

---

### Incidència 7 – Rebots a la porteria: pilota mai entrava (Godot)

**Descripció:** La pilota rebotava com si hi hagués una paret invisible just davant de la porteria.

**Com es va detectar:** Comportament visual anòmal — la pilota rebotava sempre a la mateixa posició. Inspecció del codi de rebots i càlcul manual.

**Causa probable:** La paret lateral es calculava a `wx = FW/2 + 0.2 - BR = 27.72`, però la porteria és a `FW/2 = 28.0`. La pilota xocava amb la "paret" a x=27.72 ABANS d'arribar a la porteria:
```gdscript
# Incorrecte:
var wx: float = FW/2.0 + 0.2 - BR   # = 27.72
if abs(bx) > wx:
    bvx *= -0.65; bx = sign(bx)*wx  # ← rebota SEMPRE, fins i tot en zona de porteria!
```

**Solució aplicada:** Aplicar el rebot NOMÉS si la pilota és fora de la zona de porteria:
```gdscript
var wx: float = FW/2.0 + 0.2 - BR
if abs(bx) > wx:
    if abs(bz) >= GZ:              # fora de la porteria → rebota
        bvx *= -0.65; bx = sign(bx)*wx
    # si abs(bz) < GZ → la pilota pot entrar lliurement
```

---

### Incidència 8 – Porter impossible de batre (Godot)

**Descripció:** En múltiples partides de test no s'havia marcat cap gol. El porter parava tots els xuts.

**Com es va detectar:** Cap gol en 5 partides de prova. Càlcul manual de la distància màxima de la pilota.

**Causa probable:** Dos factors combinats: (1) `GK_RADIUS = 1.0` massa gran; (2) `FRIC = 0.974` feia que la pilota s'aturés massa aviat:
```
Distància màxima amb FRIC=0.974, v0=32 u/s:
d_max ≈ 32 / (1 - 0.974^60) ≈ 23u   ← porteria a 32u → no hi arriba!
```

**Solució aplicada:**
```gdscript
const FRIC: float = 0.991    # d_max ≈ 89u > 32u ✓
var GK_RADIUS: float = 0.55  # porteria parcialment assequible
```

---

### Incidència 9 – Errors de sintaxi GDScript 4.6 (múltiples ocurrències)

Durant el desenvolupament del `Main.gd` van aparèixer diversos errors de sintaxi específics de GDScript 4.6:

**a) `if...else` en una sola línia:**
```
Parse error: Expected end of statement, found "else"
```
GDScript 4.6 no permet `if cond: A else: B` en una sola línia.
```gdscript
# MAL:  if ls: score_l += 1 else: score_r += 1
# BÉ:
if ls:
    score_l += 1
else:
    score_r += 1
```

**b) Múltiples `case` en una línia dins d'un `match`:**
```
Parse error: Expected end of statement
```
Cada cas d'un `match` ha d'estar a la seva pròpia línia.
```gdscript
# MAL:  KEY_Q: _set_shot("n"); KEY_W: _set_shot("c")
# BÉ:
KEY_Q: _set_shot("n")
KEY_W: _set_shot("c")
```

**c) Inferència de tipus amb arrays genèrics:**
```
Parse error: Cannot infer type
```
`var px := lx[2]` on `lx` és un `Array` genèric no funciona.
```gdscript
# MAL:  var px := lx[2]
# BÉ:   var px: float = float(lx[2])
```

**d) Continuació de línia amb `\`:**
GDScript NO suporta `\` per continuar línies (al contrari de Python).
```gdscript
# MAL:  var result = valor_molt_llarg + \
#                    altre_valor
# BÉ:   usar variables intermèdies o tot en una línia
```

---

## 5. Tècniques de depuració usades

### a) Lectura del stack trace (JavaFX)
Per als errors de JavaFX, la tècnica principal va ser llegir el stack trace complet (`Caused by:`) que apuntava a la línia exacta i la cadena de crides que causaven l'error.

### b) Prints de diagnòstic en GDScript
Per verificar valors de física i canvis de fase:
```gdscript
print("bx=", bx, " bz=", bz, " bvx=", bvx, " phase=", phase,
      " just_shot=", just_shot_timer, " human_ball=", human_ball)
```

### c) Càlculs manuals de física
Per detectar la incidència de FRIC massa alta (INC-08) i la paret invisible (INC-07):
```
# Distància màxima pilota segons FRIC:
FRIC=0.974: d_max ≈ 23u   < 32u (porteria) → NO hi arriba
FRIC=0.991: d_max ≈ 89u   > 32u (porteria) → ✓ hi arriba

# Paret lateral vs porteria:
wx = FW/2 + 0.2 - BR = 27.72   < 28.0 (porteria) → rebota ABANS
```

### d) Boundary testing (detecció de gol)
Es van provar valors al límit exacte de `GZ = 5.5` per verificar la funció `_check_goal()` (taula a CP-02).

### e) Verificació de versions
```powershell
java -version; javac -version
dir C:\ | Where-Object {$_.Name -like "*javafx*"}
```

---

## 6. Resum d'incidències

| Codi | Descripció | Tecnologia | Causa | Solució | Estat |
|------|-----------|-----------|-------|---------|-------|
| INC-01 | SDK JavaFX 26 incompatible amb JDK 21 | JavaFX | Bytecode v68.0 vs v65.0 | Instal·lar JavaFX 21.0.5 | ✅ |
| INC-02 | `Color.rgb()` opacitat 0–255 en comptes de 0.0–1.0 | JavaFX | Confusió amb API Android/Swing | Dividir entre 255.0 | ✅ |
| INC-03 | `NullPointerException` per ordre d'inicialització | JavaFX | `resetPos()` cridada abans de construir el HUD | Reordenar crides a `start()` | ✅ |
| INC-04 | `PauseTransition` no permet inicialitzadors `{{}}` | JavaFX | Classe `final` no subclassificable | Instanciació normal + crides separades | ✅ |
| INC-05 | Pilota recollectada immediatament en xutar | Godot | Intercepció a distància 0 al mateix frame | `just_shot_timer=0.4s` + offset 2.5u | ✅ |
| INC-06 | IA mai xutava (timer resetejat cada frame) | Godot | `ai_shoot_timer` resetejat cada frame | Timer independent del moviment | ✅ |
| INC-07 | Pilota rebotava davant la porteria (paret invisible) | Godot | Check de paret a x=27.72 < porteria a x=28 | Excloure zona de porteria del rebot | ✅ |
| INC-08 | Porter impossible de batre | Godot | `GK_RADIUS=1.0` + `FRIC=0.974` | `GK_RADIUS=0.55`, `FRIC=0.991` | ✅ |
| INC-09 | Errors sintaxi GDScript 4.6 (4 tipus) | Godot | Diferències vs Python/Java | Blocs multilínia, tipus explícits | ✅ |

---

*Document generat com a evidència de la Fase 4 del projecte Hoquei Patins 3D – Pol Hernáez, DAM1, Escola Pia de Mataró – Maig 2026*