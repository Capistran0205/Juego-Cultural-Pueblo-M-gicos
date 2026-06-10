# Pueblos Mágicos — Documento de Contexto del Proyecto

> Juego cultural/educativo sobre los **177 Pueblos Mágicos de México** y sus **32 estados**, hecho en **Godot 4.5** (GDScript). Mecánica tipo *Oca / serpientes y escaleras*: los jugadores recorren un mapa de México y, dentro de cada estado, un sub-tablero con sus pueblos mágicos, ganando puntos al responder preguntas culturales.
>
> Este documento describe **lo implementado actualmente** (escenas, lógica de negocio y puntos importantes) para servir como contexto del código. Lo marcado como **[PLANEADO]** es diseño acordado aún no implementado.

---

## 1. Información técnica

| Dato | Valor |
|---|---|
| Motor | Godot **4.5** (`config/features = "4.5", "GL Compatibility"`) |
| Lenguaje | GDScript |
| Renderer | **Mobile** (`renderer/rendering_method="mobile"`) |
| Resolución base | **1920×1080**, orientación **vertical/retrato** (`window/handheld/orientation=1`) |
| Ventana | No redimensionable, sin minimizar/maximizar; `stretch/mode="canvas_items"`, `aspect="expand"` |
| Escena principal | `uid://b3dej8fqahe5f` → `MenuPrincipal/Componentes/Escenas/MenuPrincipal.tscn` |
| Plugin | `addons/dice_roller` (dado 3D) |
| Nombre app | "Pueblos Magicos" |

---

## 2. Estructura de carpetas

```
Juego-Cultural-Pueblo-Mágicos/
├── project.godot                 # Configuración, autoloads, display
├── data/
│   └── questions.json            # Respaldo local de preguntas (offline)
├── Assets/
│   ├── FondoPrincipal.webp       # Fondo + boot splash
│   ├── LogoPueblosMagicos.webp
│   ├── Jugadores/                # Avatares: Jugador1_bg.png .. Jugador6_bg.png
│   └── Mapas/                    # Mexico.png + imágenes por estado (Hidalgo, Queretaro, ...)
├── ScriptsSinglentos/            # AUTOLOADS (singletons)
│   ├── informacion_juego.gd      # Modelo "rico" de la partida
│   ├── global.gd                 # Modelo "simple" / estado puntual
│   ├── adaptador_pantalla.gd     # Escalado de pantalla
│   └── manejador_preguntas.gd    # Preguntas desde Firebase/Firestore (REST)
├── AdministradorOnline/
│   └── ScriptsSinglentos/administrador_online.gd   # STUB de red (sin backend real)
├── MenuPrincipal/
│   └── Componentes/
│       ├── Escenas/              # MenuPrincipal, UnJugadorModo, MultijugadorModo,
│       │                         # Perfil, BarraCargaDatostscn, PlayerEntry, SalaEntry
│       └── Scripts/              # Scripts de cada escena de menú
├── Juego/TableroJuego/
│   ├── Tablero.tscn              # Tablero macro (mapa de México)
│   ├── game_manager.gd          # ★ NÚCLEO del flujo de juego
│   └── Componentes/
│       ├── Escenas/              # roll_screen, PreguntaPopup, FeedbackPopup,
│       │                         # FinJuegoEstadísticas, JugadorStatRow, EstadoArea, PuebloArea
│       └── scripts/              # Scripts de cada componente
├── addons/dice_roller/           # Plugin de dado 3D (comunitario)
└── Claves y APIS/                # ⚠️ keystores (IGNORADOS por git)
```

---

## 3. Autoloads (Singletons)

Definidos en `project.godot → [autoload]`. Disponibles globalmente por nombre.

### 3.1 `InformacionJuego` — modelo "rico" de la partida
`ScriptsSinglentos/informacion_juego.gd`. **Fuente de verdad de los jugadores.** Lo llenan los menús antes de entrar al tablero.

