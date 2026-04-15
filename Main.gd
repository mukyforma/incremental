extends Node

const HUD_SCENE      := preload("res://ui/HUD.tscn")
const SAVE_MENU_SCR  := preload("res://ui/SaveMenu.gd")

# ── Scene refs ─────────────────────────────────────────────────────────────────
var _cam_ctrl  : CameraController
var _renderer  : HexRenderer
var _plane     : Plane = Plane(Vector3.UP, 0.0)

var _spawn_structure : MarbleSpawn = null
var _save_menu       : CanvasLayer  = null

# ── Ghost preview ──────────────────────────────────────────────────────────────
var _ghost     : Node3D  = null
var _ghost_hex : Vector2i = Vector2i(2147483647, 2147483647)

# ── FPS counter ────────────────────────────────────────────────────────────────
var _fps_label  : Label = null
var _fps_smooth : float = 60.0

# ── Part 1: Face-based placement state ────────────────────────────────────────
## True when the last raycast hit a SolidHex face.
var _face_active     : bool     = false
var _face_hit_pos    : Vector3  = Vector3.ZERO
var _face_hit_normal : Vector3  = Vector3.ZERO
var _face_is_top     : bool     = false

## The hex + height derived from the face normal — used as placement target
## instead of the ground-plane projection when _face_active is true.
var _face_target_hex : Vector2i = Vector2i.ZERO
var _face_target_h   : int      = 0

## Hex of the SolidHex that was actually hit (lateral face only).
## Distinct from _face_target_hex, which is the adjacent hex where the new
## structure will be placed. The debug rectangle belongs on this side.
var _face_source_hex : Vector2i = Vector2i.ZERO

# ── Part 2: TubeJoint snap state ───────────────────────────────────────────────
const SNAP_DISTANCE : float = 0.25

var _is_snapping          : bool    = false
var _snap_target_pos      : Vector3 = Vector3.INF
var _snapping_joint_world : Vector3 = Vector3.INF  # ghost joint that triggered snap

# ── Delete tool: hovered-structure highlight ───────────────────────────────────
## The StructureBase directly under the cursor while delete tool is active.
var _hovered_structure : StructureBase = null
## Saved material_override per MeshInstance3D so we can restore on un-hover.
var _hover_saved_mats  : Dictionary    = {}   # MeshInstance3D -> Variant

# ── Debug overlay ──────────────────────────────────────────────────────────────
var _debug_node : FacePlacementDebug = null

# ──────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_cam_ctrl = CameraController.new()
	add_child(_cam_ctrl)

	_renderer = HexRenderer.new()
	add_child(_renderer)
	_renderer.set_camera(_cam_ctrl.get_camera())
	_renderer.update_visible_region()

	_add_lighting()
	_add_hud()
	_add_save_menu()

	# Spawn debug overlay when enabled
	if HexGrid.debug_faces:
		_debug_node = FacePlacementDebug.new()
		_debug_node.name = "FacePlacementDebug"
		add_child(_debug_node)

	# Load latest save or build demo
	var latest := SaveSystem.get_latest_save()
	if latest != "":
		_load_from_save(latest)
	else:
		_build_demo()

	PlacementController.selection_changed.connect(_on_placement_changed)
	_rebuild_ghost()

	_fps_label = find_child("FPS") as Label

	print("─── Controls ───────────────────────────────")
	print("  WASD / arrows    Pan camera")
	print("  Scroll wheel     Zoom")
	print("  Right-drag       Pan (mouse)")
	print("  1–6              Select structure")
	print("  Q / E            Rotate structure CCW / CW")
	print("  B / X / C        Build / Delete / Eyedropper")
	print("  Left click       Place / Delete / Pick")
	print("  Space            Release marble from spawn")
	print("  R                Reset demo")
	print("────────────────────────────────────────────")

# ── HUD ────────────────────────────────────────────────────────────────────────
func _add_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var hud := HUD_SCENE.instantiate()
	canvas.add_child(hud)

# ── Save menu ──────────────────────────────────────────────────────────────────
func _add_save_menu() -> void:
	_save_menu = SAVE_MENU_SCR.new()
	add_child(_save_menu)
	_save_menu.saved.connect(_on_save_requested)
	_save_menu.loaded.connect(_on_load_requested)

