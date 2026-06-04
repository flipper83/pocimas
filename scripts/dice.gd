class_name Dice
extends Node2D

const ROLL_FPS := 12.0
const PEAK_FRAME := 4   # frame where die reaches max height
const LAND_FRAME := 8   # frame where die lands back at base
const THROW_HEIGHT := 120.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shadow: Node2D = $"../Shadow"
@onready var dado_label: Label = $"../DadoLabel"
@onready var dice_area: Area2D = $DiceArea

var current_face: int = 1
var is_rolling: bool = false
var base_y: float

func _ready() -> void:
	base_y = position.y
	sprite.animation_finished.connect(_on_roll_finished)
	dice_area.input_event.connect(_on_input_event)
	_show_face(1)

func _process(_delta: float) -> void:
	var height := base_y - position.y
	var t := clampf(height / THROW_HEIGHT, 0.0, 1.0)
	shadow.scale = Vector2.ONE * lerpf(1.0, 0.4, t)
	shadow.modulate.a = lerpf(1.0, 0.2, t)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and not is_rolling:
		_roll()

func _roll() -> void:
	is_rolling = true
	sprite.play("roll")

	var peak_t := PEAK_FRAME / ROLL_FPS          # 0.333 s — rise
	var fall_t := (LAND_FRAME - PEAK_FRAME) / ROLL_FPS  # 0.333 s — fall

	var tween := create_tween()
	tween.tween_property(self, "position:y", base_y - THROW_HEIGHT, peak_t) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:y", base_y, fall_t) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

func _on_roll_finished() -> void:
	if sprite.animation != "roll":
		return
	current_face = randi_range(1, 6)
	_show_face(current_face)
	position.y = base_y
	is_rolling = false

func _show_face(face: int) -> void:
	current_face = face
	sprite.play("face_%d" % face)
	dado_label.text = "Dado: %d" % face
