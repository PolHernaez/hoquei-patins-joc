# 02 – Model del Joc

**Alumne:** Pol Hernáez  
**Fase:** 2 – Disseny abans de programar (modelatge)

---

## 1. Components del joc

### Entitats identificades

| Entitat | Rol al joc |
|---------|-----------|
| `Jugador` | Representa un jugador amb nom, energia i habilitat |
| `Equip` | Conté un jugador representatiu i acumula gols |
| `Partit` | Gestiona l'estat global: torns, períodes, possessió i equips |
| `AccioJoc` | Enum amb totes les accions possibles (atac i defensa) |
| `IAController` | Decideix les accions de l'equip rival |
| `GamePanel` | Interfície gràfica Swing (JPanel) que mostra i actualitza l'estat |

### Dades clau (atributs principals)

**Jugador:**
- `nom`: identificador del jugador
- `energia` (0–100): afecta l'efectivitat de les accions; disminueix amb accions potents
- `habilitat` (1–10): multiplicador base per als càlculs de probabilitat

**Equip:**
- `nom`: nom de l'equip (ex: "Arenys HC")
- `gols`: marcador del partit

**Partit:**
- `equipLocal`, `equipVisitant`: els dos equips
- `torn`: torn actual (1–20)
- `periode`: període actual (1 o 2)
- `possessio`: "local" o "visitant", indica qui té la pilota

### Accions (mètodes principals)

- `Jugador.recuperarEnergia()`: incrementa energia entre torns
- `Equip.afegirGol()`: suma un gol al marcador
- `Partit.siguientTorn()`: avança el torn i comprova canvi de període
- `Partit.haAcabat()`: retorna true si s'han completat els 20 torns
- `IAController.decideixAccio()`: retorna una AccioJoc basada en l'estat del Partit
- `GamePanel.actualitzarUI()`: redibuja l'estat a la finestra Swing
- `GamePanel.mostrarResultat()`: mostra el resultat final del partit

---

## 2. Diagrama de classes

![Diagrama de classes](diagrames/diagrama_classes.svg)

### Explicació del diagrama

El diagrama mostra 6 classes amb les seves relacions:

**Associació (línia sòlida):**
- `Equip` → `Jugador`: cada equip té un jugador representatiu (1:1).
- `Partit` → `Equip` (×2): el Partit conté l'equip local i el visitant.

**Dependència (línia discontínua):**
- `GamePanel` → `Partit`: el panell llegeix i mostra l'estat del Partit.
- `GamePanel` → `IAController`: el panell crida la IA per obtenir l'acció rival.
- `IAController` → `AccioJoc`: la IA retorna un valor del enum AccioJoc.

### Com es reflectirà al codi

- `Jugador` serà una classe Java amb camps `int` i mètodes simples.
- `Equip` tindrà un atribut de tipus `Jugador` (composició).
- `Partit` tindrà dos atributs de tipus `Equip` i gestionarà tota la lògica de torns.
- `AccioJoc` serà un `enum` Java amb 5 valors.
- `IAController` serà una classe separada amb un mètode estàtic o d'instància.
- `GamePanel` serà un `JPanel` que farà de vista (MVC bàsic).

---

## 3. Diagrama de comportament (activitat)

![Diagrama de comportament](diagrames/diagrama_comportament.svg)

### Explicació del diagrama

El diagrama d'activitat representa el **bucle principal del joc** (game loop):

1. **Iniciar Partit**: es creen els dos equips i es configuren els paràmetres inicials.
2. **Mostra estat**: la UI actualitza marcador, torn, període i energia.
3. **Tria acció**: si l'equip local té possessió, el jugador tria via botons Swing; sinó, la IA decideix i el jugador tria la defensa.
4. **Calcula resultat**: s'aplica la fórmula de probabilitat basada en habilitat i energia.
5. **Actualitza gols i possessió**: es modifica l'estat del `Partit`.
6. **Fi del joc?**: si `torn == 20`, s'acaba el partit i es mostra el resultat final.
7. **Bucle (No)**: si no ha acabat, es torna al pas 2 (fletxa discontínua de retorn).

