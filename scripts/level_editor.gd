extends Node2D

const ELEMENT_SCENE    := preload("res://scenes/element.tscn")
const VOLATILITY_SCENE := preload("res://scenes/volatility.tscn")
const _ETEX: Dictionary = {
	"fire":  preload("res://assets/fuego.png"),
	"water": preload("res://assets/agua.png"),
	"salt":  preload("res://assets/sal.png"),
	"grass": preload("res://assets/hierba.png"),
}
const _VOL_TEX: Texture2D = preload("res://assets/volatility.png")

const TOOLBAR_H := 160.0
const GRID_UNIT := 100
const GRID_COLS := 6
const GRID_ROWS := 11
const PORT_R    := 9.0
const PORT_D    := 50.0

const ELEM_TYPES: Array[String]  = ["fire", "water", "salt", "grass"]
const OP_TYPES:   Array[String]  = ["gt", "lt", "eq", "ne"]
const OP_SYM:     Dictionary     = {"gt": ">", "lt": "<", "eq": "=", "ne": "≠"}
const DICE_COLORS: Array[String] = ["red", "white", "green", "blue"]
const DICE_COL:   Dictionary     = {
	"red": Color(0.9, 0.2, 0.2), "white": Color(0.85, 0.85, 0.85),
	"green": Color(0.2, 0.75, 0.2), "blue": Color(0.2, 0.5, 1.0),
}

# ── Toolbar row 1 (y=4..76): element palette + op selector ──
const _PAL: Dictionary = {
	"fire":  Rect2(2,   4, 60, 72),
	"water": Rect2(66,  4, 60, 72),
	"salt":  Rect2(130, 4, 60, 72),
	"grass": Rect2(194, 4, 60, 72),
	"vol":   Rect2(258, 4, 60, 72),
}
const _OPR: Dictionary = {
	"gt": Rect2(332, 18, 42, 42),
	"lt": Rect2(378, 18, 42, 42),
	"eq": Rect2(424, 18, 42, 42),
	"ne": Rect2(470, 18, 42, 42),
}

# ── Toolbar row 2 (y=82..150): dice + actions ──
# Dice: 4 groups at x = i*100+2, each has [-] count [+]  (width 98px)
# Action buttons start at x=408
const _BTN_SAVE  := Rect2(412, 82,  76, 32)
const _BTN_LOAD  := Rect2(492, 82,  76, 32)
const _BTN_CLEAR := Rect2(572, 82,  72, 32)
const _BTN_DEL   := Rect2(648, 82, 68, 32)

var _font: Font
var _sw: float
var _sh: float
var _origin: Vector2

var _elems: Array = []  # {id, type, gx, gy, node: Node2D}
var _conns: Array = []  # {from_id, to_id, op}
var _next_id: int = 0
var _dice: Dictionary = {"red": 2, "white": 1, "green": 2, "blue": 2}
var _sel_op: String = "gt"

enum _Mode { IDLE, PLACE, MOVE, CONNECT }
var _mode: _Mode = _Mode.IDLE
var _place_type: String = ""
var _move_id: int = -1
var _move_off: Vector2
var _conn_from_id: int = -1
var _conn_from_port: Vector2
var _mouse: Vector2
var _status: String = "Listo"

func _ready() -> void:
	_font = ThemeDB.fallback_font
	var r := get_viewport().get_visible_rect()
	_sw = r.size.x
	_sh = r.size.y
	var grid_w := GRID_COLS * GRID_UNIT
	_origin = Vector2((_sw - grid_w) * 0.5, TOOLBAR_H + 2.0)

func _process(_dt: float) -> void:
	queue_redraw()

# ── Helpers ────────────────────────────────────────────────────────────────────

func _gpos(gx: int, gy: int) -> Vector2:
	return _origin + Vector2(gx * GRID_UNIT, gy * GRID_UNIT)

func _snap(pos: Vector2) -> Vector2i:
	var local := pos - _origin
	return Vector2i(
		clampi(roundi(local.x / GRID_UNIT), 0, GRID_COLS - 1),
		clampi(roundi(local.y / GRID_UNIT), 0, GRID_ROWS - 1))

func _find(id: int) -> Dictionary:
	for e: Dictionary in _elems:
		if e.id == id: return e
	return {}

func _elem_at(gx: int, gy: int) -> Dictionary:
	for e: Dictionary in _elems:
		if e.gx == gx and e.gy == gy: return e
	return {}

