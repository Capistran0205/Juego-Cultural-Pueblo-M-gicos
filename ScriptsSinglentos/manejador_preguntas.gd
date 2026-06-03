extends Node

# ID de tu proyecto de Firebase
const PROJECT_ID = "olintlimx-e21ff"
# Nombre de la colección en Firestore donde están las preguntas
const COLLECTION = "questions"

# URL base para hacer queries a Firestore
const FIRESTORE_BASE_URL = "https://firestore.googleapis.com/v1/projects/" + PROJECT_ID + "/databases/(default)/documents:runQuery"

# Archivo de respaldo incluido en el juego (solo lectura después de exportar)
const RUTA_RESPALDO = "res://data/questions.json"
# Archivo de cache donde se guardan actualizaciones (siempre se puede leer y escribir)
const RUTA_CACHE = "user://questions.json"

# Todas las preguntas disponibles
var preguntas_maestras: Array = []
# Mazo temporal que se consume al sacar preguntas
var preguntas_disponibles: Array = []

# ID del estado que quieres filtrar (puedes cambiarlo dinámicamente)
var state_id_filtro: int = 33  # Cambia este valor según necesites
var _tiempo_inicio_peticion: int = 0 # Medición de tiempo
var preguntas_obtenidas: bool = false

# Cooldown de actualización manual: 10 minutos (en milisegundos)
const COOLDOWN_ACTUALIZACION_MS: int = 5 * 60 * 1000
# Marca de tiempo de la última descarga exitosa (Time.get_ticks_msec)
var _ultima_actualizacion_ms: int = -COOLDOWN_ACTUALIZACION_MS
# Indica si hay una descarga de Firebase en curso (para que la barra no se oculte)
var descarga_en_curso: bool = false

# Avisos para cuando los datos están listos
signal datos_cargados
signal carga_fallida
signal datos_actualizados
signal mazo_reiniciado
signal progreso_descarga(actual: int, total: int)
signal inicio_carga(mensaje: String)
# Aviso cuando se rechaza una actualización por estar en cooldown
signal actualizacion_en_cooldown(segundos_restantes: int)

func _ready() -> void:
	# 1. Intenta cargar rápido desde cache (respuesta instantánea)
	if cargar_desde_cache():
		print("✓ Cargado desde caché — sin descarga necesaria")
		datos_cargados.emit()
	# 2. Si no hay cache, usa el archivo de respaldo
	elif cargar_desde_respaldo():
		print("✓ Cargado desde respaldo — sin descarga necesaria")
		datos_cargados.emit()
		guardar_cache_actual()  # Copia el respaldo al cache para próxima vez
	# 3. Solo si NO hay ningún dato local se descarga desde Firebase
	else:
		print("⚠️ Sin datos locales — iniciando descarga desde Firebase...")
		actualizar_desde_firebase()

# Lee preguntas del cache (carpeta del usuario)
func cargar_desde_cache() -> bool:
	# Verifica si existe el archivo
	if not FileAccess.file_exists(RUTA_CACHE):
		return false
	
	# Abre y lee el archivo
	var archivo = FileAccess.open(RUTA_CACHE, FileAccess.READ)
	if not archivo:
		return false
	
	var json_texto = archivo.get_as_text()
	archivo.close()
	
	# Convierte el JSON a datos utilizables
	var json = JSON.parse_string(json_texto)
	if json and "questions" in json:
		preguntas_maestras = json["questions"]
		var hubo_limpieza = _limpiar_lista_preguntas()
		_reiniciar_mazo()  # Mezcla las preguntas
		print("📚 %d preguntas desde caché" % preguntas_maestras.size())
		# Si limpiamos algo, reescribimos el cache para que la próxima lectura ya esté limpia
		if hubo_limpieza:
			guardar_cache_actual()
			print("💾 Cache actualizado (opciones vacías removidas)")
		return true

	return false

