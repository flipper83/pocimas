class_name Tutorial
extends CanvasLayer

# Explicación breve de las reglas; se cierra con el botón.

signal closed

@export var fade_time: float = 0.25

var _closing: bool = false

@onready var _root: Control = $Root
@onready var _close_button: Button = %CloseButton

func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, fade_time)

func _on_close_pressed() -> void:
	if _closing:
		return
	_closing = true
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, fade_time)
	tween.tween_callback(_on_faded_out)

func _on_faded_out() -> void:
	closed.emit()
	queue_free()
