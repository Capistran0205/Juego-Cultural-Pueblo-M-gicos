extends Node

# ============================================
# CONFIGURACIÓN DEL MODO DE JUEGO
# ============================================
enum GameMode { SINGLE_PLAYER, MULTIPLAYER }
var current_game_mode: GameMode = GameMode.SINGLE_PLAYER

# ============================================
# DATOS DE JUGADORES
# ============================================
var players_data = {}
var jugadores_que_van_a_jugar: int = 1
var turno_actual: int = 0
var algun_jugador_ya_gano: bool = false
var jugador_ganador: String = ""

# ============================================
# COLORES DEL MAPA
# ============================================
const COLOR_NEUTRAL = Color(1, 1, 1, 0)          # Transparente = sin jugador
const COLOR_EMPATE  = Color(0.5, 0.5, 0.5, 0.55) # Gris = 2+ jugadores

# Paleta de respaldo SOLO si InformacionJuego no trae un color para el jugador
# (p. ej. al abrir Tablero.tscn directamente sin pasar por el menú).
const COLORES_RESPALDO = [
	Color.RED, Color.BLUE, Color.GREEN,
	Color.YELLOW, Color.MAGENTA, Color.CYAN
]

# Diccionario: location_id -> Polygon2D
# Se llena automáticamente en _ready()
var poligonos_municipio: Dictionary = {}

# ============================================
# DATOS DEL TABLERO
# ============================================
# La casilla de inicio y la meta se calculan en _ready() a partir de los
# nodos reales del tablero (Location_0 .. Location_N), así el flujo funciona
# sin importar cuántos estados existan en la escena.
var start_location_id: int = 0
var final_location_id: int = 0

# ✅ Enumeración por casilla (etiquetas para el HUD)
const NOMBRES_ESTADOS: Dictionary = {
	1: "Ciudad de México",
	2: "Hidalgo",
	3: "Querétaro",
	4: "San Luis Potosí",
	5: "Tamaulipas",
	6: "Nuevo León",
	7: "Coahuila",
	8: "Chihuahua",
	9: "Sonora",
	10: "Baja California",
	11: "Baja California Sur",
	12: "Sinaloa",
	13: "Durango",
	14: "Zacatecas",
	15: "Aguascalientes",
	16: "Nayarit",
	17: "Jalisco",
	18: "Colima",
	19: "Michoacán",
	20: "Guanajuato",
	21: "Estado de México",
	22: "Morelos",
	23: "Tlaxcala",
	24: "Puebla",
	25: "Guerrero",
	26: "Oaxaca",
	27: "Chiapas",
	28: "Campeche",
	29: "Quintanarroo",
	30: "Yucatán",
	31: "Tabasco",
	32: "Veracruz"
}

var locations_nodes = {}
var is_moving = false
var is_game_active = false

# Las fichas viven en Tablero/Jugadores/JugadorN. GameManager cuelga de Mapa,
# así que hay que subir dos niveles (../../) para llegar a Jugadores.
@onready var jugadores_root: Node = get_node_or_null("../../Jugadores")

# HUD de jugadores que ya viene incrustado en Tablero.tscn. GameManager se
# encarga de poblarlo y refrescarlo (antes lo hacía tablero.gd, lo que chocaba
# con este flujo). Ruta: Tablero/HUD/HUDRoot/.../VBoxJugadores
@onready var hud_vbox: Node = get_node_or_null(
	"../../HUD/HUDRoot/PanelStats/MarginContainer/VBoxContainer/ScrollContainer/VBoxJugadores"
)
const JUGADOR_STAT_ROW = preload("res://Juego/TableroJuego/Componentes/Escenas/JugadorStatRow.tscn")
var _stat_rows: Dictionary = {}  # player_id -> fila del HUD

@export_file("*.tscn") var dice_scene_path: String = "res://Juego/TableroJuego/Componentes/Escenas/roll_screen.tscn"
var dice_scene_instance = null
var dice_canvas_layer = null

@export_file("*.tscn") var pregunta_popup_path: String = "res://Juego/TableroJuego/Componentes/Escenas/PreguntaPopup.tscn"
var question_scene_instance = null
var question_canvas_layer = null

