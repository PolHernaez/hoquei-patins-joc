# 05 – Millores i Reflexió Final

**Alumne:** Pol Hernáez  
**Mòdul:** Entorns de Desenvolupament  
**Curs:** DAM1 – Escola Pia de Mataró  
**Projecte:** Hoquei Patins 3D – Godot Engine 4.6.2 / GDScript  

---

## 1. Millores identificades

| Codi | Millora detectada | Motiu | Prioritat |
|------|-------------------|-------|-----------|
| M-01 | Porter intel·ligent: prediu trajectòria real de la pilota | El GK feia dive aleatori basat en `sin(aim_ang)*FW`, que no corresponia a on anava la pilota | Alta |
| M-02 | Reequilibri del joc: velocitat de xut de la IA reduïda | La IA xutava a 30–52 u/s i el GK local no podia reaccionar; cada atac rival era gol | Alta |
| M-03 | Radi de parada del GK ampliat durant el dive | `GK_RADIUS=0.55` estàtic feia que el GK s'hagués de situar a menys de 0.55u de la pilota, massa restrictiu | Alta |
| M-04 | Menú de pausa amb ESC | No hi havia manera d'aturar la partida ni consultar el marcador sense esperar el final | Mitjana |
| M-05 | Restricció de zona davant la porteria rival | El jugador podia plantar-se a 1.4u del GK rival i xutar des de distància nul·la | Alta |
| M-06 | Sistema de stamina del jugador | Sense límit de velocitat, el jugador podia córrer indefinidament per tot el camp | Mitjana |

---

## 2. Millores aplicades

### M-01 – Porter intel·ligent: predicció de trajectòria real

**Problema:** El GK calculava `predicted_z = sin(aim_ang) * FW`, que podia donar valors de ±56 unitats. Sempre quedava clampat als extrems, de manera que el porter sempre anava al costat equivocat.

**Abans (incorrecte):**
```gdscript
func _trigger_gk_dive(is_local:bool)->void:
    var shot_angle:float = aim_ang
    var predicted_z:float = sin(shot_angle) * FW   # ← NO té res a veure amb la trajectòria real
    if randf() < error_chance:
        predicted_z = -predicted_z + (randf()-0.5)*GZ
```

**Després (correcte):**
```gdscript
func _trigger_gk_dive(is_local:bool)->void:
    var goal_x:float = FW/2.0 - 4.0   # posició X del GK
    var predicted_z:float = bz
    if abs(bvx) > 0.5:
        var t_to_goal:float = (goal_x - bx) / bvx
        if t_to_goal > 0.0:
            predicted_z = bz + bvz * t_to_goal   # ← intersecció real trajectòria-línia GK
    predicted_z = clampf(predicted_z, -GZ+0.5, GZ-0.5)
```

**Resultat:** El porter ara s'anticipa correctament. Amb un error de lectura aleatori per dificultat (55% Fàcil, 28% Normal, 10% Difícil), el joc és equilibrat.

---

### M-02 – Reequilibri: velocitat de xut de la IA i radi de parada del GK

**Problema:** La IA xutava a 30–52 u/s. Distància GK-porteria ≈ 24u. Temps pilota fins al GK: `24/41 ≈ 0.58s`. El GK a 5.5 u/s podia córrer `0.58*5.5 = 3.2u`. Però havia de cobrir fins a 5.5u de costat → impossible al 100% dels casos.

A més, `GK_RADIUS=0.55` era massa petit: el GK havia de situar-se a menys de 0.55u de la pilota per aturar-la, però si la predicció tenia un error de ±1u ja fallava.

**Abans:**
```gdscript
var spd:float = 30.0 + randf()*22.0           # 30–52 u/s (massa ràpid)
...
var GK_RADIUS: float = 0.55                    # radi estàtic petit
if _d2(bx,bz,float(lx[0]),lgk_z) < GK_RADIUS  # sempre 0.55
```

