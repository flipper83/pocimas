extends Node2D

const ELEMENT_SCENE := preload("res://scenes/element.tscn")
const OPERATION_SCENE := preload("res://scenes/operation.tscn")
const VOLATILITY_SCENE := preload("res://scenes/volatility.tscn")

const ELEMENT_TYPES: Array = ["fire", "water", "salt", "grass"]
const OP_TYPES: Array = ["gt", "lt", "eq", "ne"]
const OP_SYMBOLS: Dictionary = {"gt": ">", "lt": "<", "eq": "=", "ne": "≠"}
const GRID_UNIT: int = 110
const GRID_COLS: int = 7
const GRID_ROWS: int = 8

var _screen_w: float
var _screen_h: float

# Grid origin (top-left of grid area)
var _grid_origin: Vector2

# Data model
var _elements: Array = []   # [{id, type, gx, gy, node}]
var _operations: Array = [] # [{from, to, type, node}]
var _volatility_gx: int = 3
var _volatility_gy: int = 0
var _volatility_node: VolatilityNode = null
var _dice_counts: Dictionary = {"red": 2, "white": 1, "green": 2, "blue": 2}
var _next_elem_id: int = 0

# Interaction state
enum Tool { ELEM, OP_FROM, VOLATILITY }
var _active_tool: Tool = Tool.ELEM
var _selected_elem_type: String = "fire"
var _selected_op_type: String = "gt"
var _op_from_id: int = -1
var _op_from_node: ElementNode = null

# UI refs
var _tool_label: Label
var _elem_type_btn: OptionButton
var _op_type_btn: OptionButton
var _dice_labels: Dictionary = {}
var _status_label: Label

func _ready() -> void:
	var rect := get_viewport().get_visible_rect()
	_screen_w = rect.size.x
	_screen_h = rect.size.y
	_grid_origin = Vector2(20.0, _screen_h * 0.12)
	_build_ui()
	_spawn_volatility()

func _build_ui() -> void:
	var panel := ColorRect.new()
	panel.color = Color(0.08, 0.08, 0.18, 0.95)
	panel.position = Vector2(0, 0)
	panel.size = Vector2(_screen_w, _screen_h * 0.11)
	add_child(panel)

	_tool_label = Label.new()
	_tool_label.add_theme_font_size_override("font_size", 22)
	_tool_label.add_theme_color_override("font_color", Color.WHITE)
	_tool_label.position = Vector2(10, 6)
	_tool_label.size = Vector2(_screen_w - 20, 28)
	add_child(_tool_label)

	# Element type picker
	var elem_lbl := Label.new()
	elem_lbl.text = "Elem:"
	elem_lbl.add_theme_font_size_override("font_size", 20)
	elem_lbl.add_theme_color_override("font_color", Color.WHITE)
	elem_lbl.position = Vector2(10, 38)
	add_child(elem_lbl)

	_elem_type_btn = OptionButton.new()
	for t: String in ELEMENT_TYPES:
		_elem_type_btn.add_item(t)
	_elem_type_btn.position = Vector2(60, 34)
	_elem_type_btn.size = Vector2(140, 34)
	_elem_type_btn.item_selected.connect(_on_elem_type_changed)
	add_child(_elem_type_btn)

	# Op type picker
	var op_lbl := Label.new()
	op_lbl.text = "Op:"
	op_lbl.add_theme_font_size_override("font_size", 20)
	op_lbl.add_theme_color_override("font_color", Color.WHITE)
	op_lbl.position = Vector2(215, 38)
	add_child(op_lbl)

	_op_type_btn = OptionButton.new()
	for t: String in OP_TYPES:
		_op_type_btn.add_item(OP_SYMBOLS[t])
	_op_type_btn.position = Vector2(248, 34)
	_op_type_btn.size = Vector2(90, 34)
	_op_type_btn.item_selected.connect(_on_op_type_changed)
	add_child(_op_type_btn)

	# Tool buttons
	var btn_elem := _make_btn("+ Elem", Vector2(350, 34), _on_tool_elem)
	add_child(btn_elem)
	var btn_op := _make_btn("+ Op", Vector2(440, 34), _on_tool_op)
	add_child(btn_op)
	var btn_vol := _make_btn("Vol", Vector2(510, 34), _on_tool_vol)
	add_child(btn_vol)

	# Dice count row
	var dx := 10.0
	for color: String in ["red", "white", "green", "blue"]:
		var minus_btn := _make_btn("-", Vector2(dx, 76), func(): _change_dice(color, -1))
		minus_btn.size = Vector2(30, 28)
		add_child(minus_btn)
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.position = Vector2(dx + 32, 78)
		lbl.size = Vector2(70, 24)
		lbl.text = "%s:%d" % [color[0].to_upper(), _dice_counts[color]]
		add_child(lbl)
		_dice_labels[color] = lbl
		var plus_btn := _make_btn("+", Vector2(dx + 100, 76), func(): _change_dice(color, 1))
		plus_btn.size = Vector2(30, 28)
		add_child(plus_btn)
		dx += 140.0

	# Bottom buttons
	var save_btn := _make_btn("Guardar JSON", Vector2(10, _screen_h - 80), _on_save)
	save_btn.size = Vector2(200, 48)
	add_child(save_btn)
	var load_btn := _make_btn("Cargar JSON", Vector2(220, _screen_h - 80), _on_load)
	load_btn.size = Vector2(200, 48)
	add_child(load_btn)
	var clear_btn := _make_btn("Limpiar", Vector2(430, _screen_h - 80), _on_clear)
	clear_btn.size = Vector2(140, 48)
	add_child(clear_btn)
	var del_btn := _make_btn("Del último", Vector2(580, _screen_h - 80), _on_delete_last)
	del_btn.size = Vector2(140, 48)
	add_child(del_btn)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7, 1.0))
	_status_label.position = Vector2(10, _screen_h - 120)
	_status_label.size = Vector2(_screen_w - 20, 30)
	add_child(_status_label)

	_update_tool_label()