### Com es reflecteix al joc

El bucle es materialitza com un flux d'esdeveniments Swing: cada cop que el jugador prem un botó, el `GamePanel` crida la lògica del `Partit`, obté el resultat, i crida `actualitzarUI()` per refrescar la pantalla. No hi ha cap `while` explícit; el flux el controla l'event listener de Swing.

---

## 4. Estructura del repositori

```
hoquei-patins-joc/
├── README.md
├── src/
│   ├── model/
│   │   ├── Jugador.java
│   │   ├── Equip.java
│   │   ├── Partit.java
│   │   └── AccioJoc.java
│   ├── logic/
│   │   └── IAController.java
│   └── ui/
│       ├── GameWindow.java
│       └── GamePanel.java
├── diagrames/
│   ├── diagrama_classes.svg
│   └── diagrama_comportament.svg
├── docs/
│   ├── 01_idea_i_abast.md
│   ├── 02_model_del_joc.md
│   ├── 03_entorn_i_prototip.md
│   ├── 04_proves_i_depuracio.md
│   ├── 05_millores_i_reflexio_final.md
│   └── IA_log.md
└── .gitignore
```

---

## 5. Repositori inicial – primer commit

El primer commit inclou:
- Estructura de carpetes creada
- README.md amb descripció del projecte
- Diagrames UML afegits a `/diagrames`
- Aquest document com a primera documentació formal

**Missatge del primer commit:** `init: estructura del projecte i diagrames UML`

---

## 10. Codi UML (PlantUML)

Els diagrames s'han generat amb **PlantUML** (eina equivalent a UMLTree). El codi font es pot enganxar a [plantuml.com](https://www.plantuml.com/plantuml/uml/) per regenerar les imatges.

### Diagrama de Classes

```plantuml
@startuml DiagramaClasses

skinparam classBackgroundColor #161b22
skinparam classBorderColor #30363d
skinparam classFontColor #e6edf3
skinparam arrowColor #58a6ff

title Diagrama de Classes — Hoquei Patins (DAM1)

package "ui" {

  class GameWindow {
    - locTeam : List<Ent>
    - rivTeam : List<Ent>
    - human   : Ent
    - bx, bz, bvx, bvz : double
    - scoreL, scoreR : int
    - timeLeft : double
    - gameOver, goalPause : boolean
    + start(stage : Stage) : void
    + startLoop() : void
    - tick(dt : double) : void
    - buildCamera() : void
    - buildField() : void
    - buildGoals() : void
    - syncScene() : void
    - onGoal(localScored : boolean) : void
    - onGameOver() : void
  }

  class Ent {
    + x, z : double
    + tx, tz : double
    + ang : double
    + hasBall : boolean
    + human : boolean
    + role : Role
    + aiTimer : double
    + node : Group
  }

  enum Role {
    GK
    DEF
    FW
  }

  class BallState {
    + x, z : double
    + vx, vz : double
    + free : boolean
    + FRICTION : double = 0.978
    + MAX_SPEED : double = 500
    + tick(dt : double) : void
    + bounceWalls(fw : double, fh : double) : void
    + checkPickup(ents : List<Ent>) : void
  }

  class GameState {
    + scoreLocal : int
    + scoreRival : int
    + timeLeft : double
    + gameOver : boolean
    + goalPause : boolean
    + tick(dt : double) : void
    + registerGoal(local : boolean) : void
    + isFinished() : boolean
  }

  class AIController {
    - ball : BallState
    - locTeam : List<Ent>
    - rivTeam : List<Ent>
    + tickAll(dt : double) : void
    - aiGK(e : Ent, dt : double) : void
    - aiDef(e : Ent, dt : double) : void
    - aiDribble(e : Ent, dt : double) : void
    - aiPressure(e : Ent, dt : double) : void
    - shootToGoal(e : Ent) : void
  }

  class InputHandler {
    - human : Ent
    - ball : BallState
    - dragging : boolean
    - startX, startY : double
    + onMousePressed(x : double, y : double) : void
    + onMouseDragged(x : double, y : double) : void
    + onMouseReleased(x : double, y : double) : void
    - shoot(dx : double, dy : double) : void
    - moveHumanTo(wx : double, wz : double) : void
    - updateAimArrow(dx : double, dy : double) : void
  }

}

GameWindow "1" *-- "6"  Ent          : conté
GameWindow "1" *-- "1"  BallState    : conté
GameWindow "1" *-- "1"  GameState    : conté
GameWindow "1" *-- "1"  AIController : delega IA a
GameWindow "1" *-- "1"  InputHandler : delega input a
AIController  "1" o-- "1" BallState  : llegeix
AIController  "1" o-- "*" Ent        : actualitza
InputHandler  "1" o-- "1" Ent        : modifica (human)
InputHandler  "1" o-- "1" BallState  : dispara
Ent           "1" --  "1" Role       : té rol

@enduml
```

