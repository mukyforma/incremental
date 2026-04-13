class_name HexRenderer
extends Node3D

# ── Config ─────────────────────────────────────────────────────────────────────
const CULL_BUFFER        : int   = 2      # extra cells beyond viewport edge

# Copper palette
const COPPER_H_BASE  : float = 0.075   # hue   (~27° orange-copper)
const COPPER_H_RANGE : float = 0.018   # ± hue variation
const COPPER_S_BASE  : float = 0.68    # saturation
const COPPER_S_RANGE : float = 0.08
const COPPER_V_BASE  : float = 0.52    # value (brightness)
const COPPER_V_RANGE : float = 0.10

const BORDER_COLOR        : Color = Color(0.12, 0.07, 0.04)   # dark burnt copper
const HOVER_COLOR         : Color = Color(0.85, 0.95, 1.00)
const HOVER_BORDER_COLOR  : Color = Color(0.50, 0.75, 1.00)
const DELETE_COLOR        : Color = Color(1.00, 0.22, 0.22)
const DELETE_BORDER_COLOR : Color = Color(0.80, 0.10, 0.10)

# ── State ──────────────────────────────────────────────────────────────────────
var _camera       : Camera3D
var _visible_cells: Dictionary = {}   # Vector2i -> MeshInstance3D
const _NO_HEX     : Vector2i = Vector2i(2147483647, 2147483647)
var _hover_hex    : Vector2i = _NO_HEX

# Shared materials (border + hover are uniform across all tiles)
var _mat_border              : StandardMaterial3D
var _mat_hover               : StandardMaterial3D
var _mat_hover_border        : StandardMaterial3D
var _mat_hover_delete        : StandardMaterial3D
var _mat_hover_delete_border : StandardMaterial3D

# Per-tile top materials, keyed by Vector2i — restored when hover leaves
var _tile_mats : Dictionary = {}   # Vector2i -> StandardMaterial3D

# Reusable mesh shapes
var _hex_top_mesh   : ArrayMesh  # top face (flat hexagon)
var _hex_side_mesh  : ArrayMesh  # 6 side quads

# ── Init ───────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_shared_materials()
	_build_hex_meshes()
	PlacementController.selection_changed.connect(_on_placement_changed)

func set_camera(cam: Camera3D) -> void:
	_camera = cam

# ── Per-frame culling update ───────────────────────────────────────────────────
func update_visible_region() -> void:
	if _camera == null:
		return

	var needed: Dictionary = _compute_needed_hexes()

	# Remove cells that left the visible region
	var to_remove: Array = []
	for hex in _visible_cells:
		if not needed.has(hex):
			to_remove.append(hex)
	for hex in to_remove:
		_visible_cells[hex].queue_free()
		_visible_cells.erase(hex)

	# Add newly visible cells
	for hex in needed:
		if not _visible_cells.has(hex):
			_spawn_cell_mesh(hex)

func _compute_needed_hexes() -> Dictionary:
	var result: Dictionary = {}
	var viewport: Viewport = get_viewport()
	var vp_size: Vector2 = viewport.get_visible_rect().size

	# Project four screen corners onto Y=0 plane to find world bounds
	var corners: Array[Vector2] = [
		Vector2(0, 0),
		Vector2(vp_size.x, 0),
		Vector2(vp_size.x, vp_size.y),
		Vector2(0, vp_size.y),
	]

	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF

	for corner in corners:
		var ray_origin   : Vector3 = _camera.project_ray_origin(corner)
		var ray_dir      : Vector3 = _camera.project_ray_normal(corner)
		if absf(ray_dir.y) < 0.001:
			continue
		var t: float = -ray_origin.y / ray_dir.y
		if t < 0.0:
			continue
		var world_pt: Vector3 = ray_origin + ray_dir * t
		min_x = minf(min_x, world_pt.x)
		max_x = maxf(max_x, world_pt.x)
		min_z = minf(min_z, world_pt.z)
		max_z = maxf(max_z, world_pt.z)

	if min_x == INF:
		return result

	# Convert world bounds to hex bounds, add buffer
	var buf_world: float = (CULL_BUFFER + 1) * HexGrid.HEX_SIZE * HexGrid.SQRT3

	var hex_min: Vector2i = HexGrid.world_to_hex(Vector3(min_x - buf_world, 0, min_z - buf_world))
	var hex_max: Vector2i = HexGrid.world_to_hex(Vector3(max_x + buf_world, 0, max_z + buf_world))

	# Iterate the bounding rectangle in offset coords
	var r0: int = mini(hex_min.y, hex_max.y) - CULL_BUFFER
	var r1: int = maxi(hex_min.y, hex_max.y) + CULL_BUFFER
	var c0: int = mini(hex_min.x, hex_max.x) - CULL_BUFFER
	var c1: int = maxi(hex_min.x, hex_max.x) + CULL_BUFFER

	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			result[Vector2i(c, r)] = true

	return result