# Lee preguntas del archivo de respaldo (incluido en el juego)
func cargar_desde_respaldo() -> bool:
	# Verifica si existe
	if not FileAccess.file_exists(RUTA_RESPALDO):
		print("❌ No existe respaldo")
		return false
	
	# Abre y lee
	var archivo = FileAccess.open(RUTA_RESPALDO, FileAccess.READ)
	if not archivo:
		return false
	
	var json_texto = archivo.get_as_text()
	archivo.close()
	# Convierte JSON a datos
	var json = JSON.parse_string(json_texto)
	if json and "questions" in json:
		preguntas_maestras = json["questions"]
		_limpiar_lista_preguntas()
		_reiniciar_mazo()
		print("📚 %d preguntas desde respaldo" % preguntas_maestras.size())
		return true

	return false

# Descarga preguntas actualizadas desde Firestore con filtro
func actualizar_desde_firebase():
	print("🌐 Obteniendo preguntas de Firestore con state_id = %d..." % state_id_filtro)
	descarga_en_curso = true
	# Aviso inmediato — antes de que llegue la respuesta de Firebase
	inicio_carga.emit("Descargando Preguntas...")
	# Cada descarga usa SU PROPIO HTTPRequest local (evita el bug de
	# liberar instancias compartidas si dos descargas se solapan).
	var peticion := HTTPRequest.new()
	add_child(peticion)
	# La señal pasa la peticion al callback vía bind, no por variable miembro
	peticion.request_completed.connect(_on_firestore_response.bind(peticion))

	# Construye la query estructurada para filtrar por state_id
	var query_body = {
		"structuredQuery": {
			"from": [{"collectionId": COLLECTION}],
			"where": {
				"fieldFilter": {
					"field": {"fieldPath": "state_id"},
					"op": "EQUAL",
					"value": {"integerValue": str(state_id_filtro)}
				}
			}
		}
	}

	# Convierte la query a JSON
	var json_string = JSON.stringify(query_body)

	# Headers necesarios para la petición
	var headers = ["Content-Type: application/json"]
	_tiempo_inicio_peticion = Time.get_ticks_usec()
	# Hace la petición POST a Firestore con la query
	var error = peticion.request(FIRESTORE_BASE_URL, headers, HTTPClient.METHOD_POST, json_string)
	if error != OK:
		print("❌ Error HTTP: ", error)
		descarga_en_curso = false
		carga_fallida.emit()
		peticion.queue_free()

# Solicitud manual con cooldown. Devuelve true si la descarga arrancó.
func solicitar_actualizacion_manual() -> bool:
	var ahora = Time.get_ticks_msec()
	var transcurrido = ahora - _ultima_actualizacion_ms
	if transcurrido < COOLDOWN_ACTUALIZACION_MS:
		var restante_seg = int(ceil((COOLDOWN_ACTUALIZACION_MS - transcurrido) / 1000.0))
		print("⏳ Actualización en cooldown: faltan %d s" % restante_seg)
		actualizacion_en_cooldown.emit(restante_seg)
		return false
	actualizar_desde_firebase()
	return true

# Tiempo restante (segundos) antes de poder volver a actualizar manualmente
func segundos_restantes_cooldown() -> int:
	var ahora = Time.get_ticks_msec()
	var transcurrido = ahora - _ultima_actualizacion_ms
	if transcurrido >= COOLDOWN_ACTUALIZACION_MS:
		return 0
	return int(ceil((COOLDOWN_ACTUALIZACION_MS - transcurrido) / 1000.0))

# Función para cambiar el filtro de state_id dinámicamente
func cambiar_filtro_estado(nuevo_state_id: int):
	state_id_filtro = nuevo_state_id
	print("🔄 Cambiando filtro a state_id = %d" % state_id_filtro)
	actualizar_desde_firebase()

