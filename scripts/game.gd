extends Node2D

const BG_TEXTURE := preload("res://assets/backgrounds/background.jpg")
const NOTE_TEXTURE := preload("res://assets/ui/note_panel.png")
const LEVEL_PAGE_SCENE := preload("res://scenes/level_page.tscn")
const DIE_SCENE := preload("res://scenes/die.tscn")
const ELEMENT_SCENE := preload("res://scenes/element.tscn")
const OPERATION_SCENE := preload("res://scenes/operation.tscn")
const VOLATILITY_SCENE := preload("res://scenes/volatility.tscn")

const ELEMENT_TYPES: Array = ["fire", "water", "salt", "grass"]
const LEVEL_DISPLAY_SCALE := 1.15  # separación de diseño; el tablero se reduce si no cabe
const BOARD_SIDE_MARGIN := 24.0
const BOARD_CELL_SIZE := 120.0  # tamaño de una pieza (marco + etiqueta) a escala 1
const OP_TYPES: Array = ["gt", "lt", "eq", "ne"]
const DICE_BOTTOM_MARGIN := 80.0
const DICE_EXTRA_MARGIN_RATIO := 0.1  # parte del alto sobrante (móviles alargados) que sube los dados
const MAX_DIE_SPACING := 90.0
const REROLL_BTN_SIZE := Vector2(240, 64)
const REROLL_BTN_GAP := 20.0  # separación entre el botón y la parte superior de los dados
const DIE_SIZE_RATIO := 0.9  # tamaño del dado respecto a la separación entre dados
const POWER_HINT_TOP := 40.0
const NOTE_TEXT_COLOR := Color(0.99, 0.95, 0.86, 1.0)
const NOTE_DETAIL_COLOR := Color(0.88, 0.93, 0.9, 1.0)
const POWER_HINT_WIDTH_RATIO := 0.88

# Modo aleatorio (sin nivel): 5 elementos en fila, separados por un operador
const _RANDOM_ROW_SLOT := 147.9  # ancho de elemento + operador
const _RANDOM_VOL_GRID := Vector2(8, 3)

var _level_data: Dictionary = {}
var _page: LevelPage = null

enum State { IDLE, SELECTING_TARGET }
enum Outcome { EXPLOSION, SOUP, POTION_READY }

var _background: Sprite2D = null
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
var _power_hint: PanelContainer = null
var _power_hint_title: Label = null
var _power_hint_detail: Label = null
var _game_over: bool = false

# Posición lógica del tablero en celdas de rejilla; se pasa a pantalla en _layout_board().
var _elem_grid: Array[Vector2] = []
var _vol_grid: Vector2 = Vector2.ZERO
var _grid_base_unit: float = 110.0
var _grid_max_scale: float = LEVEL_DISPLAY_SCALE
# Dado colocado → elemento en el que está, para recolocarlo si cambia el tamaño.
var _placed_on: Dictionary = {}

func load_level(data: Dictionary) -> void:
	_level_data = data

func _ready() -> void:
	randomize()
	_setup_background()
	_setup_page()
	_setup_overlay()
	_setup_power_hint()
	_setup_volatility()
	if _level_data.is_empty():
		_level_data = LevelLoader.load_from_file("res://assets/levels/level.json")
	if _level_data.is_empty():
		_setup_elements()
		_setup_dice()
	else:
		_page.level_name = _level_data.get("name", _page.level_name)
		_setup_elements_from_level()
		_setup_dice_from_level()
	_setup_reroll_button()
	_layout()
	# En web móvil el alto cambia al mostrar/ocultar la barra del navegador.
	get_viewport().size_changed.connect(_layout)

# --- Layout -----------------------------------------------------------------
# La columna de juego mide LevelPage.DESIGN_SIZE.x de ancho y se centra; con
# stretch "expand" el alto crece en móviles alargados y ese sobrante se reparte.

func _layout() -> void:
	var view := get_viewport().get_visible_rect()
	var safe := _safe_rect(view)
	var extra_h := maxf(0.0, safe.size.y - LevelPage.DESIGN_SIZE.y)
	var center_x := safe.get_center().x

	_background.position = view.get_center()
	var tex_size := _background.texture.get_size()
	var cover_scale := maxf(view.size.x / tex_size.x, view.size.y / tex_size.y)
	_background.scale = Vector2(cover_scale, cover_scale)
	_overlay.position = view.position
	_overlay.size = view.size

	var dice_y := safe.end.y - DICE_BOTTOM_MARGIN - extra_h * DICE_EXTRA_MARGIN_RATIO
	var dice_top := dice_y - _die_spacing() * DIE_SIZE_RATIO * 0.5
	var reroll_top := dice_top - REROLL_BTN_GAP - REROLL_BTN_SIZE.y
	_reroll_btn.position = Vector2(center_x - REROLL_BTN_SIZE.x * 0.5, reroll_top)
	_power_hint.position = Vector2(center_x - _power_hint.size.x * 0.5, safe.position.y + POWER_HINT_TOP)

	_page.layout(safe, reroll_top)
	_layout_board()
	_layout_dice(center_x, dice_y)

