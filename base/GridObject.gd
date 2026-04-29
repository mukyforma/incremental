class_name GridObject
extends Node3D

@export var hex_position: Vector2i
@export var height_level: int
var structure_type: StringName = &""

func on_placed() -> void:
	pass

func on_removed() -> void:
	pass
