@tool
extends Polygon2D

# Bloque de constantes de color según los lineamientos de diseño
const COLOR_OCULTO = Color(1, 1, 1, 0) # Totalmente transparente al inicio
# Relleno visible SOLO dentro del editor, para poder alinear cada casilla sobre el mapa
const COLOR_EDITOR = Color(1, 0.43, 0.2, 0.45)

func _ready() -> void:
	# En el editor mostramos un relleno semitransparente para ver y ajustar las áreas;
	# en el juego real las casillas inician invisibles (se encienden con iluminar()).
	if Engine.is_editor_hint():
		color = COLOR_EDITOR
		return
	# El polígono se vuelve invisible pero sigue activo en el tablero
	color = COLOR_OCULTO

# Función para encender la iluminación con opacidad reducida cuando el jugador se sitúe encima
func iluminar(color_jugador: Color) -> void:
	# Mantiene el matiz del jugador pero aplicando transparencia para dejar ver el fondo
	color = Color(color_jugador.r, color_jugador.g, color_jugador.b, 0.90) 

# Función para apagar la iluminación al salir de la casilla
func apagar() -> void:
	color = COLOR_OCULTO 

# Requerimiento: Extraer el centro exacto (global_position) del CollisionShape2D
func obtener_centro_casilla() -> Vector2:
	for hijo in get_children():
		if hijo is Area2D: 
			for nieto in hijo.get_children():
				if nieto is CollisionShape2D: 
					return nieto.global_position 
	return global_position