# Zona segura (notch, barra de gestos) en coordenadas del viewport; solo la
# reportan las plataformas móviles nativas.
func _safe_rect(view: Rect2) -> Rect2:
	if not OS.has_feature("mobile"):
		return view
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var window := Vector2(DisplayServer.window_get_size())
	if safe.size == Vector2.ZERO or window == Vector2.ZERO:
		return view
	var k := view.size / window
	return Rect2(view.position + safe.position * k, safe.size * k)

func _layout_board() -> void:
	var board := _page.board_rect
	var min_g := _vol_grid
	var max_g := _vol_grid
	for g: Vector2 in _elem_grid:
		min_g = min_g.min(g)
		max_g = max_g.max(g)
	var span := max_g - min_g

	# Si el nivel no cabe entre las cenefas se escala entero (separación y
	# piezas a la vez), así se mantienen las proporciones del diseño.
	var design_unit := _grid_base_unit * _grid_max_scale
	var needed := span * design_unit + Vector2.ONE * BOARD_CELL_SIZE  # tamaño a escala 1
	var avail := Vector2(
		minf(board.size.x, LevelPage.DESIGN_SIZE.x) - BOARD_SIDE_MARGIN * 2.0,
		board.size.y)
	var board_scale := minf(1.0, minf(avail.x / needed.x, avail.y / needed.y))
	var grid_unit := design_unit * board_scale
	var piece_scale := Vector2(board_scale, board_scale)
	var origin := board.get_center() - (min_g + span * 0.5) * grid_unit

	for i in _elements.size():
		var elem: ElementNode = _elements[i]
		elem.position = origin + _elem_grid[i] * grid_unit
		elem.scale = piece_scale
	_volatility.position = origin + _vol_grid * grid_unit
	_volatility.scale = piece_scale
	for op: OperationNode in _operations:
		var pos_a: Vector2 = (_elements[op.from_elem_idx] as ElementNode).position
		var pos_b: Vector2 = (_elements[op.to_elem_idx] as ElementNode).position
		op.position = (pos_a + pos_b) * 0.5
		op.base_scale = piece_scale

func _die_spacing() -> float:
	return minf(MAX_DIE_SPACING, LevelPage.DESIGN_SIZE.x * 0.92 / maxf(1.0, _dice.size()))

func _layout_dice(center_x: float, dice_y: float) -> void:
	var spacing := _die_spacing()
	var start_x := center_x - spacing * (_dice.size() - 1) * 0.5
	for i in _dice.size():
		var die: DieNode = _dice[i]
		var home := Vector2(start_x + spacing * i, dice_y)
		if _placed_on.has(die):
			var elem: ElementNode = _placed_on[die]
			home = elem.position
			die.scale = elem.scale
		die.home_position = home
		if die != _dragged_die:
			die.position = home

# --- Setup ------------------------------------------------------------------

func _setup_background() -> void:
	_background = Sprite2D.new()
	_background.texture = BG_TEXTURE
	_background.z_index = -10
	add_child(_background)

func _setup_page() -> void:
	_page = LEVEL_PAGE_SCENE.instantiate()
	add_child(_page)

# Panel con la textura de nota (verde azulado) usado por el tooltip y los botones.
func _note_style(margin_h: float, margin_v: float) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = NOTE_TEXTURE
	style.set_texture_margin_all(12)
	style.content_margin_left = margin_h
	style.content_margin_right = margin_h
	style.content_margin_top = margin_v
	style.content_margin_bottom = margin_v
	return style

func _setup_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.5)
	_overlay.z_index = 5
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	add_child(_overlay)

