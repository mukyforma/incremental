extends Node

const SAVES_DIR := "user://saves/"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVES_DIR)

# save

func save(save_name: String) -> bool:
	var structures: Array = []
	var seen: Dictionary = {}

	for hex in HexGrid._cells:
		var cell: HexCell = HexGrid._cells[hex]
		for h in cell.stack:
			var s: Node3D = cell.stack[h]
			if seen.has(s):
				continue
			seen[s] = true
			if not ("structure_type" in s):
				continue
			var stype: String = str(s.structure_type)
			if stype == "" or stype == "marble":
				continue
			var base_h: int = s.height_level if "height_level" in s else h
			structures.append({
				"hex_x":      hex.x,
				"hex_y":      hex.y,
				"height":     base_h,
				"type":       stype,
				"rotation_y": s.rotation.y
			})

	var data: Dictionary = {
		"version":    1,
		"name":       save_name,
		"timestamp":  Time.get_datetime_string_from_system(),
		"structures": structures
	}

	var path: String = SAVES_DIR + save_name + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: não foi possível gravar em " + path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("SaveSystem: salvo em " + path)
	return true

# load

## Returns array of structure dicts, or empty array on failure.
func load_save(save_name: String) -> Array:
	var path: String = SAVES_DIR + save_name + ".json"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveSystem: arquivo não encontrado: " + path)
		return []
	var text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("SaveSystem: erro ao parsear " + path)
		return []

	var data = json.get_data()
	if not (data is Dictionary) or not data.has("structures"):
		push_error("SaveSystem: formato inválido em " + path)
		return []

	const CURRENT_VERSION = 1
	var version = data.get("version", 0)
	if version != CURRENT_VERSION:
		push_warning("SaveSystem: save file version %d does not match current version %d. Data may be incompatible." % [version, CURRENT_VERSION])
		return []

	return data["structures"]

# lista

func list_saves() -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(SAVES_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".json"):
			result.append(fname.trim_suffix(".json"))
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort()
	result.reverse()   # mais recente primeiro (nomes começam com data)
	return result

func get_latest_save() -> String:
	var saves := list_saves()
	return saves[0] if saves.size() > 0 else ""