# ── Cell mesh spawning ─────────────────────────────────────────────────────────
func _spawn_cell_mesh(hex: Vector2i) -> void:
	var center: Vector3 = HexGrid.hex_to_world(hex)

	var root := Node3D.new()
	root.position = center
	root.set_meta("hex", hex)    # used by _set_cell_highlight to restore material
	add_child(root)

	# Per-tile copper material (create once, cache for hover restore)
	if not _tile_mats.has(hex):
		_tile_mats[hex] = _make_copper_mat(hex)

	# Top face — unique copper material
	var top := MeshInstance3D.new()
	top.mesh = _hex_top_mesh
	top.material_override = _tile_mats[hex]
	root.add_child(top)

	# Border sides — shared dark material
	var side := MeshInstance3D.new()
	side.mesh = _hex_side_mesh
	side.material_override = _mat_border
	root.add_child(side)

	_visible_cells[hex] = root

func set_hover(hex: Vector2i) -> void:
	if hex == _hover_hex:
		return

	# Restore previous cell
	if _visible_cells.has(_hover_hex):
		_set_cell_highlight(_visible_cells[_hover_hex], false)

	_hover_hex = hex

	if _visible_cells.has(hex):
		_set_cell_highlight(_visible_cells[hex], true)

func _set_cell_highlight(cell_root: Node3D, hover: bool) -> void:
	var children: Array = cell_root.get_children()
	if children.size() < 2:
		return
	var top  : MeshInstance3D = children[0]
	var side : MeshInstance3D = children[1]

	if hover:
		var is_delete := PlacementController.active_tool == &"delete"
		top.material_override  = _mat_hover_delete        if is_delete else _mat_hover
		side.material_override = _mat_hover_delete_border if is_delete else _mat_hover_border
	else:
		var hex: Vector2i = cell_root.get_meta("hex", _NO_HEX)
		top.material_override  = _tile_mats.get(hex, _mat_border)
		side.material_override = _mat_border

## Refreshes the current hover cell when the active tool changes (e.g. delete mode).
func _on_placement_changed() -> void:
	if _hover_hex == _NO_HEX:
		return
	var h := _hover_hex
	_hover_hex = _NO_HEX   # force set_hover to not early-return
	set_hover(h)

# ── Material builders ──────────────────────────────────────────────────────────
func _build_shared_materials() -> void:
	_mat_border              = _make_mat(BORDER_COLOR,        0.9, 0.05)
	_mat_hover               = _make_mat(HOVER_COLOR,         0.5, 0.0)
	_mat_hover_border        = _make_mat(HOVER_BORDER_COLOR,  0.4, 0.2)
	_mat_hover_delete        = _make_mat(DELETE_COLOR,        0.5, 0.0)
	_mat_hover_delete_border = _make_mat(DELETE_BORDER_COLOR, 0.4, 0.1)