func _setup_power_hint() -> void:
	_power_hint = PanelContainer.new()
	_power_hint.z_index = 7
	_power_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _note_style(28, 20)
	_power_hint.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	_power_hint.add_child(box)

	_power_hint_title = Label.new()
	_power_hint_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_power_hint_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_power_hint_title.add_theme_font_size_override("font_size", 40)
	_power_hint_title.add_theme_color_override("font_color", NOTE_TEXT_COLOR)
	box.add_child(_power_hint_title)

	_power_hint_detail = Label.new()
	_power_hint_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_power_hint_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_power_hint_detail.add_theme_font_size_override("font_size", 28)
	_power_hint_detail.add_theme_color_override("font_color", NOTE_DETAIL_COLOR)
	box.add_child(_power_hint_detail)

	# Con autowrap, las etiquetas necesitan un ancho fijo o el panel crece en alto.
	var hint_w := LevelPage.DESIGN_SIZE.x * POWER_HINT_WIDTH_RATIO
	var label_w := hint_w - style.content_margin_left - style.content_margin_right
	_power_hint_title.custom_minimum_size = Vector2(label_w, 0)
	_power_hint_detail.custom_minimum_size = Vector2(label_w, 0)
	_power_hint.size = Vector2(hint_w, 0)
	_power_hint.visible = false
	add_child(_power_hint)

func _show_power_hint(effect: String, placed_value: int) -> void:
	match effect:
		"fire":
			_power_hint_title.text = "Fire: add %d to a die" % placed_value
			_power_hint_detail.text = "If it goes over 6, it wraps around and volatility rises"
		"water":
			_power_hint_title.text = "Water: subtract %d from a die" % placed_value
			_power_hint_detail.text = "If it drops below 1, it wraps around and volatility rises"
		"grass":
			_power_hint_title.text = "Soil: flip a die to its opposite face"
			_power_hint_detail.text = "Flipping a die raises volatility"
	_power_hint_detail.text += "\nTap a die or the volatility die"
	_power_hint.visible = true
	_power_hint.reset_size()
	_power_hint.modulate.a = 0.0
	create_tween().tween_property(_power_hint, "modulate:a", 1.0, 0.15)


func _setup_volatility() -> void:
	_volatility = VOLATILITY_SCENE.instantiate()
	add_child(_volatility)
	_volatility.z_index = 1

func _setup_elements() -> void:
	_grid_base_unit = _RANDOM_ROW_SLOT * 0.5
	_grid_max_scale = 1.0
	_vol_grid = _RANDOM_VOL_GRID
	for i in 5:
		var elem: ElementNode = ELEMENT_SCENE.instantiate()
		add_child(elem)
		elem.setup(ELEMENT_TYPES[randi() % ELEMENT_TYPES.size()], Vector2.ZERO)
		_elements.append(elem)
		_elem_grid.append(Vector2(i * 2, 0))

	for i in 4:
		var op: OperationNode = OPERATION_SCENE.instantiate()
		add_child(op)
		op.setup(OP_TYPES[randi() % OP_TYPES.size()], Vector2.ZERO)
		op.from_elem_idx = i
		op.to_elem_idx = i + 1
		_operations.append(op)

func _setup_dice() -> void:
	var colors: Array = ["red", "red", "white", "green", "green", "blue", "blue"]
	_spawn_dice(colors)

func _setup_elements_from_level() -> void:
	_grid_base_unit = float(_level_data.get("grid_unit", 110))
	var elems_data: Array = _level_data.get("elements", [])
	var ops_data: Array = _level_data.get("operations", [])
	var vol_data: Dictionary = _level_data.get("volatility", {})

	# Legacy: separate volatility field (old format)
	if not vol_data.is_empty():
		_vol_grid = Vector2(vol_data.get("gx", 0), vol_data.get("gy", 0))

	# Elements — "vol" type positions the volatility node, not an ElementNode
	var elem_by_id: Dictionary = {}
	for e: Dictionary in elems_data:
		var type: String = e.get("type", "fire")
		var grid := Vector2(e.get("gx", 0), e.get("gy", 0))
		if type == "vol":
			_vol_grid = grid
			continue
		var elem: ElementNode = ELEMENT_SCENE.instantiate()
		add_child(elem)
		elem.setup(type, Vector2.ZERO)
		_elements.append(elem)
		_elem_grid.append(grid)
		elem_by_id[int(e.get("id", _elements.size() - 1))] = _elements.size() - 1

	# Operations — se crean con posiciones provisionales para fijar su rotación;
	# _layout_board() las recoloca después.
	for o: Dictionary in ops_data:
		var from_id: int = o.get("from", 0)
		var to_id: int = o.get("to", 1)
		if not elem_by_id.has(from_id) or not elem_by_id.has(to_id):
			continue
		var idx_a: int = elem_by_id[from_id]
		var idx_b: int = elem_by_id[to_id]
		var op: OperationNode = OPERATION_SCENE.instantiate()
		add_child(op)
		op.z_index = 1
		op.setup_between(o.get("type", "gt"), _elem_grid[idx_a], _elem_grid[idx_b], idx_a, idx_b)
		_operations.append(op)

