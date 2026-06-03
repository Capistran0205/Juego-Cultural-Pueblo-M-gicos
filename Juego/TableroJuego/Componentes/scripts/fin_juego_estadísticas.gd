extends Control

# ============================================
# REFERENCIAS A NODOS
# ============================================
@onready var winner_icon = $PanelContainer/MarginContainer/VBoxContainer/GanadorContenedor/GanadorIcono
@onready var winner_label = $PanelContainer/MarginContainer/VBoxContainer/GanadorContenedor/GanadorLabel
@onready var players_stats_container = $PanelContainer/MarginContainer/VBoxContainer/ContenedorJugadores
@onready var restart_button = $PanelContainer/MarginContainer/VBoxContainer/ContenedorBotones/ReinicioJuegoBoton
@onready var menu_button = $PanelContainer/MarginContainer/VBoxContainer/ContenedorBotones/MenuBoton

# ============================================
# SEÑALES
# ============================================
signal restart_game_requested
signal return_to_menu_requested

# ============================================
# FUNCIONES PRINCIPALES
# ============================================
func _ready():
	# Ocultar la pantalla al inicio
	visible = false
	
	# Conectar señales de botones (si no se conectaron en el editor)
	if not restart_button.pressed.is_connected(_on_reinicio_juego_boton_pressed):
		restart_button.pressed.connect(_on_reinicio_juego_boton_pressed)
	
	if not menu_button.pressed.is_connected(_on_menu_boton_pressed):
		menu_button.pressed.connect(_on_menu_boton_pressed)

func show_stats(players_data: Dictionary, winner_id: String, game_mode = null):
	"""
	Muestra las estadísticas del juego
	- players_data: diccionario con todos los jugadores
	- winner_id: ID del jugador ganador (ej: "player1")
	- game_mode: GameMode enum (opcional, para adaptar el mensaje)
	"""
	# Limpiar estadísticas anteriores
	_clear_previous_stats()
	
	# Configurar información del ganador
	_setup_winner_display(players_data, winner_id, game_mode)
	
	# Crear clasificación de jugadores
	_create_players_ranking(players_data, game_mode)
	
	# Mostrar la pantalla con animación
	_show_with_animation()

# ============================================
# CONFIGURACIÓN DEL GANADOR
# ============================================
func _setup_winner_display(players_data: Dictionary, winner_id: String, game_mode = null):
	"""Configura la visualización del ganador"""
	if not players_data.has(winner_id):
		print("⚠️ Error: No se encontró el ganador con ID '%s'" % winner_id)
		return
	
	var winner = players_data[winner_id]
	
	# Actualizar color del icono
	winner_icon.color = winner["color"]
	
	# Personalizar mensaje según el modo
	if game_mode == 0:  # SINGLE_PLAYER (asumiendo que game_mode es int)
		winner_label.text = "¡Has completado el juego! 🎉"
	else:  # MULTIPLAYER
		winner_label.text = "¡%s es el ganador! 🎉" % winner["name"]

# ============================================
# CLASIFICACIÓN DE JUGADORES
# ============================================
func _create_players_ranking(players_data: Dictionary, game_mode = null):
	"""Crea la lista de clasificación de jugadores"""
	
	# Para single player, mostrar solo estadísticas del jugador
	if game_mode == 0:  # SINGLE_PLAYER
		_create_single_player_stats(players_data)
	else:  # MULTIPLAYER
		_create_multiplayer_ranking(players_data)

func _create_single_player_stats(players_data: Dictionary):
	"""Muestra estadísticas para modo un jugador"""
	
	var player = players_data["player1"]
	
	# Contenedor principal
	var stats_container = VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 15)
	players_stats_container.add_child(stats_container)
	
	# Título de estadísticas
	var title = Label.new()
	title.text = "📊 Resumen de tu partida"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0, 0, 0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_container.add_child(title)
	
	# Separador
	var sep1 = HSeparator.new()
	stats_container.add_child(sep1)
	
	# Casilla Meta
	var location_row = _create_stat_row("🎯 Casilla Final:", "Casilla %d" % player["location_id"])
	stats_container.add_child(location_row)
	
	# Turnos jugados
	var turns_row = _create_stat_row("🔢 Turnos jugados:", "%d turnos" % player["turns_played"])
	stats_container.add_child(turns_row)
	
	# Mensaje de felicitación
	var sep2 = HSeparator.new()
	stats_container.add_child(sep2)
	
	var congrats = Label.new()
	congrats.text = "¡Excelente trabajo! 🌟"
	congrats.add_theme_font_size_override("font_size", 18)
	congrats.add_theme_color_override("font_color", Color(0, 0.5, 0))
	congrats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_container.add_child(congrats)
	
	# Animación de entrada
	stats_container.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(stats_container, "modulate:a", 1.0, 0.5).set_delay(0.2)
	
