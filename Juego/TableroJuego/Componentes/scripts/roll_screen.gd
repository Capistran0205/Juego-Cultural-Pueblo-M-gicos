extends Control

# Señal que se emite cuando el dado termina de rodar
signal dice_rolled(result: int)

@onready var dice_roller = $DiceRollerControl
@onready var button = $Button

var dice_result: int = 0
var is_rolling: bool = false

func _ready() -> void:
	print("=== Escena del dado lista ===")
	print("DiceRollerControl encontrado: ", dice_roller != null)
	print("Button encontrado: ", button != null)
	
	# Asegurarse de que el botón esté habilitado
	if button:
		button.disabled = false

func _process(delta: float) -> void:
	pass

# Cuando el usuario presiona el botón de lanzar
func _on_button_pressed() -> void:
	if is_rolling:
		print("El dado ya está rodando...")
		return
	
	is_rolling = true
	print("=== BOTÓN LANZAR PRESIONADO ===")
	
	# Deshabilitar el botón mientras rueda
	if button:
		button.disabled = true
	
	# Iniciar el dado
	if dice_roller:
		dice_roller.roll()
		print("Dado iniciado a rodar...")
	else:
		print("ERROR: DiceRollerControl no encontrado")
		is_rolling = false
		if button:
			button.disabled = false

# Cuando el dado termina de rodar (señal del DiceRollerControl)
func _on_dice_roller_control_roll_finnished(diceResult: int) -> void:
	dice_result = diceResult
	print("=== DADO TERMINÓ DE RODAR ===")
	print("Resultado del dado: %d" % dice_result)
	
	# Guardar en Global
	Global.dice_result = dice_result
	print("Guardado en Global.dice_result: %d" % Global.dice_result)
	
	# Esperar un momento antes de emitir la señal
	await get_tree().create_timer(0.5).timeout
	
	# Emitir señal para que GameManager la capture
	print("Emitiendo señal dice_rolled con resultado: %d" % dice_result)
	emit_signal("dice_rolled", dice_result)
	
	# Rehabilitar el botón
	is_rolling = false
	if button:
		button.disabled = false
	
	print("=== Señal dice_rolled emitida correctamente ===")
