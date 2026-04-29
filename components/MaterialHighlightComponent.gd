class_name MaterialHighlightComponent
extends Node

var _saved_mats: Dictionary
@export var highlight_color: Color = Color(1.0, 0.1, 0.1, 0.55)

## Save current materials on all MeshInstance3D children and apply a tinted override.
func highlight(node: Node3D) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		_saved_mats[mi] = mi.material_override
		var mat := StandardMaterial3D.new()
		mat.albedo_color = highlight_color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat

## Restore all saved material_overrides and clear the saved dict.
func clear() -> void:
	for mi in _saved_mats:
		if is_instance_valid(mi):
			(mi as MeshInstance3D).material_override = _saved_mats[mi]
	_saved_mats.clear()
