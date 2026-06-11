extends Node2D

const BG_TEXTURE := preload("res://assets/texture.png")
const DIE_SCENE := preload("res://scenes/die.tscn")
const ELEMENT_SCENE := preload("res://scenes/element.tscn")
const OPERATION_SCENE := preload("res://scenes/operation.tscn")
const VOLATILITY_SCENE := preload("res://scenes/volatility.tscn")

const ELEMENT_TYPES: Array = ["fire", "water", "salt", "grass"]
const OP_TYPES: Array = ["gt", "lt", "eq", "ne"]
const DICE_BOTTOM_MARGIN := 80.0

# Board row layout — 5 elements + 4 operators centered in screen width
# element sprite: 252px * 0.35 = 88.2px  |  operator sprite: 157px * 0.38 = 59.7px
const _ELEM_HALF_W := 44.1
const _OP_HALF_W := 29.85
const _SLOT_W := 147.9  # _ELEM_HALF_W*2 + _OP_HALF_W*2

var _level_data: Dictionary = {}

enum State { IDLE, SELECTING_TARGET }

var _screen_w: float
var _screen_h: float
var _dice: Array = []
var _elements: Array = []
var _operations: Array = []
var _volatility: VolatilityNode = null
var _reroll_btn: Button = null
var _dragged_die: DieNode = null
var _drag_offset: Vector2
var _state: State = State.IDLE
var _pending_effect: String = ""
var _pending_placed_value: int = 0
var _overlay: ColorRect = null
var _game_over: bool = false

func load_level(data: Dictionary) -> void:
	_level_data = data

func _ready() -> void:
	var rect := get_viewport().get_visible_rect()
	_screen_w = rect.size.x
	_screen_h = rect.size.y
	randomize()
	_setup_background()
	_setup_overlay()
	_setup_volatility()
	if _level_data.is_empty():
		_level_data = LevelLoader.load_from_file("res://assets/levels/level.json")
	if _level_data.is_empty():
		_setup_elements()
		_setup_dice()
	else:
		_setup_elements_from_level()
		_setup_dice_from_level()
	_setup_reroll_button()

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

func _setup_volatility() -> void:
	_volatility = VOLATILITY_SCENE.instantiate()
	add_child(_volatility)
	_volatility.position = Vector2(_screen_w * 0.5, _screen_h * 0.22)
	_volatility.z_index = 1

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

func _grid_to_screen(gx: int, gy: int, grid_unit: int, origin: Vector2) -> Vector2:
	return origin + Vector2(gx * grid_unit, gy * grid_unit)