func _make_btn(txt: String, pos: Vector2, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.add_theme_font_size_override("font_size", 20)
	btn.position = pos
	btn.size = Vector2(80, 34)
	btn.pressed.connect(cb)
	return btn

func _spawn_volatility() -> void:
	_volatility_node = VOLATILITY_SCENE.instantiate()
	add_child(_volatility_node)
	_volatility_node.position = _gxy_to_pos(_volatility_gx, _volatility_gy)
	_volatility_node.z_index = 2

func _gxy_to_pos(gx: int, gy: int) -> Vector2:
	return _grid_origin + Vector2(gx * GRID_UNIT, gy * GRID_UNIT)

func _pos_to_gxy(pos: Vector2) -> Vector2i:
	var local := pos - _grid_origin
	return Vector2i(int(round(local.x / GRID_UNIT)), int(round(local.y / GRID_UNIT)))

func _draw() -> void:
	# Grid lines
	var grid_color := Color(0.3, 0.3, 0.6, 0.4)
	for col in GRID_COLS + 1:
		var x := _grid_origin.x + col * GRID_UNIT
		draw_line(Vector2(x, _grid_origin.y), Vector2(x, _grid_origin.y + GRID_ROWS * GRID_UNIT), grid_color, 1.0)
	for row in GRID_ROWS + 1:
		var y := _grid_origin.y + row * GRID_UNIT
		draw_line(Vector2(_grid_origin.x, y), Vector2(_grid_origin.x + GRID_COLS * GRID_UNIT, y), grid_color, 1.0)
	# Op-from highlight
	if _active_tool == Tool.OP_FROM and _op_from_node:
		var p := _op_from_node.position
		draw_circle(p, 52, Color(1.0, 1.0, 0.0, 0.25))

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not (mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed):
		return
	var pos := mb.position
	if pos.y < _screen_h * 0.11 or pos.y > _screen_h - 100:
		return

	var gxy := _pos_to_gxy(pos)
	var gx := gxy.x; var gy := gxy.y
	if gx < 0 or gx >= GRID_COLS or gy < 0 or gy >= GRID_ROWS:
		return

	match _active_tool:
		Tool.ELEM:
			_place_element(gx, gy)
		Tool.OP_FROM:
			_handle_op_click(gx, gy)
		Tool.VOLATILITY:
			_move_volatility(gx, gy)

func _place_element(gx: int, gy: int) -> void:
	# Check if occupied
	for e: Dictionary in _elements:
		if e.gx == gx and e.gy == gy:
			_set_status("Ya hay un elemento aquí")
			return

	var elem: ElementNode = ELEMENT_SCENE.instantiate()
	add_child(elem)
	elem.setup(_selected_elem_type, _gxy_to_pos(gx, gy))
	var id := _next_elem_id
	_next_elem_id += 1
	_elements.append({"id": id, "type": _selected_elem_type, "gx": gx, "gy": gy, "node": elem})
	_set_status("Elemento %s colocado en (%d,%d)" % [_selected_elem_type, gx, gy])

func _handle_op_click(gx: int, gy: int) -> void:
	# Find element at this grid cell
	var found_entry: Dictionary = {}
	for e: Dictionary in _elements:
		if e.gx == gx and e.gy == gy:
			found_entry = e
			break
	if found_entry.is_empty():
		_set_status("Selecciona un elemento para la operación")
		return

	if _op_from_id == -1:
		_op_from_id = found_entry.id
		_op_from_node = found_entry.node as ElementNode
		_set_status("Selecciona el segundo elemento")
		queue_redraw()
	else:
		if found_entry.id == _op_from_id:
			_op_from_id = -1
			_op_from_node = null
			_set_status("Selección cancelada")
			queue_redraw()
			return
		_place_operation(_op_from_id, found_entry.id)
		_op_from_id = -1
		_op_from_node = null
		queue_redraw()

func _place_operation(from_id: int, to_id: int) -> void:
	var from_entry: Dictionary = {}
	var to_entry: Dictionary = {}
	for e: Dictionary in _elements:
		if e.id == from_id: from_entry = e
		if e.id == to_id: to_entry = e
	if from_entry.is_empty() or to_entry.is_empty():
		return

	var op: OperationNode = OPERATION_SCENE.instantiate()
	add_child(op)
	var idx_a := _elements.find(from_entry)
	var idx_b := _elements.find(to_entry)
	op.setup_between(_selected_op_type,
		from_entry.node.position, to_entry.node.position, idx_a, idx_b)
	_operations.append({"from": from_id, "to": to_id, "type": _selected_op_type, "node": op})
	_set_status("Operación %s añadida" % OP_SYMBOLS[_selected_op_type])

func _move_volatility(gx: int, gy: int) -> void:
	_volatility_gx = gx
	_volatility_gy = gy
	_volatility_node.position = _gxy_to_pos(gx, gy)
	_set_status("Volatilidad movida a (%d,%d)" % [gx, gy])

func _on_tool_elem() -> void:
	_active_tool = Tool.ELEM
	_op_from_id = -1
	_op_from_node = null
	_update_tool_label()
	queue_redraw()

func _on_tool_op() -> void:
	_active_tool = Tool.OP_FROM
	_op_from_id = -1
	_op_from_node = null
	_update_tool_label()
	queue_redraw()

func _on_tool_vol() -> void:
	_active_tool = Tool.VOLATILITY
	_update_tool_label()

func _on_elem_type_changed(idx: int) -> void:
	_selected_elem_type = ELEMENT_TYPES[idx]

func _on_op_type_changed(idx: int) -> void:
	_selected_op_type = OP_TYPES[idx]

func _change_dice(color: String, delta: int) -> void:
	_dice_counts[color] = maxi(0, _dice_counts[color] + delta)
	(_dice_labels[color] as Label).text = "%s:%d" % [color[0].to_upper(), _dice_counts[color]]

func _update_tool_label() -> void:
	var names := ["Colocar elemento", "Conectar operación (clic 1°, clic 2°)", "Mover volatilidad"]
	_tool_label.text = "Herramienta: " + names[_active_tool]

func _set_status(msg: String) -> void:
	_status_label.text = msg

func _on_clear() -> void:
	for e: Dictionary in _elements:
		(e.node as Node).queue_free()
	for o: Dictionary in _operations:
		(o.node as Node).queue_free()
	_elements.clear()
	_operations.clear()
	_next_elem_id = 0
	_op_from_id = -1
	_op_from_node = null
	queue_redraw()
	_set_status("Nivel limpiado")

func _on_delete_last() -> void:
	if not _operations.is_empty():
		var last: Dictionary = _operations.pop_back()
		(last.node as Node).queue_free()
		_set_status("Última operación eliminada")
	elif not _elements.is_empty():
		var last: Dictionary = _elements.pop_back()
		# Remove ops referencing this element
		var to_remove: Array = []
		for o: Dictionary in _operations:
			if o.from == last.id or o.to == last.id:
				to_remove.append(o)
		for o: Dictionary in to_remove:
			_operations.erase(o)
			(o.node as Node).queue_free()
		(last.node as Node).queue_free()
		_set_status("Último elemento eliminado")

func _on_save() -> void:
	var data := _build_level_data()
	var path := "user://level.json"
	if LevelLoader.save_to_file(path, data):
		_set_status("Guardado en " + path)
		print("Level saved to: ", ProjectSettings.globalize_path(path))
	else:
		_set_status("Error al guardar")

func _on_load() -> void:
	var path := "user://level.json"
	var data := LevelLoader.load_from_file(path)
	if data.is_empty():
		_set_status("No se pudo cargar " + path)
		return
	_on_clear()
	_load_level_data(data)
	_set_status("Nivel cargado")

func _build_level_data() -> Dictionary:
	var elems_arr: Array = []
	for e: Dictionary in _elements:
		elems_arr.append({"id": e.id, "type": e.type, "gx": e.gx, "gy": e.gy})
	var ops_arr: Array = []
	for o: Dictionary in _operations:
		ops_arr.append({"from": o.from, "to": o.to, "type": o.type})
	return {
		"dice": _dice_counts.duplicate(),
		"grid_unit": GRID_UNIT,
		"elements": elems_arr,
		"operations": ops_arr,
		"volatility": {"gx": _volatility_gx, "gy": _volatility_gy},
	}

func _load_level_data(data: Dictionary) -> void:
	if data.has("dice"):
		_dice_counts = data.dice.duplicate()
		for color: String in _dice_counts:
			if _dice_labels.has(color):
				(_dice_labels[color] as Label).text = "%s:%d" % [color[0].to_upper(), _dice_counts[color]]

	var vol_data: Dictionary = data.get("volatility", {})
	if not vol_data.is_empty():
		_volatility_gx = vol_data.get("gx", 0)
		_volatility_gy = vol_data.get("gy", 0)
		_volatility_node.position = _gxy_to_pos(_volatility_gx, _volatility_gy)

	for e: Dictionary in data.get("elements", []):
		var elem: ElementNode = ELEMENT_SCENE.instantiate()
		add_child(elem)
		elem.setup(e.get("type", "fire"), _gxy_to_pos(e.get("gx", 0), e.get("gy", 0)))
		var id: int = e.get("id", _next_elem_id)
		_next_elem_id = maxi(_next_elem_id, id + 1)
		_elements.append({"id": id, "type": e.get("type", "fire"), "gx": e.get("gx", 0), "gy": e.get("gy", 0), "node": elem})

	var elem_id_to_idx: Dictionary = {}
	for i in _elements.size():
		elem_id_to_idx[(_elements[i] as Dictionary).id] = i

	for o: Dictionary in data.get("operations", []):
		var from_id: int = o.get("from", 0)
		var to_id: int = o.get("to", 1)
		if not elem_id_to_idx.has(from_id) or not elem_id_to_idx.has(to_id):
			continue
		var idx_a: int = elem_id_to_idx[from_id]
		var idx_b: int = elem_id_to_idx[to_id]
		var op: OperationNode = OPERATION_SCENE.instantiate()
		add_child(op)
		op.setup_between(o.get("type", "gt"),
			(_elements[idx_a] as Dictionary).node.position,
			(_elements[idx_b] as Dictionary).node.position,
			idx_a, idx_b)
		_operations.append({"from": from_id, "to": to_id, "type": o.get("type", "gt"), "node": op})
