class_name ElementNode
extends Node2D

const SPRITE_SCALE := 0.42
const TEXTURES: Dictionary = {
	"fire": preload("res://assets/ingredients/fire.png"),
	"water": preload("res://assets/ingredients/water.png"),
	"salt": preload("res://assets/ingredients/salt.png"),
	"grass": preload("res://assets/ingredients/soil.png"),
}

enum Highlight { NONE, VALID, BLOCKED }

const HIGHLIGHT_COLORS: Dictionary = {
	Highlight.VALID: Color(0.3, 0.85, 0.35),
	Highlight.BLOCKED: Color(0.95, 0.25, 0.2),
}
const HIGHLIGHT_PADDING := 6.0
const HIGHLIGHT_PULSE_TIME := 0.45

var element_type: String = ""
var placed_die_value: int = -1

var _highlight: Highlight = Highlight.NONE
var _glow: float = 0.0
var _glow_tween: Tween = null

@onready var _frame: Sprite2D = $Frame
@onready var _icon: Sprite2D = $Icon

func setup(p_type: String, p_pos: Vector2) -> void:
	element_type = p_type
	position = p_pos
	_icon.texture = TEXTURES[element_type]
	_icon.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_frame.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)

func show_fail() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.2, 0.2, 1.0), 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.5)

# Brillo que late mientras se arrastra un dado: verde si se puede poner aquí,
# rojo si el color y la adyacencia encajan pero se incumple algún operador.
func set_highlight(highlight: Highlight) -> void:
	if highlight == _highlight:
		return
	_highlight = highlight
	if _glow_tween:
		_glow_tween.kill()
		_glow_tween = null
	if highlight != Highlight.NONE:
		_glow_tween = create_tween().set_loops()
		_glow_tween.tween_method(_set_glow, 0.35, 1.0, HIGHLIGHT_PULSE_TIME).set_trans(Tween.TRANS_SINE)
		_glow_tween.tween_method(_set_glow, 1.0, 0.35, HIGHLIGHT_PULSE_TIME).set_trans(Tween.TRANS_SINE)
	else:
		_set_glow(0.0)

func _set_glow(value: float) -> void:
	_glow = value
	queue_redraw()

func _draw() -> void:
	if _glow <= 0.0 or _highlight == Highlight.NONE:
		return
	var color: Color = HIGHLIGHT_COLORS[_highlight]
	var half := _local_half_size() + Vector2(HIGHLIGHT_PADDING, HIGHLIGHT_PADDING)
	var rect := Rect2(-half, half * 2.0)
	var fill := color
	fill.a = 0.3 * _glow
	draw_rect(rect, fill, true)
	var outline := color
	outline.a = _glow
	draw_rect(rect, outline, false, 5.0)

# Medio tamaño del marco en coordenadas locales (sin la escala del nodo).
func _local_half_size() -> Vector2:
	if not _frame or not _frame.texture:
		return Vector2(44, 45)
	return _frame.texture.get_size() * SPRITE_SCALE * 0.5

func get_hit_rect() -> Rect2:
	var half := _local_half_size() * scale
	return Rect2(position - half, half * 2.0)
