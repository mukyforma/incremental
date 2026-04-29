class_name StructureBase
extends GridObject

signal activated

@export var is_rail: bool = false  # marcar como true no Inspector de cada trilho
@export var activatable: bool = false

## Hex offsets this structure occupies relative to pivot (axial coords).
## Single-hex structures leave this empty (only occupy pivot).
@export var hex_offsets: Array[Vector2i] = []

@export var default_physics_material: PhysicsMaterial

## Rotation steps (0-5), set by PlacementController at placement time.
var rotation_steps: int = 0

func _ready() -> void:
	if default_physics_material != null:
		for body in find_children("*", "StaticBody3D", true, false):
			(body as StaticBody3D).physics_material_override = default_physics_material
	else:
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

func is_base_socket(_hex: Vector2i) -> bool:
	return false

func on_placed() -> void:
	pass

func on_removed() -> void:
	pass
