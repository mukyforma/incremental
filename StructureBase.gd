class_name StructureBase
extends Node3D

@export var hex_position: Vector2i
@export var height_level: int
@export var is_rail: bool = false  # marcar como true no Inspector de cada trilho

var structure_type: StringName = &""

func _ready() -> void:
	var mat := PhysicsMaterial.new()
	mat.friction  = 0.6
	mat.rough      = false
	mat.bounce     = 0.05
	mat.absorbent  = false
	for body in find_children("*", "StaticBody3D", true, false):
		(body as StaticBody3D).physics_material_override = mat

func on_placed() -> void:
	pass

func on_removed() -> void:
	pass