var pasos_pendientes: int = 0

@export var move_duration: float = 0.5
@export var pause_between_moves: float = 0.3
@export var delay_between_turns: float = 2.0

@export_file("*.tscn") var stats_screen_path: String = "res://Juego/TableroJuego/Componentes/Escenas/FinJuegoEstadísticas.tscn"
var stats_screen_instance = null
var stats_canvas_layer = null

# ============================================
# INICIALIZACIÓN
# ============================================
func _ready() -> void:
	_cargar_locations_recursivo($"../Estados")
	_cargar_poligonos_recursivo($"../Estados")
	_calcular_inicio_y_meta()

	print("GameManager listo. Ubicaciones cargadas: %d" % locations_nodes.size())
	print("Polígonos de municipio encontrados: %d" % poligonos_municipio.size())
	print("Inicio: %d | Meta: %d" % [start_location_id, final_location_id])

	# Ocultar todas las fichas; _setup_players() mostrará solo las activas.
	_ocultar_todas_las_fichas()

	await get_tree().process_frame
	await get_tree().process_frame

	var config = _leer_configuracion()
	print("\n>>> CONFIGURACIÓN DE LA PARTIDA <<<")
	print("Modo: %s | Jugadores: %d" % [
		"MULTIJUGADOR" if config.mode == GameMode.MULTIPLAYER else "UN JUGADOR",
		config.num
	])

	configure_game(config.mode, config.num)
	start_game()

# Decide modo y número de jugadores. Prioriza InformacionJuego (lo configuran
# los menús de un jugador / multijugador). Si está vacío, cae a Global.
func _leer_configuracion() -> Dictionary:
	if InformacionJuego and not InformacionJuego.players.is_empty():
		var n: int = InformacionJuego.players.size()
		var es_single: bool = InformacionJuego.is_single_player() if InformacionJuego.has_method("is_single_player") else (n <= 1)
		return {
			"mode": GameMode.SINGLE_PLAYER if es_single else GameMode.MULTIPLAYER,
			"num": max(1, n)
		}

	# Respaldo: configuración simple en Global (modo de prueba directo).
	var mode_global: int = Global.game_mode if "game_mode" in Global else 0
	var num_global: int = Global.num_players if "num_players" in Global else 1
	return {
		"mode": GameMode.MULTIPLAYER if mode_global == 1 else GameMode.SINGLE_PLAYER,
		"num": max(1, num_global)
	}

func _calcular_inicio_y_meta() -> void:
	if locations_nodes.is_empty():
		push_error("_calcular_inicio_y_meta: no se cargó ninguna Location_ del tablero.")
		return
	var ids: Array = locations_nodes.keys()
	ids.sort()
	start_location_id = ids[0]
	final_location_id = ids[-1]

func _ocultar_todas_las_fichas() -> void:
	if jugadores_root == null:
		return
	for child in jugadores_root.get_children():
		child.visible = false

# ============================================
# CARGA DE NODOS
# ============================================
func _cargar_locations_recursivo(nodo: Node) -> void:
	if nodo == null:
		push_error("_cargar_locations_recursivo: el nodo es null (¿existe 'Estados' como hermano de GameManager?)")
		return
	for child in nodo.get_children():
		if child.name.begins_with("Location_"):
			var id = int(child.name.split("_")[-1])
			locations_nodes[id] = child
		if child.get_child_count() > 0:
			_cargar_locations_recursivo(child)