func _setup_dice_from_level() -> void:
	var dice_counts: Dictionary = _level_data.get("dice", {"red": 2, "white": 1, "green": 2, "blue": 2})
	var colors: Array = []
	for color: String in dice_counts:
		for _i in dice_counts[color]:
			colors.append(color)
	_spawn_dice(colors)

func _spawn_dice(colors: Array) -> void:
	colors.shuffle()
	var die_size := minf(MAX_DIE_SPACING, LevelPage.DESIGN_SIZE.x * 0.92 / colors.size()) * DIE_SIZE_RATIO
	for i in colors.size():
		var die: DieNode = DIE_SCENE.instantiate()
		add_child(die)
		die.setup(colors[i], randi_range(1, 6), Vector2.ZERO, die_size)
		die.z_index = 1
		die.animate_appear(i * 0.08)
		_dice.append(die)

func _setup_reroll_button() -> void:
	_reroll_btn = Button.new()
	_reroll_btn.text = "Reroll"
	_reroll_btn.add_theme_font_size_override("font_size", 34)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_reroll_btn.add_theme_color_override(color_name, NOTE_TEXT_COLOR)
	var style := _note_style(16, 4)
	_reroll_btn.add_theme_stylebox_override("normal", style)
	_reroll_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var style_hover := style.duplicate() as StyleBoxTexture
	style_hover.modulate_color = Color(1.15, 1.15, 1.15, 1.0)
	_reroll_btn.add_theme_stylebox_override("hover", style_hover)
	var style_pressed := style.duplicate() as StyleBoxTexture
	style_pressed.modulate_color = Color(0.8, 0.8, 0.8, 1.0)
	_reroll_btn.add_theme_stylebox_override("pressed", style_pressed)
	var style_disabled := style.duplicate() as StyleBoxTexture
	style_disabled.modulate_color = Color(0.6, 0.6, 0.6, 1.0)
	_reroll_btn.add_theme_stylebox_override("disabled", style_disabled)
	_reroll_btn.add_theme_color_override("font_disabled_color", NOTE_DETAIL_COLOR.darkened(0.3))
	_reroll_btn.size = REROLL_BTN_SIZE
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
					_highlight_valid_targets(die)
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
	_clear_target_highlights()

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
		if not _is_adjacent_to_placed(i):
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
		die.scale = elem.scale
		_placed_on[die] = elem
		elem.placed_die_value = die.die_value
		_apply_element_effect(elem.element_type, die.die_value)
		return

	die.animate_return()

# Se llama cuando el efecto del dado colocado ya se ha resuelto: si todos los
# elementos tienen dado y la poción no ha explotado ni se ha neutralizado, se gana.
func _check_potion_ready() -> void:
	if not _game_over and _all_elements_filled():
		_end_game_after(Outcome.POTION_READY, 0.4)

func _all_elements_filled() -> bool:
	for elem: ElementNode in _elements:
		if elem.placed_die_value == -1:
			return false
	return true

func _highlight_valid_targets(die: DieNode) -> void:
	for i in _elements.size():
		(_elements[i] as ElementNode).set_highlight(_target_highlight(die, i))

func _clear_target_highlights() -> void:
	for elem: ElementNode in _elements:
		elem.set_highlight(ElementNode.Highlight.NONE)

func _target_highlight(die: DieNode, elem_index: int) -> ElementNode.Highlight:
	var elem: ElementNode = _elements[elem_index]
	if elem.placed_die_value != -1 \
			or not die.matches_element(elem.element_type) \
			or not _is_adjacent_to_placed(elem_index):
		return ElementNode.Highlight.NONE
	if _find_violated_op(die.die_value, elem_index):
		return ElementNode.Highlight.BLOCKED
	return ElementNode.Highlight.VALID

# El primer dado puede ir en cualquier elemento; los siguientes solo en
# elementos conectados por una operación a otro elemento que ya tenga dado.
func _is_adjacent_to_placed(elem_index: int) -> bool:
	var any_placed := false
	for elem: ElementNode in _elements:
		if elem.placed_die_value != -1:
			any_placed = true
			break
	if not any_placed:
		return true
	for neighbor_idx: int in _neighbors_of(elem_index):
		if (_elements[neighbor_idx] as ElementNode).placed_die_value != -1:
			return true
	return false

