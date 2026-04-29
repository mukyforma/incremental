class_name HUD
extends Control

# ── Scenes ─────────────────────────────────────────────────────────────────────
const STRUCTURE_BTN_SCENE := preload("res://ui/StructureButton.tscn")
const TOOL_BTN_SCENE      := preload("res://ui/ToolButton.tscn")

# ── Config ─────────────────────────────────────────────────────────────────────
const BTN_SPACING   : int   = 8
const MARGIN_BOTTOM : float = 12.0

const _STRUCTURE_CONFIGS := [
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
	[&"collector",     "",  1.5],
]

const _NEW_STRUCTURE_CONFIGS := [
	[&"deflector_alto",  "", 3.0],
	[&"deflector_baixo", "", 3.0],
	[&"impulsor_raso",   "", 2.0],
	[&"impulsor_medio",  "", 2.0],
	[&"impulsor_alto",   "", 2.0],
	[&"comutador",       "", 2.5],
]

# action_name → structure_type; populated by _build_structure_row
var _structure_shortcuts: Dictionary = {}

# ── Node refs (built in HUD.tscn) ──────────────────────────────────────────────
@onready var _panel : PanelContainer = $PanelContainer
@onready var _vbox  : VBoxContainer  = $PanelContainer/MarginContainer/VBoxContainer

# ── Lifecycle ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_vbox.add_child(_build_structure_row())
	_vbox.add_child(_build_tool_row())

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

# ── Structure row ──────────────────────────────────────────────────────────────
func _build_structure_row() -> HBoxContainer:
	var row := _make_hbox()
	var group := ButtonGroup.new()

	if StructureCatalog.definitions.size() > 0:
		for def in StructureCatalog.get_all():
			var btn: StructureButton = STRUCTURE_BTN_SCENE.instantiate()
			btn.structure_type = def.type
			btn.shortcut_key   = def.shortcut_key
			btn.button_group   = group
			row.add_child(btn)
			if def.shortcut_key != "":
				_structure_shortcuts["select_" + def.shortcut_key] = def.type
		return row

	# Fallback: class-level config arrays
	for cfg in _STRUCTURE_CONFIGS:
		var btn: StructureButton = STRUCTURE_BTN_SCENE.instantiate()
		btn.structure_type   = cfg[0]
		btn.shortcut_key     = cfg[1]
		btn.preview_cam_size = cfg[2]
		btn.button_group     = group
		row.add_child(btn)
		if cfg[1] != "":
			_structure_shortcuts["select_" + cfg[1]] = cfg[0]

	# ── Separator between original and new structures ──────────────────────
	var sep := VSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	sep.custom_minimum_size = Vector2(2, 0)
	row.add_child(sep)

	# ── New unlockable structures ──────────────────────────────────────────
	for cfg in _NEW_STRUCTURE_CONFIGS:
		var btn: StructureButton = STRUCTURE_BTN_SCENE.instantiate()
		btn.structure_type   = cfg[0]
		btn.shortcut_key     = cfg[1]
		btn.preview_cam_size = cfg[2]
		btn.button_group     = group
		row.add_child(btn)
		if cfg[1] != "":
			_structure_shortcuts["select_" + cfg[1]] = cfg[0]

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
	for action in _structure_shortcuts:
		if event.is_action_pressed(action):
			PlacementController.set_structure(_structure_shortcuts[action])
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("build_rotate_ccw"):
		PlacementController.rotate_ccw()
	elif event.is_action_pressed("tool_eyedrop"):
		PlacementController.rotate_cw()
	elif event.is_action_pressed("tool_build"):
		PlacementController.set_tool(&"build")
	elif event.is_action_pressed("tool_delete"):
		PlacementController.set_tool(&"delete")
	elif event.is_action_pressed("tool_cancel"):
		PlacementController.set_tool(&"eyedropper")
	else:
		return
	get_viewport().set_input_as_handled()
