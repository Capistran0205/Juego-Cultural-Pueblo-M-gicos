extends Control

const MAIN_MENU := "res://MenuPrincipal/MenuPrincipal.tscn"
const GAME_BOARD := "res://Juego/TableroJuego/Tablero.tscn"

const PLAYER_ENTRY := preload("res://MenuPrincipal/Componentes/Escenas/PlayerEntry.tscn")
const SALA_ENTRY := preload("res://MenuPrincipal/Componentes/Escenas/SalaEntry.tscn")

# Nombres de las pestañas tal como están en la escena.
const TAB_LOCAL_NAME := "Partida Local"
const TAB_ONLINE_NAME := "Partida en Linea"

@onready var tabs: TabContainer = $VBoxContainer/TabContainer
@onready var tab_local: VBoxContainer = tabs.get_node(TAB_LOCAL_NAME)
@onready var tab_online: VBoxContainer = tabs.get_node(TAB_ONLINE_NAME)

# === NODOS: Tab Local ===
@onready var slider_jugadores: HSlider = tab_local.get_node("PanelContainer/VBoxContainer/SliderJugadores")
@onready var lbl_num_jugadores: Label = tab_local.get_node("PanelContainer/VBoxContainer/LblNumJugadores")
@onready var vbox_player_list: VBoxContainer = tab_local.get_node("PanelContainer/VBoxContainer/ScrollContainer/VBoxPlayerList")
@onready var btn_comenzar_local: Button = $HBoxContainer/BtnComenzarLocal
@onready var btn_atras_local: Button = $HBoxContainer/BtnAtrasLocal

# === NODOS: Tab Online ===
@onready var input_nombre_sala: LineEdit = tab_online.get_node("PanelCrearSala/VBoxContainer/HBoxNombre/InputNombreSala")
@onready var spin_max_players: SpinBox = tab_online.get_node("PanelCrearSala/VBoxContainer/HBoxMaxPlayers/SpinMaxPlayers")
@onready var btn_crear_sala: Button = tab_online.get_node("PanelCrearSala/VBoxContainer/BtnCrearSala")
@onready var input_codigo: LineEdit = tab_online.get_node("PanelUnirse/VBoxContainer/HBoxBuscar/InputCodigo")
@onready var btn_buscar: Button = tab_online.get_node("PanelUnirse/VBoxContainer/HBoxBuscar/BtnBuscar")
@onready var vbox_salas_list: VBoxContainer = tab_online.get_node("PanelUnirse/VBoxContainer/ScrollContainer/VBoxSalasList")
@onready var btn_atras_online: Button = tab_online.get_node("BtnAtrasOnline")

# === NODOS: Waiting Room ===
@onready var waiting_room_layer: CanvasLayer = $WaitingRoomLayer
@onready var lbl_sala_info: Label = $WaitingRoomLayer/WaitingRoom/VBoxContainer/LblSalaInfo
@onready var lbl_esperando: Label = $WaitingRoomLayer/WaitingRoom/VBoxContainer/LblEsperando
@onready var vbox_player_slots: VBoxContainer = $WaitingRoomLayer/WaitingRoom/VBoxContainer/ScrollContainer/VBoxPlayerSlots
@onready var btn_iniciar_partida: Button = $WaitingRoomLayer/WaitingRoom/VBoxContainer/BtnIniciarPartida
@onready var btn_salir_sala: Button = $WaitingRoomLayer/WaitingRoom/VBoxContainer/BtnSalirSala

# Conexiones a señales del AdministradorOnline (para poder desconectarlas).
var _online_signals_connected: bool = false

# =========================================================
#                     INICIALIZACIÓN
# =========================================================

func _ready() -> void:
	# Títulos legibles para las pestañas (independiente del nombre del nodo).
	tabs.set_tab_title(tabs.get_tab_idx_from_control(tab_local), "Partida Local")
	tabs.set_tab_title(tabs.get_tab_idx_from_control(tab_online), "Partida Online")
	tabs.current_tab = tabs.get_tab_idx_from_control(tab_local)

	# Conexiones Tab Local.
	slider_jugadores.value_changed.connect(_on_slider_changed)
	btn_comenzar_local.pressed.connect(_on_comenzar_local)
	btn_atras_local.pressed.connect(_on_atras)

	# Conexiones Tab Online.
	btn_crear_sala.pressed.connect(_on_crear_sala)
	btn_buscar.pressed.connect(_on_buscar_sala)
	btn_atras_online.pressed.connect(_on_atras)

	# Conexiones Waiting Room.
	btn_iniciar_partida.pressed.connect(_on_iniciar_online)
	btn_salir_sala.pressed.connect(_on_salir_sala)

	# Estado inicial.
	waiting_room_layer.visible = false
	_generar_player_entries(int(slider_jugadores.value))

# =========================================================
#               LÓGICA: PARTIDA LOCAL
# =========================================================

func _on_slider_changed(value: float) -> void:
	var num := int(value)
	lbl_num_jugadores.text = "%d Jugadores" % num
	_generar_player_entries(num)