- **Enums:** `GameMode {NONE, SINGLE, LOCAL_MULTI, ONLINE_MULTI}`, `Difficulty`, `GameState {MENU, PLAYING_MAP, PLAYING_OCA, GAME_OVER}`.
- **`players: Array[Dictionary]`** — cada jugador: `index, name, avatar_id, color, is_local, network_id, state_index, is_inside_state, pueblo_index, pueblos_scored, skips_remaining, finished, is_winner`.
- **Colores predefinidos:** `TOKEN_COLORS` (6 colores hex).
- **Constantes:** `MAX_PLAYERS=6`, `MIN_PLAYERS_MULTI=2`, `TOTAL_PUEBLOS=177`, `TOTAL_STATES=32`.
- **Configuración:** `setup_single_player(data)`, `setup_local_multiplayer(players_data)`, `setup_online_multiplayer(...)`.
- **Turnos:** `start_game()`, `get_current_player()`, `advance_turn()`, `skip_turn()`.
- **Movimiento/puntaje (para el sub-tablero):** `enter_state()`, `advance_pueblo()`, `score_pueblo()`, `exit_state()`.
- **Fin:** `_end_game()`, `_get_winner()`, `get_scores()`, `reset()`.

### 3.2 `Global` — modelo "simple" / estado puntual
`ScriptsSinglentos/global.gd`. Estado volátil de bajo nivel usado por el tablero: `game_mode`, `num_players`, `dice_result`, `current_turn`, `player_stats`, `game_history`, `log_event()`, `reset_game()`.

> **Nota de arquitectura:** existen **dos modelos en paralelo** (`InformacionJuego` rico + `Global` simple). El `game_manager` lee la configuración de **`InformacionJuego`** (modo, jugadores, colores) y usa `Global` como respaldo y para `dice_result`/`log_event`.

### 3.3 `AdaptadorPantalla` — escalado responsivo
`ScriptsSinglentos/adaptador_pantalla.gd`. Calcula `scale_factor` y `is_tall_screen` respecto a la base 1080×1920; emite `screen_adapted`. Utilidades: `scale_value()`, `get_safe_area()`, `get_extra_vertical_space()`.

### 3.4 `ManejadorPreguntas` — preguntas desde Firebase
`ScriptsSinglentos/manejador_preguntas.gd`. Ver §7.

### 3.5 `AdministradorOnline` — red (STUB)
`AdministradorOnline/ScriptsSinglentos/administrador_online.gd`. **Stub sin backend real**: simula salas para iterar la UI (`create_room`, `join_room`, `search_rooms` con datos demo, `leave_room`, `start_match`). La intención es reemplazar la implementación interna sin tocar a los consumidores cuando se elija backend (Nakama/ENet/WebSocket).

---

## 4. Flujo de la aplicación

```
Boot splash (motor)
   └─► MenuPrincipal.tscn  (escena principal)
         │  (overlay BarraCargaDatos mientras ManejadorPreguntas carga preguntas)
         ├─► UnJugadorModo   → InformacionJuego.setup_single_player()    → Tablero
         ├─► MultijugadorModo→ setup_local_multiplayer / online           → Tablero
         └─► Perfil          (datos del usuario; esqueleto)

Tablero.tscn
   └─► GameManager toma InformacionJuego → corre la partida (turnos, dado, preguntas)
         └─► al ganar → FinJuegoEstadísticas (podio) → reinicia o vuelve al menú
```

**Barra de carga** (`Barra_carga_datos.gd`, `CanvasLayer`): se engancha a las señales de `ManejadorPreguntas` (`inicio_carga`, `progreso_descarga`, `datos_actualizados`, `carga_fallida`, `datos_cargados`) y muestra el progreso de descarga/carga de preguntas; se auto-libera (`queue_free`) al terminar.

---

## 5. Escenas y scripts del menú