# Procesa lo que devolvió Firestore
# `peticion` se recibe por bind() desde actualizar_desde_firebase(),
# garantizando que cada callback libere SU propio HTTPRequest.
func _on_firestore_response(result, response_code, headers, body, peticion: HTTPRequest):
	var tiempo_total = Time.get_ticks_usec() - _tiempo_inicio_peticion
	print("⏱️ Tiempo TOTAL para obtención de respuestas: %d µs (%.3f ms)" % [tiempo_total, tiempo_total / 1000.0])
	var titulo_estado = ""
	# 200 = petición exitosa
	if response_code == 200:
		# Convierte los bytes a texto
		var json_texto = body.get_string_from_utf8()
		# Convierte el texto a datos
		var firestore_data = JSON.parse_string(json_texto)
		
		# La respuesta de runQuery viene en un array
		if firestore_data and firestore_data is Array:
			# Array para guardar todas las preguntas convertidas
			var preguntas_convertidas = []
			# Obtener el total de los documentos encontrados
			var total_docs = firestore_data.size()
			var procesados = 0
			
			# Si ya tenemos preguntas en memoria, es una actualización. Si no, es instalación.			
			if not preguntas_maestras.is_empty():
				titulo_estado = "Actualizando Recursos..."
				print("Modo: Actualización")
			else:
				titulo_estado = "Descargando Recursos..."
				print("Modo: Primera Instalación")
			inicio_carga.emit(titulo_estado)
			
			# Emitir el inicio del progreso
			progreso_descarga.emit(0, total_docs)
			# Pausa mínima para que la barra se ponga
			await get_tree().process_frame
			
			# Cada elemento del array tiene un "document"
			var opciones_eliminadas_total = 0
			var preguntas_descartadas = 0
			for item in firestore_data:
				if "document" in item:
					var doc = item["document"]
					var pregunta_convertida = convertir_documento_firestore(doc)
					if not pregunta_convertida.is_empty():
						# Quita opciones vacías del array y reajusta correct_index
						var info = _limpiar_opciones_vacias(pregunta_convertida)
						opciones_eliminadas_total += info["eliminadas"]
						if info["valida"]:
							preguntas_convertidas.append(pregunta_convertida)
						else:
							preguntas_descartadas += 1
				# Incremento y emisión a la señal
				procesados += 1
				progreso_descarga.emit(procesados, total_docs)
				if procesados % 10 == 0:
					await get_tree().create_timer(0.1).timeout

			if opciones_eliminadas_total > 0:
				print("🧹 %d opciones vacías eliminadas" % opciones_eliminadas_total)
			if preguntas_descartadas > 0:
				print("⚠️ %d preguntas descartadas (sin opciones suficientes)" % preguntas_descartadas)
			
			# Si hay preguntas convertidas
			if not preguntas_convertidas.is_empty():
				print("🔄 Guardando %d preguntas descargadas..." % preguntas_convertidas.size())
				preguntas_maestras = preguntas_convertidas
				_reiniciar_mazo()  # Reorganiza el mazo
				
				# Guarda las nuevas preguntas en cache
				var datos_cache = {"questions": preguntas_maestras}
				guardar_en_cache(JSON.stringify(datos_cache, "\t"))
				
				print("✅ Preguntas guardadas en dispositivo")
				preguntas_obtenidas = true
				_ultima_actualizacion_ms = Time.get_ticks_msec()
				datos_actualizados.emit()  # Avisa que la descarga terminó
			else:
				print("⚠️ No se encontraron preguntas con state_id = %d" % state_id_filtro)
				carga_fallida.emit()
		else:
			print("⚠️ Formato de respuesta inesperado")
			carga_fallida.emit()
	else:
		titulo_estado = "Sin conexión al servidor, cierre el juego y conéctese a internet"
		inicio_carga.emit(titulo_estado)
		carga_fallida.emit()
		print("⚠️ Error Firestore. Código: ", response_code)
	# La descarga (con éxito o falla) ya terminó
	descarga_en_curso = false
	# Limpia el objeto HTTP propio de esta petición (defensa con is_instance_valid)
	if is_instance_valid(peticion):
		peticion.queue_free()
	

