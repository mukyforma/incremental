class_name HUD
extends Control

# ── Scenes ─────────────────────────────────────────────────────────────────────
const STRUCTURE_BTN_SCENE := preload("res://ui/StructureButton.tscn")
const TOOL_BTN_SCENE      := preload("res://ui/ToolButton.tscn")

# ── Config ─────────────────────────────────────────────────────────────────────
const PADDING       : float = 12.0
const ROW_SPACING   : float = 6.0
const BTN_SPACING   : int   = 8
const PANEL_COLOR   : Color = Color(0.10, 0.10, 0.12, 0.85)
const BORDER_COLOR  : Color = Color(0.22, 0.22, 0.25, 1.0)
const MARGIN_BOTTOM : float = 12.0

var _panel: PanelContainer

# ── Lifecycle ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_panel = _build_panel()
	add_child(_panel)

	get_tree().root.size_changed.connect(_reposition)
	call_deferred("_reposition")

# ── Layout ─────────────────────────────────────────────────────────────────────
func _reposition() -> void:
	if _panel == null:
		return
	var vp := get_viewport_rect().size
	_panel.position = Vector2(
		(vp.x - _panel.size.x) * 0.5,
		vp.y - _panel.size.y - MARGIN_BOTTOM
	)

func _build_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color                   = PANEL_COLOR
	style.corner_radius_top_left     = 10
	style.corner_radius_top_right    = 10
	style.corner_radius_bottom_left  = 10
	style.corner_radius_bottom_right = 10
	style.border_color               = BORDER_COLOR
	style.border_width_left          = 1
	style.border_width_right         = 1
	style.border_width_top           = 1
	style.border_width_bottom        = 1
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(PADDING))
	margin.add_theme_constant_override("margin_right",  int(PADDING))
	margin.add_theme_constant_override("margin_top",    int(PADDING))
	margin.add_theme_constant_override("margin_bottom", int(PADDING))
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(ROW_SPACING))
	margin.add_child(vbox)

	vbox.add_child(_build_structure_row())
	vbox.add_child(_build_tool_row())

	return panel

# ── Structure row ──────────────────────────────────────────────────────────────
func _build_structure_row() -> HBoxContainer:
	var row := _make_hbox()
	var group := ButtonGroup.new()

	var configs := [
		[&"marble_spawn",  "1", 1.0],
		[&"launch_cannon", "2", 1.2],
		[&"solid1",        "3", 2.0],
		[&"solid2",        "4", 2.0],
		[&"solid4",        "5", 2.0],
		[&"reto",          "6", 2.0],
		[&"curva60",       "7", 2.0],
		[&"curva120",      "8", 2.0],
		[&"rampa1",        "9", 2.0],
		[&"rampa2",        "",  2.5],
		[&"solid8",        "",  5.0],
		[&"speed_gate",    "0", 1.5],
	]
	for cfg in configs:
		var btn: StructureButton = STRUCTURE_BTN_SCENE.instantiate()
		btn.structure_type   = cfg[0]
		btn.shortcut_key     = cfg[1]
		btn.preview_cam_size = cfg[2]
		btn.button_group     = group
		row.add_child(btn)

	return row

# ── Tool row ───────────────────────────────────────────────────────────────────
func _build_tool_row() -> HBoxContainer:
	var row   := _make_hbox()
	var group := ButtonGroup.new()

	var configs := [
		[&"build",        "B", "⬡", "Build"],
		[&"delete",       "X", "✕", "Delete"],
		[&"select_area",  "S", "⬚", "Select Area"],
		[&"eyedropper",   "C", "◉", "Eyedropper"],
	]
	for cfg in configs:
		var btn: ToolButton = TOOL_BTN_SCENE.instantiate()
		btn.tool_name    = cfg[0]
		btn.shortcut_key = cfg[1]
		btn.icon_char    = cfg[2]
		btn.tool_label   = cfg[3]
		btn.button_group = group
		row.add_child(btn)

	return row

func _make_hbox() -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", BTN_SPACING)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	return hbox

# ── Keyboard shortcuts ─────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var handled := true
	match event.keycode:
		KEY_1: PlacementController.set_structure(&"marble_spawn")
		KEY_2: PlacementController.set_structure(&"launch_cannon")
		KEY_3: PlacementController.set_structure(&"solid1")
		KEY_4: PlacementController.set_structure(&"solid2")
		KEY_5: PlacementController.set_structure(&"solid4")
		KEY_6: PlacementController.set_structure(&"reto")
		KEY_7: PlacementController.set_structure(&"curva60")
		KEY_8: PlacementController.set_structure(&"curva120")
		KEY_9: PlacementController.set_structure(&"rampa1")
		KEY_0: PlacementController.set_structure(&"speed_gate")
		KEY_Q: PlacementController.rotate_ccw()
		KEY_E: PlacementController.rotate_cw()
		KEY_B: PlacementController.set_tool(&"build")
		KEY_X: PlacementController.set_tool(&"delete")
		KEY_C: PlacementController.set_tool(&"eyedropper")
		_:     handled = false
	if handled:
		get_viewport().set_input_as_handled()