func _elem_near(pos: Vector2, radius: float) -> Dictionary:
	for e: Dictionary in _elems:
		if (e.node as Node2D).position.distance_to(pos) <= radius: return e
	return {}

func _get_ports(e: Dictionary) -> Array[Vector2]:
	var p: Vector2 = (e.node as Node2D).position
	var r: Array[Vector2] = []
	r.append(p + Vector2(0, -PORT_D))
	r.append(p + Vector2(PORT_D, 0))
	r.append(p + Vector2(0, PORT_D))
	r.append(p + Vector2(-PORT_D, 0))
	return r

func _nearest_port_toward(e: Dictionary, target: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var best_d := INF
	for pt: Vector2 in _get_ports(e):
		var d := target.distance_to(pt)
		if d < best_d: best_d = d; best = pt
	return best

func _port_at(pos: Vector2) -> Dictionary:
	for e: Dictionary in _elems:
		for pt: Vector2 in _get_ports(e):
			if pos.distance_to(pt) <= PORT_R * 2.2:
				return {"elem": e, "port": pt}
	return {}

# ── Actions ────────────────────────────────────────────────────────────────────

func _place(type: String, gx: int, gy: int) -> void:
	if not _elem_at(gx, gy).is_empty():
		_status = "Celda ocupada"; return
	var world := _gpos(gx, gy)
	var node: Node2D
	if type == "vol":
		node = VOLATILITY_SCENE.instantiate() as Node2D
		add_child(node)
		node.position = world
	else:
		var elem := ELEMENT_SCENE.instantiate() as ElementNode
		add_child(elem)
		elem.setup(type, world)
		node = elem
	var id := _next_id
	_next_id += 1
	_elems.append({"id": id, "type": type, "gx": gx, "gy": gy, "node": node})
	_status = "%s en (%d,%d)" % [type, gx, gy]

func _connect(from_id: int, to_id: int) -> void:
	if from_id == to_id: return
	for c: Dictionary in _conns:
		if (c.from_id == from_id and c.to_id == to_id) or \
		   (c.from_id == to_id and c.to_id == from_id):
			_status = "Conexión ya existe"; return
	_conns.append({"from_id": from_id, "to_id": to_id, "op": _sel_op})
	_status = "Op %s añadida" % OP_SYM[_sel_op]

func _delete_elem(id: int) -> void:
	var entry := _find(id)
	if entry.is_empty(): return
	_conns = _conns.filter(func(c: Dictionary) -> bool:
		return c.from_id != id and c.to_id != id)
	(entry.node as Node).queue_free()
	_elems.erase(entry)
	_status = "Elemento borrado"

func _on_clear() -> void:
	for e: Dictionary in _elems: (e.node as Node).queue_free()
	_elems.clear(); _conns.clear(); _next_id = 0
	_mode = _Mode.IDLE; _status = "Limpiado"

# ── Input ──────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	var pos: Vector2
	if event is InputEventMouseMotion:
		pos = (event as InputEventMouseMotion).position
		_mouse = pos
		if _mode == _Mode.MOVE:
			var entry := _find(_move_id)
			if not entry.is_empty():
				(entry.node as Node2D).position = pos + _move_off
		return
	if not (event is InputEventMouseButton): return
	var mb := event as InputEventMouseButton
	pos = mb.position; _mouse = pos
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		_handle_rclick(pos); return
	if mb.button_index != MOUSE_BUTTON_LEFT: return
	if mb.pressed: _handle_press(pos)
	else:          _handle_release(pos)

func _handle_rclick(pos: Vector2) -> void:
	for i in _conns.size():
		var c: Dictionary = _conns[i]
		var ea := _find(c.from_id); var eb := _find(c.to_id)
		if ea.is_empty() or eb.is_empty(): continue
		var mid := ((ea.node as Node2D).position + (eb.node as Node2D).position) * 0.5
		if pos.distance_to(mid) < 22.0:
			_conns.remove_at(i); _status = "Conexión borrada"; return
	var entry := _elem_near(pos, 48.0)
	if not entry.is_empty(): _delete_elem(entry.id)

func _handle_press(pos: Vector2) -> void:
	if pos.y < TOOLBAR_H:
		_handle_toolbar_press(pos); return
	var ph := _port_at(pos)
	if not ph.is_empty():
		_mode = _Mode.CONNECT
		_conn_from_id   = (ph.elem as Dictionary).id
		_conn_from_port = ph.port as Vector2
		_status = "Conectando…"; return
	var entry := _elem_near(pos, 48.0)
	if not entry.is_empty():
		_mode = _Mode.MOVE
		_move_id  = entry.id
		_move_off = (entry.node as Node2D).position - pos

func _handle_toolbar_press(pos: Vector2) -> void:
	for type: String in _PAL:
		if (_PAL[type] as Rect2).has_point(pos):
			_mode = _Mode.PLACE; _place_type = type
			_status = "Arrastrando %s…" % type; return
	for op: String in _OPR:
		if (_OPR[op] as Rect2).has_point(pos):
			_sel_op = op; return
	for i in DICE_COLORS.size():
		var x := float(i * 100 + 2)
		var color := DICE_COLORS[i]
		if Rect2(x + 26, 82, 24, 26).has_point(pos): _dice[color] = maxi(0, _dice[color] - 1); return
		if Rect2(x + 74, 82, 24, 26).has_point(pos): _dice[color] += 1; return
	if _BTN_SAVE.has_point(pos):  _on_save(); return
	if _BTN_LOAD.has_point(pos):  _on_load(); return
	if _BTN_CLEAR.has_point(pos): _on_clear(); return
	if _BTN_DEL.has_point(pos):
		if not _conns.is_empty(): _conns.pop_back(); _status = "Última op borrada"

func _handle_release(pos: Vector2) -> void:
	match _mode:
		_Mode.PLACE:
			if pos.y > TOOLBAR_H:
				var g := _snap(pos); _place(_place_type, g.x, g.y)
			_mode = _Mode.IDLE
		_Mode.MOVE:
			var entry := _find(_move_id)
			if not entry.is_empty():
				var g := _snap(pos)
				var occ := _elem_at(g.x, g.y)
				if not occ.is_empty() and occ.id != _move_id:
					(entry.node as Node2D).position = _gpos(entry.gx, entry.gy)
				else:
					(entry.node as Node2D).position = _gpos(g.x, g.y)
					entry["gx"] = g.x; entry["gy"] = g.y
					_status = "Movido a (%d,%d)" % [g.x, g.y]
			_mode = _Mode.IDLE; _move_id = -1
		_Mode.CONNECT:
			var target := _elem_near(pos, PORT_D + 12.0)
			if not target.is_empty() and target.id != _conn_from_id:
				_connect(_conn_from_id, target.id)
			_mode = _Mode.IDLE; _conn_from_id = -1

# ── Draw ───────────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_toolbar()
	_draw_grid()
	_draw_connections()
	_draw_ports()
	_draw_ghost()
	_draw_rubber_band()
	_draw_status()

func _draw_toolbar() -> void:
	draw_rect(Rect2(0, 0, _sw, TOOLBAR_H), Color(0.08, 0.08, 0.18))
	draw_line(Vector2(0, TOOLBAR_H), Vector2(_sw, TOOLBAR_H), Color(0.35, 0.35, 0.65, 0.9), 2.0)

	# Row 1 label
	draw_string(_font, Vector2(2, 16), "Elementos:", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.55, 0.85))
	# Element tiles
	for type: String in _PAL:
		var r: Rect2 = _PAL[type]
		var hov  := r.has_point(_mouse)
		var armed := _mode == _Mode.PLACE and _place_type == type
		draw_rect(r, Color(0.28, 0.22, 0.06) if armed else (Color(0.22, 0.22, 0.42) if hov else Color(0.12, 0.12, 0.26)))
		draw_rect(r, Color(1.0, 0.85, 0.2) if armed else Color(0.4, 0.4, 0.7), false, 1.5)
		var tex: Texture2D = _VOL_TEX if type == "vol" else (_ETEX.get(type) as Texture2D)
		if tex:
			draw_texture_rect(tex, Rect2(r.position + Vector2(6, 5), r.size - Vector2(12, 20)), false)
		var names := {"fire":"Fuego","water":"Agua","salt":"Sal","grass":"Hierba","vol":"Volatil."}
		draw_string(_font, Vector2(r.get_center().x, r.end.y - 2),
			names.get(type, type), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12, Color.WHITE)

	# Op label + buttons
	draw_string(_font, Vector2(330, 16), "Op:", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.55, 0.85))
	for op: String in _OPR:
		var r: Rect2 = _OPR[op]
		var sel := op == _sel_op
		draw_rect(r, Color(0.38, 0.22, 0.04) if sel else Color(0.12, 0.12, 0.26))
		draw_rect(r, Color(1.0, 0.7, 0.2) if sel else Color(0.4, 0.4, 0.7), false, 2.0)
		draw_string(_font, r.get_center() + Vector2(0, 9),
			OP_SYM[op], HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color.WHITE)

	# Row 2 separator
	draw_line(Vector2(0, 78), Vector2(_sw, 78), Color(0.2, 0.2, 0.4, 0.5), 1.0)

	# Dice
	for i in DICE_COLORS.size():
		var x := float(i * 100 + 2)
		var color := DICE_COLORS[i]
		var dc: Color = DICE_COL[color]
		# Color label box
		draw_rect(Rect2(x, 82, 22, 26), dc.darkened(0.35))
		draw_string(_font, Vector2(x + 11, 100), color.substr(0, 1).to_upper(),
			HORIZONTAL_ALIGNMENT_CENTER, -1, 14, dc.lightened(0.4))
		# Minus
		_dbtn_small(Rect2(x + 26, 82, 24, 26), "−")
		# Count
		draw_string(_font, Vector2(x + 62, 100), str(_dice[color]),
			HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.WHITE)
		# Plus
		_dbtn_small(Rect2(x + 74, 82, 24, 26), "+")
		# Second row: count display label at y=114
		draw_string(_font, Vector2(x + 11, 145), color.substr(0, 3),
			HORIZONTAL_ALIGNMENT_CENTER, 80, 11, dc.lightened(0.2))

	# Action buttons
	_dbtn(_BTN_SAVE,  "Guardar")
	_dbtn(_BTN_LOAD,  "Cargar")
	_dbtn(_BTN_CLEAR, "Limpiar")
	_dbtn(_BTN_DEL,   "Del op")

