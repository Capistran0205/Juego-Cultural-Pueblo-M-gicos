extends Area2D

# =========================================================
#   Marcador de un estado de México sobre el mapa.
#   La posición, forma y datos se setean desde fuera
#   (futuro: AdministradorMapa / Firebase).
# =========================================================

signal estado_seleccionado(estado_id: String)

@onready var forma: CollisionShape2D = $Forma
@onready var etiqueta: Label = $Etiqueta

var estado_id: String = ""
var estado_nombre: String = ""
var pueblos_count: int = 0

func _ready() -> void:
	input_event.connect(_on_input_event)

# Setea el estado desde un diccionario (vendrá de Firebase).
# Estructura esperada:
#   {
#     "id": "hidalgo",
#     "nombre": "Hidalgo",
#     "posicion": Vector2,
#     "forma": Shape2D,           # CircleShape2D | RectangleShape2D | ConvexPolygonShape2D
#     "pueblos_count": int,
#   }
func setup(data: Dictionary) -> void:
	estado_id = data.get("id", "")
	estado_nombre = data.get("nombre", "")
	pueblos_count = data.get("pueblos_count", 0)

	position = data.get("posicion", Vector2.ZERO)

	var shape: Shape2D = data.get("forma")
	if shape != null:
		forma.shape = shape

	etiqueta.text = estado_nombre

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		estado_seleccionado.emit(estado_id)
