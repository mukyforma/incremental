extends Node

const SAVE_MENU_SCR := preload("res://ui/SaveMenu.gd")

# ── Scene refs (nodes added as children in Main.tscn) ─────────────────────────
@onready var _cam_ctrl        : CameraController        = $CameraController
@onready var _renderer        : HexRenderer             = $HexRenderer
@onready var _ghost_preview   : GhostPreviewComponent   = $GhostPreview
@onready var _mat_highlight   : MaterialHighlightComponent = $MaterialHighlight
@onready var _placement_system: PlacementSystem         = $PlacementSystem

# ── FPS counter ────────────────────────────────────────────────────────────────
var _fps_label  : Label = null
var _fps_smooth : float = 60.0

var _save_menu : CanvasLayer = null

# ──────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# CameraController added as child in Main.tscn
	# HexRenderer added as child in Main.tscn
	_renderer.set_camera(_cam_ctrl.get_camera())
	_renderer.update_visible_region()

	# HUD (CanvasLayer → HUD) added as child in Main.tscn
	_add_save_menu()

	# PlacementSystem added as child of Main in Main.tscn
	_placement_system.camera       = _cam_ctrl.get_camera()
	_placement_system.ghost_preview = _ghost_preview
	_placement_system.placement_confirmed.connect(_on_placement_confirmed)
	_placement_system.placement_hovered.connect(_on_placement_hovered)
	_placement_system.structure_hovered.connect(_on_structure_hovered)

	# Load latest save or build demo
	var latest := SaveSystem.get_latest_save()
	if latest != "":
		_load_from_save(latest)
	else:
		_build_demo()

	StructureEvents.spawn_requested.connect(_on_spawn_requested)
	StructureEvents.reparent_requested.connect(_on_reparent_requested)
	PlacementController.selection_changed.connect(_on_placement_changed)
	_ghost_preview.rebuild(
		StructureRegistry.get_scene(PlacementController.active_structure)
		if PlacementController.active_tool == &"build" else null)

	_fps_label = find_child("FPS") as Label

	print("─── Controls ───────────────────────────────")
	print("  WASD / arrows    Pan camera")
	print("  Scroll wheel     Zoom")
	print("  Right-drag       Pan (mouse)")
	print("  1–6              Select structure")
	print("  Q / E            Rotate structure CCW / CW")
	print("  B / X / C        Build / Delete / Eyedropper")
	print("  Left click       Place / Delete / Pick")
	print("  R                Reset demo")
	print("────────────────────────────────────────────")

# ── Save menu ──────────────────────────────────────────────────────────────────
func _add_save_menu() -> void:
	_save_menu = SAVE_MENU_SCR.new()
	add_child(_save_menu)
	_save_menu.saved.connect(_on_save_requested)
	_save_menu.loaded.connect(_on_load_requested)

# ── Demo scene ─────────────────────────────────────────────────────────────────
func _build_demo() -> void:
	HexGrid.spawn_structure(Vector2i(1, 0), 0, &"marble_spawn", self)

	if HexGrid.can_place_solid_hex(Vector2i(-1, 0), 0):
		HexGrid.spawn_structure(Vector2i(-1, 0), 0, &"solid1", self)
	if HexGrid.can_place_solid_hex(Vector2i(-1, 0), 1):
		HexGrid.spawn_structure(Vector2i(-1, 0), 1, &"solid1", self)

func _reset_demo() -> void:
	HexGrid.despawn_all()
	_build_demo()

# ── Input ──────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("ui_cancel"):
			_save_menu.toggle()
			return

	if _save_menu.visible:
		return

	_cam_ctrl.handle_input(event)

	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("build_rotate_cw"):
			_reset_demo()
			print("Demo reset.")

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_left_click()

func _process(delta: float) -> void:
	if delta > 0.0 and _fps_label:
		_fps_smooth = lerp(_fps_smooth, 1.0 / delta, 0.05)
		_fps_label.text = "%d FPS" % roundi(_fps_smooth)

	if _save_menu.visible:
		return
	_cam_ctrl.process_wasd(delta)
	_renderer.update_visible_region()

