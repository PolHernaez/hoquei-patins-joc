# 05 – Millores i Reflexió Final

**Alumne:** Pol Hernáez  
**Mòdul:** Entorns de Desenvolupament  
**Curs:** DAM1 – Escola Pia de Mataró  
**Projecte:** Hoquei Patins 3D

---

## 1. Millores identificades

### Millora 1 – Migració de JavaFX 3D a Godot 4.6 (APLICADA ✅)
**Descripció:** El prototip inicial usava JavaFX 3D, que no és un motor de jocs. La càmera, les coordenades 3D i la manca de físiques integrades feien impossible obtenir un resultat professional.  
**Millora:** Migració completa a Godot 4.6. El codi GDScript és molt més llegible, el renderer és professional, i les ombres i llums s'obtenen de forma trivial.  
**Impacte:** El joc va passar de ser un conjunt de bugs visuals a un producte jugable i visualment atractiu.

### Millora 2 – Mecànica de xut inspirada en Mini Soccer Star (APLICADA ✅)
**Descripció:** La primera versió tenia botons "TIRAR" i controls per teclat poc intuïtius.  
**Millora:** Sistema de drag + release: arrossegar el ratolí per apuntar (discs de colors verd→groc→vermell mostren potència) i alliberar per xutar. Idèntic a Mini Soccer Star.  
**Impacte:** La interacció és natural i intuïtiva. El jugador veu exactament on anirà la pilota abans de xutar.

### Millora 3 – Models de jugadors blocky Roblox-style (APLICADA ✅)
**Descripció:** Els primers jugadors eren cubs simples sense detalls.  
**Millora:** Models complets: 4 rodes vermelles per peu (8 per jugador), casc amb reixa cage, estic de fusta amb pala, guants de hoquei, franja blanca a la samarreta, anell daurat sota el jugador humà (★).  
**Impacte:** El joc és visualment reconeixible com a hoquei sobre patins.

### Millora 4 – (Identificada, no aplicada) So i música
**Descripció:** No hi ha cap so al joc (xut, gol, rebot).  
**Com s'aplicaria:** Godot té `AudioStreamPlayer3D` que reprodueix sons posicionals. Fitxers `.ogg` per a xut, gol i rebot.

### Millora 5 – (Identificada, no aplicada) Selecció de dificultat
**Descripció:** La IA rival sempre va a la mateixa velocitat.  
**Com s'aplicaria:** Un menú inicial amb Fàcil / Normal / Difícil que modifiqués la velocitat i precisió de l'AI (`ai_speed` variable global).

---

## 2. Detall de les millores aplicades (abans i després)

### Millora 1 – JavaFX → Godot

**Abans (JavaFX 3D):**
```java
// JavaFX: errors constants de coordenades, càmera manual
cam.getTransforms().addAll(
    new Rotate(90, Rotate.Y_AXIS),
    new Rotate(-22, Rotate.X_AXIS)
);
// Resultat: la càmera apuntava en la direcció equivocada
```

**Després (Godot GDScript):**
```gdscript
# Godot: càmera simple i funcional
cam = Camera3D.new()
cam.fov = 62.0
cam.position = Vector3(-20.0, 12.0, 0.0)
cam.look_at(Vector3(5.0, 1.5, 0.0))
# Resultat: funciona correctament a la primera
```

---

### Millora 2 – Drag per apuntar i alliberar per xutar

**Abans:**
```gdscript
# Botó "TIRA!" → l'usuari no sap on va la pilota
bShoot.setOnAction(e -> doShoot())
```

**Després:**
```gdscript
# Drag detecta moviment > 8px → actualitza fletxa
if dd > 8.0 and phase == Phase.MY_TURN and human_ball:
    did_drag = true
    aim_ang = ms_ang + dx * 0.026
    aim_pow = clampf(ms_pow - dy / 185.0, 0.05, 1.0)
# Alliberar → xuta automàticament
if did_drag:
    do_shoot()
```

---

### Millora 3 – Models de jugadors

**Abans:** Un sol `BoxMesh` per jugador, sense cap detall visual.

**Després:** 30+ nodes per jugador:
- Patins amb 8 rodes vermelles individuals
- Casc blocky amb reixa cage (4 barres)
- Braços, guants, genolleres, colzeres
- Estic de fusta inclinat amb pala
- Anell daurat animat sota el jugador humà

---

## 3. Documentació mínima afegida

- **README.md** al repositori amb instruccions d'execució amb Godot
- **Comentaris de seccions** al Main.gd (# ── CONSTANTS, # ── FÍSICA PILOTA, etc.)
- **Tots els 5 documents de fases** a la carpeta `docs/` del repo

---

## 4. Reflexió final

### Decisions preses

La decisió més important va ser **abandonar JavaFX 3D i migrar a Godot 4.6** a meitat del projecte. Va ser una decisió difícil perquè implicava reescriure tot el codi, però va ser la correcta: JavaFX no és un motor de jocs i mai hauria permès obtenir el resultat visual i de gameplay que s'ha aconseguit amb Godot.

Una altra decisió clau va ser **crear tots els elements 3D de forma procedural** en codi (sense assets externs), cosa que permet distribuir el joc amb 3 fitxers i sense cap dependència.

### Dificultats trobades

- **Godot 4.6 és molt estricte amb el tipatge:** Arrays genèrics (`Array`) retornen `Variant`, i GDScript 4.6 no pot inferir el tipus automàticament. Cal usar `float(array[i])` explícitament o declarar `var x: float`.
- **Càmera 3a persona:** La càmera de JavaFX 3D va ser la principal font de bugs. Amb Godot, `cam.look_at()` fa exactament el que s'espera.
- **Mecànica de drag:** Separar el "drag per apuntar" del "clic per moure" va requerir gestionar el flag `did_drag` i el llindar de 8px de moviment.

### Què ha aportat la IA

La IA (Claude) ha estat **essencial** per a aquest projecte. Ha aportat:
- La migració completa de JavaFX a Godot, incloent tots els models 3D procedurals
- La mecànica de drag inspirada en Mini Soccer Star
- La detecció i correcció de tots els errors de tipatge de GDScript 4.6
- Els 5 documents de les fases del projecte
- El sistema d'IA dels rivals (GK, DEF, FW amb comportaments diferenciats)

### Què he acceptat o descartat de la IA

**Acceptat:** La migració a Godot, el sistema de drag per apuntar, els models blocky dels jugadors, el sistema de fases (MYTURN, SHOOTING, AI_TURN, GOAL, OVER).

**Descartat:** La versió HTML+Three.js que la IA va proposar (no compatible amb els requisits del projecte). La càmera 3a persona de JavaFX que la IA va intentar implementar diverses vegades sense èxit.

### Què milloraria amb més temps

1. **So i música** — xuts, gols, rebots amb `AudioStreamPlayer3D`
2. **Menú principal** — pantalla de selecció de dificultat i equipDif
3. **Animacions** — rotació dels jugadors en moure's, celebració de gol
4. **Tocs al portero** — animació del porter llançant-se
5. **Efectes de partícula** — espurnes quan la pilota rebota a la banda
