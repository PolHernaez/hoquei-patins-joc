# 05 – Millores i Reflexió Final

**Alumne:** Pol Hernáez  
**Mòdul:** Entorns de Desenvolupament  
**Curs:** DAM1 – Escola Pia de Mataró  
**Projecte:** Hoquei Patins 3D

---

## 1. Millores identificades

### Millora 1 – Evolució del control: torns → temps real amb drag (APLICADA)
**Descripció:** El prototip inicial era un joc per torns amb botons Swing (TIRAR, PASSAR, DESCANSAR). Era poc dinàmic i no representava bé l'esport.  
**Millora:** Es va passar a controls en temps real inspirats en *Mini Soccer Star*: drag per xutar (amb fletxa d'alineació) i clic per moure's.  
**Impacte:** El joc va passar de ser estàtic a ser jugable i divertit.

### Millora 2 – Pilota taronja i models visuals millorats (APLICADA)
**Descripció:** Les primeres versions tenien la pilota de color blanc, igual que les esferes del cap dels jugadors. Era impossible distingir-la.  
**Millora:** La pilota es va pintar de **taronja brillant** (radi 10u) amb franja negra. Els cascs dels jugadors van passar a ser del color del seu equip (vermell fosc / blau fosc) en lloc de blanc.  
**Impacte:** La llegibilitat visual del joc va millorar molt.

### Millora 3 – IA rival amb moviment serpentejant (APLICADA)
**Descripció:** La primera IA del davanter rival anava en línia recta cap a la porteria. Era fàcil d'interceptar i poc realista.  
**Millora:** Es va implementar un moviment de zigzag basat en sinus: `tz = Math.sin(aiTimer * 0.9) * 48`. La IA ara serpenteja mentre avança, dificultant la intercepció.  
**Impacte:** La IA és més desafiadora i el comportament sembla més natural.

### Millora 4 – (Identificada, no aplicada) Passes entre companys
**Descripció:** Ara l'equip local (excepte el humà) funciona de forma autònoma, però no hi ha sistema de passes explícit entre jugadors. El jugador humà no pot passar la pilota a un company.  
**Com s'aplicaria:** Afegir detecció de clic sobre un company local per disparar la pilota cap a ell a `PASS_SPEED`. El receiver espera la pilota a la seva posició.

### Millora 5 – (Identificada, no aplicada) So i retroalimentació d'àudio
**Descripció:** No hi ha cap so al joc (xut, gol, rebot).  
**Com s'aplicaria:** Usar `AudioClip` de JavaFX per carregar fitxers `.wav` curts i reproduir-los en els events corresponents.

---

## 2. Detall de les millores aplicades (abans i després)

### Millora 1 – Controls: torns → temps real

**Abans (versió Swing per torns):**
```java
// Botons a la UI
JButton btnTirar = new JButton("TIRAR");
JButton btnPassar = new JButton("PASSAR");
JButton btnDescansar = new JButton("DESCANSAR");
btnTirar.addActionListener(e -> processarAccio(AccioJoc.TIRAR));
```
La interacció era seqüencial: premer botó → calcular resultat → mostrar text → esperar el següent torn.

**Després (versió JavaFX temps real amb drag):**
```java
sub3D.setOnMouseReleased(e -> {
    if (dragging) {
        double dx = e.getSceneX() - aimStartX;
        double dy = e.getSceneY() - aimStartY;
        shoot(dx, dy);  // xut en la direcció del drag
    } else {
        // clic simple → mou jugador
        if (e.getPickResult().getIntersectedNode() == floorBox) {
            Point3D pt = e.getPickResult().getIntersectedPoint();
            human.tx = pt.getX(); human.tz = pt.getZ();
        }
    }
});
```

---

### Millora 2 – Pilota taronja (visible i diferenciada)

**Abans:**
```java
Sphere bs = new Sphere(8);
PhongMaterial bm = new PhongMaterial(Color.WHITE);  // igual que caps jugadors
bs.setMaterial(bm);
```

**Després:**
```java
Sphere bs = new Sphere(10);  // més gran
PhongMaterial bm = new PhongMaterial(Color.rgb(255, 115, 8));  // taronja
bm.setSpecularColor(Color.rgb(255, 210, 120));
bm.setSpecularPower(75);
bs.setMaterial(bm);
Cylinder stripe = new Cylinder(8, 4);  // franja negra per millorar reconeixement
stripe.setMaterial(mat(Color.rgb(20, 20, 20)));
```

---

### Millora 3 – Moviment serpentejant de la IA

**Abans:**
```java
void aiDribble(Ent e, double dt) {
    // Línia recta cap a la porteria
    e.tx = -FW/2 + 72;
    e.tz = 0;  // sempre al centre
    moveEnt(e, 155, dt);
}
```

**Després:**
```java
void aiRivalDribble(Ent e, double dt) {
    double targetX = -FW/2 + 78;
    double targetZ = Math.sin(e.aiTimer * 0.9) * 48;  // serpenteja
    e.tx = targetX; e.tz = targetZ;
    moveEnt(e, V_AI_ATK, dt);
    e.aiTimer += dt;
    // Xuta quan s'acosta o porta massa temps
    boolean timeToShoot = (dist < 130 && e.aiTimer > 1.8) || e.aiTimer > 4.8;
    if (timeToShoot) { /* xuta */ }
}
```

---

## 3. Documentació mínima afegida

- **README.md** al repositori amb: descripció del joc, instruccions d'execució, controls.
- **Comentaris Javadoc** a les constants principals de `GameWindow.java`.
- **Comentaris de blocs** per a cada secció del codi (`// ─── CÀMERA ───`, `// ─── FÍSICA PILOTA ───`).
- **Tots els 5 documents de fases** a la carpeta `docs/`.

---

## 4. Reflexió final

### Decisions preses

La decisió més important va ser **canviar completament el paradigma del joc** a meitat del projecte: de torns amb Swing a temps real amb JavaFX 3D. Va ser arriscat però necessari; el joc per torns era funcional però avorrit. El temps real amb drag per xutar fa el joc intuïtiu i divertit.

Una altra decisió clau va ser **controlar un sol jugador** (inspiració directa en *Mini Soccer Star*) en lloc de gestionar tot l'equip. Simplifica enormement els controls i fa que el jugador se senti identificat amb el seu personatge.

### Dificultats trobades

- **Compatibilitat de versions JavaFX/JDK:** Instal·lar accidentalment JavaFX SDK 26 amb JDK 21 va bloquejar el projecte fins que es va identificar i corregir.
- **Mapping drag → velocitat 3D:** Convertir el delta de píxels de pantalla a velocitat en el món 3D isomètric no és trivial. Es va calibrar empíricament amb el factor 1.4.
- **Càmera dinàmica fallida:** Es va intentar una càmera que seguís el jugador des de darrere, però deformava els models visualment. Es va revertir a càmera estàtica.

### Què ha aportat la IA

La IA (Claude) ha estat **molt útil per al codi de JavaFX 3D**, un àmbit on la documentació és escassa i els exemples en línia sovint utilitzen versions antigues. Ha aportat:
- Estructura del game loop amb `AnimationTimer`.
- Construcció dels models 3D dels jugadors (patins, casc, estic).
- Lògica de la IA serpentejant per al davanter rival.
- Depuració d'errors de versió i d'opacitat de colors.

### Què he acceptat o descartat de la IA

**Acceptat:** Sistema de drag per xutar, estructura de `tick(dt)`, moviment serpentejant de la IA, pilota taronja.

**Descartat:** La càmera dinàmica (proposada per la IA) va ser descartada perquè causava efectes visuals incorrectes. La solució de càmera estàtica va ser una decisió pròpia. També es van descartar algunes propostes de passes entre companys per simplicitat.

### Què milloraria amb més temps

1. **So**: Xuts, gols i rebots amb AudioClip de JavaFX.
2. **Passes explícites**: Clic sobre un company local per passar-li la pilota.
3. **Dificultat variable**: Paràmetre de velocitat de la IA ajustable (Fàcil / Normal / Difícil).
4. **Animació de patinada**: Rotació de les rodes dels patins proporcional a la velocitat.
5. **Separació en classes**: Refactoritzar `GameWindow.java` en les 6 classes del diagrama UML.
