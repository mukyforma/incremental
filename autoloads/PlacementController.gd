extends Node

## Single source of truth for what the player has selected.

var active_structure    : StringName = &"marble_spawn"
var active_tool         : StringName = &"build"
var placement_rotation  : int        = 0   # 0–5 steps; each = 60° around Y

signal selection_changed()

func set_structure(type: StringName) -> void:
	active_structure = type
	active_tool      = &"build"
	selection_changed.emit()

func set_tool(tool_name: StringName) -> void:
	active_tool = tool_name
	selection_changed.emit()

## Rotate counter-clockwise (Q) — increases Y rotation.
func rotate_ccw() -> void:
	placement_rotation = (placement_rotation + 1) % 6
	selection_changed.emit()

## Rotate clockwise (E) — decreases Y rotation.
func rotate_cw() -> void:
	placement_rotation = (placement_rotation + 5) % 6
	selection_changed.emit()