func _cargar_poligonos_recursivo(nodo: Node) -> void:
	"""
	Busca Polygon2D asociados a cada área del mapa y los registra
	en poligonos_municipio[id] para poder colorearlos directamente.

	Estructura esperada en la escena:
	  Estados
		├── Area_1  ← si este nodo ES un Polygon2D
		│     └── Location_1
		│           └── CollisionShape2D
		├── Area_2 ...
	"""
	if nodo == null:
		push_error("_cargar_poligonos_recursivo: el nodo es null (¿existe 'Estados' como hermano de GameManager?)")
		return
	for child in nodo.get_children():
		# Caso A: el propio nodo Area_X extiende Polygon2D
		if child is Polygon2D and child.name.begins_with("Area_"):
			var id_str = child.name.split("_")[-1]
			if id_str.is_valid_int():
				poligonos_municipio[int(id_str)] = child

		# Caso B: dentro del Area_X hay un Polygon2D hijo
		elif child.name.begins_with("Area_"):
			var id_str = child.name.split("_")[-1]
			if id_str.is_valid_int():
				for subchild in child.get_children():
					if subchild is Polygon2D:
						poligonos_municipio[int(id_str)] = subchild
						break  # Solo el primer Polygon2D del área

		# Seguir buscando en profundidad
		if child.get_child_count() > 0:
			_cargar_poligonos_recursivo(child)

# ============================================
# SISTEMA DE COLORES DEL MAPA  ← NÚCLEO DEL REQUERIMIENTO
# ============================================
func _actualizar_colores_mapa() -> void:
	"""
	Colorea cada Polygon2D según cuántos jugadores ocupan esa casilla,
	respetando el COLOR ELEGIDO por cada jugador (viene de InformacionJuego).
	- 0 jugadores → transparente (COLOR_NEUTRAL)
	- 1 jugador   → color del jugador con 55% de opacidad
	- 2+ jugadores → gris (COLOR_EMPATE)
	"""
	# Contar jugadores por casilla
	var ocupacion: Dictionary = {}  # location_id -> [Color, Color, ...]

	for player_id in players_data.keys():
		var pdata = players_data[player_id]
		var loc: int = pdata["location_id"]
		if not ocupacion.has(loc):
			ocupacion[loc] = []
		ocupacion[loc].append(pdata["color"])

	# Limpiar todos los polígonos
	for loc_id in poligonos_municipio.keys():
		poligonos_municipio[loc_id].color = COLOR_NEUTRAL

	# Colorear según ocupación
	for loc_id in ocupacion.keys():
		if not poligonos_municipio.has(loc_id):
			continue

		var jugadores_en_casilla: Array = ocupacion[loc_id]
		var poligono: Polygon2D = poligonos_municipio[loc_id]

		if jugadores_en_casilla.size() == 1:
			var base: Color = jugadores_en_casilla[0]
			poligono.color = Color(base.r, base.g, base.b, 0.55)
		else:
			poligono.color = COLOR_EMPATE

# ============================================
# CONFIGURACIÓN INICIAL DEL JUEGO
# ============================================
func configure_game(mode: GameMode, num_players: int = 1):
	current_game_mode = mode
	jugadores_que_van_a_jugar = max(1, num_players)
	_setup_players(jugadores_que_van_a_jugar)

	print("\n=== JUEGO CONFIGURADO ===")
	print("Modo: %s" % ("MULTIJUGADOR" if mode == GameMode.MULTIPLAYER else "UN JUGADOR"))
	print("Jugadores: %d" % jugadores_que_van_a_jugar)

# Crea players_data tomando nombre y COLOR de InformacionJuego (si existe) y
# mapeando cada jugador i a la ficha de escena "Jugador{i+1}".
func _setup_players(num_players: int) -> void:
	players_data.clear()
	print("\n=== CONFIGURANDO JUGADORES ===")

	for i in range(num_players):
		var player_id = "player%d" % (i + 1)
		var player_node_name = "Jugador%d" % (i + 1)
		var node = jugadores_root.get_node_or_null(player_node_name) if jugadores_root else null

		if node == null:
			push_error("_setup_players: no se encontró la ficha '%s' en Tablero/Jugadores." % player_node_name)
			continue

		# Datos del jugador tal como los dejó el menú (nombre + color elegido).
		var info: Dictionary = {}
		if InformacionJuego and i < InformacionJuego.players.size():
			info = InformacionJuego.players[i]

		var color: Color = info.get("color", COLORES_RESPALDO[i % COLORES_RESPALDO.size()])
		var pname: String = info.get("name", "Jugador %d" % (i + 1))
		var avatar_id: int = info.get("avatar_id", i)

		node.visible = true
		node.set_meta("color_jugador", color)
		if not node.is_in_group("jugadores"):
			node.add_to_group("jugadores")

		players_data[player_id] = {
			"node": node,
			"location_id": start_location_id,
			"is_moving": false,
			"name": pname,
			"color": color,
			"turns_played": 0,
			"info_index": i,
			"avatar_id": avatar_id
		}

		_colocar_ficha_en_location(node, start_location_id)
		print("✅ %s → %s (color %s)" % [pname, player_node_name, color])

	print("✅ %d jugadores configurados\n" % players_data.size())

