extends Node

## Autoload: maintains the world positions of every TubeJoint Marker3D
## belonging to placed rail structures.
##
## TubeJoint markers are added in the editor to each rail scene.
## This registry is updated by RailCollisionManager on place / remove.

# ── Storage ────────────────────────────────────────────────────────────────────
# Each entry: { "position": Vector3, "structure": StructureBase }
var _joints: Array[Dictionary] = []

# ── Public API ─────────────────────────────────────────────────────────────────

## Register all TubeJoint markers found inside `structure`.
## Called by RailCollisionManager.register_rail().
func register_rail(structure: StructureBase) -> void:
	for marker in structure.find_children("TubeJoint", "Marker3D", true, false):
		_joints.append({
			"position":  (marker as Marker3D).global_position,
			"structure": structure,
		})

## Remove all entries belonging to `structure`.
## Called by RailCollisionManager.unregister_rail().
func unregister_rail(structure: StructureBase) -> void:
	_joints = _joints.filter(func(j: Dictionary) -> bool:
		return j["structure"] != structure)

## Returns the world position of the closest registered joint within
## `snap_distance` of `query_position` (all three axes, Euclidean).
## Returns Vector3.INF when no joint is close enough.
## Pass `exclude_structure` to ignore joints on a specific structure
## (use this when querying against a ghost to avoid self-snap).
func find_snap(
		query_position:    Vector3,
		snap_distance:     float,
		exclude_structure: StructureBase = null) -> Vector3:
	var best_dist := snap_distance
	var best_pos  := Vector3.INF
	for joint: Dictionary in _joints:
		if exclude_structure != null and joint["structure"] == exclude_structure:
			continue
		var dist: float = query_position.distance_to(joint["position"])
		if dist < best_dist:
			best_dist = dist
			best_pos  = joint["position"]
	return best_pos

## Returns a flat copy of all registered joint world positions.
## Used by FacePlacementDebug for the CYAN sphere overlay.
func get_all_joint_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for j: Dictionary in _joints:
		out.append(j["position"])
	return out
