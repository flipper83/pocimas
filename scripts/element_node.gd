class_name ElementNode
extends Node2D

const SPRITE_SCALE := 0.35
const TEXTURES: Dictionary = {
	"fire": preload("res://assets/ingredients/fire.png"),
	"water": preload("res://assets/ingredients/water.png"),
	"salt": preload("res://assets/ingredients/salt.png"),
	"grass": preload("res://assets/ingredients/soil.png"),
}

var element_type: String = ""
var placed_die_value: int = -1

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

func get_hit_rect() -> Rect2:
	if not _frame or not _frame.texture:
		return Rect2(position - Vector2(44, 45), Vector2(88, 90))
	var half := _frame.texture.get_size() * SPRITE_SCALE * 0.5
	return Rect2(position - half, half * 2.0)
