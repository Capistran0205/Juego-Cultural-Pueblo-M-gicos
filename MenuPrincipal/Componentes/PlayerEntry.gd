class_name PlayerEntry
extends HBoxContainer

# Avatares disponibles. Si agregas más, sólo amplía este array.
const AVATAR_PATHS: Array[String] = [
	"res://Assets/Jugadores/Jugador1_bg.png",
	"res://Assets/Jugadores/Jugador2_bg.png",
	"res://Assets/Jugadores/Jugador3_bg.png",
	"res://Assets/Jugadores/Jugador4_bg.png",
	"res://Assets/Jugadores/Jugador5_bg.png",
	"res://Assets/Jugadores/Jugador6_bg.png",
]

signal avatar_changed(player_index: int, avatar_id: int)

@onready var lbl_num: Label = $LblPlayerNum
@onready var input_name: LineEdit = $InputPlayerName
@onready var btn_avatar_prev: Button = $AvatarBox/BtnAvatarPrev
@onready var avatar_rect: TextureRect = $AvatarBox/Avatar
@onready var btn_avatar_sig: Button = $AvatarBox/BtnAvatarSig
@onready var btn_color: ColorPickerButton = $BtnColor

var player_index: int = 0
var avatar_id: int = 0

# Callable inyectado desde el lobby:
#   func(candidate_id: int) -> bool
# Devuelve true si OTRO jugador ya tiene ese avatar.
var _is_taken_by_other: Callable = func(_id): return false

func _ready() -> void:
	btn_avatar_prev.pressed.connect(_on_avatar_prev)
	btn_avatar_sig.pressed.connect(_on_avatar_sig)

# El lobby llama a esto ANTES de setup para inyectar la validación.
func set_taken_check(checker: Callable) -> void:
	_is_taken_by_other = checker

func setup(index: int, default_name: String, default_color: Color, default_avatar_id: int = -1) -> void:
	player_index = index
	lbl_num.text = "Jugador %d:" % index
	input_name.text = default_name
	input_name.placeholder_text = "Nombre"
	btn_color.color = default_color
	avatar_id = default_avatar_id if default_avatar_id >= 0 else (index - 1) % AVATAR_PATHS.size()
	_refrescar_avatar()

func get_player_data() -> Dictionary:
	return {
		"index": player_index,
		"name": input_name.text,
		"color": btn_color.color,
		"avatar_id": avatar_id,
	}

func _on_avatar_prev() -> void:
	_intentar_cambio(-1)

func _on_avatar_sig() -> void:
	_intentar_cambio(1)

func _intentar_cambio(direction: int) -> void:
	var nuevo := _siguiente_libre(direction)
	if nuevo == avatar_id:
		return
	avatar_id = nuevo
	_refrescar_avatar()
	avatar_changed.emit(player_index, avatar_id)

# Busca el siguiente avatar libre en la dirección indicada,
# saltándose los que ya tomó otro jugador.
func _siguiente_libre(direction: int) -> int:
	var n := AVATAR_PATHS.size()
	var candidate := avatar_id
	for _i in range(n):
		candidate = wrapi(candidate + direction, 0, n)
		if not _is_taken_by_other.call(candidate):
			return candidate
	return avatar_id

func _refrescar_avatar() -> void:
	var tex: Texture2D = load(AVATAR_PATHS[avatar_id]) as Texture2D
	if tex != null:
		avatar_rect.texture = tex
