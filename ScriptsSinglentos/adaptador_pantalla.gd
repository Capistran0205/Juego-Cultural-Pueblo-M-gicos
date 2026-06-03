# AdaptadorPantalla.gd — Autoload (singleton)
extends Node

signal screen_adapted

var base_resolution := Vector2(1080, 1920)
var current_resolution: Vector2
var scale_factor: float
var is_tall_screen: bool  # pantallas más largas que 16:9

func _ready():
	get_tree().root.size_changed.connect(_on_resize)
	_adapt()

func _adapt():
	current_resolution = get_viewport().get_visible_rect().size
	scale_factor = current_resolution.x / base_resolution.x
	
	var current_ratio = current_resolution.y / current_resolution.x
	var base_ratio = base_resolution.y / base_resolution.x
	is_tall_screen = current_ratio > base_ratio + 0.1
	
	print("Resolución: ", current_resolution)
	print("Factor de escala: ", scale_factor)
	print("Pantalla alta: ", is_tall_screen)
	
	screen_adapted.emit()

func _on_resize():
	_adapt()

# Utilidades para que otros nodos adapten sus tamaños
func get_safe_area() -> Rect2:
	return DisplayServer.get_display_safe_area()

func scale_value(value: float) -> float:
	return value * scale_factor

func get_extra_vertical_space() -> float:
	# Espacio extra en pantallas más altas que 16:9
	var current_ratio = current_resolution.y / current_resolution.x
	var base_ratio = base_resolution.y / base_resolution.x
	return max(0, (current_ratio - base_ratio) * current_resolution.x)
