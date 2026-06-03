# feedback_popup.gd
# Script que gestiona un popup emergente para mostrar retroalimentación sobre respuestas del usuario
# Puede mostrar mensajes de éxito o error con animaciones suaves

extends Control

# Señal que se emite cuando el usuario presiona el botón "Continuar"
# Otros scripts pueden conectarse a esta señal para saber cuándo proceder
signal feedback_continua

# ============================================================================
# REFERENCIAS A NODOS (cargadas automáticamente al iniciar la escena)
# ============================================================================

# Referencia al Panel principal que contiene toda la interfaz del popup
@onready var panel = $Panel

# Label que muestra el título/resultado (ej: "✅ Correcto" o "❌ Incorrecto")
@onready var titulo_label = $VBoxContainer/PanelContainerTitulo/TituloLabel

# Label que muestra el mensaje detallado de explicación
# IMPORTANTE: Este nodo DEBE existir en tu árbol de nodos de la escena
@onready var explicacion_label = $VBoxContainer/PanelContainerRetroalimentacion/MarginContainer/ScrollContainer/MensajeLabel

# Referencia al botón "Continuar" que el usuario presiona para cerrar el popup
@onready var boton_cerrar = $VBoxContainer/BotonContinuar

# Variable booleana que indica si el popup está actualmente visible
var esta_visible: bool = false

# ============================================================================
# MÉTODO _READY() - Se ejecuta cuando la escena está lista
# ============================================================================
func _ready() -> void:
	# Conectar la señal "pressed" del botón a la función que cierra el popup
	# Cuando hagas clic en el botón, se llamará automáticamente a _on_boton_continuar_pressed()
	boton_cerrar.pressed.connect(_on_boton_continuar_pressed)
	
	# Ocultar el popup al inicio (no queremos que aparezca inmediatamente)
	hide()
	
	# Aplicar la configuración de estilos iniciales
	configurar_estilo()

# ============================================================================
# MÉTODO _PROCESS() - Se ejecuta cada frame
# ============================================================================
func _process(delta: float) -> void:
	# Permitir que el usuario cierre el popup presionando ESC
	# solo si el popup está actualmente visible
	if esta_visible and Input.is_action_just_pressed("ui_cancel"):
		_on_boton_continuar_pressed()

# ============================================================================
# CONFIGURACIÓN DE ESTILOS
# ============================================================================
func configurar_estilo():
	"""
	Configura la apariencia inicial del popup.
	Esto incluye el punto de rotación y el texto de los botones.
	"""
	# Configurar el punto de pivote (centro de rotación) del panel
	# Se coloca en el centro del panel para que las animaciones sean más naturales
	if panel:
		panel.pivot_offset = panel.size / 2
	
	# Configurar el texto del botón de cierre
	if boton_cerrar:
		boton_cerrar.text = ""

# ============================================================================
# MOSTRAR RETROALIMENTACIÓN POSITIVA (Respuesta Correcta)
# ============================================================================
func mostrar_felicitacion(explicacion: String):
	"""
	Muestra un mensaje de felicitación cuando el usuario responde correctamente.
	
	Parámetros:
	- respuesta_usuario: La respuesta que el usuario seleccionó (ej: "Fotosíntesis")
	- explicacion: Explicación detallada de por qué es correcta
	"""
	# Establecer el título del popup como "✅ Correcto"
	if titulo_label:
		titulo_label.text = "✅ Correcto"
	
	# Construir el mensaje de explicación combinando la respuesta y su justificación
	# %s son placeholders que se reemplazan con los valores pasados entre []
	var texto_explicacion = "Explicación:\n%s" % explicacion
	
	# Asignar el texto construido al label de explicación
	if explicacion_label:
		explicacion_label.text = texto_explicacion
	
	# Mostrar el popup con una animación suave
	mostrar_con_animacion()