# Coloca una ficha sobre el CollisionShape2D de una casilla.
func _colocar_ficha_en_location(node: Node2D, location_id: int) -> void:
	if not locations_nodes.has(location_id):
		return
	var location = locations_nodes.get(location_id)
	var collision_shape = location.get_node_or_null("CollisionShape2D")
	if collision_shape:
		node.global_position = collision_shape.global_position

# ============================================
# INICIAR JUEGO
# ============================================
func start_game():
	if is_game_active:
		print("Ya hay un juego en progreso")
		return

	print("\n╔════════════════════════════════╗")
	print("║   === PARTIDA INICIADA ===    ║")
	print("╚════════════════════════════════╝")

	var nombres_jugadores = []
	for player_id in players_data.keys():
		nombres_jugadores.append(players_data[player_id]["name"])
	print("Jugadores: %s\n" % ", ".join(nombres_jugadores))

	is_game_active = true
	turno_actual = 0
	algun_jugador_ya_gano = false
	jugador_ganador = ""

	for player_id in players_data.keys():
		players_data[player_id]["location_id"] = start_location_id
		_colocar_ficha_en_location(players_data[player_id]["node"], start_location_id)

	Global.current_turn = 1

	# ✅ Pintar casilla inicial de todos los jugadores con su color elegido
	_actualizar_colores_mapa()

	show_game_hud()
	_ejecutar_turno_jugador()

# ============================================
# SISTEMA DE TURNOS
# ============================================
func _ejecutar_turno_jugador():
	if algun_jugador_ya_gano:
		end_game()
		return

	var jugador_actual_id = obtener_jugador_en_turno()
	var jugador_data = players_data[jugador_actual_id]

	update_game_hud()

	print("\n┌─────────────────────────────────")
	print("│ --- Turno de %s ---" % jugador_data["name"])
	print("│ Posición actual: Casilla %d" % jugador_data["location_id"])
	print("└─────────────────────────────────")

	start_dice_sequence_for_player(jugador_actual_id)

func obtener_jugador_en_turno() -> String:
	var player_index = turno_actual % jugadores_que_van_a_jugar
	return "player%d" % (player_index + 1)

func pasar_al_siguiente_jugador():
	turno_actual += 1
	Global.current_turn += 1

	var jugador_siguiente_id = obtener_jugador_en_turno()
	var jugador_siguiente = players_data[jugador_siguiente_id]

	print("\n>>> Siguiente turno: %s (Turno global: %d)\n" % [jugador_siguiente["name"], Global.current_turn])

	await get_tree().create_timer(delay_between_turns).timeout
	_ejecutar_turno_jugador()

# ============================================
# SECUENCIA DE DADO
# ============================================
func start_dice_sequence_for_player(player_id: String):
	if is_moving:
		return

	var jugador_data = players_data[player_id]

	if jugador_data["location_id"] == final_location_id:
		print("¡%s YA LLEGÓ AL FINAL!" % jugador_data["name"])
		algun_jugador_ya_gano = true
		jugador_ganador = player_id
		end_game()
		return

	show_dice_screen_for_player(player_id)

func show_dice_screen_for_player(player_id: String):
	dice_canvas_layer = CanvasLayer.new()
	dice_canvas_layer.layer = 100
	get_tree().current_scene.add_child(dice_canvas_layer)

	var dice_scene = load(dice_scene_path)
	if dice_scene:
		dice_scene_instance = dice_scene.instantiate()
		if dice_scene_instance is Control:
			dice_scene_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dice_canvas_layer.add_child(dice_scene_instance)

		if dice_scene_instance.has_signal("dice_rolled"):
			dice_scene_instance.connect("dice_rolled",
				func(result): _on_dice_rolled_for_player(result, player_id))

		print("%s lanza el dado..." % players_data[player_id]["name"])
	else:
		push_error("No se pudo cargar la escena del dado: %s" % dice_scene_path)