| Escena | Script | Rol |
|---|---|---|
| `MenuPrincipal.tscn` | `menu_principal.gd` | Navegación: diccionario `SCENES` + `change_scene_to_file`. Valida con `ResourceLoader.exists()` antes de cambiar. |
| `UnJugadorModo.tscn` | `un_jugador_modo.gd` | Elige nombre + avatar; `InformacionJuego.setup_single_player()`; va al `Tablero`. |
| `MultijugadorModo.tscn` | `multijugador_modo.gd` | Pestañas **Local** (slider de jugadores + `PlayerEntry` por jugador) y **Online** (crear/buscar sala + waiting room contra `AdministradorOnline`). Local → `setup_local_multiplayer()`. |
| `Perfil.tscn` | `perfil.gd` | Pantalla de perfil (esqueleto; datos reales pendientes de backend). |
| `PlayerEntry.tscn` | `PlayerEntry.gd` (`class_name PlayerEntry`) | Fila de configuración por jugador: nombre, **avatar** (`AVATAR_PATHS`) y **color** (`ColorPickerButton`). Evita avatares duplicados. |
| `SalaEntry.tscn` | `SalaEntry.gd` | Fila de una sala en la lista de búsqueda online. |
| `BarraCargaDatostscn.tscn` | `Barra_carga_datos.gd` | Overlay de carga de preguntas. |

> El **color elegido** por cada jugador (en `PlayerEntry`) y su avatar viajan en `InformacionJuego.players[i]` y se respetan luego en el tablero (coloreado de regiones + fila del HUD).

---

## 6. Núcleo del juego — `game_manager.gd`

`Juego/TableroJuego/game_manager.gd` (nodo `Tablero/Mapa/GameManager`). Orquesta toda la partida en el tablero macro.

### 6.1 Inicialización
- Carga recursivamente los nodos del mapa: `Location_N` (casillas) y `Area_N`/`Polygon2D` (regiones coloreables) bajo `Mapa/Estados`.
- `start_location_id` y `final_location_id` se **calculan dinámicamente** (min/max de las `Location_N`), así funciona sin importar cuántos estados haya.
- Lee la configuración de **`InformacionJuego`** (modo + jugadores + colores), con respaldo a `Global`.

### 6.2 Jugadores y colores
- `_setup_players()` mapea cada jugador `i` → ficha de escena `Jugador{i+1}` (en `Tablero/Jugadores`), tomando **nombre, color y avatar** de `InformacionJuego`.
- `players_data["playerN"] = { node, location_id, name, color, turns_played, avatar_id, info_index, ... }`.

### 6.3 Sistema de colores del mapa (requisito clave)
`_actualizar_colores_mapa()`: por cada casilla ocupada colorea su `Polygon2D` con el **color del jugador** (55% alpha); si 2+ jugadores coinciden, gris (empate); vacío = transparente. Se llama en cada paso de movimiento.

### 6.4 Ciclo de turno (mapa macro actual)
```
_ejecutar_turno_jugador()
  → start_dice_sequence_for_player()      # dado (roll_screen)
  → _on_dice_rolled_for_player()          # guarda N
  → show_question_screen_for_player()     # PreguntaPopup
  → _on_pregunta_completada_for_player()  # acierto → move_player_by_steps()
  → verificar_si_hay_ganador()            # meta → end_game(); si no → pasar_al_siguiente_jugador()
```
- **Movimiento:** `move_player_by_steps()` avanza casilla por casilla con `Tween` (con rebote al pasarse de la meta), actualizando color en cada paso.
- **Victoria actual:** llegar a `final_location_id` → `end_game()` → `FinJuegoEstadísticas`.

### 6.5 HUD en vivo
- Usa el panel ya incrustado en `Tablero.tscn` (`HUD/.../VBoxJugadores`).
- `show_game_hud()` instancia una fila `JugadorStatRow` por jugador (avatar + nombre + color + casilla); `update_game_hud()` la refresca cada turno/movimiento.
- La casilla se muestra con el **nombre real del estado** vía el diccionario `NOMBRES_ESTADOS` (1..32) y `_texto_casilla()` (“Inicio” en la salida).

### 6.6 Pantalla final
`show_stats_screen()` carga `FinJuegoEstadísticas.tscn`, le pasa `players_data` + ganador + modo, y conecta `restart_game_requested` / `return_to_menu_requested`.