func _dbtn(r: Rect2, label: String) -> void:
	var hov := r.has_point(_mouse)
	draw_rect(r, Color(0.28, 0.15, 0.42) if hov else Color(0.16, 0.1, 0.26))
	draw_rect(r, Color(0.55, 0.35, 0.75), false, 1.5)
	draw_string(_font, r.get_center() + Vector2(0, 6),
		label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 4, 14, Color.WHITE)

func _dbtn_small(r: Rect2, label: String) -> void:
	var hov := r.has_point(_mouse)
	draw_rect(r, Color(0.25, 0.25, 0.45) if hov else Color(0.15, 0.15, 0.32))
	draw_rect(r, Color(0.5, 0.5, 0.8), false, 1.0)
	draw_string(_font, r.get_center() + Vector2(0, 6),
		label, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.WHITE)

func _draw_grid() -> void:
	var gc := Color(0.22, 0.22, 0.45, 0.45)
	for c in GRID_COLS + 1:
		var x := _origin.x + c * GRID_UNIT
		draw_line(Vector2(x, _origin.y), Vector2(x, _origin.y + GRID_ROWS * GRID_UNIT), gc, 1.0)
	for r in GRID_ROWS + 1:
		var y := _origin.y + r * GRID_UNIT
		draw_line(Vector2(_origin.x, y), Vector2(_origin.x + GRID_COLS * GRID_UNIT, y), gc, 1.0)