# ── Demo scene ─────────────────────────────────────────────────────────────────
func _build_demo() -> void:
	var spawn := HexGrid.spawn_structure(Vector2i(1, 0), 0, &"marble_spawn", self)
	_spawn_structure = spawn as MarbleSpawn

	var cannon := HexGrid.spawn_structure(Vector2i(2, 0), 0, &"launch_cannon", self)
	cannon.rotation.y = _hex_rotation(1)

	if HexGrid.can_place_solid_hex(Vector2i(-1, 0), 0):
		HexGrid.spawn_structure(Vector2i(-1, 0), 0, &"solid1", self)
	if HexGrid.can_place_solid_hex(Vector2i(-1, 0), 1):
		HexGrid.spawn_structure(Vector2i(-1, 0), 1, &"solid1", self)

func _reset_demo() -> void:
	var to_remove: Array = []
	for hex in HexGrid._cells:
		for h in HexGrid._cells[hex].stack.keys():
			to_remove.append([hex, h])
	for entry in to_remove:
		HexGrid.despawn_structure(entry[0], entry[1])
	_spawn_structure = null
	_build_demo()

# ── Lighting ───────────────────────────────────────────────────────────────────
func _add_lighting() -> void:
	var env_node := WorldEnvironment.new()
	var env      := Environment.new()
	env.background_mode      = Environment.BG_COLOR
	env.background_color     = Color(0.05, 0.07, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.30, 0.35, 0.40)
	env.ambient_light_energy = 1.0
	env_node.environment     = env
	add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_energy     = 1.2
	sun.shadow_enabled   = true
	add_child(sun)

# ── Input ──────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_save_menu.toggle()
			return

	if _save_menu.visible:
		return

	_cam_ctrl.handle_input(event)

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				if _spawn_structure != null:
					_spawn_structure.release_marble()
					print("Marble released!")
			KEY_R:
				_reset_demo()
				print("Demo reset.")

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_left_click(event.position)

func _process(delta: float) -> void:
	if delta > 0.0 and _fps_label:
		_fps_smooth = lerp(_fps_smooth, 1.0 / delta, 0.05)
		_fps_label.text = "%d FPS" % roundi(_fps_smooth)

	if _save_menu.visible:
		return
	_cam_ctrl.process_wasd(delta)

	var mouse_pos := get_viewport().get_mouse_position()
	if PlacementController.active_tool == &"delete":
		_update_delete_hover(mouse_pos)
		if _hovered_structure != null:
			_renderer.set_hover(_hovered_structure.hex_position)
	else:
		if _hovered_structure != null:
			_clear_delete_highlight()
		_update_hover(mouse_pos)

	_renderer.update_visible_region()

# ── Hover ──────────────────────────────────────────────────────────────────────
func _update_hover(screen_pos: Vector2) -> void:
	var cam : Camera3D = _cam_ctrl.get_camera()

	# ── Part 1: Face raycast (layer 2 = SolidHexFace only) ────────────────────
	var space_state := get_viewport().get_world_3d().direct_space_state
	var ray_origin  := cam.project_ray_origin(screen_pos)
	var ray_end     := ray_origin + cam.project_ray_normal(screen_pos) * 1000.0
	var query       := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 2)
	var face_result := space_state.intersect_ray(query)

	_face_active = false

	if not face_result.is_empty():
		_face_hit_pos    = face_result["position"]
		_face_hit_normal = face_result["normal"]
		_face_is_top     = _face_hit_normal.dot(Vector3.UP) > 0.9

		if _face_is_top:
			# Top face: place on top of the solid that was hit
			var structure := _find_structure_base(face_result["collider"])
			var base_h    : int = structure.height_level if structure != null else 0
			var span      : int = HexGrid.HEIGHT_SPANS.get(
				structure.structure_type if structure != null else &"", 1)
			_face_target_hex = HexGrid.world_to_hex(_face_hit_pos)
			_face_target_h   = base_h + span
		else:
			# Lateral face: step 0.1 m along the normal into the adjacent hex cell
			var adjacent_point := _face_hit_pos + _face_hit_normal * 0.1
			_face_target_hex = HexGrid.world_to_hex(adjacent_point)
			# Snap to the nearest valid height level (floor, not round)
			_face_target_h   = max(0, HexGrid.world_to_height_level(_face_hit_pos.y))
			# Record the source hex (the hit solid) for the debug rectangle
			var hit_struct := _find_structure_base(face_result["collider"])
			_face_source_hex = hit_struct.hex_position if hit_struct != null \
				else HexGrid.world_to_hex(_face_hit_pos)

		_face_active = true
		_renderer.set_hover(_face_target_hex)
		_move_ghost_at(_face_target_hex, _face_target_h)
		_push_debug_state()
		return

	# ── Fall back: ground-plane raycast ───────────────────────────────────────
	var hit = _plane.intersects_ray(ray_origin, cam.project_ray_normal(screen_pos))
	if hit != null:
		var hex := HexGrid.world_to_hex(hit)
		_renderer.set_hover(hex)
		var top_h  : int = HexGrid.get_top_height(hex)
		var height : int = max(0, top_h + 1)
		_move_ghost_at(hex, height)

	_push_debug_state()

