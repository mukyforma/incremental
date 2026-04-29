extends Node

var definitions: Array[StructureDefinition] = []

func _ready() -> void:
	if not ResourceLoader.exists("res://resources/StructureCatalog.tres"):
		return
	var res = load("res://resources/StructureCatalog.tres")
	if res == null:
		return
	if "definitions" in res:
		var defs = res.get("definitions")
		if defs is Array:
			for d in defs:
				if d is StructureDefinition:
					definitions.append(d)

func get_by_type(type: StringName) -> StructureDefinition:
	for def in definitions:
		if def.type == type:
			return def
	return null

func get_all() -> Array[StructureDefinition]:
	return definitions