func _draw_connections() -> void:
	for c: Dictionary in _conns:
		var ea := _find(c.from_id); var eb := _find(c.to_id)
		if ea.is_empty() or eb.is_empty(): continue
		var pa: Vector2 = (ea.node as Node2D).position
		var pb: Vector2 = (eb.node as Node2D).position
		var port_a := _nearest_port_toward(ea, pb)
		var port_b := _nearest_port_toward(eb, pa)
		draw_line(port_a, port_b, Color(0.85, 0.65, 0.1, 0.9), 2.5)
		_draw_arrowhead(port_a, port_b)
		var mid := (port_a + port_b) * 0.5
		draw_circle(mid, 18.0, Color(0.1, 0.07, 0.02))
		draw_arc(mid, 18.0, 0.0, TAU, 24, Color(0.9, 0.7, 0.1), 2.0)
		draw_string(_font, mid + Vector2(0, 8), OP_SYM[c.op],
			HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color.WHITE)

func _draw_arrowhead(from: Vector2, to: Vector2) -> void:
	var dir := (to - from).normalized()
	var tip  := to - dir * 20.0
	var perp := Vector2(-dir.y, dir.x) * 6.0
	var col  := Color(0.85, 0.65, 0.1, 0.9)
	draw_line(tip + perp, to - dir * 24.0, col, 2.0)
	draw_line(tip - perp, to - dir * 24.0, col, 2.0)

