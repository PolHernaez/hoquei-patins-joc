# 01 – Idea i Abast del Projecte

**Alumne:** Pol Hernáez  
**Mòdul:** Entorns de Desenvolupament  
**Curs:** DAM1 – Escola Pia de Mataró  
**Projecte:** Microvideojoc en Java amb Java Swing

---

## 1. Tipus de microvideojoc seleccionat

**Joc de combats per torns** amb temàtica d'**hoquei sobre patins** (patins de 4 rodes, estiques de fusta). Es tracta d'un joc original i personal, inspirat en la pràctica real del jugador.

---

## 2. Definició del joc

### Objectiu del joc
Guanyar un partit d'hoquei sobre patins contra un equip rival controlat per la màquina. El jugador ha de marcar més gols que el rival en el temps reglamentari (2 períodes de 10 torns cadascun).

### Rol del jugador
El jugador controla el seu equip (Arenys HC) i pren decisions tàctiques cada torn: quan té la possessió, decideix si tira a porteria, passa per preparar una jugada millor, o descansa per recuperar energia. Quan no té la possessió, decideix si pressiona, bloqueja o descansa defensivament.

### Regles bàsiques i condicions de victòria/derrota
- El partit té **2 períodes de 10 torns** (20 torns totals).
- Cada torn, un equip té la **possessió de la pilota**.
- Les accions consumeixen **energia** (atribut limitat que es recupera parcialment).
- L'efectivitat de cada acció depèn de l'**habilitat del jugador** i de l'energia disponible.
- **Victòria:** l'equip del jugador té més gols en acabar el partit.
- **Derrota:** l'equip rival té més gols.
- **Empat:** s'afegeix un torn de penalti desempat.

### Bucle principal del joc (game loop)
```
MENTRE el partit no ha acabat:
    Mostrar estat (gols, energia, torn, temps)
    SI tens possessió:
        Jugador tria acció: [Tirar | Passar | Descansar]
        Calcular resultat de l'acció
        Si gol → actualitzar marcador, possessió passa al rival
        Si no gol → possessió pot canviar o mantenir-se
    SINO (rival té possessió):
        IA tria acció rival
        Jugador tria defensa: [Bloquejar | Pressionar | Descansar]
        Calcular resultat
    Actualitzar energia, torn i possessió
FI
Mostrar resultat final
```

### Repte principal i nivell de dificultat
El repte és gestionar bé l'energia: accions potents (tirar, pressionar) costen molta energia, i si l'energia cau molt, l'efectivitat baixa dràsticament. La IA rival també té aquesta limitació, però el jugador ha de saber quan arriscar i quan descansar.

### Limitacions explícites (què NO inclourà)
- No hi haurà animació de jugadors en moviment real.
- No hi haurà mode multijugador (2 humans).
- No hi haurà so ni música.
- No hi haurà sistema de lligues ni tornejos.
- No hi haurà més d'una dificultat configurable (la IA tindrà un comportament fix).

---

## 3. Tres riscos tècnics identificats

| Risc | Descripció | Mitigació |
|------|-----------|-----------|
| **Gestió d'estats** | El joc té molts estats (torn, possessió, energia, gols, període) i si no es gestionen bé es poden produir inconsistències. | Centralitzar l'estat al model `Partit`, mai a la UI. |
| **Aleatoreitat equilibrada** | Les accions tenen component aleatòria (probabilitat de gol, etc.). Si el random és massa fort, el joc no és jugable. | Definir rangs de probabilitat amb fórmules clares i testar-los. |
| **Separació UI / lògica amb Swing** | Swing tendeix a barrejar lògica de joc amb codi de pantalla si no s'organitza bé. | Seguir separació clara: model (lògica) ↔ vista (Swing) ↔ controlador. |

---

## 4. Exploració amb IA (mínim 2 prompts)