func _setup_elements_from_level() -> void:
	var grid_unit: int = _level_data.get("grid_unit", 110)
	var elems_data: Array = _level_data.get("elements", [])
	var ops_data: Array = _level_data.get("operations", [])
	var vol_data: Dictionary = _level_data.get("volatility", {})

	# Compute bounding box using all elements (including "vol" type)
	var min_gx := 99999; var max_gx := -99999
	var min_gy := 99999; var max_gy := -99999
	for e: Dictionary in elems_data:
		min_gx = mini(min_gx, e.get("gx", 0)); max_gx = maxi(max_gx, e.get("gx", 0))
		min_gy = mini(min_gy, e.get("gy", 0)); max_gy = maxi(max_gy, e.get("gy", 0))
	# Legacy: separate volatility field (old format)
	if not vol_data.is_empty():
		min_gx = mini(min_gx, vol_data.get("gx", 0)); max_gx = maxi(max_gx, vol_data.get("gx", 0))
		min_gy = mini(min_gy, vol_data.get("gy", 0)); max_gy = maxi(max_gy, vol_data.get("gy", 0))
	if min_gx == 99999: min_gx = 0; if max_gx == -99999: max_gx = 0
	if min_gy == 99999: min_gy = 0; if max_gy == -99999: max_gy = 0

	var level_w := (max_gx - min_gx) * grid_unit
	var level_h := (max_gy - min_gy) * grid_unit
	var origin := Vector2(
		(_screen_w - level_w) * 0.5 - min_gx * grid_unit,
		(_screen_h * 0.25 + (_screen_h * 0.55 - level_h) * 0.5) - min_gy * grid_unit
	)

	# Legacy separate volatility field
	if not vol_data.is_empty():
		_volatility.position = _grid_to_screen(vol_data.get("gx", 0), vol_data.get("gy", 0), grid_unit, origin)

	# Elements — "vol" type positions the volatility node, not an ElementNode
	var elem_by_id: Dictionary = {}
	for e: Dictionary in elems_data:
		var type: String = e.get("type", "fire")
		var pos := _grid_to_screen(e.get("gx", 0), e.get("gy", 0), grid_unit, origin)
		if type == "vol":
			_volatility.position = pos
			continue
		var elem: ElementNode = ELEMENT_SCENE.instantiate()
		add_child(elem)
		elem.setup(type, pos)
		_elements.append(elem)
		elem_by_id[int(e.get("id", _elements.size() - 1))] = _elements.size() - 1

	# Operations
	for o: Dictionary in ops_data:
		var from_id: int = o.get("from", 0)
		var to_id: int = o.get("to", 1)
		if not elem_by_id.has(from_id) or not elem_by_id.has(to_id):
			continue
		var idx_a: int = elem_by_id[from_id]
		var idx_b: int = elem_by_id[to_id]
		var pos_a: Vector2 = (_elements[idx_a] as ElementNode).position
		var pos_b: Vector2 = (_elements[idx_b] as ElementNode).position
		var op: OperationNode = OPERATION_SCENE.instantiate()
		add_child(op)
		op.z_index = 1
		op.setup_between(o.get("type", "gt"), pos_a, pos_b, idx_a, idx_b)
		_operations.append(op)

func _setup_dice_from_level() -> void:
	var dice_counts: Dictionary = _level_data.get("dice", {"red": 2, "white": 1, "green": 2, "blue": 2})
	var colors: Array = []
	for color: String in dice_counts:
		for _i in dice_counts[color]:
			colors.append(color)
	colors.shuffle()
	var spacing := _screen_w / float(colors.size())
	var dice_y := _screen_h - DICE_BOTTOM_MARGIN
	for i in colors.size():
		var die: DieNode = DIE_SCENE.instantiate()
		add_child(die)
		var pos := Vector2(spacing * 0.5 + spacing * i, dice_y)
		die.setup(colors[i], randi_range(1, 6), pos)
		die.z_index = 1
		die.animate_appear(i * 0.08)
		_dice.append(die)

func _setup_reroll_button() -> void:
	_reroll_btn = Button.new()
	_reroll_btn.text = "↺  Relanzar"
	_reroll_btn.add_theme_font_size_override("font_size", 28)
	_reroll_btn.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.35, 0.92)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 16
	style.content_margin_right = 16
	_reroll_btn.add_theme_stylebox_override("normal", style)
	var style_hover := style.duplicate() as StyleBoxFlat
	style_hover.bg_color = Color(0.25, 0.25, 0.5, 0.95)
	_reroll_btn.add_theme_stylebox_override("hover", style_hover)
	_reroll_btn.size = Vector2(240, 64)
	_reroll_btn.position = Vector2((_screen_w - 240) * 0.5, _screen_h * 0.78)
	_reroll_btn.pressed.connect(_on_reroll_pressed)
	add_child(_reroll_btn)

func _input(event: InputEvent) -> void:
	if _game_over:
		return
	var pos := _event_pos(event)
	if pos == Vector2.INF:
		return

	if _state == State.SELECTING_TARGET:
		if _is_press(event):
			if _volatility.get_hit_rect().has_point(pos):
				_apply_to_volatility()
				return
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
	if _level_data.is_empty():
		# Random mode: linear row, operations indexed by gap position
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
	else:
		# Level mode: check all ops that reference this element
		for op: OperationNode in _operations:
			if op.from_elem_idx == elem_index:
				var other_val := (_elements[op.to_elem_idx] as ElementNode).placed_die_value
				if other_val != -1 and not op.check(die_value, other_val):
					return op
			elif op.to_elem_idx == elem_index:
				var other_val := (_elements[op.from_elem_idx] as ElementNode).placed_die_value
				if other_val != -1 and not op.check(other_val, die_value):
					return op
	return null

