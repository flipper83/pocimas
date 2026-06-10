extends Node2D

const BG_TEXTURE := preload("res://assets/texture.png")
const DIE_SCENE := preload("res://scenes/die.tscn")
const ELEMENT_SCENE := preload("res://scenes/element.tscn")
const OPERATION_SCENE := preload("res://scenes/operation.tscn")

const ELEMENT_TYPES: Array = ["fire", "water", "salt", "grass"]
const OP_TYPES: Array = ["gt", "lt", "eq"]
const DICE_BOTTOM_MARGIN := 80.0

# Board row layout — 5 elements + 4 operators, centered in screen width
# element sprite: 252px * 0.35 = 88.2px  |  operator sprite: 157px * 0.38 = 59.7px
const _ELEM_HALF_W := 44.1
const _OP_HALF_W := 29.85
const _SLOT_W := 147.9  # _ELEM_HALF_W*2 + _OP_HALF_W*2

enum State { IDLE, SELECTING_TARGET }

var _screen_w: float
var _screen_h: float
var _dice: Array = []
var _elements: Array = []
var _operations: Array = []
var _dragged_die: DieNode = null
var _drag_offset: Vector2
var _state: State = State.IDLE
var _pending_effect: String = ""
var _pending_placed_value: int = 0
var _overlay: ColorRect = null

func _ready() -> void:
	var rect := get_viewport().get_visible_rect()
	_screen_w = rect.size.x
	_screen_h = rect.size.y
	randomize()
	_setup_background()
	_setup_overlay()
	_setup_elements()
	_setup_dice()

func _setup_background() -> void:
	var bg := Sprite2D.new()
	bg.texture = BG_TEXTURE
	bg.z_index = -10
	bg.position = Vector2(_screen_w * 0.5, _screen_h * 0.5)
	var tex_size := bg.texture.get_size()
	var cover_scale := maxf(_screen_w / tex_size.x, _screen_h / tex_size.y)
	bg.scale = Vector2(cover_scale, cover_scale)
	add_child(bg)

func _setup_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.5)
	_overlay.z_index = 5
	_overlay.size = Vector2(_screen_w, _screen_h)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	add_child(_overlay)

func _setup_elements() -> void:
	var total_w := 5.0 * _ELEM_HALF_W * 2.0 + 4.0 * _OP_HALF_W * 2.0
	var start_x := (_screen_w - total_w) * 0.5 + _ELEM_HALF_W
	var row_y := _screen_h * 0.42

	for i in 5:
		var elem_x := start_x + i * _SLOT_W
		var elem: ElementNode = ELEMENT_SCENE.instantiate()
		add_child(elem)
		elem.setup(ELEMENT_TYPES[randi() % ELEMENT_TYPES.size()], Vector2(elem_x, row_y))
		_elements.append(elem)

		if i < 4:
			var op_x := elem_x + _ELEM_HALF_W + _OP_HALF_W
			var op: OperationNode = OPERATION_SCENE.instantiate()
			add_child(op)
			op.setup(OP_TYPES[randi() % OP_TYPES.size()], Vector2(op_x, row_y))
			_operations.append(op)

func _setup_dice() -> void:
	var colors: Array = ["red", "red", "white", "green", "green", "blue", "blue"]
	colors.shuffle()
	var spacing := _screen_w / 7.0
	var dice_y := _screen_h - DICE_BOTTOM_MARGIN
	for i in 7:
		var die: DieNode = DIE_SCENE.instantiate()
		add_child(die)
		var pos := Vector2(spacing * 0.5 + spacing * i, dice_y)
		die.setup(colors[i], randi_range(1, 6), pos)
		die.z_index = 1
		die.animate_appear(i * 0.08)
		_dice.append(die)

func _input(event: InputEvent) -> void:
	var pos := _event_pos(event)
	if pos == Vector2.INF:
		return

	if _state == State.SELECTING_TARGET:
		if _is_press(event):
			for die: DieNode in _dice:
				if not die.is_placed and die.get_hit_rect().has_point(pos):
					_apply_to_die(die)
					break
		return

	if _is_press(event):
		if not _dragged_die:
			for die: DieNode in _dice:
				if not die.is_placed and die.get_hit_rect().has_point(pos):
					_dragged_die = die
					_drag_offset = die.position - pos
					die.cancel_animation()
					die.z_index = 10
					break
	elif _is_release(event):
		if _dragged_die:
			_try_drop(pos)
	elif _is_motion(event):
		if _dragged_die:
			_dragged_die.position = pos + _drag_offset

func _try_drop(drop_pos: Vector2) -> void:
	var die := _dragged_die
	_dragged_die = null
	die.z_index = 1

	for i in _elements.size():
		var elem: ElementNode = _elements[i]
		if not elem.get_hit_rect().has_point(drop_pos):
			continue
		if elem.placed_die_value != -1:
			die.animate_return()
			return
		if not die.matches_element(elem.element_type):
			elem.show_fail()
			die.animate_return()
			return
		var violated_op := _find_violated_op(die.die_value, i)
		if violated_op:
			violated_op.show_fail()
			die.animate_return()
			return
		die.position = elem.position
		die.home_position = elem.position
		die.is_placed = true
		elem.placed_die_value = die.die_value
		_apply_element_effect(elem.element_type, die.die_value)
		return

	die.animate_return()

func _find_violated_op(die_value: int, elem_index: int) -> OperationNode:
	if elem_index > 0:
		var left_val := (_elements[elem_index - 1] as ElementNode).placed_die_value
		if left_val != -1:
			var op := _operations[elem_index - 1] as OperationNode
			if not op.check(left_val, die_value):
				return op
	if elem_index < _elements.size() - 1:
		var right_val := (_elements[elem_index + 1] as ElementNode).placed_die_value
		if right_val != -1:
			var op := _operations[elem_index] as OperationNode
			if not op.check(die_value, right_val):
				return op
	return null

func _apply_element_effect(element_type: String, placed_value: int) -> void:
	match element_type:
		"fire", "water", "grass":
			_enter_selection_mode(element_type, placed_value)
		"salt":
			pass

func _enter_selection_mode(effect: String, placed_value: int) -> void:
	var available: Array = _dice.filter(func(d: DieNode): return not d.is_placed)
	if available.is_empty():
		return
	_state = State.SELECTING_TARGET
	_pending_effect = effect
	_pending_placed_value = placed_value
	_overlay.visible = true
	for die: DieNode in _dice:
		if not die.is_placed:
			die.set_highlighted(true)
			die.z_index = 6

func _exit_selection_mode() -> void:
	_state = State.IDLE
	_overlay.visible = false
	for die: DieNode in _dice:
		die.set_highlighted(false)
		if not die.is_placed:
			die.z_index = 1

func _apply_to_die(die: DieNode) -> void:
	_exit_selection_mode()
	match _pending_effect:
		"fire":
			die.die_value = ((die.die_value - 1 + _pending_placed_value) % 6) + 1
		"water":
			die.die_value = ((die.die_value - 1 - _pending_placed_value) % 6 + 6) % 6 + 1
		"grass":
			die.die_value = 7 - die.die_value
	die.update_value_display()

func _event_pos(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		return event.position
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return event.position
	return Vector2.INF

func _is_press(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	if event is InputEventScreenTouch:
		return event.pressed
	return false

func _is_release(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.button_index == MOUSE_BUTTON_LEFT and not event.pressed
	if event is InputEventScreenTouch:
		return not event.pressed
	return false

func _is_motion(event: InputEvent) -> bool:
	return event is InputEventMouseMotion or event is InputEventScreenDrag
