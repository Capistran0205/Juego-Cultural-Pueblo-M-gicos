extends Node
# FACHADA TEMPORAL. La fuente de verdad es InformacionJuego.
# Solo conserva estado local para las funciones vestigiales pendientes de borrar.

# --- Estado vestigial (prototipo; nadie del juego real debería usarlo) ---
var current_player_position: int = 1
var player_stats: Dictionary = {"money": 0, "items": [], "visited_locations": []}
var _num_players_hint: int = 1   # respaldo para la UI de menú antes de construir players

# --- CONFIG: delegada con TRADUCCIÓN de enums ---
var game_mode: int:
	get:
		match InformacionJuego.game_mode:
			InformacionJuego.GameMode.SINGLE: return 0
			InformacionJuego.GameMode.LOCAL_MULTI, InformacionJuego.GameMode.ONLINE_MULTI: return 1
			_: return 0   # NONE → "un jugador" en el esquema viejo
	set(value):
		InformacionJuego.game_mode = (InformacionJuego.GameMode.SINGLE if value == 0
			else InformacionJuego.GameMode.LOCAL_MULTI)

var num_players: int:
	get:
		return InformacionJuego.players.size() if not InformacionJuego.players.is_empty() else _num_players_hint
	set(value):
		_num_players_hint = value   # al construir players, size() manda

# --- TRANSITORIO/LOG: delegado a InformacionJuego ---
var dice_result: int:
	get: return InformacionJuego.dice_result
	set(value): InformacionJuego.dice_result = value

var current_turn: int:
	get: return InformacionJuego.turn_number
	set(value): InformacionJuego.turn_number = value

var game_history: Array:
	get: return InformacionJuego.game_history

func log_event(event_description: String) -> void:
	InformacionJuego.log_event(event_description)

# --- RESET: comportamiento ESTRECHO original. NO llama a reset() (borraría players) ---
func reset_game() -> void:
	InformacionJuego.dice_result = 0
	InformacionJuego.turn_number = 1
	current_player_position = 1
	print("Juego reiniciado")

func reset_config() -> void:
	InformacionJuego.game_mode = InformacionJuego.GameMode.SINGLE
	_num_players_hint = 1
	print("Configuración reseteada a modo un jugador")

# --- VESTIGIAL: intacto. Borrar cuando confirmes que nadie lo llama ---
func add_visited_location(location_id: int) -> void:
	if not location_id in player_stats.visited_locations:
		player_stats.visited_locations.append(location_id)

func print_game_state() -> void:
	print("Turno: %d | Dado: %d" % [current_turn, dice_result])

func print_config() -> void:
	print("Modo: %s | Jugadores: %d" % [("MULTI" if game_mode == 1 else "UNO"), num_players])
