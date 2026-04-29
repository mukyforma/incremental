class_name PlacementSystem
extends Node3D

# ── Signals ────────────────────────────────────────────────────────────────────
## Emitted when the user confirms a placement in build mode.
## skip_support is true for floating-snapped rails.
signal placement_confirmed(hex: Vector2i, height: int, scene: PackedScene, skip_support: bool)
## Emitted every frame while hovering in build mode.
signal placement_hovered(hex: Vector2i, height: int, valid: bool)
## Emitted when the hovered structure changes in delete mode (null = none).
signal structure_hovered(structure: StructureBase)
## Emitted when placement is cancelled (tool switched away).
signal placement_cancelled()

# ── Exports ────────────────────────────────────────────────────────────────────
@export var ghost_preview : GhostPreviewComponent
@export var camera        : Camera3D

# ── Ground plane ───────────────────────────────────────────────────────────────
var _plane : Plane = Plane(Vector3.UP, 0.0)

# ── Face-hit state (Part 1) ────────────────────────────────────────────────────
var _face_active     : bool     = false
var _face_hit_pos    : Vector3  = Vector3.ZERO
var _face_hit_normal : Vector3  = Vector3.ZERO
var _face_is_top     : bool     = false
var _face_target_hex : Vector2i = Vector2i.ZERO
var _face_target_h   : int      = 0
## Hex of the SolidHex that was actually hit (lateral face). The debug
## rectangle belongs on this face, not on _face_target_hex (adjacent cell).
var _face_source_hex : Vector2i = Vector2i.ZERO

# ── Delete-mode hover ──────────────────────────────────────────────────────────
var _hovered_structure : StructureBase = null

# ── Misc ───────────────────────────────────────────────────────────────────────
var _ghost_hex  : Vector2i = Vector2i(2147483647, 2147483647)
var _debug_node = null     # FacePlacementDebug — untyped to avoid stale-cache errors

# ── Lifecycle ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	if HexGrid.debug_faces:
		_debug_node = FacePlacementDebug.new()
		_debug_node.name = "FacePlacementDebug"
		add_child(_debug_node)

func _process(_delta: float) -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	if PlacementController.active_tool == &"delete":
		_update_delete_hover(mouse_pos)
	else:
		if _hovered_structure != null:
			_hovered_structure = null
			structure_hovered.emit(null)
		_update_hover(mouse_pos)

# ── Public API ─────────────────────────────────────────────────────────────────

## Called by Main on a left-click in build mode.
## Validates and emits placement_confirmed with the current ghost position.
func confirm_placement() -> void:
	var type : StringName = PlacementController.active_structure

	if _face_active:
		if not _validate_and_print(type, _face_target_hex, _face_target_h, false):
			return
		placement_confirmed.emit(
			_face_target_hex, _face_target_h,
			StructureRegistry.get_scene(type), false)
		return

	# Ground-plane fallback
	if camera == null:
		return
	var hit = _plane.intersects_ray(
		camera.project_ray_origin(get_viewport().get_mouse_position()),
		camera.project_ray_normal(get_viewport().get_mouse_position()))
	if hit == null:
		return
	var hex  : Vector2i = HexGrid.world_to_hex(hit)
	var top_h : int     = HexGrid.get_top_height(hex)
	var h     : int     = max(0, top_h + 1)
	if not _validate_and_print(type, hex, h, false):
		return
	placement_confirmed.emit(hex, h, StructureRegistry.get_scene(type), false)

## Returns the StructureBase currently under the cursor (delete mode), or null.
func get_hovered_structure() -> StructureBase:
	return _hovered_structure

## Returns the hex currently projected under the mouse (build hover or ground fallback).
func get_current_hex() -> Vector2i:
	if _face_active:
		return _face_target_hex
	return _ghost_hex

# ── Hover — build mode ────────────────────────────────────────────────────────
func _update_hover(screen_pos: Vector2) -> void:
	if camera == null:
		return

	# ── Part 1: Face raycast (layer 2 = SolidHexFace only) ────────────────────
	var space_state := get_viewport().get_world_3d().direct_space_state
	var ray_origin  := camera.project_ray_origin(screen_pos)
	var ray_end     := ray_origin + camera.project_ray_normal(screen_pos) * 1000.0
	var query       := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 2)
	var face_result := space_state.intersect_ray(query)

	_face_active = false

	if not face_result.is_empty():
		_face_hit_pos    = face_result["position"]
		_face_hit_normal = face_result["normal"]
		_face_is_top     = _face_hit_normal.dot(Vector3.UP) > 0.9

		if _face_is_top:
			var structure := _find_structure_base(face_result["collider"])
			var base_h    : int = structure.height_level if structure != null else 0
			var span      : int = HexGrid.HEIGHT_SPANS.get(
				structure.structure_type if structure != null else &"", 1)
			_face_target_hex = HexGrid.world_to_hex(_face_hit_pos)
			_face_target_h   = base_h + span
		else:
			var adjacent_point := _face_hit_pos + _face_hit_normal * 0.1
			_face_target_hex = HexGrid.world_to_hex(adjacent_point)
			_face_target_h   = max(0, HexGrid.world_to_height_level(_face_hit_pos.y))
			var hit_struct := _find_structure_base(face_result["collider"])
			_face_source_hex = hit_struct.hex_position if hit_struct != null \
				else HexGrid.world_to_hex(_face_hit_pos)

		_face_active = true
		var occ: Array[Vector2i] = [_face_target_hex]
		var ghost := ghost_preview.get_ghost()
		if is_instance_valid(ghost) and ghost.has_method(&"get_occupied_hexes"):
			occ = ghost.get_occupied_hexes(_face_target_hex, PlacementController.placement_rotation)
		var valid := HexGrid.can_place_multi(occ, _face_target_h)
		placement_hovered.emit(_face_target_hex, _face_target_h, valid)
		_move_ghost_at(_face_target_hex, _face_target_h)
		_push_debug_state()
		return

	# ── Fall back: ground-plane raycast ───────────────────────────────────────
	var hit = _plane.intersects_ray(ray_origin, camera.project_ray_normal(screen_pos))
	if hit != null:
		var hex   : Vector2i = HexGrid.world_to_hex(hit)
		var top_h : int      = HexGrid.get_top_height(hex)
		var height: int      = max(0, top_h + 1)
		_move_ghost_at(hex, height)
		var occ: Array[Vector2i] = [hex]
		var ghost := ghost_preview.get_ghost()
		if is_instance_valid(ghost) and ghost.has_method(&"get_occupied_hexes"):
			occ = ghost.get_occupied_hexes(hex, PlacementController.placement_rotation)
		var valid := HexGrid.can_place_multi(occ, height)
		placement_hovered.emit(hex, height, valid)

	_push_debug_state()