# ── Ghost positioning + snap ───────────────────────────────────────────────────

## Position the ghost at (hex, height), then run snap logic for rails.
func _move_ghost_at(hex: Vector2i, height: int) -> void:
	if not is_instance_valid(_ghost):
		return

	_ghost_hex = hex
	_ghost.global_position = HexGrid.hex_to_world_at_height(hex, height)
	_ghost.rotation.y      = _hex_rotation(PlacementController.placement_rotation)
	_ghost.visible         = true

	# ── Part 2: TubeJoint snap ────────────────────────────────────────────────
	_is_snapping          = false
	_snap_target_pos      = Vector3.INF
	_snapping_joint_world = Vector3.INF

	var active_type : StringName = PlacementController.active_structure
	var is_rail : bool = false
	# Check whether the ghost root carries is_rail (StructureBase property)
	if "is_rail" in _ghost:
		is_rail = _ghost.is_rail

	if is_rail:
		var joints := _ghost.find_children("TubeJoint", "Marker3D", true, false)
		for joint: Node in joints:
			var marker        := joint as Marker3D
			var joint_world   : Vector3 = _ghost.global_transform * marker.position
			var snap_target   : Vector3 = TubeJointRegistry.find_snap(
				joint_world, SNAP_DISTANCE)
			if snap_target != Vector3.INF:
				var offset := snap_target - joint_world
				_ghost.global_position += offset
				_is_snapping          = true
				_snap_target_pos      = snap_target
				_snapping_joint_world = joint_world + offset   # final world pos of the snapping joint
				break

	# Validity tint
	var occupied: Array[Vector2i] = [hex]
	if _ghost.has_method(&"get_occupied_hexes"):
		occupied = _ghost.get_occupied_hexes(hex, PlacementController.placement_rotation)
	var can_place := HexGrid.can_place_multi(occupied, height)
	_ghost_set_color(can_place)

## Kept for callers that only know the hex (ground-plane fallback path).
func _move_ghost(hex: Vector2i) -> void:
	var top_h  : int = HexGrid.get_top_height(hex)
	var height : int = max(0, top_h + 1)
	_move_ghost_at(hex, height)

# ── Debug state push ───────────────────────────────────────────────────────────
func _push_debug_state() -> void:
	if _debug_node == null:
		return

	# Collect ghost TubeJoint world positions
	var ghost_joints: Array[Vector3] = []
	if is_instance_valid(_ghost):
		for j: Node in _ghost.find_children("TubeJoint", "Marker3D", true, false):
			ghost_joints.append(_ghost.global_transform * (j as Marker3D).position)

	# Placement validity (green vs red face outline)
	var can_place := false
	if _face_active:
		var occ: Array[Vector2i] = [_face_target_hex]
		if is_instance_valid(_ghost) and _ghost.has_method(&"get_occupied_hexes"):
			occ = _ghost.get_occupied_hexes(_face_target_hex, PlacementController.placement_rotation)
		can_place = HexGrid.can_place_multi(occ, _face_target_h)

	_debug_node.set_face_state(
		_face_active, _face_is_top,
		_face_hit_pos, _face_hit_normal,
		_face_target_hex, _face_source_hex, _face_target_h,
		can_place)

	var snap_delta : float = 0.0
	if _is_snapping and _snap_target_pos != Vector3.INF:
		snap_delta = _snapping_joint_world.distance_to(_snap_target_pos)

	_debug_node.set_snap_state(
		_is_snapping, snap_delta, ghost_joints,
		_snapping_joint_world, _snap_target_pos)

