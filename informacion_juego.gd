extends Node

# =========================================================
#                    SEÑALES
# =========================================================

signal player_added(player: Dictionary)
signal player_removed(index: int)
signal game_started
signal game_ended(winner: Dictionary)

# =========================================================
#                    ENUMS
# =========================================================

enum GameMode { NONE, SINGLE, LOCAL_MULTI, ONLINE_MULTI }
enum Difficulty { NORMAL, HARD }
enum GameState { MENU, PLAYING_MAP, PLAYING_OCA, GAME_OVER }

# =========================================================
#                 DATOS DE PARTIDA
# =========================================================

var game_mode: GameMode = GameMode.NONE
var game_state: GameState = GameState.MENU
var difficulty: Difficulty = Difficulty.NORMAL

# Jugadores activos en la partida
var players: Array[Dictionary] = []

# Control de turnos
var current_turn_index: int = 0
var turn_number: int = 0

# Estado del tablero
var current_state_route_index: int = 0  # posición en la ruta de estados

# Datos de la sala online
var match_id: String = ""
var match_code: String = ""
var match_name: String = ""
var is_host: bool = false

# Constantes del juego
const MAX_PLAYERS: int = 6
const MIN_PLAYERS_MULTI: int = 2
const TOTAL_PUEBLOS: int = 177
const TOTAL_STATES: int = 32

# Colores predefinidos para fichas
const TOKEN_COLORS: Array[Color] = [
	Color("e63946"),  # Rojo
	Color("457b9d"),  # Azul
	Color("2a9d8f"),  # Verde
	Color("e9c46a"),  # Amarillo
	Color("9b5de5"),  # Morado
	Color("f77f00"),  # Naranja
]

# =========================================================
#              ESTRUCTURA DE UN JUGADOR
# =========================================================

# Crea un diccionario de jugador con valores por defecto
func _create_player(data: Dictionary) -> Dictionary:
	return {
		# Identidad
		"index": data.get("index", 1),
		"name": data.get("name", "Jugador"),
		"avatar_id": data.get("avatar_id", 0),
		"color": data.get("color", TOKEN_COLORS[0]),
		"is_local": data.get("is_local", true),
		"network_id": data.get("network_id", ""),
		
		# Posición en el mapa
		"state_index": 0,         # 0 = inicio, 1-32 = estados
		"is_inside_state": false,  # ¿está dentro de un sub-tablero oca?
		
		# Posición en el sub-tablero oca
		"pueblo_index": 0,        # casilla actual dentro del sub-tablero
		
		# Puntaje
		"pueblos_scored": 0,      # pueblos mágicos visitados (0-177)
		# "pueblos_visited": [],    # IDs de pueblos visitados
		
		# Estado de turno
		"skips_remaining": 0,     # turnos que pierde
		"finished": false,        # ¿ya terminó la partida?
		"is_winner": false,		  # Gano la partida?
	}

# =========================================================
#           CONFIGURACIÓN: UN JUGADOR
# =========================================================

func setup_single_player(data: Dictionary):
	reset()
	game_mode = GameMode.SINGLE
	difficulty = data.get("difficulty", Difficulty.NORMAL)
	
	var player = _create_player({
		"index": 1,
		"name": data.get("name", "Jugador"),
		"avatar_id": data.get("avatar_id", 0),
		"color": TOKEN_COLORS[0],
		"is_local": true,
	})
	players.append(player)
	player_added.emit(player)

# =========================================================
#           CONFIGURACIÓN: MULTIJUGADOR LOCAL
# =========================================================

func setup_local_multiplayer(players_data: Array[Dictionary]):
	reset()
	game_mode = GameMode.LOCAL_MULTI
	
	for i in range(players_data.size()):
		var p = players_data[i]
		var player = _create_player({
			"index": i + 1,
			"name": p.get("name", "Jugador %d" % (i + 1)),
			"avatar_id": p.get("avatar_id", 0),
			"color": p.get("color", TOKEN_COLORS[i]),
			"is_local": true,
		})
		players.append(player)
		player_added.emit(player)

# =========================================================
#           CONFIGURACIÓN: MULTIJUGADOR ONLINE
# =========================================================

func setup_online_multiplayer(players_data: Array[Dictionary], 
							   _match_id: String, 
							   _match_code: String,
							   _match_name: String,
							   _is_host: bool):
	reset()
	game_mode = GameMode.ONLINE_MULTI
	match_id = _match_id
	match_code = _match_code
	match_name = _match_name
	is_host = _is_host
	
	for i in range(players_data.size()):
		var p = players_data[i]
		var player = _create_player({
			"index": i + 1,
			"name": p.get("name", "Jugador %d" % (i + 1)),
			"avatar_id": p.get("avatar_id", 0),
			"color": TOKEN_COLORS[i],
			"is_local": p.get("is_local", false),
			"network_id": p.get("network_id", ""),
		})
		players.append(player)
		player_added.emit(player)

