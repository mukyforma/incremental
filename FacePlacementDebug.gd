class_name FacePlacementDebug
extends Node3D

## Debug overlay for face-based placement (Part 1) and TubeJoint snap (Part 2).
## Instantiated at runtime by Main._ready() when HexGrid.debug_faces is true.
## All drawing is done via ImmediateMesh so no scene modifications are needed.

# ── Child nodes created in _ready() ───────────────────────────────────────────
var _mesh_inst : MeshInstance3D   # lines: face outline, arrow, snap line
var _imesh     : ImmediateMesh
var _label     : Label            # corner HUD text (inside a CanvasLayer)

# ── Materials (created once) ──────────────────────────────────────────────────
var _mat_green   : StandardMaterial3D
var _mat_red     : StandardMaterial3D
var _mat_yellow  : StandardMaterial3D
var _mat_cyan    : StandardMaterial3D
var _mat_magenta : StandardMaterial3D
var _mat_white   : StandardMaterial3D

# ── Face state (written each frame by Main.set_face_state) ────────────────────
var _active        : bool      = false
var _is_top        : bool      = false
var _hit_pos       : Vector3   = Vector3.ZERO
var _hit_normal    : Vector3   = Vector3.UP
var _target_hex    : Vector2i  = Vector2i.ZERO
var _target_height : int       = 0
var _can_place     : bool      = false

# ── Snap state (written each frame by Main.set_snap_state) ────────────────────
var _is_snapping       : bool            = false
var _snap_delta        : float           = 0.0
var _ghost_joints      : Array[Vector3]  = []
var _snap_joint_ghost  : Vector3         = Vector3.INF
var _snap_joint_target : Vector3         = Vector3.INF

# ── Delete state (written each frame by Main.set_delete_state) ────────────────
var _active_tool        : StringName = &"build"
var _delete_target_hex  : Vector2i   = Vector2i.ZERO
var _delete_target_h    : int        = 0
var _delete_struct_type : StringName = &""

# ── Reusable sphere mesh (radius 0.04) ────────────────────────────────────────
var _sphere_mesh : SphereMesh

# ──────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_imesh     = ImmediateMesh.new()
	_mesh_inst = MeshInstance3D.new()
	_mesh_inst.mesh        = _imesh
	_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_inst)

	_mat_green   = _make_mat(Color.GREEN)
	_mat_red     = _make_mat(Color.RED)
	_mat_yellow  = _make_mat(Color.YELLOW)
	_mat_cyan    = _make_mat(Color.CYAN)
	_mat_magenta = _make_mat(Color.MAGENTA)
	_mat_white   = _make_mat(Color.WHITE)

	_sphere_mesh        = SphereMesh.new()
	_sphere_mesh.radius = 0.04
	_sphere_mesh.height = 0.08

	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	_label = Label.new()
	_label.anchors_preset = Control.PRESET_BOTTOM_LEFT
	_label.offset_left   = 8.0
	_label.offset_bottom = -8.0
	_label.add_theme_color_override(&"font_color",        Color.WHITE)
	_label.add_theme_color_override(&"font_shadow_color", Color.BLACK)
	_label.add_theme_constant_override(&"shadow_offset_x", 1)
	_label.add_theme_constant_override(&"shadow_offset_y", 1)
	canvas.add_child(_label)

func _make_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode              = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color              = color
	m.transparency              = BaseMaterial3D.TRANSPARENCY_DISABLED
	m.vertex_color_use_as_albedo = true
	return m

# ── API called by Main every _process() frame ──────────────────────────────────

func set_face_state(
		active:        bool,
		is_top:        bool,
		hit_pos:       Vector3,
		hit_normal:    Vector3,
		target_hex:    Vector2i,
		target_height: int,
		can_place:     bool) -> void:
	_active        = active
	_is_top        = is_top
	_hit_pos       = hit_pos
	_hit_normal    = hit_normal
	_target_hex    = target_hex
	_target_height = target_height
	_can_place     = can_place

