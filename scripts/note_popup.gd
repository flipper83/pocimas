class_name NotePopup
extends CanvasLayer

# Panel de texto a pantalla completa (introducción, reglas); se cierra con el botón.
# Si el contenido no cabe en pantalla, la parte central hace scroll.

signal closed

@export var fade_time: float = 0.25
@export var screen_margin: float = 40.0

var _closing: bool = false

@onready var _root: Control = $Root
@onready var _panel: PanelContainer = %Panel
@onready var _layout_box: VBoxContainer = %Layout
@onready var _scroll: ScrollContainer = %Scroll
@onready var _content: Control = %Content
@onready var _close_button: Button = %CloseButton

func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	_content.minimum_size_changed.connect(_fit_to_screen)
	get_viewport().size_changed.connect(_fit_to_screen)
	_fit_to_screen.call_deferred()
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, fade_time)

# Limita el alto del scroll a lo que queda libre en pantalla.
func _fit_to_screen() -> void:
	var style := _panel.get_theme_stylebox("panel")
	var chrome := style.get_minimum_size().y
	var separation := _layout_box.get_theme_constant("separation") * (_layout_box.get_child_count() - 1)
	for child: Control in _layout_box.get_children():
		if child != _scroll:
			chrome += child.get_combined_minimum_size().y
	var available := get_viewport().get_visible_rect().size.y - screen_margin * 2.0 - chrome - separation
	_scroll.custom_minimum_size.y = clampf(_content.get_combined_minimum_size().y, 0.0, maxf(available, 120.0))

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