# Limpia opciones vacías del array "options" de una pregunta y reajusta
# correct_index. Devuelve {"valida": bool, "eliminadas": int}.
# Una pregunta se considera inválida si la opción correcta era vacía,
# o si quedan menos de 3 opciones (el popup muestra 3 botones).
func _limpiar_opciones_vacias(pregunta: Dictionary) -> Dictionary:
	var info = {"valida": false, "eliminadas": 0}
	if not "options" in pregunta or not pregunta["options"] is Array:
		return info

	var opciones_originales: Array = pregunta["options"]
	var indice_correcto = int(pregunta.get("correct_index", -1))

	# Guardar el texto de la respuesta correcta antes de filtrar
	var texto_correcto = ""
	if indice_correcto >= 0 and indice_correcto < opciones_originales.size():
		var op_correcta = opciones_originales[indice_correcto]
		if op_correcta is String:
			texto_correcto = op_correcta

	# Filtrar opciones vacías, nulas o solo espacios
	var opciones_limpias: Array = []
	for op in opciones_originales:
		if op == null:
			info["eliminadas"] += 1
			continue
		if op is String and op.strip_edges() == "":
			info["eliminadas"] += 1
			continue
		opciones_limpias.append(op)

	pregunta["options"] = opciones_limpias

	# Recalcular correct_index buscando el texto correcto en el nuevo array
	var nuevo_indice = opciones_limpias.find(texto_correcto)
	if nuevo_indice == -1:
		# La opción correcta era vacía o desapareció: pregunta inservible
		return info
	pregunta["correct_index"] = nuevo_indice

	# El popup muestra 1 correcta + 2 incorrectas, así que se necesitan >= 3
	if opciones_limpias.size() < 3:
		return info

	info["valida"] = true
	return info

# Aplica _limpiar_opciones_vacias a todas las preguntas en preguntas_maestras.
# Devuelve true si hubo algún cambio (eliminadas > 0 o preguntas descartadas).
func _limpiar_lista_preguntas() -> bool:
	var preguntas_validas: Array = []
	var total_eliminadas = 0
	var total_descartadas = 0
	for pregunta in preguntas_maestras:
		if not pregunta is Dictionary:
			continue
		var info = _limpiar_opciones_vacias(pregunta)
		total_eliminadas += info["eliminadas"]
		if info["valida"]:
			preguntas_validas.append(pregunta)
		else:
			total_descartadas += 1
	preguntas_maestras = preguntas_validas
	if total_eliminadas > 0:
		print("🧹 Limpieza: %d opciones vacías removidas" % total_eliminadas)
	if total_descartadas > 0:
		print("⚠️ Limpieza: %d preguntas descartadas" % total_descartadas)
	return total_eliminadas > 0 or total_descartadas > 0

# Convierte el formato complejo de Firestore a un Dictionary normal
func convertir_documento_firestore(documento: Dictionary) -> Dictionary:
	# Verifica que el documento tenga campos
	if not documento or not "fields" in documento:
		return {}
	
	var resultado = {}
	var fields = documento["fields"]
	
	# Lee cada campo del documento
	for key in fields:
		var field = fields[key]
		
		# Firestore guarda cada tipo de dato con un nombre especial
		# Detecta el tipo y extrae el valor
		if "stringValue" in field:
			resultado[key] = field["stringValue"]  # Texto
		elif "integerValue" in field:
			resultado[key] = int(field["integerValue"])  # Número entero
		elif "doubleValue" in field:
			resultado[key] = field["doubleValue"]  # Número decimal
		elif "booleanValue" in field:
			resultado[key] = field["booleanValue"]  # true/false
		elif "arrayValue" in field:
			resultado[key] = convertir_array_firestore(field["arrayValue"])  # Lista
		elif "mapValue" in field:
			resultado[key] = convertir_map_firestore(field["mapValue"])  # Objeto anidado
	
	return resultado

