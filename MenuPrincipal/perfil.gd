extends Control

# =========================================================
#   Pantalla de Perfil de usuario.
#   Solo estructura/esqueleto: el llenado real de datos
#   (nombre, email, estado, estadísticas) se conectará a
#   AdministradorOnline / backend en una iteración futura.
# =========================================================

const MAIN_MENU := "res://MenuPrincipal/MenuPrincipal.tscn"

# --- Tarjeta de usuario ---
@onready var lbl_iniciales: Label = $MarginContainer/Contenido/TarjetaUsuario/HBox/AvatarCirculo/LblIniciales
@onready var lbl_nombre: Label = $MarginContainer/Contenido/TarjetaUsuario/HBox/DatosUsuario/LblNombre
@onready var lbl_email: Label = $MarginContainer/Contenido/TarjetaUsuario/HBox/DatosUsuario/LblEmail

# --- Tarjeta de estado actual ---
@onready var lbl_estado: Label = $MarginContainer/Contenido/TarjetaEstado/VBox/LblEstado

# --- Estadísticas ---
@onready var lbl_pueblos_visitados: Label = $MarginContainer/Contenido/Estadisticas/TarjetaVisitados/VBox/LblValor
@onready var lbl_pueblos_descubiertos: Label = $MarginContainer/Contenido/Estadisticas/TarjetaDescubiertos/VBox/LblValor
@onready var lbl_partidas_jugadas: Label = $MarginContainer/Contenido/Estadisticas/TarjetaJugadas/VBox/LblValor
@onready var lbl_partidas_ganadas: Label = $MarginContainer/Contenido/Estadisticas/TarjetaGanadas/VBox/LblValor

# --- Navegación ---
@onready var btn_menu: Button = $MarginContainer/Contenido/BtnMenuPrincipal

func _ready() -> void:
	btn_menu.pressed.connect(_on_menu_pressed)
	_cargar_perfil()

# Rellena la pantalla con los datos del jugador.
# TODO: reemplazar por la carga real desde el backend / datos locales.
func _cargar_perfil() -> void:
	var nombre := AdministradorOnline.local_player_name
	lbl_nombre.text = nombre
	lbl_iniciales.text = _iniciales(nombre)
	# lbl_email.text = ...
	# lbl_estado.text = ...
	# lbl_pueblos_visitados.text = str(...)
	# lbl_pueblos_descubiertos.text = str(...)
	# lbl_partidas_jugadas.text = str(...)
	# lbl_partidas_ganadas.text = str(...)

# Devuelve hasta 2 iniciales a partir del nombre.
func _iniciales(nombre: String) -> String:
	var limpio := nombre.strip_edges()
	if limpio.is_empty():
		return "?"
	var partes := limpio.split(" ", false)
	if partes.size() >= 2:
		return (partes[0].substr(0, 1) + partes[1].substr(0, 1)).to_upper()
	return limpio.substr(0, 2).to_upper()

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