func set_snap_state(
		is_snapping:    bool,
		snap_delta:     float,
		ghost_joints:   Array[Vector3],
		ghost_snapping: Vector3,
		target_joint:   Vector3) -> void:
	_is_snapping       = is_snapping
	_snap_delta        = snap_delta
	_ghost_joints      = ghost_joints
	_snap_joint_ghost  = ghost_snapping
	_snap_joint_target = target_joint

func set_delete_state(
		active_tool:   StringName,
		delete_hex:    Vector2i,
		delete_height: int,
		struct_type:   StringName) -> void:
	_active_tool        = active_tool
	_delete_target_hex  = delete_hex
	_delete_target_h    = delete_height
	_delete_struct_type = struct_type

# ── Main draw loop ─────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	_imesh.clear_surfaces()
	# Free sphere MeshInstance3D markers spawned last frame
	for i: int in range(get_child_count() - 1, 0, -1):
		var ch := get_child(i)
		if ch is MeshInstance3D and ch != _mesh_inst:
			ch.queue_free()

	if not _active:
		_label.text = ""
		return

	# Hit-point sphere (WHITE) and normal arrow (YELLOW) are always shown
	_add_sphere(_hit_pos, 0.04, _mat_white)
	_draw_arrow(_hit_pos, _hit_pos + _hit_normal * 0.3, _mat_yellow)

	# Registered TubeJoint world positions (CYAN) — always useful context
	for jp: Vector3 in TubeJointRegistry.get_all_joint_positions():
		_add_sphere(jp, 0.06, _mat_cyan)

	if _active_tool == &"delete":
		_draw_delete_frame()
	else:
		_draw_build_frame()

# ── Delete-mode overlay ────────────────────────────────────────────────────────
func _draw_delete_frame() -> void:
	# Face highlight in red at the hovered face
	if _is_top:
		_draw_hex_outline(_hit_pos + Vector3.UP * 0.01, _target_height, _mat_red)
	else:
		_draw_lateral_outline(_hit_pos, _hit_normal, _target_height, _mat_red)

	# Second hex outline at the structure-to-be-deleted (may differ on lateral)
	var del_world := HexGrid.hex_to_world_at_height(_delete_target_hex, _delete_target_h)
	_draw_hex_outline(del_world + Vector3.UP * 0.02, _delete_target_h, _mat_red)

	var struct_str := str(_delete_struct_type) if _delete_struct_type != &"" else "EMPTY"
	_label.text = "Tool: DELETE | Target: (%d, %d) height %d | Structure: %s" % [
		_delete_target_hex.x, _delete_target_hex.y, _delete_target_h, struct_str]

# ── Build-mode overlay ─────────────────────────────────────────────────────────
func _draw_build_frame() -> void:
	var face_color := _mat_green if _can_place else _mat_red

	if _is_top:
		_draw_hex_outline(_hit_pos + Vector3.UP * 0.01, _target_height, face_color)
	else:
		_draw_lateral_outline(_hit_pos, _hit_normal, _target_height, face_color)

	# Ghost TubeJoint world positions (YELLOW)
	for gj: Vector3 in _ghost_joints:
		_add_sphere(gj, 0.06, _mat_yellow)

	# Snap line between snapping ghost joint → registered target joint (MAGENTA)
	if _is_snapping and _snap_joint_ghost != Vector3.INF and _snap_joint_target != Vector3.INF:
		_draw_line(_snap_joint_ghost, _snap_joint_target, _mat_magenta)

	var face_str := "TOP" if _is_top else "LATERAL"
	var line1    := ""
	if _is_top:
		line1 = "Face: %s | Hex: (%d, %d) | Height: %d" % [
			face_str, _target_hex.x, _target_hex.y, _target_height]
	else:
		line1 = "Face: %s | Hex: (%d, %d) | Height: %d (snapped) | Normal: (%.2f, %.2f, %.2f)" % [
			face_str, _target_hex.x, _target_hex.y, _target_height,
			_hit_normal.x, _hit_normal.y, _hit_normal.z]

	var line2 := "Snap: ACTIVE | Joint delta: %.2fu" % _snap_delta \
		if _is_snapping else "Snap: NONE"
	_label.text = line1 + "\n" + line2

