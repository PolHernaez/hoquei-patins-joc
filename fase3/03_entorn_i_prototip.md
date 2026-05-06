# 03 – Entorn i Prototip

**Alumne:** Pol Hernáez  
**Mòdul:** Entorns de Desenvolupament  
**Curs:** DAM1 – Escola Pia de Mataró  
**Projecte:** Hoquei Patins 3D

---

## 1. IDE i motor de joc utilitzats

**Motor de joc:** Godot Engine 4.6.2 (stable)  
**IDE addicional:** Visual Studio Code (per editar GDScript i docs)  
**Sistema operatiu:** Windows 11  
**Ruta del projecte:** `C:\Users\Pol\Documents\Entorns\JocIA\hoquei-patins-godot\`

### Per què Godot en lloc de JavaFX?

El projecte va iniciar-se amb **JavaFX 3D**, però durant la implementació es va detectar que JavaFX no és un motor de jocs: no té físiques integrades, la gestió de la càmera 3D és manual i complexa, i els bugs de coordenades feien impossible obtenir un resultat professional en el temps disponible.

Es va prendre la decisió de migrar a **Godot 4.6**, que és un motor de jocs professional, completament gratuït i de codi obert, amb:
- Renderer 3D integrat amb ombres i llums
- GDScript (similar a Python, molt llegible)
- Exportació a Windows, HTML5 i altres plataformes
- Cap dependència externa

### Configuració de Godot 4.6

| Paràmetre | Valor |
|-----------|-------|
| Versió | 4.6.2 stable |
| Renderer | Forward+ |
| Resolució | 1280×720 |
| Antialiasing | Activat |

**Fitxer `project.godot`:**
```ini
config_version=5

[application]
config/name="Hoquei Patins"
run/main_scene="res://Main.tscn"
config/features=PackedStringArray("4.2")

[rendering]
renderer/rendering_method="forward_plus"
```

---

## 2. Decisions inicials d'implementació

### Arquitectura del projecte

Tot el joc és en **un sol fitxer GDScript** (`Main.gd`, ~960 línies) que genera tots els nodes 3D de forma procedural en `_ready()`. Aquesta decisió es va prendre per:
- Simplicitat de distribució (3 fitxers: `project.godot`, `Main.tscn`, `Main.gd`)
- Facilitat per modificar qualsevol element del joc
- No dependre d'assets externs (textures, models 3D)

### Decisions clau

| Decisió | Raó |
|---------|-----|
| **Tot procedural (sense assets)** | El joc genera tots els meshes en codi: BoxMesh, SphereMesh, CylinderMesh, TorusMesh |
| **Física manual** | Més control sobre la pilota (fricció, rebots, corba) |
| **GDScript tipat** | Godot 4.6 és estricte amb el tipatge d'arrays genèrics |
| **Càmera 3a persona** | Segueix el jugador humà (★) des de darrere, com Mini Soccer Star |
| **Discs plans per a la fletxa** | Visibles des de qualsevol angle de càmera inclinada |

### Mecànica inspirada en Mini Soccer Star

| Element MSS | Implementació |
|-------------|---------------|
| Temps aturat al teu torn | `phase == Phase.MY_TURN` atura el rellotge |
| Drag per apuntar | `InputEventMouseMotion` amb drag > 8px |
| Alliberar = xuta | `InputEventMouseButton` released detecta fi de drag |
| 3 tipus de xut | Normal (36u/s), Efecte/corba (28u/s), Fort (52u/s) |
| Rewind | 3 usos per partir, restaura l'estat anterior al xut |

---

## 3. Evidències visuals

**Captura 1:** Editor de Godot amb la jerarquia de nodes 3D creats proceduralment.  
**Captura 2:** Joc en execució: camp de parquet, jugadors blocky Roblox-style, pilota taronja, aura blava pulsant.  
**Captura 3:** Fletxa d'apuntament (discs de colors verd→groc→vermell) indicant direcció i potència.

---

## 4. Prototip executable

### Funcionalitats implementades

- [x] Camp de parquet 3D amb línies, cercle central i punts de cara-off
- [x] Porteries vermella (local) i blava (rival) amb xarxa
- [x] Bandes blanques amb franja vermella (roller hockey)
- [x] 6 jugadors blocky Roblox-style (patins amb 4 rodes vermelles, casc amb reixa cage, estic de fusta)
- [x] Pilota taronja amb física (fricció, rebots, efecte de corba)
- [x] Sistema de torns: temps aturat quan és el teu torn
- [x] Fletxa d'apuntament amb discs de colors (potència visual)
- [x] 3 tipus de xut: Normal, Efecte (corba), Fort
- [x] Passa al company, REWIND (3 usos)
- [x] IA: GK defensant porteria, DEF cobrint, FW rival dribla i xuta
- [x] HUD: marcador, rellotge 2 minuts, barra de potència
- [x] Càmera 3a persona que segueix el jugador + orbit amb ← →

### Com executar el joc

1. Descarregar **Godot Engine 4.6** de [godotengine.org](https://godotengine.org)
2. Obrir Godot → "Importar Proyecto Existente" → seleccionar `project.godot`
3. Prémer **F5** per executar

---

## 5. Control de versions – Commits

| # | Missatge | Contingut |
|---|----------|-----------|
| 1 | `init: estructura del projecte i diagrames UML` | Carpetes, .gitignore, README, diagrames |
| 2 | `feat: joc JavaFX 3D prototip inicial` | Primera versió JavaFX (camp, porteries, jugadors) |
| 3 | `refactor: migració a Godot 4.6` | Tot el joc reescrit en GDScript per Godot |
| 4 | `feat: joc Godot 4.6 funcional` | Main.gd complet amb gameplay, IA i HUD |

---

## 6. Interacció amb l'usuari

| Acció | Resposta |
|-------|----------|
| Drag ratolí + alliberar | Apunta la fletxa i xuta automàticament |
| Clic a la pista | El jugador ★ es mou cap allà |
| ASDF | Moure el jugador |
| Q / W / E | Seleccionar tipus de xut |
| P | Passar al company |
| R | Rewind (refés l'últim xut) |
| ← → | Rotar la càmera al voltant del camp |
| ESPAI | Xutar sense drag |
