extends Node

# ── Constants ──────────────────────────────────────────────────────────────────
## Circumradius of each hex (center → tip).
## SQRT3/2 gives tip-to-tip width = 1.732 m and flat-to-flat depth = 1.5 m.
const HEX_SIZE    : float = SQRT3 / 2.0
const UNIT_HEIGHT : float = 0.289   # vertical distance between stack levels (= one piece height)
const HEX_HEIGHT  : float = 0.02    # cosmetic thickness of the floor indicator tile

const SQRT3 : float = 1.7320508075688772

# ── Cell storage ───────────────────────────────────────────────────────────────
var _cells: Dictionary = {}  # Vector2i -> HexCell

# ── Coordinate utilities ───────────────────────────────────────────────────────

## World-space center of hex cell at Y = 0 (flat-top, odd-q offset).
func hex_to_world(hex: Vector2i) -> Vector3:
	var col: int = hex.x
	var row: int = hex.y
	var x: float = HEX_SIZE * 1.5   * col
	var z: float = HEX_SIZE * SQRT3 * (row + 0.5 * (col & 1))
	return Vector3(x, 0.0, z)

func hex_to_world_at_height(hex: Vector2i, height: int) -> Vector3:
	var base: Vector3 = hex_to_world(hex)
	base.y = height * UNIT_HEIGHT
	return base

## Nearest hex cell for a world position (uses Y=0 plane).
func world_to_hex(world_pos: Vector3) -> Vector2i:
	var q_frac: float = world_pos.x * (2.0 / 3.0) / HEX_SIZE
	var r_frac: float = world_pos.z / (HEX_SIZE * SQRT3) - q_frac * 0.5
	var cube := _axial_round(q_frac, r_frac)
	return _axial_to_offset(cube.x, cube.y)

func _axial_round(q: float, r: float) -> Vector2i:
	var s: float = -q - r
	var rq: int  = roundi(q)
	var rr: int  = roundi(r)
	var rs: int  = roundi(s)
	var dq: float = absf(rq - q)
	var dr: float = absf(rr - r)
	var ds: float = absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(rq, rr)

func _axial_to_offset(q: int, r: int) -> Vector2i:
	return Vector2i(q, r + (q - (q & 1)) / 2)

func _offset_to_axial(hex: Vector2i) -> Vector2i:
	return Vector2i(hex.x, hex.y - (hex.x - (hex.x & 1)) / 2)

## Six neighbors of hex in offset coordinates.
func get_neighbors(hex: Vector2i) -> Array[Vector2i]:
	var axial := _offset_to_axial(hex)
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
	]
	var result: Array[Vector2i] = []
	for d in dirs:
		var nb := axial + d
		result.append(_axial_to_offset(nb.x, nb.y))
	return result

## Shortest path distance between two hexes.
func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var ac := _offset_to_axial(a)
	var bc := _offset_to_axial(b)
	var dq: int = ac.x - bc.x
	var dr: int = ac.y - bc.y
	return (absi(dq) + absi(dq + dr) + absi(dr)) / 2

# ── Cell access ────────────────────────────────────────────────────────────────

func get_or_create_cell(hex: Vector2i) -> HexCell:
	if not _cells.has(hex):
		var cell      := HexCell.new()
		cell.terrain   = HexCell.TerrainType.FLOOR
		_cells[hex]    = cell
	return _cells[hex]

func get_cell(hex: Vector2i) -> HexCell:
	return _cells.get(hex, null)

func has_cell(hex: Vector2i) -> bool:
	return _cells.has(hex)

# ── Stack query API ────────────────────────────────────────────────────────────

func get_stack(hex: Vector2i) -> Array:
	var cell: HexCell = get_cell(hex)
	return [] if cell == null else cell.get_stack_ordered()

func get_top_height(hex: Vector2i) -> int:
	var cell: HexCell = get_cell(hex)
	return -1 if cell == null else cell.get_top_height()

# ── Stack mutation API ─────────────────────────────────────────────────────────

## Low-level: registers structure in the cell dictionary and calls on_placed().
## The structure must already be in the scene tree before calling this.
func place_structure(hex: Vector2i, height: int, structure: Node3D) -> void:
	get_or_create_cell(hex).place(height, structure)
	if structure.has_method(&"on_placed"):
		structure.on_placed()