> **Importante:** `tablero.gd` se redujo a solo el botón “← Menú”. Todo el loop (turnos, HUD, movimiento) lo controla **únicamente** `game_manager.gd` (antes ambos competían).

---

## 7. Sistema de preguntas y datos (Firebase)

`ScriptsSinglentos/manejador_preguntas.gd` (autoload `ManejadorPreguntas`).

- **Origen:** Firestore vía **REST** (`HTTPRequest` a `...:runQuery`), proyecto `olintlimx-e21ff`, colección `questions`. **No usa plugin** (no existe SDK oficial de Firebase para Godot).
- **Estrategia de carga (en `_ready`):** 1) caché `user://questions.json` → 2) respaldo `res://data/questions.json` → 3) descarga de Firebase. Así arranca offline.
- **Filtro actual:** por `state_id` (`state_id_filtro`, `cambiar_filtro_estado`). **[PLANEADO]** cambiará a filtrar por `pueblo_id`.
- **API:** `obtener_siguiente_pregunta()` (mazo barajado que se consume y se reinicia), `solicitar_actualizacion_manual()` (con cooldown).
- **Limpieza:** descarta preguntas con opciones vacías o con <3 opciones (el popup muestra 3 botones).
- **Señales:** `datos_cargados, carga_fallida, datos_actualizados, progreso_descarga, inicio_carga, ...` (las consume la barra de carga).
- **Formato de pregunta:** `{ question, options[], correct_index, explanation, ... }`.

---

## 8. Componentes del tablero

| Escena / Script | Rol | Señales / API clave |
|---|---|---|
| `roll_screen.tscn` / `roll_screen.gd` | Pantalla del **dado** (usa `DiceRollerControl` del addon). | emite `dice_rolled(result)` |
| `PreguntaPopup.tscn` / `pregunta_popup.gd` | Muestra **1 pregunta** (1 correcta + 2 incorrectas barajadas). Pide la pregunta a `ManejadorPreguntas`. | `mostrar_pregunta()`, emite `proceso_terminado(acierto)` |
| `FeedbackPopup.tscn` / `feedback_popup.gd` | Retroalimentación (✅/❌ + explicación) tras responder. | `mostrar_felicitacion()`, `mostrar_error()`, `feedback_continua` |
| `FinJuegoEstadísticas.tscn` / `fin_juego_estadísticas.gd` | Pantalla final: ganador + ranking. | `show_stats(players_data, winner_id, mode)`, `restart_game_requested`, `return_to_menu_requested` |
| `JugadorStatRow.tscn` / `jugador_stat_row.gd` | Fila del HUD: avatar (56×56), nombre, color, casilla/estado. | `setup(player_data, avatar_texture)`, `actualizar()` |
| `casilla_tablero.gd` (`@tool`, `Polygon2D`) | Región de un estado en el mapa. Relleno **visible solo en editor**; en runtime inicia transparente. | `iluminar(color)`, `apagar()`, `obtener_centro_casilla()` |
| `EstadoArea.tscn`+`PuebloArea.tscn` / `estado_area.gd` | Marcador `Area2D` de un estado/pueblo (posición, forma, datos desde fuera). | `setup(data)`, `estado_seleccionado` |

---

## 9. Addon `dice_roller`

Plugin comunitario de dado 3D (en `SubViewport`). Notas del proyecto:
- `roll_screen.tscn` define el `dice_set` y el tamaño de la caja.
- El roller emite la **suma** de los dados (`total_value`). Con 2 dados el resultado es 2–12; con 1 dado, 1–6.
- El **resaltado de cara ganadora** (`FaceHighligth`, un quad semitransparente) fue **desactivado** en `addons/dice_roller/dice/dice.gd → highlight()` porque se veía como un “fantasma” encimado. ⚠️ Es un archivo del addon: se perdería al actualizar el plugin.

---

## 10. [PLANEADO] Sub-tablero de Pueblos Mágicos

Diseño acordado (aún **no implementado**). Es la siguiente gran funcionalidad.

