extends CanvasLayer
# Variables de referencia a los nodos
@onready var barra_progreso: ProgressBar = $CenterContainer/TextureRect/MarginContainer/VBoxContainer/ProgressBar
@onready var lbl_titulo: Label = $CenterContainer/TextureRect/MarginContainer/VBoxContainer/LabelTitulo
@onready var lbl_progreso: Label = $CenterContainer/TextureRect/MarginContainer/VBoxContainer/LabelProgreso
@onready var lbl_recurso: Label = $CenterContainer/TextureRect/MarginContainer/VBoxContainer/LabelRecursos


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	barra_progreso.value = 0
	lbl_progreso.text = "0%"
	if ManejadorPreguntas:
		# Señales para el flujo de descarga desde Firebase
		ManejadorPreguntas.inicio_carga.connect(cambiar_titulo)
		ManejadorPreguntas.progreso_descarga.connect(actualizar_progreso)
		ManejadorPreguntas.datos_actualizados.connect(_on_carga_completa)
		ManejadorPreguntas.carga_fallida.connect(_on_carga_fallida)

		# Si HAY una descarga activa de Firebase, mostrar mensaje de descarga
		# y esperar a que termine — NO auto-ocultar aunque preguntas_maestras tenga datos
		if ManejadorPreguntas.descarga_en_curso:
			lbl_titulo.text = "Descargando Preguntas..."
			lbl_recurso.text = "Conectando con el servidor..."
		# Si no hay descarga y ya hay preguntas locales, ocultar inmediatamente
		elif not ManejadorPreguntas.preguntas_maestras.is_empty():
			_on_datos_locales_listos()
		# Si no hay descarga ni datos locales, esperar a datos_cargados
		else:
			lbl_titulo.text = "CARGANDO..."
			lbl_recurso.text = "Verificando preguntas..."
			ManejadorPreguntas.datos_cargados.connect(_on_datos_locales_listos)
	else:
		print("❌ Error: No se encuentra el Autoload ManejadorPreguntas")

# Función para cambiar el titulo
func cambiar_titulo(nuevo_titulo: String):
	lbl_titulo.text = nuevo_titulo

# ✅ Se ejecuta cuando las preguntas se cargaron desde cache o respaldo (sin descargar)
func _on_datos_locales_listos():
	lbl_titulo.text = "LISTO"
	lbl_progreso.text = "100%"
	lbl_recurso.text = "Preguntas cargadas desde el dispositivo"
	barra_progreso.value = 100
	
	# Pequeña pausa para que el usuario vea el mensaje
	await get_tree().create_timer(0.5).timeout
	queue_free()

# Esta función se ejecutará cada vez que el bucle for avance
func actualizar_progreso(actual: int, total: int):
	# Evitamos división por cero
	if total == 0: return
	
	# Actualizamos la barra
	var porcentaje = (float(actual) / float(total)) * 100
	barra_progreso.value = porcentaje
	
	# Actualizamos los textos
	lbl_progreso.text = "%d%%" % int(porcentaje)
	lbl_recurso.text = "RECURSOS: %d / %d" % [actual, total]

func _on_carga_completa():
	lbl_recurso.text = "Iniciando..."
	
	# Esperamos un momento para que el usuario vea el 100%
	await get_tree().create_timer(1.0).timeout
	
	# Ocultamos la pantalla de carga o cambiamos de escena
	queue_free() # O visible = false

func _on_carga_fallida():
	lbl_recurso.text = "Error de conexión"
	lbl_titulo.text = "SIN CONEXIÓN"
	# Esperamos un momento para que el usuario vea el error
	await get_tree().create_timer(2.5).timeout
	
	# Ocultamos la pantalla de carga o cambiamos de escena
	queue_free() # O visible = false
