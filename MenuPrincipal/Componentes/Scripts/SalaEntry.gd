extends PanelContainer

signal join_requested(match_id: String)

@onready var lbl_name: Label = $HBoxContainer/LblSalaName
@onready var lbl_players: Label = $HBoxContainer/LblSalaPlayers
@onready var lbl_status: Label = $HBoxContainer/LblSalaStatus
@onready var btn_unirse: Button = $HBoxContainer/BtnUnirse

var sala_match_id: String = ""

func _ready() -> void:
	btn_unirse.pressed.connect(_on_unirse)

func setup(sala_data: Dictionary) -> void:
	sala_match_id = sala_data.get("match_id", "")
	lbl_name.text = sala_data.get("name", "Sin nombre")

	var current_players: int = sala_data.get("current_players", 0)
	var max_players: int = sala_data.get("max_players", 6)
	lbl_players.text = "%d/%d" % [current_players, max_players]

	var status: String = sala_data.get("status", "waiting")
	lbl_status.text = _status_legible(status)

	var is_full: bool = current_players >= max_players
	var in_progress: bool = status == "in_progress"
	btn_unirse.disabled = is_full or in_progress

func _status_legible(status: String) -> String:
	match status:
		"waiting": return "Esperando"
		"in_progress": return "En juego"
		"closed": return "Cerrada"
		_: return status

func _on_unirse() -> void:
	join_requested.emit(sala_match_id)