func _generar_player_entries(cantidad: int) -> void:
	for child in vbox_player_list.get_children():
		child.queue_free()

	# Los hijos no se eliminan hasta el siguiente frame; durante este loop
	# usamos sólo los que estamos creando para validar duplicados.
	var nuevos: Array[PlayerEntry] = []

	for i in range(cantidad):
		var entry: PlayerEntry = PLAYER_ENTRY.instantiate()
		vbox_player_list.add_child(entry)

		var requester_index := i + 1
		entry.set_taken_check(
			func(cid: int) -> bool:
				return _avatar_tomado_por_otro(cid, requester_index, nuevos)
		)

		var inicial := _primer_avatar_libre(i, nuevos)
		entry.setup(
			requester_index,
			"Jugador %d" % requester_index,
			InformacionJuego.TOKEN_COLORS[i],
			inicial,
		)
		nuevos.append(entry)

# True si algún OTRO entry de la lista ya tomó el avatar `candidate_id`.
func _avatar_tomado_por_otro(candidate_id: int, requester_index: int, entries: Array[PlayerEntry]) -> bool:
	for e in entries:
		if e.player_index == requester_index:
			continue
		if e.avatar_id == candidate_id:
			return true
	return false

# Devuelve el primer avatar libre, prefiriendo `preferred_id`.
func _primer_avatar_libre(preferred_id: int, entries: Array[PlayerEntry]) -> int:
	var total := PlayerEntry.AVATAR_PATHS.size()
	if not _avatar_tomado_por_otro(preferred_id, -1, entries):
		return preferred_id
	for c in range(total):
		if not _avatar_tomado_por_otro(c, -1, entries):
			return c
	return preferred_id

func _on_comenzar_local() -> void:
	var players_data: Array[Dictionary] = []

	for entry in vbox_player_list.get_children():
		var data: Dictionary = entry.get_player_data()
		if String(data.get("name", "")).strip_edges().is_empty():
			data["name"] = "Jugador %d" % (players_data.size() + 1)
		players_data.append(data)

	InformacionJuego.setup_local_multiplayer(players_data)
	get_tree().change_scene_to_file(GAME_BOARD)

# =========================================================
#               LÓGICA: PARTIDA ONLINE
# =========================================================

func _on_crear_sala() -> void:
	var sala_name := input_nombre_sala.text.strip_edges()
	var max_players := int(spin_max_players.value)

	if sala_name.is_empty():
		var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
		var nombre_local := AdministradorOnline.local_player_name
		sala_name = "%s_%s" % [nombre_local, timestamp]

	var match_code: String = await AdministradorOnline.create_room(sala_name, max_players)

	if match_code != "":
		_mostrar_waiting_room(sala_name, match_code, true)

func _on_buscar_sala() -> void:
	var query := input_codigo.text.strip_edges()
	if query.is_empty():
		return

	var salas: Array = await AdministradorOnline.search_rooms(query)
	_mostrar_resultados_salas(salas)

func _mostrar_resultados_salas(salas: Array) -> void:
	for child in vbox_salas_list.get_children():
		child.queue_free()

	for sala in salas:
		var entry := SALA_ENTRY.instantiate()
		vbox_salas_list.add_child(entry)
		entry.setup(sala)
		entry.join_requested.connect(_on_unirse_sala)

func _on_unirse_sala(match_id: String) -> void:
	var success: bool = await AdministradorOnline.join_room(match_id)
	if success:
		var room_info: Dictionary = AdministradorOnline.current_room
		_mostrar_waiting_room(
			room_info.get("name", ""),
			room_info.get("code", ""),
			false,
		)

# =========================================================
#               LÓGICA: WAITING ROOM
# =========================================================

func _mostrar_waiting_room(nombre: String, codigo: String, es_host: bool) -> void:
	waiting_room_layer.visible = true
	lbl_sala_info.text = "Sala: %s | Código: %s" % [nombre, codigo]
	btn_iniciar_partida.visible = es_host

	if not _online_signals_connected:
		AdministradorOnline.player_joined.connect(_on_player_joined)
		AdministradorOnline.player_left.connect(_on_player_left)
		_online_signals_connected = true

	_actualizar_player_slots()

func _ocultar_waiting_room() -> void:
	waiting_room_layer.visible = false
	if _online_signals_connected:
		AdministradorOnline.player_joined.disconnect(_on_player_joined)
		AdministradorOnline.player_left.disconnect(_on_player_left)
		_online_signals_connected = false

func _on_player_joined(_player_info: Dictionary) -> void:
	lbl_esperando.text = "Jugadores: %d/%d" % [
		AdministradorOnline.current_player_count(),
		AdministradorOnline.max_players,
	]
	_actualizar_player_slots()

func _on_player_left(_player_id: String) -> void:
	_actualizar_player_slots()

func _actualizar_player_slots() -> void:
	for child in vbox_player_slots.get_children():
		child.queue_free()

	for player in AdministradorOnline.get_players():
		var slot := Label.new()
		slot.text = "● %s" % player.get("name", "Jugador")
		vbox_player_slots.add_child(slot)

func _on_iniciar_online() -> void:
	if AdministradorOnline.current_player_count() < InformacionJuego.MIN_PLAYERS_MULTI:
		return

	AdministradorOnline.start_match()

	var room_info: Dictionary = AdministradorOnline.current_room
	InformacionJuego.setup_online_multiplayer(
		AdministradorOnline.get_players(),
		room_info.get("match_id", ""),
		room_info.get("code", ""),
		room_info.get("name", ""),
		AdministradorOnline.is_host,
	)
	get_tree().change_scene_to_file(GAME_BOARD)

func _on_salir_sala() -> void:
	AdministradorOnline.leave_room()
	_ocultar_waiting_room()

# =========================================================
#                     NAVEGACIÓN
# =========================================================

func _on_atras() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
