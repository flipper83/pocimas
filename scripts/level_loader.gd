class_name LevelLoader

# Level JSON format:
# {
#   "dice": {"red": 2, "white": 1, "green": 2, "blue": 2},
#   "grid_unit": 110,
#   "elements": [{"id":0, "type":"fire", "gx":2, "gy":1}, ...],
#   "operations": [{"from":0, "to":1, "type":"gt"}, ...],
#   "volatility": {"gx":3, "gy":0}
# }

static func load_from_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("LevelLoader: cannot open %s" % path)
		return {}
	var text := file.get_as_text()
	file.close()
	return parse_json(text)

static func parse_json(text: String) -> Dictionary:
	var result := JSON.parse_string(text)
	if result == null:
		push_error("LevelLoader: invalid JSON")
		return {}
	return result as Dictionary

static func save_to_file(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("LevelLoader: cannot write %s" % path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

static func default_level() -> Dictionary:
	return {
		"dice": {"red": 2, "white": 1, "green": 2, "blue": 2},
		"grid_unit": 110,
		"elements": [],
		"operations": [],
		"volatility": {"gx": 0, "gy": 0},
	}
