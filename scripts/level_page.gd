class_name LevelPage
extends Node2D

# Decoración de la página (cabecera, cenefas, ilustración y nombre del nivel).
# Se apila de arriba abajo en layout(); el hueco entre la cenefa central y la
# inferior queda libre para el tablero (board_rect).

# Tamaño de referencia: el ancho de la columna de juego y el alto mínimo.
const DESIGN_SIZE := Vector2(720, 1280)

@export var level_name: String = "Candles":
	set(value):
		level_name = value
		if is_node_ready():
			_level_name_label.text = value

@export var top_margin: float = 18.0
## Parte del alto sobrante (pantallas más altas que DESIGN_SIZE) que se añade arriba.
@export var extra_top_ratio: float = 0.15
@export var section_gap: float = 8.0
@export var board_padding: float = 16.0
## Desplazamiento horizontal respecto al centro de la pantalla.
@export var illustration_offset_x: float = -170.0
@export var level_name_offset_x: float = -20.0

## Zona libre para el tablero; se recalcula en layout().
var board_rect: Rect2

@onready var _header: Sprite2D = $Header
@onready var _top_band: Sprite2D = $TopBand
@onready var _illustration: Sprite2D = $Illustration
@onready var _level_name_label: Label = $LevelName
@onready var _middle_band: Sprite2D = $MiddleBand
@onready var _bottom_band: Sprite2D = $BottomBand

func _ready() -> void:
	_level_name_label.text = level_name

# area: zona visible (segura) de la pantalla; bottom_limit: y donde empiezan
# los controles inferiores (botón y dados).
func layout(area: Rect2, bottom_limit: float) -> void:
	var cx := area.get_center().x
	var extra := maxf(0.0, area.size.y - DESIGN_SIZE.y)
	var y := area.position.y + top_margin + extra * extra_top_ratio
	y = _stack(_header, cx, y) + section_gap
	y = _stack(_top_band, cx, y) + section_gap

	var row_h := _height(_illustration)
	_illustration.position = Vector2(cx + illustration_offset_x, y + row_h * 0.5)
	_level_name_label.position = Vector2(
		cx + level_name_offset_x,
		y + (row_h - _level_name_label.size.y) * 0.5)
	y += row_h + section_gap
	y = _stack(_middle_band, cx, y)

	var band_h := _height(_bottom_band)
	var bottom_band_y := bottom_limit - section_gap - band_h * 0.5
	_bottom_band.position = Vector2(cx, bottom_band_y)

	var board_top := y + board_padding
	var board_bottom := bottom_band_y - band_h * 0.5 - board_padding
	board_rect = Rect2(area.position.x, board_top, area.size.x, maxf(0.0, board_bottom - board_top))

func _stack(sprite: Sprite2D, cx: float, top: float) -> float:
	var h := _height(sprite)
	sprite.position = Vector2(cx, top + h * 0.5)
	return top + h

func _height(sprite: Sprite2D) -> float:
	return sprite.texture.get_size().y * sprite.scale.y
