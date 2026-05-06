# 🏒 Hoquei Patins 3D

**Alumne:** Pol Hernáez  
**Mòdul:** Entorns de Desenvolupament – DAM1  
**Centre:** Escola Pia de Mataró  

Microvideojoc d'hoquei sobre patins 3D, inspirat en Mini Soccer Star. Fet 100% amb IA (Claude).

---

## 🎮 Descripció

Joc de 3 vs 3 per torns amb temps aturat. Controles el davanter local (★ daurat). La resta de jugadors els gestiona la IA.

- **Motor:** Godot Engine 4.6
- **Llenguatge:** GDScript
- **Vista:** 3a persona darrere del jugador

---

## ▶️ Com executar

1. Descarrega **Godot Engine 4.6** a [godotengine.org](https://godotengine.org/download)
2. Obre Godot → **Importar Proyecto Existente**
3. Selecciona el fitxer `project.godot` d'aquesta carpeta
4. Prem **F5** per executar

---

## 🕹️ Controls

| Acció | Control |
|-------|---------|
| Apuntar | Arrossega el ratolí |
| Xutar | Allibera el ratolí |
| Moure jugador | Clic a la pista |
| Moure (alternatiu) | A S D F |
| Normal / Efecte / Fort | Q / W / E |
| Passar | P |
| Rewind (3x) | R |
| Rotar càmera | ← → |
| Reset càmera | ↑ |
| Xutar (teclat) | ESPAI |

---

## 📁 Estructura del repositori

```
hoquei-patins-joc/
├── README.md
├── fase1/01_idea_i_abast.md
├── fase2/02_model_del_joc.md + diagrames/
├── fase3/03_entorn_i_prototip.md
│   ├── Main.gd          ← codi principal del joc
│   ├── Main.tscn        ← escena Godot
│   └── project.godot    ← configuració del projecte
├── fase4/04_proves_i_depuracio.md
└── fase5/05_millores_i_reflexio_final.md
```
