class_name OperationNode
extends Node2D

const SPRITE_SCALE := 0.38
const SYMBOLS: Dictionary = {
	"gt": ">",
	"lt": "<",
	"eq": "=",
}

var op_type: String = "gt"

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _label: Label = $Label

func setup(p_type: String, p_pos: Vector2) -> void:
	op_type = p_type
	position = p_pos
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_label.text = SYMBOLS[op_type]

func check(left_val: int, right_val: int) -> bool:
	match op_type:
		"gt": return left_val > right_val
		"lt": return left_val < right_val
		"eq": return left_val == right_val
	return true

func show_fail() -> void:
	var t1 := create_tween()
	t1.tween_property(self, "modulate", Color(1.0, 0.2, 0.2, 1.0), 0.08)
	t1.tween_property(self, "modulate", Color.WHITE, 0.45)
	var t2 := create_tween()
	t2.tween_property(self, "scale", Vector2(1.3, 1.3), 0.08)
	t2.tween_property(self, "scale", Vector2.ONE, 0.2)
