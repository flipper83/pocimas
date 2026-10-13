class_name OperationNode
extends Node2D

const SPRITE_SCALE := 0.403
# "lt" reuses the "gt" texture mirrored horizontally
const TEXTURES: Dictionary = {
	"gt": preload("res://assets/operators/greater.png"),
	"lt": preload("res://assets/operators/greater.png"),
	"eq": preload("res://assets/operators/equal.png"),
	"ne": preload("res://assets/operators/not_equal.png"),
}
const DIRECTIONAL_TYPES: Array = ["gt", "lt"]

var op_type: String = "gt"
var from_elem_idx: int = -1
var to_elem_idx: int = -1
## Escala del tablero; el rebote de show_fail() vuelve a este valor.
var base_scale: Vector2 = Vector2.ONE:
	set(value):
		base_scale = value
		scale = value

@onready var _sprite: Sprite2D = $Sprite2D

func setup(p_type: String, p_pos: Vector2) -> void:
	op_type = p_type
	position = p_pos
	_apply_texture()

func setup_between(p_type: String, pos_a: Vector2, pos_b: Vector2, idx_a: int, idx_b: int) -> void:
	op_type = p_type
	from_elem_idx = idx_a
	to_elem_idx = idx_b
	position = (pos_a + pos_b) * 0.5
	var dir := pos_b - pos_a
	rotation = dir.angle()
	_apply_texture()
	# ">"/"<" follow the from→to direction; symmetric symbols stay upright
	if not DIRECTIONAL_TYPES.has(op_type):
		_sprite.rotation = -rotation

func _apply_texture() -> void:
	_sprite.texture = TEXTURES[op_type]
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_sprite.flip_h = op_type == "lt"

func check(left_val: int, right_val: int) -> bool:
	match op_type:
		"gt": return left_val > right_val
		"lt": return left_val < right_val
		"eq": return left_val == right_val
		"ne": return left_val != right_val
	return true

func show_fail() -> void:
	var t1 := create_tween()
	t1.tween_property(self, "modulate", Color(1.0, 0.2, 0.2, 1.0), 0.08)
	t1.tween_property(self, "modulate", Color.WHITE, 0.45)
	var t2 := create_tween()
	t2.tween_property(self, "scale", base_scale * 1.3, 0.08)
	t2.tween_property(self, "scale", base_scale, 0.2)