### Diagrama de Comportament (Activitat)

```plantuml
@startuml DiagramaComportament

title Diagrama de Comportament — Bucle de Joc\nHoquei Patins (DAM1)

|Inici|
start
:Inicialitza JavaFX Stage;
:Construeix camp, porteries, jugadors, pilota;
:Reset posicions inicials;
:Arrenca AnimationTimer (60 fps);

|Game Loop (~60fps)|
repeat
  :Calcula dt (delta time);

  |Timer|
  :timeLeft -= dt;
  if (timeLeft <= 0?) then (sí)
    :gameOver = true;
    :Mostra resultat final;
    stop
  endif

  |InputHandler|
  if (drag actiu?) then (sí)
    if (human té pilota?) then (sí)
      :Mostra fletxa d'aim;
    endif
  endif
  if (drag alliberat?) then (sí)
    if (human té pilota?) then (sí)
      :shoot(dx, dy) → bvx, bvz;
    endif
  endif
  if (clic simple al terra?) then (sí)
    :human.tx = worldX;
    :human.tz = worldZ;
  endif

  |BallState|
  if (algú té la pilota?) then (sí)
    :bx = holder.x + cos(ang)×22;
    :bz = holder.z + sin(ang)×22;
  else (pilota lliure)
    :bx += bvx × dt;
    :bz += bvz × dt;
    :Aplica fricció;
    :Comprova rebots a les bandes;
    :Comprova recollida (dist < 28u);
    if (jugador proper?) then (sí)
      :hasBall = true;
    endif
  endif

  |Moviment Humà|
  if (pilota lliure i lluny?) then (sí)
    :human.tx = bx (s'apropa sol);
  endif
  :Mou human cap a (tx,tz);

  |AIController|
  fork
    :GK local → segueix pilota en Z;
  fork again
    :DEF local → pressiona rival;
  fork again
    :GK rival → segueix pilota en Z;
  fork again
    :DEF rival → pressiona local;
  fork again
    if (FW rival hasBall?) then (sí)
      :Dribla serpentejant;
      :aiTimer += dt;
      if (condició de xut?) then (sí)
        :Xuta cap a porteria;
      endif
    else (no)
      :Va a la pilota;
    endif
  end fork

  |Detecció de Gol|
  if (bx < -FW/2 i dins porteria?) then (gol rival)
    :scoreR++;
    :Pausa 2s + reset;
  else if (bx > FW/2 i dins porteria?) then (gol local)
    :scoreL++;
    :Pausa 2s + reset;
  endif

  |Render|
  :syncScene() → aplica posicions als nodes JavaFX;
  :Actualitza HUD;

repeat while (gameOver = false?) is (continua)

|Final|
:Mostra Victòria / Derrota / Empat;
stop

@enduml
```

