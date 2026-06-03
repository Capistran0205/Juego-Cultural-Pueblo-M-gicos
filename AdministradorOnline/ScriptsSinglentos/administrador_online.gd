extends Node

# =========================================================
#   STUB de red (sin backend real todavía).
#   La intención es que MultijugadorModo y el resto del juego
#   hablen siempre contra esta API. Cuando se elija el backend
#   (Nakama, ENet, WebSocket propio, etc.) se reemplaza la
#   implementación interna sin tocar a los consumidores.
# =========================================================

# === Señales ===
signal room_created(room_info: Dictionary)
signal room_joined(room_info: Dictionary)
signal room_left
signal player_joined(player_info: Dictionary)
signal player_left(player_id: String)
signal match_started

# === Estado de la sala actual ===
var current_room: Dictionary = {}
var max_players: int = 0
var is_host: bool = false

# Lista local de jugadores en la sala (solo para el stub).
var _players: Array[Dictionary] = []

# Identidad del jugador local (rellénala desde la pantalla de Perfil).
var local_player_id: String = ""
var local_player_name: String = "Jugador"

# =========================================================
#                 API PÚBLICA
# =========================================================

func create_room(room_name: String, room_max_players: int) -> String:
	# TODO: reemplazar por la creación real de la sala en el backend.
	var code := _generar_codigo()
	current_room = {
		"match_id": code,
		"code": code,
		"name": room_name,
		"max_players": room_max_players,
		"status": "waiting",
	}
	max_players = room_max_players
	is_host = true
	_players.clear()
	_agregar_jugador_local()
	room_created.emit(current_room)
	return code

func search_rooms(query: String) -> Array:
	# TODO: reemplazar por la búsqueda real.
	# Devuelve datos de prueba para iterar UI.
	await get_tree().create_timer(0.2).timeout
	var demo: Array = []
	if query.strip_edges().is_empty():
		return demo
	for i in range(3):
		demo.append({
			"match_id": "DEMO%02d" % i,
			"name": "%s #%d" % [query, i + 1],
			"current_players": 1 + i,
			"max_players": 6,
			"status": "waiting",
		})
	return demo

func join_room(match_id: String) -> bool:
	# TODO: reemplazar por unión real al backend.
	current_room = {
		"match_id": match_id,
		"code": match_id,
		"name": match_id,
		"max_players": 6,
		"status": "waiting",
	}
	max_players = 6
	is_host = false
	_players.clear()
	_agregar_jugador_local()
	room_joined.emit(current_room)
	return true

func leave_room() -> void:
	current_room = {}
	max_players = 0
	is_host = false
	_players.clear()
	room_left.emit()

func start_match() -> void:
	if current_room.is_empty():
		return
	current_room["status"] = "in_progress"
	match_started.emit()

func get_players() -> Array[Dictionary]:
	return _players

func current_player_count() -> int:
	return _players.size()

# =========================================================
#                 INTERNO (stub)
# =========================================================

func _agregar_jugador_local() -> void:
	var info := {
		"network_id": local_player_id,
		"name": local_player_name,
		"is_local": true,
	}
	_players.append(info)
	player_joined.emit(info)

func _generar_codigo() -> String:
	var chars := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code := ""
	for i in range(6):
		code += chars[randi() % chars.length()]
	return code
