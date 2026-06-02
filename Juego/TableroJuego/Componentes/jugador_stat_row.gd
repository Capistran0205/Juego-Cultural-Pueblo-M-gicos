extends PanelContainer

# =========================================================
#   Fila de la tabla de estadísticas del HUD.
#   Muestra avatar pequeño, nombre, casilla actual y color.
#   Se actualizará cuando el jugador se mueva (futuro).
# =========================================================

@onready var color_rect: ColorRect = $HBox/ColorJugador
@onready var avatar: TextureRect = $HBox/Avatar
@onready var lbl_nombre: Label = $HBox/Info/LblNombre
@onready var lbl_casilla: Label = $HBox/Info/LblCasilla

var player_index: int = 0

# Inicializa la fila a partir del diccionario de jugador
# (mismo formato que InformacionJuego._create_player).
func setup(player_data: Dictionary, avatar_texture: Texture2D) -> void:
	visible = true
	player_index = player_data.get("index", 0)
	lbl_nombre.text = player_data.get("name", "Jugador")
	color_rect.color = player_data.get("color", Color.WHITE)
	if avatar_texture != null:
		avatar.texture = avatar_texture
	_actualizar_casilla(player_data)

# Refresca la fila con los datos actuales del jugador.
# Se llama desde el HUD cuando el turno avanza o el jugador se mueve.
func actualizar(player_data: Dictionary) -> void:
	_actualizar_casilla(player_data)

func _actualizar_casilla(player_data: Dictionary) -> void:
	var dentro: bool = player_data.get("is_inside_state", false)
	if dentro:
		lbl_casilla.text = "Estado %d · Pueblo %d" % [
			player_data.get("state_index", 0),
			player_data.get("pueblo_index", 0),
		]
	else:
		var idx: int = player_data.get("state_index", 0)
		lbl_casilla.text = "Inicio" if idx == 0 else "Estado %d" % idx
