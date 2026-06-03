extends Control

# Señal que avisa cuando el proceso de pregunta-respuesta terminó
# Emite true si el jugador acertó, false si falló
signal proceso_terminado(acierto: bool)

# ============================================
# REFERENCIAS A NODOS DE LA ESCENA
# ============================================
@onready var panel_principal = $Panel
@onready var label_pregunta = $Panel/MarginContainer/VBoxContainer/PanelContainerPregunta/LabelPregunta
@onready var contenedor_botones = $Panel/MarginContainer/VBoxContainer/PanelContainerBotones/HBoxContainer
@onready var feedback_popup = $FeedbackPopup

# ============================================
# VARIABLES DE ESTADO DE LA PREGUNTA ACTUAL
# ============================================
# Guarda cuál es la respuesta correcta para validar la selección del jugador
var respuesta_correcta_actual: String = ""
# Explicación que se mostrará después de responder
var explicacion_actual: String = ""
# Almacena si el último resultado fue correcto (para emitir con la señal)
var ultimo_resultado_fue_acierto: bool = false

func _ready() -> void:
	# Conectar señal del popup de feedback
	# Este popup muestra mensajes de felicitación o error después de responder
	if feedback_popup:
		# Intenta conectar con el nombre de señal que tenga el feedback_popup
		if feedback_popup.has_signal("feedback_cerrado"):
			feedback_popup.feedback_cerrado.connect(_on_feedback_cerrado)
		elif feedback_popup.has_signal("feedback_continua"):
			feedback_popup.feedback_continua.connect(_on_feedback_cerrado)
	
	# Conectar evento de clic a todos los botones de opciones
	for hijo in contenedor_botones.get_children():
		if hijo is Button:
			hijo.pressed.connect(_on_opcion_presionada.bind(hijo))
	
	# Ocultar el popup al inicio (solo se muestra cuando se llama mostrar_pregunta)
	hide()

# Función principal que obtiene una pregunta y la muestra en pantalla
func mostrar_pregunta():
	# Hacer visible el popup de pregunta
	show()
	if panel_principal: panel_principal.show()
	
	# Pedir la siguiente pregunta al manager global
	# El manager se encarga de gestionar el mazo y dar preguntas mezcladas
	var data = ManejadorPreguntas.obtener_siguiente_pregunta()
	
	# Validación de seguridad: verificar que el manager devolvió datos válidos
	# Esto solo falla si no hay preguntas cargadas en el sistema
	if data.is_empty():
		print("⚠️ Error: El QuestionManager no devolvió ninguna pregunta.")
		hide()
		return
	
	# Mostrar el texto de la pregunta en la UI
	if label_pregunta: label_pregunta.text = data["question"]
	# Guardar la explicación para mostrarla después de responder
	explicacion_actual = data["explanation"]
	
	# ============================================
	# PREPARAR LAS OPCIONES DE RESPUESTA
	# ============================================
	
	# Copiar todas las opciones disponibles
	var todas_opciones = data["options"].duplicate()
	# Obtener el índice de la respuesta correcta
	var indice_correcto = int(data["correct_index"])
	# Guardar el texto de la respuesta correcta para validar después
	respuesta_correcta_actual = todas_opciones[indice_correcto]
	
	# Separar las opciones incorrectas en un array aparte
	var opciones_incorrectas = []
	for i in range(todas_opciones.size()):
		if i != indice_correcto: 
			opciones_incorrectas.append(todas_opciones[i])
	
	# Mezclar las opciones incorrectas para que aparezcan en orden aleatorio
	opciones_incorrectas.shuffle()
	
	# Seleccionar solo 2 opciones incorrectas (para mostrar 3 botones en total)
	var opcion1 = opciones_incorrectas[0] if opciones_incorrectas.size() > 0 else "N/A"
	var opcion2 = opciones_incorrectas[1] if opciones_incorrectas.size() > 1 else "N/A"
	
	# Crear array final con 1 correcta + 2 incorrectas
	var opciones_finales = [respuesta_correcta_actual, opcion1, opcion2]
	# Mezclar para que la respuesta correcta no siempre esté en la misma posición
	opciones_finales.shuffle()
	
	# ============================================
	# ASIGNAR OPCIONES A LOS BOTONES
	# ============================================
	
	var hijos_contenedor = contenedor_botones.get_children()
	var contador_botones = 0
	
	# Recorrer los nodos del contenedor y buscar botones
	for hijo in hijos_contenedor:
		var boton = _buscar_boton(hijo)
		# Asignar texto solo a los primeros 3 botones encontrados
		if boton and contador_botones < 3:
			boton.text = opciones_finales[contador_botones]
			boton.disabled = false  # Habilitar el botón
			boton.show()  # Asegurar que sea visible
			
			# Conectar evento de clic (verificación extra por seguridad)
			if not boton.pressed.is_connected(_on_opcion_presionada):
				boton.pressed.connect(_on_opcion_presionada.bind(boton))
			
			contador_botones += 1

# ============================================
# FUNCIONES AUXILIARES DE UI
# ============================================

# Busca recursivamente un botón dentro de un nodo y sus hijos
# Útil porque los botones pueden estar dentro de contenedores anidados
func _buscar_boton(nodo: Node) -> Button:
	# Si el nodo actual es un botón, retornarlo
	if nodo is Button: return nodo
	
	# Si no, buscar en sus hijos recursivamente
	for hijo in nodo.get_children():
		var res = _buscar_boton(hijo)
		if res: return res
	
	# Si no se encontró ningún botón, retornar null
	return null

# Se ejecuta cuando el jugador presiona una opción
func _on_opcion_presionada(boton: Button):
	# Deshabilitar todos los botones para evitar múltiples respuestas
	_deshabilitar_botones(contenedor_botones)
	
	# Verificar si la respuesta es correcta comparando el texto del botón
	if boton.text == respuesta_correcta_actual:
		print("¡Correcto!")
		ultimo_resultado_fue_acierto = true
		# Ocultar el panel principal
		if panel_principal: panel_principal.hide()
		
		# Mostrar popup de felicitación con la explicación
		if feedback_popup.has_method("mostrar_felicitacion"):
			feedback_popup.mostrar_felicitacion(explicacion_actual)
		else:
			# Si no existe el método, continuar directamente
			_on_feedback_cerrado()
	else:
		# El jugador falló
		ultimo_resultado_fue_acierto = false
		if panel_principal: panel_principal.hide()
		
		# Mostrar popup de error con la respuesta correcta y explicación
		if feedback_popup.has_method("mostrar_error"):
			feedback_popup.mostrar_error(respuesta_correcta_actual, explicacion_actual)

# Deshabilita recursivamente todos los botones dentro de un nodo
# Esto evita que el jugador pueda hacer clic en otra opción después de responder
func _deshabilitar_botones(nodo: Node):
	for hijo in nodo.get_children():
		if hijo is Button: 
			hijo.disabled = true
		elif hijo.get_child_count() > 0: 
			# Si el hijo tiene más hijos, buscar recursivamente
			_deshabilitar_botones(hijo)

# Se ejecuta cuando el popup de feedback se cierra
# Aquí se completa el ciclo de la pregunta
func _on_feedback_cerrado():
	# Ocultar todo el popup de pregunta
	hide()
	# Emitir señal para avisar al sistema que el proceso terminó
	# La señal incluye si fue acierto o fallo para actualizar puntuación/vidas
	proceso_terminado.emit(ultimo_resultado_fue_acierto)