**Després:**
```gdscript
var spd:float = 20.0 + randf()*14.0           # 20–34 u/s (GK pot reaccionar)
...
var GK_RADIUS: float = 0.75                    # Normal (Easy:0.45, Hard:1.05)
var eff_radius:float = GK_RADIUS
if lgk_dive_active: eff_radius = GK_RADIUS*2.8 # dive cobreix zona major
if _d2(bx,bz,float(lx[0]),lgk_z) < eff_radius  # radi ampliat en dive
```

**Resultat:** Amb velocitat 20–34 u/s, el GK té `24/27 ≈ 0.89s` per reaccionar i pot cobrir `0.89*5.5 = 4.9u` → gairebé tota la porteria. El joc és competitiu: es pot marcar gol però no sempre.

---

### M-03 – Menú de pausa (ESC)

**Problema:** No hi havia manera d'aturar la partida. Si sonava el telèfon o calia sortir, la partida seguia. Tampoc es podia consultar el marcador ni reiniciar sense esperar el final.

**Implementació:**
```gdscript
# Variables afegides:
var paused: bool = false
var pause_panel: Panel
var pause_lbl_score: Label
var pause_lbl_time: Label

# Al _process:
if paused: return   # tot el joc congelat

# Al _input:
if event.keycode == KEY_ESCAPE: _toggle_pause(); return

# _toggle_pause():
func _toggle_pause()->void:
    if in_menu or phase==Phase.GOAL or phase==Phase.OVER: return
    paused = !paused
    cl_pause.visible = paused
    if paused:
        pause_lbl_score.text = "%d  –  %d" % [score_l, score_r]
        pause_lbl_time.text  = "⏱  %d:%02d restants" % [mins, secs]
```

**Panell de pausa:** Apareix centrat en pantalla amb fons semi-transparent. Mostra el marcador actual (ex: "2 – 1"), el temps restant (ex: "⏱ 1:34 restants") i tres botons:
- **▶ Reprendre la partida** → torna al joc
- **🔄 Reiniciar partida** → reinicia tot (marcador, temps, posicions)
- **🏠 Menú principal** → torna al menú de selecció de dificultat

**Resultat:** Premint ESC durant qualsevol fase del joc (excepte GOAL o OVER), la partida es congela completament i apareix el menú de pausa.

---

### M-04 – Restricció de zona davant la porteria rival

**Problema:** El jugador podia arribar fins a `x = FW/2 - 1.4 = 26.6`, a menys de 3 unitats del GK rival (a x=24). Des d'aquella posició, qualsevol xut era gol garantit.

**Abans:**
```gdscript
lx[2] = clampf(float(lx[2]), -FW/2.0+1.4, FW/2.0-1.4)  # fins x=26.6
```

**Després:**
```gdscript
lx[2] = clampf(float(lx[2]), -FW/2.0+1.4, FW/2.0-9.0)  # màxim x=19.0
```

**Resultat:** El jugador ha de xutar des d'almenys 5 unitats de distància del GK rival (que és a x=24). El joc requereix punteria real.

---

### M-05 – Sistema de stamina del jugador

**Problema:** El jugador podia córrer indefinidament a 18 u/s per tot el camp, cosa que no representava el cansament real d'un esportista i permetia recuperar la pilota sempre.

**Implementació:**
```gdscript
const STAMINA_DRAIN: float = 38.0   # es buida en ~2.6s corrent
const STAMINA_REGEN: float = 7.0    # es recupera en ~14s parat

# stam_factor controla la velocitat:
var stam_factor: float = 0.18 + (stamina/STAMINA_MAX) * 0.82
# → A 0% stamina: velocitat = 18 * 0.18 = 3.24 u/s (cames de plom)
# → A 100% stamina: velocitat = 18 * 1.0 = 18 u/s (màxim)
```

**Resultat:** Barra visual blava (ST) al costat de la barra de potència. Canvia de blau (descanssat) a vermell (esgotat). Afegeix una capa de gestió estratègica: no pots córrer sempre al màxim.

---

## 3. Evidència de les millores (commits del repositori)