func _apply_element_effect(element_type: String, placed_value: int) -> void:
	match element_type:
		"fire", "water", "grass":
			_enter_selection_mode(element_type, placed_value)
		"salt":
			pass

func _enter_selection_mode(effect: String, placed_value: int) -> void:
	_state = State.SELECTING_TARGET
	_pending_effect = effect
	_pending_placed_value = placed_value
	_overlay.visible = true
	for die: DieNode in _dice:
		if not die.is_placed:
			die.set_highlighted(true)
			die.z_index = 6
	_volatility.set_highlighted(true)
	_volatility.z_index = 6

func _exit_selection_mode() -> void:
	_state = State.IDLE
	_overlay.visible = false
	for die: DieNode in _dice:
		die.set_highlighted(false)
		if not die.is_placed:
			die.z_index = 1
	_volatility.set_highlighted(false)
	_volatility.z_index = 1

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

func _apply_to_volatility() -> void:
	_exit_selection_mode()
	var new_value: int
	match _pending_effect:
		"fire": new_value = _volatility.die_value + _pending_placed_value
		"water": new_value = _volatility.die_value - _pending_placed_value
		"grass": new_value = 7 - _volatility.die_value
	_volatility.die_value = new_value
	_volatility.update_value_display()
	if new_value > 6:
		var t := create_tween()
		t.tween_interval(0.4)
		t.tween_callback(_show_game_over.bind(true))
	elif new_value < 1:
		var t := create_tween()
		t.tween_interval(0.4)
		t.tween_callback(_show_game_over.bind(false))

func _on_reroll_pressed() -> void:
	if _game_over:
		return
	for die: DieNode in _dice:
		if not die.is_placed:
			die.die_value = randi_range(1, 6)
			die.update_value_display()
	_volatility.die_value += 1
	_volatility.update_value_display()
	if _volatility.die_value > 6:
		var t := create_tween()
		t.tween_interval(0.35)
		t.tween_callback(_show_game_over.bind(true))

func _show_game_over(is_explosion: bool) -> void:
	_game_over = true
	if _reroll_btn:
		_reroll_btn.disabled = true

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.84)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)

	var title := Label.new()
	title.text = "¡La poción es inestable!" if is_explosion else "¡Sopa repugnante!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.size = Vector2(_screen_w * 0.85, 150)
	title.position = Vector2(_screen_w * 0.075, _screen_h * 0.28)
	layer.add_child(title)

	var msg := Label.new()
	msg.text = "Limpia el laboratorio,\nrepara lo que haya explotado\ny vuelve a empezar." \
		if is_explosion else \
		"La poción se ha neutralizado.\nAcabas de preparar\nuna sopa repugnante."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", 32)
	msg.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1.0))
	msg.size = Vector2(_screen_w * 0.85, 220)
	msg.position = Vector2(_screen_w * 0.075, _screen_h * 0.43)
	layer.add_child(msg)

	var btn := Button.new()
	btn.text = "Volver a empezar"
	btn.add_theme_font_size_override("font_size", 34)
	btn.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.12, 0.05, 0.95)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 20
	style.content_margin_right = 20
	btn.add_theme_stylebox_override("normal", style)
	var style_hover := style.duplicate() as StyleBoxFlat
	style_hover.bg_color = Color(0.45, 0.22, 0.08, 0.98)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.size = Vector2(_screen_w * 0.65, 76)
	btn.position = Vector2(_screen_w * 0.175, _screen_h * 0.63)
	btn.pressed.connect(func(): get_tree().reload_current_scene())
	layer.add_child(btn)

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