# ── Ghost positioning + snap ───────────────────────────────────────────────────
func _move_ghost_at(hex: Vector2i, height: int) -> void:
	var ghost := ghost_preview.get_ghost()
	if not is_instance_valid(ghost):
		return

	_ghost_hex            = hex
	ghost.global_position = HexGrid.hex_to_world_at_height(hex, height)
	ghost.rotation.y      = _hex_rotation(PlacementController.placement_rotation)
	ghost.visible         = true

	var occupied: Array[Vector2i] = [hex]
	if ghost.has_method(&"get_occupied_hexes"):
		occupied = ghost.get_occupied_hexes(hex, PlacementController.placement_rotation)
	ghost_preview.set_valid(HexGrid.can_place_multi(occupied, height))

func _move_ghost(hex: Vector2i) -> void:
	var top_h  : int = HexGrid.get_top_height(hex)
	var height : int = max(0, top_h + 1)
	_move_ghost_at(hex, height)

# ── Hover — delete mode ────────────────────────────────────────────────────────
func _update_delete_hover(screen_pos: Vector2) -> void:
	if camera == null:
		return
	var space_state := get_viewport().get_world_3d().direct_space_state
	var ray_origin  := camera.project_ray_origin(screen_pos)
	var ray_end     := ray_origin + camera.project_ray_normal(screen_pos) * 1000.0
	var result      := space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(ray_origin, ray_end))

	var found : StructureBase = null
	if not result.is_empty():
		found = _find_structure_base(result["collider"])

	if found == _hovered_structure:
		return
	_hovered_structure = found
	structure_hovered.emit(found)

# ── Debug state push ───────────────────────────────────────────────────────────
func _push_debug_state() -> void:
	if _debug_node == null:
		return

	var can_place := false
	if _face_active:
		var dbg_ghost := ghost_preview.get_ghost()
		var occ: Array[Vector2i] = [_face_target_hex]
		if is_instance_valid(dbg_ghost) and dbg_ghost.has_method(&"get_occupied_hexes"):
			occ = dbg_ghost.get_occupied_hexes(_face_target_hex, PlacementController.placement_rotation)
		can_place = HexGrid.can_place_multi(occ, _face_target_h)

	_debug_node.set_face_state(
		_face_active, _face_is_top,
		_face_hit_pos, _face_hit_normal,
		_face_target_hex, _face_source_hex, _face_target_h,
		can_place)

	var _empty: Array[Vector3] = []
	_debug_node.set_snap_state(false, 0.0, _empty, Vector3.INF, Vector3.INF, _empty)

# ── Validation helper ──────────────────────────────────────────────────────────
func _validate_and_print(type: StringName, hex: Vector2i, height: int, skip_support: bool) -> bool:
	if type in HexGrid.GROUND_ONLY_TYPES and height != 0:
		print("Cannot place %s: must be placed at height 0" % type)
		return false

	if not skip_support:
		if type in HexGrid.SOLID_TYPES and not HexGrid.can_place_solid_hex(hex, height):
			print("Cannot place SolidHex at %s height %d — support rules not met" % [hex, height])
			return false

	var occupied: Array[Vector2i] = [hex]
	var ghost := ghost_preview.get_ghost()
	if is_instance_valid(ghost) and ghost.has_method(&"get_occupied_hexes"):
		occupied = ghost.get_occupied_hexes(hex, PlacementController.placement_rotation)

	if not HexGrid.can_place_multi(occupied, height):
		print("Cannot place %s: one or more occupied hexes blocked at height %d" % [type, height])
		return false

	var span: int = HexGrid.HEIGHT_SPANS.get(type, 1)
	for i in range(1, span):
		for occ_hex in occupied:
			var cell := HexGrid.get_cell(occ_hex)
			if cell != null and cell.stack.has(height + i):
				print("Cannot place %s: height %d is already occupied" % [type, height + i])
				return false

	return true

# ── Utilities ──────────────────────────────────────────────────────────────────
func _find_structure_base(node: Node) -> StructureBase:
	var current := node
	while current != null:
		if current is StructureBase:
			return current as StructureBase
		current = current.get_parent()
	return null

func _hex_rotation(step: int) -> float:
	return step * (PI / 3.0)