| Commit | Hash | Descripció |
|--------|------|-----------|
| Fase 3 inicial | `461652f` | Estructura i documents inicials |
| Codi JavaFX + Swing | `0233846` | Primera versió visual amb Graphics2D |
| Reset + Godot | `03563ca` | Canvi de tecnologia a Godot 4.6 + 12 millores |
| 12 millores + doc fase3 | `a0c35f9` | Porter dive, trail, stamina, predicció GK |
| Captures fase3 | `17b6474` | Captures de pantalla de les 5 situacions |

---

## 4. Documentació mínima útil afegida

Al fitxer `Main.gd` es van afegir comentaris tècnics per a cada millora:
```gdscript
## MILLORA 1: Sistema de parades del porter (dive + predicció trajectòria real)
## MILLORA 13: Stamina del jugador (velocitat baixa si corres molt)
## MILLORA 15: Menú de pausa (ESC) amb marcador, temps i opcions
```

Al `README.md` del repositori es van afegir les instruccions d'execució amb Godot, els controls del joc i l'estructura del projecte.

---

## 5. Reflexió final

### Decisions tècniques preses

La decisió més important del projecte va ser abandonar JavaFX i migrar a Godot 4.6. JavaFX no és un motor de jocs: gestionar la càmera 3D, la física de la pilota i els models dels jugadors en un `Canvas3D` de JavaFX va resultar extraordinàriament complex i inestable. Cada sessió de debug resolíem un bug i n'apareixia un altre. Amb Godot, la mateixa funcionalitat es va aconseguir en una fracció del temps.

Dins de Godot, la decisió de fer-ho tot proceduralment en un sol script (`Main.gd` de ~1.340 línies) va ser deliberada: manté la coherència i facilita la revisió, tot i que un projecte gran hauria d'estar modularitzat en escenes i scripts separats.

### Dificultats trobades

La dificultat principal va ser el **balanç del joc**: trobar els valors correctes de `GK_RADIUS`, velocitat de xut de la IA i `FRIC` per a que el joc fos divertit. Cada paràmetre afectava els altres d'una manera no obvia. La solució va ser calcular les distàncies manualment (temps de vol de la pilota, velocitat màxima del GK) i ajustar fins a obtenir un equilibri jugable.

Una altra dificultat van ser els errors de sintaxi específics de **GDScript 4.6** que difereixen de Python: el `if...else` en una sola línia, els casos `match` en la mateixa línia, la inferència de tipus amb arrays genèrics, i la manca de continuació de línies amb `\`.

### Ús de la IA

S'ha fet servir Claude (Anthropic) com a eina principal de vibe coding durant tot el projecte, seguint el requisit de l'assignatura. La IA ha generat el codi, els documents de fases i els diagrames UML.

**Decisió acceptada de la IA:** La predicció de trajectòria del porter (`predicted_z = bz + bvz * t_to_goal`) és matemàticament correcta i funciona molt millor que el sistema anterior. Es va acceptar completament.

**Decisió descartada de la IA:** En una de les primeres versions, la IA va proposar usar `get_tree().paused = true` per congelar el joc en pausa. Es va descartar perquè a Godot això afecta tots els nodes i hauria deshabilitat els botons del menú de pausa. En el seu lloc es va implementar una variable `paused` manual que congela el `_process` però deixa activa la UI.

**Cosa apresa sobre la IA:** La IA pot generar codi correcte sintàcticament però amb errors de lògica de joc (com la velocitat de la IA massa alta o el radi del GK massa petit). Cal provar i verificar cada canvi, no assumir que el codi funcionarà bé sense provar-ho.

### Què milloraria amb més temps

- **Multijugador en xarxa** (2 jugadors en la mateixa pantalla o online)
- **Animacions de cicle de carrera** per als jugadors en lloc de moure el node sencer
- **Sons i música** (xut, gol, temps esgotat)
- **Mapa de calor** de les zones on es marquen més gols
- **Estadístiques de partida** (xuts a porta, possessió, distàncies recorregudes)
- **Lliga amb múltiples partits** i classificació

---

*Document generat com a evidència de la Fase 5 del projecte Hoquei Patins 3D – Pol Hernáez, DAM1, Escola Pia de Mataró – Maig 2026*
