extends Control

const MAIN_MENU := "res://MenuPrincipal/Componentes/Escenas/MenuPrincipal.tscn"
const GAME_BOARD := "res://Juego/TableroJuego/Tablero.tscn"
const AVATARS_DIR := "res://Assets/Jugadores/"

@onready var input_nombre: Label = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/lblNombreActual
@onready var avatar_rect: TextureRect = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer2/HBoxContainer/Avatar
@onready var btn_avatar_prev: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer2/HBoxContainer/BtnAvatarPrev
@onready var btn_avatar_next: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer2/HBoxContainer/BtnAvatarSig

var avatar_index: int = 0
var avatars: Array[Texture2D] = []

func _ready() -> void:
	_cargar_avatars()

func _on_btn_comenzar_pressed() -> void:
	InformacionJuego.setup_single_player({
		"name": input_nombre.text.strip_edges(),
		"avatar_id": avatar_index,
	})
	get_tree().change_scene_to_file(GAME_BOARD)

func _on_btn_atras_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)

func _on_btn_avatar_prev_pressed() -> void:
	if avatars.is_empty():
		return
	avatar_index = wrapi(avatar_index - 1, 0, avatars.size())
	avatar_rect.texture = avatars[avatar_index]

func _on_btn_avatar_sig_pressed() -> void:
	if avatars.is_empty():
		return
	avatar_index = wrapi(avatar_index + 1, 0, avatars.size())
	avatar_rect.texture = avatars[avatar_index]

func _cargar_avatars() -> void:
	var dir := DirAccess.open(AVATARS_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png"):
			var tex: Texture2D = load(AVATARS_DIR + file_name)
			if tex != null:
				avatars.append(tex)
		file_name = dir.get_next()
	dir.list_dir_end()

	if not avatars.is_empty():
		avatar_index = 0
		avatar_rect.texture = avatars[0]