### Prompt 1
**Prompt enviat:** *"Tinc de fer de fer un microvideojoc en Java amb Java Swing per a la classe d'Entorns de Desenvolupament. Vull que sigui un joc d'hoquei sobre patins per torns. Quin tipus de mecàniques podria tenir? Proposa'm alternatives."*

**Resposta de la IA (resum):** La IA va proposar diverses mecàniques: sistema de possessió amb accions (tirar, passar, defensar), sistema d'energia per donar profunditat estratègica, sistema d'habilitats per jugador, penaltis desempat, i una alternativa de gestió d'equip on fitxaves jugadors. Va destacar que el sistema de possessió per torns és el més viable per al temps disponible.

**Decisió presa:** Vaig acceptar el sistema de possessió amb accions i el sistema d'energia, però vaig descartar la gestió d'equip perquè afegia massa complexitat. Vaig mantenir el penalti desempat com a element diferenciador.

### Prompt 2
**Prompt enviat:** *"Quines classes Java necessitaria per a aquest joc d'hoquei per torns? Proposa'm una arquitectura amb separació entre model i vista Swing."*

**Resposta de la IA (resum):** La IA va proposar: `Jugador` (atributs i habilitats), `Equip` (conjunt de jugadors i gols), `Partit` (lògica del joc, torns, possessió), `AccioJoc` (enum d'accions possibles), i `GameWindow` / `GamePanel` per a la part Swing. Va recomanar patró MVC bàsic.

**Decisió presa:** Vaig acceptar l'estructura de classes proposada amb lleugeres modificacions (vaig simplificar `Equip` per tenir un sol jugador representatiu en comptes d'una llista completa, per reduir complexitat).

---

## 5. Proposta final i justificació de viabilitat

**Proposta final:** Joc d'hoquei sobre patins per torns amb interfície gràfica Java Swing. 2 períodes de 10 torns, sistema de possessió, 3 accions en atac i 3 en defensa, sistema d'energia, IA rival senzilla, penalti desempat.

| Factor | Valoració |
|--------|-----------|
| **Temps** | Viable en 10h. La lògica és senzilla i Java Swing és conegut. |
| **Complexitat** | Mitjana-baixa. No cal físiques, no cal animació, no cal so. |
| **Recursos** | Cap dependència externa. Tot inclòs a Java SE. |
| **Originalitat** | Alta. No existeix cap joc d'hoquei sobre patins en text/2D simple. |
| **Personalització** | Alta. El nom de l'equip és Arenys HC, l'equip real del jugador. |

---

## 6. Fases del procés (mini pla)

| Fase | Contingut | Temps estimat |
|------|-----------|---------------|
| Fase 1 | Idea, abast, riscos, exploració IA | 1,5h |
| Fase 2 | Diagrames de classes i comportament, estructura GitHub | 2h |
| Fase 3 | Configuració IDE, prototip funcional, commits inicials | 2h |
| Fase 4 | Casos de prova, detecció d'errors, depuració | 2h |
| Fase 5 | Refactorització, millores, reflexió final | 2h |
| **Total** | | **~9,5h** |

---

## 7. Eines previstes

| Eina | Ús | Justificació |
|------|-----|-------------|
| **IntelliJ IDEA** | IDE principal | Suport natiu a Java, autocompletat, debugger integrat. |
| **Java SE 21** | Llenguatge | Requerit per DAM1. Java Swing inclòs. |
| **GitHub** | Control de versions | Requisit del projecte. Permet historial de commits. |
| **Git** | Gestió de versions local | Integrat a IntelliJ. |
| **Claude (IA)** | Suport al procés | Generació d'idees, alternatives de disseny, detecció d'errors. |
| **draw.io** | Diagrames UML | Eina gratuïta, exporta PNG per incloure al repositori. |

---

## 8. Requisits mínims verificats

- [x] L'abast cap en 10 hores.
- [x] Hi ha un bucle de joc clar (torns de possessió).
- [x] Hi ha estats: `gols`, `energia`, `torn`, `període`, `possessió`.
