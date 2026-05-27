# 06 – Manual d'Usuari

**Projecte:** Hoquei Patins 3D  
**Alumne:** Pol Hernáez – DAM1 – Escola Pia de Mataró  

---

## Nom del joc

**Hoquei Patins 3D** — *Arenys HC vs Rivals FC*

---

## Descripció

Joc d'hoquei sobre patins per torns en 3D. Tu controles el davanter de l'Arenys HC (equip vermell) i has de marcar més gols que els rivals (equip blau) abans que s'acabi el temps.

---

## Com executar el joc

1. Obre **Godot Engine 4.6.2** (el fitxer `.exe`)
2. El projecte `hoquei-patins-godot` apareix a la llista → clica **Editar**
3. Prem **F5** per iniciar

---

## Pantalla d'inici

Quan arrenca el joc apareix el **menú principal** amb tres opcions de dificultat:

| Botó | Dificultat | Descripció |
|------|-----------|-----------|
| 😊 Fàcil | Baixa | Porter lent, IA poc agressiva |
| ⚽ Normal | Mitjana | Porter i IA equilibrats |
| 💀 Difícil | Alta | Porter molt ràpid, IA agressiva |

Selecciona la dificultat i comença la partida.

---

## Objectiu

Marcar més gols que els rivals en **2 minuts** de partida.

- Si marques més gols → **🏆 VICTÒRIA**
- Si en reps més → **💀 DERROTA**
- Si acabeu igualats → **🤝 EMPAT**

---

## Controls

### Moviment del jugador

| Acció | Control |
|-------|---------|
| Moure el jugador | Clic a qualsevol punt de la pista |
| Moure cap a l'esquerra | Tecla **A** |
| Moure cap a la dreta | Tecla **D** |
| Moure cap avall | Tecla **S** |
| Moure cap amunt | Tecla **F** |

### Xut

| Acció | Control |
|-------|---------|
| Apuntar i xutar | **Arrossegar el ratolí** + alliberar |
| Xutar normal | Tecla **Q** (o arrossegar) |
| Xutar amb efecte/corba | Tecla **W** |
| Xutar fort | Tecla **E** |
| Xutar sense apuntar | **Barra espaiadora** o **Enter** |

> 💡 **Com funciona el xut:** Prem el botó del ratolí i arrossega. Com més llarg el drag, més potència. La fletxa de colors (verd → groc → vermell) mostra la direcció i la potència. Quan alliberes, la pilota surt disparada.

### Passades i utilitats

| Acció | Control |
|-------|---------|
| Passar al company | Tecla **P** |
| Rewind (desfer el xut) | Tecla **R** — màxim 3 usos per partida |
| Rotar la càmera | Tecles **← →** |
| Reset càmera | Tecla **↑** |
| Pausar la partida | Tecla **Esc** |

---

## Indicadors de la pantalla (HUD)

![Captura del joc en marxa](../fase3/captura2.png)

| Element | Ubicació | Descripció |
|---------|---------|-----------|
| Marcador local | Cantonada superior esquerra | Gols de l'Arenys HC (vermell) |
| Marcador rival | Cantonada superior dreta | Gols dels Rivals FC (blau) |
| Rellotge | Centre superior | Temps restant en format M:SS |
| Missatge central | Centre pantalla | Torn actual, avisos i GOL! |
| Barra de potència (PW) | Inferior esquerra | Potència del xut (puja en arrossegar) |
| Barra de stamina (ST) | Inferior esquerra | Energia del jugador (blau = fresc, vermell = cansat) |

---

## La stamina

El teu jugador té **energia limitada**. Si corres molt, la barra ST baixa de blau a vermell. Quan és vermella, el jugador va molt més lent.

- La stamina es **buidar en ~2.6 segons** corrent
- Es **recupera en ~14 segons** aturant-se
- Gestiona bé quan corres per no quedar-te sense forces en el moment important

---

## Mecàniques de joc

### Torns
El joc funciona per torns. Quan és **el teu torn** (posa "EL TEU TORN" al centre), tens control del teu jugador. Quan és el torn rival, la IA juga.

### Recuperar la pilota
- **Clic** a prop de la pilota quan és lliure → la reculls
- **Apropa't** al rival que la té → interca la pilota (a 3 unitats de distància)
- Tens **1.2 segons d'invulnerabilitat** quan agafes la pilota: la IA no te la pot robar immediatament

### Disc indicador groc
Quan la pilota és a l'aire, apareix un **disc groc pulsant** al terra que mostra exactament on caurà. Usa'l per posicionar-te abans que arribi.

### Rewind
Si xutes i la pilota no va on vols, prem **R** per desfer el xut. Tens **3 usos** per partida. Ús intel·ligent: guarda'l per situacions crítiques.

---

## Menú de pausa

Prem **Esc** en qualsevol moment per pausar. Apareix un panell amb:

- **Marcador actual** i temps restant
- **▶ Reprendre la partida** → continua
- **🔄 Reiniciar partida** → reinicia tot des de zero
- **🏠 Menú principal** → torna a la selecció de dificultat

---

## Regles bàsiques

1. La pilota pot rebotar a les bandes laterals i a les porteries
2. No pots entrar a l'àrea del porter rival (zona restringida a partir de meitat del camp ofensiu)
3. El porter rival fa **dive** en la direcció on preveu que anirà la pilota
4. Si la pilota surt del camp, torna automàticament al centre

---

## Consells per jugar millor

- **Apunta als costats de la porteria** — el porter cobreix bé el centre
- **No corris sempre** — gestiona la stamina per tenir velocitat en els moments clau
- **Usa l'efecte (W)** per fer curvar la pilota i sorprendre el porter
- **Passa al company** (P) per canviar l'angle d'atac
- **Observa el disc groc** per anticipar on caurà la pilota en els rebots
- En mode Difícil, l'error del porter es redueix al 10% — has d'apuntar molt bé als extrems

---

## Pantalla de resultat final

Quan el rellotge arriba a **0:00** apareix la pantalla final amb:

- 🏆 **VICTÒRIA** (verd) si has marcat més gols
- 💀 **DERROTA** (vermell) si n'has rebut més
- 🤝 **EMPAT** (groc) si el marcador és igualat

Pots clicar **TORNAR A JUGAR** per iniciar una nova partida.

---

*Manual d'Usuari – Hoquei Patins 3D – Pol Hernáez, DAM1, Escola Pia de Mataró – Maig 2026*