func _neighbors_of(elem_index: int) -> Array[int]:
	var result: Array[int] = []
	if _level_data.is_empty():
		# Random mode: linear row
		if elem_index > 0:
			result.append(elem_index - 1)
		if elem_index < _elements.size() - 1:
			result.append(elem_index + 1)
	else:
		for op: OperationNode in _operations:
			if op.from_elem_idx == elem_index:
				result.append(op.to_elem_idx)
			elif op.to_elem_idx == elem_index:
				result.append(op.from_elem_idx)
	return result

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
			_check_potion_ready()

func _enter_selection_mode(effect: String, placed_value: int) -> void:
	_state = State.SELECTING_TARGET
	_pending_effect = effect
	_pending_placed_value = placed_value
	_overlay.visible = true
	_show_power_hint(effect, placed_value)
	for die: DieNode in _dice:
		if not die.is_placed:
			die.set_highlighted(true)
			die.z_index = 6
	_volatility.set_highlighted(true)
	_volatility.z_index = 6

func _exit_selection_mode() -> void:
	_state = State.IDLE
	_overlay.visible = false
	_power_hint.visible = false
	for die: DieNode in _dice:
		die.set_highlighted(false)
		if not die.is_placed:
			die.z_index = 1
	_volatility.set_highlighted(false)
	_volatility.z_index = 1

func _apply_to_die(die: DieNode) -> void:
	_exit_selection_mode()
	# Un dado "da la vuelta" si pasa de 6 a 1 / de 1 a 6, o si se gira con hierba.
	var flipped := false
	match _pending_effect:
		"fire":
			flipped = die.die_value + _pending_placed_value > 6
			die.die_value = ((die.die_value - 1 + _pending_placed_value) % 6) + 1
		"water":
			flipped = die.die_value - _pending_placed_value < 1
			die.die_value = ((die.die_value - 1 - _pending_placed_value) % 6 + 6) % 6 + 1
		"grass":
			flipped = true
			die.die_value = 7 - die.die_value
	die.update_value_display()
	if flipped:
		_increase_volatility()
	_check_potion_ready()

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
		_end_game_after(Outcome.EXPLOSION, 0.4)
	elif new_value < 1:
		_end_game_after(Outcome.SOUP, 0.4)
	_check_potion_ready()

func _on_reroll_pressed() -> void:
	if _game_over:
		return
	for die: DieNode in _dice:
		if not die.is_placed:
			die.die_value = randi_range(1, 6)
			die.update_value_display()
	_increase_volatility()

func _increase_volatility() -> void:
	_volatility.die_value += 1
	_volatility.update_value_display()
	if _volatility.die_value > 6:
		_end_game_after(Outcome.EXPLOSION, 0.35)

# Bloquea la partida ya y muestra el resultado tras una pausa breve.
func _end_game_after(outcome: Outcome, delay: float) -> void:
	_game_over = true
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_callback(_show_game_over.bind(outcome))

func _show_game_over(outcome: Outcome) -> void:
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

	# Centrado con anclas para que se adapte a cualquier tamaño de pantalla.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var content_w := LevelPage.DESIGN_SIZE.x * 0.85
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(content_w, 0)
	box.add_theme_constant_override("separation", 48)
	center.add_child(box)

	var title := Label.new()
	match outcome:
		Outcome.EXPLOSION: title.text = "The potion is unstable!"
		Outcome.SOUP: title.text = "Disgusting soup!"
		Outcome.POTION_READY: title.text = "The potion is ready!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(content_w, 0)
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(title)

	var msg := Label.new()
	match outcome:
		Outcome.EXPLOSION:
			msg.text = "Clean up the lab,\nfix whatever blew up\nand start over."
		Outcome.SOUP:
			msg.text = "The potion has been neutralized.\nYou just brewed\na disgusting soup."
		Outcome.POTION_READY:
			msg.text = "Every ingredient is in place.\nThe Poison of Black Death\nis ready."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(content_w, 0)
	msg.add_theme_font_size_override("font_size", 36)
	msg.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1.0))
	box.add_child(msg)

	var btn := Button.new()
	btn.text = "Play again" if outcome == Outcome.POTION_READY else "Start over"
	btn.add_theme_font_size_override("font_size", 38)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(color_name, NOTE_TEXT_COLOR)
	var style := _note_style(20, 8)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var style_hover := style.duplicate() as StyleBoxTexture
	style_hover.modulate_color = Color(1.15, 1.15, 1.15, 1.0)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.custom_minimum_size = Vector2(LevelPage.DESIGN_SIZE.x * 0.65, 76)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func(): get_tree().reload_current_scene())
	box.add_child(btn)

func _event_pos(event: InputEvent) -> Vector2:
	# En pantallas táctiles Godot también emite un evento de ratón emulado por
	# cada toque; lo ignoramos para no procesar el mismo toque dos veces.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return Vector2.INF
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
