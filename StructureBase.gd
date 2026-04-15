class_name StructureBase
extends Node3D

@export var hex_position: Vector2i
@export var height_level: int
@export var is_rail: bool = false  # marcar como true no Inspector de cada trilho

## Hex offsets this structure occupies relative to pivot (axial coords).
## Single-hex structures leave this empty (only occupy pivot).
@export var hex_offsets: Array[Vector2i] = []

## Rotation steps (0-5), set by PlacementController at placement time.
var rotation_steps: int = 0

var structure_type: StringName = &""

func _ready() -> void:
	var mat := PhysicsMaterial.new()
	mat.friction  = 0.6
	mat.rough      = false
	mat.bounce     = 0.05
	mat.absorbent  = false
	for body in find_children("*", "StaticBody3D", true, false):
		(body as StaticBody3D).physics_material_override = mat

## Returns all occupied hexes given a placed pivot and rotation.
## hex_offsets are in axial coordinates; arithmetic is done in axial space
## then converted back to offset coords so odd-column pivots work correctly.
func get_occupied_hexes(pivot: Vector2i, rotation_steps: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = [pivot]
	var axial_pivot := HexGrid._offset_to_axial(pivot)
	for offset in hex_offsets:
		var rotated  := HexGrid.rotate_hex_offset(offset, rotation_steps)
		var axial_r  := axial_pivot + rotated
		result.append(HexGrid._axial_to_offset(axial_r.x, axial_r.y))
	return result

func on_placed() -> void:
	if is_rail:
		RailCollisionManager.register_rail(self)

func on_removed() -> void:
	if is_rail:
		RailCollisionManager.unregister_rail(self)