func _on_dice_rolled_for_player(result: int, player_id: String):
	print("→ %s lanzó: %d" % [players_data[player_id]["name"], result])
	Global.dice_result = result
	pasos_pendientes = result
	Global.log_event("%s lanzó: %d" % [players_data[player_id]["name"], result])

	await get_tree().create_timer(1.0).timeout
	hide_dice_screen()
	show_question_screen_for_player(player_id)

# ============================================
# SISTEMA DE PREGUNTAS
# ============================================
func show_question_screen_for_player(player_id: String):
	question_canvas_layer = CanvasLayer.new()
	question_canvas_layer.layer = 101
	get_tree().current_scene.add_child(question_canvas_layer)

	var q_scene = load(pregunta_popup_path)
	if q_scene:
		question_scene_instance = q_scene.instantiate()
		if question_scene_instance is Control:
			question_scene_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		question_canvas_layer.add_child(question_scene_instance)

		if question_scene_instance.has_signal("proceso_terminado"):
			question_scene_instance.connect("proceso_terminado",
				func(acierto): _on_pregunta_completada_for_player(acierto, player_id))

		if question_scene_instance.has_method("mostrar_pregunta"):
			question_scene_instance.mostrar_pregunta()
	else:
		push_error("No se pudo cargar el popup de pregunta: %s" % pregunta_popup_path)

func _on_pregunta_completada_for_player(acierto: bool, player_id: String):
	hide_question_screen()

	var jugador_data = players_data[player_id]
	var player_node_ref = jugador_data["node"]

	if acierto:
		print("✓ ¡%s ACERTÓ! Avanza %d casillas" % [jugador_data["name"], pasos_pendientes])
		show_floating_text(pasos_pendientes, player_node_ref.global_position, jugador_data["name"], true)
		await get_tree().create_timer(1.5).timeout
		await move_player_by_steps(player_id, pasos_pendientes)
	else:
		print("✗ %s falló la pregunta. Pierde turno." % jugador_data["name"])
		show_floating_text(0, player_node_ref.global_position, jugador_data["name"], false)
		await get_tree().create_timer(2.0).timeout

	pasos_pendientes = 0
	jugador_data["turns_played"] += 1
	verificar_si_hay_ganador(player_id)

# ============================================
# MOVIMIENTO CON REBOTE
# ============================================
func move_player_by_steps(player_id: String, steps: int):
	if is_moving:
		return

	is_moving = true
	var jugador_data = players_data[player_id]
	var current_location = jugador_data["location_id"]
	var direction = 1

	for i in range(steps):
		var next_location_id = current_location + direction

		# Rebote al pasarse de la meta o de la salida
		if next_location_id > final_location_id:
			print("→ %s se pasó de la meta. ¡Rebotando!" % jugador_data["name"])
			direction = -1
			next_location_id = current_location + direction
		elif next_location_id < start_location_id:
			direction = 1
			next_location_id = current_location + direction

		await move_player_to_location_animated(player_id, next_location_id)
		current_location = next_location_id

		# ✅ Actualizar color del mapa en cada paso (respeta color del jugador)
		_actualizar_colores_mapa()

		if i < steps - 1:
			await get_tree().create_timer(pause_between_moves).timeout

	is_moving = false
	print("→ %s - Posición final: Casilla %d" % [jugador_data["name"], jugador_data["location_id"]])
	update_game_hud()

