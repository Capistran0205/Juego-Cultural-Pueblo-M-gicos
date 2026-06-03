extends Node2D

# El flujo de la partida (turnos, dado, preguntas, movimiento, colores y HUD)
# lo controla por completo GameManager (Mapa/GameManager). Antes este script
# corría un mini-loop propio (mover la ficha con la barra espaciadora y armar
# la tabla del HUD), lo que chocaba con GameManager. Aquí solo dejamos la
# navegación de "Regresar al menú".

const MAIN_MENU := "res://MenuPrincipal/MenuPrincipal.tscn"

@onready var btn_regresar: Button = $HUD/HUDRoot/BtnRegresar

func _ready() -> void:
	if btn_regresar:
		btn_regresar.pressed.connect(_on_regresar_pressed)

func _on_regresar_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
