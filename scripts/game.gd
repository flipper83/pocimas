extends Node2D

const BG_TEXTURE := preload("res://assets/texture.png")
const DIE_SCENE := preload("res://scenes/die.tscn")
const ELEMENT_SCENE := preload("res://scenes/element.tscn")

const ELEMENT_TYPES: Array = ["fire", "water", "salt", "grass"]
const DICE_BOTTOM_MARGIN := 80.0

var _screen_w: float
var _screen_h: float
var _dice: Array = []
var _elements: Array = []
var _dragged_die: DieNode = null
var _drag_offset: Vector2

func _ready() -> void:
	var rect := get_viewport().get_visible_rect()
	_screen_w = rect.size.x
	_screen_h = rect.size.y
	randomize()
	_setup_background()
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

func _setup_elements() -> void:
	var spacing := _screen_w / 5.0
	for i in 5:
		var elem: ElementNode = ELEMENT_SCENE.instantiate()
		add_child(elem)
		var pos := Vector2(spacing * 0.5 + spacing * i, _screen_h * 0.42)
		elem.setup(ELEMENT_TYPES[randi() % ELEMENT_TYPES.size()], pos)
		_elements.append(elem)

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
	for elem: ElementNode in _elements:
		if elem.get_hit_rect().has_point(drop_pos):
			if die.matches_element(elem.element_type):
				die.position = elem.position
				die.home_position = elem.position
				die.is_placed = true
			else:
				elem.show_fail()
				die.animate_return()
			return
	die.animate_return()

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
