extends Node

## Autoload: tracks all active entry points from placed structures and which are occupied.

var _entries: Array[Dictionary] = []
# Each: { "marker": Marker3D, "structure": StructureBase, "occupied": bool }

# ── Debug visuals ──────────────────────────────────────────────────────────────
var _debug_node: Node3D = null
var _mat_green: StandardMaterial3D
var _mat_orange: StandardMaterial3D
var _sphere_mesh: SphereMesh

# ── Public API ─────────────────────────────────────────────────────────────────

func register_structure(structure: StructureBase) -> void:
	for marker in structure.find_children("Entry_*", "Marker3D", true, false):
		_entries.append({
			"marker":    marker as Marker3D,
			"structure": structure,
			"occupied":  false,
		})

func unregister_structure(structure: StructureBase) -> void:
	_entries = _entries.filter(func(e: Dictionary) -> bool:
		return e["structure"] != structure)

func get_free_entries(structure: StructureBase) -> Array[Dictionary]:
	return _entries.filter(func(e: Dictionary) -> bool:
		return e["structure"] == structure and not e["occupied"])

func get_all_free_entries() -> Array[Dictionary]:
	return _entries.filter(func(e: Dictionary) -> bool:
		return not e["occupied"])

func set_occupied(marker: Marker3D, value: bool) -> void:
	for e in _entries:
		if e["marker"] == marker:
			e["occupied"] = value
			return

func get_entry_world_position(entry: Dictionary) -> Vector3:
	return (entry["marker"] as Marker3D).global_position

# ── Debug rendering ────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not DebugFlags.show_entry_points:
		if _debug_node != null and is_instance_valid(_debug_node):
			_debug_node.queue_free()
			_debug_node = null
		return
	_update_debug_vis()

func _update_debug_vis() -> void:
	if _debug_node == null or not is_instance_valid(_debug_node):
		_debug_node = Node3D.new()
		var scene := get_tree().current_scene
		if scene == null:
			return
		scene.add_child(_debug_node)

	for child in _debug_node.get_children():
		_debug_node.remove_child(child)
		child.free()

	_ensure_debug_resources()

	for entry in _entries:
		var marker: Marker3D = entry["marker"]
		if not is_instance_valid(marker):
			continue
		var mat := _mat_green if not entry["occupied"] else _mat_orange
		_add_debug_sphere(marker.global_position, mat)

func _ensure_debug_resources() -> void:
	if _mat_green != null:
		return
	_mat_green = StandardMaterial3D.new()
	_mat_green.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_green.albedo_color = Color.GREEN

	_mat_orange = StandardMaterial3D.new()
	_mat_orange.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_orange.albedo_color = Color.ORANGE

	_sphere_mesh = SphereMesh.new()
	_sphere_mesh.radius = 0.05
	_sphere_mesh.height = 0.1

func _add_debug_sphere(pos: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere_mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_debug_node.add_child(mi)
	mi.global_position = pos