func _create_player_stat_row(player: Dictionary, player_position: int):
	"""Crea una fila de estadísticas para un jugador"""
	
	# Contenedor horizontal para la fila
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 15)
	
	# Medalla según posición
	var medal = _get_medal_for_position(player_position)
	var position_label = Label.new()
	position_label.text = "%s %d." % [medal, player_position]
	position_label.add_theme_font_size_override("font_size", 18)
	position_label.custom_minimum_size = Vector2(60, 0)
	row.add_child(position_label)
	
	# Icono de color del jugador
	var color_icon = ColorRect.new()
	color_icon.color = player["color"]
	color_icon.custom_minimum_size = Vector2(30, 30)
	row.add_child(color_icon)
	
	# Nombre del jugador
	var name_label = Label.new()
	name_label.text = player["name"]
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	
	# Posición final
	var location_label = Label.new()
	location_label.text = "Casilla %d" % player["location_id"]
	location_label.add_theme_font_size_override("font_size", 16)
	location_label.add_theme_color_override("font_color", Color(0, 0, 0))
	row.add_child(location_label)
	
	# Turnos jugados
	var turns_label = Label.new()
	turns_label.text = "%d turnos" % player["turns_played"]
	turns_label.add_theme_font_size_override("font_size", 16)
	turns_label.add_theme_color_override("font_color", Color(0, 0, 0))
	turns_label.custom_minimum_size = Vector2(100, 0)
	row.add_child(turns_label)
	
	# Agregar la fila al contenedor
	players_stats_container.add_child(row)
	
	# Animación de entrada con delay
	row.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(row, "modulate:a", 1.0, 0.3).set_delay(player_position * 0.1)

func _create_stat_row(label_text: String, value_text: String) -> HBoxContainer:
	"""Crea una fila de estadística con etiqueta y valor"""
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	
	# Etiqueta
	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0, 0, 0))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	
	# Valor
	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 18)
	value.add_theme_color_override("font_color", Color(0.2, 0.2, 0.8))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	
	return row

func _create_multiplayer_ranking(players_data: Dictionary):
	"""Crea la clasificación para modo multijugador"""
	
	# Ordenar jugadores por posición (de mayor a menor)
	var sorted_players = players_data.keys()
	sorted_players.sort_custom(func(a, b): 
		return players_data[a]["location_id"] > players_data[b]["location_id"]
	)
	
	# Crear entrada para cada jugador
	var player_position = 1
	for player_id in sorted_players:
		var player = players_data[player_id]
		_create_player_stat_row(player, player_position)
		player_position += 1

func _get_medal_for_position(player_position: int) -> String:
	"""Retorna el emoji de medalla según la posición"""
	match player_position:
		1: return "🥇"
		2: return "🥈"
		3: return "🥉"
		_: return "  "

# ============================================
# LIMPIEZA Y ANIMACIONES
# ============================================
func _clear_previous_stats():
	"""Limpia las estadísticas anteriores"""
	for child in players_stats_container.get_children():
		child.queue_free()

func _show_with_animation():
	"""Muestra la pantalla con animación de entrada"""
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Fade in
	tween.tween_property(self, "modulate:a", 1.0, 0.4)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Scale up
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_with_animation():
	"""Oculta la pantalla con animación"""
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Fade out
	tween.tween_property(self, "modulate:a", 0.0, 0.3)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	# Scale down
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.3)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	await tween.finished
	visible = false

# ============================================
# CALLBACKS DE BOTONES
# ============================================
func _on_reinicio_juego_boton_pressed() -> void:
	"""Reinicia el juego"""
	print("🔄 Reiniciando juego...")
	await hide_with_animation()
	restart_game_requested.emit()


func _on_menu_boton_pressed() -> void:
	"""Vuelve al menú principal"""
	print("🏠 Regresando al menú...")
	await hide_with_animation()
	return_to_menu_requested.emit()