# =========================================================
#              CONTROL DE TURNOS
# =========================================================

func start_game():
	game_state = GameState.PLAYING_MAP
	current_turn_index = 0
	turn_number = 1
	game_started.emit()

func get_current_player() -> Dictionary:
	if players.is_empty():
		return {}
	return players[current_turn_index]

func advance_turn():
	turn_number += 1
	
	# Buscar el siguiente jugador que pueda jugar
	var attempts = 0
	while attempts < players.size():
		current_turn_index = wrapi(current_turn_index + 1, 0, players.size())
		var player = players[current_turn_index]
		
		# Si el jugador ya terminó, saltar
		if player.finished:
			attempts += 1
			continue
		
		# Si tiene turnos pendientes por perder
		if player.skips_remaining > 0:
			player.skips_remaining -= 1
			attempts += 1
			continue
		
		# Este jugador puede jugar
		return
	
	# Si todos terminaron o no pueden jugar, fin del juego
	_end_game()

func skip_turn(player_index: int, turns: int = 1):
	if player_index >= 0 and player_index < players.size():
		players[player_index].skips_remaining += turns

# =========================================================
#              MOVIMIENTO Y PUNTAJE
# =========================================================

# Jugador entra a un estado (pasa del mapa al sub-tablero)
func enter_state(player_index: int, state_index: int):
	if player_index < 0 or player_index >= players.size():
		return
	
	players[player_index].state_index = state_index
	players[player_index].is_inside_state = true
	players[player_index].pueblo_index = 0
	game_state = GameState.PLAYING_OCA

# Jugador avanza dentro del sub-tablero oca
func advance_pueblo(player_index: int, steps: int) -> int:
	if player_index < 0 or player_index >= players.size():
		return 0
	
	players[player_index].pueblo_index += steps
	return players[player_index].pueblo_index

# Registrar un pueblo mágico visitado
func score_pueblo(player_index: int, pueblo_id: String):
	if player_index < 0 or player_index >= players.size():
		return
	
	var player = players[player_index]
	
	# Evitar duplicados
	if pueblo_id in player.pueblos_visited:
		return
	
	player.pueblos_visited.append(pueblo_id)
	player.pueblos_scored += 1
	
	# Verificar si alcanzó el pueblo 177
	if player.pueblos_scored >= TOTAL_PUEBLOS:
		player.finished = true
		player.is_winner = true
		_end_game()

# Jugador sale del estado (completó el sub-tablero oca)
func exit_state(player_index: int):
	if player_index < 0 or player_index >= players.size():
		return
	
	players[player_index].is_inside_state = false
	players[player_index].pueblo_index = 0
	game_state = GameState.PLAYING_MAP

# =========================================================
#              FIN DE PARTIDA
# =========================================================

func _end_game():
	game_state = GameState.GAME_OVER
	
	var winner = _get_winner()
	game_ended.emit(winner)

func _get_winner() -> Dictionary:
	# El ganador es quien tiene is_winner = true
	for player in players:
		if player.is_winner:
			return player
	
	# Si no hay ganador explícito, el de mayor puntaje
	var best = players[0]
	for player in players:
		if player.pueblos_scored > best.pueblos_scored:
			best = player
	return best

# =========================================================
#              CONSULTAS
# =========================================================

func get_player_count() -> int:
	return players.size()

func get_player_by_index(index: int) -> Dictionary:
	if index >= 0 and index < players.size():
		return players[index]
	return {}

func get_player_by_network_id(network_id: String) -> Dictionary:
	for player in players:
		if player.network_id == network_id:
			return player
	return {}

func get_scores() -> Array[Dictionary]:
	var scores: Array[Dictionary] = []
	for player in players:
		scores.append({
			"name": player.name,
			"score": player.pueblos_scored,
			"finished": player.finished,
			"is_winner": player.is_winner,
		})
	# Ordenar de mayor a menor
	scores.sort_custom(func(a, b): return a.score > b.score)
	return scores

func is_game_over() -> bool:
	return game_state == GameState.GAME_OVER

func is_online() -> bool:
	return game_mode == GameMode.ONLINE_MULTI

func is_local_multi() -> bool:
	return game_mode == GameMode.LOCAL_MULTI

func is_single_player() -> bool:
	return game_mode == GameMode.SINGLE

# =========================================================
#              RESET
# =========================================================

func reset():
	game_mode = GameMode.NONE
	game_state = GameState.MENU
	players.clear()
	current_turn_index = 0
	turn_number = 0
	current_state_route_index = 0
	match_id = ""
	match_code = ""
	match_name = ""
	is_host = false
