# 04 – Proves i Depuració

**Alumne:** Pol Hernáez  
**Mòdul:** Entorns de Desenvolupament  
**Curs:** DAM1 – Escola Pia de Mataró  
**Projecte:** Hoquei Patins 3D

---

## 1. Casos de prova

### Prova 1 – Xut amb drag correcte

| Camp | Descripció |
|------|-----------|
| **Objectiu** | Verificar que el xut surt en la direcció i potència correctes. |
| **Entrada** | Jugador humà té la pilota. Es fa drag cap a la dreta (screenDx=+80, screenDy=0). |
| **Resultat esperat** | La pilota surt cap a la dreta del camp (bvx > 0, bvz ≈ 0) amb velocitat proporcional al drag. |
| **Resultat obtingut** | ✅ Correcte. La pilota surt cap a la porteria rival amb bvx ≈ +300 u/s. |

---

### Prova 2 – Rebot a la banda nord

| Camp | Descripció |
|------|-----------|
| **Objectiu** | Verificar que la pilota rebota correctament quan toca la banda superior. |
| **Entrada** | Pilota amb bvz = -500 (cap a la banda nord). |
| **Resultat esperat** | Quan `bz < -FH/2 + BR`, `bvz` s'inverteix i es multiplica per 0.62. |
| **Resultat obtingut** | ✅ Correcte. La pilota rebota i perd velocitat (coeficient 0.62 aplicat). |

---

### Prova 3 – Detecció de gol local

| Camp | Descripció |
|------|-----------|
| **Objectiu** | Verificar que un gol a la porteria rival incrementa el marcador local. |
| **Entrada** | Pilota amb bvx > 0 i bx > FW/2 + 5, amb `Math.abs(bz) < GZ`. |
| **Resultat esperat** | `scoreL++`, missatge "GOL! ARENYS HC!", pausa 2s, reset posicions. |
| **Resultat obtingut** | ✅ Correcte. El marcador s'actualitza i el parpelleig s'activa. |

---

### Prova 4 – IA porter segueix la pilota

| Camp | Descripció |
|------|-----------|
| **Objectiu** | Verificar que el porter local segueix la pilota en l'eix Z sense sortir de la porteria. |
| **Entrada** | Pilota a posició bz = +80 (extrem de la porteria). |
| **Resultat esperat** | El porter local es mou cap a `clamp(bz, -GZ+5, GZ-5)` = +27, sense sortir de la porteria. |
| **Resultat obtingut** | ✅ Correcte. El porter es queda dins dels límits de la porteria. |

---

### Prova 5 – Recollida automàtica de pilota

| Camp | Descripció |
|------|-----------|
| **Objectiu** | Verificar que el jugador humà recull la pilota quan s'hi apropa prou. |
| **Entrada** | Pilota lliure a (bx=50, bz=0). Jugador humà a (x=30, z=0). Distància = 20u < 28u. |
| **Resultat esperat** | `human.hasBall = true`, `ballFree = false`. |
| **Resultat obtingut** | ✅ Correcte. El jugador recull la pilota i el HUD mostra "Tens la pilota!". |

---

### Prova 6 – Fi de partida per temps

| Camp | Descripció |
|------|-----------|
| **Objectiu** | Verificar que el joc acaba correctament quan el temps arriba a 0. |
| **Entrada** | `timeLeft` decrementat fins a 0. `scoreL=2`, `scoreR=1`. |
| **Resultat esperat** | `gameOver=true`, missatge "🏆 VICTÒRIA! 2–1" en groc. El bucle s'atura. |
| **Resultat obtingut** | ✅ Correcte. El missatge apareix i el rellotge queda a "0:00". |

---

## 2. Incidències reals detectades

### Incidència 1 – JavaFX SDK versió incorrecta (versió major 68.0)

**Descripció:** En instal·lar JavaFX SDK 26, el compilador donava l'error:
```
bad class file: C:\javafx-sdk-26\lib\javafx.base.jar
class file has wrong version 68.0, should be 65.0
```