- **Concepto:** al caer en un estado, se abre un **sub-tablero espacial** con los pueblos mágicos de ese estado.
- **Mecánica:** dado + preguntas. **Puntaje = valor del dado, solo si se acierta** la pregunta del pueblo destino. Si falla: no avanza ni suma (pierde turno).
- **Recorrido:** se completa a lo largo de **varios turnos** (se retoma con `pueblo_index`). Al recorrer todos los pueblos → estado **visitado** → vuelve al mapa.
- **Movimiento macro:** **aleatorio** entre estados **no visitados** (por jugador); se elige nuevo estado solo al **completar** el actual.
- **Victoria:** primero en `PUNTAJE_META` (ej. 100) → **podio top 3 por puntos**. Si se agotan los 32 estados sin meta, gana el de más puntos.
- **Escena:** `SubTableroEstado` (Node2D) con fondo = imagen del estado (`Assets/Mapas/<Estado>.png`), nodos `PuebloArea` posicionados **desde Firebase** (`pos_x, pos_y, orden`), montada como overlay dejando **visible** el panel de jugadores.
- **Datos Firebase:** `pueblos: { pueblo_id, state_id, nombre, pos_x, pos_y, orden }` y `questions: { pueblo_id, question, options[], correct_index, explanation }` (solo `pueblo_id`; el vínculo estado↔pueblo vive en `pueblos`).
- **Decisión pendiente:** conexión Firebase **Opción A** (extender el REST actual a `pueblo_id`, recomendada) vs **Opción B** (plugin comunitario).

---

## 11. Puntos importantes / convenciones / gotchas

- **Singletons** viven en `ScriptsSinglentos/` (no en `Assets/`). Se referencian por nombre de autoload, no por ruta.
- **Mover escenas/recursos** debe hacerse **desde el panel FileSystem de Godot** (actualiza rutas y UIDs). Moverlos desde el explorador/IDE rompe las **rutas escritas a mano** (`res://...`) en los scripts (`change_scene_to_file`, `preload`, etc.).
- **Rutas de nodos:** `GameManager` cuelga de `Mapa`, por eso sube dos niveles (`../../`) para llegar a `Jugadores` y al `HUD`. Las fichas son `Tablero/Jugadores/Jugador1..6`.
- **Claves de los diccionarios** de `players_data` son `"player1".."playerN"` (lógicas); los **nodos** de escena son `Jugador1..Jugador6`.
- **`NOMBRES_ESTADOS`** mapea `location_id → nombre de estado` (claves 1..32; `Location_0` = “Inicio”).
- **Mapa:** los estados son `Area_0..Area_31` (`Polygon2D`) con `Location_N` (`Area2D` + `CollisionShape2D`). El centro del `CollisionShape2D` es el destino de la ficha.
- **Seguridad:** `Claves y APIS/` (keystores de firma) está en `.gitignore`. ⚠️ El `release.keystore` quedó en el historial (commit `79eadfb`); conviene reescribir ese commit antes de publicar si la llave es sensible.
- **Memoria de diseño:** las decisiones del sub-tablero están documentadas para continuidad (mecánica, escena, datos, victoria).

---

## 12. Estado actual y pendientes

**Implementado y funcional:**
- Menús (un jugador / multijugador local / perfil) → configuración en `InformacionJuego`.
- Tablero macro: turnos, dado, preguntas, retroalimentación, movimiento, coloreado por color de jugador, HUD en vivo con avatar/nombre/estado, pantalla final con ranking.
- Carga de preguntas desde Firebase con caché/respaldo offline.

**Pendiente / en progreso:**
- **Sub-tablero de pueblos mágicos** (§10) — diseñado, sin implementar.
- Filtrar preguntas por `pueblo_id` (hoy por `state_id`).
- Imágenes por estado en `Assets/Mapas/` (existen varias; faltan las restantes / nombres consistentes).
- Multijugador **online** real (hoy `AdministradorOnline` es stub).
- `Estadisticas.tscn` (referenciada por el menú) aún no existe.
- Backend de datos del **Perfil**.
- Calibrar `dice_set` (1 vs 2 dados) según la regla de puntaje final.
```
