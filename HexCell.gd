class_name HexCell
extends RefCounted

enum TerrainType { EMPTY, FLOOR, WALL }

enum SurfaceMaterial { DEFAULT, METAL, WOOD, GLASS }

var terrain: TerrainType = TerrainType.EMPTY
var surface_material: SurfaceMaterial = SurfaceMaterial.DEFAULT
var slope_direction: int = -1  # -1 = no slope, 0-5 = hex face index
var stack: Dictionary = {}     # height_level (int) -> Node3D

func get_stack_ordered() -> Array:
	var keys: Array = stack.keys()
	keys.sort()
	var result: Array = []
	for k in keys:
		result.append(stack[k])
	return result

func get_top_height() -> int:
	if stack.is_empty():
		return -1
	var keys: Array = stack.keys()
	keys.sort()
	return keys[-1]

func place(height: int, structure: Node3D) -> void:
	stack[height] = structure

func remove(height: int) -> void:
	stack.erase(height)
