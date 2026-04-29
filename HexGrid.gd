extends Node

## When true, FacePlacementDebug overlays are rendered each frame.
@export var debug_faces: bool = true

# ── Constants ──────────────────────────────────────────────────────────────────
## Circumradius of each hex (center → tip).
## SQRT3/2 gives tip-to-tip width = 1.732 m and flat-to-flat depth = 1.5 m.
const HEX_SIZE    : float = SQRT3 / 2.0
const UNIT_HEIGHT : float = 0.289   # vertical distance between stack levels (= one piece height)
const HEX_HEIGHT  : float = 0.02    # cosmetic thickness of the floor indicator tile

const SQRT3 : float = 1.7320508075688772

# ── Cell storage ───────────────────────────────────────────────────────────────
var _cells: Dictionary = {}                  # Vector2i → HexCell
var _comutador_base_hexes: Dictionary = {}   # Vector2i → true

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

## Rotates an axial hex offset by `steps` × 60° clockwise.
## Formula per step: (q, r) → (−r, q + r).
func rotate_hex_offset(offset: Vector2i, steps: int) -> Vector2i:
	var q: int = offset.x
	var r: int = offset.y
	for _i in range(steps % 6):
		var nq: int = -r
		var nr: int = q + r
		q = nq
		r = nr
	return Vector2i(q, r)

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

# ── Multi-hex placement validation ────────────────────────────────────────────

## Returns true only if ALL hexes in `occupied` are free at `height`,
## and none of them is a Comutador base socket at a height above the socket limit.
func can_place_multi(occupied: Array[Vector2i], height: int) -> bool:
	for hex in occupied:
		var cell := get_cell(hex)
		if cell != null and cell.stack.has(height):
			return false
		# Comutador base socket: only allow stack heights 0 and 1
		if height > 1 and is_comutador_base(hex):
			return false
	return true

## Returns the first StructureBase found at (hex, height) or (hex, height+1).
## Used by Comutador._toggle() to detect a guest on the base socket.
func get_structure(hex: Vector2i, height: int) -> StructureBase:
	var cell := get_cell(hex)
	if cell == null:
		return null
	for h in [height, height + 1]:
		var s = cell.stack.get(h, null)
		if s != null and s is StructureBase:
			return s as StructureBase
	return null

func register_comutador_base(hex: Vector2i) -> void:
	_comutador_base_hexes[hex] = true

func unregister_comutador_base(hex: Vector2i) -> void:
	_comutador_base_hexes.erase(hex)

## Returns true if `hex` is the current base socket of any Comutador.
func is_comutador_base(hex: Vector2i) -> bool:
	return _comutador_base_hexes.has(hex)

# ── Stack mutation API ─────────────────────────────────────────────────────────

## Low-level: registers structure in every hex of `hexes` at `height` and calls on_placed().
## The structure must already be in the scene tree before calling this.
func place_structure(hexes: Array[Vector2i], height: int, structure: Node3D) -> void:
	for hex in hexes:
		get_or_create_cell(hex).place(height, structure)
	if structure.has_method(&"on_placed"):
		structure.on_placed()
	if structure is StructureBase:
		EntryPointRegistry.register_structure(structure as StructureBase)
		var _connections := ConnectionScanner.scan_from(structure as StructureBase)
		ConnectionPreview.show_connections(_connections)

## Low-level: looks up the structure at (hex, height) and unregisters it from
## all hexes it occupies (multi-hex aware). Does not free the node.
func remove_structure(hex: Vector2i, height: int) -> void:
	var cell: HexCell = get_cell(hex)
	if cell == null:
		return
	var structure = cell.stack.get(height, null)
	if structure == null:
		cell.remove(height)
		return
	# Remove from all occupied hexes (supports multi-hex structures)
	var pivot_hex: Vector2i = structure.get("hex_position") if "hex_position" in structure else hex
	var rot_steps: int      = structure.get("rotation_steps") if "rotation_steps" in structure else 0
	if structure.has_method(&"get_occupied_hexes"):
		for occ in structure.get_occupied_hexes(pivot_hex, rot_steps):
			var c := get_cell(occ)
			if c != null:
				c.remove(height)
	else:
		cell.remove(height)

## Moves a structure to a new pivot: identity-guarded unregister across all
## occupied hexes and all spanned height levels, then re-registers at new hexes.
## The identity guard ensures we never accidentally remove a *different* structure
## that has since taken over a slot (important during Comutador's swap dance).
func move_structure(structure: StructureBase, new_pivot: Vector2i) -> void:
	var s_type : StringName = structure.get("structure_type") if "structure_type" in structure else &""
	var _mdef  : StructureDefinition = StructureCatalog.get_by_type(s_type)
	var span   : int = _mdef.height_span if _mdef != null else HEIGHT_SPANS.get(s_type, 1)
	var base_h : int        = structure.height_level

	# Unregister: only remove cells that still point to this exact structure
	for hex in structure.get_occupied_hexes(structure.hex_position, structure.rotation_steps):
		for i in range(span):
			var c := get_cell(hex)
			if c != null and c.stack.get(base_h + i, null) == structure:
				c.remove(base_h + i)

	# Commit new pivot, then re-register across all occupied hexes and span
	structure.hex_position = new_pivot
	for hex in structure.get_occupied_hexes(new_pivot, structure.rotation_steps):
		for i in range(span):
			get_or_create_cell(hex).place(base_h + i, structure)

# ── High-level spawn / despawn ─────────────────────────────────────────────────

