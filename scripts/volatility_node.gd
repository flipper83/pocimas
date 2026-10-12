class_name VolatilityNode
extends Node2D

const BACK_SCALE := 0.55
const ICON_SCALE := 0.55
const DIE_SCALE := 0.25
const DIE_TEXTURE_PATH := "res://assets/dice/black_%d.png"

var die_value: int = 1
var _highlighted: bool = false

@onready var _back: Sprite2D = $BackSprite
@onready var _icon: Sprite2D = $IconSprite
@onready var _die_sprite: Sprite2D = $DieSprite

func _ready() -> void:
	_back.scale = Vector2(BACK_SCALE, BACK_SCALE)
	_icon.scale = Vector2(ICON_SCALE, ICON_SCALE)
	_die_sprite.scale = Vector2(DIE_SCALE, DIE_SCALE)
	_update_texture()

func set_highlighted(enabled: bool) -> void:
	_highlighted = enabled
	modulate = Color(1.2, 1.15, 0.6, 1.0) if enabled else Color.WHITE
	queue_redraw()

func update_value_display() -> void:
	_update_texture()
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.6, 1.6, 0.4, 1.0), 0.08)
	tween.tween_property(self, "modulate", Color.WHITE, 0.28)

# Fuera de 1..6 la partida termina; mostramos la cara más cercana.
func _update_texture() -> void:
	_die_sprite.texture = load(DIE_TEXTURE_PATH % clampi(die_value, 1, 6))

func get_hit_rect() -> Rect2:
	return Rect2(position - Vector2(44, 44), Vector2(88, 88))

func _draw() -> void:
	if not _highlighted:
		return
	var half := Vector2(44.0, 44.0)
	draw_rect(Rect2(-half, half * 2.0), Color(1.0, 0.85, 0.0, 0.95), false, 5.0)