# ── Click dispatch ─────────────────────────────────────────────────────────────
func _on_left_click(screen_pos: Vector2) -> void:
	var cam : Camera3D = _cam_ctrl.get_camera()
	var hit            = _plane.intersects_ray(
		cam.project_ray_origin(screen_pos),
		cam.project_ray_normal(screen_pos))

	# For delete / eyedropper we still need a ground-plane hex
	var hex : Vector2i = Vector2i.ZERO
	if hit != null:
		hex = HexGrid.world_to_hex(hit)

	match PlacementController.active_tool:
		&"build":
			_do_build_smart()
		&"delete":
			if _hovered_structure != null:
				_do_delete_by_structure(_hovered_structure)
		&"eyedropper":
			if hit != null:
				_do_eyedrop(hex)
		&"select_area":
			pass

## Smart build: uses face-target or snap-target when available,
## otherwise falls back to the normal hex-grid build.
func _do_build_smart() -> void:
	if _is_snapping and is_instance_valid(_ghost):
		# Rail placed at snapped world position; derive hex + height from ghost.
		var snapped_hex : Vector2i = HexGrid.world_to_hex(_ghost.global_position)
		var snapped_h   : int      = HexGrid.world_to_height_level(_ghost.global_position.y)
		snapped_h = max(0, snapped_h)
		_do_build_at(snapped_hex, snapped_h, true)
		return

	if _face_active:
		_do_build_at(_face_target_hex, _face_target_h, false)
		return

	# Ground-plane fallback
	var cam : Camera3D = _cam_ctrl.get_camera()
	var hit = _plane.intersects_ray(
		cam.project_ray_origin(get_viewport().get_mouse_position()),
		cam.project_ray_normal(get_viewport().get_mouse_position()))
	if hit != null:
		var hex : Vector2i = HexGrid.world_to_hex(hit)
		_do_build(hex)

## Original hex-based build (ground height, full validation).
func _do_build(hex: Vector2i) -> void:
	var type   : StringName = PlacementController.active_structure
	var top_h  : int        = HexGrid.get_top_height(hex)
	var height : int        = max(0, top_h + 1)
	_do_build_at(hex, height, false)

## Place `active_structure` at (hex, height).
## `skip_support` is true when placing a snapped rail (no ground-support check).
func _do_build_at(hex: Vector2i, height: int, skip_support: bool) -> void:
	var type : StringName = PlacementController.active_structure

	# Solid placement support rules (skip when the rail is floating-snapped)
	if not skip_support:
		if type in HexGrid.SOLID_TYPES and not HexGrid.can_place_solid_hex(hex, height):
			print("Cannot place SolidHex at %s height %d — support rules not met" % [hex, height])
			return

	# Occupied hexes from ghost rotation
	var occupied: Array[Vector2i] = [hex]
	if is_instance_valid(_ghost) and _ghost.has_method(&"get_occupied_hexes"):
		occupied = _ghost.get_occupied_hexes(hex, PlacementController.placement_rotation)

	if not HexGrid.can_place_multi(occupied, height):
		print("Cannot place %s: one or more occupied hexes blocked at height %d" % [type, height])
		return

	# Height-span collision check
	var span: int = HexGrid.HEIGHT_SPANS.get(type, 1)
	for i in range(1, span):
		for occ_hex in occupied:
			var cell := HexGrid.get_cell(occ_hex)
			if cell != null and cell.stack.has(height + i):
				print("Cannot place %s: height %d is already occupied" % [type, height + i])
				return

	var s := HexGrid.spawn_structure(hex, height, type, self)
	if s == null:
		return

	s.rotation.y = _hex_rotation(PlacementController.placement_rotation)

	if s is MarbleSpawn:
		_spawn_structure = s

	print("Placed %s at col=%d row=%d height=%d rot=%d°%s" % [
		type, hex.x, hex.y, height,
		PlacementController.placement_rotation * 60,
		" [SNAPPED]" if skip_support else ""])

## Raycast every frame against all collision layers to find the structure
## under the cursor. Applies / removes the red highlight as the hover changes.
func _update_delete_hover(screen_pos: Vector2) -> void:
	var cam         := _cam_ctrl.get_camera()
	var space_state := get_viewport().get_world_3d().direct_space_state
	var ray_origin  := cam.project_ray_origin(screen_pos)
	var ray_end     := ray_origin + cam.project_ray_normal(screen_pos) * 1000.0
	# No mask argument → hits all collision layers
	var result      := space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(ray_origin, ray_end))

	var found : StructureBase = null
	if not result.is_empty():
		found = _find_structure_base(result["collider"])

	if found == _hovered_structure:
		return   # nothing changed

	_restore_delete_mats()
	_hovered_structure = found
	if found != null:
		_apply_delete_highlight(found)

