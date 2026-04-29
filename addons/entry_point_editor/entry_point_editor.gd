@tool
extends EditorInspectorPlugin

func _can_handle(object: Object) -> bool:
	return object is StructureBase

func _parse_begin(object: Object) -> void:
	var panel := EntryPointPanel.new(object as StructureBase)
	add_custom_control(panel)


class EntryPointPanel extends VBoxContainer:
	const UNIT_HEIGHT := 0.289
	# HEX_SIZE (circumradius) = SQRT3/2 ≈ 0.866; apothem = circumradius × SQRT3/2 = 0.75
	const HEX_APOTHEM := 0.75

	var _structure: StructureBase
	var _edge_option: OptionButton
	var _height_spin: SpinBox
	var _entry_list: VBoxContainer

	func _init(structure: StructureBase) -> void:
		_structure = structure

	func _ready() -> void:
		_build_ui()
		_refresh_list()

	func _build_ui() -> void:
		var add_label := Label.new()
		add_label.text = "Add Entry Point"
		add_child(add_label)

		var edge_row := HBoxContainer.new()
		add_child(edge_row)
		var edge_label := Label.new()
		edge_label.text = "Edge (0-5):"
		edge_row.add_child(edge_label)
		_edge_option = OptionButton.new()
		_edge_option.add_item("0 - Right")
		_edge_option.add_item("1 - Bottom")
		_edge_option.add_item("2 - Bottom-Left")
		_edge_option.add_item("3 - Top-Left")
		_edge_option.add_item("4 - Top")
		_edge_option.add_item("5 - Top-Right")
		edge_row.add_child(_edge_option)

		var height_row := HBoxContainer.new()
		add_child(height_row)
		var height_label := Label.new()
		height_label.text = "Height level:"
		height_row.add_child(height_label)
		_height_spin = SpinBox.new()
		_height_spin.min_value = 0
		_height_spin.max_value = 20
		_height_spin.step = 1
		height_row.add_child(_height_spin)

		var add_btn := Button.new()
		add_btn.text = "Add Entry Point"
		add_btn.pressed.connect(_on_add_pressed)
		add_child(add_btn)

		var list_label := Label.new()
		list_label.text = "Entry Points:"
		add_child(list_label)

		_entry_list = VBoxContainer.new()
		add_child(_entry_list)

	func _on_add_pressed() -> void:
		_add_entry_point(_edge_option.selected, int(_height_spin.value))

	func _add_entry_point(edge: int, height: int) -> void:
		if not is_instance_valid(_structure):
			return

		var marker_name := "Entry_E%d_H%d" % [edge, height]

		for child in _structure.get_children():
			if child.name == marker_name:
				push_warning("Entry point %s already exists on %s" % [marker_name, _structure.name])
				return

		var angle_rad := deg_to_rad(edge * 60.0 + 30.0)
		var x := cos(angle_rad) * HEX_APOTHEM
		var z := sin(angle_rad) * HEX_APOTHEM
		var y := height * UNIT_HEIGHT
		var local_pos := Vector3(x, y, z)

		var marker := Marker3D.new()
		marker.name = marker_name
		marker.position = local_pos
		marker.gizmo_extents = 0.15

		var edited_root := EditorInterface.get_edited_scene_root()
		_structure.add_child(marker)
		marker.owner = edited_root

		EditorInterface.mark_scene_as_unsaved()
		_refresh_list()

	func _remove_entry_point(marker: Marker3D) -> void:
		marker.get_parent().remove_child(marker)
		marker.queue_free()
		EditorInterface.mark_scene_as_unsaved()
		_refresh_list()

	func _refresh_list() -> void:
		for child in _entry_list.get_children():
			_entry_list.remove_child(child)
			child.queue_free()

		if not is_instance_valid(_structure):
			return

		for child in _structure.find_children("Entry_*", "Marker3D", false, false):
			var marker := child as Marker3D
			var raw: String = marker.name
			# Parse "Entry_E{edge}_H{height}"
			var body := raw.trim_prefix("Entry_")
			var parts := body.split("_")
			var edge_str := parts[0].trim_prefix("E") if parts.size() > 0 else "?"
			var height_str := parts[1].trim_prefix("H") if parts.size() > 1 else "?"

			var row := HBoxContainer.new()
			var lbl := Label.new()
			lbl.text = "Edge %s | Height %s" % [edge_str, height_str]
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(lbl)

			var remove_btn := Button.new()
			remove_btn.text = "Remove"
			remove_btn.pressed.connect(_remove_entry_point.bind(marker))
			row.add_child(remove_btn)

			_entry_list.add_child(row)
