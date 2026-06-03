extends Node

# ============================================
# CONFIGURACIÓN DEL MODO DE JUEGO (NUEVO)
# ============================================
var game_mode: int = 0  # 0 = Single Player, 1 = Multiplayer
var num_players: int = 1  # Cantidad de jugadores (1-6)

# ============================================
# DATOS DEL JUEGO ACTUAL (TU CÓDIGO ORIGINAL)
# ============================================
# Resultado del dado actual
var dice_result: int = 0

# Posición actual del jugador
var current_player_position: int = 1

# Turno actual
var current_turn: int = 1

# Estadísticas del jugador
var player_stats: Dictionary = {
	"money": 0,
	"items": [],
	"visited_locations": []
}

# Historia del juego
var game_history: Array = []

# ============================================
# FUNCIONES ORIGINALES (SIN CAMBIOS)
# ============================================
# Función para reiniciar el juego
func reset_game() -> void:
	dice_result = 0
	current_player_position = 1
	current_turn = 1
	print("Juego reiniciado")

# Registrar un evento en la historia
func log_event(event_description: String) -> void:
	var event: Dictionary = {
		"turn": current_turn,
		"position": current_player_position,
		"description": event_description,
		"timestamp": Time.get_ticks_msec()
	}
	game_history.append(event)
	print("Evento registrado: %s" % event_description)

# Agregar una ubicación visitada
func add_visited_location(location_id: int) -> void:
	if not location_id in player_stats.visited_locations:
		player_stats.visited_locations.append(location_id)

# Función de utilidad para debug
func print_game_state() -> void:
	print("=== Estado del Juego ===")
	print("Turno: %d" % current_turn)
	print("Posición: %d" % current_player_position)
	print("Último dado: %d" % dice_result)
	print("Dinero: %d" % player_stats.money)
	print("Items: %s" % str(player_stats.items))
	print("Ubicaciones visitadas: %d" % player_stats.visited_locations.size())
	print("======================")

# ============================================
# NUEVAS FUNCIONES PARA MULTIJUGADOR
# ============================================
# Resetear solo la configuración del modo de juego
func reset_config() -> void:
	"""Reinicia la configuración a modo single player"""
	game_mode = 0
	num_players = 1
	print("Configuración reseteada a modo un jugador")

# Función de debug para ver la configuración actual
func print_config() -> void:
	print("=== Configuración de Juego ===")
	print("Modo: %s" % ("MULTIJUGADOR" if game_mode == 1 else "UN JUGADOR"))
	print("Jugadores: %d" % num_players)
	print("=============================")
