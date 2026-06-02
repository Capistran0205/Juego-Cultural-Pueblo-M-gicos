extends Node2D

const MAIN_MENU := "res://MenuPrincipal/MenuPrincipal.tscn"
const JUGADOR_STAT_ROW := preload("res://Juego/TableroJuego/Componentes/JugadorStatRow.tscn")

@onready var estados_layer: Node2D = $Mapa/Estados
@onready var vbox_jugadores: VBoxContainer = $HUD/HUDRoot/PanelStats/MarginContainer/VBoxContainer/ScrollContainer/VBoxJugadores
@onready var btn_regresar: Button = $HUD/HUDRoot/BtnRegresar

var lista_casillas: Array = []
var casilla_actual_index: int = 0
var es_modo_un_jugador: bool = true
var _stat_rows: Dictionary = {}

# Color que usará el polígono activo para iluminar la región en single player
var color_iluminacion_jugador: Color = Color("ff6666") 

func _ready() -> void:
	btn_regresar.pressed.connect(_on_regresar_pressed)
	_construir_tabla_jugadores()
	
	# Validar el modo de juego activo desde tu Autoload global
	es_modo_un_jugador = InformacionJuego.is_single_player() if InformacionJuego.has_method("is_single_player") else true

	# Almacenar secuencialmente tus 32 polígonos del árbol (Polygon2D hasta Polygon2D31)
	lista_casillas = estados_layer.get_children()
	
	# Arrancar en la casilla de salida (Index 0, tu primer Polygon2D)
	_actualizar_movimiento_tablero()

func avanzar_posiciones(pasos: int) -> void:
	if lista_casillas.is_empty():
		return
		
	# Apagar la iluminación semitransparente del estado anterior antes de movernos
	if casilla_actual_index < lista_casillas.size():
		lista_casillas[casilla_actual_index].apagar()
		
	# Ciclo circular preciso sobre tus 32 casillas
	casilla_actual_index = (casilla_actual_index + pasos) % lista_casillas.size()
	
	_actualizar_movimiento_tablero()

func _actualizar_movimiento_tablero() -> void:
	var nodo_casilla_destino = lista_casillas[casilla_actual_index]
	
	# 1. ¿Cómo te ves en el tablero?: Intentamos buscar el contenedor real de tus fichas.
	# Si tienes un nodo llamado 'Jugadores' en la raíz, usará ese. Si no hay fichas aún, saltará este paso sin dar error.
	var contenedor_fichas = get_node_or_null("Jugadores")
	if contenedor_fichas != null and contenedor_fichas.get_child_count() > 0:
		var ficha_jugador = contenedor_fichas.get_child(0)
		ficha_jugador.global_position = nodo_casilla_destino.obtener_centro_casilla()
	else:
		print("Nota: Iluminando casilla %d. No se movió ficha física porque no hay nodos en 'Jugadores'." % casilla_actual_index)
	
	# 2. ¿Cómo se ilumina?: Si es modo un jugador, enciende el polígono semitransparente
	if es_modo_un_jugador:
		nodo_casilla_destino.iluminar(color_iluminacion_jugador)
		
	# 3. Sincronizar y actualizar las estadísticas en el HUD
	if not InformacionJuego.players.is_empty():
		var local_player = InformacionJuego.players[0]
		local_player["state_index"] = casilla_actual_index
		
		# Si el index es 0, el script del HUD escribirá "Inicio" en lugar de "Estado 0"
		local_player["is_inside_state"] = (casilla_actual_index != 0) 
		_actualizar_hud_tabla(local_player)

# Simulación temporal del dado (Barra Espaciadora)
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		var tiro_dado = randi_range(1, 6)
		print("Dado virtual tiró: ", tiro_dado)
		avanzar_posiciones(tiro_dado)

# =========================================================
#                    LOGICA DE CONTROL DEL HUD
# =========================================================
func _construir_tabla_jugadores() -> void:
	for child in vbox_jugadores.get_children(): child.queue_free()
	_stat_rows.clear()
	for player in InformacionJuego.players:
		var row := JUGADOR_STAT_ROW.instantiate()
		vbox_jugadores.add_child(row)
		_stat_rows[player.get("index", 0)] = row
		row.setup(player, null)

func _actualizar_hud_tabla(player_data: Dictionary) -> void:
	var idx: int = player_data.get("index", 0)
	if _stat_rows.has(idx): 
		_stat_rows[idx].actualizar(player_data)

func _on_regresar_pressed() -> void: 
	get_tree().change_scene_to_file(MAIN_MENU)