func _draw_ports() -> void:
	for e: Dictionary in _elems:
		var ep: Vector2 = (e.node as Node2D).position
		if _mouse.distance_to(ep) > 70.0 and _mode != _Mode.CONNECT: continue
		for pt: Vector2 in _get_ports(e):
			var near := _mouse.distance_to(pt) <= PORT_R * 2.2
			draw_circle(pt, PORT_R, Color(1.0, 0.9, 0.2) if near else Color(0.75, 0.6, 0.1, 0.6))
			draw_arc(pt, PORT_R, 0.0, TAU, 16,
				Color(1, 1, 1, 0.5) if near else Color(0.3, 0.25, 0.0), 1.5)

func _draw_ghost() -> void:
	if _mode != _Mode.PLACE or _mouse.y <= TOOLBAR_H: return
	var tex: Texture2D = _VOL_TEX if _place_type == "vol" else (_ETEX.get(_place_type) as Texture2D)
	if tex:
		var sz := Vector2(72, 65)
		draw_texture_rect(tex, Rect2(_mouse - sz * 0.5, sz), false, Color(1, 1, 1, 0.5))
	var g := _snap(_mouse)
	var snapped := _gpos(g.x, g.y)
	var occ := not _elem_at(g.x, g.y).is_empty()
	draw_circle(snapped, 10.0, Color(1.0, 0.2, 0.2, 0.45) if occ else Color(1.0, 1.0, 0.2, 0.45))

func _draw_rubber_band() -> void:
	if _mode != _Mode.CONNECT: return
	draw_line(_conn_from_port, _mouse, Color(0.9, 0.8, 0.2, 0.85), 2.5)
	draw_circle(_conn_from_port, PORT_R + 2, Color(1.0, 0.9, 0.2))
	var target := _elem_near(_mouse, PORT_D + 12.0)
	if not target.is_empty() and target.id != _conn_from_id:
		draw_circle((target.node as Node2D).position, PORT_D + 6, Color(0.9, 0.9, 0.2, 0.25))

func _draw_status() -> void:
	var mode_lbl := ["", "Colocar → suelta en grid", "Moviendo…", "Conectando…"]
	var txt := _status
	if _mode != _Mode.IDLE: txt += "  ·  " + mode_lbl[_mode]
	draw_string(_font, Vector2(4, _sh - 6), txt,
		HORIZONTAL_ALIGNMENT_LEFT, _sw - 8, 13, Color(0.75, 1.0, 0.75))

# ── JSON ───────────────────────────────────────────────────────────────────────

func _build_data() -> Dictionary:
	var elems_arr: Array = []
	for e: Dictionary in _elems:
		elems_arr.append({"id": e.id, "type": e.type, "gx": e.gx, "gy": e.gy})
	var ops_arr: Array = []
	for c: Dictionary in _conns:
		ops_arr.append({"from": c.from_id, "to": c.to_id, "type": c.op})
	return {"dice": _dice.duplicate(), "grid_unit": GRID_UNIT,
		"elements": elems_arr, "operations": ops_arr}

func _on_save() -> void:
	if LevelLoader.save_to_file("user://level.json", _build_data()):
		_status = "Guardado → user://level.json"
		print("Saved: ", ProjectSettings.globalize_path("user://level.json"))
	else:
		_status = "Error al guardar"

func _on_load() -> void:
	var data := LevelLoader.load_from_file("user://level.json")
	if data.is_empty(): _status = "No se encontró level.json"; return
	_on_clear()
	if data.has("dice"): _dice = (data.dice as Dictionary).duplicate()
	var old_to_new: Dictionary = {}
	for e: Dictionary in data.get("elements", []):
		var old_id: int = e.get("id", 0)
		_place(e.get("type", "fire"), e.get("gx", 0), e.get("gy", 0))
		old_to_new[old_id] = (_elems.back() as Dictionary).id
	var saved_op := _sel_op
	for c: Dictionary in data.get("operations", []):
		var of_: int = c.get("from", 0); var ot: int = c.get("to", 0)
		if not old_to_new.has(of_) or not old_to_new.has(ot): continue
		_sel_op = c.get("type", "gt")
		_connect(old_to_new[of_], old_to_new[ot])
	_sel_op = saved_op
	_status = "Cargado"
