class_name ElementNode
extends Node2D

const SPRITE_SCALE := 0.45
const TEXTURES: Dictionary = {
	"fire": preload("res://assets/fuego.png"),
	"water": preload("res://assets/agua.png"),
	"salt": preload("res://assets/sal.png"),
	"grass": preload("res://assets/hierba.png"),
}

var element_type: String = ""

@onready var _sprite: Sprite2D = $Sprite2D

func setup(p_type: String, p_pos: Vector2) -> void:
	element_type = p_type
	position = p_pos
	_sprite.texture = TEXTURES[element_type]
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)

func show_fail() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.2, 0.2, 1.0), 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.5)

func get_hit_rect() -> Rect2:
	if not _sprite or not _sprite.texture:
		return Rect2(position - Vector2(56, 58), Vector2(113, 116))
	var half := _sprite.texture.get_size() * SPRITE_SCALE * 0.5
	return Rect2(position - half, half * 2.0)
