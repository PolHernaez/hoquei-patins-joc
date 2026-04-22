# 03 – Entorn i Prototip

**Alumne:** Pol Hernáez  
**Mòdul:** Entorns de Desenvolupament  
**Curs:** DAM1 – Escola Pia de Mataró  
**Projecte:** Hoquei Patins 3D

---

## 1. IDE utilitzat i configuració bàsica

**IDE:** Visual Studio Code (VS Code)  
**Sistema operatiu:** Windows 11  
**Ruta del projecte:** `C:\Users\Pol\Documents\Entorns\JocIA\hoquei-patins-joc`

### Fitxer `.vscode/settings.json`

```json
{
    "java.project.referencedLibraries": [
        "C:/javafx-sdk-21.0.5/lib/*.jar"
    ]
}
```

### Fitxer `.vscode/launch.json`

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "java",
            "name": "GameWindow",
            "request": "launch",
            "mainClass": "ui.GameWindow",
            "vmArgs": "--module-path \"C:/javafx-sdk-21.0.5/lib\" --add-modules javafx.controls,javafx.fxml,javafx.graphics"
        }
    ]
}
```

### Versions utilitzades

| Eina | Versió |
|------|--------|
| JDK | Eclipse Adoptium 21.0.10.7 |
| JavaFX SDK | 21.0.5 |
| VS Code | 1.x |
| Git | 2.x |

### Comanda de compilació i execució (PowerShell)

```powershell
cd C:\Users\Pol\Documents\Entorns\JocIA\hoquei-patins-joc
mkdir -Force out | Out-Null
javac --module-path "C:/javafx-sdk-21.0.5/lib" --add-modules javafx.controls,javafx.fxml,javafx.graphics -cp src -d out (Get-ChildItem src -Recurse -Filter "*.java" | Select-Object -ExpandProperty FullName)
java --module-path "C:/javafx-sdk-21.0.5/lib" --add-modules javafx.controls,javafx.fxml,javafx.graphics -cp out ui.GameWindow
```

---

## 2. Decisions inicials d'implementació

### Del disseny original (Swing/torns) a JavaFX 3D en temps real

El projecte va iniciar-se com a joc per torns amb Java Swing. Durant la implementació, es va decidir evolucionar a **JavaFX 3D en temps real** per les raons següents:

| Decisió | Raó |
|---------|-----|
| **JavaFX 3D en lloc de Swing** | Swing no suporta 3D natiu. JavaFX permet SubScene, PerspectiveCamera, Box, Cylinder i Sphere sense biblioteques externes. |
| **Temps real en lloc de torns** | El joc per torns era poc dinàmic. El temps real permet física de pilota, rebots i IA reactiva. |
| **1 sol jugador controlat** | Inspiració directa en Mini Soccer Star: el jugador és UN personatge al camp, la resta és IA. Simplifica els controls. |
| **Drag per xutar** | Reprodueix el sistema de Mini Soccer Star: la longitud i direcció del drag determinen potència i angle. |
| **Càmera estàtica isomètrica** | La càmera dinàmica causava desorientació visual. La vista estàtica permet veure tot el camp. |
| **Pilota taronja gran** | Per diferenciar-la clarament dels elements blancs dels jugadors. |

### Estructura del codi

Tot el joc resideix a `src/ui/GameWindow.java`. Aquesta decisió es va prendre per simplicitat del prototip.

---

## 3. Evidències visuals

**Captura 1:** VS Code amb GameWindow.java obert i la configuració .vscode/ visible al panell esquerre.  
**Captura 2:** Terminal PowerShell mostrant la compilació correcta (0 errors).  
**Captura 3:** Joc en execució amb camp de parquet, jugadors 3D i pilota taronja.

---

## 4. Prototip executable

El prototip és **executable i jugable de principi a fi**.

### Funcionalitats implementades

- [x] Camp de parquet 3D (marró, amb línies de camp blaves i vermelles).
- [x] Porteries 3D amb xarxa (vermella local, blava rival).
- [x] 6 jugadors 3D amb patins de 4 rodes, casc i estic de fusta.
- [x] Pilota taronja amb física (fricció, rebots a les bandes).
- [x] Control per drag (xut) i clic (moviment).
- [x] IA: porters, defenses i davanter rival.
- [x] Detecció de gol i pausa de 2 segons.
- [x] HUD: marcador, rellotge 2 minuts, missatge d'event.
- [x] Pantalla de resultat final.

### Bucle de joc funcional

```
AnimationTimer → handle(now) → tick(dt) →
  tickTimer → tickBall → tickHuman → tickAI → checkGoal → syncScene
```

---

## 5. Control de versions – Commits

| # | Missatge | Contingut |
|---|----------|-----------|
| 1 | `init: estructura del projecte i diagrames UML` | Carpetes, .gitignore, README.md, diagrames PNG. |
| 2 | `feat: camp hoquei JavaFX 3D amb porteries i bandes` | Camp de parquet, línies, porteries, bandes perimetrals. |
| 3 | `feat: jugadors 3D amb patins, física pilota i IA completa` | Jugadors amb patins de 4 rodes, IA, física pilota, HUD, gol. |

---

## 6. Interacció amb l'usuari

| Acció | Resposta del sistema |
|-------|---------------------|
| Arrossegar el ratolí (drag) | Apareix la fletxa groga d'alineació; en alliberar, la pilota xuta. |
| Clic esquerre al terra | El jugador humà es desplaça cap al punt clicat. |
| La pilota s'acosta al jugador | El jugador la recull automàticament (distància < 28u). |
| Gol detectat | Pausa de 2 segons, animació de parpelleig del marcador, reset. |
| Temps a 0 | Mostra resultat final i atura el joc. |
