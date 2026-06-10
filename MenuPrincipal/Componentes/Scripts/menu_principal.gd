extends Control

const SCENES := {
	"un_jugador": "res://MenuPrincipal/Componentes/Escenas/UnJugadorModo.tscn",
	"multijugador": "res://MenuPrincipal/Componentes/Escenas/MultijugadorModo.tscn",
	"perfil": "res://MenuPrincipal/Componentes/Escenas/Perfil.tscn",
	"estadisticas": "res://MenuPrincipal/Componentes/Escenas/Estadisticas.tscn",
}

@onready var btn_salir: Button = $VBoxContainer/MarginContainer/VBoxContainer/ButtonSalir

func _ready() -> void:
	btn_salir.pressed.connect(_on_btn_salir_pressed)

func _on_btn_un_jugador_pressed() -> void:
	_change_scene(SCENES.un_jugador)

func _on_btn_multijugador_pressed() -> void:
	_change_scene(SCENES.multijugador)

func _on_btn_perfil_pressed() -> void:
	_change_scene(SCENES.perfil)

func _on_btn_ranking_pressed() -> void:
	_change_scene(SCENES.estadisticas)

func _on_btn_salir_pressed() -> void:
	get_tree().quit()

func _change_scene(scene_path: String) -> void:
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_warning("Escena no disponible: %s" % scene_path)
		return
	get_tree().change_scene_to_file(scene_path)