**Causa probable:** JavaFX SDK 26 requereix JDK 24+. El JDK instal·lat és la versió 21 (class file version 65.0). Hi havia una incompatibilitat de versions.

**Solució aplicada:** S'ha eliminat el JavaFX SDK 26 i s'ha instal·lat el **JavaFX SDK 21.0.5**, que és compatible amb JDK 21. Es van actualitzar `settings.json` i `launch.json` per apuntar a la nova ruta.

```powershell
Remove-Item -Recurse -Force C:\javafx-sdk-26
# Descarregar JavaFX SDK 21.0.5 de gluonhq.com
# Extreure a C:\javafx-sdk-21.0.5
```

---

### Incidència 2 – `Color.rgb()` amb opacitat fora del rang 0.0–1.0

**Descripció:** El joc llançava l'excepció en arrencar:
```
java.lang.IllegalArgumentException: Color's opacity value (120.0) must be in the range 0.0-1.0
    at ui.GameWindow.construirPista(GameWindow.java:147)
```

**Causa probable:** S'havia escrit `Color.rgb(30, 80, 190, 120)` assumint que l'opacitat era un valor 0–255, igual que en alguns frameworks. Però en JavaFX, el quart paràmetre de `Color.rgb()` és un `double` de 0.0 a 1.0.

**Solució aplicada:** Substituir tots els valors d'opacitat per la fracció correcta:
```java
// Incorrecte:
Color.rgb(30, 80, 190, 120)
// Correcte:
Color.rgb(30, 80, 190, 120.0/255.0)  // = 0.47
```

Es va usar una substitució amb `sed` per corregir tots els casos automàticament.

---

### Incidència 3 – Còmandes PowerShell en una sola línia

**Descripció:** En enganxar múltiples comandes a PowerShell en una sola línia (separades per `;`), la comanda `java` s'executava sense que `javac` hagués acabat de compilar, donant l'error:
```
Error: no se ha encontrado o cargado la clase principal ui.GameWindow
```

**Causa probable:** En PowerShell, el separador `;` executa les comandes de forma seqüencial però alguns sistemes interpreten la concatenació diferent. A més, `javac` retornava errors de compilació que no s'havien llegit.

**Solució aplicada:** Executar cada comanda en una línia independent i esperar el prompt abans de continuar. Verificar que `javac` no retorna errors (0 línies de sortida a stderr) abans d'executar `java`.

---

## 3. Evidència de depuració

### Tècniques de depuració usades

**a) Prints de diagnòstic:**  
Es van afegir `System.out.println()` temporals per verificar valors de física de la pilota:
```java
// Depuració física pilota
System.out.println("Ball: bx=" + bx + " bz=" + bz + " bvx=" + bvx + " bvz=" + bvz);
```
Això va permetre detectar que el factor de conversió drag→velocitat era massa gran (bvx > 600) i reduir-lo.

**b) Lectura del stack trace:**  
Per a la incidència 2 (opacitat), es va llegir el stack trace complet:
```
Caused by: java.lang.IllegalArgumentException: Color's opacity value (120.0) must be in the range 0.0-1.0
    at javafx.graphics@21.0.5/javafx.scene.paint.Color.<init>(Color.java:1904)
    at ui.GameWindow.construirPista(GameWindow.java:147)
```
La línia 147 indicava exactament on estava l'error.

**c) Verificació de versions:**  
Comanda per comprovar la versió del JDK i comparar-la amb la del JavaFX SDK:
```powershell
java -version
# openjdk version "21.0.10" 2025-01-21
javac -version
# javac 21.0.10
```

**d) Test de compilació incremental:**  
Compilar primer un sol fitxer per aïllar errors:
```powershell
javac --module-path "C:/javafx-sdk-21.0.5/lib" --add-modules javafx.graphics -d out src/ui/GameWindow.java
```