## Tint every MeshInstance3D in `structure` with a red semi-transparent override.
## Saves the previous material_override so it can be restored later.
func _apply_delete_highlight(structure: Node3D) -> void:
	for node in structure.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		_hover_saved_mats[mi] = mi.material_override
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.1, 0.1, 0.55)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat

## Restore all saved material_overrides without touching _hovered_structure.
func _restore_delete_mats() -> void:
	for mi in _hover_saved_mats:          # untyped — cast after validity check
		if is_instance_valid(mi):
			(mi as MeshInstance3D).material_override = _hover_saved_mats[mi]
	_hover_saved_mats.clear()

## Full cleanup: restore materials and clear the hovered reference.
## Call this when leaving delete mode or on tool change.
func _clear_delete_highlight() -> void:
	_restore_delete_mats()
	_hovered_structure = null

## Delete the hovered structure. Clears refs before despawn to avoid
## accessing freed nodes (despawn calls on_removed → queue_free).
func _do_delete_by_structure(structure: StructureBase) -> void:
	_hover_saved_mats.clear()
	_hovered_structure = null
	var hex := structure.hex_position
	var h   := structure.height_level
	print("Deleted %s at col=%d row=%d height=%d" % [structure.structure_type, hex.x, hex.y, h])
	HexGrid.despawn_structure(hex, h)

func _do_delete(hex: Vector2i) -> void:
	var top_h : int = HexGrid.get_top_height(hex)
	if top_h < 0:
		return
	HexGrid.despawn_structure(hex, top_h)
	print("Deleted structure at col=%d row=%d height=%d" % [hex.x, hex.y, top_h])

func _do_eyedrop(hex: Vector2i) -> void:
	var type : StringName = HexGrid.get_top_structure_type(hex)
	if type != &"":
		PlacementController.set_structure(type)
		print("Eyedropper: picked '%s'" % type)
	PlacementController.set_tool(&"build")

# ── Ghost preview ──────────────────────────────────────────────────────────────
func _on_placement_changed() -> void:
	_clear_delete_highlight()
	_rebuild_ghost()

func _rebuild_ghost() -> void:
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null

	if PlacementController.active_tool != &"build":
		return

	var scene: PackedScene = StructureRegistry.get_scene(PlacementController.active_structure)
	if scene == null:
		return

	_ghost = scene.instantiate() as Node3D
	_ghost.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_ghost)
	_ghost.visible = false
	_ghost_apply_visuals(_ghost)

func _ghost_apply_visuals(node: Node) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	if node is CollisionObject3D:
		var co := node as CollisionObject3D
		co.collision_layer = 0
		co.collision_mask  = 0
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.85, 1.0, 0.40)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_ghost_apply_visuals(child)

func _ghost_set_color(can_place: bool) -> void:
	var color := Color(0.35, 1.0, 0.35, 0.40) if can_place else Color(1.0, 0.35, 0.35, 0.40)
	_ghost_apply_color(_ghost, color)

func _ghost_apply_color(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mat = (node as MeshInstance3D).material_override
		if mat is StandardMaterial3D:
			(mat as StandardMaterial3D).albedo_color = color
	for child in node.get_children():
		_ghost_apply_color(child, color)

# ── Utilities ──────────────────────────────────────────────────────────────────

## Walk up the node tree from `node` until a StructureBase ancestor is found.
func _find_structure_base(node: Node) -> StructureBase:
	var current := node
	while current != null:
		if current is StructureBase:
			return current as StructureBase
		current = current.get_parent()
	return null

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

	var to_remove: Array = []
	for hex in HexGrid._cells:
		for h in HexGrid._cells[hex].stack.keys():
			to_remove.append([hex, h])
	for entry in to_remove:
		HexGrid.despawn_structure(entry[0], entry[1])
	_spawn_structure = null

	for s_data in structures:
		var hex    := Vector2i(int(s_data.hex_x), int(s_data.hex_y))
		var height := int(s_data.height)
		var stype  := StringName(str(s_data.type))
		var rot    := float(s_data.rotation_y)
		var rot_steps: int = posmod(roundi(rot / (PI / 3.0)), 6)
		var s := HexGrid.spawn_structure(hex, height, stype, self, rot_steps)
		if s != null:
			s.rotation.y = rot
			if s is MarbleSpawn:
				_spawn_structure = s

	print("Save carregado: " + save_name)
