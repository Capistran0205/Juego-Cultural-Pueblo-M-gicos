extends Node2D

# =========================================================
#   Tablero principal del juego (mapa de México).
#   Solo diseño/estructura: la lógica de turnos, movimiento
#   y carga desde Firebase quedará para una iteración futura.
# =========================================================

const MAIN_MENU := "res://MenuPrincipal/MenuPrincipal.tscn"

const ESTADO_AREA := preload("res://Juego/TableroJuego/Componentes/EstadoArea.tscn")
const JUGADOR_STAT_ROW := preload("res://Juego/TableroJuego/Componentes/JugadorStatRow.tscn")

# Mapeo de avatar_id → ruta del avatar.
# Si después agregas más avatares, sólo amplía este array.
const AVATAR_PATHS: Array[String] = [
	"res://Assets/Jugadores/Jugador1_bg.png",
	"res://Assets/Jugadores/Jugador2_bg.png",
	"res://Assets/Jugadores/Jugador3_bg.png",
	"res://Assets/Jugadores/Jugador4_bg.png",
	"res://Assets/Jugadores/Jugador5_bg.png",
	"res://Assets/Jugadores/Jugador6_bg.png",
]

@onready var estados_layer: Node2D = $Mapa/Estados
@onready var jugadores_layer: Node2D = $JugadoresLayer
@onready var vbox_jugadores: VBoxContainer = $HUD/HUDRoot/PanelStats/MarginContainer/VBoxContainer/ScrollContainer/VBoxJugadores
@onready var btn_regresar: Button = $HUD/HUDRoot/BtnRegresar

# Cache de filas del HUD por player_index para refrescos rápidos.
var _stat_rows: Dictionary = {}

# =========================================================
#                     INICIALIZACIÓN
# =========================================================

func _ready() -> void:
	btn_regresar.pressed.connect(_on_regresar_pressed)

	_construir_tabla_jugadores()
	_cargar_estados_desde_backend()

	# Suscripciones a InformacionJuego para refrescar el HUD
	# cuando avancen los turnos / movimientos (futuro).
	# InformacionJuego.player_added.connect(_on_player_added)

# =========================================================
#               TABLA DE ESTADÍSTICAS (HUD)
# =========================================================

func _construir_tabla_jugadores() -> void:
	for child in vbox_jugadores.get_children():
		child.queue_free()
	_stat_rows.clear()

	for player in InformacionJuego.players:
		var row := JUGADOR_STAT_ROW.instantiate()
		vbox_jugadores.add_child(row)
		var avatar_tex: Texture2D = _cargar_avatar(player.get("avatar_id", 0))
		row.setup(player, avatar_tex)
		_stat_rows[player.get("index", 0)] = row

# Llamar cuando el jugador se mueva o cambie su estado.
# (Hook para la futura lógica de turnos.)
func actualizar_jugador(player_data: Dictionary) -> void:
	var idx: int = player_data.get("index", 0)
	if _stat_rows.has(idx):
		_stat_rows[idx].actualizar(player_data)

func _cargar_avatar(avatar_id: int) -> Texture2D:
	if avatar_id < 0 or avatar_id >= AVATAR_PATHS.size():
		return null
	return load(AVATAR_PATHS[avatar_id]) as Texture2D

# =========================================================
#         CARGA DE ESTADOS (futuro: Firebase)
# =========================================================

# Pide al backend la lista de estados con sus coordenadas/forma
# y crea un EstadoArea por cada uno bajo $Mapa/Estados.
#
# Estructura esperada de cada item:
#   {
#     "id": "hidalgo",
#     "nombre": "Hidalgo",
#     "posicion": Vector2(x, y),     # en píxeles del mapa
#     "forma": Shape2D,              # opcional; si falta usa el default
#     "pueblos_count": 6,
#   }
func _cargar_estados_desde_backend() -> void:
	# TODO: reemplazar por la llamada real al AdministradorOnline
	#       o a un AdministradorMapa que consulte Firebase.
	#       Por ahora se deja un stub vacío para no bloquear el diseño.
	var estados: Array = _fetch_estados_stub()
	_pintar_estados(estados)

func _pintar_estados(estados: Array) -> void:
	for child in estados_layer.get_children():
		child.queue_free()

	for data in estados:
		var area := ESTADO_AREA.instantiate()
		estados_layer.add_child(area)
		area.setup(data)
		area.estado_seleccionado.connect(_on_estado_seleccionado)

func _fetch_estados_stub() -> Array:
	# Devolver [] por ahora. Cuando esté Firebase, esta función desaparece
	# y la llamada real va dentro de _cargar_estados_desde_backend().
	return []

# =========================================================
#                   INTERACCIÓN
# =========================================================

func _on_estado_seleccionado(estado_id: String) -> void:
	# Hook para la futura lógica: entrar al sub-tablero oca de ese estado.
	print("Estado seleccionado: ", estado_id)

func _on_regresar_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