## Instantiate a structure by registry name, add it to `parent`, position it,
## register it in the grid, and call on_placed(). Returns the new Node3D.
## `rot_steps` overrides PlacementController.placement_rotation when >= 0
## (used by the load-from-save path to avoid stale controller state).
func spawn_structure(hex: Vector2i, height: int, type: StringName, parent: Node, rot_steps: int = -1) -> Node3D:
	var scene: PackedScene = StructureRegistry.get_scene(type)
	if scene == null:
		return null

	var structure: Node3D = scene.instantiate() as Node3D
	# Set StructureBase exports if present (works for both StructureBase and Marble)
	if "hex_position" in structure:
		structure.hex_position = hex
	if "height_level" in structure:
		structure.height_level = height

	# Resolve rotation_steps: explicit argument wins, then controller default
	var steps: int = rot_steps if rot_steps >= 0 else PlacementController.placement_rotation
	if "rotation_steps" in structure:
		structure.rotation_steps = steps

	parent.add_child(structure)
	structure.global_position = hex_to_world_at_height(hex, height)

	# Assign collision layer 2 ("SolidHexFace") to every StaticBody3D inside
	# solid structures so the face-raycast hits them exclusively.
	var _sfdef  : StructureDefinition = StructureCatalog.get_by_type(type)
	var _is_solid_face: bool = _sfdef.is_solid_face if _sfdef != null else type in SOLID_FACE_TYPES
	if _is_solid_face:
		for body in structure.find_children("*", "StaticBody3D", true, false):
			(body as StaticBody3D).collision_layer |= 2

	# Tag with type so the eyedropper tool can read it back
	if "structure_type" in structure:
		structure.structure_type = type

	# Determine all occupied hexes (multi-hex support)
	var occupied: Array[Vector2i]
	if structure.has_method(&"get_occupied_hexes"):
		occupied = structure.get_occupied_hexes(hex, steps)
	else:
		occupied = [hex]

	place_structure(occupied, height, structure)   # registers all hexes + calls on_placed()

	# Register every additional level this structure spans
	var _spdef: StructureDefinition = StructureCatalog.get_by_type(type)
	var span: int = _spdef.height_span if _spdef != null else HEIGHT_SPANS.get(type, 1)
	for i in range(1, span):
		for occ_hex in occupied:
			get_or_create_cell(occ_hex).place(height + i, structure)

	return structure

func get_all_placed_structures() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hex in _cells:
		var cell: HexCell = _cells[hex]
		for h in cell.stack:
			result.append({ "hex": hex, "height": h, "node": cell.stack[h] })
	return result

func despawn_all() -> void:
	var to_despawn: Array = []
	for hex in _cells.keys():
		for h in _cells[hex].stack.keys():
			to_despawn.append([hex, h])
	for entry in to_despawn:
		despawn_structure(entry[0], entry[1])

## Call on_removed(), unregister all spanned levels across all occupied hexes, and free the node.
func despawn_structure(hex: Vector2i, height: int) -> void:
	var cell: HexCell = get_cell(hex)
	if cell == null:
		return
	var structure: Node3D = cell.stack.get(height, null)
	if structure == null:
		return
	if structure is StructureBase:
		EntryPointRegistry.unregister_structure(structure as StructureBase)
	if structure.has_method(&"on_removed"):
		structure.on_removed()

	# Determine base height, span, and all occupied hexes
	var base_h    : int       = structure.get("height_level")    if "height_level"    in structure else height
	var s_type    : StringName = structure.get("structure_type") if "structure_type"  in structure else &""
	var _ddef     : StructureDefinition = StructureCatalog.get_by_type(s_type)
	var span      : int = _ddef.height_span if _ddef != null else HEIGHT_SPANS.get(s_type, 1)
	var pivot_hex : Vector2i  = structure.get("hex_position")    if "hex_position"    in structure else hex
	var rot_steps : int       = structure.get("rotation_steps")  if "rotation_steps"  in structure else 0

	var occupied: Array[Vector2i]
	if structure.has_method(&"get_occupied_hexes"):
		occupied = structure.get_occupied_hexes(pivot_hex, rot_steps)
	else:
		occupied = [hex]

	for i in range(span):
		for occ_hex in occupied:
			var c: HexCell = get_cell(occ_hex)
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

const SOLID_TYPES: Array = [&"solid1", &"solid2", &"solid4", &"solid8"]

## Structure types that may only be placed at height 0.
const GROUND_ONLY_TYPES: Array = [&"collector"]

## All solid types whose StaticBody3D children receive collision layer 2
## so the face-raycast can hit them exclusively.
const SOLID_FACE_TYPES: Array = [&"solid1", &"solid2", &"solid4", &"solid8"]

## How many UNIT_HEIGHT levels each multi-height structure occupies.
## Structures not listed here occupy exactly 1 level.
const HEIGHT_SPANS: Dictionary = {
	&"solid2":          2,
	&"solid4":          4,
	&"solid8":          8,
	&"rampa1":          2,
	&"rampa2":          3,
	&"speed_gate":      3,
	&"deflector_alto":  4,
	&"deflector_baixo": 4,
}

## Converts a world-space Y coordinate to the nearest stack height level.
## Used by face-based placement when hovering a lateral SolidHex face.
## Returns the height level that fully contains world_y.
## Uses floor so the level only advances when the hit point crosses a level
## boundary (a multiple of UNIT_HEIGHT), not at the halfway point.
func world_to_height_level(world_y: float) -> int:
	return max(0, int(floor(world_y / UNIT_HEIGHT)))

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
		if "structure_type" in below:
			var _sdef: StructureDefinition = StructureCatalog.get_by_type(below.structure_type)
			var _is_solid: bool = _sdef.is_solid if _sdef != null else below.structure_type in SOLID_TYPES
			if _is_solid:
				return true

	# c) Lateral support from neighbours
	var support: int = 0
	for nb in get_neighbors(hex):
		var ncell: HexCell = get_cell(nb)
		if ncell != null and ncell.stack.has(height):
			support += 1
	return support >= 2
