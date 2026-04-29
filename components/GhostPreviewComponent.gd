extends Node3D
class_name GhostPreviewComponent

@export var valid_color   : Color = Color(0.35, 1.0,  0.35, 0.40)
@export var invalid_color : Color = Color(1.0,  0.35, 0.35, 0.40)

var _ghost       : Node3D            = null
var _saved_mats  : Dictionary        = {}
var _rail_joints : Array[Marker3D]   = []

# ── Public API ────────────────────────────────────────────────────────────────

## Instantiate a new ghost from `scene` (null = clear only).
## Caches TubeJoint Marker3D children so _move_ghost_at avoids per-frame scans.
func rebuild(scene: PackedScene) -> void:
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_rail_joints.clear()

	if scene == null:
		return

	_ghost = scene.instantiate() as Node3D
	_ghost.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_ghost)
	_ghost.visible = false
	_apply_visuals(_ghost)
	_rail_joints.clear()
	for n in _ghost.find_children("TubeJoint*", "Marker3D", true, false):
		_rail_joints.append(n as Marker3D)

## Move the ghost to `global_pos`.
func update_position(global_pos: Vector3) -> void:
	if is_instance_valid(_ghost):
		_ghost.global_position = global_pos

## Tint the ghost green (valid) or red (invalid).
func set_valid(valid: bool) -> void:
	var color := valid_color if valid else invalid_color
	_apply_color(_ghost, color)

## Return the cached rail-joint markers (populated in rebuild).
func get_rail_joints() -> Array[Marker3D]:
	return _rail_joints

## Return the raw ghost node for callers that need direct property access.
func get_ghost() -> Node3D:
	return _ghost

## Free the ghost and reset all state.
func clear() -> void:
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_rail_joints.clear()
	_saved_mats.clear()

# ── Private helpers (verbatim from Main._ghost_apply_visuals / _ghost_apply_color) ──

func _apply_visuals(node: Node) -> void:
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
		_apply_visuals(child)

func _apply_color(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mat = (node as MeshInstance3D).material_override
		if mat is StandardMaterial3D:
			(mat as StandardMaterial3D).albedo_color = color
	for child in node.get_children():
		_apply_color(child, color)