## Low-level: removes structure from the cell dictionary only (no free, no on_removed).
func remove_structure(hex: Vector2i, height: int) -> void:
	var cell: HexCell = get_cell(hex)
	if cell != null:
		cell.remove(height)

# ── High-level spawn / despawn ─────────────────────────────────────────────────

## Instantiate a structure by registry name, add it to `parent`, position it,
## register it in the grid, and call on_placed(). Returns the new Node3D.
func spawn_structure(hex: Vector2i, height: int, type: StringName, parent: Node) -> Node3D:
	var scene: PackedScene = StructureRegistry.get_scene(type)
	if scene == null:
		return null

	var structure: Node3D = scene.instantiate() as Node3D
	# Set StructureBase exports if present (works for both StructureBase and Marble)
	if "hex_position" in structure:
		structure.hex_position = hex
	if "height_level" in structure:
		structure.height_level = height

	parent.add_child(structure)
	structure.global_position = hex_to_world_at_height(hex, height)
	# Tag with type so the eyedropper tool can read it back
	if "structure_type" in structure:
		structure.structure_type = type
	place_structure(hex, height, structure)   # registers base level + calls on_placed()

	# Register every additional level this structure spans
	var span: int = HEIGHT_SPANS.get(type, 1)
	for i in range(1, span):
		get_or_create_cell(hex).place(height + i, structure)

	return structure

## Call on_removed(), unregister all spanned levels, and free the structure node.
func despawn_structure(hex: Vector2i, height: int) -> void:
	var cell: HexCell = get_cell(hex)
	if cell == null:
		return
	var structure: Node3D = cell.stack.get(height, null)
	if structure == null:
		return
	if structure.has_method(&"on_removed"):
		structure.on_removed()

	# Determine base height and span, then remove every registered level
	var base_h : int = structure.get("height_level") if "height_level" in structure else height
	var s_type : StringName = structure.get("structure_type") if "structure_type" in structure else &""
	var span   : int = HEIGHT_SPANS.get(s_type, 1)
	for i in range(span):
		var c: HexCell = get_cell(hex)
		if c != null and c.stack.get(base_h + i, null) == structure:
			c.remove(base_h + i)

	if is_instance_valid(structure):
		structure.queue_free()

# ── SolidHex placement validation ─────────────────────────────────────────────

## Returns the structure_type StringName of the top structure at hex, or &"" if empty.
func get_top_structure_type(hex: Vector2i) -> StringName:
	var cell := get_cell(hex)
	if cell == null:
		return &""
	var top_h := cell.get_top_height()
	if top_h < 0:
		return &""
	var s: Node3D = cell.stack.get(top_h, null)
	if s == null or not ("structure_type" in s):
		return &""
	return s.structure_type as StringName

const SOLID_TYPES: Array = [&"solid1", &"solid2", &"solid4"]

## How many UNIT_HEIGHT levels each multi-height structure occupies.
## Structures not listed here occupy exactly 1 level.
const HEIGHT_SPANS: Dictionary = {
	&"solid2":     2,
	&"solid4":     4,
	&"solid8":     8,
	&"rampa1":     2,
	&"rampa2":     3,
	&"speed_gate": 3,
}

## Returns true if a solid structure may be placed at (hex, height).
## Rules (any one is sufficient):
##   a) height == 0  (ground level, always valid)
##   b) Same hex has a solid structure at height - 1
##   c) At least 2 of the 6 neighbors have any structure at exactly `height`
func can_place_solid_hex(hex: Vector2i, height: int) -> bool:
	# a) Ground level
	if height == 0:
		return true

	# b) Supported directly below by another solid
	var cell: HexCell = get_cell(hex)
	if cell != null and cell.stack.has(height - 1):
		var below: Node3D = cell.stack[height - 1]
		if "structure_type" in below and below.structure_type in SOLID_TYPES:
			return true

	# c) Lateral support from neighbours
	var support: int = 0
	for nb in get_neighbors(hex):
		var ncell: HexCell = get_cell(nb)
		if ncell != null and ncell.stack.has(height):
			support += 1
	return support >= 2
