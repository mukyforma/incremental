extends Node

## Autoload: tracks all placed rail structures and coordinates
## TubeJoint registration for snap.
##
## "Merge logic" (future: merging overlapping rail meshes for seamless
## visuals) is reserved here. Do NOT add merge calls without reading
## the design doc first.

# ── Rail registry ──────────────────────────────────────────────────────────────

## Called by StructureBase.on_placed() for every is_rail structure.
func register_rail(structure: StructureBase) -> void:
	TubeJointRegistry.register_rail(structure)

## Called by StructureBase.on_removed() for every is_rail structure.
func unregister_rail(structure: StructureBase) -> void:
	TubeJointRegistry.unregister_rail(structure)