# ── Drawing helpers ────────────────────────────────────────────────────────────

## Flat hexagon outline at the world-space center of `hex` at `world_pos.y`.
## world_pos is used only for Y; the hex center X/Z are derived from world_to_hex.
func _draw_hex_outline(world_pos: Vector3, _height_unused: int, mat: StandardMaterial3D) -> void:
	var hex := HexGrid.world_to_hex(world_pos)
	var ctr := HexGrid.hex_to_world(hex)
	ctr.y   = world_pos.y
	var s   := HexGrid.HEX_SIZE
	_imesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for i: int in 6:
		var a0 := deg_to_rad(i * 60.0)
		var a1 := deg_to_rad((i + 1) * 60.0)
		_imesh.surface_set_color(mat.albedo_color)
		_imesh.surface_add_vertex(ctr + Vector3(cos(a0) * s, 0.0, sin(a0) * s))
		_imesh.surface_set_color(mat.albedo_color)
		_imesh.surface_add_vertex(ctr + Vector3(cos(a1) * s, 0.0, sin(a1) * s))
	_imesh.surface_end()

## Rectangle outline for a lateral face.
## The vertical center is snapped to the middle of `snapped_height`'s level
## (i.e. snapped_height * UNIT_HEIGHT + UNIT_HEIGHT * 0.5) so the rect aligns
## with a single height band regardless of where the ray hit on the face.
func _draw_lateral_outline(
		hit_pos:        Vector3,
		normal:         Vector3,
		snapped_height: int,
		mat:            StandardMaterial3D) -> void:
	# Tangent frame on the face
	var up_ref  := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	var right   := normal.cross(up_ref).normalized()
	var up_dir  := normal.cross(right).normalized()   # "up" in the plane of the face

	# Snap rect center Y to the middle of the height band
	var center_y := snapped_height * HexGrid.UNIT_HEIGHT + HexGrid.UNIT_HEIGHT * 0.5
	var center   := Vector3(hit_pos.x, center_y, hit_pos.z)

	var hw := HexGrid.HEX_SIZE * 0.5    # half-width  ≈ hex edge-length / 2
	var hh := HexGrid.UNIT_HEIGHT * 0.5 # half-height = half of one level

	var tl := center + up_dir *  hh - right * hw
	var tr := center + up_dir *  hh + right * hw
	var br := center + up_dir * -hh + right * hw
	var bl := center + up_dir * -hh - right * hw

	_imesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	var c := mat.albedo_color
	for pair in [[tl, tr], [tr, br], [br, bl], [bl, tl]]:
		_imesh.surface_set_color(c); _imesh.surface_add_vertex(pair[0])
		_imesh.surface_set_color(c); _imesh.surface_add_vertex(pair[1])
	_imesh.surface_end()

func _draw_line(a: Vector3, b: Vector3, mat: StandardMaterial3D) -> void:
	_imesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	_imesh.surface_set_color(mat.albedo_color); _imesh.surface_add_vertex(a)
	_imesh.surface_set_color(mat.albedo_color); _imesh.surface_add_vertex(b)
	_imesh.surface_end()

func _draw_arrow(start: Vector3, end: Vector3, mat: StandardMaterial3D) -> void:
	_draw_line(start, end, mat)
	var dir  := (end - start).normalized()
	var perp := dir.cross(Vector3.UP)
	if perp.length_squared() < 0.01:
		perp = dir.cross(Vector3.RIGHT)
	perp = perp.normalized() * 0.05
	_draw_line(end, end - dir * 0.08 + perp, mat)
	_draw_line(end, end - dir * 0.08 - perp, mat)

func _add_sphere(world_pos: Vector3, radius: float, mat: StandardMaterial3D) -> void:
	var sm : SphereMesh
	if radius == 0.04:
		sm = _sphere_mesh   # reuse default to avoid allocations
	else:
		sm = SphereMesh.new()
		sm.radius = radius
		sm.height = radius * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh             = sm
	mi.material_override = mat
	mi.cast_shadow      = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)                  # must be in tree before setting global_position
	mi.global_position  = world_pos