func _make_mat(color: Color, roughness: float = 0.7, metallic: float = 0.3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness    = roughness
	m.metallic     = metallic
	return m

## Deterministic copper material varied by hex coordinate hash.
func _make_copper_mat(hex: Vector2i) -> StandardMaterial3D:
	var t: float = _hex_noise(hex)         # 0.0 – 1.0, unique per tile
	var h: float = COPPER_H_BASE + (t * 2.0 - 1.0) * COPPER_H_RANGE
	var s: float = COPPER_S_BASE + (fmod(t * 7.3 + 0.3, 1.0) * 2.0 - 1.0) * COPPER_S_RANGE
	var v: float = COPPER_V_BASE + (fmod(t * 3.7 + 0.6, 1.0) * 2.0 - 1.0) * COPPER_V_RANGE
	h = clampf(h, 0.0, 1.0)
	s = clampf(s, 0.0, 1.0)
	v = clampf(v, 0.0, 1.0)
	var color: Color = Color.from_hsv(h, s, v)
	# Metallic copper feel: low roughness, medium metallic
	return _make_mat(color, 0.45, 0.55)

## Low-quality but fast integer hash → [0, 1) float, deterministic per hex.
func _hex_noise(hex: Vector2i) -> float:
	var n: int = hex.x * 1619 + hex.y * 31337
	n = n ^ (n << 13)
	n = (n * (n * n * 15731 + 789221) + 1376312589) & 0x7fffffff
	return float(n) / float(0x7fffffff)

func _build_hex_meshes() -> void:
	var s: float = HexGrid.HEX_SIZE
	var h: float = HexGrid.HEX_HEIGHT
	# Top face at y=0 (flush with ground); tile sinks downward by HEX_HEIGHT.

	# 6 vertices around the top hexagon (flat-top: first vertex at 0° = +X)
	var verts: Array[Vector3] = []
	for i in range(6):
		var angle: float = deg_to_rad(60.0 * i)
		verts.append(Vector3(s * cos(angle), 0.0, s * sin(angle)))

	# ── Top face (triangle fan) ────────────────────────────────────────────────
	var top_verts   : PackedVector3Array = PackedVector3Array()
	var top_normals : PackedVector3Array = PackedVector3Array()
	var top_uvs     : PackedVector2Array = PackedVector2Array()
	var top_indices : PackedInt32Array   = PackedInt32Array()

	# Center
	top_verts.append(Vector3(0, 0.0, 0))
	top_normals.append(Vector3.UP)
	top_uvs.append(Vector2(0.5, 0.5))

	for i in range(6):
		top_verts.append(verts[i])
		top_normals.append(Vector3.UP)
		top_uvs.append(Vector2(0.5 + 0.5 * cos(deg_to_rad(60.0 * i)),
							   0.5 + 0.5 * sin(deg_to_rad(60.0 * i))))

	for i in range(6):
		top_indices.append(0)
		top_indices.append(i + 1)
		top_indices.append((i + 1) % 6 + 1)

	var top_arrays := []
	top_arrays.resize(Mesh.ARRAY_MAX)
	top_arrays[Mesh.ARRAY_VERTEX] = top_verts
	top_arrays[Mesh.ARRAY_NORMAL] = top_normals
	top_arrays[Mesh.ARRAY_TEX_UV] = top_uvs
	top_arrays[Mesh.ARRAY_INDEX]  = top_indices

	_hex_top_mesh = ArrayMesh.new()
	_hex_top_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, top_arrays)

	# ── Side faces ────────────────────────────────────────────────────────────
	var side_verts   : PackedVector3Array = PackedVector3Array()
	var side_normals : PackedVector3Array = PackedVector3Array()
	var side_uvs     : PackedVector2Array = PackedVector2Array()
	var side_indices : PackedInt32Array   = PackedInt32Array()

	for i in range(6):
		var a: Vector3 = verts[i]
		var b: Vector3 = verts[(i + 1) % 6]
		var bot_a := Vector3(a.x, -h, a.z)
		var bot_b := Vector3(b.x, -h, b.z)

		var base_idx: int = side_verts.size()
		var face_normal: Vector3 = (a + b).normalized()
		face_normal.y = 0.0
		face_normal = face_normal.normalized()

		side_verts.append(a)
		side_verts.append(b)
		side_verts.append(bot_b)
		side_verts.append(bot_a)

		for _j in range(4):
			side_normals.append(face_normal)

		side_uvs.append(Vector2(0, 1))
		side_uvs.append(Vector2(1, 1))
		side_uvs.append(Vector2(1, 0))
		side_uvs.append(Vector2(0, 0))

		side_indices.append(base_idx)
		side_indices.append(base_idx + 2)
		side_indices.append(base_idx + 1)
		side_indices.append(base_idx)
		side_indices.append(base_idx + 3)
		side_indices.append(base_idx + 2)

	var side_arrays := []
	side_arrays.resize(Mesh.ARRAY_MAX)
	side_arrays[Mesh.ARRAY_VERTEX] = side_verts
	side_arrays[Mesh.ARRAY_NORMAL] = side_normals
	side_arrays[Mesh.ARRAY_TEX_UV] = side_uvs
	side_arrays[Mesh.ARRAY_INDEX]  = side_indices

	_hex_side_mesh = ArrayMesh.new()
	_hex_side_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, side_arrays)