# Convierte listas de Firestore a arrays normales de Godot
func convertir_array_firestore(array_value: Dictionary) -> Array:
	# Verifica que el array tenga valores
	if not "values" in array_value:
		return []
	
	var resultado = []
	# Convierte cada elemento de la lista
	for item in array_value["values"]:
		if "stringValue" in item:
			resultado.append(item["stringValue"])
		elif "integerValue" in item:
			resultado.append(int(item["integerValue"]))
		elif "doubleValue" in item:
			resultado.append(float(item["doubleValue"]))
		elif "booleanValue" in item:
			resultado.append(item["booleanValue"])
		elif "mapValue" in item:
			resultado.append(convertir_map_firestore(item["mapValue"]))
		elif "arrayValue" in item:
			resultado.append(convertir_array_firestore(item["arrayValue"]))
	
	return resultado

# Convierte objetos anidados de Firestore a Dictionary normales
func convertir_map_firestore(map_value: Dictionary) -> Dictionary:
	# Verifica que el objeto tenga campos
	if not "fields" in map_value:
		return {}
	
	var resultado = {}
	# Lee cada propiedad del objeto
	for key in map_value["fields"]:
		var field = map_value["fields"][key]
		
		# Extrae el valor según su tipo
		if "stringValue" in field:
			resultado[key] = field["stringValue"]
		elif "integerValue" in field:
			resultado[key] = int(field["integerValue"])
		elif "doubleValue" in field:
			resultado[key] = float(field["doubleValue"])
		elif "booleanValue" in field:
			resultado[key] = field["booleanValue"]
		elif "arrayValue" in field:
			resultado[key] = convertir_array_firestore(field["arrayValue"])
		elif "mapValue" in field:
			resultado[key] = convertir_map_firestore(field["mapValue"])
	
	return resultado

# Guarda el JSON en el archivo de cache
func guardar_en_cache(json_texto: String):
	# Abre/crea el archivo en modo escritura
	var archivo = FileAccess.open(RUTA_CACHE, FileAccess.WRITE)
	if archivo:
		archivo.store_string(json_texto)
		archivo.close()
		print("💾 Cache guardado")
	else:
		print("❌ Error al guardar cache")

# Convierte las preguntas actuales a JSON y las guarda
func guardar_cache_actual():
	var datos = {"questions": preguntas_maestras}
	var json_texto = JSON.stringify(datos, "\t")
	guardar_en_cache(json_texto)

# Mezcla todas las preguntas y reinicia el mazo
func _reiniciar_mazo():
	# Copia todas las preguntas
	preguntas_disponibles = preguntas_maestras.duplicate()
	# Las mezcla aleatoriamente
	preguntas_disponibles.shuffle()
	mazo_reiniciado.emit()

# Obtiene la siguiente pregunta (otras escenas llaman esta función)
func obtener_siguiente_pregunta() -> Dictionary:
	# Si no hay preguntas, retorna vacío
	if preguntas_maestras.is_empty():
		return {}
	# Si se acabaron, reinicia el mazo
	if preguntas_disponibles.is_empty():
		_reiniciar_mazo()
	# Saca y retorna la última pregunta
	return preguntas_disponibles.pop_back()

# Ejemplo: Query más compleja con múltiples filtros
func consulta_avanzada(state_id: int, correct_index: int):
	print("🔍 Consulta avanzada...")

	var peticion := HTTPRequest.new()
	add_child(peticion)
	peticion.request_completed.connect(_on_firestore_response.bind(peticion))

	# Query con múltiples condiciones
	var query_body = {
		"structuredQuery": {
			"from": [{"collectionId": COLLECTION}],
			"where": {
				"compositeFilter": {
					"op": "AND",
					"filters": [
						{
							"fieldFilter": {
								"field": {"fieldPath": "state_id"},
								"op": "EQUAL",
								"value": {"integerValue": str(state_id)}
							}
						},
						{
							"fieldFilter": {
								"field": {"fieldPath": "correct_index"},
								"op": "EQUAL",
								"value": {"integerValue": str(correct_index)}
							}
						}
					]
				}
			}
		}
	}

	var json_string = JSON.stringify(query_body)
	var headers = ["Content-Type: application/json"]

	var error = peticion.request(FIRESTORE_BASE_URL, headers, HTTPClient.METHOD_POST, json_string)
	if error != OK:
		print("❌ Error HTTP: ", error)
		peticion.queue_free()
