class_name DieNode
extends Node2D

const DEFAULT_SIZE := 88.0
const TEXTURE_PATH := "res://assets/dice/%s_%d.png"
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
var display_size: float = DEFAULT_SIZE

@onready var _sprite: Sprite2D = $Sprite2D

var _active_tween: Tween = null
var _highlighted: bool = false

func setup(p_color: String, p_value: int, p_pos: Vector2, p_size: float = DEFAULT_SIZE) -> void:
	color_key = p_color
	die_value = p_value
	home_position = p_pos
	position = p_pos
	display_size = p_size
	_update_texture()

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

func set_highlighted(enabled: bool) -> void:
	_highlighted = enabled
	modulate = Color(1.2, 1.15, 0.6, 1.0) if enabled else Color.WHITE
	queue_redraw()

func update_value_display() -> void:
	_update_texture()
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.6, 1.6, 0.4, 1.0), 0.08)
	tween.tween_property(self, "modulate", Color.WHITE, 0.28)

func _update_texture() -> void:
	_sprite.texture = load(TEXTURE_PATH % [color_key, die_value])
	var s := display_size / _sprite.texture.get_size().x
	_sprite.scale = Vector2(s, s)

func matches_element(element_type: String) -> bool:
	return ELEMENT_MAP.get(color_key, "") == element_type

func get_hit_rect() -> Rect2:
	var half := Vector2(display_size, display_size) * 0.5
	return Rect2(position - half, half * 2.0)

func _draw() -> void:
	if not _highlighted:
		return
	var half := Vector2(display_size, display_size) * 0.5
	draw_rect(Rect2(-half, half * 2.0), Color(1.0, 0.85, 0.0, 0.95), false, 5.0)