func move_player_to_location_animated(player_id: String, new_location_id: int):
	var target_location = locations_nodes.get(new_location_id)

	if target_location:
		var jugador_data = players_data[player_id]
		var player_node_ref = jugador_data["node"]
		var collision_shape = target_location.get_node_or_null("CollisionShape2D")

		if not collision_shape:
			print("ERROR: No se encontró CollisionShape2D en %s" % target_location.name)
			return

		var end_pos = collision_shape.global_position
		var tween = create_tween()
		tween.tween_property(player_node_ref, "global_position", end_pos, move_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		jugador_data["location_id"] = new_location_id
		await tween.finished
	else:
		push_warning("No existe Location_%d en el tablero; se omite el paso." % new_location_id)

# ============================================
# VERIFICACIÓN DE VICTORIA
# ============================================
func verificar_si_hay_ganador(player_id: String):
	var jugador_data = players_data[player_id]

	if jugador_data["location_id"] == final_location_id:
		print("\n🏆 ¡%s alcanzó la casilla %d!" % [jugador_data["name"], final_location_id])
		algun_jugador_ya_gano = true
		jugador_ganador = player_id
		end_game()
	else:
		print("→ %s no ganó aún (Casilla %d/%d)" % [jugador_data["name"], jugador_data["location_id"], final_location_id])
		pasar_al_siguiente_jugador()

# ============================================
# FINALIZACIÓN DEL JUEGO
# ============================================
func end_game():
	is_game_active = false
	is_moving = false

	print("\n╔═══════════════════════════════╗")
	print("║  === FIN DE LA PARTIDA ===    ║")
	print("╚═══════════════════════════════╝\n")

	if algun_jugador_ya_gano:
		var ganador = players_data[jugador_ganador]
		print("🏆 ¡%s es el ganador!" % ganador["name"])

		var jugadores_ordenados = players_data.keys()
		jugadores_ordenados.sort_custom(func(a, b):
			return players_data[a]["location_id"] > players_data[b]["location_id"]
		)

		var pos = 1
		for pid in jugadores_ordenados:
			var pdata = players_data[pid]
			var emoji = "🥇" if pos == 1 else ("🥈" if pos == 2 else ("🥉" if pos == 3 else "  "))
			print("%s %d. %s - Casilla %d" % [emoji, pos, pdata["name"], pdata["location_id"]])
			pos += 1

		await get_tree().create_timer(2.0).timeout
		show_stats_screen()

# ============================================
# HUD EN TIEMPO REAL (usa el HUD ya incrustado en Tablero.tscn)
# ============================================
func show_game_hud():
	if hud_vbox == null:
		push_warning("show_game_hud: no se encontró VBoxJugadores en el HUD.")
		return

	for child in hud_vbox.get_children():
		child.queue_free()
	_stat_rows.clear()

	for player_id in players_data.keys():
		var row = JUGADOR_STAT_ROW.instantiate()
		hud_vbox.add_child(row)
		_stat_rows[player_id] = row
		row.setup(_fila_hud_dict(player_id), _cargar_avatar_textura(players_data[player_id].get("avatar_id", 0)))

	update_game_hud()
	print("📊 HUD activado.")

func update_game_hud():
	for player_id in _stat_rows.keys():
		var row = _stat_rows[player_id]
		if is_instance_valid(row) and players_data.has(player_id):
			row.actualizar(_fila_hud_dict(player_id))

# Carga la textura del avatar elegido por el jugador (mismo orden que
# PlayerEntry.AVATAR_PATHS: Jugador1_bg.png .. Jugador6_bg.png).
func _cargar_avatar_textura(avatar_id: int) -> Texture2D:
	var rutas: Array = PlayerEntry.AVATAR_PATHS
	if rutas.is_empty():
		return null
	var idx: int = clamp(avatar_id, 0, rutas.size() - 1)
	return load(rutas[idx]) as Texture2D

# Adapta una entrada de players_data al formato que espera JugadorStatRow.
func _fila_hud_dict(player_id: String) -> Dictionary:
	var p = players_data[player_id]
	return {
		"index": p.get("info_index", 0),
		"name": p["name"],
		"color": p["color"],
		"state_index": p["location_id"],
		"is_inside_state": p["location_id"] != start_location_id,
		"pueblo_index": 0,
		"estado_nombre": _texto_casilla(p["location_id"]),
	}

# Texto a mostrar en la tabla para la casilla actual del jugador:
# "Inicio" en la salida, o el nombre real del estado desde NOMBRES_ESTADOS.
func _texto_casilla(location_id: int) -> String:
	if location_id == start_location_id:
		return "Ciudad de México"
	return get_nombre_estado(location_id)

# Función auxiliar para obtener el nombre del estado desde cualquier parte del código
func get_nombre_estado(location_id: int) -> String:
	return NOMBRES_ESTADOS.get(location_id, "Casilla %d" % location_id)

# ============================================
# PANTALLA FINAL DE ESTADÍSTICAS
# ============================================
func show_stats_screen():
	stats_canvas_layer = CanvasLayer.new()
	stats_canvas_layer.layer = 102
	get_tree().current_scene.add_child(stats_canvas_layer)

	var stats_scene = load(stats_screen_path)
	if stats_scene:
		stats_screen_instance = stats_scene.instantiate()
		if stats_screen_instance is Control:
			stats_screen_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stats_canvas_layer.add_child(stats_screen_instance)

		if stats_screen_instance.has_signal("restart_game_requested"):
			stats_screen_instance.connect("restart_game_requested", _on_restart_game)
		if stats_screen_instance.has_signal("return_to_menu_requested"):
			stats_screen_instance.connect("return_to_menu_requested", _on_return_to_menu)
		if stats_screen_instance.has_method("show_stats"):
			stats_screen_instance.show_stats(players_data, jugador_ganador, current_game_mode)

		print("📊 Pantalla de estadísticas mostrada.")
	else:
		push_error("No se pudo cargar la pantalla de estadísticas: %s" % stats_screen_path)

func hide_stats_screen():
	if stats_screen_instance:
		stats_screen_instance.queue_free()
		stats_screen_instance = null
	if stats_canvas_layer:
		stats_canvas_layer.queue_free()
		stats_canvas_layer = null

func _on_restart_game():
	print("\n🔄 Reiniciando partida...\n")
	hide_stats_screen()
	algun_jugador_ya_gano = false
	jugador_ganador = ""
	turno_actual = 0
	is_game_active = false
	configure_game(current_game_mode, jugadores_que_van_a_jugar)
	start_game()

func _on_return_to_menu():
	print("\n🏠 Regresando al menú principal...\n")
	hide_stats_screen()
	get_tree().change_scene_to_file("res://MenuPrincipal/MenuPrincipal.tscn")

# ============================================
# TEXTO FLOTANTE
# ============================================
func show_floating_text(number: int, position: Vector2, player_name: String = "", acierto: bool = true):
	var label = Label.new()

	if acierto:
		label.text = "Turno de %s\n¡Has avanzado +%d casillas!" % [player_name, number] if player_name != "" else "¡Avanzas +%d casillas!" % number
	else:
		label.text = "Turno de %s\n¡Has Fallado! Pierdes turno" % player_name if player_name != "" else "¡Fallaste! Pierdes turno"

	label.add_theme_font_size_override("font_size", 24)
	var text_color = Color(1, 0.2, 0.2) if not acierto else Color(1, 1, 0)
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(300, 0)
	label.clip_contents = false
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	get_tree().current_scene.add_child(label)
	label.reset_size()
	label.global_position = position + Vector2(-label.size.x / 2, -80)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 100, 1.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	label.scale = Vector2(0.5, 0.5)
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.3)
	tween.finished.connect(label.queue_free)

# ============================================
# AUXILIARES
# ============================================
func hide_dice_screen():
	if dice_scene_instance: dice_scene_instance.queue_free()
	if dice_canvas_layer: dice_canvas_layer.queue_free()
	dice_scene_instance = null
	dice_canvas_layer = null

func hide_question_screen():
	if question_scene_instance: question_scene_instance.queue_free()
	if question_canvas_layer: question_canvas_layer.queue_free()
	question_scene_instance = null
	question_canvas_layer = null

func reset_game():
	is_game_active = false
	is_moving = false
	algun_jugador_ya_gano = false
	turno_actual = 0
	hide_dice_screen()
	hide_question_screen()

	for player_id in players_data.keys():
		var pdata = players_data[player_id]
		pdata["location_id"] = start_location_id
		pdata["turns_played"] = 0
		_colocar_ficha_en_location(pdata["node"], start_location_id)

	_actualizar_colores_mapa()
	Global.reset_game()
	print("Juego reiniciado")