# ── Click dispatch ─────────────────────────────────────────────────────────────
func _on_left_click() -> void:
	match PlacementController.active_tool:
		&"build":
			_placement_system.confirm_placement()
		&"delete":
			var hovered := _placement_system.get_hovered_structure()
			if hovered != null:
				_do_delete_by_structure(hovered)
		&"eyedropper":
			_do_eyedrop(_placement_system.get_current_hex())
		&"select_area":
			pass

# ── PlacementSystem signal handlers ───────────────────────────────────────────
func _on_placement_confirmed(hex: Vector2i, height: int, _scene: PackedScene, skip_support: bool) -> void:
	var type : StringName = PlacementController.active_structure
	var s := HexGrid.spawn_structure(hex, height, type, self)
	if s == null:
		return
	s.rotation.y = _hex_rotation(PlacementController.placement_rotation)
	print("Placed %s at col=%d row=%d height=%d rot=%d°%s" % [
		type, hex.x, hex.y, height,
		PlacementController.placement_rotation * 60,
		" [SNAPPED]" if skip_support else ""])

func _on_placement_hovered(hex: Vector2i, _height: int, _valid: bool) -> void:
	_renderer.set_hover(hex)

func _on_structure_hovered(structure: StructureBase) -> void:
	_mat_highlight.clear()
	if structure != null:
		_mat_highlight.highlight(structure)
		_renderer.set_hover(structure.hex_position)

# ── Delete ─────────────────────────────────────────────────────────────────────
func _do_delete_by_structure(structure: StructureBase) -> void:
	_mat_highlight.clear()
	var hex := structure.hex_position
	var h   := structure.height_level
	print("Deleted %s at col=%d row=%d height=%d" % [structure.structure_type, hex.x, hex.y, h])
	HexGrid.despawn_structure(hex, h)

# ── Eyedropper ─────────────────────────────────────────────────────────────────
func _do_eyedrop(hex: Vector2i) -> void:
	var type : StringName = HexGrid.get_top_structure_type(hex)
	if type != &"":
		PlacementController.set_structure(type)
		print("Eyedropper: picked '%s'" % type)
	PlacementController.set_tool(&"build")

# ── Placement change ───────────────────────────────────────────────────────────
func _on_placement_changed() -> void:
	_mat_highlight.clear()
	_ghost_preview.rebuild(
		StructureRegistry.get_scene(PlacementController.active_structure)
		if PlacementController.active_tool == &"build" else null)

# ── StructureEvents handlers ──────────────────────────────────────────────────
func _on_spawn_requested(node: Node3D, global_pos: Vector3) -> void:
	add_child(node)
	node.global_position = global_pos

func _on_reparent_requested(node: Node, new_parent: Node) -> void:
	node.reparent(new_parent)

# ── Utilities ──────────────────────────────────────────────────────────────────
func _hex_rotation(step: int) -> float:
	return step * (PI / 3.0)

# ── Save / Load ────────────────────────────────────────────────────────────────
func _on_save_requested(save_name: String) -> void:
	if SaveSystem.save(save_name):
		print("Salvo: " + save_name)
	else:
		push_error("Falha ao salvar: " + save_name)

func _on_load_requested(save_name: String) -> void:
	_load_from_save(save_name)

func _load_from_save(save_name: String) -> void:
	var structures: Array = SaveSystem.load_save(save_name)
	if structures.is_empty():
		push_error("Nenhuma estrutura no save: " + save_name)
		return

	HexGrid.despawn_all()

	for s_data in structures:
		var hex    := Vector2i(int(s_data.hex_x), int(s_data.hex_y))
		var height := int(s_data.height)
		var stype  := StringName(str(s_data.type))
		var rot    := float(s_data.rotation_y)
		var rot_steps: int = posmod(roundi(rot / (PI / 3.0)), 6)
		var s := HexGrid.spawn_structure(hex, height, stype, self, rot_steps)
		if s != null:
			s.rotation.y = rot

	print("Save carregado: " + save_name)
