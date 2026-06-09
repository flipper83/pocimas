class_name DieNode
extends Node2D

const SPRITE_SCALE := 0.5
const TEXTURES: Dictionary = {
	"red": preload("res://assets/rojo.png"),
	"white": preload("res://assets/blanco.png"),
	"green": preload("res://assets/gren.png"),
	"blue": preload("res://assets/blue.png"),
}
const ELEMENT_MAP: Dictionary = {
	"red": "fire",
	"white": "salt",
	"green": "grass",
	"blue": "water",
}

var color_key: String = ""
var die_value: int = 1
var home_position: Vector2
var is_placed: bool = false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _label: Label = $Label

var _active_tween: Tween = null

func setup(p_color: String, p_value: int, p_pos: Vector2) -> void:
	color_key = p_color
	die_value = p_value
	home_position = p_pos
	position = p_pos
	_sprite.texture = TEXTURES[color_key]
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_label.text = str(die_value)
	var font_color := Color.BLACK if color_key == "white" else Color.WHITE
	_label.add_theme_color_override("font_color", font_color)

func animate_appear(delay: float = 0.0) -> void:
	scale = Vector2.ZERO
	if _active_tween:
		_active_tween.kill()
	_active_tween = create_tween()
	if delay > 0.0:
		_active_tween.tween_interval(delay)
	_active_tween.tween_property(self, "scale", Vector2.ONE, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func animate_return() -> void:
	if _active_tween:
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.tween_property(self, "position", home_position, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func cancel_animation() -> void:
	if _active_tween:
		_active_tween.kill()
		_active_tween = null

func matches_element(element_type: String) -> bool:
	return ELEMENT_MAP.get(color_key, "") == element_type

func get_hit_rect() -> Rect2:
	if not _sprite or not _sprite.texture:
		return Rect2(position - Vector2(44, 46), Vector2(88, 92))
	var half := _sprite.texture.get_size() * SPRITE_SCALE * 0.5
	return Rect2(position - half, half * 2.0)
