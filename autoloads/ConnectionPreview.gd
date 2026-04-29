extends Node

## Autoload: displays ghost rails and confirm buttons for detected connections.

var _previews: Array[Dictionary] = []
# Each: { "connection": ConnectionScanner.Connection, "ghost": Node3D, "button": Button }

var _debug_node: Node3D = null
var _mat_yellow: StandardMaterial3D

# ── Public API ─────────────────────────────────────────────────────────────────

func show_connections(connections: Array) -> void:
	clear()
	for conn in connections:
		var ghost := _spawn_ghost(conn)
		var button := _spawn_confirm_button(conn)
		_previews.append({
			"connection": conn,
			"ghost": ghost,
			"button": button,
		})

func clear() -> void:
	for preview in _previews:
		if is_instance_valid(preview.ghost):
			preview.ghost.queue_free()
		if is_instance_valid(preview.button):
			preview.button.queue_free()
	_previews.clear()

# ── Ghost ──────────────────────────────────────────────────────────────────────

func _spawn_ghost(conn) -> Node3D:
	var scene: PackedScene = StructureRegistry.get_scene(conn.rail_type)
	if scene == null:
		return Node3D.new()
	var ghost: Node3D = scene.instantiate()
	get_tree().root.add_child(ghost)

	ghost.global_position = conn.midpoint_world
	var dir_xz := Vector3(conn.direction.x, 0.0, conn.direction.z)
	if dir_xz.length_squared() > 0.001:
		ghost.look_at(ghost.global_position + dir_xz, Vector3.UP)

	for mesh in ghost.find_children("*", "MeshInstance3D", true):
		var mi := mesh as MeshInstance3D
		var mat := mi.get_surface_override_material(0)
		if mat == null:
			mat = StandardMaterial3D.new()
		mat = mat.duplicate()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.5
		mi.set_surface_override_material(0, mat)

	for body in ghost.find_children("*", "StaticBody3D", true):
		var sb := body as StaticBody3D
		sb.collision_layer = 0
		sb.collision_mask = 0

	return ghost

# ── Confirm button ─────────────────────────────────────────────────────────────

func _spawn_confirm_button(conn) -> Button:
	var button := Button.new()
	button.text = "✓"
	button.custom_minimum_size = Vector2(40, 40)
	_get_canvas_layer().add_child(button)
	button.set_meta("world_pos", conn.midpoint_world + Vector3(0, 0.4, 0))
	button.pressed.connect(_on_confirm.bind(conn))
	return button

# ── Process ────────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	for preview in _previews:
		var button: Button = preview.button
		if not is_instance_valid(button):
			continue
		var world_pos: Vector3 = button.get_meta("world_pos")
		var screen_pos := camera.unproject_position(world_pos)
		button.global_position = screen_pos - button.size * 0.5

	_update_debug_vis()

# ── Confirm ────────────────────────────────────────────────────────────────────

func _on_confirm(conn) -> void:
	var edge_a := ConnectionScanner._parse_edge(conn.entry_a.marker.name)
	var rot_steps := edge_a % 3
	var hex := HexGrid.world_to_hex(conn.midpoint_world)
	var height := HexGrid.world_to_height_level(conn.midpoint_world.y)
	var parent := get_tree().current_scene
	var s := HexGrid.spawn_structure(hex, height, conn.rail_type, parent, rot_steps)
	if s != null:
		s.rotation.y = rot_steps * (PI / 3.0)
	EntryPointRegistry.set_occupied(conn.entry_a.marker, true)
	EntryPointRegistry.set_occupied(conn.entry_b.marker, true)
	_remove_preview_for_connection(conn)

func _remove_preview_for_connection(conn) -> void:
	for i in _previews.size():
		if _previews[i].connection == conn:
			if is_instance_valid(_previews[i].ghost):
				_previews[i].ghost.queue_free()
			if is_instance_valid(_previews[i].button):
				_previews[i].button.queue_free()
			_previews.remove_at(i)
			return

# ── Canvas layer ───────────────────────────────────────────────────────────────

func _get_canvas_layer() -> CanvasLayer:
	var existing := get_tree().root.find_child("ConnectionUI", true, false)
	if existing is CanvasLayer:
		return existing as CanvasLayer
	var layer := CanvasLayer.new()
	layer.name = "ConnectionUI"
	layer.layer = 10
	get_tree().root.add_child(layer)
	return layer

# ── Debug visualization ────────────────────────────────────────────────────────

func _update_debug_vis() -> void:
	if not DebugFlags.show_entry_points:
		if _debug_node != null and is_instance_valid(_debug_node):
			_debug_node.queue_free()
			_debug_node = null
		return

	if _debug_node == null or not is_instance_valid(_debug_node):
		var scene := get_tree().current_scene
		if scene == null:
			return
		_debug_node = Node3D.new()
		scene.add_child(_debug_node)

	for child in _debug_node.get_children():
		_debug_node.remove_child(child)
		child.free()

	_ensure_debug_materials()

	for preview in _previews:
		var conn = preview.connection
		_add_debug_line(
			conn.entry_a.marker.global_position,
			conn.entry_b.marker.global_position)
		_add_debug_label(conn)

func _ensure_debug_materials() -> void:
	if _mat_yellow != null:
		return
	_mat_yellow = StandardMaterial3D.new()
	_mat_yellow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_yellow.albedo_color = Color.YELLOW

func _add_debug_line(from: Vector3, to: Vector3) -> void:
	var dist := from.distance_to(to)
	if dist < 0.001:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.02, 0.02, dist)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat_yellow
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_debug_node.add_child(mi)
	mi.global_position = (from + to) * 0.5
	mi.look_at(to, Vector3.UP)

func _add_debug_label(conn) -> void:
	var label := Label3D.new()
	label.text = "%s (%d)" % [conn.rail_type, conn.hex_distance]
	label.font_size = 24
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_debug_node.add_child(label)
	label.global_position = conn.midpoint_world + Vector3(0, 0.3, 0)
