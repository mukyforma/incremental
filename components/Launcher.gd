class_name Launcher
extends Node3D

## Speed of the barrel surge in the -Z direction (m/s). Higher = harder launch.
@export var launch_speed: float = 5.0

@onready var _barrel: AnimatableBody3D = $BarrelPivot

var _rest_pos: Vector3
var _firing: bool = false

func _ready() -> void:
	if _barrel == null:
		push_error("Launcher [%s]: BarrelPivot node not found" % name)
		return
	_rest_pos = _barrel.position
	var parent := get_parent()
	if parent != null and parent.get(&"activatable"):
		parent.activated.connect(_fire)

func _fire() -> void:
	if _firing:
		return
	_unfreeze_marbles()
	_firing = true
	var surge := _rest_pos + Vector3(0.0, 0.0, -launch_speed * 0.08)
	var tween  := create_tween()
	tween.tween_property(_barrel, "position", surge, 0.04)
	tween.tween_property(_barrel, "position", _rest_pos, 0.18)
	tween.tween_callback(func() -> void: _firing = false)

func _unfreeze_marbles() -> void:
	for body in get_tree().get_nodes_in_group(&"marble"):
		if body is RigidBody3D and (body as RigidBody3D).freeze:
			(body as RigidBody3D).freeze = false

func _on_marble_spawn_activated() -> void:
	_fire()