# ============================================================================
# MOSTRAR RETROALIMENTACIÓN NEGATIVA (Respuesta Incorrecta)
# ============================================================================
func mostrar_error(respuesta_correcta: String, explicacion: String):
	"""
	Muestra un mensaje de error cuando el usuario responde incorrectamente.
	
	Parámetros:
	- respuesta_usuario: La respuesta que el usuario seleccionó (ej: "Respiración")
	- respuesta_correcta: La respuesta correcta (ej: "Fotosíntesis")
	- explicacion: Explicación de por qué la respuesta correcta es válida
	"""
	# Establecer el título del popup como "❌ Incorrecto"
	if titulo_label:
		titulo_label.text = "❌ Incorrecto"
	
	# Construir el mensaje que muestra la respuesta incorrecta, la correcta y la justificación
	var texto_explicacion = "La respuesta correcta era %s. Explicación:\n%s" % [respuesta_correcta, explicacion]
	
	# Asignar el texto construido al label de explicación
	if explicacion_label:
		explicacion_label.text = texto_explicacion
	
	# Mostrar el popup con una animación suave
	mostrar_con_animacion()

# ============================================================================
# ANIMACIÓN DE ENTRADA - Muestra el popup con efecto visual
# ============================================================================
func mostrar_con_animacion():
	"""
	Muestra el popup con una animación suave que aumenta la opacidad y escala.
	La animación da una sensación de "pop-in" atractiva.
	"""
	# Marcar que el popup ahora está visible
	esta_visible = true
	
	# Hacer visible el nodo en la pantalla
	show()
	
	# Aplicar animación por código (sin necesidad de AnimationPlayer)
	if panel:
		# Estado inicial: panel completamente transparente y pequeño
		panel.modulate.a = 0  # Opacidad al 0% (invisible)
		panel.scale = Vector2(0.8, 0.8)  # Tamaño al 80%
		
		# Crear animación paralela (ambas propiedades cambian al mismo tiempo)
		var tween = create_tween().set_parallel(true)
		
		# Animar la opacidad: de 0 a 1 en 0.3 segundos
		tween.tween_property(panel, "modulate:a", 1.0, 0.3)
		
		# Animar la escala: de 0.8 a 1.0 (100%) en 0.3 segundos
		# set_ease() define la curva de aceleración (START lenta, END rápida)
		# set_trans() define el tipo de transición (BACK crea efecto de "rebote")
		tween.tween_property(panel, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

# ============================================================================
# ANIMACIÓN DE SALIDA - Oculta el popup con efecto visual
# ============================================================================
func ocultar_con_animacion():
	"""
	Oculta el popup con una animación suave que disminuye la opacidad y escala.
	Es la animación inversa a mostrar_con_animacion().
	"""
	if panel:
		# Crear animación paralela para ambas propiedades
		var tween = create_tween().set_parallel(true)
		
		# Animar la opacidad: de 1 a 0 en 0.2 segundos (se desvanece)
		tween.tween_property(panel, "modulate:a", 0.0, 0.2)
		
		# Animar la escala: de 1.0 a 0.9 en 0.2 segundos (se encoge ligeramente)
		tween.tween_property(panel, "scale", Vector2(0.9, 0.9), 0.2)
		
		# Esperar a que la animación termine antes de continuar
		# Esto evita que el panel reaparezca mientras se está ocultando
		await tween.finished
	
	# Ocultar el nodo completamente
	hide()
	
	# Actualizar el estado para indicar que ya no está visible
	esta_visible = false

# ============================================================================
# MANEJADOR DE EVENTOS - Cuando se presiona el botón "Continuar"
# ============================================================================
func _on_boton_continuar_pressed() -> void:
	"""
	Se ejecuta cuando el usuario presiona el botón "Continuar" o la tecla ESC.
	Oculta el popup y emite la señal para que el resto del juego continúe.
	"""
	# Ejecutar la animación de salida y esperar a que termine
	await ocultar_con_animacion()
	
	# Emitir la señal "feedback_continua" para notificar a otros scripts
	# que el usuario ha visto la retroalimentación y el juego puede continuar
	feedback_continua.emit()

# ============================================================================
# FUNCIÓN AUXILIAR - Alterna la visibilidad del popup
# ============================================================================
func toggle_visibilidad():
	"""
	Abre el popup si está cerrado, o lo cierra si está abierto.
	Útil para pruebas o para controles que simplemente invierten el estado.
	"""
	if esta_visible:
		# Si está visible, ocultarlo
		_on_boton_continuar_pressed()
	else:
		# Si está oculto, mostrarlo
		mostrar_con_animacion()
