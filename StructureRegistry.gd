extends Node

## Central registry mapping StringName → PackedScene.
## HexGrid uses this to instantiate structures by name.

var _registry: Dictionary = {
	&"marble":           preload("res://structures/marble.tscn"),
	&"marble_spawn":     preload("res://structures/marble_spawn.tscn"),
	&"collector":        preload("res://structures/collector.tscn"),
	&"speed_gate":       preload("res://structures/speed_gate.tscn"),
	&"solid1":           preload("res://structures/solid1.tscn"),
	&"solid2":           preload("res://structures/solid2.tscn"),
	&"solid4":           preload("res://structures/solid4.tscn"),
	&"solid8":           preload("res://structures/solid8.tscn"),
	&"curva60":          preload("res://structures/curva60.tscn"),
	&"curva120":         preload("res://structures/curva120.tscn"),
	&"rampa1":           preload("res://structures/rampa1.tscn"),
	&"rampa2":           preload("res://structures/rampa2.tscn"),
	&"reto":             preload("res://structures/reto.tscn"),
	
	# ── straight rails (auto-connected by ConnectionScanner) ─────────────
	&"rail_short":       preload("res://structures/rail_short.tscn"),
	&"rail_medium":      preload("res://structures/rail_medium.tscn"),
	&"rail_long":        preload("res://structures/rail_long.tscn"),
	&"rail_extra_long":  preload("res://structures/rail_extra_long.tscn"),

	# ── new structures ────────────────────────────────────────────────────
	&"deflector_alto":   preload("res://structures/deflector_alto.tscn"),
	&"deflector_baixo":  preload("res://structures/deflector_baixo.tscn"),
	&"impulsor_raso":    preload("res://structures/impulsor_raso.tscn"),
	&"impulsor_medio":   preload("res://structures/impulsor_medio.tscn"),
	&"impulsor_alto":    preload("res://structures/impulsor_alto.tscn"),
	&"comutador":        preload("res://structures/comutador.tscn"),
}

## Returns the PackedScene for the given type name, or null + error if unknown.
func get_scene(type: StringName) -> PackedScene:
	var def: StructureDefinition = StructureCatalog.get_by_type(type)
	if def != null and def.scene != null:
		return def.scene
	if not _registry.has(type):
		push_error("StructureRegistry: unknown type '%s'" % type)
		return null
	return _registry[type]

## Register a custom scene at runtime (e.g. from a mod or DLC).
func register(type: StringName, scene: PackedScene) -> void:
	_registry[type] = scene
