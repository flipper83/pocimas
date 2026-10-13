class_name SplashScreen
extends CanvasLayer

# Portada al arrancar: se muestra un rato y se desvanece. Un toque la salta.

signal finished

@export var display_time: float = 2.5
@export var fade_time: float = 0.5

var _closing: bool = false

@onready var _root: Control = $Root

func _ready() -> void:
	_root.gui_input.connect(_on_root_gui_input)
	var tween := create_tween()
	tween.tween_interval(display_time)
	tween.tween_callback(close)

func close() -> void:
	if _closing:
		return
	_closing = true
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, fade_time)
	tween.tween_callback(_on_faded_out)

func _on_faded_out() -> void:
	finished.emit()
	queue_free()

func _on_root_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
